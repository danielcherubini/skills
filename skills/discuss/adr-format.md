# Decision Format

Decisions live in `docs/decisions/` and use sequential numbering: `0001-slug.md`, `0002-slug.md`, etc.

Create the `docs/decisions/` directory lazily — only when the first decision is needed.

## Template

```md
---
status: accepted
date: YYYY-MM-DD
superseded-by:
---

# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

That's it. A decision can be a single paragraph. The value is in recording *that* a decision was made and *why* — not in filling out sections.

## Optional Sections

Only include these when they add genuine value. Most decisions won't need them.

- **Considered Options** — only when the rejected alternatives are worth remembering
- **Consequences** — only when non-obvious downstream effects need calling out

## Rules

- `docs/decisions/` is **append-only** — never edit a merged decision's body
- To change course, add a new decision and set the old one's `superseded-by:` field
- `status` is `accepted` or `superseded` — nothing else

## Numbering

Scan `docs/decisions/` for the highest existing number and increment by one.

## When to Write an ADR

All three of these must be true:

1. **Hard to reverse** — the cost of changing our mind later is meaningful
2. **Surprising without context** — a future reader would look at the code and wonder "why?"
3. **A real trade-off** — there were genuine alternatives and we picked one for specific reasons

If a decision is easy to reverse, skip it. If it's not surprising, nobody will wonder why. If there was no real alternative, there's nothing to record beyond "we did the obvious thing."

## What Qualifies

- **Architectural shape** — "We're using a monorepo." "The write model is event-sourced."
- **Integration patterns** — "Services communicate via domain events, not synchronous HTTP."
- **Technology choices with lock-in** — Database, message bus, auth provider. Not every library — just the ones that would take significant time to swap out.
- **Boundary and scope decisions** — "Customer data is owned by one module; others reference by ID only."
- **Deliberate deviations from the obvious** — Anything where a reasonable reader would assume the opposite.
- **Constraints not visible in code** — Compliance requirements, SLA contracts, partner limitations.
- **Rejected alternatives when the rejection is non-obvious** — If you considered X and picked Y for subtle reasons, record it.
