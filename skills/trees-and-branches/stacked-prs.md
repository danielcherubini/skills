# Stacked PRs (`gh stack`)

Load this when a plan declares a **stack** — "Stack: 6 PRs", "builds on `stack/...`". Each PR targets the previous branch; the bottom one targets the trunk.

Requires the `gh` stack extension (`gh stack --help`).

## Lifecycle

```bash
gh stack init stack/<first-sub-plan>   # first link, from the trunk
gh stack add stack/<next-sub-plan>     # each subsequent link
gh stack push && gh stack submit       # push all; create/link the PRs
gh stack sync                          # after ANY merge, rebase the rest
gh stack merge                         # merge in dependency order
```

Navigation: `gh stack top` / `bottom` / `up [n]` / `down [n]` / `trunk` move the checkout within the stack. `gh stack view` prints the stack with PR links. `gh stack checkout <stack-number | pr-number>` (no argument = interactive picker) switches between stacks.

`gh stack merge --merge-method merge|squash|rebase` picks the merge method; `gh stack rebase` does a cascading rebase across the stack without fetching the trunk.

Naming: `stack/<sub-plan-name>` — `stack/scaffold`, `stack/db-schema`, `stack/build-templates`.

## Rules

- **Never `git checkout -b` for stack branches** — use `gh stack init` (first) / `gh stack add` (subsequent). Manually created branches aren't tracked by the stack and break `push`/`submit`/`sync`. If the branch already exists, `init`/`add` adopts it rather than failing.
- **Each branch is ONE logical task** from the plan — small, reviewable scope
- **Branch N builds on branch N-1** — never branch from trunk mid-stack
- **`gh stack sync` after every merge**, then `gh stack submit` to re-point PR bases
- **Merge bottom-first** — merging a middle link orphans the links above it. Merging via the GitHub UI is fine; follow it with `sync` + `submit`
- **Link the implementation plan** in each PR description

## When sync conflicts

`gh stack sync` cascade-rebases every link onto its updated parent and pushes all branches atomically with `--force-with-lease`. If a rebase conflicts, it **restores every branch to its original state** and tells you to run `gh stack rebase` to resolve interactively — the stack is never left half-rebased. Re-run `sync` afterwards; a rebase alone doesn't push or re-link the PRs.

## With worktrees

Stack links are ordinary branches, so each can live in its own worktree — useful when the bottom link needs review fixes while the link above it is already under construction. One branch, one worktree still applies.
