# Typed Tables in handlers

`turn.table(object_id)` discovers the committed general `TableSchema`. Its
columns use the same `catalog.Column` and logical descriptors as catalog callers:
up to 128 columns, nullable/defaulted fields and scalar or nested logical types.
Object and operation identities retain their full unsigned 64-bit width. The
handle captures its resource, revision and complete Table-head digest.

`get(RowIdentity)` uses an owned 20-byte identity. `get_key(tuple_of_cells)` uses
the declared composite primary key; Tables without one use row identities.
`page(cursor=None, limit=8)` returns owned `Row.cells`, identities and an opaque
continuation. A full final page can be followed by an empty page; only `next is
None` proves completion. Cursors bind the captured cut and schema/head. Retained
handles from `turn.open_version(version).table(object_id)` are read-only and
still require current access.

`turn.create_table(schema, limits)` prepares one creation step with explicit
`TableLimits`. Repeat the same schema and limits in later committed turns while
its state is `building`. The final head and creation receipt publish atomically;
creation does not recreate a retired Table or adopt a different existing schema.

```python
from transit_station import TableMutation, TableMutationState
from transit_station import catalog as c, logical as l

# resource, operation and schema belong to application-recorded work.
intent = TableMutation.prepare(resource, principal=0, operation=operation,
    schema=schema, mutation=c.Insert(((
        c.Assignment(1, l.Present(l.Atom('signed', 7))),
        c.Assignment(2, l.Null()),
    ),)))
saved = intent.save()  # Persist as accepted work before scheduling execution.

# In each explicit continuation, using the original saved bytes:
outcome = TableMutation.load(saved).step(turn)
if outcome.state is TableMutationState.BUILDING:
    schedule_after_commit(saved)
```

The persistence and scheduling functions are application responsibilities.
`step` neither commits nor schedules an input. The stable principal is an
application operation namespace; it does not grant authority. Saved bytes bind
the current contract definition, realm, resource, original schema, principal and
operation. A changed intent under that identity fails. Missing/foreign definitions
and malformed saved work fail before dispatch. Do not rebuild a pending intent
from the latest schema or invent a replacement identity after an uncertain turn.

Outcomes distinguish admission from completion. Only `applied` exposes matched
and changed counts. Rejections retain their reason and available witness; the
application decides whether it may disclose stored values. Persist
`outcome.reference.save()` for `TableMutationReference.load(...).status(turn)` or
`cancel(turn)`. Cancellation does not reverse a completed mutation.

The binding action budget is 256 KiB including its JSON envelope. Native schemas,
rows and statements have separate bounds: 128 columns, at most 1024 insert rows,
128 assignments per row and 64 predicate instructions. A valid schema or row can
still exceed a binding action's byte budget. Each step preserves the native
four-write commit bound and existing grant/read-failure checks.

For captured handler queries, construct `QueryPlan(unified.Plan(...))` with
explicit zero-based projection indices, optional output names, typed predicates
and an aggregate. `start_query(object_id, plan)` freezes a plan of at most 512
native encoded bytes. Results have eight-row pages, a 4 MiB Arrow workspace and a
65535-byte segment buffer; an oversized segment records failure and an earlier
prefix cannot become a complete result. Catalog DDL/grants remain separate from
these application-owned handler Tables.


The complete handler Table response, including schema metadata, JSON escaping
and its envelope, is limited to 256 KiB across direct ABI and native-host SDKs.
An oversized response returns `OutputBudgetExceeded` before emitting a result;
it never truncates rows or pretends a page is complete. Retry a page in a new
turn with fewer rows. A single row or schema that exceeds this response budget
cannot be read through this handler interface, even if native storage admits it.
This transport bound is separate from the native Table row and schema bounds.
