---
name: daily-summary
description: 'Use when the user asks for a daily summary, standup, or wants to know what they did today — e.g. "daily summary", "standup", "what did I do today", "summary for slack", "daily update".'
---

# Daily Summary Skill

Scans git history across every repo under `~/Coding/AI` and `~/Coding/Ops` for the target day, then produces a human-readable, Slack-ready summary and writes it to a tmp file the user can open and copy-paste.

**Goal:** turn raw commit noise into a plain-English bulleted list a non-engineer could roughly follow — like the examples below. Not a commit log dump.

## Output Format (exact)

Always `Today:` on its own line, followed immediately (no blank line) by `- ` bulleted lines. No blank line between bullets:

```
Today:
- Foo
- Bar
- Qux
```

## Style Reference

The output should read like these real examples (plain sentences, outcome-focused, first-person-implied), just reformatted with `- ` bullets per the format above:

```
Today:
- Improved vLLM caching and scaling
- Upgraded Sonnet to 5 as well as across complexity routers
- Fixed some bugs with Sonnet 5 that were of course undocumented changed (Thanks Anthropic)
- Consolidating and fixing build and deploy pipelines
- Automatic triggering for build pipelines
- Getting the pipelines to be more closer to the ones ops wants
```

```
Today:
- Pi now supports the skills from litellm
- Slack alerts setup for litellm
- fixed some issues in the llm-skills pod
- Reviewed a couple PRs from Kristian in llm-auth
- Fixed issue in litellm, creating a new monkey-patch for our deployment, as well as upstream
- Cleaned up some of the github deployment workflows.. theres more to go..
```

Style rules:
- Every bullet starts with `- ` (hyphen + space) — required for correct Slack rendering.
- Group related commits into ONE bullet describing the outcome, not one bullet per commit.
- Describe **what changed and why it matters**, not file names or commit hashes.
- Keep the casual tone — contractions and asides ("...theres more to go..", "(Thanks Anthropic)") are fine and on-brand.
- 5–12 bullets is typical. Merge aggressively; drop trivial noise (version bumps, typo fixes, merge commits).
- Occasionally include a concrete outcome/metric bullet if the work produced one (e.g. capacity numbers, "rolled out to production on both servers").

## Phase 1: Determine the Date

Parse `$ARGUMENTS`:
- empty or `"today"` → today's date
- `"yesterday"` → yesterday
- an explicit `YYYY-MM-DD` → use as-is

Set:
```bash
DAY="<YYYY-MM-DD>"          # target day
SINCE="$DAY 00:00:00"
UNTIL="$DAY 23:59:59"
```

If the user says "today" but the system date looks stale, confirm the real current date before proceeding.

## Phase 2: Gather Commits

Find the author identity:
```bash
git config --global user.email   # e.g. you@example.com
```

Scan every git repo under both roots for commits authored that day (all branches, so local work-in-progress branches are included):
```bash
AUTHOR="$(git config --global user.email)"
for base in ~/Coding/AI ~/Coding/Ops; do
  for repo in "$base"/*/; do
    [ -d "$repo/.git" ] || continue
    name="$(basename "$repo")"
    log="$(git -C "$repo" log --all --no-merges \
      --since="$SINCE" --until="$UNTIL" \
      --author="$AUTHOR" \
      --format='%h|%s%n%b' 2>/dev/null)"
    [ -n "$log" ] && printf '\n### %s\n%s\n' "$name" "$log"
  done
done
```

Notes:
- `--all` catches commits on feature branches not yet merged.
- `--no-merges` drops merge commits (noise).
- If nothing is found for `user.email`, retry without `--author` (the user may commit under a different email locally) and show the author names so the user can confirm which are theirs.
- Also glance at uncommitted work in progress if commits are sparse:
  ```bash
  git -C "$repo" status --short 2>/dev/null
  ```
  Use this only as a hint — don't list uncommitted files as done work unless the user confirms.

## Phase 3: Synthesize

For each repo with activity:
1. Read the commit subjects + bodies.
2. Cluster related commits into themes (feature, fix, infra, review, cleanup).
3. Rewrite each theme as ONE plain-English `- ` bullet in the style above.
4. Drop pure-noise commits (formatting, version bumps, "wip", "fix typo", reverts that cancel out).

Map repos to human context where helpful (don't force it):
- `litellm`, `llm-server`, `pi*` → AI serving / model infra
- `github-code-review-bot`, `protector-reviewer-cli` → code review tooling
- `platform-modules`, `protector-platform` → Ops / platform / pipelines

Mention the repo/area naturally in the bullet when it aids clarity (e.g. "fixed some issues in the llm-skills pod"), but don't prefix every bullet with a repo name.

## Phase 4: Write the tmp File

Write the final summary to a predictable tmp path and tell the user to open it:
```bash
OUT="/tmp/daily-summary-$DAY.txt"
```

File contents = exactly what should be pasted into Slack, using `- ` bullets with no blank lines:
```
Today:
- <bullet 1>
- <bullet 2>
...
```

Then copy to clipboard (platform-aware), print the path, and echo the contents to the chat so the user can review inline:
```bash
# Copy to clipboard (Wayland / X11 / macOS)
if command -v wl-copy &>/dev/null; then
  wl-copy < "$OUT"
elif command -v xclip &>/dev/null; then
  xclip -selection clipboard < "$OUT"
elif command -v pbcopy &>/dev/null; then
  pbcopy < "$OUT"
else
  echo "(clipboard copy not available — install wl-copy, xclip, or pbcopy)"
fi
echo "Written to $OUT (copied to clipboard)"
cat "$OUT"
```

## Phase 5: Offer Refinement

After writing, ask if the user wants to:
- reorder/merge/drop any bullets,
- add a non-git item (meetings, reviews done in the UI, investigations),
- adjust tone (more technical vs. more plain-English).

Rewrite the tmp file in place on request.

## Rules

- **Every line under `Today:` must start with `- `** (Slack bullet format) — no blank lines between bullets.
- **Summarize, don't dump** — one bullet per theme, not per commit.
- **Plain English** — a PM should roughly understand every bullet; no file paths or hashes.
- **Match the casual Slack tone** from the examples.
- **Never fabricate** — only summarize work with git evidence (or user-confirmed non-git work).
- **Always write to `/tmp/daily-summary-<date>.txt`** and print the path.
- **Include both roots** — `~/Coding/AI` and `~/Coding/Ops` and all their git subfolders.
- **Ignore merge commits and trivial noise.**
