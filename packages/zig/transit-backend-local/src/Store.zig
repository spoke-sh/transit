//! Partition-zero native publication. Immutable pages become visible only when
//! this append accepts the complete next catalog and policy roots.
const std = @import("std");
const core = @import("transit_core");
const storage = @import("transit_storage");
const Backend = @import("Backend.zig");
const Self = @This();
pub const max_record_bytes = 256 * 1024;

backend: *Backend,
observe: @import("Diagnostics.zig") = .{},
cached: ?struct { at: u64, entry: core.growing.Entry } = null,
/// Failure injection after durable acceptance; used by the recovery proof.
lose_reply: bool = false,

pub fn tail(self: *Self) !u64 {
    return self.observe.run(self.backend.io, "native.tail", tailImpl, .{self});
}

fn tailImpl(self: *Self) !u64 {
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    return self.backend.wal.log().tail(0);
}

pub fn appendControlled(self: *Self, expected: u64, entry: core.growing.Entry, control: bool) !bool {
    return self.observe.run(self.backend.io, "native.append", appendImpl, .{ self, expected, entry, control });
}

fn appendImpl(self: *Self, expected: u64, entry: core.growing.Entry, control: bool) !bool {
    try validate(entry, expected);
    var bytes: [max_record_bytes]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    std.json.Stringify.value(entry, .{}, &out) catch return error.RecordTooLarge;
    const value_head = head(entry);
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    const log = self.backend.wal.log();
    if (try log.tail(0) != expected) return false;
    try self.backend.reserve(storage.TransitLog.alignedFrameSize(out.buffered().len) + 128, control);
    self.observe.metrics.request_payload_bytes +|= out.buffered().len;
    _ = try log.append(0, expected, value_head.storage_epoch, value_head.authorization.revision + 1, if (entry == .genesis) .genesis else .process_turn, out.buffered());
    self.cached = .{ .at = expected, .entry = entry };
    if (self.lose_reply) return error.LostAcknowledgement;
    return true;
}

pub fn read(self: *Self, at: u64) !?core.growing.Entry {
    return self.observe.run(self.backend.io, "native.read", readImpl, .{ self, at });
}

fn readImpl(self: *Self, at: u64) !?core.growing.Entry {
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    // Consult the log even for a cached coordinate: a trim revokes history
    // availability and cannot be bypassed by a lane's cache.
    var batch = self.backend.wal.log().read(self.backend.allocator, 0, at, 1) catch |err| switch (err) {
        error.WalHistoryTrimmed => return error.HistoryReclaimed,
        else => return err,
    };
    defer batch.deinit();
    if (batch.frames.len == 0) return null;
    const frame = batch.frames[0];
    self.observe.metrics.response_bytes +|= frame.payload.len;
    if (frame.header.lsn != at or frame.header.partition_id != 0 or frame.payload.len > max_record_bytes) return error.InvalidHistory;
    if (frame.header.kind != (if (at == 0) storage.TransitLog.FrameKind.genesis else .process_turn)) return error.InvalidHistory;
    const parsed = try std.json.parseFromSlice(core.growing.Entry, self.backend.allocator, frame.payload, .{});
    defer parsed.deinit();
    try validate(parsed.value, at);
    const next = head(parsed.value);
    if (frame.header.writer_epoch != next.storage_epoch or frame.header.policy_epoch != next.authorization.revision + 1) return error.InvalidHistory;
    self.cached = .{ .at = at, .entry = parsed.value };
    return parsed.value;
}

fn head(entry: core.growing.Entry) core.growing.Head {
    return switch (entry) {
        .genesis => |value| value.head,
        .operation => |value| value.next,
    };
}

fn validate(entry: core.growing.Entry, at: u64) !void {
    const next = head(entry);
    if (next.version != 1 or next.position != try std.math.add(u64, at, 1) or next.history_floor >= next.position or next.storage_epoch == 0) return error.InvalidHistory;
    try next.catalog.validate();
    try next.authorization.validate();
    switch (entry) {
        .genesis => |value| if (at != 0 or value.genesis.version != 1) {
            return error.InvalidHistory;
        },
        .operation => |value| if (at == 0 or value.position != at or value.request.version != 1) {
            return error.InvalidHistory;
        },
    }
}

/// Only an already committed native floor can authorize physical prefix trim.
/// The latest entry and all immutable objects remain. Exact retry records and
/// captured roots continue to live in that entry's catalog.
pub fn maintain(self: *Self, authorized: core.growing.Head) !void {
    return self.observe.run(self.backend.io, "native.trim", maintainImpl, .{ self, authorized });
}

fn maintainImpl(self: *Self, authorized: core.growing.Head) !void {
    if (authorized.history_floor == 0 or authorized.history_floor >= authorized.position) return error.NoCheckpointIntent;
    const position = try self.tail();
    if (position == 0) return error.InvalidHistory;
    const current = head(try self.read(position - 1) orelse return error.IncompleteHistory);
    if (!std.mem.eql(u8, &current.genesis, &authorized.genesis) or current.position < authorized.position or current.history_floor < authorized.history_floor) return error.NoCheckpointIntent;
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    try self.backend.wal.log().trim(0, authorized.history_floor);
    self.cached = null;
}
