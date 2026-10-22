//! Native Zig segmented Write-Ahead Log (`LocalWal`) implementing `TransitLog`.
//! Supports both POSIX directory persistence (with `sync` durability and torn-tail
//! crash recovery) and bounded in-memory partition buffers.
const std = @import("std");
const TransitLog = @import("TransitLog.zig");

pub const max_partitions: usize = 64;
pub const segment_roll_bytes: usize = 64 * 1024 * 1024;

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
    io: ?std.Io = null,
    root_path: ?[]const u8 = null,
    partitions: std.ArrayList(PartitionState) = .empty,
    appends: u64 = 0,
    syncs: u64 = 0,
    bytes_written: u64 = 0,
    recovered_frames: u64 = 0,
    truncated_tail_bytes: u64 = 0,

    pub fn initMemory(allocator: std.mem.Allocator) LocalWal {
        return .{ .allocator = allocator };
    }

    /// Open or initialize a persistent `LocalWal` directory on a POSIX filesystem.
    /// Replays all retained `part-<id>.twal` files, verifies `TWAL1` frame CRC32C and
    /// SHA-256 prefixes, and truncates any torn trailing frame at the crash boundary.
    pub fn openDisk(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !LocalWal {
        try std.Io.Dir.cwd().createDirPath(io, path);
        const owned_path = try allocator.dupe(u8, path);
        errdefer allocator.free(owned_path);

        var self: LocalWal = .{
            .allocator = allocator,
            .io = io,
            .root_path = owned_path,
        };
        errdefer self.deinit();

        var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
        defer dir.close(io);

        var it = dir.iterate();
        while (try it.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.startsWith(u8, entry.name, "part-") or !std.mem.endsWith(u8, entry.name, ".twal")) continue;
            const id_str = entry.name["part-".len .. entry.name.len - ".twal".len];
            const part_id = std.fmt.parseInt(u64, id_str, 10) catch continue;
            try self.recoverPartitionFile(part_id, entry.name);
        }
        return self;
    }

    pub fn deinit(self: *LocalWal) void {
        for (self.partitions.items) |*p| p.deinit(self.allocator);
        self.partitions.deinit(self.allocator);
        if (self.root_path) |path| self.allocator.free(path);
        self.* = undefined;
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

    fn recoverPartitionFile(self: *LocalWal, partition_id: u64, file_name: []const u8) !void {
        const io = self.io.?;
        const full_path = try std.fs.path.join(self.allocator, &.{ self.root_path.?, file_name });
        defer self.allocator.free(full_path);

        const raw = try std.Io.Dir.cwd().readFileAlloc(io, full_path, self.allocator, .limited(segment_roll_bytes));
        defer self.allocator.free(raw);

        const part = try self.getOrCreatePartition(partition_id);
        var offset: usize = 0;
        while (offset < raw.len) {
            const decoded = TransitLog.decodeFrame(raw[offset..]) catch |err| switch (err) {
                error.TruncatedWalFrame => {
                    // Torn trailing frame from an unacknowledged write before crash:
                    // truncate cleanly to the last complete verified frame offset.
                    self.truncated_tail_bytes += (raw.len - offset);
                    break;
                },
                else => return err,
            };
            if (decoded.frame.header.partition_id != partition_id) return error.CorruptWalFrame;
            if (part.next_lsn == 0 and offset == 0) {
                part.trimmed_up_to_lsn = decoded.frame.header.lsn;
                part.next_lsn = decoded.frame.header.lsn;
            }
            if (decoded.frame.header.lsn != part.next_lsn) return error.CorruptWalFrame;
            part.next_lsn += 1;
            part.min_writer_epoch = @max(part.min_writer_epoch, decoded.frame.header.writer_epoch);
            part.min_policy_epoch = @max(part.min_policy_epoch, decoded.frame.header.policy_epoch);
            offset += decoded.consumed_bytes;
            self.recovered_frames += 1;
        }
        try part.bytes.appendSlice(self.allocator, raw[0..offset]);
        if (offset < raw.len) {
            try self.syncPartitionDisk(part);
        }
    }

    fn syncPartitionDisk(self: *LocalWal, part: *const PartitionState) !void {
        const io = self.io orelse return;
        const root = self.root_path orelse return;
        var name_buf: [64]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buf, "part-{d}.twal", .{part.partition_id});
        var dir = try std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true });
        defer dir.close(io);
        var atomic = try dir.createFileAtomic(io, name, .{ .replace = true, .permissions = .fromMode(0o600) });
        defer atomic.deinit(io);
        try atomic.file.writeStreamingAll(io, part.bytes.items);
        try atomic.file.sync(io);
        try atomic.replace(io);
        self.syncs += 1;
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
        const part = try self.getOrCreatePartition(partition_id);
        if (writer_epoch < part.min_writer_epoch) return error.StaleWriterEpoch;
        if (policy_epoch < part.min_policy_epoch) return error.StalePolicyEpoch;
        if (expected_lsn) |exp| {
            if (exp != part.next_lsn) return error.WalLsnConflict;
        }
        part.min_writer_epoch = writer_epoch;
        part.min_policy_epoch = policy_epoch;

        const lsn = part.next_lsn;
        const frame_bytes = TransitLog.alignedFrameSize(payload.len);
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
        part.next_lsn = lsn + 1;
        try self.syncPartitionDisk(part);

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

    pub fn tailLsn(self: *LocalWal, partition_id: u64) u64 {
        const part = self.findPartition(partition_id) orelse return 0;
        return part.next_lsn;
    }

    pub fn trimUpTo(self: *LocalWal, partition_id: u64, up_to_lsn: u64) !void {
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
        try self.syncPartitionDisk(part);
    }

    pub fn fenceEpochs(self: *LocalWal, partition_id: u64, min_writer_epoch: u64, min_policy_epoch: u64) !void {
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
