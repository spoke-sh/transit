# Unified state queries

Include `transit/unified_query.hpp` and use
`transit::sdk::station::unified`. The C++17 API composes the
[public C SDK](../../../c/transit-station/docs/UNIFIED_QUERY.md); source validation,
encoding, signatures and query semantics remain in shared Zig.

```cpp
namespace q = transit::sdk::station::unified;
q::Source source = q::KvSource{
    resource, {'d', 'a', 't', 'a', '/'}, {q::Type::Binary}, {q::Type::UInt64}
};
auto bundle = q::prepare(source, {{1}, All{}, Aggregate::Rows, std::nullopt},
                         {1000, 100, 1048576});
auto client = q::Client::open(config, credential, connection);
auto capabilities = client.describe(source);
auto command = client.prepare_next(namespace_id, bundle);
```

The surrounding application supplies realm-scoped process/resource refs, the
explicit credential and a durable positive namespace. `Source` is a variant of
`KvSource`, `TableSource` and `DocumentSource`. `Plan` uses ordered projections,
`All`, `IsState` or typed `Compare`, an optional full-width limit and an explicit
aggregate. Unsupported decoder versions, types and paths reject.

Persist `command->data()` before `client.submit(*command)`. An
`Error` with `TRANSIT_SDK_UNKNOWN_OUTCOME` leaves the caller-owned token intact;
recover it using `Prepared::recover` and resubmit the identical bytes. Admission,
`observe` disposition and `status` completion are separate. An empty
`prepare_next` result means inspect status, not completed results.

After completion, `page` returns owned IPC, typed columns, manifest evidence and
an optional owned cursor. `Page::decode` copies rows into variants:
`Missing`, `Null`, `TypeError`, `Scalar` or ordered `Conflict` alternatives.
Scalar is a variant of `int64_t`, `uint64_t`, `double`, `bool`, `std::string` and
`Bytes`. Both pages and decoded values outlive the client. A local decode checks
Arrow shape; only an authorized page read checks current source availability and
result coverage. No Arrow C++ dependency is selected by the core SDK.

Clients, bundles, prepared commands and cursors are move-only. Calls block on the
C SDK's bounded worker. Close/RAII joins work without cancelling the durable
query. Join caller threads before moving/destroying a handle. Use
`prepare_control(Control::Cancel/Retire/Collect, namespace_id)` to explicitly
record lifecycle work, with the same persistence and uncertain-outcome rules.

`just bindings::unified-c` builds installed C11/C++17 consumers, independent nested
Arrow fixtures and the signed service recovery schedule. Source-specific evidence
and remaining deployment work are in the [proof guide](../../../../tests/README.md).
