# transit-sql

Shared database wire types, budgets and credential verification above the public
query and catalog owners. The module is `transit_sql`; SQL compilation,
source snapshots and mutation authority stay with Fuze, Query and Catalog.

`Type.from` admits int64, uint64, finite float64, Boolean, UTF-8 and binary fields.
`Type.value` validates a cell against its exact descriptor. SQL NULL requires
nullability; missing, type-error and conflict cells return distinct errors.
Unsupported stored types do not acquire wire support through projection.

`Limits.validate` checks explicit bounded deployment, session, framing and timeout
configuration. `Authentication.Verifier` derives a salted SCRAM-SHA-256 verifier
with 4096–262144 iterations (65536 default). Its stored definition is mandatory.
Passwords contain 1–128 printable ASCII bytes; SASLprep is the identity for this
profile. Other codepoints and NUL reject at provisioning and full-password
verification. Salts and nonces are supplied by the I/O owner from secure entropy.

`Authentication.Scram` implements the non-PLUS SCRAM exchange. It checks the exact
nonce/channel-binding header, verifies the client proof in constant time, returns
the server proof and consumes every attempt. It erases secret working buffers.
The full-password verifier supports MySQL's full authentication path only when
the caller has already established TLS. Callers own account selection, current
credential revision, TLS, authentication concurrency and input-buffer erasure.

These are library interfaces. The
[gateway application](../../../apps/transit-sql-gateway/README.md) owns network
listeners and deployment lifecycle. See the
[wire contract](../../../contracts/SQL_GATEWAY_V1.md) and
[executed evidence](../../../tests/README.md#database-wire-foundation).

Run `zig build test` or `zig build check` inside `nix develop`; independent Python
credential, scalar and stored-record fixtures are checked by `just test::sql-wire-contracts`.

`SavedStep` retains exact signed Table sends in a bounded binary record and
verifies them against the original intent and public key. `Upload` stages finite
records through Station publication in 128-byte ingress parts, preserving
unpublished/committed distinctions. `Ledger` supplies the
[account operation state machine](docs/ledger.md): paged discovery, explicit
reservations, fenced preparation, exact signed steps and separate native/SQL
observations. It performs no dispatch; the host supplies actual observations and
current native/catalog authorization.

`Control` defines bounded current-definition native inputs. `Behavior` adapts the
ledger to GenServer, with attributed rejection records and retryable source
failures. `Client` prepares and retains exact signed controls and observes input
progress. `Coordinator` proposes fenced transitions, reads published saved steps
before dispatch, and observes original Table outcomes. Its caller serializes
control requests and retains each exact request until its disposition is known.

`AccountRuntime` composes that worker and coordinator with one bounded
`ControlLane` per sequenced role. Connection cancellation releases its wait while
the account retains and polls the exact pending ingress request. Concurrent ledger
updates invalidate exact-current reads; the runtime reacquires those reads while
preserving pending commands. Terminal disclosure checks the original Table
outcome under current rights, separately from the ledger's retained summary.
Callers run `tick` independently of sockets, supply exclusive activation evidence
before starting, and join worker/connections before freeing the runtime. Startup
requires an already provisioned and initialized ledger with eligible native
ownership; it does not grant rights or reuse an activation.
`bootstrap` permits a separate initialization activation to wait for an explicit
operator-signed initialize control, without becoming ready while the ledger is
absent. The application keeps SQL listeners closed during that activation.

`Configuration` validates explicit SQL account/database mappings, disjoint native
sequence owners, TLS/key references and connection budgets. `Credential` binds a
versioned verifier to an account identity, revision, native principal, stable
login role and credential epoch. Database mappings retain an explicit schema
namespace and optional selected role. A separate private reader supplies storage
access while the Table caller supplies current object authority. Signed saved
steps retain their signing key across rotation; exact receipt recovery precedes
retry of the original bytes. File loading,
atomic credential replacement and session revocation are host responsibilities;
these types do not themselves supply a listener or credential-watching service.

`Statement` owns SQL text and immutable catalog metadata for typed single-Table
SELECT/DML, literal CREATE and literal relational SELECT. Preparation and
`checkValues` do not open a data snapshot or submit a native input. `validate`
rechecks current rights and source identity before cached metadata disclosure;
execution independently captures a new authorized cut or creates an exact typed
Table intent. Every relational target uses the selected database's explicit
catalog mapping. Captured relational descriptors must still match preparation
before any executor step. Parameterized relational SQL is excluded.

`Session` owns preparation, result iteration, settings and current-authorization
checks independently of a database wire protocol. The supervised SQL application
creates sessions over each account’s shared `AccountRuntime`. PostgreSQL and
MySQL retain their protocol admission and scalar encoding rules in their adapters.
Session cleanup releases reads and transports; durable account operations remain
in the ledger.
