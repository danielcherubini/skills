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
- **Independent** — each is fully writable before any other has returned
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
4. **Task card:** if your input carries a `<task id="tsk_…" stage="…">` block, note the id — that block is the only place it appears (normally your first user message). Phase 5 needs it. No block → no card, skip the card steps.

Consult strategy guides as needed:
- [Web Research](strategies/strategy-web-research.md)
- [Code Research](strategies/strategy-code-research.md)
- [Academic Research](strategies/strategy-academic.md)
- [Video Research](strategies/strategy-video-research.md)

**If the question is too vague:** ask the user to clarify before proceeding.

### Phase 2: Dispatch (main agent dispatches, never delegated)

**Always parallel.** Call `subagent` once per angle, **all in the same response** — N angles means N tool calls in one message. Do NOT use the `tasks` array — call the tool N times with a single `task` each. Parallel tool calls issued from one response execute simultaneously and each gets its own visible UI block. Quick depth is simply one call.

Never ask the user how to run the angles. Dispatch shape is not a user decision, and there is no case where serial beats parallel here: the angles are independent by construction (Phase 1 §3), and the one legitimate want behind serial — steer between steps — is what the Phase 4.5 hard stop is for, one round later and with every angle's findings in hand rather than one.

**The one exception is an explicit user instruction.** The rule forbids *polling* the user for a decision you can make, not overriding your default at their direction:

- The user says nothing, or anything short of a dispatch instruction → **parallel. No ask.** Never treat a hint, a deadline, or your own guess about their budget as an instruction — that is the same offloading, inverted.
- The user explicitly asks for serial / one-at-a-time → **comply for this run.** Name the trade-off in one line ("all five return labelled individually; you steer at the hard stop with everything in hand — say the word and I'll switch"), then run it their way. Do not re-ask, do not silently switch back, and do not decide an informed user is wrong.

"Never ask" buys you a default, not the authority to overrule.

```typescript
// Emit all of these as SEPARATE tool calls in ONE response:

subagent({ agent: "researcher", task: `Angle 1: [specific angle]\n\nFind: [exactly what]\nSources: [web / local / specific URLs]\nReport: key facts with citations, gaps if any.` })

subagent({ agent: "researcher", task: `Angle 2: [specific angle]\n\nFind: [exactly what]\nSources: [web / local / specific URLs]\nReport: key facts with citations, gaps if any.` })

subagent({ agent: "researcher", task: `Angle 3: [specific angle]\n\nFind: [exactly what]\nSources: [web / local / specific URLs]\nReport: key facts with citations, gaps if any.` })

// Quick — just one call
subagent({ agent: "researcher", task: "Find: [specific thing]. Report findings with citations." })
```

If an angle genuinely cannot be written until another has returned, that is **one angle with N steps**, not two angles — give it to a single researcher, who sequences its own steps. Two angles that depend on each other are an angle-design bug; fix the split.

**Rules:**
- One `subagent` call per angle — never bundle multiple angles into one call
- Never use `tasks: [...]` for research — that hides all children inside one UI block
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
      { label: "Move to Approved — deliver, then hand the card to a fresh Session" },
      { label: "Discuss findings" },
      { label: "Targeted deep-dive on specific gaps" },
      { label: "Add a research dimension" },
      { label: "Reframe the question" },
      { label: "Roadmap — decompose the tracks and run them" }
    ],
    multi: true,
    description: "**Write report to disk:** Write the final report as a .md file (do NOT re-print it)\n**Move to Approved:** Deliver first, then move the Task card to Approved and hand implementation to a fresh Session (see the Phase 5 table). Only offered when Phase 1 step 4 found a `<task>` block.\n**Discuss findings:** Load the discuss skill to design or plan based on these findings\n**Targeted deep-dive:** Dispatch more researchers on specific gaps\n**Add dimension:** Dispatch a new angle not in original plan\n**Reframe:** Start over with revised question\n**Roadmap:** When (and only when) the findings imply multiple separate implementation tracks, load the roadmap skill with those tracks as the approved block (see Phase 5)"
  }]
})
```

**Only include the "Move to Approved" option when Phase 1 step 4 found a `<task id="tsk_…">`
block** — with no card there is nothing to move, and an option that cannot run is a dead
control. It composes with "Write report to disk" (multi-select): delivering is a
prerequisite for the move, not an alternative to it.

**It does not compose with "Discuss findings" or "Roadmap"** — those continue the work in
*this* session, the move ends it. If both come back selected, ask once which was meant
before doing either; do not resolve it by picking one silently.

After calling ask(), **stop**. Wait for the response.

### Phase 5: Deliver (after ask() responds)

| User Choice | Action |
|-------------|--------|
| Write report to disk | Write the final structured report to a `.md` file on disk using `write`. Use a descriptive filename under `docs/research/` (e.g. `docs/research/vllm-speculative-decoding.md`). Include front-matter (see below). **Do NOT re-print the report to chat — the draft was already shown at Phase 4.5.** **THEN, if Phase 1 step 4 found a `<task id="tsk_…">` block, attach it: `write_artifact(task_id, key: "research", markdown: <the file contents you just wrote>)`.** A key is `[a-z0-9][a-z0-9-]{0,39}`, ≤40 chars, and the markdown is capped at 256 KiB (a refusal writes nothing). It UPSERTS, so re-attach after any revision. If there is no `write_artifact` tool — this skill is global, most projects have no Task board — say so in one sentence and carry on; do not emulate it with another file. **Why:** the file is the working copy and the artifact is the copy a later Session on this card, or on another machine, can actually read. |
| Discuss findings | Load the `discuss` skill, passing the research findings as context. Paste the key findings into the discussion so the agent can use the evidence to inform design decisions. **Also paste the `<task id="tsk_…">` block verbatim if Phase 1 step 4 found one** — `discuss` reads the card id ONLY from that block, and when it is loaded mid-session it will not find one, so an unforwarded id means its After-Approval step 1a silently never runs and the spec it writes lands with no durable copy. The discussion picks up where research left off. |
| Targeted deep-dive | Dispatch more researcher subagents on specific gaps, re-synthesise |
| Add dimension | Dispatch new angle, re-synthesise |
| Reframe | Return to Phase 1 with revised question |
| Move to Approved | **Only selectable alongside "Write report to disk"** — deliver first, then hand off. Load `move-task-to-approved` and follow it: attach the report as the card's `research` artifact if Phase 5 has not already, `list_board(space_path)` to read the Approved column's real slug, `move_task`, verify with `get_task`, then tell the user to **archive this session**, open the Tasks board, and click the card's **arrow pill** to launch a fresh Session. **Then stop — do not load `implement` or `discuss`.** No `<task>` block found → this option was never offered. |
| Roadmap | When (and only when) the findings imply multiple separate implementation tracks: load the `roadmap` skill, passing those tracks as the approved block — **and the `<task id="tsk_…">` block verbatim if Phase 1 step 4 found one**, since `roadmap` is loaded mid-session, never sees that block, and has no spec doc of its own to read an id from when the entry is `research`. (If combined with "Write report to disk" via multi-select, write the report first, then load roadmap.) This does not change research's default — deliver-only stays the default. |

Final report format (always include front-matter):

```yaml
---
status: current          # current | superseded
last-verified: YYYY-MM-DD
verified-by: web research — [N] sources, [date]
---
```

- Executive Summary
- Findings (organised by question, every claim cited)
- Evidence (source details, credibility)
- Unresolved Contradictions (if any)
- Gaps / What Remains Unknown

If the research supersedes an older report, update the old file's `status: superseded` and add a link to the new one.

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
