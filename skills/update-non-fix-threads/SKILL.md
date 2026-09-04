---
name: update-non-fix-threads
version: 0.1.0
description: Reply to and resolve every unresolved PR review thread except those with a Fix now verdict. Use when the user says "update non-fix threads", "resolve non-fix comments", or wants accepted, outdated, deferred, and dismissed review decisions finalized while actionable fixes remain open.
---

# Update Non-Fix Threads

Invoke `update-and-resolve-threads` with the **non-fix** subset selected: every unresolved thread whose `review-comments` verdict is not `Fix now`.

Leave all `Fix now` threads untouched and unresolved. Pass through any narrower selection or verdict corrections the user provides.
