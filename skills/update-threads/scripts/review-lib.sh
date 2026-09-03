#!/usr/bin/env bash

MANAGED_REVIEW_MARKER='<!-- update-threads-managed-review -->'

require_review_tools() {
  local required_command
  for required_command in gh jq; do
    if ! command -v "$required_command" > /dev/null 2>&1; then
      echo "Error: Required command '$required_command' was not found." >&2
      return 2
    fi
  done
}

graphql() {
  local result

  if ! result=$(gh api graphql "$@"); then
    echo "Error: GitHub GraphQL request failed. Check network and authentication." >&2
    return 1
  fi

  if printf '%s\n' "$result" | jq -e \
    'has("errors") and (.errors | length > 0)' > /dev/null 2>&1; then
    echo "Error: GitHub GraphQL request returned errors:" >&2
    printf '%s\n' "$result" | jq -r '.errors[].message' >&2
    return 1
  fi

  printf '%s\n' "$result"
}

reply_marker() {
  printf '<!-- update-threads:%s:%s -->' "$1" "$2"
}
