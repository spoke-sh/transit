# Station v1 profile

Station v1 defines message framing for behaviors, calls, scoped framework
services, Tables and shared language APIs. The
[Station reference](../docs/reference/station.md) explains those operations and
their relationship to Transit authority.

## Messages and origins

A Station message is `STN1`, a one-byte kind, a little-endian unsigned 64-bit
correlation, and at most 243 payload bytes. Kind 1 is cast (correlation zero),
2 is call, 3 is reply, 4 is result fragment, 5 is result completion, 6 is result
acknowledgement, 7 is cancellation, 8 is timeout and 9 is a terminal negative
query result (nonzero correlation).
The [Table guide](../packages/zig/transit-station/docs/tables.md) records the
implemented result framing; the [services guide](../packages/zig/transit-station/docs/services.md)
records timeout, cancellation, registry and supervisor codecs. Unknown versions/kinds and
oversize frames are rejected. Correlation is opaque and preserves all 64 bits;
Transit identities still obey the public protocol's narrower admitted range.

A call uses its caller's consumed input position as correlation. One call per
input is supported. Reply destinations come from the input's authenticated
process origin, never an application-supplied sender field. External principals
can cast; a call expecting a process reply must originate from a process.

## Resource layout and capacity

The GenServer requires one writable associated resource. Application KV keys
cannot start with zero; framework records use that prefix. They have the same
authorization, retention and quotas as application data. This is a namespacing
rule, not a security boundary against arbitrary host code.

| Key | Value |
| --- | --- |
| `00` + `station` | UTF-8 `station.genserver.v1` |
| `00` + `w` + correlation:u64le | Durable wait record |
| `00` + `disposition` | Last closed-reply disposition `station.closed-reply.v1` |

A wait record is 34 bytes: version 1, phase byte, destination:u64le,
deadline-ms:u64le, resolution-input:u64le and observer:u64le. Zero deadline
or observer means absent. Phases are waiting=1, replied=2, timed-out=3, cancelled=4.
Timed calls require a configured observer; its authenticated firing observation
closes the wait in mailbox order. A proposed deadline is not a hard wall-clock
cutoff and cannot extend a process/resource lifetime.

Resources and their keys use paged durable collections. Values are at most
256 bytes; each turn admits four distinct-key mutations, four captured views
and four outputs. Framework state shares these operation budgets. A failed
capacity check publishes nothing and does not evict completed calls. Initialization,
waiting records and application writes must fit in the same atomic proposal.
Each handler view expires within the authority's allowed window. Retained rows,
waits, resources and processes have no fixed resident-array cardinality limit;
explicit deployment quotas and storage capacity still apply.

## Turn and recovery boundary

The loop resolves a required association, obtains an authority-validated view,
checks its PID/principal/generation/input/revision, and reads bounded keys/pages.
Private writes are readable within the same handler. One state commit consumes
the input and publishes all accepted mutations, outputs and effect intent.
The default `block_input` failure policy publishes only the kernel failure marker;
`stop` discards unsent private work without consuming the input. Read failures
poison the entire proposal even when a handler catches them. No partial handler
output is observable. Required resource expiry retains its kernel lifecycle meaning.

Same-host retries preserve the exact signed proposal. A fresh host must first
obtain fresh ownership and read committed progress; it may then execute the
uncommitted input. Reply closure is in mailbox order. A duplicate reply cannot
reopen a completed wait or rerun its application callback. Signature grants,
resource permission and process ownership remain separate authority checks.

`prepare` performs reads and private preparation. Before `dispatchPending`, the
host can persist exact signed permit, view-opening or commit bytes. Repeated
preparation preserves pending identity. Dispatch attempts once, retains uncertain
requests and reports an owned receipt confirmation on success. `poll` and `step`
compose these phases for Zig callers. Discarding is permitted only for unsent
private work; a pending signed mutation must be reconciled.

## Paged and retained state

The native Zig host's `GenServer.setReadResources` selects at most three
additional read resources before an input starts. Its ordinary pending control
requests open their native views before handler dispatch. The associated
writable resource plus those views must fit the four-view turn bound. A repeated
writable resource uses its existing view; other duplicate selections reject.
Selections cannot change while an input or signed request is pending. Extra
views do not extend mutation ownership, scoped grants or associations.

`Turn.addView` accepts only an exact host-opened view for the current PID,
principal, generation, input and process revision. It refuses a different cut
for an already registered resource. `Turn.captured(resource)` provides bounded
read-only access to a registered cut; read failures poison the entire proposal.
`Turn.retainView`/`Captured.retain` stage only registered cuts, deduplicating the
same view into one retained identity. Their visibility, current authorization
and recovery follow the native retained-version contract below. Handler-failure
proposals retain the complete registered view dependency set.

`Captured.requireCurrent()` also registers its view in the native turn's
`current_views` guard set. This condition requires that resource revision to stay
unchanged through publication; read-only snapshot registration alone does not.
Handler-failure proposals preserve requested guards. See the
[state publication contract](STATE_V1.md#read-bases-and-atomic-turns) for rejection
and historical receipt semantics.

`Turn.page` and `Table.page` return at most eight entries/rows. A continuation binds
the turn view or retained version, resource, revision, Table and schema. Only a
null continuation establishes the end; an empty page can still have a continuation.
Iteration excludes private writes and cannot silently open a newer source cut.

`Turn.committed()` returns an explicit read-only borrow of the captured turn view.
Its point reads and pages exclude all private mutations. It neither acquires a
new view nor stages retention; it stays bound to the original view and turn
lifetime. Read failures poison that original turn. Ordinary `Turn.page` continues
to reject after private mutations. The explicit source allows committed-state
checks beside unrelated private framework setup without changing the native
read, grant, fencing or commit dependency boundary. No wire or ABI layout changes.

`Turn.retain` stages a durable `{pid,input,index}` source identity in the same
proposal as the job using it. `openVersion` supplies a read-only KV/Table source;
`release` stages terminal release. Current grants and lifetime rules remain live,
and reads register commit dependencies. The [retained-version contract](READ_VERSIONS_V1.md)
owns exact validation and release semantics. Native readers borrow the current
turn; applications persist identities and progress, never native pointers.

The [Table capture contract](STATION_QUERY_V1.md) defines bounded capture and
verified result delivery through an explicit host `QueryDelivery.Context`.
The [query contract](UNIFIED_QUERY_V1.md) defines general KV/Table/Document
requests and immutable result publications. [Publication](STATION_PUBLICATION_V1.md)
provides larger immutable records without changing turn budgets.

Registry and supervisor records use bounded point reads over the same resource
model. Name rebinding does not redirect recorded destinations. Supervision uses
recorded observations, independent current grants and native fencing; a provider
or host observation alone cannot grant execution rights. The
[services guide](../packages/zig/transit-station/docs/services.md) owns their codecs.
