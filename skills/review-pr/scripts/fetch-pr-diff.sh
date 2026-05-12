#!/usr/bin/env bash
set -euo pipefail

# Fetch the full diff for a PR and write it to a file.
# Usage: fetch-pr-diff.sh <pr_number> <output_file>
#
# Writes the diff to <output_file> and prints the line count to stdout.
# Requires: gh CLI (authenticated with repo access).

if [ "$#" -lt 2 ]; then
  echo "Usage: fetch-pr-diff.sh <pr_number> <output_file>" >&2
  exit 1
fi

PR_NUMBER="$1"
OUTPUT_FILE="$2"

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Error: PR number must be a positive integer, got '$PR_NUMBER'" >&2
  exit 1
fi

OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR"

TMP_FILE=$(mktemp "$OUTPUT_DIR/.tmp.fetch-pr-diff.XXXXXX")
trap 'rm -f "$TMP_FILE"' EXIT

if ! gh pr diff "$PR_NUMBER" > "$TMP_FILE"; then
  echo "Error: Failed to fetch diff for PR #$PR_NUMBER." >&2
  exit 1
fi

mv "$TMP_FILE" "$OUTPUT_FILE"

LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
echo "Wrote $LINE_COUNT lines to $OUTPUT_FILE"
