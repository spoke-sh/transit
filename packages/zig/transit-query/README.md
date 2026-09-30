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

This package imports Station's and Document's public modules and has no kernel, storage or
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
keeps full-width namespaces out of JSON numbers. The
[native ABI/port caller](../transit-station-bindings/docs/table-mutations.md)
exposes these actions through an explicit profile.
[Typed SDK callers](../../../docs/reference/sdks.md#table-mutation-callers) use the same owner;
The CLI's explicit `mutate` commands use the same bridge and saved-command rules.

`TableQueryWriter` composes the query source and mutation writer for one typed
Table. Its guarded two-turn initializer freezes the complete configuration,
creates metadata, then atomically installs independent query/mutation policies
and marks the host ready. Each turn stays within four mutations. It cannot adopt
an existing standalone owner. The [combined owner contract](../../../contracts/TABLE_QUERY_WRITER_V1.md)
defines readiness, authenticated continuations, conditional policy changes and
the visibility of intermediate metadata to native readers. Component tests cover
initialization and routing. `just test::table-query-writer` exercises both
initialization commits through disk recovery and interleaves durable/interactive
queries with CLI mutations; the proof ledger records the measured scope.

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

`UnifiedSource.pagePlanned` can use a Table primary-key point/range access path;
Fuze still evaluates the original predicate. Neither optimization changes the
bound source basis. Native leases bound abandoned sessions, and a failed read
never reopens a new cut. The [interactive contract](../../../contracts/INTERACTIVE_QUERY_V1.md)
owns quotas, lifetime, cancellation and incomplete-result semantics;
`just test::interactive-query` exercises the real console for all source kinds.

The
[caller guide](docs/unified-client.md) covers provisioning, ownership, retries and
cancellation. `transit-query-host` composes its requester/source behaviors;
`just test::unified-query` exercises these actual daemons over disk Ursula.
`TableSource` is the local composition for an explicitly configured empty
int64 Table. Its owning Station activation atomically creates the Table, native
source configuration and revision-one peer policy in three mutations. It rejects
existing Table metadata and delegates execution to `UnifiedBehavior.Source`.
This initializer has no kernel/provider dependency and grants no native resource
rights. Automatic local lifecycle qualification remains separate server work.
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
