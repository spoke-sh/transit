# Arrow interchange

Arrow supplies typed columnar values and interchange for query results. It is
not a storage authority, grant mechanism or query planner. Fuze evaluates plans
and emits bounded batches; source adapters retain their own accepted revision,
decoding and current-policy rules.

## Interface boundaries

| Interface | Role |
| --- | --- |
| Arrow IPC | Versioned batch/schema bytes for durable capture and transport |
| Arrow C data/stream interfaces | In-process ownership and release callbacks for compatible consumers |
| Flight | RPC transport for selected Arrow operations |
| Flight SQL | SQL/metadata conventions over Flight |
| ADBC | A client API; the qualified driver connects through Flight SQL |

Support for one boundary does not imply every Arrow type or protocol method.
Native unified queries carry five-state nested cells; the qualified Flight
gateway currently serves finite Table v1 and its selected int64 types. It cannot
silently flatten arbitrary v2 Documents or KV projections into that profile.

## Ownership and complete results

Keep the batch schema, validity and field-state representation with its buffers.
Respect borrowed lifetimes; retain/copy through the owning API and release native
arrays/streams exactly as specified. A release callback cannot run while another
consumer still references its buffers. Host cancellation does not automatically
join native work or release a live resource safely.

Decode bounded batches and validate full-width identities, lengths and semantic
cell states at language boundaries. A readable IPC prefix is not a verified
complete query. Result manifests, ordered segment coverage and digests remain
necessary; preserve the source basis with the result.

The shared Zig Arrow implementation and pinned dependencies live under
[Fuze](../../packages/zig/transit-fuze/README.md). Public language wrappers own
their native values and release rules above the shared boundary. Use the
[SDK reference](sdks.md) for target packages and [queries](queries.md) for recovery.

For remote clients, use [Flight SQL and ADBC](flight.md) and its tested client/type
matrix. Outbound captured Flight effects use a separate
[connector](../../packages/zig/transit-station-flight/README.md); an inbound query
ticket does not authorize an outbound RPC or confer data access.
