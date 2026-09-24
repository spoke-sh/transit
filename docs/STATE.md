# State — resources and process associations

Status: foundational design for [M7](roadmap/M7.md), before Station. The bounded
authority resource/association transitions pass unit and disk-recovery proofs;
service/client, Board, and launcher integration remain in progress. The existing
[v2 profile](../contracts/TRANSIT_V2.md) commits an opaque inline value with each
turn; its standalone immutable payloads are not enforced state references.
The initial [wire contract](../contracts/STATE_V1.md) defines bounds and a
compatibility path; full M7 qualification remains outstanding.

## Purpose

Application data should live in durable, versioned resources that a process
accesses through recorded associations. A handler reads the state it needs and
proposes mutations, rather than returning a replacement for all application
state on every message. Worker memory is a cache, not the resource's lifetime or
recovery boundary. A raw Transit caller must be able to use this model without
Station; Station will make it convenient for behaviors and registries.

Durable streams remain authoritative. Resource operations and validated
checkpoints determine state; materialized indexes provide efficient access.
This adds no independent database or task store whose decisions compete with
Transit history. It also does not require one service or physical stream per
resource. [Streams](STREAMS.md) owns the transport boundary.

## Concepts and identity

| Concept | Contract |
| --- | --- |
| Process control state | PID, lifecycle, ownership, mailbox progress, committed turns, associations, and outstanding protocol obligations |
| Application state | Caller-defined data; Transit validates its storage and sequencing contract, not its business meaning |
| State resource | A durable identity, kind/version, revision, lifecycle policy, and committed data history |
| State association | A versioned, named relationship from a PID to an exact resource identity, declaring intended access and whether recovery requires it |
| Resource revision | The committed version used for reads and mutation preconditions; distinct from process progress and ownership generation |
| Read basis | The exact resource identities and revisions used by a turn, with the evidence needed for its declared recovery/replay contract |
| Materialized index | A bounded access structure derived from committed mutations and checkpoints; losing it cannot lose committed data |

Resource identities are realm-scoped and never reused after retirement. An
association name is local to its PID, such as `positions` or `configuration`;
its target is an identity, not a physical stream name or a mutable global alias.
Changing a target is an authorized, conditional protocol operation. Old turns,
retries, and references retain their original targets and versions.

Three roles remain distinct: the **lifetime owner** determines when a resource
retires; the **writer PID** supplies its serialized mutation authority; an
**associated process** uses it. An independently owned resource can therefore
outlive its writer. A reference or association is not a grant. Realm and
action/resource permissions apply to creation, association changes, reads,
writes, inspection, lifecycle, and maintenance. See [Security](SECURITY.md).

## KV first, Table above it

M7 starts with a versioned KV resource: opaque keys and values, lookup, put,
delete, and bounded enumeration at an explicit revision. A missing key is
different from an unavailable, expired, denied, or historically trimmed view.
Canonical key equality, byte limits, pagination, and conditional-write errors
belong in the versioned public contract. The kernel does not execute caller
predicates, serializers, or migrations.

A Table can build on the same resource model with typed records and declared
schema/index semantics. Station owns those richer programming conveniences.
The first KV implementation does not promise arbitrary queries, secondary
indexes, per-key TTL, distributed transactions, or automatic schema migration.
Any small inline state retained for compatibility has an explicit versioned
contract; it is not a second mutable copy of associated data.

Start with one fenced writer PID per resource. Other processes may read under
their own grants or send mutation requests to that PID. Their request, the
writer's turn, and the reply remain separate commits. M7 supports a bounded
number of associations and mutation of one resource per turn in the existing
authority domain. Multi-resource mutation and writer transfer are rejected
until separately specified. A writer's permanent retirement leaves an
independent resource readable under its policy, with no automatic new writer.

## Turn and commit boundary

The proposed calling model is:

```text
(admitted input, associated resource views at explicit revisions)
    -> (proposed state mutations, outgoing messages, effect intents)
```

The handler still computes in the caller. Transit validates current grants,
ownership, input order, resource identity/revision, and lifetime dependencies.
The accepted turn makes its input progress, state mutations, and pending
outputs/effects authoritative through one durable commit decision.

A candidate mechanism is to persist immutable staged data, then commit a
manifest identifying its base revision, mutations, and dependencies with the
turn. Staged data alone is invisible to ordinary resource reads and cannot
authorize output delivery. A materializer only applies committed mutations;
if it has not reached a requested revision, reads wait within a bound or report
unavailability rather than serving old data as current. Publication of the
resource head cannot be an independent authoritative write.

This mechanism is a design gate, not an assumption about Ursula. Prove its
durability, commit visibility, fencing, and dependency admission under crashes
and competing operations before building the higher-level API. Keep the first
profile in one authority domain; splitting resource and process authority must
not accidentally imply an atomic multi-stream transaction.

| Failure point | Required outcome |
| --- | --- |
| Data staged, turn not committed | No visible mutation, input completion, or output; abandoned staging is reclaimable under a bounded policy |
| Commit accepted, acknowledgement lost | Reconcile the same operation identity; no second mutation or duplicate output |
| Commit accepted, index not updated | Rebuild/catch up to the committed revision; never infer rollback from index lag |
| Old activation submits after replacement | Reject through current PID fencing even if it retained a valid resource reference |
| Resource retires while a dependency is proposed | Serialize retirement with dependency admission; reject the losing proposal without partial publication |

Creation, initialization, and association installation also need recoverable
operation identities. A process must not become executable with a required
association to an uninitialized resource. Rejected or interrupted creation
must not leave invisible permanent allocations or silently create a replacement.

## Reads, replay, and lookup cost

Resolve associations from validated process control state. Reads return an
explicit resource revision and coverage; repeated reads within a declared view
must not drift to later values. Record the turn's read basis. For shared state,
a read is an observation at that revision, not a promise it remains latest
when the caller commits. The writable resource's base revision is a commit
precondition. Cross-resource snapshots and global serializability are outside M7.

Required versions need explicit, bounded dependency protection while work can
commit. An expired read basis causes rejection or an explicitly new computation;
it cannot be silently refreshed inside an uncertain submission. Retry an
uncertain commit with the same identity and proposal until its outcome is known.
Grants and expiry remain current checks even when the requested version exists.

Recovery applies committed mutations and protocol transitions without executing
application handlers. Historical re-execution, where supported by the caller,
requires retained read versions or recorded observations and compatible code;
it never reads today's latest values as yesterday's inputs. When that evidence
is gone, report the replay limit. This does not prove arbitrary caller code
deterministic or honest. See [Caller model](CLIENT.md).

Indexes and caches avoid replaying full histories on every lookup. Bound resident
memory, scan work, active views, staging, and result sizes; use durable checkpoints
and bounded catch-up when rebuilding. A validated checkpoint becomes essential
recovery evidence once its source history is reclaimed. A disposable lookup index
must not be confused with that checkpoint. Measure lookup and recovery costs;
no constant-time or latency guarantee follows merely from naming an API `KV`.

## Lifetimes and retention

Resource creation records its ownership scope and effective policy. Unlimited
is the default for expiry and history retention; finite policies and compaction
require application opt-in. The [retention contract](RETENTION.md) governs time,
settlement, dependencies, and physical reclamation.

| Dimension | Meaning |
| --- | --- |
| Resource lifetime | When the logical resource is usable; independent or coupled to an explicit PID/workload scope |
| Entry lifetime | Whether a particular key/value expires; a separate future contract, not inferred from write age |
| Version/history retention | How long prior mutations and views remain available for replay and inspection |
| Association lifetime | When a process uses or requires that resource; removing an association does not by itself delete the resource |
| Physical reclamation | Background removal after authorized retirement/trim and dependency resolution |

A 30-day history window must preserve a live value last written 40 days ago in
the current recovery basis. Deleting that value requires an explicit mutation
or entry-expiry contract. Keyed compaction preserves live values and the evidence
needed to reject stale versions; it does not compact mailbox inputs as KV entries.

M7 supports PID-owned and independently owned resources. PID-owned state survives
suspension, worker replacement, and compatible same-PID upgrades. Logical owner
termination/expiry retires it under the recorded settlement and post-termination
policy. Associated readers cannot silently extend that lifetime. Independent
resources keep their policy when an associated PID retires. Station can add
workload-scoped ownership using these same rules.

An association explicitly declares whether it is required for recovery. Required
resource availability constrains the process's resumption bound. M7 uses a
terminal policy when that required recovery lifetime ends: permanently retire
the PID rather than silently recreate data or detach the dependency. Optional
resource expiry produces an explicit expired result. Temporary
storage failure or revoked access does not prove expiry. Same-PID state-loss
resynchronization is outside the first profile.

Before expiry, an authorized association change may release a dependency only
after validating the new recovery basis and outstanding work. It cannot
retroactively erase an expiry or remove references still required by older turns.

Associations do not pin every historical version. Track the versions needed by
active views, recovery checkpoints, pending work, and the promised replay window.
Release dependencies through recorded progress; pins can delay eligible cleanup,
never extend hard expiry. Reject incompatible dependencies before accepting work.
Messages carrying a resource reference must declare the required availability
and disclosure contract or carry a bounded copied value; arbitrary IDs hidden
in opaque application bytes acquire no retention protection.

Deletes are versioned tombstones. Retain them, or equivalent validated checkpoint
and rejection-floor evidence, until delayed readers, writers, and snapshots
cannot resurrect older data. Reads outside the supported horizon return an
explicit gap; permitted state readers may resynchronize from a valid snapshot.
This cannot repair an expired required process dependency. Resource retirement
evidence survives data cleanup, and a delayed delete cannot target a new identity.

## Ownership in the stack and inspection

| Layer | Owns |
| --- | --- |
| Public protocol and Transit core | Resource/association identity, revisions, operation validation, commit visibility, fencing, grants, dependency and lifecycle rules |
| Transit client | Authorized resource calls, stable read/commit identities, bounded KV access; usable without Station |
| Backend and maintenance services | Durable storage mapping, materialization, checkpoint/trim/delete mechanisms under validated authority |
| Station | Behavior-level association helpers, Table APIs, registry/supervision state, and declared schema conventions |
| Board | Authorized resource metadata, associations, revisions, lifetime/coverage, and links to committing turns |
| Applications | Value meaning, business validation, application schemas, and application-specific interfaces |

Board may show bounded authorized raw values without decoding their business
meaning. Resource metadata access does not imply value access, and inspecting a
PID must not disclose otherwise hidden associated resources. Board should explain
why a dependency constrains recovery, with source evidence and current grants.
It must not label a value as a counter, balance, or strategy state. The current
M2 counter lens is an implementation exception scheduled for removal in M7;
Station and connector views remain interpretations of runtime primitives.

## Implementation gates

[M7](roadmap/M7.md) owns the sequence and exit criteria. First specify the public
contract, authority/storage mechanism, read-view limits, and compatibility path
from inline state. Then prove one KV resource end to end before Station depends
on it. [Conformance](CONFORMANCE.md) owns adversarial obligations.

Exact record encoding, storage segmentation, index layout, and numerical budgets
remain implementation choices that require measured evidence. Table/index APIs,
writer transfer, cross-authority transactions, per-key TTL, and automatic data
migration need separate scope; none follows from this foundational design.
