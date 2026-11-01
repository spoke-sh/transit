# 41. Deductive rules, Datalog fixpoints and equivalence graphs

[Roadmap](README.md) · [Standards & Multi-Model #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Let applications declare mutually recursive deductive rules, stratified negation,
monotonic lattice aggregations and congruence/equivalence classes over versioned
relations and graphs, then inspect derivation witnesses, fixpoint completeness
and incremental updates. Initial workloads include program and security reachability,
transitive dependency and authorization audits, equivalence-graph (`e-graph`)
rewrites and hardware verification ([M42](42-hardware-design-rtl-and-eda-verification.md)).

This is planned deductive computation-lifecycle work beyond single-table linear
`WITH RECURSIVE` queries. Existing relational joins, graph projections and delta
helpers do not establish stratified Datalog execution, unbounded fixpoint
termination or automatic solver equivalence.

## Prerequisites and ownership

Build on [data identities](01-declarative-data-lifecycle.md),
[collations and historical catalogs](10-standards-and-catalogs.md),
[indexing and access paths](11-indexing-and-access-paths.md),
[managed computations and `WITH RECURSIVE` / DBSP dataflows](12-sql-and-dataflows.md),
[Worst-Case Optimal Joins (`WCOJ` / `FreeJoin`) and per-morsel resource metering](13-data-structures-and-performance.md),
[first-class strings and perfect hashing](14-vectorized-strings-and-search.md),
[data-centric and AOT compilation](15-data-centric-compilation-and-specialization.md),
[property-graph projections](18-multi-model-and-foreign-relations.md),
[branches](20-branches-merges-and-restore.md),
[formal semantics and DBSP proofs](22-formal-semantics-and-correspondence.md),
[policy and security-barrier RLS](27-control-and-policy-plane.md),
[retained investigations](28-published-resources-and-investigations.md) and
[software evidence](39-software-build-and-deployment-evidence.md). Reuse the
[data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[SQL results](../../contracts/SQL_RESULTS_V1.md) and
[investigation](../../contracts/INVESTIGATION_V1.md) contracts. Follow public
[queries](../handbook/reference/queries.md),
[SQL](../handbook/reference/sql.md) and
[query engine architecture](../handbook/internals/query-engine.md).

`Fuze` owns deterministic stratification, semi-naive evaluation, WCOJ pattern
matching, lattice merges and Union-Find equivalence tables in Zig; catalog,
storage and computation owners retain authority, snapshot cuts and publication.
Compile-time Horn-clause and multi-head recursive SQL surface ergonomics belong to
[SQL grammar and dialect ergonomics](43-sql-grammar-and-dialect-ergonomics.md);
domain-specific hardware rules belong to
[hardware design and EDA verification](42-hardware-design-rtl-and-eda-verification.md)
and application owners.

## Delivery sequence

1. **Stratify mutually recursive rule graphs and reject negative cycles.**
   Represent deductive programs as directed dependency graphs over base
   extensional relations (`EDB`, bound to pinned `DefinitionId` and `SnapshotId`
   cuts) and derived intensional relations (`IDB`). Partition mutually recursive
   relations into Strongly Connected Components (Tarjan SCCs) and topologically
   order strata so negation (`NOT EXISTS` / `ANTI` join) and non-monotonic
   aggregates strictly cross stratum boundaries. Reject unstratifiable negative
   or non-monotonic cycles before admission with an explicit cycle witness.
   Preserve Transit's five-state cell semantics (`value`, `null`, `missing`,
   `type_error`, `conflict`) and declared column collations ($\kappa$) across all
   derived tuples.
2. **Execute semi-naive differential fixpoints and cyclic WCOJ rules.**
   Evaluate each recursive stratum via semi-naive delta iteration
   ($\Delta R^{(k+1)} = \mathcal{F}(R^{(k)}, \Delta R^{(k)}) \setminus R^{(k)}$)
   paired with [Milestone 13's](13-data-structures-and-performance.md)
   Diamond-Hardened / Worst-Case Optimal Joins (`WCOJ` / `FreeJoin`) for cyclic
   body patterns (triangles, reconvergent fanout diamonds and $k$-cliques) and
   [Milestone 15's](15-data-centric-compilation-and-specialization.md) AOT Zig /
   Copy-and-Patch stratum loops. Enforce explicit per-morsel CPU, memory, iteration
   and cardinality bounds (`OperatorTraits.WorkBound`) with deterministic Tier 2
   NVMe spill for working and delta relations. Distinguish a verified complete
   fixpoint from a budget-bounded or depth-truncated prefix in `SQL_RESULTS_V1`;
   an incomplete fixpoint never authorizes a negative ("unreachable" or "safe")
   conclusion.
3. **Support monotonic lattice and semiring aggregations inside recursion.**
   Permit declared commutative, associative, idempotent join-semilattice
   accumulators ($\langle L, \sqcup, \bot \rangle$—such as boolean reachability/taint
   `BOOL_OR`, security-label join lattices, shortest-path / critical-path tropical
   $(\min, +)$ and $(\max, +)$ bounds, and interval/set union) inside a recursive
   stratum where values move monotonically up the lattice to a finite height or
   declared bound. Keep non-monotonic aggregations (`COUNT`, `SUM` over arbitrary
   signed values, `AVG`) strictly stratified across completed lower strata.
4. **Maintain equivalence relations, Union-Find (`e-classes`) and bounded `egglog` rewrites.**
   Provide a first-class congruence and equivalence-class operator over compact
   `.tseg` and `Fuze` entity IDs so symmetric, transitive connectivity relations
   (electrical nets, alias/pointer sets, symbol unification and entity resolution)
   maintain canonical representatives in $O(\alpha(N))$ via paged Union-Find
   directories rather than materializing $O(N^2)$ Cartesian equivalence pairs.
   Support bounded algebraic and structural `e-graph` rewrite rules (`egglog`
   equality saturation) with explicit node/iteration caps, canonical extraction
   cost functions and deterministic tie-breaking.
5. **Maintain incremental DBSP deductive views over `TransitLog` (`TWAL1`).**
   Connect stratified semi-naive programs to
   [Milestone 12's](12-sql-and-dataflows.md) WAL-activated DBSP $\mathcal{Z}$-set
   dataflows so base-table insertions and retractions (`+row` / `-row`) update
   derived IDB relations, lattice states and equivalence classes incrementally
   without full recomputation. Prove exact agreement between incremental DBSP
   maintenance and finite from-scratch fixpoint evaluation at the same committed
   `SnapshotId` ([Milestone 22 `A3`](22-formal-semantics-and-correspondence.md#a3-incremental-dataflow-equivalence)).
6. **Produce inspectable derivation witnesses and proof traces.**
   Allow callers to request bounded **derivation witnesses** (`WITH PROVENANCE` /
   witness tables) recording the minimal or shortest DAG of ground EDB facts and
   rule firings that derived a target IDB tuple (such as an unauthorized
   information-flow path, a violated constraint or an equivalence rewrite chain).
   Recheck current `policy_epoch` authorization and security-barrier RLS across
   every contributing base fact before disclosing a derived tuple or its witness
   trace; a deductive rule must never leak restricted existence through a public
   summary or side-channel `type_error`.

## First acceptance journey

An application declares a multi-stratum security and dependency reachability
program over a versioned graph of services, credentials, data stores and
sanitization barriers, combining mutually recursive flow rules, a lattice taint
level, an equivalence relation over aliased endpoints and a stratified negation
guard. It queries reachable violations at a pinned `SnapshotId`, inspects the
shortest derivation witness for a flagged path, then proposes a barrier insertion
on a branch ([M20](20-branches-merges-and-restore.md)) and verifies via
incremental DBSP evaluation that the violation disappears while complete fixpoint
coverage holds.

## Completion evidence

- Compare multi-stratum mutually recursive fixpoints, WCOJ cyclic bodies,
  monotonic lattice aggregations and Union-Find / `e-graph` rewrites against an
  independent reference Datalog oracle across 5-state values, collations, cycles,
  self-loops, duplicate derivations and disconnected components.
- Challenge unstratifiable negative cycles, non-monotonic aggregates inside
  recursive strata, non-terminating value generation and budget/iteration
  exhaustion. Verify that budget truncation reports an incomplete outcome rather
  than an empty/safe fixpoint.
- Prove incremental `+row` / `-row` DBSP maintenance equals finite recomputation
  across insertions, deletions (`DRed` / $\mathcal{Z}$-set retraction), diamond
  derivations (where a fact has multiple independent proof trees and only one is
  retracted) and equivalence-class splits/rebuilds.
- Exercise working sets larger than RAM with Tier 2 NVMe spill, worker kill and
  checkpoint recovery, cancellation races and `policy_epoch` RLS revocation while
  witness traces are buffered.
- Record fixpoint iteration counts, WCOJ vs. binary-join intermediate cardinality,
  Union-Find vs. materialization memory, incremental delta latency, warm
  allocations (zero steady-state heap allocations after warmup on hot morsels) and
  witness extraction cost.

## Primary references

- [DBSP: Automatic Incremental View Maintenance for Rich Query Languages](https://www.vldb.org/pvldb/vol16/p1601-budiu.pdf)
  (Budiu et al., VLDB 2023) for the algebraic unification of relational SQL,
  stratified Datalog fixpoints and $\mathcal{Z}$-set stream maintenance.
- [Free Join: Unifying Worst-Case Optimal and Traditional Joins](https://dl.acm.org/doi/10.1145/3589295)
  (Wang et al., SIGMOD 2023) and
  [egglog: Better Together: Unifying Datalog and Equality Saturation](https://dl.acm.org/doi/10.1145/3591239)
  (Zhang et al., PLDI 2023) for cyclic pattern evaluation and equivalence-graph
  maintenance; neither upstream tool is a runtime dependency.
- [Soufflé Datalog](https://souffle-lang.github.io/) for stratified semantics,
  monotonic lattice relations and compiled specialization baselines.
