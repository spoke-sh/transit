//! Quota-accounted direct data partitions inside the exclusive native owner.
//! Acceptance checks current native policy/storage epochs under the same mutex
//! as native publication, without comparing native data progress positions.
const std = @import("std");
const storage = @import("transit_storage");
const Backend = @import("Backend.zig");
const Store = @import("Store.zig");
const Self = @This();
const Log = storage.TransitLog;
const Objects = storage.TransitObjectStore;

backend: *Backend,
control: bool = false,
observe: @import("Diagnostics.zig") = .{},

pub fn log(self: *Self) Log.Log {
    return .{ .context = self, .vtable = &.{ .append = append, .read = read, .tail = tail, .trim = trim, .fence = fence } };
}
pub fn objects(self: *Self) Objects.ObjectStore {
    return .{ .context = self, .vtable = &.{ .putImmutable = put, .putConditional = conditional, .getRange = range, .head = head, .delete = delete } };
}
fn erased(context: *anyopaque) *Self {
    return @ptrCast(@alignCast(context));
}
fn partition(id: u64) !void {
    if (id == 0) return error.NativePartitionReserved;
}

fn append(context: *anyopaque, id: u64, expected: ?u64, writer: u64, policy: u64, kind: Log.FrameKind, payload: []const u8) !Log.AppendReceipt {
    const self = erased(context);
    return self.observe.run(self.backend.io, "data.append", appendImpl, .{ self, id, expected, writer, policy, kind, payload });
}
fn appendImpl(self: *Self, id: u64, expected: ?u64, writer: u64, policy: u64, kind: Log.FrameKind, payload: []const u8) !Log.AppendReceipt {
    try partition(id);
    if (expected == null) return error.DataExpectationRequired;
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    const current = try Store.currentHeadLocked(self.backend);
    if (writer != current.storage_epoch) return error.StaleStorageEpoch;
    if (policy != current.authorization.revision + 1) return error.AuthorizationChanged;
    const value_log = self.backend.wal.log();
    if (try value_log.tail(id) != expected.?) return error.WalLsnConflict;
    if (payload.len > Log.max_payload_bytes) return error.WalPayloadTooLarge;
    try self.backend.reserve(Log.alignedFrameSize(payload.len) + 128, self.control);
    self.observe.metrics.request_payload_bytes +|= payload.len;
    return value_log.append(id, expected, writer, policy, kind, payload);
}
fn read(context: *anyopaque, allocator: std.mem.Allocator, id: u64, from: u64, count: usize) !Log.Log.OwnedBatch {
    const self = erased(context);
    return self.observe.run(self.backend.io, "data.read", readImpl, .{ self, allocator, id, from, count });
}
fn readImpl(self: *Self, allocator: std.mem.Allocator, id: u64, from: u64, count: usize) !Log.Log.OwnedBatch {
    try partition(id);
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    const batch = try self.backend.wal.log().read(allocator, id, from, count);
    for (batch.frames) |frame| self.observe.metrics.response_bytes +|= frame.payload.len;
    return batch;
}
fn tail(context: *anyopaque, id: u64) !u64 {
    const self = erased(context);
    return self.observe.run(self.backend.io, "data.tail", tailImpl, .{ self, id });
}
fn tailImpl(self: *Self, id: u64) !u64 {
    try partition(id);
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    return self.backend.wal.log().tail(id);
}
fn trim(context: *anyopaque, id: u64, before: u64) !void {
    const self = erased(context);
    while (!(try self.trimUnit(id, before)).complete) {}
}

pub const TrimProgress = struct { complete: bool };

/// Validate accepted Table archive coverage and perform one bounded physical
/// cleanup unit. The runtime owns current policy authorization and serializes
/// this call with the Table; this adapter never accepts an invented trim floor.
pub fn trimUnit(self: *Self, id: u64, before: u64) !TrimProgress {
    return self.observe.run(self.backend.io, "data.trim", trimUnitImpl, .{ self, id, before });
}

fn trimUnitImpl(self: *Self, id: u64, before: u64) !TrimProgress {
    try partition(id);
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    const value_log = self.backend.wal.log();
    const end = try value_log.tail(id);
    if (end == 0 or before >= end) return error.NoCheckpointIntent;
    var latest = try value_log.read(self.backend.allocator, id, end - 1, 1);
    defer latest.deinit();
    if (latest.frames.len != 1 or latest.frames[0].header.partition_id != id or latest.frames[0].header.lsn != end - 1) return error.IncompleteHistory;
    const through = try storage.TablePartition.archivedThrough(self.backend.allocator, latest.frames[0]);
    if (before > through) return error.NoCheckpointIntent;
    // The serialized Table owner publishes only after durable archive staging.
    // Physical removal does not expire logical history. Conservative allocation
    // reservations are reconciled on exclusive reopen, as for native WAL trim.
    return .{ .complete = try self.backend.wal.trimUnit(id, before) };
}
fn fence(_: *anyopaque, _: u64, _: u64, _: u64) !void {
    return error.NativeFenceRequired;
}

fn put(context: *anyopaque, key: []const u8, bytes: []const u8, expected: [32]u8) !Objects.ObjectMeta {
    const self = erased(context);
    return self.observe.run(self.backend.io, "data.object_put", putImpl, .{ self, key, bytes, expected });
}
fn putImpl(self: *Self, key: []const u8, bytes: []const u8, expected: [32]u8) !Objects.ObjectMeta {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &expected)) return error.ObjectDigestMismatch;
    self.observe.metrics.request_payload_bytes +|= bytes.len;
    try self.backend.put(key, bytes, self.control);
    return .{ .size = bytes.len, .sha256 = expected };
}
fn conditional(_: *anyopaque, _: []const u8, _: Objects.Condition, _: []const u8) !bool {
    return error.MutableDataObjectUnavailable;
}
fn range(context: *anyopaque, key: []const u8, offset: u64, length: u32, output: []u8) ![]const u8 {
    const self = erased(context);
    return self.observe.run(self.backend.io, "data.object_read", rangeImpl, .{ self, key, offset, length, output });
}
fn rangeImpl(self: *Self, key: []const u8, offset: u64, length: u32, output: []u8) ![]const u8 {
    try Backend.dataKey(key);
    const bytes = try self.backend.objects.objectStore().getRange(key, offset, length, output);
    self.observe.metrics.response_bytes +|= bytes.len;
    return bytes;
}
fn head(context: *anyopaque, key: []const u8) !?Objects.ObjectMeta {
    const self = erased(context);
    return self.observe.run(self.backend.io, "data.object_head", headImpl, .{ self, key });
}
fn headImpl(self: *Self, key: []const u8) !?Objects.ObjectMeta {
    try Backend.dataKey(key);
    return self.backend.objects.objectStore().head(key);
}
fn delete(_: *anyopaque, _: []const u8) !void {
    return error.DataHistoryCollectionUnavailable;
}
