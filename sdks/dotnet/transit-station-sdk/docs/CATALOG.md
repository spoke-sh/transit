# General Table callers

Serialization charges each converted column, assignment and predicate before
building the next owned value. Neutral schemas share 2 MiB and actions share
16 MiB; complete frame admission also counts enclosing fields. Oversized input
rejects before constructing the complete JSON batch or dispatching native work.

`Transit.Station.Sdk.Catalog.Client` exposes authorized schema discovery, typed
Table creation, mutations, schema evolution and retirement through shared Zig.
Provision the catalog host, resource, ownership and caller grants explicitly;
a query connection does not enable catalog administration.

```csharp
await using var client = await Catalog.Client.OpenAsync(config, credential, connection);
var compiled = await client.CompileSqlAsync(
    "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(120), active BOOL)",
    new Catalog.Identity(operationId, stagingNamespace), objectId);
SaveIntent(compiled.Saved.Definition, compiled.Saved.Copy());
var step = await client.NextAsync(compiled.Intent.Reference);
if (step.Kind == Catalog.NextKind.Send) {
    var prepared = step.Prepared!;
    SavePrepared(prepared.Bytes.Copy());
    ulong position = (await client.SubmitAsync(prepared)).Position;
    SaveReceipt(position);
    var progress = await client.ProgressAsync(
        compiled.Intent.Reference, prepared, position, wait: true);
}
```

The persistence functions are application-owned durable writes. This example
sends one step; continue to a terminal outcome before claiming publication.
`Connection(owner, scope)` combines a `ProcessRef` with
`Scope(resource, catalogId)` in one realm; the `Credential` must match.
`ClientConfig` selects the native profile, URL, timeout and optional trusted
native directory. The separate native Station NuGet package is selected by
default. Opening owns a native worker and checks the exact shared definition
and capabilities.

Resolved `Metadata` owns a `MetadataCommitment(bytes, digest)` identifying its
immutable publication. The length is one to 444 bytes and the digest is an
immutable 32-byte `Bytes` value. Query sources consume it with the metadata
revision and schema; it grants no access and does not establish live resolution.

## Types and operations

`Schema(objectId, revision, nextColumn, columns, primaryKey)` owns one to 128
ordered `Column` records. Each column has a stable positive ID, UTF-8 name,
[logical descriptor](LOGICAL.md), nullability, optional logical-cell default and
optional character limit. Columns default to nullable with no default or length
bound. Omitted primary keys preserve duplicate rows with internal row identities;
explicit single/composite keys reference column IDs. Shared Zig validates key,
nullability, default and schema semantics.

Catalog, object, column, operation, staging namespace and revision values are
exact positive `ulong` values. Native resource/process/principal/input IDs retain
their separate safe-integer bounds. Names allow at most 255 UTF-8 bytes; SQL
allows at most 4096 bytes. No physical key/value Table ID is required.

`CompileSqlAsync(sql, identity, createObject)` binds SQL through the authorized
catalog and returns `Compiled(Intent, Saved)`. Supply an object identity for
CREATE; omit it for other statements. Compilation admits no work.
`PrepareAsync(name, identity, operation)` exposes the same semantics through
owned operation records:

- `Create(schema, ifNotExists)`.
- `Mutate(basis, mutation)` with `Insert(rows)`,
  `Update(assignments, predicate)` or `Delete(predicate)`.
- `Alter(basis, change)` with `AddColumn`, `DropColumn`, `RenameColumn`,
  `SetDefault`, `SetNullable` or `SetType`.
- `Rename(basis, name)` and `Drop(basis, ifExists)`.

Obtain the immutable object/revision/fingerprint `Basis` from a looked-up
`Definition.Metadata.Basis`. A stale basis rejects without retargeting work.
Assignments take a column ID and logical cell, or `new Catalog.Default()`.
INSERT owns one to 1024 rows of at most 128 assignments each. UPDATE/DELETE
predicates are optional postfix lists of at most 64 instructions: `Comparison`,
`StatePredicate` and `BooleanPredicate` with `All`, `Negate`, `Conjunction` or
`Disjunction`. Omitted predicates select all rows. Zig owns predicate validation,
frozen selection, atomic publication and exact conversions.

## Explicit progression and recovery

A client owns at most one resident intent. Persist `SavedIntent.Definition` and
its copied binary bytes before any send. Restore both through the constructor,
then `LoadAsync(saved)`. Missing/foreign definitions reject. `ForgetAsync(reference)`
drops only local intent ownership; it does not cancel accepted work. Saved intents
are bounded to the generated 4,327,031-byte limit, action JSON to 16 MiB and
prepared commands to 8192 bytes. Catalog JSON uses a 96-level nesting limit;
raw callers retain their smaller response and nesting limits.

`NextAsync(reference)` returns `Send`, `Running`, `Terminal` or `UploadCancelled`.
Persist each Send's exact `Prepared.Bytes` before `SubmitAsync` and the admitted
position after receiving it. `ObserveAsync(prepared, position, wait: true)` waits
for input processing; `ProgressAsync(reference, prepared, position, wait: true)`
observes processing plus separate disposition, operation outcome and upload
state. Neither processed input nor sealed upload establishes successful
application. `StatusAsync(reference)` reads `State(Outcome, Upload)` without
sending a command.

Terminal phases are `Applied`, `Unchanged`, `Rejected` and `Cancelled`. Only
applied INSERT/UPDATE/DELETE outcomes carry `Counts(Matched, Changed)`; a matched
row with unchanged values can yield one matched and zero changed. Original
outcomes remain bound to their saved object/operation after ALTER, DROP and name
reuse. Current rights still gate diagnostic disclosure. `Diagnostic.Copy()`
returns an independent JSON tree; mutating it cannot change retained evidence.

`PrepareResumeAsync(reference)` and `PrepareControlAsync(reference, control)`
return explicit signed commands. Controls are `CancelOperation`,
`CleanupOperation`, `CancelUpload` and `CollectUpload`. Their meaning depends on
durable state; cleanup does not erase retained accepted evidence. Cancelling a
local Task does not request durable cancellation.

After `ErrorKind.UnknownOutcome`, retain and reconcile the exact original
`Prepared` with the original connection and credential. Do not recompile, re-sign
or replace its intent. Malformed success receipts, transport loss and result
allocation failure preserve uncertainty. Definite native rejections retain their
category, status, code and diagnostic. The client performs no automatic submission
retry; durable recovery material belongs to the application, independently of a
Task or managed object.

## Authority, dependencies and metadata

`PrepareInitializeAsync(Configuration(scope, owner, administrator, tableLimits,
authority, databaseName))` prepares immutable host configuration. `TableLimits`
requires explicit deployment quotas. `AuthorityProfile(databaseDomain,
schemaDomain, tableDomain, database, initialSchema, initialSchemaAuthority)`
contains the six registered native bindings. Provision these explicitly; startup
does not invent objects or restore grants.

`Connection(owner, scope, role: null, schemaNamespace: 1)` selects an eligible
active role and schema namespace. `Client.OpenAsync` accepts an explicit
`tableServiceUrl` for trusted Table mediation. The caller retains its own signing
credential; the service holds its separate infrastructure identity. Restricted
Table users receive no raw-resource access. Omitting the endpoint uses direct
reads and requires separately granted infrastructure rights.

`PrepareDependencyAsync(Dependency(scope, objectId, identity, owner, kind), present)`
registers/removes a dependency. Kinds are `QuerySource`, `Writer`, `Watch`,
`MaintainedRelation` and `History`; registration grants no access. DROP RESTRICT
retains original blocking dependency evidence. `InputDispositionAsync` reads an
administrator-control or rejected-input result. Absence proves no outcome.
`DescribeAsync` returns current configuration, authenticated `Subject` and
`AuthorizationRevision`; `CapabilitiesAsync` returns typed native limits. The
subject carries principal, login role, selected role, credential epoch, audience
and an owned context digest. It grants no authority. Protected disclosures and
owner continuations check current rights; accepted write identities survive
revocation.

`LookupAsync(name)` returns a nullable `Definition(Authorization, Metadata, Head, Schema)`.
`DefinitionAsync(objectId, revision)` returns a nullable accepted
`HistoricalDefinition` with metadata and schema, including after retirement;
it has no current head. Missing/unaccepted definitions are absent. Metadata
includes the schema `Namespace`; `Authorization` identifies the stable native
Table object. Current CONNECT, USAGE and SELECT also govern historical reads.
`ListAsync` returns a `Page` with a resource revision, at most eight ordered
`Entry(Metadata, Head)` values and optional `Next`. Continue while the cursor
exists, including empty pages with continuation. Restore all `Cursor` fields:
definition, scope, resource revision and after-object ID. A cursor grants neither
authority nor a snapshot lease; a changed cut rejects continuation. Discard
partial results before restarting that listing.

Methods return `Task` through one bounded owned worker and the shared C ABI.
Overlap fails with `ErrorKind.Busy`. A previously cancelled token prevents local
admission. Cancellation of admitted work abandons only its local wait; it does
not release native ownership or cancel accepted work. `await using` joins active
work and native cleanup. Collections and binary values own their contents and
outlive the client. Requests are encoded before queuing native work. Generated
recursive schemas and typed decoders validate fields, identities, canonical
integers, budgets and continuations.

The [Table reference](../../../../docs/handbook/reference/tables.md) and
[catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) own authority,
publication and retention. The [proof ledger](../../../../tests/README.md) records
executed installed-NuGet and recovery evidence.
