# Unified state queries

`Transit.Station.Sdk.UnifiedQuery` exposes explicit v1 KV/Table/accepted-Document
sources, bounded projections, plans and nested Arrow results. Shared Zig owns
encoding, validation, signatures, recovery and current-policy result verification.

`KvSource` declares two versioned `DecoderType` decoders. `TableSource` owns a
catalog `Metadata`, `Schema` and owner `ProcessRef`; the native query owner checks
the immutable metadata commitment and current rights. `DocumentSource` binds an
accepted reference and optional list expansion with bounded scalar/path/text
projections using `DecoderColumn`. Result `Column` values use
`Logical.Descriptor` with explicit nullable/optional flags. `Bundle.PrepareAsync` accepts a `Plan` and
explicit positive `Budgets`. Predicates are `All`, `IsState`, typed `Compare` or `PredicateProgram`.
Namespaces and progress use `ulong`. Logical atoms preserve exact `Int128` and
`UInt128` values, decimal coefficients, temporal values and finite float32/64 bits
including negative zero. Immutable `Bytes`
own binary values and IPC without exposing mutable buffers.

`PredicateProgram` copies one to 64 `PredicateInstruction` values into a
read-only collection. `PredicateAtomInstruction` wraps `All`, `IsState` or
`Compare`; `PredicateOperation` carries `PredicateOperator.Negate`, `Conjunction`
or `Disjunction`. Instructions use postfix order: two atoms followed by
`Conjunction` express AND. Programs cannot nest. Shared Zig validates the full
program against its source, preserves eager error order and null/missing unknown,
and selects only true. `InspectedProgram` owns redacted `InspectedAtomInstruction`
and `InspectedOperation` values without retaining native buffers.

`Client.OpenAsync(config, credential, connection)` creates a bounded native worker
without activating a process. `DescribeAsync` checks current source policy.
`PrepareNextAsync` returns an immutable `Prepared`; persist its `Bytes.Copy()`
before `SubmitAsync`. `ErrorKind.UnknownOutcome` requires resubmitting the exact
same persisted bytes, reconstructed with `new Prepared(new Bytes(saved))`.
Cancelling a Task wait does not cancel accepted work; the caller retains its
prepared token and must resolve any uncertainty. An admission receipt, an
`ObserveAsync` disposition and a `StatusAsync` completed result are distinct.
A null next command means inspect status.

`CompileSqlAsync(source, name, sql, budgets, parameters = null, cancellation)`
returns an owned `Bundle`. The optional `IReadOnlyList<Logical.Atom>` is converted to an
owned request before worker submission. `null` selects ordinary SQL; an empty
list selects a template without placeholders. Cancellation of the wait retains
worker ownership until completion; disposal joins native cleanup.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned uint64-range atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

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
and schema evidence including the retained source-head digest, original IPC and an optional opaque cursor. A cursor is not
a grant; null means verified complete coverage. `PrepareControlAsync` prepares
explicit cancellation, retirement or collection with the same durable retry rules.

`DecodeArrowAsync` and `Page.DecodeAsync` return owned read-only lists of shared logical
`Missing`, `Null`, `SourceTypeError`, `Present` or ordered `Conflict` cells.
Nested results retain their logical types and exact values. Decoding validates
shape; an authorized page read establishes current access and provenance.
No optional .NET Arrow dependency is selected. Values and pages survive disposal.

Bundles contain at most 25,069 bytes, batches at most eight rows and 128 result
columns, and IPC segments at most 64 KiB. Document projections remain bounded
to eight. Predicate byte literals are limited to 4 KiB. Source/output names are
nonempty UTF-8 of at most 255 bytes without NUL.

One operation may be in flight. Overlapping work reports Busy. Use `await using`
or await `DisposeAsync` to join the bounded 8 MiB native worker even after a local
wait is cancelled. Disposal never records durable cancellation or acknowledges
an input. Constructors and converters validate host values and generated native
schemas before exposing results.

Use `nix develop .#bindings`, then `just bindings::unified-dotnet` for installed
NuGet codec and signed KV recovery tests. An optional `table` or `document` source
argument selects another fixture. The [proof guide](../../../../tests/README.md)
records measured profiles and remaining qualification.
