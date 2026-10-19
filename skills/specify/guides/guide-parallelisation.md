# Parallelisation Guide

How to decide whether a plan's tasks can run concurrently, and how to write that decision into the plan. Load this when the plan has 2+ tasks. `implement` re-verifies your verdict against the real tree — a wave you declare wrongly is not caught by a gate, it is caught by a corrupted commit.

## Why this is not obvious

Every subagent shares ONE working tree and ONE `.git/index`. There is no per-child worktree. Two consequences that do not announce themselves:

- **Commits are index-wide.** `git commit` commits whatever is staged. Child A stages `a.py`, child B stages `b.py`, A commits → A's commit silently contains B's half-finished work. Concurrent `git add` also deadlocks on `.git/index.lock`.
- **Verification measures everyone.** A child's RED/GREEN check runs against a tree a sibling is mid-editing. It cannot distinguish "my test fails because my code is missing" from "because my sibling is halfway through `user.py`." Per-task TDD — the whole point of dispatching a child per task — stops meaning anything.

So "these two tasks are logically independent" is not the question. The question is whether they can coexist in one tree at one moment.

## The six gates

Test each candidate wave against **all six**. A task joins a wave only if it clears every one. A task that clears none runs alone — which does not contaminate the wave assignment of the tasks that do clear them.

### 1. Disjoint files

The candidate tasks' `Files:` lists — Create + Modify + Test taken together — share ZERO paths, pairwise.

The near-misses that people miss: one shared test file, one shared fixture, one shared snapshot directory, one shared factory/builder helper.

### 2. No build-graph dependency

Task A cannot `import` / `use` / link against a symbol Task B is creating in the same wave. If A needs B's new type, trait, or exported function, A belongs in a later wave.

This one is invisible to gate 1: the two tasks touch different files and still cannot coexist, because A's child starts with no `B.py` in the tree, fails, and either invents an interface or stubs it. The invented interface is the expensive outcome — it passes A's own scoped tests and breaks at integration, where nothing can attribute it.

### 3. No shared mutable artifact

Anything wave members write, even indirectly. Lockfiles, migrations, generated code, shared fixtures, seed data, route/middleware registration files, `mod.rs` / `__init__.py` / barrel files, DB schema, config.

**Check the commands, not just the file lists.** A task whose verification runs through a wrapper — `uv run`, `npm test`, `cargo test`, `poetry run` — can re-resolve a lockfile, write snapshots, or touch `conftest.py` without any of that appearing in its `Files:` list. Two tasks each running `pytest` with coverage or snapshot plugins can both be writing the same cache.

A "register the components" or "wire up the module" task is gate 3 by definition — its entire job is editing the one file every other task would also have to edit.

### 4. Scoped verification is enough

The task's acceptance criteria are provable by its **own** test file alone. If proving them requires a full-suite run, the task is serial — a full-suite run inside a wave measures every sibling at once.

Watch for acceptance criteria that are secretly integration assertions: "the endpoint returns 401", "the migration applies cleanly", "the CLI command works". Those need the whole system, and the whole system is what the wave is mid-way through changing.

### 5. No tree-wide mutation

A task that runs a whole-tree formatter, regenerates a lockfile, re-runs codegen, or reformats `tests/` touches everything at once. Serial.

### 6. Wave size ≤ 4

Beyond four concurrent children, simultaneous builds contend for one `target/` / `node_modules/.cache` / `.mypy_cache`, and the wall-clock win flattens out. Split into consecutive waves instead.

## Worked examples

**Correctly waved.** Four tasks, three waves — because disjoint files are necessary, not sufficient.

```
Task 1: Create src/cart.py, tests/test_cart.py
Task 2: Create src/refund.py, tests/test_refund.py
Task 3: Create src/cart_utils.py (imports Cart from src/cart.py), tests/test_cart_utils.py
Task 4: Modify src/settings.py

**Verdict:** PARALLEL — 2 waves
- Wave 1: Task 1, Task 2 (disjoint, no cross-imports)
- Wave 2: Task 3 (gate 2 — imports Task 1's `Cart`)
- Wave 3: Task 4 (could have joined Wave 1, but keep it simple if it's a one-liner; joining it is also correct)
```

**Wave that looks valid and is not.** Three tasks, three disjoint file sets, one wave — wrong.

```
Task 1: Create src/validate/email.py, tests/test_email.py
Task 2: Create src/validate/phone.py, tests/test_phone.py
Task 3: Modify src/validate/__init__.py (export the validators)
```

Gate 3: Task 3's whole purpose is the barrel file Tasks 1 and 2 are being built underneath. Also gate 2 — it exports symbols they are creating concurrently. Task 3 is serial, last.

**Fully serial, and saying so.**

```
**Verdict:** SERIAL — Tasks 2, 4 and 5 all modify src/routes.py; no two tasks have disjoint file sets.
```

This is worth writing even though it changes nothing, because "serial" and "never considered it" are otherwise indistinguishable to `implement` and to the next reader.

## Writing the verdict

One `## Parallelisation` section, one verdict, plus a `**Parallel:**` line on **every** task including the serial ones:

```markdown
## Parallelisation

**Verdict:** PARALLEL — 2 waves
- Wave 1: Task 1, Task 2 (disjoint file sets, verified pairwise)
- Wave 2: Task 3 (needs Task 1's `AuthError`, so it cannot join Wave 1)
```

```markdown
**Parallel:** wave 1 — disjoint from Task 2 (`src/a.py`, `tests/test_a.py`)
**Parallel:** none — shares `src/routes.py` with Task 2
```

Name the specific reason on each line. `implement` dispatches on these lines and re-checks them against the tree; "wave 1" with no justification is what it has to distrust.

## Common mistakes

| Mistake | Reality |
|---|---|
| Waving tasks because the features are independent | Independence of *features* says nothing about the tree. Gate 1 is about paths. |
| Checking only `Create:` / `Modify:` | `Test:` is a written file too, and shared test helpers are the most common collision. |
| A "wire it up" task in a wave | Registration files, barrel files, route tables, DI containers — gate 3 every time. |
| Trusting `Files:` to be complete | Gate 3's command check exists because verification writes files nobody listed. |
| Making one big wave then splitting on failure | The plan is executed verbatim by an agent that will not re-derive your intent. Get it right here. |
| Waves whose design depends on what wave 1 discovers | That is not a plan, that is exploration — do it before specifying. |
| Writing SERIAL with no reason | Serial is a verdict with a reason, or the next reader cannot tell it from an oversight. |
