---
name: update-threads
version: 1.2.0
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

### 4. Create or resume a managed review

Create a managed pending review using any target thread ID:

```bash
bash <skill-path>/scripts/create-review.sh <thread_id_1>
```

Read `review_id` from the JSON output. The script creates one identifiable review or resumes a managed review left pending by an earlier failed run. It refuses to reuse an unrelated pending review.

### 5. Post and reconcile the replies

Post each reply with its own Bash tool call, passing the managed review ID explicitly. Run calls in parallel batches of no more than five to limit secondary-rate-limit failures:

```bash
bash <skill-path>/scripts/reply-to-thread.sh \
  <review_id> <thread_id_1> "<emoji> **<verdict>** — <reason>"

bash <skill-path>/scripts/reply-to-thread.sh \
  <review_id> <thread_id_2> "<emoji> **<verdict>** — <reason>"
```

Each reply includes a hidden operation marker. If a call fails or its result is ambiguous, retry that exact command. The script first checks the thread for the marker and succeeds without posting a duplicate when the reply already exists.

Do not discard the review when one reply fails. Preserve successful drafts and retry only failed replies. If a failure cannot be recovered, report the `review_id` and stop; do not submit or resolve anything.

### 6. Submit the complete review

After every reply command succeeds, submit the review with the complete expected thread list:

```bash
bash <skill-path>/scripts/submit-review.sh \
  <review_id> <thread_id_1> <thread_id_2>
```

The submit script verifies that the managed review contains exactly one marked reply for every expected thread and no other comments. It refuses incomplete, duplicate, or unrelated contents. It is safe to retry after an ambiguous submission result.

Never call `discard-review.sh` automatically. It permanently deletes the managed pending review and is reserved for an explicit user request to abandon the run.

### 7. Resolve the threads

Only after `submit-review.sh` succeeds, resolve each thread. Issue each command as a **separate** Bash tool call, but run them in **parallel** within a single message:

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

Report the lifecycle phases separately — how many replies were posted or reconciled, whether the managed review was submitted, how many threads were resolved, and any failures. A resolution failure must not be reported as a missing reply.
