#!/usr/bin/env bash
set -euo pipefail

# Fetch all PR review threads (resolved and unresolved) for a given PR number.
# Outputs a JSON array suitable for injecting into agent prompts so they
# can avoid re-raising previously discussed issues and leverage existing
# context from ongoing discussions.
#
# Usage: fetch-review-threads.sh <pr_number>
# Output: JSON array of threads with file, line, resolution status, and full comments.

if [ $# -lt 1 ]; then
  echo "Usage: fetch-review-threads.sh <pr_number>" >&2
  exit 1
fi

PR_NUMBER="$1"

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Error: PR number must be a positive integer, got '$PR_NUMBER'" >&2
  exit 1
fi

if ! REPO_INFO=$(gh repo view --json owner,name --jq '.owner.login + " " + .name'); then
  echo "Error: Could not determine repository owner/name." >&2
  exit 1
fi
OWNER=$(echo "$REPO_INFO" | awk '{print $1}')
REPO=$(echo "$REPO_INFO" | awk '{print $2}')

QUERY='
query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved
          isOutdated
          path
          line
          originalLine
          comments(first: 50) {
            nodes {
              author { login }
              body
            }
          }
        }
      }
    }
  }
}
'

ALL_THREADS="[]"
CURSOR="null"
HAS_NEXT="true"
MAX_PAGES=50
PAGE_COUNT=0

while [ "$HAS_NEXT" = "true" ] && [ "$PAGE_COUNT" -lt "$MAX_PAGES" ]; do
  PAGE_COUNT=$((PAGE_COUNT + 1))
  CURSOR_ARGS=()
  if [ "$CURSOR" != "null" ]; then
    CURSOR_ARGS=(-f cursor="$CURSOR")
  fi

  if ! RESULT=$(gh api graphql \
    -f query="$QUERY" \
    -f owner="$OWNER" \
    -f repo="$REPO" \
    -F pr="$PR_NUMBER" \
    ${CURSOR_ARGS[@]+"${CURSOR_ARGS[@]}"}); then
    echo "Error: GraphQL API request failed." >&2
    exit 1
  fi

  if echo "$RESULT" | jq -e 'has("errors") and (.errors | length > 0)' > /dev/null 2>&1; then
    echo "Error: GraphQL API returned errors:" >&2
    echo "$RESULT" | jq -r '.errors[].message' >&2
    exit 1
  fi

  if echo "$RESULT" | jq -e '.data.repository.pullRequest == null' > /dev/null 2>&1; then
    echo "Error: PR #$PR_NUMBER not found or not accessible." >&2
    exit 1
  fi

  PAGE_THREADS=$(echo "$RESULT" | jq '.data.repository.pullRequest.reviewThreads.nodes // []')
  ALL_THREADS=$(echo "$ALL_THREADS $PAGE_THREADS" | jq -s '.[0] + .[1]')

  HAS_NEXT=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  CURSOR=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
done

if [ "$HAS_NEXT" = "true" ]; then
  echo "Warning: Pagination limit reached ($MAX_PAGES pages). Results may be incomplete." >&2
fi

# Output: file, line, resolution status, and full comment thread
jq -n --argjson threads "$ALL_THREADS" '[
  $threads[] | {
    file: .path,
    line: (.line // .originalLine),
    resolved: .isResolved,
    outdated: .isOutdated,
    comments: [.comments.nodes[] | {
      author: (.author.login // "ghost"),
      body: .body
    }]
  }
]'
