#!/usr/bin/env bash
set -euo pipefail

# Post review comments (line-level and file-level) on a pull request.
# Validates line-level comments against the diff; demotes invalid ones to file-level.
#
# Usage: post-review-comments.sh <pr_number> <comments_json_file>
#
# Input JSON format (array of comments):
# [
#   { "type": "line", "path": "src/foo.ts", "line": 42, "side": "RIGHT", "body": "..." },
#   { "type": "file", "path": "src/bar.ts", "body": "Higher-level concern..." }
# ]
#
# Output JSON: { "line_posted": N, "file_posted": N, "skipped": N, "skipped_details": [...] }
#
# Requires: gh CLI (authenticated with repo access), jq, awk.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -lt 2 ]; then
  echo "Usage: post-review-comments.sh <pr_number> <comments_json_file>" >&2
  exit 1
fi

PR_NUMBER="$1"
COMMENTS_FILE="$2"

if [ ! -f "$COMMENTS_FILE" ]; then
  echo "Error: Comments file not found: $COMMENTS_FILE" >&2
  exit 1
fi

COMMENT_COUNT=$(jq 'length' "$COMMENTS_FILE")
if [ "$COMMENT_COUNT" -eq 0 ]; then
  jq -n '{ line_posted: 0, file_posted: 0, skipped: 0, skipped_details: [] }'
  exit 0
fi

# --- Gather PR metadata ---

if ! REPO_INFO=$(gh repo view --json owner,name --jq '.owner.login + " " + .name'); then
  echo "Error: Could not determine repository owner/name." >&2
  exit 1
fi
OWNER=$(echo "$REPO_INFO" | awk '{print $1}')
REPO=$(echo "$REPO_INFO" | awk '{print $2}')

if ! HEAD_SHA=$(gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid'); then
  echo "Error: Could not get HEAD SHA for PR #$PR_NUMBER." >&2
  exit 1
fi

# --- Parse diff to extract valid (path, line, side) tuples ---

DIFF_LINES_FILE=$(mktemp)
trap 'rm -f "$DIFF_LINES_FILE" "${TMPFILES[@]:-}" 2>/dev/null' EXIT
TMPFILES=()

gh pr diff "$PR_NUMBER" | awk '
  /^diff --git/ { next }
  /^Binary files/ { next }
  /^---/ { next }
  /^\+\+\+ b\// {
    # Extract file path from the unambiguous +++ line
    file = substr($0, 7)
    next
  }
  /^\+\+\+/ { next }
  /^@@/ {
    # Parse @@ -old_start[,old_count] +new_start[,new_count] @@
    old_start = 0; new_start = 0
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^-[0-9]/) {
        split(substr($i, 2), parts, ",")
        old_start = parts[1] + 0
      }
      if ($i ~ /^\+[0-9]/) {
        split(substr($i, 2), parts, ",")
        new_start = parts[1] + 0
      }
    }
    old_line = old_start
    new_line = new_start
    in_hunk = 1
    next
  }
  in_hunk && /^\+/ {
    printf "%s\t%d\tRIGHT\n", file, new_line
    new_line++
    next
  }
  in_hunk && /^-/ {
    printf "%s\t%d\tLEFT\n", file, old_line
    old_line++
    next
  }
  in_hunk && /^ / {
    # Context lines are valid on both sides
    printf "%s\t%d\tRIGHT\n", file, new_line
    printf "%s\t%d\tLEFT\n", file, old_line
    new_line++
    old_line++
    next
  }
  in_hunk && !/^[+ -]/ && !/^\\/ {
    in_hunk = 0
  }
' > "$DIFF_LINES_FILE"

# Extract set of files in the diff
DIFF_FILES_FILE=$(mktemp)
TMPFILES+=("$DIFF_FILES_FILE")
awk -F'\t' '{ print $1 }' "$DIFF_LINES_FILE" | sort -u > "$DIFF_FILES_FILE"

# --- Classify and validate comments ---

LINE_COMMENTS_FILE=$(mktemp)
FILE_COMMENTS_FILE=$(mktemp)
SKIPPED_FILE=$(mktemp)
TMPFILES+=("$LINE_COMMENTS_FILE" "$FILE_COMMENTS_FILE" "$SKIPPED_FILE")

echo "[]" > "$LINE_COMMENTS_FILE"
echo "[]" > "$FILE_COMMENTS_FILE"
echo "[]" > "$SKIPPED_FILE"

# Process each comment
jq -c '.[]' "$COMMENTS_FILE" | while IFS= read -r comment; do
  TYPE=$(echo "$comment" | jq -r '.type // "line"')
  PATH_VAL=$(echo "$comment" | jq -r '.path')
  LINE_VAL=$(echo "$comment" | jq -r '.line // empty')
  SIDE_VAL=$(echo "$comment" | jq -r '.side // "RIGHT"')

  # Check if file is in the diff at all
  if ! grep -qxF "$PATH_VAL" "$DIFF_FILES_FILE"; then
    # File not in diff — skip entirely
    CURRENT=$(cat "$SKIPPED_FILE")
    echo "$CURRENT" | jq --argjson c "$comment" --arg reason "file not in diff" \
      '. + [($c + {reason: $reason})]' > "$SKIPPED_FILE"
    continue
  fi

  if [ "$TYPE" = "file" ] || [ -z "$LINE_VAL" ]; then
    # Explicitly file-level or no line number
    CURRENT=$(cat "$FILE_COMMENTS_FILE")
    echo "$CURRENT" | jq --argjson c "$comment" '. + [$c]' > "$FILE_COMMENTS_FILE"
    continue
  fi

  # Validate line-level comment against diff
  if awk -F'\t' -v p="$PATH_VAL" -v l="$LINE_VAL" -v s="$SIDE_VAL" \
       '$1 == p && $2+0 == l+0 && $3 == s { found=1; exit } END { exit !found }' "$DIFF_LINES_FILE"; then
    # Valid line in diff
    CURRENT=$(cat "$LINE_COMMENTS_FILE")
    echo "$CURRENT" | jq --argjson c "$comment" --arg side "$SIDE_VAL" \
      '. + [($c + {side: $side})]' > "$LINE_COMMENTS_FILE"
  else
    # Line not in diff — demote to file-level
    echo "Warning: Line $LINE_VAL ($SIDE_VAL) of $PATH_VAL not in diff, demoting to file-level comment" >&2
    CURRENT=$(cat "$FILE_COMMENTS_FILE")
    echo "$CURRENT" | jq --argjson c "$comment" '. + [$c]' > "$FILE_COMMENTS_FILE"
  fi
done

LINE_COUNT=$(jq 'length' "$LINE_COMMENTS_FILE")
FILE_COUNT=$(jq 'length' "$FILE_COMMENTS_FILE")
SKIP_COUNT=$(jq 'length' "$SKIPPED_FILE")

LINE_POSTED=0
FILE_POSTED=0

# --- Post line-level comments as batched review(s) ---

if [ "$LINE_COUNT" -gt 0 ]; then
  BATCH_SIZE=30
  OFFSET=0

  while [ "$OFFSET" -lt "$LINE_COUNT" ]; do
    BATCH=$(jq --argjson off "$OFFSET" --argjson sz "$BATCH_SIZE" \
      '.[$off:$off+$sz] | [.[] | {path, line: (.line | tonumber), side: (.side // "RIGHT"), body}]' \
      "$LINE_COMMENTS_FILE")

    PAYLOAD_FILE=$(mktemp)
    TMPFILES+=("$PAYLOAD_FILE")

    jq -n \
      --arg commit_id "$HEAD_SHA" \
      --arg event "COMMENT" \
      --argjson comments "$BATCH" \
      '{ commit_id: $commit_id, body: "", event: $event, comments: $comments }' > "$PAYLOAD_FILE"

    if RESULT=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" \
      --method POST \
      --input "$PAYLOAD_FILE" 2>&1); then
      BATCH_COUNT=$(echo "$BATCH" | jq 'length')
      LINE_POSTED=$((LINE_POSTED + BATCH_COUNT))
    else
      echo "Error: Failed to post line-level review batch (offset $OFFSET): $RESULT" >&2
      # Demote this batch to file-level as fallback
      CURRENT=$(cat "$FILE_COMMENTS_FILE")
      echo "$CURRENT" | jq --argjson batch "$BATCH" '. + $batch' > "$FILE_COMMENTS_FILE"
      FILE_COUNT=$(jq 'length' "$FILE_COMMENTS_FILE")
    fi

    OFFSET=$((OFFSET + BATCH_SIZE))
  done
fi

# --- Post file-level comments individually ---

FILE_COUNT=$(jq 'length' "$FILE_COMMENTS_FILE")
FILE_POSTED_FILE=$(mktemp)
TMPFILES+=("$FILE_POSTED_FILE")
echo "0" > "$FILE_POSTED_FILE"

if [ "$FILE_COUNT" -gt 0 ]; then
  jq -c '.[]' "$FILE_COMMENTS_FILE" | while IFS= read -r comment; do
    FILE_PATH=$(echo "$comment" | jq -r '.path')
    FILE_BODY=$(echo "$comment" | jq -r '.body')

    if bash "$SCRIPT_DIR/post-file-comment.sh" "$PR_NUMBER" "$FILE_PATH" "$HEAD_SHA" "$FILE_BODY" 2>&1; then
      COUNT=$(cat "$FILE_POSTED_FILE")
      echo $((COUNT + 1)) > "$FILE_POSTED_FILE"
    else
      echo "Warning: Failed to post file-level comment on $FILE_PATH, adding to skipped" >&2
      CURRENT=$(cat "$SKIPPED_FILE")
      echo "$CURRENT" | jq --argjson c "$comment" --arg reason "file comment API failed" \
        '. + [($c + {reason: $reason})]' > "$SKIPPED_FILE"
    fi
  done
fi

FILE_POSTED=$(cat "$FILE_POSTED_FILE")

# Recount skipped after potential fallback additions
SKIP_COUNT=$(jq 'length' "$SKIPPED_FILE")
SKIPPED_DETAILS=$(cat "$SKIPPED_FILE")

jq -n \
  --argjson line_posted "$LINE_POSTED" \
  --argjson file_posted "$FILE_POSTED" \
  --argjson skipped "$SKIP_COUNT" \
  --argjson skipped_details "$SKIPPED_DETAILS" \
  '{
    line_posted: $line_posted,
    file_posted: $file_posted,
    skipped: $skipped,
    skipped_details: $skipped_details
  }'
