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
The whole wave moves at once — planning fans out, it is not one task at a time.

**On every resume, before dispatching anything:** run `git status --porcelain`. Uncommitted edits inside some
task's Owns set mean the previous iteration died **mid-implementation** — that task is `implemented`, not
`todo`, and its siblings may be half-written. Commit or set aside those edits first; never dispatch a new wave
on a dirty tree. Then re-derive every task's state from the table's Status tests (plan file? changelog?
commit?) — the tree outranks whatever value is written, so correct the column before acting on it. Then rebuild
the **session list** (`manage_todo_list`) from the corrected column — one entry per task row, `W<wave> · <task id>`,
replacing whatever entries are there, including an empty list. The list is session-scoped and does not survive
compaction, so on resume it is always wrong: rebuild it rather than trusting it. Map each row's Status to a list
state — `todo`/`planned`/`vetted` → pending, `implemented` → in-progress (that row is the mid-implementation
signal the paragraph above just established), `done` → complete.

Loop protocol, per WAVE, repeat until `status: done`:
1. Read this file. Take the FIRST wave containing a task whose Status is not `done`. Do not pick, reorder, or
   skip. **Re-entering a half-finished wave resumes at the first incomplete step below — never re-dispatch a
   step whose output already exists** (area already in the Grounding reports table → skip grounding it; plan
   file already present → skip planning it).
2. Verify each task in the wave against the tree. Trust the tree over the task text. Re-check the Owns sets
   are still disjoint — the tree outranks this table.
3. Ground: one `researcher` per area not yet grounded, all in one response, each WRITING
   `docs/roadmap/<feature>-ground-<area>.md`. Never ground per task — a planner handed no grounding re-reads
   the whole tree (observed: 359.7k tokens / 88 tool calls / 281% of budget).
4. Plan: dispatch `specify` in CONSUMED MODE to `researcher` (`agentName: "researcher"`) for every todo task in the wave that has NO plan file yet (on
   resume, skip tasks already planned in a half-finished wave), all in one response — marker
   `SPECIFY CONSUMED MODE`, the task text, its Owns set, the grounding FILE PATH (not its contents), and
   `target: docs/roadmap/<feature>-taskNN-<slug>.md`. Not capped at 4; planning is read-only.
5. Vet: one `reviewer` per plan file in one response (max 3 rounds each), told to OPEN the files the plan
   names; findings -> re-dispatch consumed specify to refine the SAME target.
6. Commit the plan docs yourself, by pathspec — the child is forbidden from committing, so an uncommitted plan
   gets re-planned by the next session.
7. Implement the wave per implement's wave protocol (children don't commit; you commit by pathspec; scoped
   tests in-wave; <=4 implementers). In the SAME response, dispatch planning for the NEXT wave's tasks —
   only for areas this wave's implementers do not touch. That overlap is where the wall-clock is won.
8. Run the gate (full suite once per wave). Green -> commit by pathspec -> mark `done` here -> one Changelog
   line. Red -> re-dispatch; never fix by hand in the orchestrator.
9. Update THIS FILE **and the session list** before starting the next wave. Then loop.

Steps 3-8 are roadmap's Step 4, same order, same meaning.

## Gate — establish before task 1, re-run after every wave (and after each serial task)
    <exact commands, from which directory>
Baseline measured at <commit>: <N files / M tests, pass/fail>.

## Dependency graph / waves
The persisted wave grouping — the loop's only memory must carry it, or a future iteration re-derives it from
nothing. One line per wave; note the symbol that forces a later wave.
    Wave 1: A1, A2, A3   (owned file sets disjoint)
    Wave 2: B1           (needs A1's `<symbol>`)

**A chain of all-serial waves usually means the cut is wrong.** Two tasks sharing a file are ONE task — go back
to Step 2 and merge. But if several findings genuinely must edit the same hot file, width-1 is the honest shape:
stop re-cutting, merge down to as few tasks as the ceiling allows (6 steps / 8 files / one test tree), and
**record the reason** here so the next iteration does not re-litigate it:
    Wave 2 width 1 — all findings touch src-tauri/src/inline.rs

## Grounding reports
One per code AREA, written once, read by every planner for that area. Re-ground only if the tree moved inside
the area.
| Area | Report | Grounded at |
|---|---|---|
| harness | `docs/roadmap/<feature>-ground-harness.md` | `<commit>` |

A row here means that area is grounded AT THAT COMMIT. Re-ground only if the tree has moved inside the area
since — `git log --oneline <commit>..HEAD -- <area paths>`, not a feeling.

## Tasks
| # | Task | Area | Plan file | Wave | Owns (file set — disjointness evidence) | Status |
|---|------|------|-----------|------|------------------------------------------|--------|
| A1 | ... | harness | `docs/roadmap/<feature>-task01-<slug>.md` | 1 | `src/cart.py`, `tests/test_cart.py` | `todo` |
| A2 | ... | harness | `docs/roadmap/<feature>-task02-<slug>.md` | 1 | `src/pricing.py`, `tests/test_pricing.py` | `done` `<hash>` |

**Status is exactly one of these, and each is checkable from the tree without asking anyone:**

| Value | True when |
|---|---|
| `todo` | no plan file at the Plan path |
| `planned` | plan file exists |
| `vetted` | plan file exists **and** a Changelog line records the vet round for it |
| `implemented` | the task's edits exist in the tree but are not committed |
| `done` `<hash>` | committed, gate green |

Write the value only when its test passes — `done` still means the acceptance criterion measured true, not that
steps ran. These are task states, not phase prose: never add a sentence summarising a wave's state, derive it
from the rows.

The **Owns** column is load-bearing: on resume, waves can only be re-verified against the tree from what is
written here, and it is what the planner is scoped to. A task whose real edits land outside its Owns set has
broken the wave — fix the table or merge the tasks. **Area** names which grounding report the task reads, so a
resumed loop does not re-ground an area that is already reported. Do not restate the task's prose here; list files.

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

**The session list is an output of this file, never an input.** Never record `manage_todo_list` state here, never
add a column for it, never write "todos updated". On resume the Status column is rebuilt FROM the rows and never
from the list — a list left behind by a compacted session is a claim with no measurement behind it, and the
"only memory" rule above is what stops it from becoming a second source of truth.

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
