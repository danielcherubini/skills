---
name: specify
description: Use when a feature or change needs an implementation plan with concrete tasks, file paths, and test steps before coding begins
---

# Specify

Turn an approved design into a structured implementation plan with independent, commitable tasks.

**Write for a dumb agent.** The executing agent has no memory of your conversation, no knowledge of intent, and no ability to infer what you meant. Every task must be self-contained and complete enough that a capable but context-free agent can execute it without guessing. If something is ambiguous, spell it out. If something could be done multiple ways, specify which way. Leave nothing to interpretation.

## When to Use

- After discussion/design is complete and user has approved the approach
- When work is large enough to benefit from task breakdown (2+ tasks)

**Don't use when:**
- Idea isn't fleshed out yet — use `discuss` first
- Change is small enough to implement directly (single file, obvious fix)

## Input

This skill expects an approved design spec. The spec comes from the conversation — it was already presented and approved during discussion. Do NOT read from a file unless one was explicitly saved earlier.

## Plan Format

Write to `docs/plans/plan-NNN-<feature>.md` (NNN is the next sequential number, zero-padded to 3 digits, e.g. `plan-001-<feature>.md`, `plan-002-<feature>.md`):

```markdown
# [Feature] Plan

**Goal:** One sentence
**Architecture:** 2-3 sentences
**Tech Stack:** Key technologies

---

### Task N: [Name]

**Context:**
A short paragraph explaining *why* this task exists, what problem it solves, and how it fits into the overall feature. Include any decisions already made and why. Do not assume the agent knows anything about the conversation.

**Files:**
- Create: `exact/path/file.ext`
- Modify: `exact/path/existing.ext`
- Test: `tests/path/test.ext`

**What to implement:**
A precise description of the change. Include:
- Exact function/struct/module names to add or modify
- Exact signatures, types, or field names where relevant
- Any specific logic, conditions, or edge cases to handle
- What NOT to change (if there's a risk of over-engineering)

**Steps:**
- [ ] Write failing test for [specific behavior] in `tests/path/test.ext`
- [ ] Run `[exact test command]`
  - Did it fail with [expected error]? If it passed unexpectedly, stop and investigate why.
- [ ] Implement [specific thing] in `exact/path/file.ext`
- [ ] Run `[exact test command]`
  - Did all tests pass? If not, fix the failures and re-run before continuing.
- [ ] Run `[exact format command]` (e.g. `cargo fmt`)
  - Did it succeed? If not, fix and re-run before continuing.
- [ ] Run `[exact build command]` (e.g. `cargo build`)
  - Did it succeed? If not, fix and re-run before continuing.
- [ ] Commit with message: "[suggested commit message]"

**Acceptance criteria:**
- [ ] [Specific, verifiable outcome]
- [ ] [Another specific outcome]
```

Each task must be independently commitable. The agent executing it has no context beyond what is written here — be exhaustive.

## After Plan is Written

Dispatch the **reviewer subagent** to review the plan:

```
subagent({
  agent: "reviewer",
  task: "Review type: plan execution review. Review the implementation plan at `docs/plans/plan-NNN-<feature>.md`. This is NOT a review of the plan file as a document — it is a review of the plan against the actual codebase that will be modified. Read every file the plan references (creates, modifies, tests). Read any additional files needed to verify the plan is correct: existing interfaces, types, imports, dependencies, build configs, and related modules. Report anything the plan should do differently: missing files, wrong paths, incorrect signatures, overlooked edge cases, integration gaps, or anything the executing agent would get wrong. If you need to read the whole codebase to be sure, do it. The plan will be executed verbatim by an agent with no context — leave no stone unturned."
})
```

Fix issues (max 3 rounds).

Then update `docs/plans/README.md`:
1. Add the new plan to the Backlog table (use the sequential number, e.g. `plan-001`)
2. Increment the Total Plans count in Quick Stats
3. If this plan supersedes an older one, move the old entry to the Superseded Plans section

**CRITICAL: Do NOT begin implementing any tasks in the plan. The `specify` skill ends once the plan is vetted and presented to the user. The plan is handed off to the `implement` skill, which will ask the user to confirm plan selection before executing.**

**HARD BREAK — STOP here and ask. Do NOT continue into implementation on your own.**

1. **Clear the todo list** — use `manage_todo_list` to remove all entries now that planning is complete.
2. Tell the user the plan is ready (path + one-line summary).
3. Get explicit confirmation with the `ask` tool:

   ```
   ask({
     questions: [{
       id: "proceed-to-implementation",
       question: "The plan is ready at docs/plans/plan-NNN-<feature>.md. Would you like to proceed with implementation now?",
       options: [
         { label: "Yes — start implementation (load implement skill)" },
         { label: "No — hold the plan for later" },
         { label: "Revise the plan first" }
       ]
     }]
   })
   ```

4. **Only if the user explicitly confirms**, load the `implement` skill. Otherwise stop and wait for the user to decide. Do NOT load `implement` or do any implementation work without that explicit confirmation.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Tasks that depend on each other's uncommitted work | Make each task independently commitable |
| Vague file paths ("update the config") | Use exact paths: `src/config/auth.ts` |
| Skipping TDD steps in task template | Every task needs failing test → implement → pass |
| Planning before design is agreed | Use `discuss` first to align on approach |
| Too many tasks (10+) | Group related changes; aim for 3-7 tasks |
| Sliding into implementation right after the plan | HARD BREAK — stop, ask via `ask`, and only load `implement` on explicit user confirmation |