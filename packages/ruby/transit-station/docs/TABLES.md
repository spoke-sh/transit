# Typed Tables in handlers

`turn.table(object)` captures a general `TableSchema`, the same value class as
`Catalog::Schema`. It supports 128 nullable/defaulted columns with scalar and
nested logical types. The basis binds resource, committed revision, full-width
object identity and complete Table-head digest.

`get(RowIdentity.new(bytes: ...))` uses an owned 20-byte row identity.
`get_key([logical_cell, ...])` uses the declared composite primary key. Tables
without a primary key use row identities. `page(cursor, limit: 8)` returns owned
rows and an opaque cursor. Only a `nil` cursor proves completion; a full final
page can have an empty successor. Rows expose logical `cells`, preserving null,
exact decimal, binary and recursive values. Captured handles expire with the
turn; their owned schemas and returned values survive it.

`turn.open_version(version).table(object)` reads the retained cut and requires
current access. Retained handles cannot mutate. Reads observe committed state;
private mutations become visible after their turn commits. A caught read or
materialization error poisons the turn, including a changed captured basis.

`turn.create_table(schema, limits)` takes explicit `Catalog::TableLimits` and
prepares one creation step. Repeat the same schema and limits in subsequent
committed turns while the state is `:building`. Head publication and the original
creation receipt are atomic. Creation does not resurrect a retired Table or
adopt a different existing schema.

```ruby
intent = Transit::Station::TableMutation.prepare(
  resource: resource, principal: 0, operation: operation,
  schema: schema, mutation: Transit::Station::Catalog::Delete.new)
saved = intent.save # Application durably records these bytes as accepted work.

# An explicit continuation uses the original bytes in its private turn.
outcome = Transit::Station::TableMutation.load(saved).step(turn)
schedule_after_commit(saved) if outcome.state == :building
```

Persistence and scheduling belong to the application. `step` neither commits nor
schedules inputs. The principal selects a stable operation namespace and grants
no authority. Saved bytes bind the current definition, realm, resource, original
schema, principal and operation; changed work under the same identity fails.
Missing/foreign definitions fail before dispatch. An uncertain turn retains its
original intent and request identity.

Outcomes distinguish admission from completion. Only `:applied` supplies matched
and changed counts. Rejections preserve reasons and available witnesses; the
application governs any disclosure of values. Save `outcome.reference.save` to
recover a `TableMutationReference`, then call `status(turn)` or `cancel(turn)`.
Cancellation does not reverse a completed mutation. Returned outcomes must match
the requested operation; status/cancellation also match the saved digest.

The binding action budget is 256 KiB including its JSON envelope. Statements can
contain up to 1024 insert rows, 128 assignments per row and 64 predicate
instructions, subject to that independent byte budget. Native row/schema budgets
remain separate. Every step preserves four native writes and existing authority,
read-failure and recovery gates.

Handler queries use `QueryPlan.new(Unified::Plan.new(projection: [0, 2], ...))`.
`start_query(object, plan)` freezes an encoded plan of at most 512 bytes. Pages
contain at most eight rows, with a 4 MiB Arrow workspace and a 65535-byte segment
buffer. Output-budget failure terminates capture; an earlier prefix cannot
become complete. Catalog DDL and grants remain separate from these
application-owned Tables.


The complete handler Table response, including schema metadata, JSON escaping
and its envelope, is limited to 256 KiB across direct ABI and native-host SDKs.
An oversized response returns `OutputBudgetExceeded` before emitting a result;
it never truncates rows or pretends a page is complete. Retry a page in a new
turn with fewer rows. A single row or schema that exceeds this response budget
cannot be read through this handler interface, even if native storage admits it.
This transport bound is separate from the native Table row and schema bounds.
