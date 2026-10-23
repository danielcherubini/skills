---
name: roadmap
description: Use when a large approved body of work — a codebase audit's findings, a multi-part refactor, a long feature — must be split into tasks and driven to completion autonomously across many sessions. Triggers on "work through all of these", "do this autonomously, don't ask", "finish the refactor", "work through the audit findings", "break this into tasks", "keep iterating until done", or resuming multi-session work after context compaction.
---

# Roadmap

Turn one approved block of work into an ordered task list with explicit parallelism boundaries, then run
it unattended.

```
Small scope: entry → specify → implement → review → finish
Large scope: entry → roadmap → ( specify → implement per task, in waves ) → review → finish
```

Roadmap runs first and **nests** `specify` once per task. The `entry` is whichever skill produced the
approved block: `discuss`, `research`, or `codebase-improvement`.

**The status file is the only memory, and the tree outranks the plan.** A future iteration reading a stale
status file will confidently redo finished work.

Use for: many findings approved at once; work outliving one context window; being told to proceed without
asking. Not a single task (just `specify` → `implement`) and not unapproved scope (`discuss`).

## Step 0 — Entry

The approved block arrives from an entry skill. Know which one, and what to read:

- **codebase-improvement** → the approved report in `docs/reviews/`. (Always routes here — an audit backlog
  is inherently multi-task.)
- **discuss** → the spec at `docs/roadmap/<topic>.md` (`status: approved`) plus its `issue:` key. **Do NOT
  flip the spec's `status: approved` to `committed`** — `implement` treats `status: committed` as an
  executable plan, so flipping it would offer a task-list-less spec as a plan. Leave it `approved`; the
  existence of `<feature>-status.md` (this skill's memory) is what marks the run in progress.
- **research** → its report in `docs/research/`.

Then:

1. Run **Step 1** (measure the gate baseline). This is mandatory and is not repeated here.
2. Run **Step 2** (decompose into tasks and mark the seams). Not repeated here.
3. Present **once** — the measured baseline, the task dependency graph, and the wave breakdown — and ask a
   single `ask` ("Proceed autonomously with this plan?"). After yes, **never ask again** until done.
   **Roadmap owns the issue-tracker mirror and the commits that consumed `specify` declines.** Mirror the task
   breakdown as a NEW COMMENT on the spec's issue (the doc's `issue:` key, carried forward per `discuss`'s
   step 1b / `specify`'s mirror step) — the plan comment is written once here, since consumed mode cannot.
   No spec doc / no `issue:` key (the `codebase-improvement` and `research` entries) → there is nothing to
   mirror to: say so once and continue. No tracker / no `gh` → same. This never gates the run.
4. Create the feature branch: see the `gitflow-branching` skill, branch `feature/<topic>` off `main`. All N
   tasks commit to this one branch. Never commit roadmap tasks onto `main`.

**`<feature>` is defined once, here: it IS the branch topic — `feature/<topic>` → `<feature> = <topic>`.**
Every artifact this skill writes is named from it (`<feature>-status.md`, `<feature>-taskNN-*.md`,
`<feature>-follow-ups.md`) and `finish` deletes by the same name. Never derive it from an audit date, a report
filename, or a spec title, or the status file and task plans will be orphaned on ship. When the entry is
`discuss`, **`<topic>` must be the spec's basename** — if `gitflow-branching` would prepend a ticket id
(`feature/PROJ-12-user-auth`), name the branch `feature/user-auth` instead, or rename the spec to match. The
branch topic and the spec basename have to be the same string or `finish` deletes a family that does not
exist and leaves the real one behind. When the entry is `codebase-improvement` or `research`, there is no
spec file at `docs/roadmap/<feature>.md`; that is expected, and `finish` skips it.

### N=1 degenerate

If decomposition yields exactly one task → skip this skill entirely: hand straight to **standalone
`specify`** (no status file, no waves). Roadmap's value is strictly N≥2 or cross-session work; running the
status-file machinery for a single task is pure overhead.

When the entry was `codebase-improvement` or `research` there is no `docs/roadmap/<topic>.md` for specify's
"No file" branch to find — **pass the approved block's content forward in the handoff text** (the finding or
the track, verbatim), and name the report path so specify plans from it instead of asking the user to re-state
the spec.

## Grain split

Roadmap and `specify` are not peers — they are a coarse grain over a fine grain.

- **Roadmap = COARSE:** an approved block → N tasks → dependency graph → waves. It carries **no file paths,
  signatures, or TDD steps**; that fine detail does not exist yet at this altitude.
- **Specify = FINE:** one roadmap task → one commitable plan (exact files, signatures, test commands).
  A consumed-mode plan is always **single-task and therefore always SERIAL** — `specify`'s six gates and
  `## Parallelisation` verdict are trivially satisfied, and it emits no `**Parallel:**` lines. Parallelism in
  a roadmap run lives **between tasks** (waves), never inside one.

Roadmap **delegates** the fine-grain plan to `specify` and does not re-derive it. Do not restate specify's
gates here; point at them.

## Step 1 — Measure the gate before any task

Run the project's test/build/lint commands; record the exact baseline, pass **or fail**. An agent once
started a six-finding fix assuming a green suite while `npm test` failed on a broken *invocation* against
perfect code — every later "green" was meaningless. A gate you have not measured is decoration. Require
version control: a shared directory with no git turned two concurrent writers into silent data loss.

## Step 2 — Decompose, then mark the seams

Split into tasks that each end in one commit. Decide **serial or parallel** per pair and record it — a
future reader must not re-derive it. N tasks = **N commits on ONE feature branch → one PR** at review.

Task waves use the **same six parallelisation gates `specify` defines** (they live in `skills/specify/SKILL.md`
and `skills/specify/guides/guide-parallelisation.md`), applied at task grain. Roadmap tasks carry no `Files:`
lists, so disjointness is judged at decomposition time from each task's declared seam, then **re-verified
against the tree before dispatch** (Step 3: the tree outranks the text).

```
Parallelises:  research, ground-truth surveys, planning, review, audit, verification — and independent
               implementation tasks whose seams are disjoint files.
Never:         two tasks editing the same file, a shared lockfile/migration/barrel, or one shared fixture.
```

The wave protocol itself (children never commit; the orchestrator commits by pathspec; scoped in-wave tests;
full suite once per wave; ≤4 per wave; a BLOCKED sibling holds the wave) is **defined** in
`../implement/guides/guide-parallel-execution.md` — reference it, do not restate it.

The gate runs against one working tree, so child A's red gate would be caused by child B's half-finished
edits, destroying the loop's only signal. Disjoint-file tasks are safe to run together (no shared content, no
commit — the orchestrator commits). Read-only agents have no tree to corrupt at all — fan them out; that is
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

Per iteration: read status file → first `todo` task → if its wave siblings are disjoint (judged from the
**Seam** column), dispatch them together per the wave protocol, else one at a time. Expand each task with `specify` in **consumed mode** by
passing the literal marker `SPECIFY CONSUMED MODE`, the task's decomposition text (so specify knows which
single task to plan), and `target: docs/roadmap/<feature>-taskNN-<slug>.md`. Stage/commit the produced task
plan docs yourself — in their own `docs: plan <feature> taskNN` commit or folded into that task's pathspec
commit (consumed `specify` is forbidden from committing, so you own it). The orchestrator commits source by
pathspec, runs the full suite once per wave (and after each serial task), marks `done`, and updates the file
**before** the next task. The orchestrator never edits source itself.

**Roles:** that dispatch is the *orchestrator's* job. As the implementation child you have no subagent
tool — don't stall on it. Do the task, one commit, gate re-run before calling it done, verdicts recorded.
Note once that roles collapsed; a missing tool is not a blocker.

Autonomous mode: never ask the owner **after** the Step 0 Entry confirmation. Decide, record the decision and its evidence, continue. Asks that remain permitted at the very end of Step 5 (they are gates on shipping, not mid-loop questions):
`review`'s Phase 8 delivery decision (open a PR / merge), and `finish`'s merge gates — an ambiguous merge mode
(`finish` Step 1) and **pending human reviewers** (`finish` Step 3, "Wait for review" / "Merge anyway").
Never auto-merge over an unsubmitted human review: that ask exists precisely so you cannot.

## Step 5 — Ship the record, not just the code

When no task is `todo`: run `review`, then `finish`. Before the last commit write
`<feature>-follow-ups.md` — plan and status file are deleted on ship, so anything deliberately not fixed
dies with them unless written there first. On ship, `finish` deletes the whole `docs/roadmap/<feature>-*`
family (plan, status, task plans, and follow-ups) after any follow-ups content is folded into
`docs/features/` or an ADR.

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
