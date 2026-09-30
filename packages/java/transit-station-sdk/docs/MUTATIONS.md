# Table mutation callers

`io.transit.sdk.station.Mutations` provides bounded SQL INSERT, primary-key UPDATE
and DELETE through shared Zig. Open `Mutations.Client` with an explicit
`ClientConfig`, `Credential` and realm-qualified writer/resource/Table `Connection`.
The writer separately enables and authorizes each operation. Read-query access
does not confer mutation access. Opening validates the exact generated native
definition and local capabilities; server operations check current authority.

```java
try (var client = Mutations.Client.open(config, credential, connection)) {
    var compiled = client.compileSql("items", "UPDATE items SET value=12 WHERE id=7", namespace).join();
    saveCompiled(compiled.request().copy(), compiled.reference().bytes().copy());
    var next = client.prepareNext(compiled).join();
}
```

The application supplies a positive `BigInteger` namespace within the uint64
range. Protocol counters use bounded `long` values. Requests, references and
saved commands own immutable `Bytes`; its constructor and `copy()` copy arrays.
Column-name lists and permission sets are immutable. `describe()` reports the
current resource/schema/policy and optional active namespace under current read
permission. Compilation does not reserve rows or establish admission.

Persist both `Compiled.request()` and its complete 68-byte `Reference` before
upload. `prepareNext` returns an optional `Prepared` for one stage. Persist
`prepared.bytes().copy()` before `submit(prepared)`. If the future reports
`TransitException.Kind.UNKNOWN_OUTCOME`, reconstruct `Prepared` from those exact
saved bytes and resubmit, including after replacing the client. Do not recompile,
allocate another namespace, parse/re-encode the command or advance the upload
across an unresolved admission. Cancelling or losing a future also requires
reconciling the original prepared operation. There is no implicit retry or upload
loop and no sequence coordinator across independent clients.

Submission returns an admission receipt. `observe(prepared, position)` returns
PENDING or PROCESSED. After processing, `rejection` reports an optional input
rejection separately from the request's result. An empty next command requires
`status(reference)`; only APPLIED establishes affected rows. `prepareControl`
supports explicit APPLY and CANCEL. Cancellation cannot undo already applied
rows. References and saved commands never confer authority, and current read
grants gate every observation.

Methods return `CompletableFuture` and share one bounded owned worker/port.
Overlapping calls fail with BUSY. Cancelling a future does not cancel native
ownership, transport or accepted work. Close from the owning application thread;
try-with-resources joins cleanup. Completion callbacks must not blockingly close
their own publisher. Importing the package discovers no credentials or clients.
Host tasks and futures are not durable recovery storage.

The [shared mutation contract](../../../../contracts/TABLE_MUTATION_V1.md) defines
the three-row, 799-byte canonical request and 8192-byte saved command limits,
scalar types and rollback/conflict behavior. The client supports a nonnull int64
key and nullable int64, bool, UTF-8 or binary value. Executed installed-consumer
coverage and measurements belong to the [proof ledger](../../../../tests/README.md).
