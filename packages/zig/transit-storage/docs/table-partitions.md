# Table partition ownership

`TablePartition` accepts concrete row mutations for one Table interpretation and
partition. The constructor clones the schema and binds its fingerprint to a
`DataLifecycle.Definition`. `recover` must succeed before any operation or read.
The component is exercised through typed callers in its package tests. Installed
SQL still uses the catalog's existing actor path; this component has no HTTP
route, catalog name publisher, DDL rewrite or service authorization adapter yet.

## Acceptance and observation

`apply` takes a frozen `DataLifecycle.Binding`, up to 1,024 concrete changes,
the point/bulk ingestion choice, and an authorization guard. Changes support
insertion with an absent-key expectation, replacement with a present-key
expectation, explicit upsert and deletion. A batch cannot target the same key
twice. Its encoded rows fit the 4 MiB WAL payload after reserving the 44-byte
envelope and 16 KiB metadata budget. These are operation bounds, independent of
the number of durable rows, receipts and pins.

The owner validates constraints against the accepted root. It stages immutable
index pages and, for bulk ingestion, one bounded `.tseg`. It then acquires the
current policy/retirement fence and appends one conditional WAL record. That
record publishes both row indexes and the operation receipt. Private objects
cannot make a partial batch visible. Point rows are in the accepted WAL record;
bulk row locators reference the verified segment. No allocation remains after
the durable append. An uncertain append blocks reads and mutations until replay.

`observe` returns the exact original result. Retry comparison includes the
complete neutral binding and a digest of every ordered concrete change, its
expectation and row bytes. It never resolves a name. The enclosing catalog must
bind operation identity to its target before dispatching to a partition; this
storage component alone does not arbitrate one operation across different Tables.

The injected `Guard` must check current rights, object/resource retirement and
writer ownership. Its `acquire` holds that fence until `release`; the service
must serialize policy changes with the held fence. It runs for observations and
again after staging before acceptance. The component supplies no credential,
grant or policy store. The service must also serialize accesses to each owner.
Epoch integers alone do not authorize an operation.

## Reads, caches and flushing

Two immutable ordered indexes share each accepted root. Point lookup hashes the
collation-aware storage key, then checks the full decoded key; a hash collision
fails instead of substituting or overwriting a row. Keyless Tables use durable
row identities. The scan index follows physical WAL/segment coordinates, so
analytical traversal groups rows from the same segment. Its cursor is opaque;
SQL ordering must come from the query plan.

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
in memory. The logical-change frontier does not advance for flush or pin control
records. Existing read roots still address their original row versions.

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

`readSnapshot` verifies the current pin, exact content identity, original schema
and current guard. `releaseSnapshot` records retirement of that handle and is
idempotent. A retired handle cannot acquire another snapshot or serve a read.
Data snapshots omit receipt/pin directories from their retained read basis, so
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
