# Gateway configuration and controls

The executable accepts a private JSON configuration matching
[`Configuration`](../../../packages/zig/transit-sql-service/src/Configuration.zig).
`version: 1` and the exact native `definition` are mandatory. An incompatible
configuration or persisted operation rejects before execution. Use generated
current contracts from the same build; a v1 label alone does not identify a
compatible build.

| Field | Meaning |
| --- | --- |
| `native_url` | Signed native HTTP endpoint accessible from the private deployment |
| `tls_mode` | `disabled`, `optional` or `required` (default); independent of account authentication |
| `certificate_file`, `certificate_key_file` | PEM server chain and private key; clients verify the chain and hostname |
| `activation_directory` | Persistent private directory containing exclusive native-generation activation markers |
| `spill_directory` | Private bounded query spill location |
| `bind_address` | IPv4 listener address; default 127.0.0.1 |
| `postgres_port`, `mysql_port` | Optional distinct nonzero ports; omit both to run retained-operation recovery without SQL admission |
| `health_address`, `health_port` | Optional private HTTP readiness listener, separate from SQL ports; address defaults to 127.0.0.1. `/health` requires SQL admission; `/recovery` requires ready database recovery workers. |
| `drain_ms` | SIGINT/SIGTERM command drain bound, default 30000, maximum 270000 |
| `request_timeout_ms` | Native request bound, default 5000, maximum 60000 |
| `limits` | Explicit connection, authentication, statement, portal, byte and time budgets from the wire contract |
| `settings` | Optional explicit `{url, binding}` for the configuration service; binding contains realm, installation bytes and its registered domain object |
| `accounts` | 1–32 explicit SQL names, verifier references, native identities and database/catalog mappings |

Each account selects `authentication` (`password` by default, or explicit `trust`
or local `peer`) and supplies `name`, `verifier_file`, `execution`, `generation`,
`enabled` (default true), `keys.table` and `databases`. Disabling an account rejects
new sessions while retaining its database recovery worker. Key files contain the
native seed format. Protect configuration, keys and verifier files with deployment
file permissions. Account recovery needs the configured Table identity only.

Trust accounts are admitted only on an IPv4 loopback listener; they accept the
claimed configured login without a password or OS identity check. Their private
credential file retains the native identity, role, epoch and revision, with
`verifier: null`. Password accounts require a verifier. A mismatch rejects; a
configuration change cannot silently turn a trust credential into a password.
Both authentication methods use the same current native authorization checks.

Disabled TLS does not open PEM files. Optional TLS accepts either transport on
the same socket; missing or invalid TLS material fails startup without falling
back. Required TLS rejects plaintext with a protocol error. PostgreSQL SCRAM
works on both transports. MySQL full password authentication requires TLS and
rejects before requesting a password on plaintext. Disabled TLS with an enabled
MySQL password account is invalid configuration. Database recovery remains
independent of all listener authentication and TLS material.

`execution` defines the realm, Table principal, stable 32-byte account identity,
ordered catalog bindings, intent size limit and retained operation/byte/pending
quotas. Each database mapping includes its catalog resource, schema `namespace`
and optional selected `role` (the login role when omitted), exactly matching an
execution binding. Role selection requires current SET membership. Grant the
Table principal explicit CONNECT, schema and operation rights through the native
authorization graph. Configuration grants no rights and the service needs no
private Catalog storage access or Station process ownership.

The first accepted account reservation fixes its quotas. Later requests must use
the same limits; a smaller per-request budget cannot bypass account accounting.
Pending settlement releases pending capacity, while operation and byte charges
remain retained. Changing the execution identity or quota profile is not a way
to migrate existing accepted work.

Startup publishes a strictly increasing `generation` to the Catalog with a
compare-and-set activation record. Every database request carries that activation
revision; the Catalog checks it while holding the access boundary. A newer
activation fences the old service. Exclusive local markers detect accidental
reuse, but the Catalog record owns authority. There is no separate initialization
mode or actor provisioning. A failed activation needs a higher generation and the
same original account and bindings; deleting a marker does not grant authority.

With no SQL listeners, normal startup runs retained-operation and read-pin
recovery. It does not open listener TLS material. `/recovery` reports database
worker readiness; `/health` requires an enabled SQL listener. Removing exposure
does not cancel accepted operations. Retain the original source bindings and
current recovery grants until their pending operations and cached pins close.

Each session has a bounded allocator. A slow socket retains at most its bounded
frame/row and stops further acquisition. Handshake, idle, command and write
deadlines are distinct. `limits.idle_ms` defaults to zero, keeping idle wire
connections open. A positive value enables expiry with a PostgreSQL `57P05` or
MySQL `4031` error. The first bytes of a frame or TLS record start the finite
command-sized frame deadline. Native HTTP handles use the separate finite
`limits.session_lease_ms`, which defaults to 30000. Account recovery runs outside connection tasks, and two
reserved transport slots admit PostgreSQL cancellation when ordinary connections
are full. A cancelled command task is joined before freeing its host or buffers.
Native terminal evidence, rather than a successful transport send, determines a
write's result.

Storage is reserved at service admission and reused across statements and
connections. The registry reserves `limits.connections × limits.session_bytes`
for logical sessions and one separate `limits.session_bytes` recovery slot.
When a PostgreSQL or MySQL listener is configured, transport storage reserves
`(limits.connections + 2) × limits.session_bytes`; the two cancellation slots
remain independent of full data slots. Each native HTTP or Unix listener
reserves eight 16 MiB request slots and four control slots, each containing
16 MiB of request scratch plus `limits.session_bytes` of reusable control work.
Frame, row, canonical-cell and session budgets retain their separate meanings.
Freed temporary control objects return to their work reserve while request
JSON and reply bytes remain alive.

These capacities include allocator headers, alignment and retained slack inside
each reserve; slot directories add their own accounted bytes. Capacity stays
charged while idle. This is a backing-capacity bound, not a measurement of RSS.

The service also admits a fixed I/O runtime before opening listeners. It starts
`16 + 4A + 8W + 96N + 16H` workers, where `A` is the account count, `W` is
`limits.connections + 2` when either database-wire listener is enabled (otherwise
zero), `N` is the number of native TCP/Unix listeners, and `H` is one when health
inspection is enabled. Recovery without listeners uses only `16 + 4A`.
This envelope includes protocol tasks, nested request/deadline work and separate
control/recovery work. Each worker charges 16 KiB of shared task-record capacity
and the pinned runtime's 16 MiB requested stack; OS guard pages and pthread
bookkeeping are additional. Stacks are virtual reservations, not necessarily
resident pages. Thread or record exhaustion fails admission/scheduling; the
runtime does not allocate more backing while serving requests.

When TLS listeners are enabled, OpenSSL uses one additional fixed reserve of
`(16 + T) MiB`, where `T` is `limits.connections` for enabled database-wire TLS,
plus 16 for native TCP TLS. Provider state, connection objects, reallocations,
headers and fragmentation all consume that reserve. Crypto allocation exhaustion
fails the TLS operation without a heap fallback; freed payloads are erased.
All connection tasks join, then a barrier ends OpenSSL state on every I/O worker
before runtime and process cleanup free the reserve. This bounds these owners independently of account runtime, source
and authority allocations; it is not a whole-process zero-allocation claim.
Account workers and source/authority clients own additional storage beyond these
reserves. Exhaustion has no general-heap fallback in the result
reserves. Connection/request tasks join before reuse, and reassigned storage is
erased so another account cannot inherit payloads or credentials. Retained
cursor output outlives request buffers and sockets; retries preserve its ordinal
and still require fresh disclosure authorization.

Native HTTP capacity refusal maps to PostgreSQL SQLSTATE `53000`, or MySQL error
1041 with SQLSTATE `HY000`. Bounded metadata acquisition can retry that explicit
refusal within the command deadline. A failed query iterator is never restarted
inside the same result. Applications can issue a fresh SELECT after discarding
an incomplete result. For mutations, inspect the retained operation first:
capacity exhaustion can interrupt observation after admission. SQLSTATE alone
does not establish that a write was rejected before admission.
An unready or fenced gateway owner reports PostgreSQL `55000` (MySQL's generic
1105/HY000 error with the explicit readiness message). This can follow transient
native unavailability. It neither transfers ownership nor cancels retained work.

The optional private health listener serves GET `/health` with 200 only while all
account workers report ready and the service is admitting requests; otherwise it
returns 503. GET `/live` reports process liveness. Neither route reads application
data or grants execution rights. Readiness reflects the most recent account pass;
a pending native request remains bounded by its configured timeout. SIGINT and
SIGTERM stop SQL admission and allow active commands to finish within `drain_ms`,
then join connection tasks before account workers. Accepted work remains in the
Catalog for a fresh fenced activation. A completed shutdown is not a rollback or
proof that all durable work is terminal.

The [deployment example](../../../examples/sql-wire/README.md) supplies Compose
and Kubernetes/Substrate placement with persistent activation storage, separate
spill, verified client TLS and explicit native replacement. Keep SQL and health
listeners private to their intended clients and operators. Kubernetes readiness
uses `/health`; liveness uses `/live`. A failed activation must be repaired
through native ownership and retained operation evidence, not by removing its
activation marker or repeatedly restarting the same generation.

## Signed operator controls

Use `transit-sql-gateway control /private/sql-control.json ACTION`. The profile
contains `version`, `definition`, `native_url`, the same `execution`,
`table_key_file` and optional `timeout_ms` (default 30000, maximum 270000).
All operations use the current Table principal and role.

| Action | Behavior |
| --- | --- |
| `list [AFTER_ID]` | Reads at most eight operation references and an optional next numeric cursor |
| `status OPERATION` | Reads the original domain outcome with current disclosure authorization |
| `cancel OPERATION` | Records sticky cancellation intent; the original owner decides the terminal outcome |
| `credential PASSWORD_FILE VERIFIER_FILE REVISION` | Atomically writes a salted verifier |

List and status do not publish recovery work. Pagination is ordered by original
acceptance LSN; it is not an atomic snapshot. Concurrent progress can change an
operation between listing and inspection. Retained history has no automatic
expiry. Terminal mutation counts require CONNECT, USAGE and the original action's
privilege. Revoking INSERT hides its receipt without undoing an accepted insert.

The complete frozen intent is staged before token acceptance. An accepted token
therefore always identifies recoverable work, never missing SQL upload parts.
A cancelled or timed-out wait does not prove rejection or rollback. Discover and
inspect the original operation before deciding whether new SQL is appropriate.
Cancellation is idempotent and remains visible until the original owner supplies
its actual terminal outcome.

The credential command reads 1–128 printable ASCII bytes exactly, without
stripping a newline, uses secure random salt and 65536 PBKDF2 iterations, and
requires a nonzero revision. Increment the revision on rotation. To disable an
account, atomically replace the credential with `enabled: false` while preserving
its current definition/account identity. The generated verifier records the native principal, stable login role and
credential epoch observed using the configured Table key. Sessions recheck the
complete credential, that native binding, selected-role eligibility, database
CONNECT and current native rights before new work and each result disclosure. Certificate
changes require a fenced service replacement. Passwords, SQL values and private
keys do not belong in command arguments, Git or logs.

Native key rotation preserves the login role and its grants. Replace the key
reference, generate a verifier for the new epoch, and establish a fresh fenced
gateway activation. Existing sessions cannot adopt the new epoch. Database recovery retains the original frozen intent and operation identity.
It inspects that identity before executing the same intent under current rights.
Explicit captured source requests retain their original signed bytes and caller
sequence; their recovery never replaces an uncertain request. Policy revocation can prevent further progress or disclosure without
erasing the operation or undoing a committed mutation.

## Settings service binding

An explicit `settings` binding enables host `SHOW`, `transit_settings()`,
`transit_config_reloads()` and standalone `transit_reload_conf()`. The URL names
the service base, not a filesystem path. The account's authenticated Table
principal and selected role sign each request. Grant inspection, provenance and
reload independently on the target configuration domain; no native administrator
key is loaded by the adapter. Without a binding, host administration reports
unavailable. Catalog SHOW and session controls retain their own owners.

When a settings binding is configured, login requires configuration inspection
permission to capture the current statement timeout and ceiling. A denied or
unavailable owner fails login; it does not supply unrestricted defaults. SET
changes only that session; RESET restores the captured default. Its deadline is
the stricter of the configured command budget and nonzero statement timeout.
The fixed PostgreSQL/MySQL encoding/autocommit probes retain their requirements.

Preparation authorizes without dispatch; Execute dispatches reload once for that
result. Each account stores the complete original configuration request in the Catalog
before dispatch. After a lost reply, recovery reconciles that saved operation
using its original generation, caller and selected role. Retained
history requires current inspection rights. Configuration and Table mutation
owners remain separate, and neither cancellation nor connection loss undoes
accepted work. See [settings SQL](../../../docs/handbook/reference/sql/settings.md) and
the [configuration contract](../../../contracts/CONFIGURATION_V1.md).
