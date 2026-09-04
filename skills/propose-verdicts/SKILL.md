---
name: propose-verdicts
version: 0.1.0
description: Post proposed verdicts and reasoning as replies on unresolved PR review threads without resolving them, so the operator can review each decision alongside the code. Use when the user says "propose verdicts", "post proposed verdicts", or wants PR-comment triage published for review before threads are finalized.
---

# Propose Verdicts

Invoke `update-threads` in **proposal** mode with **all unresolved threads** selected. This publishes the `review-comments` verdict and reasoning beside each code thread while leaving every thread unresolved for operator review.

If the user explicitly requests only certain threads, pass that selection through unchanged. Do not finalize verdicts, resolve threads, or change code.
