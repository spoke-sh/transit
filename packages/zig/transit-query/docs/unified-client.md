# Signed unified query callers

`UnifiedClient` uses the public Transit client and the separate
[v1 contract](../../../../contracts/UNIFIED_QUERY_V1.md). Its connection fixes the
realm, calling principal, source PID/resource and requester PID/resource.
The caller needs current inspect/send authority and read/inspect access to both
resources. No worker ownership or provider credential is used by this API.

Provision the source's declaration/policy, dedicated requester and both durable
behavior configurations first. A Table uses the signed direct Table service and
an explicit requester-to-principal policy; it needs no per-Table worker. Configure
`UnifiedClient.tables` with the Table service endpoint, audience and catalog
connection. The query worker's progress resource is independent of the source
catalog resource. `describe(source)` verifies current source/schema
availability, policy declaration, permitted work limits and the active requester
slot. Its capabilities describe the current v1 finite query interface.
PID-scoped source workers additionally need a non-required association to the
request resource, established before activation, and a separate current read
grant. Associations do not grant access.

Table compilation returns an unsigned description. Explicitly call
`authorizeCapture(bundle, capture)` before saving and uploading an executable
Table bundle. The capture supplies the worker's executor principal, a fresh
nonzero pin-operation identity and the Table's expected partition/log frontier.
The caller signs a delegation for that exact source, worker, query and pin owner,
then binds the complete request to the native query route. Preparing this grant
does not acquire a pin. The worker commits acquisition eligibility before
contacting the Table service. A changed frontier rejects acquisition; recovery
never substitutes a newer cut.

The neutral `authorize` action accepts `{bundle, capture}`. Its capture operation,
partition and log position are decimal strings; `executor` is a native principal
ID. Native KV/Document descriptions omit capture and retain their existing
peer-authorized bytes. Native binding configuration supplies `tables: {url, connection}` separately
from the native query connection. Both connections must use the same caller,
selected role and realm. The Table audience is independent of the query PID.

For one finite canonical `Bundle`, choose a fresh nonzero namespace and call
`prepareNext(namespace, bundle)`. It returns one frozen `Prepared` upload command,
or null when there is no further upload/submission step. Persist the prepared
object before `submit`. On transport uncertainty, submit exactly that object
again. Never prepare a replacement based on a timeout. The host must serialize
command preparation for its principal; sharing a signing sequence concurrently
requires explicit coordination.

The receipt identifies admission of a requester input. Call `observe(position)`
until that input is committed or durably rejected before preparing a successor.
The requester status separately distinguishes uploading, sealed, admitted,
complete, cancelled, denied, rejected and retired. Null from `prepareNext` is not
a claim that a query completed. Original correlation and permanent namespace
identity survive retries and worker replacement.

`describe`, `observe` and `status` restart a stale observation at most three times
with fresh current reads. Continued churn returns `QueryReadConflict`. Denial,
expiry and signed mutations never enter this read retry. Read errors invalidate
candidate output; callers can retry a page with the same cursor after a stale
observation, without advancing coverage.

`page(namespace, cursor, allocator, workspace, output, decoded)` reads an actual
complete result under current policy. It verifies the original route, immutable
manifest, segment commitment and typed nested Arrow, then rechecks access before
return. A null continuation establishes full ordered coverage. The returned IPC
borrows `output`; schema bytes use `allocator`, while `decoded` owns its descriptor and recursive
rows. Call `decoded.deinit()` after each successful page, including before slot reuse. Copy any values that
must outlive these owners. Keep one segment at a time rather than collecting the
whole result in memory.

Use `prepare(.cancel)` for explicit durable cancellation and `prepare(.retire)`
to withdraw a terminal request publication. A cancelled native wait does neither.
Published request retirement stops later result availability and schedules bounded
collection; previously disclosed bytes cannot be retracted. Table traversal
completion or closure commits a decision to release the original pin. Direct
release and its confirmation are separate steps: denial or unavailability leaves
cleanup pending without discarding the source evidence. `prepare(.retry_cleanup)`
retries a terminal request's cleanup. It cannot close an active query's pin.
After a credential rotation, use `prepareCleanup(namespace, originalBundle)`
to sign separate current permission for closing the original grant. The neutral
action is `cleanup: {namespace, bundle}` and returns frozen prepared bytes.
This does not resign the saved query or permit new reads. The worker commits the
closure proof before its next release attempt, preserving it across uncertain
replies and worker replacement. Current denial still leaves cleanup pending.
Result retrieval verifies the retained source commitment and current source
rights without reopening the released pin.

`just test::unified-query` runs actual requester/source daemons and a courier over
disk Ursula. Its schedule persists a frozen command before a lost response,
retries identical signed bytes, kills source work during segment staging, restarts
the node/store, requires fresh worker generations, and revokes access after an
actual returned prefix. The [test ledger](../../../../tests/README.md#m18-qualification)
records which source profiles passed and the remaining qualification obligations.

The neutral `table: {namespace, name}` read resolves a direct definition through
the configured owner. It returns the exact source, full physical/logical schema,
and observed partition/frontier, or a missing result. It acquires no pin and does
not promise that a later capture can still accept that frontier. Python
`lookup_table` and TypeScript `lookupTable` return this evidence and construct
explicit capture input with the caller-selected executor and pin operation.

## Typed query templates

`prepareSql(allocator, definition, name, text)` returns an owned `SqlTemplate`.
It records the complete source definition and exposes inferred
`parameterTypes()`. A replacement resource, Table object/interpretation, KV prefix/decoder or
Document identity, revision or path invalidates reuse, even with equal columns.
The supplied definition and SQL text can be released after preparation.

`bindSql(allocator, template, definition, values, limits)` returns a separately
owned `SqlTemplate.Bound.bundle`. Values use `Types.Values.Atom`, bound to the complete logical descriptor.
The 21 qualified comparison descriptors include exact integer widths, decimal,
float, Boolean, UTF-8/binary, date/time/timestamp and UUID; intervals and
containers do not gain comparisons. Types must match exactly. Source arrays/paths and plan literals are copied.
Release each bound owner with `deinit`, independently of its template. These
methods check current access before and after their work. Binding also checks
the requested budgets at both observations. A denial or reduced budget returns
no candidate bundle and performs no upload.

Pure `SqlTemplate.init`/`bind` check typing and source compatibility without I/O;
their caller must enforce current authorization. Neither API retains source data,
opens a snapshot nor registers named durable prepared state. A bound bundle
uses the existing upload and admission path. Preserve its exact original bytes
and signed commands across uncertainty; binding again is a new query, not retry.
The [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md) defines the
profile. Named PREPARE/EXECUTE, file parameters, CLI parameter arguments and
language convenience parameter APIs remain unsupported.

`SqlCompilation.apply(allocator, client, request)` compiles a complete neutral
request through the same parser, `SqlTemplate` and scalar codecs. The request
contains an explicit `scope` (`name`, `source`, `limits`), `sql` and optional
`parameters`. Omitted/null parameters use ordinary SQL; an array uses template
syntax and must contain exactly the required values. The read-only client
boundary checks permission and budgets before and after compilation. Returned
canonical bundle hex and typed metadata belong to the result allocator, with
independent copies of source paths and values. As with other neutral operations,
use a result arena and release it on both success and failure.

`Bridge.compile` and `Workspace.compile` delegate to this operation; the workspace
supplies its configured scope. Their separate `sql_capabilities` operation
advertises local parameter support without changing existing capability responses.
Table descriptions require explicit capture authorization before upload.
Compilation does not allocate a durable namespace, sign a command or retain a
snapshot, and it cannot resolve uncertain accepted work.
