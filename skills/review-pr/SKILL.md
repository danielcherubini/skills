---
name: review-pr
description: Use when reviewing an open pull request, a PR URL, or a PR branch on GitHub to conduct a deep code review and post inline comments with suggested code fixes directly to the PR.
---

# Review PR

Perform a comprehensive code review on a GitHub Pull Request and submit batch inline comments featuring committable code suggestions (` ```suggestion `) directly to the PR.

## Overview

This skill extends the deep review principles from the `review` skill to live GitHub pull requests. It inspects the full diff and code context, analyzes the changes across correctness, security, performance, tests, and architecture, drafts concrete inline suggestions that authors can commit with one click, presents the draft review to the user for confirmation, and submits the review as a single atomic batch via GitHub's Pull Request Review API.

## When to Use

- When asked to "review PR #123", "review this PR", or given a GitHub PR URL
- When asked to "review the pull request for this branch"
- When conducting a code review on GitHub with committable inline suggestions
- When a teammate or automated tool asks for feedback on an open PR

**When NOT to use:**
- Reviewing local changes before creating a PR (use `review` skill)
- Checking reviewer status, CI status, or resolving existing feedback threads (use `check-pr` skill)
- Merging an approved PR (use `finish` skill)
- Investigating a runtime bug locally (use `systematic-debugging` skill)

---

## Architecture & Subagent Roles

```
Main Agent (Orchestrator & User Interaction)
  │
  ├── Phase 1: Context Gathering (explore subagent)
  │     ├── Inspect PR metadata, base/head commits, files, and diff hunks
  │     └── Return concise context brief & diff map
  │
  ├── Phase 2: Deep Review (reviewer subagent)
  │     ├── Multi-dimensional code review (correctness, security, perf, tests, style)
  │     └── Return structured findings with exact target line numbers and replacement code
  │
  ├── Phase 3: Suggestion Formulation & Hunk Verification
  │     ├── Validate line numbers fall strictly inside PR diff hunks (prevent HTTP 422)
  │     ├── Build committable ```suggestion blocks for diff lines
  │     └── Move out-of-diff findings into top-level review body
  │
  ├── Phase 4: User Confirmation (ask tool)
  │     ├── Present findings breakdown, draft comments, and proposed review decision
  │     └── Get user approval on event type (COMMENT, REQUEST_CHANGES, APPROVE)
  │
  └── Phase 5: Batch Submission (general subagent)
        ├── Submit single POST /repos/{owner}/{repo}/pulls/{number}/reviews
        └── Report review URL and confirmation to user
```

**Responsibilities:**
- **Main Agent:** Orchestrates phases, formats user presentations, calls `ask` for approval, and never runs heavy polling or bash diff dumps directly.
- **explore subagent:** Queries GitHub for PR metadata, changed files, and unified diff hunks.
- **reviewer subagent:** Conducts deep analysis against the code and diff, generating structured findings with replacement code. Review only — never submits to GitHub.
- **general subagent:** Executes the GitHub API review submission payload.

---

## Workflow Phases

### Phase 1: PR Discovery & Context Gathering

Identify the target PR (from user query, URL, or local branch `gh pr view --json number,headRefOid,baseRefName,headRefName`).

Dispatch an `explore` subagent to gather the full PR diff, metadata, and files:

```typescript
subagent({
  agent: "explore",
  task: `Gather complete review context for PR #${PR_NUMBER} on repo ${OWNER}/${REPO}:
1. Fetch PR details:
   gh pr view ${PR_NUMBER} --repo ${OWNER}/${REPO} \
     --json number,title,body,baseRefName,headRefName,headRefOid,author,state
2. Fetch changed files with unified patch hunks:
   gh api repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/files --paginate \
     --jq '[.[] | {filename: .filename, status: .status, additions: .additions, deletions: .deletions, patch: .patch}]'
3. Check existing PR comments/reviews to avoid duplicate feedback:
   gh api repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments \
     --jq '[.[] | {path: .path, line: .line, body: .body}]'
4. Return a structured brief: PR title/author, commit SHA (headRefOid), list of changed files with their diff line ranges (from hunk headers), and key changes.`
})
```

---

### Phase 2: Deep Review Analysis

Dispatch a `reviewer` subagent to evaluate the code changes against the standard review dimensions:

```typescript
subagent({
  agent: "reviewer",
  task: `Conduct a deep code review of PR #${PR_NUMBER} on repo ${OWNER}/${REPO} using the diff and context provided:
Files and patches:
${EXPLORE_DIFF_BRIEF}

Review criteria (refer to the 'review' skill guidelines and checklists):
1. Correctness & Edge Cases: Off-by-one errors, null/undefined safety, race conditions, async safety, error propagation.
2. Security: Injection vulnerabilities, auth/authz checks, sensitive data exposure, SSRF, unchecked inputs.
3. Performance: N+1 queries, unintended allocations, unbounded loops, blocking async tasks.
4. Test Coverage: Are new code paths and edge cases tested? Are tests meaningful?
5. Maintainability & Idioms: Clear naming, DRY logic, appropriate abstractions, language-specific best practices.

For EVERY issue identified:
- Severity: 🔴 Blocking, 🟡 Important, 🟢 Nit, 💡 Suggestion, or 🎉 Praise
- File path: exact relative path
- Line range: start_line and end_line in the new version of the file
- Issue description: impact and why it matters
- Concrete replacement code: exact code replacement ready for a GitHub suggestion block`
})
```

---

### Phase 3: Suggestion Formulation & Diff Hunk Verification

> ⚠️ **THE DIFF HUNK BOUNDARY CONSTRAINT (HTTP 422)**
> GitHub's Review Comment API strictly rejects comments on lines outside the PR diff hunk with:
> `HTTP 422: "Validation Failed: line must be part of the diff"`.
> You MUST verify every inline comment's line number against the file's unified diff patch.

#### 1. Diff Hunk Parsing Rule
In unified diff hunks (`@@ -old_start,old_count +new_start,new_count @@`):
- Only lines in the new file corresponding to context (` `) or additions (`+`) can receive comments on `side: "RIGHT"`.
- If an issue is on a line **inside** a diff hunk:
  - Format as an inline comment with a ` ```suggestion ` block.
- If an issue is on a line **outside** all diff hunks (e.g. unmodified function higher up, or a caller in an untouched file):
  - **DO NOT** create an inline comment for it.
  - Add it to a dedicated **Contextual Findings (Outside Diff)** section in the top-level review body, including permalinks (`blob/<commit_sha>/<path>#L<line>`).

#### 2. Suggestion Block Formatting
GitHub renders interactive "Commit suggestion" buttons when the body contains a suggestion block:

```markdown
Explanation of the bug or improvement.

```suggestion
exact replacement code here
```
```

- **Single-line suggestion:** Target `line: N`, `side: "RIGHT"`. Replacement code replaces line `N`.
- **Multi-line suggestion:** Target `start_line: M`, `line: N`, `start_side: "RIGHT"`, `side: "RIGHT"`. Replacement code replaces lines `M` through `N`.
- **Indentation:** The suggestion code must exactly preserve the indentation of the surrounding file.

---

### Phase 4: User Confirmation via `ask` Tool

Always present the drafted review to the user before submitting to GitHub.

#### Determine Proposed Event:
- `REQUEST_CHANGES`: If there is at least one 🔴 Blocking finding (crash, security flaw, data corruption, broken build).
- `APPROVE`: If there are zero 🔴 and zero 🟡 findings, and changes look solid (may include 🟢 nits or 🎉 praise).
- `COMMENT`: If there are 🟡 Important or 💡 Suggestion findings without critical blockers, or if the PR is a draft.

#### Present Draft & Call `ask`:
```typescript
ask({
  questions: [
    {
      id: "submit_review",
      question: `Ready to submit PR #${PR_NUMBER} review as ${PROPOSED_EVENT}?`,
      description: `### Review Summary Preview
**Event:** \`${PROPOSED_EVENT}\`
**Findings:** ${BLOCKING_COUNT} Blocking, ${IMPORTANT_COUNT} Important, ${NIT_COUNT} Nits, ${SUGGESTION_COUNT} Suggestions

#### Inline Suggestions Preview:
${INLINE_PREVIEWS}

${OUTSIDE_DIFF_SECTION}`,
      options: [
        { label: `Submit as ${PROPOSED_EVENT}` },
        { label: "Submit as COMMENT (non-blocking)" },
        { label: "Submit as REQUEST_CHANGES" },
        { label: "Submit as APPROVE" },
        { label: "Cancel (do not submit)" }
      ]
    }
  ]
})
```

---

### Phase 5: Batch Submission via GitHub API

If the user approves submission, dispatch a `general` subagent to submit the review in a single atomic API call:

```typescript
subagent({
  agent: "general",
  task: `Submit the PR review for PR #${PR_NUMBER} on repo ${OWNER}/${REPO}:

Execute the following GitHub API call:
gh api \\
  --method POST \\
  -H "Accept: application/vnd.github+json" \\
  /repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews \\
  --input - << 'EOF'
{
  "commit_id": "${HEAD_REF_OID}",
  "event": "${SELECTED_EVENT}",
  "body": "${ESCAPED_OVERALL_BODY}",
  "comments": ${JSON_COMMENTS_ARRAY}
}
EOF

Return the response ID, review HTML URL, and confirmation.`
})
```

After submission, provide the user with the review summary, links to the review comments, and next steps.

---

## API Payload Specification

### Single-Line Comment with Suggestion
```json
{
  "path": "src/auth/jwt.ts",
  "line": 42,
  "side": "RIGHT",
  "body": "Use a constant-time comparison to prevent timing attacks.\n\n```suggestion\nreturn crypto.timingSafeEqual(userSignature, expectedSignature);\n```"
}
```

### Multi-Line Comment with Suggestion
```json
{
  "path": "src/services/order.ts",
  "start_line": 88,
  "line": 94,
  "start_side": "RIGHT",
  "side": "RIGHT",
  "body": "Wrap the inventory decrement and order creation in a database transaction to ensure atomicity.\n\n```suggestion\nreturn await db.transaction(async (tx) => {\n  await tx.inventory.decrement(itemId, quantity);\n  return await tx.orders.create({ userId, itemId, quantity });\n});\n```"
}
```

### General Comment (No Code Suggestion)
For questions or architectural observations on a diff line:
```json
{
  "path": "src/config/env.ts",
  "line": 15,
  "side": "RIGHT",
  "body": "Will this environment variable be provisioned in staging and production secrets before deployment?"
}
```

---

## Severity Classification

| Severity | Criteria | Review Event Impact |
|:---|:---|:---|
| 🔴 **Blocking** | • Runtime exceptions, panics, null crashes<br>• Security vulnerabilities (SQLi, auth bypass, leak)<br>• Data corruption or race condition<br>• Breaking public API contracts without deprecation | Triggers `REQUEST_CHANGES` |
| 🟡 **Important** | • Logic edge cases not handled<br>• Significant performance degradation or N+1 queries<br>• Missing critical test coverage<br>• Unhandled network/DB errors | Suggests `COMMENT` or `REQUEST_CHANGES` |
| 🟢 **Nit** | • Idiomatic naming or minor cleanup<br>• Minor code redundancy<br>• Small documentation/comment improvements | Does not block (`COMMENT` or `APPROVE`) |
| 💡 **Suggestion** | • Alternative cleaner architecture or design<br>• Useful library/helper pattern that could be used | Informational (`COMMENT`) |
| 🎉 **Praise** | • Clever or elegant solution<br>• Excellent test coverage or documentation | Reinforces positive practices |

---

## Common Rationalizations & Traps

| Rationalization / Trap | Reality | Correct Action |
|:---|:---|:---|
| *"I'll post comments one by one with `gh pr comment`"* | Spams repo subscribers with multiple emails and fails to create a unified review object on GitHub. | Batch all comments into a single `POST /repos/{owner}/{repo}/pulls/{number}/reviews` call. |
| *"I'll just describe the change in prose instead of writing code"* | Prose forces the author to manually interpret, type, and format the fix. | Provide committable ` ```suggestion ` blocks wherever an exact fix is known. |
| *"I'll place an inline comment on an untouched line near the change"* | GitHub API will crash with `422 Unprocessable Entity: line must be part of the diff`. | Verify line numbers against hunk headers. Move out-of-diff issues to top-level review body. |
| *"I don't need to ask the user; I'll submit right away"* | Submitting reviews is public and irreversible on team repos. | Always present review draft with `ask` before calling the API. |
| *"The PR is small, so I'll run `gh pr diff` directly in the main session"* | Bash outputs pollute context and slow down agent responsiveness. | Delegate diff retrieval and API execution to `explore` and `general` subagents. |

---

## Red Flags — STOP and Reset

- Trying to submit inline comments without verifying they fall within diff hunks
- Generating suggestions that change line indentation inconsistently with surrounding code
- Calling `gh api ... reviews` without prior confirmation via `ask`
- Emitting raw markdown without ` ```suggestion ` blocks for straightforward bug fixes
- Submitting `REQUEST_CHANGES` for subjective stylistic preferences

---

## Quick Reference

| Action | Command / Tool |
|:---|:---|
| PR Metadata & Commit SHA | `gh pr view <number> --json number,headRefOid,baseRefName,headRefName` |
| File Diff Hunks | `gh api repos/<owner>/<repo>/pulls/<number>/files --paginate` |
| Batch Review API Endpoint | `POST /repos/<owner>/<repo>/pulls/<number>/reviews` |
| Single-Line Suggestion Fields | `"path"`, `"line"`, `"side": "RIGHT"`, `"body"` with ` ```suggestion ` |
| Multi-Line Suggestion Fields | `"path"`, `"start_line"`, `"line"`, `"start_side": "RIGHT"`, `"side": "RIGHT"` |
| Confirmation | `ask({ questions: [...] })` before API dispatch |
