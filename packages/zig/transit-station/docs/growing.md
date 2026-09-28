# Growing Station (M10 development)

This explicit Zig interface targets [Transit v3](../../../../contracts/TRANSIT_V3.md).
The [development contract](../../../../contracts/STATION_GROWING.md) records
compatibility and the behavior loop. The existing `Turn`, `GenServer`, legacy
foreign ABIs and launchers still use Station v1. M11's explicit
[growing ABI](../../transit-station-bindings/docs/bindings.md#explicit-growing-turns) adds gated foreign turns and
bounded state/Table access separately.

## Behavior loop

`GrowingGenServer` shares its poll/finish state machine with `GenServer`, using
`GrowingSession` for the v3 wire operations. Initialize it with an explicit
activation and association name. Keep the host and its borrowed client at stable
addresses while a turn is ready; the view reader borrows that host until `finish`.
Concurrent calls on the same host/client are unsupported.

An optional `input_guard` runs after the framework descriptor check and before
frame decoding, reply/timeout preprocessing or handler dispatch. A host exposing
untrusted external inputs can record a bounded private disposition and return
`true` to consume a malformed/unauthorized frame without blocking its input queue.
Reads, writes, input progress and the disposition still share the ordinary fenced
turn. Read failures poison the proposal and guard errors follow the configured
failure policy; no exception grants permission to skip accepted work. Initialize
the behavior through trusted provisioning before exposing ingress. Hosts without
a guard retain their existing dispatch/error semantics. The serving package uses
this hook to reject spoofed reply origins and timer observations before dispatch.

`poll` resolves the named association, opens a view and returns a `GrowingTurn`.
It reads only the behavior descriptor before calling application code. `step`
adds Zig handler dispatch; the growing ABI exposes the explicit preparation and
dispatch phases for foreign hosts.
Provide a read deadline within the authority window; finite settlement and
resource deadlines bound it further. A missing/hidden association, stale owner,
revocation or expired view cannot be bypassed by reopening data in a handler.

`finish` freezes the bounded proposal. No handler is called again while that
mutation has an unresolved result; retries retain its exact signature/sequence.
An incomplete read clears the private proposal and returns the read error. The
next poll may rebuild it against the same view if that view is still usable.
There is no hidden retry or extension of a view deadline. After worker loss,
obtain fresh ownership before constructing a replacement host. Initialization
is skipped when its descriptor already committed.

A handler failure records a kernel block and returns `blocked`. Policy outside
the handler may use the node's `scoped_retry` capability with a PID administrator
identity, then acquire new ownership and create a replacement host. The old host
does not clear its own block, and retry does not skip or acknowledge the input.

Growing call/reply and timed-wait preprocessing use shared framework logic.
Result fragment/completion/acknowledgement frames require an explicit host
`query` context; otherwise they fail with `UnsupportedGrowingQuery`. The
[query guide](queries.md) covers implemented capture, publication, receiver
verification, bounded credit and acknowledgement. Complete Station capability
remains unadvertised because supervision and runtime bindings are outside this
growing slice. M15 qualifies the shared Zig `Registry` helpers with bounded point
reads and the existing name/revision encodings; see [services](services.md).

## Private turns

### Explicit mutation dispatch for SDK hosts

M11 adds `prepare(read_deadline_ms)` and `dispatchPending()` to the shared
behavior machine. `prepare` performs bounded reads/private preparation, but never
submits a mutation. When `pending` is present, persist its exact signed operation
before calling `dispatchPending`. This gate includes permit and view-opening
requests, internal framework turns and handler/failure commits. Repeated prepare
calls preserve the pending bytes. `dispatchPending` makes one attempt; errors
retain the same request. A successful dispatch records an owned `confirmation`
with purpose, input position and receipt. Copy/record it before the next dispatch.
The existing `poll`/`step` interface still composes both phases for Zig/M9 callers.

`discard()` drops only an unsent private turn and rejects when a signed mutation
is pending. It neither consumes the input nor records a failure. Selecting
`failure_policy = .stop` applies that behavior to handler/preprocessing errors;
the default `.block_input` retains the existing failure-proposal policy. Read
failures poison/discard the private turn under both policies. These are native
Zig capabilities and now have explicit growing C/port exports; public SDK
dispatch/persistence adapters remain separate implementation work.

The real growing Station recovery proof now uses the explicit phases and checks
confirmation identity; native units exercise frozen permit/open/commit requests
with no usable I/O client, plus discard/stop and caught-read failures. Existing
legacy Station service, recovery and lifetime proofs preserve `poll` behavior.

### Bounded access

`GrowingTurn` uses the same implementation of private mutation, output, call and
reply rules as `Turn`. It replaces the complete entry array with a view-bound
reader supplied by the host. `try turn.read(key)` fetches one committed value
unless a private mutation already overrides it. `put`, `delete`, `cast`, `call`
and `reply` only build a bounded private proposal. No operation publishes early.

Read failures are sticky for that proposal, even when application code catches
the error. `validate` refuses it. A host must discard private work and retry reads
or stop; it must not convert missing read evidence into a successful proposal or
a durable handler-failure marker. A transport-capable reader is not a sandbox:
deployment isolation remains necessary for untrusted native code.

`Table.create/open`, point reads/mutations and `Table.atomic` accept either turn
profile. They share codecs, type checks and rollback rules. `scan`, `snapshot`
and captured query results remain legacy-only. No helper promises to fit a whole
growing Table into the old Fuze snapshot.

`GrowingTurn.page(after)` reads at most eight committed KV entries; private
mutations must be absent. `Table.page(turn, cursor)` decodes a bounded batch of
typed rows and stops at that Table's key boundary. Its returned `next` binds the
source ID, resource, revision, Table and schema. Passing it to another source or
Table fails with `StaleTableCursor`. Only null establishes completion; an empty
final page is possible. Keep one captured view throughout iteration. Failure or
expiry cannot silently recapture a newer version, and read failures poison the
private proposal as point reads do.

These methods expose bounded iteration; existing view lifetime and turn budgets
still apply. The [query capture helper](queries.md) supplies owned Fuze progress
and retained Arrow segments across handlers. A Table cursor alone does not
preserve a native stack across a worker restart or extend its view's lifetime.

## Retained sources across handlers

`try turn.retain()` stages retention of the current committed source and returns
its future `{pid, input, index}` identity. Store that ID in the same private
proposal as the job/progress that will use it. No bytes become visible early;
the retained source excludes this turn's private writes.

`var source = try turn.openVersion(id)` opens a read-only source.
`Table.open(&source, table_id)`, `table.get(&source, key)` and
`table.page(&source, cursor)` reuse the ordinary Table decoder and bounded paging.
The cursor's `source` distinguishes a turn view from a retained version. Reopen
the same durable ID in a replacement handler to resume its saved cursor; do not
reuse the borrowed `source` pointer after the turn ends. KV callers can use
`source.read(key)` or `source.page(after)` directly.

Opening/reading automatically includes the version in the final proposal's read
dependencies, deduplicated within a four-version budget. Current grants, source
expiry or explicit release can reject the later commit. Failures poison private
work even when caught. `try turn.release(id)` stages a release, and may accompany
the final read/progress update. Repeating retain/release for the same identity
inside one proposal does not consume additional slots.

This supplies source access and dependency wiring. The application still owns
durable continuation scheduling and the interpretation of its progress records.
`GrowingQuery` now composes those primitives for resumable capture. Complete
result publication and receiver verification use the separate `QueryDelivery`
helper and explicit host context described in the query guide.

Durable wait version 2 retains full-width timer principal identities. `Waiting`
shares cancellation, timeout and authenticated-source checks across both profiles.
The legacy decoder rejects growing waits and vice versa; switching resource
interpretations is not a migration path.

Unit checks use a resource with 127 Table rows and one descriptor, verify bounded
point access, rollback across resources, caught-read failure and authenticated
wide-observer closure. This is private-turn evidence with an injected reader,
and preserve the legacy private-turn checks.

`just test::growing-service` additionally runs two real Station callers with
41 retained Table rows and completed calls through disk-backed Ursula using the
bounded 64-page test cache for exchange and one resident page after restart. A proxy
enforces point reads by the handlers, corrupts a
state response and loses an accepted turn reply. The first error publishes
nothing; the second retries identical bytes without rerunning the handler. A
caller/node/provider restart fences a previously prepared turn and recovers the
unconsumed input under fresh ownership without rerunning initialization. This
proves the bounded behavior path, not production throughput, growing registries,
runtime integration or foreign ABI support. The separate growing-query proof
qualifies result delivery. The test explicitly
delivers committed outboxes through the public client; it does not qualify a
growing background courier.

The recovered writer also scans its 41 typed rows in six bounded pages before
committing a completion count. The proxy rejects unrequested whole-resource
reads during ordinary calls and checks that scan continuations stay in the
Table's key range. Unit checks add negative/extreme keys, neighboring Tables,
stale views/schemas, private-write exclusion and mid-scan transport failure.

The writer also retains the earlier 40-row source before admitting row 41. It
commits one retained scan page and a self-continuation, then loses its caller,
node and provider. A fresh activation resumes the saved row position without
rescanning committed pages and releases the version with the final count. The
six source pages span different handler views; current state still has 41 rows.
This is an application-managed scan, not the deferred Arrow result protocol.
