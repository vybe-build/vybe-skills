#!/usr/bin/env bash
set -euo pipefail

# Post a single file-level review comment (no line number) on a pull request.
# Usage: post-file-comment.sh <pr_number> <path> <commit_id> <body>
# Requires: gh CLI (authenticated with repo access), jq.

if [ "$#" -lt 4 ]; then
  echo "Usage: post-file-comment.sh <pr_number> <path> <commit_id> <body>" >&2
  exit 1
fi

PR_NUMBER="$1"
FILE_PATH="$2"
COMMIT_ID="$3"
shift 3
BODY="$*"

if ! REPO_INFO=$(gh repo view --json owner,name --jq '.owner.login + " " + .name'); then
  echo "Error: Could not determine repository owner/name." >&2
  exit 1
fi
OWNER=$(echo "$REPO_INFO" | awk '{print $1}')
REPO=$(echo "$REPO_INFO" | awk '{print $2}')

PAYLOAD=$(jq -n \
  --arg body "$BODY" \
  --arg commit_id "$COMMIT_ID" \
  --arg path "$FILE_PATH" \
  '{
    body: $body,
    commit_id: $commit_id,
    path: $path,
    subject_type: "file"
  }')

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
echo "$PAYLOAD" > "$TMPFILE"

if ! RESULT=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" \
  --method POST \
  --input "$TMPFILE" 2>&1); then
  echo "Error: Failed to post file comment on $FILE_PATH: $RESULT" >&2
  exit 1
fi

if echo "$RESULT" | jq -e '.message' > /dev/null 2>&1; then
  MSG=$(echo "$RESULT" | jq -r '.message')
  if [ "$MSG" != "null" ]; then
    echo "Error: GitHub API error posting file comment on $FILE_PATH: $MSG" >&2
    exit 1
  fi
fi

echo "Posted file-level comment on $FILE_PATH"
