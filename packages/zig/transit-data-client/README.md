# Shared data client

`transit_data_client.Catalog` declares, changes and inspects direct catalog data
through the public Catalog operations. It owns endpoint strings, signing state,
transports and one local immutable intent. It uses no Station handler, activation
or native Station artifact. The existing catalog ABI composes this same caller
with its native buffer and host scheduling boundary.

The package depends on `transit-catalog`; the low-level `transit-client` remains
below Catalog. The build rejects transitive Station imports. Consumer Zig
applications import this module through the [Zig SDK](../../../sdks/zig/README.md).

`Context` composes multiple Catalog facets over caller-owned I/O, with bounded
handle/data/control capacity and joined local closure. It exposes the same
explicit Table, log, Stream and Queue calls. See the
[context guide](docs/context.md) for handle lifetimes, reserved control capacity,
close cancellation and remaining boundaries.

## Construction and ownership

Supply an allocator, `std.Io`, explicit endpoint, native catalog connection and
32-byte signing seed to `Catalog.init`. Construction validates local inputs and
copies endpoints and key state without contacting the authority, discovering
credentials or starting a thread pool. The seed supplied by the application
remains application-owned. `deinit` erases the retained key.

`Config.service_url` defaults to `url`. URLs are bounded to 2048 bytes and reject
user information, queries and fragments. `timeout_ms` defaults to 5000 and must
be in 1–60000. Trust and current authorization follow the existing
[native transport](../transit-client/README.md) and
[direct catalog contract](../../../contracts/DIRECT_TABLE_V1.md).
Local construction and local capability values establish no running-service
support or permission.

The caller supplies I/O shared with other admitted work. It must outlive the
client. Keep each client at a stable address during calls and join active calls
before destruction or changing its observer. One call can use a handle at a
time; overlap returns `Busy`. This client does not supply a concurrency queue,
principal sequence allocator, SQL session or joined asynchronous host lifecycle.
Those remain the embedding application's responsibility.

## Operations and outcomes

`Catalog.call(output, action)` accepts the existing
[`DirectTableBridge.Action`](../transit-catalog/src/DirectTableBridge.zig):
local load/forget, typed or SQL preparation, preview/stage/admit, bounded
execute/inspect/cancel, metadata, administration, dependency, resource and
retention operations. These are explicit operations, not an automatic settlement
API. Metadata-dependent preparation performs authorized reads. Importing a
saved operation does not supply a new identity or grant.

`Catalog.callLog(output, action)` exposes the shared `DirectLogClient.Action`
for Stream/Queue lifecycle preview, admission, bounded execution/inspection/
cancellation, lookup, paged listing and caller-scoped pending discovery. A declaration contains an explicit
schema, partitioning, retention, scheduling policy and operation budgets.
Use `DirectLogClient.save` before admission and `load` for original-operation
recovery; both require the exact connection and current contract definition.
`LogOutcome` preserves the same mutation-attempt evidence as other catalog calls.
Lookup schemas belong to the output arena. No log payload or SQL operation is
implied by creating a declaration.

`Catalog.callStream(output, action)` exposes `DirectStreamClient.Action` for
one-partition append, original-operation inspection, finite retained reads,
consumer assignment, offset settlement and read release. Append payloads use
the shared `LogBatch` encoder. Save exact mutation bytes with
`DirectStreamClient.save` before dispatch; `load` checks the required definition,
connection and payload commitment. No request invents a retry identity.
`StreamOutcome` preserves mutation-attempt uncertainty. Pages carry the pinned
schema and decoded rows owned by output; their coverage distinguishes an empty
page from completion. Releasing a read or closing the client does not settle
consumer progress. See the [Stream contract](../../../contracts/DIRECT_TABLE_V1.md#stream-payload-and-consumer-progress)
for current service budgets and grants.

`Catalog.callQueue(output, action)` exposes `DirectQueueClient.Action` for enqueue,
claim, bounded claim waits, original-operation inspection, bounded original-claim pages and explicit
ACK/NACK/extension settlement. `DirectQueueClient.save` preserves exact mutation
bytes before dispatch; `load` verifies the mandatory definition, connection and
payload commitment. `QueueOutcome` preserves the original mutation identity and
unknown-outcome evidence. Decoded rows retain their original leases and payloads;
the separately observed status is not authority to execute or settle them.
Pages use selection ordinals and explicit completion, including empty terminal
pages. Closing the client or output arena performs no ACK, NACK or renewal.
Wait timeout accepts no empty claim. Save the underlying claim before waiting;
its original identity survives cancellation, lost replies and changed wait duration.
The [Queue action contract](../../../contracts/DIRECT_TABLE_V1.md#queue-payloads-claims-and-settlements)
owns current limits, grants and remaining DLQ/transaction limitations.

Pass a separate output arena. Successful results and their strings/collections
belong to that arena and remain valid across subsequent calls and client close.
Reset it only after all associated borrows end. Retained local intents use the
client's allocator independently; a failed replacement preserves prior work.
The existing Catalog request, intent, page and work budgets still apply. The
embedding allocator/I/O owner supplies aggregate memory and concurrency limits;
this extraction does not establish zero steady-state allocation.

An `Outcome` contains a result or a failure with the original error, native
rejection and diagnostic. Its per-call `attempt` records whether a mutation
route was entered. `mutationAttempted()` remains available after success: if an
adapter then fails to copy or deliver the result, it must preserve uncertainty
instead of claiming rejection. A failing credential read before dispatch is
separate from a possibly accepted mutation. Evidence from an earlier call is
never reused to classify a later one.

Persist exact saved intent bytes before staging and the returned original
reference before admission when recovery after caller loss is required. This
client retries nothing, creates no hidden store, and starts no recovery loop.
`deinit` only releases local ownership; it neither cancels accepted operations
nor releases explicitly acquired durable pins. See
[caller semantics](../../../docs/handbook/reference/callers.md) and
[direct catalog recovery](../transit-catalog/docs/direct-catalog.md).

## Checks

In the pinned development shell, run `zig build test` from this package.
Allocation-failure tests cover constructor cleanup and retained local work;
ownership checks cover input release, output survival, conflicting saved scope,
overlap and fresh attempt diagnostics. `zig build check` separately compiles
through this package's manifest and Station exclusion gate.

The root `test-direct-catalog-abi` schedule exercises the existing ABI/port
consumer of this implementation against the real direct owner, including lost
replies and saved recovery. Package checks alone do not establish installed
language coverage or physical durability.

The root `test-direct-table-service -- tables` schedule also uses this package's
typed Stream/Queue lifecycle over signed HTTP, corrupts admission and publication
replies, and recovers saved original work after a disk-backed node restart.
