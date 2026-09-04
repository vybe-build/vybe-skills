---
name: resolve-threads
version: 0.1.0
description: Resolve unresolved PR review threads without posting replies, flagging missing final verdicts when conversation context indicates updates may not have happened. Resolves all open threads by default or only a requested subset. Use when the user says "resolve threads", "close review threads", or wants selected review conversations marked resolved.
allowed-tools: Bash(bash *.claude/skills/update-threads/scripts/resolve-thread.sh *), Bash(bash *.claude/skills/review-comments/scripts/*)
---

# Resolve Threads

Resolve all open PR review threads by default, or only the subset the user or a calling skill requests. This skill does not post replies or change code.

Invoking it authorizes resolution of the selected threads. It commonly follows a successful `update-threads` run, but may be invoked independently.

## Workflow

1. Determine the selection. A subset may be expressed by verdict, thread, location, or an explicit list; **non-fix** means every verdict except `Fix now`. Never silently expand a requested subset.
2. Use the exact thread IDs from the preceding `update-threads` run when available. Otherwise fetch unresolved threads with `bash <skill-path>/../review-comments/scripts/fetch-comments.sh`. If verdict-based selection lacks a current `review-comments` analysis, stop and advise the operator to run `review-comments` first.
3. Stop rather than guess if a selected thread cannot be matched confidently. If none remain open, report that and stop.
4. Use the conversation context to determine whether any selected thread may lack a published final verdict. Positive signals include an update that was skipped or never run, an incomplete or failed managed-review submission, or only a proposal-mode update. If context confirms that final-mode `update-threads` submitted successfully for the exact IDs, treat those threads as updated.
5. Only when the conversation positively suggests that updates may be missing, inspect the affected thread comments to confirm. Standard final verdicts are `Fixed`, `Addressed previously`, `Outdated`, `Deferred`, and `Dismissed`; an unambiguous equivalent also counts. A `Proposed verdict` does not count as final. Inspect only the affected threads, not the whole selection.
6. Show the threads that will be resolved and summarize those left open. Prominently flag every selected thread known or confirmed to lack a final verdict. Do not silently treat those threads as updated. The warning does not cancel the user's resolve request or authorize posting a missing reply.
7. Resolve each selected thread with a separate Bash tool call, running them in parallel:

```bash
bash <skill-path>/../update-threads/scripts/resolve-thread.sh <thread_id_1>
bash <skill-path>/../update-threads/scripts/resolve-thread.sh <thread_id_2>
```

When following `update-threads`, do not resolve anything unless its managed review was submitted successfully. Report resolved threads, deliberately unselected threads, and any failures.
