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

The behavior described in the rest of this document, unchanged: full flow → reviewer vet (max 3 rounds) → **HARD BREAK** → `ask` → optionally load the `implement` skill. Use when a user or entry skill loads `specify` directly.

### Consumed mode

Entered **only** when the invoking task text contains the exact marker `SPECIFY CONSUMED MODE`. Used by the `roadmap` skill, which runs `specify` once per task. In consumed mode:

- Plan exactly **ONE task** (described by the task text), NOT a whole feature.
- The target path is the `target:` stated in the invocation text (e.g. `docs/roadmap/<feature>-taskNN-<slug>.md`). If no `target:` is present, **stop and report NEEDS_CONTEXT** — never guess a path.
- The **reviewer vet still runs** (parameterised on the target path — see *After Plan is Written*), max 3 rounds.
- Write the plan to the target path with front-matter `status: committed`, a `parent: docs/roadmap/<feature>.md` key, and `done-when`.
- Perform **neither** the spec-doc commit **nor** the issue-tracker mirror — the caller (`roadmap`) owns both.
- Do **NOT** perform the HARD BREAK, do **NOT** call `ask`, do **NOT** load the `implement` skill. Return control with a one-line "plan written to <target>" report.

## Input

This skill operates on `docs/roadmap/<topic>.md`. Read that file and branch on its front-matter `status`:

**In consumed mode ignore this section** — the target path is the `target:` given in the invocation text, no `ask` is permitted, and the 'no file → ask the user' branch never applies. If a `status: committed` plan already exists at the target (a re-run after a BLOCKED task), REFINE it in place (as the standalone committed-branch already describes) rather than re-planning from scratch.


- **No file** (no discussion was run) → ask the user for the spec, write it to `docs/roadmap/<topic>.md` with `status: approved` front-matter, then plan from scratch.
- **File exists, `status: approved`** (a design spec, no plan yet) → plan from the spec (the normal case — the spec was written by the `discuss` skill, which hands off here directly after approval).
- **File exists, `status: committed`** (a plan already exists) → **refine the existing plan; do NOT re-plan from scratch.** Read the existing plan and update it in place: fill gaps, add the information and rules this skill carries (concrete file paths, exact signatures/types, test steps, acceptance criteria, task breakdown), and keep what is already correct. This is the path taken when the `discuss` skill's "Approve the current plan?" routes back here. The file stays `status: committed` — you are improving the plan, not regenerating it.

If the topic isn't already known (no discussion handed off, no path given) and more than one roadmap doc exists, ask the user which file to work on.

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

**In consumed mode, skip the HARD BREAK below** — do not ask, do not load `implement`; return control to the caller. (The reviewer dispatch and max-3-round fix loop above still run.)

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
| Performing the HARD BREAK, committing, or mirroring to the tracker in consumed mode | Consumed mode writes the plan and returns; the caller owns commit + tracker |
| Creating a plan index or done/ folder | No index, no graveyard — roadmap docs are self-contained; history lives in git |
| Omitting the `## Parallelisation` verdict | `implement` reads a missing verdict as SERIAL. Declare SERIAL with a reason — a missed parallel opportunity is invisible; a wrong one is not |
| Declaring a wave because the tasks are *logically* independent | Independence of features is not disjointness of paths. `routes.py`, a shared fixture, or a `mod.rs` collide regardless of how separate the features feel |
| Letting a wave child run the full test suite | The result attributes a sibling's breakage to it. Scoped test in-wave, full suite after the wave |

More parallelisation mistakes and worked examples: **[Parallelisation Guide](guides/guide-parallelisation.md)**.