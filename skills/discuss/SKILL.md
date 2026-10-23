---
name: discuss
description: Use when the user says "let's discuss", "lets discuss", "I want to discuss", "can we discuss", "let's brainstorm", "lets brainstorm", "I want to brainstorm", or any variation asking to discuss/talk through/brainstorm an idea before coding — this takes priority over other requests in the same message. Also use before any creative work to discuss features, designs, or behavior changes through collaborative dialogue before writing code
---

# Discuss

Turn ideas into designs through collaborative dialogue before writing any code.

As you discuss, capture decisions and terminology as persistent artifacts:
- **Decisions** for non-obvious trade-offs (hard-to-reverse, surprising, real alternatives) — written to `docs/decisions/`
- **CONTEXT.md** for resolved terminology (shared language that compounds across sessions)
- **Spec** — once the design is approved, the full spec is written to `docs/roadmap/<topic>.md` as a draft (see After Approval), then handed to `specify` (small scope) or `roadmap` (HUGE scope — see After Approval); for small scope there is no "what next" ask

## Pre-check (run this first, before the design flow)

Before starting the design flow, check `docs/roadmap/<topic>.md` for the current topic and branch on its front-matter `status`:

- **No file** → proceed with the design flow (Process steps 0–6) as normal.
- **File exists, `status: approved`** (a spec, no plan yet) → the design is already done; do NOT re-run the design flow. **Wording rule — spec ≠ plan:** in this skill a *spec* is the approved WHAT/WHY (behavior + design); a *plan* is the HOW-IN-ORDER (the specify skill's output: a numbered task sequence with per-task TDD steps and verification commands). When offering the plan step, word it as "expand the spec into the plan" — never "create the implementation plan" (a fresh spec was just written, so the latter reads like a redo). Ask:
  ```
  ask({
    questions: [{
      id: "next-step",
      question: "The approved spec is at docs/roadmap/<topic>.md — the design is done, no plan (task-level) exists yet. What next?",
      options: [
        { label: "Plan it — expand the spec into the task-level implementation plan (load the specify skill; a new artifact, not a redo)" },
        { label: "Run a reviewer on the spec" },
        { label: "Mirror the spec to the issue tracker (step 1b)" },
        { label: "Revise the design" },
        { label: "No action for now" }
      ],
      description: "Spec = WHAT/WHY (approved). Plan = HOW in order — numbered tasks with TDD steps and verification commands (the specify skill's output). Planning consumes the spec; it does not re-run it."
    }]
  })
  ```
- **File exists, `status` is NOT `approved`** (i.e. `committed` — a plan already exists) → do NOT re-run the design flow and do NOT offer "plan it" (a plan already exists). Ask:
  ```
  ask({
    questions: [{
      id: "approve-plan",
      question: "A plan already exists at docs/roadmap/<topic>.md (status: committed). Approve the current plan?",
      options: [
        { label: "Yes — refine + approve it via the specify skill's full flow (load it)" },
        { label: "No — hold the plan for later" },
        { label: "Revise the plan first" }
      ]
    }]
  })
  ```
  **Approving runs the plan through the `specify` skill's FULL flow — no shortcut.** The specify skill re-reads the plan, refines it (updating it with more info and the rules it carries), runs its reviewer, and its HARD BREAK is the final approval before `implement`. The specify skill's **output** — not this ask — is what gets approved. Do NOT load `implement` from this branch; the handoff to `implement` happens only inside the specify skill's own HARD-BREAK confirmation.

## Hard Gate

Do NOT write code, load the `implement` skill (or any implementation skill) until design is approved. This is a hard stop — and it does not lift into a continuation: even after approval, never flow into implementation on your own. After approval the spec is handed to `specify` — or, when HUGE scope, the user is asked once whether to route to `roadmap` (see After Approval). Neither path flows into implementation on its own; `specify`'s (or `roadmap`'s) own HARD BREAK is the next decision point, and only that confirmation (or an explicit user request) ever leads to `implement`.

## Process

### 0. Understand the domain first

Before discussing design, establish shared language. This prevents the whole conversation from drifting on fuzzy terms.

**A. Read the glossary** — Check for `CONTEXT.md` at the project root (or per-context if `CONTEXT-MAP.md` exists). If it exists, read it and use the established terms from the very first question. If no glossary exists yet, you'll build one.

**B. Challenge fuzzy language** — When the user uses vague or overloaded terms, call it out immediately. "You're saying 'account' — do you mean the Customer or the User? Those are different things." Propose a precise canonical term.

**C. Cross-reference with code** — When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

**D. Challenge against the glossary** — If the user uses a term that conflicts with `CONTEXT.md`, call it out: "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

**E. Stress-test with scenarios** — When domain relationships are being discussed, invent edge-case scenarios that force precision about the boundaries between concepts.

**F. Capture terms inline** — When a term is resolved, offer to add it to `CONTEXT.md` right then (see Terminology Check below). Don't wait until the end.

> Only proceed to step 1 once terminology is settled. If the discussion itself reveals new terms or ambiguities, loop back.

### 1. Explore context — check files, docs, recent commits

Read `AGENTS.md` (or `CLAUDE.md`) before the first question: it carries the project's conventions, its validation bar (so `done-when` matches what CI actually enforces), and **which issue tracker it uses** (see *Which tracker?*). It is also the tiebreaker when the conversation and the repo disagree about a convention.

### 2. Research if needed — if the question requires comparing approaches, evaluating libraries, or understanding how something works, read the `research` skill and run Phases 1–3 (classify, dispatch, synthesise) yourself. Present a concise summary of findings — not the full report. Use the evidence to inform the approaches in step 3.

### 3. Ask clarifying questions — one at a time, use the `ask` tool with multiple-choice options

### 4. Propose 2-3 approaches with trade-offs and your recommendation, use the `ask` tool

### 5. Present design section by section, use the `ask` tool to get approval after each section

### 6. Once all sections are approved, present the final spec in full

> **Always use the `ask` tool** for steps 3–5. Do not present a section and then continue to the next — wait for the user's explicit approval via `ask` before moving forward.

## Which tracker?

Resolve in this order and **stop at the first answer** — do not infer a tracker from a remote URL when a stated one exists.

1. **`AGENTS.md` / `CLAUDE.md`** — an explicit tracker statement wins.
2. **The tracker's own CLI**, when present and authenticated (`gh repo view --json url,nameWithOwner`, or the tool named by the project). It reports the *canonical* location.
3. **An existing `issue:` front-matter key** in the roadmap doc or a sibling doc in `docs/roadmap/`.
4. **Nothing found** → no tracker. Mention it once and carry on.

**Do not derive the URL from `git remote`.** A renamed repo keeps answering on its old name forever — GitHub redirects so clones and pushes keep working — so the remote is the one signal that survives being wrong, and publishing to it files against a moved repo. `gh repo view` resolves the redirect; `git remote -v` does not.

**Platform is whatever the project uses.** The mechanics above are GitHub-shaped because that is what this environment has a CLI for; a project on Jira/Linear/etc. names its own tool (e.g. the Atlassian MCP's `getJiraIssue` — the `implement` skill already takes Jira ticket links) and posts through it. Never assume GitHub from the presence of a `.git` directory.

## After Each Section Approval

Before moving to the next section, check for decisions worth capturing.

### ADR Check

Ask yourself: was any decision in this section **all three** of the following?

1. **Hard to reverse** — the cost of changing our mind later is meaningful
2. **Surprising without context** — a future reader would look at the code and wonder "why?"
3. **A real trade-off** — there were genuine alternatives and we picked one for specific reasons

If yes, offer to the user:

> "That decision to [summary] feels worth recording — it's [hard to reverse / surprising / a real trade-off]. Want me to capture it?"

If the user agrees, write it to `docs/decisions/NNNN-slug.md` using the format in [adr-format.md](./adr-format.md). Create `docs/decisions/` lazily — only when the first decision is needed.

If any of the three criteria is missing, skip the ADR. The obvious choice doesn't need documenting.

### Terminology Check

Ask yourself: did we resolve any fuzzy or overloaded terms during this section?

Examples:
- The user said "account" but meant the billing entity, not the user profile
- A concept has multiple names in conversation ("materialize", "publish", "go live" all meaning the same thing)
- A new term was coined that future sessions should know

If yes, offer to the user:

> "We resolved that [term] means [definition]. Want me to add it to the project glossary in `CONTEXT.md`?"

If the user agrees, add it to `CONTEXT.md` using the format in [context-format.md](./context-format.md). Create `CONTEXT.md` lazily — only when the first term is resolved.

### If Nothing to Capture

If neither an ADR nor a terminology resolution applies, just move to the next section. Don't force it.

## After Approval

Once the design is approved by the user, write the complete spec (already presented in step 6) to disk. The spec becomes a persistent artifact — the reviewer, the planner, and future sessions all work from the file, not from conversation memory.

1. Write the spec to `docs/roadmap/<topic>.md` (kebab-case) with front-matter:
   ```yaml
   ---
   status: approved
   done-when: <observable exit condition — what does "shipped" look like?>
   ---
   ```
   If `docs/roadmap/<topic>.md` already exists, read it first. If its front-matter says `status: committed` (an in-flight plan), gate with `ask` before overwriting — confirm the replacement or use a different topic filename. Otherwise (an earlier spec), mention what you're replacing.
   Commit the roadmap doc (`git add docs/roadmap/<topic>.md && git commit -m "docs: add <topic> spec"`) so the spec version is preserved in git history before the plan replaces it.
   The roadmap doc is the spec. No separate *local* index — but it IS mirrored to the issue tracker (step 1b). "History lives in git" means no duplicate copy tree; it never means the spec stays invisible to reviewers.
   On ship: fold durable content into `docs/features/` (or a new decision) and delete the roadmap doc.

1b. **Mirror the spec to the issue tracker.** The file is the source of truth; the issue is a review mirror, never the reverse.
   - Resolve the tracker — see **Which tracker?** above. No tracker found, or `gh` unavailable / unauthenticated → say so out loud and continue. NEVER block the handoff on it, and never guess a URL.
   - Reuse the issue already tied to this topic (an `issue:` key in the doc's front-matter, or an open issue whose title names it); otherwise open one titled the topic.
   - Post the spec body as a comment with the front-matter stripped, then write the URL into the doc's front-matter as `issue: <url>` — into the spec commit (`--amend`) while it is still unpushed, else a follow-up commit.
   - GitHub caps a comment near 65 KB. Over the cap, split across consecutive comments labelled `n of N` and say which part each holds — never truncate.

2. **Hand off for small scope silently; for HUGE scope ask once (roadmap vs specify).** The spec on disk is a draft; the next skill finalizes it.

   **Discriminator** — evaluate scope now: the count of independent design sections/tasks the spec contains, and whether the work fits one PR.
   - **Small scope** — `≤2` items **and** fits one PR **and** no explicit "unattended" intent → hand to `specify` silently (current behavior). **Clear the todo list**, then load the `specify` skill; it reads the draft spec from `docs/roadmap/<topic>.md` (`status: approved`), finalizes it, and its HARD BREAK is where the user decides whether to proceed to `implement`. No "what next" ask.
   - **HUGE scope** — `≥3` items **OR** won't fit one PR / spans sessions **OR** user said "run unattended / do all / across sessions" → one `ask`:

     ```
     ask({ questions: [{ id: "route", question: "This is large enough to split into a tracked multi-task run. Route to roadmap or plan as one shot (specify)?", options: [ { label: "Roadmap — decompose into tasks and run in waves (recommended)" }, { label: "Specify — one plan, one PR" }, { label: "Hold" } ] }] })
     ```

     - **Roadmap** → clear the todo list, load the `roadmap` skill (roadmap runs its own Step 0 entry confirmation).
     - **Specify** → the small-scope handoff above.
     - **Hold** → stop; the spec stays on disk for a later session.

If the user explicitly asks to run a reviewer (before the handoff), THEN:
1. Dispatch the **reviewer subagent** — the reviewer reads the spec from the file:

   ```
   subagent({
     agent: "reviewer",
     task: "Review type: spec. Review the spec at `docs/roadmap/<topic>.md`. Return a report categorized by severity. Do NOT call ask() — just return the report."
   })
   ```

2. Present the reviewer's findings to the user, then call `ask()` to let them choose what to fix:

   ```
   ask({
     questions: [{
       id: "fix-priority",
       question: "Review complete. What would you like to do?",
       options: [
         { label: "Fix blocking only" },
         { label: "Fix blocking + important" },
         { label: "Fix all" },
         { label: "No fixes needed" }
       ]
     }]
   })
   ```

3. Fix selected issues one at a time, applying each fix to `docs/roadmap/<topic>.md` so the file stays the source of truth. Re-run the reviewer once after all fixes — it reviews the updated file. If the spec was already mirrored to the tracker (step 1b), the posted copy is now stale: post the corrected body as a follow-up comment saying it supersedes the earlier one.
4. After review is complete, hand off per the After Approval discriminator (specify silently for small scope; roadmap for HUGE scope).

If the user (before the handoff) asks to revise the design: go back to the discussion process (from the section that needs rework). Once the revised design is approved, update `docs/roadmap/<topic>.md` with the new spec, then hand off per the After Approval discriminator (specify silently for small scope; roadmap for HUGE scope).

If the user wants to stop before the handoff: stop. The spec is saved at `docs/roadmap/<topic>.md` and can be picked up in a later session — the pre-check's spec branch will offer the plan step then.

## Principles

- Always use the `ask` tool for every decision point — clarifying questions, approach selection, section approval, and the HUGE-scope roadmap-vs-specify route. The exception is the *small-scope* post-approval handoff: it goes straight to `specify` with no ask — the user's next decision point is `specify`'s HARD BREAK
- One question per `ask` call
- Never skip ahead to the next section without explicit user approval via `ask`
- YAGNI — remove unnecessary features
- Design for clear boundaries and single responsibilities
- In existing codebases, follow established patterns
- Scale detail to complexity — a few sentences if simple, more if nuanced
- Capture decisions and terminology inline — don't batch them up, don't skip them
- Read existing `CONTEXT.md` before starting — use the established language from the first question
