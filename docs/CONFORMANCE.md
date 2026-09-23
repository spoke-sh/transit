# Protocol conformance and implementation gates

Status: adversarial review requirements, not passed checks. Documentation review
establishes owners and testable contracts; it cannot prove runtime guarantees.
`just check` validates tooling and implemented unit tests. `just test-storage`
exercises the initial conditional-append and disk-restart experiment described
in [URSULA.md](URSULA.md#implemented-authority-experiment). This is not complete
M1 conformance evidence.

## Review assessment

Implemented evidence: `just test` exercises request signatures, realm/PID grants,
key replacement, retry identity, ownership, invalid results, ordered input, and
retirement. `just test-storage` repeats competing transitions, revocation, lost
receipts, and replay across a real Ursula SIGKILL/restart, with a 100-message
backlog and a 16-record read window. The fixed reducer is trusted and compiled.
These are local single-node results, not the Kubernetes/Substrate isolation proof.

The deadline gate remains open: the adapter's conditional append cannot atomically
test a per-process wall-clock deadline. The current profile rejects finite
deadlines instead of relying on a pre-append clock sample. M1 must supply an
enforceable storage/authority boundary before accepting those contracts.

The foundations define a viable direction for a bounded M1 proof. The highest
risk gaps are the concrete commit/fencing mechanism, authenticated authority,
native-handler enforcement, and time/revocation at external dispatch. Choose
and test those mechanisms before building framework or connector behavior on
their assumed guarantees. A failed proof requires revising the owning design,
not relabeling a weaker implementation as conformant.

## Adversarial scenarios

Each row identifies the contract owner and the earliest required evidence. Use
valid/invalid traces, deterministic schedules, crash injection, and real adapter
tests as appropriate. A happy-path example alone does not satisfy a row.

| Scenario | Required evidence | Owner / milestone |
| --- | --- | --- |
| A worker claims another PID, realm, role, or image | Authenticated provenance and scoped grants reject impersonation before mutation or data disclosure | [Security](SECURITY.md), M1 |
| Permission is revoked while a message, turn, or dispatch is pending | Defined authorization boundaries, fenced policy revisions, and durable blocked/denied outcomes; prior acceptance is not erased | [Security](SECURITY.md#authorization-over-time), M1 |
| A subscriber keeps an old token; a reader follows a private blob reference | Current read authorization covers subscriptions, receipts, payloads, and derived views | [Security](SECURITY.md), M1 API surfaces; M3 transcripts |
| Two authorities and a restored old worker race to commit | At most one accepted successor per prior commit/generation; authority restart cannot reset fencing | [Transit](TRANSIT.md#ownership-and-failure), M1 |
| The append succeeds but its acknowledgement is lost | Stable operation identity recovers the same spawn, admission, commit, or dispatch decision; conflicting content is rejected | [Transit](TRANSIT.md), [Streams](STREAMS.md), M1 |
| Outbox retries reorder a sender's messages or only part of a fan-out arrives | Preserve declared per-sender/destination order, including delayed uncertain admissions; prove terminal delivery outcomes rather than inferring them from timeouts; no cross-process atomicity claim | [Streams](STREAMS.md#commit-and-delivery), M1 |
| Native code reads an ambient clock, uses a socket, forges state, or never returns | Demonstrate the selected handler-execution boundary and limits; distinguish protocol validation, deterministic re-execution, and application correctness | [Transit](TRANSIT.md#enforcement), M1 |
| A handler repeatedly fails on the head message | Bounded retries, visible blocked state or authorized ordered disposition; no silent skipping or endless supervisor replacement | [Station](STATION.md#failure-and-progress), minimal policy M1; helpers M2 |
| A required input expires during suspension or an active turn | Permanent PID expiry; late activation/commit/dispatch authorization rejected even when bytes remain | [Retention](RETENTION.md), M1 |
| Clock rollback or a controller partition delays expiry | State the time/error model and refusal behavior; recorded deadlines do not extend through stale authority | [Retention](RETENTION.md#time-and-policy-changes), M1 |
| A worker pauses after dispatch authorization, then loses ownership | Treat the attempt as possibly in flight; do not infer cancellation or safe retry from revocation | [Security](SECURITY.md#effects-and-the-limits-of-revocation), M1 synthetic executor; M3 HTTP |
| A connector is redirected to metadata/admin APIs or submits another attempt's result | Enforce destination/credential scope at each hop and authenticate result provenance | [Connectors](CONNECTORS.md), M3 |
| Data storage fills while expiry, revocation, or GC needs a durable record | Reserve and bound control/maintenance capacity; refuse admission before cleanup deadlocks | [Retention](RETENTION.md#horizons-dependencies-and-capacity), M1 |
| GC races a new reference or crashes after physical deletion | Serialize dependency admission with logical retirement; resume maintenance from durable control evidence outside deleted data | [Retention](RETENTION.md), M1 |
| Bootstrap restarts after partial creation; the application registry is absent | Recover the same realm, catalog, policy roots, and spawn identities without duplicate children or a second execution truth | [Deployment](DEPLOYMENT.md#bootstrap-and-disaster-recovery), M1 |
| A runtime create succeeds before the controller records its result | Reconcile the intended provider incarnation; duplicate sandboxes never gain duplicate commit authority | [Deployment](DEPLOYMENT.md), M1 |
| An old backup lacks a revocation, expiry, or externally completed effect | Refuse automatic live activation; fence the old deployment and reconcile external work before an explicit restore/import | [Deployment](DEPLOYMENT.md#bootstrap-and-disaster-recovery), documented boundary M1; restore proof M4 |
| A name is rebound while replies or retries are pending | Fixed destination PID and conditional cleanup; no permission inherited from a lookup or alias | [Station](STATION.md), M2 |
| A tombstone or retry receipt is collected before a late consumer returns | Explicit horizon failure/resynchronization with no resurrection or duplicate admission | [Retention](RETENTION.md), retry boundary M1; full compaction M4 |
| A new image/schema interprets retained state differently | Authorized, versioned migration with a defined failure path; old and new owners cannot commit concurrently | [Transit](TRANSIT.md#replay-and-versions), reject unsupported changes M1; migration M4 |

## Evidence and limits

For each supported runtime/storage profile, record the tested revision, topology,
failure boundary, authoritative operation point, input schedule, and expected
durable outcomes. Assertions must inspect history and denied side effects, not
just eventual output. Recovery tests must distinguish local caches, durable
checkpoints, and external systems. A trace should make competing authority or
unexpected effect execution observable.

The first slice uses a single security realm, fixed workload code, a minimal
policy authority, and synthetic effects on the Kubernetes/Substrate reference
deployment. Multiple principals, conflicting authority instances, worker loss,
and retention deadlines still need tests; a single-realm topology is not a
reason to omit those cases.

The contract does not currently promise Byzantine fault tolerance, globally
ordered messages, cross-process transactions, exactly-once remote effects,
arbitrary native-code determinism, timely scheduling before expiry, or instant
physical erasure. Add such guarantees only with an explicit scope change and
supporting proof. Milestone ordering and the remaining design gates live in
[ROADMAP.md](ROADMAP.md).
