#!/usr/bin/env bash
set -euo pipefail

# Explicitly discard an update-threads managed pending review.
# Usage: discard-review.sh <review_id>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=review-lib.sh
source "$SCRIPT_DIR/review-lib.sh"

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "Usage: discard-review.sh <review_id>" >&2
  exit 2
fi
REVIEW_ID="$1"
require_review_tools

QUERY='
query($reviewId: ID!) {
  node(id: $reviewId) {
    ... on PullRequestReview { id state body }
  }
}
'
if ! RESULT=$(graphql -f query="$QUERY" -f reviewId="$REVIEW_ID"); then
  exit 1
fi
if [ "$(printf '%s\n' "$RESULT" | jq -r '.data.node.body')" != \
     "$MANAGED_REVIEW_MARKER" ]; then
  echo "Error: Review $REVIEW_ID was not created by update-threads." >&2
  exit 1
fi
if [ "$(printf '%s\n' "$RESULT" | jq -r '.data.node.state')" != "PENDING" ]; then
  echo "Error: Review $REVIEW_ID is not pending and cannot be discarded." >&2
  exit 1
fi

MUTATION='
mutation($reviewId: ID!) {
  deletePullRequestReview(input: { pullRequestReviewId: $reviewId }) {
    pullRequestReview { id }
  }
}
'
if ! DELETE_RESULT=$(graphql -f query="$MUTATION" -f reviewId="$REVIEW_ID"); then
  exit 1
fi
if [ "$(printf '%s\n' "$DELETE_RESULT" | jq -r \
  '.data.deletePullRequestReview.pullRequestReview.id')" != "$REVIEW_ID" ]; then
  echo "Error: GitHub did not confirm deletion of review $REVIEW_ID." >&2
  exit 1
fi

jq -n --arg review_id "$REVIEW_ID" '{review_id:$review_id, discarded:true}'
