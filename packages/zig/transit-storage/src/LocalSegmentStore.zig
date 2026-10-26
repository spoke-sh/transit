//! Native POSIX segment & manifest store (`LocalSegmentStore`) implementing `TransitObjectStore`.
//! Supports atomic staging, SHA-256 verification, `If-None-Match` / `If-Match`
//! conditional manifest publication, and byte-range reads.
const std = @import("std");
const TransitObjectStore = @import("TransitObjectStore.zig");
const Disk = @import("DiskObjects.zig");

const StoredObject = struct {
    key: []u8,
    bytes: []u8,
    sha256: [32]u8,
    immutable: bool,

    fn deinit(self: *StoredObject, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const LocalSegmentStore = struct {
    allocator: std.mem.Allocator,
    disk: ?*Disk = null,
    objects: std.ArrayList(StoredObject) = .empty,
    /// Disk operations serialize by key in DiskObjects. Only their completed
    /// attempt counters share this mutex; no object I/O runs under it. Inspect
    /// counters and deinitialize after joining callers. Memory mode remains
    /// caller-serialized.
    counters_mutex: std.Io.Mutex = .init,
    puts: u64 = 0,
    conditional_puts: u64 = 0,
    conditional_conflicts: u64 = 0,
    range_reads: u64 = 0,
    bytes_written: u64 = 0,
    bytes_read: u64 = 0,

    pub fn initMemory(allocator: std.mem.Allocator) LocalSegmentStore {
        return .{ .allocator = allocator };
    }

    pub fn openDisk(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !LocalSegmentStore {
        return openDiskAt(allocator, io, std.Io.Dir.cwd(), path);
    }

    pub fn openDiskAt(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, path: []const u8) !LocalSegmentStore {
        const disk = try allocator.create(Disk);
        errdefer allocator.destroy(disk);
        disk.* = try Disk.open(allocator, io, parent, path);
        return .{ .allocator = allocator, .disk = disk };
    }

    pub fn deinit(self: *LocalSegmentStore) void {
        for (self.objects.items) |*obj| obj.deinit(self.allocator);
        self.objects.deinit(self.allocator);
        if (self.disk) |disk| {
            disk.deinit();
            self.allocator.destroy(disk);
        }
        self.* = undefined;
    }

    pub fn objectStore(self: *LocalSegmentStore) TransitObjectStore.ObjectStore {
        return .{
            .context = self,
            .vtable = &.{
                .putImmutable = putImmutableErased,
                .putConditional = putConditionalErased,
                .getRange = getRangeErased,
                .head = headErased,
                .delete = deleteErased,
            },
        };
    }

    fn findMemory(self: *LocalSegmentStore, key: []const u8) ?*StoredObject {
        for (self.objects.items) |*obj| {
            if (std.mem.eql(u8, obj.key, key)) return obj;
        }
        return null;
    }

    pub fn putImmutableObject(
        self: *LocalSegmentStore,
        key: []const u8,
        bytes: []const u8,
        expected_sha256: [32]u8,
    ) !TransitObjectStore.ObjectMeta {
        if (self.disk) |disk| {
            const meta = try disk.putImmutable(key, bytes, expected_sha256);
            self.counters_mutex.lockUncancelable(disk.io);
            defer self.counters_mutex.unlock(disk.io);
            self.puts += 1;
            self.bytes_written += bytes.len;
            return meta;
        }
        try TransitObjectStore.validateKey(key);
        if (bytes.len > TransitObjectStore.max_object_bytes) return error.ObjectTooLarge;
        var actual: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
        if (!std.mem.eql(u8, &actual, &expected_sha256)) return error.ObjectDigestMismatch;

        if (self.findMemory(key)) |existing| {
            if (!existing.immutable or !std.mem.eql(u8, &existing.sha256, &expected_sha256) or existing.bytes.len != bytes.len) {
                return error.ImmutableObjectConflict;
            }
            return .{ .size = existing.bytes.len, .sha256 = existing.sha256 };
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const bytes_copy = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(bytes_copy);

        try self.objects.append(self.allocator, .{
            .key = key_copy,
            .bytes = bytes_copy,
            .sha256 = actual,
            .immutable = true,
        });
        self.puts += 1;
        self.bytes_written += bytes.len;
        return .{ .size = bytes.len, .sha256 = actual };
    }

    pub fn putConditionalObject(
        self: *LocalSegmentStore,
        key: []const u8,
        condition: TransitObjectStore.Condition,
        bytes: []const u8,
    ) !bool {
        if (self.disk) |disk| {
            const accepted = try disk.putConditional(key, condition, bytes);
            self.counters_mutex.lockUncancelable(disk.io);
            defer self.counters_mutex.unlock(disk.io);
            if (accepted) {
                self.conditional_puts += 1;
                self.bytes_written += bytes.len;
            } else self.conditional_conflicts += 1;
            return accepted;
        }
        try TransitObjectStore.validateKey(key);
        if (bytes.len > TransitObjectStore.max_object_bytes) return error.ObjectTooLarge;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});

        const existing = self.findMemory(key);
        if (existing) |value| if (value.immutable) return error.ImmutableObjectConflict;
        switch (condition) {
            .if_none_match => {
                if (existing != null) {
                    self.conditional_conflicts += 1;
                    return false;
                }
            },
            .if_match => |expected_etag| {
                const cur = existing orelse {
                    self.conditional_conflicts += 1;
                    return false;
                };
                if (!std.mem.eql(u8, &cur.sha256, &expected_etag)) {
                    self.conditional_conflicts += 1;
                    return false;
                }
            },
        }

        if (existing) |cur| {
            const bytes_copy = try self.allocator.dupe(u8, bytes);
            self.allocator.free(cur.bytes);
            cur.bytes = bytes_copy;
            cur.sha256 = digest;
        } else {
            const key_copy = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(key_copy);
            const bytes_copy = try self.allocator.dupe(u8, bytes);
            errdefer self.allocator.free(bytes_copy);
            try self.objects.append(self.allocator, .{
                .key = key_copy,
                .bytes = bytes_copy,
                .sha256 = digest,
                .immutable = false,
            });
        }
        self.conditional_puts += 1;
        self.bytes_written += bytes.len;
        return true;
    }

    pub fn getObjectRange(
        self: *LocalSegmentStore,
        key: []const u8,
        offset: u64,
        length: u32,
        out: []u8,
    ) ![]const u8 {
        if (self.disk) |disk| {
            const bytes = try disk.read(key, offset, length, out);
            self.counters_mutex.lockUncancelable(disk.io);
            defer self.counters_mutex.unlock(disk.io);
            self.range_reads += 1;
            self.bytes_read += bytes.len;
            return bytes;
        }
        try TransitObjectStore.validateKey(key);
        if (out.len < length) return error.BufferTooSmall;
        const obj = (self.findMemory(key)) orelse return error.ObjectNotFound;
        if (offset > obj.bytes.len) return error.RangeOutOfBounds;
        const avail = obj.bytes.len - @as(usize, @intCast(offset));
        const to_read = @min(avail, @as(usize, length));
        @memcpy(out[0..to_read], obj.bytes[@intCast(offset)..][0..to_read]);
        self.range_reads += 1;
        self.bytes_read += to_read;
        return out[0..to_read];
    }

    pub fn headObject(self: *LocalSegmentStore, key: []const u8) !?TransitObjectStore.ObjectMeta {
        if (self.disk) |disk| return disk.head(key);
        try TransitObjectStore.validateKey(key);
        const obj = (self.findMemory(key)) orelse return null;
        return .{ .size = obj.bytes.len, .sha256 = obj.sha256 };
    }

    pub fn deleteObject(self: *LocalSegmentStore, key: []const u8) !void {
        if (self.disk) |disk| return disk.delete(key);
        try TransitObjectStore.validateKey(key);
        for (self.objects.items, 0..) |*obj, idx| {
            if (std.mem.eql(u8, obj.key, key)) {
                obj.deinit(self.allocator);
                _ = self.objects.orderedRemove(idx);
                break;
            }
        }
    }

    /// Exclusive physical owner only; ordinary descriptor deletion retains bytes.
    pub fn reclaimImmutableObject(self: *LocalSegmentStore, key: []const u8, expected: TransitObjectStore.ObjectMeta) !u64 {
        if (self.disk) |disk| return disk.reclaimImmutable(key, expected);
        const existing = (self.findMemory(key)) orelse return 0;
        if (!existing.immutable or existing.bytes.len != expected.size or !std.mem.eql(u8, &existing.sha256, &expected.sha256)) return error.ImmutableObjectConflict;
        const size = existing.bytes.len;
        try self.deleteObject(key);
        return size;
    }

    fn putImmutableErased(
        ctx: *anyopaque,
        key: []const u8,
        bytes: []const u8,
        expected_sha256: [32]u8,
    ) anyerror!TransitObjectStore.ObjectMeta {
        const self: *LocalSegmentStore = @ptrCast(@alignCast(ctx));
        return self.putImmutableObject(key, bytes, expected_sha256);
    }

    fn putConditionalErased(
        ctx: *anyopaque,
        key: []const u8,
        condition: TransitObjectStore.Condition,
        bytes: []const u8,
    ) anyerror!bool {
        const self: *LocalSegmentStore = @ptrCast(@alignCast(ctx));
        return self.putConditionalObject(key, condition, bytes);
    }

    fn getRangeErased(
        ctx: *anyopaque,
        key: []const u8,
        offset: u64,
        length: u32,
        out: []u8,
    ) anyerror![]const u8 {
        const self: *LocalSegmentStore = @ptrCast(@alignCast(ctx));
        return self.getObjectRange(key, offset, length, out);
    }

    fn headErased(ctx: *anyopaque, key: []const u8) anyerror!?TransitObjectStore.ObjectMeta {
        const self: *LocalSegmentStore = @ptrCast(@alignCast(ctx));
        return self.headObject(key);
    }

    fn deleteErased(ctx: *anyopaque, key: []const u8) anyerror!void {
        const self: *LocalSegmentStore = @ptrCast(@alignCast(ctx));
        return self.deleteObject(key);
    }
};
