# Direct catalog lifecycle

`transit_station.catalog.Client` and `AsyncClient` expose direct Table declarations,
row changes, inspection and explicit snapshot retention through the shared Zig
owner. Tables have stable object identities and immutable definitions. Compiling
SQL or preparing typed work reads metadata where needed; it neither reserves a
name nor accepts a change.

```python
from transit_client import ResourceRef
from transit_station import catalog

connection = catalog.Connection(
    catalog.Scope(ResourceRef(realm, resource), catalog_id), audience,
    branch=1, role=selected_role,
)
with catalog.Client(url, principal, seed_file, connection,
                    service_url=direct_service_url) as client:
    compiled = client.compile_sql(
        "CREATE TABLE people (id BIGINT PRIMARY KEY, name UTF8)",
        catalog.Identity(operation_id, namespace=1), create_object=object_id,
    )
    save_durably("intent", compiled.saved.save())
    proposed = client.preview(compiled.intent)
    reference = client.stage(compiled.intent)
    save_durably("reference", reference.save())
    observed = client.admit(reference)
    while observed.state == "admitted":
        observed = client.execute(reference, steps=32)
    inspect_outcome(observed)
```

The application supplies distinct operation identities and durable storage for
saved work. It chooses continuation budgets and observes the actual terminal
state. Staging, admission and completion are separate. A Table commit includes
its resulting definition, data position and exact `matched`, `affected` and
`live_rows` counts. A conditional name assertion can finish `unchanged`,
`rejected` or `cancelled`; it has a catalog position rather than a Table commit.

`Connection` contains scope, branch, audience and optional role. It contains no
actor PID. Catalog, branch, object, operation, definition, position and row-count
values use exact Python integers through the complete unsigned 64-bit range;
native realm/resource/principal/namespace counters retain their native bounds.
The optional `service_url` defaults to `url`. Both URLs are at most 2048 UTF-8
bytes. Native validation rejects user information, queries and fragments. The
request timeout defaults to 5000 ms and accepts 1–60000 ms. Construction validates
the current shared definition and direct capabilities; it grants no rights and
initializes no catalog. Importing the module starts no work or credential access.

## Typed schemas and exact changes

`Schema(object_id, revision, next_column, columns, primary_key=())` owns one to
128 columns and stable primary-key column IDs. `Column` carries an exact logical
descriptor, nullability, optional default and character bound, plus independent
`Encoding` and `Collation` descriptors. Returned schemas require all physical
fields; missing values never acquire defaults. Supported execution profiles and
conversion failures belong to the [Table interface](../../../../docs/handbook/reference/tables.md).

`prepare(name, Identity(operation, namespace), action)` accepts `Create`, `Alter`,
`Rename`, `Drop` and `Mutate`. Existing-object actions take the complete
`Metadata.basis` returned by `lookup(name, namespace)`. This immutable saved basis
contains the original connection, namespace, name and stored interpretation.
An old basis never retargets a replacement sharing its name.

`Alter` accepts `AddColumn`, `DropColumn`, `RenameColumn`, `SetDefault`,
`SetNullable`, `SetType` and `SetPhysical`. `Mutate` contains `Insert`, `Update` or
`Delete` and explicitly selects `ingestion="point"` or `"bulk"`. Assignments name
stable column IDs and contain a logical cell or `Default.VALUE`. Insert batches
contain one to 1024 rows with at most 128 assignments per row. UPDATE and DELETE
accept at most 64 postfix predicate instructions; an absent predicate selects
all rows. SQL compilation accepts `dialect="transit"` or `"mysql"`, an optional
CREATE object identity and the same ingestion selection.

Logical descriptors and cells use the [typed logical values](logical.md).
`RangeType`, `MultiRangeType` and `VectorType` carry exact interval or dense
vector shapes; `RangeValue`, `MultiRangeValue` and `VectorValue` own their values.
Vector bytes are little-endian with no per-element cell tags. `Column.semantics`
accepts `ColumnSemantics` for decimal rounding, vector metrics, pinned
`TimezoneRules` and reserved `SpatialSemantics`. Timezone rules retain actual
TZif bytes as well as their version/name/digest. `SetPhysical.semantics=None`
preserves the existing descriptor; an empty `ColumnSemantics()` clears it.
Changing interpretation rules requires the owner's physical rewrite lifecycle.
Integers, decimals and temporal values keep their exact widths. Binary values
own their bytes. Conversion bounds depth, child count, names and payload bytes;
schema and mutation encoding charge each fragment before constructing the next.
Bulk batches can exceed an actor frame. The complete action remains bounded by
the generated `catalog_action_bytes` limit, and saved bytes by
`catalog_intent_bytes`.

## Saved recovery and uncertainty

Persist `SavedIntent.save()` before staging. Restore with
`SavedIntent.restore(text)` and `load(saved)`. Persist `Reference.save()` before
admission; restore with `Reference.restore(text)` for `inspect`, `execute` or
`cancel`. Loading validates locally and replaces the selected intent only after
success. Failed or foreign definitions never default to the current build.
`preview(intent)` observes current conditions without staging or acceptance.
`forget(intent)` frees only the local selection.

`Uncertain` retains `original`, the exact typed saved intent, operation reference,
snapshot acquisition or snapshot. Its inherited `recovery` bytes contain that
value's saved JSON. A malformed success response after a mutation also preserves
uncertainty. Recover the original binding and inspect its owner; do not recompile
a replacement operation. The wrapper does not retry or settle implicitly.
Destroying a client neither cancels accepted work nor releases durable retention.

## Metadata and retained reads

`describe()` reports the current configuration, authenticated subject and policy
revision. `namespace`, `namespaces` and `tables` expose bounded current directory
observations. Pages contain at most eight entries and an optional saved `Cursor`.
Continue with the original connection and selection; changed catalog cuts reject.
An empty page can still have a continuation. Table pages have `independent`
consistency and do not claim a transaction across Tables. `lookup` returns current
schema, exact prepared basis, data position, row-change position and row count.
All remote inspection checks current rights.

Create an exact acquisition with
`prepare_snapshot(basis, position, operation)`. Save its complete value before
`acquire_snapshot`. Save the returned `Snapshot` independently of the client.
After an uncertain reply, `snapshot_status(acquisition.owner)` resolves the
original retention owner. Its current Table fields are distinct from the
snapshot's accepted cut. `snapshot_metadata(snapshot)` returns the retained
schema, definition, accepted position and row count, including after DROP/name
reuse under current authorization. `release_snapshot(snapshot)` uses the original
owner and content; uncertain release requires inspection or exact retry. Release
does not establish physical reclamation or authorize expiry.

## Ownership and asynchronous calls

One worker owns each native handle. Arguments are frozen before queuing, outputs
outlive the handle, and overlapping calls raise `Busy`. `AsyncClient` has the same
remote methods as awaitables; `prepare_snapshot` is local and synchronous.
Cancelling an await leaves its native work owned. `close()` joins outstanding
work, including when the close await is itself cancelled. Neither local query
closure nor client destruction releases explicitly acquired durable snapshots.

The [shared catalog caller contract](../../../../packages/zig/transit-station-bindings/docs/catalog.md)
defines native authority, retention and failure semantics. Namespace
administration, policy preparation, dependencies and named resources have shared
native actions; Python's typed catalog methods here cover Table lifecycle and
inspection plus snapshot retention. The [proof ledger](../../../../docs/history/qualification/README.md)
records installed qualification separately from source-level decoder tests.

## Historical catalogs

Historical catalogs retain selected Table names, definitions and exact data
cuts. Current rights govern every operation. Selection alone does not retain
data; a usable snapshot is returned only when acquisition reaches `published`.

```python
key = client.prepare_history_key(account_bytes, token_bytes)
selected = client.prepare_history_selection(operation)
step = client.prepare_history_step(selected, namespace, 'events')
save(step.save())
selected = client.select_history(step)
request = client.prepare_history_acquisition(selected, key, namespace)
save(request.save())
status = client.acquire_history(request)
# Persist key and inspect/advance explicitly until status.phase == 'published'.
```

Select additional names through successive saved steps before acquisition.
`advance_history(key)` performs one bounded step. `inspect_history(key)` observes
the original work; `abandon_history(key)` closes an unfinished acquisition.
`release_history(key)` starts release of published history, with further explicit
advances until completion. There is no implicit polling or settlement.
`prepare_history_control` creates a savable `HistoryControl` with the exact
command for `resume_history_control`.

`Uncertain.original` preserves the complete `HistorySelectionStep`,
`HistoryAcquisition` or `HistoryControl`. Save/restore retains the account, token,
operation, connection, selected directory and optional common-cut evidence.
A lost selection reply is not acceptance. Retrying a selection step resolves
its requested name again; acquisition always uses the saved immutable directory.
Read failures establish no mutation outcome.

`prepare_common_history_acquisition` accepts the original transaction key, exact
acquired catalog directory and `HistoryCommonCut`. The shared owner verifies
membership and transfers the original cuts to independent history pins. Callers
must save the resulting acquisition before dispatch. Independent source vectors
cannot be relabeled as a common transaction cut.

Published `status.basis` includes the definition, original owner, branch,
catalog/source roots, source count and explicit consistency. Save its opaque
`HistoricalSnapshot` separately. `historical_namespace`, `historical_lookup`,
`historical_tables` and `historical_source` expose retained names, definitions,
schema, accepted positions and row counts under current rights. Source reads are
metadata only; row results use the shared SQL lifecycle and
[SQL snapshot selector](../../../../docs/handbook/reference/sql.md).

Pages contain at most eight entries and a snapshot/namespace/directory-bound
`HistoryCursor`. Empty pages may still have continuations. Returned values are
owned, immutable, and retain full-width Python integers. `AsyncClient` provides
the same remote methods as awaitables; all `prepare_*` methods remain local.
Cancelling an await leaves the native work owned, and close joins it without
abandoning acquisitions or releasing durable history.

## Historical interpretation coverage

`historical_coverage(snapshot, object_id, kind="definitions", cursor=None)` returns one physical schema generation or, with
`kind="locations"`, at most eight row placements. Definition coverage needs
metadata rights; locations need SELECT. The result preserves the original
catalog/source identity, logical declaration, accepted frontier and full-width
counts. Continuations can be saved and restored as `HistoryCoverageCursor` and
reject a different snapshot, object or coverage kind. Each call owns its copied
evidence; it creates no retention and performs no cleanup.

Consume pages within an explicit caller budget. A nonempty continuation means
partial traversal; exhaustion establishes directory coverage only, not payload
availability or completed query execution. Current authorization and snapshot
release are checked on every request.
