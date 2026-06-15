---
name: request-reviews
version: 1.1.0
description: Post comments to the current PR to trigger re-reviews from Claude and Greptile. Use when the user says "request reviews", "re-review", "trigger reviews", or wants reviewers to look at the PR again.
allowed-tools: Bash(bash .claude/skills/request-reviews/scripts/*), Bash(gh pr view *)
---

# Request Reviews

Post comments on the current branch's PR to trigger automated re-reviews.

## Workflow

1. Get the current PR number:

```bash
gh pr view --json number --jq '.number'
```

If there is no PR for the current branch, report that and stop.

2. Verify the resolved PR is the one intended for this conversation (if that
   context is available), and flag it to the user if it looks like it's for a
   different workstream.

3. Post the review-trigger comments by running the script (pass the PR number
   from step 1, or omit it to resolve the current branch's PR):

```bash
bash <skill-path>/scripts/post-review-triggers.sh [PR_NUMBER]
```

   The triggers live in the script's `TRIGGERS` array — edit it there as
   reviewers change.

4. Report that the review requests have been posted.
