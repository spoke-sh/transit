# Station behavior and paged state

`GenServer`, `Turn` and the language bindings use the current
[Transit v1](../../../../contracts/TRANSIT_V1.md) definition. The
[Station contract](../../../../contracts/STATION_V1.md) specifies durable layouts,
behavior dispatch and compatibility. Incompatible definitions require a hard
cutover; there is no legacy reader or alternate bounded execution profile.

## Behavior loop

`GenServer` uses the client `Session` for v1 wire operations. Initialize it with an explicit
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

`poll` resolves the named association, opens a view and returns a `Turn`.
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
`query` context; otherwise they fail with `UnsupportedQuery`. The
[query guide](queries.md) covers implemented capture, publication, receiver
verification, bounded credit and acknowledgement. Station also provides paged registry and supervision helpers and a separate
controller. See [services](services.md) for authority and retry boundaries.

## Private turns

### Explicit mutation dispatch for SDK hosts

`prepare(read_deadline_ms)` and `dispatchPending()` expose the shared
behavior machine. `prepare` performs bounded reads/private preparation, but never
submits a mutation. When `pending` is present, persist its exact signed operation
before calling `dispatchPending`. This gate includes permit and view-opening
requests, internal framework turns and handler/failure commits. Repeated prepare
calls preserve the pending bytes. `dispatchPending` makes one attempt; errors
retain the same request. A successful dispatch records an owned `confirmation`
with purpose, input position and receipt. Copy/record it before the next dispatch.
The existing `poll`/`step` interface still composes both phases for Zig callers.

`discard()` drops only an unsent private turn and rejects when a signed mutation
is pending. It neither consumes the input nor records a failure. Selecting
`failure_policy = .stop` applies that behavior to handler/preprocessing errors;
the default `.block_input` retains the existing failure-proposal policy. Read
failures poison/discard the private turn under both policies. These native Zig capabilities have corresponding C/port exports and
language adapters. The [binding guide](../../transit-station-bindings/docs/bindings.md)
defines their host ownership and dispatch rules.

### Bounded access

`Turn` uses a view-bound reader supplied by the host. `try turn.read(key)` fetches one committed value
unless a private mutation already overrides it. `put`, `delete`, `cast`, `call`
and `reply` only build a bounded private proposal. No operation publishes early.

Read failures are sticky for that proposal, even when application code catches
the error. `validate` refuses it. A host must discard private work and retry reads
or stop; it must not convert missing read evidence into a successful proposal or
a durable handler-failure marker. A transport-capable reader is not a sandbox:
deployment isolation remains necessary for untrusted native code.

`Table.create/open`, point reads/mutations and `Table.atomic` share codecs,
type checks and rollback rules. A full Table need not fit in resident memory;
use bounded pages and retained sources for iteration across handlers.

`Turn.page(after)` reads at most eight committed KV entries; private
mutations must be absent. `Table.page(turn, cursor)` decodes a bounded batch of
typed rows and stops at that Table's key boundary. Its returned `next` binds the
source ID, resource, revision, Table and schema. Passing it to another source or
Table fails with `StaleTableCursor`. Only null establishes completion; an empty
final page is possible. Keep one captured view throughout iteration. Failure or
expiry cannot silently recapture a newer version, and read failures poison the
private proposal as point reads do.

`var source = turn.committed()` borrows the same captured cut explicitly.
Its `read` and `page` both exclude private inserts, updates and deletes, including
when the source is borrowed after those changes. It supports `Table.open/get/page`
with the ordinary Table codecs and cursor basis. This lets a framework composition
check committed state while staging unrelated setup records; it never merges an
overlay into an ordered page. `Turn.page` keeps its rejection after private writes.
The source acquires no new view, retains no history and adds no permission.
Keep it within the turn's lifetime. A changed source/view binding rejects, and
point/page failures poison the original proposal. Current native read and commit
authority still apply to the captured view.

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
`Query` now composes those primitives for resumable capture. Complete
result publication and receiver verification use the separate `QueryDelivery`
helper and explicit host context described in the query guide.

Durable wait v1 records full-width timer principal identities. `Waiting` checks
cancellation, timeout and authenticated source identities. Resource interpretation
does not migrate incompatible history.

Run `just test::station`, `just test::growing-service` and the relevant binding
proofs for behavior, paging, recovery and dispatch checks. Executed schedules and
qualification limits live in the [proof ledger](../../../../tests/README.md).
