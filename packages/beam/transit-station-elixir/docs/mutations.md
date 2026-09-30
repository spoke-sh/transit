# Table mutation callers

`Transit.Station.Sdk.Mutations` supplies immutable structs and tagged results
over the [public Erlang mutation API](../../transit-station-sdk/docs/mutations.md).
Shared Zig owns SQL compilation, full request identity, signing and recovery.

```elixir
alias Transit.Station.Sdk.Mutations, as: M
{:ok, client} = M.open(config, credential,
  %M.Connection{writer: writer, resource: resource, table: 1})
try do
  {:ok, compiled} = M.compile_sql(client, "items",
    "UPDATE items SET value=12 WHERE id=7", namespace)
  save_compiled(compiled.request, compiled.reference.bytes)
  {:ok, next} = M.prepare_next(client, compiled)
after
  M.close(client)
end
```

Configuration, credentials and realm-qualified refs are explicit. The writer
separately enables and authorizes mutations; query access does not confer write
access. Opening checks the exact native definition and local capabilities.
`describe` returns current metadata, permissions and optional active namespace.
Namespaces accept positive uint64 values without signed narrowing.

Persist both `Compiled.request` and its complete `Reference.bytes` before upload.
`prepare_next` returns `{:ok, %Prepared{}}` or `{:ok, nil}`. Persist `Prepared.bytes`
before `submit`. `{:uncertain, prepared, error}` preserves the identical retry
token. Reconstruct `%Prepared{bytes: saved}` and resubmit, including after caller
replacement. Do not regenerate commands or advance an unresolved upload.
Compilation does not establish admission and there is no implicit retry loop.

Submission returns an admission receipt. `observe(client, prepared, input)`
returns `:pending` or `:processed`; `rejection` separately reports an optional
input rejection. `status(client, reference)` returns a `Status` struct or `nil`.
Only `:applied` establishes affected rows. A nil next command requires checking
status. `prepare_control` accepts `:apply` or `:cancel`; cancellation cannot undo
applied rows. Saved bytes and refs never confer authority. Current read grants
gate metadata and observations.

Calls wait on the existing bounded owned worker. Overlapping calls return `:busy`.
Killing a waiting Task does not stop its admitted operation or cancel durable
work. `close` joins cleanup; retain saved bytes durably when the creating process
can disappear. Immutable structs and binaries survive client close, but BEAM
processes and fields are temporary host state. Request bounds, scalar types and
failure behavior are defined by the [shared mutation contract](../../../../contracts/TABLE_MUTATION_V1.md).
Executed installed-consumer coverage belongs to the [proof ledger](../../../../tests/README.md).
