# `transit-backend-local`

This package persists the existing native authority engine through `TransitLog`
and `TransitObjectStore` on a local POSIX filesystem. `Backend` owns an exclusive
directory; request-owned `Store` and `PageStore` instances borrow it.
`transit-node` selects this adapter with its `local_directory` configuration;
`transit server` selects it by default. See the [node configuration](../../../apps/transit-node/docs/growing.md)
for supported operations and current maintenance/diagnostic limits.

The core engine remains the authority for permissions, sequences, ownership,
retirement, resource versions, input progress, outputs and effect intents. Pages
and blocks are staged as verified immutable objects. A single conditional WAL
append publishes the next catalog and policy roots. A lost reply remains
uncertain; reopening and resubmitting the same signed operation recovers its
existing receipt without repeating staging. Recovery does not execute effects.

`PageStore` owns a configured cache of at most 4,096 pages. Durable page count
does not determine cache size. Each operation has the shared candidate byte
bound, and encoded-file allocation admission uses `Storage.Limits` with a separate
control reserve. Failed/uncertain writes conservatively retain their reservation
until exclusive reopen recounts actual files. Exhausting quota stops new staging;
it never authorizes expiry, trimming or deletion. Accounting bounds encoded file
bytes and conservative publication overhead, not filesystem block/inode usage.

The object root requires the shared definition and a 64-byte `.native-owner`
marker (`TNOWNER1`, the 32 definition bytes, then 24 zeros), locked exclusively
for the owner's lifetime. An existing unmarked object collection rejects as a
native installation. Partition zero in `wal/` contains the native genesis and
operation records, with expected LSN, storage epoch and authorization revision
bindings. Records are bounded to 256 KiB. Current roots and exact retry receipts
are recovered from the latest accepted record.

Native objects have a 40-byte envelope: `TNAT`, byte `1`, kind byte (`p` page or
`b` block), two zero bytes, and the 32 shared definition bytes. Page bodies use
the core's `TPG1` codec; block bodies are their original bytes. Opaque locations
bind the current definition, kind, storage epoch, random candidate nonce,
ordinal and logical digest. Reads verify both the object-store integrity and
the core page/block digest. The cache holds owned pages, never borrowed buffers.

`DataStore` supplies nonzero data partitions and immutable objects to direct
data owners inside the same exclusive directory and physical quota. It checks
native storage and authorization epochs at append, under the physical owner
mutex. It does not compare the native progress position: an unrelated accepted
input does not invalidate an otherwise current Table candidate. Direct owners
still compare their own partition frontier. Data history trim, mutable objects
and physical collection are unavailable through this adapter.

`DataAuthority` authenticates the original signed subject and checks the supplied
generic native requirements. It separately verifies the catalog resource's
current lifetime, owner and dependencies through the existing state rules.
The service must bind the proof context to the complete request and choose its
requirements; the adapter cannot infer those from a row batch. A shared authority
fence covers the check and data commit/disclosure. Native publication takes its
exclusive side. Private staging holds neither side, and independent data owners
can hold shared fences together. Short data commits can delay native publication;
this is a local serialization profile, not a distributed fencing protocol.

The component tests compose this guard and quota adapter with `TablePartition`,
including actual native revocation after segment staging. The node's public
Table route and SQL integration remain separate work; exporting these components
does not change installed Table callers.

`Store.maintain` trims only an already accepted native history floor and keeps
the latest entry. It does not collect immutable objects. Superseded and staged
objects remain until a retained-root collector can establish safe reclamation;
the package does not provide that collector or standalone payload publication.

Run `nix develop --command zig build test-local-native` from the repository root,
or `zig build test` here inside the pinned development shell. The root unit task
includes the same checks. See the [proof ledger](../../../tests/README.md) for
executed cases and the [storage contract](../../../contracts/TRANSIT_STORAGE_V1.md)
for the underlying local persistence boundaries.
