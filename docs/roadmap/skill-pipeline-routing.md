---
status: committed
issue: https://github.com/danielcherubini/skills/issues/6
done-when: A user can start from discuss, research, or codebase-improvement and the routing to roadmap vs specify is explicit in each entry skill; roadmap executes N tasks as waves on one branch and drives specify in consumed mode per task; all skill files, both READMEs describe the same two-shape pipeline, and the roadmap status template's loop protocol matches the consumed-mode + wave execution.
---

# Skill Pipeline Routing & Roadmap Placement — Plan

**Goal:** Make roadmap's place in the pipeline explicit and consistent across all skills: roadmap runs first and nests specify (coarse/fine grain split), every entry skill routes to roadmap-vs-specify by an explicit rule, and roadmap drives specify in consumed mode per task while executing tasks as waves on one branch.

**Architecture:** These are markdown skill-definition files with YAML frontmatter under `~/.agents/skills/`. "Implementation" is editing prose + code-block wording so the skill files, the implement guide, the roadmap status template, and both READMEs describe one consistent pipeline. Verification is structural (frontmatter) plus cross-reference consistency (grep assertions). There is no test runner, compiler, or linter in this repo.

**Tech Stack:** Markdown, YAML frontmatter, git.

**Run all verification commands from the repo root** (`~/.agents`) — every path below is repo-relative.

**Canonical terminology:** the new specify mode is called **"consumed mode"** everywhere (never "headless"). The literal marker string is `SPECIFY CONSUMED MODE`.

**Canonical two-shape block** — every file that describes the pipeline must paste these two lines VERBATIM (Task 2 writes it in roadmap, Task 7 in both READMEs):
```
Small scope: entry → specify → implement → review → finish
Large scope: entry → roadmap → ( specify → implement per task, in waves ) → review → finish
```

---

## Parallelisation

**Verdict:** SERIAL — verification for every task is a repo-wide cross-reference consistency check (e.g. "every file that names the pipeline uses the identical two-shape block", "consumed-mode wording in specify matches how roadmap invokes it"). Acceptance criteria are not provable by a task's own file alone — gate 4 (scoped verification suffices) fails for all tasks — so no wave is legal. Editing is also conceptually dependent: specify's consumed-mode contract (Task 1) must exist before roadmap can reference it correctly (Task 2), and the roadmap status template must match the roadmap rewrite.

---

### Task 1: Specify consumed mode

**Parallel:** none — SERIAL. Its wording is consumed by Task 2 (roadmap references it) and Task 3 (implement notes it).

**Context:**
`specify` today always: reads `docs/roadmap/<topic>.md`, plans it, runs a reviewer vet, then ends in a HARD BREAK that asks "proceed with implementation?" and, on yes, loads `implement`. Roadmap must run specify **once per task, without any ask**, writing the plan to a per-task path and returning control. This task adds a second invocation mode to `skills/specify/SKILL.md`, selected by an explicit marker in the calling text (never by filesystem inference), leaving standalone behavior unchanged.

**Files:**
- Modify: `skills/specify/SKILL.md`

**What to implement:**
1. Add a `## Invocation Modes` section BEFORE `## Input` containing:
   - **Standalone mode (default):** current behavior, unchanged — full flow → reviewer vet (max 3 rounds) → HARD BREAK → ask → optionally load `implement`.
   - **Consumed mode:** entered ONLY when the invoking task text contains the exact marker `SPECIFY CONSUMED MODE`. In consumed mode:
     - Plan exactly ONE task (described by the task text), NOT a whole feature.
     - The target path is the `target:` stated in the invocation text (e.g. `docs/roadmap/<feature>-taskNN-<slug>.md`). If no `target:` is present, stop and report NEEDS_CONTEXT — never guess a path.
     - **Reviewer-vet still runs** (parameterised on the target path — see step 5), max 3 rounds.
     - Write the plan to the target path with front-matter `status: committed`, a `parent: docs/roadmap/<feature>.md` key, and `done-when`.
     - Perform **neither** the spec-doc commit **nor** the issue-tracker mirror — the caller (roadmap) owns both.
     - Do **NOT** perform the HARD BREAK, do **NOT** call `ask`, do **NOT** load `implement`. Return control with a one-line "plan written to <target>" report.
2. At the TOP of `## Input`, add: "**In consumed mode ignore this section** — the target path is the `target:` given in the invocation text, no `ask` is permitted, and the 'no file → ask the user' branch never applies. If a `status: committed` plan already exists at the target (a re-run after a BLOCKED task), REFINE it in place (as the standalone committed-branch already describes) rather than re-planning from scratch."
3. In `## Plan Format`, after the path sentence, add: "…unless consumed mode names a different `target:` — then write there instead, with the extra `parent:` front-matter key."
4. In `## After Plan is Written`, qualify the commit and tracker-mirror paragraphs for standalone only, and insert the consumed-mode note here:
   - Change the commit paragraph (`skills/specify/SKILL.md:145`, "Commit the roadmap doc (`git add docs/roadmap/<topic>.md && git commit …`)") to start with "**Standalone mode only:**" and add "in consumed mode the caller owns the commit."
   - Change the tracker-mirror paragraph (`:147`, "**Mirror the plan to the issue tracker**") to start with "**Standalone mode only:**" and add "in consumed mode the caller owns the mirror."
   - Immediately after those two paragraphs (still ABOVE the `**HARD BREAK — STOP here and ask.**` line), insert: "**In consumed mode, skip the HARD BREAK below** — do not ask, do not load `implement`; return control to the caller. (The reviewer dispatch and max-3-round fix loop above still run.)"
   Do NOT place this note at the top of the section.
5. Change the reviewer prompt in `## After Plan is Written` from the hardcoded `docs/roadmap/<topic>.md` to the resolved plan path. Concretely, replace the substring "Review the implementation plan at `docs/roadmap/<topic>.md`" with "Review the implementation plan at `<resolved plan path>`" and add a sentence right after the prompt: "<resolved plan path> is the spec's file in standalone mode, or the invocation's `target:` in consumed mode." This keeps the prompt copy-pasteable in both modes.
6. Add a Common Mistakes row: `| Performing the HARD BREAK, committing, or mirroring to the tracker in consumed mode | Consumed mode writes the plan and returns; the caller owns commit + tracker |`.

**Steps:**
- [ ] Edit `skills/specify/SKILL.md` per items 1–6.
- [ ] `grep -c "SPECIFY CONSUMED MODE" skills/specify/SKILL.md` — expect `>= 1`.
- [ ] `grep -q "## Invocation Modes" skills/specify/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -qi "parent: docs/roadmap" skills/specify/SKILL.md && echo OK` — expect `OK`.
- [ ] `head -1 skills/specify/SKILL.md` — expect `---`; `grep -m1 '^name:' skills/specify/SKILL.md` — expect `name: specify`.
- [ ] Commit: `feat(skills): add consumed mode to specify skill`

**Acceptance criteria:**
- [ ] `## Invocation Modes` defines both modes; consumed mode requires the literal marker `SPECIFY CONSUMED MODE` and a `target:` (else NEEDS_CONTEXT).
- [ ] Consumed mode runs the reviewer vet but forbids the HARD BREAK, `ask`, `implement` load, the doc commit, and the tracker mirror; refines an existing committed target.
- [ ] The reviewer prompt uses the resolved plan path, not a hardcoded `<topic>.md`.
- [ ] Standalone behavior text is unchanged in meaning.

---

### Task 2: Roadmap grain split, waves, entry, consumed-specify, follow-ups, status template

**Parallel:** none — SERIAL. Depends on Task 1's consumed-mode contract; its status template must match.

**Context:**
`skills/roadmap/SKILL.md` contradicts itself: its header says it sits *before* specify while Step 4 invokes specify per task and Step 5 calls review→finish. It inlines a mini-executor instead of referencing implement's wave protocol, never defines where N tasks' specify plans live, and never creates a branch. The status template (`status-file-template.md`) hardcodes the old loop. This task rewrites both to the approved design.

**Files:**
- Modify: `skills/roadmap/SKILL.md`
- Modify: `skills/roadmap/status-file-template.md`

**What to implement:**
- **Header pipeline line** — `skills/roadmap/SKILL.md:8-9` currently reads (`**roadmap**` bolded, backticks, line break): `it unattended. Pipeline: \`research\` / \`discuss\` / \`codebase-improvement\` → **roadmap** → \`specify\` → \`implement\` → \`review\` → \`finish\`.` Replace that sentence with the **canonical two-shape block** from this plan's header (verbatim), plus one sentence: "Roadmap runs first and NESTS specify once per task."
- **Add `## Grain split`** immediately after `## Step 0 — Entry` (below), before `## Step 1`: roadmap = COARSE (approved block → N tasks → dependency graph → waves; carries NO file paths, signatures, or TDD steps), specify = FINE (one task → commitable plan + intra-task waves). State roadmap delegates intra-task waves to specify and does not re-derive them.
- **Add `## Step 0 — Entry`** immediately BEFORE `## Step 1`. It must (reference Steps 1–2, not restate them):
  - State the approved-block input artifact per entry skill: codebase-improvement → the approved report in `docs/reviews/`; discuss → `docs/roadmap/<topic>.md` (`status: approved`) + its `issue:` key; research → its report in `docs/research/`. **Do NOT flip the spec's `status: approved`** — `implement` treats `status: committed` as an executable plan, so flipping would offer a task-list-less spec as a plan. Leave it `approved`; the existence of `<feature>-status.md` (roadmap's memory) is what marks the run.
  - Reference Step 1 (measure gate baseline) and Step 2 (decompose + seams).
  - Present the measured baseline + dependency graph + wave breakdown once and ask exactly one `ask` ("Proceed autonomously with this plan?"). After yes, never ask again until done.
  - **Create the feature branch** here: name `gitflow-branching` and branch `feature/<topic>` off `main` (roadmap commits N tasks to this branch). Do not commit onto `main`.
  - If decomposition yields exactly one task, hand straight to **standalone specify** (no status file, no waves) and say so. Put this as a `## N=1 degenerate` subsection here.
- **Step 2 (decompose/seams)** — keep the serial-vs-parallel decision, but state task waves use the SAME six gates specify defines (they live in `skills/specify/SKILL.md` and `skills/specify/guides/guide-parallelisation.md`), at task grain. **State how disjointness is determined at task grain:** roadmap tasks carry no `Files:` lists, so disjointness is judged at decomposition time from each task's declared seam, then re-verified against the tree before dispatch (per Step 3's "tree outranks the plan"). Say the wave protocol itself (children never commit; orchestrator commits by pathspec; scoped in-wave tests; full suite once per wave; ≤4 per wave; BLOCKED sibling holds the wave) is DEFINED in `skills/implement/guides/guide-parallel-execution.md` — reference the relative path `../implement/guides/guide-parallel-execution.md`, do not restate it. Add: N tasks = N commits on ONE feature branch → one PR at review.
- **Step 4 (the loop)** — rewrite per iteration: read status file → first `todo` task; if its wave siblings are disjoint, dispatch them together per the wave protocol, else serially; expand each task with specify in consumed mode by passing the literal marker `SPECIFY CONSUMED MODE`, the task's decomposition text (so specify knows which single task to plan), and `target: docs/roadmap/<feature>-taskNN-<slug>.md`; **stage/commit the produced task plan docs** either in their own `docs: plan <feature> taskNN` commit or folded into that task's pathspec commit (consumed specify is forbidden from committing, so roadmap owns it); orchestrator commits source by pathspec; run full suite per wave (and after each serial task); mark `done`; update file. Keep "orchestrator never edits source itself."
- **Autonomous line** (`skills/roadmap/SKILL.md:66`) — amend "never ask the owner" to "never ask the owner *after* the Step 0 Entry confirmation".
- **Step 5 (ship)** — keep review→finish; state `<feature>-follow-ups.md` is written BEFORE the final commit (plan/status deleted on ship) and that finish deletes the whole `docs/roadmap/<feature>-*` family (including follow-ups, after their content is folded into `docs/features/` or an ADR).

**Status template (`skills/roadmap/status-file-template.md`) — replace in place:**
- Operating-mode protocol steps 3–6: replace with the consumed-mode + wave protocol — "3. Expand it with `specify` in CONSUMED MODE (marker `SPECIFY CONSUMED MODE`, `target: docs/roadmap/<feature>-taskNN-<slug>.md`). 4. Dispatch wave siblings together per implement's wave protocol (children don't commit; you commit by pathspec; scoped tests in-wave; full suite once per wave). 5. Green → commit by pathspec → mark `done` → one Changelog line. Red → re-dispatch; never fix by hand. 6. Update THIS FILE before starting the next task. Then loop."
- Tasks table: change the `| # | Task | Plan § | Status |` header to `| # | Task | Plan file | Wave | Status |` — each task now has its own plan file and a wave, so a `Wave` column and the plan filename replace the stale `Plan §` column. Keep the same row statuses (`todo` / `done` `<hash>`).
- Gate line: change "re-run after every task" to "re-run after every wave (and after each serial task)".
- Add a `## Dependency graph / waves` section (the persisted wave grouping — the "only memory" must carry it): a small block listing `Wave 1: A, B, C (disjoint)`, `Wave 2: D (needs A's <symbol>)`.
- `## The follow-ups file` — reword: follow-ups is a **staging** file written before the final commit; on ship finish deletes it together with the plan/status after its content is folded into `docs/features/` or an ADR. (It is no longer described as the permanent survivor.)

**Steps:**
- [ ] Edit `skills/roadmap/SKILL.md` (header → canonical block + nesting sentence; add Step 0 Entry + Grain split + N=1 degenerate; Step 2 seam/gate + branch; Step 4 consumed-mode + waves; autonomous line; Step 5 follow-ups/finish).
- [ ] Edit `skills/roadmap/status-file-template.md` (protocol 3–5, gate line, dependency-graph section, follow-ups wording).
- [ ] `grep -q "Small scope: entry → specify → implement → review → finish" skills/roadmap/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q "Grain split" skills/roadmap/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q "SPECIFY CONSUMED MODE" skills/roadmap/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q "guide-parallel-execution.md" skills/roadmap/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q "^## N=1" skills/roadmap/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q "^## Step 0" skills/roadmap/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q "Dependency graph / waves" skills/roadmap/status-file-template.md && echo OK` — expect `OK`.
- [ ] `head -1 skills/roadmap/SKILL.md` — expect `---`; `name: roadmap` present.
- [ ] Commit: `feat(skills): rewrite roadmap for grain split, waves, and consumed specify`

**Acceptance criteria:**
- [ ] Header uses the canonical two-shape block verbatim and states roadmap nests specify.
- [ ] Step 0 = one confirmation (baseline + dependency graph) + branch creation, then silent; N=1 → standalone specify.
- [ ] Task waves reference implement's guide and state how disjointness is judged without `Files:` lists.
- [ ] Status template protocol matches consumed mode + waves and persists the wave grouping; follow-ups described as staging-then-fold.

---

### Task 3: Implement guide — wave protocol governs both grains

**Parallel:** none — SERIAL.

**Context:**
`skills/implement/guides/guide-parallel-execution.md` frames the wave protocol as intra-plan only and says at line 3 "Load this when the plan declares `**Verdict:** PARALLEL`." Roadmap applies the SAME protocol at task grain with no plan and no `Verdict:` line. This task makes the guide the single source for both grains and fixes the load condition.

**Files:**
- Modify: `skills/implement/guides/guide-parallel-execution.md`
- Modify: `skills/implement/SKILL.md`

**What to implement:**
- In `guide-parallel-execution.md` line 3, amend the load condition: "Load this when the plan declares `**Verdict:** PARALLEL`, **or when the roadmap skill applies this protocol to task waves.**"
- Near the top, add a "Two grains" block: "This protocol governs waves at TWO grains — (a) intra-plan: sub-tasks within one committed plan (specify emits the `**Parallel:**` lines and each task's `Files:` list is the disjointness evidence); (b) inter-task: roadmap tasks within a run (roadmap emits the wave grouping and judges disjointness from each task's declared seam re-verified against the tree, since roadmap tasks carry no `Files:` lists). Both use the identical invariants: children never commit, orchestrator commits by pathspec, scoped in-wave verification, full suite once per wave, ≤4 per wave, BLOCKED sibling holds the wave. Only the *evidence* for gate 1 differs by grain. Roadmap applies this protocol directly and does NOT load the implement skill per task."
- In `skills/implement/SKILL.md` Wave Planning section, add one sentence: "The wave protocol in [guide-parallel-execution.md](guides/guide-parallel-execution.md) is the shared source for both intra-plan waves and roadmap task waves."
- In `guide-parallel-execution.md`, the operative "The check" section (steps "collect each task's `Files:` list … compare pairwise") and integrity rule 1 (keyed on "a line contradicting its `Files:` list") must be reconciled for task grain. Add one sentence to "The check": "**At task grain (roadmap), substitute *declared seam re-verified against the tree* for `Files:` in steps 1–2, and skip the `**Parallel:**`-line integrity test** — roadmap tasks carry no `Files:` lists and no `**Parallel:**` lines."
- Do NOT add a consumed/headless mode to implement; roadmap does not load it.

**Steps:**
- [ ] Edit `guide-parallel-execution.md` (load condition + two-grains block).
- [ ] Edit `skills/implement/SKILL.md` wave section with the cross-pointer sentence.
- [ ] `grep -qi "two grains" skills/implement/guides/guide-parallel-execution.md && echo OK` — expect `OK`.
- [ ] `grep -qi "roadmap" skills/implement/guides/guide-parallel-execution.md && echo OK` — expect `OK`.
- [ ] `grep -qi "both intra-plan waves and roadmap task waves" skills/implement/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -m1 '^name:' skills/implement/SKILL.md` — expect `name: implement`.
- [ ] Commit: `feat(skills): note wave protocol governs intra-plan and roadmap task grains`

**Acceptance criteria:**
- [ ] Guide's load condition covers the roadmap invocation.
- [ ] Guide states both grains share the invariants but the disjointness evidence differs (task grain has no `Files:` lists).
- [ ] Implement SKILL.md points to the guide as the shared source; no consumed/headless mode added.

---

### Task 4: codebase-improvement hands off to roadmap

**Parallel:** none — SERIAL.

**Context:**
`codebase-improvement` offers only "Create implementation plan (specify)" in Phase 6, and its architecture diagram / Definition of Done also say specify/implement. Per approved routing, an audit backlog is inherently multi-task → **roadmap**, no ask (the menu is the routing decision).

**Files:**
- Modify: `skills/codebase-improvement/SKILL.md`

**What to implement (five sites):**
- `:19` Architecture diagram — `└── Phase 6: Pipeline handoff (specify / save / revise)` → `(roadmap / save / revise)`.
- Top pipeline mention (currently "Flows into the standard dev pipeline (discuss → specify → implement) after approval") → `(… discuss → roadmap → specify → implement …) after approval`.
- Phase 6 `ask` — change the primary option to `{ label: "Decompose the approved backlog into a roadmap (load roadmap skill)" }` (keep "Save report for later", "Revise findings"). The roadmap option needs no extra confirmation beyond the menu.
- Phase 6 bullet — `**Create implementation plan** → Clear todo list, load specify skill…` → `**Decompose into roadmap** → Clear todo list, load the roadmap skill and pass the approved backlog (roadmap runs its own Step 0 entry confirmation).`
- `:260` Definition of Done item 3 — "User has chosen a Phase 6 action (implement, save, or revise)" → "(roadmap, save, or revise)".
- `:35` ("Not for: … implementing a known change (use `specify` → `implement`)") → update to `(use specify → implement, or roadmap for multi-task work)`.
- Add one cross-reference sentence noting the deliberate asymmetry: codebase-improvement always routes to roadmap because an audit backlog is inherently multi-task, while discuss routes *small* single-design work straight to specify.

**Steps:**
- [ ] Edit the five sites above.
- [ ] `grep -q "load the roadmap skill" skills/codebase-improvement/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q "Phase 6: Pipeline handoff (roadmap" skills/codebase-improvement/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q "Phase 6 action (roadmap" skills/codebase-improvement/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -m1 '^name:' skills/codebase-improvement/SKILL.md` — expect `name: codebase-improvement`.
- [ ] Commit: `feat(skills): route codebase-improvement handoff to roadmap`

**Acceptance criteria:**
- [ ] Architecture diagram, top mention, Phase 6 option + bullet, and Definition of Done all say roadmap.
- [ ] No extra confirmation layered on the Phase 6 menu.

---

### Task 5: discuss count+scope discriminator

**Parallel:** none — SERIAL.

**Context:**
`discuss` always hands off to `specify` and in three places states that is the *only* path. Per approved routing it keeps specify as default for small scope but routes to roadmap when HUGE (≥3 independent items, or won't fit one PR / spans sessions, or user says "do all / run unattended / across sessions"). Because discuss currently forbids any other path, ALL FOUR sites must change or the skill contradicts itself.

**Files:**
- Modify: `skills/discuss/SKILL.md`

**What to implement (six sites — the Skill's own text forbids asking in three of them, so all must change):**
- `:13` (intro bullet "…handed straight to the `specify` skill, which finalizes it (no 'what next' ask in between)") → "…handed to `specify` (small scope) or `roadmap` (HUGE scope — see After Approval); for small scope there is no 'what next' ask."
- `## Hard Gate` (`:53-55`) — rewrite "The only path forward after approval is the immediate handoff to the `specify` skill…" → "After approval the spec is handed to `specify` — or, when HUGE scope, the user is asked once whether to route to `roadmap`. Neither path flows into implementation on its own."
- `:167` (the "**Hand off to the `specify` skill — do NOT ask what happens next.**" paragraph and its closing "Do NOT ask 'what next': the handoff is the answer.") — rewrite to route through the discriminator: "**Hand off for small scope silently; for HUGE scope ask once (roadmap vs specify).**" Remove the absolute "do NOT ask" wording, since the discriminator's one ask is now the whole point.
- `## After Approval` (intro `:145` + step 2) — before the specify handoff, insert the discriminator: evaluate scope — count of independent design sections/tasks and whether it fits one PR. If `≤2` items AND fits one PR AND no explicit "unattended" intent → hand to specify silently (current behavior, no extra ask). If `≥3` items OR won't fit one PR / spans sessions OR user said "run unattended / do all / across sessions" → single `ask`:
  ```
  ask({ questions: [{ id: "route", question: "This is large enough to split into a tracked multi-task run. Route to roadmap or plan as one shot (specify)?", options: [ { label: "Roadmap — decompose into tasks and run in waves (recommended)" }, { label: "Specify — one plan, one PR" }, { label: "Hold" } ] }] })
  ```
  On Roadmap → clear todo list, load the roadmap skill (roadmap runs its own Step 0 entry confirmation). On Specify → existing handoff. On Hold → stop.
- `:199` (post-review handoff "…hand off to the `specify` skill (no re-ask)") and `:201` (post-revise handoff "…then hand off to the `specify` skill (no re-ask)") — change both to "…hand off per the After Approval discriminator (specify silently, roadmap for HUGE scope)" so a HUGE-scale spec revised/reviewed later still routes correctly.
- `## Principles` (`:207`, "the post-approval handoff: it goes straight to `specify` with no ask") → "the post-approval handoff goes to `specify` for small scope with no ask; HUGE scope gets one roadmap-vs-specify ask."

**Steps:**
- [ ] Edit the six sites in `skills/discuss/SKILL.md`.
- [ ] `grep -q "Roadmap — decompose into tasks" skills/discuss/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -qi "run unattended" skills/discuss/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -qi "or, when HUGE scope" skills/discuss/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q "roadmap for HUGE scope\|HUGE scope gets one" skills/discuss/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -m1 '^name:' skills/discuss/SKILL.md` — expect `name: discuss`.
- [ ] Commit: `feat(skills): add roadmap-vs-specify discriminator to discuss handoff`

**Acceptance criteria:**
- [ ] All six sites are consistent: small → specify silently; HUGE → one ask with roadmap default; no site still claims specify is the only path.
- [ ] Hard Gate / Principles no longer claim specify is the only path.
- [ ] Roadmap selection loads the roadmap skill; specify keeps existing behavior.

---

### Task 6: research multi-track branch + finish cleanup glob

**Parallel:** none — SERIAL.

**Context:**
Research ends in a decision; default is no handoff, but multiple separate implementation tracks should offer roadmap. `finish` deletes a single roadmap doc; it must delete the whole `<feature>-*` family — safely.

**Files:**
- Modify: `skills/research/SKILL.md`
- Modify: `skills/finish/SKILL.md`

**What to implement:**
- **research:** The only place that can ask is `### Phase 4.5: HARD STOP` (`ask({... multi: true})`, `:148-188`). Add an option `{ label: "Roadmap — decompose the tracks and run them" }` to that options array when (and only when) findings imply multiple separate implementation tracks, AND add a matching clause to that `ask`'s `description` field (which currently spells out each option). Add a matching row to the `### Phase 5: Deliver` table (`:190-216`) that, when selected, loads the roadmap skill with the tracks as the approved block. Because Phase 4.5 is `multi: true`, state the resolution: if "Roadmap" is selected together with "Write report to disk", write the report first, then load roadmap. Do NOT change research's default (deliver-only / write report).
- **finish:** Replace the single-file deletion (`:150-158`, currently guarded by `if [ -f "docs/roadmap/${FEATURE_NAME}.md" ]`) with a guarded family glob that cannot widen to `docs/roadmap/*.md` and that derives `FEATURE_NAME` if unset:
  ```bash
  # Derive the feature name if not already set; refuse to run with an empty value.
  FEATURE_NAME="${FEATURE_NAME:-$(git branch --show-current | sed 's|^[^/]*/||')}"
  FEATURE_NAME="${FEATURE_NAME:?set FEATURE_NAME before cleanup}"
  # Fold any ${FEATURE_NAME}-follow-ups.md content into docs/features/ or an ADR FIRST, then:
  for f in docs/roadmap/"${FEATURE_NAME}".md docs/roadmap/"${FEATURE_NAME}"-*.md; do
    [ -e "$f" ] && git rm "$f"
  done
  git commit -m "docs: remove ${FEATURE_NAME} roadmap — shipped (PR #${PR_NUMBER})"
  git push origin main
  ```
  This matches the exact plan doc plus only the dashed family (`-status`, `-taskNN-`, `-follow-ups`), so a sibling like `user-auth-v2.md` is NOT matched. Keep the existing `PR_NUMBER` usage. Add a one-line note: follow-ups content is folded before this runs; the glob removes plan, status, task plans, and follow-ups. (Roadmap committed the task plans, so `git rm` will find them tracked.)

**Steps:**
- [ ] Edit `skills/research/SKILL.md` (Phase 4.5 option + Phase 5 row + multi-select resolution).
- [ ] Edit `skills/finish/SKILL.md` (guarded glob block + fold note).
- [ ] `grep -qi "Roadmap — decompose the tracks" skills/research/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q 'FEATURE_NAME:?set FEATURE_NAME' skills/finish/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -q 'for f in docs/roadmap/"${FEATURE_NAME}"\*.md' skills/finish/SKILL.md && echo OK` — expect `OK`.
- [ ] `grep -m1 '^name:' skills/research/SKILL.md` = `name: research`; `grep -m1 '^name:' skills/finish/SKILL.md` = `name: finish`.
- [ ] Commit: `feat(skills): research roadmap offer + finish globs roadmap family`

**Acceptance criteria:**
- [ ] research offers roadmap only for multi-track findings; default stays deliver-only; multi-select resolution stated.
- [ ] finish uses a `FEATURE_NAME` guard so an empty var cannot `git rm docs/roadmap/*.md`; removes the whole family; keeps commit+push.

---

### Task 7: READMEs reflect roadmap and two-shape pipeline

**Parallel:** none — SERIAL.

**Context:**
Two READMEs describe a flat four-skill chain and omit roadmap. `README.md` (root) and `skills/README.md` both need updating so `done-when` ("all skill files and README") holds.

**Files:**
- Modify: `README.md`
- Modify: `skills/README.md`

**What to implement (both files):**
- **"The Core Pipeline" / "Development Workflow"** — replace the flat chain with the **canonical two-shape block** (verbatim from this plan's header). Keep per-skill descriptions; add a **roadmap** description (coarse decomposition → dependency graph → waves on one branch; autonomous run with a status file as memory; drives specify in consumed mode per task).
- Add an **Entry routing** table (`## Entry routing` heading): codebase-improvement → roadmap (always); discuss → specify (unless HUGE → ask roadmap); research → deliver-only (unless multiple tracks → offer roadmap); any + "run unattended / do all these / keep going across sessions" → roadmap.
- Add roadmap to the skill listing. In `README.md`, CREATE a new `### Pipeline` table (currently discuss/specify/implement/finish are absent from All Skills — this also removes that asymmetry) with rows for discuss, specify, roadmap, implement, finish and their triggers. In `skills/README.md`, add a roadmap row to the existing Development Workflow table.
- `README.md:57` — codebase-improvement prose "Flows naturally into `discuss → specify → implement` after approval." → include roadmap (`… discuss → roadmap → specify → implement …`).
- `README.md:20` — "Beyond the pipeline, **two** skills operate as pluggable gates" → rephrase so research/codebase-improvement are described as pipeline entry points (not undercounted as "two gates"). Adjust the sentence to match the new routing table.
- `skills/README.md:84` — "Chaining — Skills naturally flow into each other (e.g. `discuss` → `specify` → `implement` → `finish`)" → use the canonical block. Also add an `## Entry routing` section to `skills/README.md` mirroring the root one.

**Steps:**
- [ ] Edit `README.md` (pipeline both shapes; roadmap description; `## Entry routing` table; new `### Pipeline` skills table; `:57` prose; `:20` sentence).
- [ ] Edit `skills/README.md` (Workflow table both shapes + roadmap row; `:84` chaining line; add `## Entry routing`).
- [ ] `grep -q "Large scope: entry → roadmap → ( specify → implement per task, in waves ) → review → finish" README.md && echo OK` — expect `OK`.
- [ ] `grep -q "Large scope: entry → roadmap" skills/README.md && echo OK` — expect `OK`.
- [ ] `grep -q "^## Entry routing" README.md && echo OK` — expect `OK`.
- [ ] `grep -q "^## Entry routing" skills/README.md && echo OK` — expect `OK`.
- [ ] `grep -q "### Pipeline" README.md && echo OK` — expect `OK`.
- [ ] Commit: `feat(skills): add roadmap and two-shape pipeline to both READMEs`

**Acceptance criteria:**
- [ ] Both READMEs show the canonical two-shape block and an `## Entry routing` section.
- [ ] Root README has a Pipeline skills table incl. roadmap; skills/README has a roadmap row.
- [ ] `:57` and `:20` prose in root README match the new pipeline; `skills/README.md:84` uses the canonical block and `skills/README.md` has `## Entry routing`.
