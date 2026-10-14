---
name: wait-for-reviews
version: 2.0.0
description: Wait until a PR's CI checks and automated reviews have finished, using the repo's own documented signal for when a review is done, up to a timeout. Use when the user says "wait for CI", "wait for reviews", "wait until checks pass", "block until the PR is reviewed", or wants to pause before the next round of work on a PR. Handles only the waiting — compose with fix/review skills for what comes next.
allowed-tools: Bash(bash *.claude/skills/wait-for-reviews/scripts/*), Bash(gh pr view *), Bash(gh repo view *)
---

# Wait for Reviews

Block until every CI check on a PR has finished (pass or fail) and the repo's
automated reviewers are done, or until a timeout (default 30 minutes).

This skill **only waits** — it does not fix, reply, or push. No reviewers are
built in.

## Review signals

The script waits on CI plus whichever of these it is given, one per reviewer:

| Flag | Done when |
|------|-----------|
| `--reaction-on '<regex>'` | The latest PR comment matching the regex has a 👍 (`--reaction <name>` for another reaction). No matching comment counts as done. |
| `--review-by <login>` | That account has reviewed the PR's current head commit. |

With no flags it waits on CI only, which also covers reviewers that report
through a check.

## Workflow

1. If the PR looks like it belongs to a different workstream than this
   conversation, flag it to the user before blocking.

2. Find how this repo's reviewers signal they are done, stopping at the first
   source that states it:
   1. This conversation (the user said so, or an earlier run established it).
   2. Loaded instructions and memory (`CLAUDE.md`, `AGENTS.md`, etc.).
   3. Repo docs: `CONTRIBUTING.md`, `README.md`, the `.github/` PR template,
      `docs/`.

   Knowing how reviews are *requested* is not enough — do not assume a
   reviewer reacts to its trigger, and do not infer a signal from past PR
   activity or installed apps.

3. If it is missing or ambiguous, ask the user before waiting (CI only is a
   valid answer), then offer to save the answer to memory or the repo's agent
   instructions. If a signal fits neither flag, say so and wait on the rest.

4. Run the script with `run_in_background: true`; it does its own polling, so
   do not poll from the agent.

   ```bash
   bash <skill-path>/scripts/pr-review-wait.sh [SIGNALS...] [PR_NUMBER] [TIMEOUT_SECONDS] [INTERVAL_SECONDS]
   ```

   - Anchor each regex so it matches only the request comment, e.g.
     `--reaction-on '^/some-review-command'`.
   - `PR_NUMBER` defaults to the current branch's PR; `TIMEOUT_SECONDS` to
     1800; `INTERVAL_SECONDS` to 30.
   - `--once` as the first argument does a single check with no waiting.

## Acting on the result

| Exit | Meaning | What to do |
|------|---------|------------|
| `0` | Ready | Report ready; the caller can proceed. |
| `124` | Timed out | Report it and show which items in the script output were still pending. |
| `2` | Usage or lookup error (bad arguments, no PR, `gh` not authenticated) | Surface the error; do not retry blindly. |
| `1` | Not ready | Only returned by `--once`. |
