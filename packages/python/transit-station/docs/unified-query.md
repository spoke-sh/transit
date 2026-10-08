# Unified state queries

`transit_station.unified` exposes the v1 KV, Table and accepted Document query
profile. Python owns typed values and scheduling; shared Zig validates bundles,
signs commands, observes admission and verifies result pages. Table sources bind
immutable catalog metadata and general logical schemas. Source adapters never infer an application
schema: supply versioned KV decoders or explicit Document paths/projections.

```python
from transit_station import unified as q
from transit_station.query import Comparison

source = q.KVSource(resource, b"events/", q.Decoder(q.DecoderType.BINARY),
                    q.Decoder(q.DecoderType.UTF8))
bundle = q.Bundle.prepare(source, q.Plan((1,),
    q.Compare(1, Comparison.NE, q.Scalar("utf8", ""))),
    q.Budgets(pages=1000, segments=100, result_bytes=1_048_576))
```

`PredicateProgram` accepts an immutable tuple of one to 64 postfix instructions.
Wrap an `IsState`, `Compare` or unfiltered `None` in `PredicateAtom`; combine them
with `PredicateOperator.NEGATE`, `CONJUNCTION` and `DISJUNCTION`. For example,
`PredicateProgram((PredicateAtom(IsState(1, State.NULL)),
PredicateOperator.NEGATE))` selects non-null cells. Shared Zig validates stack
shape and every typed atom before producing a bundle. Evaluation is eager and
ordered; null/missing comparison results remain unknown, and a determining
operand does not suppress the other operand's error. Programs cannot nest.
EXPLAIN returns an `InspectedProgram` with immutable `InspectedAtom` values and
the same operators, excluding literals. Preparing a program admits no work.

Opening `q.Client(url, principal, seed_file, connection)` loads only the explicit
credential. `connection` binds source/requester processes and their resources in
one realm; it needs no activation or writer ownership. Use a context manager or
call `close()` to join native cleanup. `q.AsyncClient` has the same methods with
`await` and supports `async with`; cancelling an await leaves the native operation
owned until it finishes. Close joins it. Importing the package starts no work.

Call `describe(source)` to check current policy and limits before preparing.
Use `prepare_next(namespace, bundle)` to obtain one `Prepared`, persist its
`data`, then `submit(prepared)`. Its returned input position is an admission
receipt. Wait until `observe(position)` is committed before preparing the next
command. A rejected observation reports the durable behavior rejection. A null
prepared command does not prove query completion: read `status(namespace)`.
Namespaces and budgets retain the full unsigned 64-bit range.

`compile_sql(source, name, sql, budgets, parameters=None)` returns an owned
`Bundle` in both client variants; await the asynchronous method. Pass a tuple of
`Scalar` values to bind `$1`, `$2`, and so on. `None` selects ordinary SQL; an
empty tuple selects a template without placeholders.

The name binds one explicit source. SQL is limited to 4096 bytes and bindings to
65 exact logical atoms, with an unsigned atom for LIMIT; no casts, null parameters or
text substitution occur. Compilation checks current source access and budgets
before and after binding and returns no bundle on failure. It takes no snapshot
and submits no query. Use the existing upload workflow for the returned bundle;
recover uncertain work from its original saved bundle and command rather than
rebinding. See the [parameter contract](../../../../contracts/SQL_PARAMETERS_V1.md).

`inspect_sql(source, name, sql, budgets)` accepts `DESCRIBE name`, `SHOW TABLES`
and `EXPLAIN SELECT ...`. Both client variants return an `Inspection` containing
current resource/policy revisions, declaration/schema digests and typed
`SourceDescription`, `TableListing` or `Explanation` details. Integers use Python
`int`; collections use tuples. An explanation preserves operator order, the
predicate's column/state or comparison/type, output columns and explicit
budgets, and excludes literal values. `None` is an absent input limit or an
unfiltered plan. The name is an alias for the one supplied source, not a global
catalog. Inspection checks current access, acquires no snapshot and submits no
query. See the [inspection contract](../../../../contracts/SQL_INSPECTION_V1.md).

If submission raises `UncertainOperation`, persist its exact `recovery` bytes.
Reopen a client if needed and submit `q.Prepared(saved_bytes)` unchanged. Never
parse/re-encode those signed bytes or create a fresh command to resolve the
previous attempt. `prepare_cancel`, `prepare_retire` and `prepare_collect` also
return commands for this explicit persistence/submission/observation sequence.
Cancelling a Python task is separate from requesting durable cancellation.

Once status is complete, `page(namespace, cursor)` returns one owned Arrow IPC
segment, typed manifest provenance and an optional next `Cursor`. Save the cursor
only with its connection and namespace. It is verification progress, not a grant;
every read rechecks current policy and lifecycle. A failed page does not advance
the cursor. A null next cursor establishes verified whole-result coverage.

`Page.decode()` and `decode_arrow(columns, ipc, rows)` use shared Zig to return
owned typed cells. Missing, explicit null, type error, value and conflict remain
distinct. Conflict alternatives retain ordered full-width assignment IDs.
`Page.to_pyarrow()` requires the optional pinned PyArrow 23.0.0 dependency and
preserves the nested state/alternative schema. An independently decoded IPC
stream alone establishes neither current authorization nor complete-result
coverage. Bundles contain at most 25069 bytes. Table results admit 128 columns;
segments contain at most eight rows and 64 KiB. Comparison literals retain a
4 KiB byte limit. Descriptors and recursive cells use the shared logical budgets.
KV has two columns, and Document projections admit eight scalar decoders.

`Column.type` is a `logical.Descriptor`, with separate `nullable` and `optional`
flags. Query parameters use `logical.Atom` (also exported as `q.Scalar`), including
exact Python integers for all widths, decimal coefficients and temporal values.
Result cells reuse `logical.Missing`, `Null`, `SourceTypeError`, `Present` and
`Conflict`; a `Present.value` is an atom or a typed recursive value. Collections
are immutable tuples. The six KV/Document decoder names remain in `DecoderType`
and `DecoderColumn` independently of the result type model.

Build a Table source from a catalog lookup:

```python
definition = catalog_client.lookup("people")
if definition is None:
    raise ValueError("Table not found")
source = q.TableSource(catalog_client.connection.owner,
                       definition.metadata, definition.schema)
```

Metadata includes the immutable record commitment returned by the shared
implementation. Preparing a source does not grant access. Current `describe`
checks its metadata, while retained-result reads check current rights and retain
their original schema and `Manifest.source_head`. Saved work does not rebind to
a renamed or replacement object.

Run `just bindings::unified-python kv` for a clean installed-wheel codec and
signed recovery schedule. `table` and `document` select the other source
profiles; see [proof evidence](../../../../tests/README.md) for completed runs.
