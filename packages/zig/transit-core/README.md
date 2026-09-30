# transit-core

Reusable Transit authority implementation, exported as `transit_core` and hosted
by [transit-node](../../../apps/transit-node/README.md). Application callers use
[transit-client](../transit-client/README.md); they do not link this package.

Its only package dependency is [transit-protocol](../transit-protocol/README.md).
It does not depend on Station, Ursula, Kubernetes, or a deployment provider.
[The module root](src/root.zig) exposes protocol types, the state machine, and
`Engine(Store)`. The executable supplies storage and trusted time. Deterministic
transitions stay separate from I/O, clock sampling, and external effects.

## Guides

- [Authority time and control capacity](docs/authority.md): deadline linearization, finite admission, and reserved progress.
- [State v1](../../../contracts/STATE_V1.md): exact resource, read, and commit contract.
- [Immutable pages](docs/pages.md): M10 ordered index primitive, staging boundary and outstanding integration obligations.
- [Growing authority](docs/growing.md): development v3 root publication, compatibility and unimplemented transitions.

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
The [Transit design](../../../docs/reference/processes.md) describes the broader invariants.

## Source map and current limits

| Source | Responsibility |
| --- | --- |
| [root.zig](src/root.zig) | `State`, protocol transitions, `Engine(Store)`, candidate validation, conditional commit and replay |
| [lifecycle.zig](src/lifecycle.zig) | Initialization barrier, scoped retry and bounded suspension |
| [collection.zig](src/collection.zig) | Opted-in working slot reclamation with non-reusable identities |
| [resources.zig](src/resources.zig) | KV catalog, associations, grants, captured views, dependency retirement and receipt rights |
| [inspection.zig](src/inspection.zig), [resource_read.zig](src/resource_read.zig) | Current-authorized bounded read projections and final tail checks |
| [Time.zig](src/Time.zig) | Trusted sample/error-bound semantics; the host supplies the clock |
| [parse_object.zig](src/parse_object.zig) | Strict allocated parsing for large checkpoint fields |

`Engine` borrows its store and optional clock. Prepared candidates contain a
complete private state copy; only a successful conditional append publishes it.
An embedding host must resolve uncertain writes through history and serialize
its own engine access. The node supplies transport deadlines; the deterministic
state machine does not run a scheduler, delivery worker, timer or handler.

The bounded catalog retains retired PIDs, completed effects and resolved outputs
by default. [Explicit catalog retention](../../../contracts/CATALOG_V1.md) can
release eligible working slots while preserving non-reusable identities, including
reclaimed resources. Checkpoint/trim alone does not enable collection. Pending
work, live dependencies and uncertain effects remain pinned; finite concurrent
catalogs and the 16-principal bound still constrain Station topology.

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
four working resources (lifetime allocations without explicit collection), 32 live keys each, four finite views, and four mutations
per turn. Current data and view copies are bounded materializations recoverable
from the journal/checkpoint. The [proof guide](../../../tests/README.md#m7-state-resources)
records serialized/layout limits, stack findings and disk-recovery evidence.

These are compiled total-capacity constraints, not configurable cache sizes.
[M10](../../../docs/roadmap/M10.md) selects paged growing state and bounded
working memory before public SDKs. Its future profile must preserve this
package's authority and recovery guarantees; raising the arrays alone is not
the target design.

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

[M8 lifecycle controls](../../../contracts/LIFECYCLE_V1.md) extend the generic
protocol without a behavior dispatcher. Legacy `spawn` is immediately ready;
managed creation enforces declared dependencies before initialization completes.
