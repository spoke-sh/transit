//! Per-key conditional publication of immutable disk content. Readers capture
//! one descriptor and verify only the requested 64 KiB chunks. No object cache.
const std = @import("std");
const p = @import("transit_protocol");
const object = @import("TransitObjectStore.zig");
const Self = @This();
pub const chunk_bytes = 64 * 1024;
const checks_bytes = (object.max_object_bytes / chunk_bytes) * 32;
const Kind = enum(u8) { immutable = 1, conditional = 2 };
const Record = struct { kind: Kind, meta: object.ObjectMeta, checks: [32]u8 };

allocator: std.mem.Allocator,
io: std.Io,
dir: std.Io.Dir,

fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
fn digest(bytes: []const u8) [32]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return hash;
}
fn sync(io: std.Io, dir: std.Io.Dir) !void {
    const opened = try dir.openDir(io, ".", .{ .iterate = true });
    defer opened.close(io);
    const file: std.Io.File = .{ .handle = opened.handle, .flags = .{ .nonblocking = false } };
    try file.sync(io);
}
fn publish(io: std.Io, dir: std.Io.Dir, path: []const u8, bytes: []const u8, replace: bool) !void {
    var temporary = try dir.createFileAtomic(io, path, .{ .replace = replace, .permissions = .fromMode(0o600) });
    defer temporary.deinit(io);
    try temporary.file.writeStreamingAll(io, bytes);
    try temporary.file.sync(io);
    if (replace) try temporary.replace(io) else try temporary.link(io);
    try sync(io, dir);
}

pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, path: []const u8) !Self {
    try parent.createDirPath(io, path);
    var ancestor = std.fs.path.dirname(path);
    while (ancestor) |name| {
        const directory = try parent.openDir(io, name, .{});
        defer directory.close(io);
        try sync(io, directory);
        const next = std.fs.path.dirname(name);
        if (next != null and std.mem.eql(u8, name, next.?)) break;
        ancestor = next;
    }
    try sync(io, parent);
    const dir = try parent.openDir(io, path, .{ .iterate = true });
    errdefer dir.close(io);
    const lock = try dir.createFile(io, ".initialize", .{ .read = true, .truncate = false, .permissions = .fromMode(0o600) });
    defer lock.close(io);
    try lock.lock(io, .exclusive);
    const marker = dir.openFile(io, ".definition", .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (marker) |file| {
        defer file.close(io);
        var bytes: [32]u8 = undefined;
        if (try file.length(io) != bytes.len or try file.readPositionalAll(io, &bytes, 0) != bytes.len or !std.mem.eql(u8, &bytes, &definition())) return error.IncompatibleDefinition;
    } else {
        var it = dir.iterate();
        while (try it.next(io)) |entry| if (!std.mem.eql(u8, entry.name, ".initialize")) return error.IncompatibleDefinition;
        try publish(io, dir, ".definition", &definition(), false);
    }
    for ([_][]const u8{ "keys", "objects", "locks" }) |name| try dir.createDirPath(io, name);
    try sync(io, dir);
    return .{ .allocator = allocator, .io = io, .dir = dir };
}
pub fn deinit(self: *Self) void {
    self.dir.close(self.io);
    self.* = undefined;
}
fn keyName(key: []const u8) [64]u8 {
    return std.fmt.bytesToHex(digest(key), .lower);
}
fn lockKey(self: *Self, key: []const u8) !std.Io.File {
    var directory = try self.dir.openDir(self.io, "locks", .{});
    defer directory.close(self.io);
    const file = try directory.createFile(self.io, &keyName(key), .{ .read = true, .truncate = false, .permissions = .fromMode(0o600) });
    errdefer file.close(self.io);
    try file.lock(self.io, .exclusive);
    return file;
}
fn contentName(key: []const u8, hash: [32]u8, checks: bool, bytes: *[144]u8) []const u8 {
    const suffix: []const u8 = if (checks) "checks" else if (std.mem.endsWith(u8, key, ".tseg")) "tseg" else if (std.mem.endsWith(u8, key, ".tdel")) "tdel" else if (std.mem.endsWith(u8, key, ".tman")) "tman" else "data";
    return std.fmt.bufPrint(bytes, "{s}-{s}.{s}", .{ keyName(key), std.fmt.bytesToHex(hash, .lower), suffix }) catch unreachable;
}
fn readRecord(self: *Self, key: []const u8) !?Record {
    var directory = try self.dir.openDir(self.io, "keys", .{});
    defer directory.close(self.io);
    const file = directory.openFile(self.io, &keyName(key), .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(self.io);
    var bytes: [512]u8 = undefined;
    if (try file.length(self.io) != bytes.len or try file.readPositionalAll(self.io, &bytes, 0) != bytes.len) return error.CorruptObjectDescriptor;
    if (!std.mem.eql(u8, bytes[8..40], &definition())) return error.IncompatibleDefinition;
    if (!std.mem.eql(u8, bytes[0..8], "TOBJ\x01\x00\x00\x00") or !std.mem.eql(u8, bytes[480..512], &digest(bytes[0..480]))) return error.CorruptObjectDescriptor;
    const kind = std.enums.fromInt(Kind, bytes[40]) orelse return error.CorruptObjectDescriptor;
    const length = std.mem.readInt(u16, bytes[41..43], .little);
    if (length != key.len or !std.mem.eql(u8, bytes[120..][0..length], key)) return error.ObjectKeyConflict;
    for (bytes[43..48]) |byte| if (byte != 0) return error.CorruptObjectDescriptor;
    for (bytes[120 + length .. 480]) |byte| if (byte != 0) return error.CorruptObjectDescriptor;
    const result: Record = .{ .kind = kind, .meta = .{ .size = std.mem.readInt(u64, bytes[48..56], .little), .sha256 = bytes[56..88].* }, .checks = bytes[88..120].* };
    if (result.meta.size > object.max_object_bytes) return error.ObjectTooLarge;
    return result;
}
fn saveRecord(self: *Self, key: []const u8, record: Record) !void {
    var bytes: [512]u8 = @splat(0);
    bytes[0..8].* = "TOBJ\x01\x00\x00\x00".*;
    bytes[8..40].* = definition();
    bytes[40] = @backingInt(record.kind);
    std.mem.writeInt(u16, bytes[41..43], @intCast(key.len), .little);
    std.mem.writeInt(u64, bytes[48..56], record.meta.size, .little);
    bytes[56..88].* = record.meta.sha256;
    bytes[88..120].* = record.checks;
    @memcpy(bytes[120..][0..key.len], key);
    bytes[480..512].* = digest(bytes[0..480]);
    var directory = try self.dir.openDir(self.io, "keys", .{ .iterate = true });
    defer directory.close(self.io);
    try publish(self.io, directory, &keyName(key), &bytes, true);
}
fn verify(file: std.Io.File, io: std.Io, bytes: []const u8) !void {
    if (try file.length(io) != bytes.len) return error.ObjectDigestMismatch;
    var scratch: [chunk_bytes]u8 = undefined;
    var position: usize = 0;
    while (position < bytes.len) {
        const part = scratch[0..@min(scratch.len, bytes.len - position)];
        if (try file.readPositionalAll(io, part, position) != part.len or !std.mem.eql(u8, part, bytes[position..][0..part.len])) return error.ObjectDigestMismatch;
        position += part.len;
    }
}
fn content(self: *Self, directory: std.Io.Dir, filename: []const u8, bytes: []const u8) !void {
    publish(self.io, directory, filename, bytes, false) catch |err| switch (err) {
        error.PathAlreadyExists => {
            const file = try directory.openFile(self.io, filename, .{ .follow_symlinks = false });
            defer file.close(self.io);
            try verify(file, self.io, bytes);
            // A retry can meet an earlier uncertain link. Establish durability
            // of that same content before publishing a new descriptor.
            try file.sync(self.io);
            try sync(self.io, directory);
        },
        else => return err,
    };
}
fn stage(self: *Self, key: []const u8, bytes: []const u8, kind: Kind) !Record {
    var chunks: [checks_bytes]u8 = undefined;
    const count = std.math.divCeil(usize, bytes.len, chunk_bytes) catch unreachable;
    for (0..count) |i| {
        const start = i * chunk_bytes;
        chunks[i * 32 ..][0..32].* = digest(bytes[start..@min(start + chunk_bytes, bytes.len)]);
    }
    const checks = chunks[0 .. count * 32];
    const record: Record = .{ .kind = kind, .meta = .{ .size = bytes.len, .sha256 = digest(bytes) }, .checks = digest(checks) };
    var directory = try self.dir.openDir(self.io, "objects", .{ .iterate = true });
    defer directory.close(self.io);
    var filename: [144]u8 = undefined;
    try self.content(directory, contentName(key, record.meta.sha256, false, &filename), bytes);
    try self.content(directory, contentName(key, record.meta.sha256, true, &filename), checks);
    return record;
}
pub fn putImmutable(self: *Self, key: []const u8, bytes: []const u8, expected: [32]u8) !object.ObjectMeta {
    try object.validateKey(key);
    if (bytes.len > object.max_object_bytes) return error.ObjectTooLarge;
    if (!std.mem.eql(u8, &digest(bytes), &expected)) return error.ObjectDigestMismatch;
    const lock = try self.lockKey(key);
    defer lock.close(self.io);
    if (try self.readRecord(key)) |existing| {
        if (existing.kind != .immutable or existing.meta.size != bytes.len or !std.mem.eql(u8, &existing.meta.sha256, &expected)) return error.ImmutableObjectConflict;
    }
    const staged = try self.stage(key, bytes, .immutable);
    try self.saveRecord(key, staged);
    return staged.meta;
}
pub fn putConditional(self: *Self, key: []const u8, condition: object.Condition, bytes: []const u8) !bool {
    try object.validateKey(key);
    if (bytes.len > object.max_object_bytes) return error.ObjectTooLarge;
    const lock = try self.lockKey(key);
    defer lock.close(self.io);
    const previous = try self.readRecord(key);
    if (previous) |record| if (record.kind != .conditional) return error.ImmutableObjectConflict;
    switch (condition) {
        .if_none_match => if (previous != null) return false,
        .if_match => |expected| if (previous == null or !std.mem.eql(u8, &expected, &previous.?.meta.sha256)) return false,
    }
    const staged = try self.stage(key, bytes, .conditional);
    try self.saveRecord(key, staged);
    return true;
}
pub fn head(self: *Self, key: []const u8) !?object.ObjectMeta {
    try object.validateKey(key);
    const record = (try self.readRecord(key)) orelse return null;
    return record.meta;
}
pub fn read(self: *Self, key: []const u8, offset: u64, length: u32, out: []u8) ![]const u8 {
    try object.validateKey(key);
    if (out.len < length) return error.BufferTooSmall;
    const record = (try self.readRecord(key)) orelse return error.ObjectNotFound;
    if (offset > record.meta.size) return error.RangeOutOfBounds;
    const wanted: usize = @intCast(@min(length, record.meta.size - offset));
    var directory = try self.dir.openDir(self.io, "objects", .{});
    defer directory.close(self.io);
    var filename: [144]u8 = undefined;
    const hashes = try directory.openFile(self.io, contentName(key, record.meta.sha256, true, &filename), .{ .follow_symlinks = false });
    defer hashes.close(self.io);
    var checks: [checks_bytes]u8 = undefined;
    const count: usize = @intCast(std.math.divCeil(u64, record.meta.size, chunk_bytes) catch unreachable);
    const checked = checks[0 .. count * 32];
    if (try hashes.length(self.io) != checked.len or try hashes.readPositionalAll(self.io, checked, 0) != checked.len or !std.mem.eql(u8, &digest(checked), &record.checks)) return error.ObjectDigestMismatch;
    const file = try directory.openFile(self.io, contentName(key, record.meta.sha256, false, &filename), .{ .follow_symlinks = false });
    defer file.close(self.io);
    if (try file.length(self.io) != record.meta.size) return error.ObjectDigestMismatch;
    var scratch: [chunk_bytes]u8 = undefined;
    var copied: usize = 0;
    while (copied < wanted) {
        const at: usize = @intCast(offset + copied);
        const index = at / chunk_bytes;
        const start = index * chunk_bytes;
        const part = scratch[0..@intCast(@min(chunk_bytes, record.meta.size - start))];
        if (try file.readPositionalAll(self.io, part, start) != part.len or !std.mem.eql(u8, &digest(part), checks[index * 32 ..][0..32])) return error.ObjectDigestMismatch;
        const within = at - start;
        const take = @min(wanted - copied, part.len - within);
        @memcpy(out[copied..][0..take], part[within..][0..take]);
        copied += take;
    }
    return out[0..wanted];
}
pub fn delete(self: *Self, key: []const u8) !void {
    try object.validateKey(key);
    const lock = try self.lockKey(key);
    defer lock.close(self.io);
    var directory = try self.dir.openDir(self.io, "keys", .{ .iterate = true });
    defer directory.close(self.io);
    directory.deleteFile(self.io, &keyName(key)) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    try sync(self.io, directory);
    // Content and checks remain immutable. Removing their last descriptor does
    // not prove that a captured reader or retained snapshot has released them.
}

/// Physical primitive for an exclusive retained-root owner. The caller must
/// fence recreation and prove that no current/history/pin/in-flight reader owns
/// this exact immutable object. Generic ObjectStore.delete cannot prove that.
/// An allocation intent supplies the identity even if publication never finished.
pub fn reclaimImmutable(self: *Self, key: []const u8, expected: object.ObjectMeta) !u64 {
    try object.validateKey(key);
    if (expected.size > object.max_object_bytes) return error.ObjectTooLarge;
    const lock = try self.lockKey(key);
    defer lock.close(self.io);
    if (try self.readRecord(key)) |record| {
        if (record.kind != .immutable or !std.meta.eql(record.meta, expected)) return error.ImmutableObjectConflict;
    }
    var keys = try self.dir.openDir(self.io, "keys", .{ .iterate = true });
    defer keys.close(self.io);
    var removed = try removeFile(self.io, keys, &keyName(key));
    // Revoke discovery durably before removing the bytes it described.
    try sync(self.io, keys);
    var objects = try self.dir.openDir(self.io, "objects", .{ .iterate = true });
    defer objects.close(self.io);
    var filename: [144]u8 = undefined;
    removed += try removeFile(self.io, objects, contentName(key, expected.sha256, false, &filename));
    removed += try removeFile(self.io, objects, contentName(key, expected.sha256, true, &filename));
    try sync(self.io, objects);
    return removed;
}

fn removeFile(io: std.Io, directory: std.Io.Dir, name: []const u8) !u64 {
    const file = directory.openFile(io, name, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    defer file.close(io);
    const size = try file.length(io);
    try directory.deleteFile(io, name);
    return size;
}
