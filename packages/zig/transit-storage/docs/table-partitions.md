# Table partition ownership

`TablePartition` accepts concrete row mutations and definition changes for one
Table and partition. The constructor clones a private declaration. Its complete
content hash binds the `DataLifecycle.Definition`; the row-schema fingerprint is
separate. `recover` must succeed before any operation or read. Opening an existing
partition loads its accepted declaration, including schema, properties and
retirement; the constructor template cannot replace persisted interpretation.
The component is exercised through typed callers in its package tests. Installed
SQL still uses the catalog's existing actor path; this component has no HTTP
route or catalog name publisher. The
[local backend](../../transit-backend-local/README.md) supplies a current native
authorization/lifetime fence and quota-accounted log/object adapter, with
separate composition tests. Public SQL integration remains required.

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
record publishes both row indexes and the operation receipt. Private objects
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
operation quotas, not limits on retained Table cardinality. Predicates currently
admit only `none`/`utf8_binary` collations; other declared collations reject.

## Retained reads and physical flushing

Three immutable ordered indexes share each accepted root. Point lookup hashes the
collation-aware storage key, then checks the full decoded key; a hash collision
fails instead of substituting or overwriting a row. Keyless Tables use durable
row identities. The physical scan index follows WAL/segment coordinates, grouping
maintenance traversal by segment. A separate identity index maps each canonical
20-byte row identity to its storage-key hash. Public retained pages follow that
stable order, including mixed WAL/segment sources. Duplicate row identities
reject before publication. SQL ordering still comes from its query plan.

`TreeStore` defaults to sixteen resident index pages and a separate 64 MiB
encoded staging-work budget. `TablePartition` caches at most one segment and one
decoded row group. Segment bytes are bounded by 16 MiB; this owner writes at most
1,024 rows per segment. Footer and decoded-group allocations are additional to
the encoded-byte cache budget. Setting `segment_cache_bytes` to zero disables
retention of that cache; it does not remove transient decoding work. Query owners
must bound their result buffers and enclosing allocators separately.

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

This owner retains its entire WAL and all immutable objects. It exposes no trim,
physical collection or retention expiry. Durable pin ownership is implemented;
GC/compaction races that actually remove retained data require a collector and
separate qualification. Recovery follows contiguous, hash-linked WAL records
one frame at a time, verifies top-level roots before serving, and verifies
descendant pages/rows on access. Missing history or objects is an error, never an
empty table. This profile does not promise distributed writers or catalog-wide
transaction sessions.

The [storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#table-acceptance-records-and-indexes)
owns byte layouts. The [proof ledger](../../../../tests/README.md) records executed
component checks and their limits.
