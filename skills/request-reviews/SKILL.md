---
name: request-reviews
version: 2.0.0
description: Request (re-)review on the current PR using the repo's own documented procedure, asking the user when none is documented. Use when the user says "request reviews", "re-review", "trigger reviews", or wants reviewers to look at the PR again.
allowed-tools: Bash(bash *.claude/skills/request-reviews/scripts/*), Bash(gh pr view *)
---

# Request Reviews

Request review on the current branch's PR using this repo's procedure. No
reviewers or triggers are built in.

## Workflow

1. Get the PR number with `gh pr view --json number --jq '.number'`. If there
   is no PR, report that and stop. If the PR looks like it belongs to a
   different workstream than this conversation, flag it to the user.

2. Find the repo's review-request procedure, stopping at the first source that
   states it:
   1. This conversation (the user said so, or an earlier run established it).
   2. Loaded instructions and memory (`CLAUDE.md`, `AGENTS.md`, etc.).
   3. Repo docs: `CONTRIBUTING.md`, `README.md`, the `.github/` PR template,
      `docs/`.

   Do not infer it from past PR comments, installed apps, or CI workflows.

3. If it is missing or ambiguous, ask the user and post nothing until they
   answer. Then offer to save the answer to memory or the repo's agent
   instructions.

4. Carry it out. Post trigger comments with the script, one argument each; run
   anything else (reviewers, labels, a repo command) as the procedure states.

```bash
bash <skill-path>/scripts/post-review-triggers.sh <PR_NUMBER> '<trigger>' ['<trigger>' ...]
```

5. Report what was posted or done.
