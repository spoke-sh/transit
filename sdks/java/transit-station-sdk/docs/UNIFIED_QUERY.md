# Unified state queries

`io.transit.sdk.station.UnifiedQuery` exposes the explicit v1 KV/Table/accepted-
Document profile. It delegates source/plan validation, encoding, signed requests,
recovery and result verification to shared Zig through the generated port schemas.

`Source` is a sealed hierarchy of `KvSource`, `TableSource` and `DocumentSource`.
KV declares versioned `DecoderType` decoders. Table sources own a direct catalog scope, service audience, branch, namespace,
`TableInterpretation` and full `Schema`. The native query owner verifies the exact
definition and current rights. Document binds an accepted
reference and bounded path/list/text projections with `DecoderColumn` values.
Result `Column` values have shared `Logical.Descriptor` types and explicit
nullable/optional flags. `Plan` selects
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

`compileSql(source, name, sql, budgets, parameters)` returns a
`CompletableFuture<Bundle>`. The optional `List<Logical.Atom>` is copied into the native
request before worker submission. The four-argument overload or `null` selects
ordinary SQL; an empty list selects a template without placeholders.
The immutable bundle survives the input list and client.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned uint64-range atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

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

Pages own immutable `Bytes` IPC and typed manifest evidence including the retained
source-cut commitment. `decode` returns immutable lists of shared `Logical.Missing`,
`Null`, `SourceTypeError`, `Present` and ordered `Conflict` cells. Nested values,
full-width signed/unsigned integers, decimals and temporal values retain their
logical representation. Copies survive client close. Standalone `decodeArrow`
checks shape; it does not establish current access or result completion. No
optional Java Arrow dependency is selected.

Bundles contain at most 25,614 bytes, batches at most eight rows and 128 result
columns, and IPC segments at most 64 KiB. KV sources have two columns; Document
projections remain bounded to eight. Predicate byte literals are limited to
4 KiB. Source/output names are nonempty UTF-8 of at most 255 bytes without NUL.

Build/install using `nix develop .#bindings` and `just bindings::java-build`.
`just bindings::unified-java` tests installed artifacts against the signed Table
schedule; its source argument accepts `kv` or `document`. The
[proof guide](../../../../tests/README.md) distinguishes measured profiles from
remaining source/deployment qualification.

Connections accept an optional selected native role; omission uses the login role.
Configure the optional direct Table endpoint with its URL, catalog scope, branch
and service audience when opening the query client. It uses the original caller's
credential and selected role. The native query progress resource can differ from
the Table's catalog resource in the same realm.

`lookupTable(namespace, name)` returns the current direct Table source, full schema and exact
partition frontier. A missing visible name returns no definition. Lookup takes no
pin and starts no query. The definition's capture helper combines that frontier
with the executor principal and a caller-chosen pin operation identity. A
concurrent change can make the expected frontier stale before acquisition; saved
work must retain its original source and expected position.

Local preparation and SQL compilation return unsigned descriptions. Call
`authorizeBundle` with the explicit capture before persisting a new Table
bundle or fingerprint. The returned bytes bind the original caller, role,
credential epoch, exact source, executor, pin owner, query route and budgets.
Storage operation, partition and WAL counters retain their full uint64 range;
native principal identities retain the native counter bound. An already signed
Table bundle rejects resealing. KV and Document bundles take no direct capture.

Persist and recover the original bundle bytes unchanged, alongside every prepared
command and receipt. Current authority is checked during progress and result
reads. Credential or policy changes never justify replacing accepted work.

`prepareCleanup` prepares separate terminal pin cleanup with the current
credential. Persist, submit and observe it like other controls. It preserves the
saved execution proof and cut, including after credential rotation, and grants no
scan or query resumption. The worker commits this proof before remote closure.

Manifest retention is `NativeRetention(ReadVersion)` or `TableRetention(worker)`;
its cut is `NativeCut(revision)` or `TableCut(commitment)`. A direct Table cut has
no native resource revision. Verified results remain readable after their pin
closes, subject to current source and result authority.
