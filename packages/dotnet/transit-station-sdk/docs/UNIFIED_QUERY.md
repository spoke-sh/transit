# Unified state queries

`Transit.Station.Sdk.UnifiedQuery` exposes explicit v1 KV/Table/accepted-Document
sources, bounded projections, plans and nested Arrow results. Shared Zig owns
encoding, validation, signatures, recovery and current-policy result verification;
the original Table query profile remains separate.

`KvSource` declares two versioned decoders. `TableSource` binds its ID/schema.
`DocumentSource` binds an accepted reference and optional list expansion with
bounded scalar/path/text projections. `Bundle.PrepareAsync` accepts a `Plan` and
explicit positive `Budgets`. Predicates are `All`, `IsState` or typed `Compare`.
Namespaces, unsigned values and progress use `ulong`; signed scalars use `long`.
Floats preserve finite double bits, including negative zero. Immutable `Bytes`
own binary values and IPC without exposing mutable buffers.

`Client.OpenAsync(config, credential, connection)` creates a bounded native worker
without activating a process. `DescribeAsync` checks current source policy.
`PrepareNextAsync` returns an immutable `Prepared`; persist its `Bytes.Copy()`
before `SubmitAsync`. `ErrorKind.UnknownOutcome` requires resubmitting the exact
same persisted bytes, reconstructed with `new Prepared(new Bytes(saved))`.
Cancelling a Task wait does not cancel accepted work; the caller retains its
prepared token and must resolve any uncertainty. An admission receipt, an
`ObserveAsync` disposition and a `StatusAsync` completed result are distinct.
A null next command means inspect status.

`InspectSqlAsync(source, name, sql, budgets, cancellation)` executes scoped
`DESCRIBE name`, `SHOW TABLES` or `EXPLAIN SELECT ...` through the shared Zig
inspection owner. `Inspection` carries source/schema digests, current
resource/policy revisions and immutable `SourceDescription`, `TableListing` or
`Explanation` details. Explanation includes ordered operators, typed predicate
structure without literals, projection/output columns and explicit budgets.
Wide values remain `ulong`. Inspection checks current access before and after
resolution, creates no snapshot and admits no query. The listing covers only
the configured source. Cancelling the wait retains native ownership until join.

`PageAsync` reads only verified complete results, checking current source grants,
lifecycle, segment digests and ordered coverage. It returns immutable manifest
and schema evidence, original IPC and an optional opaque cursor. A cursor is not
a grant; null means verified complete coverage. `PrepareControlAsync` prepares
explicit cancellation, retirement or collection with the same durable retry rules.

`DecodeArrowAsync` and `Page.DecodeAsync` return owned read-only lists of `Missing`,
`Null`, `TypeError`, `CellValue` or ordered `Conflict` cells. Decoding validates
shape; an authorized page read establishes current access and provenance.
No optional .NET Arrow dependency is selected. Values and pages survive disposal.

One operation may be in flight. Overlapping work reports Busy. Use `await using`
or await `DisposeAsync` to join the bounded 8 MiB native worker even after a local
wait is cancelled. Disposal never records durable cancellation or acknowledges
an input. Constructors and converters validate host values and generated native
schemas before exposing results.

Use `nix develop .#bindings`, then `just bindings::unified-dotnet` for installed
NuGet codec and signed KV recovery tests. An optional `table` or `document` source
argument selects another fixture. The [proof guide](../../../../tests/README.md)
records measured profiles and remaining qualification.
