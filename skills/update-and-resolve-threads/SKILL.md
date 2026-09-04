---
name: update-and-resolve-threads
version: 0.1.0
description: Post final verdict replies and resolve PR review threads in one workflow. Handles all unresolved threads by default or a requested subset. Use when the user says "update and resolve threads", "reply and resolve comments", or wants review decisions published and finalized together.
---

# Update and Resolve Threads

Publish final verdicts, then resolve the same review threads:

1. Invoke `update-threads` in **final** mode with the user's requested selection, defaulting to all unresolved threads.
2. Only after its managed review is submitted successfully, invoke `resolve-threads` with the exact thread IDs that `update-threads` successfully updated.

Do not recompute or broaden the selection between steps. Leave skipped, unselected, or unsuccessfully updated threads unresolved, and report them in the final result.
