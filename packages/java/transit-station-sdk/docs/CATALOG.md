# General Table callers

Serialization charges each converted column, assignment and predicate before
building the next owned value. Neutral schemas share 2 MiB and actions share
16 MiB; complete frame admission also counts enclosing fields. Oversized input
rejects before constructing the complete JSON batch or dispatching native work.

`Catalog.Client` exposes authorized schema discovery, typed Table creation,
mutations, schema evolution and retirement through the shared native caller.
Provision the catalog host, resource, ownership and caller grants explicitly;
a query connection does not enable catalog administration.

```java
var scope = new Catalog.Scope(resource, catalogId);
var connection = new Catalog.Connection(owner, scope);
try (var client = Catalog.Client.open(config, credential, connection)) {
    var compiled = client.compileSql(
        "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(120), active BOOL)",
        new Catalog.Identity(operationId, stagingNamespace), Optional.of(objectId)).join();
    saveIntent(compiled.saved().definition(), compiled.saved().bytes());
    var step = client.next(compiled.intent().reference()).join();
    if (step.kind() == Catalog.NextKind.SEND) {
        var prepared = step.prepared().orElseThrow();
        savePrepared(prepared.bytes().copy());
        long position = client.submit(prepared).join().position();
        saveReceipt(position);
        var progress = client.progress(compiled.intent().reference(), prepared, position, true).join();
    }
}
```

The persistence functions are application-owned durable writes. This example
sends one step; continue to a terminal outcome before claiming publication.
`owner` and `resource` are `ProcessRef` and `ResourceRef` in one realm; the
`Credential` must match. `ClientConfig` selects the native profile, URL, timeout
and optional trusted executable. The separate native Station JAR is selected by
default. Opening owns a port, worker and completion publisher and checks the exact
shared definition and capabilities.

## Types and operations

`Schema(object, revision, nextColumn, columns, primaryKey)` owns one to 128
ordered `Column` records. Each column has a stable positive `id`, UTF-8 `name`,
[logical descriptor](LOGICAL.md), nullability, optional logical-cell default and
optional `maxCharacters`. The three-argument column constructor defaults to
nullable with no default/length bound. The schema convenience constructor omits
primary keys. Empty keys preserve duplicate rows with internal row identities;
explicit single/composite keys reference column IDs. Shared Zig validates key,
nullability, default and schema semantics.

Catalog, object, column, operation, staging namespace and revision values are
exact positive uint64 `BigInteger` values. Native resource/process/principal/input
IDs retain their separate safe-integer bounds. Names allow at most 255 UTF-8
bytes; SQL allows at most 4096 bytes. No physical key/value Table ID is required.

`compileSql(sql, identity, createObject)` binds SQL through the authorized catalog
and returns `Compiled(intent, saved)`. Supply an object identity for CREATE; the
two-argument overload omits it. Compilation admits no work. `prepare(name,
identity, operation)` exposes the same semantics through sealed operation types:

- `Create(schema, ifNotExists)`.
- `Mutate(basis, mutation)` with `Insert(rows)`,
  `Update(assignments, predicate)` or `Delete(predicate)`.
- `Alter(basis, change)` with `AddColumn`, `DropColumn`, `RenameColumn`,
  `SetDefault`, `SetNullable` or `SetType`.
- `Rename(basis, name)` and `Drop(basis, ifExists)`.

Obtain the immutable object/revision/fingerprint `Basis` from
`lookup(name).join().orElseThrow().metadata().basis()`. A stale basis rejects
without retargeting work. Assignments take a column ID and logical cell, or
`Default.VALUE`. INSERT owns one to 1024 rows of at most 128 assignments each.
UPDATE/DELETE predicates are optional postfix lists of at most 64 instructions:
`Comparison`, `StatePredicate` and `BooleanOperator.ALL`, `NEGATE`, `CONJUNCTION`
or `DISJUNCTION`. Empty Optional selects all rows. Zig owns predicate validation,
frozen selection, atomic publication and exact conversions.

## Explicit progression and recovery

A client owns at most one resident intent. Persist `SavedIntent.definition()` and
its owned binary bytes before any send. Restore both through the constructor,
then `load(saved)`. Missing/foreign definitions reject. `forget(reference)` drops
only local intent ownership; it does not cancel accepted work. Saved intents are
bounded to the generated 4,327,031-byte limit, action JSON to 16 MiB and prepared commands
to 8192 bytes. Catalog frames use their own generated limit and 96-level JSON
nesting limit; raw callers retain their smaller frame and nesting limits.

`next(reference)` returns `SEND`, `RUNNING`, `TERMINAL` or `UPLOAD_CANCELLED`.
Persist each SEND's exact `Prepared.bytes()` before `submit` and the admitted
position after receiving it. `observe(prepared, position, true)` waits for input
processing; `progress(reference, prepared, position, true)` observes processing
plus separate disposition, operation outcome and upload state. Neither processed
input nor sealed upload establishes successful application. `status(reference)`
reads `State(outcome, upload)` without sending a command.

Terminal phases are `APPLIED`, `UNCHANGED`, `REJECTED` and `CANCELLED`. Only applied
INSERT/UPDATE/DELETE outcomes carry `Counts(matched, changed)`; a matched row with
unchanged values can yield one matched and zero changed. Original outcomes remain
bound to their saved object/operation after ALTER, DROP and name reuse. Current
rights still gate diagnostic disclosure. Diagnostic access returns an owned copy.

`prepareResume(reference)` and `prepareControl(reference, control)` return
explicit signed commands. Controls are `CANCEL_OPERATION`, `CLEANUP_OPERATION`,
`CANCEL_UPLOAD` and `COLLECT_UPLOAD`. Their meaning depends on durable state;
cleanup does not erase retained accepted evidence. A cancelled future does not
request durable cancellation.

After `UNKNOWN_OUTCOME`, retain and reconcile the exact original `Prepared` with
the original connection and credential. Do not recompile, re-sign or replace its
intent. Malformed success receipts, transport loss and result-allocation failure
preserve uncertainty. Definite native rejections retain their category, status,
code and diagnostic. The client performs no automatic submission retry; durable
recovery material belongs to the application, independently of a future or JVM.

## Policy, dependencies and metadata

`prepareInitialize(Configuration(scope, owner, administrator, tableLimits))`
prepares immutable host configuration. `TableLimits(recordBytes, stagingBytes,
stagingRecords)` requires explicit deployment quotas. `preparePolicy(PolicyChange(
expectedRevision, policy))` prepares conditional administrator control. A `Policy`
owns scope/principal/revision and eight independent boolean `Rights`: inspect,
create, read, insert, update, delete, alter and drop. Expected revision zero means
an absent policy. The caller and host validate successor revision and authority.

`prepareDependency(Dependency(scope, object, identity, owner, kind), present)`
registers/removes a dependency. Kinds are `QUERY_SOURCE`, `WRITER`, `WATCH`,
`MAINTAINED_RELATION` and `HISTORY`; registration grants no access. DROP RESTRICT
retains the original blocking dependency evidence. `inputDisposition` reads an
administrator-control or rejected-input result. Absence proves no outcome.
`describe` returns current configuration/policy; `capabilities` returns typed
native limits.

`lookup(name)` returns optional `Definition(metadata, head, schema)`.
`definition(object, revision)` returns optional accepted `HistoricalDefinition`
with metadata and schema, including after retirement; it has no current head.
Missing/unaccepted definitions are absent. `list` returns a `Page` with a resource
revision, at most eight ordered `Entry(metadata, head)` values and optional `next`.
Continue while the cursor exists, including empty pages with continuation. Restore
all `Cursor` fields: definition, scope, resource revision and after-object ID.
A cursor grants neither authority nor a snapshot lease; a changed cut rejects
continuation. Discard partial results before restarting that listing.

Operations return `CompletableFuture`; one client admits one job at a time and
rejects overlap with `BUSY`. Cancelling a future leaves admitted native work owned.
`close` joins native work and cleanup and preserves caller interruption. Do not
block a synchronous completion callback waiting for the same publisher. Owned
lists and binary values outlive the client; mutable inputs are copied before work
can outlive their caller. Generated recursive schemas and typed decoders validate
fields, identities, canonical integers, budgets and continuations.

The [Table reference](../../../../docs/reference/tables.md) and
[catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) own authority,
publication and retention. The [proof ledger](../../../../tests/README.md) records
executed installed-JAR and recovery evidence.
