# Application schema and data migration v1

This contract defines the declarative application schema and data migration
lifecycle across the direct catalog ledger
([`DirectMigration`](../packages/zig/transit-catalog/src/DirectMigration.zig)),
the native SQL session wire messages
([`Migration`](../packages/zig/transit-sql-protocol/src/Migration.zig)),
the shared migration planner and resumable executor
([`MigrationRunner`](../packages/zig/transit-sql-service/src/MigrationRunner.zig)),
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

Each source file is bounded to 64 KiB, independently of the executable SQL
owner's statement limit. A file may contain multiple individually bounded
statements and comments whose total exceeds 4,096 bytes. Its checksum covers
all original bytes, including comments and whitespace. This does not raise the
finite SQL statement limit or grant support to an otherwise unsupported owner.

## Multi-statement decomposition and step classification

Each migration file is tokenized into 1-based ordered steps (`step_index`, source
`line`, source `column`, `statement_digest`, `owner`, `effect`, `object_name`)
using the Fuze lexical scanner. Migrations compose the ordinary SQL service's
preparation and operation owners. The exhaustive `Session.Prepared.migrationPolicy`
switch requires every prepared owner and native plan variant to choose read,
durable-operation or unsupported migration semantics. Statements without a
staged-definition adapter use ordinary SQL preparation against the live catalog;
there is no migration keyword allowlist for those statements.

Framing retains a Queue dataflow's compound body as one source step, including
nested `BEGIN`/`END`, `IF`/`END IF` and `CASE` expressions. It does not execute or
semantically validate that program: Queue dataflow preparation remains
unsupported. Unterminated quoted tokens/comments, unbalanced parentheses/blocks
and nesting beyond 64 levels reject the file. Ordinary transaction-control
statements remain separate steps and retain the rejection below.

Interactive transaction controls and session-setting mutations are unsupported:
the migration ledger already owns ordered, independently committed steps, and
its target cannot change within a version. Planning reports an owning SQL error
or `MigrationSessionControlUnsupported` with source path, line, column, version
and step. `COMMIT OFFSET` retains its distinct Stream workload semantics.
Grammar-only forms, including connector publication and dataflow replacement,
remain unsupported until their ordinary execution owners exist. The former
`allow_publication` placeholder is removed; it never supplied those owners.

| Owner | Effects | Execution authority |
| --- | --- | --- |
| `schema_ddl` | `create_table`, `alter_table`, `drop_table`, `create_schema`, `alter_schema`, `drop_schema` | `TableDdl` / `DirectCatalog` via `DatabaseRuntime` |
| `data_transform` | `insert_rows`, `update_rows`, `delete_rows` | Bounded `TableDml` via `DatabaseRuntime` |
| `authorization_grant` | `grant_privilege` | `AuthorizationSql` via `DirectCatalog` (requires explicit `allow_grants`) |
| `verification` | `verify_query` | Shared SQL read owner, consumed through verified completion |
| `computation` | `create_dataflow`, `control_dataflow` | Shared `ManagedSql` / `ManagedOperations` / `ManagedTable` owners |
| `service` | `execute_statement` | Ordinary SQL preparation and shared statement operation dispatcher |

Table schema and finite Table dataflow adapters plan against ordered working
schemas, including Tables declared earlier in the same file or an earlier
version. Other statement owners require their dependencies to exist when ordinary
preparation runs. Planning neither creates objects nor executes queries. Applying
read statements consumes bounded batches, validates terminal completion and
rechecks disclosure authority; it does not return their rows or infer assertions
from a nonempty result. Retained workload rows are reopened by original operation
identity and consumed through that same result lifecycle.

## Dataflow planning, controls and verification

The existing [finite managed Table profile](DATAFLOW_V1.md) applies unchanged:
one Table source, an existing compatible output Table, and a cohosted native SQL
service. `CREATE DATAFLOW` publishes a definition. `AUTHORIZE`, `ACTIVATE`,
`SUSPEND`, `RESUME`, `REFRESH` and `RETIRE DATAFLOW` use their ordinary control
transitions. A completed `ACTIVATE` step establishes that control transition;
`SHOW DATAFLOW` reports background progress and verified computation completion
separately. Definition replacement remains unsupported.

A computation step records source/output logical schema fingerprints, exact
existing definitions or preceding producer-step identities, the query digest,
its existing definition or declaration step, and before/after control state.
This evidence participates in the reviewed version digest. Producer references
resolve only through successful migration receipts carrying their exact accepted
`object_definition`. Before new admission, the executor compares live definitions
and control state with this evidence. A replaced Table with the same name and
columns cannot silently rebind the plan.

On apply and resume, dataflow operations record their original `operation_kind`,
`operation_id` and accepted `object_definition`. They do not manufacture a Table
`commit_lsn` or row count from the SQL operation ID. Verification compares the
final applied declaration/control for each name, including across later applied
versions. Earlier controls legitimately superseded by those versions are not
reported as drift. Independent background result revisions are not declaration
or control drift; an external control change is `migration.dataflow_drift`.

## Target identity assertion

Every migration request binds to an observed target identity:

- `realm`, `resource`, `catalog`, `branch`, `namespace`
- `database`, `schema`, `account`, `principal`, `role`

Callers may supply a `TargetAssertion` (`database`, `schema`, `branch`,
`account`, `role`). Any mismatch between the asserted target and the session's
observed target rejects before planning or execution with outcome
`target_mismatch` (`migration.target_mismatch`). Applying a saved plan
(`transit_migration_plan_v1`) also verifies `expected_plan_digest` against the
computed `plan_digest` for the target and source set. The digest includes the
account, principal and optional role as well as the catalog coordinates and
database/schema names.

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

SQL operation steps use the shared `StatementOperations` dispatcher with their
deterministic `step_token` as the 128-bit operation nonce and `statement_digest`
as the fingerprint. It selects the original database, managed-computation or
other service owner for admission, status, result opening and resume. Explicit
authorization/grant steps retain their separate opt-in policy path.

- Concurrent runners attempting to claim an already `claimed` or `applying`
  version with a different `attempt_id` receive `claim_conflict`
  (`migration.claim_conflict`).
- If a multi-statement migration fails on step $k$, steps $1 \dots k-1$ retain
  their durable `applied` receipts and `operation_id`/`commit_lsn` in `TMV1`,
  while step $k$ records `failed` with its diagnostic code and message.
- If transport loss or timeout leaves step $k$ in `applying` or `uncertain`,
  `resume` resolves the original deterministic `step_token` through the shared
  dispatcher and resumes its recorded owner without recompiling accepted SQL
  or duplicating mutations,
  then advances remaining steps in the version.


## Current-v1 cutover

The migration ledger definition is `transit.direct.migration.v1.2026-11-06`.
The shared contract-set fingerprint changes with the computation receipts and
statement execution semantics. Missing or foreign ledger/plan definitions are
rejected. Old plans, installations and accepted work must be handled by their
matching build; this change provides no converter or automatic reset. See
[versioning](../docs/handbook/reference/versioning.md).
