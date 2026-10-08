# Application migration ledger v1

The migration ledger records reviewed plans, bounded steps and activation in the
application's state resource. Application commands provide its ingress.
[Application definitions](APPLICATION_V1.md) and
[reactive applications](../docs/reference/applications.md) own the surrounding model.
This ledger belongs above Station. It neither grants execution authority nor
changes Transit's one-mutated-resource, four-mutation turn boundary.

## Scope and authority

One application data owner holds a ledger in its own KV resource. Configuration
binds its application identity and an independently provisioned administrator.
Migration permission is a current per-operator policy, separate from interface
publication permission and from native send/read grants. Every external control
checks both its caller origin and current migration policy. `continueStage` admits
only this native owner's self-message for an already admitted exact step and
rechecks the original operator's current policy; it never rewrites the origin.
Data-owner handlers remain responsible for their normal application authorization.

The ledger records an active data epoch and at most one active plan. Historical
plans and step receipts are addressed by durable keys; their cardinality is not
bounded by a resident array. Read and mutation batches remain bounded. An active
plan is a deliberate write pause for the work-item transformation, not a
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
For domain work requiring multiple turns, `Migration.stage` first commits a
pending record containing the original step, digest and admission input without
calling the transform. Later exact continuations recheck current operator policy,
plan ownership, active epoch and ordinal. A building callback can use all four
mutations for private staging and leaves ledger progress unchanged. Its terminal
callback reserves the same two ledger mutations (three for activation), committing
the completed data head and ledger outcome together. A pending record is neither
a completed receipt nor permission to activate a partial target.

Preparation and reads do not authorize an effect. Domain changes, step receipt
and progress commit together through the ordinary private turn. Infrastructure
or allocation failure must not be recorded as a terminal caller rejection.

The first transformation is a work-item Table encoding change. Source and target
Tables have different permanent identities in the same KV resource. Beginning
the plan pauses application writes. Each backfill step stages one transformed row
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

Rejected inputs retain evidence separately from committed plan/step receipts.
The shared owner captures the policy, original plan/step commitments, next ordinal,
phase, active plan or expected/observed epoch and contracts at the failing check.
It performs no extra metadata reads to reconstruct that explanation. An absent
policy is explicit; abandonment of an applied plan retains its observed progress
without inferring a current head. Counter overflow is a specific invalid policy,
invalid proposal or exhausted step-ordinal rejection. Exhaustion does not invoke
the domain transform.

The work-item command handler rolls back the attempted decision before recording
a rejection and its companion witness in two mutations. Its domain witnesses
retain cursor commitments and lengths, copy/verification phase and counts,
submitted state/key, target Table or data epoch/contract. Invalid values already
stored in the source use `WorkItemSourceInvalid` and remain unresolved, as do
read, allocation and transform failures; they are not invalid caller values.
Later progress, policy restoration and activation do not rewrite a historical
rejection. Current resource read rights govern disclosure.

The diagnostic outcome is `input_rejected`, with the exact input and original
plan/ordinal when available. It does not settle the whole migration, release the
write pause, erase earlier steps or authorize a fresh retry. Retained phase and
step receipts establish those separate outcomes. The application operator emits
the complete structured diagnostic with `committed: false`, preserving native
admission separately from domain acceptance.

`MigrationDiagnostic.progress` projects an authorized retained plan/progress pair.
Its stable codes are `migration.active`, `migration.applied` and
`migration.abandoned`, with outcomes `pending`, `applied` and `cancelled`.
The last outcome describes abandonment of this plan, not reversal of earlier
steps. Evidence is `domain_status`; inspection targets the exact plan and resource.
Facts retain the original owner, admission/latest input, proposal commitment,
reviewed source/target epochs and contracts, next step ordinal and phase.
The opaque application cursor is not copied into the diagnostic. Generic migration
cannot infer transform arguments or authorize a successor from a status read.

## Verification

Independent canonical fixtures precede transport wiring. Deterministic tests must
cover digest conflicts, concurrent plans, out-of-order steps, current revocation,
allocation failure, restart reconstruction and the four-write bound. The actual
generated work-item binary must additionally prove bounded copy/verification,
unknown admission replies, native/disk recovery, old/new binding separation and
explicit rollback limits through native, Compose and reference placements.
The [test guide](../tests/README.md) records the work-item recovery, migration,
browser and deployment results.

## Implemented ledger records

The shared Zig ledger is called by the application's authenticated command handler;
it exposes no standalone network endpoint. Keys are `00 4d`, application u64 big-endian,
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
| `S` | plan, ordinal | `AP1S`: plan u64, ordinal u64, step digest [32], admission input u64, progress |
| `S` | plan, ordinal | `AP1T`: pending step (plan/ordinal u64, operation u16, argument value), step digest [32], original admission input u64 |

A proposal encodes plan/expected/next u64, transform u16 and source/target [32]
commitments. Plan digests are SHA-256 over
`transit.application.migration.plan.v1\0`, `AP1D`, application u64 and proposal.
Step digests use `transit.application.migration.step.v1\0`, `AP1D`, application
u64, plan digest, then plan/ordinal u64, operation u16 and argument value.
The pending and completed forms share one key. Completion replaces `AP1T` with
`AP1S`, so no extra deletion mutation is needed. The pending form occupies at most
191 bytes and is current-format staging evidence, not a compatibility decoder.
Its frozen arguments must match the canonical step digest. Receipt `input`
retains the first step admission; `progress.input` records the completing native
input. Abandonment retains pending evidence without invoking further domain work;
cleanup of unpublished domain staging is the domain owner's separate operation.

Phases are active=1, applied=2, abandoned=3. Independent Python fixtures cover
full-width IDs, canonical key/record bytes and both domain commitments.

`Migration.apply` checks current policy and exact receipts before invoking the
domain callback. It restores the caller's original turn decision on any failure,
including tentative domain writes. A normal step uses two ledger mutations;
activation uses three, leaving at most one domain mutation in that turn.
`Migration.stage` uses the same checks and rollback boundary, returning no receipt
until the transform completes. `pending` exposes the original admitted step for
exact recovery; `receipt` returns no completed result for it. A current authorized
one-turn `apply` may also finish that same frozen step if its domain callback can
complete atomically. Domain owners must keep staging and publication semantics
consistent across their commands. This protects the commit boundary, not the
honesty of arbitrary domain computation.
The work-item owner enforces its write pause and verifies the complete target
before activation. Other application owners must enforce the same boundary for
their own transforms.

### Rejected input records

The shared bounded rejection record contains, in order, cause (a length-prefixed
Value of 1–96 bytes), native input:u64, plan:u64, ordinal:u64, operation:u16 and
the complete original Station frame commitment:32 bytes. The commitment is
SHA-256 over `transit.application.migration.input.v1\0` and the frame. Zero plan,
ordinal or operation indicates an inapplicable identity where the command does
not name one; a submitted step operation zero remains available as invalid input.
With the `AP1e` header, the primary record occupies at most 159 bytes.

The shared witness is a numbered union: none=0; policy=1 (principal, expected and
actual policy revisions, presence and migration permission); head=2 (expected and
actual epoch, source/observed/target contract commitments, active plan); plan=3
(original/submitted commitments, owner and caller); step=4 (original/submitted
commitments); progress=5 (next/supplied ordinals, phase, active plan and whether
that active identity was observed); owner=6 (plan owner and caller). Its largest
`AP1f` record occupies 125 bytes. The work-item witness wraps this union and adds
the application variants described in its [migration guide](../examples/work-items/docs/migration.md).
Both records must exist at the same authorized resource view; missing companions,
old bare error strings and mismatched input identities reject. Independent fixtures
pin full-width record layouts and the original frame commitment.
