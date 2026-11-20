---
name: write-skills
description: 'Use when creating new skills, editing existing skills, or verifying skills work before deployment. Triggers on: "write a skill", "create a skill", "edit skill", "improve skill", "skill TDD".'
---

# Writing Skills

**Writing skills is Test-Driven Development applied to process documentation.**

You write test cases (pressure scenarios with subagents), watch them fail (baseline behavior), write the skill (documentation), watch tests pass (agents comply), and refactor (close loopholes).

**Core principle:** If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing.

## What is a Skill?

A reference guide for a proven technique, pattern, or tool. Skills help future agent instances find and apply effective approaches.

**Skills are:** Reusable techniques, patterns, tools, reference guides

**Skills are NOT:** Narratives about how you solved a problem once

## TDD Mapping

| TDD Concept | Skill Creation |
|-------------|----------------|
| **Test case** | Pressure scenario with subagent |
| **Production code** | Skill document (SKILL.md) |
| **Test fails (RED)** | Agent violates rule without skill (baseline) |
| **Test passes (GREEN)** | Agent complies with skill present |
| **Refactor** | Close loopholes while maintaining compliance |
| **Write test first** | Run baseline scenario BEFORE writing skill |
| **Watch it fail** | Document exact rationalizations agent uses |
| **Minimal code** | Write skill addressing those specific violations |
| **Watch it pass** | Verify agent now complies |

## When to Create a Skill

**Create when:**
- Technique wasn't intuitively obvious to you
- You'd reference this again across projects
- Pattern applies broadly (not project-specific)
- Others would benefit

**Don't create for:**
- One-off solutions
- Standard practices well-documented elsewhere
- Project-specific conventions (put in CLAUDE.md)
- Mechanical constraints (if enforceable with validation, automate it)

## Skill Types

- **Technique** — Concrete method with steps (e.g. condition-based-waiting, root-cause-tracing)
- **Pattern** — Way of thinking about problems (e.g. flatten-with-flags, test-invariants)
- **Reference** — API docs, syntax guides, tool documentation

## Directory Structure

```
skills/
  skill-name/
    SKILL.md              # Main reference (required)
    supporting-file.*     # Only if needed
```

Flat namespace — all skills in one searchable namespace.

**Separate files for:** heavy reference (100+ lines like API docs), reusable tools (scripts, utilities).

**Keep inline:** principles, code patterns under 50 lines, everything else.

## SKILL.md Structure

### Frontmatter

Only two fields: `name` and `description`. Max 1024 characters total.

- `name`: letters, numbers, hyphens only
- `description`: third-person, describes **only when to use** (not what it does). Start with "Use when..."

```yaml
---
name: skill-name
description: Use when [specific triggering conditions and symptoms]
---
```

### Body Template

```markdown
# Skill Name

## Overview
What is this? Core principle in 1-2 sentences.

## When to Use
[Small inline flowchart IF decision non-obvious]

Bullet list with SYMPTOMS and use cases
When NOT to use

## Core Pattern (for techniques/patterns)
Before/after code comparison

## Quick Reference
Table or bullets for scanning common operations

## Implementation
Inline code for simple patterns
Link to file for heavy reference or reusable tools

## Common Mistakes
What goes wrong + fixes
```

## Claude Search Optimization (CSO)

Future agents need to **find** your skill. The description is the discovery mechanism.

### Description = Trigger, Not Workflow Summary

This is the single most important rule. The description should ONLY describe triggering conditions. Do NOT summarize the skill's process or workflow.

**Why this matters:** Testing revealed that when a description summarizes the skill's workflow, the agent may follow the description instead of reading the full skill content. A description saying "review between tasks" caused the agent to do ONE review, even though the skill's flowchart clearly showed TWO reviews (spec compliance then code quality).

When the description was changed to just "Use when executing implementation plans with independent tasks" (no workflow summary), the agent correctly read the flowchart and followed the two-stage review process.

**The trap:** Descriptions that summarize workflow create a shortcut the agent will take. The skill body becomes documentation the agent skips.

```yaml
# Bad — summarizes workflow, agent takes shortcut
description: Use when executing plans - dispatches subagent per task with review between tasks

# Bad — too much process detail
description: Use for TDD - write test first, watch it fail, write minimal code, refactor

# Good — just triggering conditions, no workflow summary
description: Use when executing implementation plans with independent tasks in the current session

# Good — triggering conditions only
description: Use when implementing any feature or bugfix, before writing implementation code
```

**Content rules:**
- Concrete triggers, symptoms, situations
- Describe the *problem* (race conditions, inconsistent behavior) not *language-specific symptoms* (setTimeout, sleep)
- Technology-agnostic unless the skill itself is technology-specific
- Third person (injected into system prompt)
- Under 500 characters if possible

```yaml
# Bad — too abstract, vague
description: For async testing

# Bad — first person
description: I can help you with async tests when they're flaky

# Good — starts with "Use when", describes problem, no workflow
description: Use when tests have race conditions, timing dependencies, or pass/fail inconsistently

# Good — technology-specific skill with explicit trigger
description: Use when using React Router and handling authentication redirects
```

### Keyword Coverage

Use words the agent would search for:
- Error messages: "Hook timed out", "ENOTEMPTY", "race condition"
- Symptoms: "flaky", "hanging", "zombie", "pollution"
- Synonyms: "timeout/hang/freeze", "cleanup/teardown/afterEach"
- Tools: actual commands, library names, file types

### Descriptive Naming

Use active voice, verb-first: `creating-skills` not `skill-creation`, `condition-based-waiting` not `async-test-helpers`. Gerunds (-ing) work well for processes.

### Token Efficiency

Frequently-loaded skills appear in every conversation. Every token counts.

**Targets:** getting-started skills <150 words, frequently-loaded <200 words, others <500 words.

**Techniques:**
- Move flag details to `--help` references instead of documenting every option inline
- Cross-reference other skills by name instead of repeating their workflow
- Compress examples — one minimal example beats three verbose ones
- Don't repeat what's in cross-referenced skills, explain the obvious, or show the same pattern multiple times

### Cross-Referencing Other Skills

Use skill name only, with explicit requirement markers:

- Good: `**REQUIRED BACKGROUND:** You MUST understand test-driven-development`
- Good: `Use the systematic-debugging skill for root-cause analysis`
- Bad: `See skills/testing/test-driven-development` (unclear if required)
- Bad: `@skills/testing/test-driven-development/SKILL.md` (force-loads, burns context)

`@` syntax force-loads files immediately, consuming context before you need them.

## Flowchart Usage

Use flowcharts ONLY for:
- Non-obvious decision points
- Process loops where you might stop too early
- "When to use A vs B" decisions

Never use flowcharts for: reference material (use tables), code examples (use markdown blocks), linear instructions (use numbered lists), or labels without semantic meaning (`step1`, `helper2`).

## Code Examples

**One excellent example beats many mediocre ones.**

Choose the most relevant language for the skill's domain. A good example is complete and runnable, well-commented explaining WHY, from a real scenario, and ready to adapt.

Don't implement in 5+ languages, create fill-in-the-blank templates, or write contrived examples.

## The Iron Law

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

This applies to new skills AND edits to existing skills. Write skill before testing? Delete it. Start over. Edit skill without testing? Same violation.

**No exceptions:**
- Not for "simple additions"
- Not for "just adding a section"
- Not for "documentation updates"
- Don't keep untested changes as "reference"
- Don't "adapt" while running tests
- Delete means delete

## Testing All Skill Types

Different skill types need different test approaches:

### Discipline-Enforcing Skills (rules/requirements)

**Examples:** TDD, verification-before-completion, designing-before-coding

**Test with:** academic questions (do they understand the rules?), pressure scenarios (compliance under stress), multiple pressures combined (time + sunk cost + exhaustion). Identify rationalizations and add explicit counters.

**Success criteria:** Agent follows rule under maximum pressure.

### Technique Skills (how-to guides)

**Examples:** condition-based-waiting, root-cause-tracing, defensive-programming

**Test with:** application scenarios (can they apply correctly?), variation scenarios (edge cases), missing information tests (do instructions have gaps?).

**Success criteria:** Agent successfully applies technique to new scenario.

### Pattern Skills (mental models)

**Examples:** reducing-complexity, information-hiding concepts

**Test with:** recognition scenarios (do they see when pattern applies?), application scenarios, counter-examples (do they know when NOT to apply?).

**Success criteria:** Agent correctly identifies when/how to apply pattern.

### Reference Skills (documentation/APIs)

**Examples:** API documentation, command references, library guides

**Test with:** retrieval scenarios (can they find the right info?), application scenarios, gap testing (are common use cases covered?).

**Success criteria:** Agent finds and correctly applies reference information.

## Common Rationalizations for Skipping Testing

| Excuse | Reality |
|--------|---------|
| "Skill is obviously clear" | Clear to you ≠ clear to other agents. Test it. |
| "It's just a reference" | References can have gaps, unclear sections. Test retrieval. |
| "Testing is overkill" | Untested skills have issues. Always. 15 min testing saves hours. |
| "I'll test if problems emerge" | Problems = agents can't use skill. Test BEFORE deploying. |
| "Too tedious to test" | Testing is less tedious than debugging bad skill in production. |
| "I'm confident it's good" | Overconfidence guarantees issues. Test anyway. |
| "Academic review is enough" | Reading ≠ using. Test application scenarios. |
| "No time to test" | Deploying untested skill wastes more time fixing it later. |

**All of these mean: test before deploying. No exceptions.**

## Bulletproofing Skills Against Rationalization

Skills that enforce discipline need to resist rationalization. Agents are smart and will find loopholes under pressure.

### Close Every Loophole Explicitly

Don't just state the rule — forbid specific workarounds:

```markdown
# Bad — too narrow
Write code before test? Delete it.

# Good — closes escape hatches
Write code before test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete
```

### Address "Spirit vs Letter" Arguments

Add a foundational principle early:

```markdown
**Violating the letter of the rules is violating the spirit of the rules.**
```

This cuts off an entire class of "I'm following the spirit" rationalizations.

### Build Rationalization Table

Capture rationalizations from baseline testing. Every excuse agents make goes in a table:

```markdown
| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
```

### Create Red Flags List

Make it easy for agents to self-check when rationalizing:

```markdown
## Red Flags - STOP and Start Over

- Code before test
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "This is different because..."

**All of these mean: Delete code. Start over with TDD.**
```

### Update CSO for Violation Symptoms

Add to the description: symptoms of when the agent is ABOUT to violate the rule:

```yaml
description: use when implementing any feature or bugfix, before writing implementation code
```

## RED-GREEN-REFACTOR for Skills

### RED: Write Failing Test (Baseline)

Run a pressure scenario with a general subagent WITHOUT the skill:

```
subagent({
  agent: "general",
  task: "[Describe the pressure scenario — give the agent the task that would trigger a rule violation without the skill]"
})
```

Document exact behavior:
- What choices did they make?
- What rationalizations did they use (verbatim)?
- Which pressures triggered violations?

This is "watch the test fail" — you must see what agents naturally do before writing the skill.

### GREEN: Write Minimal Skill

Write a skill that addresses those specific rationalizations. Don't add extra content for hypothetical cases.

Run the same scenarios WITH the skill using a general subagent:

```
subagent({
  agent: "general",
  task: "[Same pressure scenario as RED — give the agent the task]"
})
```

Agent should now comply.

### REFACTOR: Close Loopholes

Agent found a new rationalization? Add an explicit counter. Re-test until bulletproof.

**Pressure types to try:** time pressure, sunk cost (agent invested work in wrong direction), authority appeals ("the user said it's fine"), exhaustion (long context with many prior tasks).

## Anti-Patterns

### Narrative Example
"In session 2025-10-03, we found empty projectDir caused..." — too specific, not reusable.

### Multi-Language Dilution
`example-js.js`, `example-py.py`, `example-go.go` — mediocre quality, maintenance burden. One excellent example is enough.

### Code in Flowcharts
Flowchart nodes with `import fs`, `read file` — can't copy-paste, hard to read.

### Generic Labels
`helper1`, `helper2`, `step3` — labels should have semantic meaning.

## STOP: Before Moving to Next Skill

After writing ANY skill, you MUST STOP and complete the deployment process.

**Do NOT:**
- Create multiple skills in batch without testing each
- Move to next skill before current one is verified
- Skip testing because "batching is more efficient"

Deploying untested skills = deploying untested code.

## Skill Creation Checklist

**RED Phase — Write Failing Test:**
- [ ] Create pressure scenarios (3+ combined pressures for discipline skills)
- [ ] Run scenarios WITHOUT skill — document baseline behavior verbatim
- [ ] Identify patterns in rationalizations/failures

**GREEN Phase — Write Minimal Skill:**
- [ ] Name uses only letters, numbers, hyphens
- [ ] YAML frontmatter with only name and description (max 1024 chars)
- [ ] Description starts with "Use when..." and includes specific triggers/symptoms
- [ ] Description written in third person
- [ ] Keywords throughout for search (errors, symptoms, tools)
- [ ] Clear overview with core principle
- [ ] Address specific baseline failures identified in RED
- [ ] Code inline OR link to separate file
- [ ] One excellent example (not multi-language)
- [ ] Run scenarios WITH skill — verify agents now comply

**REFACTOR Phase — Close Loopholes:**
- [ ] Identify NEW rationalizations from testing
- [ ] Add explicit counters (if discipline skill)
- [ ] Build rationalization table from all test iterations
- [ ] Create red flags list
- [ ] Re-test until bulletproof

**Quality Checks:**
- [ ] Small flowchart only if decision non-obvious
- [ ] Quick reference table
- [ ] Common mistakes section
- [ ] No narrative storytelling
- [ ] Supporting files only for tools or heavy reference

**Deployment:**
- [ ] No dead file references (verify every linked file exists)
- [ ] Cross-references use skill names only (no `@` links, no external namespace prefixes)
- [ ] Commit skill to git

## Discovery Workflow

How future agents find your skill:

1. Encounters problem ("tests are flaky")
2. Finds SKILL (description matches)
3. Scans overview (is this relevant?)
4. Reads patterns (quick reference table)
5. Loads example (only when implementing)

**Optimize for this flow** — put searchable terms early and often.

## The Bottom Line

**Creating skills is TDD for process documentation.**

Same Iron Law: no skill without failing test first.
Same cycle: RED (baseline) → GREEN (write skill) → REFACTOR (close loopholes).
Same benefits: better quality, fewer surprises, bulletproof results.

If you follow TDD for code, follow it for skills. It's the same discipline applied to documentation.
