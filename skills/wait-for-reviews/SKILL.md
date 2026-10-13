---
name: wait-for-reviews
version: 2.0.0
description: Wait until a PR's CI checks and automated reviews have finished, using the repo's own documented signal for when a review is done, up to a timeout. Use when the user says "wait for CI", "wait for reviews", "wait until checks pass", "block until the PR is reviewed", or wants to pause before the next round of work on a PR. Handles only the waiting — compose with fix/review skills for what comes next.
allowed-tools: Bash(bash *.claude/skills/wait-for-reviews/scripts/*), Bash(gh pr view *), Bash(gh repo view *)
---

# Wait for Reviews

Block until a PR is ready for the next round of implementation — every CI check
has finished (pass or fail) and the repo's automated reviewers have finished —
or until a timeout (default 30 minutes) is reached.

This skill **only waits**. It does not fix comments, reply to threads, or push
anything. It carries no reviewers of its own — how a reviewer signals that it
is done comes from the repo's docs, memory, or the user.

## How "ready" is defined

1. **CI** — no check is still running. Every check has settled into success,
   failure, skipped, or cancelled.
2. **Automated reviews** — every review signal passed to the script has fired.
   The script understands two kinds:

   | Flag | Done when |
   |------|-----------|
   | `--reaction-on '<regex>'` | The **latest** PR comment matching the regex has a 👍 on it (another reaction with `--reaction <name>`). For reviewers that react to their trigger comment when finished. If no comment matches, no review was requested and the signal counts as done. |
   | `--review-by <login>` | That account has submitted a review on the PR's current head commit. |

   With no signals the script waits on CI only. A reviewer that reports through
   a CI check is already covered by 1.

## Workflow

1. Verify the resolved PR is the one intended for this conversation (if that
   context is available), and flag it to the user if it looks like it's for a
   different workstream — before blocking, potentially for the full timeout.

2. Find how this repo's automated reviewers signal completion. Check, in order,
   and stop at the first source that states it:

   1. **This conversation** — the user already said, or an earlier run of this
      skill already established it. Reuse it.
   2. **Loaded instructions and memory** — agent instruction files
      (`CLAUDE.md`, `AGENTS.md`, and the like) and any memory entries for this
      repo.
   3. **Repo docs** — `CONTRIBUTING.md`, `README.md`, the PR template under
      `.github/`, and review or contributing pages under `docs/`.

   A source counts only if it says what "done" looks like for each reviewer (a
   reaction on the request comment, a submitted review, a CI check) or that
   there are no automated reviewers. Knowing how reviews are *requested* is not
   enough — do not assume a reviewer reacts to its trigger. Do not infer a
   signal from past PR activity, installed apps, or what other repos do.

3. If it was not found, or it is ambiguous, ask the user how to tell when
   reviews are done in this repo (CI only is a valid answer) and wait for the
   answer before starting the wait. Once they answer, offer to save it (to
   memory, or to the repo's agent instructions file) so later runs find it in
   step 2. If a reviewer's signal fits neither flag, say so and wait on the
   rest rather than approximating it.

4. Run the wait script **in the background** so the loop polls without occupying
   the agent. The harness re-invokes the agent when the script exits.

   ```bash
   bash <skill-path>/scripts/pr-review-wait.sh [SIGNALS...] [PR_NUMBER] [TIMEOUT_SECONDS] [INTERVAL_SECONDS]
   ```

   - `SIGNALS` are the flags from the table above, one per reviewer, e.g.
     `--reaction-on '^/some-review-command' --review-by some-review-bot`.
     Anchor the regex so it matches only the request comment.
   - With no `PR_NUMBER`, it resolves the PR for the current branch.
   - Defaults: `TIMEOUT_SECONDS=1800` (30 min), `INTERVAL_SECONDS=30`.
   - Use `--once` (`pr-review-wait.sh --once [SIGNALS...] [PR_NUMBER]`) for a
     single check with no waiting — handy for a quick status read.

   Set `run_in_background: true` on the Bash tool call. Do **not** poll with the
   agent in the loop; the script already handles the sleep/check cycle.

## Acting on the result

When the background command finishes, branch on its exit code:

| Exit | Meaning | What to do |
|------|---------|------------|
| `0` | Ready — CI and the requested review signals are done | Report ready. The caller can proceed to the next step. |
| `124` | Timed out before becoming ready | Tell the user it timed out and show which items (from the script output) were still pending. |
| `2` | Usage or lookup error — bad arguments, no PR found, or `gh` not authenticated | Surface the error; do not retry blindly. |
| `1` | Not ready | Only returned by `--once`. The polling loop never exits `1`. |
