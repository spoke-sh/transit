# transit-query

Shared Zig finite-query clients and application-side Station behaviors. Board
and `transit` share source declarations, the Fuze compiler and Arrow codecs.
The console uses fresh interactive snapshots by default; explicitly durable
queries retain frozen request and result recovery. The [v1 contract](../../../contracts/UNIFIED_QUERY_V1.md)
owns authorization, wire encodings, admission, cancellation and limits.

`TableChangeReader.open` reads an explicitly retained direct Table history lease.
Save the acquisition intent before dispatch and retain its original handle across
backfill and disconnection. Supply a fixed exclusive upper log position and
request budget. Consume `snapshotNext` through null, then save `checkpoint` with
the complete snapshot. `openTail` takes that position and a selected upper bound;
it does not reacquire retention or resolve a name. `next` yields paired row changes
and complete transaction boundaries, including accepted no-ops and definition
changes. The boundary includes the original acceptance receipt and both source
bases. Save its next position only with the complete transaction's application.
History reads scan at most eight physical records per page. Physical maintenance
advances a separate cursor and cannot fabricate a logical transaction. Each
logical acceptance is still consumed separately; a page containing several
acceptances cannot advance the checkpoint past an unconsumed transaction.
A caught-up event covers only the supplied upper bound.

Each diff step owns at most two rows and uses at most two maximum-row buffers
for exact canonical comparison. Values retain their original schema, including
schema evolution; unchanged canonical rows do not become updates merely because
the Table was renamed. Callers deinitialize returned rows/changes. Local `close`
and `deinit` do not release durable retention. Explicitly close the original
history acquisition when it is no longer required, preserving uncertain closure
for retry. Request/row-byte budgets, cancellation and current native/catalog
rights apply to every disclosure, including empty output and checkpoints.
See [Table change capture](../../../docs/handbook/reference/tables.md#snapshot-and-change-capture).

`UnifiedClient` owns signed description, finite upload, frozen submission,
committed-input observation, status, cancellation and verified result pages.
`describe` checks current catalog metadata as well as permission: renamed,
replaced or retired declarations cannot masquerade as the live schema.
`authorize` checks current rights for exact upload recovery and retained results
without rebinding their captured schema.
`recoverPreparation` returns the actual receipt for an exact frozen upload
command and namespace. It admits begin/part/seal/prepare controls only, verifies
the current definition and configured route, and checks current requester rights
before and after lookup. Accepted requests retain their identity after key
rotation; absent requests must verify under the current key. The Workspace
`recover_preparation` operation exposes this read without preparing a replacement.
`UnifiedBehavior.Requester` binds one query principal/source and admits one active
upload/query; `UnifiedBehavior.Source` captures a declared KV, Table or Document
source under current policy. Both execute in separately provisioned Station hosts.

`DirectTableQuery.openRetained` executes the shared finite Fuze SELECT compiler
over an existing signed direct Table pin. The caller supplies the explicit SQL
source name and retains the pin separately; opening, closing and destruction
never acquire, replace or release it. The source fingerprint binds its original
schema, accepted/logical-change positions, row count and pin content. Each result
batch rechecks current rights after computation, including LIMIT 0, aggregates
and repeated completion. Returned result batches own at most eight rows and
16 MiB of canonical cells. Request limits charge both the current-credential read
and direct Table call; result row/byte budgets are separate from source pages
and compute memory. Cancellation and read failures leave incomplete results.
Exactly one equality for every declared primary-key column selects a retained
point read, including a conjunction for a composite key. The original predicate
still runs. Missing keys complete the selection without claiming full-Table
coverage. Finite `COUNT(*)` without an input limit can also traverse a retained
interval when its predicate consists only of `=`, `<`, `<=`, `>` or `>=`
comparisons joined by AND on a single-column primary key. Repeated bounds
intersect, including empty intervals. The original predicate still runs, and
the count requires complete interval coverage and current rights after computation.
The interval owns at most two 4,096-byte keys and one bounded continuation; it
does not materialize matching keys or derive a count from whole-Table metadata.
Row queries, `SUM`, `COUNT(column)`, composite-key inequalities, extra conditions,
OR and NOT keep identity-ordered bounded scans; aggregate overflow checks retain
source order. Captured queries retain their separate complete-key equality path.
Finite reads also keep the scan when a valid comparison literal exceeds the
stored key's character or encoded-byte limit.

Identity-ordered finite scans push their required columns into the Table owner.
The selected set includes output and predicate inputs plus all primary-key
columns used to verify row-directory entries. Segment reads fetch and decode
only these columns; WAL rows use bounded full-row decoding before selecting
cells. Hidden key and predicate inputs do not enter the output schema. The
private execution plan remaps column positions while preserving the original
plan identity and column names in failure evidence. Aliases, repeated output
columns, declared collations, source order, LIMIT and complete-source coverage
retain their original meaning. Point/count-range paths keep their full rows.

Predicates in identity-ordered finite scans execute in the Table owner before
selected segment columns are materialized. The signed request carries a canonical
plan bound to the retained source and collations. Source pages examine at most
eight identities, including misses, and may return no rows while retaining a
continuation. The reader verifies cumulative coverage and copies original source
positions into compute batches; skipped rows do not renumber overflow or predicate
failures. LIMIT stops at the selected prefix and limits each source request's
remaining matches. Empty full-source results still verify all source coverage.
A deferred predicate failure follows earlier selected rows so prior aggregate
failures or a satisfied LIMIT retain precedence. The finite executor borrows
variable and recursive payloads from one decoded reader page until its compute
prefix is consumed, then resets those views before replacing the page. Returned
results own their values independently. This avoids a compute payload copy;
transport decoding and result materialization retain their existing owners.
Arrow buffer interchange and relational predicate pushdown have separate owners.

`DirectTablePrepared.prepare` checks current SELECT rights and owns an immutable
schema-bound template without acquiring a pin. Its preparation fingerprint
includes the complete connection, selected role, namespace, name and declaration.
`DirectTableQuery.openPreparedRetained` binds typed parameters to a separately
retained source, verifies the original interpretation and uses the same finite
executor and disclosure checks. It charges the additional current-definition
check to the request budget. A released pin fails; failed opening cannot replace
it. Template destruction and local query cleanup do not release the durable pin.
See the [Table parameter contract](../../../contracts/SQL_PARAMETERS_V1.md#catalog-table-preparation)
for fresh execution, current policy and definition-change rules.

This direct caller accepts the finite Transit SELECT profile over one explicit
retained source. Text comparisons use the exact Table column's binary,
`ASCII_CI` or `EBCDIC_CP037` collation in direct, prepared and captured plans.
The source and plan both commit the complete comparison vector; reopening
checks it against the retained schema. Closing a computation leaves its source available for other
queries until the pin owner explicitly releases it. See the [direct catalog guide](../transit-catalog/docs/direct-catalog.md)
for pin acquisition, authority and recovery.

`CapturedTablePin` supplies native-state retention for durable computations.
It commits the original grant and a permanent pin-owner claim before permitting
direct acquisition. An independently committed closing decision precedes remote
release; unknown replies retain the same grant, owner and frontier for recovery.
Worker generation changes do not authorize closure. Its
[retention guide](docs/captured-retention.md) defines the commit boundaries and
bounds. `UnifiedCapture` uses this owner for Table admission, traversal and closure;
native KV/Document capture retains native read versions.

`DirectRelationalCompilation` prepares the finite relational profile against
current direct definitions. `DirectRelationalQuery.openPreparedRetained` receives
the original pins and owns the cloned plan, bounded readers and private spill.
`DirectRelationalCompilation.fromRetained` binds a new explicit interactive query
to supplied saved Table bindings and their retained schemas. It checks source
names, exact interpretations and current snapshot rights without resolving live
names or acquiring pins. This permits original sources after ALTER, DROP and
name reuse; a different saved interpretation is rejected even when its columns
match. Opening from retained work validates those snapshots rather than requiring
the original interpretation to remain the live definition. It does not restore
the row cursor or completion evidence of a lost query.
It uses `independent_table_snapshots`; aliases of one Table must share the same
pin. Every cut explicitly distinguishes a native resource revision from a direct
Table's branch/object/partition frontier. Neither form is inferred from a v1
label. Stable row-identity pages support rewinds over the retained source without
another pin or name lookup. Current rights for all inputs are rechecked together
before row and completion disclosure. Cleanup closes local execution only;
the caller remains responsible for durable pin release.

`DirectTableAssistance` uses the same production parser and suggestion builders
as Table completion, obtaining metadata through direct lookups and paged lists.
It completes the statement at the cursor, reports complete or limited candidate
coverage, and distinguishes unsupported syntax from a cursor inside quoted text.
The shortlist holds eight candidates; source enumeration visits at most 128
pages. Ranking retains the exact definition of each selected name, including
names that replace earlier candidates in a full shortlist.
In console mode a fully typed, unique keyword advances to the next grammar
token within the same page budget. Partial words, identifiers, limited
shortlists and SQL editor mode keep their replacement range.
It rechecks all disclosed definitions and current rights together. Its contract
fingerprint binds that metadata vector; it supplies no native resource revision
or data snapshot. Installed launcher/SQL recovery qualification and durable
computation-source migration remain separate integration work.

Table scans own their bounded entry, index-node and block caches in heap storage.
Moving a scan into its query owner transfers that storage; it does not copy bulk
buffers through the calling stack. Destruction releases the caches, including
after a partially acquired source fails. Relational queries charge those
allocations to their resident budget. Aliases sharing a lease retain separate
caches and only the owning scan closes the lease.

Typed Table and file callers use the shared bounded column kernels. `ComputePool`
provides optional host-owned workers over decoded batches; source reads and
current-right checks stay serial. The [batch guide](../transit-fuze/docs/batches.md)
defines configuration, ownership, cancellation and memory accounting.

Direct Table scans read accepted WAL and segment rows through `TablePartition`
at retained cuts. Fuze's `TSegReader` verifies bounded footer and column ranges;
point reads select owned cells and scans reuse decoded groups. Finite identity
scans select columns before segment reads. Segment Zone Map and Bloom-filter
primitives do not establish general SQL predicate pushdown.

`RelationalCompilation.prepare` resolves explicit catalog routes through current
inspection reads, owns immutable schemas and compiles a prepared relational plan
without opening data snapshots or spill. It rechecks each resource revision and
returns no captured basis; execution separately acquires cuts and read authority.
The console uses this owner for relational EXPLAIN.

Relational compilation and execution accept an explicit lexer dialect in their
shared options. The default remains Transit syntax; the MySQL choice changes
quoting and token admission, preserving the same logical plan and native owners.

`RelationalQuery` executes finite int64 Table joins and grouped COUNT/SUM through
the shared Fuze compiler and executor. Callers explicitly select
`per_resource_snapshot_vector`, ordered catalog routes, resident/spill/result/work
budgets, native-request and spill-operation limits. The owner seals every Table's
schema and cut before execution; same-resource aliases share one lease. A final
combined native read validates current catalog policies and native rights for
all dependencies, including noncontributing sources. It holds frozen data through
later mutations without rebinding a Table name or schema.

Private grouping uses a disk AVL map with bounded buffers, per-record integrity
checks and immediate file unlinking. Heap allocation is budgeted independently
of retained groups; transport buffers belong to the supplied client. Errors and
cancellation leave an incomplete prefix, never successful truncation. Callers
release the stable allocated owner with `deinit`; interactive spill is not
resumable. See the [relational contract](../../../contracts/RELATIONAL_V1.md).

`RelationalBridge` exposes explicit catalog routes, metadata-only explanation
and repeatable one-row interactive pages through the Station query ABI/port.
See [interactive relational callers](docs/relational-callers.md) for full-width
values, source evidence, retry, close and host-loss semantics.
`RelationalCaller` owns the configured clients and session for the ABI and
Board. Its authorized description reports the active reference and ordinal
without rerunning or advancing a query. `RelationalWorkspace` journals Board's
original retention requests and exposes explicit cleanup after service loss;
it never resumes the lost executor or selects replacement source cuts.

`RelationalCapture` admits a frozen `RelationalBundle` through an authenticated
Station call, retains every source cut and advances one bounded execution step
per checkpoint. `RelationalState` stages immutable group records, outputs and
checkpoints through Station Publication; their acceptance is atomic with input
progress. `RelationalResult` verifies complete results through public native
reads and current rights to every dependency. The coordinator owns independent
native progress; exact Table grants and durable pin records preserve source
retention across replacement. See the [captured relational guide](docs/relational-capture.md)
for policy, host recovery, memory, closure and collection requirements.

`RelationalMaintenance` retains direct Table history independently of native
query progress. It persists physical traversal between logical acceptances,
records each selected complete source basis, stages its result and paired delta, and atomically publishes a complete revision. A failed
successor preserves the preceding result. `RelationalRevision` verifies full
results or exact predecessor deltas under the reading caller's current source
rights, using a fresh proof bound to the complete result selection; its saved
position advances only after complete delivery. The host explicitly activates
and wakes this typed owner. Terminal cleanup closes the original history leases;
completed result reads still check current source rights. See [maintained relations](docs/relational-maintenance.md)
for scheduling, recomputation costs, quotas, resume and retirement.

`RelationalExchange` records producer eligibility, copies accepted segments into
receiver-owned publications, and consumes them into a native paged row index.
Its source adapter requires terminal coverage from every logical partition and
restores original row order for the existing finite executor. Explicit hosts
own scheduling, source validation, worker placement and combined state budgets.
See [query exchanges](docs/relational-exchanges.md) for the typed operations,
credit/retry protocol and current qualification boundary.
`RelationalExchangeProducer` adds a durable bounded scan cursor for explicit
worker counts and assignments. It resumes the same pending segment after restart,
preserves the original destination, and records receiver acknowledgements through
own-resource control. Workers reopen the frozen Table-history vector with their
own current grants; native retained pins remain scoped to their capturing PID.

`TableSource` provides canonical declarations bound to the complete direct Table
interpretation and bounded owned pages over existing direct pins. It checks a
separately authenticated principal's current database, schema and Table rights
before and after each page, preserving the original schema/root through ALTER,
DROP and name reuse. Traversal resumes from a stable row identity and the recorded
number of consumed rows. Its
[source contract](../../../contracts/TABLE_QUERY_V1.md#captured-direct-table-reads)
keeps retention, requester-policy mapping and durable result publication with the
host. `UnifiedCapture` records the complete direct source cut and `UnifiedResult` checks
current rights before returning owned logical Arrow rows.
`UnifiedRecords.Policy` has explicit declaration and catalog targets. A catalog
target constrains the authenticated requester's original principal, scope and
owner. The immutable bundle carries a separately signed proof bound to the
canonical query, coordinator, requester PID and request resource. The configured
principal cannot authenticate the caller. Current CONNECT, USAGE and each
Table's SELECT gate admission, continuation, result pages and completion.
Recovery retains the original proof; credential rotation never silently resigns
accepted work. Completed-result disclosure uses a fresh, separately bound caller
proof and checks that reader's current source rights. Internal refresh
continuations instead retain the Follow input's accepted subject.
`UnifiedClient.authorizeCapture` seals a newly constructed Table bundle once,
using the explicit executor, pin-operation identity and expected Table frontier.
SQL compilation returns an unsigned description. The neutral `authorize`
operation accepts unsigned bundle hex plus those capture fields and returns
`authorized` hex. Native progress revisions and direct Table cuts remain distinct.

`DirectTableAssistance` reads current authorized metadata through the direct
catalog. It uses the production parsers, retains at most eight suggestions,
and bounds name discovery to 128 pages. Before disclosure it checks every
retained definition and its current visibility. Completion opens no snapshot
and prepares no mutation.

This package imports Station's, Catalog's and Document's public modules and has no kernel, storage or
provider dependency. SQL compiles in Fuze. Interactive execution runs over a
leased public snapshot in the client; durable execution runs in the separately
hosted source behavior and result verification reuses Station. Current reads
may return a conflict if a resource changes during a bounded observation; callers
may retry the read, but must never regenerate uncertain mutations automatically.

`zig build test` checks the package independently. The real host and shell proof
is `just test::unified-query`; `just test::direct-table-service` exercises direct Table DDL/DML with native
local storage, exact frozen recovery and current grants.
[Tests](../../../tests/README.md) record evidence and interface limits.

`Interactive.open/next/close` owns one finite statement over a fresh
`transit-client.SnapshotReader`. The caller supplies a fresh 16-byte nonce,
keeps the compiled `Bundle` and native client alive, and closes the session on
completion or failure. `next` borrows caller-owned source/Arrow work buffers and
an atomic cancellation flag; returned segment bytes borrow the output buffer.
Discard each source-page arena before requesting another page. The CLI bounds
that arena at 1 MiB. The session caches at most 64 immutable point entries,
including absent entries; current policy and native access remain uncached.

`UnifiedSource.page` can use a complete Table primary-key equality lookup;
Fuze still evaluates the original predicate. Neither optimization changes the
bound source basis. Native leases bound abandoned sessions, and a failed read
never reopens a new cut. The [interactive contract](../../../contracts/INTERACTIVE_QUERY_V1.md)
owns quotas, lifetime, cancellation and incomplete-result semantics;
`just test::interactive-query` exercises the real console for all source kinds.

The
[caller guide](docs/unified-client.md) covers provisioning, ownership, retries and
cancellation. `transit-query-host` composes its requester/source behaviors;
`just test::unified-query` exercises these actual daemons over disk Ursula.
The local server initializes the direct catalog and requester, installs query delegation,
and creates its default Table through an explicit recoverable catalog operation.
Restart preserves recorded configuration and current policy, including revocation.
See the [local server guide](../../../apps/transit-cli/docs/server.md).
`DirectRelationalQuery` executes bounded relational reads over explicit direct
Table captures, including independent source positions and current authorization
for every source. The service does not sign native mutations on the caller's
behalf. Catalog SDKs use the shared direct caller documented in
[Catalog callers](../transit-station-bindings/docs/catalog.md).

`SqlTemplate` owns a typed parameter template and commits to the full source
definition, including resource, decoders, paths and accepted Document revision.
`UnifiedClient.prepareSql` and `bindSql` check current access before and after
their work; binding also checks current budgets. Each bound owner contains an
independent ordinary `Bundle`. Release it separately from the template. The
[caller guide](docs/unified-client.md#typed-query-templates) describes identity,
ownership and retry. `SqlCompilation` adds one-shot neutral compilation through
`Bridge.compile` and `Workspace.compile`; both use the same typing, current
access and budget checks. Typed language SDK methods use this same operation;
The [console](../../../apps/transit-cli/docs/console.md#typed-query-parameters)
and durable SQL shell use explicit parameter/query files through this same
compiler; saved-operation recovery never reopens those input files.

`Bundle.fromSql` compiles the [SQL profile](../transit-fuze/docs/unified-sql.md)
against an explicit source declaration and budgets; `UnifiedClient.compileSql`
first verifies current source policy. The [compatibility matrix](docs/compatibility.md)
describes the source, result and transport boundaries.

`Workspace` constrains explicit SQL ingress to one configured source and budgets.
It uses `Values`/`Bridge` for finite bundles, frozen commands, committed-input
observation and verified nested pages. The shell's `query` and Board's
separately credentialed `query` use this interface; their integration
qualification is recorded in the proof guide.

`Values` owns the neutral JSON source/plan/cell codecs; `Bridge` owns frozen-token
operations over `UnifiedClient`, including full-width manifest fields and owned
Arrow bytes. The native ABI and local port delegate to these public modules.
Returned slices belong to the supplied allocator. This keeps shell/Board ingress
and language bindings on one representation without importing the bindings into
the query package or duplicating their protocol semantics.

`SourceDefinition`, `Decoder` and `UnifiedSource` implement the
[v1 contract](../../../contracts/UNIFIED_QUERY_V1.md). Canonical `UQS1` definitions
bind resource identity, declared KV decoder versions, exact Table schemas and
accepted Document references/projections. `UnifiedSource.page` fills a caller-owned
batch from supplied captured/retained public readers; cell byte slices borrow the
bounded arena passed to that call. `Batch.engine()` must be called after the batch
has reached its final address, and its rows cannot escape that batch/arena.

Document pages separately check a current reader before and after using retained
bytes. List expansion returns at most eight items over 32 traversal steps; empty
pages may have a continuation. Text projections share a 4096-step page budget
and have explicit per-projection byte/step bounds. Unsupported expansions and
exhausted budgets reject; values are never truncated. Decoding errors are typed
cells while unknown decoder versions reject the definition.

`UnifiedCapture` supplies resumable retained capture, publication, closure and
cleanup; see its [capture guide](docs/unified-capture.md). The
[proof ledger](../../../docs/history/qualification/README.md) records executed recovery, lifecycle and
placement checks separately from component tests.

`Bundle` owns the bounded canonical source/plan request and explicit page,
segment and result-byte budgets. `UnifiedRecords` owns versioned policies,
jobs, checkpoints, segment commitments and final manifests. Bundle decoding
borrows the input and caller arena. Independent Python fixtures cover all three
source bundles, including a 512-byte predicate and their Publication commitments.

`UnifiedResult.open/page` verifies the original request/call route, current source
policy, Document lifecycle, publication publisher and complete manifest. Pages
validate nested Arrow and ordered row/byte/digest coverage, rechecking current
access before return. `Cursor` is owned continuation state, never a bearer token.
For a direct Table, `Open.table_basis` exposes the exact original interpretation,
accepted position and retained source commitment verified against that manifest.
Other source kinds return null. This evidence remains available after pin closure
but grants no permission; opening it repeats current disclosure checks. It does
not claim that the current Table has the same data.
For Tables, `Expected.disclosure` is mandatory. `Expected.authorize` obtains a
fresh proof bound to the complete result reference, expected route and cursor;
`UnifiedClient.page` supplies it. `RelationalResult.open` takes an explicit
disclosure subject bound to `Options.selection(bundle)` and checks every source
under it. Private resource-reader credentials do not supply this subject. These
low-level result readers still require separate raw native read access; their
proofs do not grant access to backing resources.
Returned Arrow borrows the supplied output buffer; schema/scalar bytes belong to
the supplied result allocator, and decoded conflicts borrow the fixed `Batch`.
An error invalidates the entire page. The [proof guide](../../../tests/README.md)
records independent consumer and installed-SDK execution.

`UnifiedRequest`, `UnifiedUpload` and `UnifiedBehavior` compose authenticated
finite uploads with the source capture and original-call reply. The
[upload guide](docs/unified-upload.md) documents initialization, duplicate parts,
cancellation, cleanup and logical admission.

Test builds expose `testing.Store`, the existing private-turn reference model,
for dependent-package composition tests. It tracks entry revisions and retained
cuts so serving can exercise actual finite capture alongside watch acquisition.
This is test-only simulated storage, not a durability or authorization proof.

A requester-scoped principal needs an explicit optional association and an
independent current read grant for the source resource. That resource access
does not authorize foreign process inspection. V1 status checks foreign process
failure/lifecycle only when the current native identity permits that observation;
otherwise it reports the recorded query phase and source/resource availability.
A missing process diagnostic is not proof that the worker is healthy. Finite
protocol adapters retain their own waiting deadline without cancelling accepted
work or inventing a query failure.

`Draft` adds an explicit finite generation above the requester. Its
four-write submission atomically debits an intent and creates the ordinary query
call. `UnifiedClient.draft` and `prepareNextWithDraft` preserve point-addressed
history and exact admission recovery; `Workspace` exposes `draft_open`,
`draft_close`, `draft_status` and `next_draft`. The selected
[draft contract](../../../contracts/QUERY_DRAFT_V1.md) documents wire formats,
eight-intent groups, current authority and closure. Run, SDK and Follow retain
their explicit admission and lifetime boundaries.

`transit-query-api` exports the standalone workspace JSON Schema from the owning
public types. Board consumes the same schema options; `just transit-board::contract`
checks both reflections agree. The neutral `transit-query-client` browser package
owns the corresponding transport, value validation and bounded complete-result
reader so generated applications need not depend on Board.

`Workspace.suggest` acquires current source authority and returns up to eight
complete SQL drafts from `Editor`. Search is capped at 128 UTF-8 bytes and filters
before the result bound; names and types come only from the configured source.
Every candidate lowers through the real Fuze compiler. Checked sums are offered
only for int64 columns; editing a candidate does not admit a query. This is a
bounded complete-draft catalog, not a speculative parser or cross-source search.

The [v1 cursor-assistance request](../../../contracts/QUERY_ASSISTANCE_V1.md)
belongs to `Workspace`. `Assistance` obtains grammar expectations from Fuze's production
parser and filters them against the caller's declared schema and the executable type profile. The host checks current source/requester rights both
before and after computation; completion prepares no native input. One bounded
response retains at most eight items and a byte replacement range. Independent
fixtures cover quoted/qualified names, suffix replacement, hidden/foreign names,
unsupported comparisons, checked sums, slash arguments and allocation failures.
The console vocabulary is shared data; introducing it does not implement a CLI
command or administrative SQL operation.

`Assistance.edit` applies a validated completion range and candidate to a draft
using the shared SQL token scanner. It inserts separators between adjacent
words, quoted identifiers and literal values while preserving existing
whitespace, punctuation and suffix text. The returned text borrows a distinct
caller-provided output buffer; its cursor follows the candidate. The total edit,
including separators, fits the 4 KiB statement bound or returns an error before
writing output. The helper provides no metadata or authorization evidence;
callers validate the current candidate before applying the edit.

Console-mode assistance advances past a fully typed keyword when it is the
sole match with complete coverage, then obtains the next production-parser
expectations. The replacement becomes the zero-width cursor range. Partial
words, interior cursors, identifiers and limited results retain their original
range. The ordinary SQL editor mode continues to replace the current token.

`DirectTableAssistance` handles the catalog console's Table and relational SQL.
Relational completion discovers up to two declared aliases, reads their current
authorized schemas, and rechecks each displayed definition and current policy before disclosure.
It qualifies shared column names, limits suggestions to the admitted int64
profile, and suppresses predicate operators for unknown or ambiguous names.
Partial projection discovery supplies editor metadata only; it does not establish
SQL acceptance. Fuze's same relational parser owns JOIN/GROUP/aggregate token
roles and cursor expectations.

`SqlInspection` owns `DESCRIBE`, `SHOW TABLES` and `EXPLAIN SELECT` over one
configured source. `UnifiedClient.inspectSql`, `Bridge.inspect` and
`Workspace.inspect` share current authorization, bounded typed results and Fuze
output-schema rules. Metadata is separate from Arrow query results; inspection
does not create snapshots or requests. The [inspection contract](../../../contracts/SQL_INSPECTION_V1.md)
defines scope, literal redaction and final access checks.

`Workspace.applyStructured` returns owned shared diagnostics through an output
pointer. It preserves original binding context and validates a saved token before
recording its actual submission boundary. Unknown sends identify the exact
sequence; a local malformed token remains unsent. Board and application gateways
use this owner instead of reconstructing execution evidence from transport errors.

`ApiDiagnostic` maps caller, lifecycle, result-integrity and transport failures
through reviewed finite classifications. Read errors retain caller-selected query
identity without claiming existence or a terminal outcome. `Workspace` and the
native query ABI qualify that identity and all action targets with their
connection's realm/requester resource; authority rejections retain the native
cause separately. Final segment coverage mismatch is `InvalidResultCoverage`,
distinct from a result that is still incomplete. Saved commands and selection
survive denied inspection while result disclosure remains authorized separately.

`QueryFailure` owns the stable finite-query terminal codes and bounded `UQF1`
codec. Source closure and requester status retain the same original failure.
`UnifiedCapture.advanceDiagnostic` additionally captures page, segment and
result-byte budget measurements before rolling back a rejected candidate.
`RuntimeWitness` captures row, column, instruction, source key, frozen binding
and decoder evidence from the same failed retained page. The owned 104-byte
witness keeps failed jobs within one native value and the existing turn budget.
The neutral bridge and all SDK query statuses carry this evidence; no transient
handler pointer or later source read substitutes for the recorded cause. See
[retained query failures](../../../contracts/UNIFIED_QUERY_V1.md#retained-query-failures)
for code identities, truncation, exact bytes and authorization.

`QueryFailure.diagnostic(namespace, phase)` projects an authorized saved failure
into the shared [diagnostic value](../../../contracts/DIAGNOSTICS_V1.md). Every
retained code has an explicit category. `Bridge.Status.diagnostic` carries this
projection as owned JSON through the native/port boundary, SDK status models
and Board workspace responses. Measured budgets retain full-width limit
and required counters. Rejected and retired failures offer inspection/correction,
never resubmission of the old operation. This projection requires the caller to
complete current-access validation before disclosing it.

`Interactive.diagnostic` holds owned execution/budget evidence for the most recent
failed page. `ExecutionDiagnostic` projects the engine witness and the same
adapter batch's key/decoding evidence. Current native and query-policy checks
precede disclosure; no later source read reconstructs a failing row. KV keys use
bounded hex, Table keys preserve signed width, and Document expansion identifies
elements by counter/replica. These local details do not change durable job records.

Native source hosts use separate 1 MiB source/plan decoding and 4 MiB logical
Arrow workspaces. Exhausting either explicit buffer closes that query with
`adapter_memory_budget` or `arrow_workspace_budget`, retaining its identity and
releasing its captured source pin. Host/storage allocation failures keep their
original infrastructure meaning. Direct Table HTTP allocations use the client's
allocator; their failure leaves the query attempt retryable with unchanged
durable progress. Only a failed allocation from the explicit adapter buffer
establishes `adapter_memory_budget`; a declined in-place growth probe does not.
No required-byte measurement is invented.
Table persistence limits and query transport working sets are independent.

The shared settings adapters use `SettingsSql` for classification and Fuze
metadata compilation, `SettingsClient` for signed public operations,
`SettingsReader` for bounded revision-bound pages, `SettingsSession` for captured
defaults/overrides, and `SettingsJournal` for exact administrative recovery.
`SettingsAssistance` supplies authorized name completion without execution.
The console and database-wire adapters compose these owners. See
[configuration](../../../docs/handbook/reference/configuration.md) and
[settings SQL](../../../docs/handbook/reference/sql/settings.md); query-only methods do
not gain an administrative route.
