# General Table callers

`transit_station_sdk::catalog::Client` exposes CREATE, typed INSERT/UPDATE/DELETE,
ALTER, RENAME, DROP, authorized metadata and exact saved-intent recovery through
the shared Zig compiler and owner. Provision the catalog host, native resource,
ownership, grants and policy explicitly.

```rust
use transit_station_sdk::catalog::{Client, Connection, Identity, Scope};

let scope = Scope::new(resource, catalog_id)?;
let connection = Connection::new(owner, scope)?;
let mut client = Client::open(config, credential, connection)?;
let compiled = client.compile_sql(
    "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(80))",
    Identity::new(operation_id, namespace_id)?,
    Some(object_id),
)?;
save_intent(compiled.saved.definition(), compiled.saved.bytes())?;
// Application-owned persistence; prepare and persist each step before dispatch.
let reference = compiled.intent.reference;
```

`owner` and `resource` are `ProcessRef` and `ResourceRef` in one realm;
`credential` is a `Credential` in that realm. Use the raw client's explicit
`ClientConfig::growing` profile and timeout. Opening checks the installed native
ABI and general Table capabilities on one owned worker. It performs no network
request. Importing starts no worker and reads no credential.

Catalog, object, operation, namespace, schema/metadata revision and column IDs
use exact full-width `u64`; native process, resource and input positions retain
their separate safe-integer bounds. `Identity::new` requires positive operation
and upload namespace identities. SQL is limited to 4,096 UTF-8 bytes. Compilation
and typed preparation can read currently authorized metadata; they never dispatch
an operation. `compile_sql` takes `Some(object)` for CREATE and `None` for other
statements.

## Typed schemas and mutations

`Schema` owns up to 128 `Column` values, a stable `next_column` and explicit
`primary_key` column IDs. `Column::new(id, name, datatype)` defaults to nullable,
without a default or character limit. `logical::Descriptor` represents scalar,
decimal, timestamp, structure, tagged union, list, fixed array and map types.
`logical::Cell` distinguishes missing, null, source type error, value and conflict;
`CellValue` owns recursive children. Atoms use Rust integer widths including
`i128`/`u128`, finite `f32`/`f64`, owned UTF-8/binary, exact decimal coefficients,
calendar/time units, intervals and 16-byte UUIDs. Floating-point conversion keeps
signed zero and uses the selected width's exact little-endian bits.

Pass `Operation` to `prepare(name, identity, &operation)`. CREATE takes a `Schema`;
ALTER takes one `Change`; RENAME and DROP use catalog lifecycle semantics.
`Mutation::Insert` accepts at most 1,024 rows of assignments; UPDATE and DELETE
accept up to 64 postfix `Predicate` instructions. Assignments name stable column
IDs and carry `AssignmentValue::Cell` or `Default`. Comparisons use typed atoms;
state tests and boolean instructions preserve native predicate semantics.

Non-CREATE work uses `Metadata::basis()` to freeze object, metadata revision and
schema fingerprint. Absent-name DROP IF EXISTS can omit its basis. Work never
retargets a replacement object found under the same name. SQL and typed inputs
lower to the same native immutable intent and execution contract.

Logical conversion bounds both directions to depth below 16, 256 type nodes,
4,096 field-name bytes, 65,536 value children and 1 MiB of value data. MAP keys
count as children; conflict alternatives share their owning cell's depth and
require two to eight increasing positive counter/replica pairs. Native admission
checks the complete schema, values and intent. Names are bounded to 255 UTF-8
bytes; schema JSON is bounded to 2 MiB. The generated 16 MiB action limit applies
only to this catalog profile; raw-client and kernel frame bounds are unchanged.

## Persistence, submission and outcomes

Persist `SavedIntent::definition()` together with its exact `bytes()` before
submitting work. Restore with `SavedIntent::new(definition, bytes)` and
`client.load(&saved)`; omitted or foreign definitions reject. Loading validates
the original intent locally and never recompiles SQL or sends a command. A handle
owns one loaded intent; `forget(&reference)` releases that local ownership.

`next(&reference)` returns `Next::Send(Prepared)`, `Running`, `UploadCancelled` or
`Terminal(Outcome)`. Persist `Prepared::data()` unchanged before `submit(&prepared)`.
Recover it using `Prepared::from_data(saved_text)`. Shared Zig validates the
original definition, connection, frame and signature before dispatch. Submission
borrows the command and returns an `AdmissionReceipt`.

`observe(&prepared, position, wait)` reports input progress. `progress(&reference,
&prepared, position, wait)` combines input progress with the original operation;
processed inputs may have a separate `Disposition`. `status(&reference)` returns
operation outcome and upload state separately. Only applied DML has recorded
`Counts { matched, changed }`; processed input or sealed upload alone does not
establish successful execution. `prepare_resume` and `prepare_control` produce
explicit signed recovery, operation/upload cancellation and cleanup commands;
each still requires persistence and separate submission.

On `ErrorKind::UnknownOutcome`, reconcile the identical `Prepared` using the
original connection and credential, replacing the caller if needed. Missing or
malformed success receipts and failures after worker dispatch retain uncertainty.
Definite native rejections retain their status and validated diagnostic. Do not
recompile, re-sign or replace uncertain work. Closing a client or deleting local
files does not cancel accepted work.

## Metadata and administration

`lookup(name)` returns `Option<Definition>` with current `metadata`, complete
`schema` and live `head`. `definition(object, revision)` returns an accepted
`HistoricalDefinition` with metadata and schema and no live head. Historical
reads survive ALTER, DROP and name reuse under current grants and inspection
rights. Absent revisions and known unaccepted candidates return `None`; missing
original acceptance evidence or corrupt/incompatible retained records fail.
Private publication alone does not establish acceptance.

`list(None)` returns a `Page` with resource revision, up to eight owned
metadata/head entries ordered by object ID, and optional continuation. Empty
pages can continue past retired objects. Persist every cursor field and restore
with `Cursor::new(definition, scope, resource_revision, after_object)`; cursors
confer no authority. Continue using only `page.next`. Changed cuts fail; begin a
fresh listing rather than combining revisions. Response decoding checks exact
identity, page shape/order/scope, continuation and outcome/count consistency.
Native validation checks success and failure diagnostics.

`Configuration` includes explicit record/staging byte and staging-record limits.
`Policy` carries eight independent `Rights`: inspect, create, read, insert,
update, delete, alter and drop. `PolicyChange` requires the exact expected and
successor revisions. `prepare_initialize`, `prepare_policy` and
`prepare_dependency` prepare administrator controls; `describe` reads current
configuration and caller policy. The native owner rechecks authority and
conditions when processing commands.

Methods borrow the client mutably, preventing overlapping calls through safe
Rust. Use an owned blocking task on an async executor. `close(self)` consumes the
caller and joins destruction; `Drop` also joins cleanup. Returned values own
their data and outlive the handle. There is no implicit submission retry or
principal-sequence coordinator. Native reads/preparation may restart only an
exact transient stale-resource rejection within the configured deadline.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns
publication and authority. The [proof ledger](../../../../tests/README.md) records
executed installed-package schedules, compiler rejection and malformed-response
checks and their limits.
