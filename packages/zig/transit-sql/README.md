# transit-sql

Shared logical SQL sessions, account recovery, budgets and credential verification
above the public query and catalog owners. The module is `transit_sql`; SQL compilation,
source snapshots and mutation authority stay with Fuze, Query and Catalog.

`Session.write` returns the shared `CommandCompletion` used by native SQL,
PostgreSQL and MySQL. Command kind comes from the retained intent; matched and
changed counts come from verified owner evidence. PostgreSQL projects matched
counts into its command tag. MySQL selects changed counts for UPDATE unless the
client requests found rows. Session settings carry no applicable row counts.
An adapter rejects invalid counts or a non-success outcome before writing a
successful command terminator.

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
[executed evidence](../../../docs/history/qualification/sql.md#database-wire-foundation).

Run `zig build test` or `zig build check` inside `nix develop`; independent Python
credential, scalar and stored-record fixtures are checked by `just test::sql-wire-contracts`.

`IntentReference` stores a bounded reference to a complete immutable direct Table
intent. `Upload` publishes that reference through the private Station ledger in
128-byte ingress parts; row bytes remain with the direct data owner. `Ledger`
supplies the [account operation state machine](docs/ledger.md): paged discovery,
reservations, permanent dispatch eligibility and exact terminal binding. It
performs no dispatch and does not provide Table acceptance authority.

`Control` defines bounded current-definition native inputs. `Behavior` adapts the
ledger to GenServer, with attributed rejection records and retryable source
failures. `Client` retains exact signed ledger controls and observes their input
progress. `Coordinator` checks the current native generation, reads a committed
intent reference, observes its original direct operation and explicitly admits,
executes or cancels that same work. A lost response never allocates a replacement
intent or resolves its target name again.

Before a ledger control is sent, temporary unavailability of its preparation
reads uses the original statement deadline. Repeated changes to observed state
retain a separate 64-retry bound. Once prepared, the control lane retains the
exact signed request through uncertain sends and receipt observation; retries
do not restart the statement's budget.

Temporary direct-operation transport failures, current direct-access denial and
allocation pressure retain the original operation for another bounded recovery
pass. They do not mark a healthy native ledger owner unavailable. The gateway
reports changes in that condition as `sql.operation.recovery_blocked`; it does
not log row values or credentials. Status, cancellation and unrelated reads
still perform their own current checks. A lost native generation, invalid
binding or malformed response continues to stop the account owner.

Conditional CREATE on an existing Table and conditional DROP on an absent name
retain an inline catalog name assertion. The catalog records unchanged, rejected
or cancelled under the frozen condition and current rights. These outcomes carry
a catalog acceptance position and zero row counts. Preparation and binding do
not admit them; a changed condition rejects instead of selecting a new target.

Native SQL CREATE SCHEMA, ALTER SCHEMA ... RENAME and DROP SCHEMA retain a
namespace binding in the same ledger. Preparation freezes the exact schema and
owner without allocating IDs; CREATE uses the accepted operation ID for its new
namespace. Schema acceptance, cancellation and bounded RESTRICT belong to the
direct catalog. Completion carries the catalog position and zero row counts.
The PostgreSQL/MySQL profiles do not execute these schema statements.

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
namespace and optional selected role. Direct Table metadata and data reads use
the Table caller's current signed identity; they do not require a private raw
storage reader. File loading, atomic credential replacement and session
revocation are host responsibilities.

`Statement` owns SQL text and immutable catalog metadata for typed single-Table
SELECT/DML, literal CREATE and literal relational SELECT. Preparation and
`checkValues` do not open a data snapshot or submit a native input. `validate`
rechecks current rights and source identity before cached metadata disclosure;
execution independently captures a new authorized cut or creates an exact typed
Table intent. Every relational target uses the selected database's explicit
catalog mapping. Retained relational descriptors must still match preparation
before any executor step. Independent Tables carry independent partition cuts;
repeated aliases of one Table share a pin. Parameterized relational SQL is excluded.

`Session` owns preparation, result iteration, settings and current-authorization
checks independently of a database wire protocol. The supervised SQL application
creates sessions over each account’s shared `AccountRuntime`. PostgreSQL and
MySQL retain their protocol admission and scalar encoding rules in their adapters.
`Read.nextBatch` owns up to 32 logical rows and 1 MiB of canonical cell bytes,
independently of direct Table/Arrow page sizes. It fills across source pulls,
copies nested values before scratch reuse, retains a row that does not fit the
remaining byte budget and rejects a row that cannot fit an empty batch. Current
rights are checked after buffering. Exhaustion can accompany data or a subsequent
empty terminal batch; neither creates another result.
Settings preparation and page reads use the settings transport's own rejection
when deciding bounded recovery and reporting SQL errors. Transient page failures
resume the retained continuation, including private ordered rows; current denial
and changed configuration snapshots remain terminal. Reload submission stays
outside observation retries and retains its original journal identity.
Session cleanup releases reads and transports; durable account operations remain
in the ledger. `ReadPins` records each original acquisition before its first
request and marks closure before attempting release. A bounded recovery pass
closes interrupted acquisitions and pins from earlier gateway generations using
the original identity and current rights. Failed cleanup retains its record and
reports `sql.read.cleanup_blocked`; it never expires a pin or silently recaptures
a newer snapshot. See [pin recovery](docs/ledger.md#interactive-read-pin-recovery).

`Registry` admits native HTTP/peer, PostgreSQL and MySQL sessions against shared
account limits. `SourceSession` owns explicitly configured source reads.
`SessionOperations` pages Table, configuration and captured-query references by
account token. `CapturedLedger` freezes bundles and exact native submissions;
`CapturedOperations` drives the existing Query owner and verifies retained results.
`ConfigurationOperations` retains and resumes the configuration owner's original
reload identity. The recovery task scans one pending reference per pass rather
than loading the durable backlog into memory.

See [source bindings and captured queries](docs/sources.md) and the
[native session contract](../../../contracts/SQL_SESSION_V1.md).
