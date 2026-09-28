# transit-query

Shared Zig public Table query client and application-side Station behaviors for
[M13](../../../docs/roadmap/M13.md). Board and `transit` use the same compiler,
frozen request and result readers. The [v1 contract](../../../contracts/PUBLIC_QUERY_V1.md)
owns authorization, wire encodings, admission, cancellation and limits.

- `Model` owns connection, source, prepared submission, status, typed page and
  Board's opaque frozen-token transport. Tokens preserve full-width SQL literals.
- `Client.describe/prepare/submit/status/page` use current signed Transit reads
  and commands. Retain `Prepared` on uncertain submission; its receipt identifies
  the requester correlation. A page's strings borrow the supplied request arena.
- `Client.prepareCancel/submitCancel` preserve explicit cancellation identity.
- `Client.prepareSequence/submitSequence` support adapters with an explicit
  native sequence and published schema. Pure preparation reconstructs canonical
  signed bytes after host loss; submission still checks current authorization.
  Neither a sequence observation nor matching SQL reserves a query identity.
- `Client.segment` exposes one verified raw IPC segment in caller-owned buffers.
  It uses the same retained manifest/transfer checks as typed pages and rechecks
  current source/requester rights after copying. Consumers must verify ordered
  complete coverage before claiming a complete result; a returned prefix is not
  success. The Flight adapter uses this seam without an alternate result store.
- `Behavior.Requester` binds one query principal/source and admits one active
  query. Initialize it with a separate `PQI1` cast from that principal.
- `Behavior.Source` serves one declared Table to one configured peer under
  Station's current revisioned policy. The Table and policy must already exist.
  Both behaviors need a host-owned growing query context.

This package imports Station's and Document's public modules and has no kernel, storage or
provider dependency. SQL compiles in Fuze, execution runs in the separately
hosted source behavior, and result verification reuses Station. Current reads
may return a conflict if a resource changes during a bounded observation; callers
may retry the read, but must never regenerate uncertain mutations automatically.

`zig build test` checks the package independently. The real host and shell proof
is `just test::public-query`; [tests](../../../tests/README.md) record evidence.

`UnifiedClient` adds signed v2 description, finite upload, frozen submission,
committed-input observation, status and verified result pages. The
[caller guide](docs/unified-client.md) covers provisioning, ownership, retries and
cancellation. `transit-query-host` composes its v2 requester/source behaviors;
`just test::unified-query` exercises these actual daemons over disk Ursula.
`Bundle.fromSql` compiles the [v2 SQL profile](../transit-fuze/docs/unified-sql.md)
against an explicit source declaration and budgets; `UnifiedClient.compileSql`
first verifies current source policy. The [compatibility matrix](docs/compatibility.md)
describes both public versions and the transport handoff boundary.

`Workspace` constrains explicit SQL ingress to one configured source and budgets.
It uses `Values`/`Bridge` for finite bundles, frozen commands, committed-input
observation and verified nested pages. The shell's `query-v2` and Board's
separately credentialed `query_v2` use this interface; their integration
qualification is recorded in the proof guide.

`Values` owns the neutral JSON source/plan/cell codecs; `Bridge` owns frozen-token
operations over `UnifiedClient`, including full-width manifest fields and owned
Arrow bytes. The native ABI and local port delegate to these public modules.
Returned slices belong to the supplied allocator. This keeps shell/Board ingress
and language bindings on one representation without importing the bindings into
the query package or duplicating their protocol semantics.

M18 adds `SourceDefinition`, `Decoder` and `UnifiedSource` under the separate
[v2 contract](../../../contracts/UNIFIED_QUERY_V2.md). Canonical `UQS2` definitions
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

Component tests qualify these adapters and the current Document floor/retirement
checks with in-memory private turns. `UnifiedCapture` now supplies resumable
retained capture, publication, closure and cleanup; see its
[capture guide](docs/unified-capture.md). Signed submission, verified reads, all ten SDKs and disk/worker recovery are
qualified across the three source kinds. Lifecycle/expiry covers all three; physical
Compose/Substrate recovery covers Table. The existing `Client` and
`Behavior` still serve public Table v1 queries.

`Bundle` owns the bounded canonical source/plan request and explicit page,
segment and result-byte budgets. `UnifiedRecords` owns versioned policies,
jobs, checkpoints, segment commitments and final manifests. Bundle decoding
borrows the input and caller arena. Independent Python fixtures cover all three
source bundles, including a 512-byte predicate and their Publication commitments.
These codecs alone do not advertise an executable public v2 service.

`UnifiedResult.open/page` verifies the original request/call route, current source
policy, Document lifecycle, publication publisher and complete manifest. Pages
validate nested Arrow and ordered row/byte/digest coverage, rechecking current
access before return. `Cursor` is owned continuation state, never a bearer token.
Returned Arrow borrows the supplied output buffer; schema/scalar bytes belong to
the supplied result allocator, and decoded conflicts borrow the fixed `Batch`.
An error invalidates the entire page. All ten SDKs pass the signed service
matrix across all three source kinds; see the [proof guide](../../../tests/README.md#m18-qualification).

`UnifiedRequest`, `UnifiedUpload` and `UnifiedBehavior` compose authenticated
finite uploads with the source capture and original-call reply. The
[upload guide](docs/unified-upload.md) documents initialization, duplicate parts,
cancellation, cleanup and logical admission. Component tests and signed worker/node/store recovery pass across all source
kinds. The proof guide records all-source lifecycle/expiry and Table physical
placement, including failed attempts and qualification limits.

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

`Model.Source.contract()` computes the full Table `UQS2` commitment for application
bindings. Board's additive `contract` request returns it alongside the current
source and column-schema hash; existing `describe` and result shapes are unchanged.
Clients compare Table identity and schema in retained v1 manifests before binding
an old result to a newly published interface.

`Draft` adds an explicit finite generation above the existing v2 requester. Its
four-write submission atomically debits an intent and creates the ordinary query
call. `UnifiedClient.draft` and `prepareNextWithDraft` preserve point-addressed
history and exact admission recovery; `Workspace` exposes `draft_open`,
`draft_close`, `draft_status` and `next_draft`. The selected
[draft contract](../../../contracts/QUERY_DRAFT_V1.md) documents wire formats,
eight-intent groups, current authority and closure. Native Table host tests pass;
the coalescing browser scheduler remains in progress. Existing Run, SDK and
Follow profiles retain their separate contracts and qualification matrices.
