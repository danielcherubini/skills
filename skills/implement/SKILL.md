---
name: implement
description: Use when an approved body of work must be executed — a written implementation plan is ready to run, a Jira issue or ticket link is given to implement, or a large approved block (a codebase audit's findings, a multi-part refactor, a long feature, multiple implementation tracks) must be split into tasks and driven to completion autonomously across many sessions. Triggers on "execute this plan", "implement this", a ticket key, "work through all of these", "do this autonomously, don't ask", "finish the refactor", "work through the audit findings", "break this into tasks", "keep iterating until done", or resuming multi-session work after context compaction.
---

# Implement

> 🚨 **CORE RULE: This skill dispatches `general` subagents to do the work. The main agent orchestrates — it does NOT write code, edit files, or run builds directly.**
>
> Two carve-outs, both git-only: the **Baseline Check** before Task 1, and the **gate** after a wave — merging each task's branch and running the full suite on the integrated result (see *Gate*). No child can do either: they each see only their own branch, and the integrated tree is the first place the whole wave exists together. It is a narrow exception: never an inline code edit, never a fix to a child's implementation, never a build to "check" a child's work.

Two paths share one set of execution primitives. They differ in **memory and autonomy**, not in mechanics.

```
COARSE  approved block → decompose by owned file set → ground → plan every task → vet
        → implement one wave at a time → gate → fix → review → finish
        (status file = memory; one consent question, then autonomous)

LIGHT   one plan → baseline → dispatch per task → gate → review → finish
        (todo list = memory; the plan's own approval gate starts it)
```

**The tree outranks the plan, and on the coarse path the status file is the only memory.** A future iteration reading a stale status file will confidently redo finished work. The one exception is the **session list** — the `manage_todo_list` entries the user watches live. It is DERIVED from the status file's task rows, never the reverse, and is never written into the file.

## Which path

Decide from the shape of the work, then **state the path and the reason in one line** — the reason is what lets the user catch you being wrong.

| Shape | Path |
|---|---|
| A decomposed block of **N≥2** tasks, or work that outlives one context window, or "run unattended / do all of these / across sessions" | **COARSE** |
| **One plan** — a `status: committed` doc with no `parent:` key, a ticket, or an approved block that resolves to a single commitable unit | **LIGHT** |

**N=1 is a real path, not a failure.** Earlier this skill refused single-plan work and handed it to `specify`; that handoff is gone. Running the status-file machinery for one task is pure overhead, and refusing the work is worse — so a single task takes the LIGHT path and stays here.

If the entry is `discuss` / `research` / `codebase-improvement` handing you an approved block, decompose it first (COARSE Step 0) and let the decomposition decide the path.

---

# Shared primitives

Both paths use these. Neither re-derives them.

## Branch Setup

Load the `trees-and-branches` skill. Determine whether this work is part of a **stack** (check the plan for "Stack:" or "builds on `stack/...`"):

- **Simple (single PR):** create `feature/<topic>` from `main`.
- **Stacked:** create `stack/<sub-plan-name>` from the previous stack branch (or trunk for the first), then `gh stack init` and `gh stack submit`.

**`<feature>` IS the branch topic — `feature/<topic>` → `<feature> = <topic>`.** Every artifact is named from it (`<feature>-status.md`, `<feature>-taskNN-*.md`, `<feature>-follow-ups.md`) and `finish` deletes by the same name. Never derive it from an audit date, a report filename, or a spec title, or the status file and task plans are orphaned on ship. When the entry is `discuss`, **`<topic>` must be the spec's basename** — if `trees-and-branches` would prepend a ticket id (`feature/PROJ-12-user-auth`), name the branch `feature/user-auth` instead, or rename the spec to match. The branch topic and the spec basename must be the same string or `finish` deletes a family that does not exist and leaves the real one behind. When the entry is `codebase-improvement` or `research`, there is no spec file at `docs/roadmap/<feature>.md`; that is expected, and `finish` skips it.

Task branches come from the same topic — `feature/<topic>-task$n`, so `for n in 1 2 3` yields
`-task1`, `-task2`, **unpadded** — and `git branch --list "feature/<topic>*"` finds them all. Note the
asymmetry: plan *files* are zero-padded (`<feature>-taskNN-<slug>.md`), branches are not, so no single
glob covers both and nothing should pattern-match branch names as if they were padded. **Never commit
onto `main`.**

**Do not create task worktrees here.** They branch from the feature branch's tip, so they come into existence per wave, *after* the Baseline Check — created before it, they would fork the pre-fix base and every child would inherit the broken gate you were about to repair.

> 🔒 **Gate: no `subagent` dispatch of any kind — grounding `researcher`, planning, baseline child included — until the branch exists and the session list is built.** On the coarse path the list must hold **one row per task** (`W<wave> · <task id>`), not one row per wave and not a single "drive the run" row: the list's only job is to let the owner watch N parallel tasks move. **Replace** any existing entries, never append — the list is session-scoped and may hold a stale predecessor.

## Baseline Check (mandatory before Task 1)

Before dispatching a single implementer, run the project's full test/lint/build suite and record the results:

```bash
# Whatever the project's CI check is (go test, npm test, cargo test, …)
# Capture every FAIL, ERROR, and lint warning
```

**Rule: you own every failure in CI — pre-existing or not.** A PR that introduces zero regressions but leaves pre-existing failures still gets rejected; the gate does not know what was broken before you arrived. Fix them or report BLOCKED to the user before proceeding. Record the baseline **pass or fail** — a gate you have not measured is decoration — and keep it in your working notes (or the status file) so later failures can be read as new vs pre-existing.

## Task Dispatch Protocol

> ⚠️ **DISPATCH GUARD — READ BEFORE EVERY TASK**
>
> - **You MUST dispatch a `general` subagent for each task.**
> - **DO NOT write code, edit files, or run builds directly in your own context.**
> - **Update the session list per task — in-progress BEFORE dispatch, completed IMMEDIATELY after DONE. Batching list updates at the end is a failure.**
> - If you skip dispatch, you forfeit TDD, per-task commits, and isolation — the entire point of this skill.
> - The exceptions are: the Baseline Check; the gate — merging branches and running the post-wave suite; and the final review/PR steps. Nothing else.

**Step 1 — STOP & Verify.** Before touching anything:
- [ ] This is a task from the plan, not a tangent
- [ ] No code has been written yet in this context
- [ ] You are about to dispatch a `general` subagent (not do the work yourself)
- [ ] You have marked this task **in-progress** in the session list via `manage_todo_list` (required before Step 2)

**Step 2 — Dispatch.**

> **DO NOT add a `model` parameter to any subagent call.** The agent definition controls its own model; adding `model` causes hallucinated model names that break the call.

```
subagent({
  agent: "general",
  task: "[FULL TEXT of task from plan — paste it, don't make the agent read a file]\n\nContext: [where this fits, dependencies, what's already done]",
  description: "Implement Task N: [task name]"
})
```

The `general` agent already knows to: maintain its own todo list (in-progress before each step, completed immediately after); load the TDD skill and follow RED-GREEN-REFACTOR; validate format → build → test → lint in order; commit with a descriptive message — serial and wave tasks both commit, each on the branch it was given (**a wave child commits on `feature/<topic>-taskN`, never the feature branch — state the branch or it commits where it started**); report DONE | BLOCKED | NEEDS_CONTEXT.

**Step 3 — Verify dispatch happened.**
- [ ] The response includes file edits, test runs, and a **commit SHA on the task's own branch** (a wave task's SHA on the feature branch means it worked in the wrong tree)
- [ ] You did NOT write code, edit files, or run builds in your own context
- [ ] If you find you did the work inline — stop and re-dispatch the subagent immediately

**Step 4 — Handle the response:**
- **DONE:** mark the task complete in the session list IMMEDIATELY, before dispatching the next task. In a wave, mark a task complete only once *you* have merged its branch and the integrated suite is green — a returned-but-unmerged task is not done.
- **NEEDS_CONTEXT:** provide the missing info, re-dispatch (task stays in-progress)
- **BLOCKED:** assess the blocker, provide help or escalate (task stays in-progress until resolved)

> 🔁 **If you catch yourself doing work inline instead of dispatching — stop, reset, and dispatch.** This is the #1 failure mode of this skill.

Default to dispatching **one task per response, sequentially**. Run tasks concurrently ONLY when the wave check has verified them disjoint. The hazard is the file sets: two children editing one file produce one commit that is neither task's work. Each isolated child gets its own worktree, so a collision is now a merge conflict at fan-in rather than a corrupted index — recoverable, but still wasted work. If you have not explicitly verified disjoint file sets, you are running serially.

## Wave Planning (read the evidence, then decide — do not guess)

Before dispatching Task 1, get the disjointness evidence and **independently re-verify it**. A plan's verdict came from a planner that has not seen the tree since it wrote the plan; you have just run the baseline and you are about to touch those files. Trust your check, not its label.

Two grains, one protocol:
- **Intra-plan (LIGHT):** the plan's `## Parallelisation` verdict and each task's `**Parallel:**` line; the evidence is each task's `Files:` list.
- **Coarse (COARSE):** the status file's wave grouping; the evidence is each task's **`Owns`** column — its owned file set — re-verified against the tree.

**Verify per wave, mechanically:** collect the file sets (Create + Modify + Test together); compare pairwise — any shared path (shared fixtures, snapshot dirs, `mod.rs`/`__init__.py`/barrel files, route/middleware registration, config, lockfiles, migrations) invalidates the wave; check the build graph for a task consuming a symbol another task in the same wave is creating; split waves larger than **4 implementers** (concurrent builds contend on global caches, and each worktree pays its own dependency install). Read-only dispatches — planners, researchers — run no build and are **not** capped.

Disjointness is about **merge safety**, not index safety: each child works in its own worktree, so siblings cannot clobber each other. What disjointness does *not* buy is a working build — two children can add the same symbol in different files and neither sees it. That is what the post-wave suite is for.

**Then decide, in this order:**

1. **Integrity first.** No `## Parallelisation` section, a missing `**Parallel:**` line, or a line contradicting its own `Files:` list → **the plan's parallel claims are untrustworthy as a set: run fully serial.** Do not re-derive anything — with unreliable labels, any grouping you invent is speculation dressed as verification. Name the integrity failure. **A missing verdict means SERIAL, never "ask the user."**
2. **Declared wave passes the checks → run it.**
3. **A failing wave dissolves that grouping, not the plan.** Re-derive from the file sets; survivors often form smaller valid waves (1+2 disjoint while 3 imports 1's symbol → Wave 1: {1,2}, Wave 2: {3}). Re-running the same mechanical check on a *smaller* grouping is verification. **Never *expand* a wave beyond what the pairwise check proves.**
4. **Nothing clears → fully serial.**

**State your mode in one line, then proceed — no `ask`; this is your decision.** `Executing SERIALLY — Tasks 2 and 4 both modify src/routes.py, so the plan's Wave 1 is invalid.` / `Executing in 2 waves — Wave 1: Tasks 1, 2 (verified disjoint); Wave 2: Task 3 (imports Task 1's Cart).` A bare "going parallel now" is not a mode statement — **the reason is what lets the user catch you being wrong.**

Full protocol, worked examples, failure handling, the BLOCKED-sibling sequence: **[Parallel Execution Guide](guides/guide-parallel-execution.md)**.

## Running a wave

Each task in a wave of **width ≥2** gets **its own worktree on its own branch**, per the `trees-and-branches` skill. A wave that comes out **width 1 is just a serial task** — nothing else touches the tree, so use the serial path and skip the worktree, the branch, and the merge.

**1. One response, one `subagent` call per task in the wave.** Parallel calls from one response execute concurrently — N tasks take about the wall-clock of one. Separate responses is serial dispatch wearing a wave costume.

**2. Create the worktrees before dispatching anything**, all from one base:

```bash
BASE=$(git rev-parse HEAD)                                  # every task branches from here
for n in 1 2 3; do
  git worktree add "../$(basename "$PWD")-task$n" -b "feature/<topic>-task$n" "$BASE"
done
```

One shared `$BASE` makes the fan-in a clean replay **and** is your bisect boundary.

**3. Dispatch.** A wave child must be given its worktree path and must verify it: its shell starts in the *session* directory, and if that is itself a git repo a bare `git commit` lands in the wrong repository **with no error**.

```
subagent({
  agent: "general",
  task: "[FULL TEXT of task]\n\nContext: [where this fits, what's already done]\n\nPARALLEL WAVE — you have your own worktree:\n- WORKTREE: /abs/path/repo-task1   BRANCH: feature/<topic>-task1\n- FIRST ACTION: cd /abs/path/repo-task1 && git rev-parse --show-toplevel. It MUST print exactly that path. Anything else → STOP, report BLOCKED; a bare git command would commit into an unrelated repo silently.\n- Prefix EVERY git command with that cd. Commit on your branch with the plan's commit message.\n- Touch ONLY the files in your Files:/Owns: list; need one outside it → report NEEDS_CONTEXT, do not edit it.\n- Format your files, compile, and run only your own test files — do not run the full suite. The orchestrator runs it once after fan-in.\nReport DONE with your commit SHA and file list."
})
```

**4. Then, for the wave as a unit:**

1. **Wait for all of them** — the wave is a barrier. Never start wave N+1 while any wave-N task is outstanding.
2. **Fan in, in plan order**, one merge per isolated task so every task stays its own commit: `git merge --no-edit feature/<topic>-taskN`, then confirm it landed — `git merge-base --is-ancestor feature/<topic>-taskN HEAD`, and `git diff --stat HEAD^1 HEAD` must list only that task's files. Do **not** use `git show --stat HEAD`: on a merge commit it prints no file list, so the check passes having verified nothing. Expect the first merge to fast-forward (the feature branch has no commits of its own yet) — no merge commit exists to point at. A conflicting merge is the collision the disjointness check missed: resolve it by re-dispatching one task against the other's merged result, **not** by hand-editing both.
3. **Run the full suite on the integrated tree.** Children ran only their own tests, so this is the first full-suite run describing what you merged. **Prove it executed tests rather than trusting its exit code** — a package with no discovered test files still exits 0 (`go test ./...` prints `?   pkg   [no test files]`), and a *non-verbose* green run prints no `--- PASS` lines at all. Run verbosely and require a non-zero pass count: `go test -v ./...` → count `--- PASS`. A failure here is usually the seam between two siblings' work, invisible to both. Diagnose by bisecting from `$BASE`, then fix by re-dispatching: **you may not type the fix yourself.**
4. **Mark every task complete individually**, and only once its merge exists and the integrated suite is green.
5. **Clean up before the next wave:** `git worktree remove` each task worktree, then delete the task branches — git refuses the reverse order.
6. **A BLOCKED sibling holds the wave.** Merge the DONE tasks (they were written to be independently commitable) and leave the blocked worktree alone — its partial edits are isolated on their own branch and cannot contaminate the merge. Resolve or escalate before wave N+1. Do not route around it.

Serial tasks are unchanged: dispatch in the primary checkout, let the child commit as usual.

## Review → PR → Finish

When the work is complete, ask:

```
ask({
  questions: [{
    id: "next-step",
    question: "All tasks complete. What would you like to do next?",
    options: [
      { label: "Review loop" },
      { label: "Open PR only" },
      { label: "Finish plan" }
    ]
  }]
})
```

Then follow the user's choice immediately — do NOT ask for additional confirmation.

**Review loop** — load the `review` skill and run it to completion (explore → classify → reviewer → parse → fix → re-review → loop until clean). Its Phase 8 asks **Open a PR** or **Merge to main**; the merge branch loads `finish`.

**Open PR only** — simple plan:
```bash
git push -u origin [branch-name]
gh pr create --title "[title]" --body "$(cat <<'EOF'
## Summary
- [bullets]

## Test plan
- [ ] [verification steps]
EOF
)"
```
Stacked plan: `gh stack push` then `gh stack submit`. Report the PR URL(s). **Clear the session list.**

**Finish plan** — 1) **clear the session list**; 2) open the PR (the `finish` skill requires one, block format as above); 3) load `finish` to check PR status, merge to main, and complete the plan lifecycle (it deletes the `docs/roadmap/<feature>-*` family).

---

# LIGHT PATH — one plan

Use when the work is a single plan: one `status: committed` doc, a ticket, or an approved block that resolves to one commitable unit. **No status file, no autonomous mode, no per-task planning fan-out.** The session list is your only memory.

## 1. Find the plan

**From a Task card.** If your first message carries a `<task id="tsk_…" stage="…">` block, its `<artifacts>` line names the documents the previous session attached — a `plan` or `spec` key is the plan, and it is the durable copy (the file it came from is usually gitignored). Read it with `get_artifact` before looking at the filesystem. Do not ask "which plan?" when the card already names one.

**From a Jira ticket URL / key** (e.g. `KEY-123`): fetch it with the Atlassian MCP's `getJiraIssue`, then check whether the description or linked issues carry the plan or reference a plan file in the repo (`docs/`, `claude-docs/`). Use the ticket's tasks to set up the branch and session list.

**From disk.** List `docs/roadmap/*.md`. A doc is an executable plan when its front-matter says `status: committed`; a `status: approved` doc is a spec awaiting a plan — not executable (`specify` turns it into one).

**Exclude coarse-run bookkeeping** — these are not standalone plans:
- `docs/roadmap/<feature>-status.md` (a coarse run's memory file)
- `docs/roadmap/<feature>-taskNN-*.md` carrying a `parent:` key — per-task plans executed as part of a coarse run; offering one here would run a slice of a feature with its dependencies unbuilt
- `docs/roadmap/<feature>-follow-ups.md` (staging notes)
- `docs/roadmap/<feature>-ground-*.md` — grounding reports a planner reads; they carry no `status: committed`, so the status gate already rejects them. Do NOT add a `-ground-` name pattern, which would also eat real plans containing the word (`team-ground-rules.md`).

Filter mechanically — the status/parent test is the filter; name patterns are only for the bookkeeping files that DO look like plans:
```bash
for f in docs/roadmap/*.md; do
  [ -e "$f" ] || continue
  case "$f" in *-status.md|*-follow-ups.md|*-task[0-9][0-9]*-*) continue ;; esac
  grep -q '^status: committed' "$f" && ! grep -q '^parent:' "$f" && echo "$f"
done
```
If the only committed docs are coarse-run task plans, say so and ask for the feature branch instead — a run in progress owns them.

## 2. Ask which plan

**Always ask, even if only one candidate exists — do NOT skip the approval gate.**

```
ask({
  questions: [{
    id: "plan",
    question: "Which plan would you like to execute?",
    options: [ { label: "[Plan Name] — [short description]" }, … ]
  }]
})
```

## 3. Run it

Read the selected plan in full, then: Branch Setup → Baseline Check → Wave Planning → Task Dispatch Protocol → Gate → Review → PR → Finish.

Consent is the **one** question above (plus the wave-mode statement, which is a statement, not an ask). Per-task supervision stays: mark in-progress before each dispatch, complete immediately after.

---

# COARSE PATH — an approved block, many tasks

Use for many findings approved at once, work outliving one context window, or being told to proceed without asking. Not a single task (that is the LIGHT path) and not unapproved scope (`discuss`).

## Step 0 — Entry, decompose, consent

The approved block arrives from an entry skill. Know which one, and what to read:

- **codebase-improvement** → the approved report in `docs/reviews/`. (Always routes here — an audit backlog is inherently multi-task.)
- **discuss** → the spec at `docs/roadmap/<topic>.md` (`status: approved`) plus its `issue:` **and `task:`** front-matter keys — `task:` is the Task board card id and, since you are loaded mid-session, the only place you can get it (you never see the `<task>` block). Absent key → no card; skip every card step. **Do NOT flip the spec's `status: approved` to `committed`** — the LIGHT path treats `status: committed` as an executable plan, so flipping it would offer a task-list-less spec as a plan. Leave it `approved`; the existence of `<feature>-status.md` is what marks the run in progress.
- **research** → its report in `docs/research/`.
- **A Task card** → the `<task>` block in your first message; `task:` in a spec's front-matter if there is one.

Then:

1. **Decompose.** Draft tasks by owned file set (see *Partition rules*) and assign each to an **area** — the unit one grounding report covers (Step 1).
2. **If the draft yields exactly one task → take the LIGHT path.** No status file, no waves. The COARSE machinery earns its cost only at N≥2 or across sessions.

   When the entry was `codebase-improvement` or `research` there is no `docs/roadmap/<topic>.md` for `specify` to find — **pass the approved block's content forward in the handoff text** (the finding or the track, verbatim) and name the report path, so `specify` plans from it instead of asking the user to re-state the spec.
3. **Create the feature branch** (Branch Setup).
4. **Build the session list** — one entry per task, in draft wave order, named `W<wave> · <task id>` (`W1 · A1`). Step 2 re-labels it from the resolved graph. No slug: slugs are minted later by consumed `specify`, and a name you invent now will not match the plan filename `finish` deletes by.
5. **Ask the ONE consent question** — the only approval for the run (see *Consent and autonomy*):

```
ask({
  questions: [{
    id: "mode",
    question: "This decomposes into <N> tasks across <M> waves. How should I run it?",
    options: [
      { label: "Autonomously — no further questions until review/finish (recommended for multi-task runs)" },
      { label: "Check in with me after every wave" }
    ]
  }]
})
```

Record the answer in the status file's `mode:` field so a resumed session does not re-ask.

## Grain split (COARSE vs `specify`)

`implement`'s COARSE path and `specify` are not peers — they are a coarse grain over a fine grain.

- **COARSE = the coarse grain:** an approved block → N tasks → dependency graph → waves. It carries **no signatures or TDD steps**; that fine detail does not exist yet at this altitude. It DOES carry each task's **owned file set** — that is the disjointness evidence at this grain, and the only thing making waves verifiable.
- **`specify` = the fine grain:** one COARSE task → one commitable plan (exact files, signatures, test commands). A COARSE task is **one commitable unit, which may be a run of serial steps** — four steps that must follow each other are one task with four `Steps:` checkboxes, not four tasks in four waves. A consumed-mode plan is therefore always **SERIAL**: `specify`'s six gates and its `## Parallelisation` verdict are trivially satisfied and it emits no `**Parallel:**` lines. **Parallelism in a COARSE run lives between tasks (waves), never inside one.**

The COARSE path **delegates** the fine-grain plan to `specify` and does not re-derive it. Do not restate `specify`'s gates here; point at them.

## Partition rules (Step 0)

**The single biggest cause of a slow run is decomposing by logical unit.** One task per finding, one task per design section — the natural instinct, and on a real codebase it produces a chain of serial waves, because several findings land in the same file and a wave that collides collapses to one member. Observed: a 12-task audit run where **every wave was serial** — 12 sequential plan+implement round-trips, planning alone about two thirds of the wall clock. The chain was not a property of the work; it was a property of the cut.

**Partition by disjoint file ownership.** Two tasks that touch the same file can never run together, so they are one task. Cut so each task owns files no other task touches; the only serial edges left are real build-graph dependencies. Every task still ends in one commit on the one feature branch, so a run is one branch → one PR.

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

**Merge a serial run into one task.** Four steps that must run one-after-another are one task with four `Steps:` checkboxes. Coarsen **planning** aggressively (cost is roughly flat); coarsen **implementation** only to a child's ceiling: about **6 `Steps:` checkboxes, 8 owned files, and one test tree**. Over that, split at a file-set boundary and accept the serial edge. An implementer that compacts mid-task loses its grounding and re-reads, which costs more than two smaller children.

**When the graph really is a chain, stop re-cutting.** Width-1 waves are the honest shape when several findings must edit the same hot file. Merge down to as few tasks as the ceiling allows and record the reason in the status file (`Wave 2 width 1 — all findings touch harness.rs`) so the next iteration does not re-litigate it.

Record the ownership set per task in the status file's **Owns** column and the graph in its persisted section — a future reader must not re-derive either.

```
Parallelises:  research, planning, review, audit, verification, and implementation tasks whose OWNED FILE
               SETS are disjoint.
Never:         two tasks owning the same file, a shared lockfile/migration/barrel, or one shared fixture.
```

Task waves use the **same six parallelisation gates `specify` defines** (`skills/specify/SKILL.md` and `skills/specify/guides/guide-parallelisation.md`), applied at task grain — the ownership set *is* the `Files:` list at this altitude. Re-verify against the tree before dispatch. The wave protocol (worktrees, fan-in, ≤4 implementers, BLOCKED holds the wave) is the *Running a wave* section above — reference it, do not restate it.

## Step 1 — Fan out (one response)

Measure the gate and ground every area in one response. The children only read, so they never see a tree mid-edit.

- **One baseline child** (`agentName: "explore"`): run the project's gate command once, scoped to the modules the block touches, and report the exit code and pass/fail counts. No reruns, no `cleanTest`, no reading docs or history. Record it **pass or fail**.
- **One `researcher` per area**, all in one response. Each writes `docs/roadmap/<feature>-ground-<area>.md` with **no `status: committed` front-matter** (that key marks an executable plan) and ends with three sections:
  - **`## Will touch`** — every file the change must edit, including callers needing signature changes, DI and Spring wiring, shared fixtures, lockfiles and barrels.
  - **`## Provides`** — each existing symbol this area exposes to other tasks, with its verbatim signature.
  - **`## Needs from other areas`** — each symbol this area's tasks consume, with the task that creates it (or the file that already defines it).

**Ground once per area, to disk — never per task.** A planner handed no grounding burned **359.7k tokens (281% of budget) across 88 tool calls**. An **area** is a cluster of files that change together and that planners will share; size it by what a planner needs to read. Re-ground only when the tree has moved inside it since its report.

## Step 2 — Resolve (orchestrator)

- **Merge on overlap.** Compare every task's `Will touch` list. A file appearing under two tasks → merge those tasks into one, and re-check the ceiling.
- **One edge per dependency.** Each `Needs` entry becomes an edge. If the symbol already exists, its signature is the verbatim one from the grounding report's `Provides`. If the symbol is **new**, fix its signature here, in the status file's graph; both the producing and the consuming plan use that exact signature. The graph decides the waves.
- **Apply and report** each merge in one line. A merge or re-cut that adds or drops approved scope **stops and `ask`s**.
- **Write the status file** (`Owns` column, graph with signatures, area → report map, baseline record, resolved waves, `mode:`). Commit it and the grounding reports by pathspec. The orchestrator owns git; no child is needed.
- **Re-label the session list** from the resolved waves.
- **Mirror the task breakdown** as a NEW COMMENT on the spec's issue (the doc's `issue:` key, per `discuss` step 1b / `specify`'s mirror step) — written once here, since consumed mode cannot. No spec doc / no `issue:` key (the `codebase-improvement` and `research` entries) → nothing to mirror to: say so once and continue. No tracker / no `gh` → same. This never gates the run.
- **Mirror the status file to the Task card** — the card id comes from EITHER the spec's `task:` key OR the entry skill's handoff (an audit or research entry has no spec doc, so the id can only arrive in the invocation text). Launched from a card and holding no id → ask once. With an id, after writing the status file — and again whenever the run's shape changes, a wave resolving or a task going `blocked` — call `write_artifact(task_id, key: "status", markdown: <the status file's contents>)`. It UPSERTS, so refreshing is the intended use. **`status` is the ONLY key this step writes.** The task breakdown above goes to the TRACKER as an issue comment and never to the card — there is no `comment` artifact key. No id, or no `write_artifact` tool → say so once and continue; never emulate an artifact with a file.

  **This is not a courtesy copy.** The status file is this run's *only memory*. Check whether its path is gitignored (`git check-ignore -q docs/roadmap/<feature>-status.md`); if it is, "commit it by pathspec" does not just skip, it **fails** — `git commit -- <path>` on an untracked ignored file answers *"pathspec … did not match any file(s) known to git"* — and the artifact is then the sole durable copy of the graph, the `Owns` sets and the per-task Status rows.

### Verification against the tree

When text and tree disagree, **the tree is right and the text is stale.** Observed: "split the 1,259-line file, 6 domains remain" for a file already 178 lines and split; "findings 1–5 are done" on an untouched baseline. Both promised commits that would change nothing.

**Correcting a status is always right. Widening your assigned slice is not.**
- Tree says done, file says open → mark `done`, cite proof, move on.
- Tree says open, file says done → **fix the status**, then check your slice: do it if it's yours, otherwise record it as real unfinished work and continue with your slice.

Target behaviour: a child scoped to one finding found findings 1–5 untouched, fixed the statuses, recorded them for the next iteration, shipped only its own finding. **A stale tree tells you what is true, not what you were asked to do.**

## Step 3 — Plan every task (one response)

**REQUIRED READ:** [status-file-template.md](guides/status-file-template.md) — format, protocol, truthfulness rules.

Dispatch consumed `specify` to `researcher` (`agentName: "researcher"`) **for every task in every wave with no plan file yet, all in one response** (on resume, planned tasks are skipped, not re-planned). Each dispatch carries these fields, in this order:

```
read_skill specify, then follow it.
SPECIFY CONSUMED MODE
Task: <the task's decomposition text>
Owns: <owned file set, from the status file>
Grounding: docs/roadmap/<feature>-ground-<area>.md        (the PATH, not its contents)
Builds on: <verbatim signatures this task consumes, each with its producing task id — or "none">
target: docs/roadmap/<feature>-taskNN-<slug>.md
```

`researcher` writes only that plan file (markdown permissions only; no source, no git). Planning is read-only and each child writes only its own target, so this fans out to the width of the graph — **not** capped at 4. A consumed child has no `subagent` tool: you dispatch and vet every plan.

## Step 4 — Vet, then commit the plans (one response)

**Vet** — one `reviewer` per plan file, in one response, one pass. Tell it to **open the files the plan names** — a plan written from a stale grounding report reads fluently and is wrong everywhere, and only reading the tree catches that. Only 🔴 Critical findings send a plan back: re-dispatch consumed `specify` (`researcher`) to **refine that same target in place**. Do not fix the plan yourself. Re-vet only the plan you sent back. Max 3 rounds per plan.

**Commit the plan docs** by pathspec (`docs: plan <feature> taskNN…`). Consumed `specify` is forbidden from committing, so skipping this means the plan is never recorded and the next session re-plans it.

## Step 5 — Implement, one wave at a time (one response per wave)

Waves come from the resolved graph (Step 2). A task waits only for tasks whose signatures it builds on. Per wave, in order:

- **Mark in-progress** — every task in the wave, all at once. Serialising the marks hides the concurrency the list exists to show.
- **Dispatch** per *Running a wave*: one `general` child per task (`agentName: "general"`), all in one response, **≤4 implementers**.
- **Isolation.** Width ≥2: one worktree and one branch per task. Width 1: the primary checkout, on the feature branch.
- **Children test only their own files** — format, compile, run their own tests, commit on their branch (or the feature branch at width 1). Step 6 runs the full suite once.
- **DEVIATION rule.** If a child must change a public signature its plan declares, it reports `DEVIATION: <old> → <new>` and does not adapt silently. After the wave, re-dispatch the planners of every later-wave task whose `Builds on:` names that signature, and re-vet those plans, before the next wave.
- **A BLOCKED child holds the wave.** Do not start the next wave while it is outstanding.

The orchestrator never edits source. **Roles:** that dispatch is the orchestrator's job; as the implementation child you have no subagent tool — don't stall on it. Do the task, one commit, own tests run before calling it done, verdicts recorded. Note once that roles collapsed; a missing tool is not a blocker.

**Watch the child's budget, not just the count.** A child that compacts mid-task loses its grounding and re-reads — the 88-tool-call planner above is that failure, not a slow model. If a task blew past the partition ceiling (6 steps / 8 files / one test tree) and its implementer compacted, split it at a file-set boundary and re-dispatch two halves; do not simply re-run the same oversized dispatch and hope.

## Step 6 — Gate (orchestrator)

Fan the wave's branches in, in plan order, one merge per task, so every task stays its own commit (*Running a wave* step 4 has the exact `--is-ancestor` and `git diff HEAD^1 HEAD` checks). Then run the **baseline command** once on the integrated tree, verbosely, and require a non-zero pass count.

Judge against the Step 1 baseline: only **new** failures count. A failure already in the baseline is recorded, not fixed here. Green → mark each task `done <hash>` in the status file and the session list, add one Changelog line per task, remove the worktrees, delete the task branches (git refuses the reverse order), start the next wave. Red → Step 7; a red gate reopens every task in the wave in the session list.

Complete a session-list entry only when its Status row reads `done <hash>`.

**If the consent answer was "check in after every wave"**, this is where you report the wave's gate result and wait. Autonomously, state the result and continue.

## Step 7 — Fix in parallel

A red gate is a fan-in failure, and the fix is parallel too.

- **Assign each failure to a task.** Match each failing test or compile error to the task whose **Owns** set contains the file. Each task's failures go to one `general` fixer, in a worktree off the merged feature branch. Never fix in the primary checkout: two build runs in one tree fight over the build lock.
- **No single owner.** A failure no single task owns (each green alone, broken together) goes to one fixer that owns every file involved.
- **Unclear cause?** Bisect from the wave's base commit, one merge per task (*When the children report success and the suite disagrees*). Do not type the fix yourself.
- **Limit: at most 4 fixers at once**, at most **2 fix rounds**. Merge the fixes, re-run the Step 6 gate. After 2 rounds, mark the affected tasks `blocked` with evidence in Blockers, and stop only the waves that depend on them.

## Step 8 — Ship the record, not just the code

When every task's **Status row** reads `done` or `blocked` — read the column, never the session list — run `review`, then `finish`. Before the last commit write `<feature>-follow-ups.md`: plan and status file are deleted on ship, so anything deliberately not fixed dies with them unless written there first. On ship, `finish` deletes the whole `docs/roadmap/<feature>-*` family (plan, status, task plans, follow-ups) after any follow-ups content is folded into `docs/features/` or an ADR. Blocked tasks go into the follow-ups file.

**Clear the session list here — you own this; `review` and `finish` do not do it.** Do it after the follow-ups content is folded and before `finish` deletes the family, so the owner sees the run close rather than vanish.

---

## Consent and autonomy

**One consent question per run** — the COARSE Step 0 `mode` ask, or the LIGHT path's plan-selection ask. After that:

**Autonomous mode** — never ask the owner again, except for:
- a Step 2 merge or re-cut that adds or drops approved scope;
- `review`'s Phase 8 delivery decision (open a PR / merge), and `finish`'s merge gates — an ambiguous merge mode (`finish` Step 1) and **pending human reviewers** (`finish` Step 3, "Wait for review" / "Merge anyway"). Never auto-merge over an unsubmitted human review: that ask exists precisely so you cannot.

Otherwise decide, record the decision and its evidence, and continue.

**Check-in mode** — report the gate at each Step 6 and wait. The scope-change and shipping gates above still apply.

A wave-mode statement (`Executing SERIALLY — …`) is a statement, not an ask, in both modes.

## Common mistakes

| Mistake | Consequence |
|---|---|
| Running the status-file machinery for one task | Pure overhead — that shape is the LIGHT path |
| Refusing single-plan work and handing it to `specify` | That handoff is gone; a single task runs the LIGHT path here |
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
| Asking "which plan?" when a `<task>` block named one | The card's `plan` artifact IS the plan and is usually the only durable copy |

**Violating the letter of these rules is violating their spirit.** "I'll note the phase status once, it's obvious" is how four contradictory headings got written.
