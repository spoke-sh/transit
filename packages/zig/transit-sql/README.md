# transit-sql

`SourceSql` parses explicit `CREATE SOURCE ... INTO STREAM ...` HTTP declarations,
connection origins and source lifecycle/inspection forms without side effects.
The native cohosted service composes it with the shared Catalog declaration
owner for publication, inspection, retirement and restricted DROP. Its database
binding requires an explicit SOURCE executor. HTTP capture and activation retain
the gates in the
[source contract](../../../contracts/SOURCE_V1.md).

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
Native pages use the Stream reader's default 4,096-row scan budget and respect
the declaration's row/byte limits. A SQL batch may span multiple native pages;
filtered rows still contribute to original consumption coverage. A frozen Stream
LIMIT lowers each native page's row budget to the remaining output allowance.
Completion at that limit preserves a partial native cursor, including LIMIT 0
at the initial position; it neither exhausts the larger read nor commits a group.
Workload observations carry the explicit nullable limit so clients validate that
terminal distinction.
`WorkloadOperations` projects native receipts and recorded closures and advances
the same frozen work through Catalog's terminal settlement gate.
`DirectLogPreparedAppend` freezes single-partition `PRODUCE INTO` and
`ENQUEUE INTO` statements, including optional RETURNING. Native SQL admits a
caller token; wire callers generate one identity and wait on progress signals
for its original outcome. `DirectLogPreparedConsume` freezes positional
`CONSUME` requests, retaining a native upper cut at acceptance and applying the
original typed predicate and logical LIMIT during bounded result delivery. A
multi-partition Stream requires a predicate that selects exactly one partition.
`DirectLogPreparedClaim` freezes a typed acquisition predicate for `CLAIM ...
WITH LEASE` on one Queue partition. Conservative Boolean routing must establish
one partition. The native owner evaluates eligible candidates before acquisition;
LIMIT bounds acquisition and never hides accepted result rows. Native FIFO,
capacity and lease checks remain authoritative. Group consumption binds an
explicit native assignment/checkpoint descriptor, and COMMIT OFFSET freezes
the original read receipt and authenticated traversal interval. Grouped result
completion preserves both boundaries even at a partial LIMIT or LIMIT 0. Stream
and Queue WAIT freeze a bounded attempt policy; passive recovery only observes
waited work or honors cancellation, while explicit resume dispatches the same
native wait on the data lane. Stream readiness uses the saved start/checkpoint
and open upper frontier, independently of filters and LIMIT. Queue payload
predicates remain unimplemented; group assignment
and read-release tokens stay with their native owners.

Run `zig build test` or `zig build check` from this directory. The build graph
rejects transitive Station imports. Real native-owner, restart and wire proofs
are registered in the [test index](../../../tests/README.md).

Queue ACK and NACK use the same durable workload admission and recovery path. The
statement freezes the binary claim receipt, retains its original lease identity
across compatible declaration changes, and completes from native settlement
evidence without relational counts. NACK optionally freezes an absolute UTC
visibility timestamp; native retry/FIFO/attempt policy still applies. See [SQL Queue settlement](../../../docs/handbook/reference/sql/streaming.md#acknowledge-queue-work).

EXTEND LEASE uses the same settlement owner and returns one binary
`_receipt_handle` row through `WorkloadRead`. The frozen result binds the original
extension receipt, so retries and reopening preserve that exact updated expiry
even after later lease changes. It requires current settle rights and makes no
payload read or liveness claim. See [lease renewal](../../../docs/handbook/reference/sql/streaming.md#renew-a-queue-lease).
