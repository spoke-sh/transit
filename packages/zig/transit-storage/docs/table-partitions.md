# Table partition ownership

`TablePartition` accepts concrete row mutations and definition changes for one
Table and partition. The constructor clones a private declaration. Its complete
content hash binds the `DataLifecycle.Definition`; the row-schema fingerprint is
separate. `recover` must succeed before any operation or read. Opening an existing
partition loads its accepted declaration, including schema, properties and
retirement; the constructor template cannot replace persisted interpretation.
The [direct catalog](../../transit-catalog/README.md) composes this component
with name publication and native authorization. A configured local node exposes
the signed [direct Table service](../../../../contracts/DIRECT_TABLE_V1.md),
which the installed SQL runtime uses for Table operations. The
[local backend](../../transit-backend-local/README.md) supplies a current native
authorization/lifetime fence and quota-accounted log/object adapter, with
separate composition tests. The [proof ledger](../../../../tests/README.md)
distinguishes component, public service and installed execution evidence.

## Acceptance and observation

A fresh partition requires an accepted CREATE, which can include initial rows.
`apply` takes a frozen `DataLifecycle.Binding`, up to 1,024 concrete changes,
the point/bulk ingestion choice, and an authorization guard. Changes support
insertion with an absent-key expectation, replacement with a present-key
expectation, explicit upsert and deletion. A batch cannot target the same key
twice. Its encoded rows fit the 4 MiB WAL payload after reserving the 44-byte
envelope and 16 KiB metadata budget. These are operation bounds, independent of
the number of durable rows, receipts and pins.

`changeDefinition` accepts RENAME, ALTER and DROP against the frozen expected
definition and optional data frontier. RENAME preserves row indexes and schema;
its full definition revision advances. ALTER applies the shared schema evolution
rules, streams every source row into groups of at most 1,024 rows and the encoded
row-byte budget, and builds private replacement indexes. New-key collisions and
row validation failures leave the previous definition and all rows visible. One
acceptance publishes the new declaration, both indexes and the receipt. The
64 MiB default index-work budget applies to the complete attempt and can be
configured independently of the fixed resident cache. This synchronous component
has no durable pending rewrite or automatic restart of rejected private staging.

DROP records permanent retirement and preserves receipts and retained read
bases. New mutations, current reads and new pin acquisition reject retirement;
exact retries and observations still require the current guard. Retained pins
can read their original schemas and be released when the guard permits. Name
reservation, replacement identities and explicit dependency RESTRICT remain
the enclosing catalog's responsibilities.

The owner validates constraints against the accepted root. It stages immutable
index pages and, for bulk ingestion, one bounded `.tseg`. It then acquires the
current policy/retirement fence and appends one conditional WAL record. That
record publishes all four row indexes and the operation receipt. Private objects
cannot make a partial batch visible. Point rows are in the accepted WAL record;
bulk row locators reference the verified segment. No allocation remains after
the durable append. An uncertain append blocks reads and mutations until replay.

`observe` returns the exact original result. Retry comparison includes the
complete neutral binding and a digest of every ordered concrete change, its
expectation and row bytes. DDL comparison includes the exact edit and property
bytes. Accepted DML retries use their original schema after ALTER or DROP; they
do not revalidate old input under the current schema. No retry resolves a name.
`observeEvidence` also returns the original resulting declaration reference,
including its exact revision and retirement state. A later ALTER or DROP cannot
substitute its current metadata for an earlier operation's result.
The enclosing catalog must bind operation identity to its target before dispatching to a partition; this
storage component alone does not arbitrate one operation across different Tables.

The injected `Guard` must check current rights, object/resource retirement and
writer ownership. Its `acquire` holds that fence until `release`; the service
must serialize policy changes with the held fence. It runs for observations and
again after staging before acceptance. The component supplies no credential,
grant or policy store. The service must also serialize accesses to each owner.
Epoch integers alone do not authorize an operation.

## Durable row operations

`admit` stores a complete `TableDmlIntent` and publishes its binding, content
identity and observed data basis in the Table WAL. Admission publishes no rows.
Its operation and pending directories use the same bounded immutable page store
as row indexes. A staged intent without an admission record grants no execution
authority. INSERT requires absent-key puts. UPDATE supports present-key puts or
an explicit original key and replacement row, including
atomic exchanges of primary keys. It preserves the original row identity and
rejects collisions with surviving or other replacement rows. DELETE requires
removes; the admitted shape cannot perform another action under the selected
privilege.

Admitted INSERT rows use `TableDmlIntent.insertIdentity`: the original principal
plus one, the operation ID and the row's zero-based batch ordinal. This gives
distinct rows to separate callers using the same operation number and prevents
duplicate internal identities behind different primary keys. Validation happens
before the catalog claims the operation. UPDATE retains the inserted identity;
the concrete `apply` mechanism is an internal owner primitive, not an unchecked
public admission route.

`perform` loads the original intent and publishes the row changes, receipt and
removal from pending work atomically. It does not resolve names or recompile a
statement. A constraint failure records a terminal rejection. Storage failure,
missing intent and uncertain append leave the outcome unresolved; they do not
authorize replacement work. `cancel` records a terminal cancellation only for
admitted work. Once rows are committed, it returns that original result.
`operationState` and bounded `pendingOperations` inspect without executing.
Definition changes reject while any admitted row operation remains pending.

Admission checks an optional exact source frontier. It must belong to this
partition, lie within accepted history and be at or after the latest logical
change. Acquiring a pin or flushing rows before admission does not stale that
source. Execution preserves that
frozen expectation: later logical changes invalidate conditional work, while
intervening admissions, receipts, pins and physical flushing do not. Work without
a data-frontier expectation still checks its definition and concrete row
constraints. It is not a predicate-serializable SQL transaction.

Outcomes distinguish matched rows from changed rows. Replacing a row with
identical canonical bytes reports a match without new row bytes or a logical
change; removing a missing key reports neither. Every receipt retains the
original counts. SQL lowering must preserve row identity for unchanged rows and
must supply the correct source expectation for predicates and read/modify/write.

## Logical acceptance history

`history(from, through, frames, guard)` inspects a fixed exclusive interval of
this partition's accepted WAL after recovery. It visits at most one to eight
physical frames per call, retaining one bounded WAL frame at a time. The result
contains ordered logical acceptance roots, original operation receipts and
commitments, plus the next physical position. CREATE, row statements and
definition changes appear once at their acceptance position. Accepted no-op
statements remain visible even though their logical-change frontier is unchanged.
Admission/rejection/cancellation records, flushing and pin transitions advance
the inspection cursor without inventing row changes. A page can therefore be
empty and still have more work in its fixed interval.

The upper bound does not expand when later writes arrive. Current authorization
is checked before work and after buffering, including an empty result. Inspecting
history creates no pin and changes no accepted state.

`retainHistory(owner, expected, guard)` durably retains the original root and
its logical successors. The immutable snapshot records mandatory `history`
retention, distinct from an ordinary `snapshot` pin. Exact retries recover the
same lease; reusing its owner to change the original frontier or retention kind
rejects. `historyStart` resolves the original cut, and `historyAt` reopens a
specific saved partition/frontier and complete acceptance-record digest.
`retainedHistory` requires that live lease and never starts before its original
frontier. `scanHistory` reads the selected original schema and rows, with cursors
bound to the lease, historical position and record digest. Cross-revision cursors
reject even when both revisions share one lease. Current rights apply before
work and after buffering, including empty pages. `releaseSnapshot` closes either
retention kind and prevents subsequent history disclosure.

The owner retains complete logical history and immutable pages. It exposes no
immutable-object collector; archival preserves complete WAL records, and a future
collector must preserve every root and log record covered by a live history lease. Lease acquisition does not
schedule or advance a maintained computation.

## Typed predicate mutations

Typed predicate mutations use the same admission and outcome owner.
`TableDmlIntent.Request.statement` carries a complete Fuze UPDATE/DELETE plan,
an exact stored interpretation and a required data-frontier expectation.
Execution checks the retained logical basis, removes changed keys privately and
stages replacement rows in groups of at most 1,024 rows and 4 MiB. Each row keeps
its identity. The final WAL append publishes every row/index change and the
operation receipt together. No-op matches retain their old physical locators and
logical-change frontier. A rejected or interrupted attempt publishes no prefix.

Statement selection remains private under the action's Table privilege; it does
not acquire a public SELECT pin. UPDATE reads the original immutable root twice;
DELETE reads it once. `statement_scan_rows` defaults to 1,000,000 decoded row
visits and `statement_scan_bytes` to 64 MiB of canonical input row bytes across
all passes, including re-read group boundaries. Exhaustion records `work_limit`.
The separate index work budget and physical quota still apply. These are
operation quotas, not limits on retained Table cardinality. Predicates use the
exact schema's binary, ASCII case folding or CP037 collation. The predicate
literal must be representable under the selected collation before admission.

## Retained reads and physical flushing

Four immutable indexes share each accepted root. Point lookup hashes the
collation-aware storage key, then checks the full decoded key; a hash collision
fails instead of substituting or overwriting a row. Keyless Tables use durable
row identities. The physical scan index follows WAL/segment coordinates, grouping
maintenance traversal by segment. A separate identity index maps each canonical
20-byte row identity to its storage-key hash. Public retained pages follow that
stable order, including mixed WAL/segment sources. Duplicate row identities
reject before publication. Logical writes and schema rewrites stage up to eight
row-index changes together, sharing affected page paths without enlarging their
resident write set. Validation includes both queued keys/identities and earlier
private batch roots. All old keys are removed before replacement insertion, so
an UPDATE may exchange keys. Flushes similarly batch physical locator changes.
These private batches create no separate acceptance, receipt or logical change;
the complete operation still publishes once under its original work budget. The full-key index maps complete collation-aware keys
to the same row hashes. Mutations, predicate writes and schema rewrites publish
all four roots atomically; physical flushes preserve full-key and identity roots.
SQL ordering still comes from its query plan.

`rangeSnapshot` accepts optional inclusive/exclusive lower and upper storage-key
bounds. It seeks through the paged full-key index, resolves only selected row
locators and verifies each decoded key. Keyless Tables order by their stable
identity bytes. Results own at most eight rows under a separate encoded-byte
budget; one additional index candidate establishes continuation. A byte boundary
may decode one additional row. A row too large for an empty page fails explicitly.
Each cursor binds the exact retained content, interval fingerprint and last key.
Resuming with another interval or snapshot rejects. Reversed intervals are empty.
The owner rechecks current authorization after buffering, including empty results.
Pins preserve accepted WAL rows and the original schema through flush, ALTER and
DROP. A range's completion covers only that interval; its `total_rows` describes
the entire retained source and is not a match count.

`TreeStore` defaults to sixteen resident index pages and a separate 64 MiB
encoded staging-work budget. `TablePartition` caches at most one segment footer
and one row group's data. It reads the fixed header/trailer and verified footer,
then only the target group's column pages through `TSegReader`; it does not
allocate a complete encoded segment. The point directory selects the segment
without scanning all retained candidates. Footer keys remain a resident sorted
array, separate from the Table's paged full-key directory.

Point reads retain verified encoded column pages and one selected decoded row.
Adjacent points in that group reuse encoded bytes and validate the complete
pages again; skipped values are not retained in decoded output. Current and
retained-snapshot point operations use the same path. Physical, identity and
ordered-key scans instead cache a fully decoded group to amortize decoding across
rows. Switching from a selected point cache to a full-group scan discards encoded
pages and reads the group's columns again. Existing fully decoded groups can
also serve point reads. These choices change physical access, not source identity,
accepted roots or disclosure authorization.

Segment bytes are bounded by 16 MiB; this owner writes at most 1,024 rows per
segment in groups of 256 by default. `segment_rows_per_group` may select 1–1,024
rows independently of operation, execution and result-page limits. Existing
segments keep their original group layout. `segment_decode_bytes` bounds actual
live decoder allocations (64 MiB by default), including simultaneously live
selection output, dictionary entries and validation scratch. An encoded point
cache has a separate 16 MiB total allowance for page buffers and their directory;
a scan uses one transient encoded column page. Footer metadata, cache owner,
allocator overhead and output rows have separate allocations. Compressed strings
may require transient expansion for validation even if their rows are unselected.
`segment_cache_bytes` selects the largest encoded segment eligible for retained
footer/group caching; zero disables that retention, not transient decoding.
Returned rows own their values across group eviction and owner destruction.
Query owners must bound their result buffers and enclosing allocators separately.

`segment_reads`, `segment_range_reads`, `segment_bytes_read` and
`row_groups_decoded` count loaded footers, successful TSEG range requests,
returned encoded bytes and completed decoding calls for the component owner.
The last counter includes singleton selections as well as full-group decodes.
They exclude data-index and WAL reads, provider chunk-verification amplification,
filesystem cache effects and transport work. A cache hit retains no permission;
current guards still control disclosure.

`flush` finds at most one bounded group of currently live WAL rows. It stages a
segment, replaces their locators and publishes the replacement through the same
Table WAL. It neither rewrites all manifests nor accumulates all historical rows
in memory. Flush preserves the identity index. The logical-change frontier does not advance for flush or pin control
records; accepted definition changes do advance it. Existing read roots still address their original row versions.

The segment encoder writes into its supplied output budget, including values
larger than 4 KiB and column pages larger than 256 KiB. If any value lacks a
complete sort key, that group's zone map cannot exclude values. It remains a
scan candidate. Logical type, codec and collation qualification still belongs to
the admitting SQL/storage profile; descriptor validation alone is insufficient.

## Snapshots and recovery

`pin` captures an exact exclusive accepted frontier, including unflushed rows.
It stages immutable schema/read-root bytes, then records the pin in the Table
log. A lost acquisition reply can be recovered with the same owner and expected
frontier. Reusing the owner with another frontier conflicts. Private snapshot
bytes without an accepted pin confer no read capability.

`pinState` observes the original handle, release state and current physical
frontier without acquiring or releasing anything. An absent handle at a later
frontier, or on a retired Table, establishes that its earlier exact-frontier
request can no longer succeed. An absent handle at the original frontier leaves
acquisition unresolved. Cleanup can repeat that original request and then release
its handle; it cannot select a new owner or a newer frontier.

`readSnapshot` verifies the current pin, exact content identity, original schema
and current guard. `releaseSnapshot` records retirement of that handle and is
idempotent. A retired handle cannot acquire another snapshot or serve a read.
`inspectSnapshot` returns the retained schema and read basis without acquiring
or renewing a pin. `scanSnapshot` returns at most eight owned rows and at most
the requested canonical row-byte budget (up to 16 MiB). Decoding scratch and
transport envelopes have separate budgets. A first row larger than the requested
allowance fails explicitly; a later row continues on the next page.

Each cursor binds the immutable snapshot content and an existing 20-byte row
identity. It cannot continue another snapshot or current head. Returned values own
their memory across subsequent reads, cache eviction and owner destruction.
The final guard runs after buffering, including empty completion. Pages expose
the original definition, accepted position, logical-change frontier and total
source-row count. End of this source traversal is distinct from a query's
terminal result and from a consistent multi-source snapshot.

Data snapshots omit receipt, operation, pending and pin directories from their retained read basis, so
they do not recursively retain earlier pin owners.

This owner retains complete logical history in WAL or accepted immutable archives,
and retains all immutable objects. It exposes no logical expiry or immutable-object collection. Durable pin ownership is implemented;
GC/compaction races that actually remove retained data require a collector and
separate qualification. Recovery follows contiguous, hash-linked records through archive plus WAL
one frame at a time, verifies top-level roots before serving, and verifies
descendant pages/rows on access. Missing history or objects is an error, never an
empty table. This profile does not promise distributed writers or catalog-wide
transaction sessions.

The [storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#table-acceptance-records-and-indexes)
owns byte layouts. The [proof ledger](../../../../tests/README.md) records executed
component checks and their limits.


## Archive complete history and trim WAL files

`archive(through, limits, guard)` copies a bounded prefix into immutable history
objects and publishes its directory through the same acceptance log. Supply one
fixed accepted `through` position and repeat until `complete`; each result reports
the accepted archive frontier, frame count and encoded bytes. The default accepts
at most eight frames and one maximum-sized frame's encoded-byte budget per call.
The configured index work/cache bounds still apply. Control adapters can use the
reserved capacity for staging and acceptance when ordinary admission is full.

`trimArchived(guard)` removes only covered WAL files. Retry it after interruption;
reopen an uncertain WAL owner and recover the Table before continuing. The latest
acceptance record always remains in WAL and locates the archive for full chain
validation on recovery. Physical archival/trimming preserves `changed_lsn`,
original receipt positions, pending operation bases, pinned rows and history
cursor commitments. Old unflushed locators resolve through the latest accepted
archive directory. A slow or offline history consumer retains its original
position; archival does not require it to advance.

Current authorization gates both archive publication and trimming. Neither quota
pressure nor pin release authorizes logical expiry. Missing archive objects fail
recovery/read rather than returning an empty prefix. The archive mechanism keeps
all original logical records and does not collect Table segments, indexes or
archive objects. See the [storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#table-history-archives)
for the mandatory persisted layout and recovery order.
