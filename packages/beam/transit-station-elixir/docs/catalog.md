# Catalog callers

`Transit.Station.Sdk.Catalog` provides immutable structs and tagged results over
the [Erlang catalog API](../../transit-station-sdk/docs/catalog.md). Shared Zig
owns compilation, signing, current policy and exact saved-command recovery.

```elixir
alias Transit.Station.Sdk.Catalog, as: C
{:ok, client} = C.open(config, credential,
  %C.Connection{owner: owner, scope: %C.Scope{resource: resource, catalog: catalog}})
try do
  {:ok, compiled} = C.compile_sql(client,
    "CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL)",
    operation, object, table)
  {:ok, prepared} = C.prepare_create(client, compiled.request)
  save(prepared.bytes)
  {:ok, admission} = C.submit(client, prepared)
after
  C.close(client)
end
```

Configuration, credentials and realm-qualified owner/resource refs are explicit.
Catalog, operation/object identities and policy revisions are positive full-width
uint64 integers; Table IDs are positive uint32 integers. Native counters retain
their safe-integer bounds. Opening checks the matching native definition and
capabilities; each server operation checks current authority separately.

`capabilities` returns a `Capabilities` struct. `describe` returns a `Description`
with configuration, current policy and resource revision. `prepare_initialize`,
`prepare_create` and `prepare_policy` take `Configuration`, `CreateTable` and
`PolicyChange` structs. Save the returned `Prepared.bytes` before submission;
restore `%C.Prepared{bytes: saved}` to reconcile after caller loss. The command
is opaque signed UTF-8 text bounded to 8192 bytes. Canonical review bytes in
`Compiled` are bounded to 256 bytes. There is no implicit retry or re-signing.

`submit` returns an admission receipt or `{:uncertain, prepared, error}` retaining
the identical retry value. Malformed successful replies preserve uncertainty;
native rejection retains its category, status and code. `observe` returns
`:pending` or `:processed`. `input_disposition` reports an optional control or
rejection result; `status(client, original_request)` reports the original creation
receipt. Optional values use `nil` inside `{:ok, value}`. Only outcome `:applied`
establishes creation. Current catalog/native policies gate result disclosure.

Calls wait on the bounded owned worker. Overlap returns `:busy`. Killing a waiting
Task does not stop native work or cancel durable work; `close` joins cleanup.
Creating-owner loss initiates monitored cleanup. Persist recovery values outside
temporary BEAM processes. Created Tables do not automatically become query
sources or mutation writers. The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md)
defines supported schemas, policy and atomic publication; the
[proof ledger](../../../../tests/README.md) records executed coverage and limits.
