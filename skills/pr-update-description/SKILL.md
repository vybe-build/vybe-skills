---
name: pr-update-description
version: 1.0.2
description: Update the PR description for the current branch based on its changes. Use when the user asks to "update the PR description", "rewrite the PR body", "refresh the PR description", or wants the description regenerated based on current branch changes.
allowed-tools: Bash(gh pr view *), Bash(gh pr edit *), Bash(gt info *)
---

# Update PR Description

Rewrite the PR description for the current branch's pull request.

## Steps

1. Run `gh pr view --json number,title,body` to get the current PR info
2. If all of the changes on the branch are not already well understood from the current conversation, run `gt info --diff` to see the branch's commits and full diff (scoped to just this branch, not the whole stack)
3. Write a concise PR description appropriate for the changes
4. Update the PR with `gh pr edit --body "<description>"`
5. Report the updated PR URL
