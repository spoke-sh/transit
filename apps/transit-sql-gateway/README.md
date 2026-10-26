# transit-sql-gateway

A shared SQL service with native HTTP/TLS, private Unix peer, PostgreSQL and
MySQL adapters over explicit Transit catalogs and source bindings.
The gateway composes the public Query, Catalog and Station clients; it has no
storage-provider access. Each SQL account owns a native operation ledger and one
Table principal independently of its network connections. Direct Table reads
and operation evidence use that caller's current native
database/schema/Table grants and retain their selected role through recovery.

For a local installation, follow the [psql/mysql walkthrough](../transit-cli/docs/sql.md).
The local server manages explicit enrollment and separate fenced activations.

Build from the repository with `nix develop --command zig build
transit-sql-gateway`. Run `transit-sql-gateway /private/sql-gateway.json` with an
eligible, initialized configuration. The [configuration and controls](docs/configuration.md)
describe provisioning, secrets, operator recovery and replacement. The
[wire contract](../../contracts/SQL_GATEWAY_V1.md) defines framing and limits;
the [proof ledger](../../docs/history/qualification/sql.md#database-wire-gateway) records exercised
clients and failure cases.

The [native session API](../../contracts/SQL_SESSION_V1.md) and
[console](../transit-cli/docs/console.md) preserve full logical types, Table
ALTER/DROP, explicit source reads and captured query operations. Native sessions
live across HTTP connections; PG/MySQL sessions belong to their socket. The
[shared runtime](../../packages/zig/transit-sql/README.md) owns settings,
authorization, preparation, reads and account coordination for all adapters.

The PostgreSQL/MySQL profile is autocommit SELECT, CREATE TABLE, INSERT, UPDATE and DELETE.
Typed parameters apply to single-Table SELECT/DML. Literal relational SELECT
uses the admitted shared int64 join/group profile. Core wire values are int64,
uint64, finite float64, Boolean, UTF-8, binary and SQL NULL. PostgreSQL represents
uint64 as numeric(20,0); MySQL uses unsigned LONGLONG. PostgreSQL text rejects NUL.
Other projected types reject without opening a result stream.
Each UTF-8 or binary bound parameter is limited to 4096 bytes. SQL text, complete
intent size and session budgets have separate limits in the wire contract.

Prepared handles retain the original Table identity. ALTER invalidates its
definition and reports PostgreSQL SQLSTATE `55000` or MySQL error `1105` with
"Prepared source changed; prepare again". A handle targeting a retired Table
receives current-access denial (`42501` / `1142`), including after same-name
replacement. A fresh preparation of an absent name reports `42P01` / `1146`.
Neither failure automatically recompiles or retargets the old handle.
Ordinary current-state contention also reports `55000` / `1105`, retaining any
accepted operation identity and requiring inspection before repeating a write.
A caller can start a new read after failure before its first batch; it cannot
splice that read onto an earlier result prefix.

For PostgreSQL/MySQL, transactions, multi-statement requests, savepoints, autocommit-off, ALTER/DROP,
RETURNING, COPY, bulk/long-data uploads, cursors, replication and arbitrary system
catalog emulation are unsupported. PostgreSQL extended writes require exactly
one execution followed by Sync; Flush after a pending write rejects before
dispatch. Read portals may suspend and resume within that same cycle. MySQL
connection reset clears prepared handles without cancelling durable work.

Use explicit autocommit. TLS can be disabled, optional or required (the default).
Explicit loopback trust logins need no password or certificate when TLS is disabled;
they retain current native authorization. PostgreSQL password logins use
SCRAM-SHA-256, with or without TLS. MySQL uses full caching_sha2_password authentication inside TLS,
UTF8MB4, collation utf8mb4_0900_bin and SQL mode
ANSI_QUOTES,NO_BACKSLASH_ESCAPES. Host settings, catalog SHOW and session SET/RESET use the shared [settings SQL](../../docs/handbook/reference/sql/settings.md) profile; host inspection/reload requires an explicit management binding. Other unknown settings reject. Compatibility version
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
