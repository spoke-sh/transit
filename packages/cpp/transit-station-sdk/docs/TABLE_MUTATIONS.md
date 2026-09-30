# Table mutation callers

Include `transit/table_mutation.hpp` and use
`transit::sdk::station::mutations`. The C++17 API wraps the
[typed C mutation caller](../../../c/transit-station/docs/TABLE_MUTATIONS.md).
Shared Zig owns SQL validation, request commitments, signing, staging, policy,
current authorization and exact recovery.

```cpp
namespace m = transit::sdk::station::mutations;
auto client = m::Client::open(config, credential, {writer, resource, table_id});
auto compiled = client.compile_sql("items", "UPDATE items SET value=12 WHERE id=7", namespace_id);
save_compiled(compiled.request(), compiled.reference());
auto command = client.prepare_next(compiled);
```

The application supplies the explicit growing `ClientConfig`, `Credential`,
realm-qualified `ProcessRef`/`ResourceRef`, positive Table ID and positive
`uint64_t` namespace. `describe` returns owned names, schema commitment, policy
revision, operation permissions and optional active namespace. A writer policy
and native grants authorize mutations separately from read queries.

`Compiled::recover` copies a saved canonical request and complete `Reference`;
`Prepared::recover` copies an opaque signed command. Their getters return copies.
Persist each command's `data()` before `submit(*command)`. An `Error` whose
`detail().kind` is `TRANSIT_SDK_UNKNOWN_OUTCOME` leaves the command intact:
recreate the client if needed and resubmit precisely those bytes. Do not
recompile, replace the namespace or advance staging across an unknown admission.

Admission, processing and application are distinct. `observe` returns Pending
or Processed; `rejection` returns an optional input rejection. An empty next
command requires `status(reference)`; only Phase::Applied establishes affected
rows. Status is optional and binds the complete request reference. Use
`prepare_control(Control::Apply/Cancel, reference)` for explicit controls.
Cancellation cannot undo applied rows. Current read grants gate observations.

Clients, compiled values and prepared commands are move-only. Their owned values
outlive the client. Calls block on the C SDK's bounded worker; overlap rejects
with BUSY. Close and RAII join native ownership without sending a durable control.
Join caller threads before moving or destroying handles. Coordinate principal
sequence allocation across independent clients. No hidden retry queue or upload
loop allocates new accepted work.

The shared profile bounds requests to three rows, 799 canonical bytes and 8192
saved command bytes. It supports nullable int64, bool, UTF-8 and binary values
with a nonnull int64 primary key; the
[mutation contract](../../../../contracts/TABLE_MUTATION_V1.md) owns exact bounds.
Executed installed-consumer coverage and measurements live in the
[proof ledger](../../../../tests/README.md).
