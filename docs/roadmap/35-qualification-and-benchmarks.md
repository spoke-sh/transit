# 35. Qualification and complete benchmarks

[Roadmap](README.md) · **Status:** Planned

Turn component coverage into complete workload and release evidence. The
[verification reference](../handbook/reference/verification.md),
[benchmark inventory](../handbook/reference/benchmarks.md) and
[test ledger](../../tests/README.md) own current results. Focused qualification
remains a gate for every preceding milestone.

## Remaining work

- Execute the [SQL grammar, standards comparison and dialect ergonomics corpus](34-sql-grammar-and-dialect-ergonomics.md)
  at the common committed revision: verify zero ANTLR/production grammar
  conflicts, byte-identical `FQP1`/`FDM1`/`FTS1` plan lowering for ergonomic
  desugarings (`FROM`-first queries, `SELECT * EXCLUDE/REPLACE`, `GROUP BY ALL`,
  `ORDER BY ALL`, trailing commas and numeric underscores), stateful dataflow
  lifecycle DDL (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`),
  2-way/3-way `DIFF(...)` and `DIFF_SCHEMA(...)` over `.tseg` segment skipping
  and 5-state `IS CONFLICT` cells, `REMOTE`/`FETCH`/`MIRROR` incremental sync
  and reviewed foreign-dialect diagnostic hints.
- Execute the [formal semantics and correspondence suite](21-formal-semantics-and-correspondence.md)
  with its selected provider, replication, recovery, placement, policy and review
  extensions at the common committed revision. Retain finite bounds, theorem
  premises/axioms, fairness and storage assumptions, implementation projections,
  negative controls and complete tool reports. Recheck each profile's assumptions;
  report unmodeled or deferred claims explicitly. Model exploration, deductive
  proofs, concrete replay and physical experiments remain distinct evidence.
  The local milestone and later owners deliver their focused checks earlier;
  this exercise establishes their combined revision and workload correspondence.

- Compose [index lifecycle](11-indexing-and-access-paths.md) evidence across
  transactions, retained history, branches, providers, failover, backup/PITR and
  moving placements. Include partial/covering reads, unique-key conflicts,
  index-backed `FOREIGN KEY` and `CHECK` enforcement, fine-grained key-range/predicate
  Serializable Snapshot Isolation (SSI), online phased table rewrites,
  segment-backed BM25 full-text and vector/hybrid search, interrupted builds,
  branch-aware compaction and retirement under current authorization.
- Repeat the [data structures, query and runtime scorecard](13-data-structures-and-performance.md),
  [first-class strings, perfect hashing and vectorized search scorecard](14-vectorized-strings-and-search.md),
  [data-centric compilation and specialization scorecard](15-data-centric-compilation-and-specialization.md)
  and [geospatial and spatio-temporal computing scorecard](17-geospatial-and-spatio-temporal-computing.md)
  at the common revision with installed callers, concurrent maintenance and
  durable runtime workloads. Include zero-steady-state-allocation hot-path
  verification, per-morsel CPU/memory/IOPS metering, LeanStore/Umbra-style
  pointer-swizzled variable size-class buffer slabs (with admission-only SHA-256
  verification), CedarDB-style ~10-instruction directory-tagged join hash tables
  and Worst-Case Optimal Joins (WCOJ), 16-byte collation-prefixed Umbra/German
  strings, 16-byte inline spatial headers, `.geoarrow`/`.twkb_delta`/`.topo_arc`/`.s2_roaring`
  spatial codecs and DBSP Z-set incremental `ST_Union` and spatial joins, compressed-domain `.dictionary`/`.fsst` evaluation, `comptime`/immutable
  perfect hashing, vectorized 256-doc Block-Max BM25 and hybrid search, HyPer-style
  data-centric push pipeline fusion, per-row-group dense non-null specialization,
  Flying-Start Adaptive Morsel Tier-Up, `transit-app` AOT-compiled queries/views,
  leveled/tiered `.tseg` compaction bounds, `.tdel` tombstone reclamation,
  declarative partitioning/multi-dimensional clustering (`PARTITION BY`,
  `CLUSTER BY`), scan-resistant caching, external NVMe spill for window/join/sort
  operators and bitemporal `AS OF JOIN` merge execution. Preserve numeric
  budgets, matched competitor versions/configurations (including HyPer, Umbra,
  CedarDB, DuckDB and ClickHouse baselines on the VLDB 2018
  compiled-versus-vectorized microbenchmarks, the Join Order Benchmark (JOB),
  ClickBench and the HTAP CH-benCHmark), raw samples and visible
  failures/regressions. Report leadership only for reproduced equivalent workload
  profiles; a component win or reduced TPC workload is not a universal
  database/runtime ranking.

- Qualify full declaration lifecycles: define data and computation, apply policy,
  inspect publication/results/progress, evolve dependencies and recover accepted
  work after faults. Use independent data/result oracles at exact source bases;
  process health and parser coverage cannot substitute for fulfilled intent.
- Execute required suites at a common committed revision: installed SDKs, protocol
  peers, browsers and selected physical placements. Distinguish failures and
  unexecuted checks from passing evidence.
- Extend deterministic schedules and external faults at new storage, historical,
  branching and distributed boundaries. Save reproducible counterexamples and
  check forbidden outcomes as well as eventual success.
- Qualify [transactions and atomic composition](05-transactions-and-atomic-composition.md)
  across the selected local, provider, replicated and distributed profiles at one
  revision. Use independent history/business-invariant oracles for write skew,
  predicates, partial participants, lost commit replies, savepoints after spill,
  current authorization and outbox recovery. Include retained investigations,
  branch publication, complete dataflow commits and backup/PITR cuts. Earlier
  transaction correctness gates remain required; this is combined qualification.
- Compose the [result-set](04-statement-results-and-consumption.md),
  [replication](23-replication-and-failover.md) and
  [operations](24-operations-and-recovery.md) evidence at the same revision:
  complete/incomplete result delivery, failover, verified backups, restore
  activation and upgrades during real caller workloads and placement changes.
  Their focused acceptance gates remain required before this combined exercise.
- Qualify [direct-client, Station and mixed applications](33-programming-model.md)
  through real installed language packages, including cross-language typed service
  calls, original-operation recovery, explicit commit scopes and bounded host
  scheduling. Compare the same data/outcomes across modes; shared native code
  does not substitute for language-specific ownership and lifecycle evidence.
- Qualify the shared enterprise journey across SQL, SDK, MCP and browser callers:
  delegated identity, authorized resource discovery, security-barrier Row-Level
  Security (RLS) and dynamic column masking, KMS envelope encryption, GDPR/CCPA
  crypto-shredding and audited cross-branch purge, Hierarchical Workload
  Management (WLM) isolation under concurrent OLTP + analytical + MCP agent load,
  one retained investigation basis, isolated branch proposals, denied merges and
  reviewed publication. Include identity-provider outages, stale membership,
  offboarding, side-channel `type_error` non-leakage on RLS-filtered rows, agent
  attempts to approve their own work, destination movement and lost acceptance
  replies.
- Compose the installed [Board workbench](29-board-reimplementation.md) with
  those shared callers at the same revision. Compare catalog/preview/workbook,
  lineage and change-review evidence with independent public-operation results;
  include current authorization, uncertain transaction/publication recovery,
  retained bases and the supported private inspection profile. Repeat bounded
  browser work, accessibility and packaged-asset checks. Board's focused
  acceptance closes in its own milestone rather than waiting for this exercise.
- Verify MCP host/version/extension combinations independently, including useful
  text-only results, Apps, subscriptions and tasks. Compare every representation
  with the same typed result and source basis. Measure result correctness,
  freshness, disclosure boundaries and bounded activation cost; tool counts and
  successful connections are not outcome evidence.
- Build full benchmark drivers after prerequisites exist: generators/scales,
  variants, schemas, result/transaction oracles, load/refresh/concurrency schedules
  and disk recovery.
- Cover inventoried TPC-C, TPC-E, TPC-H and TPC-DS operations without presenting
  component measurements as compliant full-suite scores. Keep standard versions
  and workload semantics explicit.
- Measure hosted setup/build/fixture/scenario/cleanup costs before changing CI
  lanes. Reuse artifacts without sharing authority or dropping coverage; local
  timings do not establish hosted budgets.

## Observation and consequence evidence

Qualify the product thesis behind the
[observation and feedback loop](../handbook/reference/collaborative-decisions.md#the-observation-and-feedback-loop):
better infrastructure makes relevant evidence available before decisions and
consequences inspectable afterward. The following measures are planned evaluation
criteria. They add no runtime metric, benchmark result or new supported behavior.
Each owning milestone supplies scoped evidence; this milestone assembles the
complete comparison without deferring earlier correctness gates.

Define a workload's business question, permitted audience, expected observations,
source/delivery semantics, freshness requirements and feedback window before
running it. Use an independent source/action oracle and retain original operation
identities, evidence versions and timestamps. An initial snapshot, every change
and a coalesced latest result have different coverage obligations.

| Measure | Definition and reporting obligation |
| --- | --- |
| Initial observation coverage | Required observations available to the authorized application with the declared meaning, source basis, completeness and freshness, divided by all observations required by the fixed workload |
| Consequence observation coverage | Accepted actions with the declared business consequence established by qualifying later evidence within the feedback window, divided by all accepted actions requiring that evidence; report success and known failure separately |
| Observation latency | Time from source publication to the qualifying evidence being available through the application's read interface; separately report event-to-source delay where measurable |
| Feedback latency | Time from original action acceptance to qualifying consequence evidence being available; separate action execution, real-world/source delay, ingestion, computation and disclosure so transport timing cannot stand in for the whole interval |
| Evidence fidelity and cost | Agreement with independent expected values, definitions, versions and uncertainty states, plus CPU, I/O, resident memory, retained bytes and activation count for the same workload |

Report both coverage measures together. Preserve their relationship per decision:
identify cases with an adequate initial basis and an observed consequence, cases
missing either, and cases missing both. A tool receipt establishes only the
outcome its contract specifies; a successful allocation update is insufficient
evidence that a shipment arrived. An observed business failure counts as feedback,
not as business success. Evidence insufficient to settle the declared question
does not count as complete coverage. Missing inputs, stale data and unresolved
contradictions retain their recorded states. A question about absence or conflict
can be answered by evidence establishing that condition; silence alone does not
establish that an action had no effect.

Fix cohorts and denominators before comparison. Keep pending, timed-out and
disconnected actions in the accepted-action denominator; report age and follow
each through its declared window. Report rejected or policy-denied attempts
separately, without treating them as accepted actions. Never filter to the cases
that returned data. Publish latency distributions with coverage and unresolved
counts, plus clock assumptions and uncertainty; unobserved or incomparable times
are not zero. Authorization violations or loss of evidence fidelity fail the
qualification regardless of latency or coverage gains.

Start with the delivery-assessment story using controlled native and external
observations, then qualify selected live sources independently. Preserve a
prediction, an authorized allocation action and a later delivery observation;
exercise late, absent, duplicate and contradictory evidence, revocation and
restart. Keep model/agent version, prompts, decision policy, inputs, access policy
and budgets fixed when comparing infrastructure variants. Use deterministic
decision fixtures first; report variability separately for agent-driven trials.
Record incremental baselines and regressions in the existing proof ledger with
their source revision and supported profile. Choose workload-specific acceptance
bounds before execution; this plan supplies no universal numerical target.

Business outcome quality and causal benefit need separate application evaluation.
Observation provenance makes an explanation inspectable; correlating an action
with a later event does not establish that the action caused that event.

## Completion evidence

Record source/toolchain/binary provenance, workload configuration, ordinary versus
instrumented measurements, samples and host-variance limits. Require full oracles,
negative controls, nonzero coverage gates, bounded resources and explicit failures.
Publish reproducible commands and limits with claims instead of delivery history.

## Documentation publication

The handbook is deployed through GitHub Pages; the
[publication evidence](../history/qualification/interfaces.md#published-handbook-observations-2026-10-21)
records successful deployments and direct public-content checks. Remaining work
is qualification of that existing service, not implementing publication again:

1. Verify live direct navigation/refresh, canonical URLs, assets, sitemap, search,
   exact schema downloads and a nonexistent route's HTTP 404 across public guides,
   SDKs, Internals and generated references.
2. Exercise desktop/mobile navigation, diagrams and keyboard access on the live
   site. Confirm individual roadmap/design/history records remain outside search.
   Keep these results separate from local production-browser checks.
3. Use a controlled content change and reviewed revert through `main` to exercise
   recovery. Verify the recovered revision publicly and test that a superseded
   workflow rerun cannot replace newer content. Record cache observations without
   inferring a general GitHub CDN guarantee.

These checks do not claim runtime qualification. Release-versioned documentation
and immutable release links remain part of [release distribution](36-releases.md).
