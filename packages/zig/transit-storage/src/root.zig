//! `transit_storage`: Tiered storage runtime for Transit (`TransitLog` write-ahead
//! logs, `TransitObjectStore` segment/manifest stores, Tier 0 `TableMemtable`,
//! Tier 2 `NvmeCache`, S3 SigV4 adapter, and lock-free multi-writer OCC coordinator).
pub const TransitLog = @import("TransitLog.zig");
pub const TransitObjectStore = @import("TransitObjectStore.zig");
pub const LocalWal = @import("LocalWal.zig");
pub const LocalSegmentStore = @import("LocalSegmentStore.zig");
pub const TableManifest = @import("TableManifest.zig");
pub const NvmeCache = @import("NvmeCache.zig");
pub const S3ObjectStore = @import("S3ObjectStore.zig");
pub const PartitionLease = @import("PartitionLease.zig");
pub const TableMemtable = @import("TableMemtable.zig");
pub const TreeStore = @import("TreeStore.zig");
pub const TableDeclaration = @import("TableDeclaration.zig");
pub const TablePartition = @import("TablePartition.zig");

test {
    _ = TransitLog;
    _ = TransitObjectStore;
    _ = LocalWal;
    _ = LocalSegmentStore;
    _ = TableManifest;
    _ = NvmeCache;
    _ = S3ObjectStore;
    _ = PartitionLease;
    _ = TableMemtable;
    _ = @import("storage_test.zig");
    _ = @import("disk_wal_test.zig");
    _ = @import("disk_objects_test.zig");
    _ = @import("memtable_recovery_test.zig");
    _ = @import("tree_store_test.zig");
    _ = @import("table_partition_test.zig");
}
