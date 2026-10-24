# 1. Declarative data lifecycle

[Roadmap](README.md) · [Current data model](../handbook/reference/data-model.md) · [Tracker #108](https://github.com/spoke-sh/transit/issues/108) · **Status:** In Progress

Let an application describe its data, schemas, computations and policies, apply
a supported change, then inspect the accepted definition and operation outcome
through consistent public operations. This unifies the catalog and operation
surface across data kinds while separating direct data-plane lifecycle operations
from the actor mailbox and native turn ceremony.

## Reopened assessment — 2026-10-22

Source review of local snapshot `a0a8a3ed`
found that [PR #105](https://github.com/spoke-sh/transit/pull/105) delivered
column encoding/collation descriptors, Table preview/lifecycle observations,
dependency/policy inspection, a `TableClient.apply` convenience API and named
KV/Document/computation metadata transitions. Retain that work and its scoped
[component evidence](../../tests/README.md#declarative-data-lifecycle-codecs-and-collations).
Existing Table CRUD and native authorization/recovery predate this milestone.

The executable acceptance path is incomplete. `TableClient.apply` still drives
actor sends, uploads and continuations. Named KV/Document publication records a
supplied resource ID without establishing provisioning or initialization.
Computation completion is not bound to verified result evidence, and schema
revision comparisons do not establish freshness after row changes. Metadata
transitions alone do not fulfill a data declaration.

| Remaining work | Tracking issue |
| --- | --- |
| Direct Table operations and one acceptance/visibility/recovery protocol | [#111](https://github.com/spoke-sh/transit/issues/111) |
| Catalog/branch identities, transaction domains and durable snapshot roots | [#125](https://github.com/spoke-sh/transit/issues/125) |
| Real named KV/Document provisioning, initialization and lifecycle recovery | [#119](https://github.com/spoke-sh/transit/issues/119) |
| Computation results, dependencies and data-source freshness evidence | [#120](https://github.com/spoke-sh/transit/issues/120) |
| Executable codec/collation semantics behind declared descriptors | [#118](https://github.com/spoke-sh/transit/issues/118) |
| Coordinated current-v1 definition and artifact cutover | [#112](https://github.com/spoke-sh/transit/issues/112) |
| Accurate current documentation and scoped proof claims | [#123](https://github.com/spoke-sh/transit/issues/123) |
| Public caller, failure, growth and recovery qualification | [#124](https://github.com/spoke-sh/transit/issues/124) |

These issues preserve the delivery sequence and completion criteria below.
Resolve the operation/commit contract first, then complete the executable Table
slice with [storage](02-storage-and-query-performance.md) and the
[live cutover](03-live-storage-and-sql-cutover.md). Named resource and computation
work must reuse their existing owners. Automatic scheduling remains later scope.
The transcript review is complete and this planning revision is authorized.
The [shared contract gates](README.md#firm-scope-and-contract-gates) identify
engineering decisions that must precede dependent implementation.

## Catalog, transaction and snapshot scope

[#125](https://github.com/spoke-sh/transit/issues/125) defines the
database/catalog/branch, schema, object and definition hierarchy, its relationship
to partition heads, and supported atomic domains/isolation. A catalog-wide root
must not recreate a global realm CAS for every independent data/process write.
Deliver the complete single-owner Table statement/batch slice first. Specify
the catalog-scoped transaction extension now; its interactive sessions belong
to [managed computations and SQL](06-sql-and-dataflows.md). Arbitrary distributed
cross-owner transactions are not implied, and native turns retain their current
one-KV-resource atomicity limit.

Snapshots must distinguish a consistent catalog cut from independently captured
source versions and bind exact interpretation, manifests and committed WAL
frontiers. Include accepted unflushed rows and durable pin/recovery ownership
from [#127](https://github.com/spoke-sh/transit/issues/127). Define permitted
isolation anomalies, read/predicate conflicts, rollback and uncertain outcomes
before changing persistent formats or admitting transaction syntax.

Named KV/Document provisioning consumes the actual native persistence cutover in
[#126](https://github.com/spoke-sh/transit/issues/126); a resource metadata record
does not establish storage migration or usability. Computation evidence consumes
the snapshot and logical-change contracts, while automatic activation remains
milestone 6.

## Baseline, bottleneck diagnosis and scope

The Table catalog already owns stable object/column identities (`CatalogId`,
`DefinitionId`, `ColumnId`), immutable definitions, `CREATE`/`ALTER`/`DROP`, DML
outcomes and native authorization bindings. KV and Documents have resource/service
APIs but no common named SQL publication lifecycle. Named relational definitions
and captured/maintained execution have typed Zig owners with explicit activation.
Dependencies, policy and progress remain spread across their owning interfaces.

Crucially, the current implementation funnels relational and catalog mutations
through the actor mailbox and native turn protocol (`send_input -> open_view ->
read_resource_blocks -> commit_turn`), where each turn is capped at `4 × 256B`
metadata keys and `16 × 64KiB` (`128 KiB` total) resource blocks. Because of
these tiny actor-turn bounds, higher-level table and publication owners
(`TableWrite`, `TableStatement`, `TableAlter`, `TableCleanup`, `Publication`,
`RelationalCapture`, `RelationalMaintenance`) had to invent multi-turn resumable
staging state machines (`STC1`, `STW1`, `STG1`, `STX1`) just to move rows or
evolve schemas.

This milestone unifies the public declarative lifecycle and decouples **data-plane
declaration and mutation operations** from the **actor turn ceremony**:

- **Data-plane operations** validate against the catalog and `policy_epoch`,
  commit idempotent operation records and batch payloads directly through the
  storage/catalog boundary (prepared for the [four-tier storage hierarchy](02-storage-and-query-performance.md)),
  and return typed operation outcomes without cycling through actor mailbox turns.
- **Actor turns (`Station` processes)** remain the mechanism for stateful
  workflow orchestration, message-driven behaviors and external effect coordination.
- Server YAML remains operational configuration; data declarations and
  administrative changes use their owning public operations. A new manifest, CLI
  command or UI form must not become a separate source of authority.

## Delivery sequence

1. **Inventory the lifecycle contracts.** For Table, KV, Document and named
   computation definitions, record identity (`CatalogId`, `DefinitionId`), naming,
   logical types, physical encoding and collation descriptors, dependencies,
   policy references, admission, publication, inspection, alteration and retirement.
   Distinguish supported operations, offline compilation and missing execution.
   Identify which fields and operations are shared across the catalog and which
   remain kind-specific.
2. **Define shared metadata, operation evidence and direct data-plane boundaries.**
   Specify versioned neutral types for object/definition identity, expected
   revision/manifest head, dependency bindings, idempotent operation identity,
   accepted outcome and bounded observed progress. Separate direct data-plane
   batch/DDL admission from the actor `open_view`/`commit_turn` wire limits so
   table mutations and catalog transitions do not depend on `4 × 256B` metadata
   keys or `16 × 64KiB` turn blocks. A query's source vector, a Table manifest
   head and a Document revision remain distinct types. Define unavailable,
   incomplete and denied observations; do not infer failure from a timeout or
   fulfillment from worker liveness. Generate the schemas and shared fixtures
   from the owning types.
3. **Implement a complete Table slice.** Adapt the existing catalog lifecycle to
   those shared types and direct data-plane operations. Validate and show a
   proposed change without applying it; apply against its expected definition/head
   and inspect the exact accepted result. Preserve original intent through lost
   replies and name/schema replacement. Retire redundant multi-turn staging
   ceremonies as direct batch/manifest commits land in
   [Milestone 2](02-storage-and-query-performance.md). Use existing SQL and typed
   callers to demonstrate the whole path before extending object kinds.
4. **Add named KV and Document lifecycles.** Bind explicit encodings, initialization
   rules and owned resources to stable catalog identities. Reuse current service
   provisioning and publication, with durable bounded recovery between steps.
   Do not promise atomicity across independent owners. Define failed/partial
   provisioning, cleanup, rename, retirement and same-name replacement. Publish
   typed operations first; expose SQL publication only for implemented grammar
   and qualified execution paths.
5. **Make dependencies and policy references inspectable.** Bind exact object and
   definition identities, record required access and distinguish metadata visibility
   from data access. Extend explicit dependency registration and `RESTRICT` behavior;
   never infer all consumers from names or payloads. Reuse current authorization,
   unlimited-retention defaults and owner-specific budgets. Explain a blocked
   change without disclosing unauthorized dependency data.
6. **Connect computation definitions and inspection.** Expose named query inputs,
   requested lifetime and definition revisions through the same metadata model.
   Link to existing activation and outcome evidence; distinguish a definition
   from a running computation and a completed result from current freshness.
   SQL/SDK adapters and Board projections consume these shared public operations.
   Board changes follow its explicit capability and UI review boundaries.

Each numbered slice needs an independently reviewable contract and usable caller
path. Avoid waiting for every data kind to be implemented before proving the
Table path. No parsing or metadata milestone counts as complete publication.

## Completion evidence

- An application can create a Table, inspect its definition, write/query rows,
  alter the schema and recover the original accepted change after losing a reply
  without routing bulk row data through multi-turn actor mailbox loops.
- Named KV and Document objects expose explicit interpretation, initialization
  state, current rights and lifecycle outcomes through the qualified typed path.
- Repeating an inspection or loading a definition starts no work. Applying a
  competing change rejects the stale expectation; recreating a name never
  retargets an earlier operation or dependent definition.
- Independent caller fixtures agree on definitions, outcomes and permission
  failures. Test revocation, interrupted provisioning/publication, missing
  dependencies and object/dependency counts beyond resident caches.
- Snapshot/transaction fixtures distinguish consistent from independent cuts,
  include accepted unflushed data, and establish the selected isolation profile
  under concurrent data/schema changes without promising unsupported atomicity.
- The handbook states each object's executable lifecycle and demonstrates how
  to distinguish defined, published, pending, complete and unavailable evidence.
  These are review questions; the implementation must define exact status types.

## Boundaries and follow-on work

This milestone does not add automatic maintained-query scheduling, arbitrary
cross-resource transactions, historical SQL, branches or a universal health
boolean. [Storage hierarchy and `.tseg` segments](02-storage-and-query-performance.md)
replace the underlying B-tree page store and single-sequencer bottleneck;
[managed computations](06-sql-and-dataflows.md) add WAL-driven activation and
service-owned maintenance; [historical catalogs](05-standards-and-catalogs.md)
extend the same identities and interpretation model. The kernel stays generic.
Definitions and reads never grant rights or dispatch external effects.
