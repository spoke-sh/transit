//! Native POSIX segment & manifest store (`LocalSegmentStore`) implementing `TransitObjectStore`.
//! Supports atomic staging, SHA-256 verification, `If-None-Match` / `If-Match`
//! conditional manifest publication, and byte-range reads.
const std = @import("std");
const TransitObjectStore = @import("TransitObjectStore.zig");

const StoredObject = struct {
    key: []u8,
    bytes: []u8,
    sha256: [32]u8,

    fn deinit(self: *StoredObject, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const LocalSegmentStore = struct {
    allocator: std.mem.Allocator,
    io: ?std.Io = null,
    root_path: ?[]const u8 = null,
    objects: std.ArrayList(StoredObject) = .empty,
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
        try std.Io.Dir.cwd().createDirPath(io, path);
        const owned = try allocator.dupe(u8, path);
        return .{
            .allocator = allocator,
            .io = io,
            .root_path = owned,
        };
    }

    pub fn deinit(self: *LocalSegmentStore) void {
        for (self.objects.items) |*obj| obj.deinit(self.allocator);
        self.objects.deinit(self.allocator);
        if (self.root_path) |path| self.allocator.free(path);
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

    fn loadFromDiskIfPresent(self: *LocalSegmentStore, key: []const u8) !?*StoredObject {
        if (self.findMemory(key)) |obj| return obj;
        const io = self.io orelse return null;
        const root = self.root_path orelse return null;
        const full_path = try std.fs.path.join(self.allocator, &.{ root, key });
        defer self.allocator.free(full_path);

        const raw = std.Io.Dir.cwd().readFileAlloc(io, full_path, self.allocator, .limited(TransitObjectStore.max_object_bytes)) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
        errdefer self.allocator.free(raw);

        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(raw, &digest, .{});
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        try self.objects.append(self.allocator, .{
            .key = key_copy,
            .bytes = raw,
            .sha256 = digest,
        });
        return &self.objects.items[self.objects.items.len - 1];
    }

    fn persistToDisk(self: *LocalSegmentStore, key: []const u8, bytes: []const u8) !void {
        const io = self.io orelse return;
        const root = self.root_path orelse return;
        const full_path = try std.fs.path.join(self.allocator, &.{ root, key });
        defer self.allocator.free(full_path);

        if (std.fs.path.dirname(full_path)) |parent| {
            try std.Io.Dir.cwd().createDirPath(io, parent);
        }
        var dir = try std.Io.Dir.cwd().openDir(io, std.fs.path.dirname(full_path) orelse ".", .{ .iterate = true });
        defer dir.close(io);
        var atomic = try dir.createFileAtomic(io, std.fs.path.basename(full_path), .{ .replace = true, .permissions = .fromMode(0o600) });
        defer atomic.deinit(io);
        try atomic.file.writeStreamingAll(io, bytes);
        try atomic.file.sync(io);
        try atomic.replace(io);
    }

    pub fn putImmutableObject(
        self: *LocalSegmentStore,
        key: []const u8,
        bytes: []const u8,
        expected_sha256: [32]u8,
    ) !TransitObjectStore.ObjectMeta {
        try TransitObjectStore.validateKey(key);
        if (bytes.len > TransitObjectStore.max_object_bytes) return error.ObjectTooLarge;
        var actual: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
        if (!std.mem.eql(u8, &actual, &expected_sha256)) return error.ObjectDigestMismatch;

        if (try self.loadFromDiskIfPresent(key)) |existing| {
            if (!std.mem.eql(u8, &existing.sha256, &expected_sha256) or existing.bytes.len != bytes.len) {
                return error.ImmutableObjectConflict;
            }
            return .{ .size = existing.bytes.len, .sha256 = existing.sha256 };
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const bytes_copy = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(bytes_copy);

        try self.persistToDisk(key, bytes);
        try self.objects.append(self.allocator, .{
            .key = key_copy,
            .bytes = bytes_copy,
            .sha256 = actual,
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
        try TransitObjectStore.validateKey(key);
        if (bytes.len > TransitObjectStore.max_object_bytes) return error.ObjectTooLarge;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});

        const existing = try self.loadFromDiskIfPresent(key);
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

        try self.persistToDisk(key, bytes);
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
        try TransitObjectStore.validateKey(key);
        if (out.len < length) return error.BufferTooSmall;
        const obj = (try self.loadFromDiskIfPresent(key)) orelse return error.ObjectNotFound;
        if (offset > obj.bytes.len) return error.RangeOutOfBounds;
        const avail = obj.bytes.len - @as(usize, @intCast(offset));
        const to_read = @min(avail, @as(usize, length));
        @memcpy(out[0..to_read], obj.bytes[@intCast(offset)..][0..to_read]);
        self.range_reads += 1;
        self.bytes_read += to_read;
        return out[0..to_read];
    }

    pub fn headObject(self: *LocalSegmentStore, key: []const u8) !?TransitObjectStore.ObjectMeta {
        try TransitObjectStore.validateKey(key);
        const obj = (try self.loadFromDiskIfPresent(key)) orelse return null;
        return .{ .size = obj.bytes.len, .sha256 = obj.sha256 };
    }

    pub fn deleteObject(self: *LocalSegmentStore, key: []const u8) !void {
        try TransitObjectStore.validateKey(key);
        for (self.objects.items, 0..) |*obj, idx| {
            if (std.mem.eql(u8, obj.key, key)) {
                obj.deinit(self.allocator);
                _ = self.objects.orderedRemove(idx);
                break;
            }
        }
        if (self.io) |io| if (self.root_path) |root| {
            const full_path = try std.fs.path.join(self.allocator, &.{ root, key });
            defer self.allocator.free(full_path);
            std.Io.Dir.cwd().deleteFile(io, full_path) catch |err| switch (err) {
                error.FileNotFound => {},
                else => return err,
            };
        };
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
