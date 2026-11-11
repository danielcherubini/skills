# Durable Capture — tracker, Task card, ADRs, glossary

Shared by both paths. Everything in this file is a **write that outlives the session**, and each one
has a failure mode where it silently does not happen. Read the matching section before doing the
write, not after discovering it missing.

## Which tracker?

Resolve in this order and **stop at the first answer** — do not infer a tracker from a remote URL
when a stated one exists.

1. **`AGENTS.md` / `CLAUDE.md`** — an explicit tracker statement wins. Check here first:
   - **Jira**: if it specifies Jira (mentions Jira, a project key like `SUWS`, or Jira issue
     formatting), the tracker is **Jira**.
   - **GitHub**: if it specifies GitHub Issues (or mentions `gh issue`), the tracker is **GitHub**.
2. **The tracker's own CLI or MCP tools**, when present and authenticated:
   - `gh repo view --json url,nameWithOwner` succeeds → **GitHub**.
   - Atlassian MCP tool `atlassian_getAccessibleAtlassianResources` is available → **Jira**.
3. **An existing `issue:` front-matter key** in the roadmap doc or a sibling doc in `docs/roadmap/`:
   - A Jira key/URL (`https://*.atlassian.net/...` or `PROJ-123`) → **Jira**.
   - A GitHub issue URL (`https://github.com/.../issues/...`) → **GitHub**.
4. **Nothing found** → no tracker. Skip the publish ask, mention it once, and carry on.

**Do not derive the URL from `git remote`.** A renamed repo keeps answering on its old name forever —
GitHub redirects so clones and pushes keep working — so the remote is the one signal that survives
being wrong, and publishing to it files against a moved repo. `gh repo view` resolves the redirect;
`git remote -v` does not.

## The Task card id — where it comes from and where it must go

A card session carries a `<task id="tsk_…" stage="…">` block, and **that block is the only place the
card's id appears.** It normally arrives in your first user message (the board's launch button emits
it); when another skill loads this one mid-session it must forward the block, so also accept one
pasted into the context you were handed. Note the id the moment you see it.

**No block anywhere in your input → this is not a card session; skip every Task-board step in this
skill.** If you were clearly asked to work a named card but hold no block, ask for its id rather than
guessing — `write_artifact` refuses a dangling id and there is no fuzzy lookup to fall back on.

The id has to survive the session, because `specify`, `implement` and `finish` are loaded
mid-session, **never see the block**, and read the id from the document's front-matter instead. So
every durable doc you write carries it:

```yaml
task: <task_id>
```

Write it even when the tracker step was skipped. Without it the chain dead-ends exactly where the
docs are most destructive — a plan overwriting a spec, a deletion on ship.

## Attaching a document to the card

```
write_artifact(task_id: "<id from the <task> block>", key: "<key>", markdown: "<full file contents>")
```

Keys: `spec` for a spec, `plan` for a plan, `research` for a research report, `adr-<number>` for each
ADR (e.g. `adr-0101`), `<topic>` for a `docs/features/` closeout. A key is
`[a-z0-9][a-z0-9-]{0,39}` — lowercase, digits, hyphens, ≤40 chars, never a path, never a dot.
Markdown is capped at 256 KiB and **a refusal writes nothing**. The call **UPSERTS**, so re-running
after a revision is safe and is the correct response to a reviewer's fix.

**Read before you overwrite.** `write_artifact` replaces the whole artifact and exits happily, and
`get_task` returns artifact **key names only, never content** — so the card can tell you a key exists
while leaving you blind to what is in it. `get_artifact(task_id, key)` is the only call that detects a
clobber. If it has content, merge deliberately or pick a distinct key. Never replace approved text you
have not read. And `spec` and `plan` are two keys for two documents — do not overwrite one with the
other.

Then point the card at the file two ways, because each half is read from the other side:

- `edit_task(task_id, spec_path: "docs/roadmap/<topic>.md")` — card → file.
- `task: <task_id>` in the document's own front-matter — file → card (see above).

**Why this exists, in one line:** `docs/roadmap/` is gitignored in repos that have a Task board, so a
git-guard on the doc sends it down the "do not force-commit" branch and the document ends the run with
**no durable copy at all** — no commit, no stash, no dangling blob — and `finish` deletes the file on
ship (ADR 0100). The artifact is the copy that survives; the file is the working copy.

**Attach BEFORE anything that publishes.** Attaching is not gated on an `ask` — unlike the tracker
mirror, nothing leaves the machine: this writes to the card that started the session. Skipping it is
what makes the durability promise above false. Stopping early is not a reason to leave the only copy
on one disk.

**If there is no `write_artifact` tool** (this skill is global — plenty of projects have no Task
board), say so in one sentence and continue. Do not emulate it by writing a file elsewhere.

## Mirroring a document to the tracker

Only after the artifact is attached. If no tracker was found, skip — this never gates anything.

Ask first:

```
ask({
  questions: [{
    id: "mirror-issue",
    question: "The <spec|report> is saved at docs/roadmap/<topic>.md. Create or mirror to a GitHub issue?",
    options: [
      { label: "Create or update issue and attach the artifact (recommended)" },
      { label: "Skip — keep it local on disk only" }
    ]
  }]
})
```

**GitHub:**
- Reuse the issue already tied to this topic (an `issue:` key in the front-matter, or an open issue
  whose title names it); otherwise open one titled the topic:
  `gh issue create --title "<topic>" --body "<summary> — artifact attached."`
- Attach the markdown: `gh issue artifact create <issue-number> docs/roadmap/<topic>.md`
- Write the URL into the front-matter as `issue: <url>` (if the doc is tracked in git, amend the
  commit; do not force-commit if gitignored).
- If `gh issue artifact` is unavailable or fails, fall back to posting the body as a comment with the
  front-matter stripped (split across consecutive comments if over the 65 KB limit).
- After a later revision: `gh issue artifact edit <issue-number> <artifact-number> -F <path>`, or post
  a comment saying it supersedes the earlier one.

**Jira:**
- Reuse the ticket the `issue:` key names; otherwise load `create-jira-ticket` (or
  `atlassian_createJiraIssue` with `contentFormat: "markdown"`) using project routing from
  `AGENTS.md` / `CLAUDE.md` / that skill.
- Post or link the description, and write the key or URL into the front-matter as `issue: <key-or-url>`.

The file is the source of truth; the tracker is the review mirror.

## When to write an ADR

All three must be true:

1. **Hard to reverse** — the cost of changing our mind later is meaningful
2. **Surprising without context** — a future reader would look at the code and wonder "why?"
3. **A real trade-off** — there were genuine alternatives and we picked one for specific reasons

If any is missing, skip it. The obvious choice doesn't need documenting. If the user agrees to
capture one, write `docs/decisions/NNNN-slug.md` using [adr-format.md](../adr-format.md). Create
`docs/decisions/` lazily — only when the first decision is needed.

Offer it, don't announce it: *"That decision to [summary] feels worth recording — it's [hard to
reverse / surprising / a real trade-off]. Want me to capture it?"*

## When to add a glossary term

Did a fuzzy or overloaded term get resolved? Typical cases:
- The user said "account" but meant the billing entity, not the user profile
- One concept has several names in conversation ("materialize", "publish", "go live")
- A new term was coined that a future session should know

If the user agrees, add it to `CONTEXT.md` using [context-format.md](../context-format.md). Create
`CONTEXT.md` lazily — only when the first term is resolved. Capture inline, as it happens; don't
batch to the end, and don't force it when neither an ADR nor a term applies.
