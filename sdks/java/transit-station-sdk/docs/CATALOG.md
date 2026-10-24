# Direct catalog lifecycle

`Catalog.Client` exposes direct Table definitions, row changes, current inspection
and explicit retention through the shared Zig caller. Compilation and typed
preparation produce frozen work without reserving names or accepting changes.
Provision the catalog service and native grants first.

```java
Catalog.Connection connection = new Catalog.Connection(scope, audience);
try (Catalog.Client client = Catalog.Client.open(config, credential, connection, serviceUrl)) {
    Catalog.Compiled work = client.compileSql(
        "CREATE TABLE people (id BIGINT PRIMARY KEY, name UTF8)",
        new Catalog.Identity(operationId, 1), Optional.of(objectId)).join();
    saveDurably("intent", work.saved().save());
    inspectPreview(client.preview(work.intent()).join());
    Catalog.Reference original = client.stage(work.intent()).join();
    saveDurably("reference", original.save());
    Catalog.Observation observed = client.admit(original).join();
    while (observed.state() == Catalog.OperationState.ADMITTED) {
        observed = client.execute(original, 32).join();
    }
    inspectOutcome(observed);
}
```

Persistence and inspection functions in the example belong to the application.
The application supplies distinct operation IDs and continuation budgets. Staging,
admission and completion are separate. Committed Table work reports the resulting
definition, accepted position and exact `matched`, `affected` and `liveRows`.
Conditional name assertions report a catalog position and `UNCHANGED`, `REJECTED`
or `CANCELLED`, without inventing a Table commit.

`Connection(scope, audience, branch, role)` contains no actor PID. Its two-argument
constructor selects branch one with no explicit role. Credentials supply the
principal. Catalog, branch, object, operation, definition, position and row-count
values use exact uint64 `BigInteger` values. Realm, resource, principal and
namespace counters use validated native safe-integer `long` values.

`ClientConfig` selects `NATIVE_V1`, the authority endpoint, timeout and optional
trusted native executable. `serviceUrl` defaults to the authority URL. Both URLs
exclude user information, query strings and fragments; native catalog timeouts
range from 1 through 60000 milliseconds. Opening checks the current definition
and capabilities, owns a native worker and child, and loads the supplied key. It
initializes no catalog and grants no rights.

## Typed work and current observations

`Schema` owns one to 128 columns with stable IDs, [logical types](LOGICAL.md),
nullability, optional defaults and character bounds. Encoding and collation are
independent descriptors. New columns default to `PLAIN` and `NONE`; returned
schemas require both fields explicitly. Shared Zig validates supported
combinations and conversion semantics. Empty primary keys allow duplicate
unkeyed rows. Names are at most 255 UTF-8 bytes; SQL is at most 4096 bytes.

`prepare(name, identity, operation)` accepts `Create`, `Alter`, `Rename`, `Drop`
and `Mutate`. Existing-object actions require the complete `Metadata.basis()`
returned by `lookup`. `Basis.save()` preserves connection, namespace, name and
stored interpretation; restore it with `Basis.restore(text)`. Stale bases reject
without retargeting a newer definition or a same-named replacement. ALTER supports
adding, dropping and renaming columns, defaults, nullability, logical types and
physical descriptors.

`Mutate(basis, mutation, ingestion)` accepts `Insert`, `Update` and `Delete` with
`POINT` or `BULK` ingestion. The two-argument constructor selects `POINT`.
INSERT owns one to 1024 rows with at most 128 assignments each. UPDATE and DELETE
accept at most 64 postfix predicate instructions; an absent predicate selects
all rows. Assignments address stable column IDs with a logical cell or default.
SQL compilation accepts an optional create-object ID, `Dialect.TRANSIT` or
`MYSQL`, and the ingestion selection. The shared owner enforces atomicity,
constraints and current authorization.

Schema and mutation conversion charge fragments before constructing further
values. Schemas are at most 2 MiB; complete saved work and actions obey generated
`catalog_intent_bytes` and `catalog_action_bytes` limits. Direct catalog frames
can exceed actor frame limits. The [Table reference](../../../../docs/handbook/reference/tables.md)
describes executable storage and codec profiles.

`capabilities`, `describe`, `namespace`, `namespaces`, `tables` and `lookup` return
futures for current observations. Descriptions distinguish authenticated subject
from native policy revision. Metadata pages contain at most eight entries, and
cursors bind the original connection, selection and directory position. A changed
directory requires a fresh scan. Table observations have `INDEPENDENT`
consistency; they do not establish a common transactional snapshot.

## Recovery and retention

Save `SavedIntent.save()` before staging and restore it with
`SavedIntent.restore(text)`, then `load`. Save `Reference.save()` before admission.
`Reference.restore(text)` supports exact `inspect`, `execute` and `cancel`,
including after DROP/name reuse. Missing or foreign definitions reject. One
local intent can be loaded at a time; `forget(intent)` releases only that local
ownership. `NOT_OBSERVED` remains distinct from admission, rejection,
cancellation and commitment.

A mutating future can fail with `Catalog.Uncertain`. Its `original()` is the
saved intent, operation reference, snapshot acquisition or snapshot required for
recovery. `failure()` preserves the native `TransitException`, including status,
code and optional structured diagnostic. `join()` wraps failures in
`CompletionException`; inspect its cause. Save the original value explicitly;
Java object serialization of this exception is refused. Malformed successful
replies and transport loss after dispatch do not establish mutation failure.

`prepareSnapshot(metadata, operationId)` creates an exact acquisition. Save its
`save()` result before `acquireSnapshot`, and save the returned snapshot before
using it. After a lost reply, restore the acquisition and inspect
`snapshotStatus(acquisition.owner())`. Status reports current interpretation and
position separately from retained metadata. `snapshotMetadata(snapshot)` returns
the accepted interpretation, schema and row count after ALTER, DROP and name
reuse. Its authorization object IDs confer no rights; remote reads recheck current
access. This Java API exposes retained metadata, not an interactive SQL cursor.

`releaseSnapshot(snapshot)` explicitly releases the original handle. Save cleanup
responsibility first. After a lost reply, inspect the same owner's status and
retry that release. Closing the client does not release durable snapshots or
assign an expiry. Applications retain cleanup responsibility.

One worker admits one operation at a time. Cancelling a `CompletableFuture`
abandons the local wait without cancelling native ownership. `close()` joins
active work and child cleanup before returning. Responses own their nested data;
mutable JSON values remain behind the SDK boundary.
