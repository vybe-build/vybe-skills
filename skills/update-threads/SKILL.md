---
name: update-threads
version: 1.1.0
description: Reply to and resolve PR review comment threads with verdicts. Use when the user says "update threads", "resolve threads", "reply to comments", or wants to post decisions (Fixed, Addressed previously, Outdated, Deferred, Dismissed) on PR review threads and resolve them.
allowed-tools: Bash(bash *.claude/skills/update-threads/scripts/*), Bash(bash *.claude/skills/review-comments/scripts/*)
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

### 3. Show the plan

Show a table of what will be posted:

| # | File | Line | Author | Concern | Verdict | Reply |
|---|------|------|--------|---------|---------|-------|

The **Author** column should list the distinct GitHub logins across all comments in the thread (matching what `review-comments` derived). For grouped duplicate threads, list every author from the underlying threads.

Proceed directly to posting — do not ask for user confirmation. The user has already approved by invoking this skill after running `review-comments`.

### 4. Publish all replies

Pass every thread/reply pair to the batch script in a **single** Bash tool call:

```bash
bash <skill-path>/scripts/reply-to-threads.sh \
  <thread_id_1> "<emoji> **<verdict>** — <reason>" \
  <thread_id_2> "<emoji> **<verdict>** — <reason>"
```

The script validates all targets before making changes, creates one dedicated pending review, explicitly attaches every reply to that review, submits that exact review as `COMMENT`, and verifies publication. If the authenticated user already has a pending review on the PR, the script stops before posting anything; submit or discard that review and retry. This prevents GitHub from silently distributing replies across implicit pending reviews and avoids accidentally submitting unrelated draft comments.

If reply publication fails, report the failure and stop. Do not resolve any threads.

### 5. Resolve the threads

Only after the reply batch succeeds, resolve each thread. Issue each command as a **separate** Bash tool call, but run them in **parallel** within a single message:

```bash
bash <skill-path>/scripts/resolve-thread.sh <thread_id_1>
bash <skill-path>/scripts/resolve-thread.sh <thread_id_2>
```

Use these emoji prefixes:

| Verdict | Emoji |
|---------|-------|
| Fixed | ✅ |
| Addressed previously | ✅ |
| Outdated | 🗑️ |
| Deferred | ⏳ |
| Dismissed | 🙅 |

Report the two phases separately — how many replies were published, how many threads were resolved, and any failures. A resolution failure must not be reported as a missing reply.
