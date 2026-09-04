#!/usr/bin/env bash
set -euo pipefail

# Submit a managed review only when its replies exactly match the expected
# thread IDs. Rerunning after an ambiguous submit result is safe.
# Usage: submit-review.sh <review_id> <thread_id> [<thread_id> ...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=review-lib.sh
source "$SCRIPT_DIR/review-lib.sh"

if [ "$#" -lt 2 ]; then
  echo "Usage: submit-review.sh <review_id> <thread_id> [<thread_id> ...]" >&2
  exit 2
fi

REVIEW_ID="$1"
shift
THREAD_IDS=("$@")
require_review_tools

for ((i = 0; i < ${#THREAD_IDS[@]}; i++)); do
  if [ -z "${THREAD_IDS[$i]}" ]; then
    echo "Error: Expected thread IDs must be non-empty and unique." >&2
    exit 2
  fi
  for ((j = i + 1; j < ${#THREAD_IDS[@]}; j++)); do
    if [ "${THREAD_IDS[$i]}" = "${THREAD_IDS[$j]}" ]; then
      echo "Error: Expected thread IDs must be non-empty and unique." >&2
      exit 2
    fi
  done
done

REVIEW_QUERY='
query($reviewId: ID!) {
  node(id: $reviewId) {
    ... on PullRequestReview {
      id
      state
      submittedAt
      body
      pullRequest { number url }
      comments(first: 100) {
        pageInfo { hasNextPage }
        nodes { id body state }
      }
    }
  }
}
'

if ! REVIEW_RESULT=$(graphql -f query="$REVIEW_QUERY" -f reviewId="$REVIEW_ID"); then
  exit 1
fi
if ! printf '%s\n' "$REVIEW_RESULT" | jq -e '.data.node.id != null' > /dev/null; then
  echo "Error: Review $REVIEW_ID was not found or is not accessible." >&2
  exit 1
fi
if [ "$(printf '%s\n' "$REVIEW_RESULT" | jq -r '.data.node.body')" != \
     "$MANAGED_REVIEW_MARKER" ]; then
  echo "Error: Review $REVIEW_ID was not created by update-threads." >&2
  exit 1
fi
if [ "$(printf '%s\n' "$REVIEW_RESULT" | jq -r \
  '.data.node.comments.pageInfo.hasNextPage')" = "true" ]; then
  echo "Error: Review $REVIEW_ID has more than 100 comments; refusing incomplete validation." >&2
  exit 1
fi

COMMENT_COUNT=$(printf '%s\n' "$REVIEW_RESULT" | jq \
  '.data.node.comments.nodes | length')
if [ "$COMMENT_COUNT" -ne "${#THREAD_IDS[@]}" ]; then
  echo "Error: Review $REVIEW_ID has $COMMENT_COUNT replies; expected ${#THREAD_IDS[@]}." >&2
  echo "Post the missing replies or explicitly discard the managed review." >&2
  exit 1
fi

for THREAD_ID in "${THREAD_IDS[@]}"; do
  MARKER=$(reply_marker "$REVIEW_ID" "$THREAD_ID")
  MATCH_COUNT=$(printf '%s\n' "$REVIEW_RESULT" | jq \
    --arg marker "$MARKER" \
    '[.data.node.comments.nodes[] | select(.body | endswith($marker))] | length')
  if [ "$MATCH_COUNT" -ne 1 ]; then
    echo "Error: Expected exactly one reply for thread $THREAD_ID; found $MATCH_COUNT." >&2
    exit 1
  fi
done

MANAGED_COMMENT_COUNT=$(printf '%s\n' "$REVIEW_RESULT" | jq \
  --arg prefix "<!-- update-threads:$REVIEW_ID:" \
  '[.data.node.comments.nodes[] | select(.body | contains($prefix))] | length')
if [ "$MANAGED_COMMENT_COUNT" -ne "$COMMENT_COUNT" ]; then
  echo "Error: Review $REVIEW_ID contains comments not created by update-threads." >&2
  exit 1
fi

REVIEW_STATE=$(printf '%s\n' "$REVIEW_RESULT" | jq -r '.data.node.state')
PR_NUMBER=$(printf '%s\n' "$REVIEW_RESULT" | jq -r '.data.node.pullRequest.number')
if [ "$REVIEW_STATE" = "PENDING" ]; then
  EXPECTED_COMMENT_STATE="PENDING"
elif [ "$REVIEW_STATE" = "COMMENTED" ]; then
  EXPECTED_COMMENT_STATE="SUBMITTED"
else
  echo "Error: Review $REVIEW_ID has unexpected state $REVIEW_STATE." >&2
  exit 1
fi
INVALID_STATE_COUNT=$(printf '%s\n' "$REVIEW_RESULT" | jq \
  --arg state "$EXPECTED_COMMENT_STATE" \
  '[.data.node.comments.nodes[] | select(.state != $state)] | length')
if [ "$INVALID_STATE_COUNT" -ne 0 ]; then
  echo "Error: Review $REVIEW_ID contains replies in an unexpected state." >&2
  exit 1
fi

if [ "$REVIEW_STATE" = "COMMENTED" ]; then
  jq -n \
    --arg review_id "$REVIEW_ID" \
    --argjson pr_number "$PR_NUMBER" \
    --argjson reply_count "$COMMENT_COUNT" \
    '{review_id:$review_id, pr_number:$pr_number, reply_count:$reply_count, submitted:false, reconciled:true}'
  exit 0
fi

SUBMIT_MUTATION='
mutation($reviewId: ID!) {
  submitPullRequestReview(input: {
    pullRequestReviewId: $reviewId
    event: COMMENT
  }) {
    pullRequestReview { id state submittedAt }
  }
}
'

if ! SUBMIT_RESULT=$(graphql -f query="$SUBMIT_MUTATION" -f reviewId="$REVIEW_ID"); then
  echo "Retry this command to reconcile an ambiguous submission result." >&2
  exit 1
fi

SUBMITTED_ID=$(printf '%s\n' "$SUBMIT_RESULT" | jq -r \
  '.data.submitPullRequestReview.pullRequestReview.id')
SUBMITTED_STATE=$(printf '%s\n' "$SUBMIT_RESULT" | jq -r \
  '.data.submitPullRequestReview.pullRequestReview.state')
SUBMITTED_AT=$(printf '%s\n' "$SUBMIT_RESULT" | jq -r \
  '.data.submitPullRequestReview.pullRequestReview.submittedAt')
if [ "$SUBMITTED_ID" != "$REVIEW_ID" ] || [ "$SUBMITTED_STATE" != "COMMENTED" ] || \
   [ -z "$SUBMITTED_AT" ] || [ "$SUBMITTED_AT" = "null" ]; then
  echo "Error: GitHub did not confirm publication of review $REVIEW_ID." >&2
  echo "Retry this command to reconcile the review state." >&2
  exit 1
fi

jq -n \
  --arg review_id "$REVIEW_ID" \
  --argjson pr_number "$PR_NUMBER" \
  --argjson reply_count "$COMMENT_COUNT" \
  '{review_id:$review_id, pr_number:$pr_number, reply_count:$reply_count, submitted:true, reconciled:false}'
