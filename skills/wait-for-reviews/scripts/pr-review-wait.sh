#!/usr/bin/env bash
#
# pr-review-wait.sh — Block until a PR's CI + automated reviews finish (or time out).
#
# A PR is "ready for the next round of implementation" when:
#   1. Every CI check has finished (success OR failure — nothing still running).
#   2. The automated reviewers have finished. The request-reviews skill posts
#      two trigger comments, `/claude-review` and `@greptileai`. Each reviewer
#      adds a 👍 (+1) reaction to its trigger comment when it is done reviewing.
#      Reviews can be requested multiple times, so we only look at the LATEST
#      trigger comment of each kind.
#
# Usage:
#   pr-review-wait.sh [PR_NUMBER] [TIMEOUT_SECONDS] [INTERVAL_SECONDS]
#   pr-review-wait.sh --once [PR_NUMBER]      # single check, print verdict, no waiting
#
# With no PR number it resolves the PR for the current branch.
# Defaults: TIMEOUT=1800 (30 min), INTERVAL=30.
#
# Exit codes:
#   0   = ready (CI + automated reviews are done)
#   1   = not ready yet   (only returned by --once; the polling loop never exits 1)
#   2   = usage / lookup error (no PR, gh not authenticated, etc.)
#   124 = timed out waiting for the PR to become ready

set -euo pipefail

ONCE=0
if [[ "${1:-}" == "--once" ]]; then
  ONCE=1
  shift
fi

PR="${1:-}"
TIMEOUT="${2:-1800}"
INTERVAL="${3:-30}"

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

# latest_plus1 <regex>  ->  prints "MISSING" | "WAITING" | "DONE"
#   MISSING: no trigger comment of this kind exists (no review was requested)
#   WAITING: latest trigger comment has no 👍 yet
#   DONE:    latest trigger comment has a 👍
latest_plus1() {
  local pattern="$1" comments_json="$2"
  jq -r --arg re "$pattern" '
    [ .[] | select(.body | test($re)) ]
    | sort_by(.created_at)
    | last
    | if . == null then "MISSING"
      elif (.reactions["+1"] // 0) > 0 then "DONE"
      else "WAITING" end
  ' <<<"$comments_json"
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

  # --- 2. Automated reviews -------------------------------------------------
  local comments_json
  comments_json="$(gh api --paginate "repos/$REPO/issues/$PR/comments" 2>/dev/null || echo '[]')"

  local label pattern status
  for spec in "Claude:^/claude-review" "Greptile:^@greptileai"; do
    label="${spec%%:*}"
    pattern="${spec#*:}"
    status="$(latest_plus1 "$pattern" "$comments_json")"
    case "$status" in
      DONE)    echo "✓ $label: review complete (👍 on latest request)" ;;
      WAITING) echo "… $label: reviewing (no 👍 on latest request yet)"; reviews_ready=0 ;;
      MISSING) echo "✓ $label: no review requested (treated as done)" ;;
    esac
  done

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
