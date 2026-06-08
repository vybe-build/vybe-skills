---
name: gt-modify
version: 1.0.2
description: Commit changes to the current branch using Graphite
allowed-tools: Bash(git status), Bash(git diff *), Bash(git add *), Bash(gt modify *), Bash(gt log *)
---

# Commit to Current Branch

Create a new commit on the current branch. Automatically restacks descendants.

## Steps

1. Run `git status` to see current changes
2. If there are unstaged or staged changes:
   a. Run `git diff --stat` to review what's unstaged
   b. Stage the appropriate files with `git add <files>` (be specific — avoid `git add .` to prevent accidentally including unwanted files)
   c. Run `git diff --cached --stat` to confirm exactly what's staged
3. Generate a commit message following conventional commits format (e.g., `feat(VYB-<number>): description` if working on a Linear ticket)
4. Run `gt modify --commit --message "<commit message>"` to create a new commit
5. Run `gt log short` to show the updated stack
