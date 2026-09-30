# Catalog callers

`transit_station.catalog.Client` and `AsyncClient` expose the shared catalog
caller through the native ABI. They compile named Table requests, prepare
initialization and conditional policy controls, submit exact saved commands and
read separate processing/application outcomes. Provision a catalog host, its
native resource, ownership and caller grants explicitly. Query access does not
grant catalog administration or create a writer.

```python
from pathlib import Path
from transit_client import ProcessRef, ResourceRef
from transit_station import catalog

scope = catalog.Scope(ResourceRef(realm, resource), catalog_id)
connection = catalog.Connection(ProcessRef(realm, owner), scope)
with catalog.Client(url, principal, Path("caller.seed"), connection) as client:
    compiled = client.compile_sql(
        "CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL)",
        operation_id, object_id, table_id,
    )
    prepared = client.prepare_create(compiled.request)
    # Persist prepared.data and compiled.request through application-owned storage.
    position = client.submit(prepared)
```

Client creation loads the matching native library and supplied key, checks local
capabilities and owns one bounded worker. Importing the module starts no native
work or credential access. Compilation itself is offline; it grants no authority
and reserves no name or identity. `describe()` reads currently authorized metadata.
URLs are at most 2048 UTF-8 bytes; request timeout is 1–60000 milliseconds,
default 5000. Native discovery and `native_directory` follow the
[package installation guide](../README.md).

`Scope`, `Connection`, `Configuration`, `Schema`, `CreateTable`, `Policy`,
`PolicyChange`, `Compiled` and `Prepared` are immutable values. Catalog,
operation, object and policy revision fields use Python integers through the
full uint64 range; the adapter encodes their canonical decimal strings at the
shared boundary. Native identities retain their separate bounds. `CreateTable`
names its object field `object_id`. `Schema` owns exactly two names and a
`CellType`; the shared compiler requires an explicitly non-null int64 key and
explicitly nullable value. `Compiled.canonical` owns the current-definition record
bytes for review; preparation takes the complete typed `compiled.request`.

## Preparation and outcomes

Call `prepare_initialize(Configuration(scope, owner_ref, administrator))` for
the exact host configuration. `prepare_policy(PolicyChange(expected_revision,
policy))` prepares an explicit administrator control. Policy fields are `scope`,
`principal`, `revision`, `inspect` and `create`; expected revision zero denotes
an absent policy. The shared Zig owner validates successor revisions and checks
current metadata. The host independently rechecks authorization and conditions
when processing. Administrator controls and inspection rights remain separate.

Every preparation returns owned opaque `Prepared.data`, bounded to 8192 bytes.
Persist it unchanged before `submit()`, including across caller replacement.
Submission returns an admission position, not a publication result.
`observe(prepared, position)` returns `Observation.PENDING` or `PROCESSED`.
`input_disposition(prepared, position)` reads initialization/policy outcomes and
input rejections; its absence proves no outcome. `status(original_request)`
reads a `Receipt` or `None` under current inspection rights. Only
`Outcome.APPLIED` establishes creation; name, object and Table conflicts remain
distinct frozen outcomes. Current native rights also gate disclosure.

`UncertainOperation` retains the exact submitted bytes in `error.recovery`.
Retry `Prepared(error.recovery)` with the same connection and signing identity;
do not recompile, re-sign or prepare a replacement. Malformed success responses
also preserve submission uncertainty. A definite native rejection keeps its
status/code. Neither process exit nor deleting local recovery bytes cancels work.

## Ownership and asynchronous calls

Each client admits one operation at a time and rejects overlap with `Busy`.
There is no automatic retry, provisioning loop or principal sequence coordinator.
`close()` joins active work before destroying the native handle. Returned values
outlive the handle; opaque bytes and schema name collections own their data.
Native response shapes, decimal strings, enums and numeric bounds are validated.

`AsyncClient` has the same method names, used with `await`, and supports
`async with`. Cancelling an await leaves the native operation owned until it
finishes. Await `close()` to join destruction; closing also remains joined if its
await is cancelled. Store prepared bytes independently of Python tasks.
The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns
atomicity and authority semantics; [proof evidence](../../../../tests/README.md)
records the executed installed-wheel recovery schedules and remaining limits.
