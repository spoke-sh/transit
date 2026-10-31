# Application schema and data migration v1

This contract defines the declarative application schema and data migration
lifecycle across the direct catalog ledger
([`DirectMigration`](../packages/zig/transit-catalog/src/DirectMigration.zig)),
the native SQL session wire messages
([`Migration`](../packages/zig/transit-sql-protocol/src/Migration.zig)),
the shared migration planner and resumable executor
([`MigrationRunner`](../packages/zig/transit-sql/src/MigrationRunner.zig)),
the public SQL client
([`MigrationClient`](../packages/zig/transit-sql-client/src/MigrationClient.zig)),
and the CLI subcommand (`transit migrate`).

Application schema migrations operate strictly in the **Control & Policy Plane**
and **Direct Data Plane** (`DirectCatalog`, `DirectMigration`, `TablePartition`,
and `DatabaseRuntime`). They never route admission, token deduplication,
schema inspection or recovery through `Station` actor turns (`GenServer`,
`AccountRuntime`, `Ledger`) or `STATE_V1` 256-byte KV records.

## Source ordering, naming and immutability

Migration sources are ordered UTF-8 SQL files named `<version_id>-<name>.sql`
or `<version_id>_<name>.sql`.

- `version_id` is 1–64 ASCII alphanumeric, `.` or `_` bytes and determines the
  strict lexicographical execution order. Duplicate `version_id` entries across
  files are rejected before planning or admission.
- `name` is 1–128 bytes describing the change.
- `sha256` is the 32-byte SHA-256 digest of the exact source file bytes.
- Once a migration version is recorded in the target namespace's durable ledger,
  its `source_sha256` is immutable. Modifying an already-recorded migration file
  returns outcome `checksum_mismatch` (`migration.checksum_mismatch`).

## Multi-statement decomposition and step classification

Each migration file is tokenized into 1-based ordered steps (`step_index`, source
`line`, source `column`, `statement_digest`, `owner`, `effect`, `object_name`)
using the Fuze lexical scanner. Comments, quoted strings and quoted identifiers
are preserved; interactive transaction control statements (`BEGIN`, `START
TRANSACTION`, `COMMIT`, `ROLLBACK`, `SAVEPOINT`, `RELEASE SAVEPOINT`) are
rejected with `InteractiveTransactionInMigration` because Transit interactive
transactions are scoped to local Table DML and cannot span DDL.

Supported step owners and effects:

| Owner | Effects | Execution authority |
| --- | --- | --- |
| `schema_ddl` | `create_table`, `alter_table`, `drop_table`, `create_schema`, `alter_schema`, `drop_schema` | `TableDdl` / `DirectCatalog` via `DatabaseRuntime` |
| `data_transform` | `insert_rows`, `update_rows`, `delete_rows` | Bounded `TableDml` via `DatabaseRuntime` |
| `authorization_grant` | `grant_privilege` | `AuthorizationSql` via `DirectCatalog` (requires explicit `allow_grants`) |
| `publication` | `publish_resource` | Blocked unless explicitly enabled (`allow_publication`) |
| `verification` | `verify_query` | Read-only `TableSelect` check |

## Target identity assertion

Every migration request binds to an observed target identity:

- `realm`, `resource`, `catalog`, `branch`, `namespace`
- `database`, `schema`, `account`, `principal`, `role`

Callers may supply a `TargetAssertion` (`database`, `schema`, `branch`,
`account`, `role`). Any mismatch between the asserted target and the session's
observed target rejects before planning or execution with outcome
`target_mismatch` (`migration.target_mismatch`). Applying a saved plan
(`transit_migration_plan_v1`) also verifies `expected_plan_digest` against the
computed `plan_digest` for the target and source set.

## Logical schema reconciliation and `IF NOT EXISTS` drift detection

`CREATE TABLE` and `CREATE TABLE IF NOT EXISTS` steps compute the desired
logical `TableSchema.Schema` and its canonical SHA-256 fingerprint
(`DirectMigration.logicalFingerprint`). When the target table already exists in
`DirectCatalog`:

1. `DirectMigration.reconcileCreate` compares the live `TableSchema.Schema`
   against the migration's desired schema across table kind, column count,
   column names, logical types ($\tau$), nullability, codecs ($\epsilon$),
   collations/ordering ($\kappa$), primary-key columns, and secondary indexes.
2. If the live table matches the desired schema and the statement specifies
   `IF NOT EXISTS` (or the step was already recorded as `applied` or `verified`
   under the same `step_token`), the step is classified as `already_satisfied`.
3. If the live table's schema differs from the migration's declaration—even
   when `CREATE TABLE IF NOT EXISTS` is used—the planner and executor surface
   `already_diverged` with a structured `Drift` descriptor (`aspect`, `column`,
   `expected`, `actual`) and refuse to silently mark the migration applied.

## Durable ledger and deterministic step tokens

`DirectMigration` persists migration state in the catalog's direct record store
(`DirectRecord`) and compare-and-swap revision index (`DirectClientToken`),
scoped to `(account_id, namespace)`:

- **Directory record (`0x544d4431` / `TMD1`):** ordered list of recorded
  `version_id` entries for the namespace.
- **Version record (`0x544d5631` / `TMV1`):** `version_id`, `name`,
  `source_sha256`, `plan_digest`, `VersionState`, `active_attempt_id`,
  `claimed_at_lsn`, `applied_at_lsn`, `verified_at_lsn`, and per-step
  `StepReceipt` entries.
- **Deterministic `step_token`:** derived via SHA-256 over
  `"transit.migration.step.v1\x00"`, `scope`, `branch`, `namespace`,
  `version_id`, `source_sha256`, `step_index`, and `statement_digest`.

Each mutating step is admitted through `DatabaseRuntime` using its deterministic
`step_token` as the 128-bit operation nonce and `statement_digest` as the
fingerprint.

- Concurrent runners attempting to claim an already `claimed` or `applying`
  version with a different `attempt_id` receive `claim_conflict`
  (`migration.claim_conflict`).
- If a multi-statement migration fails on step $k$, steps $1 \dots k-1$ retain
  their durable `applied` receipts and `operation_id`/`commit_lsn` in `TMV1`,
  while step $k$ records `failed` with its diagnostic code and message.
- If transport loss or timeout leaves step $k$ in `applying` or `uncertain`,
  `resume` queries `DatabaseRuntime.status` / `resumeOperation` by the original
  deterministic `step_token` without recompiling SQL or duplicating mutations,
  then advances remaining steps in the version.
