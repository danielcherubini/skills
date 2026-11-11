---
name: finish
description: Use when a plan or feature branch is ready to merge into main (e.g. user says "merge this", "ship it", "finish up", or "land this").
---

# Finish

Complete the plan lifecycle: validate the PR/branch via subagents using `check-pr`, merge into main, sync local main, and clean up roadmap documents.

## Core Architecture: Subagent Delegation

> ⚠️ **DISPATCH GUARD — NO MANUAL POLLING OR CODE EDITING IN MAIN AGENT**
>
> - **Delegate all PR validation, comment resolution, and CI watching to `general` subagents using the `check-pr` skill.**
> - **DO NOT run repeated `sleep` / polling loops (`gh pr view --json statusCheckRollup`, `sleep 20`, etc.) in the main agent context.**
> - The subagent handles polling, checks, and fixes internally and returns a clean, structured readiness report to the main agent.

```
Main Agent (Finish Orchestrator)
  │
  ├── 0.  Determine Merge Mode (PR exists vs Direct Merge) + capture FEATURE_TIP
  │
  ├── 0b. Confirm PRIMARY worktree — HARD GATE, stops a linked worktree merging into itself
  │
  ├── 1. PR Path: Delegate to general subagent running `check-pr`
  │        ├── Inspect reviews, comments & threads
  │        ├── Fix any issues & resolve threads
  │        └── Watch CI checks to completion (no main agent polling!)
  │
  ├── 2. If pending human reviewers: Prompt user (ask tool)
  │
  ├── 3. Merge PR (`gh pr merge --squash --delete-branch`) — local+remote, unless a worktree holds it
  │        └── confirm the LOCAL branch actually went
  │
  ├── 4. Sync local main (`git checkout main` — MUST succeed)
  │
  ├── 4b. Remove leftover worktrees — enumerate ALL, never filter by name
  │
  └── 5. Clean up roadmap docs & report summary
```

---

## When to Use

- After a plan's work is complete and ready to land on main
- When the user says "merge this", "ship it", "finish up", or "land this"
- After `implement` has opened a PR, or after a review loop is clean

**Don't use when:**
- Design isn't approved yet — use `discuss`
- Work is incomplete — finish implementation first

---

## Process

### Step 0: Determine Merge Mode

Check whether an open PR exists for the current branch. **Capture the branch tip here** — step 4b needs it, and by then the branch is gone:

```bash
CURRENT_BRANCH=$(git branch --show-current)
FEATURE_TIP=$(git rev-parse HEAD)     # before any merge; 4b's only reliable reference point
gh pr list --head "$CURRENT_BRANCH" --state open --json number,title,url --jq '.[0]'
```

- **PR exists** → Follow the [PR Merge Path](#pr-merge-path) (Steps 1–5).
- **No PR exists** → Follow the [Direct Merge Path](#direct-merge-path).

### Step 0b: Confirm You Are in the Primary Checkout (hard gate)

**Run this before entering either path.** `finish` runs `git checkout main` and then merges into it.
In a **linked** worktree — which is where `trees-and-branches` tells you to do the work
(`../repo-feature-payments`) — that checkout **cannot succeed**: only one worktree may hold a branch,
and the primary checkout already holds `main`.

```bash
ROOT=$(git rev-parse --show-toplevel)
COMMON=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ -z "$COMMON" ]; then COMMON=$(git rev-parse --git-common-dir); fi   # git < 2.31: may be RELATIVE
case "$COMMON" in /*) : ;; *) COMMON="$ROOT/$COMMON" ;; esac
if [ "$COMMON" = "$ROOT/.git" ]; then echo "PRIMARY — safe to merge"; else echo "LINKED worktree — STOP"; fi
```

The `case` arm is load-bearing, not tidiness: the pre-2.31 spelling returns a path relative to the
toplevel, so comparing it unresolved reports **LINKED for the primary checkout** and blocks every
normal run. And do not write the fallback as `a || b && c` — that parses as `(a || b) && c`, so the
fallback always runs and clobbers the good value.

**If it reports LINKED, STOP. Do not continue "because the next command exited 0."** Measured end
state when this gate is skipped, run verbatim from a feature worktree:

| Step | Command | What actually happens |
|---|---|---|
| 4 | `git checkout main` | `fatal: 'main' is already used by worktree at …` — **exit 128** |
| 5 | `git merge --squash "$CURRENT_BRANCH"` | *"Already up to date"* — merges the branch **into itself**, exit **0** |
| 6 | `git push origin --delete "$CURRENT_BRANCH"` | **succeeds** — the remote branch is gone |
| 6 | `git branch -D "$CURRENT_BRANCH"` | fails, the worktree still holds it |

The exit-128 step is the only one that fails, and nothing gates on it, so the run reads as success
while `main` never received the work and the remote branch was deleted. The commit survives in exactly
one place: the leftover worktree. **Report it and stop** — `git worktree list` names the primary
checkout (it is the first entry), and the user can run `finish` there with `git -C <primary> …`.

> 🔒 **Gate: do not run any merge, push, or branch delete until that check prints PRIMARY.**

> **When no PR exists:** If context is clear (e.g., clean review completed on a feature branch), proceed with direct merge. If ambiguous, ask the user using `ask`:
> ```typescript
> ask({
>   questions: [{
>     id: "merge-mode",
>     question: "No open PR found for this branch. What would you like to do?",
>     options: [
>       { label: "Open a PR then merge" },
>       { label: "Merge directly without PR" },
>       { label: "Cancel" }
>     ],
>     recommended: 0
>   }]
> })
> ```

---

## PR Merge Path

### 1. Validate & Watch PR via `check-pr` Subagent

Dispatch a `general` subagent to execute the `check-pr` skill workflow. The subagent inspects reviews, resolves threads, applies fixes if needed, and monitors CI until terminal completion:

```typescript
subagent({
  agent: "general",
  task: `Execute the check-pr workflow for PR #${PR_NUMBER} on branch ${CURRENT_BRANCH}:
1. Inspect review decision, reviewer statuses, and unresolved review threads.
2. If there are unresolved review comments or actionable bot feedback, fix them, run tests, commit, push, reply to comments, and resolve the threads.
3. Watch CI checks until ALL checks reach terminal COMPLETED status (using 'gh pr checks ${PR_NUMBER} --watch' or polling inside this subagent).
4. If any CI checks fail, investigate logs ('gh run view --log-failed'), apply fixes, push, and re-watch.
5. Return a readiness report:
   - All review threads resolved (yes/no)
   - Review decision (APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED / null)
   - Pending human review requests (list of users/teams)
   - Final CI check conclusions (all SUCCESS/SKIPPED or failures)
   - Mergeability status (MERGEABLE / CONFLICTING)
   - Final verdict: READY TO MERGE or BLOCKED (with reasons)`
})
```

### 2. Handle Human Reviewers & Blockers

Review the subagent's readiness report:

- **If pending human review requests exist:**
  Ask the user via `ask`:
  ```typescript
  ask({
    questions: [{
      id: "pending-reviewers",
      question: "@<reviewer> has not submitted their review yet. Wait or merge anyway?",
      options: [
        { label: "Wait for review" },
        { label: "Merge anyway" }
      ],
      recommended: 0
    }]
  })
  ```
  If the user chooses to wait, stop and report.

- **If review comments or CI failures remain:**
  The subagent must resolve them before merging. Every unresolved comment blocks merge unless explicitly overridden by user.

### 3. Merge the PR

Once the subagent confirms the PR is clean, approved/cleared, and CI is green:

```bash
gh pr merge "$PR_NUMBER" --squash --delete-branch
```

`--delete-branch` deletes the **local and remote** branch (its own help text says so) — but git refuses
to delete a branch a **linked worktree** has checked out, so on that path the local half cannot
succeed. Do not treat the flag as proof the local branch is gone; verify it:

```bash
git branch --list "$CURRENT_BRANCH"     # empty = gone; non-empty = something still holds it
```

If it still exists, that is Step 0b's situation surfacing late: go to 4b, check the worktree for
unmerged work, clear it, then delete the branch. Never `git branch -D` while you are standing on the
branch itself — in the primary checkout too — git refuses with `cannot delete branch '…' used by
worktree at …`; step 4's `git checkout main` is what moves you off it.

*Note: Use squash merge by default. If the project/user prefers merge commits, use `--merge`.*

### 4. Sync Local Main

```bash
git checkout main || { echo "STOP: cannot check out main — not the primary worktree (Step 0b)"; exit 1; }
git pull origin main
```

A failure here is not noise to continue past: it means the merge target was never reached, and the
next command would merge the branch into itself. Step 0b exists to catch this earlier; this guard is
the backstop, because it is the only place the failure becomes visible.

### 4b. Remove Leftover Worktrees

A parallel wave creates one worktree and branch per task (`feature/<topic>-taskN`, per
`trees-and-branches`); the run itself may also live in a `feature/<topic>` worktree. A successful wave
removes its own, so anything still present is debris — and it outlives the merge, because git
**refuses** to delete a branch a worktree has checked out. `gh pr merge --delete-branch` asks for the
local delete, receives that refusal, and carries on; `git branch -D` gets the same refusal. So the
leftover worktree is what strands both the directory *and* its branch.

Enumerate **every** worktree. Do **not** filter by a name pattern:

```bash
git worktree list
```

> ⚠️ **Never scope this to `*-taskNN`.** Branches are created as `feature/<topic>-task$n` from
> `for n in 1 2 3` — `task1`, **unpadded** — while plan *files* are zero-padded
> (`-taskNN-<slug>.md`). A literal `*-taskNN` glob matches neither the real branches nor the real
> directories: the loop body runs zero times, the step reports "no leftovers", and every worktree on
> disk survives. The feature worktree is matched by no task pattern at all, and it is the one most
> likely to hold the only copy of the work.

For **each** entry that is not the primary checkout, ask whether it shipped:

```bash
git merge-base --is-ancestor <branch> "$FEATURE_TIP"   # 0 = shipped, 1 = unmerged work
git log --oneline "$FEATURE_TIP..<branch>"             # what would be lost
git -C <worktree> status --porcelain                   # uncommitted edits
```

Test against `$FEATURE_TIP` (step 0), **never against `main`**: this merge is a squash, so no task
branch is an ancestor of post-merge `main`, and every branch — including the ones that shipped — would
read as unmerged. The captured tip is also the only reference left once `--delete-branch` has removed
the remote feature branch.

**Unmerged commits or uncommitted edits are work nobody shipped — report them and stop before removing
anything.** A worktree with a non-empty `status --porcelain` or a non-empty log is not debris, it is a
backup. Only after confirming nothing is lost:

```bash
git worktree remove <worktree>        # refuses while dirty; never --force past that
git branch -D <branch>                # only once the worktree is gone
git worktree prune                    # clears registrations left by an earlier rm -rf
```

`git worktree remove` refuses on uncommitted **or untracked** work, but **gitignored build output does
not block it** — a populated `target/` or `node_modules/` never forces `--force`. If it refuses,
something real is uncommitted: read it before forcing.

No leftover worktrees → say so in one line and continue. That never gates the merge — **but a worktree
holding unmerged work does: report it rather than removing it.**
```

No task worktrees → say so in one line and continue. This never gates the merge.

### 5. Clean Up Roadmap Doc & Final Report

Delete the whole feature roadmap family (plan/spec, status, task plans, follow-ups — history lives in git).
**Fold any `${FEATURE_NAME}-follow-ups.md` content into `docs/features/` or an ADR FIRST** — it is deleted here too.

**"History lives in git" is an assumption, and when it is false this step destroys the work unrecoverably.** In
any repo where `docs/roadmap/` is gitignored, these files were never committed, so `rm -f` leaves no blob, no
stash, no `git checkout` — and `git add -u` then stages nothing, so the destruction is not even visible in the
diff. So before the loop, for every file the loop will touch, require ONE survivor:

1. `git ls-files --error-unmatch "$f"` succeeds — git holds it, so it is safe to delete. **Or**
2. Its content was already FOLDED into a durable file by the fold this step requires first
   (`docs/features/<feature>.md` or an ADR). Prove it: `git check-ignore -q <fold target>` must report NOT
   ignored, and you must have staged it yourself with `git add -- <fold target>` — the commit below runs
   `git add -u -- docs/roadmap`, which stages **deletions in one directory only** and can never stage a new
   file elsewhere, so an unstaged fold is as good as absent. This is the survivor for `-follow-ups.md`; do not
   ALSO demand an artifact for that file, since no skill writes one and insisting blocks a clean ship. **Or**
3. The Task card holds it as a **Task artifact** — read the card's key list (`list_board` prints each card's
   artifact keys) and require the file's role: `spec`/`plan` for the spec-or-plan doc, `status` for
   `-status.md`.

Grounding reports and per-task plans are run scaffolding: no survivor needed, delete them unconditionally.

None of the three? **Stop and say which file has no copy**, and delete only the ones that do. Do not "proceed because the
PR is merged": the merge proves the code shipped, which says nothing about whether the *documents* survive. No
`task:` key in the spec's front-matter and no tracker `issue:` key either → the run was never mirrored anywhere,
so say so plainly and leave the family in place; it is the only copy.

After the deletions, if the spec's front-matter carries `task:`, re-point the card so it stops naming a deleted
file: `edit_task(task_id, spec_path: "docs/features/<feature>.md")` — the durable doc you folded above. This is
the only move available and it is the right one: `edit_task` **cannot** null a `spec_path` out (the UPDATE is
`COALESCE(?4, spec_path)`, so `null` means "leave it alone", not "clear it"), which means a card whose spec file
was deleted would keep pointing at it forever unless you re-point it at something that exists.

```bash
# Derive from CURRENT_BRANCH (captured at step 0) — NOT `git branch --show-current`, which by now
# returns `main` because step 4 already checked it out. An empty value must abort, never glob.
# Run this block in the SAME shell as step 0, or re-set CURRENT_BRANCH before it.
FEATURE_NAME="${FEATURE_NAME:-$(printf '%s' "$CURRENT_BRANCH" | sed 's|^[^/]*/||')}"
FEATURE_NAME="${FEATURE_NAME:?set FEATURE_NAME before cleanup}"
removed=0
for f in "docs/roadmap/${FEATURE_NAME}.md" \
         "docs/roadmap/${FEATURE_NAME}-status.md" \
         "docs/roadmap/${FEATURE_NAME}-follow-ups.md" \
         docs/roadmap/"${FEATURE_NAME}"-ground-*.md \
         docs/roadmap/"${FEATURE_NAME}"-task[0-9][0-9]*.md; do
  # `-ground-*` is anchored to ${FEATURE_NAME} on purpose: a bare `-ground-` would also match an
  # unrelated doc that merely contains the word (play-ground-refactor.md).
  [ -e "$f" ] || continue
  # `rm`, not `git rm`: the status file and task plans are written by the implement COARSE run and are
  # frequently UNTRACKED or locally modified, which `git rm` refuses without -f.
  rm -f -- "$f"
  removed=1
done
# `add -u` records the deletions of TRACKED files only — never stages an untracked file.
[ "$removed" -eq 1 ] && git add -u -- docs/roadmap
# Only commit when something was actually removed; an unconditional commit fails on a no-op
# feature name and would leave `git push` to run against a stale commit.
if ! git diff --cached --quiet; then
  git commit -m "docs: remove ${FEATURE_NAME} roadmap — shipped (PR #${PR_NUMBER})"
  git push origin main
fi
```

The glob names each roadmap artifact explicitly and **always prefixed by `${FEATURE_NAME}`** (`<feature>.md`, `-status`, `-follow-ups`, `-ground-<area>`, `-taskNN`), so a sibling like `user-auth-v2.md` — or an unrelated `play-ground-refactor.md` — is never touched and the glob can never widen to `docs/roadmap/*.md`. If `docs/roadmap/<feature>.md` does not exist (a roadmap run whose entry was `codebase-improvement` or `research` has no spec file), the matching entries are simply skipped.

If the plan contained durable architectural decisions, fold them into `docs/features/<feature>.md` or `docs/decisions/` before deleting.

---

## Direct Merge Path (No PR)

When merging directly without a PR:

1. **Verify branch**: Ensure not already on `main`.
2. **Dispatch validation subagent**:
   ```typescript
   subagent({
     agent: "general",
     task: `Validate branch ${CURRENT_BRANCH} before direct merge:
1. Check AGENTS.md or CLAUDE.md for project build, lint, and test commands.
2. Run validation suite (e.g. npm test, make lint, cargo test, etc.).
3. Report pass/fail result.`
   })
   ```
3. **Squash-merge into main**:
   ```bash
   git checkout main || { echo "STOP: cannot check out main — not the primary worktree (Step 0b)"; exit 1; }
   git merge --squash "$CURRENT_BRANCH"
   git commit -m "feat: [plan summary]"
   git push origin main
   ```
   This path is where the linked-worktree failure is most destructive: without the guard, the failed
   checkout leaves you on `$CURRENT_BRANCH`, `git merge --squash "$CURRENT_BRANCH"` then answers
   *"Already up to date"* and **exits 0**, and the commit + push publish a main that never received the
   work. Step 0b is the gate; this `||` is the backstop.
4. **Delete local & remote feature branch**:
   ```bash
   git push origin --delete "$CURRENT_BRANCH"
   git branch -D "$CURRENT_BRANCH"
   ```
5. **Remove leftover worktrees** — same as step 4b above: enumerate **all** of them, never a name
   pattern. Both a wave's task worktrees and the `feature/<topic>` worktree survive this path. If a
   worktree held `$CURRENT_BRANCH`, step 4's `git branch -D` **errored** (`used by worktree at …`)
   with nothing gating on it, so confirm with `git branch --list "$CURRENT_BRANCH"` rather than
   assuming it went.
6. **Clean up roadmap doc** (Step 5 above).

---

## Summary Report

Present the final confirmation to the user:
- PR merged (with link) or direct branch merged
- Local `main` branch synced with origin
- Leftover worktrees removed — list each path removed, or "none remaining" (from `git worktree list`, not from a name pattern)
- Any worktree that held **unmerged work**: named, NOT removed, and reported as needing a decision
- Feature branch gone — confirm with `git branch --list "$CURRENT_BRANCH"`, since a worktree can hold it
- Roadmap doc cleaned up
- Any durable architecture notes documented
