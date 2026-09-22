---
name: finish
description: Use when a plan's PR is ready to merge — marks the plan completed, checks PR status, merges to main, and syncs local main
---

# Finish

Complete the plan lifecycle: mark it done, merge the PR, sync local main.

## When to Use

- After a plan's work is complete and ready to land on main
- When the user says "merge this", "ship it", "finish up", or "land this"
- After `implement` has opened a PR, or after `greptile` review loop is clean

**Don't use when:**
- Design isn't approved yet — use `discuss`
- Work is incomplete — finish implementation first

## Process

### 0. Determine Merge Mode

Check whether a PR already exists for the current branch:

```bash
CURRENT_BRANCH=$(git branch --show-current)
gh pr list --head $CURRENT_BRANCH --state open --json number --jq '.[0].number'
```

- **PR exists** → Follow the [PR Merge Path](#pr-merge-path) below (Steps 1–3)
- **No PR exists** → Follow the [Direct Merge Path](#direct-merge-path) below

> **When no PR exists:** If context is clear (e.g., clean greptile review just completed on a feature branch), proceed directly to building, testing, and merging. If ambiguous (e.g., on `main` with no changes, or unclear what should merge), ask the user:
>
> ```
> ask({ questions: [{ id: "merge-mode", question: "No open PR found for this branch. What would you like to do?", options: [
>   { label: "Open a PR then merge" },
>   { label: "Merge directly without PR" },
>   { label: "Cancel" }
> ]}]})
> ```

### Direct Merge Path

No PR required — validate the branch locally and merge:

1. **Verify we're on a feature branch** (not `main`):
   - If already on `main`, stop and report "Already on main — nothing to merge."

2. **Discover the project's validation commands:**
   Read the repo's `AGENTS.md` or `CLAUDE.md` (whichever exists at the repo root) for a "Build & Testing", "CI", "Gate", or similar section that lists the format/lint/test commands.

   - **Found instructions** → Run the listed validation commands (e.g., `make check`, `npm run lint && npm test`, etc.)
   - **No instructions found** → Ask the user: "The repo has no AGENTS.md/CLAUDE.md with build/test commands. What commands should I run to validate this branch before merging?"
     After the user answers, add a section to `AGENTS.md` (create if missing) documenting the commands, so future runs don't need to ask.

   If anything fails, stop and report the failures.

3. **Squash-merge the feature branch into main:**
   ```bash
   git checkout main
   git merge --squash $CURRENT_BRANCH
   git commit -m "feat: [plan summary from plan file or branch name]"
   ```
   (Use the plan title or a descriptive summary — not just the branch name.)

4. **Push main:**
   ```bash
   git push origin main
   ```

5. **Delete the feature branch** (remote + local):
   ```bash
   git push origin --delete $CURRENT_BRANCH
   git branch -d $CURRENT_BRANCH
   ```

6. Skip to [Step 4: Sync Local Main](#4-sync-local-main) (already synced above).

### PR Merge Path

A PR already exists — validate via GitHub, then merge.

### 1. Check Reviews and Comments (via `check-pr` in `general` subagent)

> ⚠️ **DISPATCH GUARD — ALWAYS DISPATCH A GENERAL SUBAGENT**
>
> - **Dispatch a `general` subagent to run the `check-pr` skill.**
> - **The `general` subagent inspects reviews/comments, implements fixes, validates with tests/lint, commits, pushes, replies to comments, and resolves review threads via GraphQL.**
> - **DO NOT fix code, edit files, or run tests directly in the main agent context.**

**A. Dispatch the `general` subagent with the `check-pr` skill:**
```typescript
subagent({
  agent: "general",
  task: `Load the check-pr skill and check PR #${PR_NUMBER} for open review comments, bot feedback, or requested changes. Analyze unresolved threads, apply all required fixes, validate with tests, push, reply to comments, and resolve the review threads.`,
  description: `Check PR #${PR_NUMBER} and resolve review comments`
})
```

**B. Check for pending human review requests:**
Inspect `reviewRequests`:
```bash
gh pr view [PR-NUMBER] --json reviewRequests
```
> If `reviewRequests` is non-empty (pending human reviewers):
> - **STOP** and ask the user: "@X hasn't reviewed yet. Wait or merge anyway?"
> - If user says wait, stop and report back
> - If user says proceed, continue to Step 2

> **RULE: ALL comments must be resolved (minimized) before merging.** There is no "non-blocking" exception — every single unresolved comment blocks the merge. If the user wants to skip resolving a comment, they must explicitly say so (e.g., "ignore this comment," "non-blocking," "skip this one").

### 2. Check CI and Mergeability

Only after reviews are clear, check technical readiness:

```bash
gh pr view [PR-NUMBER] --json state,statusCheckRollup,reviewDecision,mergeable
```

Verify all of:
- **State**: `OPEN`
- **CI checks**: Every entry in `statusCheckRollup` must reach a terminal state (`COMPLETED`) with a non-empty `conclusion`. **If any entry has `status: "IN_PROGRESS"`, `status: "QUEUED"`, or no `status`/`conclusion` at all, it means a check is still running — WAIT and re-check.** Poll every ~30 seconds until all checks reach `COMPLETED` state, regardless of whether they are currently passing or failing. A bot review comment saying "safe to merge" does NOT mean the check is done. Do not proceed until every `statusCheckRollup` entry is `COMPLETED` with a non-empty `conclusion`. Once all checks are `COMPLETED`:
  - If all conclusions are `"SUCCESS"` or `"SKIPPED"` → proceed to merge
  - If any conclusion is `"FAILURE"`, `"TIMED_OUT"`, or `"ACTION_REQUIRED"` → go to Step 1a
- **Reviews**: `APPROVED` (or no review required)
- **Mergeable**: `MERGEABLE`

If any check is still running, wait (~30s) and re-check with the same command. Loop until all are `COMPLETED`. If CI is failing, go to Step 1a.

### 1a. Fix PR Issues (loop via `general` subagent)

> ⚠️ **DISPATCH GUARD — DELEGATE ALL FIXES TO GENERAL SUBAGENT**
>
> - **Dispatch a `general` subagent to investigate failures, make code fixes, run validation, and push.**
> - **DO NOT edit code directly in the main agent context.**

**A. Dispatch `general` subagent to fix the issue:**
```typescript
subagent({
  agent: "general",
  task: `Investigate and fix the CI failure or review issue on PR #${PR_NUMBER} on branch ${CURRENT_BRANCH}. Run tests to verify the fix, commit, and push.`,
  description: `Fix CI/review issue on PR #${PR_NUMBER}`
})
```

**B. Re-check reviews & CI** — go back to Step 1 and Step 2.

**C. Loop until:**
- **All** review comments are resolved (minimized) — no exceptions
- All CI checks reach `COMPLETED` with `SUCCESS` or `SKIPPED`
- Review decision is `APPROVED` (or no review required)
- PR is `MERGEABLE`

### 3. Merge the PR

```bash
gh pr merge [PR-NUMBER] --squash --delete-branch
```

Use squash merge by default to keep main history clean. If the user prefers merge commits, use `--merge` instead.

### 4. Sync Local Main

```bash
git checkout main
git pull origin main
```

### 5. Delete the Roadmap Doc

The plan lived in `docs/roadmap/<feature>.md`. On ship, delete it — history lives in git:

```bash
rm docs/roadmap/<feature>.md
git add docs/roadmap/<feature>.md
git commit -m "docs: remove [feature] roadmap — shipped (PR #[number])"
```

If the plan contained durable knowledge (architecture notes, non-obvious constraints), fold that content into a `docs/features/<feature>.md` (present-tense, with front-matter) or a new `docs/decisions/NNNN-slug.md` before deleting. Don't preserve the plan file itself — no graveyards.

```yaml
# docs/features/<feature>.md front-matter
---
status: live
last-verified: YYYY-MM-DD
verified-by: <command or observation that proves it works>
---
```

### 6. Report

Tell the user:
- PR was merged (with link)
- Local main is synced
- Roadmap doc deleted
- Any durable content folded into `docs/features/` or `docs/decisions/`
- Any follow-up items noted in the plan

## Common Issues

| Issue | Action |
|-------|--------|
| Pending human reviewers | Ask user: wait or merge anyway? |
| CI still running | Wait and re-check until all checks reach COMPLETED state, then evaluate results |
| CI failing | Fix on feature branch, push, re-check (loop until green) |
| Review comments unresolved | Fix each issue, push, reply to comment, re-check (loop until ALL comments are resolved — no non-blocking exceptions) |
| `CHANGES_REQUESTED` review | Fix the requested changes, push, re-check |
| Bot review with issues | Fix the issues, push, re-check |
| Bot review clean ("no new issues") | Continue to next step |
| Merge conflicts on PR | Do NOT merge locally. Ask user to resolve on the branch. |
| PR already merged | Skip merge step, sync main, update index |
| Roadmap doc already deleted | Nothing to do — skip step 5 |

## Rules

- **Always check reviews/comments BEFORE checking CI/status** — this is the first gate
- **Never skip unresolved review comments** — every comment must be resolved before merging, no exceptions unless the user explicitly says so
- **Never force-merge a PR with failing CI** — always report the issue
- **Always sync main after merge** — prevents stale branch issues
- **Always delete the roadmap doc after merge** — no graveyards; history lives in git
- **Use squash merge by default** — keeps main history clean
- **Wait for all active checks to complete** — poll until every `statusCheckRollup` entry reaches `COMPLETED` state before evaluating results
