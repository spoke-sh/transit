# Roadmap

This roadmap tracks milestone scope, sequencing, acceptance criteria and
completion status for Transit, ordered by dependency rather than delivery date.
Current behavior belongs in the [public reference](../README.md), mechanisms in
[Internals](../handbook/internals/README.md), and executed checks in the
[proof ledger](../../tests/README.md). A planned milestone does not establish
support; completed milestones promote their current semantics into the public
handbook while remaining in this index with their completion status.

The product goal is programmable, versioned data infrastructure: declare schemas,
datasets, computations and policies, then inspect whether Transit is fulfilling
that declaration. Data and derived computation are the primary model; durable
processes (`Station`), write-ahead streams (`TransitLog`) and connectors are the
mechanisms that **activate** data, materialize changes and coordinate external
effects. The [current data model](../handbook/reference/data-model.md) describes
the supported pieces and the gaps between them.

The [observation and feedback loop](../handbook/reference/collaborative-decisions.md#the-observation-and-feedback-loop)
gives this work a product target: improve what humans and agents can observe
before acting and what they can learn from the consequences afterward. Track
observation coverage, latency and cost while preserving meaning, source versions,
current authorization and uncertainty. The
[qualification plan](16-qualification-and-benchmarks.md#observation-and-consequence-evidence)
defines the proposed measures and comparison method; individual milestones
qualify their contribution as they land. These are evaluation goals, not current
measurements, and they do not assume that modeling or reasoning is solved.

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 1 | [Declarative data lifecycle](01-declarative-data-lifecycle.md) | In Progress ([#108](https://github.com/spoke-sh/transit/issues/108)) | Shared catalog identities, transaction/snapshot contracts and executable Table/KV/Document/computation lifecycles, with orthogonal $(\tau, \epsilon, \kappa)$ descriptors and direct data operations |
| 2 | [Storage hierarchy, `.tseg` segments and query performance](02-storage-and-query-performance.md) | In Progress ([#109](https://github.com/spoke-sh/transit/issues/109)) | Shared storage for native durable owners, logical change history and safe retention, hybrid segments, encoded query access, codecs/collations and partitioned/OCC concurrency |
| 3 | [Live storage engine and SQL execution cutover](03-live-storage-and-sql-cutover.md) | In Progress ([#110](https://github.com/spoke-sh/transit/issues/110)) | Installed local storage across native owners, direct Table writes/bounded SQL reads, observable flushing and exact restart recovery, with delivered cache/wakeup improvements preserved |
| 4 | [Standards, collations and historical catalogs](04-standards-and-catalogs.md) | Planned | Capability evidence, collation-preserving snapshots and historical interpretation over shared catalog manifests |
| 5 | [Managed computations and WAL-activated dataflows](05-sql-and-dataflows.md) | Planned | `TransitLog`-driven activation, service-managed incremental maintenance and observable freshness/failure |
| 6 | [Multi-model and multi-format foreign relations](06-multi-model-and-foreign-relations.md) | Planned | Document projections, finite graphs and zero-copy/mainframe foreign tables (Parquet, Arrow, CSV/JSONL, COBOL/EBCDIC) |
| 7 | [Branches, merges and restore](07-branches-merges-and-restore.md) | Planned | Branching within a realm over durable pinned versions, logical three-way merges and forward restore |
| 8 | [Service and SDK coverage](08-service-and-sdk-coverage.md) | In Progress | Go raw callers and broader types, sources and streaming interactions through shared contracts |
| 9 | [Enterprise identity and the Control & Policy Plane](09-control-and-policy-plane.md) | Planned | Trusted identity bindings, IAM membership lifecycle, bounded delegation and shared branch/publication authorization |
| 10 | [Published business resources and consistent investigations](10-published-resources-and-investigations.md) | Planned | Deliberate resource exposure, disclosure policy, shared typed results and one retained basis across related calls |
| 11 | [Versioned proposals and reviewed publication](11-reviewed-data-collaboration.md) | Planned | Comparable branch proposals, branching-only policy and exact reviewed publication |
| 12 | [MCP service and interactive Apps](12-mcp-service-and-apps.md) | Planned | Authenticated agent access and optional views generated from shared published capabilities |
| 13 | [Reactive context, subscriptions and agent activation](13-reactive-context-and-agent-activation.md) | Planned | Meaningful change conditions, durable interests and version-bound context through subscriptions and tasks |
| 14 | [Recorded outbound MCP and application guidance](14-recorded-mcp-integrations.md) | Planned | Governed external capabilities, captured observations, network-free replay and optional reviewed prompts/skills |
| 15 | [Clustered execution and storage-disaggregated placement](15-clustered-execution.md) | Planned | Fenced lease transfer, verified object/NVMe range caching and locality-aware distributed query execution |
| 16 | [Qualification and complete benchmarks](16-qualification-and-benchmarks.md) | Planned | Reproducible full workloads, fault coverage and measured CI costs |
| 17 | [Release distribution](17-releases.md) | Planned | Versioned, verified artifacts with runnable installed onboarding |

Performance measurement and amplification work remains tracked in
[issue #76](https://github.com/spoke-sh/transit/issues/76), alongside the reopened
milestone trackers above.
Standards, multi-model and branching work is tracked in
[issue #31](https://github.com/spoke-sh/transit/issues/31).

## Enterprise collaboration and MCP direction — 2026-10-23

The outcome is governed collaboration over versioned, enriched business resources:
people and agents inspect the same evidence, explore alternatives on branches,
and publish changes only under the installation's policy. The
[business stories](../handbook/reference/collaborative-decisions.md) explain that
proposed experience and its current building blocks without requiring this plan.

Milestones 1–8 retain their existing identities and delivered/remaining scope.
Six independently reviewable milestones now precede clustered placement,
qualification and release; those former milestones 9–11 move to 15–17 with their
scope preserved. Every new milestone is Planned. This documentation records
direction and acceptance gates, not executed runtime evidence.

The sequence is linear, with explicit prerequisites per milestone. Contract work
and a read-only MCP spike can start before all earlier implementations finish;
an adapter may expose only the capabilities whose owning contracts and evidence
are complete. Native branch operations use current realm authority; milestone 9
adds enterprise identity/delegation integration and milestone 11 adds the shared
proposal/approval experience. A protocol spike does not qualify those additions.

| Shared contract | Delivery owner | Required boundary |
| --- | --- | --- |
| Identity, membership, delegation and access decisions | 9 | Trusted issuer/subject and actor/represented-subject bindings; current authority, membership freshness and explicit approval powers across every adapter |
| Published resources and statement/results | 10 | Headless definitions, deliberate exposure, typed complete results, approved disclosure and a retained investigation basis independent of connections |
| Branch histories and reviewed proposals | 7, 11 | Branching within one realm; frozen base/source/target and candidate; no copied grants or effects; no protected-destination bypass |
| MCP and presentation bindings | 12 | Generated descriptions and views over shared owners; exact host/revision matrix; useful structured/text fallback |
| Meaningful activation and durable interests | 5, 13 | Source changes, completed results and business conditions remain distinct; no implied agent execution from socket delivery |
| External MCP observations and effects | 14 | Recorded intent/attempt/capture, explicit remote reconciliation, no network dispatch on replay |

The Control & Policy Plane owns identity bindings, catalog definitions, access and
publication policy. Data owners enforce reads and conditional writes; process
and effect owners enforce activation and dispatch. Reasoning remains an
application responsibility. A model's confidence, an App button or an MCP tool
annotation supplies no authority.

Branching is the versioning primitive within a realm. A branch has an identity,
head and ancestry under the realm's current policy; it is not inherently an
independent export or ownership boundary. A GitHub-like project/application fork
relationship is a possible later collaboration feature, not a prerequisite or a
synonym. Copy-on-write and manifest sharing are storage techniques. Historical
data selection never restores historical permissions or executable effects.

The first collaboration acceptance story uses one native dataset, one captured
external source, a human and two delegated agents. Related queries retain one
basis; agents publish different branch proposals; a report and App show the same
evidence. Source changes mark old evidence without relabeling it. A branching-only
installation rejects every merge and equivalent direct write. A separate approval
profile publishes one exact reviewed candidate and recovers its outcome after a
lost reply. Each owning milestone qualifies its part before the complete journey
is claimed. No new top-level `transit` command or automatic catalog-wide MCP
exposure is part of this direction.

## Reopened assessment — 2026-10-22

Milestones 1–3 are reopened following review of local source snapshot
`a0a8a3ed`.
The initial implementations in [PR #105](https://github.com/spoke-sh/transit/pull/105),
[PR #106](https://github.com/spoke-sh/transit/pull/106) and
[PR #107](https://github.com/spoke-sh/transit/pull/107), plus subsequent latency
work, delivered useful metadata, component libraries and improvements to the
existing Ursula/actor path. They did not satisfy the milestones' full lifecycle,
storage correctness or live cutover acceptance criteria. Component test passes
do not establish disk durability, independent-writer safety or runtime wiring.

The audit snapshot includes four unpublished implementation commits on
`feat/single-turn-sql-and-tseg-cutover` after the published
[PR #107 base](https://github.com/spoke-sh/transit/commit/733bc50406bf7a9100697478960fc18bb6ab8a8b).
Those implementation commits are outside this documentation change. Statements
about subsequent latency work refer to that local audit snapshot; they do not
claim that work is already on `main`.

The milestone pages separate that delivered work from the remaining gaps and
link actionable issues with source evidence, dependencies and completion gates.
The original design discussion transcript was reviewed, and the user authorized
this planning revision on 2026-10-22. The source transcript has SHA-256
`455cff4e0843d7d4602d2273041aa14055fd3272a88192bb5b4ec9ebec679f7e`;
it remains local source material, not a capability contract or a prerequisite
for understanding this plan. The scope and gates below supersede the initial
tracking pass's pending-review notes. They establish intended delivery, not
implementation or qualification.

## Firm scope and contract gates

Transit uses shared `TransitLog` and `TransitObjectStore` boundaries for the
durable system: catalog/control state, native process progress, KV, Documents,
Tables and supported captured/stream payloads. Data kinds retain their own
semantics and may use different physical layouts. Table-only storage does not
complete this cutover. Direct point mutations and bulk segment ingestion share
one accepted-operation protocol; process/effect owners preserve their existing
atomicity and recovery guarantees.

| Required contract | Owner | Gate before dependent implementation |
| --- | --- | --- |
| Catalog/branch roots and transactions | [#125](https://github.com/spoke-sh/transit/issues/125), [#111](https://github.com/spoke-sh/transit/issues/111) | Define atomic domains, isolation, head publication and consistent snapshots including accepted unflushed WAL state. Start with the complete single-owner Table slice; milestone 5 implements the selected transaction-session extension. |
| Native durable-state ownership | [#126](https://github.com/spoke-sh/transit/issues/126) | Map each control/process/KV/Document/payload owner to log transitions, checkpoint evidence and immutable objects; preserve input/state/output atomicity, retirement and effect outcomes. |
| Logical history and retention | [#127](https://github.com/spoke-sh/transit/issues/127) | Separate state recovery, net-result deltas and every-change capture; define subscriptions, snapshot-to-tail handoff, pins and safe physical trimming. |
| Encoded query access | [#128](https://github.com/spoke-sh/transit/issues/128), [#118](https://github.com/spoke-sh/transit/issues/118) | Define layouts, buffer ownership, encoded operators, collation identity and five-state/export semantics before changing segment/query interpretation. |
| Direct writer trust and durability profiles | [#117](https://github.com/spoke-sh/transit/issues/117), [#121](https://github.com/spoke-sh/transit/issues/121) | Select enforceable permission/fencing mechanisms and acknowledgement/failure guarantees for each provider profile; a lease tuple or object CAS is insufficient alone. |
| Maintenance and installed operation | [#116](https://github.com/spoke-sh/transit/issues/116), [#122](https://github.com/spoke-sh/transit/issues/122) | Assign flush/checkpoint/compaction/GC ownership, backpressure, shutdown and authorized progress inspection. Resolve runtime composition and the single-binary packaging target explicitly. |

Resolve these interacting contracts in their owning milestone and public topic
as appropriate before dependent code or persistent formats. This is required
engineering work, not an open-ended request for another product-direction review.
Unsupported combinations must be rejected explicitly. Any later scope change
must update the owner, linked issues and acceptance criteria together.

The native local profile is the first delivery checkpoint, with no Ursula or
MinIO dependency for either application or control state. The distributed
reference remains disk-backed Ursula plus S3 on Compose and Kubernetes/Substrate.
Kafka/Pulsar and GCS/R2/Azure remain explicit target coverage in milestone 2;
each needs its own provider contract and evidence, or an explicit recorded move
in scope. They are not assumed interchangeable implementations. Advanced provider,
codec and concurrency slices may follow the local checkpoint without closing
the enclosing milestones early.

## Delivery checkpoints

Sequence the recovery work as follows:

1. Resolve the contract gates above and coordinate the current-v1 cutover in
   [#112](https://github.com/spoke-sh/transit/issues/112).
   Correct documentation claims immediately through
   [#123](https://github.com/spoke-sh/transit/issues/123).
2. Establish durable local WAL/object-store behavior, complete Table semantics,
   native durable owners and bounded reads. Complete named resource and explicit
   computation lifecycle integration alongside those foundations. A contract
   prerequisite does not require every later provider implementation to finish.
3. Cut over the actual executables through
   [#122](https://github.com/spoke-sh/transit/issues/122), proving the local path
   before extending deployment qualification. Prove WAL-only accepted writes,
   controlled segment flushing, Table/KV/Document state and native process/effect
   recovery. Attaching the optional storage mirror cannot satisfy this step.
4. Extend the same contracts to partition fencing/OCC, the full planned
   codec/collation profiles and real distributed providers. Later milestones add
   historical queries, managed activation, foreign readers and branches using
   these foundations; they do not invent replacement storage semantics.
5. Close milestones only after their public caller acceptance paths and actual
   disk/failure/performance evidence pass
   [#124](https://github.com/spoke-sh/transit/issues/124), with accurate public
   documentation. Later milestones do not absorb unfinished promises implicitly.

## Architectural direction across the sequence

1. **Decouple declarative data operations from the actor turn ceremony ([Milestone 1](01-declarative-data-lifecycle.md) — In Progress).**
   Unify catalog identities (`CatalogId`, `DefinitionId`), dependency tracking and
   policy bindings across Tables, KV, Documents and named computations. Route
   data-plane DDL/DML and batch ingestion directly through the catalog and
   storage boundary instead of cycling every row through the `4 × 256B` metadata /
   `128 KiB` block actor-turn loop (`open_view -> commit_turn`), reserving
   `Station` actor turns for stateful process behavior and effect orchestration.
2. **Replace B-tree-over-JSON-streams with a four-tier storage hierarchy and `.tseg` segments ([Milestone 2](02-storage-and-query-performance.md) — In Progress).**
   Split storage into two swappable primitives: **`TransitLog`** (the sequenced
   `TWAL1` write-ahead log and live data-activation delta bus, backed by a native
   Zig local WAL by default in `transit server`, or by Ursula, Kafka or Pulsar in
   distributed deployments) and **`TransitObjectStore`** (the immutable segment
   and manifest store, backed by a local POSIX directory in `transit server` or
   S3/GCS/R2 with a local NVMe read-through cache in cloud deployments). Store
   relational data in 64-byte-aligned **`.tseg` hybrid OLTP/OLAP segments** with
   Arrow-compatible physical column buffers, 5-state cell validity tags, embedded
   primary-key prefix B-tree indexes, zone maps, `.tdel` deletion vectors,
   composable Zig codecs (bitpacking, RLE, dictionary, FSST, plus mainframe
   `COMP-3`, `ZONED`, `COMP`, `IBM_HFP` and `EBCDIC`) and first-class Collation
   (`COLLATE`) support. Progress concurrency from a single global realm sequencer
   to **Partitioned Policy/Data Logs**, **Fenced Partition Leases**, and
   **Multi-Writer OCC** over authorized conditional publication. Formal progress
   and metadata-complexity claims require scoped evidence.
3. **Cut over live executables and activate derived views, multi-format foreign sources, branches and clustered compute ([Milestones 3](03-live-storage-and-sql-cutover.md)–[15](15-clustered-execution.md)).**
   Wire the storage hierarchy, `.tseg` segments, write-through caches and immediate
   wakeups into the live node, SQL gateway and server executables; bind historical
   catalog snapshots to immutable manifest versions and collations;
   drive maintained SQL views, reactive watches and Station processes directly
   from `TransitLog` (`+row`/`-row`) delta streams; read Parquet, Arrow IPC,
   CSV/JSONL and mainframe fixed/variable (`FB`/`VB`) copybook datasets through
   the shared `Fuze` segment boundary; implement branch creation over complete
   durable snapshots and logical three-way merges over immutable state; and schedule distributed
   Station and `Fuze` workers over shared object storage with fenced lease handoff.

Handbook publication is implemented. Remaining live-site navigation and recovery
qualification belongs to [qualification](16-qualification-and-benchmarks.md#documentation-publication),
with completed observations in the proof ledger.

## Shared implementation gates

- Name the user-visible declaration, its owner, dependencies, permitted work and
  lifecycle evidence. A healthy process or parsed statement does not fulfill a
  data declaration. State how the user can distinguish publication, unresolved
  work, a complete result and stale or blocked progress.
- Define neutral contracts, ownership, authorization, lifetimes and bounds before
  exposing syntax. Grammar acceptance is separate from executable behavior.
- Preserve exact accepted-operation recovery, current permissions, permanent
  retirement and the distinction between cancellation and uncertainty.
- Keep retained collection size independent of resident memory. Measure provider,
  compute, transport and publication costs separately.
- Apply the [v1 hard-cutover policy](../handbook/reference/versioning.md) to incompatible
  definitions. Never reinterpret accepted work or reset data automatically.
- Run focused proofs and committed-source clean checks. Publish supported
  behavior and measured limits with their public owners as work lands.

Each delivered slice needs an end-to-end acceptance path: describe, validate,
apply, inspect, change and recover through actual public callers. Include denied
access, lost responses, dependency changes, bounded work and incomplete results.
Retain different completion semantics for interactive, captured and maintained
computation; one universal readiness flag is insufficient.

## Maintaining the sequence

Keep one numbered, descriptively named file per milestone (`01-` through `17-`).
Insert or reorder work by updating this index, filenames and links together.
Split work only when it has independently reviewable outcomes and prerequisites.

When a milestone is complete, keep its file in `docs/roadmap/` and update its
status to `Completed` in both the milestone header and the table above, while
promoting all current user-facing behavior and reasoning into its public
handbook owner and recording executed verification in `tests/README.md`.
If review finds an unmet completion criterion, reopen the milestone as
`In Progress`, preserve delivered work and prior evidence, and link the remaining
acceptance work. Merged code, parser support and component tests do not substitute
for the milestone's executable caller and recovery evidence.
