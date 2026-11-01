# transit-sql-host

Shared placement and listener ownership for SQL data, computation and policies.
This library hosts `transit-sql` database runtimes and `transit-sql-service`
sessions behind native SQL (HTTP/TLS and private Unix), PostgreSQL and MySQL
listeners. It owns bounded connection memory, TLS lifetimes, recovery wakeups,
listener shutdown and joined worker tasks. It does not own catalog authority or
storage.

The pure PostgreSQL and MySQL `Session` engines emit bounded host requests and
borrowed output. `WireSessionDriver` maps ephemeral handles to shared-service
preparations and reads, executes requests, checks disclosure and drains output.
Connection generations and event sequences reject late or duplicate completions;
they do not replace durable operation identity. The driver closes reads before
prepared objects and codec memory. Cancellation joins borrowers before cleanup.

A scheduled caller uses `perform` to invalidate cached authorization before
resuming owner work or buffered output. Protected metadata, rows and terminal
frames carry a guard. Resumed mutation replies re-observe the original accepted
completion through the database owner, including COMMIT or DROP whose execution
attachment may have ended. The installed driver still drains requests with its
existing blocking worker/deadline orchestration; this change does not reduce
worker counts or remove timer tasks. Authentication input and TLS upgrades also
retain those deadlines.

The pure `StartupSession` engines emit input, output, TLS upgrade, credential,
verification and final admission requests through `Wire.Startup`. The host
performs credential reads, randomness, SCRAM/password verification and TLS, and
rechecks the credential before creating the shared session. Command state and
input buffers are reserved before it acknowledges final admission. Failure
releases partial admission without a successful login; an I/O or TLS failure
closes without retrying output or falling back to plaintext. Startup borrows stay
alive until the connection task joins, and credential/password storage is erased
on cleanup. The same adapter serves local and standalone placement.

Command input uses the codecs' incremental continuations. Each connection starts
with at most 8 KiB from its existing admitted session reserve, grows to a checked
frame length only when needed, and reuses its high-water capacity. Initial command
state and input capacity are admitted before the successful login/ready reply.
A command owns
its input until execution and joined cancellation finish; release erases used
bytes. Failure closes the decoder and cleanup erases the whole buffer, including
bytes from partial failed reads. Handshake input retains separate bounded owners.

Native SQL request slots retain their scratch workspaces across requests. Slot
reassignment clears the used high-water range, including freed allocations and
failed requests, without repeatedly clearing untouched reserve capacity. Data
and control admission remain separate, and every borrower joins before release.

The installed `transit server` places this host inside `transit-node`. Signed
Table and native calls use `transit-client.LocalEndpoint` and the node's shared
request lanes, storage owners and current policy checks. Result storage belongs
to the caller; request scratch cannot escape. The configuration service retains
its existing separate owner.

`transit-sql-gateway` composes the same host with HTTP-backed clients for explicit
standalone placement and provides operator controls. Moving placement does not
change SQL acceptance, client tokens, account generations or completion evidence.

`Deployment` is a private same-user Unix lifecycle channel. The installation
supervisor supplies the existing account configuration after enrollment. Starts
are identified by the complete configuration fingerprint: repeating an identical
start observes that activation, and replacement requires its current fingerprint.
The host joins the old tasks before replacement and before releasing node owners.
Its status includes bounded typed-request attempt counters, not durable outcomes.
`Shutdown` supplies an event wakeup; signal ownership remains with the executable.

Run `nix develop --command zig build test` from this package. Installed lifecycle,
restart, revocation and lost-reply schedules belong to `just test::server-sql`,
`just test::server-direct-tables`, and `just test::server-direct-faults`.
See the [SQL reference](../../../docs/handbook/reference/sql.md) and
[shared service](../transit-sql-service/README.md) for supported statements and
[SQL session contract](../../../contracts/SQL_SESSION_V1.md) for exact semantics.
