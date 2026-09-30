# Table mutation callers

`transit_station_sdk::mutations::Client` exposes bounded SQL INSERT, primary-key
UPDATE and DELETE through the shared Zig mutation caller. Supply a realm-qualified
writer/resource/Table connection and credential. The writer must expose the
operation and separately authorize the caller. A read-query declaration or grant
does not enable writes.

```rust
use transit_station_sdk::mutations::{Client, Connection};

let connection = Connection::new(writer, resource, table_id)?;
let mut client = Client::open(config, credential, connection)?;
let metadata = client.describe()?;
let compiled = client.compile_sql("items", "UPDATE items SET value=12 WHERE id=7", namespace)?;
save_compiled(compiled.request(), compiled.reference().data())?;
client.close()?;
```

`writer` and `resource` are `ProcessRef` and `ResourceRef` values in one realm;
`credential` is a `Credential` in that realm. Use the raw client's explicit
`ClientConfig::growing` profile and configured timeout. The matching installed
native Station library is the default; the existing native-directory override
is available for source development. Opening checks the exact generated ABI
definition before creating the mutation handle. Importing starts no worker and
reads no credential.

Namespace is a positive `u64`. `Compiled` owns its canonical request and full
`Reference`; persist both unchanged before upload. Their getters borrow immutable
bytes, and `from_data` reconstructs owned values from saved bytes. `Prepared`
owns opaque UTF-8 text. Shared Zig validates the request commitment and original
saved command before transport. The
[mutation contract](../../../../contracts/TABLE_MUTATION_V1.md) defines the
three-row limit, scalar types, conflicts and current authority checks.
Compilation does not reserve rows or prove admission.

Call `prepare_next(&compiled)` for one stage. Persist its `Prepared::data()` before
calling `submit(&prepared)`, which returns an `AdmissionReceipt`. Submission
borrows the prepared command; it does not consume or rewrite it. On
`ErrorKind::UnknownOutcome`, recreate the caller if needed and resubmit the
identical saved command. Do not recompile, parse/re-encode its text, allocate a
new namespace or prepare another stage while admission remains unresolved.
The client has no implicit upload loop, retry queue or sequence coordinator.

After admission, wait for `observe(&prepared, receipt.position.get())` to return
`Observation::Processed`, then inspect `rejection` for that prepared input before
preparing a successor. Input processing can record a rejection without changing
the request's result. A `None` next command requires `status(compiled.reference())`
to distinguish `Phase::Applied`, `Rejected` and `Cancelled`. Only the durable
applied result establishes `affected_rows`. `prepare_apply` and `prepare_cancel`
provide explicit controls; cancellation cannot undo rows already applied.

Methods borrow the client mutably, so overlapping calls cannot share a client
through safe Rust borrows. One owned native worker supplies the required stack
and serialized calls. This is a blocking API; use an owned blocking host task on
an executor. Abandoning a receive does not cancel native work. `close` and `Drop`
join destruction. Save recovery material independently of host tasks, and
coordinate new principal sequences across separate clients yourself.

Descriptions, compiled values, references and statuses own their data. Current
native read grants gate every observation. Namespaces, references and schema
commitments confer no authority. Protocol, policy, staging, signing and recovery
semantics remain in the shared Zig implementation.
