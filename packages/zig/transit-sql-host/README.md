# transit-sql-host

Shared placement and listener ownership for SQL data, computation and policies.
This library hosts `transit-sql` database runtimes and `transit-sql-service`
sessions behind native SQL (HTTP/TLS and private Unix), PostgreSQL and MySQL
listeners. It owns bounded connection memory, TLS lifetimes, recovery wakeups,
listener shutdown and joined worker tasks. It does not own catalog authority or
storage.

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
