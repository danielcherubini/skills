---
name: update-task-with-findings
description: Use when a session produced durable output — an approved spec, a design decision, a measurement, a research finding — and an existing task-board card must carry it — "update the task with what we decided", "attach the spec", "record this on the card", or after research / specify / implement finishes. Not for brand-new ideas (use add-idea-to-backlog) or for cards you are creating.
---

# Update a task with new information

## Overview

Every board write here is a **full replace**, not an append, and reading the card does
not tell you what you are about to overwrite. So the rule is: **read the specific thing
you are about to replace, then prove the write landed.**

**Violating the letter of this rule is violating the spirit.** "I called `get_task` so I
read before writing" does not detect an artifact clobber — see step 2.

## Why this needs a skill

Two facts that read opposite to intuition:

- `write_artifact` upserts with `ON CONFLICT(task_id, key) DO UPDATE SET markdown =
  excluded.markdown` — it **replaces the whole artifact** and exits happily.
- `get_task` returns `artifact_keys` — **names only, never content**. So the card can
  tell you a key exists while leaving you blind to what is in it.

And a durable-copy hazard: specs under `docs/roadmap/` are gitignored, `finish` deletes
the plan family on ship, and those files are **unrecoverable** — no checkout, no stash,
no dangling blob. The artifact is often the only copy that survives.

## The sequence

1. **`list_board(space_path)`** for the current Space → get the real `task_id`. Never
   invent or reuse an id from memory.
2. **`get_task(task_id)`** → current title, body, `spec_path`, artifact key names.
3. **`get_artifact(task_id, key)` for the key you intend to write** — this is the only
   call that detects a clobber. If it has content, merge deliberately or pick a distinct
   key; never replace approved text you have not read.
4. **`write_artifact`** with the content **plus a provenance header** naming the source
   path and that the artifact is now the durable copy.
5. **Prove it**: `get_artifact` again and compare against the source. A silent drop
   during a paraphrase is the failure this step exists to catch.
6. **`edit_task`** for `body` / `spec_path` last.

## `edit_task` is per-field replace

`title` / `body` / `spec_path` go through `COALESCE`: **omit a field to preserve it, pass
it to replace it entirely.** Body is never appended. So a body rewrite must carry forward
anything in the old body that still holds — re-read it in step 2, don't recall it.

`spec_path` can be **replaced but never cleared**: omitting it preserves the old value, and
passing `""` writes an empty string, not NULL. If a card's `spec_path` points somewhere
wrong, the only repair is a better path — say so rather than assuming you can blank it.

## `spec_path` must be a path that survives

Pointing `spec_path` at a gitignored or scratch file is worse than leaving it null: it
reads like a pointer to a durable record and resolves to nothing on ship. Set it only to
a tracked path. When the real source is gitignored, the **artifact holds the content** and
`spec_path` stays null or names a tracked location.

## Artifact keys: self-enforced

Grammar `[a-z0-9][a-z0-9-]{0,39}`, ≤ 256 KiB. `require_artifact_key` sits in the command
layer and **rejects rather than cleans** — but the model's path goes through the router
straight to `write_artifact` and **never touches it**, so nothing validates your key for
you. A key is interpolated into the `<task>` launch block, so a bad key is load-bearing,
not cosmetic. Conventional names: `spec`, `research`, `notes`, `design`.

## Do not move the card unless asked

Settling a design is not a stage transition you get to invent. And know the real
semantics before refusing or performing one for the wrong reason: a **model** `move_task`
fires **no** `on_enter` hook and no compaction — only a human drag runs the full verb. So
a move is safe but inert, and "moving it triggers the launch skill" is false.

## Subagents cannot touch the board

Task tools **park** in a worker — the daemon holds no `TaskStore` and answers
`TaskRequest` with a `task-unsupported` refusal, so the call hangs until the turn is
cancelled. Emit the exact calls as your deliverable; the parent executes them.

## Common mistakes

| Mistake | Reality |
|---|---|
| Writing `key: "spec"` because `get_task` showed no `spec` | Names without content still hide nothing here — but if the key DOES exist you just replaced it blind. `get_artifact` first. |
| "I stored it verbatim" after paraphrasing | Paraphrase silently drops sections — caveats and load-bearing guard clauses first. Re-read and diff. |
| Setting `spec_path` to the scratch/gitignored file | A pointer to a deleted file looks like a record. The artifact is the record. |
| Replacing body and losing prior content | Body is a full replace. Carry forward what still holds. |
| Moving the card to `approved`/`done` unprompted | Not your transition to make. |
| Believing a move will run the launch skill | A model move fires no `on_enter`. |
| Trusting your artifact key to be validated | The model path bypasses `require_artifact_key`. |
