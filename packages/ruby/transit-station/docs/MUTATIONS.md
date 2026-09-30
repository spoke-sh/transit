# Table mutation callers

`Transit::Station::Mutations::Client` exposes bounded SQL INSERT, primary-key
UPDATE and DELETE through the shared Zig mutation caller. Supply an explicit
writer/resource/Table connection and credential. The writer must expose the
operation and separately authorize the caller; a query grant does not enable
writes.

```ruby
m = Transit::Station::Mutations
connection = m::Connection.new(writer: writer, resource: resource, table: table_id)
m::Client.open(config, credential, connection) do |client|
  metadata = client.describe
  compiled = client.compile_sql('items', 'UPDATE items SET value=12 WHERE id=7', namespace)
  save_compiled(compiled.request, compiled.reference.data)
end
```

`writer` and `resource` are realm-qualified `ProcessRef` and `ResourceRef` values.
Use `ClientConfig` with `profile: :native_v1` and a `Credential` in that realm.
The URL, timeout and optional trusted `native_host` follow the raw client's
configuration. The default is the matching installed native Station gem. Opening
checks the generated contract definition and capabilities before caller work.
Loading the module starts no worker and reads no credential.

Namespace is a positive uint64 `Integer`. `Compiled` owns a frozen binary
request `String` and full `Reference`; save both unchanged before upload.
`Prepared` owns opaque, frozen UTF-8 text. Constructors copy caller strings.
The [shared mutation contract](../../../../contracts/TABLE_MUTATION_V1.md)
defines the three-row limit, value types, conflicts, atomicity and authority gates.
Compilation does not reserve rows or prove admission.

`prepare_next(compiled)` prepares one stage. Persist its `Prepared.data` before
calling `submit(prepared)`, which returns the admitted input position. An
`Uncertain` error preserves the original `prepared`; resubmit the exact saved
text after recreating the caller if needed. Do not recompile, parse/re-encode
the token, allocate a new namespace or prepare another stage while admission
is unresolved. There is no implicit upload loop or automatic retry.

After a receipt, wait for `observe(prepared, position)` to return `:processed`,
then inspect `rejection(prepared, position)` before asking for the next stage.
Input processing can record a separate rejection while leaving the request's
status unchanged. A nil next command requires `status(compiled.reference)`:
`:applied`, `:rejected` and `:cancelled` remain distinct. Only a durable applied
result establishes `affected_rows`; an admission receipt is not a row count.
`prepare_apply(reference)` and `prepare_cancel(reference)` are explicit controls;
cancellation cannot undo rows already applied.

Each client owns one Ruby worker and one native child. The synchronous API
allows ordinary Ruby scheduling during I/O and rejects overlapping work with
`Busy`; it is not a Fiber scheduler adapter. A cancelled caller thread cannot
cancel owned native work. `close` joins that work and the child. Block-based
`open` protects acquisition until its ensure clause owns cleanup. Preserve
recovery text independently of host threads, and serialize new principal
sequences across separate clients yourself.

Description and status fields use owned immutable values and symbols. Current
native read grants gate every observation; references and schema commitments
confer no authority. The port validates generated action/response schemas and
retains native error causes without logging statement text or credentials.
