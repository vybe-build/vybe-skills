#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$TEST_DIR/../scripts"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
mkdir -p "$TEST_TMP/bin"

cat > "$TEST_TMP/bin/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -euo pipefail

QUERY=""
THREAD_ID=""
REVIEW_ID=""
BODY=""
for argument in "$@"; do
  case "$argument" in
    query=*) QUERY="${argument#query=}" ;;
    threadId=*) THREAD_ID="${argument#threadId=}" ;;
    reviewId=*) REVIEW_ID="${argument#reviewId=}" ;;
    body=*) BODY="${argument#body=}" ;;
  esac
done

printf '%s\n' "$GH_SCENARIO" >> "$GH_LOG"

case "$GH_SCENARIO:$QUERY" in
  create-new:*'query($threadId: ID!)'*)
    echo '{"data":{"viewer":{"login":"octocat"},"node":{"id":"THREAD_1","pullRequest":{"id":"PR_1","number":42,"url":"https://github.example/pull/42","reviews":{"nodes":[]}}}}}'
    ;;
  create-new:*'addPullRequestReview(input:'*)
    [ "$BODY" = '<!-- update-threads-managed-review -->' ] || exit 90
    echo '{"data":{"addPullRequestReview":{"pullRequestReview":{"id":"PRR_managed","state":"PENDING"}}}}'
    ;;
  create-resume:*'query($threadId: ID!)'*)
    echo '{"data":{"viewer":{"login":"octocat"},"node":{"id":"THREAD_1","pullRequest":{"id":"PR_1","number":42,"url":"https://github.example/pull/42","reviews":{"nodes":[{"id":"PRR_managed","body":"<!-- update-threads-managed-review -->","author":{"login":"octocat"},"comments":{"totalCount":3}}]}}}}}'
    ;;
  reply-new:*'query($reviewId: ID!, $threadId: ID!)'*)
    echo '{"data":{"review":{"id":"PRR_managed","state":"PENDING","body":"<!-- update-threads-managed-review -->","pullRequest":{"id":"PR_1","number":42}},"thread":{"id":"THREAD_1","isResolved":false,"viewerCanReply":true,"pullRequest":{"id":"PR_1"},"comments":{"pageInfo":{"hasNextPage":false},"nodes":[]}}}}'
    ;;
  reply-new:*'addPullRequestReviewThreadReply(input:'*)
    case "$BODY" in
      *'<!-- update-threads:PRR_managed:THREAD_1 -->') ;;
      *) exit 91 ;;
    esac
    echo '{"data":{"addPullRequestReviewThreadReply":{"comment":{"id":"PRRC_1","state":"PENDING","pullRequestReview":{"id":"PRR_managed"}}}}}'
    ;;
  reply-failure:*'query($reviewId: ID!, $threadId: ID!)'*)
    echo '{"data":{"review":{"id":"PRR_managed","state":"PENDING","body":"<!-- update-threads-managed-review -->","pullRequest":{"id":"PR_1","number":42}},"thread":{"id":"THREAD_1","isResolved":false,"viewerCanReply":true,"pullRequest":{"id":"PR_1"},"comments":{"pageInfo":{"hasNextPage":false},"nodes":[]}}}}'
    ;;
  reply-failure:*'addPullRequestReviewThreadReply(input:'*)
    echo '{"errors":[{"message":"simulated reply failure"}]}'
    ;;
  reply-reconcile:*'query($reviewId: ID!, $threadId: ID!)'*)
    echo '{"data":{"review":{"id":"PRR_managed","state":"PENDING","body":"<!-- update-threads-managed-review -->","pullRequest":{"id":"PR_1","number":42}},"thread":{"id":"THREAD_1","isResolved":false,"viewerCanReply":true,"pullRequest":{"id":"PR_1"},"comments":{"pageInfo":{"hasNextPage":false},"nodes":[{"id":"PRRC_1","body":"reply\n\n<!-- update-threads:PRR_managed:THREAD_1 -->","pullRequestReview":{"id":"PRR_managed"}}]}}}}'
    ;;
  submit-complete:*'query($reviewId: ID!)'*)
    echo '{"data":{"node":{"id":"PRR_managed","state":"PENDING","submittedAt":null,"body":"<!-- update-threads-managed-review -->","pullRequest":{"number":42,"url":"https://github.example/pull/42"},"comments":{"pageInfo":{"hasNextPage":false},"nodes":[{"id":"PRRC_1","state":"PENDING","body":"one\n\n<!-- update-threads:PRR_managed:THREAD_1 -->"},{"id":"PRRC_2","state":"PENDING","body":"two\n\n<!-- update-threads:PRR_managed:THREAD_2 -->"}]}}}}'
    ;;
  submit-complete:*'submitPullRequestReview(input:'*)
    echo '{"data":{"submitPullRequestReview":{"pullRequestReview":{"id":"PRR_managed","state":"COMMENTED","submittedAt":"2026-09-03T12:00:00Z"}}}}'
    ;;
  submit-incomplete:*'query($reviewId: ID!)'*)
    echo '{"data":{"node":{"id":"PRR_managed","state":"PENDING","submittedAt":null,"body":"<!-- update-threads-managed-review -->","pullRequest":{"number":42,"url":"https://github.example/pull/42"},"comments":{"pageInfo":{"hasNextPage":false},"nodes":[{"id":"PRRC_1","state":"PENDING","body":"one\n\n<!-- update-threads:PRR_managed:THREAD_1 -->"}]}}}}'
    ;;
  *)
    echo "Unexpected mock operation for $GH_SCENARIO" >&2
    exit 99
    ;;
esac
MOCK_GH
chmod +x "$TEST_TMP/bin/gh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run_script() {
  local scenario="$1"
  shift
  GH_SCENARIO="$scenario" GH_LOG="$TEST_TMP/operations.log" \
    PATH="$TEST_TMP/bin:$PATH" "$@"
}

: > "$TEST_TMP/operations.log"

CREATE_OUTPUT=$(run_script create-new "$SCRIPTS/create-review.sh" THREAD_1)
[ "$(printf '%s\n' "$CREATE_OUTPUT" | jq -r '.review_id')" = "PRR_managed" ] || \
  fail "create did not return the managed review"
[ "$(printf '%s\n' "$CREATE_OUTPUT" | jq -r '.resumed')" = "false" ] || \
  fail "new review was reported as resumed"

RESUME_OUTPUT=$(run_script create-resume "$SCRIPTS/create-review.sh" THREAD_1)
[ "$(printf '%s\n' "$RESUME_OUTPUT" | jq -r '.resumed')" = "true" ] || \
  fail "managed pending review was not resumed"
[ "$(printf '%s\n' "$RESUME_OUTPUT" | jq -r '.existing_reply_count')" -eq 3 ] || \
  fail "resume did not report existing replies"

REPLY_OUTPUT=$(run_script reply-new \
  "$SCRIPTS/reply-to-thread.sh" PRR_managed THREAD_1 "reply")
[ "$(printf '%s\n' "$REPLY_OUTPUT" | jq -r '.posted')" = "true" ] || \
  fail "new reply was not posted"

RECONCILE_OUTPUT=$(run_script reply-reconcile \
  "$SCRIPTS/reply-to-thread.sh" PRR_managed THREAD_1 "reply")
[ "$(printf '%s\n' "$RECONCILE_OUTPUT" | jq -r '.reconciled')" = "true" ] || \
  fail "existing reply was not reconciled"

BEFORE_FAILURE_CALLS=$(wc -l < "$TEST_TMP/operations.log" | tr -d ' ')
if run_script reply-failure \
  "$SCRIPTS/reply-to-thread.sh" PRR_managed THREAD_1 "reply" \
  > "$TEST_TMP/reply-failure.out" 2>&1; then
  fail "reply API failure should fail"
fi
AFTER_FAILURE_CALLS=$(wc -l < "$TEST_TMP/operations.log" | tr -d ' ')
[ $((AFTER_FAILURE_CALLS - BEFORE_FAILURE_CALLS)) -eq 2 ] || \
  fail "reply failure performed unexpected cleanup or submission operations"

SUBMIT_OUTPUT=$(run_script submit-complete \
  "$SCRIPTS/submit-review.sh" PRR_managed THREAD_1 THREAD_2)
[ "$(printf '%s\n' "$SUBMIT_OUTPUT" | jq -r '.submitted')" = "true" ] || \
  fail "complete review was not submitted"

if run_script submit-incomplete \
  "$SCRIPTS/submit-review.sh" PRR_managed THREAD_1 THREAD_2 \
  > "$TEST_TMP/incomplete.out" 2>&1; then
  fail "incomplete review should not be submitted"
fi
grep -q 'has 1 replies; expected 2' "$TEST_TMP/incomplete.out" || \
  fail "incomplete review error was not actionable"

echo "review lifecycle tests passed"
