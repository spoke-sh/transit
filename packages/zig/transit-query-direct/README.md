# transit-query-direct

Finite SQL query execution over authorized direct Tables, exported as
`transit_query_direct`. The package depends on Catalog, Fuze and the public
protocol. Its compiled dependency graph excludes Station.

`ApplicationData` connects Fuze's ordered-program operands to native typed
values, KV point reads and exact revision-guarded mutations, retained single-row
SELECTs, Table row assertions and Stream/Queue append preparation. SELECT keeps
the caller's original snapshot, bounds scanned rows and requests, rejects a
second matching row and checks current read authority after buffering. A
Document result carries the native collection state fingerprint; a Table result carries
its exact source fingerprint. KV revisions remain point-value identities.
`CURRENT_REVISION` performs a one-key lookup on a versioned row Document. A
missing key returns NULL. Inside an atomic block its collection revision uses
the same retained serializable guard as SELECT. Its fingerprint excludes
acceptance advances caused only by pinning or maintenance; the native decision
still rechecks the full guard. Outside, the point read refuses a changed basis.
Neither path silently moves to another data cut.
`DO ASSERT SAME ROW` compares every typed value in a serializable transaction;
an existing key alone cannot satisfy it. Prepared mutations preserve the original
operation and use the existing common transaction API. These adapters do not
install, schedule or recover an application. Managed Queue integration remains
tracked by [#430](https://github.com/spoke-sh/transit/issues/430).

`ApplicationBinding` reconstructs immutable native resource definitions, keeping
row positions and current grants out of the compiled identity.
Sink bindings preserve the complete immutable transport profile and exact
connection dependency. Binding requires inspection for retained continuation
disclosure and separate dispatch use. Both remain current native requirements; sinks
are excluded from common data transaction participants. A retained sink binding
does not grant dispatch permission or establish a current activation state.
`ApplicationDeclaration` retains the typed instruction tree, publication connection,
exact dependencies and per-invocation budgets. `ManagedApplication` publishes that
definition through owned records and the shared catalog/KV lifecycle. Its saved
controls separate publication, explicit role authorization and activation;
authorization selects a nonzero executor role without changing the definition.
Every admitted invocation freezes that role, including its transaction, input and
effect identities. Execution checks it against current control; recovery and
cleanup use the original role and never substitute a later one. The permanent
token fingerprint commits the invocation's declaration, role, lease and input
claim; loading, advancing and executing progress verify it even after original
payload closure. Readiness
rechecks current dependency actions through the native owner. These
typed operations do not yet supply installed SQL execution.

Programs using `SECRET` or `SECRET_CURRENT` must bind the canonical
`transit.secret_references` KV definition. Compilation records that requirement;
executable declaration binding rejects missing or duplicate native owners and
merges the implicit read with any explicit use. Readiness requires KV READ and
`use_secret`; common transactions include the secret resource as a read-guarded
participant. An unrelated KV with identical columns cannot satisfy the binding.

`ApplicationInvocation` attaches original work before Queue acquisition and
retains the original claim receipt before reading its input. An immutable input
record contains the initial typed environment and original enqueue operation,
row ordinal and Queue partition behind current input/control read guards.
Recovery metadata contains only identities, receipts and references.
Every data call composes the invocation progress fence with the service lease;
suspend and retire cancel the saved pending token before changing the head.
Input retention does not ACK the Queue message or execute the program.

`ApplicationExecution.tick` advances one persisted invocation phase with a
caller-supplied native expression host. It retains proposed successor values
before dispatching native work. A proposal is not a committed checkpoint.
The host binds separately for each evaluation, after opening any transaction
view, with the current fenced client, original input, invocation and step.
Borrowed binding values cannot outlive that evaluation.
`Context.requireCurrent` rechecks the invocation fence, active control head and
registered dependency rights through the exact executor role. Control checks
observe current state even during an atomic block; data helpers keep their
private transaction view. Each successful bind returns a `BoundHost` with its
expression context and mandatory release callback. Cleanup runs on that exact
context after candidate retention or any failure. Factories serving concurrent
evaluations return distinct borrowed contexts; cleanup cannot select another
request through shared factory state. Failed binding releases any partial borrow. A current observation does not authorize later dispatch
or disclosure without another check.
`ApplicationTransaction` selects exact Table, row Document, KV and log partitions
under the existing serializable transaction owner; read access is required for
write participants as well as declared reads. Native provisional statement
completions and terminal decisions remain the evidence for their original work.
The first committed boundary includes the exact input ACK and a transaction-owned
checkpoint. Later boundaries retain that checkpoint without another ACK.
Single-record SELECT outside an atomic block uses a bounded original read
transaction and releases it before adopting the retained observation.

Failure entry follows verified native abort and drops the failed body's locals.
Guard refusals preserve `EffectGuardRefused` and `ResponseGuardRefused` from the
original typed instruction, alongside application-written `REQUIRE` codes.
A lost or expired transient request enters that failure path while retaining
its distinct reason. It does not cancel the durable input or replace the
original transaction. Public failure-handler state and receipts can still settle
after protected bytes disappear; response delivery remains a separate outcome.
A failed failure handler terminates without recursive entry. Cancellation resolves
the original transaction before deciding whether it committed; it cannot replace
a committed success with refusal. The control head retains its pending invocation
until the original input read is released, so retirement cannot remove its
dependencies early. Cancelled acquisition closes the original claim and releases
any accepted read without ACKing its input. Terminal progress retains native
decision evidence; hosts must retry closing an attached original even when its
progress already says `pending = false`.

`ApplicationEffect` supplies effect bookkeeping through the same native owned
records and conditional progress operations. Its key binds one invocation step;
changed operands conflict with the frozen descriptor. Admission permanently
binds a fresh nonce in the original receipt. Only the successful live admission
returns an attempt; replay and lost admission replies cannot return another one.
Admission first verifies that the exact guarded request is durably retained.
The caller must still verify current sink, program, secret, guard and deadline
authority before sending. This component performs no HTTP and does not establish
honest computation by a caller holding the native identity.

Recorded outcomes distinguish unsent refusal, unknown remote outcome and a
complete response, including loss of its transient protected body. Cancellation
preserves a known response. After a worker fence changes, recovery may record
unknown but cannot authorize another send. An interrupted outcome publication
resumes its exact saved bytes; missing bytes remain unresolved. Closing an
unretained original races retention under the native revision and establishes
that no fresh attempt escaped only when closure wins. The host must withdraw
and join the live task before using that closure path. Ordered execution and
HTTP worker integration remain required before this owner runs application effects.

Frozen limits bound each SELECT's requests/scanned rows/result bytes, native
transaction participants/statements/work, each continuation payload and cumulative
retained input/proposal/checkpoint bytes. The request limit also bounds partition
expansion; it is not a count of transport retries. These typed owners currently
execute data instructions and failure continuations. `ApplicationRecovery`
reopens frozen declarations and invocations for bounded service scheduling,
including interrupted final closure and defeated attachment cleanup.
The compiler derives required host functions and facilities from all branches,
failure handlers and the input schema. A deployment-supplied host must report
ready before the service creates or acquires an invocation. Unavailable placement
parks the existing original; accepted transaction settlement and cancellation
cleanup do not depend on host availability. The default host admits public data
programs and refuses protected inputs, effects, responses, handoffs, paging and
deadlines until the corresponding implementation is supplied. These checks
describe placement and support, and confer no native rights.
`ApplicationHost` supplies native public time, entropy, duration, digest and
Document revision observations; the runner retains their original candidate
before advancing. Its JSON/URL helpers share Fuze's bounded lossless parser,
reject duplicate fields and protected values, and preserve exact integer tokens.
See the [program contract](../../../contracts/APPLICATION_PROGRAM_V1.md#protected-values)
for admitted JSON paths, conversions and URL construction.
SQL installation, HTTP effects and response/capability operations remain
integration work in [#430](https://github.com/spoke-sh/transit/issues/430).

`DirectTablePrepared` binds a typed SELECT to an immutable Table definition.
`DirectTableQuery` executes it over an explicitly retained snapshot with bounded
rows, bytes and source requests. `DirectRelationalCompilation` and
`DirectRelationalQuery` supply finite joins and grouped aggregation over explicit
source cuts. Independent Table cuts remain an independent source vector.

The historical preparation entry points bind names and schemas through a
published `DirectHistory` catalog before compiling. Prepared bindings retain
the exact catalog identity as well as each source cut. Historical executors
scan those retained sources and validate current access on every disclosure;
they never substitute a live-name lookup or a newer physical index. Their
borrowed catalog pins remain owned by the original acquisition. The
[historical SQL reference](../../../docs/handbook/reference/sql/as-of.md)
defines the admitted selector and read-only scope.

The caller owns snapshot acquisition and release. Closing an executor releases
its local buffers and spill work; it does not release the caller's retained pin.
Current authorization is checked after computation and before disclosure,
including empty results and terminal batches. Cancellation or failure preserves
an incomplete prefix and never recaptures a different snapshot.

`ComputePool` owns bounded reusable workers and vector scratch. `RelationalSpill`
provides bounded disk scratch for the relational executor. Neither supplies
application scheduling, durable operation admission or an execution authority.
The SQL service and captured-query integration both use these same executors.

`RelationalBridge` exposes neutral requests and a retained-Table session over
the relational executor. It borrows clients, I/O and the spill directory from its
host, which serializes calls and joins them before destruction. Only the current
page can be repeated; each disclosure rechecks current source rights.
`TableChangeReader` supplies snapshot backfill and bounded change handoff over
an explicitly retained direct history lease. Its checkpoint names a complete
acceptance, and reopening repeats an incomplete transaction from its beginning.
Local closure never releases that durable lease. `transit_query` re-exports
these exact modules for captured/interactive composition, and the public Zig
SDK exports `transit_query_direct` independently.

Run `zig build check` and `zig build test` from this directory in `nix develop`.
`-Dtest-filter=<substring>` selects focused existing component schedules.
The [query reference](../../../docs/handbook/reference/queries.md) describes
supported SQL and source semantics; the [SQL service](../transit-sql/README.md)
owns sessions, operation recovery and read-pin cleanup.

`DirectView` expands an accepted single-Table projection/filter over the exact
source declaration. Historical preparation resolves the retained view before
compiling the outer SELECT. Source filtering precedes outer expressions, and
view identity participates in the binding fingerprint and disclosure guard.
DESCRIBE and EXPLAIN use the same metadata bindings. General graph/foreign
execution, view joins, captured views, explicit schema projection and transaction
composition over views remain unavailable. See the
[catalog interpretation contract](../../../contracts/CATALOG_DEFINITIONS_V1.md).

`ManagedTable` composes immutable catalog records, named direct KV control and
common Table/KV transactions for finite recomputation. Save the complete
`Declaration` before `publish`, and save `prepareControl` bytes before
`applyControl`; retries use those original bytes. `inspect` returns lifecycle,
source coverage and the committed transaction decision. The service drives
`start`/`step` with bounded workers and an owned spill directory. Hosts serialize
a work token and retain it until completion. On activation, page pending tokens
with `DirectClientToken.list(client, ManagedTable.workAccount(), after, true)`
and resume their exact `step` calls before discovering new work with `start`.
Declaration and initial work staging reserve original tokens before creating
`SOR1` payloads. Publication retains declarations permanently. Work attachment
saves and executes the exact pending-head KV operation through Catalog; recovery
can discover it before any head write. `closeOriginal(progress)` explicitly
abandons unattached staging under the Catalog fence. A reserved payload needs
the saved staging request to complete creation. Terminal work closes its original
payload after transaction cleanup; closure never releases retained revisions.
Subsequent `DFW1` progress uses Catalog-owned `CPR1` records, with one durable
candidate reservation before byte creation. The open original, current and candidate records
share a 64 KiB token reservation. Superseded progress and closed originals are
collectible; permanent receipts retain their commitments and closure. A terminal work
record stays retained, independently of result-page retention.
A prepared control participant can refuse `inspect` or `start`; recovery must
not depend on reading that participant to discover its pending transaction.

`ManagedRevision.open(manager, declaration, revision, limits)` reads one completed
revision from its immutable schema and row pages, independently of later output
Table writes. `next(&output)` copies each row into a caller-owned arena; reset
that arena only after consuming its rows. Rows follow ascending evaluation ordinal
through a bounded forward page-reference chain, including across page boundaries.
An unordered SQL read of the mutable output Table has no such ordering guarantee. Call `validateDisclosure` after buffering
and before exposing schema, metadata or rows. Reads recheck current source, output
and control access, including empty and terminal results. Defaults bound consumption
to 10,000 rows and 16 MiB of encoded manifest/link/page bytes. Budget stops and failures
do not establish completion. `deinit` frees local memory without releasing the
retained revision or retiring the computation. Result pages and manifests use
transaction-owned immutable records. Their original transaction retains them
through uncertainty; completed abort cleanup permits physical candidate
collection. Committed records retain indefinitely.

See [managed Table computations](../../../docs/handbook/reference/queries.md#managed-table-computations)
for supported SQL, current-policy checks and retention limits.

`ManagedInspection.apply` provides bounded, read-only computation metadata with
lossless host values. It calls Catalog's signed `managed_inspection` action and
never opens a retained row reader. Requests explicitly select namespace/name,
optionally fence the computation definition, and optionally select one positive
revision. SQL SHOW uses that same native owner. An independent reader needs the
current source/output/control read conjunction, not publisher credentials.

`ManagedTable.diagnostics` provides opt-in, fixed-cardinality process observations
of recovery phases and successful result-page staging. Hosts configure it before
starting workers and never reset it during work. The private SQL deployment
inspection composes it with the catalog's owned-record counters; neither supplies
completion or cleanup authority. See the [measurement semantics](../../../docs/handbook/reference/observability.md).
