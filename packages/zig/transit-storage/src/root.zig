//! `transit_storage`: Tiered storage runtime for Transit (`TransitLog` write-ahead
//! logs, `TransitObjectStore` segment/manifest stores, paged `TablePartition`,
//! Tier 2 `NvmeCache`, S3 SigV4 adapter, and optimistic manifest rebasing).
pub const TransitLog = @import("TransitLog.zig");
pub const TransitObjectStore = @import("TransitObjectStore.zig");
pub const LocalWal = @import("LocalWal.zig");
pub const LocalSegmentStore = @import("LocalSegmentStore.zig");
pub const TableManifest = @import("TableManifest.zig");
pub const NvmeCache = @import("NvmeCache.zig");
pub const S3ObjectStore = @import("S3ObjectStore.zig");
pub const PartitionLease = @import("PartitionLease.zig");
pub const TreeStore = @import("TreeStore.zig");
pub const OrderedKeyIndex = @import("OrderedKeyIndex.zig");
pub const TableDeclaration = @import("TableDeclaration.zig");
pub const TableArchive = @import("TableArchive.zig");
pub const TableRecovery = @import("TableRecovery.zig");
pub const TableEvidence = @import("TableEvidence.zig");
pub const TableStorageWalk = @import("TableStorageWalk.zig");
pub const TableStorageRoots = @import("TableStorageRoots.zig");
pub const TableSnapshot = @import("TableSnapshot.zig");
pub const TablePartitionRecord = @import("TablePartitionRecord.zig");
pub const TablePartition = @import("TablePartition.zig");
pub const TableDmlIntent = @import("TableDmlIntent.zig");

test {
    _ = TransitLog;
    _ = TransitObjectStore;
    _ = LocalWal;
    _ = LocalSegmentStore;
    _ = TableManifest;
    _ = NvmeCache;
    _ = S3ObjectStore;
    _ = PartitionLease;
    _ = @import("storage_test.zig");
    _ = @import("disk_wal_test.zig");
    _ = @import("disk_objects_test.zig");
    _ = @import("tree_store_test.zig");
    _ = @import("ordered_key_index_test.zig");
    _ = @import("table_partition_test.zig");
    _ = @import("table_storage_walk_test.zig");
    _ = @import("table_dml_intent_test.zig");
    _ = @import("table_operation_test.zig");
    _ = @import("table_statement_test.zig");
    _ = @import("table_snapshot_scan_test.zig");
}
