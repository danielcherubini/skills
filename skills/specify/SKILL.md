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

## Invocation Modes

This skill runs in one of two modes. The mode is chosen by an **explicit marker in the invoking text** — never inferred from the filesystem.

### Standalone mode (default)

The behavior described in the rest of this document, unchanged: read the input → **ground the plan (`researcher`, or inline if dispatched)** → write plan → reviewer vet (max 3 rounds) → **HARD BREAK** → `ask` → optionally load the `implement` skill. Use when a user or entry skill loads `specify` directly.

### Consumed mode

Entered **only** when the invoking task text contains the exact marker `SPECIFY CONSUMED MODE`. Used by the
`roadmap` skill, which runs `specify` once per task. Consumed mode is normally run **as a dispatched child**
(`researcher`, `agentName: "researcher"`), which has **no `subagent` tool** — so consumed mode never dispatches anything itself; the caller
owns every sub-agent. In consumed mode:

- Plan exactly **ONE task** (described by the task text), NOT a whole feature. The invocation also supplies a
  **grounding report path** and the task's **owned file set** — consume both (see *Ground the Plan First*); a
  missing report path is the only grounding you should ever have to do yourself.
- **Ground the plan inline** — read the files, grep the real signatures, confirm each path exists (see *Ground the Plan First*). If you genuinely have a `subagent` tool, dispatch `researcher` instead and say so.
- The target path is the `target:` stated in the invocation text (e.g. `docs/roadmap/<feature>-taskNN-<slug>.md`). If no `target:` is present, **stop and report NEEDS_CONTEXT** — never guess a path.
- Write the plan to the target path with front-matter `status: committed`, a `parent: docs/roadmap/<feature>.md` key, and `done-when`. The target file is the **only** file you write — never a grounding report, never source, never the status file.
- **The reviewer vet is the caller's, not yours.** Do not dispatch a reviewer — a child cannot, and promising one silently produces an un-vetted plan. `roadmap` vets the plan you write (see its Step 4) and re-dispatches you to refine it if the vet finds anything. If you *are* running with a `subagent` tool, run the vet as described in *After Plan is Written*.
- Perform **neither** the spec-doc commit **nor** the issue-tracker mirror — the caller (`roadmap`) owns both.
- Do **NOT** perform the HARD BREAK, do **NOT** call `ask`, do **NOT** load the `implement` skill. Return control with a one-line "plan written to <target>" report, plus anything you could not verify so the caller's vet can target it.

## Input

This skill operates on `docs/roadmap/<topic>.md`. Read that file and branch on its front-matter `status`:

**In consumed mode ignore this section** — the target path is the `target:` given in the invocation text, no `ask` is permitted, and the 'no file → ask the user' branch never applies. If a `status: committed` plan already exists at the target (a re-run after a BLOCKED task), REFINE it in place (as the standalone committed-branch already describes) rather than re-planning from scratch.


- **No file** (no discussion was run) → ask the user for the spec, write it to `docs/roadmap/<topic>.md` with `status: approved` front-matter, then plan from scratch.
- **File exists, `status: approved`** (a design spec, no plan yet) → plan from the spec (the normal case — the spec was written by the `discuss` skill, which hands off here directly after approval).
- **File exists, `status: committed`** (a plan already exists) → **refine the existing plan; do NOT re-plan from scratch.** Read the existing plan and update it in place: fill gaps, add the information and rules this skill carries (concrete file paths, exact signatures/types, test steps, acceptance criteria, task breakdown), and keep what is already correct. This is the path taken when the `discuss` skill's "Approve the current plan?" routes back here. The file stays `status: committed` — you are improving the plan, not regenerating it.

If the topic isn't already known (no discussion handed off, no path given) and more than one roadmap doc exists, ask the user which file to work on.

## Ground the Plan First

**Never write a plan from memory of the codebase.** Ground it — write the plan from what the tree actually
contains. The plan's entire value is that it names *exact* paths, signatures and commands; an invented path is
worse than no plan, because the executing agent follows it confidently and nothing downstream can tell a
verified path from a plausible one.

**How you ground depends on whether you can dispatch — and only you know that.** Do not assume, and do not
stall looking for a tool you were never given:

- **You have a `subagent` tool** (you are the main agent, running standalone `specify`) → **dispatch
  `researcher`** and write the plan from its report.
- **You do not** (you were dispatched as a child, which is how `roadmap` runs consumed `specify` via `researcher`) → **read the
  grounding report the caller hands you.** A `roadmap` dispatch supplies a path like
  `docs/roadmap/<feature>-ground-<area>.md`; open it and plan from it. It already contains the file inventory,
  the verbatim signatures, and the test commands — that is why it exists.
  - **Read the report first, then read only what it does not answer.** Do not re-walk the tree to re-confirm
    what the report already states. A planning child that ignored its report and re-derived the codebase from
    scratch cost **359.7k tokens / 88 tool calls / 281% of its context budget**, compacting and re-reading as it
    went — the report is the fix for exactly that, so ignoring it is the expensive choice, not the careful one.
  - Stay inside the **owned file set** the caller gave you: read your set and the report, and treat files
    outside it as out of scope.
  - No report was supplied? Then ground yourself — read the files, grep the real signatures, confirm each path
    exists — and **say in your report back that no grounding was supplied**, so the caller fixes it for the rest
    of the run. Say once that you are grounding inline; never report it as a blocker.
- Either way the plan must be grounded. The mechanism changes; the requirement does not.

When dispatching, one `researcher` per independent area of the change — all calls in **one response** so they
run concurrently:

```typescript
subagent({ agent: "researcher", task: `Grounding for plan: <feature or task name>

Find and report, with file paths and line references:
1. Every existing file this work will touch or depend on — confirm each path exists on disk.
2. The real signatures / types / field names of anything this plan will call or modify. Quote them verbatim.
3. Conventions this codebase already uses for that kind of change (error handling, module layout, naming).
4. The exact test, format and build commands, and where test files for this area live.
5. Integration points — who calls this code, and what would break.
6. Anything already implemented that the plan might duplicate.

Sources: local codebase. Report findings with paths; flag anything you could NOT confirm.` })
```

- **`researcher` for planning, `general` for implementation** — `general` is the *implementation* child; it writes code and commits.
  Grounding and consumed planning are read-only to code and touch only markdown files; they run via `researcher`. (When you are the consumed-mode child doing inline
  grounding, you are already read-only for the duration — do not edit source while grounding.)
- **Not the `reviewer`** — the reviewer runs *after* the plan exists (see *After Plan is Written*) and checks it
  against the tree. Grounding runs *before*, so the plan starts from facts instead of being corrected afterwards.
- **Report anything that could NOT be confirmed** — by the researcher, or by your own reading. Mark those items
  explicitly `UNVERIFIED: <reason>` in the plan rather than inventing a plausible path. An honest gap is
  actionable; a confident guess is not. The caller's reviewer uses these to target its vet.
- **Scale to the work** — a one-file change needs one quick researcher; a multi-area feature needs one per area.
  Two angles that depend on each other are one angle with N steps: give them to a single researcher.
- **Consumed mode:** the caller supplies a **grounding report path** and the task's **owned file set**. Read the
  report; do not re-derive the tree. Scope everything to the owned set — the caller uses it to prove the wave's
  tasks are disjoint, so a plan that reaches outside it breaks the wave. No `ask` is permitted, so never pause to
  query the user about a gap; record it as `UNVERIFIED: <reason>` in the plan instead.

Never skip grounding silently. If you could not ground part of the plan, say so in the plan itself rather
than writing a confident path you never opened.

## Parallelisation

Decide this while writing the plan, not after. Emit a `## Parallelisation` verdict and a `**Parallel:**` line on **every** task — those two are all `implement` reads.

**Consumed mode exception:** a consumed-mode plan contains exactly one task, so it has nothing to parallelise
with. Write `## Parallelisation` with a `SERIAL` verdict (one task cannot be a wave) and emit no `**Parallel:**`
line. Parallelism in a `roadmap` run happens **between tasks**, in the wave grouping roadmap owns.

Test each candidate wave against ALL SIX gates. A task joins a wave only if it clears every one; a task that clears none runs alone (which does not disqualify the tasks that do clear them).

1. **Disjoint files** — `Files:` lists (Create + Modify + **Test**) share ZERO paths, pairwise.
2. **No build-graph dependency** — A cannot `import`/`use` a symbol B creates in the same wave.
3. **No shared mutable artifact** — lockfiles, migrations, generated code, shared fixtures, `mod.rs`/`__init__.py`/barrel files, route or middleware registration, config. **Check the commands, not just the file lists**: a task verified through `uv run` / `npm test` / `cargo test` can rewrite a lockfile or write snapshots without naming them in `Files:`.
4. **Scoped verification suffices** — acceptance criteria provable by the task's own test file alone. Needs a full-suite run → serial.
5. **No tree-wide mutation** — whole-tree formatters, lockfile regeneration, codegen.
6. **Wave size ≤ 4** — beyond four, simultaneous builds contend for one `target/` / `node_modules/.cache` and the win flattens.

**Why this is not just "are they independent?":** every child shares ONE working tree and ONE `.git/index` — there is no per-child worktree. Getting gates 1–3 wrong does not crash. It silently blends two tasks' half-finished edits into one commit, and makes a child's RED/GREEN check meaningless because it is measuring a sibling's in-progress code.

Consult **[Parallelisation Guide](guides/guide-parallelisation.md)** for worked wave/serial examples, the near-miss checklist, and how to word each `**Parallel:**` line.

**State the verdict even when it is SERIAL — with the reason.** A plan with no verdict is read by `implement` as SERIAL anyway; the difference is that a reason tells the next reader whether serial was decided or merely assumed.

## Plan Format

Write the plan to the spec's existing file — `docs/roadmap/<topic>.md` (kebab-case, named for the outcome, e.g. `docs/roadmap/user-auth.md`). Keep the spec's filename; the plan replaces the spec content in the same file: …unless consumed mode names a different `target:` — then write there instead, with the extra `parent:` front-matter key.

```markdown
---
status: committed
done-when: <observable exit condition — what does "shipped" look like for a real user?>
---

# [Feature] Plan

**Goal:** One sentence
**Architecture:** 2-3 sentences
**Tech Stack:** Key technologies

---

## Parallelisation

**Verdict:** SERIAL — every task shares `src/routes.py`, so no two tasks have disjoint file sets.

<!-- Exactly one verdict. The PARALLEL form:
**Verdict:** PARALLEL — 2 waves
- Wave 1: Task 1, Task 2, Task 3 (disjoint file sets, verified pairwise)
- Wave 2: Task 4 (needs Task 1's `AuthError`, so it cannot join Wave 1)
-->

---

### Task N: [Name]

**Parallel:** wave 1 — disjoint from Task 2 (`src/a.py`, `tests/test_a.py`) and Task 3 (`src/b.py`, `tests/test_b.py`)
<!-- or: **Parallel:** none — shares `src/routes.py` with Task 2. Every task carries this line; it is the field `implement` dispatches on. -->

**Context:**
A short paragraph explaining *why* this task exists, what problem it solves, and how it fits into the overall feature. Include any decisions already made and why. Do not assume the agent knows anything about the conversation.

**Files:**
<!-- In consumed mode these MUST fall inside the owned file set the caller gave you. A file outside it is not
     yours to change: mark it `UNVERIFIED: outside owned set` and report it, never silently add it. -->
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
  - **Wave tasks differ:** a task declared `**Parallel:** wave N` must NOT commit — the orchestrator commits its files after the wave (see *Parallel wave rules* below). Write the commit message here anyway; the orchestrator uses it verbatim.

**Acceptance criteria:**
- [ ] [Specific, verifiable outcome]
- [ ] [Another specific outcome]
```

Each task must be independently commitable. The agent executing it has no context beyond what is written here — be exhaustive.

## Parallel wave rules

The invariants the `**Parallel:**` lines encode — `implement` executes these, so a plan claiming PARALLEL must hold all four:

- **Wave children do not commit.** They edit and report their file list; the orchestrator commits each task separately by explicit pathspec (`git commit -m "<msg>" -- <files>`), which a sibling's staged work cannot corrupt. Serial tasks commit as usual.
- **In-wave verification is scoped** — own test file, own files formatted. Never a full suite or tree-wide formatter: siblings are mid-edit in the same tree.
- **The full suite runs once per wave, afterwards, serially** — so acceptance criteria are provable by scoped-test-in-wave + suite-after-wave together.
- **A wave is a barrier** — dispatch all of wave N together, wait for all, then wave N+1. A BLOCKED sibling holds the following waves.

Full protocol, failure handling, and the child dispatch wording live in the **implement** skill's Parallel Execution Guide — that is `implement`'s to read at execution time, not yours.

## After Plan is Written

Dispatch the **reviewer subagent** to review the plan:

```
subagent({
  agent: "reviewer",
  task: "Review type: plan execution review. Review the implementation plan at `<resolved plan path>`. This is NOT a review of the plan file as a document — it is a review of the plan against the actual codebase that will be modified. Read every file the plan references (creates, modifies, tests). Read any additional files needed to verify the plan is correct: existing interfaces, types, imports, dependencies, build configs, and related modules. Report anything the plan should do differently: missing files, wrong paths, incorrect signatures, overlooked edge cases, integration gaps, or anything the executing agent would get wrong. If you need to read the whole codebase to be sure, do it. The plan will be executed verbatim by an agent with no context — leave no stone unturned."
})
```

`<resolved plan path>` is the spec's file in standalone mode, or the invocation's `target:` in consumed mode.

Fix issues (max 3 rounds).

**Standalone mode only:** in consumed mode the caller owns the commit. In the normal case (input was `status: approved`), the plan replaces the spec content in the same file and the front-matter moves from `status: approved` to `status: committed`. In the refine case (input was already `status: committed`), the plan is updated in place and the `status` stays `committed` — you improved the existing plan, you did not regenerate it. Commit the roadmap doc (`git add docs/roadmap/<topic>.md && git commit -m "docs: plan <topic>"`) so the plan version is preserved in git history. If this plan supersedes a separate older roadmap doc, delete it — history lives in git.

**Standalone mode only:** in consumed mode the caller owns the mirror. **Mirror the plan to the issue tracker** — the same step the `discuss` skill calls 1b; resolve the tracker there (AGENTS.md first, never `git remote`). The file is the source of truth, the tracker is the review mirror. Reuse the issue the spec was posted to (the doc's `issue:` front-matter key) — the plan is a NEW COMMENT on that issue, not a new issue; carry the key forward if the spec step never ran. Post the plan body with the front-matter stripped and note the commit SHA so reviewers can link the exact version. GitHub caps a comment near 65 KB — split into consecutive `n of N` comments over the cap, never truncate. No tracker / no `gh` → say so once and continue; this never gates the HARD BREAK.

**CRITICAL: Do NOT begin implementing any tasks in the plan. The `specify` skill ends once the plan is vetted and presented to the user. The plan is handed off to the `implement` skill, which will ask the user to confirm plan selection before executing.**

**In consumed mode, skip the HARD BREAK below** — do not ask, do not load `implement`; return control to the caller. **The reviewer dispatch above runs only if you actually have a `subagent` tool** (true standalone, false when you are the consumed-mode child) — when you do not, the caller (`roadmap`) vets the plan you wrote; never report a vet you did not run as one you did.

**HARD BREAK — STOP here and ask. Do NOT continue into implementation on your own.**

1. **Clear the todo list** — use `manage_todo_list` to remove all entries now that planning is complete.
2. Tell the user the plan is ready (path + one-line summary).
3. Get explicit confirmation with the `ask` tool:

   ```
   ask({
     questions: [{
       id: "proceed-to-implementation",
       question: "The plan is ready at docs/roadmap/<topic>.md. Would you like to proceed with implementation now?",
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
| Writing the plan from memory — invented paths, signatures, or test commands | Ground first: dispatch `researcher` if you have a subagent tool, otherwise read the files yourself. Mark anything unconfirmed `UNVERIFIED` |
| Performing the HARD BREAK, committing, or mirroring to the tracker in consumed mode | Consumed mode writes the plan and returns; the caller owns commit + tracker |
| Creating a plan index or done/ folder | No index, no graveyard — roadmap docs are self-contained; history lives in git |
| Omitting the `## Parallelisation` verdict | `implement` reads a missing verdict as SERIAL. Declare SERIAL with a reason — a missed parallel opportunity is invisible; a wrong one is not |
| Declaring a wave because the tasks are *logically* independent | Independence of features is not disjointness of paths. `routes.py`, a shared fixture, or a `mod.rs` collide regardless of how separate the features feel |
| Letting a wave child run the full test suite | The result attributes a sibling's breakage to it. Scoped test in-wave, full suite after the wave |

More parallelisation mistakes and worked examples: **[Parallelisation Guide](guides/guide-parallelisation.md)**.