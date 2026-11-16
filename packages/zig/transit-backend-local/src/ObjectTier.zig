//! Single-owner immutable tier. Local bytes, queue intent and original identity
//! precede acceptance. Remote coverage is durable before disposable eviction.
const std = @import("std");
const storage = @import("transit_storage");
const p = @import("transit_core").protocol;
const Objects = storage.TransitObjectStore;
const Local = storage.LocalSegmentStore.LocalSegmentStore;
const Queue = @import("UploadQueue.zig");
const Files = @import("LocalFiles.zig");
const Self = @This();
pub const Options = p.Storage.ObjectStorage;
const Phase = enum(u8) { pending = 1, uploaded = 2, deleting = 3 };
const State = struct { position: u64, generation: u64, phase: Phase, meta: Objects.ObjectMeta };
allocator: std.mem.Allocator,
io: std.Io,
local: *Local,
directory: std.Io.Dir,
states: std.Io.Dir,
locks: std.Io.Dir,
queue: Queue,
remote: storage.S3ObjectStore.S3ObjectStore,
cache: storage.NvmeCache.DiskCache,
options: Options,
/// Separate bounded workspaces: reads and background transfer never retain one
/// another's borrowed memory. Adapter serialization has its own request deadline.
read_buffer: []u8,
upload_buffer: []u8,
reads: std.Io.Mutex = .init,
worker: std.Io.Mutex = .init,
poisoned: std.atomic.Value(bool) = .init(false),

fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}
fn name(key: []const u8) [64]u8 {
    return std.fmt.bytesToHex(hash(key), .lower);
}
fn remoteKey(key: []const u8, generation: u64, out: *[96]u8) []const u8 {
    return std.fmt.bufPrint(out, "objects/{s}/{x:0>16}", .{ name(key), generation }) catch unreachable;
}
pub fn open(allocator: std.mem.Allocator, io: std.Io, local: *Local, parent: std.Io.Dir, options: Options, fresh: bool) !*Self {
    if (options.staging_bytes < Objects.max_object_bytes or options.staging_bytes > p.max_counter or options.pending_objects == 0 or options.pending_objects > 1024 * 1024) return error.InvalidTierBudget;
    var remote = try storage.S3ObjectStore.S3ObjectStore.init(allocator, io, .{
        .endpoint = options.endpoint,
        .region = options.region,
        .bucket = options.bucket,
        .prefix = options.prefix,
        .credentials_file = options.credentials_file,
        .request_timeout_ms = options.request_timeout_ms,
        .allow_loopback_http = options.allow_loopback_http,
    });
    errdefer remote.deinit();
    var binding = std.crypto.hash.sha2.Sha256.init(.{});
    for ([_][]const u8{ options.endpoint, options.region, options.bucket, options.prefix }) |part| {
        var length: [8]u8 = undefined;
        std.mem.writeInt(u64, &length, part.len, .little);
        binding.update(&length);
        binding.update(part);
    }
    const bound = binding.finalResult();
    var identity: [160]u8 = @splat(0);
    if (try Files.read(io, parent, ".object-tier", &identity)) |raw| {
        if (raw.len != identity.len or !std.mem.eql(u8, identity[0..8], "TTIER001") or
            !std.mem.eql(u8, identity[8..40], &p.Growth.definition_bytes) or !std.mem.allEqual(u8, identity[104..128], 0) or
            !std.mem.eql(u8, identity[128..160], &hash(identity[0..128]))) return error.InvalidTierIdentity;
        if (!std.mem.eql(u8, identity[72..104], &bound)) return error.TierNamespaceChanged;
    } else {
        if (!fresh) return error.TierRequiresFreshInstallation;
        var retained: [32]u8 = undefined;
        if (try Files.read(io, parent, ".object-tier-ready", &retained) != null) return error.MissingTierInventory;
        identity[0..8].* = "TTIER001".*;
        identity[8..40].* = p.Growth.definition_bytes;
        try io.randomSecure(identity[40..72]);
        identity[72..104].* = bound;
        identity[128..160].* = hash(identity[0..128]);
        try Files.save(io, parent, ".object-tier", &identity, false);
    }
    var initialized: [32]u8 = undefined;
    if (try Files.read(io, parent, ".object-tier-ready", &initialized)) |raw| {
        if (!std.mem.eql(u8, raw, &hash(&identity))) return error.InvalidTierIdentity;
        // A retained owner cannot manufacture empty inventories after loss.
        for ([_][]const u8{ "tier/claimed", "tier/cursor", "tier/queue/.definition" }) |path| {
            const file = parent.openFile(io, path, .{ .follow_symlinks = false }) catch return error.MissingTierInventory;
            file.close(io);
        }
        for ([_][]const u8{ "tier/states", "tier/locks" }) |path| {
            const dir = parent.openDir(io, path, .{ .iterate = true }) catch return error.MissingTierInventory;
            dir.close(io);
        }
    } else if (!fresh) return error.MissingTierInventory;
    try parent.createDirPath(io, "tier/states");
    try parent.createDirPath(io, "tier/locks");
    try Files.sync(io, parent);
    const directory = try parent.openDir(io, "tier", .{ .iterate = true });
    errdefer directory.close(io);
    try Files.sync(io, directory);
    var claimed: [160]u8 = undefined;
    if (try Files.read(io, directory, "claimed", &claimed)) |raw| {
        if (!std.mem.eql(u8, raw, &identity)) return error.InvalidTierIdentity;
    } else {
        // Exact replay after a lost response proves the same immutable owner.
        // This marker detects namespace reuse; it is not distributed fencing.
        _ = remote.objectStore().putImmutable(".transit/owner", &identity, hash(&identity)) catch |err| switch (err) {
            error.ImmutableObjectConflict => return error.TierNamespaceInUse,
            else => return err,
        };
        try Files.save(io, directory, "claimed", &identity, false);
    }
    const states = try directory.openDir(io, "states", .{ .iterate = true });
    errdefer states.close(io);
    const locks = try directory.openDir(io, "locks", .{ .iterate = true });
    errdefer locks.close(io);
    var queue = try Queue.open(allocator, io, directory);
    errdefer queue.deinit();
    var cache = try storage.NvmeCache.DiskCache.open(allocator, io, parent, "cache", options.cache_bytes);
    errdefer cache.deinit();
    const read_buffer = try allocator.alloc(u8, Objects.max_object_bytes);
    errdefer allocator.free(read_buffer);
    const upload_buffer = try allocator.alloc(u8, Objects.max_object_bytes);
    errdefer allocator.free(upload_buffer);
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator, .io = io, .local = local, .directory = directory, .states = states, .locks = locks, .queue = queue, .remote = remote, .cache = cache, .options = options, .read_buffer = read_buffer, .upload_buffer = upload_buffer };
    // Recover intents whose state publication was interrupted before admitting
    // any request. This scan is paged, with one fixed-size record resident.
    try self.queue.reconcile(self);
    try Files.save(io, parent, ".object-tier-ready", &hash(&identity), true);
    return self;
}
pub fn deinit(self: *Self) void {
    const allocator = self.allocator;
    allocator.free(self.upload_buffer);
    allocator.free(self.read_buffer);
    self.cache.deinit();
    self.remote.deinit();
    self.queue.deinit();
    self.locks.close(self.io);
    self.states.close(self.io);
    self.directory.close(self.io);
    allocator.destroy(self);
}
pub fn check(self: *Self) !void {
    if (self.poisoned.load(.acquire) or self.queue.wal.requiresRecovery()) return error.TierRecoveryRequired;
}
fn lock(self: *Self, key: []const u8) !std.Io.File {
    try Objects.validateKey(key);
    const file = try self.locks.createFile(self.io, &name(key), .{ .read = true, .truncate = false, .permissions = .fromMode(0o600) });
    errdefer file.close(self.io);
    try file.lock(self.io, .exclusive);
    try self.check();
    return file;
}
fn readState(self: *Self, key: []const u8) !?State {
    var raw: [512]u8 = undefined;
    const bytes = (try Files.read(self.io, self.states, &name(key), &raw)) orelse return null;
    if (bytes.len != raw.len or !std.mem.eql(u8, bytes[0..8], "TTCOVER1") or !std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes) or
        !std.mem.eql(u8, bytes[480..512], &hash(bytes[0..480])) or !std.mem.allEqual(u8, bytes[57..64], 0) or
        !std.mem.allEqual(u8, bytes[66..72], 0) or std.mem.readInt(u16, bytes[64..66], .little) != key.len or
        !std.mem.eql(u8, bytes[112..][0..key.len], key) or !std.mem.allEqual(u8, bytes[112 + key.len .. 480], 0)) return error.InvalidTierCoverage;
    const phase = std.enums.fromInt(Phase, bytes[56]) orelse return error.InvalidTierCoverage;
    const result: State = .{ .position = std.mem.readInt(u64, bytes[40..48], .little), .generation = std.mem.readInt(u64, bytes[48..56], .little), .phase = phase, .meta = .{ .size = std.mem.readInt(u64, bytes[72..80], .little), .sha256 = bytes[80..112].* } };
    if (result.meta.size > Objects.max_object_bytes or result.position > p.max_counter or result.generation > result.position) return error.InvalidTierCoverage;
    return result;
}
fn saveState(self: *Self, key: []const u8, state: State) !void {
    var raw: [512]u8 = @splat(0);
    raw[0..8].* = "TTCOVER1".*;
    raw[8..40].* = p.Growth.definition_bytes;
    std.mem.writeInt(u64, raw[40..48], state.position, .little);
    std.mem.writeInt(u64, raw[48..56], state.generation, .little);
    raw[56] = @backingInt(state.phase);
    std.mem.writeInt(u16, raw[64..66], @intCast(key.len), .little);
    std.mem.writeInt(u64, raw[72..80], state.meta.size, .little);
    raw[80..112].* = state.meta.sha256;
    @memcpy(raw[112..][0..key.len], key);
    raw[480..512].* = hash(raw[0..480]);
    try Files.save(self.io, self.states, &name(key), &raw, true);
}
pub fn restore(self: *Self, record: Queue.Record) !void {
    const key = record.item.key.slice();
    const generation = record.item.remote_generation orelse record.position;
    if (try self.readState(key)) |state| {
        if (state.position > record.position) return;
        if (state.position == record.position) {
            if (state.generation != generation or !std.meta.eql(state.meta, record.item.meta) or
                (record.item.action == .upload and state.phase == .deleting) or (record.item.action == .delete and state.phase != .deleting)) return error.InvalidTierCoverage;
            return;
        }
    }
    try self.saveState(key, .{ .position = record.position, .generation = generation, .meta = record.item.meta, .phase = if (record.item.action == .upload) .pending else .deleting });
}
/// The foreground performs only local durable I/O. No provider request runs here.
pub fn put(self: *Self, key: []const u8, bytes: []const u8, digest: [32]u8) !Objects.ObjectMeta {
    const held = try self.lock(key);
    defer held.close(self.io);
    const expected: Objects.ObjectMeta = .{ .size = bytes.len, .sha256 = digest };
    const previous = try self.readState(key);
    if (previous) |state| {
        if (state.phase != .deleting) {
            if (!std.meta.eql(state.meta, expected)) return error.ImmutableObjectConflict;
            if (state.phase == .uploaded) return expected;
            return self.local.putImmutableObject(key, bytes, digest);
        }
        // A collector durably authorized deletion of the old generation. Clear
        // any interrupted local removal before creating a distinct generation.
        _ = try self.local.reclaimImmutableObject(key, state.meta);
    }
    // Intent precedes staging, so quota refusal cannot create unaccounted bytes.
    // A crash before content publication leaves unaccepted work visible to the
    // original allocation collector; only that owner may supersede the intent.
    const position = self.queue.enqueue(.{ .key = try Queue.Key.init(key), .meta = expected, .action = .upload }, self.options.staging_bytes, self.options.pending_objects) catch |err| {
        if (err != error.UploadStagingQuota) self.poisoned.store(true, .release);
        return err;
    };
    self.saveState(key, .{ .position = position, .generation = position, .meta = expected, .phase = .pending }) catch |err| {
        self.poisoned.store(true, .release);
        return err;
    };
    return self.local.putImmutableObject(key, bytes, digest);
}
/// Called only after the retained-root collector has fenced readers/recreation.
pub fn reclaim(self: *Self, key: []const u8, expected: Objects.ObjectMeta) !u64 {
    const held = try self.lock(key);
    defer held.close(self.io);
    const state = (try self.readState(key)) orelse return self.local.reclaimImmutableObject(key, expected);
    if (!std.meta.eql(state.meta, expected)) return error.ImmutableObjectConflict;
    if (state.phase != .deleting) {
        const position = self.queue.enqueue(.{ .key = try Queue.Key.init(key), .meta = expected, .action = .delete, .remote_generation = state.generation }, self.options.staging_bytes, self.options.pending_objects) catch |err| {
            if (err != error.UploadStagingQuota) self.poisoned.store(true, .release);
            return err;
        };
        self.saveState(key, .{ .position = position, .generation = state.generation, .meta = expected, .phase = .deleting }) catch |err| {
            self.poisoned.store(true, .release);
            return err;
        };
    }
    return self.local.reclaimImmutableObject(key, expected);
}
pub fn confirm(self: *Self, key: []const u8, expected: Objects.ObjectMeta) !void {
    const held = try self.lock(key);
    defer held.close(self.io);
    const state = (try self.readState(key)) orelse return error.MissingTierCoverage;
    if (state.phase == .deleting or !std.meta.eql(state.meta, expected)) return error.ImmutableObjectConflict;
    const local = (try self.local.headObject(key)) orelse return error.ObjectNotFound;
    if (!std.meta.eql(local, expected)) return error.ImmutableObjectConflict;
    if (state.phase == .pending) try self.local.confirmImmutableObject(key, expected);
}
pub fn read(self: *Self, key: []const u8, offset: u64, length: u32, out: []u8) ![]const u8 {
    const held = try self.lock(key);
    defer held.close(self.io);
    const expected = (try self.local.headObject(key)) orelse return error.ObjectNotFound;
    const state = (try self.readState(key)) orelse return error.MissingTierCoverage;
    if (!std.meta.eql(state.meta, expected) or state.phase == .deleting) return error.InvalidTierCoverage;
    if (offset > expected.size) return error.RangeOutOfBounds;
    if (out.len < length) return error.BufferTooSmall;
    if (state.phase == .pending) return self.local.objectStore().getRange(key, offset, length, out);
    if (self.local.objectStore().getRange(key, offset, length, out)) |bytes| return bytes else |err| switch (err) {
        error.FileNotFound, error.ObjectDigestMismatch => {},
        else => return err,
    }
    // Uploaded bytes are disposable. Their absence/corruption cannot authorize
    // replacing the retained identity with an untrusted remote descriptor.
    try self.reads.lock(self.io);
    defer self.reads.unlock(self.io);
    if (!try self.cache.get(key, expected, self.read_buffer)) {
        var remote_name: [96]u8 = undefined;
        const got = (try self.remote.objectStore().getObject(remoteKey(key, state.generation, &remote_name), self.read_buffer)) orelse return error.RemoteObjectMissing;
        if (!std.meta.eql(got, expected)) return error.ObjectDigestMismatch;
        try self.cache.put(key, expected, self.read_buffer[0..@intCast(expected.size)]);
    }
    const count: usize = @intCast(@min(length, expected.size - offset));
    @memcpy(out[0..count], self.read_buffer[@intCast(offset)..][0..count]);
    return out[0..count];
}
/// One bounded background step. Errors retain original work, with no implicit
/// provider retry. The host owns scheduling, cancellation and joined shutdown.
pub fn step(self: *Self) !u64 {
    try self.worker.lock(self.io);
    defer self.worker.unlock(self.io);
    try self.check();
    const record = (try self.queue.next()) orelse return 0;
    const key = record.item.key.slice();
    const held = try self.lock(key);
    defer held.close(self.io);
    const state = (try self.readState(key)) orelse return error.MissingTierCoverage;
    var remote_name: [96]u8 = undefined;
    var removed: u64 = 0;
    if (record.item.action == .upload) {
        if (state.position == record.position) {
            if (state.phase == .pending) {
                const got = (try self.local.objectStore().getObject(key, self.upload_buffer)) orelse return error.ObjectNotFound;
                if (!std.meta.eql(got, record.item.meta)) return error.ObjectDigestMismatch;
                _ = try self.remote.objectStore().putImmutable(remoteKey(key, state.generation, &remote_name), self.upload_buffer[0..@intCast(got.size)], got.sha256);
                const verified = (try self.remote.objectStore().getObject(remoteKey(key, state.generation, &remote_name), self.upload_buffer)) orelse return error.RemoteObjectMissing;
                if (!std.meta.eql(verified, got)) return error.ObjectDigestMismatch;
                // The adapter verifies exact conditional retries. Coverage is
                // published before either eviction or queue progress.
                var covered = state;
                covered.phase = .uploaded;
                self.saveState(key, covered) catch |err| {
                    self.poisoned.store(true, .release);
                    return err;
                };
            }
            removed = try self.local.disk.?.evictImmutable(key, state.meta);
        }
    } else {
        try self.remote.objectStore().delete(remoteKey(key, record.item.remote_generation.?, &remote_name));
        if (state.position == record.position) {
            errdefer self.poisoned.store(true, .release);
            removed = try self.local.reclaimImmutableObject(key, record.item.meta);
            // Replaying this still-pending delete recreates its state after a
            // crash. Removal precedes cursor advancement to avoid orphan state.
            try Files.remove(self.io, self.states, &name(key));
        }
    }
    errdefer self.poisoned.store(true, .release);
    try self.queue.consume(record);
    return removed;
}
