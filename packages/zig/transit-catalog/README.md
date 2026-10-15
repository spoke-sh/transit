# transit-catalog

Named typed Tables and schema lifecycle above Station, exported as
`transit_catalog`. Fuze owns pure schemas, values and SQL/typed compilation;
Station owns bounded immutable row/index publication; Catalog owns names,
metadata, native authorization bindings and attributed operation outcomes. The deterministic
catalog helper performs no I/O. The signed caller uses the public native client.

`TableIntent.Binding.matches` checks saved steps through a bounded equality
adapter over the original command bytes. An immutable-publication owner can
validate one inline command or one upload part without reloading a whole intent.
The owner must establish the complete canonical intent before retaining that
binding; this interface performs no authorization or signing.

## Schema, lifecycle and authorization

`TableCatalog` resolves live names and immutable historical definitions in an
explicit resource/catalog scope. Object and column identities survive rename;
name reuse allocates another object. Definitions bind complete shared logical
schemas, defaults, primary keys and immutable physical references. Catalog and
Table cardinality remain independent of resident page size.

`TableCatalogRecords.Configuration` fixes the worker PID, bootstrap principal,
scope, publication quotas and native database/schema/Table domains. Stable native
database naming is explicit. `SchemaCatalog` provides CREATE, stable-identity
rename, bounded DROP RESTRICT and current authorized namespace inspection.
`AuthorizationSql` lowers role/privilege/schema SQL to reviewable native or
catalog actions with a policy revision precondition. Stable native
role ownership is separate from the worker PID. Every Table operation requires
CONNECT on its database and USAGE on its schema. CREATE additionally requires
schema CREATE; data operations require their Table privilege; ALTER and DROP
require ownership. Metadata visibility follows ownership or an applicable Table
grant. There is no catalog-local permission store. Current native authority is
checked during work and disclosure, including the original credential epoch and
selected role. Names, retained roots and prepared artifacts grant no permission.

`TableBehavior` accepts initialization and administrator controls, staged Table
commands, continuation and qualified cancellation/cleanup. It records control or
rejected-input dispositions independently of the original operation outcome.
The [catalog role](../../../apps/transit-query-host/README.md) runs it with explicit
configuration, scoped courier and fresh fenced ownership. Initialization and
resource provisioning remain separate operations.

CREATE publishes the name, immutable schema/metadata, empty head and outcome.
ALTER separates metadata-only changes from complete validation/rewrites.
DROP uses explicit dependency records, RESTRICT, tombstones and identity-safe
name reuse. DML freezes selection and publishes one complete successor with
committed matched/changed counts. Staging never exposes a successful prefix.
The owner preserves the four-mutation native turn boundary; larger work advances
through durable bounded stages rather than widening that boundary.

[General Table metadata and caller operations](docs/table-metadata.md) define
physical records, schema references, atomic transitions, policy, dependencies,
cleanup, ownership and exact limits. The [Table reference](../../../docs/reference/tables.md)
and [SQL reference](../../../docs/reference/sql.md) describe user-facing behavior.

## Signed and neutral callers

`TableClient` prepares general Table SQL and typed intent, signs individual
steps, submits exact saved commands and inspects original outcomes. Direct callers
need explicit raw-resource access. Restricted callers use the
[Table service](../../../apps/transit-table-service/README.md), whose private
storage identity is separate from the signed original subject. Its unsigned
`Candidate` binds the exact native request; callers verify and sign that request
with their own key. A mediated client cannot sign with the service key. Current
metadata lookup binds the source before preparation. Loading saved work never
resolves its name again or recompiles against a replacement schema.

`TablePreparedDml.prepare` owns a typed INSERT/UPDATE/DELETE template after
current operation-right and metadata checks. `bind` rechecks both and returns an
independent `TableIntent`; it performs no send. `TableBinding` includes the
caller and complete immutable metadata while allowing later data revisions.
See [Table preparation](../../../contracts/SQL_PARAMETERS_V1.md#catalog-table-preparation)
for NULL, dialect, identity and bounded-operation rules.

Each metadata acquisition seeds a bounded 64-key cache from one authorized
resource revision. Schema chunks share native read batches at that same cut;
missing keys are cached too. Read failures poison the acquisition, and a later
call acquires current policy and resource evidence again. This cache neither
retains a snapshot nor carries permission between calls.

`TableAuthority.Context.wrapAcquisition` lets a bounded read coalesce repeated
checks of its accumulated native privilege requirements. Its owner must call
`finish` before disclosure, including empty results, and discard the handle.
`finish` always checks the complete requirement set against current authority
and clears the local result. Effects use ordinary current checks. Both wrappers
forward supported batch prefetch and immutable-node caching without retaining
permissions across calls.

`TableTyped` lowers complete neutral schemas, assignments, predicates and
lifecycle requests into the same immutable intent. `TableBridge.Session` owns
one intent at a time; small content references identify it for progress calls.
`Compiled` exports its full summary and mandatory-definition saved bytes.
`load` verifies those bytes and connection without admitting work. Replacing or
destroying a handle does not cancel a prior send or operation.

`next` distinguishes a signed step, running work, terminal outcome and closed
upload. `submit`, `observe`, `input_disposition`, `progress` and `status` preserve
admission, processing, upload state and domain completion separately. An uncertain
send must use the original signed bytes. Cancellation cannot undo publication;
cleanup cannot erase accepted history, receipts or identity floors.

After `next` reports running work, native callers can use `waitForChange` before
the next acquisition. This bounded process-inspection hint avoids continuous
metadata polling between staging turns. It is tied to the same connection and
intent, requires current native inspection rights, and never establishes Table
completion. The following acquisition rechecks current scoped policy and the
actual outcome. The console uses this wait and records its time in the wait phase.

`TableValues` supplies owned neutral metadata, schemas, cells, authorization bindings, counts,
results and cursors. Full-width application IDs use canonical decimal strings;
native IDs remain bounded JSON numbers. Every output belongs to the supplied
arena. Destruction must release that ownership, including partial allocations.

The [native ABI/port](../transit-station-bindings/docs/catalog.md), all enabled
language SDKs, [explicit catalog CLI](../../../apps/transit-cli/docs/catalog.md)
and [console](../../../apps/transit-cli/docs/console.md#writing-tables-and-catalogs)
compose this shared owner. `transit-query.TableQuery` supplies catalog-routed
finite typed snapshots; durable query delegation has its own current policy.
Neither query routing nor CREATE grants subsequent DML authority.

Metadata lists contain at most eight live entries ordered by stable object ID.
Their cursor binds scope, current definition, exact resource revision and last
examined identity. A changed cut requires a fresh listing; denial rejects old
cursors too. Historical definition reads preserve their original metadata and
schema without inventing a live Table head.

`TableDiagnostic` projects original domain outcomes and input dispositions;
`TableAttempt` separately projects a failed caller attempt. Missing, rejected,
cancelled and applied evidence cannot collapse into an uncertain transport
failure. Disclosure uses current permissions, and diagnostics do not authorize
replacement work or cancellation of already published changes.

## Checks

From the pinned development shell:

```sh
(cd packages/zig/transit-catalog && zig build test)
```

Component tests use an independent dynamic-map store for atomic proposals,
identity conflicts, policies, dependency/lifecycle rules, failures and bounded
catalog traversal. Native authority, physical-disk recovery, installed callers
and performance require their own [executed proofs](../../../tests/README.md).
