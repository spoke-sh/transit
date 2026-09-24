# State — resources and process associations

Status: bounded M7 profile implemented and verified, before Station. The
[wire contract](../contracts/STATE_V1.md) and component READMEs own exact APIs,
numerical bounds and compatibility. [M7](roadmap/M7.md) and the
[proof guide](../tests/README.md#m7-state-resources) record qualification.

The broader design below includes future capabilities. The first profile has
opaque KV values, one writer PID, bounded materialization, and one mutated
resource per turn in the existing realm journal. Inline-state callers coexist;
no existing realm is automatically migrated. Table abstractions, per-key TTL,
writer transfer and transactions across resources are outside this profile.

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
The [M9 Table design](TABLES.md) proposes Arrow query results and typed keyspaces:
several logical tables can share one resource and its existing atomic turn,
permissions and lifetime. This is distinct from a transaction across resources.
Query computation and schema validation stay in callers; the kernel does not
become a SQL or Arrow compute engine.

[Fuze](FUZE.md) names that shared query engine. Its target source model includes
KV, Table and a proposed Station Document for structured values and collaborative
text. [M10](roadmap/M10.md) owns Document change/CRDT semantics above core and
the qualification of its storage/lifetime profile. Shared querying does not add
those semantics to the current KV resource or widen its transaction boundary.

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

The implemented calling model is:

```text
(admitted input, associated resource views at explicit revisions)
    -> (proposed state mutations, outgoing messages, effect intents)
```

The handler still computes in the caller. Transit validates current grants,
ownership, input order, resource identity/revision, and lifetime dependencies.
The accepted turn makes its input progress, state mutations, and pending
outputs/effects authoritative through one durable commit decision.

M7 puts the bounded mutation batch and turn proposal in one conditional realm
journal append. Validation changes a private candidate; failed validation or a
lost append race publishes none of it. The accepted record determines both
process progress and resource revision. Recovery rebuilds the bounded catalog
from committed records and checkpoints. There is no separate durable staging
allocation, independently published resource head, or asynchronous index service.
See [core](../packages/zig/transit-core/README.md) and the
[state contract](../contracts/STATE_V1.md) for the implemented mechanism.

Larger resources may eventually need durable staging and a manifest commit.
That would require new proofs for abandoned uploads, dependency protection and
index lag. It cannot inherit atomicity from the current single-record design.
Splitting resource and process authority also requires an explicit coordination
contract; independently successful stream appends are insufficient.

| Failure point | Required outcome |
| --- | --- |
| Candidate prepared, turn not committed | No visible mutation, input completion, or output; discard the private candidate |
| Commit accepted, acknowledgement lost | Reconcile the same operation identity; no second mutation or duplicate output |
| Commit accepted, authority crashes before updating memory | Recover the committed revision; never infer rollback from a lost materialization |
| Old activation submits after replacement | Reject through current PID fencing even if it retained a valid resource reference |
| Resource retires while a dependency is proposed | Serialize retirement with dependency admission; reject the losing proposal without partial publication |

Creation initializes an empty resource; it does not initialize application data.
Creation, grants, association installation and activation are separate recoverable
commands. [M8 lifecycle creation](../contracts/LIFECYCLE_V1.md) declares required
association names and blocks handlers until explicit initialization succeeds.
New launchers use this barrier; legacy `spawn` remains immediately executable.
Station must define application schema initialization and recover the exact
provisioning requests, including partial allocations, before completing the
barrier. Empty resource creation is still not application initialization.

[Opt-in collection](../contracts/CATALOG_V1.md) releases reclaimed resource slots
without reusing their IDs. Default retention keeps those entries. Pending work,
live associations and captured views pin the resources they require.

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
It must not label a value as a counter, balance, or strategy state. M7 removed the
M2 counter lens; Station and connector views remain interpretations of runtime
primitives.

## Implementation gates

[M7](roadmap/M7.md) records the completed bounded profile and qualification.
[Conformance](CONFORMANCE.md) owns adversarial obligations; the
[pre-Station review](reviews/PRE_STATION.md) identifies limits relevant to M9.

The [state v1 contract](../contracts/STATE_V1.md) specifies current encoding,
limits, and compatibility. Changes to storage layout or numerical budgets need
new measured evidence. Bounded Table helpers are planned in [M9](roadmap/M9.md);
larger indexes, writer transfer, multi-resource/cross-authority transactions,
per-key TTL and automatic data migration require later explicit scope.
