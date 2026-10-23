# 1. Data identities, declarations and commit contracts

[Roadmap](README.md) · [Current data model](../handbook/reference/data-model.md) · [Tracker #108](https://github.com/spoke-sh/transit/issues/108) · **Status:** In Progress

Define how an application describes data, schemas, computations and policies,
and how public operations bind that declaration to identities, dependencies,
authority, accepted changes and observable outcomes. Establish neutral contracts
before storage formats and runtime integration depend on them.

The 2026-10-24 sequencing review separates this contract/metadata foundation from
the installed lifecycle implementation in [milestone 3](03-live-storage-and-sql-cutover.md).
The original direct Table, named KV/Document and computation-lifecycle acceptance
obligations transfer explicitly to that owner; #108 continues tracking both
the foundation and those outstanding outcomes. This milestone remains In Progress.
Neither the split nor a contract fixture completes the original executable scope.

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

The issues retain their original work and proof obligations. #125 and the
neutral contract portions of #111/#119/#120 belong here; executable direct Table,
named resource and computation integration belongs to
[milestone 3](03-live-storage-and-sql-cutover.md#installed-lifecycle-integration).
Native codec execution stays with [storage](02-storage-and-query-performance.md).
Automatic scheduling remains later scope.
The transcript review is complete and this planning revision is authorized.
The [shared contract gates](README.md#firm-scope-and-contract-gates) identify
engineering decisions that must precede dependent implementation.

## Implementation in progress

The feature branch supplies the neutral data operation/snapshot contract, local
native persistence and a default local launcher backed by the native local
owner. Its direct Table storage component has atomic point/bulk acceptance,
paged row/receipt/pin indexes, bounded flushes, durable read pins and
CREATE/ALTER/RENAME/DROP definition transitions under the existing native
authorization fence. The scoped [executed evidence](../../tests/README.md#table-definition-acceptance-and-retained-interpretation--2026-10-22)
distinguishes these component and native-adapter checks from public integration.

The direct catalog component now reserves names and records durable DDL
admission/rejection/cancellation, with name visibility governed by the Table
acceptance record. Its [component evidence](../../tests/README.md#direct-catalog-reservations-and-table-publication--2026-10-22)
covers lost replies, restart, replacement and growth beyond the resident cache.
The Table owner also retains frozen row work, durable admission/rejection/
cancellation, matched/changed counts and atomic primary-key replacement. Its
[component and native policy evidence](../../tests/README.md#durable-table-row-admission-and-outcomes--2026-10-22)
covers restart, lost replies, quota pressure and current rights. A configured
local node now serves signed typed requests directly over HTTP and resumes native
registration under the original caller's fence. The [public HTTP proof](../../tests/README.md#direct-table-http-owner-and-typed-caller--2026-10-22)
covers a 64 KiB point row, bulk `.tseg` publication, exact lost-reply recovery,
restart, an unflushed retained pin and current revocation. Its subsequent
[CRUD/DDL recovery run](../../tests/README.md#direct-table-crudddl-recovery--2026-10-23)
also covers UPDATE, DELETE, ADD COLUMN, RENAME, DROP and name reuse with retained
schemas and exact outcomes across a second restart. [Read-only DDL preview](../../tests/README.md#direct-table-preview--2026-10-23)
checks current policy, expectations and schema work without claims or admission.
The [typed finite SQL owner](../../tests/README.md#finite-sql-over-retained-direct-tables--2026-10-23)
now executes Fuze filtering/aggregation over retained direct sources with current
disclosure checks. The direct Table owner also accepts frozen typed SQL
UPDATE/DELETE plans with bounded private selection and one atomic outcome.
Read-only exact-definition and action checks support prepared bindings without
raw-storage inspection credentials. Parameterized DML templates produce complete
saved direct intents with explicit admission and recovery.

SQL's control ledger now publishes exact intent references and commits dispatch
eligibility before direct admission, replacing its actor row-upload/saved-step
path. Its current session adapters use direct prepared reads and mutations.
A durable local pin journal preserves interrupted acquisitions and closure;
relational reads use stable row-identity traversal and explicit independent Table
cuts. [Recovery and binding evidence](../../tests/README.md#direct-sql-references-and-read-recovery--2026-10-23)
covers those component and HTTP paths, including lost pin replies, replacement,
current denial and definition changes that preserve column schemas.

Conditional name-only DDL now has a distinct catalog assertion path and SQL
ledger representation; it carries a catalog acceptance position without
fabricating a Table commit. Its [component and HTTP evidence](../../tests/README.md#conditional-sql-catalog-outcomes--2026-10-23)
covers the SQL compiler, lost replies, restart, cancellation and name reuse.

The default launcher now provisions the direct catalog with a dedicated native
registrar and retains the exact initial Table intent. The
[installed proof](../../tests/README.md#installed-direct-table-bootstrap--2026-10-23)
passes CRUD/DDL while the query worker is stopped, abrupt restart and deliberate
default-Table deletion/name reuse. A separate
[execution fault proof](../../tests/README.md#installed-direct-execution-recovery--2026-10-23)
keeps new-console inspection, reads and cancellation available while direct
execution is refused, preserving the original write across caller/manager loss.
The [broader installed lifecycle and capacity proofs](../../tests/README.md#installed-direct-lifecycle-rollback-and-capacity--2026-10-23)
also pass against the direct boundary, including revocation, native-history
rollback refusal and original-write recovery after physical exhaustion.
The [physical representation proof](../../tests/README.md#lossless-physical-column-admission-and-public-sql--2026-10-23)
now checks supported codec ranges, complete CP037 conversion, signed floating
zero, unsupported-profile rejection and SQL equivalence over retained WAL/segment
cuts. Incompatible physical schemas/pages use replaced current-v1 definitions.
The [neutral-schema caller proof](../../tests/README.md#neutral-physical-schemas-across-language-callers--2026-10-23)
now preserves explicit encoding/collation fields across ten language bindings,
with independent bytes/fingerprints and strict missing-field rejection. Non-binary
SQL collation remains unsupported.
The [administration and database-client proof](../../tests/README.md#direct-catalog-administration-and-installed-database-clients--2026-10-23)
also resolves policy plans through the direct catalog and qualifies explicit
grants/revocation and retained recovery through real PostgreSQL/MySQL clients.
The [scoped read-delegation proof](../../tests/README.md#scoped-direct-table-read-delegation--2026-10-23)
now qualifies original-caller grants for one executor, exact Table cut and pin
owner, including uncertain acquisition/closure and retained reads after restart.
The [captured-query recovery proof](../../tests/README.md#direct-captured-table-queries-and-separate-cleanup-authority--2026-10-23)
now covers single-source admission, independent progress storage, original-cut
traversal, verified results and cleanup across lost replies and replacement.
Fresh cleanup authorization remains separate from the original execution proof
after credential rotation. All ten installed SDKs now resolve direct definitions,
seal the same captured bundle and read its verified result through that fault
schedule. The captured relational owner now uses the same direct pin protocol
with independent native progress. Its scoped self-join and two-Table proofs pass
replacement, shared alias retention, independent Table partitions, cleanup and
current-source revocation/restoration at result disclosure. Retained source pages
also preserve nested/wide values through Fuze/Arrow after ALTER, DROP and name
reuse, including direct composite-key hit/absence under current rights.
The direct storage/service boundary now has explicit history leases, fixed-bound
logical acceptance pages and exact historical reads. Its
[storage and native-policy evidence](../../tests/README.md#direct-table-history-retention--2026-10-23)
covers restart, no-ops, retention-kind separation and current revocation.
The maintained-query adapter now uses those direct history leases and stores a
separate bounded physical scan cursor. Its [public recovery evidence](../../tests/README.md#maintained-direct-table-queries--2026-10-23)
covers original acquisition recovery, restart inside a physical-only prefix,
initial backfill, independent Table cuts, accepted no-op revisions, paired deltas,
terminal lease cleanup and current result-disclosure rights. The
[direct failure schedule](../../tests/README.md#direct-relational-failure-boundaries--2026-10-23)
also covers work/spill limits, ordered overflow witnesses, prior-result
preservation, explicit history-coverage rejection and bounded captured cleanup.
The [direct exchange proof](../../tests/README.md#direct-table-exchange-placement-and-borrowed-reads--2026-10-23)
now places the receiver independently of Table ownership and uses exact-cut
borrowed reads for a separate producer credential. Initial maintained attachment,
receiver generation replacement, verified output and lease cleanup pass. Multiple
workers, later attachments, broader exchange recovery and maintained
credential-rotation cleanup schedules, older relational
caller fixtures and broader qualification remain unfinished. The full query
package remains unqualified during the cutover.
The [finite capture boundary checks](../../tests/README.md#finite-direct-capture-memory-and-retirement--2026-10-23)
now replace the old Table memory/retirement fixtures. They cover empty retained
sources after DROP, adapter/Arrow exhaustion, preserved large stored rows,
retryable separate-client allocation failures and explicit result retirement.
Native KV/Document capture checks remain in place. A local allocating writer's
failure now requires evidence of adapter exhaustion before closing the query.
Direct namespace lifecycle, relational and remaining caller migration,
dependency contracts, automatic point flushing, named resource
provisioning and computation evidence also remain unfinished. None of the
completion matrix rows below is closed by this partial caller path.

## Catalog, transaction and snapshot scope

[#125](https://github.com/spoke-sh/transit/issues/125) defines the
database/catalog/branch, schema, object and definition hierarchy, its relationship
to partition heads, and supported atomic domains/isolation. A catalog-wide root
must not recreate a global realm CAS for every independent data/process write.
Deliver the complete single-owner Table statement/batch slice first. Specify
the catalog-scoped transaction extension now; its interactive sessions belong
to [transactions and atomic composition](05-transactions-and-atomic-composition.md).
Arbitrary distributed cross-owner transactions are not implied, and native turns
retain their current one-KV-resource atomicity limit.

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
milestone 9.

## Baseline, bottleneck diagnosis and scope

Include neutral index identities and immutable definitions in the catalog
contract before dependent formats. Bind source/column identities, comparison
and collation semantics, constraint dependencies, build generations and exact
coverage to the existing snapshot/publication model. Separate declaration,
maintenance progress and query eligibility. The
[indexing owner](08-indexing-and-access-paths.md) delivers secondary access paths
and online lifecycle; this contract work grants no new executable index syntax.

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

The shared contract establishes these boundaries; milestone 3 delivers their
executable lifecycle integration:

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

1. **Inventory lifecycle contracts.** For Tables, KV, Documents and named
   computations, define stable object/definition identities, names, logical
   types, physical codecs and collations, dependencies, policy references,
   admission, publication, inspection, alteration and retirement. Distinguish
   supported operations, offline compilation and missing execution.
2. **Define neutral operations and commit evidence.** Specify expected
   definition/head, idempotent operation identity, frozen content, accepted
   outcomes and bounded progress. Define direct point/batch/DDL admission apart
   from actor-frame limits. Separate temporary session state from accepted work;
   a timeout cannot establish rejection. Generate schemas and independent
   positive/negative fixtures from owning types, following #112's v1 cutover.
3. **Resolve atomic domains and consistent snapshot roots.** Close #125/#111's
   identity hierarchy, publication linearization, isolation, rollback/uncertainty,
   DDL visibility and read/predicate-conflict decisions before dependent formats.
   Bind exact interpretation, manifests and committed WAL frontiers, including
   unflushed state. Separate independent source vectors from atomic cuts and
   descriptors from durable pins. Specify the multi-object extension delivered
   by milestone 5 without widening native turns implicitly.
4. **Define dependencies, provisioning and computation observations.** Preserve
   current scoped authorization, explicit dependency registration/RESTRICT and
   unlimited-retention defaults. Specify named KV/Document initialization,
   partial provisioning and recovery; bind computation results to exact source
   data and definition revisions. Define unavailable, incomplete, denied and
   stale observations; reading definitions or inspection starts no work.
5. **Land the foundation with explicit implementation owners.** Implement shared
   types, metadata transitions and generated fixtures through their owning
   packages. Assign storage/native persistence to milestone 2 and complete
   installed lifecycle paths to milestone 3. Board projections use public owners
   and their existing UI/capability review boundaries. Publish only actually
   implemented semantics in current references; proposals stay in this plan.

## Completion evidence

- Neutral fixtures and owning types agree on object/definition identity,
  expected heads, operation identity, permissions, outcome and snapshot evidence.
- Specify permitted and forbidden histories, including read/predicate conflicts,
  name/schema replacement, unflushed data and independent versus atomic cuts.
  Record the selected domain and isolation decisions before persistent formats.
- Verify existing metadata operations preserve dependency and access boundaries;
  generated declarations and missing/foreign-definition rejection stay coherent.
- #111/#119/#120/#125 have concrete contracts and the installed caller/recovery
  obligations below are assigned to milestone 3. Do not mark this milestone
  complete until its own contract/implementation evidence exists, or close #108
  before its transferred executable outcomes are qualified.

The original public-caller completion criteria are preserved under
[installed lifecycle integration](03-live-storage-and-sql-cutover.md#installed-lifecycle-integration).
A contract fixture is not that end-to-end evidence.

### Original executable acceptance tracking

The matrix below preserves the original obligations transferred to
[milestone 3](03-live-storage-and-sql-cutover.md#installed-lifecycle-integration).
It does not expand the foundation-only completion criteria above or close #108.

The implementation review uses the following matrix. Descriptor validation and
contract fixtures are a foundation, not closure of the public caller gates.

| Gate | Work owner | Required executable evidence |
| --- | --- | --- |
| Stable identities and exact retry binding | #125, #111 | Lost-reply recovery, altered-content rejection and rename/drop/recreate without retargeting |
| One durable Table acceptance authority | #111, #112 | Point and bulk operations, complete CRUD/DDL, atomic visibility, incompatible-artifact rejection |
| Durable snapshots including unflushed data | #125, #127 | Retained object/WAL coverage, interrupted acquisition, restart and GC/compaction races |
| Named usable resources | #119, #126 | Real KV/Document provisioning, initialization, reads/writes, partial failure and recovery |
| Dependency and policy evidence | #111, #119, #120 | Current rights, redacted blockers, explicit RESTRICT and paged collections beyond cache |
| Actual computation completion and freshness | #120 | Verified output/source binding, row-change detection and inspection without execution |
| Admitted codec/collation semantics | #118, #128 | Independent SQL/storage equivalence and unsupported-profile rejection |
| Installed qualification and current explanations | #122, #123, #124 | Real local artifacts, WAL-only recovery, controlled flushing, caller/fault proofs and accurate public documentation |

The [neutral data contract](../../contracts/DATA_LIFECYCLE_V1.md) defines the
initial single-owner acceptance and snapshot descriptors. Runtime implementation
and qualification remain required for every row above. Shared issues retain
their broader scope after a milestone-specific gate passes.

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

This milestone does not itself deliver the installed lifecycle, transaction
sessions, automatic scheduling, historical SQL, branches or a universal health
boolean. [Local storage and `.tseg` segments](02-storage-and-query-performance.md)
replace the underlying B-tree page store;
[provider/writer qualification](14-storage-providers-and-concurrency.md) delivers
partitioned concurrency;
[managed computations](09-sql-and-dataflows.md) add WAL-driven activation and
service-owned maintenance; [historical catalogs](07-standards-and-catalogs.md)
extend the same identities and interpretation model. The kernel stays generic.
Definitions and reads never grant rights or dispatch external effects.
