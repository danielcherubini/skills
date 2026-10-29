# Parallel Execution Guide

How to verify a plan's waves against the real tree, run them safely in isolated worktrees, and integrate the result. Load this when the plan declares `**Verdict:** PARALLEL`, **or when the `roadmap` skill applies this protocol to task waves.** The invariants in `implement`'s own text still apply — this is the detail, not a replacement. Branch and worktree mechanics live in the `trees-and-branches` skill.

## Two grains

This protocol governs waves at **two grains**:

- **(a) Intra-plan** — sub-tasks within one committed plan. `specify` emits the `**Parallel:**` lines, and each task's `Files:` list is the disjointness evidence.
- **(b) Inter-task** — roadmap tasks within a run. `roadmap` emits the wave grouping and judges disjointness from each task's **owned file set** (its status-file `Owns` column), re-verified against the tree — the ownership set is the `Files:` list at task grain.

Both use the **identical invariants**: one worktree and one branch per wave task, children commit on their own branch, the orchestrator fans the branches in and runs the full suite on the integrated result, ≤4 **implementers** per wave (read-only dispatches are not capped — see check 4), a BLOCKED sibling holds the wave. Only the *evidence* for gate 1 (disjoint files) differs by grain. **Roadmap applies this protocol directly and does NOT load the `implement` skill per task.**

## Why isolation, and what it does not buy you

Each wave child gets its own worktree and branch, so siblings share an object store and nothing else: separate trees, separate indexes, separate build artifacts. A child can therefore commit normally and run the project's **full** suite — its own tree makes that a real measurement of its work rather than a reading of everyone's.

What isolation does **not** buy you is a correct integration. Two children can define the same symbol in different files, or both need a registration point neither was assigned. Each is green alone and the combination is broken. **Disjoint files make the merge clean; only the post-fan-in suite says whether the build works.** That single check remains the load-bearing one, exactly as it was before.

## Why you re-verify instead of obeying

The plan's verdict came from a planner that has not seen the tree since it wrote the plan. You have just run the baseline and you are about to touch those files. Three ways the plan can be stale or wrong:

- A file the plan says to Create already exists (someone merged it since).
- The `Files:` list omits something the task's *commands* will write — a lockfile, a snapshot, `conftest.py`.
- Two tasks the planner believed independent now share a newly-added fixture or config file.

Also treat the plan's labels as load-bearing data. A `**Parallel:**` line missing entirely, or one that contradicts its own `Files:` list, means the plan's parallel claims are untrustworthy *as a set* — re-deriving groupings from labels you have proven unreliable is speculation dressed as verification. Fully serial, and say which integrity failure you hit.

## The check

For each declared wave:

**At task grain (roadmap), substitute each task's *owned file set (`Owns` column), re-verified against the tree* for `Files:` in steps 1–2, and skip the `**Parallel:**`-line integrity test below** — roadmap tasks carry no `**Parallel:**` lines. A task whose real edits land outside its `Owns` set breaks the wave's disjointness: treat it as a failed wave and let roadmap merge or re-cut.

1. Collect each task's `Files:` list — Create + Modify + Test together.
2. Compare pairwise. Any shared path fails the wave. Include: shared fixtures, snapshot dirs, `mod.rs` / `__init__.py` / barrel files, route or middleware registration, config, lockfiles, migrations. A shared path is no longer index-corrupting — it is a guaranteed merge conflict, which is wasted work rather than a corrupt commit. Still split it.
3. Check the build graph. Does a task in the wave consume a symbol another task in the same wave is creating? If yes, split — the consumer goes in a later wave.
4. Size. More than 4 **implementers** → split into consecutive waves. Each worktree pays its own dependency install (`node_modules`, `target/`), and global caches (`~/.cache/go-build`, the module cache) are still shared, so past a few concurrent builds the speedup flattens. This cap counts implementers only — read-only dispatches (planners, researchers) run no build and are not capped. Measure before widening.

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

## Setting up the wave

```bash
BASE=$(git rev-parse HEAD)                                  # every task branches from here
for n in 1 2 3; do
  git worktree add "../$(basename "$PWD")-task$n" -b "feature/<topic>-task$n" "$BASE"
done
```

Siblings, never nested inside the repo. Record `$BASE` — it is both what makes the fan-in a clean replay and your bisect boundary.

## The dispatch text for a wave child

A child's shell starts in the session directory, not its worktree. If that directory is itself a git repo, a bare `git commit` commits into the wrong repository **silently, with no error to catch it**. So the worktree path and branch are mandatory in the task text, along with an instruction to verify them before the first write:

```
PARALLEL WAVE — you have your own worktree:
- WORKTREE: /abs/path/repo-task1   BRANCH: feature/<topic>-task1
- FIRST ACTION: cd /abs/path/repo-task1 && git rev-parse --show-toplevel.
  It MUST print exactly that path. Anything else → STOP and report BLOCKED;
  a bare git command would commit into an unrelated repo silently.
- Prefix EVERY git command with that cd. Commit on your branch with the plan's
  commit message — never the feature branch, never main.
- Touch ONLY the files in your Files: list. Need one outside it → report
  NEEDS_CONTEXT, do not edit it.
- Run the FULL suite and format your files: your tree is yours alone.
Report DONE with your commit SHA and file list.
```

Unlike a serial child, a wave child is **not** told to skip committing or to scope its tests — isolation makes both correct.

## Running the wave

1. **One response, one `subagent` call per task.** Calls emitted together run concurrently — N tasks take roughly the wall-clock of one. Emitting them in separate responses is serial dispatch wearing a wave costume.
2. **Wait for all of them.** The wave is a barrier. Do not start wave N+1 while any wave-N task is outstanding.
3. **Fan in, in plan order**, one merge per task so every task stays its own commit:
   ```bash
   git merge --no-edit feature/<topic>-task1
   git merge-base --is-ancestor feature/<topic>-task1 HEAD   # landed
   git diff --stat HEAD^1 HEAD                               # must show ONLY task 1's files
   ```
   Use `git diff HEAD^1 HEAD`, **not** `git show --stat HEAD`: on a merge commit `git show` prints no file list at all, so the check silently passes having verified nothing. And expect the *first* merge to fast-forward — the feature branch has no commits of its own yet, so there is no merge commit to point at. That is why "landed" is tested with `--is-ancestor` against the child's branch rather than by naming a merge commit.
   A conflicting merge is the collision the pairwise check missed. Resolve it by re-dispatching one task against the other's merged result — not by hand-editing both, which is where a third bug comes from.
4. **Run the full suite on the integrated tree.** This is the integration check no isolated child can provide, and the *only* measurement describing what you just merged. **Prove it executed tests — do not trust the exit code.** A package where no test files were discovered still exits 0 (`go test ./...` prints `?   pkg   [no test files]`), and a *non-verbose* green run prints no `--- PASS` lines at all, so counting passes requires `-v`. Run verbosely and require a non-zero pass count: `go test -v ./...` → count `--- PASS`.
5. **Mark each task complete individually**, and only once its merge exists and the integrated suite is green. A returned-but-unmerged task is not done.
6. **Clean up before the next wave**: `git worktree remove` each task worktree, then delete the task branches — git refuses the reverse order.

## When part of the wave fails

**A BLOCKED sibling holds the wave.** In order:

1. Do not start wave N+1.
2. Collect the DONE children's commit SHAs and file lists.
3. Fan in the completed tasks in plan order — they were written to be independently commitable; that is the plan's job, not the failure's.
4. **Leave the blocked task's worktree untouched.** Its partial edits sit on its own branch in its own tree; they cannot contaminate the merge, so there is nothing to set aside. Note the path and branch so the work is recoverable.
5. Run the full suite on the merged state, so the last green measurement describes a real commit.
6. Classify the blocker: missing context → supply it and re-dispatch into the same worktree. Plan or interface defect → fix the plan and re-dispatch. Escalate to the user if it is neither.

Never route around a BLOCKED task by starting the next wave.

## When the children report success and the suite disagrees

This is the expected failure mode of a wave, not an anomaly: each child is green **alone**, and the seam between two siblings is invisible to both of them. Trust the suite over the self-report.

1. Do not re-dispatch blindly, and do not edit the code yourself.
2. Re-run the failing test and read it fully — `systematic-debugging`.
3. **Bisect by commit.** This is the payoff of fanning in one merge per task: with N tasks bundled into one commit this diagnosis is impossible, which is the strongest argument for the whole protocol. Bisect between `$BASE` and HEAD — each merge commit maps to exactly one task.
4. Check the third party — is the failing test in a file nobody touched, whose inputs changed? Shared fixture, config, settings. That reframes ownership.
5. Fix by re-dispatching a scoped task against the root cause. You may read anything and run anything; you may not type the fix. The tempting two-line inline fix is precisely the fix that hides the next three instances of the same defect.
6. Re-run the full suite. The wave is not done until it is green at HEAD — wave N+1 built on a red base makes every later bisect noisier.
7. Report the discrepancy even after resolving it. "Task 1 reported DONE with a green suite in its own worktree; the integrated suite disagreed; merge X exposed it" is worth the user's attention.

## The user asks you to just fire them all

Give the specific reason and offer the valid subset, not a lecture:

> Task 3 imports `Cart` from `src/cart.py`, which Task 1 hasn't written yet — fired together, Task 3 invents the interface, passes its own tests, and breaks at integration where neither child can see why. Tasks 1 and 2 are genuinely disjoint, so I'll run those two together now and Task 3 right after.

An explicit user instruction, given after hearing the specific cost, is theirs to make. A vague "why isn't this faster" is not an instruction — it is a request for the reason.
