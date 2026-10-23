---
name: roadmap
description: Use when a large approved body of work — a codebase audit's findings, a multi-part refactor, a long feature — must be split into tasks and driven to completion autonomously across many sessions. Triggers on "work through all of these", "do this autonomously, don't ask", "finish the refactor", "work through the audit findings", "break this into tasks", "keep iterating until done", or resuming multi-session work after context compaction.
---

# Roadmap

Turn one approved block of work into an ordered task list with explicit parallelism boundaries, then run
it unattended. Pipeline: `research` / `discuss` / `codebase-improvement` → **roadmap** → `specify` →
`implement` → `review` → `finish`.

**The status file is the only memory, and the tree outranks the plan.** A future iteration reading a stale
status file will confidently redo finished work.

Use for: many findings approved at once; work outliving one context window; being told to proceed without
asking. Not a single task (just `specify` → `implement`) and not unapproved scope (`discuss`).

## Step 1 — Measure the gate before any task

Run the project's test/build/lint commands; record the exact baseline, pass **or fail**. An agent once
started a six-finding fix assuming a green suite while `npm test` failed on a broken *invocation* against
perfect code — every later "green" was meaningless. A gate you have not measured is decoration. Require
version control: a shared directory with no git turned two concurrent writers into silent data loss.

## Step 2 — Decompose, then mark the seams

Split into tasks that each end in one commit. Decide **serial or parallel** per pair and record it — a
future reader must not re-derive it.

```
Parallelises:  research, ground-truth surveys, planning, review, audit, verification.
Never:         two children editing the same tree.
```

The gate runs against one working tree, so child A's red gate would be caused by child B's half-finished
edits, destroying the loop's only signal. Read-only agents have no tree to corrupt — fan them out; that is
where the wall-clock win is. Phase order: risk first, then size; cheapest win first inside a phase.

## Step 3 — Verify each task against the tree, every iteration

When text and tree disagree, **the tree is right and the text is stale**. Observed: "split the 1,259-line
file, 6 domains remain" for a file already 178 lines and split; "findings 1–5 are done" on an untouched
baseline. Both promised commits that would change nothing.

**Correcting a status is always right. Widening your assigned slice is not.**
- Tree says done, file says open → mark `done`, cite proof, move on.
- Tree says open, file says done → **fix the status**, then check your slice: do it if it's yours, otherwise
  record it as real unfinished work and continue with your slice.

Target behaviour: a child scoped to one finding found findings 1–5 untouched, fixed the statuses, recorded
them for the next iteration, shipped only its own finding. **A stale tree tells you what is true, not what
you were asked to do.**

## Step 4 — Run the loop

**REQUIRED READ:** `status-file-template.md` — format, protocol, truthfulness rules.

Per iteration: read status file → first `todo` task → `specify`, vetted by a `reviewer` subagent against
real code → ONE `general` subagent implements → gate → commit → mark `done` → update the file **before**
the next task. The orchestrator never edits source itself.

**Roles:** that dispatch is the *orchestrator's* job. As the implementation child you have no subagent
tool — don't stall on it. Do the task, one commit, gate re-run before calling it done, verdicts recorded.
Note once that roles collapsed; a missing tool is not a blocker.

Autonomous mode: never ask the owner. Decide, record the decision and its evidence, continue.

## Step 5 — Ship the record, not just the code

When no task is `todo`: run `review`, then `finish`. Before the last commit write
`<feature>-follow-ups.md` — plan and status file are deleted on ship, so anything deliberately not fixed
dies with them unless written there first.

## Common mistakes

| Mistake | Consequence |
|---|---|
| Implement before measuring the gate | Every later green is unverified |
| "Phase C: IN PROGRESS" prose above `done` rows | Next iteration re-plans finished work |
| Copy a count a test already asserts | Stale in every copy; one was wrong three ways |
| `file:line` citations | Dead or misleading within one branch |
| Mark `done` because the steps ran | Criterion false while recorded complete |
| Silently skip a finding you rejected | Reads as unfinished; gets redone |
| Two implementers in one tree | Overwritten files; gates that mean nothing |
| Widen scope because the tree shows work undone | Unapproved changes shipped as diligence |
| Pay any cost to satisfy a criterion exactly | A Proxy-and-freeze rewrite where a limit note fit |
| Child stalls: "no subagent tool here" | Nothing ships; dispatch is the orchestrator's job |

**Violating the letter of these rules is violating their spirit.** "I'll note the phase status once, it's
obvious" is how four contradictory headings got written.
