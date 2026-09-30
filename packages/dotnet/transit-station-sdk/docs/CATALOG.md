# Catalog callers

`Transit.Station.Sdk.Catalog` provides explicit initialization, conditional
policy controls and named Table creation through the shared Zig catalog caller.
Open `Catalog.Client` with a `ClientConfig`, `Credential` and realm-qualified
owner/resource/catalog `Connection`. Opening validates the matching definition
and capabilities. Server operations check current authority separately.

```csharp
await using var client = await Catalog.Client.OpenAsync(config, credential, connection);
var compiled = await client.CompileSqlAsync(
    "CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL)",
    operation, objectId, table);
var prepared = await client.PrepareCreateAsync(compiled.Request);
Save(prepared.Bytes.Copy());
var admitted = await client.SubmitAsync(prepared);
```

The application supplies positive full-width `ulong` values for catalog,
operation/object identities and policy revisions. Native identities are bounded
`ulong` values; physical Table IDs are positive `uint` values. Records own
immutable strings, copied name lists and immutable `Bytes`. `Bytes` copies arrays
on construction and extraction. `Compiled` holds a typed request and at most
256 canonical review bytes. The two-column Table profile has a nonnull int64 key
and nullable int64, bool, UTF-8 or binary value.

`PrepareInitializeAsync`, `PrepareCreateAsync` and `PreparePolicyAsync` return
owned `Prepared` commands. Save the exact bytes before submitting or awaiting its
task; recover with `new Catalog.Prepared(new Bytes(saved))`. Saved commands
contain at most 8192 bytes of opaque signed UTF-8 text. Shared Zig validates them
before transport. Keep the original command across response loss and retain the
original typed creation request for `StatusAsync`.

`SubmitAsync` borrows the immutable command and returns an admission receipt.
A `TransitException` with `ErrorKind.UnknownOutcome`, cancellation after
admission to the local worker, or a lost caller requires reconciliation using the
original saved command. Malformed successful receipts preserve uncertainty.
Definite native rejections retain their category, status and code. `ObserveAsync`
reports pending/processed input; `InputDispositionAsync` reports optional
control/rejection outcomes. `StatusAsync` returns the original creation receipt;
only `Outcome.Applied` establishes creation. Current native and catalog policies
gate metadata, retries and result disclosure.

Methods return `Task` through one bounded owned worker and the shared C ABI.
Overlap fails with `ErrorKind.Busy`. A previously cancelled token prevents local
admission. Cancellation of an admitted operation abandons only its local wait;
it does not release native ownership or cancel accepted work. `await using`
joins active work and native cleanup. Tasks and managed fields are not durable
recovery storage. Created Tables do not automatically become query sources or
mutation writers.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns
policies, atomic publication, supported schemas and bounds. The
[proof ledger](../../../../tests/README.md) records installed recovery,
receipt-decoding and cancellation coverage with its execution limits.
