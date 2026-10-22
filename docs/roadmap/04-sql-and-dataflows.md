# 4. SQL and declarative dataflows

[Roadmap](README.md)

Complete unsupported operation families in the [SQL reference](../handbook/reference/sql.md)
and [grammar inventory](../handbook/reference/sql/grammar-surface.md). Existing typed Tables,
joins/grouping, expressions, parameters and named relational activation are the
baseline; extend their shared owners rather than planning them again.

## Remaining work

- Extend expression/relational composition while preserving five-state values,
  checked arithmetic, source identities, output types and bounded operator state.
- Provide logical/physical explanation and output-schema inspection without
  source disclosure, mutation or external work.
- Implement typed COPY/import/export, MERGE/upsert, prepared-plan lifetime and
  explicit transaction sessions. Define identities, conflicts, budgets and
  uncertain commits first. Cross-resource atomicity needs its own native contract.
- Complete dependency lifecycle for connections, sources, queries and
  materializations, including conditional alteration and retirement. SQL, CLI,
  SDK and Board use the same administrative operations.
- Define maintained queries and subscriptions: source vectors, backfill/live
  handoff, deletes, refresh, cancellation, expiry and restart. Event-time windows
  require explicit timestamps, watermarks and late-data rules.
- Bind outputs to recorded effects through independently authorized activation.
  Compiling, explaining, reading and replaying never dispatch a dataflow.

## Prerequisites and completion

Historical operations consume [catalog contracts](03-standards-and-catalogs.md).
Branch merge and SQL MERGE remain distinct. Fuze owns computation; Station and
application owners coordinate work above a generic kernel.

Require independent finite/maintained equivalence at completed source bases,
current grants, lost responses, interrupted publication, bounded spill and
larger-than-cache workloads. Qualify actual callers for each exposed slice.
