#!/usr/bin/env bash
set -euo pipefail

# Create a managed pending review for the PR containing a review thread. If a
# prior update-threads run left its managed review pending, return it so the
# caller can resume posting missing replies.
# Usage: create-review.sh <thread_id>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=review-lib.sh
source "$SCRIPT_DIR/review-lib.sh"

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "Usage: create-review.sh <thread_id>" >&2
  exit 2
fi
THREAD_ID="$1"
require_review_tools

CONTEXT_QUERY='
query($threadId: ID!) {
  viewer { login }
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      id
      pullRequest {
        id
        number
        url
        reviews(first: 100, states: [PENDING]) {
          nodes {
            id
            body
            author { login }
            comments { totalCount }
          }
        }
      }
    }
  }
}
'

if ! CONTEXT=$(graphql -f query="$CONTEXT_QUERY" -f threadId="$THREAD_ID"); then
  exit 1
fi
if ! printf '%s\n' "$CONTEXT" | jq -e '.data.node.id != null' > /dev/null; then
  echo "Error: Review thread $THREAD_ID was not found or is not accessible." >&2
  exit 1
fi

VIEWER_LOGIN=$(printf '%s\n' "$CONTEXT" | jq -r '.data.viewer.login')
PR_ID=$(printf '%s\n' "$CONTEXT" | jq -r '.data.node.pullRequest.id')
PR_NUMBER=$(printf '%s\n' "$CONTEXT" | jq -r '.data.node.pullRequest.number')
PR_URL=$(printf '%s\n' "$CONTEXT" | jq -r '.data.node.pullRequest.url')
PENDING_REVIEW=$(printf '%s\n' "$CONTEXT" | jq -c --arg login "$VIEWER_LOGIN" \
  '[.data.node.pullRequest.reviews.nodes[] | select(.author.login == $login)][0] // empty')

if [ -n "$PENDING_REVIEW" ]; then
  REVIEW_ID=$(printf '%s\n' "$PENDING_REVIEW" | jq -r '.id')
  REVIEW_BODY=$(printf '%s\n' "$PENDING_REVIEW" | jq -r '.body')
  COMMENT_COUNT=$(printf '%s\n' "$PENDING_REVIEW" | jq -r '.comments.totalCount')
  if [ "$REVIEW_BODY" != "$MANAGED_REVIEW_MARKER" ]; then
    echo "Error: $VIEWER_LOGIN already has an unrelated pending review on PR #$PR_NUMBER." >&2
    echo "Submit or discard that review before running update-threads." >&2
    exit 1
  fi

  jq -n \
    --arg review_id "$REVIEW_ID" \
    --arg pr_url "$PR_URL" \
    --argjson pr_number "$PR_NUMBER" \
    --argjson comment_count "$COMMENT_COUNT" \
    '{review_id:$review_id, pr_number:$pr_number, pr_url:$pr_url, resumed:true, existing_reply_count:$comment_count}'
  exit 0
fi

CREATE_REVIEW_MUTATION='
mutation($pullRequestId: ID!, $body: String!) {
  addPullRequestReview(input: { pullRequestId: $pullRequestId, body: $body }) {
    pullRequestReview { id state }
  }
}
'

if ! CREATE_RESULT=$(graphql \
  -f query="$CREATE_REVIEW_MUTATION" \
  -f pullRequestId="$PR_ID" \
  -f body="$MANAGED_REVIEW_MARKER"); then
  exit 1
fi

REVIEW_ID=$(printf '%s\n' "$CREATE_RESULT" | jq -r \
  '.data.addPullRequestReview.pullRequestReview.id')
REVIEW_STATE=$(printf '%s\n' "$CREATE_RESULT" | jq -r \
  '.data.addPullRequestReview.pullRequestReview.state')
if [ -z "$REVIEW_ID" ] || [ "$REVIEW_ID" = "null" ] || [ "$REVIEW_STATE" != "PENDING" ]; then
  echo "Error: GitHub did not create the expected pending review for PR #$PR_NUMBER." >&2
  exit 1
fi

jq -n \
  --arg review_id "$REVIEW_ID" \
  --arg pr_url "$PR_URL" \
  --argjson pr_number "$PR_NUMBER" \
  '{review_id:$review_id, pr_number:$pr_number, pr_url:$pr_url, resumed:false, existing_reply_count:0}'
