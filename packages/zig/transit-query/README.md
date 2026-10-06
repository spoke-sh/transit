# transit-query

Shared Zig finite-query clients and application-side Station behaviors. Board
and `transit` share source declarations, the Fuze compiler and Arrow codecs.
The console uses fresh interactive snapshots by default; explicitly durable
queries retain frozen request and result recovery. The [v1 contract](../../../contracts/UNIFIED_QUERY_V1.md)
owns authorization, wire encodings, admission, cancellation and limits.

`UnifiedClient` owns signed description, finite upload, frozen submission,
committed-input observation, status, cancellation and verified result pages.
`UnifiedBehavior.Requester` binds one query principal/source and admits one active
upload/query; `UnifiedBehavior.Source` captures a declared KV, Table or Document
source under current policy. Both execute in separately provisioned Station hosts.

`TableQuery` executes [general typed Table SELECT](../../../contracts/TABLE_QUERY_V1.md)
through the catalog's signed connection, without a separately configured source
or requester per Table. It owns a leased snapshot, typed plan and bounded native
entry cache. Each output is one owned logical row; current catalog and native
authorization precede disclosure, including completion and empty output. Explicit
request, row and canonical-byte budgets apply. The console's `catalog_v1` profile uses this adapter. Durable-query and
foreign-language routes retain their separately admitted profiles.

`TableSource` provides canonical schema-bound declarations and bounded owned pages
over supplied captured/retained readers. It checks a separately authenticated
principal's current catalog rights before and after each page, preserving the
original schema/root through ALTER, DROP and name reuse. Complete composite-key
equality uses the existing collision-safe index. Its
[source contract](../../../contracts/TABLE_QUERY_V1.md#signed-native-table-reads)
keeps retention, requester-policy mapping and durable result publication with the
host. `UnifiedCapture` retains the head/schema cut and `UnifiedResult` checks
current rights before returning owned logical Arrow rows.
`UnifiedRecords.Policy` has explicit declaration and catalog targets. A catalog
target maps a requester process to a catalog principal within one scope and
owner. It permits resolving new Table objects without installing a per-Table
policy; every page still requires current catalog inspect/read rights. Policy
installation belongs to the authorized owner, and a changed mapping advances its
revision. Native durable admission and result verification use this adapter and the
canonical logical plan/Arrow codecs. `CatalogQueryOwner` composes the Table
lifecycle owner with query dispatch; its administrator installs explicit
requester delegation without creating a worker or policy per Table. See
[catalog query ownership](../../../contracts/CATALOG_QUERY_OWNER_V1.md).

`TableAssistance` reads current catalog metadata, derives continuations from the
same general Table parsers and checks the metadata/policy revision again before
returning. It bounds source searches to 128 pages and eight suggestions while
retaining only one page. The terminal reacquires suggestions before accepting
an edit. Completion is read-only and does not prepare or dispatch SQL.

This package imports Station's, Catalog's and Document's public modules and has no kernel, storage or
provider dependency. SQL compiles in Fuze. Interactive execution runs over a
leased public snapshot in the client; durable execution runs in the separately
hosted source behavior and result verification reuses Station. Current reads
may return a conflict if a resource changes during a bounded observation; callers
may retry the read, but must never regenerate uncertain mutations automatically.

`TableMutationRequest` encodes owned, definition-bound requests over the shared
Table mutation plan and Station Table codecs. It can produce an immutable
publication reference without admission or execution. `TableMutationAdmission`
composes explicit principal/Table policies, immutable upload staging and a
terminal result with the row proposal in one private Station turn. Applications
retain the full immutable publication reference in every staged or control command;
the owner rejects changed resource, length or digest even for terminal results.
Applications must install its policy through their authorized configuration path and opt into
its external-cast dispatch. The query host offers an explicit `table_writer`
role; read-query roles and public query clients still reject writes. No read permission implicitly enables mutation dispatch.
See the [mutation contract](../../../contracts/TABLE_MUTATION_V1.md).

`TableMutationClient` supplies the shared Zig caller for applications that expose
that owner: current metadata/SQL compilation, canonical saved signed commands,
explicit submission, input observation, status and bounded upload resumption.
`prepareNew` rejects namespace collisions in its preparation batch. `progress`
checks mailbox advancement before returning both input disposition and mutation
status from one authorized resource cut. `prepareNextResult` preserves terminal
evidence acquired during successor selection. These composed Zig helpers avoid
redundant reads; the neutral caller's individual actions keep their contracts.
`waitObserve` and `waitProgress` use a bounded notification hint after observing
the same exact input pending. They retain only its scheduling position and wait
at most 50 ms per native wait, with current checks after wake/timeout. Exhausted
wait admission uses bounded backoff followed by an ordinary authorized read.
The console and neutral SDK `observe` action use these helpers. A timeout is
not completion, and observation never resubmits a command. `observe` and
`progress` remain available for immediate current reads.
It retains full request identity across caller and writer recovery. Preparing the
next step requires reconciling the preceding exact command first; a native send
receipt is admission, and only a terminal mutation status establishes the result.
The [caller contract](../../../contracts/TABLE_MUTATION_V1.md#signed-zig-caller)
defines these APIs and the required current grants. `TableMutationWriter`
composes guarded initialization, policy changes and durable rejected-input
dispositions for the explicit host role. Read-query routes do not dispatch
mutations. `TableMutationBridge` supplies owned neutral actions/results
over the same caller, including exact compiled-reference validation and opaque
saved commands. Its [neutral value contract](../../../contracts/TABLE_MUTATION_V1.md#neutral-caller-values)
keeps full-width namespaces and conflicting signed keys out of JSON numbers.
Rejected INSERT status includes the actual key and one-based input row from the
rejecting execution, retained atomically with the outcome. The
[native ABI/port caller](../transit-station-bindings/docs/table-mutations.md)
exposes these actions through an explicit profile.
[Typed SDK callers](../../../docs/reference/sdks.md#table-mutation-callers) use the same owner;
The CLI's explicit `mutate` commands use the same bridge and saved-command rules.

`CatalogQueryOwner` routes query and Table lifecycle inputs through their owning
operations. Administrator initialization and conditional requester delegation
are separate bounded commits. Query access uses each requester's explicit mapped
catalog principal and current read rights; mutation permissions remain independent.
See the [catalog owner contract](../../../contracts/CATALOG_QUERY_OWNER_V1.md).

`zig build test` checks the package independently. The real host and shell proof
is `just test::unified-query`; `just test::table-mutation` exercises an explicit
mutation application against native authority and disk-backed Ursula, including
exact frozen recovery, writer fencing and current grants.
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
The local server initializes the catalog and requester, installs query delegation,
and creates its default Table through an explicit recoverable catalog operation.
Restart preserves recorded configuration and current policy, including revocation.
See the [local server guide](../../../apps/transit-cli/docs/server.md).
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
[proof ledger](../../../tests/README.md) records executed recovery, lifecycle and
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

`MutationDiagnostic` projects authorized mutation statuses and rejected input
dispositions into owned diagnostic values. Statuses retain the original conflict
key/row and policy or descriptor mismatch evidence. `bound` verifies the original
immutable request before adding its column name. Terminal results and rejected
inputs retain distinct recovery guidance; projection never reads current rows or
changes work. See the [mutation record contract](../../../contracts/TABLE_MUTATION_V1.md#record-and-command-encodings).

`TableMutationBridge.Status.diagnostic` and `.Disposition.diagnostic` carry these
projections through the ABI, native port, CLI and all SDK models. The bridge's
`rejection` response retains the complete checked input disposition, including
principal, native input and payload commitment, separately from mutation status.

`MutationDiagnostic.codes` defines finite caller causes separately from durable
mutation outcomes. Failed status reads preserve the exact supplied publication
reference's namespace and resource, qualified by the connection realm. A failed
read does not prove absence, rejection or cancellation. Native authority conflict
is distinct from mutation identity conflict; ABI and CLI details retain its native
cause. Unknown sends still require reconciliation of the original signed command.

Native source hosts use separate 1 MiB source/plan decoding and 4 MiB logical
Arrow workspaces. Exhausting either explicit buffer closes that query with
`adapter_memory_budget` or `arrow_workspace_budget`, retaining its identity and
releasing its captured source pin. Host/storage allocation failures keep their
original infrastructure meaning. No required-byte measurement is invented.
Table persistence limits and query transport working sets are independent.
