# General Table callers

Include `transit/catalog.hpp` and use `transit::sdk::station::catalog` for direct
Table definitions, DDL/DML, catalog inspection and explicit snapshot retention.
`Client::open(config, credential, connection, service_url)` selects a catalog
scope, audience, branch and optional role. `Identity` selects an operation and
namespace. The [C SDK](../../../c/transit-station/docs/CATALOG.md) owns bounded
dispatch and shared native validation; C++ adds typed actions and RAII ownership.

`compile_sql` and `prepare(name, identity, action)` return a move-only `Compiled`.
Compilation accepts a dialect, point/bulk ingestion mode and optional new CREATE
object identity. Typed `Action` selects Create, Alter, Rename, Drop, Insert, Update
or Delete. Persist `compiled.saved().save()` before `stage(compiled.intent())`.
Persist the returned `Reference::save()` before `admit`. Use `inspect`, `execute`
and `cancel` with the exact reference. Admission and completed publication are
distinct; committed row results report matched, affected and live row counts.
`preview` reports the current definition and proposed work without applying it.

`SavedIntent`, `Basis`, `Reference`, `Cursor`, `SnapshotOwner`,
`SnapshotAcquisition` and `Snapshot` own complete immutable recovery values.
`save()` returns copied JSON bytes; `restore(bytes)` validates and copies them,
including the mandatory current definition. `copy(native())` explicitly copies a
borrowed C value. These handles are move-only. An `Intent` shares immutable
ownership with its compiled result, so it survives destruction of that result.
`load(saved)` installs the original work in a fresh client without resolving its
name again.

Mutating calls throw `catalog::Uncertain` when dispatch has an unknown outcome.
`failure()` retains the native failure and `original()` owns a `Recovery` variant:
SavedIntent for staging, Reference for operation calls, SnapshotAcquisition for
pin acquisition, or Snapshot for release. The wrapper captures this value before
dispatch and moves it into the exception without allocating or re-signing after
dispatch. The caller's input remains intact. Other failures throw `sdk::Error`.
No method automatically retries or assigns a replacement operation identity.

`lookup(name, namespace)` returns optional owned `Metadata`; `basis()` preserves
the complete object interpretation and `schema()` returns owned logical columns.
Descriptions expose the current configuration, authenticated subject and policy
revision. `namespace_read`, `namespaces` and `tables` inspect namespaces and bounded
metadata pages. Each page has at most eight entries and an optional owned cursor;
empty pages can continue. Preserve every cursor field, and restart a partial
listing if its directory cut conflicts. Table data positions remain independent.

`prepare_snapshot(metadata, operation)` constructs a durable ownership request.
Persist it before `acquire_snapshot`. Recover a lost reply through
`snapshot_status(acquisition.owner())`. Persist the discovered handle before
reading or releasing it. `snapshot_metadata` preserves the original schema and
accepted position after ALTER, DROP or name reuse, subject to current access
checks. `release_snapshot` closes that explicit ownership; status resolves an
uncertain release. Client close and destruction join local work without cancelling
operations or releasing durable pins. There is no interactive relational SQL,
namespace administration, dependency-control or named KV/Document publication
wrapper in this catalog interface.

Schemas and changes use immutable [logical types and cells](LOGICAL.md), stable
column IDs, defaults, nullability, character limits and primary keys. Encoding and
collation remain separate descriptors; `SetPhysical` requests native validation.
An absent `Assignment::value` means DEFAULT; `logical::Cell::null()` means SQL
NULL. ADD obtains its column ID at native admission. `Insert`, `Update` and
`Delete` select an `Ingestion` mode. Input trees are copied before native dispatch.

Schemas admit 128 columns, inserts 1,024 rows and predicates 64 postfix terms.
SQL admits 4,096 bytes; encoded intents 8,388,644 bytes; complete actions
16,793,672 bytes; responses 16,810,056 bytes. Aggregate construction stops at its
bound. Catalog, branch, object, operation and accepted positions preserve all
64 bits; native realm/resource/principal/audience/namespace IDs keep their
safe-integer bound. One native intent is resident per client.

Result owners and copied schemas outlive clients. `view()` exposes a read-only C
SDK construction/result view borrowed from its owner; `native()` is for explicit
C interoperation. Overlap returns `BUSY`; close and destruction join active calls.
Deferred POSIX cancellation waits through receipt publication. Join caller threads
before destroying their borrowed handles.

The [direct catalog contract](../../../../contracts/DIRECT_TABLE_V1.md) owns
native semantics. The [proof ledger](../../../../tests/README.md) records installed
recovery and boundary evidence.
