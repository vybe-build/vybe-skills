---
name: review-pr
version: 1.1.1
description: Deep multi-dimensional code review for a pull request
allowed-tools: Bash(gh issue view:*), Bash(gh search:*), Bash(gh issue list:*), Bash(gh pr comment:*), Bash(gh pr diff:*), Bash(gh pr view:*), Bash(gh pr list:*), Bash(gh api:*), Bash(bash *.claude/skills/review-pr/scripts/*), Bash(echo *), Bash(date *), Bash(jq *), Bash(git fetch *), Bash(git show *), Bash(git diff *), Bash(git log *), Bash(git branch --list *), Write(.claude-scratch/*), Write(/.claude-scratch/*), Write(//**/.claude-scratch/*)
---

Provide a deep, multi-dimensional code review for the given pull request.

Follow these steps precisely:

0. **Signal that the review is starting.** Check if a `--trigger-comment-id=` argument was passed in the prompt. Parse the value after the `=` sign. If it is non-empty, react with 👀 to acknowledge the request:

   ```bash
   bash <skill-path>/scripts/react-to-comment.sh "<COMMENT_ID>" eyes
   ```

   Save the comment ID for use in the final step. If no `--trigger-comment-id` was provided or the value is empty (e.g. the review was triggered by a PR open event), skip this step.

1. Use a Haiku agent to check if the pull request (a) is closed or (b) does not need a code review (eg. because it is an automated pull request, or is very simple and obviously ok). If so, do not proceed.
- Note: re-reviews are allowed. Draft PRs are allowed.

2. Use another Haiku agent to give you a list of file paths to (but not the contents of) any relevant CLAUDE.md files from the codebase: the root CLAUDE.md file (if one exists), as well as any CLAUDE.md files in the directories whose files the pull request modified.

3. **Gather PR context.** Run these three in parallel:

   a. Use a Haiku agent to view the pull request (`gh pr view ... --json title,body,author,baseRefName,headRefName,commits,files`) and return a summary of the PR metadata. Do NOT have this agent fetch the diff — the diff is fetched separately below.

   b. Fetch all existing review threads (resolved and unresolved) on the PR:

      ```bash
      bash <skill-path>/scripts/fetch-review-threads.sh <PR_NUMBER>
      ```

      This returns a compact JSON array with each thread's file, line, resolution status, and a summary of the initial comment. Pass this to the review agents in step 4 so they can avoid re-raising issues that have already been discussed or resolved.

   c. Fetch the PR diff to a file:

      ```bash
      bash <skill-path>/scripts/fetch-pr-diff.sh <PR_NUMBER> .claude-scratch/pr-diff.txt
      ```

4. Launch **all 8** review agents in a **single parallel call**. Each agent's prompt should include the PR summary (from step 3a), list of CLAUDE.md files (from step 2), existing review threads (from step 3b), and the instruction to read the diff from `.claude-scratch/pr-diff.txt` using the Read tool. Each agent MUST return:
   - A score from 0 to 5 for their category (0 = catastrophic, 5 = perfect)
   - A list of findings, each marked as either 🚫 BLOCKING or ⚠️ NON-BLOCKING
   - For each finding: brief justification with specific file path and line number references
   - For each finding: one or more **suggested fixes or remediations** — concrete, actionable steps the author can take to resolve the issue (e.g. code snippets, API changes, configuration adjustments). If multiple valid approaches exist, list them as alternatives
   - For each finding: whether it is a **line-level** finding (tied to a specific line in the diff) or a **file-level** finding (about the file as a whole, or about a line outside the diff region)
   - Any additional issues noticed outside their checklist

   The 8 agents are:

   a. **🔒 Security (a.k.a. Sentinel)**: Audit for XSS, injection (SQL/command/path traversal), auth bypass, missing permission checks (`withAuth`/`withApp`/`checkPermission`), secrets or credentials in code, CORS/CSRF issues, insecure dependencies, information leakage in error messages or logs, and any OWASP Top 10 violations. **Bugs:** logic flaws that could be exploited (e.g. inverted permission checks, missing authorization on branching paths, TOCTOU races). Flag anything else security-relevant you notice.

   b. **🚨 Error Handling (a.k.a. Failsafe)**: Check for unhandled promise rejections, missing try/catch in async functions, generic catch-all handlers that swallow errors, missing `logger` usage (using `console.log` instead), wrong HTTP status codes, silent failures (empty catch blocks), missing Zod validation on API inputs, and error messages that expose internal details. **Observability:** missing `logger.exception()` on caught errors, empty catch blocks with no logging or tracing, errors that would be invisible in production, missing spans around error-prone operations, failure modes that can't be diagnosed from logs alone. **Bugs:** null/undefined access on error paths, catch blocks that re-throw the wrong error, error handlers that corrupt state. Flag anything else error-handling-relevant you notice.

   c. **⚡ Performance (a.k.a. Nitro)**: Check for N+1 queries, missing database indexes, unnecessary React re-renders (missing memoization, unstable references in deps), large bundle imports that should be lazy-loaded or tree-shaken, missing pagination on list endpoints, memory leaks (unremoved event listeners, unclosed subscriptions), blocking operations on hot paths, missing caching opportunities, and inefficient algorithms. **Observability:** missing OpenTelemetry spans on DB queries or external API calls (see `src/lib-server/otel.ts`), operations that would be hard to profile without instrumentation, missing tracing on slow paths. **Bugs:** race conditions, infinite loops/re-renders, stale closures capturing outdated values, async operations that never resolve. Flag anything else performance-relevant you notice.

   d. **🧹 Code Hygiene (a.k.a. Surgeon)**: Check for DRY violations, single-responsibility principle violations, files exceeding 300 lines, functions exceeding 50 lines, unclear naming, circular dependencies, layer violations (client importing from server or vice versa), magic numbers/strings, deeply nested logic (>3 levels), poor modularization, and DDD boundary violations. **Bugs:** off-by-one errors, wrong boolean logic or inverted conditions, incorrect equality checks (== vs ===), missing early returns, copy-paste errors where values weren't updated. Flag anything else code-quality-relevant you notice.

   e. **🧪 Test Quality (a.k.a. Chemist)**: Verify tests exist for new features/logic, edge cases are covered, mocks use shared factories from `test/mocks/` per CLAUDE.md (not inline `jest.mock()` factories for logger/access/prisma/otel), assertions are meaningful (not just `toBeDefined`), tests are isolated, test names clearly describe behavior, integration tests exist for API routes, and pure functions are NOT over-mocked. **Bugs:** tests that pass but don't actually verify the behavior they claim to (e.g. asserting on mock return values instead of real logic), tests that would still pass if the feature broke. Flag anything else test-quality-relevant you notice.

   f. **🎨 Design System & UI/UX (a.k.a. Pixel)**: Check that project color tokens are used (no raw Tailwind colors like `gray`, `slate`, `red`), project typography classes are used (no default `text-sm`, `text-lg`, etc.), no `dark:` variants (semantic tokens handle dark mode), no opacity modifiers on colors (`bg-primary/50`), responsive design considered, accessibility (aria attributes, keyboard navigation), consistency with existing UI patterns, and no hardcoded inline styles. Flag anything else UI/UX-relevant you notice. Only apply this agent's checks to files that contain JSX/TSX markup — skip pure logic files.

   g. **📋 CLAUDE.md Compliance (a.k.a. Sheriff)**: Verify all rules from the root and directory-level CLAUDE.md files are followed: file/directory naming (kebab-case), component naming (PascalCase), hook naming (camelCase with `use` prefix), constants (UPPER_SNAKE_CASE), auth wrappers on API routes, `logger` instead of `console.log`, tracing consideration, error handling with Zod + proper HTTP status codes, comment style (minimal, only when non-obvious), shared types (no duplication between client/server), testing requirements met, color/typography system used, and Graphite conventions followed. Flag anything else CLAUDE.md-relevant you notice.

   h. **💀 Dead Code (a.k.a. Reaper)**: Hunt for code introduced or left behind by this PR that is never reached or used. Focus on the cross-module and semantic cases a linter/typechecker won't catch: exports that nothing imports, functions/components/hooks/constants defined but never referenced anywhere in the codebase, unreachable code after `return`/`throw`/`break`, branches that can never execute (dead conditionals, feature flags that are now always-on or always-off), commented-out code blocks, orphaned files no longer imported by anything, leftover scaffolding or debug code, and symbols referenced only by their own (now-removed) call sites. Also flag dead dependencies added to `package.json` but never used, and exports kept "just in case" with no consumer. **Bugs:** a "dead" branch that is actually reachable (indicating an upstream logic error), or removed code whose remaining references will break. When uncertain whether a symbol is truly unused, search the codebase before flagging — public API surface and entrypoints may be intentionally unreferenced internally. Flag anything else dead-code-relevant you notice.

5. Use a Haiku agent to repeat the eligibility check from step 1 (closed or automated/trivial), to make sure the pull request is still eligible for code review.

6. Synthesize all agent results into the output format below. Calculate the overall score as the simple average of all 8 category scores. Apply verdict logic: 🚫 DO NOT MERGE if ANY 🚫 BLOCKING issue exists across any category. ✅ READY TO MERGE otherwise.

7. Post the review using the helper scripts:

   a. **Write findings to a JSON file.** Create `.claude-scratch/review-comments.json` with an array of comment objects. Each finding with a specific file path becomes a comment:

      ```json
      [
        {
          "type": "line",
          "path": "src/foo/bar.ts",
          "line": 42,
          "side": "RIGHT",
          "body": "🚫 **[Security]** Description of finding\n\n**Suggested fix:** Concrete remediation steps..."
        },
        {
          "type": "file",
          "path": "src/baz.ts",
          "body": "⚠️ **[Test Quality]** This file has no test coverage for the new helper functions.\n\n**Suggested fix:** Add unit tests for `parseConfig` and `validateInput`."
        }
      ]
      ```

      Rules for constructing comments:
      - `path` must be relative to repo root, no leading `/`
      - Use `"type": "line"` when the finding is about a specific line the author changed in the diff
      - Use `"type": "file"` when the finding is about the file as a whole (e.g., missing test coverage, architectural concern, file too long, naming convention) or about a line outside the diff region
      - `line` is the line number in the **new** version of the file (for additions/modifications). Only needed for `"type": "line"`
      - `side` defaults to `"RIGHT"` (new file). Use `"LEFT"` only when commenting on a deleted line
      - `body` should include the severity emoji (`🚫` or `⚠️`), category in bold brackets, description, and suggested fix
      - Keep inline comment bodies concise — the full detail is in the summary

   b. **Post inline and file-level comments.** Run:

      ```bash
      bash <skill-path>/scripts/post-review-comments.sh <PR_NUMBER> .claude-scratch/review-comments.json
      ```

      Capture the JSON output. The script automatically:
      - Validates line-level comments against the diff
      - Demotes comments with invalid line numbers to file-level (they still get posted on the file)
      - Skips comments whose file isn't in the diff at all
      - Returns `{ "line_posted": N, "file_posted": N, "skipped": N, "skipped_details": [...] }`

   c. **Write and post the summary comment.** Write the scorecard to `.claude-scratch/review-summary.md` using the format below. Replace the `YYYY-MM-DD HH:MM UTC` timestamp placeholder with the current UTC time (get it via `date -u '+%Y-%m-%d %H:%M UTC'`). If any findings were skipped (from the `skipped_details` in step 7b), append them under an "Additional Findings" section in the summary so they are not lost. Then run:

      ```bash
      bash <skill-path>/scripts/post-summary-comment.sh <PR_NUMBER> .claude-scratch/review-summary.md
      ```

   d. **Fallback.** If the inline comment script fails entirely (non-zero exit), include ALL findings in the summary comment body instead.

   e. **React to indicate completion.** If a trigger comment ID was parsed in step 0, react to signal the outcome:
      - On success (summary posted): `bash <skill-path>/scripts/react-to-comment.sh "<COMMENT_ID>" "+1"`
      - On failure (could not post summary): `bash <skill-path>/scripts/react-to-comment.sh "<COMMENT_ID>" "-1"`

Examples of false positives — avoid flagging these in step 4:

- Issues that were already raised in a prior review thread (from step 3b) — whether resolved or still open. Do not re-raise these unless the code has materially changed since the thread was created

- Pre-existing issues (problems that existed before this PR)
- Something that looks like a bug but is not actually a bug
- Pedantic nitpicks that a senior engineer wouldn't call out
- Issues that a linter, typechecker, or compiler would catch (eg. missing or incorrect imports, type errors, broken tests, formatting issues, pedantic style issues like newlines). No need to run these build steps yourself — it is safe to assume that they will be run separately as part of CI.
- General code quality issues (eg. lack of test coverage, general security issues, poor documentation), unless explicitly required in CLAUDE.md
- Issues that are called out in CLAUDE.md, but explicitly silenced in the code (eg. due to a lint ignore comment)
- Changes in functionality that are likely intentional or are directly related to the broader change
- Real issues, but on lines that the user did not modify in their pull request

Notes:

- Do not check build signal or attempt to build or typecheck the app. These will run separately, and are not relevant to your code review.
- Always use `gh` CLI commands (`gh pr comment`, `gh api`) to interact with GitHub — never use MCP tools or web fetch, as they are unreliable in CI environments.
- Make a todo list first.
- You must cite and link each finding (eg. if referring to a CLAUDE.md, you must link it).
- When linking to code, follow this format precisely, otherwise the Markdown preview won't render correctly: https://github.com/anthropics/claude-cli-internal/blob/c21d3c10bc8e898b7ac1a2d745bdc9bc4e423afe/package.json#L10-L15
  - Requires full git sha (not abbreviated)
  - You must provide the full sha. Commands like `https://github.com/owner/repo/blob/$(git rev-parse HEAD)/foo/bar` will not work, since your comment will be directly rendered in Markdown.
  - Repo name must match the repo you're code reviewing
  - `#` sign after the file name
  - Line range format is `L[start]-L[end]`
  - Provide at least 1 line of context before and after, centered on the line you are commenting about

For the top-level PR comment, use this format precisely:

---

### 🔍 Code Review

#### 🚦 Verdict: ✅ READY TO MERGE / 🚫 DO NOT MERGE

**Overall Score: X.X/5**

| Category | Score | Status |
|---|---|---|
| 🔒 Security | X/5 | ✅ / 🚫 N blocking |
| ⚡ Performance | X/5 | ✅ / ⚠️ N non-blocking |
| 🚨 Error Handling | X/5 | ✅ / ... |
| 🧹 Code Hygiene | X/5 | ✅ / ... |
| 🧪 Tests | X/5 | ✅ / ... |
| 🎨 Design System | X/5 | ✅ / ... |
| 📋 CLAUDE.md | X/5 | ✅ / ... |
| 💀 Dead Code | X/5 | ✅ / ... |

---

#### 🚫 Blocking Issues (N total)

1. **[Category]** Description of the issue
   [link to file and line with full sha]
   **Suggested fix:** Concrete remediation step(s) the author can take to resolve this issue.

---

#### ⚠️ Non-blocking Suggestions (N total)

1. **[Category]** Description of the suggestion
   [link to file and line with full sha]
   **Suggested fix:** Concrete remediation step(s) or alternative approaches.

---

#### 📎 Additional Findings

_These findings could not be posted as inline comments (file not in diff). Included here for completeness._

1. **[Category]** Description
   **File:** `path/to/file.ts`
   **Suggested fix:** ...

---

🤖 Generated with [Claude Code](https://claude.ai/code) · <sub>Last updated: <!-- timestamp -->YYYY-MM-DD HH:MM UTC<!-- /timestamp --></sub>

<sub>If this code review was useful, please react with 👍. Otherwise, react with 👎.</sub>

---

Or, if no issues found at all:

---

### 🔍 Code Review

#### 🚦 Verdict: ✅ READY TO MERGE

**Overall Score: 5.0/5**

| Category | Score | Status |
|---|---|---|
| 🔒 Security | 5/5 | ✅ |
| ⚡ Performance | 5/5 | ✅ |
| 🚨 Error Handling | 5/5 | ✅ |
| 🧹 Code Hygiene | 5/5 | ✅ |
| 🧪 Tests | 5/5 | ✅ |
| 🎨 Design System | 5/5 | ✅ |
| 📋 CLAUDE.md | 5/5 | ✅ |
| 💀 Dead Code | 5/5 | ✅ |

No issues found. Deep review across security, performance, error handling, code hygiene, tests, design system, CLAUDE.md compliance, and dead code.

🤖 Generated with [Claude Code](https://claude.ai/code) · <sub>Last updated: <!-- timestamp -->YYYY-MM-DD HH:MM UTC<!-- /timestamp --></sub>

<sub>If this code review was useful, please react with 👍. Otherwise, react with 👎.</sub>

---
