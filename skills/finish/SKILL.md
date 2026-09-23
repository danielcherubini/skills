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
  └── 6. Clean up roadmap docs & report summary
```

---

## When to Use

- After a plan's work is complete and ready to land on main
- When the user says "merge this", "ship it", "finish up", or "land this"
- After `implement` has opened a PR, or after `greptile` review loop is clean

**Don't use when:**
- Design isn't approved yet — use `discuss`
- Work is incomplete — finish implementation first

---

## Process

### Step 0: Determine Merge Mode

Check whether an open PR exists for the current branch:

```bash
CURRENT_BRANCH=$(git branch --show-current)
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

### 5. Clean Up Roadmap Doc & Final Report

Delete the feature roadmap/plan doc (history lives in git):

```bash
if [ -f "docs/roadmap/${FEATURE_NAME}.md" ]; then
  git rm "docs/roadmap/${FEATURE_NAME}.md"
  git commit -m "docs: remove ${FEATURE_NAME} roadmap — shipped (PR #${PR_NUMBER})"
  git push origin main
fi
```

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
5. **Clean up roadmap doc** (Step 5 above).

---

## Summary Report

Present the final confirmation to the user:
- PR merged (with link) or direct branch merged
- Local `main` branch synced with origin
- Remote feature branch deleted
- Roadmap doc cleaned up
- Any durable architecture notes documented
