---
name: commit-and-push
version: 0.1.0
description: Commit and push the current branch's changes using whichever VCS workflow the user prefers — Graphite or plain git. A VCS-agnostic router so review loops and other skills can commit without hard-coding a tool. Use when the user says "commit and push", or as the commit step inside an automated review round.
---

# Commit and Push

Commit the working changes and push them to update the open PR, dispatching to
the user's preferred VCS workflow. This is a thin router: it resolves which tool
to use, then invokes the matching implementation skill. Keep the tool-specific
mechanics in those skills, not here.

## Resolve the workflow

Pick **Graphite** or **git** in this order:

1. **Per-invocation override.** If the user said which to use for this run (e.g.
   "use git this time", "stack this"), honor it.
2. **Recorded preference.** Otherwise use the user's known VCS preference (from
   memory). Recognized preferences:
   - **Graphite always** → Graphite.
   - **Git always** → git.
   - **Git normally, Graphite only when stacking** → git for this loop. A
     comment-fix / review round operates on a single existing PR branch — the
     "normal" case — so use git. Only reach for Graphite when the user is
     explicitly building a stack.
3. **No preference recorded → ask.** Ask whether they want Graphite, git always,
   or git-normally-Graphite-for-stacks, then **save the answer to memory** so
   future rounds run hands-off. Apply their answer to this run.

## Dispatch

- **Graphite** → invoke the `/gt-modify-submit` skill (commits with `gt modify`,
  restacks descendants, and submits — preserving stacked-PR behavior).
- **Git** → invoke the `/git-commit-push` skill (stages by explicit path,
  commits, and pushes the branch).

## Report

Note which workflow was used and the result, so the caller (e.g. an automated
review round) can see whether anything was committed.
