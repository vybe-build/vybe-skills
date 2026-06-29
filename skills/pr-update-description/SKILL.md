---
name: pr-update-description
version: 1.1.0
description: Update the PR description for the current branch based on its changes. Use when the user asks to "update the PR description", "rewrite the PR body", "refresh the PR description", or wants the description regenerated based on current branch changes.
allowed-tools: Bash(gh pr view *), Bash(gh pr edit *), Bash(gh pr diff *), Bash(gt info *), Bash(git diff *)
---

# Update PR Description

Rewrite the PR description for the current branch's pull request.

## Steps

1. Run `gh pr view --json number,title,body` to get the current PR info
2. If all of the changes on the branch are not already well understood from the current conversation, view the branch's diff:
   - **Graphite** repos: `gt info --diff` (scoped to just this branch, not the whole stack)
   - **Plain git** repos (no Graphite): `gh pr diff` for the PR's full diff, or `git diff <base>...HEAD`
3. Write a concise PR description appropriate for the changes
4. Update the PR with `gh pr edit --body "<description>"`
5. Report the updated PR URL
