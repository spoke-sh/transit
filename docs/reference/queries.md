# Query execution and result recovery

Fuze is Transit's Zig-native finite query engine. SQL and native callers lower
to the same typed plans. Source adapters acquire authorized data; query execution
does not acquire kernel authority or raw storage credentials. Neither DataFusion
nor Acero is a runtime dependency.

Durable Table queries bind the original caller, credential epoch and selected
role to the immutable query and intended requester. Admission policies constrain
that identity and work budgets; they do not authenticate a user. Every source
requires current CONNECT, schema USAGE and Table SELECT, including join sources
that contribute no rows. Continuations retain the original proof after restart;
credential rotation does not silently resign an accepted query. Completed results
from captured queries use a fresh proof for the requested result and page under the reader's
current rights. An explicitly authorized recovery operator can read the original
result without changing its request or execution attribution. Result completion
is also an authorization boundary.

Explicit physical exchange placement requires the original caller to authorize
each logical worker assignment for the frozen query and complete source basis.
The retained proof fixes the worker PID, layout and budgets. Worker replacement
keeps that proof; fresh worker credentials cannot renew the caller's authority.
The [exchange contract](../../contracts/RELATIONAL_EXCHANGE_V1.md) defines the
assignment and current-check boundaries.

Invalid editor cursor offsets identify the byte-offset/UTF-8 boundary requirement
separately from invalid saved-result cursors. Invalid typed predicate programs
identify instruction, literal-storage or stack bounds as a plan-construction
failure. These local failures do not replace an already uncertain submission or
authorize retrying a new command.

Caller errors distinguish pending results, closed snapshots, missing uploads,
draft conflicts, invalid cursors, corrupt manifests/segments/coverage and
unavailable authority. Inspection failures retain the selected query namespace,
realm and requester resource in the diagnostic and its action targets. They do
not establish whether earlier work completed. A refused status read preserves
the shell's saved command and query selection; result disclosure still requires
current access.

Read failures identify whether retrying that read is appropriate. An unconfirmed
submission instead retains its exact sequence and reconciliation action. If a
truncated read reaches the caller without transport/decoder origin evidence,
the diagnostic explicitly marks that origin unrecorded. It does not infer
corruption or authorize submitting the SQL again.

## Physical execution

File and general Table queries use bounded typed columns. Int64, uint64, finite
float64 and Boolean comparisons have specialized kernels; other admitted logical
values retain generic comparisons and deep-owned projections. Eager predicates
preserve the first error by original row and instruction. COUNT observes all
five states, and SUM checks each selected int64 contribution in source order.

Compute batches default to 256 rows and 256 KiB, with a maximum of 1024 rows and
1 MiB; width and payload size can reduce the actual row count. Source decoding,
Arrow output and durable publication keep their existing independent bounds.
A valid large decoded row executes under its source owner when it cannot fit the
compute buffer. File LIMIT still verifies the complete captured input.

Linux x86_64 can select AVX2 comparisons after CPU and operating-system checks.
The Zig host APIs allow portable selection and an optional bounded compute pool.
Source acquisition, authorization, failure arbitration and publication stay with
the ordered caller. The default is local computation with portable kernels. See the
[physical execution guide](../../packages/zig/transit-fuze/docs/batches.md) for
configuration, ownership and memory accounting.

Resumable logical/Unified pages and relational predicates share the kernels.
Their progress encodings and original source-validation/work boundaries remain
unchanged. Relational joins and group updates retain their one-pair work quantum.

## Source declarations

A query selects one explicit KV decoder, Table schema or accepted Document
projection with finite execution budgets. General Table declarations bind an
immutable catalog definition and admit up to 128 columns. KV has two explicit
decoders; Document projections retain their independent eight-column bound.
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
constructors and inspected programs. Local file-query plans share the bounded
Boolean evaluator and retain their own logical schema and source fingerprints;
the [query contract](../../contracts/UNIFIED_QUERY_V1.md#typed-expressions-and-results)
defines the native program representation and ownership.

## Admission and execution

Compile and validate the plan before submission, with explicit operation and
resource budgets. Query admission is separate from execution and complete result
publication. Current source permission is checked independently from requester
ownership or a gateway's own credential.

Terminal query status retains the original semantic failure code and whether it
occurred during admission or execution. Page, segment and result-byte failures
also retain their admitted limit and required work. Runtime cell and aggregate
failures retain the first failing scanned row, column, expression instruction,
source key and frozen binding identity where that operator has them. Column
names and long KV keys have explicit truncation markers; decoder failures name
the encoding reason and byte counts without copying stored values.

The neutral status and all ten SDKs carry the shared diagnostic envelope beside
the original failure. Its typed facts and recovery actions do not depend on
English text. These values survive exact
retry, cleanup, request retirement and restart; they are not reconstructed by
rerunning the query. Current access to the request resource is still required.
Policy failures distinguish a missing policy, disabled queries, changed policy
revision, a different request/source resource or declaration, and a requested
budget above the policy allowance. Available expected and observed revisions,
resource IDs, fingerprints and budget measurements are retained at the failing
check. Table schema mismatches keep both fingerprints. A later policy/schema
repair or query retirement preserves that evidence.

A terminal failure has no complete result. Correcting the query or its authorized
budget requires a new submission. Infrastructure or transport failure without a
recorded terminal outcome retains the original recovery obligation.

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

Native query hosts bound source decoding to 1 MiB and logical Arrow encoding to
4 MiB per active step. Exhaustion records a specific query memory-budget failure,
discards the candidate and releases its source pin. It does not stop the source
owner or remove stored rows. Storage and general allocator failures remain
infrastructure errors. These working-set limits are independent of Table value
and encoded-result limits.

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
General sorting, arbitrary writes and continuous SQL remain unsupported.

## Relational boundary

COUNT(*) counts selected rows. COUNT(column) counts top-level values of any
admitted column type, skips missing/null and rejects type errors/conflicts.
Both return uint64; null/missing still consume the input LIMIT. Checked int64
SUM adds the selected values of one declared source.
Those single-source interfaces retain their original cut and operator profile.
The separate [finite relational contract](../../contracts/RELATIONAL_V1.md)
supports one or two explicitly routed Tables, one inner/left int64 equijoin,
grouping by int64 columns, projection, COUNT and ordered checked int64 SUM.
SQL declares int64 as BIGINT. Join nulls do not match; grouping places null keys
together and before integer keys. Duplicate rows retain their multiplicity.

`transit-query.RelationalQuery` seals a per-resource snapshot vector before
execution. Aliases in one resource share its cut, while different resources may
be captured at different times. This does not provide an atomic or causal shared
snapshot. Every source's current rights still apply, including empty inputs.
The [console configuration](../../apps/transit-cli/docs/console.md#finite-relational-queries)
explicitly enables this interactive profile. Its private disk group index and
bounded operator state have separate resident, spill, work and result limits.
Rows remain incomplete until terminal source/output checks succeed.

The Zig `RelationalCapture` owner provides a separate durable lifetime. An
authenticated call admits a frozen plan and schema vector, retains its data cuts,
and records immutable operator checkpoints and output coverage. The coordinator
is the first Table owner; other sources remain read-only. `RelationalResult`
checks the complete manifest, ordered rows, byte counts and digest chain, with
current rights to every source before disclosure. Cancellation, failure and
retirement release pins; explicitly scheduled collection removes publication
chunks in bounded turns while preserving control evidence. The
[captured owner guide](../../packages/zig/transit-query/docs/relational-capture.md)
defines the host's exact-retry and authorization responsibilities.

The Station query ABI and port expose explicit catalog configuration, explanation,
repeatable one-row pages and close through the shared
[interactive caller](../../packages/zig/transit-query/docs/relational-callers.md).
A complete page rechecks all source rights; host loss expires interactive handles.
The [TypeScript](../../packages/ts/transit-station-sdk/docs/relational.md) and
[Python](../../packages/python/transit-station/docs/relational.md) SDKs expose
that interactive owner with immutable references and full-width integer rows.
Board's [relational worksheet](../../apps/transit-board/docs/relational.md) exposes
the same owner through explicit routes and page controls. Active-session
inspection can recover a browser's lost reference without rerunning the query.
The console does not activate maintained queries. Flight rejects relational
execution. Typed Zig maintained ownership and
complete Table history have their own interfaces below; coalesced invalidation
notifications remain distinct from complete transaction capture.

| Caller | Relational lifetime and operations |
| --- | --- |
| Typed Zig query hosts | Interactive pages; captured admission, recovery and result reads; maintained activation, complete revisions and exact deltas; explicit exchanges |
| Typed Zig application host | Immutable named definitions, separate query authorization and explicit captured/maintained activation |
| Station ABI/port, TypeScript and Python | Interactive explain, open, repeatable pages and close |
| SQL console and Board worksheet | Explicit interactive submission and result pages |
| Flight and other language SDK adapters | Relational execution is unsupported |

Named definitions use the [application-owned interface](applications.md#contracts-and-commands).
Saved typed requests and cursors require the exact current contract definition;
none of these callers substitutes a fresh query for missing accepted work.

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

Table admission resolves catalog metadata and the complete schema at an exact
resource revision. Repeated metadata lookups share a bounded 64-entry scratch
cache for that observation; eviction fetches the record again. This cache does
not retain permissions across operations. Current authorization is interpreted
using the exact keys requested for that observation, and a fresh check precedes
schema or result disclosure.

Interactive execution failures identify the first failing scan row, source column
and operation. Predicate failures include the zero-based postfix instruction;
eager evaluation reports a later failing atom even when an earlier atom would
already determine the Boolean result. SUM reports the intermediate overflow site.
The scan ordinal describes the adapter's actual traversal, including any Table
seek; it is not a stable row identity. When present, Table keys are exact signed
integers, KV keys are bounded hexadecimal bytes, and expanded Document element
identities are `counter:replica`. Truncation is explicit. The frozen plan/source
fingerprint and source revision identify the computation that failed. Stored
value payloads are excluded; KV failures retain decoding reasons and byte counts.

Page, segment and result-byte budget failures identify the dimension, configured
limit and required amount. The console reports already emitted rows/segments and
marks the result incomplete. Current permissions gate enrichment, including
failures computed from cached source rows. Diagnostic construction or disclosure
failure preserves the primary computation error and does not create durable work.
These local witnesses are not saved outcomes for a durable captured query.

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


### Handler query failures

Station handler queries deliver deterministic output/workspace exhaustion and
arithmetic overflow as typed negative results. Explicit cancellation and policy
denial also carry a reason. The framework authenticates the recorded source and
correlation, preserves any received prefix as incomplete evidence, and invokes
only the first terminal callback. Application message codecs do not decode these
frames. Storage, allocation and local cancellation failures still abort private
work; they do not manufacture a terminal result. See the
[handler query contract](../../contracts/STATION_QUERY_V1.md) for framing,
wait closure, retained evidence and duplicate handling.


## Maintained Table revisions

The typed Zig `RelationalMaintenance` owner publishes a complete result for each
recorded Table-history basis, including no-op transaction coverage. It captures
an initial basis, backfills while later history remains durable, then advances
one eligible resource transaction at a time. Required Tables in one resource
move together. Different resources have an explicit vector and recorded processing
order; this is not a global or causal snapshot.

The owner recomputes each basis with the same finite relational executor and
stages an ordered paired delta against the previous complete result. One commit
publishes the source vector, checkpoint, result and delta coverage together.
Until then, readers retain the previous revision. A semantic failure records the
failed successor and stops advancement; later input cannot skip that failure.
Missing history or a changed schema requires explicit rebuild under a new query
identity. Current source rights remain necessary even for noncontributing inputs.

Activation and wakeups are explicit authenticated host operations. The owner does
not supply a background daemon, automatic SQL activation, or an event-time finality
claim. Its first-source owner placement, workspace/state budgets and cumulative
retention costs are described in the
[maintained caller guide](../../packages/zig/transit-query/docs/relational-maintenance.md).

`RelationalRevision` reads full revisions or deltas against an exact previous
manifest. A partial delivery cannot replace the consumer's relation. After
terminal coverage validation, save its position atomically with applying the
complete transaction. Resume requests the next recorded revision; pending keeps
the old position, and a mismatch requires explicit reset. Cancellation or failure
preserves previous complete results; retirement makes them unavailable. Every
read rechecks current policy and native/catalog rights to all sources.

## Explicit query exchanges

Typed Zig hosts can route frozen source rows into logical partitions and stage
them in bounded segments. The receiver shares the first Table owner's resource;
producers have explicit PIDs and separate resources under the same authority.
Each accepted segment has a receiver-owned copy and an exact deduplication
identity. Consumption separately indexes its rows and returns credits. Every
partition, including an empty one, must publish and consume terminal coverage
before execution can read the exchanged source.

The native paged row index restores original source order, so different delivery
or batch schedules preserve the existing join and checked-SUM semantics. Current
source rights apply during staging, consumption and execution. Hosts supply
placement, scheduling and combined operator/exchange budgets; these primitives
do not provision an automatic runtime controller or grant execution authority.
The [typed host guide](../../packages/zig/transit-query/docs/relational-exchanges.md)
defines the operations and links their concrete qualification limits.
