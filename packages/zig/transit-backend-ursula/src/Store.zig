//! Bounded journal transport for the explicit development v1 authority profile.
//! Pages are persisted separately; this journal alone publishes their roots.
const std = @import("std");
const growing = @import("transit_core").growing;
const adapter = @import("root.zig");
const observations = @import("transit_observability");
const Self = @This();
pub const Checkpoint = struct { version: u32 = 1, entry: growing.Entry };

journal: adapter.Journal,
cached: ?struct { at: u64, entry: growing.Entry } = null,

pub fn tail(self: *Self) !u64 {
    return self.journal.tail();
}

pub fn append(self: *Self, expected: u64, entry: growing.Entry) !bool {
    try validate(entry, expected);
    var bytes: [adapter.max_record_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    std.json.Stringify.value(entry, .{}, &writer) catch return error.RecordTooLarge;
    return self.journal.append(expected, writer.buffered());
}

pub fn read(self: *Self, at: u64) !?growing.Entry {
    if (self.cached) |cached| if (cached.at == at) return cached.entry;
    var observation = observations.begin(self.journal.observer, .storage_operation, "growing.read", self.journal.parent_context);
    defer observation.finish();
    return self.fetch(at) catch |err| {
        observation.fail(err);
        return err;
    };
}

fn fetch(self: *Self, at: u64) !?growing.Entry {
    // Recovery needs one published head, not a catalog-sized replay buffer.
    var response = try self.journal.client.send(.{ .read = .{
        .stream = self.journal.stream,
        .options = .{ .position = .{ .record = at }, .max_records = 1 },
    } });
    defer response.deinit();
    if (response.head.status == .gone) return error.HistoryReclaimed;
    try response.head.requireSuccess();
    const metadata = try response.head.metadata();
    const next = metadata.record_next orelse return error.MissingRecordCoordinate;
    if (metadata.record_start != at or next < at or next - at > 1) return error.InvalidReadRange;
    if (next == at) {
        if (response.body.len != 0) return error.InvalidFraming;
        return null;
    }
    if (response.body.len > adapter.max_record_bytes) return error.RecordTooLarge;
    // Every field is owned, so no parsed arena is retained by the cache.
    const parsed = try std.json.parseFromSlice(growing.Entry, self.journal.client.http.allocator, response.body, .{});
    defer parsed.deinit();
    try validate(parsed.value, at);
    self.cached = .{ .at = at, .entry = parsed.value };
    return parsed.value;
}

fn validate(entry: growing.Entry, at: u64) !void {
    const value_head = switch (entry) {
        .genesis => |value| blk: {
            if (at != 0 or value.genesis.version != 1) return error.UnsupportedHistory;
            break :blk value.head;
        },
        .operation => |value| blk: {
            if (at == 0 or value.position != at) return error.InvalidPosition;
            if (value.request.version != 1) return error.UnsupportedHistory;
            break :blk value.next;
        },
    };
    if (value_head.version != 1) return error.UnsupportedHistory;
    if (value_head.position != try std.math.add(u64, at, 1)) return error.InvalidPosition;
    if (value_head.history_floor >= value_head.position) return error.InvalidHistory;
    try value_head.catalog.validate();
}

fn head(entry: growing.Entry) growing.Head {
    return switch (entry) {
        .genesis => |value| value.head,
        .operation => |value| value.next,
    };
}

pub fn loadCheckpoint(self: *Self) !?Checkpoint {
    var latest = try self.journal.client.send(.{ .read_snapshot = .{ .stream = self.journal.stream } });
    defer latest.deinit();
    if (latest.head.status == .not_found) return null;
    if (latest.head.status != .temporary_redirect) return error.InvalidSnapshotResponse;
    // The configured stream and opaque offset are authoritative, never a
    // provider-controlled Location URL to which credentials could be forwarded.
    const offset = (try latest.head.metadata()).snapshot_offset orelse return error.MissingSnapshotOffset;
    var response = try self.journal.client.send(.{ .read_snapshot = .{ .stream = self.journal.stream, .offset = offset } });
    defer response.deinit();
    try response.head.requireSuccess();
    if (response.body.len > adapter.max_record_bytes) return error.RecordTooLarge;
    const parsed = try std.json.parseFromSlice(Checkpoint, self.journal.client.http.allocator, response.body, .{});
    defer parsed.deinit();
    if (parsed.value.version != 1) return error.UnsupportedHistory;
    const snapshot = head(parsed.value.entry);
    if (snapshot.position == 0 or snapshot.history_floor == 0) return error.InvalidCheckpoint;
    try validate(parsed.value.entry, snapshot.position - 1);
    return parsed.value;
}

/// Privileged maintenance of an already committed core intent. No page GC.
/// Publication is verified before prefix trim; repeated calls do not write.
pub fn maintain(self: *Self, authorized: growing.Head) !void {
    var observation = observations.begin(self.journal.observer, .storage_operation, "growing.maintain", self.journal.parent_context);
    defer observation.finish();
    return self.maintainImpl(authorized) catch |err| {
        observation.fail(err);
        return err;
    };
}
fn maintainImpl(self: *Self, authorized: growing.Head) !void {
    if (authorized.history_floor == 0 or authorized.history_floor >= authorized.position) return error.NoCheckpointIntent;
    // Derive permission from the current durable head. A stale worker cannot
    // manufacture a retention floor or use an uncommitted candidate root.
    const tail_position = try self.tail();
    if (tail_position == 0) return error.InvalidHistory;
    const current = (try self.read(tail_position - 1)) orelse return error.IncompleteHistory;
    const current_head = head(current);
    if (!std.mem.eql(u8, &current_head.genesis, &authorized.genesis) or
        current_head.history_floor < authorized.history_floor or
        current_head.position < authorized.position) return error.NoCheckpointIntent;
    const existing = try self.loadCheckpoint();
    if (existing) |value| {
        const saved = head(value.entry);
        if (saved.position > tail_position or !std.mem.eql(u8, &saved.genesis, &current_head.genesis)) return error.InvalidCheckpoint;
    }
    if (existing == null or head(existing.?.entry).history_floor < authorized.history_floor) {
        var bytes: [adapter.max_record_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        std.json.Stringify.value(Checkpoint{ .entry = current }, .{}, &writer) catch return error.RecordTooLarge;
        var published = try self.journal.client.send(.{ .publish_snapshot = .{ .stream = self.journal.stream, .at = .{ .record = tail_position }, .body = writer.buffered(), .content_type = "application/json" } });
        defer published.deinit();
        try published.head.requireSuccess();
        const saved = head((try self.loadCheckpoint() orelse return error.MissingCheckpoint).entry);
        if (saved.position < tail_position or saved.position > try self.tail() or saved.history_floor < authorized.history_floor or
            !std.mem.eql(u8, &saved.genesis, &current_head.genesis)) return error.StaleCheckpoint;
    }
    var metadata = try self.journal.client.send(.{ .head = .{ .stream = self.journal.stream } });
    defer metadata.deinit();
    try metadata.head.requireSuccess();
    if (((try metadata.head.metadata()).record_first orelse return error.MissingRecordCoordinate) >= authorized.history_floor) {
        self.cached = null;
        return;
    }
    var trimmed = try self.journal.client.send(.{ .advance_retention = .{ .stream = self.journal.stream, .at = .{ .record = authorized.history_floor } } });
    defer trimmed.deinit();
    try trimmed.head.requireSuccess();
    self.cached = null;
}
