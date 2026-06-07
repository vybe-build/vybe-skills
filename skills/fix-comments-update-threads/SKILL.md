---
name: fix-comments-update-threads
version: 1.0.0
description: End-to-end PR review-comment loop — fetch unresolved comments, apply Fix Now fixes, commit/push, then reply and resolve the threads. Use when the user says "fix comments and update threads", "fix and resolve comments", "full comment loop", or wants the entire feedback-to-resolved cycle in one shot.
---

# Fix Comments and Update Threads

Run the full review-comment loop: fetch, fix, push, and resolve.

## Steps

1. Follow the `/review-comments-and-fix` skill to fetch unresolved comments and apply fixes for any **Fix now** items
2. If any fixes were applied, follow the `/gt-modify-submit` skill to commit and push them — so the resolved threads point at real code on the PR
3. Follow the `/update-threads` skill to reply with verdicts and resolve each thread
