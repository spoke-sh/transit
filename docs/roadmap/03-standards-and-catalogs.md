# 3. Standards and historical catalogs

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31)

Establish historical query, multi-model and branch semantics using the
[grammar inventory](../handbook/reference/sql/grammar-surface.md),
[query model](../handbook/internals/query-engine.md) and [state model](../handbook/internals/state-model.md).

Extend the [shared data lifecycle](01-declarative-data-lifecycle.md). Historical
inspection must answer which definition interpreted the data, what a derived
result depended on and which current policy permits disclosure. Do not introduce
a second catalog identity or confuse a historical definition with current rights.

## Delivery sequence

1. Publish a machine-readable standards ledger: edition/correction, feature,
   owner, dependencies, deviations and separate parse/lower/execute/recover/transport
   states. Generate capabilities and licensed positive/negative fixtures.
2. Define shared operators and read/mutate/capture/dispatch effects. Propagate
   determinism, fallibility, change mode and work bounds. Explanation does no work.
3. Define historical catalogs: stable catalog/column identities, ancestry,
   definitions, data inclusion, consistency basis, typed selectors, current access
   and conditional head publication.
4. Bind historical schemas, views, graph mappings and decoders before resolving
   names or compiling. Moving a branch cannot change an accepted request's basis.
5. Expose historical inspection and explicit projections through shared operations,
   distinguishing metadata permission from row access.

## Boundaries and evidence

Target selected SQL:2023, SQL/JSON, SQL/PGQ and SQL/MED features explicitly.
GQL, Cypher and PGQL need separate frontend/compatibility evidence. Reserve
system-time syntax for temporal semantics; resource revisions, application
revisions and snapshot identities remain different types.

Qualify rename/drop/recreate, changed historical views, unavailable history,
old-column success/new-column rejection, explicit projections, metadata-only
rights, revocation after a prefix and branch movement after admission. Publish
independent transition/canonical fixtures before implementing branch storage.
