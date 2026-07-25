---
name: greptile
description: Use when the user wants Greptile to review the current local branch iteratively until all findings are resolved, before opening a PR or merging to main.
---

# Greptile

Run `greptile review` on the current local branch, fix findings, and re-run until clean — all before opening a PR.

## Overview

This skill runs the Greptile CLI review against the local branch in a loop. Each iteration: run review → parse findings → fix actionable items → re-run. The loop exits when there are zero actionable findings, max iterations are reached, or the user aborts. After the loop, the skill asks whether to **Open a PR** (using the implement skill's PR logic) or **Merge to main** (using the finish skill).

## When to Use

- After `implement` tasks are complete and the user selects "Greptile review loop"
- When the user says "review with greptile", "greptile loop", "run greptile review"
- When the user wants Greptile feedback on the local branch before opening a PR

**Not for:** reviewing an already-open PR (use `greptileai/skills@greploop`), debugging a specific bug (use `systematic-debugging`), general code review (use `review`)

## Architecture

```
Main agent (YOU — running this skill)
  ├── Phase 1: Setup (repo context, greptile CLI, authentication)
  ├── Phase 1.5: Load plan context (optional — feed plan as --instructions)
  ├── Phase 2: Run greptile review — async dispatch + poll for completion
  ├── Phase 3: Parse findings — classify actionable vs informational
  ├── Phase 4: Fix findings — dispatch general subagent to fix each actionable item
  ├── Phase 5: Re-run review — loop back to Phase 2 if findings remain
  ├── Phase 6: Exit conditions met — present summary
  └── Phase 7: Final ask() — Open a PR or Merge to main
```

**You (the main agent) own all orchestration AND all user interaction.** Subagents dispatched in Phase 4 are pure fixing leaves — they apply fixes and return summaries, never call `ask()` or present to the user.

## Workflow

### Phase 1: Setup

1. **Confirm repository context:**
   ```bash
   git rev-parse --show-toplevel
   ```
   If this fails, tell the user the skill must be run from a git repository.

2. **Check for Greptile CLI:**
   ```bash
   command -v greptile
   ```
   If missing, do NOT install automatically. Ask the user for permission, then show:
   ```bash
   npm i -g greptile
   ```
   Fallback if npm unavailable:
   ```bash
   curl -fsSL "https://greptile.com/cli/install" | sh
   ```

3. **Ensure authentication:**
   ```bash
   greptile whoami
   ```
   If auth is missing, run `greptile login` and wait for the user to complete the flow.

### Phase 1.5: Load Plan Context (Optional but Recommended)

If the work on this branch was driven by an implementation plan, feed it to the review
so greptile can check **spec compliance** (does the code match what was planned?) in
addition to general code quality.

#### Find the active plan

1. Check for a plans index:
   ```bash
   test -f docs/plans/README.md && echo "exists"
   ```

2. If it exists, find the plan for the current branch. Look in the Backlog or In-Progress
   section for a plan whose branch name or feature matches `git branch --show-current`:
   ```bash
   git branch --show-current
   grep -i "$(git branch --show-current | head -c 30)" docs/plans/README.md
   ```

3. If you can identify the plan (e.g., `docs/plans/plan-003-auth-middleware.md`), read it.

4. If no plans index exists, try globbing:
   ```bash
   ls docs/plans/plan-*.md 2>/dev/null
   ```
   Pick the most recently modified one, or ask the user which plan applies.

#### Build instructions from the plan

If a plan was found, distill it into a concise set of review instructions. Focus on:
- **Acceptance criteria** — what "done" looks like
- **Key tasks and file paths** — what was planned to change
- **Design notes / edge cases** — specific behaviors the reviewer should verify

Do NOT paste the entire plan verbatim if it's very long. Summarize into a tight block:

```
This branch implements plan-003-auth-middleware. Review for spec compliance:

Acceptance criteria:
- JWT validation middleware rejects expired tokens with 401
- Rate limiting: 100 req/min per IP, returns 429
- Middleware chain order: cors → rate-limit → auth → routes

Key changes:
- New file: src/middleware/auth.ts (JWT validation)
- New file: src/middleware/rate-limit.ts (sliding window)
- Modified: src/app.ts (middleware registration order)
- Tests: tests/middleware/auth.test.ts, tests/middleware/rate-limit.test.ts

Verify all planned files exist, acceptance criteria are met, and no planned work was missed.
```

#### Pass to the review

Append the instructions to the dispatch command:

```bash
greptile review --agent --instructions "This branch implements plan-003-auth-middleware. Review for spec compliance: [distilled plan]" 2>&1
```

If no plan was found, skip this phase — the review will run with default (code quality) focus.

### Phase 2: Run Greptile Review (Async Dispatch + Poll)

Greptile reviews run asynchronously on their servers and can take several minutes.
Do NOT wait for a single long-running command — it will timeout. Instead, dispatch
the review, then poll until complete.

#### Step 1: Dispatch the review

```bash
greptile review --agent 2>&1
```

This returns quickly (a few seconds) with output like:
```
▸ Review started: d50775e5-b351-4a3f-9040-b8e562f67e59
   Continue later with: greptile review show d50775e5-b351-4a3f-9040-b8e562f67e59
```

Extract the review ID (the UUID) for later use. If dispatch fails, report the error and stop.

> **Optional — `--resume`:** Greptile tracks the latest unfinished review per repository.
> Instead of dispatching a new review, you can run `greptile review --resume` to pick up
> where a prior dispatch left off. This is useful if a prior dispatch succeeded but you
> didn't capture the ID. For the normal loop (new review after each round of fixes), always
> dispatch fresh — don't use `--resume`.

#### Step 2: Poll for completion

Greptile tracks reviews per-repository, so `status` knows which review to check.
Use either approach below:

**Option A — `greptile review status`** (simplest — no args needed):
```bash
greptile review status 2>&1
```
- Exit code **3** = review still in progress → wait ~30s and retry
- Any other exit code = review complete or error → capture output

**Option B — `greptile review show <ID>`** (explicit by ID, supports `--json`):
```bash
greptile review show d50775e5-b351-4a3f-9040-b8e562f67e59 --agent 2>&1
```
- Output contains "Reviewing files…" or similar in-progress text → wait ~30s and retry
- Output contains findings/results → review complete, capture output

> **Tip:** Adding `--json` to `show` gives machine-parseable output for easier finding extraction.

#### Polling loop

```
loop:
  run `greptile review status`
  if exit code == 3:
    wait ~30 seconds
    goto loop
  else:
    # Review complete — retrieve findings with:
    greptile review show <ID> --json 2>&1
    capture the full output as the review results
```

Use a reasonable timeout per poll attempt (e.g., 60s). If the review appears stuck
for an unusually long time (>15 min of polling), report to the user.

Capture the full final output. Do not hide raw command failures — report the failing
command and the next action the user needs to take.

### Phase 3: Parse Findings

Parse the review output and classify each finding:

| Type | Description | Action |
|------|-------------|--------|
| **Actionable** | Code change needed (bug, refactor, missing validation, etc.) | Fix in Phase 4 |
| **Informational** | FYI, suggestion, or false positive | Note but don't fix |
| **Already addressed** | Resolved by prior commits | Skip |

If there are **zero findings**, skip to Phase 6 (exit condition met).

### Phase 4: Fix Findings

> ⚠️ **DISPATCH GUARD — READ BEFORE FIXING EACH FINDING**
>
> - **You MUST dispatch a `general` subagent for each actionable finding.**
> - **DO NOT fix code, edit files, or stage changes directly in your own context.**
> - If you skip dispatch, you forfeit the isolation and accountability that the subagent provides.
> - The main agent owns orchestration only — fix application is delegated.

#### Per-Finding Sequence (follow rigidly for every actionable finding)

**Step 1 — STOP & Verify.**
Before touching anything, confirm:
- [ ] This is an actionable finding from the current review output
- [ ] No fix has been applied yet in this context
- [ ] You are about to dispatch a `general` subagent (not fix the code yourself)

**Step 2 — Dispatch the subagent.**

> **DO NOT add a `model` parameter to any subagent call.** The agent definition controls its own model. Adding `model` causes hallucinated model names that break the call.

```
/// ───────────────────────────────────────────────────────────
///  MANDATORY: dispatch a `general` subagent to fix this finding.
///  DO NOT edit files or stage changes in your own context.
/// ───────────────────────────────────────────────────────────
subagent({
  agent: "general",
  task: "Fix the following Greptile findings on the local branch. For each finding: read the file, understand the issue, make the fix, and stage the change with git add. Findings: [list with file paths and descriptions]. Return a summary of what was changed.",
  description: "Fix Greptile finding: [short summary]"
})
```

The `general` subagent (not `reviewer`) is the correct dispatch target for applying code fixes — it is the same agent the `implement` skill uses for task execution. The `reviewer` subagent is prohibited from making changes and only returns reports.

**Step 3 — Verify dispatch happened.**
After the `subagent()` call returns, confirm the subagent actually performed the fix:
- [ ] The response includes file edits or `git add` from the subagent
- [ ] You did NOT edit files or stage changes in your own context
- [ ] If you find yourself having fixed code inline, stop and re-dispatch the subagent immediately

> 🔁 **If you catch yourself fixing code inline instead of dispatching — stop, reset, and dispatch the subagent.** This is the #1 failure mode of this skill; do not let it happen.

### Phase 5: Re-run Review (Loop)

After fixes are applied:

1. Go back to Phase 2 (dispatch a new review + poll for completion)
2. Parse new findings (Phase 3)
3. If new actionable findings exist, fix them (Phase 4)
4. Repeat

**Loop guard:** Max 5 iterations to avoid runaway loops. Each iteration is one full cycle of Phase 2 → Phase 3 → Phase 4.

### Phase 6: Exit Conditions

Stop the loop if **any** of these are true:

| Condition | Behavior |
|-----------|----------|
| Zero actionable findings | Exit loop, present summary, go to Phase 7 |
| Max 5 iterations reached | Exit loop, report remaining findings, go to Phase 7 |
| Review command fails | Report the failure, go to Phase 7 |

### Phase 7: Final Ask

After the loop exits, present a summary and ask:

```
ask({
  questions: [{
    id: "final-action",
    question: "Greptile review loop complete. X findings resolved, Y remaining. What would you like to do?",
    options: [
      { label: "Open a PR" },
      { label: "Merge to main" }
    ],
    description: "**Summary:**\n- Iterations: N\n- Findings resolved: X\n- Remaining: Y\n- Final confidence: [score if available]\n\n**Note:** 'Open a PR' uses the implement skill's PR opening logic. 'Merge to main' uses the finish skill to merge and sync."
  }]
})
```

- **Open a PR** → Push the branch and open a PR:
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
  Report the PR URL to the user. Return to the implement skill, which will handle updating the plan index.

- **Merge to main** → Load the `finish` skill directly (no PR needed — the finish skill handles both PR and direct-merge paths):
  1. Push the branch: `git push -u origin [branch-name]`
  2. Load the `finish` skill and run its full pipeline:
     - The finish skill checks whether a PR exists for the branch
     - If no PR → runs local validation gate and squash-merges directly onto main
     - If PR exists → checks reviews/CI/mergeability then merges via GitHub

## Integration with Implement Skill

The `implement` skill's "After All Tasks Complete" section adds a new option:

```
{ label: "Greptile review loop" }
```

When selected:
1. Load the `greptile` skill
2. Run it to completion (Phases 1–6)
3. At Phase 7, the greptile skill asks "Open a PR" or "Merge to main"
4. If "Open a PR" → use implement's "Open PR only" logic
5. If "Merge to main" → load the `finish` skill

## Quick Reference

| Phase | Command | Purpose |
|-------|---------|---------|
| 1 | `git rev-parse --show-toplevel` | Confirm repo context |
| 1 | `command -v greptile` | Check CLI installed |
| 1 | `greptile whoami` | Check auth |
| 1.5 | Read `docs/plans/plan-NNN-*.md` | Load plan for spec-compliance instructions |
| 2 | `greptile review --agent --instructions "..."` | Dispatch review with plan context |
| 2 | `greptile review --resume` | Pick up latest unfinished review (fallback) |
| 2 | `greptile review status` | Poll for completion (exit 3 = in progress) |
| 2 | `greptile review show <ID> --json` | Retrieve findings as JSON |
| 5 | (loop back to Phase 2) | Dispatch new review + poll after fixes |
| 7 | `ask()` | Open a PR or Merge to main |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Running review once and stopping | Loop back to Phase 2 after fixes until zero findings |
| Not checking auth first | Always run `greptile whoami` in Phase 1 |
| Waiting for `greptile review` to finish in one command | Dispatch returns immediately with a review ID — poll with `status` or `show <ID>` instead of waiting |
| Hiding CLI failures | Report the failing command and next action |
| Exceeding max iterations | Stop at 5 iterations and report remaining findings |
| Opening a PR during the loop | The greptile skill does NOT open PRs — only Phase 7 does, per user choice |
| Fixing findings directly instead of dispatching a subagent | The main agent must delegate ALL code fixes to `general` subagents — never edit files or stage changes in your own context |
