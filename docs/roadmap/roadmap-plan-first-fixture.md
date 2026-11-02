# Scenario fixture — roadmap dispatch trace

You are testing a skill, not doing real work. **Do not dispatch any subagent, run any build, or edit any file
other than the one output file named in your task.**

## Your role

You are the **orchestrator** (the main agent) of a `roadmap` run. Read `skills/roadmap/SKILL.md` and every file
it tells you to read (relative paths resolve against `skills/roadmap/`). Follow that skill exactly as written for
the project below. Where the skill leaves a choice to you, make it and keep going.

## The project (it does not exist on disk — use only what is written here)

- Java 21, Gradle multi-module repo `claims`, modules `core` and `offer`. Git repo, clean tree on `main`.
- `CLAUDE.md` names the gate command: `./gradlew :core:test :offer:test` (about 3 minutes).
- The approved block is an audit report, `docs/reviews/2026-07-01-dialect.md`, with four approved findings:

| Finding | Change | Files |
|---|---|---|
| F1 | Add `String getTemporalValidFromColumn()` to the `DatabaseDialect` interface and both implementations | `core/src/main/java/claims/dialect/DatabaseDialect.java`, `core/src/main/java/claims/dialect/SqlServerDialect.java`, `core/src/main/java/claims/dialect/PostgresDialect.java`, `core/src/test/groovy/claims/dialect/DialectSpec.groovy` |
| F2 | Transaction DAOs call `getTemporalValidFromColumn()` instead of the hard-coded column | `core/src/main/java/claims/dao/transaction/MasterTransactionDao.java`, `core/src/main/java/claims/dao/transaction/MasterTransactionApprovalDao.java`, `core/src/test/groovy/claims/dao/transaction/MasterTransactionDaoSpec.groovy`, `core/src/test/groovy/claims/dao/transaction/MasterTransactionApprovalDaoSpec.groovy` |
| F3 | `AmountSetDao` calls `getTemporalValidFromColumn()` | `core/src/main/java/claims/dao/amountset/AmountSetDao.java`, `core/src/test/groovy/claims/dao/amountset/AmountSetDaoSpec.groovy` |
| F4 | `OfferDao` calls `getTemporalValidFromColumn()` | `offer/src/main/java/claims/offer/dao/OfferDao.java`, `offer/src/test/groovy/claims/offer/dao/OfferDaoSpec.groovy` |

## Assume every outcome is the happy path

- The user answers **yes** to any approval question.
- Every grounding report confirms the file lists above exactly and finds no other file to touch.
- F2, F3 and F4 each need F1's `getTemporalValidFromColumn()`. Nothing else crosses findings.
- Every reviewer passes every plan on the first round.
- Every implementer reports DONE with no signature changes. Every gate run is green.

## Output

Write the trace to the output file named in your task: **one line per response** you, the orchestrator, would
send, from the moment the skill is loaded until the run ships. Count only tool calls; leave out your prose.

```
R<n>: <tool>*<count> (<verb>)[, <tool>*<count> (<verb>)]...
```

- `<tool>` is one of: `ask`, `bash` (only the gate command, which Step 6 has you run yourself), `git` (git
  commands you run yourself), `manage_todo_list`, `explore`, `researcher`, `reviewer`, `general` (each a
  `subagent` call with that `agentName`), or `skill` (loading another skill such as `review` or `finish`).
  The baseline is a child (`explore`, verb `gate`), not a command you run.
- `<count>` is how many calls of that tool that one response contains.
- `<verb>` is exactly one of: `ask`, `ground`, `plan`, `vet`, `implement`, `gate`, `fix`, `commit`, `track`,
  `ship`.
- Group several tools in one line only if the skill has you emit them **in the same response**.

Example of the format only (not of the answer): `R7: git*2 (commit), manage_todo_list*1 (track)`

After the trace, add a section `## Notes` with at most five lines naming any instruction in the skill you found
ambiguous and the choice you made.
