# PostgreSQL and MySQL clients

Transit accepts selected PostgreSQL and MySQL wire protocols through its SQL
gateway. Both adapters use the same database runtime, catalog, Fuze execution
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

Protocol decoding uses bounded caller-owned buffers and has no transport or SQL
execution dependency. Startup engines emit TLS, credential-verification and
session-admission requests. Login success follows current credential/authority
checks and command-buffer reservation. Authenticated command engines emit explicit
execution and output requests, with bounded borrowed buffers and fenced
completions. The shared SQL host owns TLS, deadlines, authentication and current
authorization. Resuming buffered output rechecks rights; resuming a write reply
observes its original outcome without replaying the statement. Command buffers retain their high-water
capacity within the admitted session reserve; malformed lengths reject before
body reads, and partial EOF cannot become another command or a completion.

## Supported queries and types

| Surface | Supported boundary |
| --- | --- |
| SQL execution | Autocommit general-Table `SELECT`, `CREATE TABLE`, `INSERT`, `UPDATE` and `DELETE` |
| Streams and Queues | [Declarations, metadata and single-partition appends](sql/streaming.md), including `PRODUCE`/`ENQUEUE ... RETURNING` |
| Parameters | Typed single-Table SELECT/mutations and Stream/Queue appends; the owning compiler imposes its plan limits |
| Relational reads | Selected literal int64 joins and grouping in the [relational profile](sql/relational.md) |
| Values | Signed/unsigned 8/16/32/64-bit integers, finite float32/float64, exact decimal, Boolean, UTF-8, binary and SQL NULL |
| PostgreSQL extended protocol | Prepared reads and suspended read portals; a write requires exactly one Execute followed by Sync |
| MySQL prepared statements | Bounded classic-protocol preparation, typed execution and explicit handle cleanup |

PostgreSQL exposes uint64 as numeric(20,0); MySQL uses unsigned LONGLONG.
DECIMAL/NUMERIC preserve precision 1–38 and scale 0–precision (MySQL scale at most
30); defaults remain precision 38, scale 0. Values never pass through binary
floating point. Overflow and inexact prepared rescaling reject. `INT`/`INTEGER`
remain int32, `REAL` remains float32, and `VARCHAR` remains UTF-8. Thus
`CREATE TABLE employees (id INT, name VARCHAR, salary DECIMAL(10,2))` supports
empty and populated reads through the console, psql and MySQL.

PostgreSQL text cannot contain NUL. Missing, type-error and conflict cells cannot
be encoded as SQL NULL. Nested, 128-bit integer, temporal, UUID, JSON and other native logical descriptors
outside this matrix reject at the wire boundary. CREATE TABLE checks every column
before admission, so an unsupported declaration cannot succeed and then fail its
first SELECT. Refusals identify the protocol, column/parameter and type with
PostgreSQL SQLSTATE `0A000` or MySQL error 1235 / SQLSTATE `42000`. Native Tables may retain broader types; projecting only supported
columns through a wire client is allowed. Each UTF-8 or binary bound
parameter is limited to 4096 bytes, independently of frame size.

Stream and Queue append completions use `PRODUCE n` and `ENQUEUE n` command
tags. PostgreSQL clients can read the accepted count from the status tag;
libpq's `PQcmdTuples` does not recognize these Transit commands, so psycopg's
`rowcount` is `-1` for an append without `RETURNING`. MySQL reports the count
in its ordinary affected-rows field. `RETURNING` uses the normal row-result
lifecycle on both adapters.

Disabling autocommit, multi-statement requests,
general Table ALTER/DROP/RETURNING, COPY, bulk upload, replication and arbitrary upstream
system catalogs are unsupported. The console's native statement/type profile
is broader; parser acceptance in the common grammar does not widen a wire
adapter's execution profile.

Both adapters support [local Table transactions](sql/transactions.md), including
read-only cuts and savepoints. PostgreSQL ReadyForQuery reports idle, active or
failed transaction state; MySQL sets IN_TRANS while retaining configured
autocommit. DML counts within a transaction remain provisional until its decision.

PostgreSQL writes are held until the complete permitted extended cycle has
arrived. A write followed by Flush rejects before dispatch. Suspended read
portals retain their original snapshot; continuing a portal never silently
opens a newer one. MySQL reset releases temporary handles and session state,
without undoing previously admitted account work.

## psql inspection commands

The PostgreSQL adapter accepts the catalog queries generated by `psql` 18
(checked with 18.6 and English column labels) for these commands:

| Command | Transit observation |
| --- | --- |
| `\d`, `\dt` | Authorized Tables in the session's selected schema |
| `\d name` | A Table's logical column types, nullability, defaults, collations and primary key |
| `\dn` | Authorized schemas in the selected database |
| `\l`, `\list` | Authorized database bindings configured for the SQL account |

Names can be quoted, including Unicode and punctuation. Literal names, `*` and
`?` patterns are supported, for example `\dt order*` and `\d public.orders`.
A schema qualifier filters the selected schema; it does not switch schemas or
expand access. Listings are ordered by name. Use `\set ECHO_HIDDEN on` to see
the SQL generated by `psql`.
Use `LC_MESSAGES=C` when launching a client whose catalog labels are localized.

This is a bounded inspection profile, not a general `pg_catalog` SQL engine.
Verbose `+` forms, role/privilege inspection, arbitrary regular expressions,
other upstream object families and arbitrary catalog SELECTs return SQLSTATE
`0A000`. Table descriptions currently reject Tables declaring CHECK or FOREIGN
KEY constraints; use native `DESCRIBE` for their column metadata. Descriptions
do not enumerate incoming Transit dependencies. PostgreSQL rules, triggers,
inheritance, publications, statistics objects and row policies are not Transit
objects and are absent from this projection; Transit authorization still applies.
Owner, PostgreSQL ACL and database-locale fields are NULL rather than inferred
from the connected account. Types and defaults use Transit's logical display.
Primary-key display names use `<table>_pkey` and the access-method label `transit`;
they identify the declared key for display, not a PostgreSQL index or heap.

Metadata uses public Catalog reads and the ordinary result lifecycle. It admits
no durable SQL operation, reads no application rows and grants no access.
Current credentials, selected role, schema and object rights are rechecked before
metadata disclosure, including resumed or empty results. Catalog observations
are independent, not an atomic snapshot. A directory or policy change during
ordered enumeration fails with `40001`; discard partial output before a new read.
Enumeration retains a native page and one candidate, rescanning by name within
a budget of 10,000 catalog page reads or database-selection probes and the session
deadline. Current-authority validation remains additional work. Exceeding the scan
budget returns `54000`, never a successful truncated listing.

Client-local commands such as `\x`, `\timing`, `\pset` and `\q` continue to be
handled by `psql` itself. Commands that submit SQL retain the selected SQL
profile; this inspection support does not enable COPY or PostgreSQL administration.

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
After a transient owner conflict interrupts an already accepted Table write,
the gateway waits for recovery of the original operation within the same command
deadline. Completion retains that operation's original outcome and counts.
The PostgreSQL/MySQL protocols do not carry the native admission token: submitting
the SQL again creates new work. Inspect the original operation through the
account's recovery controls when a mutation outcome is uncertain.
