#!/usr/bin/env bash
set -euo pipefail

# Fetch unresolved PR review comment threads for the current branch.
# Requires: gh CLI (authenticated with repo access), jq, and awk.
# Output: JSON object with PR metadata and a "threads" array of unresolved
#         review threads with all comments in each thread.

if ! PR_NUMBER=$(gh pr view --json number --jq '.number'); then
  echo "Error: No PR found for the current branch." >&2
  exit 1
fi

if ! REPO_INFO=$(gh repo view --json owner,name --jq '.owner.login + " " + .name'); then
  echo "Error: Could not determine repository owner/name. Ensure 'gh' is authenticated and you are inside a GitHub repository." >&2
  exit 1
fi
OWNER=$(echo "$REPO_INFO" | awk '{print $1}')
REPO=$(echo "$REPO_INFO" | awk '{print $2}')

QUERY='
query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      title
      url
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          startLine
          originalStartLine
          diffSide
          comments(first: 50) {
            nodes {
              author { login }
              body
              createdAt
              commit { abbreviatedOid oid }
              originalCommit { abbreviatedOid oid }
              path
              outdated
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
PR_TITLE=""
PR_URL=""

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
    echo "Error: GraphQL API request failed. Check network connectivity and GitHub authentication." >&2
    exit 1
  fi

  if echo "$RESULT" | jq -e '.errors' > /dev/null 2>&1; then
    echo "Error: GraphQL API returned errors:" >&2
    echo "$RESULT" | jq -r '.errors[].message' >&2
    exit 1
  fi

  PAGE_THREADS=$(echo "$RESULT" | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]')
  ALL_THREADS=$(echo "$ALL_THREADS $PAGE_THREADS" | jq -s '.[0] + .[1]')

  HAS_NEXT=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  CURSOR=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
done

PR_TITLE=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.title')
PR_URL=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.url')
TOTAL=$(echo "$ALL_THREADS" | jq 'length')

jq -n \
  --arg title "$PR_TITLE" \
  --arg url "$PR_URL" \
  --argjson pr "$PR_NUMBER" \
  --argjson total "$TOTAL" \
  --argjson threads "$ALL_THREADS" \
  '{
    pr_number: $pr,
    pr_title: $title,
    pr_url: $url,
    unresolved_thread_count: $total,
    threads: [
      $threads[] | {
        thread_id: .id,
        file: .path,
        line: (.line // .originalLine),
        start_line: (.startLine // .originalStartLine),
        is_outdated: .isOutdated,
        diff_side: .diffSide,
        comments: [
          .comments.nodes[] | {
            author: (.author.login // "ghost"),
            body: .body,
            created_at: .createdAt,
            commit: .commit.abbreviatedOid,
            commit_full: .commit.oid,
            original_commit: .originalCommit.abbreviatedOid,
            file: .path,
            outdated: .outdated
          }
        ]
      }
    ]
  }'
