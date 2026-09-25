# Growing Station (M10 development)

This explicit Zig interface targets [Transit v3](../../../../contracts/TRANSIT_V3.md).
The [development contract](../../../../contracts/STATION_GROWING.md) records
compatibility and the intended behavior loop. The existing `Turn`, `GenServer`,
foreign ABIs and launchers still use Station v1.

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
not yet a growing Station service/recovery qualification.
