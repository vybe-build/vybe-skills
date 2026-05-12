#!/usr/bin/env bash
# Fails if a skill folder changed without bumping its SKILL.md version.
# Usage: scripts/check-version-bump.sh [base-ref]
# Default base-ref: origin/main

set -euo pipefail

base_ref="${1:-origin/main}"

mapfile -t changed < <(git diff --name-only "$base_ref"...HEAD -- 'skills/' 2>/dev/null || true)

if [[ ${#changed[@]} -eq 0 ]]; then
  echo "No skill changes detected."
  exit 0
fi

declare -A touched=()
for f in "${changed[@]}"; do
  [[ "$f" =~ ^skills/([^/]+)/ ]] || continue
  touched["${BASH_REMATCH[1]}"]=1
done

read_version() {
  local content="$1"
  awk '
    /^---$/ { c++; next }
    c == 1 && /^version:/ { sub(/^version:[[:space:]]*/, ""); print; exit }
    c >= 2 { exit }
  ' <<<"$content"
}

failed=0
for skill in "${!touched[@]}"; do
  skill_md="skills/$skill/SKILL.md"

  if [[ ! -f "$skill_md" ]]; then
    continue
  fi

  current_version=$(read_version "$(cat "$skill_md")")
  if [[ -z "$current_version" ]]; then
    echo "::error file=$skill_md::missing 'version' field in frontmatter"
    failed=1
    continue
  fi

  if ! base_content=$(git show "$base_ref:$skill_md" 2>/dev/null); then
    echo "ok: $skill (new skill at v$current_version)"
    continue
  fi

  base_version=$(read_version "$base_content")
  if [[ -z "$base_version" ]]; then
    echo "ok: $skill (no prior version, now v$current_version)"
    continue
  fi

  if [[ "$base_version" == "$current_version" ]]; then
    echo "::error file=$skill_md::skill changed but version did not bump (still $current_version) — update the 'version' field"
    failed=1
  else
    echo "ok: $skill v$base_version -> v$current_version"
  fi
done

exit "$failed"
