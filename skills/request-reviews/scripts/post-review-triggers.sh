#!/usr/bin/env bash
#
# post-review-triggers.sh — Post the automated-reviewer trigger comments on a PR.
#
# Posts one comment per trigger to re-invoke the automated reviewers. To change
# which reviewers are triggered (as reviewers come and go), edit the TRIGGERS
# array below — nothing else needs to change.
#
# Usage:
#   post-review-triggers.sh [PR_NUMBER]
#
# With no PR number it resolves the PR for the current branch.
#
# Exit codes:
#   0 = both trigger comments posted
#   2 = lookup error (no PR, gh not authenticated, etc.)

set -euo pipefail

# The trigger comments to post, one per automated reviewer.
TRIGGERS=(
  '/claude-review'
  '@greptileai'
)

PR="${1:-}"
if [[ -z "$PR" ]]; then
  PR="$(gh pr view --json number --jq '.number' 2>/dev/null || true)"
fi
if [[ -z "$PR" ]]; then
  echo "error: no PR number given and no PR found for the current branch" >&2
  exit 2
fi

for trigger in "${TRIGGERS[@]}"; do
  gh pr comment "$PR" --body "$trigger"
  echo "posted: $trigger"
done
