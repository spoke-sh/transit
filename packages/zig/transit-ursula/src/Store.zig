//! Transit store contract over Ursula JSON record coordinates.
const std = @import("std");
const transit = @import("transit");
const adapter = @import("root.zig");
const Store = @This();

journal: adapter.Journal,
cache: [adapter.read_window]transit.Entry = undefined,
cache_start: u64 = 0,
cache_len: usize = 0,

pub fn tail(self: *Store) !u64 {
    return self.journal.tail();
}

pub fn append(self: *Store, expected: u64, entry: transit.Entry) !bool {
    const allocator = self.journal.client.http.allocator;
    const bytes = try std.json.Stringify.valueAlloc(allocator, entry, .{});
    defer allocator.free(bytes);
    if (bytes.len > transit.max_entry_bytes) return error.RecordTooLarge;
    return self.journal.append(expected, bytes);
}

pub fn read(self: *Store, at: u64) !?transit.Entry {
    if (at >= self.cache_start and at - self.cache_start < self.cache_len) return self.cache[@intCast(at - self.cache_start)];
    var response = try self.journal.read(at);
    defer response.deinit();
    const next = (try response.head.metadata()).record_next.?;
    self.cache_start = at;
    self.cache_len = 0;
    errdefer self.cache_len = 0;
    var lines = std.mem.splitScalar(u8, response.body, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            if (lines.peek() != null) return error.InvalidFraming;
            break;
        }
        if (line.len > adapter.max_record_bytes or self.cache_len == adapter.read_window) return error.RecordTooLarge;
        var parsed = try std.json.parseFromSlice(transit.Entry, self.journal.client.http.allocator, line, .{});
        defer parsed.deinit();
        const position = at + self.cache_len;
        if (parsed.value == .genesis) {
            if (position != 0) return error.InvalidHistory;
        } else if (parsed.value.operation.position != position) return error.InvalidPosition;
        self.cache[self.cache_len] = parsed.value;
        self.cache_len += 1;
    }
    if (self.cache_len != next - at) {
        self.cache_len = 0;
        return error.InvalidFraming;
    }
    return if (self.cache_len == 0) null else self.cache[0];
}

pub fn loadCheckpoint(self: *Store, genesis: transit.Genesis) !?transit.Checkpoint {
    var latest = try self.journal.client.send(.{ .read_snapshot = .{ .stream = self.journal.stream } });
    defer latest.deinit();
    if (latest.head.status == .not_found) return null;
    if (latest.head.status != .temporary_redirect) return error.InvalidSnapshotResponse;
    // Follow only the opaque snapshot offset on the configured stream, never an
    // arbitrary Location URL that could leak privileged storage credentials.
    const offset = (try latest.head.metadata()).snapshot_offset orelse return error.MissingSnapshotOffset;
    var response = try self.journal.client.send(.{ .read_snapshot = .{ .stream = self.journal.stream, .offset = offset } });
    defer response.deinit();
    try response.head.requireSuccess();
    var parsed = try std.json.parseFromSlice(transit.Checkpoint, self.journal.client.http.allocator, response.body, .{});
    defer parsed.deinit();
    try parsed.value.validate(self.journal.client.http.allocator, genesis);
    return parsed.value;
}

/// Reconcile an already committed checkpoint intent. Publication is verified
/// before logical retention moves; every step can be retried after a crash.
pub fn publishCheckpoint(self: *Store, checkpoint: transit.Checkpoint) !void {
    const allocator = self.journal.client.http.allocator;
    try checkpoint.validate(allocator, checkpoint.genesis);
    if (try self.loadCheckpoint(checkpoint.genesis)) |existing| {
        if (existing.state.position >= checkpoint.state.position and existing.state.history_floor >= checkpoint.state.history_floor) return;
    }
    const bytes = try std.json.Stringify.valueAlloc(allocator, checkpoint, .{});
    defer allocator.free(bytes);
    if (bytes.len > transit.max_checkpoint_bytes) return error.CheckpointTooLarge;
    var published = try self.journal.client.send(.{ .publish_snapshot = .{
        .stream = self.journal.stream,
        .at = .{ .record = checkpoint.state.position },
        .body = bytes,
        .content_type = "application/json",
    } });
    defer published.deinit();
    try published.head.requireSuccess();
    const verified = (try self.loadCheckpoint(checkpoint.genesis)) orelse return error.MissingCheckpoint;
    if (verified.state.position < checkpoint.state.position or verified.state.history_floor < checkpoint.state.history_floor) return error.StaleCheckpoint;
}

pub fn maintain(self: *Store, checkpoint: transit.Checkpoint) !void {
    try checkpoint.validate(self.journal.client.http.allocator, checkpoint.genesis);
    const existing = try self.loadCheckpoint(checkpoint.genesis);
    // A checkpoint covering the committed floor plus its retained tail is a
    // complete recovery basis. Restart must not republish the same maintenance
    // intent at ever-newer tails and consume reserved disk indefinitely.
    if (existing == null or existing.?.state.history_floor < checkpoint.state.history_floor)
        try self.publishCheckpoint(checkpoint);
    var head = try self.journal.client.send(.{ .head = .{ .stream = self.journal.stream } });
    defer head.deinit();
    try head.head.requireSuccess();
    if (((try head.head.metadata()).record_first orelse return error.MissingRecordCoordinate) >= checkpoint.state.history_floor) {
        self.cache_len = 0;
        return;
    }
    var trimmed = try self.journal.client.send(.{ .advance_retention = .{ .stream = self.journal.stream, .at = .{ .record = checkpoint.state.history_floor } } });
    defer trimmed.deinit();
    try trimmed.head.requireSuccess();
    self.cache_len = 0;
}
