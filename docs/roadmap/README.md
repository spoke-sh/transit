# Roadmap

This roadmap tracks milestone scope, sequencing, acceptance criteria and
completion status for Transit, ordered by dependencies and explicit delivery
priorities, not delivery dates.
The supporting [development workflow implementation plan](development-workflow.md)
records the completed test directory migration, build reuse and feedback
qualification alongside this product sequence.
Current behavior belongs in the [public reference](../README.md), mechanisms in
[Internals](../handbook/internals/README.md), and executed checks in the
[proof ledger](../history/qualification/README.md). A planned milestone does not establish
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
[qualification plan](27-qualification-and-benchmarks.md#observation-and-consequence-evidence)
defines the proposed measures and comparison method; individual milestones
qualify their contribution as they land. These are evaluation goals, not current
measurements, and they do not assume that modeling or reasoning is solved.

## Performance ambition

Our ambition is to make Transit the fastest database and durable runtime for its
supported workloads. Pursue that through measured access paths, efficient data
structures, query planning and runtime execution, with explicit latency,
throughput, memory and recovery targets. Every claim must name its workload,
comparison versions, hardware, resource budgets, durability and isolation.
Measure complete outcomes and sustained mixed load, including background work;
component throughput alone does not establish application performance.

The [indexing milestone](08-indexing-and-access-paths.md) establishes safe shared
access paths. The [data structures and performance milestone](10-data-structures-and-performance.md)
delivers the local workload scorecard, selected optimizations and regression
budgets. Earlier owners establish baselines and meet their existing gates; later
providers, distributed execution and language surfaces extend the same measures.
[Final qualification](27-qualification-and-benchmarks.md) combines the evidence
at one revision. Publish wins, regressions and unresolved competitive gaps with
reproducible results; correctness, current authorization and accepted-work
recovery remain part of every performance profile.

## Delivery phases

Six phases group the linear milestone sequence by the capability an application
or operator gains. The phase outcomes summarize their milestones' acceptance
criteria; each numbered milestone remains the owner of scope, status and proof.
Read the [delivery checkpoints](#delivery-checkpoints) for the execution plan.

| Phase | Milestones | Exit outcome |
| --- | --- | --- |
| [I: Local data and application foundations](#phase-i-local-data-and-application-foundations) | 1–8 | Applications declare and query local data, consume complete statement outcomes, compose supported transactions and use shared clients with exact historical interpretation and maintained indexes |
| [II: Data composition, performance and interface coverage](#phase-ii-data-composition-performance-and-interface-coverage) | 9–14 | Applications maintain derived data, meet measured local database/runtime performance targets, compose native and foreign models, work across branches and use the qualified service/SDK matrix with selected formal models and implementation correspondence |
| [III: Distributed durability and operations](#phase-iii-distributed-durability-and-operations) | 15–18 | Operators use qualified providers, replicate and recover complete history, perform verified backup/restore/upgrades and move execution safely |
| [IV: Governed collaboration and Board](#phase-iv-governed-collaboration-and-board) | 19–22 | People and applications inspect published resources, propose and review changes under shared policy and use the installed Board workbench |
| [V: Agents and mixed application composition](#phase-v-agents-and-mixed-application-composition) | 23–26 | Agents and applications use governed MCP access, reactive activation and recorded effects through complete direct, Station and mixed language experiences |
| [VI: Qualification and release](#phase-vi-qualification-and-release) | 27–28 | One committed revision has combined workload/fault evidence, verified distribution artifacts and runnable installed onboarding |

Phases are delivery groupings, not additional runtime dependencies or release
dates. Contract work and implementation may overlap when the owning prerequisites
are satisfied; an adapter exposes only qualified capabilities. A phase is complete
only when every milestone it contains is complete. Focused correctness, recovery
and performance checks remain acceptance gates throughout the sequence; phase VI
combines that evidence at one revision.

## Milestone sequence

### Phase I: Local data and application foundations

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 1 | [Data identities, declarations and commit contracts](01-declarative-data-lifecycle.md) | Completed ([#108](https://github.com/spoke-sh/transit/issues/108)) | Neutral data/definition identities, lifecycle operations, atomic-domain/isolation decisions and snapshot contracts before dependent formats |
| 2 | [Local durable storage, `.tseg` segments and bounded queries](02-storage-and-query-performance.md) | Completed ([#109](https://github.com/spoke-sh/transit/issues/109)) | Durable native local WAL/object storage across all owners, bounded segments/readers, logical history, codecs/collations and safe local publication |
| 3 | [Executable data lifecycles and live storage/SQL cutover](03-live-storage-and-sql-cutover.md) | In Progress ([#110](https://github.com/spoke-sh/transit/issues/110); [implementation plan](03-live-storage-and-sql-cutover.md#implementation-plan--2026-10-27)) | Installed direct Table and named KV/Document/computation lifecycles, lazy `.tseg` schema projection, local storage/SQL wiring and exact restart recovery |
| 4 | [SQL statement results and client consumption](04-statement-results-and-consumption.md#implementation-plan) | Planned | Formal transport-independent result model, shared client consumption, bounded batches/readers and verified completion |
| 5 | [Transactions, consistent snapshots and atomic composition](05-transactions-and-atomic-composition.md) | Planned | Consistent reads, supported multi-object SQL/SDK transactions, savepoints, durable commit recovery and transactional outbox |
| 6 | [Shared client foundation and language-native APIs](06-client-foundation-and-language-apis.md) | Planned | Reusable data packages, bounded shared client infrastructure and idiomatic direct APIs before SDK expansion |
| 7 | [Standards, collations and historical catalogs](07-standards-and-catalogs.md) | Planned | Capability evidence, declarative `CHECK`/`FOREIGN KEY` catalog bindings, collation-preserving history and exact retained catalog/data interpretation |
| 8 | [Indexing model, access paths and online maintenance](08-indexing-and-access-paths.md) | Planned | Shared index definitions, bounded ordered/covering/partial access, fine-grained key-range SSI conflict tracking, index-backed `FOREIGN KEY` enforcement and recoverable online index/table builds |

### Phase II: Data composition, performance and interface coverage

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 9 | [Managed computations and WAL-activated dataflows](09-sql-and-dataflows.md) | Planned | Complete analytical SQL (window functions, CTEs, subqueries, multi-way joins, sandboxed UDFs), bitemporal `AS OF JOIN`, `CHANGES(...)` CDC egress and WAL-driven managed computations |
| 10 | [Data structures, query optimization and runtime performance](10-data-structures-and-performance.md) | Planned | Measured structures, statistics/costing, declarative partitioning/clustering keys, LSM/`.tseg` compaction bounds, scan-resistant caching and comparative workload scorecards |
| 11 | [Multi-model and multi-format foreign relations](11-multi-model-and-foreign-relations.md) | Planned | Document/graph projections, native BM25 full-text and vector/hybrid search, foreign formats, streaming CDC ingress and typed COPY/import/export |
| 12 | [Branches, merges and restore](12-branches-merges-and-restore.md) | Planned | Durable multi-commit branches, logical three-way merge with `FOREIGN KEY`/`CHECK` verification, branch-aware compaction/GC and forward restore under current authority |
| 13 | [Service and SDK coverage](13-service-and-sdk-coverage.md) | In Progress | Preserved Go raw/console slices and broader service, language, type and platform coverage over the shared API foundation |
| 14 | [Formal semantics and implementation correspondence](14-formal-semantics-and-correspondence.md) | Planned | Selected temporal models and algebraic proofs over delivered local contracts, connected to production behavior before distributed extensions |

### Phase III: Distributed durability and operations

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 15 | [Storage providers and concurrent-writer qualification](15-storage-providers-and-concurrency.md) | Planned | Real provider/cache profiles, KMS/BYOK envelope encryption at rest, enforceable partitioned authority and distributed fine-grained concurrent-writer qualification |
| 16 | [Replication and durable failover](16-replication-and-failover.md) | Planned | Complete replicated history, transaction decisions and objects, bounded catch-up and fenced failover |
| 17 | [Operations, backup, restore and upgrades](17-operations-and-recovery.md) | Planned | Verified transaction-consistent backups/PITR, authority-safe disaster recovery, upgrades and operational workflows |
| 18 | [Clustered execution and storage-disaggregated placement](18-clustered-execution.md) | Planned | Fenced placement changes and distributed queries preserving qualified transaction, replication and operational contracts |

### Phase IV: Governed collaboration and Board

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 19 | [Enterprise identity and the Control & Policy Plane](19-control-and-policy-plane.md) | Planned | Trusted enterprise identity, security-barrier RLS, dynamic column masking, GDPR crypto-shredding/purge, Hierarchical Workload Management (WLM) and shared branch/publication policy |
| 20 | [Published business resources and consistent investigations](20-published-resources-and-investigations.md) | Planned | Deliberate resource exposure, disclosure policy and retained multi-call investigation bases |
| 21 | [Versioned proposals and reviewed publication](21-reviewed-data-collaboration.md) | Planned | Comparable branch proposals, branching-only policy and exact reviewed publication |
| 22 | [Board reimplementation and data-first workbench](22-board-reimplementation.md) | Planned | Installed catalog, previews, workbooks, lineage and governed change workflows over shared contracts, with bounded accessible UI and preserved operational inspection |

### Phase V: Agents and mixed application composition

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 23 | [MCP service and interactive Apps](23-mcp-service-and-apps.md) | Planned | Authenticated agent access and optional Apps over shared published capabilities |
| 24 | [Reactive context, subscriptions and agent activation](24-reactive-context-and-agent-activation.md) | Planned | Meaningful change conditions, durable interests and governed version-bound hybrid context through subscriptions/tasks |
| 25 | [Recorded outbound MCP and application guidance](25-recorded-mcp-integrations.md) | Planned | Governed outbound MCP, captured observations, network-free replay and reviewed application guidance |
| 26 | [Language-native programming model and mixed application composition](26-programming-model.md) | Planned | Complete language-native direct, Station and mixed composition over the earlier client/transaction foundation |

### Phase VI: Qualification and release

| Order | Milestone | Status | Intended outcome |
| --- | --- | --- | --- |
| 27 | [Qualification and complete benchmarks](27-qualification-and-benchmarks.md) | Planned | Combined common-revision workload/fault evidence, full benchmarks and measured CI costs |
| 28 | [Release distribution](28-releases.md) | Planned | Versioned verified artifacts, matching documentation and runnable installed onboarding |

Performance measurement and amplification work remains tracked in
[issue #76](https://github.com/spoke-sh/transit/issues/76), alongside the reopened
milestone trackers above.
Standards, multi-model and branching work is tracked in
[issue #31](https://github.com/spoke-sh/transit/issues/31).

## Delivery checkpoints

This is the execution plan within the [delivery phases](#delivery-phases). Work
within a checkpoint may overlap when shared contracts are settled; implementation
and acceptance retain the numbered owners.
Resolve contract dependencies before code, and close delivery against executable
evidence rather than assuming every preceding number is a technical dependency.

| Phase | Checkpoint | Owners | Concrete execution and exit gate |
| --- | --- | --- | --- |
| I | Define identities and commit truth | 1; #125/#111/#112 | Resolve atomic domains/isolation, snapshot/WAL roots, publication decisions, native owners (#126), feeds/pins (#127), layouts/codecs (#128/#118), provider trust (#117/#121) and current-v1 migration before dependent formats |
| I | Establish the local system | 2–3; #113–#116/#119/#120/#122/#124 | Qualify local disk storage, complete native persistence, direct Table and named resource/computation lifecycles; prove installed WAL-only commits, controlled flush, bounded reads and exact restart recovery without Ursula/MinIO |
| I | Deliver statement and transaction experiences | 4–5 | Shared result lifecycle first; then supported multi-object transactions, consistent reads, savepoints, isolation/decision evidence and outbox recovery. Design provisional results and commit attribution together |
| I | Establish the application API foundation | 6 | Extract shared data packages, compose bounded client/host infrastructure and qualify representative installed language APIs with original-operation recovery before SDK expansion |
| I | Retain exact data interpretation | 7 | Qualify historical catalog/data bindings, declarative `CHECK`/`FOREIGN KEY` constraints, lazy `.tseg` schema projection, collation and encoding fidelity, current permissions and explicit capability evidence over the earlier snapshot contracts |
| I | Declare and maintain indexes | 8 | Qualify ordered, covering and partial access, fine-grained key-range SSI conflict tracking, index-backed `FOREIGN KEY` enforcement, online index/table build recovery and snapshot-specific coverage through shared callers |
| II | Maintain declared computations | 9 | Qualify complete analytical SQL (windows, CTEs, subqueries, multi-way joins, sandboxed UDFs), bitemporal `AS OF JOIN`, `CHANGES(...)` CDC egress, service-owned activation, complete-commit change consumption, bounded operator state and recovered completed revisions |
| II | Optimize database and runtime work | 10 | Establish workload/competitor baselines and numeric budgets, compare structures, deliver statistics/planning, partitioning/clustering keys, LSM/`.tseg` compaction bounds, scan-resistant caching and runtime improvements, and pass installed correctness/resource/performance gates |
| II | Compose data models and history | 11–12 | Qualify foreign COPY/projections, streaming CDC ingress, native BM25 full-text and vector/hybrid search, multi-commit branches, branch-aware compaction/GC and conditional forward publication with `FOREIGN KEY`/uniqueness/constraint evidence and measured costs |
| II | Expand qualified interfaces | 13 | Extend the language/service/platform matrix over the existing foundation; preserve delivered Go raw and console evidence and reject unsupported transaction/feed profiles |
| II | Establish formal semantics and correspondence | 14 | Select settled local contracts, execute temporal/algebraic checks with implementation replay or independent fixtures, challenge them with negative controls and assign later extensions |
| III | Qualify distributed infrastructure | 15–18 | Real providers, KMS/BYOK envelope encryption at rest and writer fencing/fine-grained distributed SSI, then replication, backup/PITR/upgrade procedures and automatic placement/distributed queries; repeat transaction and native-owner recovery across each failure profile |
| IV | Establish governed collaboration contracts | 19–21 | Enterprise identity, security-barrier RLS, dynamic column masking, GDPR crypto-shredding/purge, Hierarchical Workload Management (WLM), published resources/investigations and exact reviewed publication through independently usable public owners |
| IV | Reimplement the Board workbench | 22 | Deliver the installed data-first interface, bounded profiles/workbooks/lineage and separately authorized change review; preserve operational inspection and prove real browser/recovery journeys |
| V | Extend agent-host interfaces and activation | 23–25 | MCP/Apps, reactive context and recorded outbound MCP over shared owners; no dependency on Board's frontend or configured credential |
| V | Prove complete application composition | 26 | Installed direct, Station and all mixed capabilities in every claimed language; transaction/turn/checkpoint/effect boundaries and recovery remain explicit |
| VI | Qualify and distribute one revision | 27–28 | Compose workload/fault/performance evidence at one committed revision, then immutable artifacts, matching docs and installed onboarding. Focused correctness gates remain mandatory earlier |

Track first-three-milestone acceptance and explicitly transferred scope through
#108/#109/#110 and the component issues. Update tracker ownership and links with
this sequence; retain original diagnoses, delivered evidence and incomplete
checks. #123 corrects current documentation as implementation changes, and #124
owns traceable installed acceptance. No planning edit changes their runtime status.

## Enterprise database and governance review — 2026-10-25

An architectural review of the 28-milestone plan against enterprise HTAP,
zero-copy branching and governed multi-agent database requirements identified
ten capabilities that needed explicit ownership within the existing sequence:

1. **Fine-grained Serializable Snapshot Isolation (SSI / key-range conflict tracking):**
   [Milestone 5](05-transactions-and-atomic-composition.md) retains conservative
   whole-Table read conflict validation for its initial local slice, while
   [Milestone 8](08-indexing-and-access-paths.md) and
   [Milestone 15](15-storage-providers-and-concurrency.md) explicitly own the
   progression to index-range and predicate-level conflict detection so concurrent
   read-write transactions touching disjoint keys on shared Tables commit without
   false whole-Table aborts.
2. **LSM/`.tseg` compaction invariants, branch-aware GC and multi-dimensional clustering:**
   [Milestone 10](10-data-structures-and-performance.md) owns leveled/size-tiered
   `.tseg` overlap bounds ($K_{\max}$), `.tdel` tombstone compaction thresholds
   and declarative `PARTITION BY` / `CLUSTER BY` (including Z-order/Hilbert sort
   keys decoupled from primary keys); [Milestone 12](12-branches-merges-and-restore.md)
   owns branch-aware compaction and shared-segment garbage collection watermarks.
3. **Security-barrier Row-Level Security (RLS), Column-Level Security (CLS) / dynamic masking and GDPR crypto-shredding:**
   [Milestone 15](15-storage-providers-and-concurrency.md) owns authenticated
   encryption at rest and KMS/BYOK per-tenant/per-subject envelope encryption over
   `TransitLog` and `.tseg`/`.tdel` objects;
   [Milestone 19](19-control-and-policy-plane.md) owns security-barrier RLS
   (preventing side-channel leakage via 5-state `type_error`, division-by-zero or
   zone-map/index statistics), dynamic column masking and auditable cross-branch
   crypto-shredding/purge workflows.
4. **Declarative `FOREIGN KEY` and `CHECK` relational integrity:**
   [Milestone 7](07-standards-and-catalogs.md) owns catalog bindings and dependency
   graphs for `CHECK` and `FOREIGN KEY` constraints;
   [Milestone 8](08-indexing-and-access-paths.md) owns index-backed transaction
   enforcement; and [Milestone 12](12-branches-merges-and-restore.md) validates
   referential integrity across 3-way branch merges.
5. **First-class bitemporal SQL (`AS OF JOIN` and application-time periods):**
   [Milestone 9](09-sql-and-dataflows.md) and
   [Milestone 10](10-data-structures-and-performance.md) pair `FOR SYSTEM_TIME AS OF`
   with declarative valid-time periods (`PERIOD FOR valid_time`) and streaming
   $O(N + M)$ `AS OF JOIN` merge execution so point-in-time backtesting and
   decision audits never leak later corrections into earlier simulated decisions.
6. **Complete analytical SQL and deterministic in-engine UDFs:**
   [Milestone 9](09-sql-and-dataflows.md) and
   [Milestone 10](10-data-structures-and-performance.md) explicitly enumerate
   multi-way/non-equi/`SEMI`/`ANTI`/`LATERAL` joins, correlated subquery
   decorrelation, window functions (`OVER (...)` / `QUALIFY`), CTEs (`WITH` /
   bounded `WITH RECURSIVE`), set operations, rich aggregates, external NVMe
   spill and sandboxed scalar/table UDFs (SQL macros and deterministic Wasm
   kernels running over `Fuze` vectors without actor-mailbox round-trips).
7. **Native segment-backed Full-Text Search (BM25) and Vector / Hybrid Retrieval:**
   [Milestone 11](11-multi-model-and-foreign-relations.md) and
   [Milestone 24](24-reactive-context-and-agent-activation.md) own immutable
   inverted full-text segments (BM25) and `.tseg` vector/ANN similarity indexes
   so lexical, semantic and relational queries execute under a single `SnapshotId`,
   branch and `policy_epoch` without exporting data to external search/vector stores.
8. **Hierarchical Workload Management (WLM) and scan-resistant caching:**
   [Milestone 10](10-data-structures-and-performance.md) owns scan-resistant
   buffer-pool/NVMe eviction (2Q/ARC/W-TinyLFU) and background I/O token buckets;
   [Milestone 19](19-control-and-policy-plane.md) owns multi-tenant WLM resource
   groups isolating OLTP writes, interactive Board/SQL queries, continuous
   dataflows, background compaction and autonomous MCP agent bursts.
9. **Lazy `.tseg` schema projection and online phased table rewrites:**
   [Milestone 3](03-live-storage-and-sql-cutover.md) and
   [Milestone 7](07-standards-and-catalogs.md) project historical `.tseg`
   `DefinitionId` layouts and 5-state `missing`/default cells lazily on read for
   compatible `ALTER TABLE` operations, while
   [Milestone 8](08-indexing-and-access-paths.md) executes physical type/collation
   rewrites through the recoverable online snapshot-to-tail lifecycle.
10. **Continuous Change Data Capture (CDC) ingress and `CHANGES(...)` SQL egress:**
    [Milestone 9](09-sql-and-dataflows.md) exposes committed deltas via a
    `CHANGES(table, ...)` table-valued function, and
    [Milestone 11](11-multi-model-and-foreign-relations.md) delivers governed
    streaming CDC ingress adapters (PostgreSQL logical replication, MySQL binlog,
    Debezium/Kafka CDC envelopes) with watermark and checkpoint recovery.

All 28 milestone numbers, phase boundaries and existing statuses remain unchanged.
This planning update establishes delivery ownership and acceptance criteria, not
implemented runtime support.

## Formal semantics and correspondence review — 2026-10-25

Add [formal semantics and implementation correspondence](14-formal-semantics-and-correspondence.md)
as milestone 14, closing phase II after service/SDK coverage and before provider
qualification. The local system's storage, statement/transaction, index, dataflow,
selected-structure and branch contracts must settle before this work selects its
models. Earlier correctness and recovery gates remain with their owners; in
particular, this insertion adds no formal-model prerequisite to the upcoming
statement-result work.

The milestone preserves seven temporal and six algebraic candidate families from
the reviewed Argon discussion, including motivating schedules, proposed laws,
implementation connections and corrections to premature algorithm/guarantee
assumptions. Its provenance and self-contained candidate descriptions live in the
milestone. Scope selection requires actual executable models/proofs and production
correspondence; neither an inventory alone nor thirteen predetermined filenames
is the completion criterion. Distributed fencing/replication and enterprise
policy/approval extensions retain later owners once their contracts settle.

The sequence now has 28 milestones in six contiguous phases. Former milestones
14–27 move to 15–28 with statuses, delivered scope and evidence preserved.
Phase II expands to 9–14; subsequent phase ranges, checkpoints and inbound links
move together. Final qualification combines the selected formal suites with
installed workload and physical-fault evidence at one revision. This planning
change implements no model, selects no runtime algorithm and establishes no new
proof result.

## Indexing, performance and phase review — 2026-10-25

The review at `8309a0dc` combines the indexing/lifecycle assessment with the
hardware-conscious data-structure discussion. Add
[indexing](08-indexing-and-access-paths.md) at the end of phase I, after transaction
and historical/collation semantics, and
[data structures, query optimization and runtime performance](10-data-structures-and-performance.md)
in phase II after managed computations. Neutral index/constraint contracts begin
with the foundations; basic storage and transaction guarantees remain earlier
acceptance obligations. Online index maintenance uses qualified storage feeds
without requiring the later general dataflow scheduler.

The first new owner delivers definitions, query eligibility and recoverable
maintenance, including ordered, covering and deterministic partial-index slices.
The second evaluates trees, filters, bitmaps, hashing, vector execution and
runtime scheduling against explicit workload targets. Algorithms, node sizes,
fixed I/O counts, Bloom-filter rates and concurrency guarantees require scoped
proof and measurement. Immutable sharing does not make branch preparation,
constraint validation or historical correctness free. The runtime scope includes
native messages, Station turns, state, wakeups and recovery as well as SQL.

At that review, the sequence had 27 milestones in six contiguous phases. Former
milestone 8 moves to 9 and former 9–25 move to 11–27. Every previous status, delivered slice
and acceptance obligation is preserved. Provider qualification, replication,
operations and clustered execution remain before enterprise/agent adapters;
Board remains after reviewed publication, and complete mixed composition remains
after recorded outbound MCP. This planning change establishes no new executable
index syntax, transaction profile or measured performance result.

The earlier dated reviews below retain their then-current milestone numbers;
links resolve to the current owning files. The [milestone sequence](#milestone-sequence)
and [delivery checkpoints](#delivery-checkpoints) give the current delivery order.

## Board reimplementation review — 2026-10-24

The review at `f699e6ad` adds
[Board reimplementation](22-board-reimplementation.md) as milestone 19, after
reviewed publication and before MCP/Apps. [Board data D2](../design/board-data/D2.md)
defines a focused data-first direction, but its prototype and screenshots do not
deliver the installed interface. The new milestone owns that cutover, including
public API projections, the frontend, accessibility, preserved operational
inspection and real browser/recovery evidence.

The full experience consumes published investigations and exact proposal/review
contracts from milestones 17–18. Building the human workbench before agent-host
adapters is a delivery priority, not a dependency of MCP on Board. Basic catalog,
preview and shell work can land against earlier qualified owners. Existing Board
migrations, service parity and inspection obligations stay with those owners;
the new milestone must not become a reason to postpone them.

Milestone 18 retains bounded comparison, approval and publication operations
usable without a browser; milestone 19 owns their complete Board presentation.
Later reactive context and mixed-language composition are not prerequisites for
the Board cutover. The sequence at that review had 25 milestones: the former 19–24 move to
20–25, with every existing status and acceptance obligation preserved. This adds
delivery ownership without declaring the D2 workflows implemented or all design
details accepted.

## Transaction model and linear execution review — 2026-10-24

The review at `7f9343cc` adds [transactions](05-transactions-and-atomic-composition.md)
immediately after statement results, separates the
[client foundation](06-client-foundation-and-language-apis.md) from later
[complete mixed composition](26-programming-model.md), and gives
[provider/concurrent-writer qualification](15-storage-providers-and-concurrency.md)
an explicit delivery owner. That review produced 24 milestones; the Board review
above adds the 25th. All four existing In Progress statuses and all delivered
evidence are preserved; moving
unfinished work establishes no completion or new supported behavior.

Transaction design covers all experiences together: autocommit/batches, SQL and
typed multi-object transactions, consistent reads, DDL/constraints, Station and
consumer composition, outbox intents, branch publication and uncertain commit
recovery. Serializability within a selected atomic domain is the design target;
the algorithm, real-time ordering and any weaker opt-in profile require explicit
decisions and proof. Multi-partition commit needs participant durability,
visibility and decision recovery, not just a root CAS. No universal nonblocking
execution, zero-I/O savepoint or remote exactly-once promise is implied.

| Previous owner | Current delivery owner and preserved obligation |
| --- | --- |
| 1: combined lifecycle contracts and runtime | 1 retains neutral contracts/metadata; 3 receives the complete direct Table, named KV/Document and computation integration, including #111/#119/#120 and original #108 caller evidence |
| 2–3: local foundation interleaved with provider/writer expansion | 2 retains local correctness, codecs and bounded storage; 3 qualifies installed local lifecycles; 12 receives #117/#121 and corresponding runtime/#124 provider and concurrent-writer proofs |
| 6: transaction sessions inside managed dataflows | 5 owns transactions; 8 retains general SQL composition, MERGE/upsert, prepared plans and managed dataflows, consuming the transaction contract |
| 6–7: typed import/export separate from actual formats | 9 owns typed COPY/import/export and foreign adapters together, using the direct-ingestion and transaction owners |
| 16: all programming-model work after MCP | 6 delivers package/runtime/API foundations before SDK expansion at 11; 23 retains every mixed capability and full per-language Station/composition qualification after outbound MCP at 22 |
| 17–19: replication, operations and clustered execution after MCP | 13–15 preserve their order and scope after provider qualification and branches, before enterprise/collaboration adapters |

Placing infrastructure before enterprise/MCP work is a delivery priority, not a
claim that an authenticated finite adapter technically requires clustered
execution. Likewise, source formats may qualify locally before all cloud
providers; provider-dependent combinations close with milestone 12. Native
authorization and local safety apply from the start; enterprise IAM is an
extension, not the first permission gate. Later capabilities must not become
hidden prerequisites of an earlier milestone's completion.

The first three trackers remain open. #108 retains oversight of its original
installed lifecycle promises through milestone 3; #109 retains oversight of the
provider/writer scope now owned by milestone 12. A later milestone does not
absorb a missing promise without the explicit transfers above. The earlier dated
reviews below preserve the rationale and then-current sequencing. This table
records ownership at that review; the milestone sequence and execution plan
above give the current delivery order.

## Programming model review — 2026-10-24

[Language-native programming and mixed composition](26-programming-model.md)
follows recorded outbound MCP and application guidance. Direct data applications,
Station behaviors and applications combining both need a coherent public model:
shared types, operation identities, results and recovery with explicit execution
scopes. Current raw clients and Station runners are independently usable, but
several ordinary data/query APIs are packaged with Station and expose protocol
orchestration to applications. That review assigned those concerns to one
milestone; the transaction review above now separates its early foundation from
complete mixed qualification.

The Gemini Argon transcript review makes mixed composition concrete: standalone
recorded effects, durable change consumers and typed calls into Station are all
required. That review also required reusable data-package ownership, shared
bounded client infrastructure, recovery/staging helpers and side-by-side language
examples, now divided between the early foundation and later mixed qualification.
Checkpoint progress, turn commits and remote outcomes retain their
separate contracts; an operation key does not establish remote idempotency.

This is distinct from [service/SDK coverage](13-service-and-sdk-coverage.md),
which retains its existing operation and platform obligations. Shared result
semantics remain with [statement results](04-statement-results-and-consumption.md).
The current split requires the early client foundation before expanded SDK
coverage; the later mixed qualification cannot defer those obligations or
introduce another execution protocol. No transparent durability of host tasks or new
cross-resource transaction is implied.

At that review the new milestone was Planned at 16, moving replication through
release from 16–20 to 17–21. Those are historical positions; the transaction
and Board reviews above supersede them while retaining their scope and statuses.

## Result sets, replication and operations — 2026-10-24

[Statement results and client consumption](04-statement-results-and-consumption.md)
follows the live cutover as an independently reviewable SQL service/client
outcome. It covers statement completion, result identity/schema/basis, safe
batching, shared readers and bounded presentation. Storage/query performance
retains encoded execution ownership; the live cutover retains safe bounded
reads and runtime wiring. Their existing promises are not deferred by this split.
Contract work can proceed together. Published resources now consume the earlier
result contract and own disclosure plus retained investigations across calls.

[Replication](16-replication-and-failover.md) and
[operations](17-operations-and-recovery.md) precede
[clustered execution](18-clustered-execution.md). Replication qualifies complete
durable history, object coverage and safe failover for explicit failure profiles.
Operations owns backup/restore, upgrades and maintenance, including the
backup/restore/migration work previously grouped under clustered execution.
Clustered execution adds scheduling and distributed queries, and proves those
operational contracts across placement changes. Branch restore remains logical
data publication under current authority, separate from installation recovery.

This revision inserted three Planned milestones: former milestones 4–14 moved
to 5–15, and clustered execution, qualification and releases moved from 15–17 to
18–20 before the programming-model insertion above. Existing statuses, delivered
slices and proof obligations are preserved. Replication and operational
contract work depends on storage and live runtime foundations, not on every
intervening MCP or collaboration adapter completing first. No backup, replication
topology, result API or upgrade profile is qualified by this planning change.

## Enterprise collaboration and MCP direction — 2026-10-23

The outcome is governed collaboration over versioned, enriched business resources:
people and agents inspect the same evidence, explore alternatives on branches,
and publish changes only under the installation's policy. The
[business stories](../handbook/reference/collaborative-decisions.md) explain that
proposed experience and its current building blocks without requiring this plan.

The 2026-10-23 revision preserved the then-numbered milestones 1–8 and inserted
six collaboration milestones before clustered placement, qualification and
release. The 2026-10-24 revision above inserts result sets and separates
replication/operations; the current table includes the subsequent transaction
and Board reviews as well.
Delivered work and evidence retain their status. These revisions record direction
and acceptance gates, not executed runtime evidence.

The sequence is linear, with explicit prerequisites per milestone. Contract work
and a read-only MCP spike can start before all earlier implementations finish;
an adapter may expose only the capabilities whose owning contracts and evidence
are complete. Native branch operations use current realm authority; milestone 19
adds enterprise identity/delegation integration and milestone 21 adds the shared
proposal/approval experience. A protocol spike does not qualify those additions.

The ownership table below uses the current sequence. Dated insertion records
retain their historical numbers.

| Shared contract | Delivery owner | Required boundary |
| --- | --- | --- |
| Statement outcomes and result consumption | 4 | One typed result lifecycle, bounded readers and verified completion; statement completion is distinct from transaction commit |
| Transactions, snapshots and outbox | 1 contract gates; 5 implementation | Qualified atomic domains/isolation, original decision recovery and atomic local intent publication; external outcomes remain separate |
| Client packages and language APIs | 6, then coverage at 13 | Reusable shared implementation, bounded runtime ownership and idiomatic direct/recovery APIs before adapter expansion |
| Complete application composition | 26 | Direct, Station and all mixed capabilities preserve transaction, turn, checkpoint and effect boundaries across languages |
| Formal semantics and implementation correspondence | 14 | Selected settled local obligations, executable models/theorems, negative controls and production correspondence; later owners extend the qualified assumptions |
| Provider, replication and operational contracts | 15–18 | Enforceable durability/fencing, complete decisions/objects, recoverable backups/upgrades and qualified moving placements |
| Identity, membership, delegation and access decisions | 19 | Trusted actor/subject bindings, current authority and explicit approval powers through every adapter |
| Published resources and retained investigations | 20 | Deliberate exposure, approved disclosure and retained source bases independent of connections/open transactions |
| Branch histories and reviewed proposals | 12, 21 | Frozen base/source/target and candidate; no copied grants/effect rights or protected-destination bypass |
| Board presentation and workflow integration | 22 | Installed catalog/workbook/lineage/change interfaces over public owners; bounded disclosure, read-only inspection and exact recovery |
| MCP and presentation bindings | 23 | Generated descriptors/views over shared owners; exact host/revision matrix and useful fallback |
| Meaningful activation and durable interests | 9, 24 | Complete source commits, completed results and business conditions remain distinct |
| External capabilities and application guidance | 25 | Authorized recorded attempts, capture, uncertainty and network-free replay; instructions confer no authority |

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
| Index definitions, constraints and coverage | [Identities](01-declarative-data-lifecycle.md), [transactions](05-transactions-and-atomic-composition.md), [indexing](08-indexing-and-access-paths.md) | Define index/source identities, comparison and constraint dependencies, snapshot coverage and build/publication lifetimes before dependent formats; later structure selection preserves these contracts. |
| Maintenance and installed operation | [#116](https://github.com/spoke-sh/transit/issues/116), [#122](https://github.com/spoke-sh/transit/issues/122) | Assign flush/checkpoint/compaction/GC ownership, backpressure, shutdown and authorized progress inspection. Resolve runtime composition and the single-binary packaging target explicitly. |

Resolve these interacting contracts in their owning milestone and public topic
as appropriate before dependent code or persistent formats. This is required
engineering work, not an open-ended request for another product-direction review.
Unsupported combinations must be rejected explicitly. Any later scope change
must update the owner, linked issues and acceptance criteria together.

The native local profile is the first delivery checkpoint, with no Ursula or
MinIO dependency for either application or control state. The distributed
reference remains disk-backed Ursula plus S3 on Compose and Kubernetes/Substrate.
Kafka/Pulsar and GCS/R2/Azure remain explicit target coverage in milestone 15;
each needs its own provider contract and evidence, or an explicit recorded move
in scope. They are not assumed interchangeable implementations. Provider and
concurrent-writer implementation is explicitly transferred to milestone 15.
Native codec correctness and local publication safety remain milestone 2
requirements; no original tracker closes merely because its work was split.

## Architectural direction across the sequence

1. **Define declarative operations independently of the actor turn ceremony ([Milestone 1](01-declarative-data-lifecycle.md) — Completed).**
   Unify catalog identities (`CatalogId`, `DefinitionId`), dependency tracking and
   policy bindings across Tables, KV, Documents and named computations. Route
   data-plane DDL/DML and batch ingestion directly through the catalog and
   storage boundary instead of cycling every row through the `4 × 256B` metadata /
   `128 KiB` block actor-turn loop (`open_view -> commit_turn`), reserving
   `Station` actor turns for stateful process behavior and effect orchestration.
2. **Replace B-tree-over-JSON-streams with a four-tier storage hierarchy and `.tseg` segments ([Milestone 2](02-storage-and-query-performance.md) — Completed).**
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
   **Multi-Writer OCC** in [provider/writer qualification](15-storage-providers-and-concurrency.md),
   over authorized conditional publication. The native local foundation remains
   milestone 2; distributed-provider and writer integration belongs to milestone
   15. Formal progress and metadata-complexity claims require scoped evidence.
3. **Declare safe access paths ([Milestone 8](08-indexing-and-access-paths.md)).**
   Bind index definitions, key/collation semantics, transaction maintenance and
   historical coverage to public owners. Deliver recoverable online builds,
   bounded primary/secondary reads and inspectable planner eligibility without
   introducing a second catalog or permission authority.
4. **Optimize the database and durable runtime ([Milestone 10](10-data-structures-and-performance.md)).**
   Use workload contracts and comparative baselines to select trees, filters,
   bitmaps, hash tables and vector/runtime strategies. Deliver statistics and
   cost-based plans, measure complete durable operations under mixed load, and
   enforce latency, throughput, memory and recovery budgets throughout later work.
5. **Cut over live executables and activate derived views, multi-format foreign sources, branches and clustered compute ([Milestones 3](03-live-storage-and-sql-cutover.md)–[18](18-clustered-execution.md)).**
   Wire the storage hierarchy, `.tseg` segments, write-through caches and immediate
   wakeups into the live node, SQL gateway and server executables; formalize shared
   statement outcomes, bounded result consumption, transactions and early client
   APIs; bind historical catalog snapshots to immutable manifest versions and collations;
   drive maintained SQL views, reactive watches and Station processes directly
   from `TransitLog` (`+row`/`-row`) delta streams; read Parquet, Arrow IPC,
   CSV/JSONL and mainframe fixed/variable (`FB`/`VB`) copybook datasets through
   the shared `Fuze` segment boundary; implement branch creation over complete
   durable snapshots and logical three-way merges over immutable state; qualify
   replication, backup/restore and upgrades; and schedule distributed Station and
   `Fuze` workers over shared object storage with fenced lease handoff.

Handbook publication is implemented. Remaining live-site navigation and recovery
qualification belongs to [qualification](27-qualification-and-benchmarks.md#documentation-publication),
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
  compute, transport and publication costs separately. Set workload performance
  budgets before optimization, retain correctness oracles and publish comparable
  latency/throughput, memory, amplification and recovery evidence for each slice.
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

Keep one numbered, descriptively named file per milestone (`01-` through `28-`).
Insert or reorder work by updating this index, filenames and links together.
Split work only when it has independently reviewable outcomes and prerequisites.
Keep phase membership contiguous and exhaustive: each milestone appears exactly
once in the ordered sequence. Update the phase overview, milestone groups and
delivery checkpoints together when inserting or moving work. Phase labels and
boundaries describe delivery outcomes; they do not replace numbered milestone
identities, change completion evidence or introduce implicit prerequisites.

When a milestone is complete, keep its file in `docs/roadmap/` and update its
status to `Completed` in both the milestone header and the sequence above, while
promoting all current user-facing behavior and reasoning into its public
handbook owner and recording executed verification in `tests/README.md`.
If review finds an unmet completion criterion, reopen the milestone as
`In Progress`, preserve delivered work and prior evidence, and link the remaining
acceptance work. Merged code, parser support and component tests do not substitute
for the milestone's executable caller and recovery evidence.
