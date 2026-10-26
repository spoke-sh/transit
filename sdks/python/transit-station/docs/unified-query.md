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
coverage. Bundles contain at most 25743 bytes. Table results admit 128 columns;
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

A Table source binds a direct catalog scope, service audience, branch, namespace,
full interpretation commitment and schema. `TableInterpretation` keeps the
accepted definition revision, declaration digest and byte count, and schema
digest. `TableSource(scope, audience, branch, namespace, interpretation, schema)`
uses that exact object identity; it does not bind through an actor catalog record.

Configure `Client(..., tables=Tables(url, scope, branch, audience))` (or
`AsyncClient`) with the direct Table endpoint. The client uses the same caller,
credential and selected role for native progress and direct Table operations.
The query worker's progress resource is independent of the catalog resource.
Native KV and Document sources still use the configured native resource.

`Manifest.cut` is `NativeCut(revision)` for KV/Document or
`TableCut(commitment)` for a direct Table. Its `source` is respectively a retained
`ReadVersion` or the query worker's `ProcessRef`. Table commitments cover the
original retained interpretation, manifest and accepted WAL frontier. Current
result disclosure rechecks rights after the source pin has been released; it does
not reopen that pin or bind to a renamed or replacement object.

Resolve metadata through the configured direct owner before compiling:

```python
definition = client.lookup_table("people", namespace=1)
if definition is None:
    raise ValueError("Table not found")
description = client.compile_sql(definition.source, "people",
    "SELECT COUNT(*) AS n FROM people", q.Budgets(100, 100, 1048576))
bundle = client.authorize_bundle(description,
    definition.capture(executor=worker_principal, operation=pin_operation))
```

Lookup starts no query and acquires no pin. A concurrent change can invalidate the
observed frontier before capture; inspect that conflict instead of substituting a
new source for saved work.

Connections accept an optional selected native role; omission uses the login role.
Local bundle construction produces a description. Call `authorize_bundle` once on the
query client with `Capture(executor, operation, partition, next_lsn)` before
persisting a newly constructed Table bundle or its fingerprint. `executor` is the
executor principal; `operation` identifies this pin acquisition, and the last two
fields specify the exact expected Table frontier. All three storage counters use
full-width Python integers.
The returned bytes bind the authenticated caller, role, credential epoch, source
owner and requester to the exact query and budget. SQL compilation returns an unsigned description and requires this explicit
capture authorization for Tables. An already authorized Table bundle rejects resealing.

Persist and recover the original bundle bytes unchanged, alongside each prepared
command and receipt. Current authorization is checked again during progress and
result disclosure. Credential or policy changes never justify replacing accepted
work with a newly signed bundle. The complete bundle bound is 25,614 bytes.

`prepare_cleanup(namespace, original_bundle)` creates a separate prepared control
for terminal pin cleanup using the current credential. Persist, submit and observe
it like the other prepared controls. It preserves the saved execution proof and
source cut, including after credential rotation; it grants no source scan or query
resumption. A worker records the fresh cleanup proof before retrying remote closure.
