---
name: update-threads
version: 3.0.0
description: Alias for update-and-resolve-threads. Post final verdict replies and then resolve the same PR review threads, handling all unresolved threads by default or only a requested subset. Use when the user says "update threads", "reply and resolve comments", or wants review decisions published and finalized.
---

# Update Threads

This is a compatibility alias for `update-and-resolve-threads`.

Invoke `update-and-resolve-threads` with the user's requested selection. Default to all unresolved threads when no subset is requested. Pass every subset constraint through unchanged; never silently broaden it.

This alias always uses final verdicts and resolves only the threads whose replies were successfully published. Use `reply-to-threads` directly when replies should remain unresolved, including proposal workflows.
