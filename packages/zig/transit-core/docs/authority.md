# Authority time and control capacity

[transit-core](../README.md)

## Deadline enforcement

The selected contract permits previously authorized work to settle within a
bounded window. There is no requirement that every physical storage
write finish before the earlier cutoff for starting work. Final settlement
closure is irreversible: it rejects late results, even if the request originally
started on time. A historical receipt can still be read under current permission;
returning that receipt is not accepting a new result.

Keep the upstream Ursula API unchanged. Transit must record the authorized work,
its finite settlement rights, and closure in the same authority ordering. A
worker's prepared proposal or claimed timestamp is not a durable settlement
grant. Closure and result acceptance race through conditional append: once
closure wins, an old prepared result cannot append or reopen the attempt.

The [implemented profile](../../../../contracts/TRANSIT_V2.md#authority-time-and-bounded-settlement)
uses trusted validation time at the expected journal tail as the authorization
boundary. Its recorded uncertainty must fit the realm's configured bound.
Persistence may finish later; an intervening closure or policy operation fences
the candidate and forces fresh validation. A result first validated after its
window is rejected even if a closure controller is delayed. Clock rollback below
the durable high-water mark fails closed. This is an explicit authorization-time
contract, not a guarantee that all physical writes stop at the UTC cutoff.

The executable proof uses controlled time. A deployment still needs a trustworthy
synchronized source and periodic maintenance; ordinary host wall-clock readings
do not establish a UTC error bound. Reject finite contracts without the required
realm opt-in and time source. Replay applies recorded time evidence.

The node's [clock integration](../../../../apps/transit-node/docs/operations.md#time-and-deadlines)
provides the supported Linux time source and states its deployment assumptions.

## Finite admission and control capacity

Genesis may explicitly set `admission_ceiling` between 2 and 65,536 journal
positions. The default is unset. Once reached, Transit rejects new admissions,
spawns, grants, activations, running-provider intents, and effect dispatches.
It can finish already admitted inline inputs, settle existing outputs/attempts,
revoke grants, retire processes, stop provider resources, and checkpoint once.
Turns cannot introduce new outputs/effects into this reserve. Reads remain
available. Repeated revocations, repeated unknown provider observations, repeated
stop intents, and further checkpoint intents cannot consume unlimited records.

This is an explicit finite allocation for the experimental realm, not a retention
deadline. It never expires a PID, cancels input, or authorizes deletion by itself.
An accepted input whose completion requires a new effect or a newly opened
state view remains pending; only
explicit termination or its original opted-in expiry can cancel it. Trim and
restart do not reopen admission. Online expansion/rearming is not implemented;
do not enable this profile expecting a self-resizing production store.

For ceiling `N`, the conservative post-ceiling bound is
`2*(N+256+128) + 128*17 + 64*6 + 16 + 16*3 + 1` accepted records: at most a permit and
turn per old/newly delivered input, finite attempt observations/closures, bounded
provider completion/stop and retirement, revocations, payload publication/
retirement/deletion, and one checkpoint.
Typed journal entries are capped at 8 KiB and checkpoints at 1 MiB.
M7 adds at most four view-release and eight resource-retirement/reclamation
records to that reserve; creation, view opening, association changes and grants
are refused after admission closes. State turns retain the ordinary turn budget
and cannot publish new outputs/effects from the reserve.
Pending preauthorized payload creation can additionally write at most sixteen
64 KiB bodies (1 MiB total); those bytes need their own reserved headroom.
Transport failures and backend housekeeping are not accepted protocol records; physical
provisioning must additionally cover their amplification and temporary files.

The [physical-capacity proof](../../../../tests/README.md#physical-capacity-profile)
records the reserved-filesystem setup, measurements, and limits. Node startup
does not provision physical headroom. The [Ursula backend](../../transit-backend-ursula/docs/storage.md#immutable-payload-deletion)
documents the implemented payload publication and deletion mapping.
