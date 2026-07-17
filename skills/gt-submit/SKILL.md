---
name: gt-submit
version: 1.0.7
description: Submit current branch and its ancestors to Graphite, creating or updating PRs (new PRs as drafts)
allowed-tools: Bash(git status), Bash(gt sync), Bash(gt log *), Bash(gt submit --draft --no-edit), Bash(gt info *), Bash(git diff *), Bash(gh pr view *), Bash(gh pr edit *), Bash(gh pr diff *)
---

# Submit to Graphite

Submit the current branch and all downstack branches to Graphite.

## Steps

1. Run `git status` to check for staged changes. If there are staged but uncommitted changes, abort and tell the user to commit them first (e.g. via `/gt-modify`). Unstaged changes are ignored.
2. Run `gt sync` to pull latest trunk and restack branches
3. Run `gt log --stack` to show the current stack (shows PR numbers and status for each branch in the stack)
4. Note which branches already have PRs (they show `PR #<number>` in the `gt log` output). If any **downstack** branch (below the current one, toward trunk) has no PR yet, abort and ask the user to submit those first.
5. Run `gt submit --draft --no-edit` to push and create/update PRs (new PRs are created as drafts)
6. If the current branch created a new PR, or this submit made substantial changes to an existing one, invoke the `/pr-update-description` skill to write or refresh its description.
7. Report the PR URL(s) created or updated
