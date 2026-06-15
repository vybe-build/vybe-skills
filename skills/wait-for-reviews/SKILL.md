---
name: wait-for-reviews
version: 1.1.0
description: Wait until a PR's CI checks and automated reviews (Claude, Greptile) have finished, up to a timeout. Use when the user says "wait for CI", "wait for reviews", "wait until checks pass", "block until the PR is reviewed", or wants to pause before the next round of work on a PR. Handles only the waiting — compose with fix/review skills for what comes next.
allowed-tools: Bash(bash .claude/skills/wait-for-reviews/scripts/*), Bash(gh pr view *), Bash(gh repo view *)
---

# Wait for Reviews

Block until a PR is ready for the next round of implementation — every CI check
has finished (pass or fail) and the automated reviewers have posted their
verdicts — or until a timeout (default 30 minutes) is reached.

This skill **only waits**. It does not fix comments, reply to threads, or push
anything.

## How "ready" is defined

1. **CI** — no check is still running. Every check has settled into success,
   failure, skipped, or cancelled.
2. **Automated reviews** — the `request-reviews` skill posts two trigger
   comments, `/claude-review` and `@greptileai`. Each reviewer adds a 👍 (+1)
   reaction to its trigger comment when it finishes. Only the **latest** trigger
   comment of each kind is checked, since reviews can be requested repeatedly. A
   reviewer that was never triggered is treated as done.

## Workflow

1. Verify the resolved PR is the one intended for this conversation (if that
   context is available), and flag it to the user if it looks like it's for a
   different workstream — before blocking, potentially for the full timeout.

2. Run the wait script **in the background** so the loop polls without occupying
   the agent. The harness re-invokes the agent when the script exits.

   ```bash
   bash <skill-path>/scripts/pr-review-wait.sh [PR_NUMBER] [TIMEOUT_SECONDS] [INTERVAL_SECONDS]
   ```

   - With no `PR_NUMBER`, it resolves the PR for the current branch.
   - Defaults: `TIMEOUT_SECONDS=1800` (30 min), `INTERVAL_SECONDS=30`.
   - Use `--once` (`pr-review-wait.sh --once [PR_NUMBER]`) for a single check with
     no waiting — handy for a quick status read.

   Set `run_in_background: true` on the Bash tool call. Do **not** poll with the
   agent in the loop; the script already handles the sleep/check cycle.

## Acting on the result

When the background command finishes, branch on its exit code:

| Exit | Meaning | What to do |
|------|---------|------------|
| `0` | Ready — CI and automated reviews are done | Report ready. The caller can proceed to the next step. |
| `124` | Timed out before becoming ready | Tell the user it timed out and show which items (from the script output) were still pending. |
| `2` | Lookup error — no PR found, or `gh` not authenticated | Surface the error; do not retry blindly. |
| `1` | Not ready | Only returned by `--once`. The polling loop never exits `1`. |
