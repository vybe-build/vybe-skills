---
name: gt-sync
version: 1.0.1
description: Sync with trunk (main), restack all branches, and clean up merged branches
allowed-tools: Bash(git status), Bash(gt sync), Bash(gt log *)
---

# Sync with Graphite

Sync all branches with the latest trunk and clean up merged branches.

## Steps

1. Run `git status` to check for uncommitted changes
2. If there are unstaged or staged changes, abort and tell the user to commit or stash their changes first
3. Run `gt sync` to:
   - Pull latest changes into trunk
   - Restack all open PRs on top of new trunk
4. Run `gt log short` to show the updated stack state
5. Report any branches that had conflicts and need manual resolution
