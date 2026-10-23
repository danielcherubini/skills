# The status file — format

`docs/roadmap/<feature>-status.md` is the loop's **only memory**. Assume every future reader has been
context-compacted and knows nothing else. Copy this structure; delete the comments.

```markdown
---
status: running            # running | done
mode: autonomous           # autonomous = no mid-loop questions (entry confirmation and the
                           #   review/finish shipping gates are the documented exceptions)
updated: YYYY-MM-DD
---

# <Feature> — STATUS

**READ THIS FIRST on every iteration. This file is the loop's only memory.**

## Mission
One paragraph: what "finished" means, and which source document the work comes from.

## Operating mode
Loop protocol (repeat until `status: done`):
1. Read this file. Take the FIRST task whose Status is `todo`. Do not pick, reorder, or skip.
2. Verify the task against the tree before doing it. Trust the tree over the task text.
3. YOU dispatch `researcher` to ground the task (the plan child cannot — it has no subagent tool).
4. YOU dispatch `specify` in CONSUMED MODE (marker `SPECIFY CONSUMED MODE`, the task text, the grounding
   report, and `target: docs/roadmap/<feature>-taskNN-<slug>.md`).
5. YOU dispatch `reviewer` on the plan file (max 3 rounds); findings -> re-dispatch consumed specify to refine
   the same target. Commit the plan doc yourself — the child is forbidden from committing.
6. Implement: wave siblings together per implement's wave protocol (children don't commit; you commit by
   pathspec; scoped tests in-wave). Serial tasks: one `general` subagent, one commit.
7. Run the gate (full suite once per wave). Green -> commit by pathspec -> mark `done` here -> one Changelog
   line. Red -> re-dispatch; never fix by hand in the orchestrator.
8. Update THIS FILE before starting the next task. Then loop.

## Gate — establish before task 1, re-run after every wave (and after each serial task)
    <exact commands, from which directory>
Baseline measured at <commit>: <N files / M tests, pass/fail>.

## Dependency graph / waves
The persisted wave grouping — the loop's only memory must carry it, or a future iteration re-derives it from
nothing. One line per wave; note the symbol that forces a later wave.
    Wave 1: A1, A2, A3   (disjoint seams)
    Wave 2: B1           (needs A1's `<symbol>`)

## Tasks
| # | Task | Plan file | Wave | Seam (disjointness evidence) | Status |
|---|------|-----------|------|------------------------------|--------|
| A1 | ... | `docs/roadmap/<feature>-task01-<slug>.md` | 1 | `src/cart.py` (owned outright) | `todo` |
| A2 | ... | `docs/roadmap/<feature>-task02-<slug>.md` | 1 | `src/pricing.py` | `done` `<hash>` |

The **Seam** column is load-bearing: on resume, wave 1-3 can only be re-verified against the tree from what is
written here. Record the files/areas each task owns, not a restatement of its text.

## Blockers / open questions
Anything that stops the loop. Empty means empty.

## Decisions log
Dated one-liners. **The only place a fact may be written.**

## Changelog
One line per task: hash, what shipped, gate numbers at that moment.
```

## Rules that keep the file truthful

A real 98-commit run produced ~20 false statements in files like this while its code was fine. Each rule
closes a hole that was actually hit.

**Never write a phase-level status sentence.** Task rows are the only status. Four headings reading
"Phase C: PLANNED + VETTED" sat directly above tables where every row said `done`; a future iteration
re-planned finished work. Derive summaries from the rows at read time.

**Never restate a fact a test or script already owns.** File/export/mock counts, class strings, version
numbers, line numbers: if an assertion or script can produce it, link the assertion. Every hand-copied
instance of one such count went stale — in six places, one of them wrong three ways at once. Write "the
count is pinned by `x.test.ts` — read it there."

**Cite the assertion, not the address.** Name the `it(...)` string, the exported symbol, the named const.
A `file:line` you cannot check is one you cannot trust, and it decays on the next commit.

**Mark a task `done` only when its acceptance criterion measures true** — not when its steps were
performed. A phase was recorded COMPLETE while its criterion ("no module exports a symbol nothing
imports") was measurably false. Fix the code or amend the criterion, and say which you did.

**Cost is a legitimate answer, and it must be recorded rather than silently paid.** Two agents given
"memoize the total without ever serving a stale sum" diverged: one built frozen rows plus Proxy dirty-traps
— correct, and a behaviour change nobody asked for that breaks any future caller mutating a row in place.
The other shipped the cheap cache and pinned the residual hole as a visible `todo` test with the reason
attached. The second is the better call: **prefer the cheap, correct-enough fix plus an honest recorded
limitation over the expensive complete one.** Escalate the design change to a follow-up item instead of
smuggling it in as "finishing the task". The failure to avoid is a green gate hiding an unbounded rewrite.

**Record a rejection as loudly as a delivery.** Decided NOT to do the thing? Write the verdict, the
evidence, and where the proof lives. A silent skip reads as unfinished work and gets redone.

**Changelog figures are historical.** A gate number under a task's entry is what it was *then*. State
current figures once, in one place, labelled current.

## The follow-ups file

The plan, the status file, the task plans, **and this follow-ups file are all deleted on ship** — `finish`
removes the whole `docs/roadmap/<feature>-*` family. So the follow-ups file is a **staging** artifact, not a
permanent survivor: write it before the final commit, and before `finish` runs, **fold its durable content
into `docs/features/` or an ADR** so it outlives the roadmap directory. Each item: what it is, its **status**
(`open work` / `recorded, not open work` / `accepted`), and the reason it was left. Point the status file's
Blockers section at it and do not restate the items.
