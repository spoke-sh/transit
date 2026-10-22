# 5. Multi-model and foreign relations

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31)

Compose KV, Table and Document data using the
[standards/semantic contracts](03-standards-and-catalogs.md) and relevant
[declaration/dataflow lifecycle](04-sql-and-dataflows.md).

Use the shared object/definition identities, policy references and inspection
model from the [data lifecycle](01-declarative-data-lifecycle.md). A new projection
or foreign source must expose its interpretation, captured basis, dependencies
and completeness; another storage adapter alone is not the user-facing outcome.

## Delivery sequence

1. Define explicit Document-to-SQL and richer projections with stable identities.
   Specify missing/null/conflict/type-error and overflow behavior; no implicit
   conflict winner or default value.
2. Map finite property graphs over existing resources. Lower fixed-pattern SQL/PGQ
   through graph-aware Fuze operators, preserving parallel edges, self-loops,
   endpoint validity and multiplicity.
3. Add one rooted filesystem foreign relation using SQL/MED. Select a decoder;
   capture immutable paged manifests with source identity, completeness, bounds
   and recoverable publication. S3 requires a later qualified binding.
4. Extend maintained composition after independent finite verification. Include
   updates/deletes, graph changes, captured refresh and backfill. Completed source
   bases must equal finite recomputation.

## Completion evidence

Use independent relational/graph oracles and current source rights. Qualify changed
or missing files, interrupted captures, lost acknowledgements, revocation after
partial disclosure, invalid endpoints and data beyond resident caches.

External writes remain separately activated recorded effects. Declarations do not
grant raw filesystem, network or backend access. Publish grammar, types, bounds
and exclusions through consistent capability views across shared interfaces.
