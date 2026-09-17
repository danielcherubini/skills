---
name: codebase-improvement
description: Use when asking to improve a codebase, refactor for quality, find architectural issues, audit code health, or surface improvement opportunities — DRY violations, long files, weak abstractions, coupling, dead code, naming, test gaps, or inconsistent patterns.
---

# Codebase Improvement

Systematic codebase audit that surfaces improvement opportunities through 8 engineering lenses, produces a dated markdown report in `docs/reviews/`, then walks through each finding conversationally. Flows into the standard dev pipeline (discuss → specify → implement) after approval.

## Architecture — Read This First

```
Main agent (YOU — running this skill)
  ├── Phase 1: Load context (CONTEXT.md, ADRs, plans)
  ├── Phase 2: Dispatch explore subagents for scanning  ← pure leaves, no user interaction
  ├── Phase 3: Dispatch explore + reviewer subagents    ← pure leaves, no user interaction
  ├── Phase 4: Synthesize findings → write report       ← YOU do this
  ├── Phase 5: Walk through findings with ask()         ← YOU interact with the user
  └── Phase 6: Pipeline handoff (specify / save / revise) ← YOU decide next step
```

**You (the main agent) own all orchestration AND all user interaction.** Subagents dispatched in Phases 2–3 are pure data-gathering leaves:

- **Subagents scan and report findings** — they return structured data (file paths, descriptions, evidence). They do NOT call `ask()`, do NOT present findings to the user, do NOT suggest what to do.
- **The main agent synthesizes, writes the report, and discusses** — after collecting all subagent results, the main agent classifies findings, writes the markdown report, then walks through each finding with the user via `ask()`.

**Subagents never interact with the user.** If a subagent is about to call `ask()` or present findings conversationally, it has violated this rule.

## When to Use

- "Improve this codebase", "Audit the code quality", "Find architectural issues"
- "Where should we refactor?", "Surface improvement opportunities"
- Codebase feels messy but unclear where to start

**Not for:** reviewing a specific PR (use `review`), debugging a specific bug (use `systematic-debugging`), implementing a known change (use `specify` → `implement`)

## Workflow

### Phase 1: Context Load

Read project context to ground the analysis:

1. **`CONTEXT.md`** — domain glossary + engineering rules section (see CONTEXT.md Extension below). If missing, use all defaults and note in report.
2. **`docs/adr/`** — read all ADRs (cap: 20 by mtime). If directory missing, skip silently and note in report.
3. **`docs/roadmap/`** — read the 10 most recent roadmap docs by file modification time. If directory missing, skip silently and note in report.

### Phase 2: Scan (follow the research skill's dispatch pattern)

Load the **research skill** and follow its dispatch pattern for code research:

1. **Classify:** Code research, deep (8 angles)
2. **Design 8 angles** — one per improvement lens (see Lenses below). Each angle is a specific, narrow task for an explore subagent.
3. **Dispatch** parallel explore subagents — one per angle. Each subagent scans the codebase through its lens and returns findings with file paths and evidence.
4. **Synthesize** all findings — merge duplicates across lenses (each finding assigned to its primary lens), classify by severity and confidence.

**Ownership boundary:** This skill follows the research skill's dispatch pattern (classify → angles → dispatch → synthesize), including its Phase 2 parallel-vs-serial execution-mode `ask()` gate (since 8 angles > 1, this gate will trigger — ask before dispatching). It does NOT execute the research skill's Phase 4.5 `ask()` hard-stop — the main agent handles all user interaction in Phase 5. Subagents return findings only; they never call `ask()` or present to the user.

### Phase 3: Deep-dive (follow the review skill's dispatch pattern)

For findings that match the deep-dive trigger, load the **review skill** and follow its dispatch pattern:

**Trigger:** All 🔴 High severity findings + any 🟡 Medium findings from architectural lenses (Weak Abstractions, Coupling).

For each triggered finding:
1. Dispatch an explore subagent for context (related files, callers, dependencies)
2. Dispatch a reviewer subagent for detailed analysis
3. Collect the categorized report and enrich the finding

**Ownership boundary:** This skill follows the review skill's dispatch pattern (explore → reviewer → collect). It does NOT execute the review skill's `ask()` hard-stop — the main agent handles all user interaction in Phase 5. Subagents return reports only; they never call `ask()` or present to the user.

### Phase 4: Report

Generate a markdown report and save to `docs/reviews/YYYY-MM-DD-codebase-improvement.md`:

```markdown
# Codebase Improvement Report — YYYY-MM-DD

## Summary
N findings across M categories. X high, Y medium, Z low.

## Context
- CONTEXT.md: [loaded / not found, defaults applied]
- ADRs reviewed: [count or "none"]
- Plans reviewed: [count or "none"]

## Findings

### 🔴 High Severity

#### 1. [Title]
- **Lens:** [which of the 8 lenses]
- **Files:** `path/to/file.ts`
- **Severity:** High
- **Confidence:** High / Medium / Low
- **Problem:** [description]
- **Proposal:** [concrete change — included only when Confidence is High]

### 🟡 Medium Severity
[same format — Severity: Medium]

### 🟢 Low Severity
[same format — Severity: Low]

## Top Recommendation
[Which finding to tackle first and why]
```

Present the summary to the user.

### Phase 5: Discuss (one by one)

**The main agent** walks through each finding from the report and calls `ask()` for the user to decide. Do NOT delegate this to a subagent — the main agent owns the conversation.

For each finding, call `ask()`:

```
ask({
  questions: [{
    id: "finding-N",
    question: "[Title] — [one-line summary]",
    options: [
      { label: "Approve — add to backlog" },
      { label: "Research more" },
      { label: "Dismiss" },
      { label: "Defer — decide later" }
    ],
    description: "[Full details: lens, files, severity, confidence, problem, proposal]"
  }]
})
```

| Choice | Action |
|--------|--------|
| **Approve** | Add to implementation backlog |
| **Research more** | Dispatch a targeted research subagent scoped to this finding's open questions. Re-present the same 4 options. **Cap: 2 research rounds per finding**, then force Approve/Dismiss/Defer. |
| **Dismiss** | Skip. If the reason is load-bearing (not "not now" or "too hard"), offer: *"Want me to record this as an ADR so future audits don't re-suggest it?"* If agreed, write to `docs/adr/NNNN-slug.md` following the discuss skill's ADR format. |
| **Defer** | Move to a "Needs Decision" list. Revisit all deferred findings at the end of Phase 5. |

After all findings discussed, present the approved backlog + any remaining deferred items.

### Phase 6: Pipeline Handoff

```
ask({
  questions: [{
    id: "next-step",
    question: "Discussion complete. N findings approved, D deferred. What next?",
    options: [
      { label: "Create implementation plan (specify)" },
      { label: "Save report for later" },
      { label: "Revise findings" }
    ]
  }]
})
```

- **Create implementation plan** → Clear todo list, load `specify` skill, pass the approved backlog
- **Save for later** → Report already saved in `docs/reviews/`
- **Revise findings** → Return to Phase 2 with refined angles

## Improvement Lenses

Each finding is assigned to exactly one **primary lens**. If a finding spans multiple lenses, assign to the most specific one and merge duplicates during synthesis.

### 1. File Length + Structure
Files exceeding threshold (default: 200 lines per file, excluding comments and blank lines, overridable in `CONTEXT.md`). God files. Multiple unrelated responsibilities in one file.

### 2. DRY Violations
Duplicate logic across files. Copy-pasted code with minor variations. Same transformation in multiple places.

### 3. Weak Abstractions
Concepts repeated as inline logic instead of named types/functions. Primitive obsession. Logic that knows too much about multiple domains.

### 4. Coupling Issues
Circular dependencies. Modules importing from too many others. Leaked internals. Tight coupling where abstractions would help.

### 5. Missing Tests / Testability
Untested critical paths. Code hard to test (no injection points, tight coupling). Missing test utilities.

> *Note: This lens is heuristic-based and does not run coverage tooling.*

### 6. Inconsistent Patterns
Same thing done differently across files. Mixed conventions. Some files follow a pattern, others don't.

### 7. Dead Code
Unused exports. Unreachable code paths. Files with no external imports. Commented-out code.

### 8. Naming
Functions/variables that don't express intent. Inconsistent conventions. Names contradicting `CONTEXT.md` domain terms.

## Finding Classification

Every finding carries:

| Field | Values | Meaning |
|-------|--------|---------|
| **Lens** | One of the 8 above | Primary category (no duplicates) |
| **Severity** | 🔴 High / 🟡 Medium / 🟢 Low | Impact of not fixing. There is no Critical tier. |
| **Confidence** | High / Medium / Low | How sure we are based on evidence |
| **Proposal** | Concrete change | Included only when Confidence = High |

## CONTEXT.md Extension — Engineering Rules Section

This skill extends `CONTEXT.md` with an "Engineering Rules" section. The discuss skill owns the `CONTEXT.md` schema for domain terminology; this section is an additive extension for project-level engineering preferences.

Format:

```markdown
## Engineering Rules

- File length threshold: 150 lines
- Prefer composition over inheritance
- No barrel exports
- Functional style in TypeScript
- One domain concept per file
```

The skill loads these and applies them alongside the default lenses. When the discuss skill resolves terminology, it should preserve any existing "Engineering Rules" section.

## ADR Integration

- **Before scanning:** Read existing ADRs to know what not to re-suggest
- **During discuss:** If a finding contradicts an ADR, only surface it when friction is real enough to warrant reopening. Mark clearly: *"contradicts ADR-0007 — but worth reopening because..."*
- **After dismiss:** If the user dismisses with a load-bearing reason, offer: *"Want me to record this as an ADR so future audits don't re-suggest it?"* If agreed, write to `docs/adr/NNNN-slug.md` following the discuss skill's ADR format.

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| No `CONTEXT.md` | Use all defaults. Note "not found, defaults applied" in report. |
| No `docs/adr/` | Skip silently. Note "none" in report. |
| No `docs/roadmap/` | Skip silently. Note "none" in report. |
| Empty / trivial codebase (< 5 source files) | Write report with "No meaningful findings." Skip Phase 5. Offer Phase 6. |
| Zero findings after scan | Write report with "No findings." Skip Phase 5. Phase 6 offers "Save for later" only. |
| Research/review subagent fails | Note as a gap in the report. Continue with remaining findings. |

## Uncertainty Protocol

Applies **outside Phase 5** finding discussion (e.g., ambiguous CONTEXT.md rule, unclear lens assignment, contradictory ADR). During Phase 5, use the fixed 4-option menu.

If unsure about anything: Ask the user before proceeding. Always include "research" as an option:

```
ask({
  questions: [{
    id: "uncertain-X",
    question: "I'm uncertain about [specific thing]. How should I proceed?",
    options: [
      { label: "Research it — dispatch a targeted scan" },
      { label: "Skip this area" },
      { label: "[Context-specific option]" }
    ]
  }]
})
```

## Definition of Done

The skill is complete when:
1. Report written to `docs/reviews/YYYY-MM-DD-codebase-improvement.md`
2. All findings resolved (Approved, Dismissed, or Deferred)
3. User has chosen a Phase 6 action (implement, save, or revise)
