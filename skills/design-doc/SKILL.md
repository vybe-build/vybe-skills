---
name: design-doc
version: 1.1.0
description: Write technical design documents for complex features, problems, or architectural decisions. Use when the user asks to "write a design doc", "create a design", "draft a technical design", "design this feature", or when planning a complex feature that calls for a written technical design before implementation.
---

# Design Doc

Write design docs in `docs/designs/` as markdown files. 
Prefix filenames with a date slug in `YYYYMMDD-` format followed by a short kebab-case name (e.g., `docs/designs/20260210-user-authentication.md`).
Capitals can be used for abbreviations (e.g., `VUT` for Vybe User Token).

## Before Writing

1. Read the codebase to understand existing architecture relevant to the design
2. Ask clarifying questions if the problem space is ambiguous
3. Identify security implications early
4. Check any term you're about to introduce against vocabulary the platform already uses.
   Prefer an existing term; if you must coin one, make sure it doesn't collide with a
   user-facing concept or a common infrastructure word.

## Brainstorm Docs

For designs with a wide option space, split the work into two documents:

- A brainstorm doc in `docs/brainstorm/` laying out the option space. It stays
  **solution-agnostic**: present each option's costs and benefits, but do not draw the
  conclusion for the reader. No "Decision:" blocks, no "Chosen"/"Rejected" verdicts in
  comparison tables, no decisions summary. The exception is a hard product requirement
  that rules an option out — say so plainly.
- The design doc in `docs/designs/` records the decisions and links to the brainstorm.

Write the brainstorm to be readable by an engineer without prior context on the feature:
explain each section's problem and background before comparing options.

## Document Structure

Use the following template, adding or removing subsections as the topic demands. Keep the doc brief — brevity increases the chance reviewers actually read it.

```markdown
# [Feature/Topic Name]

## Overview

[1-3 sentences describing the design at a very high level.]

## Problem Statement

[What are we trying to achieve, centered on value delivered to users. Not implementation-focused.]

## Solution

### Functionality

[How the end user interacts with the feature. No implementation details — describe behavior, flows, and user-facing outcomes only.]

### Design

[Technical approach for implementation. High level — no code snippets (they become immediately stale and duplicate the implementation). Use pseudocode sparingly only when needed to convey a specific point. Use Mermaid diagrams where helpful.]

### Security

[Security implications of this design and how they are mitigated.]

## Open Questions

[Add when useful. Anything deliberately unresolved, with enough specificity that the
reader knows what would settle it. Distinguish "deferred to another project" from
"genuinely undecided".]

## Decision Log

[Add when useful. Records decisions a human explicitly made during the design process,
and the reasoning behind each one where it is known. A decision may be a choice ("use X")
or a ruling-out ("X is out of scope", "we are not doing Y") — record either as the
decision itself. Table of Decision | Why. Add a third column for what a choice rules out
only when the ruled-out option would otherwise keep resurfacing in review. Keep each
entry to a clause or two; state the reasoning, don't re-argue it.]
```

## Writing Guidelines

- **Present tense.** Readers will on average read this after implementation is complete.
- **Mermaid for diagrams.** Readable by both humans and AI. Use sequence diagrams for flows, entity-relationship diagrams for data models, flowcharts for decision logic.
- **No code snippets.** They are immediately stale and duplicate the implementation. Use pseudocode sparingly if needed.
- **Functionality has zero implementation details.** Describe what the user sees and does, not how it works under the hood.
- **Design stays high level.** Describe the technical approach, not the line-by-line implementation.
- **Brief but sufficient.** Cover the topic in enough depth to catch design issues, but no more.
- **Add subsections as needed.** The template sections are a starting point — add subsections (e.g., Data Model, API Changes, Migration Strategy) when the topic requires them.
- **No filler.** Every sentence must explain something or lead the reader from one
  concept to the next. Cut value judgments about the design's own choices ("X is worth
  more than Y", "that is the whole of the claim here"). Colorful section leads should be
  replaced by ones that state what the paragraph covers.
- **No phantom alternatives.** Never describe what was removed ("there is no event
  journal behind them") or dangle a cut option as a future possibility ("a journal could
  be added later"). Each mention makes the reviewer picture the thing, evaluate it, and
  conclude nothing. Cut every trace. Contrast IS fine when it points at something the
  reader knows exists ("a simple web server rather than Next.js"). The option space
  belongs in the brainstorm doc; a decision log entry may name what a decision rules out
  when that is worth recording. Nowhere else.
- **No meta-commentary about the document.** Don't record how it was built, what an
  earlier draft said, or what sources it synthesizes. State current thinking only.
- **No time estimates.** Relative effort and complexity are fine; engineer-weeks and
  calendar ranges are not.
- **Introduce a thing before any property of it.** The first sentence a reader meets
  about a table, component, or concept should say what it is, not how it behaves under
  some edge case.

## Revising After Review

When applying review feedback, fold the content into the section while preserving that
section's existing purpose. Do not let a reviewer's comment become the section's new
thesis.

Symptoms to check for after each round:
- A section reorganized around whatever the last comment emphasized (e.g. a comment
  asking to show component placement in a diagram turning the whole section into a
  piece about component placement, when the diagram is an overview of the process).
- Sentences arguing against a previous draft the reviewer never saw — after removing
  something, prose that defends its absence ("not a component built for X", "the
  response is not redacted").
- Answers to review questions left inline where an explanation should be. Most review
  comments do not warrant an explanation in the design.

## After Writing

Confirm with the user that the doc is ready, and offer to create a PR for review.
