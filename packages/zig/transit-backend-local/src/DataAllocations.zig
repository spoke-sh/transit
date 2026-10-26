//! Durable direct-data creation/reuse inventory. The latest per-key epoch
//! protects reused immutable content from a collector's older allocation entry.
//! This private inventory confers no publication or deletion authority.
const std = @import("std");
const core = @import("transit_core");
const storage = @import("transit_storage");
const Files = @import("LocalFiles.zig");
const Self = @This();
const Objects = storage.TransitObjectStore;
pub const Name = [64]u8;
pub const record_bytes = 512;
pub const queue_record_bytes = 64 + record_bytes;
pub const QueueHead = struct { tail: u64, cursor: u64 };
pub const QueueRecord = struct { position: u64, cursor: u64, item: ?Allocation };
pub const Allocation = struct {
    epoch: u64,
    object_key: storage.TreeStore.pages.Bytes(Objects.max_key_bytes),
    meta: Objects.ObjectMeta,

    pub fn init(epoch: u64, key: []const u8, meta: Objects.ObjectMeta) !Allocation {
        const result: Allocation = .{ .epoch = epoch, .object_key = try .init(key), .meta = meta };
        try result.validate();
        return result;
    }
    pub fn name(self: Allocation) Name {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(self.object_key.slice(), &digest, .{});
        return std.fmt.bytesToHex(digest, .lower);
    }
    fn validate(self: Allocation) !void {
        try self.object_key.validate();
        try Objects.validateKey(self.object_key.slice());
        if (self.epoch == 0 or self.epoch > core.protocol.max_counter or
            self.meta.size > Objects.max_object_bytes or
            std.mem.startsWith(u8, self.object_key.slice(), "native/")) return error.InvalidDataAllocation;
    }
    fn encode(self: Allocation) ![record_bytes]u8 {
        try self.validate();
        var bytes: [record_bytes]u8 = @splat(0);
        bytes[0..8].* = "TDALLOC1".*;
        bytes[8..40].* = core.protocol.Growth.definition_bytes;
        std.mem.writeInt(u64, bytes[40..48], self.epoch, .little);
        std.mem.writeInt(u16, bytes[48..50], self.object_key.len, .little);
        std.mem.writeInt(u64, bytes[56..64], self.meta.size, .little);
        bytes[64..96].* = self.meta.sha256;
        bytes[96..352].* = self.object_key.data;
        std.crypto.hash.sha2.Sha256.hash(bytes[0..480], bytes[480..512], .{});
        return bytes;
    }
    fn decode(bytes: []const u8) !Allocation {
        if (bytes.len != record_bytes) return error.InvalidDataAllocation;
        if (!std.mem.eql(u8, bytes[8..40], &core.protocol.Growth.definition_bytes)) return error.IncompatibleDefinition;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes[0..480], &digest, .{});
        if (!std.mem.eql(u8, bytes[0..8], "TDALLOC1") or !std.mem.eql(u8, bytes[480..512], &digest) or
            !std.mem.allEqual(u8, bytes[50..56], 0) or !std.mem.allEqual(u8, bytes[352..480], 0)) return error.InvalidDataAllocation;
        const result: Allocation = .{
            .epoch = std.mem.readInt(u64, bytes[40..48], .little),
            .object_key = .{ .len = std.mem.readInt(u16, bytes[48..50], .little), .data = bytes[96..352].* },
            .meta = .{ .size = std.mem.readInt(u64, bytes[56..64], .little), .sha256 = bytes[64..96].* },
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
    const directory = try parent.openDir(io, "data-allocations", .{ .iterate = true });
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
pub fn latest(self: *Self, name: Name) !?Allocation {
    var buffer: [record_bytes]u8 = undefined;
    const bytes = (try Files.read(self.io, self.directory, &name, &buffer)) orelse return null;
    const allocation = try Allocation.decode(bytes);
    if (!std.mem.eql(u8, &allocation.name(), &name)) return error.InvalidDataAllocation;
    return allocation;
}
/// Caller serializes inventory updates and excludes reclamation through content
/// publication. Record existing content reused in a newer accepted epoch too.
pub fn record(self: *Self, allocation: Allocation) !bool {
    const encoded = try allocation.encode();
    const name = allocation.name();
    const previous = try self.latest(name);
    if (previous) |known| {
        if (!std.meta.eql(known.object_key, allocation.object_key) or !std.meta.eql(known.meta, allocation.meta)) return error.ImmutableObjectConflict;
        if (known.epoch > allocation.epoch) return error.StaleStorageEpoch;
        if (known.epoch == allocation.epoch) {
            const file = try self.directory.openFile(self.io, &name, .{});
            defer file.close(self.io);
            try file.sync(self.io);
            try Files.sync(self.io, self.directory);
            return false;
        }
    }
    const head = try self.current();
    try self.append(.{ .position = head.tail, .cursor = head.cursor, .item = allocation });
    // An uncertain append/marker publication creates no object. Retrying can
    // duplicate an intent, but cannot omit a creator from the durable queue.
    try Files.save(self.io, self.directory, &name, &encoded, previous != null);
    return true;
}
fn append(self: *Self, entry: QueueRecord) !void {
    if (entry.cursor > entry.position) return error.InvalidAllocationHistory;
    var bytes: [queue_record_bytes]u8 = @splat(0);
    bytes[0..8].* = "TDALQ1\x00\x00".*;
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
    if (frame.header.partition_id != 0 or frame.header.lsn != position or frame.header.kind != .manifest_checkpoint or
        frame.header.writer_epoch != 1 or frame.header.policy_epoch != 1 or bytes.len != queue_record_bytes) return error.InvalidAllocationHistory;
    if (!std.mem.eql(u8, bytes[8..40], &core.protocol.Growth.definition_bytes)) return error.IncompatibleDefinition;
    if (!std.mem.eql(u8, bytes[0..8], "TDALQ1\x00\x00") or !std.mem.allEqual(u8, bytes[57..64], 0) or
        bytes[56] > 1 or (bytes[56] == 0 and !std.mem.allEqual(u8, bytes[64..], 0))) return error.InvalidAllocationHistory;
    const entry: QueueRecord = .{
        .position = std.mem.readInt(u64, bytes[40..48], .little),
        .cursor = std.mem.readInt(u64, bytes[48..56], .little),
        .item = if (bytes[56] == 1) try Allocation.decode(bytes[64..]) else null,
    };
    if (entry.position != position or entry.cursor > position) return error.InvalidAllocationHistory;
    return entry;
}
pub fn current(self: *Self) !QueueHead {
    const tail = try self.queue.log().tail(0);
    return .{ .tail = tail, .cursor = if (tail == 0) 0 else (try self.at(tail - 1)).cursor };
}
pub fn consume(self: *Self, cursor: u64, expected: ?Allocation, keep: bool) !void {
    const head = try self.current();
    if (head.cursor != cursor or cursor >= head.tail or (keep and expected == null)) return error.AllocationConflict;
    if (!std.meta.eql((try self.at(cursor)).item, expected)) return error.AllocationConflict;
    try self.append(.{ .position = head.tail, .cursor = cursor + 1, .item = if (keep) expected else null });
}
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
/// The reclamation owner separately proves reachability and epoch safety while
/// holding its creation mutex. A newer reuse must never lose its marker.
pub fn remove(self: *Self, allocation: Allocation) !void {
    const name = allocation.name();
    if (try self.latest(name)) |known| if (!std.meta.eql(known, allocation)) return error.AllocationConflict;
    try Files.remove(self.io, self.directory, &name);
}
