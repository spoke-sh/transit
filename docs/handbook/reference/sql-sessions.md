# SQL sessions

The console, PostgreSQL and MySQL adapters execute through one server-managed
SQL service. Each connection opens its own logical session; accounts share a
fenced runtime and durable operation ledger. Two consoles can use the same
installation without sharing a client recovery lock or private signing keys.

Start with the [console guide](../../../apps/transit-cli/docs/console.md) for local
and remote connections, or [PostgreSQL and MySQL](database-protocols.md) for those
wire adapters. This reference describes the native SQL API. The
[SQL session contract](../../../contracts/SQL_SESSION_V1.md) and its
[generated message description](../../../contracts/sql-session-v1.schema.json)
own exact fields, codecs and bounds.

## Connect and authenticate

Local console discovery selects the server's private Unix socket from a
nonsecret runtime rendezvous. The console does not load the installation's
signing seeds or `installation.json`. The operating system's socket peer
credential authenticates the configured local owner. Selecting an installation
path chooses a server; it does not give the client ownership of that server.

Remote clients use explicitly configured HTTP/TLS listeners. HTTPS verifies
the certificate against system roots or a configured CA. Password accounts use
SCRAM-SHA-256, bound to the exact protocol definition, server instance, account,
database and source binding. Explicit trust login is confined to configured
loopback listeners. Trust accepts a configured account name; it is different
from Unix peer authentication.

The API uses HTTP/1.1 POST with bounded JSON bodies:

| Route | Actions |
| --- | --- |
| `/v1/sql/session` | `hello`, `open`, `authenticate`, `touch`, `reset`, `context`, `prepare`, `describe`, `release`, `execute`, `fetch`, `result`, `assist` |
| `/v1/sql/control` | `cancel`, `status`, `operations`, `resume`, `close`, `close_result` |

`hello` reports compatibility, persistent instance identity and bounds. Every
request carries the current v1 definition; subsequent requests also bind the
instance. Authenticated operations carry a secret session handle. Handles belong
in request bodies, never URLs or logs. The generated description is a native
route/message schema, not OpenAPI. Browser Origin and forwarded identity headers,
cookie authentication and redirects are not supported.

The separate control lane lets a client cancel or inspect work while a data
request is occupied. Concurrent work still has explicit service and per-account
bounds; a second command against the same busy session can reject. Use distinct
sessions for independently active clients.

## Session and result lifetime

HTTP connections can be replaced without losing the logical session's settings,
prepared metadata or current read cursor. A native session has a 30-second idle
lease by default, configured locally as `sql.native.session_lease_ms`. `touch`
renews it after checking current credentials and database authority. Closing,
resetting, expiry or service restart releases temporary state. Restart preserves
the persistent instance and durable history but invalidates session handles.

This lease is separate from `sql.idle_ms`: PostgreSQL/MySQL connections have no
idle expiry by default and close their logical sessions when their wire
connections close. Neither timeout cancels previously accepted durable work.

An interactive execution owns a fresh source snapshot and at most one active
cursor per session. The initial batch is number zero. Fetching the last returned
batch repeats its retained bytes after a current authorization check; requesting
the next number acknowledges it and advances the iterator. Gaps reject. The
final batch remains repeatable until closure or expiry. A lost session reports
an incomplete result; opening another session does not resume that SELECT.

Source-basis metadata distinguishes a Table cut, an explicit source cut or an
ordered vector of resource snapshots. It does not imply one atomic snapshot
across unrelated resources. Settings and inspection results have no retained
data basis. Current rights govern metadata, every batch including repeats, and
terminal counts.

## Durable work and recovery

Mutations and explicitly captured queries carry a caller-generated 128-bit
admission token. The account ledger binds that token to the exact SQL, parameters,
execution mode and database/source context. Reusing it with identical content
observes the original operation; different content conflicts. SQL equivalence
is not inferred.

Use `status` to inspect the original token or operation, `operations` to page the
account's history and `resume` to continue its saved work. A transport failure
cannot tell a caller whether admission succeeded. Resending SQL with a new token
can create another operation. Session closure, cancelling a wait, or resetting
prepared handles does not roll back an accepted mutation.

Captured queries require a service-owned source binding and publish their exact
compiled intent through the durable query owner. After reconnection or restart,
an authorized caller can inspect the original operation and use `result` to open
its complete retained output from the beginning. An ordinary interactive result
does not acquire this durability. See [query execution](queries.md) for completion,
cancellation and recovery rules.

`context` lists authorized source names. These names select server-owned native
connections, definitions, decoders and budgets; clients cannot submit a private
server file path in their place. Configuration reloads likewise retain their
original owner operation and generation. Observing a reload does not perform a
new reload.

## Types and limits

The native encoding `transit.logical.v1.hex` carries canonical logical values:
schema fields contain FTY1 descriptors, parameters contain FVL1 values, and row
cells use their schema's canonical encoding. Hexadecimal carriage preserves
wide integers, decimals, nested values and the distinction between ordinary
values, NULL, missing, type errors and conflicts. It does not convert values
through JSON floating point. Fixed byte identities use JSON integer arrays;
text uses strings.

Messages are at most 4 MiB, SQL at most 64 KiB, parameter lists at most 65 values,
and batches at most 32 rows and 1 MiB of encoded logical payload. Prepared
handles, sessions, in-flight requests, memory, spill and execution time have
additional explicit bounds in the contract and gateway configuration. These
are operation or resident limits, separate from retained history size.

The supported statement set belongs to the [SQL reference](sql.md). Native
logical types do not imply equivalent PostgreSQL/MySQL or Flight coverage.
The [service internals](../internals/service-interfaces.md) explains why transport,
session state and durable operation ownership have separate lifetimes.
