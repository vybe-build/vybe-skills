---
name: gt-submit
version: 1.0.0
description: Submit current branch and its ancestors to Graphite, creating or updating PRs
---

# Submit to Graphite

Submit the current branch and all downstack branches to Graphite.

## Steps

1. Run `git status` to check for uncommitted changes
2. If there are unstaged or staged changes:
   a. Stage the appropriate files with `git add <files>`
   b. Generate a commit message following conventional commits format
   c. Present the commit message to the user using `AskUserQuestion` with the generated message as the first option
   d. Commit using `gt modify --commit --message "<commit message>"` with the user's chosen message
3. Run `gt sync` to pull latest trunk and restack branches
4. Run `gt log` to show the current stack state (the full log shows PR numbers and status for each branch)
5. Note which branches already have PRs (they show `PR #<number>` in the `gt log` output)
6. Run `gt submit --no-edit` to push and create/update PRs
7. For each branch that created a **new** PR (i.e., it had no PR in the `gt log` output from step 4):
   a. Check out that branch
   b. If all of the changes on this branch are not already well understood from the current conversation, run `gt info --diff` to see the branch's commits and full diff (scoped to just this branch, not the whole stack)
   c. Write a concise PR description that summarizes the changes
   d. Update the PR with `gh pr edit --body "<description>"`
   e. Check out the original branch when done
8. Report the PR URL(s) created or updated
