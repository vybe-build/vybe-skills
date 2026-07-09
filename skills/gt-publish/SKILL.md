---
name: gt-publish
version: 1.0.0
description: Mark the current branch's already-submitted PR as ready for review (publish it out of draft). Requires the branch to have been submitted first.
allowed-tools: Bash(gh pr view *), Bash(gh pr ready *)
---

# Publish PR

Mark the current branch's PR as ready for review. This is the final step after submitting the branch and writing its PR description — it does not push or create anything.

## Steps

1. Run `gh pr view --json number,isDraft,url` to confirm the current branch has an open PR. If there is no PR, abort and tell the user to submit the branch first (e.g. via `/gt-submit`).
2. If the PR is already published (`isDraft` is `false`), report that and stop — there is nothing to do.
3. Run `gh pr ready` to mark the PR ready for review.
4. Report the PR URL.
