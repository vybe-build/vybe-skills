---
name: commit-and-push
version: 0.1.0
description: Commit and push the current branch's changes using the right VCS workflow — Graphite when a stacked PR is wanted, otherwise plain git. A VCS-agnostic router so other skills can commit without hard-coding a tool. Use when the user says "commit and push" or as a commit step in a larger workflow.
---

# Commit and Push

Commit the working changes and push them, dispatching to the right VCS workflow.

## Choose the tool

Use **Graphite** when a stacked PR has been requested; otherwise use plain
**git**. Honor any explicit instruction for this run (e.g. "stack this",
"use git").

## Dispatch

- **Graphite** → invoke the `/gt-modify-submit` skill.
- **Git** → invoke the `/git-commit-push` skill.
