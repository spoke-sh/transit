# transit-core

Reusable Transit authority implementation, exported as `transit_core` and hosted
by [transit-node](../../../apps/transit-node/README.md). Application callers use
[transit-client](../transit-client/README.md); they do not link this package.

Its only package dependency is [transit-protocol](../transit-protocol/README.md).
It does not depend on Station, Ursula, Kubernetes, or a deployment provider.
[The module root](src/root.zig) exposes protocol types, the state machine, and
`Engine(Store)`. The executable supplies storage and trusted time. Deterministic
transitions stay separate from I/O, clock sampling, and external effects.

## Authority and recovery

The engine validates signatures and current grants, principal sequences,
PID lifecycle, activation generations, input order, state revisions, and
output/effect permissions. Accepted state is opaque application data; the engine
cannot prove the caller computed it correctly. A single conditional append orders
the validated transition. Replay restores recorded state and outcomes without
calling application logic or dispatching effects.

M1 serializes one realm through one journal, with bounded catalogs and replay
windows. This is not a sharded or production capacity design. Exact types, limits,
and rejection rules live in the [v2 protocol profile](../../../contracts/TRANSIT_V2.md).
The [Transit design](../../../docs/TRANSIT.md) describes the broader invariants.

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

The [implemented profile](../../../contracts/TRANSIT_V2.md#authority-time-and-bounded-settlement)
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

The node's [clock integration](../../../apps/transit-node/README.md#time-and-deadlines)
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
An accepted input whose completion requires a new effect remains pending; only
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

The [physical-capacity proof](../../../tests/README.md#physical-capacity-profile)
records the reserved-filesystem setup, measurements, and limits. Node startup
does not provision physical headroom. The [Ursula backend](../transit-backend-ursula/README.md#immutable-payload-deletion)
documents the implemented payload publication and deletion mapping.

## Build and verification

Use the repository's pinned `nix develop` shell. From the repository root:

```sh
(cd packages/zig/transit-core && zig build test)
just test::packages
```

See the [test guide](../../../tests/README.md) for integration evidence and limits.

`just test::unit` covers legal and rejected transitions. `just test::storage`
proves conditional authority, uncertain writes, bounded replay, and retained
control evidence through actual disk WAL interruption.

## Inspection projections

`inspection.read` builds bounded public pages from validated state/history and
checks the final authority tail before disclosure. It filters every PID and both
endpoints of outbox relationships; no raw administrative records escape. The
[inspection contract](../../../contracts/INSPECTION_V1.md) owns wire guarantees.

Same-PID workload changes use the guarded `runtime_upgrade` transition in the
[v2 contract](../../../contracts/TRANSIT_V2.md#runtime-bindings-and-activation).
It preserves opaque state and pending work while recording a stopped provider
switch; it does not perform state migration. Unit tests cover stale owners,
permissions, incompatible declarations, lost acknowledgements and expiry; the
disk runtime proof checkpoints and trims with a switch outstanding.

## State resources (M7)

[`resources.zig`](src/resources.zig) implements the deterministic catalog,
independent resource grants, named associations, bounded revision views, and
atomic KV mutations through the existing conditional turn append. One resource
mutation batch and input progress/outputs share that decision; prepared copies
are private. Resource data remains opaque, and core executes no application code.

The [v1 state contract](../../../contracts/STATE_V1.md) owns the exact bounds:
four resources, 32 live keys each, four finite views, and four mutations per turn.
Current data and view copies are bounded materializations recoverable from the
journal/checkpoint. The initial eight-resource/64-key candidate exhausted the
default Debug stack in an existing checkpoint proof; the selected bounds pass
the complete disk-recovery suite without raising process stack limits.

The optional catalog is omitted for inline-only checkpoint encoding. Resource
grants never replace process execution authority; replacing/revoking a principal
clears its resource grants, while same-PID activation credential rotation keeps
the workload's grants. Required-resource expiry fences execution before delayed
maintenance and records permanent dependent-PID retirement. Compaction preserves
current values independently of their write age. The public service/client,
Board and three launcher profiles are qualified; see the
[proof guide](../../../tests/README.md#m7-state-resources).

State-turn receipt dependencies are retained in the catalog after read-view
release. Returning a known receipt rechecks current resource inspect/read/write
grants; a revoked writer cannot use a lost-response retry to bypass revocation.
Unlimited historical retries resolve their bounded view references from retained
history. This check discloses the original decision and never republishes a turn.
Large checkpoint objects use `Checkpoint.Heap` and an owned parsed result at the
storage boundary. The parser preserves strict field and fixed-array validation
without passing the full catalog through nested by-value parse frames.
