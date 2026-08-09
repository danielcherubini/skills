# Skills

Specialized instruction sets that extend the agent's capabilities for structured workflows.

---

## The Idea

This pipeline was built around one belief: **you should be able to run small, open models locally and still ship complex work reliably.**

The trick is structure. If you break work into the right stages, each one produces artifacts precise enough that any capable model — even a small one — can execute its part without guessing. No chain-of-thought fluff, no vague prompts, no context bleed between tasks.

```
discuss → specify → implement → finish
```

- **discuss** — collaborative design dialogue. Produces an approved spec with clear terminology, trade-offs, and acceptance criteria.
- **specify** — turns the spec into independent, commitable tasks. Each task is self-contained: exact file paths, function names, test commands. Written for a context-free agent.
- **implement** — executes the plan task by task. Subagents get one task each, run TDD, commit, report done.
- **finish** — checks reviews and CI, fixes issues, merges, syncs main.

The result: you can one-shot any task no matter how complex, just by running it through the pipeline. Small models handle the execution. You handle the design.

### Where larger models fit

The [research](research/) and [review](review/) skills are pluggable gates you can run with either small or large models. Need a second opinion on architecture? Run research through a bigger model. Want a thorough code review before merge? Offload it. Like getting a second opinion from a specialist — you pay for the heavy reasoning only when you need it, and the rest of the pipeline stays cheap.

---

## Development Workflow

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [discuss](discuss/) | "let's discuss", "lets brainstorm" | Collaborative design dialogue before coding. Establishes shared terminology, proposes approaches with trade-offs, captures ADRs and glossary terms. Hard gate — no code until design is approved. |
| [specify](specify/) | After design approval | Turns an approved design into a structured implementation plan with independent, commitable tasks. Writes to `docs/plans/`. Includes reviewer pass against the actual codebase. |
| [implement](implement/) | After plan is ready | Executes the plan: creates feature branch, runs baseline checks, dispatches subagents per task, handles reviews, opens PRs. |
| [finish](finish/) | "merge this", "ship it", "finish up" | Completes the plan lifecycle: checks reviews and CI, fixes issues, merges the PR, syncs local main, updates the plan index. |

## Quality and Debugging

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [review](review/) | "review", PR reviews, code quality checks | Systematic code review with explore → reviewer → present pipeline. Covers 12+ languages. Categorizes findings by severity (blocking, important, nit, suggestions). |
| [codebase-improvement](codebase-improvement/) | "improve this codebase", "audit code quality", "find architectural issues" | Systematic codebase audit through 8 engineering lenses (DRY, file length, abstractions, coupling, tests, patterns, dead code, naming). Produces a dated report in `docs/reviews/`. |
| [systematic-debugging](systematic-debugging/) | Any bug, test failure, unexpected behavior | Root-cause-first debugging process. Investigate → analyze → hypothesize → fix. No guessing. Stops after 3+ failed fixes to question architecture. |
| [test-driven-development](test-driven-development/) | Before writing implementation code | RED-GREEN-REFACTOR cycle. Write failing test first, verify it fails, write minimal code to pass, refactor. No production code without a failing test. |
| [verification-before-completion](verification-before-completion/) | Before claiming work is done | Run the verification command. Read the output. Then claim the result. No "should work" or "looks correct" without evidence. |
| [greptile](greptile/) | "greptile review", "greptile loop", "review with greptile" | Runs Greptile CLI review iteratively on the local branch until all findings are resolved, then offers to open a PR or merge to main. |

## Project Operations

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [gitflow-branching](gitflow-branching/) | Starting new work requiring a branch | Trunk-based branching conventions: `main → feature/* or bugfix/* → main`. Always branch from main, keep branches short-lived. |
| [release](release/) | "release", "bump version", "publish vX.Y.Z" | Multi-language semver bumping with GitHub Actions verification. Detects all ecosystem files, checks CI status, applies custom `AGENTS.md` steps, tags and pushes. |
| [daily-summary](daily-summary/) | "daily summary", "standup", "what did I do today" | Scans git history across configured repo roots, synthesizes a Slack-ready bulleted summary to a tmp file for copy-paste. |

## Research and Discovery

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [research](research/) | Comparing libraries, evaluating approaches, deep-dives | Phased research: classify → dispatch parallel researcher subagents → synthesize → hard-stop ask → write report to disk. Evidence-backed with citations. |
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
3. **Chaining** — Skills naturally flow into each other (e.g., `discuss` → `specify` → `implement` → `finish`)

## Adding New Skills

Place a new directory in the skills folder with a `SKILL.md` file containing YAML frontmatter (`name` + `description`). See the [write-skills](write-skills/) skill for the full TDD-driven creation process.
