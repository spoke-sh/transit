//! Exclusive local owner shared by bounded request lanes. No physical collection
//! is inferred from an unpublished root or from quota pressure.
const std = @import("std");
const core = @import("transit_core");
const storage = @import("transit_storage");
const Allocations = @import("NativeAllocations.zig");
const DataAllocations = @import("DataAllocations.zig");
const Self = @This();

allocator: std.mem.Allocator,
io: std.Io,
directory: std.Io.Dir,
lock: std.Io.File,
wal: storage.LocalWal.LocalWal,
objects: storage.LocalSegmentStore.LocalSegmentStore,
allocations: Allocations,
data_allocations: DataAllocations,
mutex: std.Io.Mutex = .init,
collection: std.Io.Mutex = .init,
/// Creation holds the shared side through inventory and object publication.
/// Reclamation must hold the exclusive side before inspecting the latest epoch.
data_creators: std.Io.RwLock = .init,
/// Serializes the private allocation queue, independently of native publication.
/// Lock order: data_creators, data_inventory, then short quota/head mutex work.
data_inventory: std.Io.Mutex = .init,
/// Data owners hold a shared fence only while checking/disclosing/committing.
/// Native publication takes the exclusive side; private staging holds neither.
authority: std.Io.RwLock = .init,
/// A verified accepted native head, never a private candidate. Access under
/// mutex; Store invalidates it before any potentially uncertain native append.
accepted_native: ?core.growing.Head = null,
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
    var allocations = try Allocations.open(allocator, io, directory);
    errdefer allocations.deinit();
    var data_allocations = try DataAllocations.open(allocator, io, directory);
    errdefer data_allocations.deinit();
    var allocated = try countFiles(io, directory);
    // Known depth only; file/object cardinality does not determine resident size.
    for ([_][]const u8{ "keys", "locks", "objects", "wal", "native-allocations", "native-allocations/queue", "data-allocations", "data-allocations/queue" }) |relative| {
        const child = try directory.openDir(io, relative, .{ .iterate = true });
        defer child.close(io);
        allocated = try std.math.add(u64, allocated, try countFiles(io, child));
    }
    return .{ .allocator = allocator, .io = io, .directory = directory, .lock = lock, .wal = wal, .objects = objects, .allocations = allocations, .data_allocations = data_allocations, .limits = limits, .allocated = allocated };
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
        if (!std.mem.eql(u8, entry.name, "keys") and !std.mem.eql(u8, entry.name, "locks") and !std.mem.eql(u8, entry.name, "objects") and !std.mem.eql(u8, entry.name, "native-allocations") and !std.mem.eql(u8, entry.name, "data-allocations")) return error.NativeStorageUnmarked;
        const child = try directory.openDir(io, entry.name, .{ .iterate = true });
        defer child.close(io);
        var contents = child.iterate();
        if (try contents.next(io) != null) return error.NativeStorageUnmarked;
    }
    try directory.createDirPath(io, "native-allocations");
    try directory.createDirPath(io, "data-allocations");
    try @import("LocalFiles.zig").sync(io, directory);
    try lock.writePositionalAll(io, &expected, 0);
    try lock.sync(io);
    const file: std.Io.File = .{ .handle = directory.handle, .flags = .{ .nonblocking = false } };
    try file.sync(io);
}

pub fn deinit(self: *Self) void {
    self.data_allocations.deinit();
    self.allocations.deinit();
    self.objects.deinit();
    self.wal.deinit();
    self.lock.close(self.io);
    self.directory.close(self.io);
    self.* = undefined;
}

/// Observe all three serialized log owners without reading payloads or changing
/// authority. The host must join every borrower before closing/reopening us.
pub fn requiresRecovery(self: *Self) !bool {
    try self.data_inventory.lock(self.io);
    defer self.data_inventory.unlock(self.io);
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    return self.wal.requiresRecovery() or self.allocations.queue.requiresRecovery() or
        self.data_allocations.queue.requiresRecovery();
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
    try dataKey(key);
    if (bytes.len > storage.TransitObjectStore.max_object_bytes) return error.ObjectTooLarge;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const meta: storage.TransitObjectStore.ObjectMeta = .{ .size = bytes.len, .sha256 = digest };
    try self.data_creators.lockShared(self.io);
    defer self.data_creators.unlockShared(self.io);
    const store = self.objects.objectStore();
    const existing = try store.head(key);
    if (existing) |known| if (!std.meta.eql(known, meta)) return error.ImmutableObjectConflict;
    const epoch = blk: {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        const epoch = if (try self.wal.log().tail(0) == 0) 1 else (try @import("Store.zig").currentHeadLocked(self)).storage_epoch;
        // Payload, checksum chunks, descriptor and bounded publication overhead.
        // Concurrent missing-key observations can reserve twice. Keep both
        // reservations until reopen rather than undercount uncertain staging.
        // Reserve before waiting on private inventory I/O so ordinary writes
        // still fail quota promptly while another creator's sync is paused.
        if (existing == null) {
            const checks = std.math.divCeil(usize, bytes.len, 64 * 1024) catch unreachable;
            try self.reserve(bytes.len + checks * 32 + 1024, control);
        }
        break :blk epoch;
    };
    const allocation = try DataAllocations.Allocation.init(epoch, key, meta);
    {
        try self.data_inventory.lock(self.io);
        defer self.data_inventory.unlock(self.io);
        const previous = try self.data_allocations.latest(allocation.name());
        if (previous == null or previous.?.epoch < epoch) {
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);
            try self.reserve(DataAllocations.record_bytes + storage.TransitLog.alignedFrameSize(DataAllocations.queue_record_bytes) + 1024, control);
        }
        // Persist a new epoch even for deduplicated content. The old allocation
        // cannot authorize deletion after this key is reused by newer work.
        _ = try self.data_allocations.record(allocation);
    }
    // Private immutable publication is per-key. Disk syncs must not hold the
    // quota/journal mutex or delay unrelated native reads and control work.
    _ = try store.putImmutable(key, bytes, digest);
}

pub fn dataKey(key: []const u8) !void {
    try storage.TransitObjectStore.validateKey(key);
    if (std.mem.startsWith(u8, key, "native/")) return error.NativeObjectReserved;
}

/// Record the allocation before any object bytes. The accepted epoch fences
/// delayed creators, including those whose previous publication was uncertain.
pub fn putNative(self: *Self, epoch: u64, kind: @FieldType(Allocations.Allocation, "kind"), address: [32]u8, bytes: []const u8, control: bool) !void {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const current_epoch = if (try self.wal.log().tail(0) == 0) 1 else (try @import("Store.zig").currentHeadLocked(self)).storage_epoch;
    // A storage-fence candidate stages in the next epoch before acceptance.
    if (epoch < current_epoch or epoch - current_epoch > 1) return error.StaleStorageEpoch;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const allocation: Allocations.Allocation = .{ .epoch = epoch, .kind = kind, .address = address, .meta = .{ .size = bytes.len, .sha256 = digest } };
    if (try self.allocations.read(allocation.name()) == null) {
        const checks = std.math.divCeil(usize, bytes.len, 64 * 1024) catch unreachable;
        try self.reserve(bytes.len + checks * 32 + 1536 + Allocations.record_bytes, control);
    }
    _ = try self.allocations.record(allocation);
    var key: [96]u8 = undefined;
    _ = try self.objects.objectStore().putImmutable(try allocation.key(&key), bytes, digest);
}

pub fn read(self: *Self, key: []const u8, output: []u8) ![]const u8 {
    const store = self.objects.objectStore();
    const metadata = try store.head(key) orelse return error.MissingStorageObject;
    if (metadata.size > output.len) return error.StorageObjectTooLarge;
    return store.getRange(key, 0, @intCast(metadata.size), output);
}
