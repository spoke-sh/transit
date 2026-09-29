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

## Admission and execution

Compile and validate the plan before submission, with explicit operation and
resource budgets. Query admission is separate from execution and complete result
publication. Current source permission is checked independently from requester
ownership or a gateway's own credential.

The qualified requester has one active query. Retained queries and results can
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
