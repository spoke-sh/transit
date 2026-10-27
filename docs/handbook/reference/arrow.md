# Arrow interchange

Arrow supplies typed columnar values and interchange for query results. It is
not a storage authority, grant mechanism or query planner. Fuze evaluates plans
and emits bounded batches; source adapters retain their own accepted revision,
decoding and current-policy rules.

Physical compute columns do not change Arrow IPC schemas, five-state sidecars,
output page sizes or buffer ownership. Logical/Unified execution validates each
original source page before borrowing it for column predicates. Owned pull-query
outputs deep-copy recursive values and remain valid after the compute batch is
reset. See [physical execution](queries.md#physical-execution).

## Interface boundaries

| Interface | Role |
| --- | --- |
| Arrow IPC | Versioned batch/schema bytes for durable capture and transport |
| Arrow C data/stream interfaces | In-process ownership and release callbacks for compatible consumers |
| Flight | RPC transport for selected Arrow operations |
| Flight SQL | SQL/metadata conventions over Flight |
| ADBC | A client API; the Flight SQL driver connects to the gateway |

Support for one boundary does not imply every Arrow type or protocol method.
Native unified queries carry five-state nested cells; the Flight
gateway serves finite Table v1 with int64 types. It cannot
silently flatten arbitrary query Documents or KV projections into that profile.

Local [`transit_fuze.LogicalArrow`](../../../packages/zig/transit-fuze/README.md)
exports the richer logical type model, including recursive cells and exact
decimal/temporal/128-bit values. The [logical Arrow contract](../../../contracts/FUZE_ARROW_V1.md)
defines physical layouts, mandatory schema evidence, five states, ownership and
the independent eight-row/4 MiB workspace/64 KiB segment limits. This capability
includes local `LogicalInspect` decoding of one canonical complete segment against
an exact supplied schema. Decoded rows and descriptors own their bytes. General
external Arrow import, neutral ABI import, full logical C data export and richer Flight
output admission have separate contracts and are not enabled by this decoder.
Native durable query jobs use these logical segments under their own source and
working-set bounds. Fixed encoding-workspace exhaustion is distinct from a host
allocator failure.

## Ownership and complete results

Keep the batch schema, validity and field-state representation with its buffers.
Respect borrowed lifetimes; retain/copy through the owning API and release native
arrays/streams exactly as specified. A release callback cannot run while another
consumer still references its buffers. Host cancellation does not automatically
join native work or release a live resource safely.

Fuze's retained segment group exposes aligned Arrow value buffers for plain
int64, uint64, float64, Boolean, UTF-8, binary and JSON columns on little-endian
hosts. The local `arrowValues` view borrows both the group and a caller-owned
buffer directory. Non-value cells appear null in that value child; the enclosing
column's state tags and error/conflict details preserve their full meaning.
Retaining a borrowed buffer does not extend the group's lifetime. A
`TSegReader.SharedGroup` can instead own the group and produce retained Arrow
value arrays. Their slices and C exports pin the same payloads until the final
release callback. Hosts keep the backing allocators alive and charge retained
groups to their memory budgets. These arrays describe the nullable value child;
full Transit cells still require the state and error/conflict sidecars. Recursive
and other encoded columns use bounded logical decoding. This interface does not
admit arbitrary external Arrow input. See the
[segment reader](../../../packages/zig/transit-fuze/README.md) for ownership and
the [stored layout](../../../contracts/TRANSIT_STORAGE_V1.md#qualified-plain-value-buffers)
for offsets, validity and canonical padding.

Decode bounded batches and validate full-width identities, lengths and semantic
cell states at language boundaries. A readable IPC prefix is not a verified
complete query. Result manifests, ordered segment coverage and digests remain
necessary; preserve the source basis with the result.

The [Transit console](../../../apps/transit-cli/docs/console.md) consumes logical
statement results through the shared SQL client. Its table presentation does not
expose storage pages or Arrow segment boundaries. Native session cells currently
use canonical logical bytes in a bounded hex/JSON envelope; captured query owners
can decode their retained Arrow segments beneath that boundary. JSON presentation
uses exact typed row envelopes and a verified logical-result footer.

The shared Zig Arrow implementation and pinned dependencies live under
[Fuze](../../../packages/zig/transit-fuze/README.md). Public language wrappers own
their native values and release rules above the shared boundary. Use the
[SDK reference](sdks.md) for target packages and [queries](queries.md) for recovery.

For remote clients, use [Flight SQL and ADBC](flight.md) and its tested client/type
matrix. Outbound captured Flight effects use a separate
[connector](../../../packages/zig/transit-station-flight/README.md); an inbound query
ticket does not authorize an outbound RPC or confer data access.
