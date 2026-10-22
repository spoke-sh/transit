# 4. Managed computations and SQL dataflows

[Roadmap](README.md)

Let an application declare a derived result, apply it, and inspect the definition,
source basis, completed revision and pending or blocked work while Transit owns
the qualified scheduling and recovery. Extend the
[shared lifecycle](01-declarative-data-lifecycle.md),
[SQL reference](../handbook/reference/sql.md) and
[grammar inventory](../handbook/reference/sql/grammar-surface.md).

Typed Tables, joins/grouping, expressions, parameters, named relational
activation, complete Table history and typed maintained revisions already exist.
Maintained owners currently require host-driven activation and wakeups and
recompute at recorded source bases. The missing service lifecycle is the first
delivery slice; incremental optimization must preserve that existing oracle.

## Managed computation sequence

1. Define a computation declaration's bound inputs, lifetime, output, policy
   references, budget and desired activation revision. Publish/alter definitions
   separately from authorizing work. Bind accepted work to its exact definition;
   a rename or newer definition cannot relabel it.
2. Implement a service owner for explicit activation and bounded scheduling of
   the existing captured/maintained owners. Record recoverable intent and progress,
   fence competing owners, and preserve pending work across service replacement.
   Admission pressure must not discard accepted work; reserve control capacity.
3. Expose completed source vectors, result revisions, pending successor and
   attributable failure/blocked reasons. Compare progress with authorized observed
   input positions and define freshness at that observation. A completed result
   remains complete for its own basis while later changes are pending.
4. Define refresh, pause/resume, cancellation, alteration, retirement and cleanup.
   Preserve the last complete result while a successor is incomplete. Define
   dependency/schema changes, revocation, unavailable history, backfill/live
   handoff and policy expiry without inventing cross-owner atomicity.
5. Adapt the qualified lifecycle to SQL views/subscriptions and typed SDK
   operations. Inspection and EXPLAIN do no work. Board consumes the same
   definitions and evidence through its explicit capabilities; it adds no hidden
   scheduler or administrative authority.

## Remaining work

- Extend expression/relational composition while preserving five-state values,
  checked arithmetic, source identities, output types and bounded operator state.
- Provide logical/physical explanation and output-schema inspection without
  source disclosure, mutation or external work.
- Implement typed COPY/import/export, MERGE/upsert, prepared-plan lifetime and
  explicit transaction sessions. Define identities, conflicts, budgets and
  uncertain commits first. Cross-resource atomicity needs its own native contract.
- Extend the common dependency lifecycle to connections, sources and sinks,
  including conditional alteration and retirement. SQL, SDK and Board use the
  same administrative operations.
- Optimize maintained computation against the complete finite-recomputation
  oracle. Event-time windows require explicit timestamps, watermarks and late-data
  rules; incremental deltas require exact update/delete semantics.
- Bind outputs to recorded effects through independently authorized activation.
  Compiling, explaining, reading and replaying never dispatch a dataflow.

## Prerequisites and completion

Historical operations consume [catalog contracts](03-standards-and-catalogs.md).
Branch merge and SQL MERGE remain distinct. Fuze owns computation; Station and
application owners coordinate work above a generic kernel.

Require independent finite/maintained equivalence at completed source bases,
current grants, lost responses, interrupted publication, bounded spill and
larger-than-cache workloads. Qualify actual callers for each exposed slice.

The acceptance journey declares a derived relation, observes its first complete
result, changes source rows and schema, inspects catch-up or blocking, replaces
the service and recovers the same accepted work. Exercise pause, revocation and
retirement without reporting a partial successor as a complete result. Measure
freshness and control latency under load separately from correctness.
