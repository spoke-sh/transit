# Catalog callers

`transit_station.catalog.Client` and `AsyncClient` expose general Tables through
the shared native ABI. They compile SQL or typed schema changes and mutations,
prepare exact signed steps, and read separate input and application outcomes.
Provision the catalog owner, native resource, courier and caller grants
explicitly. Query access does not provision a writer or grant administration.

```python
from pathlib import Path
from transit_client import ProcessRef, ResourceRef
from transit_station import catalog, logical

scope = catalog.Scope(ResourceRef(realm, resource), catalog_id)
connection = catalog.Connection(ProcessRef(realm, owner), scope)
with catalog.Client(url, principal, Path("caller.seed"), connection) as client:
    compiled = client.compile_sql(
        "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200))",
        catalog.Identity(operation_id, staging_namespace),
        create_object=object_id,
    )
    # Persist compiled.saved.definition and compiled.saved.data before dispatch.
    step = client.next(compiled.intent.reference)
    if step.kind is catalog.NextKind.SEND:
        # Persist step.prepared.data unchanged before submission.
        position = client.submit(step.prepared)
        # Persist the position; admission alone does not establish application.
        progress = client.progress(
            compiled.intent.reference, step.prepared, position, wait=True,
        )
```

Client creation checks the generated definition and capabilities, loads the
supplied key and owns one bounded worker. Importing the module starts no native
work or credential access. Compilation and typed preparation resolve currently
authorized metadata where required and freeze its basis; they reserve no name and
grant no execution authority. URLs contain at most 2048 UTF-8 bytes. Request
timeout is 1–60000 milliseconds, default 5000. Native discovery and
`native_directory` follow the [installation guide](../README.md).

## Types and typed operations

`Schema(object_id, revision, next_column, columns, primary_key=())` owns an immutable
tuple of one to 128 `Column` values and stable primary-key column IDs. Each column
has `id`, `name`, a `logical.Descriptor`, default-nullable `nullable`, an optional
`logical.Cell` default and optional `max_characters`. No primary key means an
unkeyed Table; the native owner gives duplicate rows distinct stable identities.
Names contain at most 255 UTF-8 bytes. SQL text contains at most 4096 bytes.

Descriptors are native dataclasses: `ScalarType`, `DecimalType`, `TimestampType`,
`StructureType`, `UnionType`, `ListType`, `ArrayType` and `MapType`. Nested fields
and elements carry their own nullability. Cells are `Missing`, `Null`,
`SourceTypeError`, `Present` or `Conflict`. A `Present` value carries an `Atom`,
`SequenceValue`, `MapValue`, `TaggedValue` or explicitly typed `JsonValue`.
Integers, decimal coefficients and temporal integers use exact Python `int`;
floats specify width 32 or 64; binary and UUID values own `bytes`; intervals have
months, days and nanoseconds. A decimal coefficient's scale belongs to its column
descriptor. These values do not require JSON documents or lossy floating-point
conversion. The existing local `logical.Codec` remains available separately.

`prepare(name, identity, operation)` accepts `Create`, `Alter`, `Rename`, `Drop`
and `Mutate`. Existing-object operations require `definition.metadata.basis`,
which includes the object, metadata revision and schema fingerprint. Stale bases
fail instead of rebinding column IDs to changed schemas or same-named objects.
`Alter` accepts `AddColumn`, `DropColumn`, `RenameColumn`, `SetDefault`,
`SetNullable` and `SetType`; the shared owner qualifies each change and conversion.

`Mutate` takes `Insert`, `Update` or `Delete`. Assignments address stable column
IDs and carry a cell or `Default.VALUE`. Inserts contain one to 1024 rows, each
with at most 128 assignments. UPDATE and DELETE accept an optional tuple of at
most 64 postfix predicate instructions: `Comparison`, `StatePredicate` or
`BooleanOperator`. An absent predicate selects all rows. Native admission owns
schema compatibility, canonical key rules, constraints and atomic execution.

```python
current = client.lookup("people")
assert current is not None
compiled = client.prepare(
    "people", catalog.Identity(operation_id, staging_namespace),
    catalog.Mutate(current.metadata.basis, catalog.Insert((
        (catalog.Assignment(1, logical.Present(logical.Atom("signed", 1))),
         catalog.Assignment(2, logical.Present(logical.Atom("utf8", "Ada")))),
    ))),
)
```

The compiler and typed preparer return `Compiled(intent, saved)`. The handle owns
one intent; a successful new compilation or load replaces that local selection.
The returned immutable intent records connection, principal, operation, staging
namespace, object, kind and exact reference. Catalog identities and revisions
retain their full uint64 range independently of native counter bounds.

## Recovery and outcomes

Persist `SavedIntent.definition` and `SavedIntent.data` independently of Python
tasks. Restore both explicitly, then call `load(saved)` on the same connection
and identity. Missing or foreign definitions fail; they are never substituted.
`forget(reference)` releases local intent memory without cancelling remote work.

Call `next(reference)` until it returns a terminal outcome. A `SEND` step owns
opaque `Prepared.data`, bounded to 8192 bytes; save it before `submit()` and save
the returned admission position separately. `RUNNING` means accepted work still
needs observation; `UPLOAD_CANCELLED` distinguishes cancelled staging from an
applied Table operation. `progress(reference, prepared, position, wait=True)`
waits within the configured request deadline and returns pending or processed
input, an optional disposition, upload state and application outcome.
`observe(..., wait=True)` and `input_disposition()` expose input evidence alone.

`status(reference)` reads current authorized evidence without submitting work.
`Outcome` separates its phase, terminal flag, input positions, semantic diagnostic
and optional `Counts(matched, changed)`. Counts exist only for applied DML;
same-value UPDATE can match one row and change zero. Rejected, cancelled,
unchanged DDL and unfinished work never acquire invented affected-row counts.

`UncertainOperation.recovery` retains the exact submitted bytes. Reconcile
`Prepared(error.recovery)` using the original connection and signing identity.
Do not recompile or prepare a replacement after an uncertain send. Malformed
success replies retain the same uncertainty. Definite native rejections preserve
their status and semantic diagnostic. `prepare_resume(reference)` and
`prepare_control(reference, control)` prepare explicit recorded continuation,
operation cancellation/cleanup or upload cancellation/collection. Deleting local
files and closing a client do not cancel accepted work.

## Metadata, policy and ownership

`describe()` returns the current configuration, caller policy and resource
revision. `lookup(name)` returns a `Definition` with committed metadata, live head
and owned schema, or `None`. `list()` returns at most eight entries containing
metadata and heads, ordered by object ID. Continue only with `page.next`, including
when a page has no visible entries because it scanned retired objects. A cursor
requires definition, scope, resource revision and `after_object`. Changed cuts
fail; discard the incomplete listing and begin again. Cursors confer no authority.

`Configuration` requires explicit `TableLimits(record_bytes, staging_bytes,
staging_records)`. `prepare_initialize`, `prepare_policy` and `prepare_dependency`
produce exact administrator commands. `Rights` explicitly separates inspect,
create, read, insert, update, delete, alter and drop. `PolicyChange` requires the
next revision after its expected revision. `Dependency` names object, identity,
owner and kind; registering or removing one is an explicit control. The native
owner rechecks authority and publication conditions when processing commands.

Each client admits one operation at a time and rejects overlap with `Busy`.
Returned bytes and nested values outlive the handle. Response decoding validates
canonical integers, enum tags, definition IDs, requested identities, page cuts and
outcome/count consistency; the native validator checks diagnostic evidence.
Requests use the generated 16 MiB catalog frame limit. There is no implicit
submission retry or principal-sequence coordinator. Native reads/preparation can
restart only the exact transient stale-resource rejection within the deadline.

`AsyncClient` has the same methods with `await` and supports `async with`.
Cancelling an await leaves native work owned until it finishes. Await `close()`
to join destruction; cancellation of the close await also preserves joined
ownership. The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md)
owns authority and atomicity; [proof evidence](../../../../tests/README.md) records
executed installed-package schedules and their limits.
