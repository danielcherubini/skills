---
name: add-idea-to-backlog
description: Use when an idea, request, or half-formed feature surfaces mid-session and must be recorded as a task-board card instead of designed on the spot — "add it to the backlog", "note this for later", "put this on the board", "we should do X someday", or when an audit, research finding, or bug report is filed rather than acted on. Not for designing the idea (use discuss) or planning it (use specify).
---

# Add an idea to the backlog

## Overview

Capture the idea **without inventing decisions**, on the assumption that **a card you
create is permanent**: there is no delete verb for tasks, so a duplicate or a mis-filed
card cannot be undone — only amended.

**Violating the letter of this rule is violating the spirit.** "I'll just add a little
spec so it's useful later" is where a captured idea hardens into invented requirements.

## When to use

- "Add it to the backlog", "note this for later", "file it", "put it on the board"
- A finding from an audit / research run / issue triage that is **filed, not fixed**
- An idea that arrives mid-task and is not what you were asked to build

**Not for:** designing it (`discuss`), planning it (`specify`), implementing it, or
tracking work you are doing right now (that is `manage_todo_list`).

## The sequence

1. **`list_board(space_path)` on the Space you are working in.** `space_path` is the
   working directory itself — pass your cwd, do not guess or reconstruct a path. Never
   guess the slug either: `backlog` is the seeded default (`DEFAULT_STAGES`: `backlog,
   discuss, research, approved, doing, done`) but Stages are **user-editable per Space**,
   and an unknown slug errors naming the valid set.
2. **Duplicate-check that listing before creating.** Scan titles for the same subject.
   If one exists, `edit_task` / `write_artifact` onto it — do not add a second card.
   This step is the whole cost of a mistake, because deletion is unreachable. If the
   board's titles carry GitHub numbers, the board mirrors the issue tracker here — so
   also check the tracker (`check-issue`) before creating a card that duplicates an issue.
3. **`create_task` with `stage_slug` read from step 1**, not assumed. Omit it only when
   the first stage is genuinely the target.
4. **Verify** with `get_task(task_id)` that the title and stage came back as intended.

## Body: what goes in

Four parts, in this order:

- **Verbatim ask** — the user's own words, quoted. Prose you write later cannot be
  distinguished from theirs unless you quote it.
- **Provenance** — where it came from (issue/PR/discussion/date). Cite by **PR number or
  title, never a task `#N`**: task numbers ARE reused after a highest-position delete.
- **Open questions** — every inference you are NOT making, as an explicit list. This is
  what keeps a capture a capture.
- **`done-when`** — one exit-condition line if you can state one from what was said. If
  you cannot, write `no exit condition yet` rather than inventing one.

## Quick reference

| Situation | Do |
|---|---|
| Slug unknown | `list_board` first; use the returned slug verbatim |
| Similar card exists | `edit_task` onto it; do not create |
| Idea needs design | Capture it, then offer `discuss` — never design inside the capture |
| Idea is a real bug you can fix now | Say so; filing it is the wrong move |
| You are a **subagent/worker** | Do NOT call board tools (see below) — report the exact calls for the parent session to make |

## Subagents cannot touch the board

Task tools **park** in a worker: the daemon holds no `TaskStore` and answers a
`TaskRequest` with a `task-unsupported` refusal, so the call hangs until the turn is
cancelled. A hung tool looks exactly like a slow tool. If you are a subagent, emit the
exact calls and arguments as your deliverable and let the parent session execute them.

## Common mistakes

| Mistake | Reality |
|---|---|
| "I'll create it first, dedupe later" | There is no delete. A duplicate is forever. |
| Writing a `spec` artifact for a one-sentence idea | You are inventing answers and promoting them to decisions. No artifact until the idea is actually designed. |
| Assuming `backlog` exists | Stages are per-Space and user-editable. Read them. |
| Citing the card as `#7` | Numbers are reused after a highest-position delete. Cite the title. |
| Paraphrasing the ask | The user's words are the only record of what they actually asked for. |
| Silently resolving ambiguity | Put it in Open questions. A quiet guess is indistinguishable from a decision later. |
| Calling `list_board` "to be safe" from a subagent | It hangs the turn instead of answering. |
