# Durable streams and mailboxes

Status: Ursula and the unbounded process mailbox are established choices. The
M1 realm-journal mapping has conditional-write, bounded-read and disk recovery
proofs; broader stream/reference topologies remain planned. The
[Transit kernel protocol](TRANSIT.md) owns execution semantics; this document
owns their durable transport requirements.
The [experimental profile](../contracts/TRANSIT_V1.md#process-outboxes) now proves
same-realm outboxes, per-route order, partial fan-out, current delivery grants,
and checkpoint recovery. Cross-realm delivery is not implemented.

## Ordered, logically unbounded mailbox

Every Transit process owns a durable mailbox. Its backlog can outlive an activation
and grow beyond any worker's memory. Suspension or worker loss does not itself
destroy accepted messages; availability follows the application's recorded
lifetime contract. Admission assigns a stable per-process order across producers.
The process consumes that order sequentially; independent processes execute in parallel.

"Unbounded" means the programming model has no fixed in-memory mailbox capacity.
Implementations read bounded windows and enforce explicit message/storage quotas.
When admission capacity is exhausted, reject or backpressure new sends before
accepting them. Never acknowledge a send and then drop it to make room.

Retention defaults to unlimited. Applications can opt into finite process/mailbox
lifetimes, history windows, and resources owned by a workload. Suspension and
activation must respect the mailbox's recovery lifetime. At a hard expiry, the
process becomes terminal under its accepted policy; it cannot resume with an
empty or truncated mailbox. See [RETENTION.md](RETENTION.md) for these guarantees,
compaction, tombstones, consumer horizons, and background reclamation.

Logical termination retires a PID; retain the retirement evidence needed to
reject new admissions and prevent identity reuse. Apply recorded disposition
and reconciliation policy to unread input, pending deliveries, and effects.
Spawning a replacement or rebinding a name cannot transfer that backlog
implicitly. Worker loss or suspension does not reset its identity or deadline.

## Transport requirements

| Concern | Required behavior |
| --- | --- |
| Persistence | Acknowledgement follows a documented persistent storage boundary |
| Ordering | Stable mailbox admission order; process outboxes preserve source order per destination, without a global order |
| Identity | Scoped PID destinations and message, turn, and effect identities survive retries and differ from storage cursors |
| Resume | Recover a committed position without silently skipping accepted messages |
| Delivery | Assume at-least-once transport delivery; deduplicate protocol effects |
| Fan-out | Independent readers can inspect/replay history without stealing process input |
| Backpressure | Bounded resident buffers, visible backlog, and explicit admission failure |
| Compatibility | Versioned records, framing, validation, and unknown-schema policy |
| Retention | Enforce the accepted policy, lifetime, and logical retained boundary; expiry is explicit and physical cleanup can follow later |
| Recovery | Validate lifetime and restore a durable checkpoint plus retained history, preserving required pending work and control evidence |

## Proposed storage mapping

Start by evaluating one logical process journal containing admitted inputs,
lifecycle/ownership records, and turn commits. The mailbox is its ordered input
view; a processing checkpoint identifies which inputs have completed. This keeps
each PID's execution facts in one ordering domain. Physical streams or shards
may serve multiple processes only if the same protocol properties are preserved.

The journal is a logical stream, independent of Ursula naming and cursor format.
It may span physical segments with a durable mapping and stable logical sequence
positions. Rotation and segment deletion must preserve ordering, incarnation
checks, and recovery boundaries. A whole-stream TTL is not a rolling record-age
window. Storage adapters implement supported policies through explicit contracts;
they do not define Transit's lifetime semantics.

Durable control catalogs must locate process journals, physical segments,
checkpoint manifests, and pending maintenance without consulting an application
registry. Bootstrap and recovery of those catalogs are protocol responsibilities;
see [DEPLOYMENT.md](DEPLOYMENT.md#bootstrap-and-disaster-recovery).

Registry services persist name bindings through their own process turns. Runtime
binding changes and provider observations also require validated durable records.
Their indexes are rebuildable; a stream name, pod label, or provider database row
cannot substitute for a PID or authoritative process history.

Bulk connector data may occupy related streams. A **stream group** is a Rey
manifest tying member streams to one exchange/effect identity and lifecycle.
It does not imply a native Ursula consumer group or an atomic multi-stream write.
See [CONNECTORS.md](CONNECTORS.md) for the HTTP exchange design.

Before implementation, fix record encoding, length framing, commit visibility,
size limits, stream naming, ownership permissions, and sequence assignment.
An HTTP transport chunk is not a kernel record boundary. Only validated complete
records contribute to authoritative protocol history.

## Envelopes

Define language-neutral fixtures for protocol/schema version, target PID,
authenticated sender/realm, message type/ID, sequence position, ownership
generation, causation, correlation, and payload. Bind operation identities to a
defined payload digest and scope so conflicting retries are detectable. Record
grant/policy provenance, not credentials. Turn/effect/attempt/group references
are present where their record family requires them. Separate source time,
observed time, and duration units; timestamps do not establish mailbox order.

A finite deduplication horizon needs verifiable identity age or a durable
sequence/epoch rejection floor. Forgetting arbitrary UUID receipts cannot
distinguish an old retry from new work. M1 must choose a scoped identity scheme
that proves this distinction; a client-supplied timestamp cannot renew an old
operation. If validity cannot be established, refuse ambiguous admission.

Treat Ursula offsets/cursors as opaque transport metadata, passing them back
unchanged. Protocol sequence numbers must not depend on their encoding. Unknown
versions or malformed records stop or quarantine processing with explicit
evidence; a checkpoint cannot simply advance past them.

## Commit and delivery

The kernel's durable turn commit contains the state transition, consumed input,
and pending outputs. Stage any referenced payloads durably with compatible
lifetimes before committing.
Commit visibility and stale-writer exclusion require explicit tests against
Ursula; a series of successful append calls alone is not a transaction.

Deliver committed outgoing messages with stable identities. On a crash between
destination admission and source delivery bookkeeping, retry the same identity and PID;
the destination must recover the original admission. Retain deduplication for
the supported retry/replay horizon. Outside it, reject uncertain old retries
rather than treating them as new sends. Local outbox indexes can be rebuilt from
committed history, delivery records, and validated checkpoints that retain
outstanding obligations.

Process outboxes preserve source commit/output order for each destination PID.
A later message on that route cannot overtake an earlier unresolved delivery;
admission or a recorded terminal disposition releases the next message. Other
senders can interleave at destination admission. Concurrent external client
requests and independent effect completions have no source-order guarantee
unless a separate contract supplies one. Correlation does not imply ordering.

A source-side timeout or cancellation is not proof of destination rejection.
If admission is uncertain, resolve its receipt or establish a durable rejection
at the destination before releasing that route. Delayed earlier attempts must
not become admissible after later messages; a local terminal label cannot fence
an in-flight delivery.

Fan-out is independently admitted at each destination and can partially succeed.
Source commit does not guarantee delivery or destination authorization forever.
Distinguish retryable unavailability/capacity refusal from permanent denial,
expiry, invalid input, and retired destination. Record blocked or terminal
outcomes under policy, with bounded retries; cancellation cannot withdraw a
message already accepted by the destination. See [SECURITY.md](SECURITY.md#authorization-over-time).

When sending by name, record the resolved PID and registry revision with the
outgoing message. A retry cannot resolve the name again and silently change its
destination. Direct sends and replies already carry PIDs. Retired destinations
produce a recorded delivery outcome under lifecycle policy, not automatic
rerouting to whichever process now holds the name.

Ursula producer deduplication helps with uncertain appends but does not implement
process ownership, consumer transactions, or external-effect idempotency. Its
producer epochs have separate semantics from kernel ownership generations;
define their mapping explicitly. See [URSULA.md](URSULA.md).

## Recovery evidence

M1 uses persistent Ursula storage in the Kubernetes reference environment.
Demonstrate process recovery after worker/pod loss and storage service restart;
record what this proves separately from disk-loss, host-loss, or regional
availability. A memory-only Ursula process cannot satisfy the persistence test.

Exercise crashes around admission, turn commit, publication, and checkpoint
updates; duplicate and conflicting identities; stale owners; expired cursors;
partial records; unavailable/full storage; and backlogs larger than worker RAM.
Replay must reproduce committed state with effect execution disabled. Retention
and restore failures must be visible, with no automatic jump to the stream tail.
