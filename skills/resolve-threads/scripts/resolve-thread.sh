#!/usr/bin/env bash
set -euo pipefail

# Resolve a single PR review thread by its GraphQL node ID.
# Usage: resolve-thread.sh <thread_id>
# Requires: gh CLI (authenticated with repo access), jq.

THREAD_ID="${1:?Usage: resolve-thread.sh <thread_id>}"

MUTATION='
mutation($threadId: ID!) {
  resolveReviewThread(input: { threadId: $threadId }) {
    thread { id isResolved }
  }
}
'

if ! RESULT=$(gh api graphql \
  -f query="$MUTATION" \
  -f threadId="$THREAD_ID"); then
  echo "Error: GraphQL API request failed for thread $THREAD_ID. Check network and authentication." >&2
  exit 1
fi

if echo "$RESULT" | jq -e 'has("errors") and (.errors | length > 0)' > /dev/null 2>&1; then
  echo "Error: Failed to resolve thread $THREAD_ID:" >&2
  echo "$RESULT" | jq -r '.errors[].message' >&2
  exit 1
fi

IS_RESOLVED=$(echo "$RESULT" | jq -r '.data.resolveReviewThread.thread.isResolved')

if [ "$IS_RESOLVED" = "true" ]; then
  echo "Resolved thread $THREAD_ID"
else
  echo "Warning: Thread $THREAD_ID may not have been resolved" >&2
  exit 1
fi
