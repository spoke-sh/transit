# Query execution and result recovery

Fuze is Transit's Zig-native finite query engine. SQL and native callers lower
to the same typed plans. Source adapters acquire authorized data; query execution
does not acquire kernel authority or raw storage credentials. Neither DataFusion
nor Acero is a runtime dependency.

## Source declarations

A query selects one explicit KV decoder, Table schema or accepted Document
projection, with one to eight declared columns and finite execution budgets.
Durable callers upload the finite plan bundle through bounded commands.
Flight exposes a Table subset with primitive int64 output; the adapter verifies
captured query cells before conversion.

KV bytes need an explicitly selected decoder. Document projections read accepted
state, not tentative edits. A declaration fixes names, types and identity; SQL
cannot discover or grant access to an undeclared source. The query cell model keeps
value, null, missing, type error and conflict distinct through Arrow and language
bindings. Do not coerce missing/conflict into null or a successful empty result.

Native query transports do not admit CSV/JSONL sources. Fuze's local Zig
[file-source API](../../packages/zig/transit-fuze/docs/file-sources.md) supports
bounded discovery/decoding over host-authorized immutable bytes; it does not
acquire files or create a durable query job. The
local [file-query command](../../apps/transit-cli/docs/file-query.md) explicitly
captures regular files, gzip or stdin and executes finite SQL against those bytes.
It returns provisional logical JSON rows followed by verified completion; it
does not use native durable acceptance. The
[type and discovery reference](sql/types.md#schema-discovery-and-binding) describes
frozen file bindings, exact logical types and each interface's admission limits.

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

Native typed plans and the shared native/port codec accept Boolean predicate
programs with up to 64 instructions. They retain null/missing as unknown,
evaluate atoms eagerly in instruction order, and select only true. A determining
Boolean operand does not suppress an evaluated type error or conflict. Programs
share the finite plan's byte budget and continuation identity. Native SQL lowers
NOT, AND, OR and grouping to these programs. All ten SDKs expose typed program
constructors and inspected programs. Local file-query plans accept one comparison
or state predicate;
the [query contract](../../contracts/UNIFIED_QUERY_V1.md#typed-expressions-and-results)
defines the native program representation and ownership.

## Admission and execution

Compile and validate the plan before submission, with explicit operation and
resource budgets. Query admission is separate from execution and complete result
publication. Current source permission is checked independently from requester
ownership or a gateway's own credential.

Explicit durable queries use the query v1 captured-query path. The requester
uploads and seals the plan bundle, then makes a durable source call. The source
retains a read version, stages Arrow segments through bounded Publication turns,
publishes a complete manifest and returns its reference through the original
reply route. Even an empty result carries its schema and completion evidence.
Source rows remain unchanged by a SELECT, but query bookkeeping and result
publication write durable state. The console defaults to the separate interactive
session profile below; explicit durable callers retain this recovery contract.

Each durable requester runs one active query. Retained queries and results can
grow on disk without loading their complete history into memory. Work is bounded
by pages, operators, batches, upload and active execution; omitting SQL `LIMIT`
does not authorize unbounded resident memory or silently truncate the answer.

Growing delivery uses durable immutable segments and receiver-issued credit.
Digests, ordered segment coverage and the complete manifest establish a result.
A decoded page, transport success or initial status alone cannot establish the
whole answer. See [stream flow control](streams.md#flow-control).

## Finite draft evaluation

A Table workspace can explicitly open a draft generation with one to eight
evaluation intents. The generation freezes its source contract and page, segment
and result-byte limits. While enabled, complete valid edits can admit finite
queries; the browser coalesces edits and retains one accepted query at a time.
Partial SQL and speculative alternatives are not executed. KV and Document draft
evaluation are unsupported.

Admission atomically records an intent with the query's existing call identity.
Retries, edits, reloads and reconnects do not reset the budget; cancellation or
later failure does not refund it. Pause and close stop new scheduling while
accepted work keeps its independent exact recovery and cancellation semantics.
Current authority and source compatibility still apply. The
[draft contract](../../contracts/QUERY_DRAFT_V1.md) owns the wire and generation
rules; [Board's controls](../../apps/transit-board/docs/reactive.md#evaluate-edited-drafts)
explain browser enable, pause and saved recovery.

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
operators and errors. The [delivery contract](../../contracts/STATION_QUERY_V1.md) and
[query v1 contract](../../contracts/UNIFIED_QUERY_V1.md) own wire details.
Joins, general sorting, arbitrary writes and continuous SQL remain unsupported.

## Relational boundary

COUNT and checked int64 SUM aggregate the selected rows of one declared source.
They do not provide grouping or multi-source aggregation. Each query has one
resource cut; there is no source-vector consistency mode, JOIN or GROUP BY
execution contract. Querying two resources separately does not establish an
atomic shared snapshot. Current Table notifications support finite refresh,
not a complete update/delete stream for maintaining a join.

SUM checks overflow in source order, including across pages. Reordering inputs
or combining partition totals can change whether it fails; no parallel reduction
or optimizer rewrite is implied. Worker replacement preserves accepted query
identity and its retained basis within the captured profile, without providing
automatic operator repartitioning. The
[query reasoning](../internals/query-engine.md#relational-correctness-and-data-movement)
explains why source consistency, multiplicity, arithmetic and complete coverage
must be specified together when extending this boundary.

## Interactive sessions

Selective Table queries use the ordered primary-key index: equality reads one
key, lower bounds seek, and upper bounds stop the scan. The original Fuze
predicate still determines matching rows. Comparisons on the value column and
`!=` and compound native predicates retain the general bounded scan. Persistent Arrow storage blocks are
separate from the native Arrow batches used for execution and presentation.

The [interactive query contract](../../contracts/INTERACTIVE_QUERY_V1.md) defines
the leased snapshot, cancellation and bounded output boundary.

The console opens a fresh query session and source snapshot for
each SELECT. Completion releases that session; console exit cancels its active
query. Reconnecting does not resume a previous interactive SELECT. This changes
interactive query recovery, not the durability of accepted application state.
Existing callers explicitly requesting durable captured jobs keep their recovery
contract. A session does not require a new durable PID or principal.

Fuze executes in the client over signed native snapshot reads. The authority
does not execute SQL. There are no durable upload, execution-progress or result
publication turns in this profile. Table, KV and Document share the existing
finite compiler, source adapters and Arrow codecs. The contract provides:

- One explicit source basis per session, bounded plan/buffers/cursor/pins and
  current authorization before disclosure. It is not a global snapshot.
- Idempotent release and a defined completion/cancellation race. Release needs
  no new snapshot slot or durable journal admission; failed acknowledgements
  fall back to the lease.
- A server-enforced lease or deadline for cleanup after a killed client or broken
  connection; cleanup cannot depend on a final packet from the console.
- Complete, failed and canceled result framing. A visible prefix cannot become
  a successful complete answer when the session fails.
- Release on completion/cancellation/expiry, with bounded snapshot accounting.
  Shared verified immutable bytes may be cached, but cached bytes never retain
  permission or resume a previous query.

The authority admits 64 active snapshot slots, at most eight per principal.
Each has a renewable 60-second lease and a five-minute hard lifetime. Expired
slots are reclaimed on bounded snapshot operations, and restart invalidates
tokens. These limits apply to snapshot bookkeeping, not underlying data retention.
Client computation stops with the process. A failed release falls back to lease
expiry. Current grants, principal epoch and source liveness still gate reads.

With native `snapshot_read`, acquisition combines source/requester metadata,
the fresh cut and initial data. Final current validation can release the snapshot
in the same request. Captured reads and current metadata have explicit separate
bases; a write during data acquisition does not require recapturing the source.
The client requires this capability and rejects incompatible authorities.

Console output keeps bounded Arrow batches, a 64-entry point cache and at most
64 prefetched range entries with a 32 KiB decoded-entry budget.
Document index adapters fetch known immutable Publication chunk keys in groups
of at most eight. Descriptor, chunk length, digest and index commitment checks
still run; missing or invalid data fails instead of becoming an empty result.
Cached bytes are checked against the live lease and current source policy before
disclosure. A failed, interrupted or denied prefix has no successful completion
footer. Reconnecting starts new statements; `execution: durable` explicitly
selects the captured-query/recovery console behavior.
[Workload priorities](workloads.md) and [measured costs](performance.md) explain
the rationale and the shared storage work needed alongside this lifecycle.
