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
2. Run **Step 2** (partition the block into owned-file-set tasks and build the dependency graph). Not repeated here.
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

- **Roadmap = COARSE:** an approved block → N tasks → dependency graph → waves. It carries **no signatures or
  TDD steps**; that fine detail does not exist yet at this altitude. It DOES carry each task's **owned file set**
  — that is the disjointness evidence at this grain, and the only thing making waves verifiable.
- **Specify = FINE:** one roadmap task → one commitable plan (exact files, signatures, test commands).
  A roadmap task is **one commitable unit, which may be a run of serial steps** — four steps that must follow
  each other are one task with four `Steps:` checkboxes, not four tasks in four waves. A consumed-mode plan is
  therefore always **SERIAL**: `specify`'s six gates and `## Parallelisation` verdict are trivially satisfied
  and it emits no `**Parallel:**` lines. Parallelism in a roadmap run lives **between tasks** (waves), never
  inside one.

Roadmap **delegates** the fine-grain plan to `specify` and does not re-derive it. Do not restate specify's
gates here; point at them.

## Step 1 — Measure the gate before any task

Run the project's test/build/lint commands; record the exact baseline, pass **or fail**. An agent once
started a six-finding fix assuming a green suite while `npm test` failed on a broken *invocation* against
perfect code — every later "green" was meaningless. A gate you have not measured is decoration. Require
version control: a shared directory with no git turned two concurrent writers into silent data loss.

## Step 2 — Partition by file ownership, not by finding

**The single biggest cause of a slow run is decomposing by logical unit.** One task per finding, one task per
design section — that is the natural instinct, and on a real codebase it produces a chain of serial waves,
because several findings land in the same file and a wave that collides collapses to one member. Observed: a
12-task audit run where **every wave was serial** — 12 sequential plan+implement round-trips, planning alone
about two thirds of the wall clock. The chain was not a property of the work. It was a property of the cut.

**Partition by disjoint file ownership instead.** Two tasks that touch the same file can never run together —
so they were never siblings; **they are one task.** Cut so that each task owns a set of files no other task
touches, and collisions are impossible by construction: the only serial edges left are real build-graph
dependencies (task B consumes a symbol task A creates), and those are genuine.

Every task still ends in exactly one commit, and every task commits to the one feature branch from Step 0 —
so a run is **one branch → one PR** however the tasks are cut.

Work through the block once, listing every file it touches, then group:

```
1. Inventory   every file the approved block will touch, including lockfiles, barrels,
               shared fixtures, migrations, route/middleware registration.
2. Group       files that must change together (or that any two findings both touch) into ONE owned set.
               That set is one task.
3. Edge        add a dependency only where B consumes a symbol A creates — never because
               A and B "feel related". Related-but-disjoint is exactly what parallel is for.
4. Wave        the transitive levels of that graph. Width is a result of the cut, so if the
               graph comes out a chain, the cut is wrong: re-cut and merge.
```

**Merge a serial run into one task.** Four steps that must run one-after-another are one task with four steps,
not four tasks in four waves — you pay one `specify` and one implementer instead of four of each, and the
plan's `Steps:` checkboxes carry the sequencing and the resume points. Coarsen **planning** aggressively (a
plan for four serial steps is one document, and cost is roughly flat); coarsen **implementation** only to a
child's ceiling.

**The ceiling, as a number you can compute at Step 2:** a merged task should stay under roughly **6 `Steps:`
checkboxes, 8 owned files, and one test tree**. Over that, split it at a file-set boundary and accept the serial
edge. This is deliberately asymmetric — merging is cheap for *planning* and expensive for *implementation*,
because an implementer that compacts mid-task loses its grounding and re-reads, which is worse than two smaller
children. When in doubt, merge the plan and split the work.

**When the graph really is a chain, stop re-cutting.** If several findings must edit the same hot file, width-1
waves are the honest shape of the work and no re-cut fixes it. Then the goal changes from parallelism to
**dispatch count**: merge them into as few tasks as the ceiling allows, and still pipeline next-wave planning
over implementation — a chain of 3 fat tasks beats a chain of 12 thin ones on wall clock even though both are
serial. Record the reason in the status file (`Wave 2 width 1 — all findings touch harness.rs`) so the next
iteration does not re-litigate the cut.

Record the ownership set per task in the status file's **Owns** column and the dependency graph in its
persisted section — a future reader must not re-derive either.

```
Parallelises:  research, planning, review, audit, verification, and implementation tasks whose OWNED FILE
               SETS are disjoint.
Never:         two tasks owning the same file, a shared lockfile/migration/barrel, or one shared fixture.
```

Task waves use the **same six parallelisation gates `specify` defines** (in `skills/specify/SKILL.md` and
`skills/specify/guides/guide-parallelisation.md`), applied at task grain — the ownership set is the `Files:`
list at this altitude. **Re-verify the sets against the tree before dispatch** (Step 3: the tree outranks the
text), because a task whose real edits land outside its declared set silently breaks the wave's disjointness.

The wave protocol itself (children never commit; the orchestrator commits by pathspec; scoped in-wave tests;
full suite once per wave; ≤4 implementers per wave; a BLOCKED sibling holds the wave) is **defined** in
`../implement/guides/guide-parallel-execution.md` — reference it, do not restate it.

The ≤4 cap counts **implementers**, not planners. It exists because concurrent builds contend for one
`target/` / `node_modules/.cache`; a planner runs no build and writes only its own unique plan path, so
planning fans out to the width of the graph and is not capped at 4.

The gate runs against one working tree, so child A's red gate would be caused by child B's half-finished
edits, destroying the loop's only signal. Disjoint-ownership tasks are safe to run together (no shared content,
no commit — the orchestrator commits). Read-only agents have no tree to corrupt at all — fan them out; that is
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

**The unit of the loop is the WAVE, not the task.** Read the status file → the first wave containing a `todo`
task → run the six steps below for the whole wave at once. Their ownership sets are disjoint by construction
(Step 2), which is what makes "all the planners at once" safe.

**You own every sub-agent dispatch in this loop.** A consumed-`specify` run is a dispatched `researcher` child
(`agentName: "researcher"`) and has **no `subagent` tool** — it cannot ground itself with a researcher or vet itself with a reviewer. If you
delegate those to it, they silently do not happen and you ship an un-grounded, un-vetted plan.

**Ground once per area, to disk — never per task.** This is the single biggest cost lever in the loop. Observed:
a consumed-`specify` child handed no grounding burned **359.7k tokens (281% of its budget) across 88 tool calls
and 57 minutes** — it blew its context, compacted, forgot what it had read, and read it again. Every planner you
send without shared grounding repeats that. One `researcher` per code **area** (not per task) writes a report to
`docs/roadmap/<feature>-ground-<area>.md`; every planner for that area reads the file. Re-derivation becomes one
read instead of eighty tool calls.

An **area** is a cluster of files that change together and that planners will share — a module, a subsystem, a
test tree. Size it by what a planner needs to read to plan any task inside it, not by the task list: several
tasks in one area share one report. Record the area → report mapping in the status file.

Per wave, in order:

1. **Ground** — one `researcher` per not-yet-grounded area, all calls in one response: existing files, real
   signatures quoted verbatim, conventions, exact test/build commands, integration points, anything already
   implemented. Each writes `docs/roadmap/<feature>-ground-<area>.md` with NO `status: committed` front-matter —
   that key marks an executable plan, and a report carrying it would get offered to `implement` as one. Re-ground
   an area only when the tree has moved inside it since the report.
2. **Plan** — dispatch consumed `specify` to `researcher` (`agentName: "researcher"`) **for every task in the wave that has no plan file yet, in one
   response** (on resume, tasks already planned in a half-finished wave are skipped, not re-planned) — the literal marker
   `SPECIFY CONSUMED MODE`, the task's decomposition text, its **owned file set**, the **path** to the grounding
   file (not its contents pasted through your context), and
   `target: docs/roadmap/<feature>-taskNN-<slug>.md`. `researcher` writes only the plan markdown file at its target path (markdown permissions only; cannot touch source code or git); planning is read-only and each child writes only its own
   unique target, so this fans out to the width of the graph — **not** capped at 4.
3. **Vet** — one `reviewer` per plan file, in one response (max 3 rounds each). Tell it to **open the files the
   plan names** — a plan written from a grounding report that has since gone stale reads fluently and is wrong
   everywhere, and only reading the tree catches that. Findings → re-dispatch consumed `specify` (`researcher`) to **refine
   that same target in place**; do not fix the plan yourself.
4. **Commit the plan docs** — your commit, by pathspec (`docs: plan <feature> taskNN…`). Consumed `specify` is
   forbidden from committing, so if you skip this the plan is never recorded and the next session re-plans it.
5. **Implement** — dispatch per the wave protocol (children don't commit; you commit by pathspec; scoped tests
   in-wave).
6. **Gate** — full suite once per wave, mark `done`, update the file **before** the next task.

**Pipeline the next wave's planning over this wave's implementation.** A planner reads its own area and writes
only its own plan file; an implementer writes only its owned set. Those do not collide, so while implementers run,
dispatch planning for the next wave's tasks in the same response. Wall clock approaches max(plan, implement)
instead of plan + implement. Four bounds, all of them real:

- **Only plan areas the running wave does not touch.** An implementer's edits land in its owned set; a planner
  reading that set mid-edit records signatures that do not exist yet, and the report is poisoned for every
  planner that reads it afterwards.
- **Shared mutable files belong to the running wave** — lockfile, barrel, `mod.rs`/`__init__.py`, shared
  fixtures, route registration — even if the planner only reads them.
- **Ground the next wave before implementing this one.** A researcher runs no build and is quick; a planner is
  cheap once the report exists. The thing you must not overlap is a *researcher* reading a tree implementers are
  actively mutating.
- **A BLOCKED implementer does not cancel the plans already in flight**, but do not commit them until the wave
  resolves — a re-cut wave invalidates them, and committing plans for a wave that never ran leaves the status
  file describing work that will not happen.

**Watch the child's budget, not just the count.** A child that compacts mid-task loses its grounding and re-reads
— the 88-tool-call planner above is that failure, not a slow model. If a task blew past Step 2's ceiling
(6 steps / 8 files / one test tree) and its implementer compacted, split it at a file-set boundary and re-dispatch
two halves; do not simply re-run the same oversized dispatch and hope.

The orchestrator never edits source itself.

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
| Telling the consumed-`specify` child to "ground with researcher and vet with reviewer" | Those dispatches silently never happen — a child has no subagent tool. YOU dispatch researcher and reviewer; the child only writes the plan |
| One task per finding / per design section | Same file lands in two tasks → every wave collapses to one member → a chain of serial waves. Partition by owned file set instead |
| Four serial steps split into four tasks | Four `specify` dispatches and four implementers where one of each was enough. Merge a serial run into one task |
| Handing each planner no grounding, or the report pasted through your context | Each planner re-reads the whole tree: observed 359.7k tokens / 88 tool calls / 281% of budget, compacting and re-reading. Ground once per area **to disk**; pass the planner the path |
| Applying the ≤4 wave cap to planners | The cap is for build-cache contention. Planning is read-only — fan it out to the width of the graph |

**Violating the letter of these rules is violating their spirit.** "I'll note the phase status once, it's
obvious" is how four contradictory headings got written.
