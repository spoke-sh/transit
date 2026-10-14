# transit-sql-gateway

An opt-in PostgreSQL and MySQL TLS endpoint over explicit Transit Table catalogs.
The gateway composes the public Query, Catalog and Station clients; it has no
storage-provider access. Each SQL account owns a native operation ledger and one
Table principal independently of its network connections.

Build from the repository with `nix develop --command zig build
transit-sql-gateway`. Run `transit-sql-gateway /private/sql-gateway.json` with an
eligible, initialized configuration. The [configuration and controls](docs/configuration.md)
describe provisioning, secrets, operator recovery and replacement. The
[wire contract](../../contracts/SQL_GATEWAY_V1.md) defines framing and limits;
the [proof ledger](../../tests/README.md#database-wire-gateway) records exercised
clients and failure cases.

The SQL profile is autocommit SELECT, CREATE TABLE, INSERT, UPDATE and DELETE.
Typed parameters apply to single-Table SELECT/DML. Literal relational SELECT
uses the admitted shared int64 join/group profile. Core wire values are int64,
uint64, finite float64, Boolean, UTF-8, binary and SQL NULL. PostgreSQL represents
uint64 as numeric(20,0); MySQL uses unsigned LONGLONG. PostgreSQL text rejects NUL.
Other projected types reject without opening a result stream.
Each UTF-8 or binary bound parameter is limited to 4096 bytes. SQL text, complete
intent size and session budgets have separate limits in the wire contract.

Transactions, multi-statement requests, savepoints, autocommit-off, ALTER/DROP,
RETURNING, COPY, bulk/long-data uploads, cursors, replication and arbitrary system
catalog emulation are unsupported. PostgreSQL extended writes require exactly
one execution followed by Sync; Flush after a pending write rejects before
dispatch. Read portals may suspend and resume within that same cycle. MySQL
connection reset clears prepared handles without cancelling durable work.

Use verified TLS and explicit autocommit. PostgreSQL authenticates with
SCRAM-SHA-256. MySQL uses full caching_sha2_password authentication inside TLS,
UTF8MB4, collation utf8mb4_0900_bin and SQL mode
ANSI_QUOTES,NO_BACKSLASH_ESCAPES. Unknown settings reject. Compatibility version
selectors choose driver codecs; the endpoint is a Transit adapter, not either
upstream database engine.

A disconnect, deadline or cancellation ends a wait; it cannot promise rollback.
The account retains admitted work and exact signed requests. Sending SQL again
creates a new operation. Use signed operator controls to discover and inspect
the original operation before deciding to retry. Rows, metadata and terminal
counts require current native/catalog rights even when already buffered.

Run `just test::sql-wire-gateway` for the real disk-backed gateway with the pinned
Python, CLI and C clients. Protocol package tests and
`just test::sql-wire-contracts` exercise independent bytes and session state
machines without claiming deployment or socket fault coverage.
