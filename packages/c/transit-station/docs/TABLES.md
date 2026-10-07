# General handler Tables

Include `<transit/table.h>`. Application-owned Tables use the catalog's
`transit_station_catalog_schema` and the shared [logical model](LOGICAL.md):
up to 128 stable column IDs, recursive types, nullable columns, typed defaults,
character limits and an optional composite primary key. Object, column and
operation IDs use full `uint64_t`; realm, resource, principal and input positions
use the protocol's safe counters. Principal zero identifies the application
namespace. Table names and SQL aliases belong to the [catalog caller](CATALOG.md).

`table_create(turn, schema, limits, &creation)` prepares one private creation
step. Keep the original schema and explicit record/staging limits, commit the
turn, and schedule another input with those same values while the state is
`BUILDING`. `APPLIED` identifies the creation's domain completion. The helper
neither commits nor schedules inputs. Accepted input and committed framework
progress do not alone establish a completed Table operation.

`table_open(turn, object, version, &table)` captures the current schema and a
basis containing resource, revision, full object ID and head digest. A null
version reads the turn's current associated resource. A retained version is
read-only and each operation rechecks current native authority. Releasing a
retained read version is an explicit turn operation, separate from destroying
local handles. Schema and basis access also check the handle's turn/thread scope.

Rows contain a stable 20-byte identity and ordered logical cells.
`table_get` reads that identity; `table_get_key` accepts the primary key's logical
cells in declared order. A null returned row means absent; a logical null cell
is a value in a present row. Tables without primary keys permit duplicate values.
`table_page_read` accepts a limit from 1 through 8 and an optional opaque cursor.
Follow a non-null cursor even when a page is full; a final empty page is valid.
Each returned definition must match the captured schema and head basis.

## Saved mutations and outcomes

Construct `transit_station_table_mutation_spec` as INSERT, UPDATE or DELETE.
INSERT accepts 1–1024 rows; each row and UPDATE accepts at most 128 assignments.
Assignments identify stable columns. A null assignment pointer means DEFAULT;
a non-null logical null cell means SQL NULL. Predicates use the catalog's typed
postfix instructions with at most 64 terms. The C codec validates bounded values;
the shared Zig compiler and owner enforce schema and mutation semantics.

`table_mutation_prepare(resource, principal, operation, schema, spec, &saved)`
freezes the original schema, explicit operation identity and mutation.
`table_prepare` supplies resource and schema from a live Table handle; retained
handles reject preparation. Save the bytes before losing the application state
that identifies pending work. `table_mutation_import` validates the current
definition, canonical JSON, original identities, recursive logical values and
the complete action envelope before accepting a saved value. Missing or foreign
definitions fail; loading never substitutes the latest schema or a new identity.

`table_mutation_step(turn, saved, &status)` performs one bounded private step.
Commit the turn and explicitly arrange later steps with the same saved mutation
while its status is `BUILDING`. `APPLIED`, `REJECTED` and `CANCELLED` are terminal
Table outcomes. Counts exist only for APPLIED and distinguish matched from
changed rows. Rejections carry a typed reason and an optional bounded witness.
Applications govern disclosure of their row and conflict values.

Save a status reference with `table_reference_export`. `table_status_read`
returns whether the reference has an observed status; `table_cancel` prepares
cancellation through its owning operation. Both require the original resource,
operation namespace and digest. An unknown transport commit requires the runner's
exact pending-work recovery; constructing a fresh Table mutation does not
reconcile it. Cancellation does not undo a previously applied mutation.

## Bounds and ownership

The complete handler Table action and result are each bounded to 262,144 JSON
bytes, including envelopes, schemas and escaping. Logical/schema limits apply
in addition to that aggregate bound. The JSON profile admits 96 levels to carry
the shared 16-level logical type/value profile. An oversized response fails;
it is never truncated. A smaller page limit can help, but a single oversized
row or schema cannot be read through this handler boundary.

Construction views borrow input only during the synchronous call. Saved mutations
own their bytes and decoded schema. Returned schemas borrow their Table or saved
mutation owner; row views borrow their row/page owner. Destroy owners only after
all borrowers finish. Reference/status/creation structures own their fixed-size
fields. `mutation_bytes` returns borrowed bytes; `reference_export` returns an
owned SDK buffer. Error paths clear output handles and values.

Table handles retain the local turn token, not durable authority. Expired turns
and foreign threads reject access. All native and host validation failures during
reads invalidate the private turn even if caught. Companion bindings use
`table_fail_read` to preserve this rule if copying a successfully returned view
fails. The helper records a non-OK SDK error under the same scope guard and issues
no I/O. The runner discards a poisoned private turn.

Handler queries start with `turn_start_query(turn, object, unified_plan, &job)`.
They use the shared typed projections, aliases, scalar/state predicates, postfix
Boolean programs, aggregates and limits. The durable encoded plan is bounded to
512 bytes; execution uses a 4 MiB workspace and an IPC buffer of 65,535 bytes
(with usable segments aligned to 65,528 bytes). The producer reads bounded pages
from its captured schema/head and retained source. Query manifests carry that
basis and the plan/schema digests. Current source access and destination policy
remain required. Result publication, source release and original IPC consumption
follow the [runner contract](USAGE.md#state-tables-and-results).
