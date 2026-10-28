# transit-sql

SQL database execution over the public Catalog and direct query interfaces.
`Statement` prepares authorized metadata and binds complete immutable intents.
`DatabaseRuntime` admits account tokens, recovers accepted work, and projects
original owner outcomes. This package and its transitive dependencies contain
no Station modules, actor turns, private KV ledger, or storage-provider access.

The [database runtime](docs/runtime.md) describes admission, fencing, quotas,
snapshot caching and recovery. The [direct contract](../../../contracts/DIRECT_TABLE_V1.md)
owns token records and partition operations. The [query package](../transit-query-direct/README.md)
owns finite Table reads and relational execution.

`transit-sql-service` composes this package with authentication, sessions,
settings and explicitly configured captured-source adapters. PostgreSQL, MySQL
and the native SQL endpoint use that [shared service](../transit-sql-service/README.md).
Captured source execution retains its separate Query owner; it is not an
admission or execution dependency of database DDL/DML or ordinary Table SELECT.

Run `zig build test` or `zig build check` from this directory. The build graph
rejects transitive Station imports. Real native-owner, restart and wire proofs
are registered in the [test index](../../../tests/README.md).
