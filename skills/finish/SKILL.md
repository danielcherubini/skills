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
  ├── 1. Determine Merge Mode (PR exists vs Direct Merge)
  │
  ├── 2. PR Path: Delegate to general subagent running `check-pr`
  │        ├── Inspect reviews, comments & threads
  │        ├── Fix any issues & resolve threads
  │        └── Watch CI checks to completion (no main agent polling!)
  │
  ├── 3. If pending human reviewers: Prompt user (ask tool)
  │
  ├── 4. Merge PR (`gh pr merge --squash --delete-branch`)
  │
  ├── 5. Sync local main (`git checkout main && git pull origin main`)
  │
  ├── 5b. Remove leftover task worktrees from any abandoned parallel wave
  │
  └── 6. Clean up roadmap docs & report summary
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

*Note: Use squash merge by default. If the project/user prefers merge commits, use `--merge`.*

### 4. Sync Local Main

```bash
git checkout main
git pull origin main
```

### 4b. Remove Leftover Task Worktrees

A parallel wave creates one worktree and branch per task (`feature/<topic>-taskNN`, per `trees-and-branches`). A successful wave removes its own, so anything still present is debris from an abandoned or failed wave — and it survives `gh pr merge --delete-branch`, which only touches the PR's branch.

```bash
git worktree list                     # anything besides the primary checkout?
```

For each `*-taskNN` branch belonging to this feature, ask whether it shipped:

```bash
git merge-base --is-ancestor <task-branch> "$FEATURE_TIP"   # 0 = shipped, 1 = unmerged work
git log --oneline "$FEATURE_TIP..<task-branch>"            # what would be lost
git -C <worktree> status --porcelain                       # uncommitted edits
```

Test against `$FEATURE_TIP` (step 0), **never against `main`**: this merge is a squash, so no task branch is an ancestor of post-merge `main`, and every branch — including the ones that shipped — would read as unmerged. The captured tip is also the only reference left once `--delete-branch` has removed the feature branch.

**Unmerged commits or uncommitted edits are work nobody shipped — report them to the user before removing anything.** Only after confirming nothing is lost:

```bash
git worktree remove <worktree>        # refuses while dirty; never --force past that
git branch -D feature/<topic>-taskNN  # after the worktree is gone
git worktree prune                    # if any were rm -rf'd earlier
```

No task worktrees → say so in one line and continue. This never gates the merge.

### 5. Clean Up Roadmap Doc & Final Report

Delete the whole feature roadmap family (plan/spec, status, task plans, follow-ups — history lives in git).
**Fold any `${FEATURE_NAME}-follow-ups.md` content into `docs/features/` or an ADR FIRST** — it is deleted here too.

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
  # `rm`, not `git rm`: the status file and task plans are written by the roadmap run and are
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
   git checkout main
   git merge --squash "$CURRENT_BRANCH"
   git commit -m "feat: [plan summary]"
   git push origin main
   ```
4. **Delete local & remote feature branch**:
   ```bash
   git push origin --delete "$CURRENT_BRANCH"
   git branch -D "$CURRENT_BRANCH"
   ```
5. **Remove leftover task worktrees** — same as step 4b above; a wave's `*-taskNN` worktrees survive this path too.
6. **Clean up roadmap doc** (Step 5 above).

---

## Summary Report

Present the final confirmation to the user:
- PR merged (with link) or direct branch merged
- Local `main` branch synced with origin
- Task worktrees removed (or "none remaining")
- Remote feature branch deleted
- Roadmap doc cleaned up
- Any durable architecture notes documented
