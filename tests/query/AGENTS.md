# Working on query checks

Follow [test instructions](../AGENTS.md), the [query index](README.md) and owning
query/SQL/Arrow contracts. Keep parser acceptance, valid plans, execution, complete
results and durable recovery as separate claims.

Keep expected values, fingerprint bytes and reference ASTs independent of the
production implementation. Preserve logical types, physical codecs, collations,
five-state values, source ordering and overflow/error outcomes. Unsupported
grammar and incomplete results must remain explicit. Retain corpus seeds,
replay inputs, row/page bounds and real disk schedules when reorganizing checks.

Use qualified Python imports and the shared launcher. Independent SQL reference
helpers and deployment helpers can have similar names; import their owning
modules explicitly. Give cross-domain Zig helpers explicit module dependencies
and preserve shared type identities.

Direct Table ingestion and scans belong to the direct data plane; Station actors
serve application computation/effects. Keep provider, transport and SDK coverage
with their distinct owners. Execute affected query results, current-policy denial,
snapshots, released pins, uncertainty and recovery schedules after oracle checks.
Compilation and parser agreement alone do not establish those outcomes.
