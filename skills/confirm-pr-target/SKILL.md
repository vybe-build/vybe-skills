---
name: confirm-pr-target
version: 1.0.0
description: Confirm the PR resolved from the current branch is the one the user intends before acting on it (waiting, reviewing, commenting). Guards against acting on a PR for a different workstream.
allowed-tools: Bash(gh pr view *)
---

# Confirm PR Target

Make sure the PR resolved from the current branch is the one the user intends —
it may be wrong if they switched branches or have multiple workstreams open.

```bash
gh pr view --json number,title,headRefName
```

If the branch/title don't match the workstream this conversation is about (or no
PR exists for the branch), stop and confirm the intended PR before continuing.
Otherwise proceed.
