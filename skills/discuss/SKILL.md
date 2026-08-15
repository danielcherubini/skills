---
name: discuss
description: Use when the user says "let's discuss", "lets discuss", "I want to discuss", "can we discuss", "let's brainstorm", "lets brainstorm", "I want to brainstorm", or any variation asking to discuss/talk through/brainstorm an idea before coding — this takes priority over other requests in the same message. Also use before any creative work to discuss features, designs, or behavior changes through collaborative dialogue before writing code
---

# Discuss

Turn ideas into designs through collaborative dialogue before writing any code.

As you discuss, capture decisions and terminology as persistent artifacts:
- **ADRs** for non-obvious trade-offs (hard-to-reverse, surprising, real alternatives)
- **CONTEXT.md** for resolved terminology (shared language that compounds across sessions)

## Hard Gate

Do NOT write code, load the `implement` skill (or any implementation skill) until design is approved. This is a hard stop — and it does not lift into a continuation: even after approval, never flow into implementation on your own. The only path forward is the explicit next-step choice via `ask` below, and that choice never leads directly to `implement` (it goes to `specify` at most).

## Process

### 0. Understand the domain first

Before discussing design, establish shared language. This prevents the whole conversation from drifting on fuzzy terms.

**A. Read the glossary** — Check for `CONTEXT.md` at the project root (or per-context if `CONTEXT-MAP.md` exists). If it exists, read it and use the established terms from the very first question. If no glossary exists yet, you'll build one.

**B. Challenge fuzzy language** — When the user uses vague or overloaded terms, call it out immediately. "You're saying 'account' — do you mean the Customer or the User? Those are different things." Propose a precise canonical term.

**C. Cross-reference with code** — When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

**D. Challenge against the glossary** — If the user uses a term that conflicts with `CONTEXT.md`, call it out: "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

**E. Stress-test with scenarios** — When domain relationships are being discussed, invent edge-case scenarios that force precision about the boundaries between concepts.

**F. Capture terms inline** — When a term is resolved, offer to add it to `CONTEXT.md` right then (see Terminology Check below). Don't wait until the end.

> Only proceed to step 1 once terminology is settled. If the discussion itself reveals new terms or ambiguities, loop back.

### 1. Explore context — check files, docs, recent commits

### 2. Research if needed — if the question requires comparing approaches, evaluating libraries, or understanding how something works, read the `research` skill and run Phases 1–3 (classify, dispatch, synthesise) yourself. Present a concise summary of findings — not the full report. Use the evidence to inform the approaches in step 3.

### 3. Ask clarifying questions — one at a time, use the `ask` tool with multiple-choice options

### 4. Propose 2-3 approaches with trade-offs and your recommendation, use the `ask` tool

### 5. Present design section by section, use the `ask` tool to get approval after each section

### 6. Once all sections are approved, present the final spec in full

> **Always use the `ask` tool** for steps 3–5. Do not present a section and then continue to the next — wait for the user's explicit approval via `ask` before moving forward.

## After Each Section Approval

Before moving to the next section, check for decisions worth capturing.

### ADR Check

Ask yourself: was any decision in this section **all three** of the following?

1. **Hard to reverse** — the cost of changing our mind later is meaningful
2. **Surprising without context** — a future reader would look at the code and wonder "why?"
3. **A real trade-off** — there were genuine alternatives and we picked one for specific reasons

If yes, offer to the user:

> "That decision to [summary] feels worth recording as an ADR — it's [hard to reverse / surprising / a real trade-off]. Want me to capture it?"

If the user agrees, write it to `docs/adr/NNNN-slug.md` using the format in [adr-format.md](./adr-format.md). Create `docs/adr/` lazily — only when the first ADR is needed.

If any of the three criteria is missing, skip the ADR. The obvious choice doesn't need documenting.

### Terminology Check

Ask yourself: did we resolve any fuzzy or overloaded terms during this section?

Examples:
- The user said "account" but meant the billing entity, not the user profile
- A concept has multiple names in conversation ("materialize", "publish", "go live" all meaning the same thing)
- A new term was coined that future sessions should know

If yes, offer to the user:

> "We resolved that [term] means [definition]. Want me to add it to the project glossary in `CONTEXT.md`?"

If the user agrees, add it to `CONTEXT.md` using the format in [context-format.md](./context-format.md). Create `CONTEXT.md` lazily — only when the first term is resolved.

### If Nothing to Capture

If neither an ADR nor a terminology resolution applies, just move to the next section. Don't force it.

## After Approval

Once the design is approved by the user, present the complete spec in your response — do NOT write it to disk. The spec stays in the conversation and flows directly into the next step.

Use the `ask` tool to ask what happens next:

```
ask({
  questions: [{
    id: "next-step",
    question: "Design approved. What would you like to do next?",
    options: [
      { label: "Run a reviewer" },
      { label: "Create implementation plan" },
      { label: "Save spec for later" },
      { label: "Revise the design" }
    ]
  }]
})
```

If the user chooses "Run a reviewer", THEN:
1. Dispatch the **reviewer subagent**:

   ```
   subagent({
     agent: "reviewer",
     task: "Review type: spec. Review the following spec: [paste the approved spec here]. Return a report categorized by severity. Do NOT call ask() — just return the report."
   })
   ```

2. Present the reviewer's findings to the user, then call `ask()` to let them choose what to fix:

   ```
   ask({
     questions: [{
       id: "fix-priority",
       question: "Review complete. What would you like to do?",
       options: [
         { label: "Fix blocking only" },
         { label: "Fix blocking + important" },
         { label: "Fix all" },
         { label: "No fixes needed" }
       ]
     }]
   })
   ```

3. Fix selected issues one at a time. Re-run the reviewer once after all fixes.
4. After review is complete, re-ask the next-step question

If the user chooses "Create implementation plan":
1. **Clear the todo list** — use `manage_todo_list` to remove all entries now that discussion is complete.
2. Immediately load the `specify` skill and invoke it. The `specify` skill handles the entire planning process.

If the user chooses "Save spec for later", THEN:
1. Write it to `docs/specs/spec-NNN-<topic>-spec.md` (NNN is the next sequential number, zero-padded to 3 digits, matching the plan numbering convention)
2. Add the new spec to `docs/plans/README.md` in the Specs → Draft section
3. Update the Quick Stats (increment Total Specs and Draft count)

## Principles

- Always use the `ask` tool for every decision point — clarifying questions, approach selection, section approval, and post-approval next steps
- One question per `ask` call
- Never skip ahead to the next section without explicit user approval via `ask`
- YAGNI — remove unnecessary features
- Design for clear boundaries and single responsibilities
- In existing codebases, follow established patterns
- Scale detail to complexity — a few sentences if simple, more if nuanced
- Capture decisions and terminology inline — don't batch them up, don't skip them
- Read existing `CONTEXT.md` before starting — use the established language from the first question
