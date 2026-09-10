---
name: fix-comments-update-threads
version: 1.1.3
description: End-to-end PR review-comment loop — fetch unresolved comments, apply Fix Now fixes, commit/push, then reply and resolve the threads. Use when the user says "fix comments and update threads", "fix and resolve comments", "full comment loop", or wants the entire feedback-to-resolved cycle in one shot.
---

# Fix Comments and Update Threads

Run the full review-comment loop: fetch, fix, push, and resolve.

## Steps

1. Invoke `/review-comments-and-fix`.
2. If any fixes were applied, invoke the `/commit-and-push` skill to commit and push them — so the resolved threads point at real code on the PR
3. Invoke `/update-threads` to reply with final verdicts and resolve the successfully updated threads
