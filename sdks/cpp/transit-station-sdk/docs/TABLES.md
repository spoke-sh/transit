# General handler Tables

Include `<transit/station.hpp>`. `TableSchema` is the catalog's owned `Schema`:
up to 128 stable columns with shared logical types, nullability, defaults,
character limits and an optional composite primary key. `Row` contains a stable
20-byte `RowIdentity` and owned `logical::Cell` values. Schema, row and saved
mutation values do not borrow caller input or a native I/O buffer.

`turn.create_table(schema, limits)` prepares one private creation step. Keep the
original schema and explicit `TableLimits`, commit the turn and schedule another
input with those values while the result is `TableCreationState::Building`.
`Applied` identifies domain completion. The helper does not commit or schedule
work; an admitted input or framework commit is a different observation.

`turn.table(object)` captures the current schema and `TableBasis` (resource,
revision, full object ID, head digest). `get(identity)` and `get_key(cells)` return
an optional row. Missing rows differ from logical null cells. `page(cursor, limit)`
returns owned rows and an optional move-only cursor, with a limit of 1 through 8.
A full final page may be followed by an empty page. `source(version).table(object)`
is read-only and every operation retains the current native access checks.
Releasing the durable version is an explicit turn operation.

```cpp
using namespace transit::sdk;
using namespace transit::sdk::station;

TableSchema people{100, 1, 3, {
    {1, "id", logical::Type::scalar(TRANSIT_LOGICAL_INT64), false, {}, {}},
    {2, "name", logical::Type::scalar(TRANSIT_LOGICAL_UTF8), true, {}, 80}
}, {1}};

// Keep this original value with the application's durable operation identity.
auto intent = TableMutation::prepare(ResourceRef(46, 7), 0, 501, people,
    TableInsert{{{{1, logical::Cell::atom(logical::Atom::signed_integer(7))},
                  {2, logical::Cell::atom(logical::Atom::utf8("Ada"))}}}});
auto saved = intent.save();
// In each explicitly scheduled handler turn:
// auto status = TableMutation::recover(saved).step(turn);
```

`TableInsert`, `TableUpdate` and `TableDelete` form `TableMutationSpec`.
Assignments and optional postfix predicates use catalog values. An absent
assignment cell means DEFAULT; `logical::Cell::null()` means SQL NULL. INSERT
accepts up to 1024 rows, assignments up to 128 columns and predicates up to 64
terms. Shared Zig compilation and mutation ownership enforce Table semantics.

`table.prepare(principal, operation, spec)` captures the live handle's resource
and schema. `TableMutation::prepare` takes them explicitly. `save` returns owned
bytes; `recover` validates the current definition, complete action size, original
identities and logical values. It never reads a newer schema or invents an
operation ID. Saved handles are move-only; schema/value results are owned copies.
Object, column and operation IDs use full `uint64_t`. Principal zero identifies
the application namespace; protocol IDs and positions retain safe-counter bounds.

`intent.step(turn)` prepares one bounded private step. `Building` requires a
later committed turn using the same saved intent. `Applied`, `Rejected` and
`Cancelled` are terminal Table states. Optional counts exist only for Applied;
matched and changed counts remain distinct. A rejection may include a bounded
witness, whose disclosure belongs to the application. Save its reference with
`status.reference.save()`; `TableMutationReference::recover(bytes).status(turn)`
observes it and `cancel(turn)` prepares cancellation. Runner uncertainty still
requires exact pending-request reconciliation. A new mutation identity is not a
recovery operation, and cancellation does not undo an applied result.

The complete Table action/result bound is 262,144 JSON bytes, including schemas,
envelopes and escaping. A smaller page limit may fit a response; an oversized
single row or schema fails without truncation. The JSON depth bound is 96 for the
16-level logical model. Table reads and C++ copy/conversion failures invalidate
the private turn even when caught. Scope expiry and foreign-thread checks also
apply to cached schema and basis access. Destroying local RAII owners grants no
rights and performs no durable mutation.

`QueryPlan` freezes a copy of `unified::Plan`. Call
`turn.start_query(object, plan)` to execute shared projections/aliases, scalar or
state predicates, Boolean programs, aggregates and limits through Fuze. The
saved plan bound is 512 bytes; the workspace is 4 MiB; the IPC buffer is 65,535
bytes, with usable segments aligned to 65,528 bytes. Query manifests identify
the captured schema/head and retained source. Reading original result segments
requires current access. Catalog DDL, including ALTER and DROP, uses the separate
[catalog caller](CATALOG.md) and its catalog authority.
