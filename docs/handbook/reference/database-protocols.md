# PostgreSQL and MySQL clients

Transit accepts selected PostgreSQL and MySQL wire protocols through its SQL
gateway. Both adapters use the same account runtime, catalog, Fuze execution
and Catalog-owned operation history as [native SQL sessions](sql-sessions.md). They do
not run either upstream database engine or provide its complete SQL dialect.

Follow [Connect with psql and mysql](../../../apps/transit-cli/docs/sql.md) for
runnable configuration and login examples. The [gateway application](../../../apps/transit-sql-gateway/README.md)
owns standalone configuration; the [wire contract](../../../contracts/SQL_GATEWAY_V1.md)
owns exact messages, admission rules and limits.

## Listeners and accounts

`transit server` starts PostgreSQL and MySQL listeners only when their ports are
configured. There is no implicit PostgreSQL or MySQL port. Local server listeners
bind IPv4 loopback; their accounts explicitly select trust or password
authentication and need native login and database grants. The native console's
Unix peer account does not implicitly enable TCP login.

Local development can set `sql.tls.mode: disabled` and use an enabled trust
account. Trust accepts the configured SQL account name asserted by the client;
it does not verify the client's operating-system user. Password authentication
uses PostgreSQL SCRAM-SHA-256 over either permitted transport. MySQL password
authentication requires TLS for its full `caching_sha2_password` exchange.

Standalone gateway TLS defaults to required. The three modes are disabled,
optional and required. Optional mode requires valid TLS material before binding
and permits encrypted or plaintext startup; required mode rejects plaintext.
TLS negotiation failures never trigger an automatic downgrade. Remote exposure
also requires explicit host, certificate and account configuration.

## Supported queries and types

| Surface | Supported boundary |
| --- | --- |
| SQL execution | Autocommit general-Table `SELECT`, `CREATE TABLE`, `INSERT`, `UPDATE` and `DELETE` |
| Parameters | Typed single-Table SELECT and mutations; the owning compiler imposes its plan limits |
| Relational reads | Selected literal int64 joins and grouping in the [relational profile](sql/relational.md) |
| Values | int64, uint64, finite float64, Boolean, UTF-8, binary and SQL NULL |
| PostgreSQL extended protocol | Prepared reads and suspended read portals; a write requires exactly one Execute followed by Sync |
| MySQL prepared statements | Bounded classic-protocol preparation, typed execution and explicit handle cleanup |

PostgreSQL exposes uint64 as numeric(20,0); MySQL uses unsigned LONGLONG.
PostgreSQL text cannot contain NUL. Missing, type-error and conflict cells cannot
be encoded as SQL NULL. Nested, decimal and other native logical descriptors
outside these six types reject at the wire boundary. Each UTF-8 or binary bound
parameter is limited to 4096 bytes, independently of frame size.

Transactions, savepoints, disabling autocommit, multi-statement requests,
ALTER/DROP, RETURNING, COPY, bulk upload, replication and arbitrary upstream
system catalogs are unsupported. The console's native statement/type profile
is broader; parser acceptance in the common grammar does not widen a wire
adapter's execution profile.

PostgreSQL writes are held until the complete permitted extended cycle has
arrived. A write followed by Flush rejects before dispatch. Suspended read
portals retain their original snapshot; continuing a portal never silently
opens a newer one. MySQL reset releases temporary handles and session state,
without undoing previously admitted account work.

## Timeouts, disconnection and recovery

Idle PostgreSQL/MySQL connections remain open by default: `sql.idle_ms` is zero.
A positive value sets an idle timeout between complete commands. Expiry reports
PostgreSQL FATAL `57P05` or MySQL error `4031` / SQLSTATE `HY000`, then closes the
connection. Handshake, partial-frame, command and output deadlines remain finite.
The native HTTP session lease is a separate setting.

The default gateway limits include 64 connections, eight per account, 16 prepared
statements and four portals per session, with a 16 MiB session allocator budget.
Wire SQL text is at most 4096 bytes. Interactive reads admit at most 10,000 output
rows, 16 MiB of result bytes and 10,000 native requests; relational execution has
separate bounded work and spill. The wire contract lists configurable ceilings.

Current account credentials, role and object permissions govern metadata, rows
and terminal counts. An unavailable authority prevents disclosure. A socket
failure, deadline or cancellation cannot establish rollback of accepted work.
The PostgreSQL/MySQL protocols do not carry the native admission token: submitting
the SQL again creates new work. Inspect the original operation through the
account's recovery controls when a mutation outcome is uncertain.
