# Catalog callers

`transit_station_sdk::catalog::Client` exposes initialization, conditional policy,
named Table creation and saved-command recovery through the shared Zig caller.
Provision the catalog host, native resource, ownership and caller grants
explicitly. Query connections do not enable catalog administration.

```rust
use transit_station_sdk::catalog::{Client, Connection, Scope};

let scope = Scope::new(resource, catalog_id)?;
let connection = Connection::new(owner, scope)?;
let mut client = Client::open(config, credential, connection)?;
let compiled = client.compile_sql(
    "CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL)",
    operation_id,
    object_id,
    table_id,
)?;
let prepared = client.prepare_create(compiled.request())?;
save_prepared(prepared.data())?; // Application-owned durable persistence.
let receipt = client.submit(&prepared)?;
client.close()?;
```

`owner` and `resource` are `ProcessRef` and `ResourceRef` in one realm;
`credential` is a `Credential` in that realm. Use the raw client's explicit
`ClientConfig::growing` profile and timeout. The installed native Station library
is selected by default. Opening starts one owned worker, reads the supplied key
and checks the exact ABI definition and catalog capabilities. Importing starts
no worker and reads no credential. Opening performs no network request.

Catalog, operation/object IDs and policy revisions are full-width positive `u64`
values. Native IDs keep their separate safe-integer bounds; the physical Table
ID is a positive `u32`. `Schema` owns two names and a `CellType`. Compilation
requires an explicit non-null int64 key and an explicitly nullable value. It
is offline after caller creation: no identity is reserved and no authority is
granted. `Compiled::canonical()` borrows owned current-definition bytes for
review; preparation takes the complete typed `Compiled::request()`.

## Explicit preparation and outcomes

`prepare_initialize(&Configuration::new(scope, owner, administrator)?)` prepares
the exact immutable host configuration. `prepare_policy(&PolicyChange::new(
expected_revision, policy))` prepares a conditional administrator control.
Construct `Policy` with scope, principal, revision, inspect and create fields;
expected revision zero denotes an absent policy. Shared Zig validates successor
revisions and current metadata. The host rechecks authorization and conditions
at application. `describe()` reads currently authorized configuration and policy.

Every preparation returns an owned `Prepared` with opaque canonical UTF-8 text,
bounded to 8192 bytes. Persist `data()` unchanged before submission. Recover it
with `Prepared::from_data(saved_text)`; the shared caller validates the exact
definition, connection, signed frame and signature before dispatch. Only
`submit(&prepared)` dispatches, returning an `AdmissionReceipt`. Submission
borrows the command without consuming or rewriting it.

Use `observe(&prepared, receipt.position.get())` for pending/processed input,
then inspect the separate outcome. `input_disposition` returns an
initialization/policy/rejected-input outcome or `None`; absence proves no outcome.
`status(original_request)` returns the original creation receipt or `None` and
checks that its complete request matches the original. Only `Outcome::Applied`
establishes publication. Name, object and Table conflicts are distinct terminal
outcomes. Processing is separate from application; current catalog and native
rights still gate disclosure.

On `ErrorKind::UnknownOutcome`, recreate the caller if necessary and resubmit
the identical saved command with the same connection and credential. Do not
parse/re-encode, re-sign or replace it while admission remains unresolved.
Missing or malformed success receipts and failure of an admitted worker job
preserve uncertainty. Definite native
rejections retain their status/code. Dropping local recovery data or abandoning
a host task does not cancel accepted work.

Methods borrow the client mutably, preventing overlapping calls through safe
Rust borrows. This is a blocking API; use an owned blocking host task on an
executor. `close(self)` consumes the caller and joins destruction; `Drop` also
joins cleanup. There is no retry queue, provisioning loop or principal sequence
coordinator. Keep recovery material independently of the worker and coordinate
new principal sequences across separate clients yourself.

Descriptions, declarations, controls and receipts own their data; borrowed
getters do not expose mutable recovery bytes. Full-width neutral IDs use exact
decimal strings, and response shapes, types and bounds are checked at runtime.
Protocol, signing, policy and recovery semantics remain in the shared Zig
implementation. The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md)
defines atomic publication and authority; the [proof ledger](../../../../tests/README.md)
records installed-package, compiler rejection and malformed-response checks.

## Definition reads and pages

`lookup(name)` returns `Option<Definition>` after exact-name binding and live
Table schema checks. `definition(object, revision)` takes two positive `u64`
identities and reads immutable metadata without requiring the current Table to
match. Definitions own their scope, object/revision/name, `TableSource` (physical
`table` and schema), original principal, operation and input position.

`list(None)` returns a `Page`: its `resource_revision`, an owned dense vector of
at most eight ordered `entries`, and optional `next`. Continue with
`list(Some(&cursor))` only when `next` exists. An empty final page is possible.
Restore a cursor with `Cursor::new(definition, scope, resource_revision, after)`;
all original fields are required, and a missing/foreign definition rejects.
Borrowed cursor getters expose the fields for application-owned persistence.

Each call checks current catalog inspection policy and native grants. A cursor
confers no authority and retains no snapshot. Changed scope/revision returns a
conflict; discard the partial result before beginning a fresh listing. Strict
decoding checks requested identity, page shape/order/scope and continuation;
malformed metadata returns `ErrorKind::IncompatibleNative`. Calls submit no
command and perform no automatic retry. Definitions/pages/cursors can be cloned
and retained after closing the native caller.
