# Growing query capture

The explicit Zig `GrowingQuery` API captures incremental Fuze results across
ordinary growing turns. It is an M10 development slice. Publication, consumer
reassembly and acknowledgement are still being implemented; `GrowingGenServer`
continues to reject unsupported result frames. Legacy `Query` and foreign ABI
result limits remain unchanged. The [v2 design and layout](../../../../contracts/STATION_QUERY_V2.md)
separate implemented capture from the remaining delivery contract.

Set a revisioned peer/Table policy with `GrowingQuery.setPolicy`. A handler for
an authenticated call invokes `start(turn, table, stream_plan)` after its behavior
has already initialized. Start consumes all four mutations: job, owned plan,
owned engine progress and peer/correlation index. It retains the committed source
and emits a self-continuation. No source or result is an implicit lifetime owner;
normal process/resource/grant rules still apply.

Dispatch the recorded `GQC2` cast payload by decoding `GrowingQuery.Continuation`
and calling `advance(turn, continuation, workspace, cancellation)`. It handles one
bounded step, stages its next continuation, and returns `progress`, `captured`,
`closed` or `duplicate`. The application supplies a per-step workspace; it must
not preserve a native stack or iterator across inputs. The framework verifies
self-origin, source identity, persisted plan/progress, current policy and the
candidate segment's identity before adding staged fragments.

Each step may use an 8192-byte segment buffer independently of total result size.
At most three 221-byte fragments are staged in a turn. A separate seal verifies
those bytes and atomically advances the source and aggregate progress with the
segment manifest and result chain. Until then, progress still names the previous
sealed source page. A restart recomputes only the current unsealed step from the
retained version, verifying it against staging metadata. Global limits and
aggregates come from `transit_fuze.Stream`; they do not reset on a source page.

After `captured`, `captured(turn, result_id)` returns owned job/progress metadata.
`capturedSegment(turn, result_id, ordinal, buffer)` reads one sealed segment and
checks its byte digest. The returned bytes borrow the buffer. It rejects partial
jobs, missing fragments and altered bytes. It does not return the whole result
as one allocation or claim separate IPC streams can be concatenated. The source
version is released with the final seal; captured data remains ordinary retained
state. End-to-end publication must still validate the complete ordered chain.

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
`just test::growing-query` owns the real caller/node/provider proof and independent
Arrow decoding; its evidence is recorded in the [test guide](../../../../tests/README.md).
