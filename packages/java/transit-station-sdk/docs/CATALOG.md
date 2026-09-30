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

## Metadata

`lookup(name)` returns a future of `Optional<Definition>` for an exact
case-sensitive ASCII name of one to sixteen bytes. `definition(object, revision)`
reads an immutable definition by positive uint64 `BigInteger` identities.
Absence is an empty optional; malformed records and current denial are errors.
Definitions own scope, original name, Table/schema and creation attribution.

`list()` starts an ordered page; `list(page.next())` continues only when `next`
is present. `Page.entries()` is an immutable copied list of at most eight
values. An empty final page is possible. Retain every original `Cursor` field,
including its mandatory matching contract definition, scope, resource revision
and last name. A changed revision returns a native conflict; restart the listing
and keep results from different revisions separate. Do not pass an empty optional
to continue an exhausted listing: that starts a fresh page.

Metadata readers submit no command or snapshot and check current catalog
inspection and native rights on each call, including continuation. Response
validation checks requested identity, page order/scope and continuation cut.
These methods use the same bounded worker and cancellation/close ownership as
other catalog calls. They do not make created Tables into query sources.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns
policies, atomic publication, supported schemas and bounds. The
[proof ledger](../../../../tests/README.md) records installed recovery,
malformed-reply and cancellation coverage with its execution limits.
