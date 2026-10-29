# Table transaction qualification

The question is whether one local Catalog can preserve a common Table cut,
provisional statements and one original decision across failure and caller loss.
Current semantics belong to the [transaction reference](../../handbook/reference/sql/transactions.md),
[SQL session contract](../../../contracts/SQL_SESSION_V1.md) and
[direct Table contract](../../../contracts/DIRECT_TABLE_V1.md). This record keeps
finite models, component recovery and installed histories separate.

## Finite safety models — 2026-10-28

At base `ae19b4e7931bd0d3c9793e10363f7ed3ef771592` with implementation changes
present, `just test::table-transaction-model` exhausted five finite two-transaction,
two-Table programs and detected all seven intended missing-guard controls.
The model sources were unchanged from that commit. Distinct states were 18,706
(write skew), 22,315 (publication), 25,114 (savepoint), 19,850 (private reads) and
36,378 (competing barriers). `just test::transaction-decision-model` exhausted
3,227 states and detected its six intended controls.

The pinned TLC used one worker, seed 1, fingerprint 0 and a 512 MiB heap, with a
60-second limit per configuration. Every positive configuration exhausted its
queue. Every negative run ended with the named invariant and a complete recognized
trace; timeout, compilation and malformed output are failures. These are safety
checks without fairness or eventual-completion assumptions.

Raw source hashes, commands, configurations, state counts and counterexamples
remain in `.cache/verification/table-transaction-model/20261028T212857-1617337/`
and `.cache/verification/transaction-decision-model/20261028T212858-1617334/`.
The Table specification SHA-256 is
`baa2478fc9c9c45204e33ffb416903d62187fe49998b6cbafbfbfcb7b6a9a8a8`.
The [model guide](../../../tests/verification/models/README.md#finite-local-table-transaction-model)
states symbolic-value, program, storage and failure assumptions. These runs are
not automatic production trace replay or a refinement proof.

## Integration failures retained during implementation

The initial installed gateway build failed because the console did not handle
the provisional command variant. After adding the shared outcome presentation,
the next run rejected BEGIN with `ClientTokenBudget`: SQL used the ordinary
reference reservation rather than the transaction caller-record reservation.
The following run reached BEGIN and rejected private UPDATE with
`InvalidTableStatementIntent`. Private predicate work needed its virtual evaluator
frontier, independently of the retained public source position. The fix also
selects bulk staging for private INSERT and retains workspace revision checks on
repeated buffered disclosure.

These failures remain failures. Logs are `.cache/m5-installed-transactions-first.log`,
`.cache/m5-installed-transactions-second.log` and
`.cache/m5-installed-transactions-third.log`. The failed installations are retained
privately; their credentials and raw configuration are not published. The focused
predicate-write regression then passed UPDATE, paged savepoint rollback and DELETE
against the original private row, including explicit completion of rollback.
The first isolated SDK build also failed because new source files were untracked
and omitted from its source closure; the tracked-source rerun passed. These
development observations do not substitute for committed-source qualification.

## Reproducible boundaries

`just test::sql-transactions` runs the independent HTTPS client and actual
PostgreSQL/MySQL clients against a disk-backed local node and SQL gateway. Its
finite histories cover original command identities, private cuts, savepoints,
decisions, gateway replacement, anomaly refusals and the executable three-Table
checkpoint/outbox example. It prints source provenance and command timings;
process replacement is distinct from host power loss. The application-owned fake
dispatcher tests denied/replay gates and an unknown remote result, not a real
connector or exactly-once execution.

The Catalog `transaction` test filter covers paged acquisition, bounded temporary
memory, aggregate reservations, original outcomes, retained roots, savepoints,
partial preparation/publication and disk reopen at injected lost-reply boundaries.
The storage transaction tests independently check the decision journal and Table
barriers. Current definitions, policy and ownership are required by the actual
owners. A successful finite history cannot establish arbitrary distributed
atomicity, unbounded concurrency, fine-grained predicate locking, automatic
transaction expiry or implementation refinement. Native KV/Document/Stream/Queue
participation and Station turn migration remain excluded from this Table profile.
