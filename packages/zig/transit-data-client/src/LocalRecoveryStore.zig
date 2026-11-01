//! Explicit local recovery storage. Records preserve exact original bytes and
//! opaque owner evidence; neither a record nor the filesystem lock grants
//! permission to dispatch work. The exclusive owner must join users before close.
const std = @import("std");
const builtin = @import("builtin");
const p = @import("transit_catalog").protocol;
const Self = @This();

pub const Key = [32]u8;
pub const Record = struct { key: Key, revision: u64, original: []const u8, evidence: []const u8 };
pub const Page = struct { count: usize, next: ?Key };
pub const Config = struct { record_bytes: usize = 1024 * 1024 };
const header_bytes = 116;
const magic = "TCR1";
allocator: std.mem.Allocator,
io: std.Io,
directory: std.Io.Dir,
owner: std.Io.File,
buffer: []u8,
mutex: std.Io.Mutex = .init,

fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
fn fileName(key: Key) [68]u8 {
    var name: [68]u8 = undefined;
    @memcpy(name[0..64], &std.fmt.bytesToHex(key, .lower));
    @memcpy(name[64..], ".rec");
    return name;
}
fn private(stat: std.Io.File.Stat, kind: std.Io.File.Kind) !void {
    if (stat.kind != kind or stat.permissions.toMode() & 0o077 != 0) return error.RecoveryStorePermissions;
}
fn syncDirectory(io: std.Io, directory: std.Io.Dir) !void {
    const file: std.Io.File = .{ .handle = directory.handle, .flags = .{ .nonblocking = false } };
    try file.sync(io);
}
fn temporary(name: []const u8) bool {
    if (name.len != 16) return false;
    for (name) |byte| if (!std.ascii.isHex(byte)) return false;
    return true;
}

/// Linux local filesystems only. `name` is one child of a trusted parent, which
/// must not be renamed/replaced while the store is open. The store creates a
/// private directory or checks the existing one; it never repairs permissions
/// or adopts records with a missing/foreign format marker.
pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, name: []const u8, config: Config) !Self {
    if (builtin.os.tag != .linux) return error.UnsupportedRecoveryStore;
    if (name.len == 0 or std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..") or std.mem.indexOfAny(u8, name, "/\\\x00") != null) return error.InvalidRecoveryStorePath;
    if (config.record_bytes <= header_bytes or config.record_bytes > 64 * 1024 * 1024) return error.RecoveryRecordCapacity;
    parent.createDir(io, name, .fromMode(0o700)) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
    const directory = try parent.openDir(io, name, .{ .iterate = true, .follow_symlinks = false });
    errdefer directory.close(io);
    try private(try directory.stat(io), .directory);
    const owner = directory.createFile(io, ".owner", .{ .read = true, .truncate = false, .exclusive = true, .permissions = .fromMode(0o600) }) catch |err| switch (err) {
        error.PathAlreadyExists => try directory.openFile(io, ".owner", .{ .mode = .read_write, .follow_symlinks = false }),
        else => return err,
    };
    errdefer owner.close(io);
    try private(try owner.stat(io), .file);
    if (!try owner.tryLock(io, .exclusive)) return error.RecoveryStoreOwned;
    var format: [36]u8 = undefined;
    @memcpy(format[0..4], magic);
    @memcpy(format[4..], &definition());
    const marker = directory.openFile(io, ".format", .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (marker) |file| {
        defer file.close(io);
        try private(try file.stat(io), .file);
        var actual: [36]u8 = undefined;
        if (try file.length(io) != actual.len or try file.readPositionalAll(io, &actual, 0) != actual.len or !std.mem.eql(u8, &actual, &format)) return error.IncompatibleRecoveryStore;
    } else {
        var it = directory.iterate();
        while (try it.next(io)) |entry| if (!std.mem.eql(u8, entry.name, ".owner") and !temporary(entry.name)) return error.IncompatibleRecoveryStore;
        var staged = try directory.createFileAtomic(io, ".format", .{ .permissions = .fromMode(0o600) });
        defer staged.deinit(io);
        try staged.file.writeStreamingAll(io, &format);
        try staged.file.sync(io);
        try staged.link(io);
    }
    try syncDirectory(io, directory);
    // Parent may be an O_PATH handle; acquire a sync-capable directory handle.
    const parent_sync = try parent.openDir(io, ".", .{ .iterate = true });
    defer parent_sync.close(io);
    try syncDirectory(io, parent_sync);
    const buffer = try allocator.alloc(u8, config.record_bytes);
    return .{ .allocator = allocator, .io = io, .directory = directory, .owner = owner, .buffer = buffer };
}

/// Caller joins all users first. Close does not forget any recovery obligation.
pub fn deinit(self: *Self) void {
    std.crypto.secureZero(u8, self.buffer);
    self.allocator.free(self.buffer);
    self.owner.close(self.io);
    self.directory.close(self.io);
    self.* = undefined;
}

fn read(self: *Self, key: Key, output: []u8) !?Record {
    const file = self.directory.openFile(self.io, &fileName(key), .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(self.io);
    const stat = try file.stat(self.io);
    try private(stat, .file);
    if (stat.size < header_bytes) return error.InvalidRecoveryRecord;
    if (stat.size > self.buffer.len or stat.size > output.len) return error.RecoveryRecordCapacity;
    const bytes = output[0..@intCast(stat.size)];
    if (try file.readPositionalAll(self.io, bytes, 0) != bytes.len) return error.InvalidRecoveryRecord;
    if (!std.mem.eql(u8, bytes[0..4], magic) or !std.mem.eql(u8, bytes[4..36], &definition())) return error.IncompatibleRecoveryStore;
    if (!std.mem.eql(u8, bytes[36..68], &key)) return error.RecoveryKeyConflict;
    const revision = std.mem.readInt(u64, bytes[68..76], .little);
    const original: usize = std.mem.readInt(u32, bytes[76..80], .little);
    const evidence: usize = std.mem.readInt(u32, bytes[80..84], .little);
    if (revision == 0 or original == 0 or original > bytes.len - header_bytes or evidence != bytes.len - header_bytes - original) return error.InvalidRecoveryRecord;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(bytes[0..84]);
    hash.update(bytes[header_bytes..]);
    if (!std.mem.eql(u8, bytes[84..header_bytes], &hash.finalResult())) return error.InvalidRecoveryRecord;
    return .{ .key = key, .revision = revision, .original = bytes[header_bytes..][0..original], .evidence = bytes[header_bytes + original ..] };
}

/// Borrowed slices refer only to caller `output`, never to the store's scratch.
pub fn get(self: *Self, key: Key, output: []u8) !?Record {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    return self.read(key, output);
}

fn publish(self: *Self, record: Record, replace: bool) !void {
    if (record.original.len == 0 or record.original.len > self.buffer.len - header_bytes or record.evidence.len > self.buffer.len - header_bytes - record.original.len) return error.RecoveryRecordCapacity;
    var header: [header_bytes]u8 = undefined;
    @memcpy(header[0..4], magic);
    @memcpy(header[4..36], &definition());
    @memcpy(header[36..68], &record.key);
    std.mem.writeInt(u64, header[68..76], record.revision, .little);
    std.mem.writeInt(u32, header[76..80], @intCast(record.original.len), .little);
    std.mem.writeInt(u32, header[80..84], @intCast(record.evidence.len), .little);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(header[0..84]);
    hash.update(record.original);
    hash.update(record.evidence);
    @memcpy(header[84..], &hash.finalResult());
    var staged = try self.directory.createFileAtomic(self.io, &fileName(record.key), .{ .replace = replace, .permissions = .fromMode(0o600) });
    defer staged.deinit(self.io);
    try staged.file.writeStreamingAll(self.io, &header);
    try staged.file.writeStreamingAll(self.io, record.original);
    try staged.file.writeStreamingAll(self.io, record.evidence);
    try staged.file.sync(self.io);
    if (replace) try staged.replace(self.io) else try staged.link(self.io);
    try syncDirectory(self.io, self.directory);
}

/// Repeating identical preparation retains any later evidence and revision.
/// Any failure prevents dispatch, even if publication may have reached disk.
pub fn insert(self: *Self, key: Key, original: []const u8) !u64 {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    if (try self.read(key, self.buffer)) |record| {
        if (!std.mem.eql(u8, record.original, original)) return error.RecoveryKeyConflict;
        // A prior attempt may have failed during directory sync after rename.
        // Re-establish the durability barrier before reporting success.
        try syncDirectory(self.io, self.directory);
        return record.revision;
    }
    try self.publish(.{ .key = key, .revision = 1, .original = original, .evidence = &.{} }, false);
    return 1;
}

/// The domain adapter validates evidence. Compare-and-swap never changes frozen
/// work. Failure after rename leaves a complete old or new record, not rejection
/// of the remote operation whose outcome the caller already knows.
pub fn update(self: *Self, key: Key, expected: u64, evidence: []const u8) !u64 {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    var record = try self.read(key, self.buffer) orelse return error.RecoveryRecordMissing;
    if (record.revision != expected) return error.RecoveryRevisionConflict;
    if (std.mem.eql(u8, record.evidence, evidence)) {
        try syncDirectory(self.io, self.directory);
        return record.revision;
    }
    record.revision = std.math.add(u64, record.revision, 1) catch return error.RecoveryRevisionExhausted;
    record.evidence = evidence;
    try self.publish(record, true);
    return record.revision;
}

/// Explicit application retention decision; there is no TTL or quota eviction.
pub fn remove(self: *Self, key: Key, expected: u64, policy: enum { forget_original }) !void {
    _ = policy;
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const record = try self.read(key, self.buffer) orelse return error.RecoveryRecordMissing;
    if (record.revision != expected) return error.RecoveryRevisionConflict;
    try self.directory.deleteFile(self.io, &fileName(key));
    try syncDirectory(self.io, self.directory);
}

/// Lexicographic bounded paging; scans names without retaining a directory.
/// Each call holds the local owner lock. A multi-page walk is not a snapshot:
/// insertions before `after` require a later walk from null. Corrupt records are
/// still listed so recovery cannot silently skip them; `get` validates content.
pub fn listPage(self: *Self, after: ?Key, output: []Key) !Page {
    if (output.len == 0) return error.RecoveryPageCapacity;
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    var count: usize = 0;
    var more = false;
    var it = self.directory.iterate();
    while (try it.next(self.io)) |entry| {
        if (std.mem.eql(u8, entry.name, ".owner") or std.mem.eql(u8, entry.name, ".format") or temporary(entry.name)) continue;
        if (entry.kind != .file or entry.name.len != 68 or !std.mem.eql(u8, entry.name[64..], ".rec")) return error.InvalidRecoveryRecord;
        var key: Key = undefined;
        _ = std.fmt.hexToBytes(&key, entry.name[0..64]) catch return error.InvalidRecoveryRecord;
        if (!std.mem.eql(u8, &fileName(key), entry.name)) return error.InvalidRecoveryRecord;
        if (after) |previous| if (std.mem.order(u8, &key, &previous) != .gt) continue;
        var position: usize = 0;
        while (position < count and std.mem.order(u8, &output[position], &key) == .lt) : (position += 1) {}
        if (count == output.len) more = true;
        if (position == output.len) continue;
        const end = @min(count, output.len - 1);
        std.mem.copyBackwards(Key, output[position + 1 .. end + 1], output[position..end]);
        output[position] = key;
        count = @min(count + 1, output.len);
    }
    return .{ .count = count, .next = if (more) output[count - 1] else null };
}

test "private local recovery records preserve original work across reopen and CAS" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const key: Key = @splat(7);
    {
        var store = try Self.open(t.allocator, t.io, tmp.dir, "recovery", .{ .record_bytes = 512 });
        defer store.deinit();
        try t.expectError(error.RecoveryStoreOwned, Self.open(t.allocator, t.io, tmp.dir, "recovery", .{}));
        try t.expectEqual(1, try store.insert(key, "exact original bytes"));
        try t.expectError(error.RecoveryKeyConflict, store.insert(key, "replacement"));
        try t.expectEqual(2, try store.update(key, 1, "observed receipt"));
        try t.expectError(error.RecoveryRevisionConflict, store.update(key, 1, "stale writer"));
        try t.expectEqual(2, try store.insert(key, "exact original bytes"));
    }
    var reopened = try Self.open(t.allocator, t.io, tmp.dir, "recovery", .{ .record_bytes = 512 });
    defer reopened.deinit();
    var output: [512]u8 = undefined;
    const record = (try reopened.get(key, &output)).?;
    try t.expectEqual(2, record.revision);
    try t.expectEqualStrings("exact original bytes", record.original);
    try t.expectEqualStrings("observed receipt", record.evidence);
    try t.expectError(error.RecoveryRevisionConflict, reopened.remove(key, 1, .forget_original));
    try reopened.remove(key, 2, .forget_original);
    try t.expect(try reopened.get(key, &output) == null);
}

test "recovery enumeration exceeds the bounded page and allocates no directory" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var failing: t.FailingAllocator = .init(t.allocator, .{});
    var store = try Self.open(failing.allocator(), t.io, tmp.dir, "recovery", .{ .record_bytes = 512 });
    defer store.deinit();
    failing.fail_index = failing.alloc_index;
    for (0..31) |i| _ = try store.insert(@splat(@intCast(31 - i)), "frozen");
    var after: ?Key = null;
    var total: usize = 0;
    while (true) {
        var keys: [3]Key = undefined;
        const page = try store.listPage(after, &keys);
        for (keys[0..page.count]) |key| {
            total += 1;
            try t.expectEqual(@as(Key, @splat(@intCast(total))), key);
        }
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(31, total);
    try t.expect(!failing.has_induced_failure);
}

test "recovery rejects corrupt, oversize, and missing-definition artifacts" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const key: Key = @splat(9);
    {
        var store = try Self.open(t.allocator, t.io, tmp.dir, "recovery", .{ .record_bytes = 256 });
        defer store.deinit();
        try t.expectError(error.RecoveryRecordCapacity, store.insert(key, &(@as([256]u8, @splat(1)))));
        _ = try store.insert(key, "preserved");
        const file = try store.directory.openFile(t.io, &fileName(key), .{ .mode = .read_write });
        defer file.close(t.io);
        try file.writePositionalAll(t.io, "x", header_bytes);
        var output: [256]u8 = undefined;
        try t.expectError(error.InvalidRecoveryRecord, store.get(key, &output));
        try t.expectError(error.InvalidRecoveryRecord, store.insert(key, "preserved"));
        var keys: [1]Key = undefined;
        try t.expectEqual(1, (try store.listPage(null, &keys)).count);
        try store.directory.deleteFile(t.io, ".format");
    }
    try t.expectError(error.IncompatibleRecoveryStore, Self.open(t.allocator, t.io, tmp.dir, "recovery", .{}));
    try tmp.dir.createDir(t.io, "public", .fromMode(0o755));
    try t.expectError(error.RecoveryStorePermissions, Self.open(t.allocator, t.io, tmp.dir, "public", .{}));
}

test "failed record writes and syncs preserve complete original recovery material" {
    const t = std.testing;
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var mode: enum { none, disk_full, partial_write, cancelled_write, file_sync, rename, directory_sync } = .none;
        var syncs: usize = 0;
        var writes: usize = 0;
        fn operate(context: ?*anyopaque, operation: std.Io.Operation) std.Io.Cancelable!std.Io.Operation.Result {
            if (operation == .file_write_streaming) {
                writes += 1;
                if (writes == 2 and mode == .partial_write) return .{ .file_write_streaming = error.NoSpaceLeft };
                if (writes == 2 and mode == .cancelled_write) return error.Canceled;
            }
            return real.operate(context, operation);
        }
        fn create(context: ?*anyopaque, dir: std.Io.Dir, path: []const u8, options: std.Io.Dir.CreateFileAtomicOptions) std.Io.Dir.CreateFileAtomicError!std.Io.File.Atomic {
            if (mode == .disk_full) return error.NoSpaceLeft;
            return real.dirCreateFileAtomic(context, dir, path, options);
        }
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            syncs += 1;
            if ((mode == .file_sync and syncs == 1) or (mode == .directory_sync and syncs == 2)) return error.InputOutput;
            return real.fileSync(context, file);
        }
        fn rename(context: ?*anyopaque, from: std.Io.Dir, old: []const u8, to: std.Io.Dir, new: []const u8) std.Io.Dir.RenameError!void {
            if (mode == .rename) return error.AccessDenied;
            return real.dirRename(context, from, old, to, new);
        }
    };
    Fault.real = t.io.vtable;
    var table = t.io.vtable.*;
    table.dirCreateFileAtomic = Fault.create;
    table.operate = Fault.operate;
    table.fileSync = Fault.sync;
    table.dirRename = Fault.rename;
    var io = t.io;
    io.vtable = &table;
    defer Fault.mode = .none;
    for (std.enums.values(@TypeOf(Fault.mode))) |mode| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        const key: Key = @splat(12);
        {
            Fault.mode = .none;
            var store = try Self.open(t.allocator, io, tmp.dir, "recovery", .{ .record_bytes = 256 });
            defer store.deinit();
            _ = try store.insert(key, "original");
            Fault.mode = mode;
            Fault.syncs = 0;
            Fault.writes = 0;
            const result = store.update(key, 1, "known commitment");
            switch (mode) {
                .none => try t.expectEqual(2, try result),
                .disk_full, .partial_write => try t.expectError(error.NoSpaceLeft, result),
                .cancelled_write => try t.expectError(error.Canceled, result),
                .file_sync, .directory_sync => try t.expectError(error.InputOutput, result),
                .rename => try t.expectError(error.AccessDenied, result),
            }
        }
        Fault.mode = .none;
        var reopened = try Self.open(t.allocator, io, tmp.dir, "recovery", .{ .record_bytes = 256 });
        defer reopened.deinit();
        var bytes: [256]u8 = undefined;
        const record = (try reopened.get(key, &bytes)).?;
        try t.expectEqualStrings("original", record.original);
        const published = mode == .none or mode == .directory_sync;
        try t.expectEqual(@as(u64, if (published) 2 else 1), record.revision);
        try t.expectEqualStrings(if (published) "known commitment" else "", record.evidence);
    }
}
