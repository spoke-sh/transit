# transit-sql

SQL database execution over the public Catalog and direct query interfaces.
`Statement` prepares authorized metadata and binds complete immutable intents.
`DatabaseRuntime` admits account tokens, recovers accepted work, and projects
original owner outcomes. This package and its transitive dependencies contain
no Station modules, actor turns, private KV ledger, or storage-provider access.

Stream/Queue DDL uses `DirectLogPreparedDdl` and the Catalog's immutable
`DirectLogIntent` token reference. It preserves typed declaration completions
and original accepted identities through the same database runtime as Table
writes. The [SQL profile](../../../docs/handbook/reference/sql/streaming.md#stream-and-queue-declarations)
defines supported syntax, policy defaults and inspection results.

The [database runtime](docs/runtime.md) describes admission, fencing, quotas,
snapshot caching and recovery. The [direct contract](../../../contracts/DIRECT_TABLE_V1.md)
owns token records and partition operations. The [query package](../transit-query-direct/README.md)
owns finite Table reads and relational execution.

`transit-sql-service` composes this package with authentication, sessions,
settings and explicitly configured captured-source adapters. PostgreSQL, MySQL
and the native SQL endpoint use that [shared service](../transit-sql-service/README.md).
Captured source execution retains its separate Query owner; it is not an
admission or execution dependency of database DDL/DML or ordinary Table SELECT.

`TransactionSql` parses the shared transaction controls. `TransactionWork` freezes
caller commands for Catalog-owned common cuts, private Table changes, savepoints
and original commit/abort settlement. [Table transactions](../../../docs/handbook/reference/sql/transactions.md)
describes the supported local serializable domain and provisional outcomes.

`WorkloadRead` composes frozen workload bodies, Fuze projections and the signed
native original-result API. It owns decoded metadata and retained scratch,
resumes failed page requests at the same position, and exposes original selection
and completion evidence. Returned rows are borrowed until the next pull: a batch
owner must copy them and recheck disclosure after buffering, including repeated
or empty terminal responses. Closing only releases local memory. The session
service uses this adapter to reopen existing workload tokens.
`WorkloadOperations` projects native receipts and recorded closures and advances
the same frozen work through Catalog's terminal settlement gate. Workload SQL
admission remains unimplemented; native group assignment and read-release tokens
remain with their native owners rather than SQL recovery.

Run `zig build test` or `zig build check` from this directory. The build graph
rejects transitive Station imports. Real native-owner, restart and wire proofs
are registered in the [test index](../../../tests/README.md).
