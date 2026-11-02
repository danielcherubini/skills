---
status: approved
done-when: skills/roadmap/SKILL.md and status-file-template.md describe Steps 0–8 below (fan-out → resolve → plan all → vet → per-wave implement → gate → parallel fix → ship); no roadmap step runs a planner or researcher at the same time as an implementer; the pipelining section and the width-1 worktree decision are gone from roadmap and guide-parallel-execution; the consumed-specify dispatch is a literal template that loads the specify skill; SKILL.md is shorter than today's 347 lines.
issue: https://github.com/danielcherubini/skills/issues/8
---

# Roadmap: plan everything first

## Problem

Measured on CLAIMS-17112 (4 small DAO tasks, 2 waves): **127 min** from `$roadmap` to the PR. Children's real working time was a fraction of that. The rest was serial front-loading and dispatches that only ran git:

| Phase | Time | Cause |
|---|---|---|
| Baseline child | 35 min | Open-ended "measure the gate": the same Gradle tests ran ~9 times (`--rerun`, `cleanTest`), then the child read git history and docs |
| Wave 1 ground → plan → vet | 14 min | Fine, but it blocked everything else |
| T1 implement | 17.5 min | Told not to commit |
| T1 gate + commit child | 11 min | Ran the same tests the implementer had just run |
| Wave 2 ground → plan → vet | 22 min | Started only after T1 finished. The optional pipelining rule was never applied |
| Wave 2 implement + gate | 16.5 min | Parallel, fine |
| Git-only children | ~6 min | 5 dispatches just to create the branch, commit docs, update status, open the PR |

The planning stage is serial per wave, even though planning only reads code and could be fully parallel. The skill tries to fix that with "pipeline next wave's planning over this wave's implementation", which takes 27 lines of overlap rules (stale reads, shared mutable files, fan-in timing, width-1 isolation) and was still skipped in practice.

## Decisions

1. **Plan every task in every wave before implementing any.** Planning only reads code, so it fans out to the full width of the task list. This replaces pipelining instead of adding to it. Since nothing reads the tree while implementers run, the overlap rules and the width-1 worktree decision can be deleted.
2. **Later-wave plans build on earlier-wave *plans*.** T2 only needed T1's *signature*, which T1's vetted plan already declares. Implementation still runs in waves, but only where one task really needs another task's code.
3. **One researcher per area, not researcher + explore.** Both would read the same files, and `explore` cannot write a grounding report to disk.
4. **Grounding reports carry a machine-checkable overlap contract** ("Will touch" + "Needs from other areas"). Overlaps cross areas, so no single grounder can see them. The orchestrator compares the reports and detects overlaps from them.
5. **The single approval runs in the same response as the fan-out.** Verified in the pi runtime: tool calls in one response run in parallel unless a tool is `executionMode: "sequential"`, and the desktop `ask` is not. Your thinking time overlaps grounding. After approval, grounding can only *merge* tasks (same scope, fewer tasks), so merges are applied and reported. Anything that adds or drops scope stops and asks.
6. **Test split, hybrid:** children run nothing before starting. After editing, they run compile plus their own test files only. The orchestrator runs the full gate once per wave on the merged tree. This keeps each child's fast compile-and-fix loop in context, with no duplicate full-suite runs.
7. **The orchestrator does its own git.** "The orchestrator never edits source" does not mean "never runs git". It handles branch creation, commits for docs/status, merges, and the PR directly, without a child.
8. **The step 6 gate and the step 7 fixers stay in worktrees, never the main checkout, when more than one runs.** Two Gradle runs in one tree fight over the build lock (T4 ran `ps aux | grep gradle` while blocked).

## Flow

### Step 0 — Decompose (orchestrator, no dispatch)

Draft tasks by owned file set, using the existing Step 2 partition rules and ceiling (≤6 steps, ≤8 files, one test tree). Assign each task to an **area**. Build the session todo list (one row per task, `W<wave> · <id>`).

### Step 1 — Fan out (one response)

- `ask`: "Proceed autonomously?", showing the draft graph.
- **One baseline child.** Runs the gate command **once**, limited to the modules the block touches, and records pass/fail plus counts. No reruns, no `cleanTest`, no investigation: that is grounding's job.
- **One `researcher` per area.** Each writes `docs/roadmap/<feature>-ground-<area>.md` (no `status:` front-matter), ending with:
  - **Will touch:** every file the change must edit, including callers needing constructor changes, DI/Spring wiring, shared fixtures, lockfiles, barrels.
  - **Needs from other areas:** symbols this area uses that another task creates.

### Step 2 — Resolve (orchestrator)

Merge all the Will-touch lists:
- A file listed under two tasks → **merge those tasks.**
- A cross-area symbol → a dependency between tasks; the dependencies decide the waves.
- Merges are applied and reported. Anything that adds or drops approved scope → stop and `ask`.

The orchestrator then writes the status file (Owns column, dependency graph, area → report map, baseline) and commits it with the grounding reports itself.

### Step 3 — Plan everything (one response)

Consumed `specify` via `researcher` for **every task in every wave**, with no cap. The skill gets a literal dispatch template:

```
read_skill specify, then follow it.
SPECIFY CONSUMED MODE
Task: <decomposition text>
Owns: <owned file set>
Grounding: docs/roadmap/<feature>-ground-<area>.md
Builds on: <paths of earlier-wave plans this task depends on, or "none">
target: docs/roadmap/<feature>-taskNN-<slug>.md
```

### Step 4 — Vet (one response)

One `reviewer` per plan, one pass, told to open the files the plan names. Only 🔴 findings go back to that plan's planner to be refined in place, and then only that plan is re-vetted. The orchestrator commits all plans.

### Step 5 — Implement, one wave at a time (one response per wave)

- Width ≥2: one worktree + task branch per task (`feature/<topic>-taskNN`), per the existing protocol. Width 1: the main checkout. Nothing else reads the tree any more, so there is no decision to make.
- Implementer dispatch: no gate run before starting. After editing, compile plus **its own test files only**, then commit on its branch.
- **DEVIATION rule:** if it must change a public signature its plan declares, it reports `DEVIATION: <old> → <new>` and does not quietly adapt. After the wave, the orchestrator re-dispatches the planners of the dependent later-wave plans to refine them before the next wave starts. Nothing else runs during that step.
- ≤4 implementers at once. All of the wave's todo rows are marked in-progress together.

### Step 6 — Gate (orchestrator)

Merge the task branches into the feature branch. Run **the baseline command**, once. Judge the result against the baseline: only new failures count. Green → `done <hash>` in the status file and the session list → next wave.

### Step 7 — Fix in parallel

- Each new failure is matched to a task through the Owns column, and each task's failures go to one fixer.
- Fixers work in worktrees off the merged branch.
- A failure with no single owner (each task green alone, broken together) gets **one** fixer owning all the files involved.
- Merge the fixes, then gate again. After 2 rounds → `BLOCKED` with evidence; only dependent waves stop.

### Step 8 — Ship

Unchanged: follow-ups file → `review` → `finish` → clear the session list.

## Removed

- "Pipeline the next wave's planning over this wave's implementation" and its bounds (SKILL.md, ~27 lines)
- The width-1 worktree decision (SKILL.md Step 4.5, `guide-parallel-execution.md` "When a child gets its own worktree" judgement and mode-line examples, status-file template step 5)
- The per-wave ground → plan → vet loop; the loop becomes implement → gate → fix
- Orchestrator-dispatched children whose only job is git

## Files affected

- `skills/roadmap/SKILL.md`: restructured to Steps 0–8. Net shorter.
- `skills/roadmap/status-file-template.md`: protocol rewritten to match. Records the baseline command, area → report map, and BLOCKED fix rounds.
- `skills/implement/guides/guide-parallel-execution.md`: drop the "reader during a wave" row and the width-1 judgement. Child verification becomes "compile + own tests; the orchestrator's post-fan-in suite is the gate" for **both grains**, because the guide requires both grains to share identical invariants.
- `skills/specify/SKILL.md`: consumed mode accepts the `Builds on:` input (earlier plans whose declared signatures this plan may rely on).

## Out of scope

- Enforcing the researcher's markdown-only permissions. The `permission:` block in `agents/researcher.md` is opencode syntax and pi ignores it. Follow-up: a guard in `pi-gate/gate.ts`, or delete the block.
- Any change to `review` / `finish`.

## Projected impact

Same CLAIMS-17112 shape: **~55–60 min** (fan-out ~7, resolve ~2, plan ~5, vet ~4, W1 ~15 + gate ~3, W2 ~12 + gate ~4, review/PR ~5), down from 127.
