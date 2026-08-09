---
name: gitflow-branching
description: Use when starting any new work that requires creating a git branch
---

# Git Branching

Trunk-based development with two workflows: simple feature branches for single-PR work, and `gh stack` for multi-PR chains.

## Which workflow?

| Scenario | Workflow | Tool |
|----------|----------|------|
| Single PR, independent change | Feature branch | `git checkout -b` |
| Multi-PR chain (plans with stacked sub-plans) | Stacked branches | `gh stack` |

When a plan references a **stack** (e.g. "Stack: 6 PRs", "builds on `stack/...`"), use the `gh stack` workflow below. Otherwise, use simple feature branching.

---

## Simple Feature Branches

`main → feature branch → main`

### Branch types

| Branch | Purpose | From | Merges to |
|--------|---------|------|-----------|
| `main` | Production-ready | - | - |
| `feature/*` | New features | `main` | `main` |
| `bugfix/*` | Bug fixes | `main` | `main` |

### Naming

- `feature/<ticket-id>-<description>`
- `bugfix/<ticket-id>-<description>`

### Starting a feature

```bash
git checkout main && git pull origin main
git checkout -b feature/<ticket-id>-<description>
```

### Finishing

```bash
git push -u origin feature/<ticket-id>-<description>
gh pr create --title "..." --body "..."
```

### Rules

- **Always branch from `main`** — never from another feature branch
- **Always PR back to `main`** — never to `develop` or other branches
- **Never create a `develop` branch** — it does not exist in this workflow
- Keep branches short-lived — merge back to main frequently

---

## Stacked PRs (`gh stack`)

For plans delivered as a chain of dependent PRs (e.g. plan-002 with 6 sub-plans). Each PR builds on the previous one in the stack.

### Branch naming

- `stack/<sub-plan-name>` — e.g. `stack/scaffold`, `stack/db-schema`, `stack/build-templates`

### Stack lifecycle

#### 1. Initialize the stack

When starting the first sub-plan of a stack, use `gh stack init` to create and register the first branch:

```bash
# Creates stack/<first-sub-plan> from the default trunk (auto-detected)
gh stack init stack/<first-sub-plan>

# Or specify a different trunk explicitly
gh stack init --base <trunk> stack/<first-sub-plan>
```

If the branch already exists locally, `gh stack init` adopts it into the stack.

#### 2. Add subsequent branches

Use `gh stack add` to create each new branch on top of the current stack position:

```bash
# From any branch in the stack (creates on top of the current position)
gh stack add stack/<next-sub-plan>
```

If the branch already exists, `gh stack add` adopts it into the stack instead of creating a new one.

**Never use `git checkout -b` for stack branches** — always use `gh stack init` (first) or `gh stack add` (subsequent). Manual branches won't be tracked by the stack and will break `gh stack push/submit/sync`.

#### 3. Push + submit PRs

```bash
gh stack push          # Push all branches
gh stack submit        # Create/update PRs, linking them as a stack
```

Each PR targets the previous branch in the stack. The bottom PR targets the trunk.

#### 4. Navigate within a stack

```bash
gh stack top           # Jump to the top (furthest from trunk)
gh stack bottom        # Jump to the bottom (closest to trunk)
gh stack up [n]         # Move n branches up (default 1)
gh stack down [n]       # Move n branches down (default 1)
gh stack trunk          # Check out the trunk branch
gh stack view           # See full stack with PR links
```

#### 5. Switch between stacks

```bash
gh stack checkout <stack-number>   # By stack number
gh stack checkout <pr-number>      # By PR number
gh stack checkout                  # Interactive picker of all stacks
```

#### 6. Sync + update

```bash
gh stack sync          # Pull remote changes across all branches
gh stack submit        # Push + update all PRs
```

#### 7. Merge the stack

Merge PRs in order (bottom first):

```bash
gh stack merge         # Merges all PRs in dependency order
```

Or merge individually via GitHub UI — always merge the bottom PR first, then rebase/sync the stack:

```bash
# After bottom PR is merged
gh stack sync          # Rebases remaining branches onto main
gh stack submit        # Updates PR bases
```

### Rules

- **Each branch does ONE logical task** from the plan — small, reviewable scope
- **Branch N builds on Branch N-1** — never branch from trunk mid-stack
- **Use `gh stack` for all stack operations** — don't manually push/create PRs
- **Keep the stack in sync** — run `gh stack sync` after any merge
- **PR descriptions reference the plan** — link to the implementation plan file

### Quick reference

| Action | Command |
|--------|---------|
| Create first branch | `gh stack init stack/<name>` |
| Add branch on top | `gh stack add stack/<name>` |
| Adopt existing branches | `gh stack init branch1 branch2 ...` or `gh stack add branch` |
| Push all branches | `gh stack push` |
| Create/update all PRs | `gh stack submit` |
| View stack + PR links | `gh stack view` |
| Navigate up/down | `gh stack up`, `gh stack down`, `gh stack top`, `gh stack bottom` |
| Switch between stacks | `gh stack checkout <number>` or `gh stack checkout` (interactive) |
| Sync with remote | `gh stack sync` |
| Merge entire stack | `gh stack merge` |
