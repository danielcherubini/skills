# My Skills and Agents

## The Core Pipeline

The primary development workflow chains four skills together:

```
discuss → specify → implement → finish
```

1. **discuss** — Collaborative design dialogue before coding. Establishes shared terminology, proposes approaches with trade-offs, captures ADRs and glossary terms. Hard gate — no code until design is approved.
2. **specify** — Turns the approved design into independent, commitable tasks with exact file paths, function names, and test commands. Written for a context-free agent. Outputs to `docs/plans/`.
3. **implement** — Executes the plan: creates feature branch, runs baseline checks, dispatches subagents per task (TDD-driven), handles reviews, opens PRs.
4. **finish** — Checks reviews and CI, fixes issues, merges the PR, syncs local main, updates the plan index.

This structure lets even small local models handle complex work reliably — each stage produces precise artifacts that the next stage can execute without guessing.

## Meta Skills

Beyond the pipeline, two skills operate as pluggable gates you can run with either small or large models. Like getting a second opinion from a specialist — you pay for heavy reasoning only when you need it.

### Review

The [review skill](skills/review/) is a full code review pipeline — not just "look at the diff and comment." It follows a structured three-phase architecture:

```
explore subagent(s) → reviewer subagent → main agent presents + ask()
```

- **Explore phase** — one or more subagents gather context in parallel: changed files, related imports/callers, test coverage, CI status, docs. For large changes (> 400 lines), multiple explore agents run simultaneously.
- **Reviewer phase** — a dedicated reviewer subagent receives the enriched context and runs through detailed checklists: architecture & design, performance (Big-O, memory, N+1 queries), security (injection, auth, data exposure), correctness, testing, maintainability, documentation. Consults language-specific guides for 12+ languages/frameworks.
- **Presentation phase** — the main agent presents findings categorized by severity (🔴 blocking, 🟡 important, 🟢 nit, 💡 suggestions, 📚 learning, 🎉 praise) and calls `ask()` so you choose what to fix. Hard stop — nothing happens until you respond.

The reviewer subagent never fixes code or interacts with the user. The main agent owns orchestration, presentation, and all fixes after your decision.

**Triggers:** *"review"*, *"PR review"*, *"code review"*, *"check this code"*, *"audit"*, *"security review"*

### Research

The [research skill](skills/research/) is a systematic investigation engine for comparing libraries, evaluating architectures, deep-diving into topics, or finding best practices. It follows a phased approach:

```
classify → dispatch N parallel researcher subagents → synthesise → hard-stop ask → deliver
```

- **Classification** — determines research type (web, code, academic, video, hybrid) and depth (quick 1 angle, standard 2-3, deep 4-6 angles).
- **Dispatch** — the main agent designs narrow, non-overlapping research angles and dispatches parallel researcher subagents. Each gets one specific angle, gathers evidence, and reports back with citations. Supports both parallel (fastest) and serial (when angles depend on each other) modes.
- **Synthesis** — the main agent combines all findings, resolves contradictions (presenting both sides with credibility assessment), builds evidence chains, and identifies gaps.
- **Hard-stop ask** — presents the draft report and pauses for your input: deliver as-is, discuss findings, targeted deep-dive on gaps, add a research dimension, or reframe the question entirely.

Every claim is backed by a source — GitHub permalinks with commit SHAs, full URLs, video timestamps. Claims are classified as verified facts, reasonable inferences, or speculation.

**Triggers:** *"research"*, *"compare"*, *"evaluate"*, *"deep-dive"*, *"investigate"*, *"best practices for"*

### Codebase Improvement

The [codebase-improvement skill](skills/codebase-improvement/) is a systematic audit that surfaces improvement opportunities through 8 engineering lenses: file length, DRY violations, weak abstractions, coupling issues, missing tests, inconsistent patterns, dead code, and naming. It borrows the research skill's dispatch pattern for scanning and the review skill's deep-dive pattern for high-severity findings. Produces a dated markdown report in `docs/reviews/`, then walks through each finding conversationally with you — approve, research more, dismiss (with optional ADR recording), or defer. Flows naturally into `discuss → specify → implement` after approval.

**Triggers:** *"improve this codebase"*, *"audit code quality"*, *"find architectural issues"*

### Systematic Debugging

The [systematic-debugging skill](skills/systematic-debugging/) enforces a root-cause-first process: investigate (read errors, reproduce, trace data flow) → analyze (compare working vs broken) → hypothesize and test (one variable at a time) → fix (failing test first). No guessing. If 3+ fixes fail, it stops and questions the architecture instead of piling on band-aids.

**Triggers:** Any bug, test failure, or unexpected behavior

## All Skills

### Quality and Debugging

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [review](skills/review/) | "review", "PR review", "check this code" | Full three-phase review pipeline with explore → reviewer subagents, 12+ language guides, severity-categorized findings, hard-stop ask before fixes |
| [codebase-improvement](skills/codebase-improvement/) | "improve this codebase", "audit code quality" | Systematic audit through 8 engineering lenses, produces dated report, conversational walkthrough, flows into dev pipeline |
| [systematic-debugging](skills/systematic-debugging/) | Any bug or test failure | Root-cause-first: investigate → analyze → hypothesize → fix. Stops after 3+ failed fixes to question architecture |
| [test-driven-development](skills/test-driven-development/) | Before writing implementation code | RED-GREEN-REFACTOR cycle. No production code without a failing test first |
| [verification-before-completion](skills/verification-before-completion/) | Before claiming work is done | Run the verification command. Read the output. Then claim the result. No "should work" without evidence |
| [greptile](skills/greptile/) | "greptile review", "review with greptile" | Runs Greptile CLI iteratively on the local branch until all findings are resolved, then offers PR or merge |

### Project Operations

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [gitflow-branching](skills/gitflow-branching/) | Starting new work requiring a branch | Trunk-based branching: `main → feature/* or bugfix/* → main`. Always from main, short-lived branches |
| [release](skills/release/) | "release", "bump version", "publish vX.Y.Z" | Multi-language semver bump with GitHub Actions verification. Detects all ecosystem files, checks CI, applies custom `AGENTS.md` steps, tags and pushes |
| [daily-summary](skills/daily-summary/) | "daily summary", "standup", "what did I do today" | Scans git history across configured repos, synthesizes Slack-ready bulleted summary |

### Research and Discovery

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [research](skills/research/) | "compare", "evaluate", "deep-dive", "investigate" | Phased investigation: classify → parallel researcher subagents → synthesise → hard-stop ask → deliver. Evidence-backed with citations |
| [find-skills](skills/find-skills/) | "find a skill for X", "how do I do X" | Searches the open agent skills ecosystem (skills.sh) to discover, evaluate, and install new skills |

### Profile and Documentation

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [write-readme](skills/write-readme/) | "create a README", "write a README" | Surveys the project and writes a comprehensive README.md inspired by top open-source projects |
| [github-profile](skills/github-profile/) | "improve my GitHub profile", "profile README" | Audits and optimizes GitHub profile pages — README, metadata, pinned repos, stats widgets. Scores four categories (x/40) |

### Meta

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [write-skills](skills/write-skills/) | "write a skill", "create a skill", "edit skill" | TDD for process documentation. RED-GREEN-REFACTOR applied to skill creation: write failing test, write skill, verify compliance, close loopholes |

## Subagents

The [`agents/`](agents/) directory contains subagent configurations — specialized agents dispatched by skills for specific roles:

| Agent | Role |
|-------|------|
| [general](agents/general.md) | Executes a single task from an approved plan (TDD-driven) |
| [explore](agents/explore.md) | Surveys codebases and gathers context |
| [researcher](agents/researcher.md) | Parallel research on specific angles |
| [reviewer](agents/reviewer.md) | Systematic code review with severity categorization |

All subagents are "pure leaves" — they receive a task, do the work, and return results. They never plan, dispatch other agents, or interact with the user. The main agent owns all orchestration and user interaction.

## Installation

This repo symlinks its contents into the config directories of supported tools:

```bash
~/.agents/install.sh
```

Currently manages symlinks for:
- **Claude** — `~/.claude/skills`
- **opencode** — `~/.config/opencode/agents`

> **Note:** Tool-specific configs (pi, claude, opencode) are managed separately via dotfiles. Only `skills/` and `agents/` live here.

## Adding New Skills

Place a new directory under `skills/` with a `SKILL.md` file containing YAML frontmatter:

```yaml
---
name: my-skill
description: Use when ...
---
```

See the [write-skills](skills/write-skills/) skill for the full TDD-driven creation process.

## Philosophy

This pipeline was built around one belief: **you should be able to run small, open models locally and still ship complex work reliably.**

The trick is structure. Break work into the right stages, each producing artifacts precise enough that any capable model can execute its part without guessing. No chain-of-thought fluff, no vague prompts, no context bleed between tasks. Small models handle the execution. You handle the design.
