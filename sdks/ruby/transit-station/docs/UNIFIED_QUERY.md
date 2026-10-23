# Unified state queries

`Transit::Station::Unified` provides typed v1 KV/Table/accepted Document sources,
plans, finite budgets and owned nested Arrow results. It composes shared Zig
through one joined native worker; Ruby contains no query execution or protocol
implementation. Import starts no process or credential access.

Use `KVSource` with explicit versioned `Decoder` values, `TableSource` with its
direct catalog scope, service audience, branch, namespace, `TableInterpretation` and `Schema`, or `DocumentSource` with an accepted `DocumentReference` and
bounded `Projection` values with `DecoderColumn` declarations. Table columns
reuse logical descriptors with explicit nullable/optional flags; `Scalar` is the
shared `Logical::Atom` type. The native owner verifies the full interpretation commitment
and current catalog rights when admitting a Table query. `Bundle.prepare(source, plan, budgets)` validates
and creates canonical bytes without admitting work. All wide values use Ruby
`Integer`; binary strings and returned bytes are copied and frozen.

`PredicateProgram.new(instructions: [...])` copies and freezes one to 64 postfix
instructions. Use `PredicateAtom.new(predicate: comparison_or_state)` or
`PredicateAtom.new` for an all-row atom, and `:negate`, `:conjunction` and
`:disjunction` for operators. Shared Zig validates complete stack shape and typed
atoms; nested programs reject. Evaluation retains instruction order, unknown
truth and eager errors. EXPLAIN returns an `InspectedProgram` with frozen
`InspectedAtom` values and operator symbols, excluding literal values.

`Client.open(config, credential, connection) { |client| ... }` owns one query
port. The explicit `Connection` binds source/requester PIDs and resources in one
realm. It needs no activation or writer ownership. `describe(source)` checks
current availability and policy. Native requests and results are checked against
the generated schema, including the complete tagged variants.

Pass `tables: Tables.new(url:, scope:, branch:, audience:)` to `Client.open` for
direct Table access. It shares the native client's credential and selected role;
the catalog and native progress resources can differ within the same realm.
`lookup_table(name, namespace: 1)` returns a `TableDefinition` with the full schema,
source identity and observed partition/frontier, or nil. Lookup starts no work
and acquires no pin. Compile using its `source`, then authorize with
`capture: definition.capture(executor:, operation:)`. A concurrent change can
invalidate that expected frontier; saved work never substitutes a later cut.

`compile_sql(source, name, sql, budgets, parameters: nil)` returns an owned
`Bundle`. Supply an array of immutable `Scalar` values to bind placeholders.
`nil` selects ordinary SQL; `[]` selects a template without placeholders.
The resulting bytes are copied and frozen.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned uint64-range atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

`inspect_sql(source, name, sql, budgets)` executes scoped `DESCRIBE name`,
`SHOW TABLES` or `EXPLAIN SELECT ...` through the same Zig inspection owner as
the console. The immutable `Inspection` carries source/schema digests, current
resource/policy revisions and `SourceDescription`, `TableListing` or
`Explanation` details. Explanation includes ordered operator symbols, a typed
predicate without literal values, projection/output columns and explicit budgets.
Wide values remain `Integer`; returned strings, digests and arrays are frozen.
The operation checks current authorization before and after resolution, creates
no snapshot and admits no query. The listing covers only the configured source.

For each command, call `prepare_next(namespace, bundle)`, persist the returned
`Prepared.data`, and then `submit(prepared)`. The returned input position proves
admission only; wait for `observe(position).state == :committed` before preparing
again. A nil prepared command does not establish query completion. Read
`status(namespace)` for admitted and terminal phases. A rejected observation
retains the durable behavior rejection separately from admission failure.

`Uncertain` carries the unchanged `prepared` value after unconfirmed dispatch.
Resubmit those identical bytes, including after replacing the owner. Do not
parse/re-encode the token or generate another command to resolve that attempt.
`prepare_cancel`, `prepare_retire` and `prepare_collect` use the same persistence,
submission and observation sequence. Interrupting a Ruby wait does not cancel
accepted work; closing joins the worker before destroying the native owner.

After completion, `page(namespace, cursor)` returns an immutable page with owned
IPC, typed manifest provenance and an optional next `Cursor`. `Manifest#cut` is
`NativeCut` for KV/Document resource revisions or `TableCut` for the original direct
interpretation/manifest/WAL commitment. `Manifest#source` is respectively a retained
read version or the query worker's `ProcessRef`. Every page rechecks
current source/request grants and lifecycle. A cursor is verification progress,
not permission; save it only with the same connection and namespace. Read failure
does not advance it. Nil next establishes verified whole-result coverage.

`Page#decode` and `Unified.decode_arrow(columns, ipc, rows)` return typed cells
through shared Zig. Missing, null, type error, value and conflict remain distinct;
results reuse the `Logical` cell classes, and alternatives retain their original
ordered assignment identities. Predicate byte literals are bounded to 4 KiB.
Batches have at most eight rows and 128 result columns; KV has two source
columns and Document projections remain bounded to eight. Source/output names
are nonempty UTF-8 strings of at most 255 bytes without NUL. Bundles are bounded
to 25,614 bytes and IPC segments to 64 KiB. Nested values and exact 128-bit
integers retain their shared logical representation. No optional Ruby Arrow dependency is selected; original
owned IPC remains available to an application-selected consumer.

`nix develop .#bindings --command just bindings::unified-ruby kv` builds fresh
gems and tests shared codecs plus signed recovery. Other source selections are
`table` and `document`; consult [completed evidence](../../../../tests/README.md).

Connections accept an optional selected native role; omission uses the login role.
Local bundle construction produces a description. Call `authorize_bundle` once on the
query client with `capture: Capture.new(executor:, operation:, partition:, next_lsn:)`
before persisting a newly constructed Table bundle or its fingerprint. The executor
is a principal; the pin operation and exact frontier use full-width `Integer` values.
The returned bytes bind the authenticated caller, role, credential epoch, source
owner and requester to the exact query and budget. SQL compilation returns an unsigned description; Tables require this explicit
capture authorization. An already authorized Table bundle rejects resealing.

Persist and recover the original bundle bytes unchanged, alongside each prepared
command and receipt. Current authorization is checked again during progress and
result disclosure. Credential or policy changes never justify replacing accepted
work with a newly signed bundle. The complete bundle bound is 25,614 bytes.

`prepare_cleanup(namespace, original_bundle)` returns a separate prepared terminal
cleanup control using the current credential. Persist, submit and observe it like
the other controls. It preserves the original execution proof and source cut after
credential rotation and grants no source scan or query resumption.
