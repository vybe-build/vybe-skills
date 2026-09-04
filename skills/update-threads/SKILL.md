---
name: update-threads
version: 2.0.0
description: Reply to unresolved PR review threads with proposed or final verdicts, without resolving them. Updates all threads by default or only a requested subset. Use when the user says "update threads", "reply to comments", "post verdicts", or wants review decisions recorded on selected threads.
allowed-tools: Bash(bash *.claude/skills/update-threads/scripts/create-review.sh *), Bash(bash *.claude/skills/update-threads/scripts/reply-to-thread.sh *), Bash(bash *.claude/skills/update-threads/scripts/submit-review.sh *), Bash(bash *.claude/skills/review-comments/scripts/*), Read
---

# Update Threads

Post verdicts and concise reasoning to unresolved PR review threads through one managed GitHub review. This skill only publishes replies; it never resolves threads or changes code.

This skill normally follows `review-comments`. Invoking it authorizes the requested replies.

## Modes and selection

Choose the reply mode from the request:

- **Final** (default) — post the final verdict for each selected thread.
- **Proposal** — label each verdict as proposed so the operator can review it alongside the code.

Select all unresolved threads by default. If the user or a calling skill requests a subset, operate only on that subset. A subset may be expressed by verdict, thread, location, or an explicit list; **non-fix** means every verdict except `Fix now`.

Never silently expand a requested subset. If the selection is ambiguous, stop before posting and ask which threads are intended.

## Workflow

### 1. Gather decisions

Use the latest `review-comments` analysis and any subsequent operator corrections in the conversation. If decisions are missing or stale, invoke `review-comments` before continuing.

For each underlying unresolved thread, retain its GraphQL `thread_id`, location, authors, concern, verdict, and concise reasoning. A grouped duplicate represents multiple underlying threads; apply the same decision to each one unless the operator says otherwise.

The triage verdicts are `Fix now`, `Addressed previously`, `Outdated`, `Defer`, and `Dismiss`.

### 2. Select and reconcile the target threads

Apply the requested selection, defaulting to all unresolved threads. Then re-fetch the open threads:

```bash
bash <skill-path>/../review-comments/scripts/fetch-comments.sh
```

Match the selected decisions to the fresh thread IDs. Ignore a selected thread that is already resolved. Stop rather than guess if an open selected thread has no decision or cannot be matched confidently.

For final replies, verify every selected `Fix now` item before labeling it `Fixed`. Conversation context is sufficient when it shows the applied change; otherwise read the current code. Skip and report an item whose fix has not been applied. Proposal replies do not require the fix to exist yet.

If no selected threads remain, report that no replies were posted and stop.

### 3. Prepare the replies

For final mode, map triage verdicts to reply verdicts:

| Triage verdict | Final reply verdict | Emoji |
|----------------|---------------------|-------|
| Fix now | Fixed | ✅ |
| Addressed previously | Addressed previously | ✅ |
| Outdated | Outdated | 🗑️ |
| Defer | Deferred | ⏳ |
| Dismiss | Dismissed | 🙅 |

Format final replies as:

```markdown
<emoji> **<final verdict>** — <reason>
```

For proposal mode, preserve the triage verdict and format replies as:

```markdown
💭 **Proposed verdict: <triage verdict>** — <reason>
```

Keep each reason to one or two sentences and state the evidence or tradeoff behind the decision. A final reply after an earlier proposal should incorporate any operator correction and clearly record the final decision.

Show a plan with one row per selected underlying thread:

| File | Line | Author | Concern | Verdict | Reply |
|------|------|--------|---------|---------|-------|

Also summarize skipped or unselected threads. Proceed directly after showing the plan; invoking the skill supplied the necessary authorization.

### 4. Create or resume a managed review

Create a managed pending review using any selected thread ID:

```bash
bash <skill-path>/scripts/create-review.sh <thread_id_1>
```

Read `review_id` from the JSON output. If it says `resumed: true`, continue only when the conversation confirms that the pending review belongs to this interrupted operation with the same mode and selection. Otherwise report it and stop; never discard a pending review automatically.

### 5. Post and reconcile the replies

Post each reply with its own Bash tool call, passing the managed review ID explicitly. Run calls in parallel batches of no more than five:

```bash
bash <skill-path>/scripts/reply-to-thread.sh \
  <review_id> <thread_id_1> "<formatted reply>"
```

Each reply includes a hidden operation marker. If a call fails or its result is ambiguous, retry that exact command; the script reconciles a successful reply instead of duplicating it.

Do not discard the review when one reply fails. Preserve successful drafts and retry only failed replies. If a failure cannot be recovered, report the `review_id` and stop without submitting.

### 6. Submit the complete review

After every reply succeeds, submit the review with exactly the selected thread IDs:

```bash
bash <skill-path>/scripts/submit-review.sh \
  <review_id> <thread_id_1> <thread_id_2>
```

The script refuses incomplete, duplicate, or unrelated contents and is safe to retry after an ambiguous result. Never call `discard-review.sh` without an explicit user request to abandon the run.

Report the mode and selection, replies posted or reconciled, review submission, skipped or deliberately unselected threads, and any failures. Explicitly note that no threads were resolved.
