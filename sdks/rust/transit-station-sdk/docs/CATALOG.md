# Direct Table lifecycle

`transit_station_sdk::catalog::Client` compiles, prepares and executes named Table
work through the shared Zig direct catalog owner. A connection names a catalog
scope, audience, branch and optional active role. Provisioning supplies these
identities and their grants. A connection does not allocate a catalog or grant
access. Namespace selection belongs to each operation and lookup.

```rust
use transit_station_sdk::catalog::{Client, Connection, Dialect, Identity, Ingestion, Scope};

let connection = Connection::new(Scope::new(resource, catalog_id)?, audience)?;
let mut client = Client::open(config, credential, connection, Some(service_url))?;
let work = client.compile_sql(
    "CREATE TABLE people (id BIGINT PRIMARY KEY, name VARCHAR(80))",
    Identity::new(operation_id, 1)?,
    Some(object_id),
    Dialect::Transit,
    Ingestion::Point,
)?;
persist_intent(&work.saved.save())?; // Application-owned durable persistence.
let original = client.stage(&work.intent)?;
persist_reference(&original.save())?;
let observed = client.admit(&original)?;
```

`Client::open` accepts a growing `ClientConfig`, a credential and an optional
service URL. Without a separate URL, direct catalog requests use the configured
node endpoint. Opening verifies the native ABI and local catalog capabilities;
it does not initialize the service. The current definition is mandatory in
saved values, native configuration and responses. Foreign definitions reject.

`compile_sql` and typed `prepare` can read current authorized metadata. Their
results contain a local `Intent` and an owned `SavedIntent`; they do not admit
work. `preview` describes the current basis, reason and required schema work.
`stage` stores the intent content and returns its exact `Reference`. Persist that
reference before `admit`. `execute` advances admitted work within an explicit
step budget; `inspect` observes the original operation and `cancel` requests
cancellation. Only a committed observation carries `Commit` with accepted
position, resulting definition, matched/affected counts and live row count.
Admission, preparation and preview are distinct from completion.

## Definitions and values

`lookup(name, namespace)` returns `Option<Metadata>` with a complete `Basis`,
authorization identity, accepted position, changed position, row count and typed
schema. The basis includes the original connection, namespace, name, object,
branch, immutable definition, content commitment and schema fingerprint.
ALTER, RENAME, DROP and typed mutations use that complete basis. Old work cannot
retarget an object subsequently created under the same name.

Catalog, object, branch, operation, definition revision and accepted positions
use full-width `u64`. Native resource, audience, principal, role and namespace
identities retain native safe-integer bounds. `Identity::new(operation, namespace)`
requires positive identities. SQL text is limited to 4,096 UTF-8 bytes; names to
255 UTF-8 bytes. Generated capability values expose intent/action bounds.

`Schema` owns up to 128 columns and stable primary-key column IDs. Logical
`Descriptor`, physical `Encoding` and `Collation` remain separate. Wire schemas
require physical fields; absent or foreign tags reject. `Change::Physical`
selects descriptors for an existing column. Shared Zig validation owns supported
combinations, exact conversion and comparison semantics.

`Operation::Mutate` selects `Ingestion::Point` or `Bulk`. INSERT accepts at most
1,024 rows; assignments use stable column IDs and owned logical cells or an
explicit default. UPDATE and DELETE accept bounded postfix predicates. Logical
values include recursive structures, unions, lists, arrays, maps, exact decimal
coefficients, binary data and typed missing/null/error/conflict states. Conversion
bounds depth, children and aggregate bytes before serializing later values.
Handler-local Table helpers reuse these codecs and retain their separate native
turn commit semantics.

## Recovery and retention

`SavedIntent::restore` and `load` restore exact original work without recompiling
SQL. `forget` releases local loaded work. `Reference::restore` preserves every
original binding for inspection or resumption. Saved values own their JSON and
reject duplicate fields, excess depth, missing fields and incompatible definitions.
The language decoder validates the generated Zig schema and checks identity,
page ordering and receipt consistency. It does not establish authorization or
accepted history independently of the native owner.

Mutating calls return `DispatchResult<T>`. `DispatchError::Uncertain` contains
the native `cause` and a typed `Recovery` holding the original saved intent,
reference, acquisition or snapshot. Preserve that value and inspect the original
operation after loss. Malformed success responses retain uncertainty. Definite
failures remain `DispatchError::Definite`. There is no automatic retry or new
identity allocation. Closing a caller does not cancel accepted work.

`prepare_snapshot(&metadata, operation)` creates an explicit
`SnapshotAcquisition` for the accepted position. Persist it before
`acquire_snapshot`. Resolve uncertain acquisition through
`snapshot_status(&acquisition.owner())`. Persist the resulting `Snapshot` before
using `snapshot_metadata` or releasing it. Uncertain release retains the original
snapshot; owner status resolves it, and repeated original release is idempotent.

Retained metadata preserves the accepted definition after ALTER, DROP and name
reuse. Every disclosure checks current access. Saved bindings, snapshot ownership
and `ReadAuthority` identifiers do not grant rights. This Rust catalog API exposes
retained metadata; it does not expose an interactive relational SQL cursor.
Snapshot acquisition and release are explicit. Dropping the Rust client does not
release retained data or authorize physical deletion or expiry.

## Inspection and ownership

`describe`, `namespace`, `namespaces` and `tables` inspect the current authorized
catalog. Description separates configuration, authenticated subject and current
policy revision. Pages contain at most eight entries and a complete continuation
`Cursor`. Restore its exact saved fields and continue only that listing. Changed
catalog cuts fail; start a fresh listing rather than mixing revisions. Table
entries use independent accepted positions and report `Consistency::Independent`.
Namespace administration, dependency controls and named KV/Document declarations
use their owning public operations; this typed adapter does not expose them.

The blocking client owns one native worker and one loaded intent. Methods borrow
it mutably, preventing concurrent calls in safe Rust. Move ownership into an
executor's blocking task when needed. `close(self)` consumes the handle and joins
destruction; `Drop` also joins. Returned values own their data and outlive the
client. Imported packages do not read credentials or start workers.
