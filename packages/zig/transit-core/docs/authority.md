# Authority time and control capacity

[transit-core](../README.md)

## Validation and publication

Both authority profiles authenticate and check retry identity once on the normal
`submit` path. A private preparation continuation uses that exact recovered head;
it is not a public authentication bypass or a reusable permission cache. The
publication's conditional append rejects any intervening operation, including a
revocation. Public `prepare` independently authenticates before returning its
candidate. Exact retries still check current permission before returning evidence.

Unit schedules insert a competing revocation at the storage append boundary of
`submit` itself. The proposal loses, its input/progress stays unchanged, and a
subsequent retry sees the current denial in both profiles.

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
are refused after admission closes. M8 adds at most 468 catalog-collection records (256 outputs, 128 effects,
64 processes, four resources and sixteen payloads). At N=256 the combined
bound is 4,385 records. New retention opt-ins and lifecycle activations are not
allowed in the reserve. State turns retain the ordinary turn budget
and cannot publish new outputs/effects from the reserve.
Pending preauthorized payload creation can additionally write at most sixteen
64 KiB bodies (1 MiB total); those bytes need their own reserved headroom.
Transport failures and backend housekeeping are not accepted protocol records; physical
provisioning must additionally cover their amplification and temporary files.

The [physical-capacity proof](../../../../tests/README.md#physical-capacity-profile)
records the reserved-filesystem setup, measurements, and limits. Node startup
does not provision physical headroom. The [Ursula backend](../../transit-backend-ursula/docs/storage.md#immutable-payload-deletion)
documents the implemented payload publication and deletion mapping.

## Growing profile: an explicit control reserve, not a derived one

The growing (`transit-v3`) engine's `Genesis` accepts the same shape of
opt-in: `admission_ceiling` (2 to 65,536 journal positions, unset by default)
and `control_reserve` (0 to 65,536, default 4,096). Once the ceiling is
reached, new spawns, sends, grants, resource/view/association creation, effect
dispatch and turns that would admit a new output or effect are refused.
Ownership reassignment, revocation, retry, termination, expiry, view/resource
retirement or expiry, delivery, effect observation/closure/cancellation, an
opted-in checkpoint, and a turn that only drains existing backlog without
producing a new output or effect remain admissible until the ceiling plus the
reserve is exhausted too, at which point every command is refused.

This deliberately does not reuse the legacy profile's formula. That formula is
a closed-form worst case derived from the legacy catalog's fixed array sizes —
exactly the ceilings the growing profile removes. With no fixed size to derive
from, `control_reserve` is an explicit, reviewed band instead: a deployer
states how much journal headroom wind-down work gets, the same way they state
the ceiling itself. Unlike the legacy reserve, growing's capacity check does
not additionally guard against spending that headroom on redundant, already-
satisfied revoke or checkpoint calls; each still costs one position toward the
reserve, since a principal doing that only depletes its own realm's headroom.

This closes admission accounting for the growing engine itself
([`GROWTH-11`](../../../../tests/verification/invariants.json)), proved
in-memory with real restart recovery of the same ceiling/reserve state. It
does not close CAP-01's second scenario for the growing profile: no proof yet
exercises a real physical-storage/ENOSPC condition against disk Ursula, no
service or client surface exposes remaining ceiling/reserve as a read, and
`apps/transit-node`'s JSON config accepts the new `Genesis` fields (they
deserialize like any other field, defaulting when absent) without yet
documenting or qualifying an operational profile around them.
