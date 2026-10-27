//! Fixed-memory discovery of direct owners accepted before a native storage
//! fence. The caller must validate that fence and finish every owner traversal
//! before using its marks. Discovery alone never authorizes object deletion.
const std = @import("std");
const core = @import("transit_core");
const storage = @import("transit_storage");
const Backend = @import("Backend.zig");
const Store = @import("Store.zig");
const Self = @This();

pub const Cut = struct {
    header: storage.TransitLog.Header,
    payload_hash: [32]u8,
};
pub const Step = union(enum) { progress, cut: Cut, complete };

genesis: [32]u8,
epoch: u64,
partition: u64 = 0,
next_lsn: ?u64 = null,
complete: bool = false,

/// `head` is the accepted native storage-fence result, not a staged candidate.
pub fn init(head: core.growing.Head) !Self {
    if (head.storage_epoch < 2) return error.NoStorageFence;
    return .{ .genesis = head.genesis, .epoch = head.storage_epoch };
}

/// Each step discovers one owner or reads one bounded WAL frame. A partition's
/// initial tail is fixed before walking backwards; later appends cannot extend
/// that walk. All fields and returned cuts own their bytes and can be saved.
/// Errors preserve the cursor. Required history disappearing aborts traversal;
/// it must never be interpreted as an empty owner or complete mark pass.
pub fn next(self: *Self, backend: *Backend) !Step {
    const before = self.*;
    errdefer self.* = before;
    try backend.mutex.lock(backend.io);
    defer backend.mutex.unlock(backend.io);
    const current = try Store.currentHeadLocked(backend);
    if (self.epoch < 2 or self.epoch > current.storage_epoch or !std.mem.eql(u8, &self.genesis, &current.genesis) or
        (self.next_lsn != null and (self.partition == 0 or self.complete))) return error.InvalidStorageCollection;
    if (self.complete) return .complete;
    if (self.next_lsn) |next_lsn| {
        if (next_lsn == 0) return error.InvalidStorageCollection;
        const lsn = next_lsn - 1;
        var batch = try backend.wal.readFrames(backend.allocator, self.partition, lsn, 1);
        defer batch.deinit();
        if (batch.frames.len != 1) return error.IncompleteHistory;
        const frame = batch.frames[0];
        if (frame.header.partition_id != self.partition or frame.header.lsn != lsn) return error.IncompleteHistory;
        if (frame.header.writer_epoch < self.epoch) {
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(frame.payload, &digest, .{});
            self.next_lsn = null;
            return .{ .cut = .{ .header = frame.header, .payload_hash = digest } };
        }
        self.next_lsn = if (lsn == 0) null else lsn;
        return .progress;
    }
    const id = (try backend.wal.nextPartition(self.partition)) orelse {
        self.complete = true;
        return .complete;
    };
    const end = try backend.wal.tailLsn(id);
    self.partition = id;
    self.next_lsn = if (end == 0) null else end;
    return .progress;
}
