---
name: graphite
version: 1.0.1
description: Manage stacked PRs using Graphite (gt CLI). Use when implementing multi-part features that should be broken into reviewable chunks, creating PRs, submitting stacks, syncing with trunk, or addressing reviewer feedback. Triggers on requests to "stack PRs", "create a PR", "submit changes", "sync with main", or any code implementation worth breaking into incremental commits.
---

# Graphite Stacked PRs

Graphite (`gt`) manages stacked pull requests—sequences of PRs that build on each other, keeping changes small and reviewable.

## Key Concepts

- **Stack**: PRs linked parent-to-child (e.g., main ← PR1 ← PR2 ← PR3)
- **Trunk**: Base branch stacks merge into (usually `main`)
- **Downstack/Upstack**: Ancestors/descendants of current PR

## Workflow Decision Tree

```
User wants to implement something?
├─ Multiple logical parts → Plan stack structure first, get approval
├─ Single change → Create one branch, submit
└─ Addressing feedback → Use gt modify --commit

Ready to push?
├─ Just this branch + ancestors → gt submit --no-edit
└─ Entire stack → gt submit --stack --no-edit

Need latest from main?
└─ gt sync (pulls trunk, restacks branches, cleans up merged)
```

## Creating Stacks

### 1. Plan the Stack Structure

Before writing code, present the proposed stack to the user:

```
I'll implement this as a stack of N PRs:
1. [branch-name-1] - Brief description of first change
2. [branch-name-2] - Brief description (builds on #1)
3. [branch-name-3] - Brief description (builds on #2)

Should I proceed with this structure?
```

### 2. Implement Each PR

For each PR in the stack:

```bash
# 1. Write the code first (before creating branch)
# 2. Stage changes
git add <files>

# 3. Create branch with commit
gt create --message "type(scope): description"
```

**Commit message format**: Follow conventional commits. The first line becomes the PR title.

Suggest a commit message and allow the user to override before running `gt create`.

### 3. Submit the Stack

```bash
# Submit current branch + all ancestors
gt submit --no-edit

# OR submit entire stack (including upstack)
gt submit --stack --no-edit
```

After submission, provide the PR link for the first PR in the stack.

## Addressing Reviewer Feedback

When making changes to a PR that already exists:

```bash
# Checkout the branch needing changes
gt checkout <branch-name>

# Make edits...
# Stage changes
git add <files>

# Create a NEW commit (not amend) and restack upstack branches
gt modify --commit --message "address review: description"

# Push updates
gt submit --no-edit
```

Always use `--commit` to create explicit feedback commits rather than amending.

## Common Operations

### Sync with Trunk
```bash
gt sync
```
Pulls latest trunk and restacks all open PRs.

### Navigate Stack
```bash
gt up           # Move to child branch
gt down         # Move to parent branch
gt top          # Move to top of stack
gt bottom       # Move to bottom of stack
gt checkout     # Interactive branch picker
```

### View Stack
```bash
gt log          # Show stack with PR status
gt log short    # Compact view (alias: gt ls)
```

### Branch Info
```bash
gt info         # Show current branch: parent, children, commits, PR status
gt info --diff  # Include full diff (scoped to this branch only)
gt info --stat  # Include diffstat (scoped to this branch only)
```

### Restack After Conflicts
```bash
gt restack      # Rebase current stack
```

## Important Notes

- Never use `git commit` or `git push` directly—use `gt create` and `gt submit`
- Write code BEFORE creating the branch so users can review changes first
- Prefer creating new commits over amending when addressing feedback
