//! Disposable, bounded whole-object disk cache. Every hit is checked against the
//! caller's retained content identity, never a digest learned from the cache.
const std = @import("std");
const object = @import("TransitObjectStore.zig");
const p = @import("transit_protocol");
const Self = @This();
const Entry = struct { key: [32]u8, meta: object.ObjectMeta, referenced: bool };
allocator: std.mem.Allocator,
io: std.Io,
directory: std.Io.Dir,
entries: []?Entry,
capacity: u64,
used: u64 = 0,
hand: usize = 0,
hits: u64 = 0,
misses: u64 = 0,
evictions: u64 = 0,
corruptions: u64 = 0,

fn hash(bytes: []const u8) [32]u8 {
    var out: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &out, .{});
    return out;
}
fn filename(index: usize, out: *[24]u8) []const u8 {
    return std.fmt.bufPrint(out, "{x:0>8}.cache", .{index}) catch unreachable;
}
/// The caller serializes accesses. Reopen starts cold and bounds its inventory
/// independently of retained authority data. This directory is never staging.
pub fn open(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, path: []const u8, capacity: u64) !Self {
    if (capacity < object.max_object_bytes or capacity > 4 * 1024 * 1024 * 1024) return error.InvalidCacheBudget;
    try parent.createDirPath(io, path);
    const directory = try parent.openDir(io, path, .{ .iterate = true });
    errdefer directory.close(io);
    const marker = directory.openFile(io, ".cache-owner", .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (marker) |file| {
        defer file.close(io);
        var raw: [40]u8 = undefined;
        if (try file.length(io) != raw.len or try file.readPositionalAll(io, &raw, 0) != raw.len or
            !std.mem.eql(u8, raw[0..8], "TCACHE1\x00") or !std.mem.eql(u8, raw[8..40], &p.Growth.definition_bytes)) return error.IncompatibleCache;
    } else {
        var it = directory.iterate();
        if (try it.next(io) != null) return error.UnownedCache;
        var raw: [40]u8 = undefined;
        raw[0..8].* = "TCACHE1\x00".*;
        raw[8..40].* = p.Growth.definition_bytes;
        try directory.writeFile(io, .{ .sub_path = ".cache-owner", .data = &raw, .flags = .{ .exclusive = true, .permissions = .fromMode(0o600) } });
    }
    var it = directory.iterate();
    while (try it.next(io)) |entry| {
        if (std.mem.eql(u8, entry.name, ".cache-owner")) continue;
        if (entry.kind != .file or entry.name.len != 14 or !std.mem.endsWith(u8, entry.name, ".cache")) return error.UnownedCache;
        const index = std.fmt.parseInt(usize, entry.name[0..8], 16) catch return error.UnownedCache;
        if (index >= 4096) return error.UnownedCache;
        try directory.deleteFile(io, entry.name);
    }
    const entries = try allocator.alloc(?Entry, @intCast(@min(4096, capacity / (64 * 1024))));
    @memset(entries, null);
    return .{ .allocator = allocator, .io = io, .directory = directory, .entries = entries, .capacity = capacity };
}
pub fn deinit(self: *Self) void {
    self.allocator.free(self.entries);
    self.directory.close(self.io);
    self.* = undefined;
}
fn remove(self: *Self, index: usize) !void {
    const entry = self.entries[index] orelse return;
    var name: [24]u8 = undefined;
    self.directory.deleteFile(self.io, filename(index, &name)) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    self.used -= entry.meta.size;
    self.entries[index] = null;
}
pub fn get(self: *Self, key: []const u8, expected: object.ObjectMeta, out: []u8) !bool {
    if (expected.size > out.len) return error.BufferTooSmall;
    const identity = hash(key);
    for (self.entries, 0..) |maybe, i| {
        const entry = maybe orelse continue;
        if (!std.mem.eql(u8, &entry.key, &identity) or !std.meta.eql(entry.meta, expected)) continue;
        var name: [24]u8 = undefined;
        const file = self.directory.openFile(self.io, filename(i, &name), .{ .follow_symlinks = false }) catch |err| switch (err) {
            error.FileNotFound => {
                try self.remove(i);
                break;
            },
            else => return err,
        };
        defer file.close(self.io);
        const bytes = out[0..@intCast(expected.size)];
        if (try file.length(self.io) != expected.size or try file.readPositionalAll(self.io, bytes, 0) != bytes.len or !std.mem.eql(u8, &hash(bytes), &expected.sha256)) {
            self.corruptions +|= 1;
            try self.remove(i);
            break;
        }
        self.entries[i].?.referenced = true;
        self.hits +|= 1;
        return true;
    }
    self.misses +|= 1;
    return false;
}
pub fn put(self: *Self, key: []const u8, expected: object.ObjectMeta, bytes: []const u8) !void {
    if (bytes.len != expected.size or !std.mem.eql(u8, &hash(bytes), &expected.sha256)) return error.ObjectDigestMismatch;
    if (bytes.len > self.capacity) return error.InvalidCacheBudget;
    // Evict before writing, reserving the temporary file's full length. Cache
    // capacity includes staged replacement bytes, not just published slots.
    while (self.used > self.capacity - bytes.len or self.entries[self.hand] != null) {
        if (self.entries[self.hand]) |*entry| {
            if (entry.referenced) entry.referenced = false else {
                try self.remove(self.hand);
                self.evictions +|= 1;
            }
        }
        if (self.used <= self.capacity - bytes.len and self.entries[self.hand] == null) break;
        self.hand = (self.hand + 1) % self.entries.len;
    }
    const index = self.hand;
    var name: [24]u8 = undefined;
    // A cache write may be torn by process death. Reopen drops cache slots;
    // live reads verify the original content digest before disclosure.
    try self.directory.writeFile(self.io, .{ .sub_path = filename(index, &name), .data = bytes, .flags = .{ .permissions = .fromMode(0o600) } });
    self.entries[index] = .{ .key = hash(key), .meta = expected, .referenced = true };
    self.used += bytes.len;
    self.hand = (index + 1) % self.entries.len;
}
