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
keys_dir: std.Io.Dir,
objects_dir: std.Io.Dir,
locks_dir: std.Io.Dir,

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
fn syncIterated(io: std.Io, dir: std.Io.Dir) !void {
    const file: std.Io.File = .{ .handle = dir.handle, .flags = .{ .nonblocking = false } };
    try file.sync(io);
}
// Sync bytes and link/replace the name. The caller must sync the containing
// directory before depending on its persistence or acknowledging publication.
fn publishName(io: std.Io, dir: std.Io.Dir, path: []const u8, bytes: []const u8, replace: bool) !void {
    var temporary = try dir.createFileAtomic(io, path, .{ .replace = replace, .permissions = .fromMode(0o600) });
    defer temporary.deinit(io);
    try temporary.file.writeStreamingAll(io, bytes);
    try temporary.file.sync(io);
    if (replace) try temporary.replace(io) else try temporary.link(io);
}
fn publish(io: std.Io, dir: std.Io.Dir, path: []const u8, bytes: []const u8, replace: bool) !void {
    try publishName(io, dir, path, bytes, replace);
    try syncIterated(io, dir);
}

pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, path: []const u8) !Self {
    try parent.createDirPath(io, path);
    var ancestor = std.fs.path.dirname(path);
    while (ancestor) |name| {
        const directory = try parent.openDir(io, name, .{ .iterate = true });
        defer directory.close(io);
        try syncIterated(io, directory);
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
    try syncIterated(io, dir);
    const keys_dir = try dir.openDir(io, "keys", .{ .iterate = true });
    errdefer keys_dir.close(io);
    const objects_dir = try dir.openDir(io, "objects", .{ .iterate = true });
    errdefer objects_dir.close(io);
    const locks_dir = try dir.openDir(io, "locks", .{ .iterate = true });
    errdefer locks_dir.close(io);
    return .{ .allocator = allocator, .io = io, .dir = dir, .keys_dir = keys_dir, .objects_dir = objects_dir, .locks_dir = locks_dir };
}
pub fn deinit(self: *Self) void {
    self.locks_dir.close(self.io);
    self.objects_dir.close(self.io);
    self.keys_dir.close(self.io);
    self.dir.close(self.io);
    self.* = undefined;
}
fn keyName(key: []const u8) [64]u8 {
    return std.fmt.bytesToHex(digest(key), .lower);
}
fn lockKey(self: *Self, key: []const u8) !std.Io.File {
    const file = try self.locks_dir.createFile(self.io, &keyName(key), .{ .read = true, .truncate = false, .permissions = .fromMode(0o600) });
    errdefer file.close(self.io);
    try file.lock(self.io, .exclusive);
    return file;
}
fn contentName(key: []const u8, hash: [32]u8, checks: bool, bytes: *[144]u8) []const u8 {
    const suffix: []const u8 = if (checks) "checks" else if (std.mem.endsWith(u8, key, ".tseg")) "tseg" else if (std.mem.endsWith(u8, key, ".tdel")) "tdel" else if (std.mem.endsWith(u8, key, ".tman")) "tman" else "data";
    return std.fmt.bufPrint(bytes, "{s}-{s}.{s}", .{ keyName(key), std.fmt.bytesToHex(hash, .lower), suffix }) catch unreachable;
}
fn readRecord(self: *Self, key: []const u8) !?Record {
    const file = self.keys_dir.openFile(self.io, &keyName(key), .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(self.io);
    var raw: [513]u8 = undefined;
    if (try file.readPositionalAll(self.io, &raw, 0) != 512) return error.CorruptObjectDescriptor;
    const bytes = raw[0..512];
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
const StagedRecord = struct {
    name: [64]u8,
    atomic: std.Io.File.Atomic,

    fn deinit(self: *StagedRecord, io: std.Io) void {
        self.atomic.deinit(io);
    }
};
fn prepareRecordName(self: *Self, key: []const u8, record: Record, out: *StagedRecord) !void {
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
    out.name = keyName(key);
    out.atomic = try self.keys_dir.createFileAtomic(self.io, &out.name, .{ .replace = true, .permissions = .fromMode(0o600) });
    errdefer out.atomic.deinit(self.io);
    try out.atomic.file.writeStreamingAll(self.io, &bytes);
}
fn publishRecordName(self: *Self, staged: *StagedRecord) !void {
    try staged.atomic.file.sync(self.io);
    try staged.atomic.replace(self.io);
}
fn saveRecordName(self: *Self, key: []const u8, record: Record) !void {
    var staged: StagedRecord = undefined;
    try self.prepareRecordName(key, record, &staged);
    defer staged.deinit(self.io);
    try self.publishRecordName(&staged);
}
fn saveRecord(self: *Self, key: []const u8, record: Record) !void {
    try self.saveRecordName(key, record);
    try syncIterated(self.io, self.keys_dir);
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
inline fn needsChecksFile(size: u64) bool {
    return size > chunk_bytes;
}
const StagedContent = struct {
    record: Record,
    data_name: [144]u8,
    data_name_len: usize,
    checks_name: [144]u8,
    checks_name_len: usize,
    data_file: std.Io.File.Atomic,
    checks_file: ?std.Io.File.Atomic,

    fn deinit(self: *StagedContent, io: std.Io) void {
        if (self.checks_file) |*file| file.deinit(io);
        self.data_file.deinit(io);
    }
};
fn prepareContent(self: *Self, key: []const u8, bytes: []const u8, kind: Kind, out: *StagedContent) !void {
    var chunks: [checks_bytes]u8 = undefined;
    const count = std.math.divCeil(usize, bytes.len, chunk_bytes) catch unreachable;
    for (0..count) |i| {
        const start = i * chunk_bytes;
        chunks[i * 32 ..][0..32].* = digest(bytes[start..@min(start + chunk_bytes, bytes.len)]);
    }
    const checks = chunks[0 .. count * 32];
    out.record = .{
        .kind = kind,
        .meta = .{ .size = bytes.len, .sha256 = if (count == 1) chunks[0..32].* else digest(bytes) },
        .checks = digest(checks),
    };
    const data_slice = contentName(key, out.record.meta.sha256, false, &out.data_name);
    out.data_name_len = data_slice.len;
    out.data_file = try self.objects_dir.createFileAtomic(self.io, data_slice, .{ .replace = false, .permissions = .fromMode(0o600) });
    errdefer out.data_file.deinit(self.io);
    try out.data_file.file.writeStreamingAll(self.io, bytes);
    if (needsChecksFile(bytes.len)) {
        const checks_slice = contentName(key, out.record.meta.sha256, true, &out.checks_name);
        out.checks_name_len = checks_slice.len;
        var checks_file = try self.objects_dir.createFileAtomic(self.io, checks_slice, .{ .replace = false, .permissions = .fromMode(0o600) });
        errdefer checks_file.deinit(self.io);
        try checks_file.file.writeStreamingAll(self.io, checks);
        out.checks_file = checks_file;
    } else {
        out.checks_name_len = 0;
        out.checks_file = null;
    }
}
fn publishContentFile(self: *Self, temporary: *std.Io.File.Atomic, filename: []const u8, bytes: []const u8, is_checks: bool) !void {
    try temporary.file.sync(self.io);
    try self.linkContentFile(temporary, filename, bytes, is_checks);
}
fn linkContentFile(self: *Self, temporary: *std.Io.File.Atomic, filename: []const u8, bytes: []const u8, is_checks: bool) !void {
    temporary.link(self.io) catch |err| switch (err) {
        error.PathAlreadyExists => {
            const file = try self.objects_dir.openFile(self.io, filename, .{ .follow_symlinks = false });
            defer file.close(self.io);
            if (is_checks) {
                var chunks: [checks_bytes]u8 = undefined;
                const count = std.math.divCeil(usize, bytes.len, chunk_bytes) catch unreachable;
                for (0..count) |i| {
                    const start = i * chunk_bytes;
                    chunks[i * 32 ..][0..32].* = digest(bytes[start..@min(start + chunk_bytes, bytes.len)]);
                }
                try verify(file, self.io, chunks[0 .. count * 32]);
            } else {
                try verify(file, self.io, bytes);
            }
            // A retry can meet an earlier uncertain link. Establish durability
            // of that same content before publishing a new descriptor.
            try file.sync(self.io);
        },
        else => return err,
    };
}
fn publishStagedContent(self: *Self, bytes: []const u8, staged: *StagedContent) !void {
    try self.publishContentFile(&staged.data_file, staged.data_name[0..staged.data_name_len], bytes, false);
    if (staged.checks_file) |*checks_file| {
        try self.publishContentFile(checks_file, staged.checks_name[0..staged.checks_name_len], bytes, true);
    }
}
fn stageContent(self: *Self, key: []const u8, bytes: []const u8, kind: Kind) !Record {
    var staged: StagedContent = undefined;
    try self.prepareContent(key, bytes, kind, &staged);
    defer staged.deinit(self.io);
    try self.publishStagedContent(bytes, &staged);
    return staged.record;
}
fn stage(self: *Self, key: []const u8, bytes: []const u8, kind: Kind) !Record {
    const record = try self.stageContent(key, bytes, kind);
    // Both files have durable bytes and final names in this same directory.
    // One directory barrier covers the pair, including observed names on exact
    // retry. No descriptor may become visible before this barrier succeeds.
    try syncIterated(self.io, self.objects_dir);
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

/// Hold all per-key locks in canonical lock-name order until the shared final
/// barrier. Each descriptor depends on already durable content; partial failure
/// may expose a subset but never a descriptor whose dependencies are unsynced.
pub fn putImmutableBatch(self: *Self, batch: []const object.ImmutablePut, output: []object.ObjectMeta) !void {
    try object.validateBatch(batch, output);
    const Ordered = struct {
        index: usize,
        name: [64]u8,
        fn less(_: void, a: @This(), b: @This()) bool {
            return std.mem.order(u8, &a.name, &b.name) == .lt;
        }
    };
    var order: [object.max_put_batch]Ordered = undefined;
    for (batch, order[0..batch.len], 0..) |item, *entry, i| entry.* = .{ .index = i, .name = keyName(item.key) };
    std.mem.sort(Ordered, order[0..batch.len], {}, Ordered.less);
    for (1..batch.len) |i| if (std.mem.eql(u8, &order[i - 1].name, &order[i].name)) return error.ObjectKeyConflict;
    var locks: [object.max_put_batch]std.Io.File = undefined;
    var locked: usize = 0;
    defer for (locks[0..locked]) |lock| lock.close(self.io);
    for (order[0..batch.len]) |entry| {
        locks[locked] = try self.lockKey(batch[entry.index].key);
        locked += 1;
    }
    // Reject known conflicts before creating any of this group's content.
    for (batch) |item| if (try self.readRecord(item.key)) |existing| {
        if (existing.kind != .immutable or existing.meta.size != item.bytes.len or !std.mem.eql(u8, &existing.meta.sha256, &item.sha256)) return error.ImmutableObjectConflict;
    };
    var staged_content: [object.max_put_batch]StagedContent = undefined;
    var staged_count: usize = 0;
    defer for (staged_content[0..staged_count]) |*item| item.deinit(self.io);
    for (batch) |item| {
        try self.prepareContent(item.key, item.bytes, .immutable, &staged_content[staged_count]);
        staged_count += 1;
    }
    var files: [object.max_put_batch * 2]std.Io.File = undefined;
    var file_count: usize = 0;
    for (staged_content[0..staged_count]) |staged| {
        files[file_count] = staged.data_file.file;
        file_count += 1;
        if (staged.checks_file) |checks| {
            files[file_count] = checks.file;
            file_count += 1;
        }
    }
    try @import("SyncBatch.zig").sync(self.io, files[0..file_count]);
    for (batch, staged_content[0..staged_count]) |item, *staged| {
        try self.linkContentFile(&staged.data_file, staged.data_name[0..staged.data_name_len], item.bytes, false);
        if (staged.checks_file) |*checks| try self.linkContentFile(checks, staged.checks_name[0..staged.checks_name_len], item.bytes, true);
    }
    try syncIterated(self.io, self.objects_dir);
    var staged_records: [object.max_put_batch]StagedRecord = undefined;
    var record_count: usize = 0;
    defer for (staged_records[0..record_count]) |*item| item.deinit(self.io);
    for (batch, staged_content[0..staged_count]) |item, staged| {
        try self.prepareRecordName(item.key, staged.record, &staged_records[record_count]);
        record_count += 1;
    }
    for (staged_records[0..record_count], files[0..record_count]) |record_file, *file| file.* = record_file.atomic.file;
    try @import("SyncBatch.zig").sync(self.io, files[0..record_count]);
    for (staged_records[0..record_count]) |*record_file| try record_file.atomic.replace(self.io);
    try syncIterated(self.io, self.keys_dir);
    for (output, staged_content[0..staged_count]) |*meta, staged| meta.* = staged.record.meta;
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
    return self.readContent(key, record, offset, length, out);
}
pub fn getObject(self: *Self, key: []const u8, out: []u8) !?object.ObjectMeta {
    try object.validateKey(key);
    const record = (try self.readRecord(key)) orelse return null;
    if (record.meta.size > out.len) return error.BufferTooSmall;
    _ = try self.readContent(key, record, 0, @intCast(record.meta.size), out);
    return record.meta;
}
fn readContent(self: *Self, key: []const u8, record: Record, offset: u64, length: u32, out: []u8) ![]const u8 {
    if (offset > record.meta.size) return error.RangeOutOfBounds;
    const wanted: usize = @intCast(@min(length, record.meta.size - offset));
    var filename: [144]u8 = undefined;
    var checks: [checks_bytes]u8 = undefined;
    const count: usize = @intCast(std.math.divCeil(u64, record.meta.size, chunk_bytes) catch unreachable);
    const checked = checks[0 .. count * 32];
    if (needsChecksFile(record.meta.size)) {
        const hashes = try self.objects_dir.openFile(self.io, contentName(key, record.meta.sha256, true, &filename), .{ .follow_symlinks = false });
        defer hashes.close(self.io);
        if (try hashes.length(self.io) != checked.len or try hashes.readPositionalAll(self.io, checked, 0) != checked.len or !std.mem.eql(u8, &digest(checked), &record.checks)) return error.ObjectDigestMismatch;
    } else {
        if (count == 1) checks[0..32].* = record.meta.sha256;
        if (!std.mem.eql(u8, &digest(checked), &record.checks)) return error.ObjectDigestMismatch;
    }
    const file = try self.objects_dir.openFile(self.io, contentName(key, record.meta.sha256, false, &filename), .{ .follow_symlinks = false });
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
    self.keys_dir.deleteFile(self.io, &keyName(key)) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    try syncIterated(self.io, self.keys_dir);
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
    var removed = try removeFile(self.io, self.keys_dir, &keyName(key));
    // Revoke discovery durably before removing the bytes it described.
    try syncIterated(self.io, self.keys_dir);
    var filename: [144]u8 = undefined;
    removed += try removeFile(self.io, self.objects_dir, contentName(key, expected.sha256, false, &filename));
    removed += try removeFile(self.io, self.objects_dir, contentName(key, expected.sha256, true, &filename));
    try syncIterated(self.io, self.objects_dir);
    return removed;
}

/// Verify and establish durability of an observed immutable publication without
/// repeating creation. Readable files after a crash are not a directory barrier.
pub fn confirmImmutable(self: *Self, key: []const u8, expected: object.ObjectMeta) !void {
    try object.validateKey(key);
    const lock = try self.lockKey(key);
    defer lock.close(self.io);
    const record = (try self.readRecord(key)) orelse return error.ObjectNotFound;
    if (record.kind != .immutable or !std.meta.eql(record.meta, expected)) return error.ImmutableObjectConflict;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var bytes: [chunk_bytes]u8 = undefined;
    var offset: u64 = 0;
    if (expected.size == 0) _ = try self.read(key, 0, 0, &bytes);
    while (offset < expected.size) {
        const wanted: u32 = @intCast(@min(bytes.len, expected.size - offset));
        const part = try self.read(key, offset, wanted, &bytes);
        if (part.len != wanted) return error.ObjectDigestMismatch;
        hash.update(part);
        offset += wanted;
    }
    if (!std.mem.eql(u8, &hash.finalResult(), &expected.sha256)) return error.ObjectDigestMismatch;
    var name: [144]u8 = undefined;
    const data_file = try self.objects_dir.openFile(self.io, contentName(key, expected.sha256, false, &name), .{ .follow_symlinks = false });
    defer data_file.close(self.io);
    try data_file.sync(self.io);
    if (needsChecksFile(expected.size)) {
        const checks_file = try self.objects_dir.openFile(self.io, contentName(key, expected.sha256, true, &name), .{ .follow_symlinks = false });
        defer checks_file.close(self.io);
        try checks_file.sync(self.io);
    }
    try syncIterated(self.io, self.objects_dir);
    const descriptor = try self.keys_dir.openFile(self.io, &keyName(key), .{ .follow_symlinks = false });
    defer descriptor.close(self.io);
    try descriptor.sync(self.io);
    try syncIterated(self.io, self.keys_dir);
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
