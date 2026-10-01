# Signed unified query callers

`UnifiedClient` uses the public Transit client and the separate
[v1 contract](../../../../contracts/UNIFIED_QUERY_V1.md). Its connection fixes the
realm, calling principal, source PID/resource and requester PID/resource.
The caller needs current inspect/send authority and read/inspect access to both
resources. No worker ownership or provider credential is used by this API.

Provision the source's declaration/policy, dedicated requester and both durable
behavior configurations first. `describe(source)` verifies current source/schema
availability, policy declaration, permitted work limits and the active requester
slot. Its capabilities describe the current v1 finite query interface.
PID-scoped source workers additionally need a non-required association to the
request resource, established before activation, and a separate current read
grant. Associations do not grant access.

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
borrows `output`; schema/scalar bytes use `allocator`, while conflict alternatives
borrow `decoded`, which must remain at its final address. Copy any values that
must outlive these owners. Keep one segment at a time rather than collecting the
whole result in memory.

Use `prepare(.cancel)` for explicit durable cancellation and `prepare(.retire)`
to withdraw a terminal request publication. A cancelled native wait does neither.
Published request retirement stops later result availability and schedules bounded
collection; previously disclosed bytes cannot be retracted. The source releases
its retained cut at capture completion or closure, before result retrieval.

`just test::unified-query` runs actual requester/source daemons and a courier over
disk Ursula. Its schedule persists a frozen command before a lost response,
retries identical signed bytes, kills source work during segment staging, restarts
the node/store, requires fresh worker generations, and revokes access after an
actual returned prefix. The [test ledger](../../../../tests/README.md#m18-qualification)
records which source profiles passed and the remaining qualification obligations.

## Typed query templates

`prepareSql(allocator, definition, name, text)` returns an owned `SqlTemplate`.
It records the complete source definition and exposes inferred
`parameterTypes()`. A replacement resource, Table ID, KV prefix/decoder or
Document identity, revision or path invalidates reuse, even with equal columns.
The supplied definition and SQL text can be released after preparation.

`bindSql(allocator, template, definition, values, limits)` returns a separately
owned `SqlTemplate.Bound.bundle`. Values use the shared six-type `Unified.Scalar`;
types must match exactly. Source arrays/paths and plan literals are copied.
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
advertises local parameter support without changing existing capability responses. Their compiled bundles use the existing upload and admission path.
Compilation does not allocate a durable namespace, sign a command or retain a
snapshot, and it cannot resolve uncertain accepted work.
