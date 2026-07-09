---
name: gt-create-publish
version: 1.0.0
description: Create a new stacked branch, submit it as a draft PR with a description, then publish it (mark ready for review)
allowed-tools: Bash(git status), Bash(git diff *), Bash(git add *), Bash(gt create *), Bash(gt sync), Bash(gt log *), Bash(gt submit --draft --no-edit), Bash(gt info *), Bash(gh pr view *), Bash(gh pr edit *), Bash(gh pr diff *), Bash(gh pr ready *)
---

# Create and Publish

Create a new stacked branch, submit it as a **draft** PR, fill in the description, then publish it (mark ready for review). Drafting first keeps reviewers from being pinged before the PR is described.

## Steps

1. Invoke the `/gt-create` skill
2. Invoke the `/gt-submit` skill (creates the draft PR and writes its description)
3. Invoke the `/gt-publish` skill to mark the current branch's PR ready for review
