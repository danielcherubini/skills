---
name: move-task-to-approved
description: Use at the end of research, specify, or implement when the work was produced from a Task board card and the session is finished — offers to move the card to the Approved lane and hand implementation to a fresh Session instead of continuing in this one. Triggered by "move it to approved", "hand it off", "we're done here then what", or by the terminal ask of one of those skills when a `<task id="tsk_…">` block was seen.
---

# Move a task to Approved and hand off

## Overview

End the session by **parking the card and letting the board start the work**, rather
than implementing in the session that did the thinking. The card carries the artifacts;
a fresh Session reads them from the card, so the handoff is the transfer of context.

Run this **only when this session knows a task id** — from a `<task id="tsk_…">` block
or a plan's `task:` front-matter key. No id → no card → skip entirely and keep whatever
the calling skill's terminal ask already did.

## Order is load-bearing

1. **Attach every durable document first** — `write_artifact` for spec / plan / research,
   then `get_artifact` to prove it landed. Follow `update-task-with-findings` for the read
   before you overwrite: `get_task` lists artifact KEY NAMES only, never content, and the
   upsert replaces the whole document. A fresh Session reads the card and nothing else, so
   a card moved before its artifacts exist hands off an empty card.
2. **`list_board(space_path)`** and take the Approved column's **real slug** from the
   rows. Stages are user-editable per Space; `approved` is the seeded default, not a
   guarantee, and a wrong slug errors naming the valid set.
3. **`move_task(task_id, <slug>)`**.
4. **Verify** with `get_task` that `stage_slug` changed.
5. **Tell the user, then stop.** Do not load `implement`. Do not keep working.

## What to tell the user

Say all three parts, in this order, and name the control the way the UI names it:

> The card is now in **Approved**. To implement it:
> 1. **Archive this session** — hover its row in the sidebar and click **Archive** (it is
>    a hover-revealed action). This session's context is done; the card now holds the
>    spec and plan.
> 2. **Open the Tasks board** for this Space.
> 3. **Click the arrow pill on the card** — it is labelled with the next column's name,
>    which you read from `list_board` in step 2 (quote the real label; never guess it).
>    That click moves the card and starts a **fresh Session** on it, which loads this
>    column's launch Skill and reads the card's artifacts.

Then stop.

## Facts that read opposite to intuition

- **A model `move_task` fires no `on_enter` hook and no launch** — only a human drag runs
  the full verb. So the move is safe but inert; nothing starts until the user clicks.
- **`approved` has no launch Skill on a default board** (`on_enter_skill` is NULL). That
  is what makes it a parking lane: the work starts clean in the new Session, not as a
  continuation of this one.
- **The pill's label is the DESTINATION column's name — data you read, never a word you
  hardcode.** A Space owner can rename that column, so `Doing →`, `Implement →` and
  `WIP →` are each correct on some board. Quote the label `list_board` returned; a
  guessed name is an instruction the user cannot follow.
- **Which Skill the new Session loads comes from the destination Stage's
  `on_enter_skill`**, and it varies per Space and changes without warning. Say "its
  launch Skill" — never name one you have not read in the stage rows. Renaming a column
  does **not** change which Skill it launches: `slug` and `label` are separate columns,
  so a board can read `Implement` while launching any Skill.
- **Under `board_strict = 1` a move that is not a declared edge refuses**, writing
  nothing. Relay the refusal's allowed list; do not retry with a guessed slug.

## Do not

- Do not load `implement` after the move — that is the thing the handoff replaces.
- Do not move when there is no card, and do not create one to have something to move.
- Do not move to `done`. The work is not done; it is approved.
- Do not assume the slug. Read it.
