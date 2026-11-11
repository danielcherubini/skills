# Skills

Specialized instruction sets that extend the agent's capabilities for structured workflows.

---

## The Idea

This pipeline was built around one belief: **you should be able to run small, open models locally and still ship complex work reliably.**

The trick is structure. If you break work into the right stages, each one produces artifacts precise enough that any capable model — even a small one — can execute its part without guessing. No chain-of-thought fluff, no vague prompts, no context bleed between tasks.

```
One plan:  entry → specify → implement (LIGHT) → review → finish
Many tasks: entry → implement (COARSE: decompose → ground → plan every task → vet
                       → one wave at a time → gate → fix) → review → finish
```

`implement` is one skill with two paths that share every execution primitive — branch setup, baseline, dispatch, wave protocol, gate, review/PR/finish. They differ in **memory and autonomy**, not mechanics.

- **research** — the front of the pipeline, on two paths. **Path A** gathers evidence (parallel researcher subagents, cited findings). **Path B** is collaborative design dialogue — settle the terminology, propose approaches with trade-offs, capture ADRs and glossary terms. Both ask what you actually mean *before* working, and neither writes the doc: `specify` does.
- **specify** — the sole writer of `docs/roadmap/<topic>.md`: the spec (WHAT/WHY) and the plan (HOW-IN-ORDER) in one pass. Each task is self-contained: exact file paths, function names, test commands. Written for a context-free agent, and it seeks waves rather than defaulting to serial.
- **implement** — executes the work. **LIGHT path:** one plan, todo list as memory, per-task supervision. **COARSE path:** decomposes an approved block into N tasks by **owned file set** so waves are genuinely parallel, builds the dependency graph, drives `specify` in consumed mode per task, keeps a status file as memory, and runs on one consent answer.
- **finish** — checks reviews and CI, fixes issues, merges, syncs main.

The result: you can one-shot any task no matter how complex, just by running it through the pipeline. Small models handle the execution. You handle the design.

### Where larger models fit

The [research](research/) and [review](review/) skills are pluggable gates you can run with either small or large models. Need a second opinion on architecture? Run research through a bigger model. Want a thorough code review before merge? Offload it. Like getting a second opinion from a specialist — you pay for the heavy reasoning only when you need it, and the rest of the pipeline stays cheap.

---

## Entry routing

Which skill the pipeline starts from — and whether it routes to `implement`'s COARSE path or straight to `specify`:

| Entry | Default target | Ask? |
|-------|----------------|------|
| **codebase-improvement** | → `implement` COARSE | never — an approved audit backlog is inherently multi-task |
| **research** Path B (design) | → `specify` | only when HUGE: ≥3 independent items, or won't fit one PR / spans sessions |
| **research** Path A (evidence) | → `specify` on the answer the user picks | also: findings imply multiple implementation tracks → offer the COARSE path |
| **any** + "run unattended / do all these / keep going across sessions" | → `implement` COARSE | no ask — explicit override |

`implement` itself asks exactly **one** consent question per run — autonomous vs check-in after every wave (COARSE), or which plan to execute (LIGHT).

## Development Workflow

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [research](research/) | "research", "compare", "evaluate", "deep-dive", "best practices for", "let's discuss", "lets brainstorm" | The front of the pipeline, two paths. **A — research:** clarify the question, then classify → dispatch parallel researcher subagents → synthesise → hard-stop ask → cited report. **B — design:** settle the domain language, ask one question at a time, propose approaches with trade-offs, approve section by section, capture ADRs and glossary terms. Both ask what the user means first. Neither writes the doc, and neither reaches implementation: the hard gate holds until a human approves. |
| [specify](specify/) | After design approval | Turns an approved design into a structured implementation plan with independent, commitable tasks. Writes to `docs/roadmap/` (or to the per-task `target:` in consumed mode). Grounds the plan before writing, then vets it against the actual codebase. As a consumed-mode child (`researcher`) it grounds inline and dispatches nothing — `implement`'s COARSE path runs the grounding researcher and reviewer for it. |
| [implement](implement/) | After plan is ready · a ticket key · "work through all of these", "do this autonomously", "break this into tasks", "keep going across sessions" | Executes the work on one of two paths. **LIGHT:** one plan (or a Task card's `plan` artifact, or a Jira ticket) — branch, baseline, dispatch per task, gate, review, PR. **COARSE:** an approved block of N≥2 tasks — partition by **owned file set** so waves are genuinely parallel, dependency graph, ground once per area to disk, fan planning out wide, implement in waves on one branch (status file = memory), one consent answer then autonomous. |
| [finish](finish/) | "merge this", "ship it", "finish up" | Completes the plan lifecycle: checks reviews and CI, fixes issues, merges the PR, syncs local main, deletes the whole `docs/roadmap/<feature>-*` family (history lives in git). |

## Quality and Debugging

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [review](review/) | "review", PR reviews, code quality checks | Systematic code review with explore → reviewer → present pipeline. Covers 12+ languages. Categorizes findings by severity (blocking, important, nit, suggestions). |
| [codebase-improvement](codebase-improvement/) | "improve this codebase", "audit code quality", "find architectural issues" | Systematic codebase audit through 8 engineering lenses (DRY, file length, abstractions, coupling, tests, patterns, dead code, naming). Produces a dated report in `docs/reviews/`. |
| [systematic-debugging](systematic-debugging/) | Any bug, test failure, unexpected behavior | Root-cause-first debugging process. Investigate → analyze → hypothesize → fix. No guessing. Stops after 3+ failed fixes to question architecture. |
| [test-driven-development](test-driven-development/) | Before writing implementation code | RED-GREEN-REFACTOR cycle. Write failing test first, verify it fails, write minimal code to pass, refactor. No production code without a failing test. |
| [verification-before-completion](verification-before-completion/) | Before claiming work is done | Run the verification command. Read the output. Then claim the result. No "should work" or "looks correct" without evidence. |

## Project Operations

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [trees-and-branches](trees-and-branches/) | Starting work that needs a branch, running tasks concurrently, switching branches with uncommitted work | Trunk-based branching conventions (`main → feature/* or bugfix/* → main`) plus git worktrees: one tree per concurrent task, worktree-for-the-interrupt instead of stash, fan-in of task branches, `gh stack` for PR chains. |
| [release](release/) | "release", "bump version", "publish vX.Y.Z" | Multi-language semver bumping with GitHub Actions verification. Detects all ecosystem files, checks CI status, applies custom `AGENTS.md` steps, tags and pushes. |
| [daily-summary](daily-summary/) | "daily summary", "standup", "what did I do today" | Scans git history across configured repo roots, synthesizes a Slack-ready bulleted summary to a tmp file for copy-paste. |

## Research and Discovery

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [research](research/) | Comparing libraries, evaluating approaches, deep-dives, "let's discuss" | Full skill in [Development Workflow](#development-workflow) above — it is the pipeline's front end as well as a research tool. Path A ends in a cited report under `docs/research/`; Path B ends in an approved design handed to `specify`. |
| [find-skills](find-skills/) | "find a skill for X", "how do I do X" | Searches the open agent skills ecosystem (skills.sh) and helps discover, evaluate, and install new skills. |

## Profile and Documentation

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [write-readme](write-readme/) | "create a README", "write a README" | Surveys the project and writes a comprehensive, well-structured README.md inspired by top open-source projects. |
| [github-profile](github-profile/) | "improve my GitHub profile", "profile README" | Audits and optimizes GitHub profile pages — README, metadata, pinned repos, stats widgets. Scores four categories (x/40 total). |

## Meta

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [write-skills](write-skills/) | Creating new skills, editing existing skills | TDD for process documentation. RED-GREEN-REFACTOR cycle applied to skill creation: write failing test (baseline), write skill, verify compliance, close loopholes. |

---

## How Skills Work

1. **Auto-detection** — The agent reads the `description` field in each skill's frontmatter to decide when to load it
2. **Manual reference** — You can explicitly ask the agent to use a skill by name
3. **Chaining** — Skills naturally flow into each other:
   ```
   One plan:   entry → specify → implement (LIGHT) → review → finish
   Many tasks: entry → implement (COARSE: decompose → ground → plan every task → vet
                   → one wave at a time → gate → fix) → review → finish
   ```

## Adding New Skills

Place a new directory in the skills folder with a `SKILL.md` file containing YAML frontmatter (`name` + `description`). See the [write-skills](write-skills/) skill for the full TDD-driven creation process.
