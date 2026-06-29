---
name: git-commit-push
version: 0.1.0
description: Commit changes to the current branch with plain git and push them to update the PR. The git-native counterpart to gt-modify-submit, for repos and users that don't use Graphite.
allowed-tools: Bash(git status), Bash(git diff *), Bash(git add *), Bash(git commit *), Bash(git push *), Bash(git rev-parse *)
---

# Commit and Push with Git

Create a commit on the current branch and push it, so the open PR points at the
updated code. This is the plain-`git` counterpart to `/gt-modify-submit` — no
Graphite, no stacks.

## Steps

1. Run `git status` to see current changes.
2. If there are unstaged or staged changes:
   a. Run `git diff --stat` to review what's unstaged.
   b. Stage each relevant file by its explicit path with `git add <path1> <path2> ...`. Never use `git add -A` or `git add .` — bulk staging risks committing unrelated changes.
   c. Run `git diff --cached --stat` to confirm exactly what's staged, and verify nothing unrelated is included.
   d. If nothing relevant is staged, stop and report that there was nothing to commit.
3. Generate a commit message following conventional commits format (e.g., `feat(VYB-<number>): description` if working on a Linear ticket).
4. Run `git commit -m "<commit message>"`.
5. Push to the PR branch with `git push`. The branch already has an upstream when an open PR exists, so a plain `git push` updates it; if push reports no upstream, set one with `git push -u origin HEAD`.
6. Report the pushed commit and the branch it updated.
