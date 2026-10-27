//! Catalog recovery retains every accepted control root. This bounded walk
//! verifies the complete hash chain to an exact accepted cut; it does not turn
//! a latest-root-only mark pass into permission to delete historical pages.
const std = @import("std");
const c = @import("root.zig");
const r = @import("DirectCatalogRecords.zig");
const Store = @import("DirectCatalogStore.zig");
const Self = @This();

cut: Store.RecoveryState,
next_lsn: u64 = 0,
next_partition: u64,
previous: [32]u8 = @splat(0),

pub fn init(cut: Store.RecoveryState) !Self {
    try cut.root.validate();
    if (cut.root.next_lsn == 0) return error.InvalidDirectCatalogHistory;
    return .{ .cut = cut, .next_partition = cut.root.configuration.partition + 1 };
}

/// One bounded frame per step. Later acceptances do not extend the cut. Null
/// means the entire selected chain was checked, not merely an empty read batch.
/// Every returned root and action owns its fields; errors preserve the cursor.
pub fn next(self: *Self, allocator: std.mem.Allocator, log: c.storage.TransitLog.Log) !?r.Record {
    const before = self.*;
    errdefer self.* = before;
    if (self.next_lsn > self.cut.root.next_lsn) return error.InvalidDirectCatalogHistory;
    if (self.next_lsn == self.cut.root.next_lsn) {
        if (!std.mem.eql(u8, &self.previous, &self.cut.chain)) return error.InvalidDirectCatalogHistory;
        return null;
    }
    var batch = try log.read(allocator, self.cut.root.configuration.partition, self.next_lsn, 1);
    defer batch.deinit();
    if (batch.frames.len != 1) return error.CatalogHistoryMissing;
    const frame = batch.frames[0];
    const record = try Store.decodeFrame(allocator, frame, self.cut.root.configuration.partition, self.next_lsn);
    if (!std.meta.eql(record.root.configuration, self.cut.root.configuration) or
        record.root.next_partition < self.next_partition or record.root.next_partition > self.cut.root.next_partition or
        !std.mem.eql(u8, &record.previous, &self.previous)) return error.InvalidDirectCatalogHistory;
    const digest = r.hash(frame.payload);
    if (record.root.next_lsn == self.cut.root.next_lsn and
        (!std.meta.eql(record.root, self.cut.root) or !std.mem.eql(u8, &digest, &self.cut.chain))) return error.InvalidDirectCatalogHistory;
    self.next_lsn = record.root.next_lsn;
    self.next_partition = record.root.next_partition;
    self.previous = digest;
    return record;
}
