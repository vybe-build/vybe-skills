---
name: auto-loop-n
version: 1.0.0
description: Run N automated PR review rounds back-to-back — each round waits for reviews, fixes and resolves comments, and re-requests review. Use when the user says "auto-loop", "loop N times", "run 3 review rounds", or wants the wait/fix/review cycle repeated a set number of times.
---

# Auto Loop N

Repeat the wait → fix → re-review cycle up to **N** times on the current PR.

## N

`N` is the number of rounds, taken from the user's request (e.g.
"auto-loop-n 3" → `N = 3`). If the user did not specify a number, ask for one
before starting.

## Loop

For each round `i` from 1 to `N`:

1. Announce the round: **"Round i of N"**.
2. Follow the `/auto-wait-fix-review` skill.
3. Decide whether to keep going. **Stop the loop early** if that round reported
   any of:
   - a **timeout** waiting for reviews,
   - a **lookup error** (no PR / `gh` not authenticated), or
   - **convergence** — no comments were left to fix.

   Otherwise continue to the next round.

## Report

When the loop ends (whether `N` rounds completed or it stopped early),
summarize: how many rounds ran, how many comments were addressed across all
rounds, why it stopped, and the final state (converged / open items remain /
timed out).

## Notes

- Each round re-requests reviews at its end, so the next round's wait has fresh
  trigger comments to watch for.
- This is an **agent-driven** loop: each round requires judgment (triaging and
  fixing comments), so the agent stays in the loop across rounds. Only the
  waiting *within* a round is delegated to the `/wait-for-reviews` script, which
  polls programmatically.
