# transit-sql-service

Shared SQL sessions over the [database runtime](../transit-sql/README.md), public
Query source clients and configuration service. Native SQL, PostgreSQL and MySQL
adapters share authentication, preparation, bounded result buffers, current
permission checks and original-operation recovery through this package.

`Registry` owns bounded sessions and retained response batches. `Session` maps
configured database names to Catalog bindings. `ReadSources` composes cleanup
for explicitly configured source connections above the database runtime; it
introduces no database permission or storage authority.

Each command verifies its account credential against the native identity. Its
direct Table clients reuse that observed credential epoch when signing requests,
avoiding a separate identity read before every Table exchange. The epoch is a
claim, not permission: the owner authenticates it and checks current policy and
runtime fencing on every request. Rotation rejects a stale claim. Buffered and
repeated result batches retain their current disclosure checks.
Credential and scope denial are checked before waiting for account recovery
readiness, so revocation is reported even when it also stops background recovery.
Readiness and activation fencing still gate execution.

Prepared Table reads retain their definitions and parameter types. Each later
execution observes the current data frontier before selecting a cached snapshot;
an already open result keeps its original snapshot through completion.

Native SQL and the database wire adapters attempt accepted INSERT, UPDATE and
DELETE in the submitting request. Successful responses carry the owner's verified
terminal outcome and matched/changed counts. The foreground also settles pending
accounting; a failed settlement or interrupted command wakes recovery with the
original token and frozen intent. Status remains observation-only; ordinary
retries never recompile accepted SQL against later data.

`SessionTransaction` attaches temporary sessions to Catalog-owned Table
transactions. `TransactionSql` parses common BEGIN/COMMIT/ROLLBACK and savepoint
controls; `TransactionWork` freezes each caller command before native admission.
Private reads bypass the independent read-pin cache and retain one exact workspace
revision. The shared result model reports provisional counts and actual decisions.
See [Table transactions](../../../docs/handbook/reference/sql/transactions.md) for
scope, session loss, conflicts and resource limits.

`ConfigurationOperations` records the original reload identity and expected
configuration generation in Catalog before dispatch. `CapturedOperations` stages
a complete compiled bundle and publishes each complete signed Query request
before dispatch. `CapturedRecovery` serializes each source's uncertain request in
a Catalog CAS lane. It records the original receipt and processed-input evidence
before allowing a successor. Status reads never initialize a lane. Source actors
remain the owners of explicit captured Query execution, independently of SQL
account recovery and direct database DDL/DML.
`SessionRecovery` discovers these operations on startup and wakes on admission,
explicit resume/cancellation or uncertainty. It rotates accounts, advances every
page and owns persistent per-account transports. Incomplete work retains bounded
retry debt; settled workers make no upstream requests. Native-session and SCRAM
challenge expiry waits for actual lease deadlines and wakes when leases change.
Expiry releases temporary session state without deciding durable transactions.


`SHOW STORAGE FOR name` prepares an exact direct Table definition and reads its
signed `storage` observation at execution. `SessionStorage` projects those facts
into typed columns shared by native, PostgreSQL and MySQL results. Prepared
re-execution observes fresh progress; buffered retries preserve their original
values and recheck current inspection rights. The one-row observation creates no
data pin and invokes no maintenance. Backlog counts are bounded to 1,024 rows and
retain their completeness flag. See the [SHOW reference](../../../docs/handbook/reference/sql/show.md#table-storage-progress).

See [source bindings](docs/sources.md), the [SQL session contract](../../../contracts/SQL_SESSION_V1.md)
and [gateway configuration](../../../apps/transit-sql-gateway/docs/configuration.md).
Run `zig build test` or `zig build check` here. The real service proofs use the
[registered SQL checks](../../../tasks/test.just).

`just test::sql-gateway` exercises exact token admission, DDL/INSERT commit
recovery, fencing, counts and result framing through the native HTTP boundary.
Its commit-loss schedule observes the owner's committed outcome, withholds the
reply until the original client's deadline expires, and blocks later requests.
It kills the helper and authority and joins the old proxy connections before
restarting recovery. The original saved binding/result, authoritative rows and
counts are the recovery oracle; a helper's nonzero exit alone is not evidence
that a commit reply was lost. Failed private installations are retained for
original-outcome investigation. This process-death schedule does not establish
host power-loss durability.
