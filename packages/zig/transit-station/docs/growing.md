# Growing Station (M10 development)

This explicit Zig interface targets [Transit v3](../../../../contracts/TRANSIT_V3.md).
The [development contract](../../../../contracts/STATION_GROWING.md) records
compatibility and the behavior loop. The existing `Turn`, `GenServer`,
foreign ABIs and launchers still use Station v1.

## Behavior loop

`GrowingGenServer` shares its poll/finish state machine with `GenServer`, using
`GrowingSession` for the v3 wire operations. Initialize it with an explicit
activation and association name. Keep the host and its borrowed client at stable
addresses while a turn is ready; the view reader borrows that host until `finish`.
Concurrent calls on the same host/client are unsupported.

`poll` resolves the named association, opens a view and returns a `GrowingTurn`.
It reads only the behavior descriptor before calling application code. `step`
adds Zig handler dispatch; foreign bindings do not yet expose this profile.
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

Growing call/reply and timed-wait preprocessing use shared framework logic.
Result fragment/completion/acknowledgement frames fail with
`UnsupportedGrowingQuery`; a result must not look verified before growing result
capture is implemented. Complete Station capability remains unadvertised.

## Private turns

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
and captured query results remain legacy-only until paged query execution and
result capture are qualified. No helper promises to fit a whole growing Table
into the old Fuze snapshot.

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
default bounded cache for exchange and one resident page after restart. A proxy
enforces point reads by the handlers, corrupts a
state response and loses an accepted turn reply. The first error publishes
nothing; the second retries identical bytes without rerunning the handler. A
caller/node/provider restart fences a previously prepared turn and recovers the
unconsumed input under fresh ownership without rerunning initialization. This
proves the bounded behavior path, not production throughput, growing registries,
query results, runtime integration or foreign ABI support. The test explicitly
delivers committed outboxes through the public client; it does not qualify a
growing background courier.
