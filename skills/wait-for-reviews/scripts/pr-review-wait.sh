#!/usr/bin/env bash
#
# pr-review-wait.sh — Block until a PR's CI + automated reviews finish (or time out).
#
# A PR is "ready for the next round of implementation" when:
#   1. Every CI check has finished (success OR failure — nothing still running).
#   2. Every review signal the caller asked for has fired. How a reviewer signals
#      that it is done is repo-specific, so the signals are supplied by the
#      caller (from the repo's docs, memory, or the user) — none are built in.
#      With no signals, only CI is waited on.
#
# Review signals (each may be repeated):
#   --reaction-on REGEX   The latest PR comment whose body matches REGEX has the
#                         done-reaction on it. For reviewers that react to their
#                         trigger comment when finished. Reviews can be requested
#                         multiple times, so only the LATEST match is checked; if
#                         no comment matches, no review was requested and the
#                         signal is treated as done.
#   --review-by LOGIN     LOGIN has submitted a review on the PR's current head
#                         commit. A trailing "[bot]" on either side is ignored.
#   --reaction NAME       The done-reaction for --reaction-on (default: +1).
#                         One of: +1 -1 laugh confused heart hooray rocket eyes.
#
# Usage:
#   pr-review-wait.sh [SIGNALS...] [PR_NUMBER] [TIMEOUT_SECONDS] [INTERVAL_SECONDS]
#   pr-review-wait.sh --once [SIGNALS...] [PR_NUMBER]   # single check, no waiting
#
# With no PR number it resolves the PR for the current branch.
# Defaults: TIMEOUT=1800 (30 min), INTERVAL=30.
#
# Exit codes:
#   0   = ready (CI + requested review signals are done)
#   1   = not ready yet   (only returned by --once; the polling loop never exits 1)
#   2   = usage / lookup error (no PR, gh not authenticated, etc.)
#   124 = timed out waiting for the PR to become ready

set -euo pipefail

usage_error() {
  echo "error: $1" >&2
  echo "usage: pr-review-wait.sh [--once] [--reaction-on REGEX]... [--review-by LOGIN]... [--reaction NAME] [PR_NUMBER] [TIMEOUT_SECONDS] [INTERVAL_SECONDS]" >&2
  exit 2
}

ONCE=0
REACTION="+1"
REACTION_PATTERNS=()
REVIEWERS=()
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --once) ONCE=1; shift ;;
    --reaction-on|--review-by|--reaction)
      [[ $# -ge 2 && -n "$2" ]] || usage_error "$1 needs a value"
      case "$1" in
        --reaction-on) REACTION_PATTERNS+=("$2") ;;
        --review-by)   REVIEWERS+=("$2") ;;
        --reaction)    REACTION="$2" ;;
      esac
      shift 2 ;;
    --*) usage_error "unknown option: $1" ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

case "$REACTION" in
  +1|-1|laugh|confused|heart|hooray|rocket|eyes) ;;
  *) usage_error "unknown reaction: $REACTION" ;;
esac

[[ ${#POSITIONAL[@]} -le 3 ]] || usage_error "too many arguments"
PR="${POSITIONAL[0]:-}"
TIMEOUT="${POSITIONAL[1]:-1800}"
INTERVAL="${POSITIONAL[2]:-30}"

[[ -z "$PR" || "$PR" =~ ^[0-9]+$ ]] || usage_error "PR_NUMBER must be a number"
[[ "$TIMEOUT" =~ ^[0-9]+$ ]] || usage_error "TIMEOUT_SECONDS must be a number"
[[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]] || usage_error "INTERVAL_SECONDS must be a positive number"

for pattern in ${REACTION_PATTERNS[@]+"${REACTION_PATTERNS[@]}"}; do
  jq -n --arg re "$pattern" '"" | test($re)' >/dev/null 2>&1 \
    || usage_error "invalid --reaction-on regex: $pattern"
done

if [[ -z "$PR" ]]; then
  PR="$(gh pr view --json number --jq '.number' 2>/dev/null || true)"
fi
if [[ -z "$PR" ]]; then
  echo "error: no PR number given and no PR found for the current branch" >&2
  exit 2
fi

REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
if [[ -z "$REPO" ]]; then
  echo "error: could not determine repository (is gh authenticated?)" >&2
  exit 2
fi

# fetch_all <api-path>  ->  prints every page merged into one JSON array.
# Returns non-zero if the request fails, so a failed fetch is never mistaken
# for "nothing there".
fetch_all() {
  local out
  out="$(gh api --paginate "$1?per_page=100" 2>/dev/null)" || return 1
  jq -s 'add // []' <<<"$out"
}

# latest_reaction <regex> <comments-json>  ->  prints "MISSING" | "WAITING" | "DONE"
#   MISSING: no comment matches (no review was requested)
#   WAITING: latest matching comment has no done-reaction yet
#   DONE:    latest matching comment has the done-reaction
latest_reaction() {
  local pattern="$1" comments_json="$2"
  jq -r --arg re "$pattern" --arg reaction "$REACTION" '
    [ .[] | select((.body // "") | test($re)) ]
    | sort_by(.created_at)
    | last
    | if . == null then "MISSING"
      elif (.reactions[$reaction] // 0) > 0 then "DONE"
      else "WAITING" end
  ' <<<"$comments_json"
}

# reviewed_head <login> <head-sha> <reviews-json>  ->  prints "DONE" | "WAITING"
reviewed_head() {
  local login="$1" head="$2" reviews_json="$3"
  jq -r --arg login "$login" --arg head "$head" '
    def norm: ascii_downcase | sub("\\[bot\\]$"; "");
    if any(.[];
         ((.user.login // "") | norm) == ($login | norm)
         and .commit_id == $head
         and .state != "PENDING")
    then "DONE" else "WAITING" end
  ' <<<"$reviews_json"
}

# check_ready  ->  0 = ready, 1 = not ready.  Prints a human-readable status block.
check_ready() {
  local ci_ready=1 reviews_ready=1

  # --- 1. CI checks ---------------------------------------------------------
  # `bucket` collapses GitHub's many states into: pass | fail | pending | skipping | cancel.
  # Anything still in flight lands in "pending"; everything else has settled.
  # `gh pr checks` exits non-zero when checks are failing/pending but still
  # prints JSON, so capture output independently of exit status and only fall
  # back to "[]" when stdout is genuinely empty (e.g. no checks configured).
  local checks_json
  checks_json="$(gh pr checks "$PR" --json name,bucket 2>/dev/null)" || true
  [[ -z "$checks_json" ]] && checks_json='[]'

  local pending_count pending_names
  pending_count="$(jq '[.[] | select(.bucket == "pending")] | length' <<<"$checks_json")"

  if [[ "$pending_count" -eq 0 ]]; then
    echo "✓ CI: all checks finished"
  else
    ci_ready=0
    pending_names="$(jq -r '.[] | select(.bucket == "pending") | "    - " + .name' <<<"$checks_json")"
    echo "… CI: $pending_count check(s) still running:"
    echo "$pending_names"
  fi

  # --- 2. Review signals ----------------------------------------------------
  if [[ ${#REACTION_PATTERNS[@]} -eq 0 && ${#REVIEWERS[@]} -eq 0 ]]; then
    echo "✓ Reviews: no review signals requested (CI only)"
  fi

  local status
  if [[ ${#REACTION_PATTERNS[@]} -gt 0 ]]; then
    local comments_json pattern
    if comments_json="$(fetch_all "repos/$REPO/issues/$PR/comments")"; then
      for pattern in "${REACTION_PATTERNS[@]}"; do
        status="$(latest_reaction "$pattern" "$comments_json")"
        case "$status" in
          DONE)    echo "✓ $pattern: review complete ($REACTION on latest request)" ;;
          WAITING) echo "… $pattern: reviewing (no $REACTION on latest request yet)"; reviews_ready=0 ;;
          MISSING) echo "✓ $pattern: no review requested (treated as done)" ;;
        esac
      done
    else
      echo "… could not fetch PR comments; will retry"
      reviews_ready=0
    fi
  fi

  if [[ ${#REVIEWERS[@]} -gt 0 ]]; then
    local head reviews_json login
    head="$(gh pr view "$PR" --json headRefOid --jq '.headRefOid' 2>/dev/null || true)"
    if [[ -n "$head" ]] && reviews_json="$(fetch_all "repos/$REPO/pulls/$PR/reviews")"; then
      for login in "${REVIEWERS[@]}"; do
        status="$(reviewed_head "$login" "$head" "$reviews_json")"
        case "$status" in
          DONE)    echo "✓ $login: reviewed ${head:0:7}" ;;
          WAITING) echo "… $login: no review on ${head:0:7} yet"; reviews_ready=0 ;;
        esac
      done
    else
      echo "… could not fetch PR reviews; will retry"
      reviews_ready=0
    fi
  fi

  [[ "$ci_ready" -eq 1 && "$reviews_ready" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# --once: single check, report, exit 0/1.
# ---------------------------------------------------------------------------
if [[ "$ONCE" -eq 1 ]]; then
  echo "Checking PR #$PR in $REPO …"
  if check_ready; then
    echo
    echo "READY — CI and automated reviews are done."
    exit 0
  fi
  echo
  echo "NOT READY — still waiting on the items marked above."
  exit 1
fi

# ---------------------------------------------------------------------------
# Polling loop: check, sleep, repeat until ready or the deadline passes.
# ---------------------------------------------------------------------------
start="$(date +%s)"
deadline=$(( start + TIMEOUT ))

echo "Waiting on PR #$PR in $REPO (timeout ${TIMEOUT}s, polling every ${INTERVAL}s) …"
while :; do
  echo
  echo "--- $(date '+%H:%M:%S') ---"
  if check_ready; then
    echo
    echo "READY after $(( $(date +%s) - start ))s — CI and automated reviews are done."
    exit 0
  fi

  now="$(date +%s)"
  if (( now + INTERVAL > deadline )); then
    echo
    echo "TIMED OUT after ${TIMEOUT}s — still waiting on the items marked above." >&2
    exit 124
  fi
  echo "… not ready; sleeping ${INTERVAL}s ($(( deadline - now ))s left)"
  sleep "$INTERVAL"
done
