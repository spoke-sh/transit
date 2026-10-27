//! Local `TransitLog`: exclusive segmented POSIX persistence or a volatile
//! memory fixture. Callers serialize access; disk collections exceed the cache.
const std = @import("std");
const TransitLog = @import("TransitLog.zig");
const Disk = @import("DiskWal.zig");

pub const max_partitions: usize = 64;
pub const memory_bytes: usize = 64 * 1024 * 1024;

const PartitionState = struct {
    partition_id: u64,
    min_writer_epoch: u64 = 1,
    min_policy_epoch: u64 = 1,
    trimmed_up_to_lsn: u64 = 0,
    next_lsn: u64 = 0,
    bytes: std.ArrayList(u8) = .empty,

    fn deinit(self: *PartitionState, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.* = undefined;
    }
};

pub const LocalWal = struct {
    allocator: std.mem.Allocator,
    disk: ?*Disk = null,
    partitions: std.ArrayList(PartitionState) = .empty,
    appends: u64 = 0,
    syncs: u64 = 0,
    bytes_written: u64 = 0,
    recovered_frames: u64 = 0,
    truncated_tail_bytes: u64 = 0,

    pub fn initMemory(allocator: std.mem.Allocator) LocalWal {
        return .{ .allocator = allocator };
    }

    pub const DiskOptions = Disk.Options;

    pub fn openDisk(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !LocalWal {
        return openDiskWithOptions(allocator, io, std.Io.Dir.cwd(), path, .{});
    }

    pub fn openDiskWithOptions(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, path: []const u8, options: DiskOptions) !LocalWal {
        const disk = try allocator.create(Disk);
        errdefer allocator.destroy(disk);
        disk.* = try Disk.open(allocator, io, parent, path, options);
        return .{ .allocator = allocator, .disk = disk, .syncs = disk.syncs, .recovered_frames = disk.recovered_frames, .truncated_tail_bytes = disk.truncated_tail_bytes };
    }

    pub fn deinit(self: *LocalWal) void {
        for (self.partitions.items) |*p| p.deinit(self.allocator);
        self.partitions.deinit(self.allocator);
        if (self.disk) |disk| {
            disk.deinit();
            self.allocator.destroy(disk);
        }
        self.* = undefined;
    }

    /// Caller serialization is the same as for log operations. Only closing
    /// and reopening the disk owner can clear uncertain publication state.
    pub fn requiresRecovery(self: *const LocalWal) bool {
        return if (self.disk) |disk| disk.poisoned else false;
    }

    pub fn log(self: *LocalWal) TransitLog.Log {
        return .{
            .context = self,
            .vtable = &.{
                .append = appendErased,
                .read = readErased,
                .tail = tailErased,
                .trim = trimErased,
                .fence = fenceErased,
            },
        };
    }

    fn getOrCreatePartition(self: *LocalWal, partition_id: u64) !*PartitionState {
        for (self.partitions.items) |*p| {
            if (p.partition_id == partition_id) return p;
        }
        if (self.partitions.items.len >= max_partitions) return error.WalPartitionLimitExceeded;
        try self.partitions.append(self.allocator, .{ .partition_id = partition_id });
        return &self.partitions.items[self.partitions.items.len - 1];
    }

    fn findPartition(self: *LocalWal, partition_id: u64) ?*PartitionState {
        for (self.partitions.items) |*p| {
            if (p.partition_id == partition_id) return p;
        }
        return null;
    }

    pub fn appendFrame(
        self: *LocalWal,
        partition_id: u64,
        expected_lsn: ?u64,
        writer_epoch: u64,
        policy_epoch: u64,
        kind: TransitLog.FrameKind,
        payload: []const u8,
    ) !TransitLog.AppendReceipt {
        if (self.disk) |disk| {
            const receipt = try disk.append(partition_id, expected_lsn, writer_epoch, policy_epoch, kind, payload);
            self.appends += 1;
            self.bytes_written += receipt.frame_bytes;
            self.syncs = disk.syncs;
            return receipt;
        }
        if (writer_epoch == 0 or policy_epoch == 0) return error.InvalidWalEpoch;
        if (payload.len > TransitLog.max_payload_bytes) return error.WalPayloadTooLarge;
        const part = try self.getOrCreatePartition(partition_id);
        if (writer_epoch < part.min_writer_epoch) return error.StaleWriterEpoch;
        if (policy_epoch < part.min_policy_epoch) return error.StalePolicyEpoch;
        if (expected_lsn) |exp| {
            if (exp != part.next_lsn) return error.WalLsnConflict;
        }
        const lsn = part.next_lsn;
        const successor = std.math.add(u64, lsn, 1) catch return error.WalLsnExhausted;
        const frame_bytes = TransitLog.alignedFrameSize(payload.len);
        var retained: usize = 0;
        for (self.partitions.items) |existing| retained += existing.bytes.items.len;
        if (frame_bytes > memory_bytes - retained) return error.WalMemoryCapacity;
        const old_len = part.bytes.items.len;
        try part.bytes.resize(self.allocator, old_len + frame_bytes);
        errdefer part.bytes.shrinkRetainingCapacity(old_len);

        _ = try TransitLog.encodeFrame(
            partition_id,
            writer_epoch,
            policy_epoch,
            lsn,
            1,
            kind,
            payload,
            part.bytes.items[old_len .. old_len + frame_bytes],
        );
        part.next_lsn = successor;
        part.min_writer_epoch = writer_epoch;
        part.min_policy_epoch = policy_epoch;

        self.appends += 1;
        self.bytes_written += frame_bytes;
        return .{
            .partition_id = partition_id,
            .lsn = lsn,
            .next_lsn = part.next_lsn,
            .writer_epoch = writer_epoch,
            .policy_epoch = policy_epoch,
            .frame_bytes = frame_bytes,
        };
    }

    pub fn readFrames(
        self: *LocalWal,
        allocator: std.mem.Allocator,
        partition_id: u64,
        from_lsn: u64,
        max_frames: usize,
    ) !TransitLog.Log.OwnedBatch {
        if (self.disk) |disk| return disk.read(allocator, partition_id, from_lsn, max_frames);
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const a = arena.allocator();

        const part = self.findPartition(partition_id) orelse {
            return .{ .arena = arena, .frames = &.{} };
        };
        if (from_lsn < part.trimmed_up_to_lsn) return error.WalHistoryTrimmed;
        if (from_lsn >= part.next_lsn or max_frames == 0) {
            return .{ .arena = arena, .frames = &.{} };
        }

        var list = std.ArrayList(TransitLog.Frame).empty;
        var offset: usize = 0;
        while (offset < part.bytes.items.len and list.items.len < max_frames) {
            const decoded = try TransitLog.decodeFrame(part.bytes.items[offset..]);
            offset += decoded.consumed_bytes;
            if (decoded.frame.header.lsn < from_lsn) continue;
            const payload_copy = try a.dupe(u8, decoded.frame.payload);
            try list.append(a, .{
                .header = decoded.frame.header,
                .payload = payload_copy,
            });
        }
        return .{ .arena = arena, .frames = list.items };
    }

    pub fn tailLsn(self: *LocalWal, partition_id: u64) !u64 {
        if (self.disk) |disk| return disk.tail(partition_id);
        const part = self.findPartition(partition_id) orelse return 0;
        return part.next_lsn;
    }

    /// Select the least existing partition strictly after `after`, including
    /// empty fenced/fully trimmed partitions. This is discovery, not a snapshot:
    /// callers serialize each call and establish their own acceptance cut.
    /// Disk discovery uses constant resident memory and one directory scan.
    pub fn nextPartition(self: *LocalWal, after: ?u64) !?u64 {
        if (self.disk) |disk| return disk.nextPartition(after);
        var selected: ?u64 = null;
        for (self.partitions.items) |part| {
            const id = part.partition_id;
            if (after != null and id <= after.?) continue;
            if (selected == null or id < selected.?) selected = id;
        }
        return selected;
    }

    pub fn trimUpTo(self: *LocalWal, partition_id: u64, up_to_lsn: u64) !void {
        if (self.disk) |disk| return disk.trim(partition_id, up_to_lsn);
        const part = self.findPartition(partition_id) orelse return;
        if (up_to_lsn <= part.trimmed_up_to_lsn) return;
        if (up_to_lsn > part.next_lsn) return error.InvalidWalTrimBoundary;

        var offset: usize = 0;
        while (offset < part.bytes.items.len) {
            const decoded = try TransitLog.decodeFrame(part.bytes.items[offset..]);
            if (decoded.frame.header.lsn >= up_to_lsn) break;
            offset += decoded.consumed_bytes;
        }
        const remaining = part.bytes.items.len - offset;
        std.mem.copyForwards(u8, part.bytes.items[0..remaining], part.bytes.items[offset..]);
        part.bytes.shrinkRetainingCapacity(remaining);
        part.trimmed_up_to_lsn = up_to_lsn;
    }

    /// One bounded physical cleanup unit after publishing the authorized floor.
    /// False means more cleanup remains; it does not undo the accepted floor.
    pub fn trimUnit(self: *LocalWal, partition_id: u64, up_to_lsn: u64) !bool {
        if (self.disk) |disk| return disk.trimUnit(partition_id, up_to_lsn);
        try self.trimUpTo(partition_id, up_to_lsn);
        return true;
    }

    /// Background owners can finish an existing unit without a new trim request.
    /// Returns whether any volatile cleanup work was present. Restarted owners
    /// reconstruct work by submitting their already accepted floors again.
    pub fn resumeTrim(self: *LocalWal) !bool {
        const disk = self.disk orelse return false;
        if (disk.trim_work == null) return false;
        _ = try disk.continueTrim();
        return true;
    }

    pub fn fenceEpochs(self: *LocalWal, partition_id: u64, min_writer_epoch: u64, min_policy_epoch: u64) !void {
        if (self.disk) |disk| return disk.fence(partition_id, min_writer_epoch, min_policy_epoch);
        if (min_writer_epoch == 0 or min_policy_epoch == 0) return error.InvalidWalEpoch;
        const part = try self.getOrCreatePartition(partition_id);
        if (min_writer_epoch < part.min_writer_epoch or min_policy_epoch < part.min_policy_epoch) {
            return error.WalEpochRegression;
        }
        part.min_writer_epoch = min_writer_epoch;
        part.min_policy_epoch = min_policy_epoch;
    }

    fn appendErased(
        ctx: *anyopaque,
        partition_id: u64,
        expected_lsn: ?u64,
        writer_epoch: u64,
        policy_epoch: u64,
        kind: TransitLog.FrameKind,
        payload: []const u8,
    ) anyerror!TransitLog.AppendReceipt {
        const self: *LocalWal = @ptrCast(@alignCast(ctx));
        return self.appendFrame(partition_id, expected_lsn, writer_epoch, policy_epoch, kind, payload);
    }

    fn readErased(
        ctx: *anyopaque,
        allocator: std.mem.Allocator,
        partition_id: u64,
        from_lsn: u64,
        max_frames: usize,
    ) anyerror!TransitLog.Log.OwnedBatch {
        const self: *LocalWal = @ptrCast(@alignCast(ctx));
        return self.readFrames(allocator, partition_id, from_lsn, max_frames);
    }

    fn tailErased(ctx: *anyopaque, partition_id: u64) anyerror!u64 {
        const self: *LocalWal = @ptrCast(@alignCast(ctx));
        return self.tailLsn(partition_id);
    }

    fn trimErased(ctx: *anyopaque, partition_id: u64, up_to_lsn: u64) anyerror!void {
        const self: *LocalWal = @ptrCast(@alignCast(ctx));
        return self.trimUpTo(partition_id, up_to_lsn);
    }

    fn fenceErased(ctx: *anyopaque, partition_id: u64, min_writer_epoch: u64, min_policy_epoch: u64) anyerror!void {
        const self: *LocalWal = @ptrCast(@alignCast(ctx));
        return self.fenceEpochs(partition_id, min_writer_epoch, min_policy_epoch);
    }
};
