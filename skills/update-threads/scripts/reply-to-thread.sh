#!/usr/bin/env bash
set -euo pipefail

# Idempotently add one reply to an explicitly managed pending review.
# Usage: reply-to-thread.sh <review_id> <thread_id> <body>
# Requires: gh CLI (authenticated with repo access), jq.

if [ "$#" -lt 3 ]; then
  echo "Usage: reply-to-thread.sh <review_id> <thread_id> <body>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=review-lib.sh
source "$SCRIPT_DIR/review-lib.sh"

REVIEW_ID="$1"
THREAD_ID="$2"
shift 2
BODY="$*"
if [ -z "$REVIEW_ID" ] || [ -z "$THREAD_ID" ] || [ -z "$BODY" ]; then
  echo "Error: Review ID, thread ID, and reply body must not be empty." >&2
  exit 2
fi
require_review_tools
MARKER=$(reply_marker "$REVIEW_ID" "$THREAD_ID")
BODY_WITH_MARKER=$(printf '%s\n\n%s' "$BODY" "$MARKER")

CONTEXT_QUERY='
query($reviewId: ID!, $threadId: ID!) {
  review: node(id: $reviewId) {
    ... on PullRequestReview {
      id
      state
      body
      pullRequest { id number }
    }
  }
  thread: node(id: $threadId) {
    ... on PullRequestReviewThread {
      id
      isResolved
      viewerCanReply
      pullRequest { id }
      comments(first: 100) {
        pageInfo { hasNextPage }
        nodes {
          id
          body
          pullRequestReview { id }
        }
      }
    }
  }
}
'

if ! CONTEXT=$(graphql \
  -f query="$CONTEXT_QUERY" \
  -f reviewId="$REVIEW_ID" \
  -f threadId="$THREAD_ID"); then
  exit 1
fi

if ! printf '%s\n' "$CONTEXT" | jq -e \
  '.data.review.id != null and .data.thread.id != null' > /dev/null; then
  echo "Error: The managed review or thread was not found." >&2
  exit 1
fi
if [ "$(printf '%s\n' "$CONTEXT" | jq -r '.data.review.state')" != "PENDING" ]; then
  echo "Error: Review $REVIEW_ID is not pending." >&2
  exit 1
fi
if [ "$(printf '%s\n' "$CONTEXT" | jq -r '.data.review.body')" != "$MANAGED_REVIEW_MARKER" ]; then
  echo "Error: Review $REVIEW_ID was not created by update-threads." >&2
  exit 1
fi
if [ "$(printf '%s\n' "$CONTEXT" | jq -r '.data.review.pullRequest.id')" != \
     "$(printf '%s\n' "$CONTEXT" | jq -r '.data.thread.pullRequest.id')" ]; then
  echo "Error: Review $REVIEW_ID and thread $THREAD_ID belong to different pull requests." >&2
  exit 1
fi
if [ "$(printf '%s\n' "$CONTEXT" | jq -r '.data.thread.isResolved')" = "true" ]; then
  echo "Error: Review thread $THREAD_ID is already resolved." >&2
  exit 1
fi
if [ "$(printf '%s\n' "$CONTEXT" | jq -r '.data.thread.viewerCanReply')" != "true" ]; then
  echo "Error: The authenticated user cannot reply to review thread $THREAD_ID." >&2
  exit 1
fi
if [ "$(printf '%s\n' "$CONTEXT" | jq -r \
  '.data.thread.comments.pageInfo.hasNextPage')" = "true" ]; then
  echo "Error: Thread $THREAD_ID has more than 100 comments; refusing an incomplete reconciliation." >&2
  exit 1
fi

EXISTING_COMMENT=$(printf '%s\n' "$CONTEXT" | jq -c \
  --arg review_id "$REVIEW_ID" \
  --arg marker "$MARKER" \
  '[.data.thread.comments.nodes[] |
    select(.pullRequestReview.id == $review_id and (.body | endswith($marker)))][0] // empty')
if [ -n "$EXISTING_COMMENT" ]; then
  EXISTING_COMMENT_ID=$(printf '%s\n' "$EXISTING_COMMENT" | jq -r '.id')
  EXISTING_BODY=$(printf '%s\n' "$EXISTING_COMMENT" | jq -r '.body')
  if [ "$EXISTING_BODY" != "$BODY_WITH_MARKER" ]; then
    echo "Error: Thread $THREAD_ID already has a managed reply with different text." >&2
    echo "Explicitly discard the managed review before changing a drafted reply." >&2
    exit 1
  fi
  jq -n \
    --arg review_id "$REVIEW_ID" \
    --arg thread_id "$THREAD_ID" \
    --arg comment_id "$EXISTING_COMMENT_ID" \
    '{review_id:$review_id, thread_id:$thread_id, comment_id:$comment_id, posted:false, reconciled:true}'
  exit 0
fi

MUTATION='
mutation($reviewId: ID!, $threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewId: $reviewId
    pullRequestReviewThreadId: $threadId
    body: $body
  }) {
    comment {
      id
      state
      pullRequestReview { id }
    }
  }
}
'

if ! RESULT=$(graphql \
  -f query="$MUTATION" \
  -f reviewId="$REVIEW_ID" \
  -f threadId="$THREAD_ID" \
  -f body="$BODY_WITH_MARKER"); then
  exit 1
fi

COMMENT_ID=$(printf '%s\n' "$RESULT" | jq -r \
  '.data.addPullRequestReviewThreadReply.comment.id')
COMMENT_STATE=$(printf '%s\n' "$RESULT" | jq -r \
  '.data.addPullRequestReviewThreadReply.comment.state')
ATTACHED_REVIEW_ID=$(printf '%s\n' "$RESULT" | jq -r \
  '.data.addPullRequestReviewThreadReply.comment.pullRequestReview.id')
if [ -z "$COMMENT_ID" ] || [ "$COMMENT_ID" = "null" ] || \
   [ "$COMMENT_STATE" != "PENDING" ] || [ "$ATTACHED_REVIEW_ID" != "$REVIEW_ID" ]; then
  echo "Error: GitHub did not attach the reply to managed review $REVIEW_ID." >&2
  exit 1
fi

jq -n \
  --arg review_id "$REVIEW_ID" \
  --arg thread_id "$THREAD_ID" \
  --arg comment_id "$COMMENT_ID" \
  '{review_id:$review_id, thread_id:$thread_id, comment_id:$comment_id, posted:true, reconciled:false}'
