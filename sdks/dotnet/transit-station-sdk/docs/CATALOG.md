# Direct catalog lifecycle

`Catalog.Client` exposes direct Table definitions, row changes, current inspection
and explicit retention through the shared Zig caller. Compilation and typed
preparation freeze work without reserving names or accepting changes. Provision
the catalog service and native grants first.

```csharp
using C = Transit.Station.Sdk.Catalog;

var connection = new C.Connection(scope, audience);
await using var client = await C.Client.OpenAsync(config, credential, connection, serviceUrl);
var work = await client.CompileSqlAsync(
    "CREATE TABLE people (id BIGINT PRIMARY KEY, name UTF8)",
    new C.Identity(operationId, 1), objectId);
SaveDurably("intent", work.Saved.Save());
InspectPreview(await client.PreviewAsync(work.Intent));
var original = await client.StageAsync(work.Intent);
SaveDurably("reference", original.Save());
var observed = await client.AdmitAsync(original);
while (observed.State == C.OperationState.Admitted) {
    observed = await client.ExecuteAsync(original, 32);
}
InspectOutcome(observed);
```

Persistence and inspection functions belong to the application. The application
supplies distinct operation IDs and continuation budgets. Staging, admission and
completion are separate. Committed Table work reports the resulting definition,
accepted position and exact `Matched`, `Affected` and `LiveRows`. Conditional name
assertions report a catalog position with `Unchanged`, `Rejected` or `Cancelled`;
they do not invent a Table commit.

`Connection(scope, audience, branch: 1, role: null)` contains no actor PID.
Credentials supply the principal. Catalog, branch, object, operation, definition,
position and row-count values use exact uint64 `ulong` values. Realm, resource,
principal and namespace counters retain their native safe-integer bounds.
`ClientConfig` selects `Profile.NativeV1`, authority endpoint, timeout and optional
trusted native library directory. `serviceUrl` defaults to the authority URL.
Both endpoints exclude user information, query strings and fragments. Native
catalog timeouts range from 1 through 60000 milliseconds. Opening checks the
current definition and capabilities, loads the supplied key and owns an ABI
worker. It initializes no catalog and grants no rights.

## Typed work and inspection

`Schema` owns one to 128 columns with stable IDs, [logical types](LOGICAL.md),
nullability, optional defaults and character bounds. Encoding and collation are
independent descriptors. New columns default to `Plain` and `None`; returned
schemas require both explicitly. Shared Zig validates supported combinations and
conversion semantics. Empty primary keys permit unkeyed duplicate rows. Names
are at most 255 UTF-8 bytes; SQL is at most 4096 bytes.

`PrepareAsync(name, identity, operation)` accepts `Create`, `Alter`, `Rename`,
`Drop` and `Mutate`. Existing-object actions require the complete `Metadata.Basis`
returned by `LookupAsync`. `Basis.Save()` preserves the connection, namespace,
name and stored interpretation; restore it with `Basis.Restore(text)`. Stale
bases reject without retargeting newer definitions or same-named replacements.
ALTER supports adding, dropping and renaming columns, defaults, nullability,
logical types and physical descriptors.

`Mutate(basis, mutation, ingestion: Ingestion.Point)` accepts `Insert`, `Update`
and `Delete`; `Ingestion.Bulk` stages immutable data directly. INSERT owns one to
1024 rows with at most 128 assignments each. UPDATE and DELETE accept at most 64
postfix predicate instructions; an absent predicate selects all rows. Assignments
address stable column IDs with logical cells or defaults. SQL compilation accepts
an optional create-object ID, `Dialect.Transit` or `Mysql`, and ingestion selection.
Shared owners enforce constraints, atomic publication and current authorization.

Schema and mutation conversion charge fragments before constructing further
values. Schemas are at most 2 MiB. Complete saved work and action frames obey the
generated `catalog_intent_bytes` and `catalog_action_bytes` limits. Direct catalog
requests can exceed actor frame limits. The [Table reference](../../../../docs/handbook/reference/tables.md)
describes executable storage and codec profiles.

`CapabilitiesAsync`, `DescribeAsync`, `NamespaceAsync`, `NamespacesAsync`,
`TablesAsync` and `LookupAsync` return current observations. Descriptions separate
authenticated subject from native policy revision. Pages hold at most eight
entries; cursors bind their original connection, selection and directory position.
A changed directory requires a fresh scan. Table observations have `Independent`
consistency, without establishing a shared transactional cut.

## Recovery and retention

Save `SavedIntent.Save()` before staging. `SavedIntent.Restore(text)` and
`LoadAsync` restore local work without recompilation. Save `Reference.Save()`
before admission; `Reference.Restore(text)` supports exact `InspectAsync`,
`ExecuteAsync` and `CancelAsync`, including after DROP/name reuse. Missing or
foreign definitions reject. One local intent can be loaded at a time.
`ForgetAsync(intent)` releases that local ownership without cancelling accepted
work. `NotObserved` remains distinct from admission, rejection, cancellation and
commitment.

`Catalog.Uncertain.Original` retains the exact saved intent, operation reference,
snapshot acquisition or snapshot needed for recovery. `Failure` preserves the
native `TransitException`, status, code and optional structured diagnostic.
Malformed successful replies and transport loss after mutation dispatch do not
establish mutation failure. Persist the original value and recover the same
identity instead of recompiling or inventing a replacement operation.

`PrepareSnapshot(metadata, operationId)` creates an exact acquisition. Save its
`Save()` result before `AcquireSnapshotAsync`, then save the returned snapshot.
After a lost reply, restore the acquisition and inspect
`SnapshotStatusAsync(acquisition.Owner)`. Status reports current Table
interpretation and position separately from retained metadata.
`SnapshotMetadataAsync(snapshot)` returns the accepted interpretation, schema
and row count after ALTER, DROP and name reuse. Its authorization object IDs do
not confer rights; remote reads recheck current access. This .NET API exposes
retained metadata, not an interactive relational cursor.

`ReleaseSnapshotAsync(snapshot)` explicitly releases the original handle. Save
cleanup responsibility first. After a lost reply, inspect the same owner's status
and retry that release. Client disposal does not release durable snapshots or
assign an expiry. Applications retain cleanup responsibility.

One worker admits one operation at a time. A cancelled `CancellationToken`
abandons a local wait without cancelling native ownership. `DisposeAsync()` joins
active work and native cleanup before returning. Responses own their nested data;
mutable JSON representations remain behind the SDK boundary.
