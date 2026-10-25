---
name: check-issue
description: Use when checking the status of a GitHub or Jira issue or ticket — triaging or labeling a backlog, finding stale or already-fixed issues, or asked to "check issue", "check issues", "issue status", "what's open", "label these issues", "#1234", or a pasted issue URL.
---

# Check Issue

Report on the **state** of issues. The main agent is a strict orchestrator; every `researcher` subagent investigates one issue and returns a triage report.

> 🚨 **CORE RULE: Triage, not repair.** This skill answers *"what is the state of this issue?"* — never *"how do we fix it?"* Root-causing, code archaeology, and implementation planning belong to `specify` / `implement` / `roadmap`.

## ⚠️ STRICT RULE: ZERO BASH IN THE MAIN AGENT, NO WRITES WITHOUT AN ASK

> - The main agent MUST NOT run `gh`, `git`, `sleep`, or any shell command. No `bash`, no `read` of source files.
> - All querying happens inside `researcher` subagents (dispatched **concurrently**, one per issue).
> - **Investigation is read-only end to end.** No subagent edits, creates, stashes, checks out, or reverts a file, and no running test suites or builds. No `gh issue comment`, `lock`, or `assign` in any path. A probe edit that "gets reverted" is still a violation.
> - **Two sanctioned writes, both gated on an explicit user choice:** labels (Phase 3) and closing confirmed stale/already-fixed issues (Phase 2). Nothing else — not commenting, not assigning, not retitling, not editing a body.
> - The main agent's only jobs: (1) resolve scope, (2) dispatch, (3) merge reports, (4) `ask`, (5) report.

```
Main Agent (orchestrator - no bash; writes only labels, only when asked)
  ├── 0. Scope: parse args → resolve repo → (blank?) count + ask
  ├── 1. Dispatch N [researcher: Issue Trier] concurrently ── one issue each
  ├── 2. Merge into one triage table → ask what next
  └── 3. Label (ask → gh label list → propose → ask → [general] apply)
         or hand off to implement / roadmap / specify
```

## Parsing the Input

| Input | Meaning |
|---|---|
| `#1234`, `1234` | Issue 1234 in the resolved repo |
| `https://github.com/<owner>/<repo>/issues/<n>` | That issue; the URL's owner/repo **wins** over cwd |
| `KEY-123`, `https://<host>.atlassian.net/browse/KEY-123` | Jira → Atlassian MCP `getJiraIssue` |
| Several of the above (list, commas, newlines) | One researcher **each**, dispatched together |
| Nothing / vague ("check the issues") | **Scope gate** below — never guess one issue |

**Resolve the repo** (GitHub only): if a URL supplies owner/repo, use it — that is the main agent's job, done from the text alone, no shell. When no URL gives it, leave resolution to the trier's first command (`gh repo view --json nameWithOwner`); if that fails because cwd is not a GitHub repo, `ask` the user for one. Never infer owner/repo from a directory that merely *looks* like the project — ask. (Locating a checkout of an **already-resolved** repo is a separate, later step.)

**No `subagent` tool in this session?** That's the only case where the zero-bash rule lifts, and only for the cheap count in Phase 0. Triage depth is where an inline agent overruns, so cap yourself: one `gh issue list`, then `ask` for scope, then hand the Phase 1 command list to the user (or run it per issue, two probes max). Never triage inline into a design doc.

**Locate a checkout** (GitHub only): the repo named by the issue is often checked out somewhere on this machine. If the user named a path, or cwd is that repo, pass it to every trier as `checkout: <path>`. If unknown, dispatch one cheap `researcher` to find it (`ls ~/Coding/*/*/`, `find ~ -maxdepth 4 -name .git`) before fanning out — without it, every trier forfeits code-level verification and lands at "medium" confidence for no reason. If none exists, say so in the dispatch and let triers report state-only verdicts.

Pass the checkout as **read-only context**: `git log`/`git show`/`grep` are fine; a dirty tree is normal and must stay dirty — no `checkout`, `stash`, `restore`, or `clean` to get a "clean" read, since that destroys someone's in-progress work.

**Jira:** route `KEY-123` / `browse/KEY-123` items to the Atlassian MCP `getJiraIssue`. The same read-only rule and the same stop condition apply — status, resolution, assignee, links, age, verdict; no code probing. If the MCP is absent or disconnected, say so and skip those items rather than falling back to `gh`.

## Phase 0: Scope Gate (blank or vague input)

The count is cheap; the deep dive is not. Gate first — and never answer a blank invocation by picking a single issue.

1. Dispatch **one** `researcher` for counts only — no per-issue digging:
   `gh issue list --state open --limit 500 --json number,title,labels,assignees,updatedAt`
   Have it return exactly: total open · the 10 most recently updated (`#`, title, age) · the distinct labels and assignees in use with counts. No bodies, no verdicts.
2. `ask` for scope, putting the total in the question and the label list in the options so the choices are self-explanatory:

```typescript
ask({ questions: [{ id: "scope",
  question: `${OPEN_COUNT} open issues. Which should I check?`,
  options: [
    { label: "All of them" },
    { label: "Assigned to me" },
    { label: `By label (in use: ${LABEL_LIST})` },
    { label: "The 10 most recently updated" }
  ] }]});
```

3. Turn the answer into an explicit issue list — for a label or assignee, one more cheap `gh issue list --label "<name>"` / `--assignee "<login>"` — and echo those numbers back to the user before fanning out, so a wrong filter is caught before N agents run.
4. Fan out over the approved set only. If it exceeds ~10, confirm the count again before dispatching.

## Phase 1: Dispatch One `researcher` Per Issue

Send all issues in **one block of parallel calls** — never a single agent for a batch.

```typescript
subagent({
  agent: "researcher",
  task: `Triage issue #${N} on ${OWNER}/${REPO}. READ-ONLY: no file edits, no
builds, no test runs, no state-changing gh calls. Report STATE, not a fix.

1. gh issue view ${N} --repo ${OWNER}/${REPO} --json number,title,url,body,state,
   stateReason,issueType,labels,assignees,author,milestone,createdAt,updatedAt,
   closed,closedAt,comments,closedByPullRequestsReferences,subIssuesSummary,blockedBy
   (`body` is required for a needs-info verdict: a title-only issue is not actionable)
2. Cross-references and PR activity:
   gh api repos/${OWNER}/${REPO}/issues/${N}/timeline --jq '.[].event'
   (look for cross-referenced / connected / closed events)
3. PRs that actually reference it — a bare --search "${N}" matches unrelated
   numbers, so filter on the text:
   gh pr list --repo ${OWNER}/${REPO} --state all --search "${N} in:title,body" \
     --json number,title,state,url   → keep only titles/bodies naming #${N}
4. Staleness budget: at most TWO cheap read-only probes, then stop. Prefer
   linked-PR state; else one grep or one `git log --oneline -S"<term>" -5` for
   a file/flag/string the title names. Do not open files to understand behaviour.
   Grep source only — skip `target/`, `node_modules/`, `dist/`. A generated file
   or an ADR/doc mentioning the term is NOT evidence the code does it; docs record
   intent, not behaviour, so cite them separately or not at all.
   ${CHECKOUT_LINE}
   A dirty tree whose modified files match the issue's subject = work in flight.
   Report it as "being worked now, uncommitted"; it is a state fact, not a fix.

STOP CONDITION: you have state + activity + one staleness verdict. Do NOT
root-cause, open files to understand behaviour, propose a patch, or rank work.

VERDICT RULES:
- "likely stale" requires EVIDENCE OF TIME — weeks/months of silence, or a merged
  PR/commit addressing it. An issue created hours or days ago CANNOT be stale;
  "the subsystem is active" is not staleness, it is the opposite.
- "likely already fixed" requires one citable command showing the fix.
  "The area has been refactored recently" is not that command — say "needs info".
- Never hedge a verdict with "— lean". Pick one, or report "needs info".
- A command that fails: report the REAL error text. Do not invent a plausible
  cause (a preview header, a rate limit, a network fault) for what is usually
  your own malformed call. Re-read the command, fix it once, or report the failure.

Return exactly:
- **Issue** — #N, title, URL, author
- **State** — open/closed (+ stateReason), labels, assignees, milestone, issueType
- **Age** — created, last activity, days since, comment count
- **Links** — PRs (number/state/URL), blocking/blocked-by, sub-issues, duplicates
- **Verdict** — one of: genuinely open | likely stale | likely already fixed
  (cite the one command that shows it) | needs info | duplicate of #N
- **One-line next action** — e.g. "close", "needs repro", "ready for specify"
- **Confidence** — high/medium/low, plus what you could not check`
})
```

**Fill `${CHECKOUT_LINE}` before sending** — never ship it literal:
- checkout known → `Run these in <path> (a checkout of ${OWNER}/${REPO}, may be dirty — read-only: no checkout/stash/restore/clean/clone/fetch).`
- none → `No local checkout exists: skip code probes entirely and say so in Confidence. Never clone or fetch to enable one.`

### `gh` hanging in a subagent — fix stdin, not the network

In a spawned subagent, `gh` (and `curl`, `git`, even `ls`) can appear to hang until the call times out while **the command actually ran and printed its full output**. This is not DNS, not IPv6, not auth — it is the harness waiting on an inherited stdin. Two fixes, in order:

1. `< /dev/null gh …` — closes the inherited stdin; usually instant.
2. `-o file -w '%{http_code}'` to a file, then read the file — output survives the kill.

Do **not** diagnose this as an IPv6/DNS problem and reach for `curl -4`: the hang reproduces on commands that make no network calls. If both fixes fail, report the stall as your finding — do not substitute a guessed value for data you could not read.

## Phase 2: Merge, Present, Hand Off

Print one table across all issues — `# | Title | Verdict | Age | Linked PR | Next action` — then a short list of anything flagged *likely already fixed* or *duplicate*, since those are the only items with a decision attached.

If issues were checked, `ask` what to do next:

```typescript
ask({ questions: [{ id: "next", question: "What should we do with these?",
  options: [
    { label: "Stop here — report only" },
    { label: "Label them from the triage verdicts" },
    { label: "Implement one — load the implement skill" },
    { label: "Plan one — load the specify skill" },
    { label: "Decompose the backlog — load the roadmap skill" },
    { label: "Close the stale/already-fixed ones (confirm each first)" }
  ] }]});
```

Closing is out of scope unless selected; then confirm each issue by number before any `gh issue close`, inside one subagent.

## Phase 3: Labeling

`gh issue edit` is a write and stays banned everywhere else — this phase is one of only two exceptions, and it runs only after the user picked "Label them."

**3a. Read the vocabulary (read-only `researcher`):**
`gh label list --repo <o>/<r> --json name,description` → return every name verbatim, plus the labels already on each issue in scope.

**3b. Map verdict → label using ONLY names that list returned.**

| Verdict | Candidate, by the repo's own vocabulary |
|---|---|
| genuinely open | the "been looked at" label (`triaged`) if one exists, else nothing |
| needs info | whatever means that — usually GitHub's stock `question` |
| duplicate of #N | `duplicate` |
| likely already fixed / stale | the close path, not a label |

Then `ask` with the concrete proposal — `#86 → +triaged` — one option to apply, one to adjust, one to cancel. **Nothing is written before this.**

**3c. Apply (one `general` subagent** — `researcher` is read-only by contract):

- `--add-label` only. Never `--set-labels` or `--remove-label`: they destroy labels you never looked at.
- **Never `gh label create`.** A missing label is a finding, not a gap to fill — report "no label fits X" and leave it untouched.
- Labels only: no title/body fixes, no assignee, milestone, or milestone typo repair, even when obviously wrong. Mention it; don't do it.
- Open issues only; skip any verdict with low confidence.
- Verify after: `gh issue view <n> --json labels` and report what each issue now carries.

A "being worked on" state with no matching label in the repo goes in the summary text, not into a new label.

Verdict labels are the baseline for every issue in scope — apply them uniformly. A type label (`bug` / `enhancement`) is an *extra*, only when the issue body states the type plainly, and it never *replaces* the verdict label. Propose each one visibly so the user can veto it.

## Common Mistakes

| Failure (observed) | Reality |
|---|---|
| Running `cargo test`/`npm test` to "verify the issue" | Triage never runs suites. Two cheap probes, then report. |
| Editing a file to see what breaks, then reverting | Writes are banned outright. Reason from `git log` and grep. |
| Emitting a fix plan with file:line and a work order | That is `specify`'s output. Return a verdict; hand off. |
| One agent checking 3 issues in sequence | One `researcher` per issue, all dispatched together. |
| Blank input → "you must have meant #6" | Count, summarize, `ask`. Guessing is not scoping. |
| Recommending `gh issue close 6` unprompted | Read-only until the user selects an action. |
| Guessing `gh` field names (`commentCount`, `authors`) | The verified list is in Phase 1 step 1 — use it verbatim. On an "Unknown JSON field" error, read the "Available fields" the error prints; don't re-guess. |
| Treating `issueType: null`, empty `subIssuesSummary` as a query failure | Absent/unused fields come back null or empty on repos without issue types or sub-issues. Report them as absent and move on. |
| Diagnosing a `gh` hang as IPv6/DNS and switching to `curl -4` | The hang reproduces on `ls` — no network involved. It's inherited stdin. See *fix stdin, not the network*. |
| "medium" confidence on every issue because cwd is another repo | Find the checkout first and pass it in. State-only verdicts should be the exception, not the default. |
| "likely stale" on an issue filed hours ago | Staleness needs elapsed time or a merged fix. A busy subsystem argues the opposite. |
| Explaining a failed API call with an invented cause ("needs a preview header") | `gh api repos/o/r/issues/N/timeline` needs no header — it returns 200. Quote the real error; a silent `[]` means no events, not a failure. |
| Labeling with names you assumed (`needs-info`, `in-progress`) | Those don't exist on most repos, including yours. `gh label list` first; map onto what's actually there — `question`, not `needs-info`. |
| Emitting `gh label create` for the missing ones | Creating taxonomy is the user's call. Report "no label fits" and move on. |
| `--set-labels` / `--remove-label` to "clean up" | Additive only. Those wipe labels you never inspected. |
| Fixing a title typo while you're in there | Phase 3 is labels. Mention the typo; do not touch it. |

## Red Flags — STOP

- More than two commands per issue probing code behaviour
- Any output containing a proposed patch, refactor, or task list
- Any `write`/`edit`, `git checkout`/`stash`, or state-changing `gh` call
- A merged report that reads like a design doc instead of a table
- In Phase 3: a label name not present in this session's `gh label list` output, any `gh label create`, or a non-label change (title, body, assignee, milestone)

**First four: the triage went too deep — return the verdict and stop. Last: the labeling went too far — propose it, don't perform it.**
