# vybe-skills

Shared agent skills for Vybe engineers. Distributed via `skillshare` to each dev's local agent dirs (Claude Code, Codex, opencode, etc).

## Layout

```
skills/
  <skill-name>/
    SKILL.md         # required — frontmatter + body
    scripts/         # optional — helper scripts the skill invokes
    references/      # optional — reference material the skill reads
```

## Skill format

Each `SKILL.md` starts with YAML frontmatter:

```markdown
---
name: graphite
version: 1.2.0
description: One-line description used to decide when the skill applies.
allowed-tools: Bash(gh pr view:*), Read   # optional — Claude Code only
---

# Skill body
...
```

Required fields: `name`, `version`, `description`. `name` must match the directory.

## Versioning

Semver per skill, declared in `SKILL.md` frontmatter. `main` is the source of truth — no tags, no releases.

**Rules:**

- Bump `version` in the same PR as any change to that skill's folder.
- `MAJOR` for breaking changes (renamed/removed behaviors, different invocation contract).
- `MINOR` for new behavior that's backward compatible.
- `PATCH` for wording fixes, prompt tweaks, bug fixes.

CI (`.github/workflows/version-bump.yml`) fails if a skill folder changes without its `version` bumping. New skills and deletions are exempt.

## Consuming

Devs install via `skillshare`:

```bash
skillshare upgrade          # pull latest main, sync any skills with bumped versions
skillshare pin <name>@X.Y.Z # freeze a skill at a specific version
skillshare list             # show installed skills and versions
```

`skillshare` reads each `SKILL.md` from `main`, diffs against local state, and writes per-agent files (`~/.claude/skills/<name>/`, etc).

### Browsing via the hub index

This repo ships a [`skillshare-hub.json`](./skillshare-hub.json) catalog so devs can search and install skills without cloning the repo. Point `skillshare search` at the file (locally or via raw URL):

```bash
skillshare search --hub ./skillshare-hub.json            # browse everything
skillshare search graphite --hub ./skillshare-hub.json   # filter by keyword
```

See [the skillshare hub-index docs](https://skillshare.runkids.cc/docs/how-to/sharing/hub-index) for more.

### Regenerating the hub index

Regenerate `skillshare-hub.json` after adding, renaming, or removing a skill, or after editing a skill's `description`:

```bash
skillshare hub index -s ./
```

Commit the updated `skillshare-hub.json` alongside the skill changes.

## Adding a new skill

1. Create `skills/<name>/SKILL.md` with `version: 0.1.0` (or `1.0.0` if it's mature).
2. Reference scripts via relative paths (`scripts/foo.sh`) — they ship alongside the skill.
3. Open a PR. New skills don't need a version bump.

## Updating a skill

1. Edit the skill.
2. Bump `version` in its `SKILL.md`.
3. Open a PR. CI will reject the PR if the version didn't bump.
