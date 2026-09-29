# Application migration ledger v1

Status: shared ledger core implemented; domain ingress and physical qualification pending.
[Application definitions](APPLICATION_V1.md) and
[reactive applications](../docs/internal/REACTIVE_APPLICATIONS.md) own the surrounding model.
This ledger belongs above Station. It neither grants execution authority nor
changes Transit's one-mutated-resource, four-mutation turn boundary.

## Scope and authority

One application data owner holds a ledger in its own KV resource. Configuration
binds its application identity and an independently provisioned administrator.
Migration permission is a current per-operator policy, separate from interface
publication permission and from native send/read grants. Every accepted control
checks both the external caller origin and current migration policy. Data-owner
handlers remain responsible for their normal application authorization.

The ledger records an active data epoch and at most one active plan. Historical
plans and step receipts are addressed by durable keys; their cardinality is not
bounded by a resident array. Read and mutation batches remain bounded. An active
plan is a deliberate write pause for the first qualified transformation, not a
lease inferred from wall time or coordinator liveness. A coordinator restart
cannot release it. Unsupported transforms reject before beginning a plan.

## Review and exact identity

A proposal binds a nonzero plan identity, expected data epoch, next epoch,
versioned transformation and complete source/target contract commitments. The
owner recomputes its canonical digest. The reviewed proposal is immutable.
Conditional plan admission checks the expected epoch and absence of another
active plan. Exact retries recover the original plan; another proposal at that
identity conflicts, and a concurrent different plan cannot replace the active
one. A native admission receipt remains separate from a committed plan receipt.

Each step has a stable plan/ordinal identity and a canonical digest of its
versioned operation and arguments. The domain owner computes the digest from
those actual arguments, never from a caller-supplied hash alone. Completed step
receipts survive coordinator/worker/node restart. Exact reapply returns the
receipt without repeating data mutations. A different digest at the same step,
a skipped ordinal, a stale cursor or a changed source contract rejects explicitly.
Accepted-but-lost replies retain the original native request and step identity.

## Bounded application transition

The shared ledger reserves two mutations for a normal step: progress and its
receipt. At most two additional domain mutations can commit with that step.
Preparation and reads do not authorize an effect. Domain changes, step receipt
and progress commit together through the ordinary private turn. Infrastructure
or allocation failure must not be recorded as a terminal caller rejection.

The first transformation is a work-item Table encoding change. Source and target
Tables have different permanent identities in the same KV resource. Beginning
the plan pauses application writes. Each backfill step copies at most two rows
using an exact retained cursor and the selected pure encoding transform. A
separate bounded verification pass checks the entire target against the source
before the ledger permits consumer activation. Neither a partial backfill nor a
returned prefix establishes completion. Reads of the old Table remain internally
consistent; old command codecs reject after cutover.

Activation conditionally advances the data epoch and settles the plan. Domain
code derives its active codec from that epoch, so no separate unfenced switch is
needed. Interface publication has its own immutable conditional head and already
uses four writes. The two owners therefore cannot claim atomic cross-resource
publication. Keep the data write pause across the reviewed interface/configuration
transition; a renderer rejects mismatched full source contracts before display.
Any temporarily unavailable binding remains explicit. Replay never allocates a
new query or dispatches an administrative operation.

## Failure, abandonment and retention

Only explicit authorized control can abandon a plan before activation. Source
rows remain unchanged; partially copied target rows are not an active schema.
Abandonment cannot reuse target identities or erase plan/step receipts. Any
physical cleanup is a separate bounded operation with its own recorded progress.
After activation, rollback requires a separately specified compatible inverse or
compensation and a new review. This profile promises no generic inverse and no
undo of external effects, permanent retirement or history reclamation.

Retention remains unlimited unless explicitly selected by an application.
Storage pressure, a missing coordinator, a timeout or an inaccessible provider is
never permission to expire work, unpause writes, discard receipts or infer that a
step did not commit. Current resource grants and permanent retirement continue to
apply to reads and replay independently of the ledger.

## Required qualification

Independent canonical fixtures precede transport wiring. Deterministic tests must
cover digest conflicts, concurrent plans, out-of-order steps, current revocation,
allocation failure, restart reconstruction and the four-write bound. The actual
generated work-item binary must additionally prove bounded copy/verification,
unknown admission replies, native/disk recovery, old/new binding separation and
explicit rollback limits through native, Compose and reference placements.
These obligations remain open until executable evidence is recorded in tests.

## Implemented ledger records

The shared Zig ledger core and its independent fixtures are implemented. There is
no network migration endpoint yet. Keys are `00 4d`, application u64 big-endian,
a one-byte tag, then two u64 big-endian identifiers. Values reuse the bounded
`AP1` version envelope with the same tag, followed by declared-order fixed
little-endian integers, one-byte enums/bools, fixed byte arrays and length-prefixed
values of at most 128 bytes. Full-width JSON counters use canonical decimal
strings. Unknown enums, trailing bytes and oversized values reject.

| Tag | Key identifiers | Record fields in order |
| --- | --- | --- |
| `C` | 0, 0 | application u64, realm u64, administrator u64, initial epoch u64, initial contract [32] |
| `P` | principal, 0 | policy revision u64, migrate bool |
| `H` | 0, 0 | epoch u64, contract [32], active plan u64 (zero means none) |
| `A` | plan, 0 | proposal, plan digest [32], principal u64, admission input u64 |
| `G` | plan, 0 | next ordinal u64, phase u8, cursor value, last committing input u64 |
| `S` | plan, ordinal | plan u64, ordinal u64, step digest [32], admission input u64, progress |

A proposal encodes plan/expected/next u64, transform u16 and source/target [32]
commitments. Plan digests are SHA-256 over
`transit.application.migration.plan.v1\0`, `AP1D`, application u64 and proposal.
Step digests use `transit.application.migration.step.v1\0`, `AP1D`, application
u64, plan digest, then plan/ordinal u64, operation u16 and argument value.
Phases are active=1, applied=2, abandoned=3. Independent Python fixtures cover
full-width IDs, canonical key/record bytes and both domain commitments.

`Migration.apply` checks current policy and exact receipts before invoking the
domain callback. It restores the caller's original turn decision on any failure,
including tentative domain writes. A normal step uses two ledger mutations;
activation uses three, leaving at most one domain mutation in that turn. This
protects the commit boundary, not the honesty of arbitrary domain computation.
The selected work-item owner must still implement and qualify its transform,
write pause and complete verification before using activation.
