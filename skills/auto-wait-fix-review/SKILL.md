---
name: auto-wait-fix-review
version: 1.1.0
description: One hands-off PR review round — wait for CI and automated reviews to finish, fix any CI failures, apply and resolve review comments, then request a fresh review. Use when the user says "auto fix round", "wait then fix and re-review", "run a review round", or wants one cycle of waiting for feedback, addressing it, and re-requesting review.
---

# Auto Wait, Fix, Review

Run one complete automated review round on the current PR: wait for feedback,
address it, then ask for the next review.

## Steps

1. **Wait** — invoke the `/wait-for-reviews` skill to block until CI checks and
   automated reviews have finished.
   - Run its script in the background and branch on the exit code.
   - On **timeout** (exit `124`) or **lookup error** (exit `2`): stop and report.
     Do not continue to the fix step.

2. **Check CI** — once the wait reports ready, inspect the final CI results.
   "Ready" only means every check *finished*, not that it *passed*, so look for
   failures before moving on:

   ```bash
   gh pr checks <PR_NUMBER> --json name,bucket,link
   ```

   - If no check is in the `fail` bucket, continue to the Fix step.
   - If any check failed, treat it as feedback for this round:
     1. Fetch the failing check's logs to diagnose it. For GitHub Actions
        checks, `gh run view <run-id> --log-failed` (the run id is in the
        check's `link`); otherwise open the `link`.
     2. Apply fixes, then stage by explicit path, commit, and push.
     3. **Skip** a check you can't act on — a flaky or required external check,
        or one failing for reasons unrelated to this PR's changes. Note it in
        the report rather than guessing at a fix.

3. **Fix** — invoke the `/fix-comments-update-threads` skill to fetch unresolved
   comments, apply **Fix now** fixes, commit/push, and reply to + resolve the
   threads.
   - **Convergence** requires CI to be settled too: if there were no **Fix now**
     comments, no CI failures were fixed, and nothing changed, the PR has
     converged. Report that and stop — do **not** request another review, since
     there is nothing new to review.
   - If CI failures remain that you **could not fix**, the PR is *not* converged
     and *not* ready: report the outstanding failure and stop without
     re-requesting review.

4. **Re-review** — invoke the `/request-reviews` skill to post fresh trigger
   comments, so a subsequent round has new reviews to wait on.

## Report

Summarize the round: whether the PR became ready (or timed out), any CI failures
and whether they were fixed or left outstanding, how many comments were
addressed, and whether reviews were re-requested or the PR converged.
