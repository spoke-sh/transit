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

## Installed Table profile — 2026-10-28

The complete `zig build test-sql-wire-gateway -Doptimize=ReleaseSafe -- transactions`
run passed under the pinned `sql-wire` shell at committed source
`71badbc3c5fc3d61235cb388b6944fc59c2866ad`. Its source was clean at fixture start and completion.
The configuration event records all seven executable hashes and the locked
Python/Zig/toolchain identities. Raw output is `.cache/m5-installed-current.log`;
`.cache/m5-verification-manifest.json` attributes the accompanying check logs.

The independent HTTPS client checked two-Table private reads and joins,
provisional counts, original statement retries after savepoint rollback, common
commit publication and two lost commit replies. A cancelled wait after the
recorded decision returned that decision. Competing transactions could not both
consume the other's old balance. Absent-key inserts, predicate phantoms,
ASCII_CI matches and concurrent DDL rejected the conflicting commit. Keyless
duplicate occurrences survived private mutation and rollback distinctly.

Read-only snapshots survived later commits. Gateway replacement required explicit
original-handle attachment. Revocation denied buffered repeats and COMMIT without
manufacturing an abort; an authorized rollback closed the original lifetime.
Another attachment's savepoint invalidated a retained final batch. The 40-row
private result crossed two wire batches with a delayed consumer and concurrent
public update without changing its basis. Session expiry preserved accepted
private rows for reattachment and rollback. Fixed statement/savepoint limits
refused excess SQL work while explicit cleanup remained available. DDL inside a
transaction refused without an implicit commit.

Actual PostgreSQL clients observed I/T/E state and duplicate-key failure;
MySQL observed IN_TRANS and rollback. The real console executed a TLS script
with provisional counts/rows, savepoint rollback, full rollback and read-only
commit. The three-Table example published data, checkpoint and intent together;
exact retry recovered its lost commit reply, aborted intent stayed invisible,
and the fake dispatcher preserved unknown external outcome and denied/replay gates.

The run printed 93 native command samples. Across that heterogeneous sequential
history, elapsed command time ranged from 29.603 to 7838.420 ms with median
2235.751 ms. These include durable control work and retries; they are not
isolated throughput, tail-latency or contention benchmarks. A quarter-second
read-only observer recorded 1559 samples, peak summed direct-child RSS of
776944 KiB and gateway high-water RSS of
667148 KiB across incarnations. Raw observations are
`.cache/m5-installed-resources.json`; its observer hash and limitations are retained.
The process measurements include runtime/provider capacity beyond the 16 MiB
per-transaction temporary allowance. They do not prove zero steady-state allocation.

## Component, correspondence and compatibility checks

The committed Catalog transaction filter passed 36 tests; storage transaction
checks passed 14. The common-cut regression uses disk-backed WAL and objects,
flush, compaction and Catalog reopen, preserving the logical frontier and old
WAL-inclusive cut. Quota refusal preserves pending private work; explicit abort
releases that transaction's reservation without public rows. Other histories
inject loss during preparation, decision and publication, retain original
outcomes across reopen, refuse unavailable prepared data and check paged graph
reachability. These component faults are separate from installed gateway death.

After integrating main's correspondence checks, the decision model again exhausted
3,227 states and replayed six negative controls through Zig. The workspace model
exhausted 304 states and replayed eight controls; the storage lifecycle and resident
owner models exhausted 1,200 and 149 states and replayed six and five controls.
Raw runs are `.cache/verification/transaction-decision-model/20261028T215740-1946614/`,
`.cache/verification/transaction-workspace-model/20261028T215834-1953118/`,
`.cache/verification/storage-lifecycle-model/20261029T050025-1970609/` and
`.cache/verification/resident-owner-cache-model/20261029T050032-1973401/`.
The workspace run used base `6e11bd4c4` with its adapter revision change present;
that adapter is committed in `806372169`. The storage/cache runs used committed
`810694f73`. They replay selected model counterexamples, not every production
history or a refinement theorem. The initial workspace/storage adapter builds
failed because the newly required private revision was absent; those failures
remain in `.cache/m5-workspace-model.log` and `.cache/m5-storage-lifecycle-model.log`.

All seven SQL packages, 74 protocol tests, 17 direct-query tests, the signed native
host controls, isolated Zig SDK application and Board checks passed. The grammar
suite passed 479 cases and 697 coverage obligations. Clean checkouts of
`810694f73` passed all 47 fast and 18 contract checks; reports are under
`.cache/ci/clean/810694f73516-transit-ci-jnl2vfh5/` and
`.cache/ci/clean/810694f73516-transit-ci-yzqgl3qd/`. Subsequent changes to the
installed driver added the console history without changing those library or
contract sources. No whole-CI, all-language SDK or distributed deployment pass
is inferred from these selected checks.

The exploratory debug installation reached buffered revocation and failed because
its fixture expected `AuthorityUnavailable` instead of the correct `AccessDenied`.
`.cache/m5-debug-transactions.log` preserves that failed run. The final installed
run above used the corrected exact denial assertion. No failed or skipped history
is counted as success.

The first release-mode run completed the console, anomaly, outbox, delayed-reader
and session-expiry histories, then rejected a fixture restart with
`GatewayConfigurationChanged`. It had attempted to replace the immutable execution
limits of an accepted account. The corrected schedule provisions a distinct
limited account instead of weakening that guard. The failed run remains in
`.cache/m5-installed-configuration-refusal.log`; it is not counted as a completed
installed pass. A focused recovery of that retained installation confirmed the
new account's fixed-limit refusals and explicit rollback before the full rerun.

## Closeout integration and diagnostic correction

Main through `5ae56029d` was integrated in `c28da17ef`, preserving the new gateway
architecture handoff and milestone numbering. The installed pass above predates
that merge and is not relabeled as a run of the final branch.

Final review found that a rejected ROLLBACK against an already committed decision
used serialization-abort SQLSTATE `40001`. Commit `71d478ff7` instead returns
`25000` with the known committed outcome, while a confirmed aborted COMMIT keeps
`40001`. The SQL service package passed all ten tests, including the two decision
outcomes, with that correction present. The first diagnostic build accessed the
nested decision incorrectly and failed compilation; its raw failure is
`.cache/m5-decision-diagnostic-first.log`. The corrected package run is
`.cache/m5-decision-diagnostic.log`. The full installed history was not repeated
for this diagnostic-only change.

The first closeout documentation run found the new transaction reference missing
from the site catalog and a delivery-plan label inherited in the verification
reference. The first fast run also found a handoff link missing its dated anchor.
Those failed runs remain in `.cache/m5-closeout-docs-first.log` and
`.cache/m5-closeout-fast.log`; they do not establish completed validation.

The installed output SHA-256 is
`49ce3f50e4a2afa446a68c2e17e4294434d2dbe3fcb99687c8a50c560ac7ef0a`.
The resource observation SHA-256 is
`9c6f96f6c274942c6bf0ef6026efc26ca0696984267dedcc6d170baabdf096e5`.
The corrected diagnostic test output SHA-256 is
`446eb1bfba0e7c579d72b42e3e686a5cba2419e4e81d2388c1cd17d7d003b665`.
These hashes attribute the ignored raw outputs; no credentials or generated
per-run archive is added to Git.
