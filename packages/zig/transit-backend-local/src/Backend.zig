//! Exclusive local owner shared by bounded request lanes. No physical collection
//! is inferred from an unpublished root or from quota pressure.
const std = @import("std");
const core = @import("transit_core");
const storage = @import("transit_storage");
const Self = @This();

allocator: std.mem.Allocator,
io: std.Io,
directory: std.Io.Dir,
lock: std.Io.File,
wal: storage.LocalWal.LocalWal,
objects: storage.LocalSegmentStore.LocalSegmentStore,
mutex: std.Io.Mutex = .init,
limits: core.protocol.Storage.Limits,
allocated: u64,

pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, path: []const u8, limits: core.protocol.Storage.Limits) !Self {
    try limits.validate();
    // The object root's mandatory marker guards the entire native layout. A
    // separate lifetime lock covers the WAL and object owner together.
    var objects = try storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(allocator, io, parent, path);
    errdefer objects.deinit();
    const directory = try parent.openDir(io, path, .{ .iterate = true });
    errdefer directory.close(io);
    const lock = try directory.createFile(io, ".native-owner", .{ .read = true, .truncate = false, .permissions = .fromMode(0o600) });
    errdefer lock.close(io);
    if (!try lock.tryLock(io, .exclusive)) return error.NativeStorageInUse;
    try bindNativeOwner(io, directory, lock);
    var wal = try storage.LocalWal.LocalWal.openDiskWithOptions(allocator, io, directory, "wal", .{});
    errdefer wal.deinit();
    var allocated = try countFiles(io, directory);
    // Known depth only; file/object cardinality does not determine resident size.
    for ([_][]const u8{ "keys", "locks", "objects", "wal" }) |relative| {
        const child = try directory.openDir(io, relative, .{ .iterate = true });
        defer child.close(io);
        allocated = try std.math.add(u64, allocated, try countFiles(io, child));
    }
    return .{ .allocator = allocator, .io = io, .directory = directory, .lock = lock, .wal = wal, .objects = objects, .limits = limits, .allocated = allocated };
}

fn bindNativeOwner(io: std.Io, directory: std.Io.Dir, lock: std.Io.File) !void {
    var expected: [64]u8 = @splat(0);
    expected[0..8].* = "TNOWNER1".*;
    expected[8..40].* = core.protocol.Growth.definition_bytes;
    const size = try lock.length(io);
    if (size != 0) {
        var bytes: [64]u8 = undefined;
        if (size != bytes.len or try lock.readPositionalAll(io, &bytes, 0) != bytes.len or !std.mem.eql(u8, &bytes, &expected)) return error.IncompatibleDefinition;
        return;
    }
    // A shared object directory with existing data is not a fresh native
    // installation. Never manufacture a new authority alongside that history.
    var iterator = directory.iterate();
    while (try iterator.next(io)) |entry| {
        if (std.mem.eql(u8, entry.name, ".initialize") or std.mem.eql(u8, entry.name, ".definition") or std.mem.eql(u8, entry.name, ".native-owner")) continue;
        if (!std.mem.eql(u8, entry.name, "keys") and !std.mem.eql(u8, entry.name, "locks") and !std.mem.eql(u8, entry.name, "objects")) return error.NativeStorageUnmarked;
        const child = try directory.openDir(io, entry.name, .{ .iterate = true });
        defer child.close(io);
        var contents = child.iterate();
        if (try contents.next(io) != null) return error.NativeStorageUnmarked;
    }
    try lock.writePositionalAll(io, &expected, 0);
    try lock.sync(io);
    const file: std.Io.File = .{ .handle = directory.handle, .flags = .{ .nonblocking = false } };
    try file.sync(io);
}

pub fn deinit(self: *Self) void {
    self.objects.deinit();
    self.wal.deinit();
    self.lock.close(self.io);
    self.directory.close(self.io);
    self.* = undefined;
}

fn countFiles(io: std.Io, directory: std.Io.Dir) !u64 {
    var total: u64 = 0;
    var iterator = directory.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind == .directory) continue;
        const file = try directory.openFile(io, entry.name, .{ .follow_symlinks = false });
        defer file.close(io);
        total = try std.math.add(u64, total, try file.length(io));
    }
    return total;
}

/// The caller holds mutex. Uncertain staging consumes its reservation; only a
/// later exclusive reopen can recount actual bytes. No accepted work is evicted.
pub fn reserve(self: *Self, bytes: usize, control: bool) !void {
    const ceiling = try std.math.add(u64, self.limits.bytes, if (control) self.limits.control_bytes else 0);
    if (self.allocated > ceiling or bytes > ceiling - self.allocated) return error.StorageQuota;
    self.allocated += bytes;
}

pub fn put(self: *Self, key: []const u8, bytes: []const u8, control: bool) !void {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const store = self.objects.objectStore();
    if (try store.head(key) == null) {
        // Payload, checksum chunks, descriptor and bounded publication overhead.
        const checks = std.math.divCeil(usize, bytes.len, 64 * 1024) catch unreachable;
        try self.reserve(bytes.len + checks * 32 + 1024, control);
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    _ = try store.putImmutable(key, bytes, digest);
}

pub fn read(self: *Self, key: []const u8, output: []u8) ![]const u8 {
    // Immutable contents are safe to read outside the log/allocator mutex.
    // LocalSegmentStore counters are mutable, so serialize its facade as well.
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const store = self.objects.objectStore();
    const metadata = try store.head(key) orelse return error.MissingStorageObject;
    if (metadata.size > output.len) return error.StorageObjectTooLarge;
    return store.getRange(key, 0, @intCast(metadata.size), output);
}
