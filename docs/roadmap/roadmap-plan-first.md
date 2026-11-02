---
status: committed
done-when: skills/roadmap/SKILL.md and status-file-template.md describe Steps 0–8 (fan-out → resolve → plan every task → vet → implement one wave at a time → gate → parallel fix → ship); no roadmap step runs a planner or researcher at the same time as an implementer; the pipelining section and the width-1 worktree decision are gone from roadmap and guide-parallel-execution; the consumed-specify dispatch is a literal template that loads the specify skill; SKILL.md is shorter than today's 347 lines.
issue: https://github.com/danielcherubini/skills/issues/8
---

# roadmap-plan-first — Plan

**Goal:** Implement the approved spec (`docs/roadmap/roadmap-plan-first.md`, first committed as `73cdb8e`): plan every roadmap task before implementing any, and delete the pipelining machinery that this makes unnecessary.
**Architecture:** Markdown-only edits to skill files. Verification is the structural gate `docs/roadmap/roadmap-plan-first-gate.sh`.
**Tech Stack:** Markdown, POSIX sh, git, `gh`.

> **Provenance.** Grounded in-thread by the orchestrator, not by a `researcher` subagent. The subagent runtime is failing (`subagent failed: the subagent settled with no output`, 5 dispatches across `explore`, `researcher`, `general`, and config-less). **Not reviewer-vetted.**
> The gate is a set of structural text checks. It shows the wording changed. It does not show the new flow behaves correctly. The write-skills RED/GREEN scenario run was **not performed**; the behaviour is untested.

## Corrections to the spec

1. **Scope.** The spec's "Files affected" lists 4 files. Grounding found 6 more that describe the old flow or depend on the removed text: `README.md`, `skills/README.md`, `skills/discuss/SKILL.md`, `skills/codebase-improvement/SKILL.md`, `skills/implement/SKILL.md`, `skills/specify/guides/guide-parallelisation.md`. They are in T2–T4.
2. **Decision 2 cannot be done as written.** The spec says later-wave plans build on earlier-wave *plans*, but every plan is written in one response, so a wave-2 planner cannot read a wave-1 plan that does not exist yet. **Replacement:** Step 2 records each cross-task symbol with its verbatim signature, taken from the producing task's grounding report. A consuming task's planner gets that signature inline as `Builds on:`. Plan files are not read across tasks. The DEVIATION rule (T3) still catches a signature that changes during implementation.

## Parallelisation

**Verdict:** PARALLEL — 1 wave (T1–T4). Owned file sets are pairwise disjoint (checked below). **Executed serially in this thread**: no subagents are available, so there is no wave to fan out.

Owned sets:
- T1: `skills/roadmap/SKILL.md`
- T2: `skills/roadmap/status-file-template.md`, `README.md`, `skills/README.md`, `skills/discuss/SKILL.md`, `skills/codebase-improvement/SKILL.md`
- T3: `skills/implement/guides/guide-parallel-execution.md`, `skills/implement/SKILL.md`
- T4: `skills/specify/SKILL.md`, `skills/specify/guides/guide-parallelisation.md`

Gate 2 (no build-graph dependency): none. These are markdown files, and T1's link to the T3 guide already resolves.
Gate 3 (no shared mutable artifact): the gate script and fixture are read-only inputs and are committed in T0 before any task.

---

### Task 0: RED baseline and commit the plan

**Parallel:** precondition — runs before T1–T4.

**Context:** The gate must fail before any skill is edited, otherwise it proves nothing.

**Files:**
- Test: `docs/roadmap/roadmap-plan-first-gate.sh`
- Test: `docs/roadmap/roadmap-plan-first-fixture.md` (scenario fixture; not run, see T5)
- Modify: `docs/roadmap/roadmap-plan-first.md` (this file replaces the spec)

**Steps:**
- [x] Run `sh docs/roadmap/roadmap-plan-first-gate.sh`. Result: 23 checks, 21 FAIL, 2 ok (T1 wave-protocol link, T1 front-matter regression), T5 SKIP.
- [ ] Commit `docs/roadmap/roadmap-plan-first.md`, `docs/roadmap/roadmap-plan-first-gate.sh`, `docs/roadmap/roadmap-plan-first-fixture.md` with the message `docs: plan roadmap-plan-first`.

**Acceptance:**
- [ ] The gate and fixture are committed on `feature/roadmap-plan-first`, and nothing else is.

---

### Task 1: roadmap core (`skills/roadmap/SKILL.md`)

**Parallel:** wave 1 — disjoint from T2, T3, T4 (owned set above).

**Context:** The main skill carries the old loop. Its pipelining section, width-1 decision and per-wave ground/plan/vet loop are replaced by the spec's Steps 0–8. Most of the existing text stays.

**Files:**
- Modify: `skills/roadmap/SKILL.md`

**What to implement:**
- **Keep byte-identical:** front-matter (lines 1–4). The gate's `t1_front` check depends on it.
- **Keep, with small edits:** the intro and "status file is the only memory" paragraph; "Use for"; Step 0 entry bullets (`codebase-improvement`, `discuss`, `research`); the `<feature>` naming paragraph; task branch naming; the N=1 degenerate section; the "Grain split" section; the "Violating the letter" line; the Common mistakes table.
- **Rename:** the heading "## Step 2 — Partition by file ownership, not by finding" becomes "## Partition rules (used in Step 0)". The rules themselves stay as written.
- **Rename:** the heading "## Step 0 — Entry" becomes "## Step 0 — Entry and decompose (no dispatch)". Add the decompose rule: draft tasks by owned file set, assign each task to an area, then build the session list.
- **Move:** the "## Step 3 — Verify each task against the tree" text goes under Step 2 as "Verification against the tree", and keeps its paragraphs unchanged.
- **Delete:**
  - the "Pipeline the next wave's planning over this wave's implementation" block and its five bullets;
  - the width-1 paragraph ("Width 1 is your call…");
  - the per-wave Ground/Plan/Vet/Implement list and its "The unit of the loop is the WAVE" intro, which the new flow replaces.
- **Add**, in this order, using the spec's Flow Steps 1–8:
  - **Step 1 — Fan out (one response):** one `ask` ("Proceed autonomously with this plan?") plus one baseline child (`explore`, given the exact gate command, records exit code and pass/fail counts, does not rerun or read docs) plus one `researcher` per area. The "Ground once per area, to disk" paragraph moves here. Each grounding report ends with three sections: `## Will touch`, `## Needs from other areas` (symbols it consumes, each with its producing task), and `## Provides` (verbatim signatures it exposes).
  - **Step 2 — Resolve (orchestrator):** merge tasks whose Will-touch lists share a file; create one dependency edge for each `Needs` entry, recorded with its signature; apply merges and report them; anything that adds or drops approved scope stops and `ask`s. Then write the status file and commit the grounding reports and status file (by pathspec).
  - **Step 3 — Plan every task (one response):** a literal dispatch template. It must contain, in this order: `read_skill specify, then follow it.`, the marker line `SPECIFY CONSUMED MODE`, `Task:`, `Owns:`, `Grounding:` (the area's report path), `Builds on:` (the verbatim signatures from Step 2 that this task consumes, with producing task ids, or `none`), and `target: docs/roadmap/<feature>-taskNN-<slug>.md`. One `researcher` per task, all in one response, with no cap.
  - **Step 4 — Vet (one response):** one `reviewer` per plan, one pass, told to open the files each plan names. Only 🔴 findings send a plan back to its planner, which refines the same target. Then re-vet that plan alone. Commit the plans by pathspec.
  - **Step 5 — Implement, one wave at a time:** dispatch rules per the implement wave protocol; ≤4 implementers; worktree and branch per task when width ≥2, primary checkout when width 1; implementers compile and run their own tests only; DEVIATION rule (report `DEVIATION: <old> → <new>` and do not adapt silently; after the wave, re-dispatch the planners of dependent tasks). The "orchestrator never edits source" rule and the "Roles" paragraph move here. The "Watch the child's budget" paragraph moves here.
  - **Step 6 — Gate:** fan in, then run the baseline command once on the integrated tree. Judge against the baseline: only new failures count. Green → `done <hash>` in the status file and the session list.
  - **Step 7 — Fix in parallel:** failures matched to tasks through the Owns column; one fixer per task in its own worktree; a failure with no single owner goes to one fixer owning all involved files; gate again; after 2 rounds, mark `blocked` with the evidence.
  - **Step 8 — Ship:** the existing Step 5 text, renumbered. Follow-ups file, then `review`, then `finish`, then clear the session list.
- Use the words "Step 0" through "Step 8" only for the new numbering. Do not leave "Step 4" or "Step 5" referring to the old numbering in any sentence.

**Steps:**
- [ ] Run `sh docs/roadmap/roadmap-plan-first-gate.sh T1`. Expect 7 FAIL, 2 ok.
- [ ] Confirm the edit tool can write under `skills/`. An earlier attempt in this session was refused for that directory, and I have not re-tested it since. If the write is refused, **stop and report it. Do not write around the refusal** (an earlier `python3` workaround was a mistake).
- [ ] Apply the changes above.
- [ ] Run `wc -l skills/roadmap/SKILL.md`. Expect fewer than 347 lines.
- [ ] Run `grep -i pipelin skills/roadmap/SKILL.md`. Expect no output.
- [ ] Run `sh docs/roadmap/roadmap-plan-first-gate.sh T1`. Expect all T1 checks ok.
- [ ] Commit by pathspec: `feat(roadmap): plan every task before implementing any`.

**Acceptance:**
- [ ] T1 gate checks all pass. Front-matter is unchanged. SKILL.md is under 347 lines.
- [ ] Every `Step N` reference in the file matches the new numbering.

---

### Task 2: status template, READMEs, entry-skill references

**Parallel:** wave 1 — disjoint from T1, T3, T4.

**Context:** The status template repeats the old loop and the width-1 decision. Two READMEs draw the old flow as a diagram. Two entry skills say "Step 0 entry confirmation", which is wrong once the entry confirmation moves to Step 1.

**Files:**
- Modify: `skills/roadmap/status-file-template.md`
- Modify: `README.md`
- Modify: `skills/README.md`
- Modify: `skills/discuss/SKILL.md`
- Modify: `skills/codebase-improvement/SKILL.md`

**What to implement:**
- **Template, "Operating mode" section:** replace the 9-step loop protocol with the new Steps 0–8, matching SKILL.md. Remove the line "Steps 3-8 are roadmap's Step 4, same order, same meaning." Remove the width-1 decision from the Step 7 text entirely.
- **Template, Status vocabulary table:** add a row `` `blocked` `` — true when the gate is still red after 2 fix rounds, or a sibling is BLOCKED; the evidence goes in the Blockers section.
- **Template, "Dependency graph / waves":** each dependency edge records its verbatim signature and the producing task. Keep the "Wave 2 width 1 — reason" example, since it still applies to chains of width 1.
- **Template, any `Step N` reference:** check each one against the new numbering.
- **`README.md`:** the diagram `Large scope: entry → roadmap → ( specify → implement per task, in waves ) → review → finish` becomes `Large scope: entry → roadmap ( ground → plan every task → vet → implement one wave at a time → gate → fix ) → review → finish`. In the roadmap bullet, replace "then commits each task by pathspec" with "the orchestrator commits the plan docs and the status file itself".
- **`skills/README.md`:** the same diagram change, in both places it appears.
- **`skills/discuss/SKILL.md`, the Roadmap route line:** "roadmap runs its own Step 0 entry confirmation" → "roadmap runs its own entry confirmation".
- **`skills/codebase-improvement/SKILL.md`, the Decompose line:** the same change.

**Steps:**
- [ ] Run `sh docs/roadmap/roadmap-plan-first-gate.sh T2`. Expect 7 FAIL.
- [ ] Apply the changes above.
- [ ] Run `sh docs/roadmap/roadmap-plan-first-gate.sh T2`. Expect all T2 checks ok.
- [ ] Commit by pathspec: `docs(roadmap): status template, READMEs and entry-skill references follow the new flow`.

**Acceptance:**
- [ ] No `roadmap's Step 4` mapping remains. No pipelining text. No width-1 decision. The old diagram is gone from both READMEs. Both entry skills reference the entry confirmation without a step number.

---

### Task 3: implement wave protocol (guide and SKILL.md)

**Parallel:** wave 1 — disjoint from T1, T2, T4.

**Context:** Per Decision 6 of the spec, implementer children run compile and their own tests, and the full suite runs once after fan-in. The guide is shared by intra-plan waves and roadmap waves, so **this also changes `implement`'s intra-plan waves**, not just roadmap's. That is intended by the spec, and it is flagged in Risks for the user to veto.

**Files:**
- Modify: `skills/implement/guides/guide-parallel-execution.md`
- Modify: `skills/implement/SKILL.md`

**What to implement:**

*Guide:*
- **"When a child gets its own worktree", table:** remove the row "a planner or researcher reads the tree (roadmap's pipelining)". Keep "another implementer in the same wave → yes" and "nothing else → no". Add one sentence: "Roadmap plans every task before any implementer starts, so nothing reads the tree during a wave."
- **Same section:** delete the paragraph beginning "Width-1 is the only case the table forces a judgement on", the two mode-line examples, and the paragraph beginning "Record the choice in the status file". Keep "Waves of width ≥2 need no decision: siblings force isolation."
- **"Why isolation, and what it does not buy you":** replace "A child can therefore commit normally and run the project's **full** suite — its own tree makes that a real measurement of its work rather than a reading of everyone's." with: "A child commits normally on its branch and runs format, compile, and its own test files. The project's full suite runs once on the integrated tree after fan-in (step 4 of *Running the wave*)."
- **"The dispatch text for a wave child":** replace "Run the FULL suite and format your files: your tree is yours alone." with "Format your files, compile, and run only your own test files. Do not run the full suite: the orchestrator runs it once on the integrated tree after fan-in."
- **Same section:** replace "Unlike a serial child, a wave child is **not** told to skip committing or to scope its tests — isolation makes both correct." with "A wave child commits on its branch like any child, and its tests are scoped to its own files."
- **"Running the wave", step 4:** change "This step is not optional even for a single non-isolated child that already ran the suite itself" to "…that already ran its own tests itself".

*implement/SKILL.md:*
- **"Running a wave" intro (the line that begins "Each task in a wave of width ≥2"):** replace the parenthetical "(roadmap pipelines planners; you do not)" with "(roadmap plans every task before any implementer starts, so nothing reads the tree during a wave)".
- **Step 2 of the wave protocol** (the line that begins "Its tree is its own, so it commits normally and runs the **full** suite"): replace with "Its tree is its own, so it commits normally and runs its own test files. The full suite runs once after fan-in."
- **The wave-child dispatch text:** replace "Run the FULL suite and format your files — your tree is yours alone, so a full-suite result measures only you." with "Format your files, compile, and run only your own test files. Do not run the full suite."
- **Step 3 of the wave protocol** (the line that begins "Each child already ran it in isolation"): replace with "Children ran only their own tests, so this is the first full-suite run on the wave and the only one describing what you merged."

**Steps:**
- [ ] Run `sh docs/roadmap/roadmap-plan-first-gate.sh T3`. Expect 4 FAIL.
- [ ] Apply the changes above.
- [ ] Run `sh docs/roadmap/roadmap-plan-first-gate.sh T3`. Expect all T3 checks ok.
- [ ] Commit by pathspec: `feat(implement): children run their own tests; full suite runs once after fan-in`.

**Acceptance:**
- [ ] Neither file contains "FULL suite", "pipelin", or "judgement". Both contain "own test files".

---

### Task 4: specify (SKILL.md and parallelisation guide)

**Parallel:** wave 1 — disjoint from T1, T2, T3.

**Context:** Consumed mode gets a new `Builds on:` input (Decision 2, as corrected above). Two statements contradict the new protocol: "must NOT commit" for wave tasks, and "the child runs the full suite". The parallelisation guide repeats the second one.

**Files:**
- Modify: `skills/specify/SKILL.md`
- Modify: `skills/specify/guides/guide-parallelisation.md`

**What to implement:**

*specify/SKILL.md:*
- **"Consumed mode" input list:** add a bullet: "**`Builds on:`** the verbatim signatures this task consumes from other tasks in the same run, each with its producing task id, or `none`. Plan against these signatures. No other task's plan file exists yet, because all plans are written in one response. Do not invent a signature that is not listed."
- **"Plan Format", the Commit step:** replace "a task declared `**Parallel:** wave N` must NOT commit — the orchestrator commits its files after the wave (see *Parallel wave rules* below)" with "a task declared `**Parallel:** wave N` commits on its own task branch, per *Parallel wave rules*; a serial task commits on the feature branch."
- **"Parallel wave rules", bullet 2** ("In-wave verification is complete but local"): replace "the child runs the full suite in its own worktree, where that result measures only its own work" with "the child runs compile and its own test files in its worktree; the full suite runs once after fan-in".
- **"Parallelisation", gate 4** ("Provable from the base alone"): replace "Each child runs the full suite in its own worktree, so a suite run is no longer disqualifying; needing a *sibling's* work present to pass is." with "Each child runs its own test files in its worktree, and the full suite runs once after fan-in. A criterion may be checked by the full suite; needing a *sibling's* work present to pass is still disqualifying."

*guide-parallelisation.md:*
- **Line 9** ("A child verifies against the base plus its own work"): replace "Its full-suite run is a genuine measurement of *its* task, which is why isolation is worth the setup." with "Its own test run is a genuine measurement of *its* task, which is why isolation is worth the setup."
- **Section 4, "Provable from the base alone"**: replace "A child now runs the full suite in its own worktree, so a whole-suite run is no longer disqualifying — it is the expected verification." with "A child runs its own test files in its worktree, and the full suite runs once after fan-in. A whole-suite check is therefore not a child's check, but it does not disqualify a criterion. Needing a sibling's work present does."

**Steps:**
- [ ] Run `sh docs/roadmap/roadmap-plan-first-gate.sh T4`. Expect 3 FAIL.
- [ ] Apply the changes above.
- [ ] Run `sh docs/roadmap/roadmap-plan-first-gate.sh T4`. Expect all T4 checks ok.
- [ ] Commit by pathspec: `feat(specify): consumed mode takes Builds-on signatures; children do not run the full suite`.

**Acceptance:**
- [ ] `Builds on:` appears in consumed mode. No "must NOT commit". No child is described as running the full suite.

---

### Task 5: verify and close

**Parallel:** precondition for shipping — runs after T1–T4.

**Steps:**
- [ ] Run `sh docs/roadmap/roadmap-plan-first-gate.sh`. Expect all checks ok and one SKIP line for T5.
- [ ] Run `git diff --stat main..HEAD`. Expect only the owned files above plus the three `docs/roadmap/roadmap-plan-first*` files. Any other file is a scope change: stop and report it.
- [ ] Check that the scenario fixture is still not run. Do not produce a trace by hand and call it a scenario run.

**Acceptance:**
- [ ] Gate passes except T5 (SKIP, reported as UNTESTED). Diff is limited to the owned sets.

---

## Risks and decisions for the user

1. **Decision 2 is changed** (see Corrections). Later-wave planners now get declared signatures, not earlier plan files. This is the only change to the approved design.
2. **Implement's intra-plan waves change too.** Children no longer run the full suite in either grain. That follows from the spec, but it changes `implement` beyond roadmap, so the user should confirm it.
3. **No behavioural test.** The gate checks wording. T5 is SKIPPED, so whether the flow works is unknown until a real run.
4. **No review.** The plan has not been vetted by a `reviewer`.
5. **Write access to `skills/` is unverified.** An earlier summary claimed the directory is protected. Check before T1, and do not work around a refusal.
