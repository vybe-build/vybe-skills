---
name: update-and-resolve-threads
version: 0.1.1
description: Post final verdict replies and resolve PR review threads in one workflow. Handles all unresolved threads by default or a requested subset. Use when the user says "update and resolve threads", "reply and resolve comments", or wants review decisions published and finalized together.
---

# Update and Resolve Threads

Publish final verdicts, then resolve the same review threads:

1. Determine the selection once, using the user's requested subset or all unresolved threads by default. Never silently broaden a requested subset.
2. Invoke `reply-to-threads` in **final** mode with that exact selection.
3. Only after its managed review is submitted successfully, invoke `resolve-threads` with the exact thread IDs that `reply-to-threads` successfully updated.

Do not recompute or broaden the selection between steps. Leave skipped, unselected, or unsuccessfully updated threads unresolved, and report them in the final result.
