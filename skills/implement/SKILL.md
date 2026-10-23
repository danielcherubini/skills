---
name: implement
description: Use when you have a written implementation plan to execute or when given a Jira issue / ticket link to implement
---

# Implement

> 🚨 **CORE RULE: This skill dispatches `general` subagents to do the work. The main agent orchestrates — it does NOT write code, edit files, or run builds directly.**
>
> The single carve-out is the **wave commit + post-wave suite**: after a parallel wave, the orchestrator commits each task by pathspec and runs the full suite once (see *Running a wave*). Those two are the orchestrator's because no child inside a wave can safely do them — they all share one index and one tree. It is a narrow exception: never an inline code edit, never a fix to a child's implementation, never a build to "check" a child's work.

Read the plan, create a feature branch, dispatch subagents per task, review the branch, open a PR.

> ⚠️ **Before each task: STOP → Dispatch a `general` subagent → Verify dispatch → Handle response.**
> See the [Task Dispatch Protocol](#task-dispatch-protocol) for the mandatory per-task sequence.

## Plan Selection & Jira Ticket Inputs

### 1. When given a Jira ticket URL / key (e.g. `https://domain.atlassian.net/browse/KEY-123` or `KEY-123`):
1. **Fetch the ticket via MCP**: Call `getJiraIssue` (from the Atlassian MCP) with the issue key to retrieve summary, description, and details.
2. **Locate or extract the implementation plan**:
   - Check if the ticket description or linked issues contain the implementation plan/tasks, or reference a plan file in the repository (e.g. in `claude-docs/` or `docs/`).
   - If the ticket represents a work package from a roadmap/plan document in the repo, read that plan document.
   - If tasks are directly specified in the ticket or plan doc, use them to set up the branch and todo list.

### 2. When no plan or ticket is provided:
1. **Find candidate plans** — List `docs/roadmap/*.md` or roadmap docs. A doc is an executable plan when its front-matter says `status: committed`; a `status: approved` doc is a spec awaiting a plan — not executable yet (the `specify` skill turns it into a plan).

   **Exclude roadmap artifacts from this list** — they are `roadmap`-run bookkeeping, not standalone plans:
   - `docs/roadmap/<feature>-status.md` (the run's memory file)
   - `docs/roadmap/<feature>-taskNN-*.md` — per-task plans that carry a `parent:` front-matter key. They are executed by `roadmap` as part of a run, never on their own; offering one here would execute a slice of a feature with its dependencies unbuilt.
   - `docs/roadmap/<feature>-follow-ups.md` (staging notes)

   Only a committed doc **without** a `parent:` key is a standalone plan. If the only committed docs are roadmap task plans, say so and ask for the feature branch instead (a `roadmap` run in progress owns them).
2. **Ask the user** which plan to execute:

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

3. Always ask the user which plan to execute, even if only one candidate exists — do NOT skip the approval gate.
4. Once selected, read the full plan file and continue to Branch Setup.

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
> - **Update the todo list per task — in-progress BEFORE dispatch, completed IMMEDIATELY after DONE. Batching todo updates at the end is a failure.**
> - If you skip dispatch, you forfeit TDD, per-task commits, and isolation — the entire point of this skill.
> - The exceptions are: the Baseline Check (before Task 1); the wave commit + post-wave suite (*Running a wave* — a wave child cannot do these, it shares the index); and the final PR/code-review steps. Nothing else.

## Wave Planning (read the plan, then decide — do not guess)

After the baseline check and **before dispatching Task 1**, read the plan's `## Parallelisation` section and every task's `**Parallel:**` line, then **independently re-verify it**. The plan's verdict is a proposal from a planner who has not seen the tree since it wrote the plan; you have just run the baseline and you are about to touch the files. Trust your check, not its label.

**Verify per wave, mechanically:** collect each task's `Files:` list (Create + Modify + Test together); compare pairwise — any shared path (shared fixtures, snapshot dirs, `mod.rs`/`__init__.py`/barrel files, route/middleware registration, config, lockfiles, migrations) invalidates the wave; check the build graph for a task consuming a symbol another task in the same wave is creating; split waves larger than 4 (concurrent builds contend for one `target/` / `node_modules/.cache`).

**Then decide, in this order:**

1. **Integrity first.** No `## Parallelisation` section, a missing `**Parallel:**` line, or a line contradicting its own `Files:` list → **the plan's parallel claims are untrustworthy as a set: run fully serial.** Do not re-derive anything — with unreliable labels, any grouping you invent is speculation dressed as verification. Name the integrity failure you hit. **A missing verdict means SERIAL, never "ask the user."**
2. **Declared wave passes the checks → run it.**
3. **A wave failing a check dissolves that grouping, not the plan.** Re-derive from the `Files:` lists; survivors often form smaller valid waves (1+2 disjoint while 3 imports 1's symbol → Wave 1: {1,2}, Wave 2: {3}). The same mechanical check on a *smaller* grouping is verification; pushing a bigger one through on a hunch is embellishment. **Never *expand* a wave beyond what the pairwise check proves.**
4. **Nothing clears → fully serial.**

**State your mode in one line, then proceed — no `ask`; this is your decision to make.** Name the collision or the verification: `Executing SERIALLY — Tasks 2 and 4 both modify src/routes.py, so the plan's Wave 1 is invalid.` / `Executing in 2 waves — Wave 1: Tasks 1, 2 (verified disjoint); Wave 2: Task 3 (imports Task 1's Cart).` A bare "going parallel now" is not a mode statement — **the reason is what lets the user catch you being wrong.**

Full protocol with worked examples, failure handling, and the BLOCKED-sibling sequence: **[Parallel Execution Guide](guides/guide-parallel-execution.md)**.

The wave protocol in [guide-parallel-execution.md](guides/guide-parallel-execution.md) is the shared source for both intra-plan waves and roadmap task waves.

## Per-Task Sequence (follow rigidly for every task)

Applies to every task, serial or in a wave — a wave just means several of these run concurrently, each in its own child. Steps 1–4 are per-task; the wave barriers are per-wave (*Running a wave*).

**Step 1 — STOP & Verify.**
Before touching anything, confirm:
- [ ] This is a task from the plan, not a tangent
- [ ] No code has been written yet in this context
- [ ] You are about to dispatch a `general` subagent (not do the work yourself)
- [ ] You have marked this task **in-progress** in the todo list via `manage_todo_list` (required before Step 2 — do not skip; the user is watching this list to track progress)

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
- Create and maintain its own todo list for the task's steps (in-progress before each step, completed immediately after)
- Load TDD skill and follow RED-GREEN-REFACTOR
- Validate format → build → test → lint in order
- Commit with a descriptive message — **unless the task text forbids committing** (wave tasks do; see *Running a wave*). Its default is to commit, so a wave dispatch must say so explicitly or it will commit and blend a sibling's files into its commit.
- Report DONE | BLOCKED | NEEDS_CONTEXT

**Step 3 — Verify dispatch happened.**
After the `subagent()` call returns, confirm the subagent actually performed the work:
- [ ] The response includes file edits, test runs, or commits from the subagent (a **wave** task reports file edits and scoped test runs and deliberately has NO commit — its commit comes from you; an absence of commit there is correct, not a skipped step)
- [ ] You did NOT write any code, edit files, or run builds in your own context
- [ ] If you find yourself having done work inline, stop and re-dispatch the subagent immediately

**Step 4 — Handle the subagent response:**
- **DONE:** Mark task complete in the todo list via `manage_todo_list` IMMEDIATELY — this is part of Step 4, not an afterthought. Do NOT defer it to the end of the plan; update the list before dispatching the next subagent. In a wave, mark each task complete only once *you* have committed its files (Step 2 of *Running a wave*) — a returned-but-uncommitted task is not done.
- **NEEDS_CONTEXT:** Provide missing info, re-dispatch (task stays in-progress)
- **BLOCKED:** Assess blocker, provide help or escalate to user (task stays in-progress until resolved)

**Important:** Default to dispatching tasks **sequentially** — one response, one task, wait. Run them concurrently ONLY when *Wave Planning* has verified a wave for them. The hazard is not the dispatch mechanism but the shared working tree: two children editing one file, one shared fixture, or one `.git/index` produce a commit that is neither task's work and a RED/GREEN check that is measuring a sibling. If you have not explicitly verified disjoint file sets, you are running serially.

> 🔁 **If you catch yourself doing work inline instead of dispatching — stop, reset, and dispatch the subagent.** This is the #1 failure mode of this skill; do not let it happen.

### Running a wave

**One response, one `subagent` call per task in the wave.** Parallel tool calls from a single response execute concurrently — N tasks take about the wall-clock of one, not N. Emitting them in separate responses is serial dispatch wearing a wave costume.

Every wave dispatch must carry these additions to the usual task text — the numbered deviations override the `general` agent's defaults, so state them explicitly:

```
subagent({
  agent: "general",
  task: "[FULL TEXT of task from plan]\n\nContext: [where this fits, what's already done]\n\nPARALLEL WAVE — two deviations from your defaults:\n1. DO NOT COMMIT. Leave your changes in the working tree and report the exact files you touched. The orchestrator commits your task with its own message. (A commit here would sweep a sibling's half-finished files into your commit — you share one index.)\n2. VERIFY SCOPED ONLY. Run only your own test file/module and format only your own files. Do NOT run the full suite, a whole-tree formatter, or a lockfile regeneration — siblings are mid-edit in this same tree, so a full-suite result measures everyone at once and cannot tell you whether YOUR code is broken.\nReport DONE with the file list."
})
```

Then, for the wave as a unit:

1. **Wait for all of them** — the wave is a barrier. Do not start wave N+1 while any wave-N task is outstanding.
2. **Commit each task separately, with an explicit pathspec**, using the plan's commit message for that task, one at a time in plan order: `git commit -m "<task N message>" -- <task N files>`. The pathspec is what makes this safe — never `git commit -a`, never `git add .`.
3. **Run the full suite once, serially**, now that nothing is moving. This is the integration check no scoped in-wave test can provide. A failure here is yours to resolve before wave N+1 — usually the seam between two siblings' work, which neither child could see. Diagnose by reading and bisecting, then fix by re-dispatching: **you may not type the fix yourself** (CORE RULE carve-out covers committing and this suite run, nothing else).
4. **Mark every task complete individually**, and only once you have committed its files.
5. **A BLOCKED sibling holds the wave.** Commit the completed tasks (they were written to be independently commitable), set the blocked task's partial edits aside so the tree represents only what you committed, then resolve or escalate before wave N+1. Do not route around it.

Serial tasks are unchanged: dispatch one, let it commit as usual, wait, verify, next.

## After All Tasks Complete

Once all tasks are done, ask the user what to do next:

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

### Review Loop

**Run a full code review loop — auto-fix all findings iteratively until clean.**

1. Load the `review` skill and run it to completion (explore → classify → reviewer → parse → fix → re-review → loop until clean or max iterations)
2. The review skill handles the review loop itself — let it run to completion
3. The review skill's Phase 8 will ask **Open a PR** or **Merge to main** and execute the chosen action:
   - **Open a PR** → The review skill opens the PR and reports the URL
   - **Merge to main** → The review skill loads the `finish` skill (see **Finish Plan** below)

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
3. Load the `finish` skill to check PR status, merge to main, and complete the plan lifecycle (delete the roadmap doc)
