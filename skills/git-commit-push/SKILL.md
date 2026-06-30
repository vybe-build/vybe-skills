---
name: git-commit-push
version: 0.1.0
description: Commit changes to the current branch with plain git and push them to update the PR. The git-native counterpart to gt-modify-submit, for repos and users that don't use Graphite.
allowed-tools: Bash(git status), Bash(git diff *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git branch *), Bash(git switch *), Bash(git checkout *)
---

# Commit and Push with Git

Create a commit on the current branch and push it. This is the plain-`git`
counterpart to `/gt-modify-submit` — no Graphite, no stacks.

## Steps

1. Confirm you're on the intended branch (`git branch --show-current`). If not, switch to it before doing anything else.
2. Run `git status` to see current changes.
3. If there are unstaged or staged changes:
   a. Run `git diff --stat` to review what's unstaged.
   b. Stage each relevant file by its explicit path with `git add <path1> <path2> ...`. Never use `git add -A` or `git add .` — bulk staging risks committing unrelated changes.
   c. Run `git diff --cached --stat` to confirm exactly what's staged, and verify nothing unrelated is included.
   d. If nothing relevant is staged, stop and report that there was nothing to commit.
4. Write a commit message in the user's preferred commit style.
5. Run `git commit -m "<commit message>"`.
6. Push the branch with `git push`. If it has no upstream yet, set one with `git push -u origin HEAD`.
7. Report the pushed commit and the branch it updated.
