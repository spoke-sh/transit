# Protocol conformance and implementation gates

Status: adversarial requirements with executable evidence for the bounded M1
profile. The [roadmap](ROADMAP.md) maps the completion criteria to commands and
limits. `just check` alone validates tooling/unit tests; storage, service,
physical-capacity and Kubernetes/Substrate proofs remain separate commands.
Results apply to their pinned topology, reviewed workload and stated failure
boundary, not every target requirement in the documents below.

## Review assessment

`just test-service` exercises actual signed HTTP ingress, PID-scoped reads,
key rotation/revocation, slow-body deadlines, and paused/replacement workers
against disk-backed Ursula. Authority and storage restart preserve state and
revocations. This loopback proof does not establish deployment network isolation;
see the [service profile](../contracts/SERVICE_V2.md).

`just reference-test` runs the fixed counter via the pinned Substrate gVisor
runtime on an owned Kind cluster. A controller crash after Actor creation is
reconciled without a duplicate resource; killing the real worker preserves the
PID/Actor and rotates worker identity and ownership. Ursula and authority pod
restarts preserve state, and separate maintenance expires an opted-in process.
The sandbox probe first reaches Transit, then verifies denied raw Ursula
read/write/admin access, direct IP access, CONNECT tunnelling, and Substrate and
Kubernetes APIs. Host spoofing reaches only Transit's fixed NotFound handler.
Known credential/control mounts are absent or inaccessible. These claims cover
the configured fixed images, private trusted cluster network and pinned runtime;
they do not establish arbitrary native-handler determinism or protection against
privileged administrators. Public ingress TLS and broader runtime support remain
outside this reference slice.

Caller-reported counter overflow records a blocked head input and fences its
owner. Unit tests reject failure reports that change state or emit outputs;
signed-service tests preserve pending input across restart and permit explicit
termination. The counter worker also reports malformed application bytes as a
blocked failure. Transit does not verify the caller's arithmetic or failure claim.
Runtime reconciliation uses that durable failure to stop replacement; its cluster test also checks a
stable generation after shutdown. This bounds retries of the fixed reviewed
handler; arbitrary plugin execution and general Station restart policies remain
outside this profile.

The [bounded capacity profile](RETENTION.md#m1-bounded-capacity-profile) has a
real ext4/ENOSPC proof in `just test-capacity`. Closed admissions survive restart;
accepted input is preserved, and releasing only a preallocated reserve enables
revocation, opted-in expiry, unknown closure, backlog completion and checkpoint/
trim. The recorded bounds and measured amplification apply to the specified
single-node fixture, not arbitrary disk writers, topologies or unlimited faults.

Immutable standalone payload tests add whole-stream deletion through the pinned
client. Owner/PID and current grants fence retirement; publication, explicit
deletion opt-in and permanent owner retirement are prerequisites. Disk restart
after DELETE but before outcome recording recovers from a tombstone in the
separate control checkpoint. Background service maintenance completes deletion
while preserving default-retention bytes. Late publication cannot reopen a
retired payload. This profile rejects finite owners and live dependencies;
unresolved creation cannot be mistaken for safe deletion or retried blindly.

Implemented evidence: `just test` exercises request signatures, realm/PID grants,
key replacement, retry identity, ownership, stale state revisions, ordered input, and
retirement. `just test-storage` repeats competing transitions, revocation, lost
receipts, and replay across a real Ursula SIGKILL/restart, with a 100-message
backlog and a 16-record read window. Application logic is absent from the
authority and its replay path.
Further SIGKILL boundaries exercise checkpoint publication before trim, retried
trim, and recovery after prefix removal with new pending input in the tail.
Effect tests additionally prove intent validation, revocation racing dispatch,
authenticated observations, and one mailbox admission per result. Disk restart
and prefix removal preserve unknown attempts; late evidence after caller
termination cannot revive application execution. No external I/O is invoked.
The separate service proof now adds actual I/O through a trusted Zig synthetic
executor: successful result admission, pause after authorization, late response,
and executor death after remote acceptance. A fixture records exactly four
requests across these schedules; fresh executors and checkpoint/trim/restart
cause no additional sends. Closed attempts reject late outcomes, including when
the authorized executor starts its request after closure. This demonstrates the
external limit, not remote cancellation or a general HTTP connector.
Closure tests exercise both winners of the result/closure race, lost
acknowledgements, and unauthorized closure. Real disk restart and trim preserve
closed unknown outcomes and reject late observations even while the caller lives.
Outbox tests cover ordered routes, partial fan-out, denied/expired destinations,
revocation racing delivery, and cancellation of undelivered outputs. Disk restart
and prefix removal preserve pending payloads; a lost delivery receipt cannot
admit the same output twice. Replay verifies explicit admission metadata so
denied deliveries cannot masquerade as mailbox messages.
These are local single-node results, not the Kubernetes/Substrate isolation proof.

The time interface and finite-policy transitions now have executable proofs:
missing/uncertain time, rollback, delayed maintenance, permit recovery, deadline
closure, and observation-budget exhaustion. A disk-backed fixture settles a
preauthorized turn after its work cutoff, then expires its PID and trims history;
restart preserves both retirement and the time high-water mark. Time is controlled
in this fixture. `just test-service` additionally exercises Linux's synchronized
clock and a separate maintenance process: opted-in expiry, explicit cancellation
of unfinished input, checkpoint/trim while ingress remains live, and permanent
retirement after authority/storage restart. It requires the host clock to report
an error bound within two seconds; the fixture explicitly permits that bound
because a synchronized host can exceed one second between NTP polls. Controlled
clock tests retain exact rejection boundaries. Other platforms exercise explicit
retirement and cleanup without claiming a supported finite-time source.
The [deadline investigation](RETENTION.md#m1-deadline-enforcement-investigation)
defines the tested acceptance-time and closure contract. A physical
storage-write cutoff at the earlier work deadline is no longer the target.

The M1 mechanisms above now have concrete implementations and adversarial
results. Extending them to general behaviors, connectors or another storage/
runtime profile requires preserving these contracts and adding its own evidence.
A failed proof requires revising the owning design, not relabeling a weaker
implementation as conformant. The client cursor-model bug and separate upstream
documentation mismatch are recorded in [URSULA.md](URSULA.md). The corrected
client proof verifies offset-plus-cursor and record-plus-cursor continuation;
Transit's journal reads use record positions.

`just test-callers` compiles two Zig programs using only `transit-client` and their
own application module: decimal accumulation and arbitrary byte concatenation.
The same node binary accepts both, records opaque state and atomic outputs,
rejects stale revisions/skipped inputs/unauthorized effects, and recovers through
authority and disk Ursula restart. A proxy drops successful commit responses;
retrying the identical pending request returns the original receipt. Replaced
activations fail locally and at signed ingress. Recovery verification does not
execute either application. `just check-contract` checks that the committed
binding schema exactly matches the public types; shared fixtures check signing.

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
| Native code attempts forbidden I/O, submits a stale commit, reports false application state, or never returns | Prove runtime I/O boundaries and stale-commit rejection; authorized state bytes remain a trusted application claim, and protocol legality does not prove computation correct or bounded | [Transit](TRANSIT.md#enforcement), M1 |
| A handler repeatedly fails on the head message | Bounded retries, visible blocked state or authorized ordered disposition; no silent skipping or endless supervisor replacement | [Station](STATION.md#failure-and-progress), minimal policy M1; helpers M2 |
| A work cutoff or required-input expiry occurs during suspension or a turn | Only explicitly authorized bounded settlement may continue with a valid recovery basis; final retirement rejects all further execution even when bytes remain | [Retention](RETENTION.md), M1 |
| A result races reconciliation closure or arrives after recovery/trim | One authoritative winner; closed unknown stays unknown; no late admission, retry, or reopening; existing receipts do not constitute new acceptance | [Connectors](CONNECTORS.md#bounded-reconciliation-contract), kernel proof M1; connector execution M3 |
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
deployment. Multiple principals, conflicting authority instances, worker loss
and retention deadlines are exercised above; the single-realm topology does
not remove those obligations when the profile expands.

The contract does not currently promise Byzantine fault tolerance, globally
ordered messages, cross-process transactions, exactly-once remote effects,
arbitrary native-code determinism, timely scheduling before expiry, or instant
physical erasure. Add such guarantees only with an explicit scope change and
supporting proof. Milestone ordering and the remaining design gates live in
[ROADMAP.md](ROADMAP.md).
