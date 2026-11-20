---
name: verification-before-completion
description: Use when about to claim work is complete, before committing or creating PRs
---

# Verification Before Completion

Run the verification command. Read the output. Then claim the result.

## Rule

Before claiming any work is done:

1. **Identify** — What command proves this claim?
2. **Run** — Execute it fresh, right now
3. **Read** — Full output, check exit code
4. **Verify** — Does output confirm the claim?
5. **Then claim** — With evidence

## Never say

- "Should work now" / "Probably fixed"
- "Looks correct" / "I'm confident"
- "Done!" before running verification

## What counts as verification

| Claim | Requires |
|-------|----------|
| Tests pass | Test command output showing 0 failures |
| Build succeeds | Build command exit 0 |
| Bug fixed | Reproduction test passes |
| Requirements met | Line-by-line checklist verified |
