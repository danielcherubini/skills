---
name: check-pr
description: Use when checking a pull request for review comments, reviewer status, CI/approval status, or resolving code review feedback.
---

# Check PR

Orchestrate pull request inspection, resolution, and monitoring by delegating all execution tasks to **general subagents**. The main agent acts strictly as an orchestrator: launching subagents for investigation, presenting options to the user with `ask`, launching subagents to implement approved fixes and resolve threads, and launching subagents to watch PR and CI status.

---

## ⚠️ STRICT RULE: ZERO BASH IN MAIN AGENT

> **CRITICAL DISPATCH GUARD:**
> - **The main agent MUST NOT run any `gh`, `git`, or bash inspection/polling commands directly in the main session.**
> - **DO NOT run `gh pr view`, `gh api graphql`, `git commit`, `sleep 20`, or any shell commands in the main agent context.**
> - **All execution, querying, file reading, code editing, test running, and status polling MUST occur inside a `general` subagent.**
> - The main agent's sole responsibilities are: (1) dispatching subagents, (2) reading their reports, (3) interacting with the user via `ask`, and (4) reporting the final outcome.

```
Main Agent (Strict Orchestrator - ZERO BASH)
  │
  ├── 1. Launch [General Subagent: PR Checker]
  │        ├── Detects PR, queries GraphQL, inspects code context
  │        └── Returns structured inspection report
  │
  ├── 2. Prompt User (ask tool)
  │        └── Presents findings to the user (if actionable items exist)
  │
  ├── 3. Launch [General Subagent: PR Fixer] (if fixes approved)
  │        ├── Applies code changes & runs linters/tests
  │        ├── Commits, pushes, posts replies & resolves GraphQL threads
  │        └── Returns fix summary
  │
  └── 4. Launch [General Subagent: PR Watcher]
           ├── Loops/polls internally until ALL CI & bot checks reach terminal completion
           └── Returns final PR readiness report
```

---

## Workflow Phases

### Phase 1: Launch Checking Subagent

The main agent immediately dispatches a `general` subagent. If the PR number is not already known, the subagent detects it from the current branch.

#### Dispatch Call:
```typescript
subagent({
  agent: "general",
  task: `Check the pull request for the current branch (or PR #${PR_NUMBER} if known):
1. Detect owner, repo, and PR number if not provided ('gh pr view --json number,title,url,headRefName').
2. Fetch review decision, reviewer statuses (approved/changes requested/pending), CI check rollup, and all unresolved review threads using GitHub GraphQL:
   gh api graphql -f query='query($owner: String!, $repo: String!, $pr: Int!) { repository(owner: $owner, name: $repo) { pullRequest(number: $pr) { id title url reviewDecision reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } ... on Team { name } } } } latestReviews(first: 20) { nodes { author { login } state submittedAt } } reviewThreads(first: 50) { nodes { id isResolved isOutdated path line originalLine comments(first: 20) { nodes { id databaseId author { login } body createdAt } } } } } } }' -F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUMBER"
3. For each unresolved review thread (where isResolved == false):
   - Read the referenced file around the specified line to understand the context.
   - Assess whether the feedback is valid, partially valid, or a false positive / nitpick.
   - Formulate a recommended code fix or reply rationale.
4. Output a comprehensive structured report containing:
   - PR Metadata (number, title, branch, URL)
   - Reviewer Status Table (reviewers, decision, pending human requests)
   - CI / Check Runs Status Table
   - Unresolved Comments List (thread ID, comment database ID, file, line, author, comment snippet, context excerpt, recommended action/fix)
   - Overall recommendation`
})
```

---

### Phase 2: User Decision via `ask` Tool

The main agent parses the report returned by the checking subagent:

1. **If no actionable comments exist and PR is approved / passing checks:**
   - Display the status summary to the user.
   - If checks are still pending/running, proceed to Phase 4 (watching subagent).

2. **If actionable review comments exist:**
   - Call the `ask` tool to present each finding to the user with clear options.

```typescript
ask({
  questions: [
    {
      id: "action_thread_<databaseId>",
      question: "How should we handle the comment on <path>:<line>?",
      description: "### Reviewer: @<author>\n\n> <comment_snippet>\n\n**Proposed fix:** <concise explanation of proposed change>",
      options: [
        { label: "Apply proposed fix" },
        { label: "Skip / keep as is (explain and resolve)" },
        { label: "Ignore for now" }
      ],
      recommended: 0
    }
  ]
})
```

---

### Phase 3: Launch Fixing Subagent

For any comments where the user selected "Apply proposed fix" or "Skip / keep as is (explain and resolve)", the main agent dispatches a `general` subagent.

#### Dispatch Call:
```typescript
subagent({
  agent: "general",
  task: `Apply the approved review comment fixes and resolve the threads on PR #${PR_NUMBER}:

Approved actions:
${USER_DECISIONS_AND_INSTRUCTIONS}

Instructions:
1. Apply the specified code modifications to the corresponding files.
2. Run project linters, type checks, and tests (e.g. npm test, make lint, pytest, cargo test, etc.) to verify fixes.
3. Stage modified files and commit: 'git commit -m "<ticket/scope>: address review comments"'.
4. Push changes: 'git push origin <branch>'.
5. For each fixed comment:
   - Reply via REST API: gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments/${COMMENT_DATABASE_ID}/replies" -f body="Fixed in commit \`\$(git rev-parse --short HEAD)\`: ${FIX_SUMMARY}"
   - Resolve thread via GraphQL mutation: gh api graphql -f query='mutation($threadId: ID!) { resolveReviewThread(input: { threadId: $threadId }) { thread { id isResolved } } }' -F threadId="${THREAD_ID}"
6. For skipped comments requiring resolution:
   - Reply with explanation and resolve the review thread.
7. Return a summary of applied fixes, commit SHA, test results, and resolved threads.`
})
```

---

### Phase 4: Launch Watching Subagent

To monitor ongoing CI runs, automated review bots (e.g. Greptile, GitHub Actions, typecheck), and approval transitions, the main agent dispatches a `general` subagent.

> ⚠️ **WATCHER REQUIREMENT:** The watcher subagent MUST NOT return prematurely while checks are in progress. It must actively poll until all checks reach terminal status (`COMPLETED`, `SUCCESS`, `FAILURE`).

#### Dispatch Call:
```typescript
subagent({
  agent: "general",
  task: `Watch the status of PR #${PR_NUMBER} on repo ${OWNER}/${REPO} until ALL checks and reviews complete:
1. Poll the PR status checks every 20 seconds until NO checks are in progress or queued:
   while true; do
     PENDING=$(gh pr view ${PR_NUMBER} --json statusCheckRollup --jq '[.statusCheckRollup[]? | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING" or .state == "PENDING")] | length')
     if [ "$PENDING" -eq 0 ]; then
       break
     fi
     echo "Waiting for $PENDING pending check(s)..."
     sleep 20
   done
2. Once checks complete, inspect if any checks failed. If failed, fetch logs with 'gh run view <run-id> --log-failed'.
3. Check for any newly submitted review comments or threads (e.g. from Greptile or reviewers) using GraphQL.
4. Fetch final review decision and mergeability ('gh pr view ${PR_NUMBER} --json reviewDecision,latestReviews,mergeable').
5. Return a complete status report:
   - Final CI check status (all passed vs specific failures)
   - Reviewer approval status (APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED)
   - Any new unresolved comments created by bots/reviewers
   - Final ready-to-merge readiness assessment`
})
```

---

## Summary & Reporting

After the subagents finish:
- The main agent presents the final consolidated status to the user.
- If the PR is ready to merge, recommend or invoke `finish`.
- If new review comments or CI failures appeared during the watch, prompt the user or dispatch another fixer subagent.
