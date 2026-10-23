---
status: approved
issue: https://github.com/danielcherubini/skills/issues/6
done-when: A user can start from discuss, research, or codebase-improvement and the routing to roadmap vs specify is explicit in each entry skill; roadmap executes N tasks as waves on one branch and drives specify headless per task; all skill files and README describe the same two-shape pipeline.
---

# Skill Pipeline Routing & Roadmap Placement

**Goal:** Place `roadmap` correctly in the skill pipeline and make the trigger from every entry skill explicit, by splitting decomposition into two grains (roadmap coarse, specify fine) and removing the duplicated parallelism engine.

## Motivation

`roadmap` was added to sit "between `codebase-improvement`/`research`/`discuss` and `specify`/`implement`", but its own Step 4 already invokes `specify` per task and its Step 5 already calls `review`→`finish`. That makes the documented pipeline a flat line that contradicts the skill's behavior: roadmap cannot be both *in front of* specify and *the thing that calls* specify. In practice roadmap and specify looked like they were "trying to achieve the same thing" because both decompose work and both decide parallelism. The fix is a **grain split**, not a reordering: roadmap runs first and nests specify.

A second real gap: no entry skill says *when* to route to roadmap. `codebase-improvement` Phase 6 offers only `specify`; `discuss` and `research` have no roadmap branch; the README still lists a four-skill chain without roadmap.

## Design

### Pipeline — two shapes, not one line

```
small  (≤2 items, one PR):  entry → specify → implement → review → finish
large:                       entry → roadmap ─┬─ specify → implement ─┐
                                               ├─ specify → implement ─┼→ review → finish
                                               └─ specify → implement ─┘
```

Roadmap runs **first** and **nests** specify once per task.

### Grain split (resolves the "same thing" smell)

- **Roadmap = COARSE** — approved block → N tasks → dependency graph → waves. Does **not** know file paths, signatures, or TDD steps; the fine plan does not exist yet at this altitude.
- **Specify = FINE** — one roadmap task → one commitable plan (exact files, signatures, test commands) plus intra-task waves.

One execution engine (implement's wave protocol) applied at two grains. Roadmap delegates intra-task waves to specify instead of re-deriving them.

### Entry routing

| Entry | Default | Ask before handoff? |
|---|---|---|
| `codebase-improvement` | → **roadmap** | never — an approved backlog is inherently multi-task |
| `discuss` | → **specify** | only if HUGE: ≥3 independent items OR work won't fit one PR / spans sessions OR user says "run unattended" |
| `research` | → **nothing** (informs a decision) | only if findings imply multiple separate implementation tracks → offer roadmap |
| any entry, user says "do all of these / run unattended / keep going across sessions" | → **roadmap** | no ask — global override |

The count+scope discriminator: `≤2` items **and** fits one PR → silent specify (no ask). `≥3` items **or** "won't fit one PR / multiple sessions" → ask, defaulting to roadmap.

### Roadmap execution

- **N tasks = N commits on ONE feature branch → one PR** at review.
- **Waves:** tasks grouped by the same six parallelisation gates specify already defines, applied at task grain (disjoint `Files:`, no build-graph dependency, no shared lockfile/migration/barrel/route-registration, scoped verification suffices, no tree-wide mutation, ≤4 per wave). Wave children are dispatched in one response, **do not commit**, and run **scoped tests only**; the orchestrator commits each by explicit pathspec in plan order, then runs the **full suite once** as the wave barrier.
- **Autonomy:** ONE entry confirmation (measured baseline + dependency graph + wave breakdown) → then silent until done.
- **N=1 degenerate:** roadmap detects a single task and hands straight to **standalone specify** — no status-file machinery, no waves.
- **Executor reuse:** roadmap conforms to `implement`'s `Parallel Execution Guide` + `Task Dispatch Protocol` (referenced, not duplicated). It does **not** load the `implement` skill per task (that would re-fire implement's plan-selection/branch/after-tasks asks). BLOCKED-sibling handling, pathspec commits, and post-wave suite are inherited.

### Specify modes

| Mode | Invoker | Behavior |
|---|---|---|
| **Standalone** (unchanged) | entry skill / user, small scope | Full flow → reviewer vet → **HARD BREAK** → optional `implement` |
| **Consumed** (new) | roadmap, per task | Plan one task → reviewer vet (max 3 rounds) → write `docs/roadmap/<feature>-taskNN-<slug>.md` → **return control to roadmap; no HARD BREAK, no `implement` load** |

Mode is set by an **explicit instruction in the invocation text** (e.g. `SPECIFY CONSUMED MODE — plan this task; vetted; write to target path; NO hard break; return.`), not inferred from the filesystem — same discipline `implement` uses for wave dispatch.

### Artifacts

```
docs/roadmap/<feature>-status.md          # roadmap's memory (existing status-file-template format)
docs/roadmap/<feature>-taskNN-<slug>.md   # per-task consumed-specify plans (committed)
docs/roadmap/<feature>-follow-ups.md      # written by roadmap before the final commit; survives cleanup
```

`finish` cleanup becomes a glob over the family: `docs/roadmap/<feature>-*` (plan, status, all task plans). The follow-ups file is written by roadmap *before* the plan/status files are removed so deliberately-deferred work is not lost.

### File changes

| File | Change |
|---|---|
| `skills/roadmap/SKILL.md` | Grain split; task waves via implement's protocol; N=1 → standalone specify; ONE entry confirmation; consumed-specify per task; follow-ups pre-ship; header pipeline corrected to show nesting |
| `skills/specify/SKILL.md` | Add **consumed mode** (explicit-instruction detection, no HARD BREAK, target path, return); standalone unchanged |
| `skills/implement/SKILL.md` + `skills/implement/guides/guide-parallel-execution.md` | Note the wave protocol governs **both grains** (intra-plan waves and roadmap task waves). No new headless mode added. |
| `skills/codebase-improvement/SKILL.md` | Phase 6 handoff default → **roadmap** (no ask) |
| `skills/discuss/SKILL.md` | count+scope discriminator + HUGE ask before the specify handoff; silent specify otherwise; N=1/cross-session escape-hatch |
| `skills/research/SKILL.md` | Optional multi-implementation-track → offer roadmap branch |
| `skills/finish/SKILL.md` | Cleanup glob `docs/roadmap/<feature>-*` instead of single-file `rm` |
| `README.md` | Core pipeline shows both shapes; skill table + skill count gain roadmap; add a Roadmap entry |

## Out of scope

- No new skill. No change to `review`, `greptile`, `check-pr`, `release`, or agents.
- No multi-PR / stacked-branch / worktree execution mode — roadmap stays one-branch + waves (explicitly deferred).
- No tracker changes beyond what `discuss`/`specify` already do.
