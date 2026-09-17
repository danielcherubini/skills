---
name: check-pr
description: Use when checking a pull request for review comments, code reviews, or bot feedback, deciding how to address them with the ask tool, applying fixes, replying to comments, and resolving review threads.
---

# Check PR

Check a pull request for open review comments, present options to the user with the `ask` tool, apply agreed fixes, reply to inline review threads, and resolve them.

---

## Workflow

```
1. Detect PR & repo
       │
2. Fetch unresolved review threads & reviews via GitHub API
       │
3. Analyze comments and propose fixes
       │
4. Ask user what to do using `ask` tool
       │
5. Implement selected fixes & run tests
       │
6. Commit & push changes
       │
7. Reply to each inline review comment & resolve the thread via GraphQL
       │
8. Report final status
```

---

## Step 1: Detect PR and Repository

Find the repository and current PR:

```bash
# Get owner and repo
gh repo view --json owner,name -q '.owner.login + "/" + .name'

# Get PR for current branch (or ask user for PR number/URL)
gh pr view --json number,title,url,headRefName
```

If no PR is found on the current branch, ask the user for the PR number or URL using the `ask` tool.

---

## Step 2: Fetch Unresolved Review Comments & Threads

Use GitHub GraphQL API to fetch review threads, comments, and resolution status:

```bash
gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      id
      title
      url
      reviewThreads(first: 50) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          comments(first: 20) {
            nodes {
              id
              databaseId
              author { login }
              body
              createdAt
            }
          }
        }
      }
      reviews(first: 20) {
        nodes {
          id
          author { login }
          state
          body
          submittedAt
        }
      }
    }
  }
}' -F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUMBER"
```

Filter threads to those where:
- `isResolved == false`
- `comments.nodes` has at least one comment

If there are no unresolved review threads and no actionable review comments, inform the user that the PR has no open review comments.

---

## Step 3: Analyze Comments and Formulate Options

For each unresolved review comment:
1. Identify the file (`path`), line number (`line`), author, and comment body.
2. Read the referenced file around the specified line to understand the context.
3. Formulate:
   - **Assessment**: Is the feedback valid, partially valid, or a false positive / nitpick?
   - **Recommended Action**: Proposed fix, or rationale for why it should be skipped/replied to without code changes.

---

## Step 4: Ask the User Using the `ask` Tool

Call the `ask` tool to present the findings to the user with clear options:

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

## Step 5: Implement Fixes & Validate

For every comment where the user selected "Apply proposed fix":
1. Edit the relevant files.
2. Run local linters and tests (e.g. `make lint`, `go test ./...`, `npm test`, `npm run check`).
3. Ensure no regressions or broken builds.

---

## Step 6: Commit and Push Changes

1. Stage only modified files.
2. Commit with conventional format referencing the ticket:
   ```bash
   git commit -m "<ticket>: address review comments on <topic>
   
   - <details of fix>"
   ```
3. Push to the remote branch:
   ```bash
   git push origin <branch>
   ```

---

## Step 7: Reply to Comments and Resolve Threads

For each addressed review comment:

### A. Reply to the Inline Comment (REST API)
```bash
gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments/${COMMENT_DATABASE_ID}/replies" \
  -f body="Fixed in commit \`$(git rev-parse --short HEAD)\`: ${FIX_SUMMARY}"
```

### B. Resolve the Review Thread (GraphQL Mutation)
```bash
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: { threadId: $threadId }) {
    thread {
      id
      isResolved
    }
  }
}' -F threadId="${THREAD_ID}"
```

---

## Step 8: Report Summary

Provide a concise summary table of:
- File and line
- Comment summary
- Action taken (Fixed / Skipped)
- Reply posted and thread resolution status
- Commit hash and PR link
