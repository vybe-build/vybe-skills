#!/usr/bin/env bash
#
# post-review-triggers.sh — Post review-trigger comments on a PR.
#
# Posts one comment per trigger argument. The triggers themselves are
# repo-specific and are supplied by the caller (from the repo's docs, memory,
# or the user) — none are built in.
#
# Usage:
#   post-review-triggers.sh PR_NUMBER TRIGGER [TRIGGER...]
#
# Example:
#   post-review-triggers.sh 123 '/some-review-command' '@some-review-bot'
#
# Exit codes:
#   0 = every trigger comment posted
#   2 = usage error (missing/invalid PR number, no triggers)

set -euo pipefail

usage() {
  echo "usage: post-review-triggers.sh PR_NUMBER TRIGGER [TRIGGER...]" >&2
  exit 2
}

PR="${1:-}"
if [[ ! "$PR" =~ ^[0-9]+$ ]]; then
  echo "error: first argument must be a PR number" >&2
  usage
fi
shift

if [[ $# -eq 0 ]]; then
  echo "error: no triggers given" >&2
  usage
fi

for trigger in "$@"; do
  if [[ -z "${trigger//[[:space:]]/}" ]]; then
    echo "error: empty trigger" >&2
    usage
  fi
done

for trigger in "$@"; do
  gh pr comment "$PR" --body "$trigger"
  echo "posted: $trigger"
done
