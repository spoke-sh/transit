# Qualification history

[Engineering history](../README.md) · [Test index](../../../tests/README.md)

This archive groups executed qualification accounts by subject. Records retain
their original sources and limits; a later passing run does not erase an earlier
failure or establish its cause. Current behavior belongs to the handbook.

| Subject | Records |
| --- | --- |
| [Storage and recovery](storage.md) | WAL, immutable objects, segments, native persistence, retained roots and physical collection. |
| [Catalog and data lifecycles](catalog.md) | Direct Table ownership, identities, declarations, dependencies, publication and named resources. |
| [Query execution and computation](query.md) | Captured and maintained results, relational execution, source attribution and bounded computation. |
| [Table transactions](transactions.md) | Common cuts, provisional statements, savepoints, original decisions and checkpoint/outbox composition. |
| [SQL and database protocols](sql.md) | SQL grammar, prepared operations, sessions, database protocols and installed SQL recovery. |
| [Clients and language SDKs](sdk.md) | Installed language consumers, shared bindings, ABI ownership and cross-language conformance. |
| [CLI, Board and documentation](interfaces.md) | Console interaction, operator views, browser behavior and documentation publication. |
| [Application runtime and effects](runtime.md) | Station delivery, effects, connectors, application execution and live consumers. |
| [Installation and deployment](deployment.md) | Local launchers, Compose, reference placement, installed applications and tooling. |
| [Verification and qualification](verification.md) | Formal checks, simulation, suite execution, CI costs and cross-domain qualification. |
| [Performance experiments](performance.md) | Measured storage, query and runtime workloads with their source-specific limits. |

The [migration map](migration.json) maps every previous proof heading from
`tests/README.md` to its topic owner and records original section hashes at
source `0e6586bba5a2d9e8b0aa3b11ba422cb623c6c467`. The initial migration changed relative links only. Archived generated artifacts
remain accessible through immutable source-revision links and recorded hashes. Use topic records for accepted
qualification evidence, issues for active investigations, and the roadmap for
delivery status. Do not append chronological agent handoffs to this index.
