# Unified state queries

Include `transit/unified_query.h` for the explicit v1 KV/Table/accepted-Document
profile. Result values use the shared logical model in `transit/logical.h`.
[The shared contract](../../../../contracts/UNIFIED_QUERY_V1.md) defines source
identity, decoder versions, projection budgets, five cell states and availability.

Build a `transit_station_unified_source`, typed plan and positive work budgets,
then call `transit_station_unified_prepare_bundle`. KV declares both decoders;
Table borrows its catalog owner, metadata and resolved schema; metadata includes
the immutable publication commitment. Document binds an accepted reference and
bounded path/list/text projections. Result columns carry full logical descriptors
and nullable/optional flags. Predicates and parameters use `transit_logical_atom`,
including exact two-limb 128-bit integers. Input pointers borrow only through the
synchronous call. Zig owns encoding and semantic validation. KV decoders and
Document `transit_station_unified_decoder_column` projections retain their six
scalar types and the eight-column Document projection limit.

Set the plan predicate to `TRANSIT_UNIFIED_PROGRAM` and supply one to 64
`transit_station_unified_instruction` values. `TRANSIT_UNIFIED_ATOM` carries an
all-row, state or comparison atom; `TRANSIT_UNIFIED_NEGATE`,
`TRANSIT_UNIFIED_CONJUNCTION` and `TRANSIT_UNIFIED_DISJUNCTION` combine them in
postfix order. Programs cannot nest. The instruction array and scalar byte
pointers borrow only until `prepare_bundle` returns; the bundle owns its encoded
bytes. Shared Zig validates the complete stack, source columns and scalar types
before encoding, preserving eager error order and unknown truth for null/missing.
Only true selects a row. Single-atom plans require a null instruction pointer
and zero instruction count.

The current C plan and explanation layouts require matching headers, SDK libraries
and native artifacts. Their ABI cutover replaces the shared v1 definition;
older native builds and saved requests reject before use. Recover accepted work
with its matching build before changing definitions. Source, schema and plan commitments use the current unified query formats. See the
[versioning policy](../../../../docs/handbook/reference/versioning.md).

`transit_station_unified_open` takes a growing client config, explicit credential
and source/resource/requester/request-resource connection. It owns a bounded
native worker and copied credential; it acquires no process activation.
`describe` checks current policy and the declared source. The maximum bundle is
25,255 bytes, an Arrow segment is at most 64 KiB and a batch has at most eight
rows and 128 columns. Column/output names allow 255 UTF-8 bytes. Local capability support does not establish remote permission.

`transit_station_unified_compile_sql(client, source, name, sql, budgets,
parameters, out)` returns an independently owned bundle; destroy it with
`transit_station_unified_bundle_destroy`. `parameters` points to a
`transit_station_unified_bindings` containing scalar pointers and a count.
A null bindings pointer selects ordinary SQL; a non-null binding with count zero
selects a template without placeholders. Inputs borrow only for the synchronous
call. On failure `*out` is null.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned uint64-range atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

`transit_station_unified_inspect_sql(client, source, name, sql, budgets, out)`
executes scoped `DESCRIBE name`, `SHOW TABLES` or `EXPLAIN SELECT ...` through the
shared Zig owner. On success, `*out` owns an immutable inspection. Call
`transit_station_unified_inspection_get` to borrow its names, nested descriptors,
digests, revisions and tagged description/list/explanation details; release it
with `transit_station_unified_inspection_destroy`. The owner outlives its client.
The response contains at most 128 columns and four operators. The Table listing
has zero or one names for the configured source. Explanation exposes predicate
structure without literal values and preserves full-width limits and budgets.
A program explanation owns up to 64 instructions and redacted names/types.
Inspection rechecks current authorization before returning, creates no snapshot
and admits no query. Failure leaves `*out` null.

For a positive namespace, call `prepare_next`, copy and persist the returned
prepared bytes, then `submit`. Keep the prepared owner until a definite outcome.
`TRANSIT_SDK_UNKNOWN_OUTCOME` requires resubmitting the identical persisted bytes;
never replace them with another freshly prepared command. `observe` checks the
admitted input's behavior disposition. A receipt is admission, and a null next
command means inspect status. Neither means the result is complete.

Read pages only after a complete status. Every page checks current grants,
source lifecycle, manifest/segment digests and ordered coverage. Manifest
evidence includes the retained source head alongside source/schema digests. `page_next`
returns an owned opaque cursor; null means verified complete coverage. A saved
cursor does not grant access. Cancellation, retirement and collection are explicit
prepared controls with the same persistence/submission rules. Closing a client
does not record cancellation or remove accepted work.

Destroy every bundle, prepared command, cursor, inspection, page, decoded rows
and client with its matching function. `page_get` borrows IPC, names and full
descriptors from its page. `rows_cell` returns a `transit_logical_cell_view` whose
nested values and conflict alternatives borrow the decoded rows owner. A scalar
cell contains a logical value with kind `TRANSIT_VALUE_ATOM`.
Pages survive client destruction, and decoded rows survive page destruction.
Standalone `decode_arrow` validates shape and preserves conflict alternatives;
it establishes neither current access nor complete-result provenance.

Operations block on the bounded worker. One operation may be in flight; overlapping
work returns BUSY. Close joins owned work; join caller threads before moving or
destroying public handles. No destructor dispatches a durable control.

`just bindings::unified-c` installs independent archives and exercises C11 and
C++17 consumers against signed KV recovery. An optional source argument chooses
`table` or `document`. The [proof guide](../../../../tests/README.md) records
measured runs and remaining qualification separately.

Connections accept an optional selected native role; omission uses the login role.
Local bundle construction produces a description. Call `transit_station_unified_authorize_bundle` once on the
query client before persisting a newly constructed Table bundle or its fingerprint.
The returned bytes bind the authenticated caller, role, credential epoch, source
owner and requester to the exact query and budget. SQL compilation already returns
an authorized bundle. An already authorized Table bundle rejects resealing.

Persist and recover the original bundle bytes unchanged, alongside each prepared
command and receipt. Current authorization is checked again during progress and
result disclosure. Credential or policy changes never justify replacing accepted
work with a newly signed bundle. The complete bundle bound is 25,255 bytes.
