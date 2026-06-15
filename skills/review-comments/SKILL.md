---
name: review-comments
version: 1.1.0
description: Fetch and analyze unresolved PR review comments for the current branch. Use when the user says "review comments", "PR comments", "PR feedback", "check comments", "address feedback", or wants to see and triage unresolved review comments on their pull request.
allowed-tools: Bash(bash .claude/skills/review-comments/scripts/*), Bash(gh pr view *), Read
---

# Review Comments

Fetch unresolved PR review comments, read the relevant code, and provide an actionable analysis.

Before fetching, verify the PR resolved from the current branch is the one intended for this conversation (if that context is available), and flag it to the user if it looks like it's for a different workstream.

## Workflow

### 1. Fetch unresolved comments

Run the fetch script:

```bash
bash <skill-path>/scripts/fetch-comments.sh
```

If there are no unresolved threads, report that and stop.

### 2. Read relevant source files

For each thread, read the file at the referenced path (use the `file` and `line` fields) to understand the current state of the code. If a thread is marked `is_outdated: true`, note that the code may have changed since the comment was made — still read the current file to check.

### 3. Group duplicate threads

Before writing any per-thread analysis, scan all unresolved threads and group duplicates — threads from different authors (e.g. `greptile-apps` and `claude`) raising substantially the same issue on the same file/line or about the same code. Each group will be analyzed and presented as a single entry in both the prose section and the summary table.

A "thread" in the steps below refers to a group from this step (which may contain one or more underlying threads).

### 4. Analyze each thread

For every (grouped) thread, provide:

1. **Location** — file path and line number
2. **Author(s)** — the distinct GitHub logins across all comments in the thread (or all underlying threads, if grouped). List every unique author.
3. **Comment summary** — one-line distillation of the reviewer's concern (pick the clearest wording when grouping)
4. **Validity assessment** — is this a valid concern? Why or why not? Consider:
   - Does the concern reflect an actual bug, readability issue, or violation of project conventions?
   - Is it subjective style preference vs objective improvement?
   - Has the code already been changed to address this concern?
   - Is the comment outdated (code rewritten or removed)?
   - Is it from a bot (e.g. accounts that look bot-like such as `greptile-apps`, `copilot-pull-request-reviewer`, `claude`, or any login ending in `[bot]`) vs a human reviewer? Bot comments deserve less weight.
5. **Recommendation** — one of:
   - **Fix now** — valid concern, in scope for this PR, worth addressing before merge
   - **Addressed previously** — the code has already been changed to satisfy the reviewer's concern
   - **Outdated** — the relevant code has been significantly rewritten or removed, making the comment no longer applicable
   - **Defer** — valid concern but out of scope (explain why — e.g. unrelated refactor, risky change, separate feature)
   - **Dismiss** — not a valid concern (explain why — e.g. subjective, incorrect)

### 5. Present a summary table

End with a markdown table:

| # | File | Line | Author | Concern | Verdict | Reason |
|---|------|------|--------|---------|---------|--------|

Group by verdict (Fix now, Addressed previously, Outdated, Defer, Dismiss). The `#` column is only a row index for readability within this table — it has no meaning outside the list and should not be used to reference comments elsewhere.
