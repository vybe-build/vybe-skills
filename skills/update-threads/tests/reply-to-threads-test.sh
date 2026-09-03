#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/reply-to-threads.sh"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT

mkdir -p "$TEST_TMP/bin"

cat > "$TEST_TMP/bin/gh" <<'MOCK_GH'
#!/usr/bin/env bash
set -euo pipefail

QUERY=""
THREAD_ID=""
REVIEW_ID=""
for argument in "$@"; do
  case "$argument" in
    query=*) QUERY="${argument#query=}" ;;
    threadId=*) THREAD_ID="${argument#threadId=}" ;;
    reviewId=*) REVIEW_ID="${argument#reviewId=}" ;;
  esac
done

case "$QUERY" in
  *'query($threadId: ID!)'*)
    printf 'context %s\n' "$THREAD_ID" >> "$GH_LOG"
    if [ "$GH_SCENARIO" = "existing-pending" ]; then
      PENDING='[{"id":"PRR_existing","author":{"login":"octocat"}}]'
    else
      PENDING='[]'
    fi
    jq -n \
      --arg thread_id "$THREAD_ID" \
      --argjson pending "$PENDING" \
      '{data:{viewer:{login:"octocat"},node:{id:$thread_id,isResolved:false,viewerCanReply:true,viewerCanResolve:true,pullRequest:{id:"PR_1",number:42,url:"https://github.example/pull/42",reviews:{nodes:$pending}}}}}'
    ;;
  *'addPullRequestReview(input:'*)
    echo 'create-review' >> "$GH_LOG"
    echo '{"data":{"addPullRequestReview":{"pullRequestReview":{"id":"PRR_managed","state":"PENDING"}}}}'
    ;;
  *'addPullRequestReviewThreadReply(input:'*)
    printf 'reply %s %s\n' "$THREAD_ID" "$REVIEW_ID" >> "$GH_LOG"
    if [ "$GH_SCENARIO" = "reply-error" ]; then
      echo '{"errors":[{"message":"simulated reply failure"}]}'
    else
      echo '{"data":{"addPullRequestReviewThreadReply":{"comment":{"id":"PRRC_1","state":"PENDING","pullRequestReview":{"id":"PRR_managed","state":"PENDING"}}}}}'
    fi
    ;;
  *'submitPullRequestReview(input:'*)
    printf 'submit %s\n' "$REVIEW_ID" >> "$GH_LOG"
    echo '{"data":{"submitPullRequestReview":{"pullRequestReview":{"id":"PRR_managed","state":"COMMENTED","submittedAt":"2026-09-03T12:00:00Z"}}}}'
    ;;
  *'deletePullRequestReview(input:'*)
    printf 'delete %s\n' "$REVIEW_ID" >> "$GH_LOG"
    echo '{"data":{"deletePullRequestReview":{"pullRequestReview":{"id":"PRR_managed"}}}}'
    ;;
  *)
    echo "Unexpected GraphQL operation" >&2
    exit 99
    ;;
esac
MOCK_GH
chmod +x "$TEST_TMP/bin/gh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_line() {
  local expected="$1"
  local actual="$2"
  [ "$actual" = "$expected" ] || fail "expected '$expected', got '$actual'"
}

line_at() {
  sed -n "${1}p" "$2"
}

run_success_test() {
  local log="$TEST_TMP/success.log"
  local output="$TEST_TMP/success.out"
  : > "$log"

  GH_LOG="$log" GH_SCENARIO="success" PATH="$TEST_TMP/bin:$PATH" \
    "$SCRIPT" THREAD_1 "first reply" THREAD_2 "second reply" > "$output"

  line_count=$(wc -l < "$log" | tr -d ' ')
  [ "$line_count" -eq 6 ] || fail "success path made $line_count operations"
  assert_line "context THREAD_1" "$(line_at 1 "$log")"
  assert_line "context THREAD_2" "$(line_at 2 "$log")"
  assert_line "create-review" "$(line_at 3 "$log")"
  assert_line "reply THREAD_1 PRR_managed" "$(line_at 4 "$log")"
  assert_line "reply THREAD_2 PRR_managed" "$(line_at 5 "$log")"
  assert_line "submit PRR_managed" "$(line_at 6 "$log")"
  grep -q 'Published 2 replies' "$output" || fail "success summary is missing"
}

run_existing_pending_test() {
  local log="$TEST_TMP/existing-pending.log"
  local output="$TEST_TMP/existing-pending.out"
  : > "$log"

  if GH_LOG="$log" GH_SCENARIO="existing-pending" PATH="$TEST_TMP/bin:$PATH" \
    "$SCRIPT" THREAD_1 "reply" > "$output" 2>&1; then
    fail "existing pending review should fail"
  fi

  line_count=$(wc -l < "$log" | tr -d ' ')
  [ "$line_count" -eq 1 ] || fail "existing pending review performed a write"
  assert_line "context THREAD_1" "$(line_at 1 "$log")"
  grep -q 'No replies were posted' "$output" || fail "pending review guidance is missing"
}

run_cleanup_test() {
  local log="$TEST_TMP/cleanup.log"
  local output="$TEST_TMP/cleanup.out"
  : > "$log"

  if GH_LOG="$log" GH_SCENARIO="reply-error" PATH="$TEST_TMP/bin:$PATH" \
    "$SCRIPT" THREAD_1 "reply" > "$output" 2>&1; then
    fail "reply failure should fail"
  fi

  line_count=$(wc -l < "$log" | tr -d ' ')
  [ "$line_count" -eq 4 ] || fail "cleanup path made $line_count operations"
  assert_line "context THREAD_1" "$(line_at 1 "$log")"
  assert_line "create-review" "$(line_at 2 "$log")"
  assert_line "reply THREAD_1 PRR_managed" "$(line_at 3 "$log")"
  assert_line "delete PRR_managed" "$(line_at 4 "$log")"
  grep -q 'Discarded temporary pending review' "$output" || fail "cleanup confirmation is missing"
}

run_success_test
run_existing_pending_test
run_cleanup_test
echo "reply-to-threads tests passed"
