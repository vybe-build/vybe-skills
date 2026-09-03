#!/usr/bin/env bash
set -euo pipefail

# Publish replies to PR review threads in one explicitly managed review. This
# avoids GitHub implicitly assigning replies to arbitrary pending reviews when
# pullRequestReviewId is omitted. Thread resolution is intentionally separate.
#
# Usage:
#   reply-to-threads.sh <thread_id> <body> [<thread_id> <body> ...]
#
# Requires: gh CLI (authenticated with repo access), jq.

usage() {
  echo "Usage: reply-to-threads.sh <thread_id> <body> [<thread_id> <body> ...]" >&2
}

if [ "$#" -lt 2 ] || [ $(( $# % 2 )) -ne 0 ]; then
  usage
  exit 2
fi

for command in gh jq; do
  if ! command -v "$command" > /dev/null 2>&1; then
    echo "Error: Required command '$command' was not found." >&2
    exit 2
  fi
done

THREAD_IDS=()
BODIES=()
while [ "$#" -gt 0 ]; do
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Thread IDs and reply bodies must not be empty." >&2
    exit 2
  fi
  THREAD_IDS+=("$1")
  BODIES+=("$2")
  shift 2
done

for ((i = 0; i < ${#THREAD_IDS[@]}; i++)); do
  for ((j = i + 1; j < ${#THREAD_IDS[@]}; j++)); do
    if [ "${THREAD_IDS[$i]}" = "${THREAD_IDS[$j]}" ]; then
      echo "Error: Duplicate thread ID ${THREAD_IDS[$i]}." >&2
      exit 2
    fi
  done
done

graphql() {
  local result

  if ! result=$(gh api graphql "$@"); then
    echo "Error: GitHub GraphQL request failed. Check network and authentication." >&2
    return 1
  fi

  if echo "$result" | jq -e 'has("errors") and (.errors | length > 0)' > /dev/null 2>&1; then
    echo "Error: GitHub GraphQL request returned errors:" >&2
    echo "$result" | jq -r '.errors[].message' >&2
    return 1
  fi

  printf '%s\n' "$result"
}

CONTEXT_QUERY='
query($threadId: ID!) {
  viewer { login }
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      id
      isResolved
      viewerCanReply
      viewerCanResolve
      pullRequest {
        id
        number
        url
        reviews(first: 100, states: [PENDING]) {
          nodes {
            id
            author { login }
          }
        }
      }
    }
  }
}
'

PR_ID=""
PR_NUMBER=""
PR_URL=""
VIEWER_LOGIN=""

# Validate every target before creating any GitHub content. The explicit review
# created below is all-or-nothing, so predictable permission or input failures
# should be caught before it exists.
for ((i = 0; i < ${#THREAD_IDS[@]}; i++)); do
  THREAD_ID="${THREAD_IDS[$i]}"
  if ! CONTEXT=$(graphql -f query="$CONTEXT_QUERY" -f threadId="$THREAD_ID"); then
    exit 1
  fi

  if ! echo "$CONTEXT" | jq -e '.data.node.id != null' > /dev/null; then
    echo "Error: Review thread $THREAD_ID was not found or is not accessible." >&2
    exit 1
  fi

  CURRENT_PR_ID=$(echo "$CONTEXT" | jq -r '.data.node.pullRequest.id')
  if [ -z "$PR_ID" ]; then
    PR_ID="$CURRENT_PR_ID"
    PR_NUMBER=$(echo "$CONTEXT" | jq -r '.data.node.pullRequest.number')
    PR_URL=$(echo "$CONTEXT" | jq -r '.data.node.pullRequest.url')
    VIEWER_LOGIN=$(echo "$CONTEXT" | jq -r '.data.viewer.login')
  elif [ "$CURRENT_PR_ID" != "$PR_ID" ]; then
    echo "Error: All review threads must belong to the same pull request." >&2
    exit 1
  fi

  if [ "$(echo "$CONTEXT" | jq -r '.data.node.isResolved')" = "true" ]; then
    echo "Error: Review thread $THREAD_ID is already resolved." >&2
    exit 1
  fi
  if [ "$(echo "$CONTEXT" | jq -r '.data.node.viewerCanReply')" != "true" ]; then
    echo "Error: The authenticated user cannot reply to review thread $THREAD_ID." >&2
    exit 1
  fi
  if [ "$(echo "$CONTEXT" | jq -r '.data.node.viewerCanResolve')" != "true" ]; then
    echo "Error: The authenticated user cannot resolve review thread $THREAD_ID." >&2
    exit 1
  fi

  PENDING_REVIEW_ID=$(echo "$CONTEXT" | jq -r --arg login "$VIEWER_LOGIN" \
    '.data.node.pullRequest.reviews.nodes[] | select(.author.login == $login) | .id' | head -n 1)
  if [ -n "$PENDING_REVIEW_ID" ]; then
    echo "Error: $VIEWER_LOGIN already has a pending review on PR #$PR_NUMBER." >&2
    echo "Submit or discard that review, then retry. No replies were posted." >&2
    exit 1
  fi
done

CREATE_REVIEW_MUTATION='
mutation($pullRequestId: ID!) {
  addPullRequestReview(input: { pullRequestId: $pullRequestId }) {
    pullRequestReview { id state }
  }
}
'

if ! CREATE_RESULT=$(graphql -f query="$CREATE_REVIEW_MUTATION" -f pullRequestId="$PR_ID"); then
  exit 1
fi

REVIEW_ID=$(echo "$CREATE_RESULT" | jq -r '.data.addPullRequestReview.pullRequestReview.id')
REVIEW_STATE=$(echo "$CREATE_RESULT" | jq -r '.data.addPullRequestReview.pullRequestReview.state')
if [ -z "$REVIEW_ID" ] || [ "$REVIEW_ID" = "null" ] || [ "$REVIEW_STATE" != "PENDING" ]; then
  echo "Error: GitHub did not create the expected pending review for PR #$PR_NUMBER." >&2
  exit 1
fi

REVIEW_NEEDS_CLEANUP=1
DELETE_REVIEW_MUTATION='
mutation($reviewId: ID!) {
  deletePullRequestReview(input: { pullRequestReviewId: $reviewId }) {
    pullRequestReview { id }
  }
}
'

cleanup_review() {
  if [ "$REVIEW_NEEDS_CLEANUP" -eq 1 ]; then
    if gh api graphql \
      -f query="$DELETE_REVIEW_MUTATION" \
      -f reviewId="$REVIEW_ID" > /dev/null 2>&1; then
      echo "Discarded temporary pending review $REVIEW_ID after failure." >&2
    else
      echo "Warning: Could not discard temporary pending review $REVIEW_ID on $PR_URL." >&2
    fi
  fi
}
trap cleanup_review EXIT

REPLY_MUTATION='
mutation($threadId: ID!, $reviewId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: $threadId
    pullRequestReviewId: $reviewId
    body: $body
  }) {
    comment {
      id
      state
      pullRequestReview { id state }
    }
  }
}
'

for ((i = 0; i < ${#THREAD_IDS[@]}; i++)); do
  THREAD_ID="${THREAD_IDS[$i]}"
  BODY="${BODIES[$i]}"
  if ! REPLY_RESULT=$(graphql \
    -f query="$REPLY_MUTATION" \
    -f threadId="$THREAD_ID" \
    -f reviewId="$REVIEW_ID" \
    -f body="$BODY"); then
    exit 1
  fi

  ATTACHED_REVIEW_ID=$(echo "$REPLY_RESULT" | jq -r \
    '.data.addPullRequestReviewThreadReply.comment.pullRequestReview.id')
  COMMENT_STATE=$(echo "$REPLY_RESULT" | jq -r \
    '.data.addPullRequestReviewThreadReply.comment.state')
  if [ "$ATTACHED_REVIEW_ID" != "$REVIEW_ID" ] || [ "$COMMENT_STATE" != "PENDING" ]; then
    echo "Error: GitHub did not attach the reply for $THREAD_ID to review $REVIEW_ID." >&2
    exit 1
  fi
done

SUBMIT_REVIEW_MUTATION='
mutation($reviewId: ID!) {
  submitPullRequestReview(input: {
    pullRequestReviewId: $reviewId
    event: COMMENT
  }) {
    pullRequestReview { id state submittedAt }
  }
}
'

if ! SUBMIT_RESULT=$(graphql -f query="$SUBMIT_REVIEW_MUTATION" -f reviewId="$REVIEW_ID"); then
  exit 1
fi

SUBMITTED_REVIEW_ID=$(echo "$SUBMIT_RESULT" | jq -r \
  '.data.submitPullRequestReview.pullRequestReview.id')
SUBMITTED_REVIEW_STATE=$(echo "$SUBMIT_RESULT" | jq -r \
  '.data.submitPullRequestReview.pullRequestReview.state')
SUBMITTED_AT=$(echo "$SUBMIT_RESULT" | jq -r \
  '.data.submitPullRequestReview.pullRequestReview.submittedAt')
if [ "$SUBMITTED_REVIEW_ID" != "$REVIEW_ID" ] || \
   [ "$SUBMITTED_REVIEW_STATE" != "COMMENTED" ] || \
   [ -z "$SUBMITTED_AT" ] || [ "$SUBMITTED_AT" = "null" ]; then
  echo "Error: GitHub did not confirm publication of review $REVIEW_ID." >&2
  exit 1
fi

# The review is now published and must never be deleted by the cleanup trap.
REVIEW_NEEDS_CLEANUP=0

echo "Published ${#THREAD_IDS[@]} replies on PR #$PR_NUMBER."
