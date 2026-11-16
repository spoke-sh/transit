//! Paged durable upload/deletion intent FIFO. Queue progress is not application
//! acceptance, remote coverage, nor authority to collect an object.
const std = @import("std");
const storage = @import("transit_storage");
const p = @import("transit_core").protocol;
const Files = @import("LocalFiles.zig");
const Self = @This();
pub const Key = storage.TreeStore.pages.Bytes(storage.TransitObjectStore.max_key_bytes);
pub const Item = struct { key: Key, meta: storage.TransitObjectStore.ObjectMeta, action: enum { upload, delete }, remote_generation: ?u64 = null };
pub const Head = struct { tail: u64, cursor: u64, pending_bytes: u64, pending_objects: u64 };
pub const Record = struct { definition: p.Growth.Definition, position: u64, total_bytes: u64, item: Item };
pub const record_limit = 4096;
const Cursor = struct { position: u64 = 0, bytes: u64 = 0, tail_floor: u64 = 0 };
allocator: std.mem.Allocator,
io: std.Io,
directory: std.Io.Dir,
wal: storage.LocalWal.LocalWal,
mutex: std.Io.Mutex = .init,
/// Derived only from verified or durably appended records, never recovery authority.
total: ?struct { tail: u64, bytes: u64 } = null,
decode_scratch: [record_limit * 8]u8 = undefined,

pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir) !Self {
    var wal = try storage.LocalWal.LocalWal.openDiskWithOptions(allocator, io, parent, "queue", .{});
    errdefer wal.deinit();
    var self: Self = .{ .allocator = allocator, .io = io, .directory = parent, .wal = wal };
    var bytes: [96]u8 = undefined;
    if (try Files.read(io, parent, "cursor", &bytes) == null) {
        if (try self.wal.log().tail(0) != 0) return error.MissingUploadProgress;
        try self.saveCursor(.{});
    }
    const head = try self.current();
    if (head.cursor < head.tail) _ = try self.atLocked(head.cursor);
    return self;
}
pub fn deinit(self: *Self) void {
    self.wal.deinit();
    self.* = undefined;
}
fn cursor(self: *Self) !Cursor {
    var buffer: [96]u8 = undefined;
    const raw = (try Files.read(self.io, self.directory, "cursor", &buffer)) orelse return error.MissingUploadProgress;
    var digest: [32]u8 = undefined;
    if (raw.len != buffer.len) return error.InvalidUploadProgress;
    std.crypto.hash.sha2.Sha256.hash(raw[0..64], &digest, .{});
    if (!std.mem.eql(u8, raw[0..8], "TUPLOAD1") or !std.mem.eql(u8, raw[8..40], &p.Growth.definition_bytes) or
        !std.mem.eql(u8, raw[64..96], &digest)) return error.InvalidUploadProgress;
    return .{ .position = std.mem.readInt(u64, raw[40..48], .little), .bytes = std.mem.readInt(u64, raw[48..56], .little), .tail_floor = std.mem.readInt(u64, raw[56..64], .little) };
}
fn saveCursor(self: *Self, value: Cursor) !void {
    var bytes: [96]u8 = @splat(0);
    bytes[0..8].* = "TUPLOAD1".*;
    bytes[8..40].* = p.Growth.definition_bytes;
    std.mem.writeInt(u64, bytes[40..48], value.position, .little);
    std.mem.writeInt(u64, bytes[48..56], value.bytes, .little);
    std.mem.writeInt(u64, bytes[56..64], value.tail_floor, .little);
    std.crypto.hash.sha2.Sha256.hash(bytes[0..64], bytes[64..96], .{});
    try Files.save(self.io, self.directory, "cursor", &bytes, true);
}
fn atLocked(self: *Self, position: u64) !Record {
    // The returned Record owns its fixed arrays; no borrowed scratch escapes.
    var scratch = std.heap.FixedBufferAllocator.init(&self.decode_scratch);
    const allocator = scratch.allocator();
    var batch = try self.wal.log().read(allocator, 0, position, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != position or batch.frames[0].payload.len > record_limit) return error.InvalidUploadQueue;
    const parsed = try std.json.parseFromSlice(Record, allocator, batch.frames[0].payload, .{});
    defer parsed.deinit();
    const value = parsed.value;
    if (value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    if (value.position != position or value.total_bytes > p.max_counter) return error.InvalidUploadQueue;
    try value.item.key.validate();
    try storage.TransitObjectStore.validateKey(value.item.key.slice());
    if (value.item.meta.size > storage.TransitObjectStore.max_object_bytes) return error.InvalidUploadQueue;
    return value;
}
fn currentLocked(self: *Self) !Head {
    const tail = try self.wal.log().tail(0);
    const consumed = try self.cursor();
    const total = if (tail == 0) 0 else blk: {
        if (self.total) |cached| if (cached.tail == tail) break :blk cached.bytes;
        const bytes = (try self.atLocked(tail - 1)).total_bytes;
        self.total = .{ .tail = tail, .bytes = bytes };
        break :blk bytes;
    };
    if (consumed.tail_floor > tail or consumed.position > consumed.tail_floor or consumed.bytes > total) return error.InvalidUploadProgress;
    return .{ .tail = tail, .cursor = consumed.position, .pending_bytes = total - consumed.bytes, .pending_objects = tail - consumed.position };
}
pub fn current(self: *Self) !Head {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    return self.currentLocked();
}
pub fn next(self: *Self) !?Record {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const head = try self.currentLocked();
    return if (head.cursor == head.tail) null else try self.atLocked(head.cursor);
}
pub fn enqueue(self: *Self, item: Item, staging_budget: u64, object_budget: u64) !u64 {
    return self.enqueueBatch(&.{item}, staging_budget, object_budget);
}
/// Preserve individual intent positions while sharing the WAL and cursor barriers.
pub fn enqueueBatch(self: *Self, items: []const Item, staging_budget: u64, object_budget: u64) !u64 {
    if (items.len == 0 or items.len > storage.TransitObjectStore.max_put_batch) return error.InvalidObjectBatch;
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const head = try self.currentLocked();
    var pending = head.pending_bytes;
    var total = (try self.cursor()).bytes + pending;
    var buffers: [storage.TransitObjectStore.max_put_batch][record_limit]u8 = undefined;
    var payloads: [storage.TransitObjectStore.max_put_batch][]const u8 = undefined;
    for (items, buffers[0..items.len], payloads[0..items.len], 0..) |item, *buffer, *payload, i| {
        const bytes = if (item.action == .upload) item.meta.size else 0;
        const objects = head.pending_objects + i;
        if ((item.action == .upload and (pending > staging_budget or bytes > staging_budget - pending or objects >= object_budget)) or
            objects >= object_budget + 4096) return error.UploadStagingQuota;
        total = try std.math.add(u64, total, bytes);
        if (total > p.max_counter) return error.UploadStagingQuota;
        pending += bytes;
        const record: Record = .{ .definition = p.Growth.current_definition, .position = head.tail + i, .total_bytes = total, .item = item };
        var writer: std.Io.Writer = .fixed(buffer);
        try std.json.Stringify.value(record, .{}, &writer);
        payload.* = writer.buffered();
    }
    _ = try self.wal.appendFrames(0, head.tail, 1, 1, .process_turn, payloads[0..items.len]);
    var progress = try self.cursor();
    progress.tail_floor = head.tail + items.len;
    try self.saveCursor(progress);
    self.total = .{ .tail = progress.tail_floor, .bytes = total };
    return head.tail;
}
/// Startup reconciliation visits persisted work with constant resident memory.
/// The caller has not admitted requests and owns the exclusive native lock.
pub fn reconcile(self: *Self, context: anytype) !void {
    const head = try self.current();
    var position = head.cursor;
    while (position < head.tail) : (position += 1) try context.restore(try self.atLocked(position));
    // Startup may walk the whole retained suffix, but its final seek must
    // prepare the first consumer step rather than point at the distant tail.
    if (head.cursor < head.tail) _ = try self.atLocked(head.cursor);
}
pub fn consume(self: *Self, expected: Record) !void {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const head = try self.currentLocked();
    if (head.cursor > expected.position) return;
    if (head.cursor != expected.position or !std.meta.eql(try self.atLocked(expected.position), expected)) return error.UploadQueueConflict;
    // A verified frame at the next floor survives trimming. An EOF
    // continuation may name a removed segment and cannot serve as that hint.
    // Preserve the next actual frame before moving the durable trim floor.
    if (expected.position + 1 < head.tail) _ = try self.atLocked(expected.position + 1);
    try self.saveCursor(.{ .position = expected.position + 1, .bytes = expected.total_bytes, .tail_floor = head.tail });
    // Retain the last cumulative total even when all work has been consumed.
    _ = try self.wal.trimUnit(0, @min(expected.position + 1, head.tail - 1));
}

test "upload FIFO retains exact work across reopen and never consumes a later generation" {
    const t = std.testing;
    var temporary = t.tmpDir(.{ .iterate = true });
    defer temporary.cleanup();
    const item: Item = .{ .key = try Key.init("native/p/one"), .meta = .{ .size = 100, .sha256 = @splat(7) }, .action = .upload };
    {
        var queue = try open(t.allocator, t.io, temporary.dir);
        defer queue.deinit();
        try t.expectEqual(@as(u64, 0), try queue.enqueue(item, 100, 8));
        try t.expectError(error.UploadStagingQuota, queue.enqueue(item, 100, 8));
        const original = (try queue.next()).?;
        var later = original;
        later.position += 1;
        try t.expectError(error.UploadQueueConflict, queue.consume(later));
    }
    {
        var queue = try open(t.allocator, t.io, temporary.dir);
        defer queue.deinit();
        const original = (try queue.next()).?;
        try t.expectEqualDeep(item, original.item);
        try queue.consume(original);
        try queue.consume(original); // Lost completion response, same intent.
        try t.expect((try queue.next()) == null);
        for (0..8) |_| {
            _ = try queue.enqueue(item, 100, 8);
            try queue.consume((try queue.next()).?);
            try t.expect((try queue.next()) == null);
        }
        const head = try queue.current();
        try t.expectEqual(@as(u64, 9), head.tail);
        try t.expectEqual(head.tail, head.cursor);
        try t.expectEqual(@as(u64, 0), head.pending_bytes);
    }
    // Missing persisted progress cannot reset an established upload history.
    try temporary.dir.deleteFile(t.io, "cursor");
    try t.expectError(error.MissingUploadProgress, open(t.allocator, t.io, temporary.dir));
}

test "upload batch checks its whole quota before append and retains each original position" {
    const t = std.testing;
    var temporary = t.tmpDir(.{ .iterate = true });
    defer temporary.cleanup();
    const a: Item = .{ .key = try Key.init("native/p/a"), .meta = .{ .size = 40, .sha256 = @splat(7) }, .action = .upload };
    const b: Item = .{ .key = try Key.init("native/p/b"), .meta = .{ .size = 60, .sha256 = @splat(9) }, .action = .upload };
    {
        var queue = try open(t.allocator, t.io, temporary.dir);
        defer queue.deinit();
        try t.expectError(error.UploadStagingQuota, queue.enqueueBatch(&.{ a, b }, 99, 2));
        try t.expectError(error.UploadStagingQuota, queue.enqueueBatch(&.{ a, b }, 100, 1));
        try t.expectEqual(@as(u64, 0), (try queue.current()).tail);
        try t.expectEqual(@as(u64, 0), try queue.enqueueBatch(&.{ a, b }, 100, 2));
        try t.expectEqual(@as(u64, 100), (try queue.current()).pending_bytes);
        const first = (try queue.next()).?;
        try t.expectEqualDeep(a, first.item);
        try queue.consume(first);
    }
    {
        var queue = try open(t.allocator, t.io, temporary.dir);
        defer queue.deinit();
        const second = (try queue.next()).?;
        try t.expectEqual(@as(u64, 1), second.position);
        try t.expectEqualDeep(b, second.item);
        try t.expectEqual(@as(u64, 60), (try queue.current()).pending_bytes);
        try queue.consume(second);
        try t.expect((try queue.next()) == null);
    }
}

test "upload FIFO drains retained work without rereading growing WAL prefixes" {
    const t = std.testing;
    var temporary = t.tmpDir(.{ .iterate = true });
    defer temporary.cleanup();
    const full_key: [storage.TransitObjectStore.max_key_bytes]u8 = @splat('a');
    const item: Item = .{ .key = try Key.init(&full_key), .meta = .{ .size = 1, .sha256 = @splat(7) }, .action = .upload };
    const items: [storage.TransitObjectStore.max_put_batch]Item = @splat(item);
    const count = 128;
    {
        var queue = try open(t.allocator, t.io, temporary.dir);
        defer queue.deinit();
        for (0..count / items.len) |_| _ = try queue.enqueueBatch(&items, count, count);
        const before = queue.wal.disk.?.read_frames;
        for (0..count) |position| {
            const record = (try queue.next()).?;
            try t.expectEqual(position, record.position);
            try t.expectEqual(position + 1, record.total_bytes);
            try t.expectEqualDeep(item, record.item);
            try t.expectEqual(count - position, (try queue.current()).pending_objects);
            try queue.consume(record);
        }
        try t.expect((try queue.next()) == null);
        const reads = queue.wal.disk.?.read_frames - before;
        std.debug.print("upload FIFO backlog: {d} verified frame reads for {d} original records\n", .{ reads, count });
        try t.expect(reads <= 8 * count);
    }
    {
        var queue = try open(t.allocator, t.io, temporary.dir);
        defer queue.deinit();
        const before = queue.wal.disk.?.read_frames;
        for (0..count / items.len) |batch| {
            const first = count + batch * items.len;
            try t.expectEqual(first, try queue.enqueueBatch(&items, count, count));
            for (0..items.len) |offset| {
                const record = (try queue.next()).?;
                try t.expectEqual(first + offset, record.position);
                try t.expectEqual(first + offset + 1, record.total_bytes);
                try t.expectEqualDeep(item, record.item);
                try queue.consume(record);
            }
            const head = try queue.current();
            try t.expectEqual(head.tail, head.cursor);
            try t.expectEqual(@as(u64, 0), head.pending_bytes);
        }
        const reads = queue.wal.disk.?.read_frames - before;
        std.debug.print("upload FIFO interleaved append/drain: {d} verified frame reads for {d} original records\n", .{ reads, count });
        try t.expect(reads <= 8 * count);
    }
}

test "upload FIFO resumes bounded reads after cold open and reconciliation" {
    const t = std.testing;
    var temporary = t.tmpDir(.{ .iterate = true });
    defer temporary.cleanup();
    const item: Item = .{ .key = try Key.init("native/p/reopen"), .meta = .{ .size = 1, .sha256 = @splat(7) }, .action = .upload };
    const items: [storage.TransitObjectStore.max_put_batch]Item = @splat(item);
    const count = 128;
    {
        var queue = try open(t.allocator, t.io, temporary.dir);
        defer queue.deinit();
        for (0..count / items.len) |_| _ = try queue.enqueueBatch(&items, count, count);
        for (0..count - 2) |_| try queue.consume((try queue.next()).?);
    }
    var queue = try open(t.allocator, t.io, temporary.dir);
    defer queue.deinit();
    const first_reads = queue.wal.disk.?.read_frames;
    try t.expectEqual(@as(u64, count - 2), (try queue.next()).?.position);
    const cold_reads = queue.wal.disk.?.read_frames - first_reads;
    std.debug.print("upload FIFO first read after cold open: {d} verified frame reads\n", .{cold_reads});
    try t.expect(cold_reads <= 8);
    const Restore = struct {
        next_position: u64 = count - 2,
        expected: Item,
        pub fn restore(self: *@This(), record: Record) !void {
            try t.expectEqual(self.next_position, record.position);
            try t.expectEqual(record.position + 1, record.total_bytes);
            try t.expectEqualDeep(self.expected, record.item);
            self.next_position += 1;
        }
    };
    var restored: Restore = .{ .expected = item };
    try queue.reconcile(&restored);
    try t.expectEqual(@as(u64, count), restored.next_position);
    const before = queue.wal.disk.?.read_frames;
    for (count - 2..count) |position| {
        const record = (try queue.next()).?;
        try t.expectEqual(@as(u64, position), record.position);
        try t.expectEqualDeep(item, record.item);
        try queue.consume(record);
    }
    try t.expect((try queue.next()) == null);
    const reads = queue.wal.disk.?.read_frames - before;
    std.debug.print("upload FIFO reconciled drain: {d} verified frame reads for two original records\n", .{reads});
    try t.expect(reads <= 16);
}

test "upload FIFO bounds cleanup syncs while each consumed position remains durable" {
    const t = std.testing;
    var temporary = t.tmpDir(.{ .iterate = true });
    defer temporary.cleanup();
    const item: Item = .{ .key = try Key.init("native/p/cleanup"), .meta = .{ .size = 1, .sha256 = @splat(7) }, .action = .upload };
    const items: [storage.TransitObjectStore.max_put_batch]Item = @splat(item);
    const count = 128;
    var syncs: u64 = 0;
    {
        var queue = try open(t.allocator, t.io, temporary.dir);
        defer queue.deinit();
        for (0..count / items.len) |_| _ = try queue.enqueueBatch(&items, count, count);
        const before = queue.wal.disk.?.syncs;
        // Reopen inside a cleanup group: the cursor must already be durable.
        for (0..3) |_| try queue.consume((try queue.next()).?);
        syncs += queue.wal.disk.?.syncs - before;
    }
    {
        var queue = try open(t.allocator, t.io, temporary.dir);
        defer queue.deinit();
        const before = queue.wal.disk.?.syncs;
        for (3..count) |position| {
            const record = (try queue.next()).?;
            try t.expectEqual(@as(u64, position), record.position);
            try t.expectEqual(@as(u64, position + 1), record.total_bytes);
            try t.expectEqualDeep(item, record.item);
            try queue.consume(record);
        }
        try t.expect((try queue.next()) == null);
        syncs += queue.wal.disk.?.syncs - before;
    }
    // Count actual WAL file/directory syncs, excluding the required per-record
    // cursor barrier, append and reopen. Cleanup must amortize its own barriers.
    std.debug.print("upload FIFO cleanup: {d} WAL syncs for {d} consumed records\n", .{ syncs, count });
    try t.expect(syncs <= count);
    var queue = try open(t.allocator, t.io, temporary.dir);
    defer queue.deinit();
    const head = try queue.current();
    try t.expectEqual(@as(u64, count), head.cursor);
    try t.expectEqual(head.cursor, head.tail);
    try t.expectEqual(@as(u64, 0), head.pending_bytes);
}
