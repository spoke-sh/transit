# Typed Tables in BEAM handlers

`transit_table:open(Turn, Object)` discovers the committed
`#transit_catalog_schema{}`. Elixir uses `Table.open(turn, object)` and
`Catalog.Schema`. Schemas support 128 columns with scalar and nested logical
descriptors, nullable/defaulted fields and composite primary keys. Object and
operation identities use the complete unsigned 64-bit range. The captured basis
binds resource, revision, object and the complete Table-head digest.

`get/2` reads a stable 20-byte row identity; `get_key/2` reads a logical composite
primary key. Tables without a primary key use row identities. Responses preserve
`missing` versus `{found, #transit_row{identity, cells}}`. Elixir exposes the
corresponding `Row` struct and immutable logical values. `page/3` accepts an opaque
cursor and a limit from one to eight. `page/1,2` default to eight. An absent
continuation proves completion; a full page can have an empty successor.

`open_source/2` and Elixir `Source.table/2` read the original retained cut under
current authorization. They cannot mutate. Reads observe committed state;
private writes become visible after commitment. A retained version grants no
access and requires explicit release. Handles expire with the callback and
reject use from another BEAM process. Failed reads poison the private turn even
when caught. Owned schemas, rows and saved binaries survive the callback;
saved-data loading copies sub-binaries so they cannot retain unrelated storage.

`transit_table:create(Turn, Schema, Limits)` prepares one creation step with
explicit `#transit_catalog_limits{}`. Elixir uses `Table.create/3` and
`Catalog.TableLimits`. Repeat the original schema and limits in later committed
turns while the creation state is `building`. Final publication commits the head
and original receipt together. Creation cannot resurrect a retired Table or
adopt a different existing schema.

```erlang
{ok, Intent} = transit_table:prepare(Resource, Principal, Operation, Schema,
    {delete, undefined}),
{ok, Saved} = transit_table:save(Intent),
% Persist Saved as accepted application work before scheduling a continuation.
{ok, Original} = transit_table:load(Saved),
{ok, Outcome} = transit_table:step(Turn, Original).
```

Elixir exposes `TableMutation.prepare/5`, `save/1`, `load/1` and
`step(intent, turn)`. A live Table can prepare work with `prepare/4`. Persistence
and scheduling are application responsibilities. Each step prepares one private
turn; it neither commits nor schedules another input. The principal selects a
stable operation namespace and grants no authority. Saved work binds the current
definition, realm, resource, original schema, principal and operation. Changed
work under that identity fails. Preserve exact saved bytes and the native request
identity after uncertain commitment. Do not rebuild work from the latest schema.

Only `applied` carries matched and changed counts. Rejections preserve reasons
and available witnesses; application policy controls disclosure of values.
Use `save_reference/1`, `load_reference/1`, `status/2` and `cancel/2` for later
inspection or cancellation. Elixir uses `TableMutationReference`. Cancellation
cannot reverse a completed mutation. Returned outcomes must match the original
identity and saved reference digest.

Complete handler actions and Table responses each have a 256 KiB JSON budget,
including envelopes and escaping. Statements admit at most 1024 insert rows,
128 assignments per row and 64 predicate instructions within that byte budget.
Native schema and row storage bounds remain separate. `OutputBudgetExceeded`
never truncates a page; fewer requested rows can help. A single row or schema
above the response budget cannot be read through this handler interface.
Four-write native commits and authority/recovery gates remain unchanged.

Handler queries use immutable `#transit_unified_plan{}` values; Elixir uses
`UnifiedQuery.Plan`. The plan binds explicit projection, output names, typed
predicate, aggregate and limit, within 512 native encoded bytes. Results use
at most eight rows per segment, a 4 MiB Arrow workspace and a 65535-byte segment
buffer. Output-budget failure terminates capture; an earlier prefix cannot
become complete. Catalog DDL and grants remain separate from application-owned
handler Tables.
