//! Durable FIFO intent precedes native content creation. Carry/consume is one
//! WAL append; bounded iteration and recovery never materialize the inventory.
const std = @import("std");
const core = @import("transit_core");
const storage = @import("transit_storage");
const Files = @import("LocalFiles.zig");
const Self = @This();
pub const Name = [83]u8;
pub const record_bytes = 160;
pub const QueueHead = struct { tail: u64, cursor: u64 };
pub const QueueRecord = struct { position: u64, cursor: u64, item: ?Allocation };
pub const queue_record_bytes = 64 + record_bytes;
pub const Allocation = struct {
    epoch: u64,
    kind: enum(u8) { page = 'p', block = 'b' },
    address: [32]u8,
    meta: storage.TransitObjectStore.ObjectMeta,

    pub fn key(self: Allocation, output: *[96]u8) ![]const u8 {
        return std.fmt.bufPrint(output, "native/{c}/{x}", .{ @backingInt(self.kind), &self.address });
    }
    pub fn name(self: Allocation) Name {
        var result: Name = undefined;
        _ = std.fmt.bufPrint(&result, "{x:0>16}-{c}-{x}", .{ self.epoch, @backingInt(self.kind), &self.address }) catch unreachable;
        return result;
    }
    fn validate(self: Allocation) !void {
        if (self.epoch == 0 or self.epoch > core.protocol.max_counter or std.mem.allEqual(u8, &self.address, 0) or self.meta.size > storage.TransitObjectStore.max_object_bytes) return error.InvalidNativeAllocation;
    }
    fn encode(self: Allocation) ![record_bytes]u8 {
        try self.validate();
        var bytes: [record_bytes]u8 = @splat(0);
        bytes[0..8].* = "TALLOC1\x00".*;
        bytes[8..40].* = core.protocol.Growth.definition_bytes;
        std.mem.writeInt(u64, bytes[40..48], self.epoch, .little);
        bytes[48] = @backingInt(self.kind);
        bytes[56..88].* = self.address;
        std.mem.writeInt(u64, bytes[88..96], self.meta.size, .little);
        bytes[96..128].* = self.meta.sha256;
        std.crypto.hash.sha2.Sha256.hash(bytes[0..128], bytes[128..160], .{});
        return bytes;
    }
    fn decode(bytes: []const u8) !Allocation {
        if (bytes.len != record_bytes) return error.InvalidNativeAllocation;
        if (!std.mem.eql(u8, bytes[8..40], &core.protocol.Growth.definition_bytes)) return error.IncompatibleDefinition;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes[0..128], &digest, .{});
        if (!std.mem.eql(u8, bytes[0..8], "TALLOC1\x00") or !std.mem.allEqual(u8, bytes[49..56], 0) or !std.mem.eql(u8, bytes[128..160], &digest)) return error.InvalidNativeAllocation;
        const result: Allocation = .{
            .epoch = std.mem.readInt(u64, bytes[40..48], .little),
            .kind = std.enums.fromInt(@FieldType(Allocation, "kind"), bytes[48]) orelse return error.InvalidNativeAllocation,
            .address = bytes[56..88].*,
            .meta = .{ .size = std.mem.readInt(u64, bytes[88..96], .little), .sha256 = bytes[96..128].* },
        };
        try result.validate();
        return result;
    }
};

io: std.Io,
directory: std.Io.Dir,
queue: storage.LocalWal.LocalWal,
allocator: std.mem.Allocator,

pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir) !Self {
    const directory = try parent.openDir(io, "native-allocations", .{ .iterate = true });
    errdefer directory.close(io);
    const existing = directory.openDir(io, "queue", .{}) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (existing) |dir| dir.close(io) else {
        var iterator = directory.iterate();
        if (try iterator.next(io) != null) return error.MissingAllocationHistory;
    }
    var queue = try storage.LocalWal.LocalWal.openDiskWithOptions(allocator, io, directory, "queue", .{});
    errdefer queue.deinit();
    if (try queue.log().tail(0) == 0) {
        const scan = try directory.openDir(io, ".", .{ .iterate = true });
        defer scan.close(io);
        var iterator = scan.iterate();
        while (try iterator.next(io)) |entry| if (entry.name.len == @sizeOf(Name)) return error.MissingAllocationHistory;
    }
    return .{ .io = io, .directory = directory, .allocator = allocator, .queue = queue };
}
pub fn deinit(self: *Self) void {
    self.queue.deinit();
    self.directory.close(self.io);
}
pub fn record(self: *Self, allocation: Allocation) !bool {
    const encoded = try allocation.encode();
    const name = allocation.name();
    var bytes: [record_bytes]u8 = undefined;
    if (try Files.read(self.io, self.directory, &name, &bytes)) |existing| {
        if (!std.mem.eql(u8, existing, &encoded)) return error.InvalidNativeAllocation;
        // Resolve a prior uncertain link before creating content behind it.
        const file = try self.directory.openFile(self.io, &name, .{});
        defer file.close(self.io);
        try file.sync(self.io);
        try Files.sync(self.io, self.directory);
        return false;
    }
    // An uncertain append creates no content. A retry without its exact marker
    // may add a duplicate intent; collection safely consumes both references.
    const head = try self.current();
    try self.append(.{ .position = head.tail, .cursor = head.cursor, .item = allocation });
    try Files.save(self.io, self.directory, &name, &encoded, false);
    return true;
}
pub fn read(self: *Self, name: Name) !?Allocation {
    var bytes: [record_bytes]u8 = undefined;
    const encoded = (try Files.read(self.io, self.directory, &name, &bytes)) orelse return null;
    const allocation = try Allocation.decode(encoded);
    if (!std.mem.eql(u8, &allocation.name(), &name)) return error.InvalidNativeAllocation;
    return allocation;
}
fn append(self: *Self, entry: QueueRecord) !void {
    if (entry.cursor > entry.position) return error.InvalidAllocationHistory;
    var bytes: [queue_record_bytes]u8 = @splat(0);
    bytes[0..8].* = "TNALQ1\x00\x00".*;
    bytes[8..40].* = core.protocol.Growth.definition_bytes;
    std.mem.writeInt(u64, bytes[40..48], entry.position, .little);
    std.mem.writeInt(u64, bytes[48..56], entry.cursor, .little);
    if (entry.item) |item| {
        bytes[56] = 1;
        bytes[64..].* = try item.encode();
    }
    _ = try self.queue.log().append(0, entry.position, 1, 1, .manifest_checkpoint, &bytes);
}
pub fn at(self: *Self, position: u64) !QueueRecord {
    var batch = try self.queue.log().read(self.allocator, 0, position, 1);
    defer batch.deinit();
    if (batch.frames.len != 1) return error.MissingAllocationHistory;
    const frame = batch.frames[0];
    const bytes = frame.payload;
    if (frame.header.partition_id != 0 or frame.header.lsn != position or frame.header.kind != .manifest_checkpoint or frame.header.writer_epoch != 1 or frame.header.policy_epoch != 1 or bytes.len != queue_record_bytes) return error.InvalidAllocationHistory;
    if (!std.mem.eql(u8, bytes[8..40], &core.protocol.Growth.definition_bytes)) return error.IncompatibleDefinition;
    if (!std.mem.eql(u8, bytes[0..8], "TNALQ1\x00\x00") or !std.mem.allEqual(u8, bytes[57..64], 0) or bytes[56] > 1 or (bytes[56] == 0 and !std.mem.allEqual(u8, bytes[64..], 0))) return error.InvalidAllocationHistory;
    const entry: QueueRecord = .{ .position = std.mem.readInt(u64, bytes[40..48], .little), .cursor = std.mem.readInt(u64, bytes[48..56], .little), .item = if (bytes[56] == 1) try Allocation.decode(bytes[64..]) else null };
    if (entry.position != position or entry.cursor > position) return error.InvalidAllocationHistory;
    return entry;
}
pub fn current(self: *Self) !QueueHead {
    const tail = try self.queue.log().tail(0);
    return .{ .tail = tail, .cursor = if (tail == 0) 0 else (try self.at(tail - 1)).cursor };
}
/// The caller serializes queue operations. A carry and cursor advance share one
/// accepted WAL record, so uncertainty cannot lose or double-consume ownership.
pub fn consume(self: *Self, cursor: u64, expected: ?Allocation, keep: bool) !void {
    const head = try self.current();
    if (head.cursor != cursor or cursor >= head.tail or (keep and expected == null)) return error.AllocationConflict;
    if (!std.meta.eql((try self.at(cursor)).item, expected)) return error.AllocationConflict;
    try self.append(.{ .position = head.tail, .cursor = cursor + 1, .item = if (keep) expected else null });
}
/// Collapse at most 64 empty records in one progress append. Internal progress
/// frames therefore shrink across collections instead of retaining peak history.
pub fn consumeEmpty(self: *Self, end: u64) !void {
    const head = try self.current();
    var cursor = head.cursor;
    while (cursor < @min(end, head.tail) and cursor - head.cursor < 64) : (cursor += 1) {
        if ((try self.at(cursor)).item != null) break;
    }
    if (cursor == head.cursor) return error.AllocationConflict;
    try self.append(.{ .position = head.tail, .cursor = cursor, .item = null });
}
pub fn trim(self: *Self) !void {
    const head = try self.current();
    if (head.cursor != 0) try self.queue.log().trim(0, head.cursor);
}
pub fn remove(self: *Self, allocation: Allocation) !void {
    const name = allocation.name();
    if (try self.read(name)) |existing| if (!std.meta.eql(existing, allocation)) return error.InvalidNativeAllocation;
    try Files.remove(self.io, self.directory, &name);
}
