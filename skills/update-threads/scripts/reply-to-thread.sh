#!/usr/bin/env bash
set -euo pipefail

# Reply to a PR review thread.
# Usage: reply-to-thread.sh <thread_id> <body>
# Requires: gh CLI (authenticated with repo access), jq.

if [ "$#" -lt 2 ]; then
  echo "Usage: reply-to-thread.sh <thread_id> <body>" >&2
  exit 1
fi

THREAD_ID="$1"
shift
BODY="$*"

MUTATION='
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: $threadId, body: $body }) {
    comment { id }
  }
}
'

if ! RESULT=$(gh api graphql \
  -f query="$MUTATION" \
  -f threadId="$THREAD_ID" \
  -f body="$BODY"); then
  echo "Error: GraphQL API request failed for thread $THREAD_ID. Check network and authentication." >&2
  exit 1
fi

if echo "$RESULT" | jq -e 'has("errors") and (.errors | length > 0)' > /dev/null 2>&1; then
  echo "Error: Failed to reply to thread $THREAD_ID:" >&2
  echo "$RESULT" | jq -r '.errors[].message' >&2
  exit 1
fi

echo "Replied to thread $THREAD_ID"
