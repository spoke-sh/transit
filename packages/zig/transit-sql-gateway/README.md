# transit-sql-gateway

Shared database wire types, budgets and credential verification above the public
query and catalog owners. The module is `transit_sql_gateway`; SQL compilation,
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

These are library interfaces. Network listeners and deployment lifecycle are
separate integration work. See the
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
