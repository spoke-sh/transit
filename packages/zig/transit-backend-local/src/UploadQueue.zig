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

pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir) !Self {
    var wal = try storage.LocalWal.LocalWal.openDiskWithOptions(allocator, io, parent, "queue", .{});
    errdefer wal.deinit();
    var self: Self = .{ .allocator = allocator, .io = io, .directory = parent, .wal = wal };
    var bytes: [96]u8 = undefined;
    if (try Files.read(io, parent, "cursor", &bytes) == null) {
        if (try self.wal.log().tail(0) != 0) return error.MissingUploadProgress;
        try self.saveCursor(.{});
    }
    _ = try self.current();
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
    var batch = try self.wal.log().read(self.allocator, 0, position, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != position or batch.frames[0].payload.len > record_limit) return error.InvalidUploadQueue;
    const parsed = try std.json.parseFromSlice(Record, self.allocator, batch.frames[0].payload, .{});
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
    const total = if (tail == 0) 0 else (try self.atLocked(tail - 1)).total_bytes;
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
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const head = try self.currentLocked();
    const bytes = if (item.action == .upload) item.meta.size else 0;
    if ((item.action == .upload and (head.pending_bytes > staging_budget or bytes > staging_budget - head.pending_bytes or head.pending_objects >= object_budget)) or
        head.pending_objects >= object_budget + 4096) return error.UploadStagingQuota;
    const total = try std.math.add(u64, (try self.cursor()).bytes + head.pending_bytes, bytes);
    if (total > p.max_counter) return error.UploadStagingQuota;
    const record: Record = .{ .definition = p.Growth.current_definition, .position = head.tail, .total_bytes = total, .item = item };
    var buffer: [record_limit]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try std.json.Stringify.value(record, .{}, &writer);
    _ = try self.wal.log().append(0, record.position, 1, 1, .process_turn, writer.buffered());
    var progress = try self.cursor();
    progress.tail_floor = head.tail + 1;
    try self.saveCursor(progress);
    return head.tail;
}
/// Startup reconciliation visits persisted work with constant resident memory.
/// The caller has not admitted requests and owns the exclusive native lock.
pub fn reconcile(self: *Self, context: anytype) !void {
    const head = try self.current();
    var position = head.cursor;
    while (position < head.tail) : (position += 1) try context.restore(try self.atLocked(position));
}
pub fn consume(self: *Self, expected: Record) !void {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const head = try self.currentLocked();
    if (head.cursor > expected.position) return;
    if (head.cursor != expected.position or !std.meta.eql(try self.atLocked(expected.position), expected)) return error.UploadQueueConflict;
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
