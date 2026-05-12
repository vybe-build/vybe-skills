---
name: update-threads
version: 1.0.0
description: Reply to and resolve PR review comment threads with verdicts. Use when the user says "update threads", "resolve threads", "reply to comments", or wants to post decisions (Fixed, Addressed previously, Outdated, Deferred, Dismissed) on PR review threads and resolve them.
---

# Update Threads

Reply to each unresolved PR review thread with the verdict and a short explanation, then resolve the thread.

This skill is designed to run **after** the `review-comments` skill has triaged the threads and the user has reviewed the decisions and applied any fixes.

## Workflow

### 1. Gather decisions from conversation context

Look at the current conversation for the output of the `review-comments` skill (or user-provided decisions). For each thread, you need:

- **thread_id** — the GraphQL node ID from the `fetch-comments.sh` JSON output earlier in the conversation. If the JSON is no longer in context, re-fetch by running `bash <skill-path>/../review-comments/scripts/fetch-comments.sh`
- **verdict** — one of: `Fixed`, `Addressed previously`, `Outdated`, `Deferred`, `Dismissed`
- **reason** — a short (1–2 sentence) explanation of the decision

Map the `review-comments` verdicts to reply verdicts:

| review-comments verdict | Reply verdict |
|------------------------|---------------|
| Fix now | Fixed (only after verifying the fix was applied) |
| Addressed previously | Addressed previously |
| Outdated | Outdated |
| Defer | Deferred |
| Dismiss | Dismissed |

If there are no decisions available in the conversation, tell the user to run the `review-comments` skill first.

### 2. Verify "Fix now" items

For any thread with a `Fix now` verdict, confirm the fix was applied before marking it as `Fixed`. If the fix is visible in the current conversation context, that is sufficient. Otherwise, read the current code to verify. If a fix was **not** applied, flag it to the user and skip it.

### 3. Present the plan and ask for confirmation

Show a table of what will be posted:

| # | File | Line | Author | Concern | Verdict | Reply |
|---|------|------|--------|---------|---------|-------|

The **Author** column should list the distinct GitHub logins across all comments in the thread (matching what `review-comments` derived). For grouped duplicate threads, list every author from the underlying threads.

Then use the `AskUserQuestion` tool to get confirmation before proceeding. Do not post any replies without explicit user approval.

### 4. Reply to and resolve each thread

For each confirmed thread, format the reply body and post it, then resolve:

```bash
bash <skill-path>/scripts/reply-to-thread.sh <thread_id> "<emoji> **<verdict>** — <reason>"
bash <skill-path>/scripts/resolve-thread.sh <thread_id>
```

Use these emoji prefixes:

| Verdict | Emoji |
|---------|-------|
| Fixed | ✅ |
| Addressed previously | ✅ |
| Outdated | 🗑️ |
| Deferred | ⏳ |
| Dismissed | 🙅 |

Report the results — how many threads were updated and any failures.
