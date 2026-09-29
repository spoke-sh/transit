# Tables and materialization

A Station Table is typed application state over one durable resource. A fenced
writer commits row changes with input progress and outputs. Readers use current
authorization and an explicit source/revision basis; a Table handle is not a
permission or an independent database connection.

## Mutation and visibility

Table helpers encode schema-aware values into the resource's key/value model.
Validate column types and operation budgets before proposing a batch. Accepted
mutations within one turn become visible together with its consumed input and
outputs. A failed proposal cannot expose half the batch.

The underlying one-mutated-resource boundary remains. Multiple Table helpers
or independently captured sources do not create a multi-resource transaction or
global snapshot. Larger changes require an explicit publication/workflow contract,
not silently splitting one promised atomic batch across turns.

Legacy Table APIs retain their fixed bounds. Growing APIs access retained rows
and framework records through bounded pages. Use the selected package API and
authority capabilities; no implicit migration upgrades older state.

## Materialize a stream

An application can consume mailbox input, update its Table and advance input
progress in the same turn. After recovery it resumes from accepted progress;
it must not apply an already consumed input again under a fresh identity.
Domain event decoding, validation and aggregation belong in that application.

Backlog stays durable when a worker is slow. Bound each batch and page, retain
control capacity and expose blocked progress. Retention does not become finite
because a materialization falls behind. Current rows can outlive old input
history when a validated checkpoint preserves recovery.

## Query and observe

The finite v1 Table query profile has a declared int64 key and nullable scalar
value. Unified v2 adds wider declared schemas/source adapters, not unrestricted
SQL. Source revision and data watermark have different meanings: data progress
can exclude framework bookkeeping writes. A reply must identify the basis it
actually used.

[SQL](sql.md) compiles into typed Fuze plans. Results use bounded Arrow batches
with complete-result verification; an initial page is not the whole result.
[Reactive watches](reactive.md) currently qualify int64 Table notifications and
exact snapshot refresh, not arbitrary continuous materialized SQL.

For APIs use [Station](../../packages/zig/transit-station/README.md) and the
[query host](../../apps/transit-query-host/README.md). Exact contracts are
[Tables v1](../../contracts/STATION_V1.md),
[query v1](../../contracts/PUBLIC_QUERY_V1.md) and
[query v2](../../contracts/STATION_QUERY_V2.md). [State](state.md),
[queries](queries.md) and [Arrow](arrow.md) explain shared lifetime rules.
