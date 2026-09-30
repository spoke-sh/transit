# Catalog callers

`io.transit.sdk.station.Catalog` provides explicit initialization, conditional
policy controls and named Table creation through the shared Zig catalog caller.
Open `Catalog.Client` with a `ClientConfig`, `Credential` and realm-qualified
owner/resource/catalog `Connection`. Opening validates the matching definition
and capabilities. Server operations check current authority separately.

```java
try (var client = Catalog.Client.open(config, credential, connection)) {
    var compiled = client.compileSql(
        "CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL)",
        operation, object, table).join();
    var prepared = client.prepareCreate(compiled.request()).join();
    save(prepared.bytes().copy());
    var admitted = client.submit(prepared).join();
}
```

The application supplies a positive full-width uint64 `BigInteger` for catalog,
operation/object identities and policy revisions. Native identities use bounded
`long` values; physical Table IDs use positive uint32 values represented as
`long`. Records own immutable strings, copied name lists and immutable `Bytes`.
`Bytes` copies arrays on construction and extraction. `Compiled` holds a typed
request and at most 256 canonical review bytes. The two-column Table profile has
a nonnull int64 key and nullable int64, bool, UTF-8 or binary value.

`prepareInitialize`, `prepareCreate` and `preparePolicy` return owned `Prepared`
commands. Save the exact bytes before submitting or awaiting its future; recover
with `new Catalog.Prepared(new Bytes(saved))`. Saved commands contain at most
8192 bytes of opaque signed UTF-8 text. Shared Zig validates them before transport.
Do not parse/re-encode, prepare a replacement identity or infer rejection from a
lost response. Keep the original typed creation request for `status`.

`submit` borrows the immutable command and returns an admission receipt. A
`TransitException` with `Kind.UNKNOWN_OUTCOME`, a cancelled future or a lost
caller requires reconciliation using the original saved command. Malformed
successful receipts preserve uncertainty. Definite native rejections retain
their category, status and code. `observe` reports pending/processed input;
`inputDisposition` reports optional control/rejection outcomes. `status` returns
the original creation receipt; only `Outcome.APPLIED` establishes creation.
Current native and catalog policies gate metadata, retries and result disclosure.

Methods return `CompletableFuture` through one bounded owned worker and native
port. Overlap fails with `BUSY`. Cancelling a future does not release native
ownership or cancel accepted work. Close on the owning application thread;
try-with-resources joins active work and child cleanup. Completion callbacks must
not blockingly close their own publisher. Futures and Java fields are not durable
recovery storage. Created Tables do not automatically become query sources or
mutation writers.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns
policies, atomic publication, supported schemas and bounds. The
[proof ledger](../../../../tests/README.md) records installed recovery,
malformed-reply and cancellation coverage with its execution limits.
