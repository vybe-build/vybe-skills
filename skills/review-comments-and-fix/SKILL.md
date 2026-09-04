---
name: review-comments-and-fix
version: 1.0.3
description: Fetch unresolved PR review comments and immediately apply fixes for any "Fix now" items. Use when the user says "fix comments", "fix-comments", "review-comments-and-fix", "fix review feedback", "address comments", or wants to skip the triage-and-confirm step and jump straight to applying fixes.
---

# Review Comments and Fix

Fetch unresolved PR review comments and immediately apply fixes for valid concerns.

## Steps

1. Invoke the `/review-comments` skill to fetch and analyze unresolved threads
2. For each thread with a **Fix now** verdict, apply the fix directly to the code — do not pause to ask for confirmation
3. Report which threads were fixed and which were skipped (with their verdicts)

## Notes

- The user opted into auto-fix by invoking this skill, so apply fixes without intermediate approval prompts.
- If a Fix Now item is ambiguous, apply the safest interpretation and call it out in the final report.
- Do not commit or push. Suggest `/commit-and-push` and `/update-and-resolve-threads` as natural next steps.
