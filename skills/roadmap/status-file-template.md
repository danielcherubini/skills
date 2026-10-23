# The status file — format

`docs/roadmap/<feature>-status.md` is the loop's **only memory**. Assume every future reader has been
context-compacted and knows nothing else. Copy this structure; delete the comments.

```markdown
---
status: running            # running | done
mode: autonomous           # autonomous = never ask the owner questions
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
3. Plan it with `specify`; a `reviewer` subagent vets the plan against real code (max 3 rounds).
4. Implement it with ONE `general` subagent. One task = one commit.
5. Run the gate. Green -> commit -> mark `done` here -> one Changelog line.
   Red -> re-dispatch with the failure; never fix by hand in the orchestrator.
6. Update THIS FILE before starting the next task. Then loop.

## Gate — establish before task 1, re-run after every task
    <exact commands, from which directory>
Baseline measured at <commit>: <N files / M tests, pass/fail>.

## Tasks
| # | Task | Plan § | Status |
|---|------|--------|--------|
| A1 | ... | Phase A | `todo` |
| A2 | ... | Phase A | `done` `<hash>` |

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

The plan and the status file are **deleted on ship**, so anything deliberately not fixed must live
somewhere that survives. Write `docs/roadmap/<feature>-follow-ups.md` before the final commit, not after.
Each item: what it is, its **status** (`open work` / `recorded, not open work` / `accepted`), and the
reason it was left. Then point the status file's Blockers section at it and do not restate the items.
