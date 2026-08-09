---
name: implement
description: Use when you have a written implementation plan to execute
---

# Implement

> 🚨 **CORE RULE: This skill dispatches `general` subagents to do the work. The main agent orchestrates — it does NOT write code, edit files, or run builds directly.**

Read the plan, create a feature branch, dispatch subagents per task, review the branch, open a PR.

> ⚠️ **Before each task: STOP → Dispatch a `general` subagent → Verify dispatch → Handle response.**
> See the [Task Dispatch Protocol](#task-dispatch-protocol) for the mandatory per-task sequence.

## Plan Selection

If no plan file path is provided by the user:

1. **Read the plans index** — Load `docs/plans/README.md` (or the project's equivalent plan index) to find available plans.
2. **Identify candidates** — Collect all plans in the Backlog section (exclude ✅ COMPLETED, 🔁 SUPERSEDED, and any "remaining work" / roadmap items that lack a plan file).
3. **Ask the user** which plan to execute:

```
ask({
  questions: [{
    id: "plan",
    question: "Which plan would you like to execute?",
    options: [
      { label: "[Plan Name] — [short description]" },
      ...
    ]
  }]
})
```

4. Always ask the user which plan to execute, even if only one candidate exists — do NOT skip the approval gate.
5. Once selected, read the full plan file and continue to Branch Setup.

## Branch Setup

Load the `gitflow-branching` skill. Determine whether this plan is part of a **stack** (check the plan file for "Stack:" or "builds on `stack/...`"):

- **Simple plan (single PR):** Create a `feature/*` branch from `main`.
- **Stacked plan:** Create a `stack/<sub-plan-name>` branch from the previous stack branch (or trunk for the first sub-plan). After all needed branches exist, register with `gh stack init` and submit with `gh stack submit`.

Then create a todo list with `manage_todo_list` with all tasks from the plan.

> 🔒 **Gate: Do not proceed to Task Dispatch until the branch exists AND the todo list is created.** These are prerequisites for proper subagent dispatch and tracking.

## Baseline Check (Mandatory Before Task 1)

Before writing a single line of code, run the full test/lint/build suite and record the results:

```bash
# Run whatever the project's CI check is (go test, npm test, cargo test, etc.)
# Capture every FAIL, ERROR, and lint warning
```

**Rule: You own every failure in CI — pre-existing or not.**
If a test or lint check was already broken before your branch, you must still fix it before opening a PR. The CI gate does not know or care what was broken before you arrived. A PR that introduces zero regressions but leaves pre-existing failures will still be rejected. Fix them or report BLOCKED to the user before proceeding.

Document the baseline results in your working notes so you know which failures were pre-existing vs introduced by your changes.

## Task Dispatch Protocol

> ⚠️ **DISPATCH GUARD — READ BEFORE EVERY TASK**
>
> - **You MUST dispatch a `general` subagent for each task.**
> - **DO NOT write code, edit files, or run builds directly in your own context.**
> - If you skip dispatch, you forfeit TDD, per-task commits, and isolation — the entire point of this skill.
> - The only exception is the Baseline Check (run before Task 1) and the final PR/code-review steps.

### Per-Task Sequence (follow rigidly for every task)

**Step 1 — STOP & Verify.**
Before touching anything, confirm:
- [ ] This is a task from the plan, not a tangent
- [ ] No code has been written yet in this context
- [ ] You are about to dispatch a `general` subagent (not do the work yourself)

**Step 2 — Dispatch the subagent.**

> **DO NOT add a `model` parameter to any subagent call.** The agent definition controls its own model. Adding `model` causes hallucinated model names that break the call.

```
/// ───────────────────────────────────────────────────────────
///  MANDATORY: dispatch a `general` subagent for this task.
///  DO NOT write code directly in your own context.
/// ───────────────────────────────────────────────────────────
subagent({
  agent: "general",
  task: "[FULL TEXT of task from plan — paste it, don't make the agent read a file]\n\nContext: [where this fits, dependencies, what's already done]",
  description: "Implement Task N: [task name]"
})
```

The `general` agent already knows to:
- Load TDD skill and follow RED-GREEN-REFACTOR
- Validate format → build → test → lint in order
- Commit with a descriptive message
- Report DONE | BLOCKED | NEEDS_CONTEXT

**Step 3 — Verify dispatch happened.**
After the `subagent()` call returns, confirm the subagent actually performed the work:
- [ ] The response includes file edits, test runs, or commits from the subagent
- [ ] You did NOT write any code, edit files, or run builds in your own context
- [ ] If you find yourself having done work inline, stop and re-dispatch the subagent immediately

**Step 4 — Handle the subagent response:**
- **DONE:** Mark task complete in todo list, move to next task
- **NEEDS_CONTEXT:** Provide missing info, re-dispatch
- **BLOCKED:** Assess blocker, provide help or escalate to user

**Important:** Dispatch tasks sequentially (not in parallel) to avoid file conflicts.

> 🔁 **If you catch yourself doing work inline instead of dispatching — stop, reset, and dispatch the subagent.** This is the #1 failure mode of this skill; do not let it happen.

## After All Tasks Complete

Once all tasks are done, ask the user what to do next:

```
ask({
  questions: [{
    id: "next-step",
    question: "All tasks complete. What would you like to do next?",
    options: [
      { label: "Review loop" },
      { label: "Greptile review loop" },
      { label: "Open PR only" },
      { label: "Finish plan" }
    ]
  }]
})
```

Then follow the user's choice immediately — do NOT ask for additional confirmation.

### Review Loop

**Run a full code review loop — auto-fix all findings iteratively until clean.**

1. Load the `review` skill and run it to completion (explore → classify → reviewer → parse → fix → re-review → loop until clean or max iterations)
2. The review skill handles the review loop itself — let it run to completion
3. The review skill's Phase 8 will ask **Open a PR** or **Merge to main** and execute the chosen action:
   - **Open a PR** → The review skill opens the PR and reports the URL
   - **Merge to main** → The review skill loads the `finish` skill (see **Finish Plan** below)
4. After the review skill completes, proceed to **Update Plan Index** below

### Greptile Review Loop

**Run Greptile review iteratively on the local branch until clean — do NOT open a PR during the loop.**

1. Load the `greptile` skill and run it to completion (setup → review → parse → fix → re-run → loop until clean or max iterations)
2. The greptile skill handles the review loop itself — let it run to completion
3. The greptile skill's Phase 7 will ask **Open a PR** or **Merge to main** and execute the chosen action:
   - **Open a PR** → The greptile skill opens the PR and reports the URL
   - **Merge to main** → The greptile skill opens the PR, then loads the `finish` skill (see **Finish Plan** below)
4. After the greptile skill completes, proceed to **Update Plan Index** below

### Open PR only

**For simple plans (single PR):**
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

**For stacked plans:** Use `gh stack` to push and submit all branches:
```bash
gh stack push      # Push all stack branches
gh stack submit    # Create/update PRs as a linked stack
```

Report the PR URL(s) to the user.

**Clear the todo list** — remove all remaining entries now that execution is complete.

Proceed to **Update Plan Index** below.

### Finish Plan

1. **Clear the todo list** — remove all remaining entries
2. Open a PR (the `finish` skill requires an existing PR):
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
3. Load the `finish` skill to check PR status, merge to main, and update the plan index

## Update Plan Index

After a PR is opened, update `docs/plans/README.md`:
1. Move the plan from the Backlog table to the appropriate Completed Plans category
2. Add the PR number and key git commit refs to the entry
3. Increment completed count in Quick Stats
4. Commit this update with message: `docs: mark [plan-name] as completed`
5. **Clear the todo list** — remove all remaining entries
