---
name: request-reviews
version: 1.0.0
description: Post comments to the current PR to trigger re-reviews from Claude and Greptile. Use when the user says "request reviews", "re-review", "trigger reviews", or wants reviewers to look at the PR again.
allowed-tools: Bash(gh pr view *), Bash(gh pr comment *)
---

# Request Reviews

Post comments on the current branch's PR to trigger automated re-reviews.

Before posting, verify the PR resolved from the current branch is the one
intended for this conversation (if that context is available), and flag it to the
user if it looks like it's for a different workstream.

## Workflow

1. Get the current PR number:

```bash
gh pr view --json number --jq '.number'
```

If there is no PR for the current branch, report that and stop.

2. Post both review-trigger comments:

```bash
gh pr comment "$(gh pr view --json number --jq '.number')" --body '/claude-review'
gh pr comment "$(gh pr view --json number --jq '.number')" --body '@greptileai'
```

3. Report that both review requests have been posted.
