# Typed Tables in handlers

`turn.table(object)` borrows the active turn and discovers its committed general
`TableSchema`, the same type as `catalog::Schema`. Schemas support 128 columns
with scalar or nested logical descriptors, nullable/defaulted fields and a
composite primary key. The basis binds resource, revision, object and complete
Table-head digest. Object and operation IDs use the full `u64` range.

`get(RowIdentity([u8; 20]))` reads by stable identity. `get_key(&[Cell])` uses the
schema's primary key. Tables without one use row identities. `page(cursor, limit)`
returns owned `Row { identity, cells }` values, at most eight per page. Only a
missing continuation proves completion; a full page can have an empty successor.
Rows, cursors and schemas own their bytes. The reader's exclusive borrow lasts
only for its active turn.

Retained handles from `open_version(...).table(object)` read the original cut
under current access. They cannot mutate. All readers observe committed state;
private writes become visible after commitment. A read-version ID supplies no
access grant or implicit lifetime ownership.

`create_table(&schema, &limits)` prepares one creation step with explicit
`TableLimits`. Repeat the same schema and limits in later committed turns while
its state is `TableCreationState::Building`. The final head and original creation
receipt publish atomically. Creation does not resurrect a retired Table or adopt
a different existing schema.

```rust
use transit_station_sdk::{Counter, TableMutation, TableMutationState};
use transit_station_sdk::catalog::Mutation;

let intent = TableMutation::prepare(resource, Counter::new(0)?, operation,
    &schema, &Mutation::Delete { predicate: None })?;
let saved = intent.save().to_vec(); // Persist as accepted application work.

// An explicit continuation uses the original saved bytes.
let outcome = TableMutation::load(&saved)?.step(&mut turn)?;
if outcome.state == TableMutationState::Building {
    schedule_after_commit(saved);
}
```

Persistence and scheduling are application responsibilities. `step` neither
commits nor schedules an input. The principal selects a stable operation
namespace and grants no authority. Saved data binds the current definition,
realm, resource, original schema, principal and operation. Changed work under
that identity fails; missing/foreign definitions and malformed saved data fail
before dispatch. Keep the exact saved bytes and native request identity after
uncertain commitment instead of reconstructing work from the latest schema.

Only `Applied` carries matched and changed counts. Rejections retain reasons
and available typed witnesses; application policy governs disclosure of values.
Persist `outcome.reference.save()` for later `TableMutationReference::load`,
`status` or `cancel`. Cancellation does not reverse a completed mutation.
Returned outcomes must match the original identity and saved reference digest.

Both a complete handler action and a complete Table response are limited to
256 KiB of JSON, including their envelopes and escaping. Native schemas and rows
have independent bounds. Statements admit at most 1024 insert rows, 128
assignments per row and 64 predicate instructions, within the action byte
budget. `OutputBudgetExceeded` never truncates a returned page; smaller page
limits can help. A single row/schema exceeding the response budget cannot be
read through this handler interface. Native four-write commits and current
authority/recovery gates are unchanged.

`QueryPlan::new(&unified::Plan { ... })` freezes an explicit projection, optional
output names, typed predicate, aggregate and limit. `start_query(object, &plan)`
admits at most 512 native encoded plan bytes. Results use eight-row pages, a
4 MiB Arrow workspace and a 65535-byte segment buffer. Output-budget failure
terminates capture; an earlier prefix cannot become complete. Catalog DDL and
grants remain separate from application-owned handler Tables.
