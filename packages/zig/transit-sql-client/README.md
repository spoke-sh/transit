# Native SQL session client

`transit_sql_client` connects to the shared SQL service over HTTP/TLS or a private
Unix socket. It depends on `transit-sql-protocol`; it does not import the SQL
runtime, account signing keys or storage adapters.

`Client.init` validates endpoint and trust configuration. `open` negotiates the
current definition and instance, performs peer/trust/SCRAM login and retains the
logical session. `call` returns an owned parsed response; the caller must call
`deinit` on each response. A client has one borrower. A separate client with the
same instance/session may issue independent controls. `Client.deinit` releases
transport resources; explicitly send `close` to release the logical session.

TCP credentials use HTTPS with system roots or a configured PEM CA bundle.
Plain HTTP requires explicit loopback trust. Redirects are refused. No request is
automatically replayed. Mutation callers retain their original admission token
and inspect its outcome after an uncertain reply. HTTP sockets may be replaced
without replacing the logical session. Idle callers renew the lease with `touch`;
expired sessions do not reopen an interrupted read.

`Discovery` reads nonsecret local rendezvous records under an owner-checked
runtime directory. On Linux, the service verifies the socket peer UID. The
fallback is `/tmp/transit-<uid>` with mode `0700`; an installation path digest
selects its socket. Missing/foreign definitions, unsafe directories, links at
owned socket paths and a live socket are rejected. Only the service holds the
socket ownership lock.

Run `nix develop --command sh -c 'cd packages/zig/transit-sql-client && zig build test'`.
The public messages and failure rules are in the
[SQL session contract](../../../contracts/SQL_SESSION_V1.md).

`Pending` observes one original admission token under a single deadline. It never
contains or replays SQL. It can open one separately authenticated observation
session after expiry, pinned to the same instance and account; this does not
restore the caller's session or settings. Interruption requests cancellation of
the active query and original operation where supported, with a one-second
settlement budget. Missing observation, timeout and denial do not imply rejection.
The caller still renders the confirmed outcome or explicit uncertainty. This is
an adapter to the existing session API, not the future logical result-set API.
