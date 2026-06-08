---
name: gt-submit
version: 1.0.1
description: Submit current branch and its ancestors to Graphite, creating or updating PRs
---

# Submit to Graphite

Submit the current branch and all downstack branches to Graphite.

## Steps

1. Run `git status` to check for staged changes. If there are staged but uncommitted changes, abort and tell the user to commit them first (e.g. via `/gt-modify`). Unstaged changes are ignored.
2. Run `gt sync` to pull latest trunk and restack branches
3. Run `gt log` to show the current stack state (the full log shows PR numbers and status for each branch)
4. Note which branches already have PRs (they show `PR #<number>` in the `gt log` output)
5. Run `gt submit --no-edit` to push and create/update PRs
6. For each branch that created a **new** PR (i.e., it had no PR in the `gt log` output from step 3):
   a. Check out that branch
   b. If all of the changes on this branch are not already well understood from the current conversation, run `gt info --diff` to see the branch's commits and full diff (scoped to just this branch, not the whole stack)
   c. Write a concise PR description that summarizes the changes
   d. Update the PR with `gh pr edit --body "<description>"`
   e. Check out the original branch when done
7. Report the PR URL(s) created or updated
