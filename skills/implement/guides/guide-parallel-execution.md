# Parallel Execution Guide

How to verify a plan's waves against the real tree, run them safely, and commit the result. Load this when the plan declares `**Verdict:** PARALLEL`, **or when the `roadmap` skill applies this protocol to task waves.** The invariants in `implement`'s own text still apply — this is the detail, not a replacement.

## Two grains

This protocol governs waves at **two grains**:

- **(a) Intra-plan** — sub-tasks within one committed plan. `specify` emits the `**Parallel:**` lines, and each task's `Files:` list is the disjointness evidence.
- **(b) Inter-task** — roadmap tasks within a run. `roadmap` emits the wave grouping and judges disjointness from each task's declared seam, re-verified against the tree, since roadmap tasks carry no `Files:` lists.

Both use the **identical invariants**: children never commit, the orchestrator commits by pathspec, scoped in-wave verification, full suite once per wave, ≤4 per wave, a BLOCKED sibling holds the wave. Only the *evidence* for gate 1 (disjoint files) differs by grain. **Roadmap applies this protocol directly and does NOT load the `implement` skill per task.**

## Why you re-verify instead of obeying

The plan's verdict came from a planner that has not seen the tree since it wrote the plan. You have just run the baseline and you are about to touch those files. Three ways the plan can be stale or wrong:

- A file the plan says to Create already exists (someone merged it since).
- The `Files:` list omits something the task's *commands* will write — a lockfile, a snapshot, `conftest.py`.
- Two tasks the planner believed independent now share a newly-added fixture or config file.

Also treat the plan's labels as load-bearing data. A `**Parallel:**` line missing entirely, or one that contradicts its own `Files:` list, means the plan's parallel claims are untrustworthy *as a set* — re-deriving groupings from labels you have proven unreliable is speculation dressed as verification. Fully serial, and say which integrity failure you hit.

## The check

For each declared wave:

**At task grain (roadmap), substitute *declared seam re-verified against the tree* for `Files:` in steps 1–2, and skip the `**Parallel:**`-line integrity test below** — roadmap tasks carry no `Files:` lists and no `**Parallel:**` lines.

1. Collect each task's `Files:` list — Create + Modify + Test together.
2. Compare pairwise. Any shared path fails the wave. Include: shared fixtures, snapshot dirs, `mod.rs` / `__init__.py` / barrel files, route or middleware registration, config, lockfiles, migrations.
3. Check the build graph. Does a task in the wave consume a symbol another task in the same wave is creating? If yes, split — the consumer goes in a later wave.
4. Size. More than 4 → split into consecutive waves; concurrent builds contend for one `target/` / `node_modules/.cache` and the speedup evaporates.

Then, in order:

1. Integrity failure (no `## Parallelisation`, a missing `**Parallel:**` line, or a line contradicting its `Files:` list) → **fully serial**, no re-derivation.
2. Wave passes → run it.
3. Wave fails → *that grouping dissolves, not the plan.* Re-derive from the `Files:` lists; survivors often form smaller valid waves. Re-running the same mechanical check on a **smaller** grouping is verification. **Never expand a wave beyond what the pairwise check proves.**
4. Nothing clears → fully serial.

## Announcing the mode

One line, before dispatching anything, naming the collision or the verification. No `ask` — this is your decision. The reason is the point: it is the only thing that lets the user catch you being wrong.

```
Executing SERIALLY — Tasks 2 and 4 both modify src/routes.py, so the plan's Wave 1 is invalid.
```
```
Executing in 2 waves — Wave 1: Tasks 1, 2 (verified disjoint); Wave 2: Task 3 (imports Task 1's Cart); Wave 3: Task 4.
```

"Going parallel now" is not a mode statement.

## The dispatch text for a wave child

A child's defaults are built for serial execution — it commits, and it runs the project's checks. Both are wrong inside a wave, and both must be overridden in the task text explicitly. Do not assume the child will infer it.

```
PARALLEL WAVE — two deviations from your defaults:
1. DO NOT COMMIT. Leave your changes in the working tree and report the exact
   files you touched. The orchestrator commits your task with its own message.
   A commit here would sweep a sibling's half-finished files into your commit —
   you share one index.
2. VERIFY SCOPED ONLY. Run only your own test file/module and format only your
   own files. Do NOT run the full suite, a whole-tree formatter, or a lockfile
   regeneration — siblings are mid-edit in this same tree, so a full-suite
   result measures everyone at once and cannot tell you whether YOUR code is
   broken.
Report DONE with the file list.
```

## Running the wave

1. **One response, one `subagent` call per task.** Calls emitted together run concurrently — N tasks take roughly the wall-clock of one. Emitting them in separate responses is serial dispatch wearing a wave costume.
2. **Wait for all of them.** The wave is a barrier. Do not start wave N+1 while any wave-N task is outstanding.
3. **Commit each task separately, by explicit pathspec**, using the commit message the plan wrote for that task, one at a time in plan order:
   ```bash
   git commit -m "<task N message>" -- <task N files>
   ```
   The pathspec is what makes this safe — it is immune to a sibling's unstaged work landing in the wrong commit. Never `git commit -a`, never a bare `git commit`, never `git add .`.
4. **Run the full suite once, serially**, now that the tree is quiet. This is the integration check no scoped in-wave test can provide, and it is the *only* measurement that describes what you just committed.
5. **Mark each task complete individually**, and only once you have committed its files. A returned-but-uncommitted task is not done.

## When part of the wave fails

**A BLOCKED sibling holds the wave.** In order:

1. Do not start wave N+1.
2. Collect the DONE children's reported file lists.
3. Commit the completed tasks individually by pathspec, in plan order — they were written to be independently commitable; that is the plan's job, not the failure's.
4. Set the blocked task's partial edits aside (stash or move them out of the tree) so the tree represents only what you have committed.
5. Run the full suite on that state, so the last green measurement describes a real commit.
6. Classify the blocker: missing context → supply it and re-dispatch. Plan or interface defect → fix the plan and re-dispatch. Escalate to the user if it is neither.

Never route around a BLOCKED task by starting the next wave.

## When the children report success and the suite disagrees

This is the expected failure mode of a wave, not an anomaly: a child's scoped tests prove only its own file, so the seam between two siblings is invisible to both of them. Trust the suite over the self-report.

1. Do not re-dispatch blindly, and do not edit the code yourself.
2. Re-run the failing test and read it fully — `systematic-debugging`.
3. **Bisect by commit.** This is the payoff of committing each task separately by pathspec: with N tasks bundled into one commit this diagnosis is impossible, which is the strongest argument for the whole protocol.
4. Check the third party — is the failing test in a file nobody touched, whose inputs changed? Shared fixture, config, settings. That reframes ownership.
5. Fix by re-dispatching a scoped task against the root cause. You may read anything and run anything; you may not type the fix. The tempting two-line inline fix is precisely the fix that hides the next three instances of the same defect.
6. Re-run the full suite. The wave is not done until it is green at HEAD — wave N+1 built on a red base makes every later bisect noisier.
7. Report the discrepancy even after resolving it. "Task 1 reported DONE with green scoped tests; the full suite disagreed; commit X exposed it" is worth the user's attention.

## The user asks you to just fire them all

Give the specific reason and offer the valid subset, not a lecture:

> Task 3 imports `Cart` from `src/cart.py`, which Task 1 hasn't written yet — fired together, Task 3 invents the interface, passes its own tests, and breaks at integration where neither child can see why. Tasks 1 and 2 are genuinely disjoint, so I'll run those two together now and Task 3 right after.

An explicit user instruction, given after hearing the specific cost, is theirs to make. A vague "why isn't this faster" is not an instruction — it is a request for the reason.
