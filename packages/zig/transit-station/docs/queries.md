# Table query capture and delivery

The Zig `Query` API captures incremental Fuze results across ordinary paged
turns. `QueryDelivery` publishes segments, validates receiver completion and
retains acknowledgements through the same turn boundary. Hosts supply an explicit
query context. The [binding ABI](../../transit-station-bindings/docs/bindings.md#explicit-growing-turns)
owns this context when query results are enabled. The
[v1 contract](../../../../contracts/STATION_QUERY_V1.md) specifies capture,
delivery and credit. The public finite KV/Table/Document client composes its
own source and upload protocol in [transit-query](../../transit-query/README.md).

Set a revisioned peer/Table policy with `Query.setPolicy`. A handler for
an authenticated call invokes `start(turn, table, plan)` after its behavior
has already initialized. Start consumes all four mutations: job, owned plan,
owned engine progress and peer/correlation index. It retains the committed source
and emits a self-continuation. No source or result is an implicit lifetime owner;
normal process/resource/grant rules still apply.

Dispatch the recorded `GQC1` cast payload by decoding `Query.Continuation`
and calling `advance(turn, continuation, workspace, cancellation)`. It handles one
bounded step, stages its next continuation, and returns `progress`, `captured`,
`closed` or `duplicate`. The application supplies a per-step workspace; it must
not preserve a native stack or iterator across inputs. `plan` is a `fuze.Unified.Plan`; all projections are explicit. The framework verifies
self-origin, source identity, persisted plan/progress, current policy and the
candidate segment's identity before adding staged fragments.

The plan uses canonical `FZP1` bytes and must fit one 256-byte value at start.
The source basis and 175-byte `FZS1` progress use the current query definition;
the Table cursor is stored separately in the job. Each step uses a 4 MiB workspace
and an 8192-byte nested Arrow segment buffer independently of total result size.
At most three 221-byte fragments are staged in a turn. A separate seal verifies
those bytes and atomically advances the source and aggregate progress with the
segment manifest and result chain. Until then, progress still names the previous
sealed source page. A restart recomputes only the current unsealed step from the
retained version, verifying it against staging metadata. Global limits and
aggregates come from `transit_fuze.Unified.Stream`; they do not reset on a source page.

After `captured`, `captured(turn, result_id)` returns owned job/progress metadata.
`capturedSegment(turn, result_id, ordinal, buffer)` reads one sealed segment and
checks its byte digest. The returned bytes borrow the buffer. It rejects partial
jobs, missing fragments and altered bytes. It does not return the whole result
as one allocation or claim separate IPC streams can be concatenated. The source
version is released with the final seal; captured data remains ordinary retained
state. End-to-end publication must still validate the complete ordered chain.

Native captured turns prefetch fragment keys in groups of at most eight while
assembling or verifying a segment. Each group uses the same captured view and
current read authority; private writes still take precedence. The bounded turn
cache is reused only within that turn. Missing fragments, wrong lengths and
digest mismatches still reject the segment. Read-only completion adapters retain
their ordinary point-read interface.

## Publication and receipt

Configure both hosts with `server.query = .{ .workspace = workspace,
.cancellation = &cancellation }`, keeping the borrowed workspace and flag alive
through each poll/finish operation. Without that opt-in, result frames fail with
`UnsupportedQuery`. The host does not allocate an unbounded result buffer
or advertise the complete Station service family.

After capture, call `QueryDelivery.begin(turn, result_id)` in a fresh turn. It
records a self-continuation; subsequent `GenServer` polls dispatch
publication, incoming result fragments, completion and acknowledgement through
`QueryDelivery`. Standalone private-turn runners can call `dispatch` explicitly.
The sender uses retained sealed segments after the source is released. Each
receiver independently checks Arrow schema/rows, segment bytes, ordered digests
and the complete manifest before closing its durable wait and acknowledging.
Receiver-issued credit permits at most two uncredited segments. Only committed
segment seals grant new credit; a stalled receiver backpressures the sender.

`Query.completed(reader, correlation)` reads the retained complete
manifest. `completedSegment(reader, correlation, ordinal, buffer)` returns one
verified segment using a caller-owned bounded buffer. Missing or incomplete
evidence fails explicitly. Duplicate delivery cannot reopen a closed wait;
acknowledgement retains both peers' records under default unlimited retention.
Cancellation of a local poll while a turn is uncertain retains its signed
proposal for reconciliation. No cancellation flag can undo a committed turn.

The read-only completion helpers also accept a public-client reader implementing
`read(key)`, `waiting(correlation)` and `delivery.pid`. Every read must preserve an
exact resource cut and check current rights; the adapter must also enforce the
source's current query policy. [transit-query](../../transit-query/README.md)
provides the general finite query client and result-publication interface.

Foreign handles enable these capture/delivery actions with `query_results: true`.
The [native query host](../../../../apps/transit-query-host/README.md) runs the
public finite KV/Table/Document behaviors through `transit-query`, with its own
bundle and result-publication contract.

Read failures poison the private turn; catching one cannot authorize publishing
partial work. `close(turn, result_id, .cancelled)` is an explicit owner decision
in a fresh authorized turn **before** attempting source reads. It records a
terminal outcome, releases an unfinished source and sends a terminal reply.
Current job-resource access remains required. Because jobs and source Tables
share the resource in this initial slice, losing that resource's read grant also
blocks this helper; it is not an administrative bypass. Process expiry may prevent
any final reply. Policy changes cause `advance` to close as denied before source
access. Neither closure nor future acknowledgement implicitly deletes fragments.

In-memory private-turn checks cover 70 retained rows, interruptions before each
proposal, changed staging, duplicate/future/forged continuations, policy revocation,
sticky source failure, explicit close, and missing/corrupted captured fragments.
They use an injected reader and do not establish real authority or disk recovery.
`just test::query` owns the real caller/node/provider proof and independent
Arrow decoding; its evidence is recorded in the [test guide](../../../../tests/README.md).
