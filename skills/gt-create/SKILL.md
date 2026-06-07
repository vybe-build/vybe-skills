---
name: gt-create
version: 1.0.0
description: Create a new stacked branch on top of the current branch, with or without changes
---

# Create Stacked Branch

Create a new branch stacked on top of the current branch.

## Steps

1. Run `git status` to check for uncommitted changes
2. If there are unstaged or staged changes:
   a. Run `git diff --stat` to review what's unstaged
   b. Stage the appropriate files with `git add <files>` (be specific — avoid `git add .` to prevent accidentally including unwanted files)
   c. Run `git diff --cached --stat` to confirm exactly what's staged
3. Generate a commit message following conventional commits format (e.g., `feat(VYB-<number>): description` if working on a Linear ticket)
4. Run `gt create --message "<commit message>"` to create the branch (creates empty branch if no staged changes)
5. Run `gt sync` to pull latest trunk and restack branches
6. Run `gt log short` to show the updated stack
