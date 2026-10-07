# Typed Tables in handlers

`turn.table(object)` discovers the committed `Catalog.Schema` through the active
turn. Schemas support 128 columns with scalar and nested logical descriptors,
nullable/defaulted fields and a composite primary key. The basis binds resource,
revision, object and complete Table-head digest. Object and operation identities
use the full unsigned 64-bit range through `BigInteger`.

`get(RowIdentity)` reads by an owned 20-byte stable identity. `getKey(List<Cell>)`
uses the schema's primary key. Tables without a primary key use row identities.
`page(cursor, limit)` returns owned rows with at most eight entries per page;
only an absent continuation proves completion. A full page can have an empty
successor. `Optional<Row>` distinguishes absent rows from logical null cells.
Lists, logical values, byte containers, schemas and cursors own their data.

Retained handles from `openVersion(version).table(object)` read the original cut
under current authorization and cannot mutate. Reads observe committed state;
private writes become visible after commitment. A retained version grants no
access and has an explicit release operation. Handles expire with their turn;
failed reads poison the private turn even if the handler catches the error.

`createTable(schema, limits)` prepares one creation step with explicit
`Catalog.TableLimits`. Repeat the original schema and limits in later committed
turns while its state is `Table.CreationState.BUILDING`. Final publication commits
the head and original creation receipt together. Creation cannot resurrect a
retired Table or adopt a different existing definition.

```java
Table.Mutation intent = Table.Mutation.prepare(resource, principal, operation,
    schema, new Catalog.Delete());
String saved = intent.save(); // Persist as accepted application work.

// An explicit continuation uses the original saved bytes.
Table.MutationStatus outcome = Table.Mutation.load(saved).step(turn);
if (outcome.state() == Table.MutationState.BUILDING) {
    scheduleAfterCommit(saved);
}
```

Applications own persistence and scheduling. `step` prepares one private turn;
it neither commits nor schedules another input. The principal selects a stable
operation namespace and grants no authority. Saved work binds the current
definition, realm, resource, original schema, principal and operation. Reusing
that identity for changed work fails. Preserve exact saved bytes and native
request identity after uncertain commitment. Do not reconstruct accepted work
from the latest schema.

Only `APPLIED` carries matched and changed counts. Rejections preserve reasons
and available witnesses; application policy controls disclosure of values.
Persist `outcome.reference().save()` for `Table.Reference.load`, `status` and
`cancel`. Cancellation cannot reverse a completed mutation. Returned outcomes
must match the original identity and saved reference digest.

Complete handler actions and Table responses each have a 256 KiB JSON budget,
including their envelopes and escaping. Statements admit at most 1024 insert
rows, 128 assignments per row and 64 predicate instructions within that budget.
Native schema and row storage bounds remain separate. `OutputBudgetExceeded`
never truncates returned rows; a smaller page can help. A single row or schema
above the response budget cannot be read through this handler interface.
Four-write native commits and authority/recovery gates remain unchanged.

`new Query.Plan(UnifiedQuery.Plan)` freezes projection, output names, typed
predicates, aggregate and limit. `startQuery(object, plan)` admits at most 512
native encoded plan bytes. Results use eight-row pages, a 4 MiB Arrow workspace
and a 65535-byte segment buffer. Output-budget failure terminates capture; an
earlier prefix cannot become complete. Catalog DDL and grants remain separate
from application-owned handler Tables.
