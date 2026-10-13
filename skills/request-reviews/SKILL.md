---
name: request-reviews
version: 2.0.0
description: Request (re-)review on the current PR using the repo's own documented procedure, asking the user when none is documented. Use when the user says "request reviews", "re-review", "trigger reviews", or wants reviewers to look at the PR again.
allowed-tools: Bash(bash *.claude/skills/request-reviews/scripts/*), Bash(gh pr view *)
---

# Request Reviews

Ask reviewers to look at the current branch's PR again, using whatever
procedure this repo uses. The skill carries no reviewers or trigger phrases of
its own — they come from the repo's docs, memory, or the user.

## Workflow

1. Get the current PR number:

```bash
gh pr view --json number --jq '.number'
```

If there is no PR for the current branch, report that and stop.

2. Verify the resolved PR is the one intended for this conversation (if that
   context is available), and flag it to the user if it looks like it's for a
   different workstream.

3. Find this repo's review-request procedure. Check, in order, and stop at the
   first source that states it:

   1. **This conversation** — the user already said how to request reviews, or
      an earlier run of this skill already established it. Reuse it.
   2. **Loaded instructions and memory** — agent instruction files
      (`CLAUDE.md`, `AGENTS.md`, and the like) and any memory entries for this
      repo.
   3. **Repo docs** — `CONTRIBUTING.md`, `README.md`, the PR template under
      `.github/`, and review or contributing pages under `docs/`.

   A procedure counts only if it says what to do: comments to post (e.g. a
   slash command or a bot mention), reviewers or teams to request, a label to
   add, or a command to run. Do not infer one from past PR comments, installed
   apps, CI workflow files, or what other repos do.

4. If no procedure was found, or the one found is ambiguous, ask the user how
   reviews are requested in this repo and wait for the answer — do not guess
   and do not post anything. Once they answer, offer to save it (to memory, or
   to the repo's agent instructions file) so later runs find it in step 3.

5. Carry out the procedure against the PR from step 1.

   - **Trigger comments** — post them with the script, one argument per
     comment:

     ```bash
     bash <skill-path>/scripts/post-review-triggers.sh <PR_NUMBER> '<trigger>' ['<trigger>' ...]
     ```

   - **Anything else** (requesting reviewers, adding a label, running a repo
     command) — run exactly what the procedure specifies.

6. Report what was done: each comment posted or action taken, and where the
   procedure came from (which doc, memory, or the user).
