---
name: request-reviews
version: 1.0.0
description: Post comments to the current PR to trigger re-reviews from Claude and Greptile. Use when the user says "request reviews", "re-review", "trigger reviews", or wants reviewers to look at the PR again.
allowed-tools: Bash(gh pr view *), Bash(gh pr comment *)
---

# Request Reviews

Post comments on the current branch's PR to trigger automated re-reviews.

## Workflow

1. Confirm the target PR — invoke the `/confirm-pr-target` skill to make sure the
   PR resolved for the current branch is the one the user intends before posting
   trigger comments to it.

2. Get the current PR number:

```bash
gh pr view --json number --jq '.number'
```

If there is no PR for the current branch, report that and stop.

3. Post both review-trigger comments:

```bash
gh pr comment "$(gh pr view --json number --jq '.number')" --body '/claude-review'
gh pr comment "$(gh pr view --json number --jq '.number')" --body '@greptileai'
```

4. Report that both review requests have been posted.
