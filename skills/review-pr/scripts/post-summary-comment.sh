#!/usr/bin/env bash
set -euo pipefail

# Post or update the summary scorecard comment on a pull request.
# Usage: post-summary-comment.sh <pr_number> <body_file>
# Requires: gh CLI (authenticated with repo access).

if [ "$#" -lt 2 ]; then
  echo "Usage: post-summary-comment.sh <pr_number> <body_file>" >&2
  exit 1
fi

PR_NUMBER="$1"
BODY_FILE="$2"

if [ ! -f "$BODY_FILE" ]; then
  echo "Error: Body file not found: $BODY_FILE" >&2
  exit 1
fi

# Try --edit-last with --create-if-none first (updates existing comment or creates new)
if gh pr comment "$PR_NUMBER" --body-file "$BODY_FILE" --edit-last --create-if-none 2>/dev/null; then
  echo "Posted summary comment on PR #$PR_NUMBER"
  exit 0
fi

# Fallback: try --edit-last alone (fails if no prior comment)
if gh pr comment "$PR_NUMBER" --body-file "$BODY_FILE" --edit-last 2>/dev/null; then
  echo "Updated existing summary comment on PR #$PR_NUMBER"
  exit 0
fi

# Final fallback: create a new comment
if gh pr comment "$PR_NUMBER" --body-file "$BODY_FILE" 2>/dev/null; then
  echo "Created new summary comment on PR #$PR_NUMBER"
  exit 0
fi

echo "Error: Failed to post summary comment on PR #$PR_NUMBER" >&2
exit 1
