# Gateway configuration and controls

The executable accepts a private JSON configuration matching
[`Configuration`](../../../packages/zig/transit-sql-gateway/src/Configuration.zig).
`version: 1` and the exact native `definition` are mandatory. An incompatible
configuration or persisted operation rejects before execution. Use generated
current contracts from the same build; a v1 label alone does not identify a
compatible build.

| Field | Meaning |
| --- | --- |
| `native_url` | Signed native HTTP endpoint accessible from the private deployment |
| `certificate_file`, `certificate_key_file` | PEM server chain and private key; clients verify the chain and hostname |
| `activation_directory` | Persistent private directory containing exclusive native-generation activation markers |
| `spill_directory` | Private bounded query spill location |
| `bind_address` | IPv4 listener address; default 127.0.0.1 |
| `postgres_port`, `mysql_port` | Optional distinct nonzero ports; at least one is required |
| `health_address`, `health_port` | Optional private HTTP readiness listener, separate from SQL ports; address defaults to 127.0.0.1 |
| `drain_ms` | SIGINT/SIGTERM command drain bound, default 30000, maximum 270000 |
| `request_timeout_ms` | Native request bound, default 5000, maximum 60000 |
| `limits` | Explicit connection, authentication, statement, portal, byte and time budgets from the wire contract |
| `accounts` | 1–32 explicit SQL names, verifier references, native identities and database/catalog mappings |

Each account supplies `name`, `verifier_file`, `ledger`, `generation`, optional
state `association` (default `state`), `keys` and `databases`. Key references are
`worker`, `ingress`, `coordinator` and `table`; key files contain the native seed
format. Protect configuration, keys, verifier and recovery files with deployment
file permissions. The operator control key is separate from the running service.

`ledger` defines the realm, private resource, owner process, five distinct
principals, Table public key, account fingerprint, admitted catalog bindings and
durable quotas. Its five roles are worker, ingress, control, coordinator and
Table principal. Give the worker execution and private resource write access;
give each control role its scoped send/read rights. Give the Table principal
only the explicit catalog/resource permissions required for the selected
database operations. Associations and local configuration grant no rights.
Database bindings must exactly match the ledger's immutable ordered bindings.
Sequenced principals and private owner/resources cannot be shared across SQL
accounts.

Provision through the public native/application operations: create the private
resource and process, assign its state association and scoped grants, establish
the worker's ownership generation, and grant the Table principal access through
the catalog owner. Native lifecycle and catalog controls remain their public
owners; the gateway never acquires an administrator key or provisions implicitly.

To initialize a new private ledger, run a separate eligible activation with
`transit-sql-gateway --initialize /private/sql-gateway.json`, then prepare and
submit the operator `initialize` control below. This mode runs the ledger worker
without SQL listeners and exits once every account has committed initialization.
It waits up to 120 seconds. Establish a fresh native generation before starting
the normal service. Normal startup requires an initialized ledger and current
ownership. Reusing an activation marker fails, including after an idle exit.
Replacement must fence the previous native owner before resuming saved work;
restarting a container or deleting a marker does not establish authority.

Each session has a bounded allocator. A slow socket retains at most its bounded
frame/row and stops further acquisition. Handshake, idle, command and write
deadlines are distinct. Account recovery runs outside connection tasks, and two
reserved transport slots admit PostgreSQL cancellation when ordinary connections
are full. A cancelled command task is joined before freeing its host or buffers.
Native terminal evidence, rather than a successful transport send, determines a
write's result.

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
ledger for a fresh fenced activation. A completed shutdown is not a rollback or
proof that all durable work is terminal.

The [deployment example](../../../examples/sql-wire/README.md) supplies Compose
and Kubernetes/Substrate placement with persistent activation storage, separate
spill, verified client TLS and explicit native replacement. Keep SQL and health
listeners private to their intended clients and operators. Kubernetes readiness
uses `/health`; liveness uses `/live`. A failed activation must be repaired
through native ownership and retained operation evidence, not by removing its
activation marker or repeatedly restarting the same generation.

## Signed operator controls

Use `transit-sql-gateway control /private/sql-control.json ACTION`. The private
operator configuration contains `version`, `definition`, `native_url`, the same
`ledger`, `control_key_file`, `table_key_file`, `pending_file` and optional
`timeout_ms` (default 30000, maximum 270000). The Table key is used for current
terminal disclosure and initial sequence inspection, not a second write lane.
Dedicate one pending file and exclusive operator owner to each control principal.

| Action | Behavior |
| --- | --- |
| `list [cursor.json]` | Reads at most eight operation summaries and a next cursor; exposes no stored counts or values |
| `status OPERATION` | Reads the ledger and freshly authorized original Table outcome; counts require matching terminal evidence |
| `pending` | Shows the saved control's receipt and processed disposition without sending |
| `prepare initialize` | Reads the dedicated Table principal sequence and saves the initialization request |
| `prepare reconcile OPERATION` | Saves an exact-reconciliation request for existing work |
| `prepare cancel OPERATION` | Saves qualified cancellation intent; completion still requires original native evidence |
| `prepare capacity OPERATIONS BYTES PENDING` | Saves an explicit ledger capacity change |
| `prepare reserve OPERATION BYTES` | Saves an explicit operation reservation increase |
| `submit` | Submits the saved signed request, or continues observing its known receipt |
| `credential PASSWORD_FILE VERIFIER_FILE REVISION` | Creates a salted verifier and atomically replaces its private file |

Preparation does not send. It atomically saves and syncs the exact signed request
before returning. An unresolved saved request blocks preparation of a successor.
`submit` retains unknown outcomes and retries the identical bytes after a lost
receipt. Processed controls remain recorded; their disposition is distinct from
the SQL operation's terminal state. The pending file is locked during mutations.
Inspection never sends or reconciles. A cursor pins one ledger revision; changes
invalidate it explicitly, requiring a new first page. Retained history has no
automatic expiry.
List/status observations retry a concurrent current-revision read conflict within
the configured timeout, before printing a result. They do not advance a supplied
cursor to another revision. Terminal inspection batches finite intent reads and
checks the original Table result under current rights. A SQL command can exhaust
its wait while an admitted operation continues; discover and inspect that
operation instead of sending the SQL again.

The credential command reads 1–128 printable ASCII bytes exactly, without
stripping a newline, uses secure random salt and 65536 PBKDF2 iterations, and
requires a nonzero revision. Increment the revision on rotation. To disable an
account, atomically replace the credential with `enabled: false` while preserving
its current definition/account identity. Sessions recheck the complete credential
and current native rights before new work and each result disclosure. Certificate
changes require a fenced service replacement. Passwords, SQL values and private
keys do not belong in command arguments, Git or logs.
