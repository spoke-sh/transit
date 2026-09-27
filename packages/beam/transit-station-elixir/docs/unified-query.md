# Unified state queries

`Transit.Station.Sdk.UnifiedQuery` supplies structs and tagged results over the
[public Erlang query API](../../transit-station-sdk/docs/unified-query.md).
`KvSource`, `TableSource` and `DocumentSource` share `Plan`, `Budgets`, typed
projections and six tagged scalar types. Source/plan semantics and binary codecs
remain in shared Zig. Explicit v2 querying does not change the original Table API.

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

The application supplies scoped public refs, an explicit credential and connection.
`describe` checks policy. Persist `Prepared.bytes` returned by `prepare_next`
before calling `submit`. `{ :uncertain, prepared, error }` preserves the identical
retry token. Admission, `observe` disposition and `status` completion are separate;
`nil` from `prepare_next` means inspect status. `prepare_control` creates explicit
cancel/retire/collect commands with the same persistence rules.

`page` rechecks current source access, lifecycle and complete result coverage.
It returns immutable IPC and manifest evidence with an optional opaque cursor;
`nil` continuation means verified complete coverage. `decode_arrow` preserves
`:missing`, `:null`, type errors, typed values and ordered conflict alternatives.
Local decoding does not establish current permission. Pages and values survive
close; no optional BEAM Arrow dependency is selected.

Calls wait on an owned bounded port worker. Killing a waiting Task does not stop
its admitted operation or cancel the durable query. `close` joins native work;
keep prepared bytes durably if the owning process can disappear. Structs, tasks
and BEAM PIDs are temporary host state, not durable Transit ownership.

`just bindings::unified-beam` tests installed packages against shared source/Arrow
fixtures and the signed Table recovery schedule. See the
[proof guide](../../../../tests/README.md) for measured source-specific evidence.
