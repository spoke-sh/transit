//! `UrsulaWal`: Implements `TransitLog.Log` over long-lived Ursula partition streams
//! (`<prefix>-part-<partition_id>`) instead of creating ephemeral streams per page.
//! Encodes 64-byte-aligned `TWAL1` binary frames into canonical base64 JSON records
//! with conditional `record_match` LSN sequencing and `(writer_epoch, policy_epoch)` fencing.
const std = @import("std");
const adapter = @import("root.zig");
const storage = @import("transit_storage");
const TransitLog = storage.TransitLog;

pub const max_partitions: usize = 64;

const PartitionStream = struct {
    partition_id: u64,
    stream_created: bool = false,
    min_writer_epoch: u64 = 1,
    min_policy_epoch: u64 = 1,
    trimmed_up_to_lsn: u64 = 0,
    next_lsn: u64 = 0,
    records: std.ArrayListUnmanaged([]u8) = .empty, // used in loopback/memory mode

    fn deinit(self: *PartitionStream, allocator: std.mem.Allocator) void {
        for (self.records.items) |rec| allocator.free(rec);
        self.records.deinit(allocator);
        self.* = undefined;
    }
};

pub const UrsulaWal = struct {
    allocator: std.mem.Allocator,
    client: ?*adapter.ursula.Client = null,
    bucket: []const u8,
    stream_prefix: []const u8,
    partitions: std.ArrayListUnmanaged(PartitionStream) = .empty,
    streams_created: u64 = 0,
    appends: u64 = 0,

    pub fn initLoopback(
        allocator: std.mem.Allocator,
        bucket: []const u8,
        stream_prefix: []const u8,
    ) UrsulaWal {
        return .{
            .allocator = allocator,
            .client = null,
            .bucket = bucket,
            .stream_prefix = stream_prefix,
        };
    }

    pub fn initClient(
        allocator: std.mem.Allocator,
        client: *adapter.ursula.Client,
        bucket: []const u8,
        stream_prefix: []const u8,
    ) UrsulaWal {
        return .{
            .allocator = allocator,
            .client = client,
            .bucket = bucket,
            .stream_prefix = stream_prefix,
        };
    }

    pub fn deinit(self: *UrsulaWal) void {
        for (self.partitions.items) |*p| p.deinit(self.allocator);
        self.partitions.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn log(self: *UrsulaWal) TransitLog.Log {
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

    pub fn partitionStreamName(self: *const UrsulaWal, partition_id: u64, buf: *[128]u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "{s}-part-{d}", .{ self.stream_prefix, partition_id });
    }

    fn getOrCreatePartition(self: *UrsulaWal, partition_id: u64) !*PartitionStream {
        for (self.partitions.items) |*p| {
            if (p.partition_id == partition_id) return p;
        }
        if (self.partitions.items.len >= max_partitions) return error.WalPartitionLimitExceeded;
        try self.partitions.append(self.allocator, .{ .partition_id = partition_id });
        const part = &self.partitions.items[self.partitions.items.len - 1];
        try self.ensureUrsulaPartitionStream(part);
        return part;
    }

    fn findPartition(self: *UrsulaWal, partition_id: u64) ?*PartitionStream {
        for (self.partitions.items) |*p| {
            if (p.partition_id == partition_id) return p;
        }
        return null;
    }

    fn ensureUrsulaPartitionStream(self: *UrsulaWal, part: *PartitionStream) !void {
        if (part.stream_created) return;
        if (self.client) |client| {
            var name_buf: [128]u8 = undefined;
            const stream_name = try self.partitionStreamName(part.partition_id, &name_buf);
            const stream: adapter.ursula.Stream = .{ .bucket = self.bucket, .name = stream_name };

            var bucket_resp = try client.send(.{ .create_bucket = self.bucket });
            defer bucket_resp.deinit();
            try bucket_resp.head.requireSuccess();

            var stream_resp = try client.send(.{
                .create_stream = .{
                    .stream = stream,
                    .options = .{ .content_type = "application/json" },
                },
            });
            defer stream_resp.deinit();
            try stream_resp.head.requireSuccess();

            var head_resp = try client.send(.{ .head = .{ .stream = stream } });
            defer head_resp.deinit();
            try head_resp.head.requireSuccess();
            const meta = try head_resp.head.metadata();
            part.next_lsn = meta.record_next orelse 0;
        }
        part.stream_created = true;
        self.streams_created += 1;
    }

    pub fn encodeBase64JsonRecord(allocator: std.mem.Allocator, twal_frame: []const u8) ![]u8 {
        const b64_len = std.base64.standard.Encoder.calcSize(twal_frame.len);
        const out = try allocator.alloc(u8, b64_len + 2);
        out[0] = '"';
        _ = std.base64.standard.Encoder.encode(out[1 .. 1 + b64_len], twal_frame);
        out[1 + b64_len] = '"';
        return out;
    }

    pub fn decodeBase64JsonRecord(allocator: std.mem.Allocator, json_record: []const u8) ![]u8 {
        const trimmed = std.mem.trim(u8, json_record, " \r\n\t");
        if (trimmed.len < 2 or trimmed[0] != '"' or trimmed[trimmed.len - 1] != '"') {
            return error.InvalidUrsulaWalRecord;
        }
        const inner = trimmed[1 .. trimmed.len - 1];
        const dec_len = std.base64.standard.Decoder.calcSizeForSlice(inner) catch return error.InvalidUrsulaWalRecord;
        const out = try allocator.alloc(u8, dec_len);
        errdefer allocator.free(out);
        std.base64.standard.Decoder.decode(out, inner) catch return error.InvalidUrsulaWalRecord;
        return out;
    }

    pub fn appendFrame(
        self: *UrsulaWal,
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

        const lsn = part.next_lsn;
        const frame_bytes = TransitLog.alignedFrameSize(payload.len);
        const raw_frame = try self.allocator.alloc(u8, frame_bytes);
        defer self.allocator.free(raw_frame);

        _ = try TransitLog.encodeFrame(
            partition_id,
            writer_epoch,
            policy_epoch,
            lsn,
            1,
            kind,
            payload,
            raw_frame,
        );

        const json_record = try encodeBase64JsonRecord(self.allocator, raw_frame);
        errdefer self.allocator.free(json_record);

        if (self.client) |client| {
            defer self.allocator.free(json_record);
            var name_buf: [128]u8 = undefined;
            const stream_name = try self.partitionStreamName(partition_id, &name_buf);
            var resp = try client.send(.{
                .append = .{
                    .stream = .{ .bucket = self.bucket, .name = stream_name },
                    .body = json_record,
                    .options = .{ .content_type = "application/json", .record_match = lsn },
                },
            });
            defer resp.deinit();
            if (resp.head.status == .precondition_failed) return error.WalLsnConflict;
            try resp.head.requireSuccess();
        } else {
            try part.records.append(self.allocator, json_record);
        }

        part.min_writer_epoch = writer_epoch;
        part.min_policy_epoch = policy_epoch;
        part.next_lsn = lsn + 1;
        self.appends += 1;

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
        self: *UrsulaWal,
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
        if (self.client) |client| {
            var name_buf: [128]u8 = undefined;
            const stream_name = try self.partitionStreamName(partition_id, &name_buf);
            var resp = try client.send(.{
                .read = .{
                    .stream = .{ .bucket = self.bucket, .name = stream_name },
                    .options = .{ .position = .{ .record = from_lsn }, .max_records = @intCast(@min(max_frames, 64)) },
                },
            });
            defer resp.deinit();
            if (resp.head.status == .gone) return error.WalHistoryTrimmed;
            try resp.head.requireSuccess();

            var lines = std.mem.splitScalar(u8, resp.body, '\n');
            while (lines.next()) |line| {
                const trimmed = std.mem.trim(u8, line, " \r\t");
                if (trimmed.len == 0) continue;
                const raw = try decodeBase64JsonRecord(a, trimmed);
                const dec = try TransitLog.decodeFrame(raw);
                try list.append(a, dec.frame);
                if (list.items.len >= max_frames) break;
            }
        } else {
            const start_idx: usize = @intCast(from_lsn);
            const end_idx: usize = @min(part.records.items.len, start_idx + max_frames);
            for (part.records.items[start_idx..end_idx]) |rec| {
                const raw = try decodeBase64JsonRecord(a, rec);
                const dec = try TransitLog.decodeFrame(raw);
                try list.append(a, dec.frame);
            }
        }

        return .{ .arena = arena, .frames = list.items };
    }

    pub fn tailLsn(self: *UrsulaWal, partition_id: u64) u64 {
        const part = self.findPartition(partition_id) orelse return 0;
        return part.next_lsn;
    }

    pub fn trimUpTo(self: *UrsulaWal, partition_id: u64, up_to_lsn: u64) !void {
        const part = self.findPartition(partition_id) orelse return;
        if (up_to_lsn <= part.trimmed_up_to_lsn) return;
        if (up_to_lsn > part.next_lsn) return error.InvalidWalTrimBoundary;
        part.trimmed_up_to_lsn = up_to_lsn;
    }

    pub fn fenceEpochs(self: *UrsulaWal, partition_id: u64, min_writer_epoch: u64, min_policy_epoch: u64) !void {
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
        const self: *UrsulaWal = @ptrCast(@alignCast(ctx));
        return self.appendFrame(partition_id, expected_lsn, writer_epoch, policy_epoch, kind, payload);
    }

    fn readErased(
        ctx: *anyopaque,
        allocator: std.mem.Allocator,
        partition_id: u64,
        from_lsn: u64,
        max_frames: usize,
    ) anyerror!TransitLog.Log.OwnedBatch {
        const self: *UrsulaWal = @ptrCast(@alignCast(ctx));
        return self.readFrames(allocator, partition_id, from_lsn, max_frames);
    }

    fn tailErased(ctx: *anyopaque, partition_id: u64) anyerror!u64 {
        const self: *UrsulaWal = @ptrCast(@alignCast(ctx));
        return self.tailLsn(partition_id);
    }

    fn trimErased(ctx: *anyopaque, partition_id: u64, up_to_lsn: u64) anyerror!void {
        const self: *UrsulaWal = @ptrCast(@alignCast(ctx));
        return self.trimUpTo(partition_id, up_to_lsn);
    }

    fn fenceErased(ctx: *anyopaque, partition_id: u64, min_writer_epoch: u64, min_policy_epoch: u64) anyerror!void {
        const self: *UrsulaWal = @ptrCast(@alignCast(ctx));
        return self.fenceEpochs(partition_id, min_writer_epoch, min_policy_epoch);
    }
};

test "UrsulaWal reuses one long-lived partition stream across appends and enforces epoch fencing" {
    const allocator = std.testing.allocator;
    var uwal = UrsulaWal.initLoopback(allocator, "transit-bucket", "wal");
    defer uwal.deinit();
    const log = uwal.log();

    // Append 10 frames to partition 1 and verify only 1 partition stream was created!
    for (0..10) |i| {
        const receipt = try log.append(1, @intCast(i), 2, 1, .row_delta, "ursula-delta");
        try std.testing.expectEqual(@as(u64, i), receipt.lsn);
    }
    try std.testing.expectEqual(@as(u64, 1), uwal.streams_created);
    try std.testing.expectEqual(@as(u64, 10), try log.tail(1));

    var batch = try log.read(allocator, 1, 0, 10);
    defer batch.deinit();
    try std.testing.expectEqual(@as(usize, 10), batch.frames.len);
    try std.testing.expectEqualStrings("ursula-delta", batch.frames[9].payload);

    // Reject stale writer epoch
    try std.testing.expectError(error.StaleWriterEpoch, log.append(1, 10, 1, 1, .row_delta, "stale"));
}
