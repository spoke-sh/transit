# Table partition ownership

`TablePartition` accepts concrete row mutations and definition changes for one
Table and partition. The constructor clones a private declaration. Its complete
content hash binds the `DataLifecycle.Definition`; the row-schema fingerprint is
separate. `recover` must succeed before any operation or read. Opening an existing
partition loads its accepted declaration, including schema, properties and
retirement; the constructor template cannot replace persisted interpretation.
Within the same exclusive physical storage owner, `recoveryState` exports a
fixed-size validated root/chain hint. A request-local Table can use `recoverSince`
to recheck that accepted boundary and replay its successors. A newer accepted
checkpoint supersedes an older hint; checkpoint capsules and current top-level
roots remain verified. Hints contain no authority or retained pin, must not be
persisted or supplied by callers, and cannot bypass full recovery after physical
owner replacement. An uncertain append prevents exporting a hint. Corruption in
an earlier already-validated byte is detected when that byte is next accessed,
or during cold recovery; prefix reuse does not continuously scrub history.
The [direct catalog](../../transit-catalog/README.md) composes this component
with name publication and native authorization. A configured local node exposes
the signed [direct Table service](../../../../contracts/DIRECT_TABLE_V1.md),
which the installed SQL runtime uses for Table operations. The
[local backend](../../transit-backend-local/README.md) supplies a current native
authorization/lifetime fence and quota-accounted log/object adapter, with
separate composition tests. The [proof ledger](../../../../docs/history/qualification/README.md)
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
its full definition revision advances. Compatible ALTER actions publish metadata
without visiting rows: non-key column rename/drop, nullable or constant-default
ADD, and insertion-default changes. Reads project older physical rows by stable
column ID. An added column uses its immutable ADD-time value; later defaults only
affect new assignments. New columns never reuse dropped identities.

Key renames and changes to types, codecs, collations or nullability retain the
complete validation/rewrite path. That path streams every source row into groups
of at most 1,024 rows and the encoded row-byte budget, and builds private
replacement indexes. New-key collisions and
row validation failures leave the previous definition and all rows visible. One
acceptance publishes the new declaration, indexes, interpretation directories
and receipt. The
64 MiB default index-work budget applies to the complete attempt and can be
configured independently of the fixed resident cache. Private candidate
allocations have a separate `build_resident_bytes` budget, defaulting to 64 MiB.
It covers retained intent decoding during execution, encoders, copied rows,
mutation vectors and segment builders, including arena backing slack. The same
budget applies to concrete point/bulk changes, predicate UPDATE/DELETE, ALTER
rewrites and flushes. Each rewrite group releases its private memory before the
next group. `build_resident_peak` records the last attempt's private allocation
peak. Cache/index memory, the bounded persistent declaration, WAL acceptance
buffer, provider I/O and caller-owned input have separate bounds; this counter is
not process RSS.

Concrete mutations allocate canonical row bytes for their actual batch and use
the largest proposed row for equality scratch. Different encoded lengths already
establish a change. Segment encoding starts with 64 KiB of output capacity and
doubles on insufficient space, up to the unchanged maximum segment size. Each
retry encodes the bounded batch again; all attempts share the build budget.
These allocations do not reserve a maximum-size segment for every small write.

`TableBuildBudget` refuses an unpublished candidate without changing accepted
rows or definitions. Executing an admitted operation records the existing
terminal `work_limit` outcome under the original identity. Parent allocator
failure remains `OutOfMemory`; it cannot masquerade as configured budget
exhaustion and terminally reject that work. This synchronous component
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

Receipt, operation and pending directories reference compact immutable
`TableEvidence` objects. An original receipt preserves its complete binding,
change digest, outcome and resulting declaration; a control preserves its frozen
intent and admission/terminal state. Their accepted positions remain unchanged.
The objects contain no old row/index/pin roots. Receipt lookup therefore reads
bounded evidence metadata independently of the original WAL row payload.
Publication and recovery bind each reference to its exact accepting transition.
Missing or corrupt evidence fails explicitly, even if the old WAL frame remains.
The [storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#compact-table-outcome-and-operation-evidence)
defines the layout and current-definition cutover. This separates retention
dependencies; physical object collection still needs all live owner roots.

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

History remains unlimited until an application explicitly calls
`expireHistory(through, guard)` with maintenance authority. The operation advances
a durable logical read floor to a fixed accepted frontier only after archive and
recovery-checkpoint coverage exist. A live history lease blocks expiry past its
original frontier, including while its consumer is offline. A paged directory
ordered by lease frontier keeps the oldest-lease check bounded as pins grow.
Releasing the lease permits a later explicit expiry call; it does not itself
expire history. Retrying an already covered floor performs no new append.

Starting `history` below the floor returns `TableHistoryExpired`, even for an
empty interval. Ordinary snapshot pins still read their original values below
that boundary. Original receipts, current rows and admitted work remain exact.
Expiry uses the optional control reserve and rechecks current authority before
publication. It does not collect immutable objects or remove archive records.
Physical collection must preserve each live snapshot, history lease and remaining
receipt/recovery dependency. Lease acquisition does not schedule or advance a
maintained computation.

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

`scanSnapshotColumns` visits the retained identity directory with a canonical
set of selected column ordinals. All primary-key columns are required so every
returned row still verifies its directory key. Segment groups fetch, validate
and retain only selected column pages under the same decoder budget. Changing
column sets invalidates the group's encoded/decoded cache while retaining its
verified footer. WAL rows still decode their bounded full record before cloning
the selected cells. Output rows own their values; metadata and total row count
describe the complete original source. The continuation binds both that source
and the column set. Projection does not prune rows or expire history.

`scanSnapshotFiltered` applies a finite plan's predicate to at most one eight-entry
identity-index page and returns the required output/predicate/key columns. The
adapter must establish the original plan's authorized source basis; the component
checks its exact row type and collation vector. This operation performs neither
aggregation nor the plan's overall LIMIT: the caller supplies its remaining
match allowance through `ReadLimits.rows`, and stops without requesting a page
for LIMIT zero. It visits only live locators from the retained root, preserving
identity order when segments, key order, updates or WAL rows are interleaved.

`FilteredPage.examined` counts consumed identities, including misses. `offsets`
maps returned rows to one-based positions within that page. An empty page can
have a continuation; it is not an empty complete source. A continuation binds
the retained content and complete original plan and names the last consumed
identity. A returned `failure` describes the next identity's semantic predicate
failure. Earlier rows remain available so an earlier aggregate failure can win;
the failure is not a continuation or completion. Only a page without either a
failure or continuation establishes exhaustion. Current authorization is checked
after buffering, including empty, failed and terminal pages.

Segment filtering caches one group's deferred decisions under the exact plan
fingerprint. Encoded predicate kernels validate requested pages; matching rows
use the existing selected decoder and verify their complete directory key.
Pruned or unselected rows require valid locator/identity/footer-key bindings
but do not decode unrelated payload pages. WAL fallback decodes a bounded full
row and uses the same predicate semantics before cloning required cells.
`segment_predicate_bytes` independently bounds predicate decisions and scratch
(4 MiB by default), alongside the output decoder and encoded-page budgets.
`row_groups_filtered` counts completed group evaluations, including zone-pruned
groups. A cached decision carries no authority. Filtered pages are a storage
component operation; signed-service continuations and finite SQL integration
have their own delivery and validation boundary.

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

Bounded scan, range and filtered pages reset one transient row arena between
candidates. Cached segment payloads can be borrowed until that candidate's byte
admission; admitted rows copy into one shared output arena for the page. WAL
decoding copies its bounded record into reusable scratch. Uncached segment
groups detach before their temporary cache owner closes. Rejected candidates
and predicate misses do not accumulate in retained output storage.

An `OwnedRow` detached from a page keeps the shared output alive independently
of the page container, other rows, cache replacement and Table closure. Clear
its original page slot when moving it and call `deinit` exactly once on each
owner. The last row releases the arena; retaining one row can therefore retain
the entire admitted page, bounded by eight rows and its encoded-byte allowance
plus decoded metadata and arena slack. Point results retain their own arena;
lazy projection releases discarded physical values before returning. These
lifetimes do not make complete reads allocation-free: page output, physical
schema metadata, provider reads and owner caches have separate allocation costs.

`segment_reads`, `segment_range_reads`, `segment_bytes_read` and
`row_groups_decoded` count loaded footers, successful TSEG range requests,
returned encoded bytes and completed decoding calls for the component owner.
The last counter includes singleton selections as well as full-group decodes.
They exclude data-index and WAL reads, provider chunk-verification amplification,
filesystem cache effects and transport work. A cache hit retains no permission;
current guards still control disclosure.

Every row locator names its physical schema revision. The accepted root includes
a paged physical-schema directory containing exact immutable declarations and
live-locator counts, plus a column-origin directory for frozen ADD-time values.
Resolving a row uses one bounded tree lookup for its schema and at most one per
absent logical column, with at most 128 columns. No ancestry traversal or resident
list of every schema revision is required. Removing the last locator for a schema
drops its current directory entry; retained roots preserve their own entries.
DROP COLUMN removes its active origin, and complete rewrites reset both
directories. The collector follows declaration dependencies from all retained
directories. Missing or corrupt mappings reject instead of assuming today's
schema. These mandatory root fields and revision-bearing locators belong to the
current shared contract definition; older stored roots are incompatible.

WAL rows and segment rows use the same physical-to-logical projector. Mixed
layouts evaluate predicates after projection; physical zone maps and encoded
predicate decisions apply only to matching layouts. This preserves default and
collation semantics when logical column positions change. The existing optimized
column selection remains available for matching layouts.

`flush` finds at most one bounded group of currently live WAL rows. It stages a
segment, replaces their locators and publishes the replacement through the same
Table WAL. It neither rewrites all manifests nor accumulates all historical rows
in memory. Flush and bounded compaction normalize their selected rows to the
current schema and update physical-schema counts atomically with their locators.
Flush preserves the identity index. The logical-change frontier does not advance for flush or pin control
records; accepted definition changes do advance it. Existing read roots still address their original row versions.

`flushThrough(exclusive_frontier, guard)` restricts that unit to current WAL row
locators strictly below a fixed accepted frontier. Later writes do not extend
the target, and overwritten/deleted rows cease to be current obligations. A
lost publication reply is resolved from the accepted root before repeating the
same target. Historical pins retain independent WAL dependencies. This primitive
does not itself persist a caller's work request.

`flushThroughRows(exclusive_frontier, rows, guard)` additionally limits the
selected unit to 1–1,024 rows. This work limit is independent of a scheduler's
eligibility threshold. Remaining rows retain their accepted WAL locators; another
turn can continue the same target without a separate in-memory work queue.

`pendingRows(limit, guard)` reads the current manifest prefix without decoding
row values or staging objects. It returns the observed row count, encoded WAL
row bytes, earliest current-row WAL position and an explicit completeness flag.
The limit is 1–1,024 rows; incomplete counts are lower bounds. A scan validates at
most one extra page to establish completion. Both entry and final disclosure
recheck authority. Pending counts describe current rows, not retained history,
physical device bytes or logical expiry eligibility.

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
Page sizing streams the canonical row envelope into a bounded counting writer.
It validates the same row and value limits without reserving a maximum-sized
row buffer or copying every payload a second time. Owned result cells, verified
segment caches and decoding work still consume their separate allocations.

Each cursor binds the immutable snapshot content and an existing 20-byte row
identity. It cannot continue another snapshot or current head. Returned values own
their memory across subsequent reads, cache eviction and owner destruction.
The final guard runs after buffering, including empty completion. Pages expose
the original definition, accepted position, logical-change frontier and total
source-row count. End of this source traversal is distinct from a query's
terminal result and from a consistent multi-source snapshot.

Data snapshots omit recovery references and receipt, operation, pending and both
pin directories from their retained read basis, so they do not recursively
retain earlier pin owners.

This owner preserves accepted WAL records in WAL or immutable archives and retains
all immutable objects. The explicit history floor controls logical disclosure;
immutable-object collection remains separate. Durable pin ownership is implemented;
collection races that actually remove retained data require a collector and
separate qualification. Recovery follows contiguous, hash-linked records from a
published recovery baseline, or from creation when none exists. It consumes
archive/WAL records one frame at a time, verifies top-level roots before serving, and verifies
descendant pages/rows on access. Missing history or objects is an error, never an
empty table. This profile does not promise distributed writers or catalog-wide
transaction sessions.

The [storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#table-acceptance-records-and-indexes)
owns byte layouts. The [proof ledger](../../../../docs/history/qualification/README.md) records executed
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
acceptance record always remains in WAL and locates the archive and any recovery
checkpoint. Recovery validates the chain from that baseline, or from creation. Physical archival/trimming preserves `changed_lsn`,
original receipt positions, pending operation bases, pinned rows and history
cursor commitments. Old unflushed locators resolve through the latest accepted
archive directory. A slow or offline history consumer retains its original
position; archival does not require it to advance.

Current authorization gates both archive publication and trimming. Neither quota
pressure nor pin release authorizes logical expiry. Missing archive objects fail
when replay or a read requires them, rather than returning an empty prefix. The archive mechanism keeps
all original logical records and does not collect Table segments, indexes or
archive objects. See the [storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#table-history-archives)
for the mandatory persisted layout and recovery order.


## Checkpoint accepted state for restart

Call `checkpoint(through, guard)` with a fixed, nonzero accepted position. The
owner publishes a bounded capsule of its current root and last record digest,
then records its reference in the Table WAL. The returned reference covers at
least the requested cut. Keep the same `through` when retrying a lost reply:
accepted coverage returns the existing reference without another append, even
if later work has advanced the Table. Current authorization applies to both
publication and retries; control adapters provide reserved staging/append space.

The capsule contains the complete row, receipt, operation and pin directories,
exact declaration, retirement state and archive coordinates, without a resident
copy of their contents. Its maximum encoded size is 16 KiB plus a 40-byte header.
Recovery loads that accepted capsule, validates its publishing WAL transition,
and verifies every later contiguous hash-linked transition before exposing the
current top-level roots. Missing/corrupt checkpoint data is an error with no
fallback to older state. `recovery_work.checkpoint_lsn` and `replayed_frames`
describe the last successful Table replay; they exclude LocalWal startup and
separate historical/index lookups.

Checkpointing preserves logical-change positions and all original read/retry
obligations. Old records and descendant objects are verified on access, rather
than all being scrubbed during restart. A missing old receipt still fails the
original retry; it cannot become new work. Checkpoints do not permit WAL trimming
without accepted archive coverage, expire history, release pins, or collect old
objects. Scheduling is explicit. The [checkpoint contract](../../../../contracts/TRANSIT_STORAGE_V1.md#table-recovery-checkpoints)
defines the mandatory stored reference and acceptance checks.


## Traverse retained index dependencies

The separate `TableStorageWalk` component traverses one retained index directory
with a fixed cursor of at most 33 page frames. Each call loads at most 34 pages
and emits one verified page or typed ownership edge. Failed reads, corrupt pages,
invalid child heights and malformed leaf records leave its cursor unchanged.
Call `skip` only immediately after a page was emitted and a retained mark proves
the complete subtree was already visited under the same Table context,
directory kind and ordered-key prefix depth.

Directory roles distinguish row locators, scan locators, ordered keys, compact
receipts/operations, live pins and archive frames. Released pins have no snapshot
edge. `pages_only` walks just page ownership; it does not interpret arbitrary
metadata as a pin. A long ordered key emits its child directory as separate work,
which a collector must put in a bounded durable work queue rather than a growing
resident list. Segment, snapshot, evidence and archive edges still require
content and semantic validation by their owning readers.

This cursor neither selects all retained roots nor grants read/deletion rights.
The caller must retain its selected roots for the entire traversal. History
anchors, unflushed rows, snapshots, recovery baselines, current roots and other
owners remain separate retention obligations. Cursor JSON used in component
tests is not a persisted maintenance format. The local backend composes these
cursors with [durable graph work and physical collection](../../transit-backend-local/docs/maintenance.md#direct-table-and-catalog-collection);
automatic scheduling remains separate.

`TableStorageRoots` enumerates the current root, selected recovery capsule and
frames from a fixed cut's logical history floor through its accepted frontier.
Construct its cut from a recovered Table's root and chain and keep that storage
available. Each step loads at most one bounded frame or capsule and returns
owned metadata. It checks frame identity/kind, contiguous hashes, the selected
checkpoint's baseline and publication, and the exact final root and chain.
Failed reads or validation preserve the cursor; a partial traversal is never
completion evidence. Later appends do not extend the selected cut.

Historical roots retain their data and exact declaration; their old control/pin
graphs do not create new live owners. Recovery roots additionally retain control
dependencies needed by replay, including pin/release metadata. A capsule's old
recovery reference remains weak. Live pins still require separate traversal from
the current directories: history leases retain their original anchor frame at
`original.next_lsn - 1`, even when their frontier equals the history floor.
Unflushed rows can require still earlier frames. This enumerator supplies no
global root selection, durable work/marks, archive pruning or deletion authority.

## Resume physical maintenance

`archiveMaintenanceUnit(limits, guard)` and
`compactionMaintenanceUnit(limits, guard)` accept or advance fixed work targets
stored in the Table root. Each successful call publishes at most one record.
After a lost reply or owner replacement, recover the Table and call the same
work class again. New foreground writes cannot move an active target.

Archive completion requires archive coverage and a recovery checkpoint covering
the target's archive publication. Compaction visits at most two adjacent inputs
per unit. It rewrites a whole input with at least half its original rows removed
or replaced, or merges two whole inputs that fit the work budgets. It never
splits a healthy segment to fit the configured row limit. Oversized inputs, a
lone dense input and inputs that cannot fit the encoded-byte budget are retained.
A mandatory `after_segment` cursor records skipped inputs through the Table WAL;
recovery rejects a cursor step that jumps over the next live segment. Selection
reads at most `rows + 8` directory entries per candidate, including one page
of lookahead, and loads bounded footer metadata
before decoding selected rows. Private allocation failure remains a budget error
and leaves the accepted target unchanged.

Compaction completion checks that no unexamined live input remains between that
cursor and the captured boundary. It means the pass considered its inputs, not
that all rows were rewritten or normalized. Logical changes or new non-compaction
segments can select another pass; changing budgets alone does not. Retirement closes a
compaction target without moving retained data. The accepted source and completed
source frontiers exclude each class's own bookkeeping, allowing finite workloads
to become idle. Even idle calls check current authorization.

The [maintenance target contract](../../../../contracts/TRANSIT_STORAGE_V1.md#resumable-table-maintenance-targets)
defines those frontiers and transitions. These APIs preserve logical change
positions, receipts, pins and unlimited history. They do not trim the WAL,
collect objects, expire history or supply an automatic scheduler. Their caller
still owns scheduling, independent class cursors, aggregate memory and backoff.

## Compact live segments

Capture the current `root.next_segment` and pass it as the fixed exclusive boundary
to `compact(before_segment, limits, guard)` until its result is `complete`. Each
call rewrites a bounded group of live rows from older segments into one new
segment. It skips WAL rows and any segment at or above that boundary. Persist the
same boundary if a maintenance driver must resume this pass after replacement.
Accepted row locators record progress: a retry after an uncertain reply does not
rewrite the segment produced by that accepted call. A zero-row complete response
performs no append and requires no private row/build workspace.

The current paged row directories determine liveness. Compaction merges small
segments and omits their removed or replaced rows; the direct owner does not
require a separate `.tdel` bitmap to make those rows invisible. It preserves row
identities, full-key order, definitions, receipts, pending operations, pins,
`live_rows` and `changed_lsn`. Its `compaction` action uses the same acceptance
path as flushing. Older retained roots continue to use their original segments.
No segment or index object is deleted by this operation.

`CompactionLimits` admits at most 1,024 rows and the Table operation's encoded-row
byte bound per call. The default private allocation budget is 64 MiB; it accounts
requested backing bytes for row, encoder and segment-build allocations, including
arena growth slack. Allocator bookkeeping and process RSS are separate measurements.
Reader caches and decoded groups retain their existing separate bounds, as do
index staging, the acceptance-frame buffer and provider I/O. The result reports
rows, contributing input segments, encoded row bytes and private peak allocation.
Budget exhaustion, staging failure or revocation before publication leaves the
accepted root unchanged. Configured control adapters supply reserved staging and
append capacity. Compaction rejects retired Tables; retained reads remain separate.
This explicit `compact` API rewrites every selected live row, potentially across
multiple bounded calls. `compactionMaintenanceUnit` supplies the selective policy
above; its runtime caller still owns scheduling.
