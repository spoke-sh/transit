# Table mutation callers

`Transit.Station.Sdk.Mutations` provides bounded SQL INSERT, primary-key UPDATE
and DELETE through shared Zig. Open `Mutations.Client` with an explicit
`ClientConfig`, `Credential` and realm-qualified writer/resource/Table `Connection`.
The writer separately enables and authorizes each operation. Read-query access
does not confer mutation access. Opening validates the exact native definition
and local capabilities; server operations check current authority.

```csharp
await using var client = await Mutations.Client.OpenAsync(config, credential, connection);
var compiled = await client.CompileSqlAsync("items", "UPDATE items SET value=12 WHERE id=7", namespaceId);
SaveCompiled(compiled.Request.Copy(), compiled.Reference.Bytes.Copy());
var next = await client.PrepareNextAsync(compiled);
```

The application supplies a positive `ulong` namespace. Requests, complete 72-byte
references and saved commands own immutable `Bytes`; construction and `Copy()`
copy arrays. Returned column-name lists are read-only. `DescribeAsync` reports
the current resource/schema/policy and optional active namespace under current
read permission. Compilation does not reserve rows or establish admission.

Persist both `Compiled.Request` and its `Reference` before upload.
`PrepareNextAsync` returns a nullable `Prepared` for one stage. Persist
`prepared.Bytes.Copy()` before `SubmitAsync(prepared)`. After
`TransitException` with `ErrorKind.UnknownOutcome`, reconstruct `Prepared` from
those exact saved bytes and resubmit, including after replacing the client.
Do not recompile, allocate another namespace, parse/re-encode the command or
advance the upload across unresolved admission. Cancelling or losing a task
also requires reconciling the original prepared operation. There is no implicit
retry or upload loop and no sequence coordinator across independent clients.

Submission returns an admission receipt. `ObserveAsync(prepared, position)`
returns `Pending` or `Processed`. After processing, `RejectionAsync` reports a
nullable input rejection separately from the request's result. A null next
command requires `StatusAsync(reference)`; only `Applied` establishes affected
rows. `PrepareControlAsync` supports explicit `Apply` and `Cancel`. Cancellation
cannot undo already applied rows. Saved references and commands never confer
authority, and current read grants gate every observation.

Methods return `Task` and share one bounded 8 MiB native worker. Overlapping
calls fail with `Busy`. `CancellationToken` cancels a local wait; admitted native
ownership continues until completion. `DisposeAsync` joins cleanup, including
after cancellation. Use `await using` and retain recovery bytes outside the
client. Importing the package discovers no credentials or clients. Host tasks
and object fields are not durable recovery storage.

The [shared mutation contract](../../../../contracts/TABLE_MUTATION_V1.md) defines
the three-row, 799-byte canonical request and 8192-byte saved command limits,
scalar types and rollback/conflict behavior. The client supports a nonnull int64
key and nullable int64, bool, UTF-8 or binary value. Executed installed-consumer
coverage and measurements belong to the [proof ledger](../../../../tests/README.md).
