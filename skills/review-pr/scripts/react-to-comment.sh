#!/usr/bin/env bash
set -euo pipefail

# Add a reaction to a PR/issue comment.
# Usage: react-to-comment.sh <comment_id> <reaction>
#
# Reactions: +1, -1, laugh, confused, heart, hooray, rocket, eyes
#
# The comment_id is the numeric ID from the GitHub REST API (not the GraphQL node ID).
# Requires: gh CLI (authenticated with repo access).

if [ "$#" -lt 2 ]; then
  echo "Usage: react-to-comment.sh <comment_id> <reaction>" >&2
  exit 1
fi

COMMENT_ID="$1"
REACTION="$2"

if ! REPO_INFO=$(gh repo view --json owner,name --jq '.owner.login + "/" + .name'); then
  echo "Error: Could not determine repository." >&2
  exit 1
fi

if gh api "repos/$REPO_INFO/issues/comments/$COMMENT_ID/reactions" \
  --method POST \
  -f content="$REACTION" > /dev/null 2>&1; then
  echo "Added '$REACTION' reaction to comment $COMMENT_ID"
else
  echo "Warning: Failed to add '$REACTION' reaction to comment $COMMENT_ID" >&2
fi
