# 4. SQL statement results and client consumption

[Roadmap](README.md) · **Status:** Planned

Let a caller execute a statement and inspect one authoritative command outcome
or consume one logical typed result set, independently of storage pages, execution
vectors and transport batches. SELECT, SHOW, DESCRIBE and EXPLAIN share the result
lifecycle. A console displays a bounded view of that relation with explicit
coverage; applications can stream it without collecting the entire result.

## Prerequisites and scope

Follow the [live storage and SQL cutover](03-live-storage-and-sql-cutover.md),
consuming the catalog/snapshot and reader ownership contracts from
[data lifecycle](01-declarative-data-lifecycle.md) and
[storage/query performance](02-storage-and-query-performance.md). Contract work
and bounded batching improvements can proceed alongside that cutover; they do
not require every provider or codec to finish. Existing cutover obligations for
safe bounded reads remain with their owner.

The approved [early integration handoff](03-live-storage-and-sql-cutover.md#early-integration-pr-and-statement-result-handoff)
separates that dependency from completion of the entire storage milestone. Start
implementation from the merged early PR, which qualifies installed direct SQL,
automatic point flushing, lazy schema projection over mixed WAL/segment data and
single-executable startup through ordinary `transit server` / `transit console`.
Automatic archive/collection, further reader performance work, storage inspection
and final storage qualification remain with the storage owner. Coordinate shared
reader lifetime/inspection changes and any replacement of the current definition
across both branches; do not introduce parallel compatibility definitions.

The [SQL session contract](../../contracts/SQL_SESSION_V1.md),
[query semantics](../handbook/reference/queries.md),
[shared SQL service](../../packages/zig/transit-sql/README.md) and
[shared SQL client](../../packages/zig/transit-sql-client/README.md) are the
starting owners. Coordinate with the existing acceptance/compatibility work
([#111](https://github.com/spoke-sh/transit/issues/111),
[#112](https://github.com/spoke-sh/transit/issues/112)), catalog snapshots
([#125](https://github.com/spoke-sh/transit/issues/125)), encoded reader lifetimes
([#128](https://github.com/spoke-sh/transit/issues/128)) and read amplification
([#76](https://github.com/spoke-sh/transit/issues/76)).

Review at source `94335c2a` confirms the gap described by the local
`result_set.txt` discussion, with two delivered improvements preserved:
[Console](../../apps/transit-cli/Console.zig) suppresses an empty terminal table
after earlier rows, and the shared client already supplies `Pending` settlement.
The console still owns fetch iteration and renders transport batches in slices;
[Session.Read](../../packages/zig/transit-sql/src/Session.zig) still emits one row
for several read variants, while
[ReadBatch](../../packages/zig/transit-sql/src/ReadBatch.zig) inherits the Table
batch limit. The transcript is diagnosis, not a current contract or measurement.
Its SHA-256 is
`b8ab0e6bf526a8c545129759ef027057d79aceda7879ddb0595f4cab895c5f2c`;
this plan is self-contained and does not require that local file.

Coordinate the [transaction contract](05-transactions-and-atomic-composition.md)
before freezing statement outcomes. A statement may complete within an open
transaction while its changes and counts remain provisional until commit.
Define transaction/basis attribution and cursor lifetime hooks here; milestone 5
implements transaction sessions and proves their commit/rollback interactions.
This does not make executable transactions a prerequisite for the autocommit
result-reader delivery.

## Delivery sequence

1. **Define shared statement outcomes before adapters.** Formalize command
   completion with owner-supplied command kind and matched/changed counts, and
   row-returning results with one logical schema, typed rows, terminal outcome,
   verified row count and observation basis. Define count meaning per command;
   renderers cannot infer it from SQL text. Keep durable acceptance, pending
   execution, statement completion and result delivery distinct. Interactive
   callers obtain the outcome without operating a separate job workflow.
2. **Define result identity, sequencing and evidence.** Preserve exact fetch
   acknowledgement/repetition, schema validation and one original source basis.
   Align data results with the owning exact definitions and snapshot cuts as
   those contracts land. Define catalog/settings observation evidence separately;
   metadata inspection does not acquire a fictional data snapshot. An independent
   source vector is not an atomic snapshot, and a descriptor is not a retention
   pin. Missing completion, EOF, cancellation and failure leave an incomplete
   prefix. Never restart a SELECT and splice in rows from another cut.
3. **Fill bounded server batches across read variants.** Keep storage pages,
   Fuze vectors, wire batches and display windows independently budgeted. Give
   batches explicit row/byte limits and owned or borrowed lifetimes; rows collected
   across iterator calls cannot alias reset scratch memory. Cover Table,
   relational, inspection, settings, probe, source and captured reads. Mark the
   final data batch complete when exhaustion is known without unbounded lookahead;
   a necessary empty terminal batch remains valid completion evidence, never a
   second result. Recheck current authority after buffering and before disclosure,
   including repeated batches, schema, empty results and terminal counts.
4. **Own consumption and settlement in `transit-sql-client`.** Provide a shared
   result reader owning schema decoding, cursor sequencing, batch lifetimes,
   completion evidence and deterministic cleanup on exhaustion, early close or
   failure, backed by server leases after lost cleanup. Offer bounded streaming
   and optional bounded materialization/windows. Evolve the existing `Pending`
   helper under the shared contract: retain the original accepted identity,
   finite settlement budgets and explicit unresolved outcomes. Specify
   cancellation racing with completion; stopping a wait does not roll back work.
   Accepted-work execution and recovery remain service responsibilities.
5. **Migrate presentation and existing adapters together.** Render one logical
   result or explicitly limited display window with consistent schema/widths;
   transport chunk boundaries do not start new tables. Preserve streaming JSON,
   exact wide integers/decimals and five-state cells. Display/memory limits cannot
   imply query completion or require unbounded accumulation for column widths.
   Migrate native SQL messages, PostgreSQL/MySQL adapters and existing consumers
   affected by the contract; later [SDK coverage](13-service-and-sdk-coverage.md)
   and [published resources](20-published-resources-and-investigations.md) reuse
   it. No console-only result protocol is introduced.
6. **Apply the current-v1 cutover and publish the contract.** Replace the shared
   definition on incompatible changes, regenerate schemas/bindings/fixtures and
   preserve rejection of missing/foreign definitions. Update the SQL/query
   references, client/component guides and proof ledger together. Broader
   cross-call investigation retention, continuous queries and new foreign
   sources remain with their later owners.

[Client-foundation work](06-client-foundation-and-language-apis.md) composes this result reader
and settlement contract into language-native direct clients and mixed Station
applications. It does not define a second result lifecycle or defer this
milestone's shared-client and existing-consumer obligations.

## Completion evidence

Use actual native sessions, installed console callers and affected database
adapters, with independent typed row/count/basis oracles. Prove empty, single-row,
multi-batch and exact-boundary results for SELECT and metadata statements, plus
command matched/changed counts. Include variable-width/nested values whose
iterator scratch storage is overwritten on the next pull, oversized-row budget
failure, early close, slow consumers and results beyond resident memory.

Exercise revocation after buffering and on repeated/empty/terminal responses,
schema or cursor inconsistency, lost fetch replies, transport EOF, session
expiry/restart, incomplete prefixes, display truncation and cancellation racing
with write completion. Verify original-token recovery without new SQL dispatch.
Measure fetches, authority/provider calls, bytes, latency and peak resident memory
for SHOW/DESCRIBE and representative Table/relational queries under matched
controls. Reduced amplification cannot weaken disclosure checks or result truth.

Component checks alone do not complete this milestone. Record end-to-end outcomes
in the [proof ledger](../history/qualification/README.md); this planning change establishes no
new result API or executed runtime guarantee.
