# Historical catalog v1

This contract separates an immutable **selection**, accepted **acquisition**,
published **snapshot**, and retained **availability**. Its source owners are
[`DirectHistory`](../packages/zig/transit-catalog/src/DirectHistory.zig) and
[`DirectHistoryDirectory`](../packages/zig/transit-catalog/src/DirectHistoryDirectory.zig).
The directory implementation alone does not enable a public operation or SQL
selector. Installed support and executed evidence belong in the public
[Tables reference](../docs/handbook/reference/tables.md) and qualification record.

## Identity and meaning

A selection records exact qualified names, stable objects, immutable Table
declarations, namespace revisions, schema fingerprints and `SourceCut` values.
The Table source's exclusive accepted position includes its unflushed WAL tail;
the separately recorded catalog position is metadata attribution. Neither
position can substitute for the other. Each source preserves its physical
schema directory, ADD-time origins, deletion state and required transaction
decisions through its owning Table pin.

The published identity reuses `DataLifecycle.Snapshot`: current Transit
definition, original acquisition `Operation`, branch, catalog-directory content,
retained-source-directory content, source count and consistency. A single source
uses `single_partition` with that exact position. Independently selected sources
use `independent`; they establish no common transaction cut. A transferred
transaction cut uses `common_transaction`, carrying the original
transaction operation, acquired catalog position and complete source-directory
commitment/count. Publication authenticates these fields against the acquired
transaction; a caller-provided descriptor cannot establish common consistency.

A directory is a selected set, not a claim of complete database or branch
history. Only its stored names resolve within that set. Later namespace or
Table renames, DROP, name reuse and default changes cannot redirect a binding.
The same stable namespace must have one exact revision and one name throughout
a selection. Colliding qualified names, duplicate objects with different cuts,
mixed namespace revisions and a reused namespace name reject. Exact retries
make no changes. Catalog declarations retain comparison rules and CHECK/FK
identities through the normal schema format; no separate constraint authority
is introduced here.

## Acquisition and recovery

1. Stage bounded immutable selection pages. Staging performs no pin acquisition,
   publishes no snapshot and establishes no retained-data guarantee. A selection
   must be submitted with the same original owner identity and content.
2. Bind the complete selection through the existing account/client token owner.
   Preserve its original operation, scope, selection and request fingerprint on
   an uncertain reply. A second compilation or current-name lookup cannot replace
   the accepted request. Capacity refusal cannot discard accepted work.
3. Advance one source at a time. Verify the exact accepted declaration, namespace
   and selected data position under current rights. Record an in-flight source
   before acquiring its pin. An unrelated pre-existing pin cannot be adopted.
   Recover a lost acquisition reply from that original in-flight identity.
4. Store each verified pin and its original binding in the retained directory.
   A changed definition/frontier that cannot satisfy the original selection
   refuses; it never selects a newer cut. An acquired prefix remains unpublished.
5. Verify the complete retained selection and current permissions before
   publication. A paged authorization pass must be fenced to one policy epoch.
   A changed epoch requires rechecking the same retained selection; it does not
   permit replacement source cuts. Publication verifies the original selection's
   complete object count and every binding, not just a caller's progress counter.
6. Publish the exact snapshot identity. A later physical flush or schema change
   cannot alter that identity or result observation.

Acquisition progress is service-owned. Generic operation-record APIs cannot
create, replace or disclose its reserved state format. Recovery validates all
state transitions and directory references, including roots reached after a
lost acknowledgement. No default supplies a missing persisted definition.

## Transfer from an acquired transaction

Transaction acquisition freezes a paged catalog directory alongside its complete
source directory under the same database publication fence. The catalog directory
records selected Tables' names, namespaces and definitions. KV and log participants
remain in the complete transaction source commitment; they do not become SQL Tables.

An acquisition intent's required `common` field is null for an independent
selection. For a common cut it carries the original transaction key and `CommonCut`;
`selection` must match that transaction's acquired catalog directory. Admission
requires the actual original transaction to have an acquired cut and no closing
control. Forged positions, directory commitments and identities reject. There is
no fallback to current names or a newly acquired transaction.

Admission atomically reserves the transaction's original retention in a paged
catalog index. Only one transfer per transaction can be pending. Each bounded
advance copies one exact original Table pin into the history operation's own pin.
The immutable copy records its original pin and preserves its schema, WAL frontier,
row/deletion directories and transaction decisions. A lost reply retries the same
copy identity. Copying a released source first rejects; a previously accepted copy
remains valid independently of later source release. A retired current Table does
not change the copied cut.

Commit or abort may become durable while transfer is pending. Transaction cleanup
reports `cleanup_complete = false` until history is published or abandonment has
released its acquired prefix. Ordinary private-pin release cannot bypass this
reservation. A transfer can resolve only its source transaction's already
recorded decision before copying or releasing a pin; it cannot decide that
transaction or resolve another transaction's barrier. Publishing or completing
abandonment removes the reservation in the
same catalog transition. Transaction cleanup then releases its own pins, while a
published historical snapshot retains independent copies. Neither historical
release nor transaction cleanup releases the other's pins. The copied snapshot's
original-pin attribution is not itself a live retention edge.

## Release and abandonment

Abandonment applies before publication and releases only pins acquired by that
original preparation, including a recorded in-flight source whose pin reply was
lost. It records progress before reporting cancellation complete. Publication
winning a cancellation race preserves the successful acquisition.

After publication, explicit release first makes the snapshot unavailable for
new reads, then releases pins in bounded steps. The original successful
acquisition and identity remain inspectable; release changes retained
availability, not that earlier outcome. Retrying release resumes its original
progress. Process shutdown, an ephemeral reader's close and a transport timeout
do not release a separately retained snapshot.

Ordinary private-pin APIs cannot acquire, replace or release a pin reserved by
an admitted historical owner. Historical operations use that owner to settle
its recorded obligations. Collection follows the catalog operation records,
selection and retained directories, definitions and live Table pins, including
an unrecorded pin reply after recorded acquisition intent. A descriptor alone
is not a retention root. Partial cleanup cannot establish completed release.

Retention is unlimited by default. Quotas, missing objects and storage outages
never authorize expiry. Denial, explicit release/expiry, unavailable artifacts,
incompatible definitions and corruption have distinct owning failures, subject
to non-disclosure rules. None produce an empty successful result.

## Disclosure and query binding

Historical metadata and rows use current native grants on the original object
and its current authorization namespace. Historical grants and policy epochs
provide no access. Metadata visibility is distinct from SELECT and row-location
inspection. A recreated name's grants cannot authorize its former object.

A published snapshot may be inspected by a different principal only through a
historical operation that verifies its publication and current rights. Possessing
a private pin handle does not grant that principal private-pin control. Every
protected response is checked after buffering, including repeated pages, empty
pages and terminal counts. No partial disclosure implies complete coverage.

Historical compilation selects the exact catalog before resolving names,
columns, views or comparison/decoder rules. Explicit projection binds an exact
target definition and stable ColumnIds, including a requested CURRENT target
resolved once. The result's observation remains immutable. Detailed physical
projection coverage uses a separate bounded inspection lifecycle.

EXPLAIN and metadata lookup acquire no data pins, decode no row payloads, read
no segments and perform no mutation or dispatch. SELECT uses already retained
cuts and preserves the shared result schema, bounded batches and verified
completion. Unsupported historical mutation, temporal syntax, foreign execution
or active-write-transaction composition rejects before execution.

## Directory artifacts and bounds

`catalog-history/<sha256>.data` contains `THCDIR01` directory roots or `THCENT01`
binding entries, followed by the 32-byte current Transit definition and canonical
typed JSON. Each artifact is at most 16 KiB. Its complete byte length and SHA-256
are verified on load; the artifact kind and definition must match. Names own
their bounded bytes. No temporary JSON allocation escapes a load.

Four immutable paged indexes bind object IDs, qualified names, namespace IDs
and namespace names. Entry references carry exact content length and digest.
The complete names are checked after hashed lookup. All candidate roots advance
together only after every required write succeeds. Failed staging may leave
unreferenced objects, never a partial directory publication.

One directory page contains at most eight bindings. A continuation binds the
exact directory and original last object, and is rejected against another
selection or a missing last object. It does not certify that the consumer read
the preceding pages. Resident cache size and per-step work budgets are explicit
and independent of durable selection cardinality. Deployment quotas can refuse
growth; fixed total-cardinality arrays cannot replace the paged directory.

## SQL snapshot selector

`AS OF SNAPSHOT 'selector'` is a statement-level suffix after the query's
admitted clauses (including LIMIT) and before its optional semicolon. The same suffix applies
to `DESCRIBE name`, `SHOW TABLES` and `EXPLAIN SELECT ...`. It selects one exact
catalog for the whole statement before binding any table or column. It does not
apply to writes, transaction control, settings or external sources. A prepared
statement retains that exact selector for every execution; closing its result
closes only local computation. Acquire and release use the explicit historical
catalog operations rather than implicit SQL side effects.

The selector is lowercase hexadecimal of the fixed 297-byte `THSNAP01` record:
8-byte magic, 32-byte current shared definition, five little-endian u64 Operation
fields (realm/resource/catalog/principal/operation), branch u64, catalog content
and retained-source content (each byte-length u64 then SHA-256), source-count
u64, consistency byte (1 single-partition, 2 independent, 3 common-transaction), a
16-byte position (partition then exclusive LSN; zero except for single-partition),
and a 104-byte common-cut field. The latter encodes the transaction Operation
(40 bytes), acquired position (16 bytes), complete source content (40 bytes) and
source count (8 bytes); all integers are little-endian. It is zero for other
consistency kinds. Decoding verifies exact
length, canonical spelling, definition and nonempty source count. Single-source
consistency requires count one and a nonzero position. The value carries no
permission or private-pin authority; the owner verifies actual publication.
A client can generate the selector from the published typed snapshot without
rounding any u64 through a floating-point host value.

## Shared host operations

`DirectTableBridge.Action.history` exposes the same owner through the shared
Catalog caller and ABI. Each action performs one bounded request: `select`,
`acquire`, `inspect`, `advance`, `abandon`, `release`, `lookup`, `namespace`,
`list` or metadata-only `source`. Row consumption uses the shared SQL/query
lifecycle. There is no host-specific snapshot registry or background settlement.

Save the complete acquisition key and intent before `acquire`. The key carries
the required shared definition, connection, account and token; changing them
does not resume the original work. Keep the original key after an uncertain
advance, abandonment or release. Closing the local caller releases no durable
history. Results own their copied metadata independently of response buffers.

Full-width operations, catalog/branch/object identities, positions, byte counts,
directory counts and policy epochs use canonical decimal strings. Accounts,
tokens, content digests and selectors use canonical lowercase hexadecimal.
Namespace and native authorization IDs keep their existing safe-integer bounds.
List cursors bind the exact selector, namespace and directory; changing any part
rejects. An empty page with a continuation is not complete coverage.

### Explicit historical namespace selection

The SQL suffix `AS OF SNAPSHOT 'selector' IN SCHEMA schema_name` optionally
resolves a namespace through `historical_catalog.namespace` in that published
selection before binding any Table name. Identifier folding and quoting use the
existing dialect rules. No current-name fallback or session search-path change
is permitted. The prepared binding retains the resolved stable namespace ID;
current namespace and object rights are checked through the historical owner.
The clause applies equally to SELECT, SHOW TABLES, DESCRIBE and EXPLAIN. Metadata
observations report the resolved namespace, and EXPLAIN performs only metadata
reads. The historical directory contains selected namespaces, so an unselected
name refuses even if a current namespace has that name.

## Explicit schema projection

Historical SELECT, DESCRIBE and EXPLAIN admit an optional suffix after the
snapshot and namespace selection:

```sql
SELECT id, added_column FROM events
AS OF SNAPSHOT 'source' IN SCHEMA public PROJECTING TO CURRENT;
```

`PROJECTING TO SNAPSHOT 'target'` selects the accepted definition of the same
stable object from another published catalog. Source names resolve only in the
source catalog. CURRENT resolves once during preparation. Subsequent execution
uses the exact accepted target, even after a default change, column removal or
Table DROP. The target's row cut is never read or pinned. Preparing anew from a
released target selector refuses; an already prepared target retains accepted
metadata through the Table definition directory. SHOW TABLES has no projection
clause. System-time syntax and historical writes remain outside this profile.

The signed `schema_projection.prepare` action accepts exact source and nullable
target declarations; null means CURRENT. It requires current inspection rights,
verifies both accepted declarations and forward compatibility, and returns the
exact target, its acceptance frontier, ADD-origin directory and encoded schema.
This operation reads no segments and acquires no pins. Staged content cannot
substitute for acceptance. `schema_projection.scan` takes an existing private
Table pin or published historical source, exact target, cursor and read budget.
Current SELECT protects every page, including empty and terminal results.

Mapping uses stable ColumnIds and the target's frozen ADD-origin values. Existing
five-state cells retain their state; later defaults do not substitute values.
Target nullability and length limits validate each mapped row and may refuse
historical values. Projection does not apply write-time CHECK enforcement or
claim that historical rows were accepted under the target's constraints.
Type, codec, collation, semantic descriptor and key changes require separately
qualified conversion and currently refuse. Backward revision mapping refuses.
Each call reads at most eight source rows within 16 MiB and applies a separate
caller output-byte budget; a row that cannot fit refuses. Continuations commit
to both the source pin and canonical accepted target. Returned rows own their
values independently of temporary metadata and later pages.

`DirectTableReader.projectTo` composes preparation and traversal without changing
retention ownership. Its basis fingerprints source and target separately. SQL
Table observations preserve the original interpretation and schema fingerprint;
`projection` records target definition, declaration content, target schema,
acceptance frontier and `stable_columns_add_origins` policy. Metadata observations
list these projections beside the original definitions. Result initialization
freezes this evidence; traversal never mutates the published basis. Existing
physical access paths are bypassed until qualified for both interpretations.
