---
name: design-doc
version: 1.0.1
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
```

## Writing Guidelines

- **Present tense.** Readers will on average read this after implementation is complete.
- **Mermaid for diagrams.** Readable by both humans and AI. Use sequence diagrams for flows, entity-relationship diagrams for data models, flowcharts for decision logic.
- **No code snippets.** They are immediately stale and duplicate the implementation. Use pseudocode sparingly if needed.
- **Functionality has zero implementation details.** Describe what the user sees and does, not how it works under the hood.
- **Design stays high level.** Describe the technical approach, not the line-by-line implementation.
- **Brief but sufficient.** Cover the topic in enough depth to catch design issues, but no more.
- **Add subsections as needed.** The template sections are a starting point — add subsections (e.g., Data Model, API Changes, Migration Strategy) when the topic requires them.

## After Writing

Confirm with the user that the doc is ready, and offer to create a PR for review.
