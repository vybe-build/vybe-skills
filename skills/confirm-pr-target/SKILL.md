---
name: confirm-pr-target
version: 1.0.0
description: Confirm the PR resolved for the current branch is the one the user intends before acting on it. Use before waiting on, reviewing, or commenting on a PR — or when the user says "is this the right PR", "confirm the PR", "check I'm on the right branch". Guards against acting on a PR meant for a different workstream.
allowed-tools: Bash(gh pr view *)
---

# Confirm PR Target

Before acting on "the current PR", make sure it is the one the user intends. The
PR is resolved from the current branch, which may be wrong if the user switched
branches or is juggling more than one workstream.

```bash
gh pr view --json number,title,headRefName,url
```

- Check the branch and title match the workstream this conversation is about. If
  the user named a specific PR or feature, confirm it lines up.
- If it looks like a **different workstream**, or no PR exists for the current
  branch, stop and confirm the intended PR with the user before continuing.
- Otherwise proceed.
