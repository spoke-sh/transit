# Unified state queries

`Transit.Station.Sdk.UnifiedQuery` supplies structs and tagged results over the
[public Erlang query API](../../transit-station-sdk/docs/unified-query.md).
`KvSource`, `TableSource` and `DocumentSource` share `Plan`, `Budgets`, typed
projections and shared logical descriptors, atoms and cells. `TableSource` takes
a direct catalog scope, service audience, branch, namespace, `TableInterpretation`
and full schema. Result `Column` values carry nullable/optional flags,
with up to 128 columns and 255-byte UTF-8 names. KV decoders and Document
`DecoderColumn` projections retain their six scalar types and the eight-column
Document projection limit. Source/plan semantics and binary codecs remain in
shared Zig.

```elixir
alias Transit.Station.Sdk.UnifiedQuery, as: Q
source = %Q.KvSource{
  resource: resource, prefix: "data/",
  key: %Q.Decoder{type: :binary}, value: %Q.Decoder{type: :uint64}
}
{:ok, bundle} = Q.prepare(source, %Q.Plan{projection: [1]},
  %Q.Budgets{pages: 1000, segments: 100, result_bytes: 1_048_576})
{:ok, client} = Q.open(config, credential, connection)
```

`%Q.PredicateProgram{instructions: instructions}` composes one to 64 immutable
postfix instructions. Use `{:atom, :all}`, `{:atom, {:state, column, state}}` or
`{:atom, {:compare, column, op, scalar}}`, followed by `:negate`, `:conjunction`
or `:disjunction`. Two atoms followed by `:conjunction` express AND. Programs
cannot nest. The Erlang adapter and shared Zig owner validate bounds, stack shape,
columns and scalar types; evaluation preserves eager error order and null/missing
unknown, selecting only true. Inspected programs use the same struct with
column names/types instead of comparison literals.

The application supplies scoped public refs, an explicit credential and connection.
`describe` checks policy. Persist `Prepared.bytes` returned by `prepare_next`
before calling `submit`. `{ :uncertain, prepared, error }` preserves the identical
retry token. Admission, `observe` disposition and `status` completion are separate;
`nil` from `prepare_next` means inspect status. `prepare_control` creates explicit
cancel/retire/collect commands with the same persistence rules.

`compile_sql(client, source, name, sql, budgets, parameters \ nil)` returns
`{:ok, %Bundle{}}` or a tagged error through the shared Erlang owner. Bindings are
a list of the existing tagged scalars, such as `{:utf8, "value"}` and
`{:unsigned, 8}`. `nil` selects ordinary SQL; `[]` selects a template without
placeholders. The immutable result survives client close.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned uint64-range atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

`inspect_sql(client, source, name, sql, budgets)` returns `{:ok, %Inspection{}}`
for scoped `DESCRIBE name`, `SHOW TABLES` and `EXPLAIN SELECT ...`. Its details
are `SourceDescription`, `TableListing` or `Explanation` structs with owned
immutable values, source/schema digests and current resource/policy revisions.
Explanation includes ordered operator atoms, predicate structure without literal
values, projection/output columns and explicit budgets. Integers preserve all
64 bits. The shared Zig owner checks current authorization before and after
resolution, creates no snapshot and admits no query. The listing covers only
the configured source; local tasks do not extend its permission.

`page` rechecks current source access, lifecycle and complete result coverage.
It returns immutable IPC and manifest evidence with an optional opaque cursor;
`nil` continuation means verified complete coverage. `decode_arrow` preserves
`:missing`, `:null`, type errors, nested logical values and ordered
`Logical.Alternative` values. A scalar cell is `{:value, {:atom, atom}}`;
integers retain their full 128-bit range. Manifest evidence includes the retained
source head.
Local decoding does not establish current permission. Pages and values survive
close; no optional BEAM Arrow dependency is selected.

Calls wait on an owned bounded port worker. Killing a waiting Task does not stop
its admitted operation or cancel the durable query. `close` joins native work;
keep prepared bytes durably if the owning process can disappear. Structs, tasks
and BEAM PIDs are temporary host state, not durable Transit ownership.

`just bindings::unified-beam` tests installed packages against shared source/Arrow
fixtures and the signed Table recovery schedule. See the
[proof guide](../../../../tests/README.md) for measured source-specific evidence.

Connections accept an optional selected native role; omission uses the login role.
Configure the optional direct Table endpoint with its URL, catalog scope, branch
and service audience when opening the query client. It uses the original caller's
credential and selected role. The native query progress resource can differ from
the Table's catalog resource in the same realm.

`lookup_table/3` returns the current direct Table source, full schema and exact
partition frontier. A missing visible name returns no definition. Lookup takes no
pin and starts no query. The definition's capture helper combines that frontier
with the executor principal and a caller-chosen pin operation identity. A
concurrent change can make the expected frontier stale before acquisition; saved
work must retain its original source and expected position.

Local preparation and SQL compilation return unsigned descriptions. Call
`authorize_bundle/3` with the explicit capture before persisting a new Table
bundle or fingerprint. The returned bytes bind the original caller, role,
credential epoch, exact source, executor, pin owner, query route and budgets.
Storage operation, partition and WAL counters retain their full uint64 range;
native principal identities retain the native counter bound. An already signed
Table bundle rejects resealing. KV and Document bundles take no direct capture.

Persist and recover the original bundle bytes unchanged, alongside every prepared
command and receipt. Current authority is checked during progress and result
reads. Credential or policy changes never justify replacing accepted work.

`prepare_cleanup/3` prepares separate terminal pin cleanup with the current
credential. Persist, submit and observe it like other controls. It preserves the
saved execution proof and cut, including after credential rotation, and grants no
scan or query resumption. The worker commits this proof before remote closure.

Manifest `source` is `{native, ReadVersion}` or `{table, Worker}`; `cut` is
`{native_revision, Revision}` or `{table, Commitment}` (Elixir uses atom tags).
A direct Table cut has no native resource revision. Verified result reads after
pin closure still check current source and result authority.
