---
name: review-comments-and-fix
version: 1.0.5
description: Fetch unresolved PR review comments and immediately apply fixes for any "Fix now" items. Use when the user says "fix comments", "fix-comments", "review-comments-and-fix", "fix review feedback", "address comments", or wants to skip the triage-and-confirm step and jump straight to applying fixes.
---

# Review Comments and Fix

Fetch unresolved PR review comments and immediately apply fixes for valid concerns.

## Steps

1. Reuse the latest `/review-comments` results from this conversation when they are for the same repository and PR, include the underlying thread IDs, comments, and verdicts, and no intervening activity indicates the review is stale. Honor subsequent operator corrections. When eligible, skip fetching and re-running the analysis. If results are missing, incomplete, for another PR, or stale (for example, a new review round has completed), or the user explicitly requests fresh comments, invoke `/review-comments` instead. If only the target PR is uncertain, verify its identity without fetching comments.
2. For each thread with a **Fix now** verdict, apply the fix directly to the code — do not pause to ask for confirmation
3. Report which threads were fixed and which were skipped (with their verdicts)

## Notes

- The user opted into auto-fix by invoking this skill, so apply fixes without intermediate approval prompts.
- If a Fix Now item is ambiguous, apply the safest interpretation and call it out in the final report.
- Do not commit or push. Suggest `/commit-and-push` and `/update-threads` as natural next steps.
