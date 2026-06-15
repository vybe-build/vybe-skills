---
name: auto-wait-fix-review
version: 1.0.0
description: One hands-off PR review round — wait for CI and automated reviews to finish, apply and resolve review comments, then request a fresh review. Use when the user says "auto fix round", "wait then fix and re-review", "run a review round", or wants one cycle of waiting for feedback, addressing it, and re-requesting review.
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

2. **Fix** — invoke the `/fix-comments-update-threads` skill to fetch unresolved
   comments, apply **Fix now** fixes, commit/push, and reply to + resolve the
   threads.
   - If there were no **Fix now** comments and nothing changed, the PR has
     **converged**. Report that and stop — do **not** request another review,
     since there is nothing new to review.

3. **Re-review** — invoke the `/request-reviews` skill to post fresh trigger
   comments, so a subsequent round has new reviews to wait on.

## Report

Summarize the round: whether the PR became ready (or timed out), how many
comments were addressed, and whether reviews were re-requested or the PR
converged.
