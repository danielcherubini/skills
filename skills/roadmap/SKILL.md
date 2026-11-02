---
name: roadmap
description: Use when a large approved body of work — a codebase audit's findings, a multi-part refactor, a long feature — must be split into tasks and driven to completion autonomously across many sessions. Triggers on "work through all of these", "do this autonomously, don't ask", "finish the refactor", "work through the audit findings", "break this into tasks", "keep iterating until done", or resuming multi-session work after context compaction.
---

# Roadmap

Turn one approved block of work into an ordered task list with explicit parallelism boundaries, then run
it unattended.

```
Small scope: entry → specify → implement → review → finish
Large scope: entry → roadmap ( ground → plan every task → vet → implement one wave at a time → gate → fix ) → review → finish
```

Roadmap runs first and **nests** `specify` once per task. The `entry` is whichever skill produced the
approved block: `discuss`, `research`, or `codebase-improvement`.

**The status file is the only memory, and the tree outranks the plan.** A future iteration reading a stale
status file will confidently redo finished work. The one exception is the **session list** — the `manage_todo_list`
entries the user watches live. It is DERIVED from the status file's task rows, never the reverse, and it is never
written into the file.

Use for: many findings approved at once; work outliving one context window; being told to proceed without asking.
Not a single task (just `specify` → `implement`) and not unapproved scope (`discuss`).

## Step 0 — Entry and decompose (no dispatch)

The approved block arrives from an entry skill. Know which one, and what to read:

- **codebase-improvement** → the approved report in `docs/reviews/`. (Always routes here — an audit backlog
  is inherently multi-task.)
- **discuss** → the spec at `docs/roadmap/<topic>.md` (`status: approved`) plus its `issue:` key. **Do NOT
  flip the spec's `status: approved` to `committed`** — `implement` treats `status: committed` as an
  executable plan, so flipping it would offer a task-list-less spec as a plan. Leave it `approved`; the
  existence of `<feature>-status.md` (this skill's memory) is what marks the run in progress.
- **research** → its report in `docs/research/`.

Then:

1. **Decompose.** Draft the tasks by owned file set (see *Partition rules*) and assign each task to an
   **area** — the unit one grounding report covers (Step 1).
2. **Create the feature branch**: see the `trees-and-branches` skill, branch `feature/<topic>` off `main`. Every task
   lands on this one branch — serial tasks commit to it directly; wave tasks land on it via their own task branches,
   fanned in by the wave protocol. Never commit roadmap tasks onto `main`.
3. **Build the session list** with `manage_todo_list`: one entry per task, in wave order, named
   `W<wave> · <task id>` — `W1 · A1`. Use the draft wave; Step 2 re-labels it from the resolved graph. No slug:
   slugs are minted later by consumed `specify`, and a name you invent now will not match the plan filename
   `finish` deletes by. **Replace** any existing entries, never append; the entry skills clear the list before
   routing here, and the list is session-scoped, so it may hold a stale predecessor.

   > 🔒 **Gate: no `subagent` dispatch of any kind — grounding `researcher` and the baseline child included — until
   > the list holds one row per task.** Not one row per wave, and not a single "drive the roadmap run" row: the
   > list's only job is to let the owner watch N parallel tasks move.

   **N=1 skips this** — that branch hands to standalone `specify`, which builds its own list; building one here
   leaves two.

**`<feature>` is defined once, here: it IS the branch topic — `feature/<topic>` → `<feature> = <topic>`.**
Every artifact this skill writes is named from it (`<feature>-status.md`, `<feature>-taskNN-*.md`,
`<feature>-follow-ups.md`) and `finish` deletes by the same name. Never derive it from an audit date, a report
filename, or a spec title, or the status file and task plans will be orphaned on ship. When the entry is
`discuss`, **`<topic>` must be the spec's basename** — if `trees-and-branches` would prepend a ticket id
(`feature/PROJ-12-user-auth`), name the branch `feature/user-auth` instead, or rename the spec to match. The
branch topic and the spec basename have to be the same string or `finish` deletes a family that does not
exist and leaves the real one behind. When the entry is `codebase-improvement` or `research`, there is no
spec file at `docs/roadmap/<feature>.md`; that is expected, and `finish` skips it.

Task branches are named from the same topic — `feature/<topic>-taskNN` — so `git branch --list "feature/<topic>*"` finds them all.

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

## Partition rules (used in Step 0)

**The single biggest cause of a slow run is decomposing by logical unit.** One task per finding, one task per
design section — that is the natural instinct, and on a real codebase it produces a chain of serial waves,
because several findings land in the same file and a wave that collides collapses to one member. Observed: a
12-task audit run where **every wave was serial** — 12 sequential plan+implement round-trips, planning alone
about two thirds of the wall clock. The chain was not a property of the work. It was a property of the cut.

**Partition by disjoint file ownership.** Two tasks that touch the same file can never run together, so they are
one task. Cut so each task owns files no other task touches; the only serial edges left are real build-graph
dependencies. Every task still ends in one commit on the one feature branch, so a run is one branch → one PR.

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

**Merge a serial run into one task.** Four steps that must run one-after-another are one task with four `Steps:`
checkboxes. Coarsen **planning** aggressively (cost is roughly flat); coarsen **implementation** only to a child's
ceiling: about **6 `Steps:` checkboxes, 8 owned files, and one test tree**. Over that, split at a file-set boundary
and accept the serial edge. An implementer that compacts mid-task loses its grounding and re-reads, which costs more
than two smaller children.

**When the graph really is a chain, stop re-cutting.** Width-1 waves are the honest shape when several findings must
edit the same hot file. Merge down to as few tasks as the ceiling allows, and record the reason in the status file
(`Wave 2 width 1 — all findings touch harness.rs`) so the next iteration does not re-litigate it.

Record the ownership set per task in the status file's **Owns** column and the dependency graph in its
persisted section — a future reader must not re-derive either.

```
Parallelises:  research, planning, review, audit, verification, and implementation tasks whose OWNED FILE
               SETS are disjoint.
Never:         two tasks owning the same file, a shared lockfile/migration/barrel, or one shared fixture.
```

Task waves use the **same six parallelisation gates `specify` defines** (in `skills/specify/SKILL.md` and
`skills/specify/guides/guide-parallelisation.md`), applied at task grain — the ownership set is the `Files:`
list at this altitude. **Re-verify the sets against the tree before dispatch** (see *Verification against the
tree*, under Step 2), because a task whose real edits land outside its declared set silently breaks the wave's
disjointness.

The wave protocol (worktrees, fan-in, ≤4 implementers, BLOCKED holds the wave) is **defined** in
`../implement/guides/guide-parallel-execution.md` — reference it, do not restate it. The ≤4 cap counts
**implementers** only: planners and researchers run no build and write only their own unique file, so they fan out
to the width of the graph. The full suite runs **once**, on the integrated tree after fan-in — the one measurement
that can be red for reasons no single child could see.

## Step 1 — Fan out (one response)

Measure the gate and ground every area in one response. The children only read, so they never see a tree
mid-edit.

- **One `ask`:** "Proceed autonomously with this plan?", showing the draft task graph. A yes is the only
  approval for the run (see *Autonomous mode*).
- **One baseline child** (`agentName: "explore"`): run the project's gate command once, scoped to the modules the
  block touches, and report the exit code and pass/fail counts. No reruns, no `cleanTest`, no reading of docs or
  history. Record it **pass or fail**: a gate you have not measured is decoration.
- **One `researcher` per area**, all in one response. Each writes `docs/roadmap/<feature>-ground-<area>.md` with
  **no `status: committed` front-matter** (that key marks an executable plan) and ends with three sections:
  - **`## Will touch`** — every file the change must edit, including callers that need signature changes, DI and
    Spring wiring, shared fixtures, lockfiles and barrels.
  - **`## Provides`** — each existing symbol this area exposes to other tasks, with its verbatim signature.
  - **`## Needs from other areas`** — each symbol this area's tasks consume, with the task that creates it (or
    the file that already defines it).

**Ground once per area, to disk — never per task.** A planner handed no grounding burned **359.7k tokens (281% of
budget) across 88 tool calls**. An **area** is a cluster of files that change together and that planners will share;
size it by what a planner needs to read. Re-ground only when the tree has moved inside it since its report.

## Step 2 — Resolve (orchestrator)

- **Merge on overlap.** Compare every task's `Will touch` list. A file that appears under two tasks → merge those
  tasks into one (see *Partition rules*), and re-check the ceiling.
- **One edge per dependency.** Each `Needs` entry becomes a dependency edge. If the symbol already exists, its
  signature is the verbatim one from the grounding report's `Provides`. If the symbol is **new**, the orchestrator
  fixes its signature here, in the status file's graph. Both the producing and the consuming plan use that exact
  signature. The graph decides the waves.
- **Apply and report.** Apply the merges and report each one to the owner in one line. A merge or re-cut that adds
  or drops approved scope stops and `ask`s (see *Autonomous mode*).
- **Write the status file** (Owns column, dependency graph with signatures, area → report map, baseline record,
  resolved waves). Commit it and the grounding reports by pathspec. The orchestrator owns git; no child is needed.
- **Re-label the session list** from the resolved waves.
- **Mirror the task breakdown** as a NEW COMMENT on the spec's issue (the doc's `issue:` key, carried forward per
  `discuss`'s step 1b / `specify`'s mirror step) — the plan comment is written once here, since consumed mode
  cannot. No spec doc / no `issue:` key (the `codebase-improvement` and `research` entries) → there is nothing to
  mirror to: say so once and continue. No tracker / no `gh` → same. This never gates the run.

### Verification against the tree

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

## Step 3 — Plan every task (one response)

**REQUIRED READ:** `status-file-template.md` — format, protocol, truthfulness rules.

Dispatch consumed `specify` to `researcher` (`agentName: "researcher"`) **for every task in every wave that has
no plan file yet, all in one response** (on resume, tasks already planned are skipped, not re-planned). Each
dispatch carries these fields, in this order:

```
read_skill specify, then follow it.
SPECIFY CONSUMED MODE
Task: <the task's decomposition text>
Owns: <owned file set, from the status file>
Grounding: docs/roadmap/<feature>-ground-<area>.md        (the PATH, not its contents)
Builds on: <verbatim signatures this task consumes, each with its producing task id — or "none">
target: docs/roadmap/<feature>-taskNN-<slug>.md
```

`researcher` writes only that plan file (markdown permissions only; no source, no git). Planning is read-only
and each child writes only its own target, so this fans out to the width of the graph — **not** capped at 4.
A consumed child has no `subagent` tool: you dispatch and vet every plan.

## Step 4 — Vet, then commit the plans (one response)

**Vet** — one `reviewer` per plan file, in one response, one pass. Tell it to **open the files the plan names** —
a plan written from a grounding report that has since gone stale reads fluently and is wrong everywhere, and only
reading the tree catches that. Only 🔴 Critical findings send a plan back: re-dispatch consumed `specify`
(`researcher`) to **refine that same target in place**. Do not fix the plan yourself. Re-vet only the plan you
sent back. Max 3 rounds per plan.

**Commit the plan docs** — by pathspec (`docs: plan <feature> taskNN…`). Consumed `specify` is forbidden from
committing, so if you skip this the plan is never recorded and the next session re-plans it.

## Step 5 — Implement, one wave at a time (one response per wave)

Waves come from the resolved graph (Step 2). A task waits only for the tasks whose signatures it builds on.

Per wave, in order:
- **Mark in-progress.** Every task in the wave in the session list, all at once. Serialising the marks hides the
  concurrency the list exists to show.
- **Dispatch** per the implement wave protocol (`implement/guides/guide-parallel-execution.md` — read its *Running
  the wave* and *The dispatch text for a wave child* sections before the first wave). One `general` child per task
  (`agentName: "general"`), all in one response, **≤4 implementers**.
- **Isolation.** Width ≥2: one worktree and one branch per task (`feature/<topic>-taskNN`), per the
  `trees-and-branches` skill. Width 1: the primary checkout, on the feature branch.
- **Children test only their own files.** Each implementer formats, compiles, runs its own test files, and commits
  on its branch (or on the feature branch at width 1). It does not run the full suite. Step 6 runs it once.
- **DEVIATION rule.** If a child must change a public signature its plan declares, it reports
  `DEVIATION: <old> → <new>` and does not adapt silently. After the wave, re-dispatch the planners of every
  later-wave task whose `Builds on:` names that signature, and re-vet those plans, before the next wave starts.
- **A BLOCKED child holds the wave.** Do not start the next wave while it is outstanding (see the guide's *When part
  of the wave fails*).

The orchestrator never edits source. **Roles:** that dispatch is the orchestrator's job. As the implementation
child you have no subagent tool — don't stall on it. Do the task, one commit, own tests run before calling it
done, verdicts recorded. Note once that roles collapsed; a missing tool is not a blocker.

**Watch the child's budget, not just the count.** A child that compacts mid-task loses its grounding and re-reads
— the 88-tool-call planner above is that failure, not a slow model. If a task blew past the partition ceiling
(6 steps / 8 files / one test tree) and its implementer compacted, split it at a file-set boundary and re-dispatch
two halves; do not simply re-run the same oversized dispatch and hope.

## Step 6 — Gate (orchestrator)

Fan the wave's branches in, in plan order, one merge per task, so every task stays its own commit (the guide's
*Running the wave*, step 3, has the exact `--is-ancestor` and `git diff HEAD^1 HEAD` checks). Then run the
**baseline command** once on the integrated tree, verbosely, and require a non-zero pass count — a green
non-verbose run prints no `--- PASS` lines, so it proves nothing.

Judge against the Step 1 baseline: only **new** failures count. A failure already in the baseline is recorded,
not fixed here. Green → mark each task `done <hash>` in the status file and the session list, add one Changelog
line per task, remove the task worktrees, delete the task branches (git refuses the reverse order), and start the
next wave. Red → Step 7; a red gate reopens every task in the wave in the session list.

Complete a session-list entry only when its Status row reads `done <hash>`.

## Step 7 — Fix in parallel

A red gate is a fan-in failure, and the fix is parallel too.

- **Assign each failure to a task.** Match each failing test or compile error to the task whose **Owns** set
  contains the file. Each task's failures go to one `general` fixer, in a worktree off the merged feature branch.
  Never fix in the primary checkout: two Gradle runs in one tree fight over the build lock.
- **No single owner.** A failure no single task owns (each task green alone, broken together) goes to one fixer
  that owns every file involved.
- **Unclear cause?** Bisect from the wave's base commit, one merge per task (the guide's *When the children report
  success and the suite disagrees*). Do not type the fix yourself.
- **Limit: at most 4 fixers at once**, and at most **2 fix rounds**. Merge the fixes, then run the Step 6 gate
  again. After 2 rounds, mark the affected tasks `blocked` with the evidence in the Blockers section, and stop only
  the waves that depend on them.

## Step 8 — Ship the record, not just the code

When every task's **Status row** reads `done` or `blocked` — read the column, never the session list — run
`review`, then `finish`. Before the last commit write `<feature>-follow-ups.md` — plan and status file are deleted
on ship, so anything deliberately not fixed dies with them unless written there first. On ship, `finish` deletes
the whole `docs/roadmap/<feature>-*` family (plan, status, task plans, and follow-ups) after any follow-ups content
is folded into `docs/features/` or an ADR. Blocked tasks go into the follow-ups file.

**Clear the session list here — you own this, `review` and `finish` do not do it.** Do it after the follow-ups
content is folded and before `finish` deletes the family, so the owner sees the run close rather than vanish.

## Autonomous mode

Never ask the owner **after** the Step 0 entry confirmation, except for:
- a Step 2 merge or re-cut that adds or drops approved scope;
- `review`'s Phase 8 delivery decision (open a PR / merge), and `finish`'s merge gates — an ambiguous merge mode
  (`finish` Step 1) and **pending human reviewers** (`finish` Step 3, "Wait for review" / "Merge anyway"). Never
  auto-merge over an unsubmitted human review: that ask exists precisely so you cannot.

Otherwise decide, record the decision and its evidence, and continue.
## Common mistakes

| Mistake | Consequence |
|---|---|
| Implement before measuring the gate | Every later green is unverified |
| "Phase C: IN PROGRESS" prose above `done` rows | Next iteration re-plans finished work |
| Copy a count a test already asserts | Stale in every copy; one was wrong three ways |
| `file:line` citations | Dead or misleading within one branch |
| Mark `done` because the steps ran | Criterion false while recorded complete |
| Silently skip a finding you rejected | Reads as unfinished; gets redone |
| Two implementers dispatched into one tree | Each child must get its own worktree; sharing one reintroduces clobbered files and a suite result that measures a sibling |
| Each child runs the full suite | The suite runs N+1 times per wave and only the integrated run measures the wave. Children run their own test files |
| Planning a wave after implementing the one before | Serialises the run. Plan every task in Step 3, before any implementer starts |
| Widen scope because the tree shows work undone | Unapproved changes shipped as diligence |
| Pay any cost to satisfy a criterion exactly | A Proxy-and-freeze rewrite where a limit note fit |
| Child stalls: "no subagent tool here" | Nothing ships; dispatch is the orchestrator's job |
| Telling the consumed-`specify` child to "ground with researcher and vet with reviewer" | Those dispatches silently never happen — a child has no subagent tool. YOU dispatch researcher and reviewer; the child only writes the plan |
| One task per finding / per design section | Same file lands in two tasks → every wave collapses to one member → a chain of serial waves. Partition by owned file set instead |
| Four serial steps split into four tasks | Four `specify` dispatches and four implementers where one of each was enough. Merge a serial run into one task |
| Handing each planner no grounding, or the report pasted through your context | Each planner re-reads the whole tree: observed 359.7k tokens / 88 tool calls / 281% of budget, compacting and re-reading. Ground once per area **to disk**; pass the planner the path |
| Applying the ≤4 wave cap to planners | The cap is for build cost — per-worktree dependency installs and shared global caches. Planning is read-only — fan it out to the width of the graph |
| Session list never built, or updated in a batch at the end | The list is the owner's only live view of a run that can span hours and waves. Unbuilt, the run looks stalled and gets interrupted mid-wave; batched, it lies about which tasks are finished |
| Session list says complete, Status row cannot read `done` | Two artifacts disagreeing is the exact failure the truthfulness rules exist to prevent — the next iteration trusts the file and the owner trusts the list, and both are wrong about different tasks |

**Violating the letter of these rules is violating their spirit.** "I'll note the phase status once, it's
obvious" is how four contradictory headings got written.
