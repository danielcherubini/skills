---
name: review
description: |
  Use when reviewing pull requests, PRs, code changes, or code quality.
  Covers architecture reviews, security audits, mentoring through review feedback,
  and establishing review standards. Triggers on: "review", "code review", "PR review",
  "check this code", "audit", "security review".
---

# Review

Run a code review on the current local branch, fix all actionable findings, and re-review until clean — all in a loop before opening a PR.

## Overview

This skill runs an iterative review loop. Each iteration: dispatch reviewer → parse findings → fix all actionable items → re-review. The loop exits when there are zero actionable findings, max iterations are reached, or the review command fails. After the loop, the skill asks whether to **Open a PR** (using the implement skill's PR logic) or **Merge to main** (using the finish skill).

## When to Use

- After `implement` tasks are complete and the user selects "Review loop"
- When the user says "review loop", "looped review", "fix all review issues"
- When the user wants a thorough code review with automatic fixes before opening a PR

**Not for:** reviewing an already-open PR on GitHub (use `gh pr review`), debugging a specific bug (use `systematic-debugging`), quick sanity check on a single file (inline review is fine)

## Architecture — Read This First

```
Main agent (YOU — running this skill)
  ├── Phase 1: Dispatch explore subagent(s) for context gathering
  │     ├── explore: gather files, diff, related code, CI status  ← pure leaf
  │     └── (optional) explore: additional angles (tests, docs)  ← pure leaf
  ├── Phase 2: Synthesize context → classify change, determine scope
  ├── Phase 3: Dispatch reviewer subagent with enriched brief
  │     └── reviewer: reads code, runs checks, returns report     ← pure leaf
  ├── Phase 4: Parse findings — classify actionable vs informational
  ├── Phase 5: Fix findings — dispatch general subagent to fix each actionable item
  ├── Phase 6: Re-run review — loop back to Phase 3 if findings remain
  ├── Phase 7: Exit conditions met — present summary
  └── Phase 8: Final ask() — Open a PR or Merge to main
```

**You (the main agent) own all orchestration AND all user interaction.** Three subagent types, all pure leaves:

1. **explore** — gathers context: files to review, diffs, related code, test coverage, CI status, docs. Returns a concise context brief.
2. **reviewer** — receives the context brief + review scope from the main agent. Reads code, runs lint/test commands, performs analysis, returns a categorized report.
3. **general** — dispatched in Phase 5 to fix actionable findings. Applies fixes and returns summaries.

**Subagents never interact with the user.** The reviewer returns findings as a report. The general subagent applies fixes. Only the main agent calls `ask()` — and only once at the end (Phase 8).

## Workflow

### Phase 1: Dispatch explore subagent(s)

Use `subagent` with `agent: "explore"` to gather context. Dispatch one or more in parallel:

```
subagent({
  agent: "explore",
  task: "Gather review context for the current branch. Find all changed files, " +
        "related imports/callers, test coverage, and any CI/lint status. " +
        "Return a concise brief: files, scope, languages, and risk areas."
})
```

For large changes, dispatch multiple explore subagents in parallel:
- One for the changed files and their dependencies
- One for tests and CI status
- One for docs and related ADRs/plans

### Phase 2: Synthesize and classify

The main agent collects all explore results, classifies the change (bug fix, feature, refactor, security), determines review depth, and identifies focus areas.

### Phase 3: Dispatch reviewer subagent

Use `subagent` with `agent: "reviewer"` and pass the synthesized context:

```
subagent({
  agent: "reviewer",
  task: "Review the following for [scope]: [files/context from explore]. " +
        "Change type: [classification]. Depth: [quick/standard/deep]. " +
        "Focus areas: [correctness, security, perf, etc.]. " +
        "Follow the review skill reviewer checklist. " +
        "Consult [language] guide. Return a report categorized by severity. " +
        "Do NOT call ask() — just return the report."
})
```

The reviewer subagent **returns a report only** — it never calls `ask()` and never fixes code.

### Phase 4: Parse Findings

Parse the reviewer's report and classify each finding:

| Type | Description | Action |
|------|-------------|--------|
| **Actionable** | 🔴 Blocking or 🟡 Important — code change needed | Fix in Phase 5 |
| **Nit** | 🟢 Nice to have, not blocking | Fix in Phase 5 (auto-fix all) |
| **Informational** | 💡 Suggestion, 📚 Learning, or 🎉 Praise | Note but don't fix |

If there are **zero actionable findings** (no 🔴, 🟡, or 🟢), skip to Phase 7 (exit condition met).

### Phase 5: Fix Findings

> ⚠️ **DISPATCH GUARD — READ BEFORE FIXING EACH FINDING**
>
> - **You MUST dispatch a `general` subagent for each actionable finding.**
> - **DO NOT fix code, edit files, or stage changes directly in your own context.**
> - If you skip dispatch, you forfeit the isolation and accountability that the subagent provides.
> - The main agent owns orchestration only — fix application is delegated.

#### Per-Finding Sequence (follow rigidly for every actionable finding)

**Step 1 — STOP & Verify.**
Before touching anything, confirm:
- [ ] This is an actionable finding from the current review output
- [ ] No fix has been applied yet in this context
- [ ] You are about to dispatch a `general` subagent (not fix the code yourself)

**Step 2 — Dispatch the subagent.**

> **DO NOT add a `model` parameter to any subagent call.** The agent definition controls its own model. Adding `model` causes hallucinated model names that break the call.

```
/// ───────────────────────────────────────────────────────────
///  MANDATORY: dispatch a `general` subagent to fix this finding.
///  DO NOT edit files or stage changes in your own context.
/// ───────────────────────────────────────────────────────────
subagent({
  agent: "general",
  task: "Fix the following review findings on the local branch. For each finding: read the file, understand the issue, make the fix, and stage the change with git add. Findings: [list with file paths, severity, and descriptions]. Return a summary of what was changed.",
  description: "Fix review finding: [short summary]"
})
```

The `general` subagent (not `reviewer`) is the correct dispatch target for applying code fixes — it is the same agent the `implement` skill uses for task execution. The `reviewer` subagent is prohibited from making changes and only returns reports.

**Step 3 — Verify dispatch happened.**
After the `subagent()` call returns, confirm the subagent actually performed the fix:
- [ ] The response includes file edits or `git add` from the subagent
- [ ] You did NOT edit files or stage changes in your own context
- [ ] If you find yourself having fixed code inline, stop and re-dispatch the subagent immediately

> 🔁 **If you catch yourself fixing code inline instead of dispatching — stop, reset, and dispatch the subagent.** This is the #1 failure mode of this skill; do not let it happen.

### Phase 6: Re-run Review (Loop)

After all fixes from Phase 5 are applied:

1. Go back to Phase 3 (dispatch reviewer again with updated code)
2. Parse new findings (Phase 4)
3. If new actionable findings exist, fix them (Phase 5)
4. Repeat

**Loop guard:** Max 5 iterations to avoid runaway loops. Each iteration is one full cycle of Phase 3 → Phase 4 → Phase 5.

### Phase 7: Exit Conditions

Stop the loop if **any** of these are true:

| Condition | Behavior |
|-----------|----------|
| Zero actionable findings (no 🔴, 🟡, or 🟢) | Exit loop, present summary, go to Phase 8 |
| Max 5 iterations reached | Exit loop, report remaining findings, go to Phase 8 |
| Review fails catastrophically | Report the failure, go to Phase 8 |

### Phase 8: Final Ask

After the loop exits, present a summary and ask:

```
ask({
  questions: [{
    id: "final-action",
    question: "Review loop complete. X findings resolved, Y remaining. What would you like to do?",
    options: [
      { label: "Open a PR" },
      { label: "Merge to main" }
    ],
    description: "**Summary:**\n- Iterations: N\n- Findings resolved: X\n- Remaining: Y (all informational/suggestions)\n\n**Note:** 'Open a PR' pushes the branch and creates a PR. 'Merge to main' uses the finish skill to merge and sync."
  }]
})
```

- **Open a PR** → Push the branch and open a PR:
  ```bash
  git push -u origin [branch-name]
  gh pr create --title "[title]" --body "$(cat <<'EOF'
  ## Summary
  - [bullets]

  ## Test plan
  - [ ] [verification steps]
  EOF
  )"
  ```
  Report the PR URL to the user.

- **Merge to main** → Load the `finish` skill directly (no PR needed — the finish skill handles both PR and direct-merge paths):
  1. Push the branch: `git push -u origin [branch-name]`
  2. Load the `finish` skill and run its full pipeline:
     - The finish skill checks whether a PR exists for the branch
     - If no PR → runs local validation gate and squash-merges directly onto main
     - If PR exists → checks reviews/CI/mergeability then merges via GitHub

### When to use subagents vs. review inline

| Scenario | Approach |
|---|---|
| Single file, < 100 lines, trivial change | Inline review (no subagents) |
| Multiple files or > 100 lines | **explore → reviewer → fix loop** pipeline |
| Cross-cutting concern (security, perf, architecture) | **explore → reviewer** with focused scope |
| User says "review" without specifics | **explore → reviewer → fix loop** pipeline |
| Large change (> 400 lines) | **Multiple explore** in parallel → **reviewer → fix loop** |

## Integration with Implement Skill

The `implement` skill's "After All Tasks Complete" section includes:

```
{ label: "Review loop" }
```

When selected:
1. Load the `review` skill
2. Run it to completion (Phases 1–7)
3. At Phase 8, the review skill asks "Open a PR" or "Merge to main"
4. If "Open a PR" → use implement's "Open PR only" logic
5. If "Merge to main" → load the `finish` skill

## Quick Reference

| Phase | Action | Purpose |
|-------|--------|---------|
| 1 | Dispatch `explore` subagent(s) | Gather context: files, scope, dependencies |
| 2 | Synthesize & classify | Determine change type, depth, focus areas |
| 3 | Dispatch `reviewer` subagent | Run review against code, return categorized report |
| 4 | Parse findings | Classify actionable (🔴🟡🟢) vs informational (💡📚🎉) |
| 5 | Fix findings via `general` subagents | Dispatch one subagent per actionable finding |
| 6 | Loop back to Phase 3 | Re-review until zero actionable or max iterations |
| 7 | Exit conditions met | Present summary of resolved/remaining findings |
| 8 | `ask()` — Open a PR or Merge to main | Final user decision |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Running review once and stopping | Loop back to Phase 3 after fixes until zero actionable findings |
| Fixing code directly instead of dispatching a subagent | The main agent must delegate ALL code fixes to `general` subagents — never edit files in your own context |
| Having the reviewer fix code | The reviewer only returns reports — use `general` for fixes |
| Calling `ask()` after each review iteration | Only call `ask()` once at Phase 8 (after the loop exits) |
| Exceeding max iterations | Stop at 5 iterations and report remaining findings |
| Skipping informational findings entirely | Note 💡 Suggestions, 📚 Learning, and 🎉 Praise in the final summary

## Core Principles

### 1. The Review Mindset

**Goals of Code Review:**
1. **Catch bugs and edge cases** — Prevent production issues before they ship
2. **Ensure code maintainability** — Make future changes easier, not harder
3. **Share knowledge** — Spread understanding across the team, reduce bus factor
4. **Enforce standards** — Consistency reduces cognitive load for everyone
5. **Improve design and architecture** — Catch structural problems early
6. **Build team culture** — Reviews are conversations, not verdicts

**Not the Goals:**
- Show off knowledge or prove you're smarter
- Nitpick formatting (use linters/formatters)
- Block progress unnecessarily
- Rewrite code to your personal preference
- A substitute for thorough testing

### 2. Effective Feedback

**Good Feedback is:**
- **Specific** — Point to exact lines, explain the impact
- **Actionable** — Suggest concrete fixes or alternatives
- **Educational** — Explain why, not just what
- **Focused on code** — Never attack the person
- **Balanced** — Praise good work, not just problems
- **Prioritized** — Distinguish must-fix from nice-to-have

```markdown
❌ Bad: "This is wrong."
✅ Good: "This could cause a race condition when multiple users
         access simultaneously. Consider using a mutex here."

❌ Bad: "Why didn't you use X pattern?"
✅ Good: "Have you considered the Repository pattern? It would
         make this easier to test. Here's an example: [link]"

❌ Bad: "Rename this variable."
✅ Good: "[nit] Consider `userCount` instead of `uc` for
         clarity. Not blocking if you prefer to keep it."

❌ Bad: "This is messy."
✅ Good: "This function does 5 different things. Consider extracting
         the validation logic into a separate function for clarity."
```

### 3. Review Depth Guidelines

**Match your review depth to the change:**

| Change Type | Depth | Focus Areas |
|------------|-------|-------------|
| Bug fix (< 50 lines) | Quick | Correctness, edge cases, test coverage |
| Feature addition (< 200 lines) | Standard | Logic, design, tests, docs |
| Major refactor (> 400 lines) | Deep | Architecture, migration safety, rollback plan |
| Security-sensitive code | Thorough | All security checklist items |
| Performance-critical path | Detailed | Algorithm complexity, allocations, memory |
| New dependency | Careful | Security, license, maintenance, alternatives |

**Rule of thumb:** Spend more time on changes that affect more code, touch critical paths, or introduce new dependencies.

### 4. Review Scope

**What to Review (Deep):**
- Logic correctness and edge cases
- Security vulnerabilities (injection, auth, data exposure)
- Performance implications (algorithm complexity, allocations, memory)
- Test coverage and quality (edge cases, meaningful assertions)
- Error handling (complete, informative, recoverable)
- Documentation (README, inline comments, API docs)
- API design and naming (clear, consistent, hard to misuse)
- Architectural fit (patterns, separation of concerns, coupling)
- Concurrency and async safety (race conditions, cancellation safety)

**What Not to Review Manually (delegate to tools):**
- Code formatting (use Prettier, Black, cargo fmt, etc.)
- Import organization (use import sorters)
- Linting violations (use ESLint, clippy, pylint, etc.)
- Simple typos (unless in user-facing text)
- Style preferences that are already codified in linters

## Review Process Details

See [Architecture](#architecture--read-this-first) for the high-level flow. This section expands each phase with detailed checklists.

### Explore Subagent — What to Gather

The explore subagent collects:
- Changed files and their contents
- Related imports, callers, and dependencies
- Test coverage for affected code
- CI/lint/build status
- PR description, linked issues, design docs

For large changes (> 400 lines), dispatch multiple explore subagents in parallel:
- **explore 1:** Changed files + dependencies + related patterns
- **explore 2:** Tests + CI status + coverage gaps
- **explore 3:** Docs + ADRs + migration notes

### Main Agent — Classification Checklist

After collecting explore results, classify:
1. **Change type** — bug fix, feature, refactor, security, perf
2. **Review depth** — quick (< 100 lines), standard (100-400), deep (> 400)
3. **Focus areas** — correctness, security, performance, architecture
4. **Risk level** — based on affected code paths and test coverage

Checklist:
- [ ] What problem does this solve? (from branch context / plan)
- [ ] What's the scope? (lines changed, files touched)
- [ ] Are tests passing? Is linting clean?
- [ ] Who is this for? What's the user impact?
- [ ] New dependencies? API changes? Schema changes? Breaking changes?
- [ ] How does this interact with existing code?

### Reviewer Checklist (what the reviewer subagent does)

The reviewer subagent follows this checklist for each changed file:

#### Architecture & Design
- Does the solution fit the problem?
- Are there anti-patterns?
- Is the design scalable?
- Consult [Architecture Review Guide](guides/guide-architecture-review.md)

#### Performance
- Algorithm complexity (Big-O)
- Memory usage patterns
- N+1 queries or excessive API calls
- Unnecessary allocations
- Consult [Performance Review Guide](guides/guide-performance-review.md)

#### Security
- Input validation
- Authentication/authorization
- Data exposure risks
- Consult [Security Review Guide](guides/guide-security-review.md)

#### Correctness
- Logic errors or off-by-one mistakes
- Edge case handling (empty inputs, null values, boundary conditions)
- Error handling completeness
- Concurrency issues (race conditions, deadlocks, TOCTOU)
- State machine transitions complete and valid

#### Testing
- Are tests covering edge cases?
- Are tests meaningful or just exercising code?
- Is there test coverage for error paths?

#### File Organization
- Are new files in the right places?
- Is there logical grouping?
- Are there unnecessary files?

#### Maintainability
- Clear naming conventions (express intent, not implementation)
- Single responsibility principle (one reason to change)
- DRY violations (duplicate logic)
- Comment quality and relevance (why, not what)
- API design (hard to misuse, clear contracts)
- Error messages (helpful for debugging)

#### Documentation
- README updated if needed
- Inline comments explain non-obvious logic
- API docs for public functions/types
- Migration guides for breaking changes
- Changelog entries for user-facing changes

## Severity Classification Guide

### 🔴 Blocking — Must Fix Before Merge

Issues that will cause:
- Runtime crashes or panics
- Data loss or corruption
- Security vulnerabilities (injection, auth bypass, data exposure)
- Build failures
- Test failures
- Breaking changes without migration path
- Deadlocks or race conditions in production code

### 🟡 Important — Should Fix, Discuss if Disagree

Issues that will cause:
- Incorrect behavior in edge cases
- Performance degradation (significant)
- Memory leaks
- Missing error handling
- Test coverage gaps for critical paths
- API design that's hard to use correctly
- Code that will be difficult to maintain

### 🟢 Nit — Nice to Have, Not Blocking

Issues that are:
- Minor style inconsistencies
- Unnecessary complexity that could be simplified
- Naming that could be clearer
- Redundant code that could be extracted
- Missing documentation that would help future readers

### 💡 Suggestions — Alternative Approaches

Ideas for:
- Different patterns that might work better
- Libraries or tools that could help
- Architectural improvements
- Performance optimizations
- Code organization improvements

### 📚 Learning — Educational, No Action Needed

Notes for:
- Alternative approaches worth knowing
- Language/framework features not being used
- Best practices that apply elsewhere
- "Nice to know" information

### 🎉 Praise — Good Work, Keep It Up

Recognition for:
- Well-designed components
- Excellent test coverage
- Clear documentation
- Creative solutions to hard problems
- Consistent adherence to patterns

## Review Techniques

### Technique 1: The Checklist Method

Use checklists for consistent, thorough reviews. Start with the language-specific guide, then apply the appropriate domain guide (security, performance, architecture).

### Technique 2: The Question Approach

Instead of stating problems, ask questions that guide the author to the solution:

```markdown
❌ "This will fail if the list is empty."
✅ "What happens if `items` is an empty array? Should we handle that case?"

❌ "You need error handling here."
✅ "How should this behave if the API call fails? Should we retry or show an error?"

❌ "This is too complex."
✅ "This function does validation, transformation, and persistence. Could we split these into separate functions?"
```

### Technique 3: Suggest, Don't Command

Use collaborative language that invites discussion:

```markdown
❌ "You must change this to use async/await"
✅ "Suggestion: async/await might make this more readable. What do you think?"

❌ "Extract this into a function"
✅ "This logic appears in 3 places. Would it make sense to extract it into a shared function?"

❌ "This is a bad pattern"
✅ "Have you considered using the Strategy pattern here? It would make testing easier."
```

### Technique 4: The Impact Framework

For each finding, explain the impact:

```markdown
🟡 **Important: Missing error handling in API endpoint** - `api/users.rs:42`

**Impact:** If the database is unreachable, the API returns a 500 with no context.
Users see a generic error, and we lose visibility into the failure.

**Suggested fix:** Add error context with `.with_context()` and return a proper
error response with a user-friendly message.
```

### Technique 5: The Before/After Pattern

Show concrete before/after examples:

```markdown
💡 **Suggestion: Extract validation logic**

**Before:**
```rust
fn process_order(order: &str) -> Result<()> {
    if order.is_empty() {
        return Err("empty".into());
    }
    if !order.chars().all(|c| c.is_alphanumeric()) {
        return Err("invalid".into());
    }
    // ... 50 more lines
}
```

**After:**
```rust
fn validate_order_id(order: &str) -> Result<()> {
    if order.is_empty() || !order.chars().all(|c| c.is_alphanumeric()) {
        return Err("invalid order ID".into());
    }
    Ok(())
}

fn process_order(order: &str) -> Result<()> {
    validate_order_id(order)?;
    // ... 50 more lines
}
```
```

## Language-Specific Guides

When reviewing code in a specific language/framework, consult the corresponding detailed guide:

| Language/Framework | Reference File | Key Topics |
|-------------------|----------------|------------|
| **React** | [React Guide](languages/lang-react.md) | Hooks, useEffect, React 19 Actions, RSC, Suspense, TanStack Query v5 |
| **Vue 3** | [Vue Guide](languages/lang-vue.md) | Composition API, Reactivity System, Props/Emits, Watchers, Composables |
| **Rust** | [Rust Guide](languages/lang-rust.md) | Ownership/Borrowing, Unsafe Review, Async Code, Error Handling, Cancellation Safety, Testing, Macros |
| **TypeScript** | [TypeScript Guide](languages/lang-typescript.md) | Type Safety, async/await, Immutability, Generics |
| **Python** | [Python Guide](languages/lang-python.md) | Mutable Default Args, Exception Handling, Class Attributes, Context Managers |
| **Java** | [Java Guide](languages/lang-java.md) | Java 21/25 Features, Spring Boot 4, Virtual Threads, Stream/Optional |
| **Go** | [Go Guide](languages/lang-go.md) | Error Handling, goroutine/channel, context, Interface Design |
| **C** | [C Guide](languages/lang-c.md) | Pointers/Buffers, Memory Safety, UB, Error Handling |
| **C++** | [C++ Guide](languages/lang-cpp.md) | RAII, Lifetime, Rule of 0/3/5, Exception Safety |
| **SQL/PostgreSQL** | [SQL/PG Guide](languages/lang-sql-pg.md) | SQL Injection Prevention, EXPLAIN ANALYZE, Indexing, Concurrency |
| **CSS/Less/Sass** | [CSS Guide](languages/lang-css-less-sass.md) | Variable Conventions, !important, Performance Optimization, Responsive Design |
| **Qt** | [Qt Guide](languages/lang-qt.md) | Object Model, Signals/Slots, Memory Management, Thread Safety |
| **WASM/Frontend** | [WASM Guide](languages/lang-wasm.md) | Memory management, JS interop, bundle size, accessibility, browser compat |

## Additional Resources

- [Architecture Review Guide](guides/guide-architecture-review.md) - Architecture design review guide (SOLID, anti-patterns, coupling)
- [Performance Review Guide](guides/guide-performance-review.md) - Performance review guide (Web Vitals, N+1, complexity)
- [Security Review Guide](guides/guide-security-review.md) - Security review guide (OWASP, injection, auth)
- [Code Review Best Practices](guides/guide-code-review-best-practices.md) - Code review best practices
- [Common Bugs Checklist](checklists/checklist-common-bugs.md) - Common bugs by language
- [PR Review Template](assets/pr-review-template.md) - Standard PR review template
- [Review Checklist](assets/review-checklist.md) - Quick reference checklist
