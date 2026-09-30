# Unified state queries

`transit_station.unified` exposes the v1 KV, Table and accepted Document query
profile. Python owns typed values and scheduling; shared Zig validates bundles,
signs commands, observes admission and verifies result pages. Existing Table v1
queries keep their original APIs. Source adapters never infer an application
schema: supply versioned KV decoders or explicit Document paths/projections.

```python
from transit_station import unified as q
from transit_station.query import Comparison

source = q.KVSource(resource, b"events/", q.Decoder(q.Type.BINARY),
                    q.Decoder(q.Type.UTF8))
bundle = q.Bundle.prepare(source, q.Plan((1,),
    q.Compare(1, Comparison.NE, q.Scalar(q.Type.UTF8, ""))),
    q.Budgets(pages=1000, segments=100, result_bytes=1_048_576))
```

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
coverage. Work limits remain 16 KiB per bundle, eight columns/rows per batch,
4 KiB per scalar and 64 KiB per IPC segment.

Run `just bindings::unified-python kv` for a clean installed-wheel codec and
signed recovery schedule. `table` and `document` select the other source
profiles; see [proof evidence](../../../../tests/README.md) for completed runs.
