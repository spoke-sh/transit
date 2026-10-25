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
The [exchange contract](../../../contracts/RELATIONAL_EXCHANGE_V1.md) defines the
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
the caller's saved command and query selection; result disclosure still requires
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
[physical execution guide](../../../packages/zig/transit-fuze/docs/batches.md) for
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
[file-source API](../../../packages/zig/transit-fuze/docs/file-sources.md) supports
bounded discovery/decoding over host-authorized immutable bytes; it does not
acquire files or create a durable query job. Hosts own capture, result presentation
and completion evidence. The
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
the [query contract](../../../contracts/UNIFIED_QUERY_V1.md#typed-expressions-and-results)
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
retains a native KV/Document version or an exact direct Table pin, stages Arrow segments through bounded Publication turns,
publishes a complete manifest and returns its reference through the original
reply route. Even an empty result carries its schema and completion evidence.
Source rows remain unchanged by a SELECT, but query bookkeeping and result
publication write durable state. The console defaults to the separate interactive
session profile below; explicit durable callers retain this recovery contract.

A direct Table capture uses an explicit executor principal, pin-operation
identity and expected Table partition/log frontier. Its progress resource can
differ from the Table's catalog resource. Compilation produces an unsigned
description; capture authorization freezes the original caller, selected role,
interpretation, frontier and query route before upload. The worker records
acquisition eligibility before contacting storage. Recovery repeats that
original operation, including after RENAME or schema changes; it never captures
newer data silently. The [typed caller guide](../../../packages/zig/transit-query/docs/unified-client.md)
describes configuration and the prepare/submit/observe sequence.

Captured Table reads use the retained schema and row-identity pages. A complete
primary-key equality can seek the retained index, including composite keys;
the original predicate still determines selection. An absent key completes that
selection without claiming that all Table rows were scanned. Both matching and
empty reads require current source rights.

Result completeness and pin cleanup are separate observations. A completed
result retains its source commitment and checks current source rights even after
the pin is released. A storage outage or current denial leaves cleanup pending.
After credential rotation, `prepareCleanup` authorizes closure of the original
pin separately; it cannot renew the accepted query's read authority. Repeated
cleanup uses saved prepared bytes and preserves the original result and failure
evidence.

A current-frontier capture that has not acquired a pin can close when an
authorized status observation proves its Table definition has advanced. The old
definition cannot become current again. A pin acquired before ALTER still retains
the old cut and requires release; advancing data alone does not close an absent
current-frontier capture. Denial and unavailable observations leave cleanup pending.

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
infrastructure errors, including allocation failures in the direct Table HTTP
client. Those failures leave the attempt retryable without advancing the query.
These working-set limits are independent of Table value
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
[draft contract](../../../contracts/QUERY_DRAFT_V1.md) owns the wire and generation
rules; [Board's controls](../../../apps/transit-board/docs/reactive.md#evaluate-edited-drafts)
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

Use the [SQL reference](sql.md), [query compatibility matrix](../../../packages/zig/transit-query/docs/compatibility.md)
and [Fuze package](../../../packages/zig/transit-fuze/README.md) for exact types,
operators and errors. The [delivery contract](../../../contracts/STATION_QUERY_V1.md) and
[query v1 contract](../../../contracts/UNIFIED_QUERY_V1.md) own wire details.
General sorting, arbitrary writes and continuous SQL remain unsupported.

## Relational boundary

COUNT(*) counts selected rows. COUNT(column) counts top-level values of any
admitted column type, skips missing/null and rejects type errors/conflicts.
Both return uint64; null/missing still consume the input LIMIT. Checked int64
SUM adds the selected values of one declared source.
Those single-source interfaces retain their original cut and operator profile.
The separate [finite relational contract](../../../contracts/RELATIONAL_V1.md)
supports one or two explicitly routed Tables, one inner/left int64 equijoin,
grouping by int64 columns, projection, COUNT and ordered checked int64 SUM.
SQL declares int64 as BIGINT. Join nulls do not match; grouping places null keys
together and before integer keys. Duplicate rows retain their multiplicity.

The SQL service uses `DirectRelationalQuery` over independently retained Table
partition cuts. Tables in one catalog need not share a frontier; repeated aliases
of the same Table share one pin. Each cut records its atomic domain explicitly.
`RelationalQuery` retains the separate native-resource snapshot-vector profile.
Neither vector promises an atomic or causal cross-domain snapshot. Every source's
current rights apply, including empty inputs. The
[console configuration](../../../apps/transit-cli/docs/console.md#finite-relational-queries)
describes interactive execution. Private disk grouping and bounded operator
state have separate resident, spill, work and result limits. Rows remain
incomplete until terminal source/output checks succeed.

The Zig `RelationalCapture` owner provides a separate durable lifetime. An
authenticated call admits a frozen plan and schema vector, retains its data cuts,
and records immutable operator checkpoints and output coverage. The coordinator
owns an independent native progress resource and retains each direct Table
through the original caller's scoped grant. `RelationalResult`
checks the complete manifest, ordered rows, byte counts and digest chain, with
current rights to every source before disclosure. Completion, cancellation,
failure and retirement schedule pin cleanup. Current denial leaves cleanup
pending; separately authorized cleanup can close the original pins after
credential rotation. Explicitly scheduled collection removes publication
chunks in bounded turns while preserving control evidence. The
[captured owner guide](../../../packages/zig/transit-query/docs/relational-capture.md)
defines the host's exact-retry and authorization responsibilities.

Before exhausting a captured result or maintained revision, its typed reader's
`freshness` operation compares the original retained source vector with current
authorized Table observations. Logical row changes make the result stale even
when the schema is unchanged; no-op writes and physical storage work alone do
not. A changed interpretation is reported separately, while denied or unavailable
reads return an error. Different Tables are observed independently. Inspection
starts no computation and does not establish complete output coverage: that
still requires the result reader's checked terminal outcome.

The Station query ABI and port expose explicit catalog configuration, explanation,
repeatable one-row pages and close through the shared
[interactive caller](../../../packages/zig/transit-query/docs/relational-callers.md).
A complete page rechecks all source rights; host loss expires interactive handles.
The [TypeScript](../../../sdks/ts/transit-station-sdk/docs/relational.md) and
[Python](../../../sdks/python/transit-station/docs/relational.md) SDKs expose
that interactive owner with immutable references and full-width integer rows.
Board's [relational worksheet](../../../apps/transit-board/docs/relational.md) exposes
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
Its typed `NamedRelationalPublication` plan saves the complete immutable bundle,
predicted logical reference and one dependency registration per distinct Table.
Explicit registration requires the caller's current source SELECT and computation
metadata WRITE rights. Publication checks current graph membership before
returning the native command; it starts no query. A lost reply keeps the original
plan and operation identities. Registration and native publication have separate
acceptances and require explicit recovery.

Retiring an exact definition prevents new authorization and activation. Retiring
the current name permits reuse with a fresh object identity. Existing accepted
work, result access policy and original attribution remain with their query owner.
Retirement leaves dependency edges intact until separately authorized removal;
an old registration receipt does not restore a removed edge. Resolve uncertain
publication before cleanup. The [naming contract](../../../contracts/NAMED_RELATIONAL_V1.md)
defines these controls and their bounds.

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

Native key/value Table queries use their ordered primary-key index: equality
reads one key, lower bounds seek, and upper bounds stop the scan. General catalog
Table SELECTs use a collision-safe point lookup for a conjunction containing
exactly one equality per declared primary-key column. Partial keys, inequalities
and additional predicates retain identity-ordered bounded scans. The original
Fuze predicate still determines matching rows, and empty selections require
current rights. The direct retained key-range API does not itself enable SQL
inequality pushdown. Persistent Arrow storage blocks are
separate from the native Arrow batches used for execution and presentation.

The [interactive query contract](../../../contracts/INTERACTIVE_QUERY_V1.md) defines
the leased snapshot, cancellation and bounded output boundary.

The SQL service opens a fresh result and source snapshot for each console
SELECT. Completion releases the underlying read; the logical session retains
its final bounded batch for exact fetch retries. Normal console exit closes the
session. Abnormal disconnection falls back to its lease. A new logical session
does not resume a previous interactive SELECT. This changes
interactive query recovery, not the durability of accepted application state.
Existing callers explicitly requesting durable captured jobs keep their recovery
contract. A session does not require a new durable PID or principal.

Table admission resolves catalog metadata and the complete schema at an exact
resource revision. Repeated metadata lookups share a bounded 64-entry scratch
cache for that observation; eviction fetches the record again. This cache does
not retain permissions across operations. Current authorization is interpreted
using the exact keys requested for that observation, and a fresh check precedes
schema or result disclosure. Table capture and page reads carry the caller's
signed identity and selected role through both the retained data reader and the
current metadata reader. Native SELECT remains required for empty results and
`LIMIT 0`; raw-resource read permission does not replace that Table check.

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

Fuze executes outside kernel authority over authorized source reads. Direct
Table reads retain a durable partition pin including accepted unflushed rows.
The SQL service journals acquisition before dispatch and release before cleanup;
its bounded recovery worker closes interrupted requests and earlier-generation
pins under current rights. Denied cleanup retains its record. These pins do not
expire with the native-resource lease described below. An ordinary SQL result
still cannot resume after losing its session.

The native-resource read profile uses signed snapshot requests.
For console connections, execution lives in the shared SQL service. Low-level
Query SDK callers execute in their own process. The authority
does not execute SQL. There are no durable upload, execution-progress or result
publication turns in this profile. Table, KV and Document adapters share finite compiler and Arrow interfaces.
The native-resource snapshot contract provides:

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
Computation stops with the process hosting the query. A failed release falls back to lease
expiry. Current grants, principal epoch and source liveness still gate reads.

With native `snapshot_read`, acquisition combines source/requester metadata,
the fresh cut and initial data. Final current validation can release the snapshot
in the same request. Captured reads and current metadata have explicit separate
bases; a write during data acquisition does not require recapturing the source.
The client requires this capability and rejects incompatible authorities.

Table reads check native database, schema and Table privileges separately from
the source policy. Within one bounded metadata or page acquisition, repeated
checks of the same accumulated privileges may share a verified result. The
acquisition finishes with a fresh native check of all observed requirements;
final disclosure also checks current authority after computation, including
empty results. No authorization decision carries into a later page or statement.
Authority decoration preserves batched immutable-chunk reads and bounded caches.

Source execution keeps bounded Arrow batches, a 64-entry point cache and at most
64 prefetched range entries with a 32 KiB decoded-entry budget.
Document index adapters fetch known immutable Publication chunk keys in groups
of at most eight. Descriptor, chunk length, digest and index commitment checks
still run; missing or invalid data fails instead of becoming an empty result.
Cached bytes are checked against the live lease and current source policy before
disclosure. A failed, interrupted or denied prefix has no successful completion
footer. The native session API retains one bounded batch for fetch retries. Opening a
new session starts new statements. The native session API separately supports
service-owned captured queries against an explicit source binding.
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
[handler query contract](../../../contracts/STATION_QUERY_V1.md) for framing,
wait closure, retained evidence and duplicate handling.


## Maintained Table revisions

The typed Zig `RelationalMaintenance` owner publishes a complete result for each
recorded Table-history basis, including no-op transaction coverage. It captures
an initial direct Table basis, backfills while later history remains durable,
then advances one eligible logical Table acceptance at a time. Same-Table aliases
share a cut; distinct Tables remain independent, including within one catalog.
Bounded storage-only traversal has a durable cursor and publishes no result
revision. Source vectors record the processing order without a global snapshot
claim. Native query progress is independent of the Table catalog resource.

The owner recomputes each basis with the same finite relational executor and
stages an ordered paired delta against the previous complete result. One commit
publishes the source vector, checkpoint, result and delta coverage together.
Until then, readers retain the previous revision. A semantic failure records the
failed successor and stops advancement; later input cannot skip that failure.
Missing history or a changed schema requires explicit rebuild under a new query
identity. Current source rights remain necessary even for noncontributing inputs.

Activation and wakeups are explicit authenticated host operations. The owner does
not supply a background daemon, automatic SQL activation, or an event-time finality
claim. Its direct retention grants, workspace/state budgets and cumulative
retention costs are described in the
[maintained caller guide](../../../packages/zig/transit-query/docs/relational-maintenance.md).

`RelationalRevision` reads full revisions or deltas against an exact previous
manifest. A partial delivery cannot replace the consumer's relation. After
terminal coverage validation, save its position atomically with applying the
complete transaction. Resume requests the next recorded revision; pending keeps
the old position, and a mismatch requires explicit reset. Cancellation or failure
preserves previous complete results and schedules closure of the original history
leases; retirement makes results unavailable. Cleanup progress remains separate
from result completion. Every read rechecks current policy and source rights,
including after source leases close.

## Explicit query exchanges

Typed Zig hosts can route frozen source rows into logical partitions and stage
them in bounded segments. Receiver and producers have explicit PIDs and separate
resources under the same authority, independently of the Table catalog owners.
Workers use their own credentials and original-caller grants for exact retained
cuts. These borrowed reads confer no acquisition, history advancement or cleanup
permission; the coordinator owns the source leases.
Each accepted segment has a receiver-owned copy and an exact deduplication
identity. Consumption separately indexes its rows and returns credits. Every
partition, including an empty one, must publish and consume terminal coverage
before execution can read the exchanged source.

A maintained successor requires a new exchange bound to its exact source vector.
Attaching incomplete coverage or an exchange from the preceding revision leaves
the query unchanged. Retiring the live request publication does not revoke an
already accepted computation's retained request. Explicit query retirement
releases that dependency and makes its results unavailable.

The native paged row index restores original source order, so different delivery
or batch schedules preserve the existing join and checked-SUM semantics. Current
source rights apply during staging, consumption and execution. Hosts supply
placement, scheduling and combined operator/exchange budgets; these primitives
do not provision an automatic runtime controller or grant execution authority.
The [typed host guide](../../../packages/zig/transit-query/docs/relational-exchanges.md)
defines the operations and links their concrete qualification limits.
