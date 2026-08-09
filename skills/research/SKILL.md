---
name: research
description: |
  Use when comparing libraries or frameworks, evaluating approaches or
  architectures, investigating a technology or topic, finding best practices,
  deep-diving into a subject, doing competitive analysis, or researching
  academic papers. Triggers on: "research", "compare", "evaluate",
  "deep-dive", "investigate", "best practices for". Not for: simple file
  lookups (use explore directly), quick fact checks, or tasks requiring code changes.
---

# Research

Systematic research through phased investigation, evidence-backed findings, and structured reporting.

## Architecture — Read This First

```
Main agent (YOU — running this skill)
  ├── Phase 1: Classify + plan all research angles
  ├── Phase 2: Dispatch N parallel researcher subagents
  │     ├── researcher: one specific angle  ← pure leaf, no nesting
  │     ├── researcher: another angle       ← pure leaf, no nesting
  │     └── researcher: another angle       ← pure leaf, no nesting
  ├── Phase 3: Synthesise all findings
  └── Phase 4.5: Hard-stop ask → Phase 5 deliver
```

**You (the main agent) own all orchestration.** Researcher subagents are leaves — they receive one targeted angle, gather data, and report back. They never plan, never dispatch, never synthesise. No nesting, no depth issues.

## When to Use This Skill

- Comparing libraries, frameworks, or technologies
- Evaluating architectural approaches or design patterns
- Investigating how something works under the hood
- Finding best practices for a domain
- Deep-diving into a topic before making decisions
- Competitive or market analysis
- Any question requiring multi-source investigation

**Not for:** simple file lookups (use `explore` directly), quick one-liner facts.

## Core Principles

### 1. Evidence Over Opinion

Every claim must be backed by a source — URL, file path, or video timestamp. Distinguish:
- **Verified facts** — directly observable from a cited source
- **Reasonable inferences** — logical conclusions from multiple sources
- **Speculation** — educated guesses with no direct evidence

### 2. Depth Matches the Question

| Depth | Angles | When |
|-------|--------|------|
| **Quick** | 1 | Simple lookup, single fact |
| **Standard** | 2-3 | "How does X work?", approach comparison |
| **Deep** | 4-6 | "Should we use X or Y?", architecture research |

### 3. Angle Design — The Key to Good Research

Each parallel subagent gets **one specific angle**. Good angles are:
- Narrow enough to execute in one pass
- Different enough that results don't overlap
- Together they cover the full question

| Question type | Angles to dispatch |
|---|---|
| "Compare A vs B" | A docs/features / B docs/features / performance benchmarks / community/adoption |
| "How does X work?" | Official docs / source code internals / usage examples / known gotchas |
| "Best approach for X?" | Option A trade-offs / Option B trade-offs / real-world usage / codebase patterns |
| Hybrid (local + web) | Local codebase patterns / web docs / web best practices |

### 4. Citation Standards

| Source type | Format |
|-------------|--------|
| Open-source code | GitHub permalink with commit SHA |
| Local code | `repo:path:line` |
| Web | Full URL + title |
| Video | URL + timestamp |

## Research Workflow

### Phase 1: Classify (1 min)

1. **Research type:** web, code, academic, video, or hybrid
2. **Depth:** quick / standard / deep → determines number of angles
3. **Design angles:** define 1-6 specific, non-overlapping research angles

Consult strategy guides as needed:
- [Web Research](strategies/strategy-web-research.md)
- [Code Research](strategies/strategy-code-research.md)
- [Academic Research](strategies/strategy-academic.md)
- [Video Research](strategies/strategy-video-research.md)

**If the question is too vague:** ask the user to clarify before proceeding.

### Phase 2: Dispatch (main agent dispatches, never delegated)

**Execution mode gate:** If more than one angle was planned, ask the user how to run them before dispatching:

```typescript
ask({
  questions: [{
    id: "execution-mode",
    question: "Run the N research angles in parallel or in series?",
    options: [
      { label: "Parallel — all angles at once (default, fastest)" },
      { label: "Serial — one angle at a time, each informed by the last" }
    ],
    recommended: 0,
    description: "Parallel is faster and fine when angles are independent. Serial is better when a later angle depends on an earlier one's findings, or you want to review/steer between steps."
  }]
})
```

Skip this ask for **quick** depth (single angle) — go straight to parallel dispatch (which is just one call).

**Parallel mode — call `subagent` once per angle, all in the same response.** Do NOT use the `tasks` array — call the tool N times with a single `task` each. Pi executes parallel tool calls from the same response simultaneously, and each gets its own visible block in the UI.

```typescript
// Emit all of these as SEPARATE tool calls in ONE response:

subagent({ agent: "researcher", task: `Angle 1: [specific angle]\n\nFind: [exactly what]\nSources: [web / local / specific URLs]\nReport: key facts with citations, gaps if any.` })

subagent({ agent: "researcher", task: `Angle 2: [specific angle]\n\nFind: [exactly what]\nSources: [web / local / specific URLs]\nReport: key facts with citations, gaps if any.` })

subagent({ agent: "researcher", task: `Angle 3: [specific angle]\n\nFind: [exactly what]\nSources: [web / local / specific URLs]\nReport: key facts with citations, gaps if any.` })

// Quick — just one call
subagent({ agent: "researcher", task: "Find: [specific thing]. Report findings with citations." })
```

**Serial mode — call `subagent` once, wait for the result, then dispatch the next.** Each subsequent angle's task can reference prior findings (e.g. "Angle 2 builds on Angle 1's finding that X — investigate Y in that light"). Never batch serial calls into one response; each call must wait for the previous result before being issued.

```typescript
// Call 1 — dispatch, wait for result
subagent({ agent: "researcher", task: `Angle 1: [specific angle]\n\nFind: [exactly what]\nSources: [web / local / specific URLs]\nReport: key facts with citations, gaps if any.` })

// (after Angle 1 returns) Call 2 — informed by Angle 1's result
subagent({ agent: "researcher", task: `Angle 2: [specific angle]. Context from Angle 1: [carry forward relevant finding]\n\nFind: [exactly what]\nSources: [web / local / specific URLs]\nReport: key facts with citations, gaps if any.` })

// continue one at a time until all angles are covered
```

**Rules:**
- One `subagent` call per angle — never bundle multiple angles into one call
- Never use `tasks: [...]` for research — that hides all children inside one UI block
- In serial mode, never fire the next call before the current one has returned
- Be explicit about what sources to use (web, local files, specific URLs)
- Do NOT tell researchers to plan, synthesise, or dispatch — they are leaves
- **DO NOT add a `model` parameter to any subagent call.** The agent definition controls its own model. Adding `model` causes hallucinated model names that break the call.

**Failure modes during dispatch:**
- Subagent returns nothing → note as gap, try a follow-up call if critical
- Subagent times out → note timeout, skip angle and note gap

### Phase 3: Synthesise (main agent only)

Combine all findings into a coherent draft:

1. **Organise by research question**, not by which subagent found it
2. **Resolve contradictions** — present both sides with credibility assessment; never silently discard
3. **Build evidence chain** — every claim linked to its source
4. **Identify gaps** — what remains unanswered

### Phase 4.5: HARD STOP — Present Draft + Ask (REQUIRED)

> 🛑 **STOP HERE. Do not proceed to Phase 5 until ask() returns.**

Present the draft report, then call ask():

```markdown
## Research Draft

### Executive Summary
[Brief overview of key findings]

### Findings
[Organised by research question, every claim cited]

### Unresolved Contradictions
[If any — paired claims with citations]

### Gaps
[What remains unanswered]
```

```typescript
ask({
  questions: [{
    id: "research-next",
    question: "Draft report ready. What would you like to do?",
    options: [
      { label: "Write report to disk" },
      { label: "Discuss findings" },
      { label: "Targeted deep-dive on specific gaps" },
      { label: "Add a research dimension" },
      { label: "Reframe the question" }
    ],
    multi: true,
    description: "**Write report to disk:** Write the final report as a .md file (do NOT re-print it)\n**Discuss findings:** Load the discuss skill to design or plan based on these findings\n**Targeted deep-dive:** Dispatch more researchers on specific gaps\n**Add dimension:** Dispatch a new angle not in original plan\n**Reframe:** Start over with revised question"
  }]
})
```

After calling ask(), **stop**. Wait for the response.

### Phase 5: Deliver (after ask() responds)

| User Choice | Action |
|-------------|--------|
| Write report to disk | Write the final structured report to a `.md` file on disk using `write`. Use a descriptive filename under `docs/research/` (e.g. `docs/research/vllm-speculative-decoding.md`). **Do NOT re-print the report to chat — the draft was already shown at Phase 4.5.** |
| Discuss findings | Load the `discuss` skill, passing the research findings as context. Paste the key findings into the discussion so the agent can use the evidence to inform design decisions. The discussion picks up where research left off. |
| Targeted deep-dive | Dispatch more researcher subagents on specific gaps, re-synthesise |
| Add dimension | Dispatch new angle, re-synthesise |
| Reframe | Return to Phase 1 with revised question |

Final report format:
- Executive Summary
- Findings (organised by question, every claim cited)
- Evidence (source details, credibility)
- Unresolved Contradictions (if any)
- Gaps / What Remains Unknown

## Credibility Hierarchy

1. Official source code / docs
2. Peer-reviewed papers / specs
3. Well-known experts / maintainers
4. Community discussions (Stack Overflow, GitHub issues)
5. Blogs / tutorials

See [Source Credibility Guide](sources/source-credibility.md) for detailed scoring.

## Failure Modes & Recovery

| Failure | Recovery |
|---------|----------|
| Question too vague | Ask user to clarify before Phase 2 |
| Subagent returns nothing | Note as gap; retry with broader angle if critical |
| Sources conflict | Present both with citations, mark unresolved |
| Source paywalled/stale | Note in report; try archive; flag as gap |
| Depth misjudged too shallow | User catches at hard stop — they choose "dig deeper" |

## Quick Reference

- [Web Research Strategy](strategies/strategy-web-research.md)
- [Code Research Strategy](strategies/strategy-code-research.md)
- [Academic Research Strategy](strategies/strategy-academic.md)
- [Video Research Strategy](strategies/strategy-video-research.md)
- [Source Credibility Guide](sources/source-credibility.md)
- [Research Report Template](assets/research-report-template.md)
