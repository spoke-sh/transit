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

Native Zig hosts can call `setReadResources(ids)` between inputs to select up to
three additional resource cuts. Duplicate IDs, invalid IDs and changes during a
prepared input reject. Selecting the writable resource reuses its existing cut.
Each extra view is opened through the same explicit pending-request gate; an
uncertain open retains its original signed request. All views belong to the
current PID, activation and input and join its native commit dependencies.
The host still mutates only its associated resource. A read selection creates
neither an association nor a grant: provision those through their public owners.
This selection method is currently a Zig host API.

`Turn.captured(resource)` borrows one of those registered committed cuts.
Its bounded point cache and pages exclude private writes. Failed reads poison
the whole proposal even when caught by application code. `captured.retain()`
retains exactly that cut with the turn's publication; repeated aliases share one
retained identity. `Turn.retain()` keeps its meaning for the writable resource.
Reopen retained identities through `openVersion` after a handler or activation
ends. Current scoped rights, source lifetimes and native conditional publication
remain required for every dependency. These are explicit resource cuts; the
interface does not negotiate a cross-resource transaction or grant additional
write authority.

Call `Captured.requireCurrent()` when a policy or configuration read must remain
at its captured resource revision through publication. It records a native
`current_views` condition. A changed guarded resource rejects the whole proposal;
the original input remains unconsumed. Unguarded resource views and retained
versions continue to read their frozen data when that resource advances. Native
current grants remain mandatory in both cases. An uncertain proposal must still
be reconciled by its original signed identity before preparing replacement work.

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

`writeBlock(key, bytes)` adds a complete immutable value to the separate bulk
budget; null removes its current edge. A turn admits sixteen block mutations and
128 KiB, with at most 64 KiB per block. `readBlock(key, output)` copies a verified
complete block into caller-owned memory and sees private overrides.
`prefetchBlocks(keys)` acquires at most eight keys within the same byte bound.
The committed, captured and retained adapters exclude private block writes and
bind caches to their exact source. `blockPage(after)` scans only block metadata.
None of these buffers retains permission; reads and final commit use native
authorization and lifetime checks. A failed block fetch poisons the turn.

Read failures are sticky for that proposal, even when application code catches
the error. `validate` refuses it. A host must discard private work and retry reads
or stop; it must not convert missing read evidence into a successful proposal or
a durable handler-failure marker. A transport-capable reader is not a sandbox:
deployment isolation remains necessary for untrusted native code.

`TableCreation`, `TableReader` and `TableWrite` share the general typed schema,
immutable row/index representation and exact operation identities. Creation and
mutation can require multiple committed steps; applications durably schedule
continuations and publish replies only after the terminal outcome. A full Table
need not fit in resident memory. See [Tables](tables.md) for ownership, limits
and mutation composition.

`Turn.page(after)` reads at most eight committed KV entries; private
mutations must be absent. `table.page(allocator, source, cursor, limit)` decodes
one to eight owned logical rows in internal identity order. Its returned `next`
binds the source ID, resource, revision, object and exact head. Passing it to another source or
Table fails with `StaleTableCursor`. Only null establishes completion; an empty
final page is possible. Keep one captured view throughout iteration. Failure or
expiry cannot silently recapture a newer version, and read failures poison the
private proposal as point reads do.

`var source = turn.committed()` borrows the same captured cut explicitly.
Its `read` and `page` both exclude private inserts, updates and deletes, including
when the source is borrowed after those changes. `TableReader` also uses this
committed cut when passed a turn directly. This lets a framework composition
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
`TableReader.open(allocator, &source, object)`, `table.getKey(allocator, &source, cells)`
and `table.page(allocator, &source, cursor, limit)` use the captured schema and
owned logical values. Release readers and rows/pages with `deinit`. The cursor's
`basis.cut` distinguishes a turn view from a retained version. Reopen
the same durable ID in a replacement handler to resume its saved cursor; do not
reuse the borrowed `source` pointer after the turn ends. KV callers can use
`source.read(key)` or `source.page(after)` directly.

When the host enables captured read caching, each opened retained source also
keeps at most 64 point entries, including absence, for that handler invocation.
The cache belongs to its exact retained cut and excludes private writes. A new
open starts empty; eviction fetches the entry again. Ordered pages still use the
native reader. Every point read, including a cache hit, records the retained
dependency and rejects an earlier read failure. Current application permissions
remain a separate live check; cached bytes do not preserve permission or prevent
the authority from rejecting the final proposal.

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
