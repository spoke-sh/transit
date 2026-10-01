# Unified state queries

`io.transit.sdk.station.UnifiedQuery` exposes the explicit v1 KV/Table/accepted-
Document profile. It delegates source/plan validation, encoding, signed requests,
recovery and result verification to shared Zig through the generated port schemas.
The original Table API remains available in `Query`.

`Source` is a sealed hierarchy of `KvSource`, `TableSource` and `DocumentSource`.
KV declares versioned decoders, Table binds an exact ID/schema, and Document
binds an accepted reference and bounded path/list/text projections. `Plan` selects
ordered columns, an `All`, `IsState`, typed `Compare` or `PredicateProgram` predicate, aggregate and
optional limit. `Bundle.prepare` requires explicit positive `Budgets`.
Full-width unsigned values, namespaces, conflict IDs and progress use `BigInteger`;
IDs governed by the protocol's smaller counter bound use `long`.

`PredicateProgram` owns a copied list of one to 64 `PredicateInstruction` values.
Wrap an `All`, `IsState` or `Compare` in `PredicateAtomInstruction`; combine atoms
with `PredicateOperator.NEGATE`, `CONJUNCTION` and `DISJUNCTION` in postfix order.
For example, `[atom(A), atom(B), NEGATE, CONJUNCTION]` means `A AND NOT B`.
Programs cannot nest. Shared Zig validates stack shape, column bounds and scalar
types before encoding; it evaluates eagerly with null/missing as unknown.
Only true selects a row. `InspectedProgram` owns the same operator order with
`InspectedAtomInstruction` values containing names/types and no literals.

`Client.open(config, credential, connection)` starts an owned bounded port worker
without acquiring process activation. `describe` checks current policy and the
declared source. Query methods return `CompletableFuture`; one operation may be
in flight. Try-with-resources closes the port and joins the worker. Completion
callbacks must not call blocking close on the publisher thread; close from the
owning application thread after observing the future.

`inspectSql(source, name, sql, budgets)` executes scoped `DESCRIBE name`,
`SHOW TABLES` or `EXPLAIN SELECT ...` through the shared Zig inspection owner.
Its future returns an immutable `Inspection` with source/schema digests, current
resource/policy revisions and `SourceDescription`, `TableListing` or
`Explanation` details. Explanation includes ordered operators, a typed
predicate without literal values, projection/output columns and explicit budgets.
Full-width limits and policy revisions use `BigInteger`. Inspection checks
current access before and after resolution, creates no snapshot and admits no
query. The listing covers only the configured source. Cancelling the future
retains native ownership until join.

For a positive namespace, `prepareNext` returns an optional immutable `Prepared`.
Persist `prepared.bytes().copy()` before `submit`. Keep those exact bytes after
`TransitException.Kind.UNKNOWN_OUTCOME` or a cancelled/lost future, and recover
with `new Prepared(new Bytes(saved))`; resubmit that same token. Cancelling a
future does not cancel native work or the durable query. Close still joins it.
`prepareControl` prepares explicit cancellation, retirement or collection using
the same persistence/submission rules.

A submission receipt is admission. `observe` checks behavior disposition;
`status` distinguishes upload, admission, completion and terminal states. An
empty `prepareNext` means inspect status. Pages are available only for a verified
complete result, and every read rechecks current source policy and lifecycle.
`Page.next` is an opaque continuation, never a grant. An empty continuation means
verified complete coverage.

Pages own immutable `Bytes` IPC and typed manifest evidence. `decode` returns
immutable lists with `Missing`, `Null`, `TypeError`, `Value` and ordered `Conflict`
cells. Scalars preserve signed/unsigned integers, finite doubles (including
negative zero), booleans, UTF-8 and binary. Copies survive client close. Standalone
`decodeArrow` checks shape; it does not establish current access or result
completion. No optional Java Arrow dependency is selected.

Build/install using `nix develop .#bindings` and `just bindings::java-build`.
`just bindings::unified-java` tests installed artifacts against the signed Table
schedule; its source argument accepts `kv` or `document`. The
[proof guide](../../../../tests/README.md) distinguishes measured profiles from
remaining source/deployment qualification.
