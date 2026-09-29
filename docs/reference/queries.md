# Query execution and result recovery

Fuze is Transit's Zig-native finite query engine. SQL and native callers lower
to the same typed plans. Source adapters acquire authorized data; query execution
does not acquire kernel authority or raw storage credentials. Neither DataFusion
nor Acero is a runtime dependency.

## Source profiles

| Profile | Source and value model |
| --- | --- |
| Table v1 | One declared Table with int64 key and nullable scalar value; public plan bounded to 207 encoded bytes |
| Unified v2 | One explicit KV decoder, Table schema or accepted Document projection; one to eight declared columns and finite budgeted plan upload |

KV bytes need an explicitly selected decoder. Document projections read accepted
state, not tentative edits. A declaration fixes names, types and identity; SQL
cannot discover or grant access to an undeclared source. The v2 cell model keeps
value, null, missing, type error and conflict distinct through Arrow and language
bindings. Do not coerce missing/conflict into null or a successful empty result.

Each captured source basis names the resource/revision and contract/schema it
actually read. This is not a cross-resource transaction, global snapshot or
promise of an arbitrary historical `AS OF` query. Preserve source evidence with
the result and disclose it in interfaces.

A source snapshot, a storage checkpoint and query progress serve different
purposes. Immutable state roots let a reader keep one data version. Storage
checkpoints preserve recovery evidence; Document checkpoints also preserve the
accepted materialization and its causal/history rules. A captured query records
its own progress and result publications so execution and exact result recovery
can survive worker loss. Having a source snapshot does not remove that query
protocol work.

## Admission and execution

Compile and validate the plan before submission, with explicit operation and
resource budgets. Query admission is separate from execution and complete result
publication. Current source permission is checked independently from requester
ownership or a gateway's own credential.

The console's unified v2 SQL path uses durable captured queries. The requester
uploads and seals the plan bundle, then makes a durable source call. The source
retains a read version, stages Arrow segments through bounded Publication turns,
publishes a complete manifest and returns its reference through the original
reply route. Even an empty result carries its schema and completion evidence.
Source rows remain unchanged by a SELECT, but query bookkeeping and result
publication write durable state. There is no separate console execution profile
that streams a snapshot result without this captured-query lifecycle.

Each requester runs one active query. Retained queries and results can
grow on disk without loading their complete history into memory. Work is bounded
by pages, operators, batches, upload and active execution; omitting SQL `LIMIT`
does not authorize unbounded resident memory or silently truncate the answer.

Growing delivery uses durable immutable segments and receiver-issued credit.
Digests, ordered segment coverage and the complete manifest establish a result.
A decoded page, transport success or initial status alone cannot establish the
whole answer. See [stream flow control](streams.md#flow-control).

## Recovery and display

Save the exact query submission/recovery identity when the interface supports
it. A lost response may follow admission; a fresh namespace or operation creates
new work. Poll status, resume the same query and read only according to its
completion contract. Preserve denial, incomplete, unknown and terminal outcomes
as separate states.

Paged displays keep one result identity. Verify completeness with bounded memory
and reread the visible page under current permission. Old result references do
not retain grants, extend released pins or reopen expired history. Closing a UI
does not erase accepted queries. Refresh is a new finite query under the
[reactive](reactive.md) budget and coverage rules.

Use the [SQL reference](sql.md), [query compatibility matrix](../../packages/zig/transit-query/docs/compatibility.md)
and [Fuze package](../../packages/zig/transit-fuze/README.md) for exact types,
operators and errors. The [public v1 contract](../../contracts/PUBLIC_QUERY_V1.md),
[growing delivery contract](../../contracts/STATION_QUERY_V2.md) and
[unified v2 contract](../../contracts/UNIFIED_QUERY_V2.md) own wire details.
Joins, general sorting, arbitrary writes and continuous SQL remain unsupported.

## Planned interactive sessions

The selected console design opens a fresh query session and source snapshot for
each SELECT. Completion releases that session; console exit cancels its active
query. Reconnecting does not resume a previous interactive SELECT. This changes
interactive query recovery, not the durability of accepted application state.
Existing callers explicitly requesting durable captured jobs keep their recovery
contract. A session does not require a new durable PID or principal.

This profile is not implemented. Today's console uses the durable path described
above, including saved recovery intent; exit does not cancel accepted work.
Before changing it, a shared neutral contract must define:

- One explicit source basis per session, bounded plan/buffers/cursor/pins and
  current authorization before disclosure. It is not a global snapshot.
- Idempotent cancellation and a defined completion/cancellation race, with
  bounded acknowledgement and reserved control capacity.
- A server-enforced lease or deadline for cleanup after a killed client or broken
  connection; cleanup cannot depend on a final packet from the console.
- Complete, failed and canceled result framing. A visible prefix cannot become
  a successful complete answer when the session fails.
- Release on completion/cancellation/expiry, with bounded snapshot accounting.
  Shared verified immutable bytes may be cached, but cached bytes never retain
  permission or resume a previous query.

The aim is authorized snapshot acquisition and bounded Arrow streaming without
durable execution progress and result writes per small interactive fragment.
[Workload priorities](workloads.md) and [measured costs](performance.md) explain
the rationale and the shared storage work needed alongside this lifecycle.
