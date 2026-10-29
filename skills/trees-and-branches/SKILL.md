---
name: trees-and-branches
description: Use when starting new work that needs a git branch, when running work concurrently that would share one working tree or index, or when switching between in-flight branches with uncommitted work — "create a branch", "branch off main", "work on these in parallel", "switch to that branch without losing my work", "stacked PRs", "worktree"
---

# Trees and Branches

Two mechanisms, one page: **branches** decide *where work lands*; **worktrees** decide *how many places it can land at once*.

Trunk-based development — `main → branch → main`, no `develop`. Worktrees give you N working directories over one object store, so concurrent work and branch switching stop competing for one checkout.

## Which workflow?

| Scenario | Workflow |
|----------|----------|
| Single PR, independent change | Feature branch in the primary worktree |
| Work must run **concurrently** with other work | One worktree per unit of work |
| Interrupted mid-edit by urgent work elsewhere | Worktree for the interruption |
| Multi-PR chain (plan declares a **stack**) | `gh stack` |

When a plan references a **stack** ("Stack: 6 PRs", "builds on `stack/...`"), use the stack workflow. Otherwise, feature branching.

---

## Branches

### Types and naming

| Branch | Purpose | From | Merges to |
|--------|---------|------|-----------|
| `main` | Production-ready | — | — |
| `feature/*` | New features | `main` | `main` |
| `bugfix/*` | Bug fixes | `main` | `main` |
| `stack/*` | One link in a PR chain | previous stack branch | previous link |

Name them `feature/<ticket-id>-<description>`; drop the ticket id when none exists.

```bash
git checkout main && git pull origin main
git checkout -b feature/<ticket-id>-<description>
```

### Rules

- **Always branch from `main`** — never from another feature branch (mid-stack is the one exception; see below)
- **Always PR back to `main`** — never to `develop` or a sibling feature branch
- **Never create a `develop` branch** — it does not exist in this workflow
- Keep branches short-lived; merge back to main frequently

---

## Worktrees

`git worktree add <dir> -b <branch> <start-point>` gives `<dir>` its own checkout **and its own index**, sharing the repo's object store and refs.

This is the property that matters: **two children in two worktrees cannot see, stage, or clobber each other's files.** Untracked files — `node_modules/`, `target/`, build artifacts — are per-worktree too, so concurrent builds don't fight over one in-tree cache.

> ⚠️ **Concurrency means N branches, not one shared branch.** One branch, one worktree — git enforces it. "These tasks touch disjoint files, run all three on `feature/payments`" is not a workable instruction: disjoint files make a *merge* clean, they do not make a *shared index* safe, and three agents on one branch have one index. Give each unit of work its own branch, then fan in (see *Fan-in*).

### Placement: sibling, never nested

```bash
git worktree add ../$(basename "$PWD")-feature-payments -b feature/payments main
```

A worktree **inside** the repo directory shows up as untracked cruft (`?? wt/`) and `git add .` will try to commit it as an embedded repo. Put them beside the repo, named `<repo>-<branch>` so `git worktree list` reads unambiguously.

### Rules

- **One branch, one worktree.** Git enforces it: `worktree add <dir> main` dies with *`fatal: 'main' is already used by worktree at ...`*. To read another branch's state without checking it out, use `git show main:file` or `git worktree add --detach <dir>` — do not force the checkout.
- **`cd` is mandatory.** A subagent's shell starts in the session directory, not its worktree. If that default happens to be *another* git repo, a bare `git commit` commits into the wrong repo **silently — no error**. Prefix every git command with `cd <worktree> &&`, and verify with `git rev-parse --show-toplevel` before the first write.
- **`git stash` is repo-global, not per-worktree.** A `stash@{0}` created in the feature worktree is listed *and poppable* from the hotfix worktree, so popping from the wrong directory injects the WIP into the wrong tree. Stash is also an expendable ref — `git stash drop` is near-silent and effectively unrecoverable.
- **Prefer a `wip:` commit over a stash** for anything worth keeping; resume with `git reset --mixed <sha-from-before-the-wip-commit>`. `HEAD~1` is only correct if you made exactly one commit and no amend — capture the sha *before* committing, so the reset target is a fact rather than an assumption.
- **Prune after deleting by hand.** `rm -rf` leaves the registration behind (`prunable` in `git worktree list`); `git worktree prune` clears it. Prefer `git worktree remove <dir>` — it refuses while real work is uncommitted, which is the safety you want; `--force` discards it.
- **Removing a worktree does not remove its branch.** The commits survive; only the directory goes. Deleting the branch first is not a hazard — git refuses: *`cannot delete branch 'x' used by worktree at ...`*. Remove the worktree, then delete the branch.
- **`git worktree remove` refuses on uncommitted *or untracked* work — but gitignored artifacts don't block it.** Per-worktree build output never forces `--force`. If it refuses, something real is uncommitted: read it before forcing.

### Interrupt pattern

Halfway through `feature/payments` with failing tests, user needs a hotfix on `main`:

```bash
git worktree add ../repo-bugfix-hotfix -b bugfix/hotfix main
cd ../repo-bugfix-hotfix   # pristine tree; the WIP never moves
```

The WIP stays exactly where it was — **there is no restore step to get wrong**, and the hotfix tree physically cannot contain it. Branch the hotfix off `main`, never off the feature branch, so it inherits no feature commits.

On resume, expect conflicts and re-run the suite: the WIP was last tested against a base that the merged hotfix has moved.

### Fan-in: re-converging parallel branches

N worktrees is N branches. Something has to bring them back together, and **disjoint files guarantee a clean merge, not a working build** — two children can define the same symbol in different files, or both need a registration point neither was told to touch.

```bash
git diff --name-only main feature/payments-task-1 > /tmp/f1
git diff --name-only main feature/payments-task-2 > /tmp/f2
comm -12 <(sort -u /tmp/f1) <(sort -u /tmp/f2)     # any line = two children fought over a file
```

Run the check **from a worktree whose toplevel you have verified** — a disjointness check that reads the wrong repo compares empty sets and reports "no overlap." A green that proves nothing is worse than a red.

Then dry-run the merge without touching any tree, merge in order, and run the full suite **on the integrated result**:

```bash
git merge-tree --write-tree feature/payments-task-1 feature/payments-task-2   # exit 0 = clean, 1 = conflict
git merge --no-edit feature/payments-task-1
go test -v ./...
```

**Prove the suite actually ran — do not trust the exit code.** A file named `test_foo.go` instead of `foo_test.go` is not a test file, so `go test ./...` prints `?   pkg   [no test files]` and **exits 0** having run nothing. And a genuinely green non-verbose run prints no `--- PASS` lines either. So: run verbosely and require a non-zero `--- PASS` count — `go test -v ./...`.

### What worktrees do *not* fix

Global caches are still shared — Go's `GOCACHE` lives in `~/.cache/go-build` regardless of worktree, as does any tool's home-directory cache. Per-worktree isolation covers in-tree artifacts only. Very large concurrent builds still contend; if wall-clock doesn't improve, that's why.

---

## Stacked PRs

When a plan declares a **stack** ("Stack: 6 PRs", "builds on `stack/...`"), read **[Stacked PRs](stacked-prs.md)** before branching. The two rules that break the most: never `git checkout -b` a stack branch (`gh stack init`/`add` or the branch is untracked by the stack), and merge bottom-first — a middle merge orphans everything above it.

---

## Cleanup

`git worktree list` first — it shows what exists and what is `prunable`. Remove worktrees, then delete branches (git refuses the reverse). Removal refuses while real work is uncommitted; see the rules above before reaching for `--force`.

## Common mistakes

| Mistake | Consequence |
|---------|-------------|
| Worktree nested inside the repo | `?? wt/` untracked cruft; `git add .` tries to add it as an embedded repo |
| Forgetting `cd` in a subagent | Commits land in the session's repo silently, no error |
| `git stash pop` from another worktree | WIP injected into the wrong tree |
| `git checkout main` to service an interrupt | Carries the WIP onto `main`; `git commit -a` ships half-edited files |
| `git worktree remove --force` reflexively | Discards uncommitted work — find out *why* it's dirty first |
| `git checkout -b` inside a stack | Untracked branch; `gh stack push/submit/sync` break |
| Assuming worktrees lift every concurrency limit | `implement` caps a wave at 4 concurrent implementers; global caches survive worktrees (see *What worktrees do not fix*). Measure before widening. |
