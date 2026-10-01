//! The only Rey package importing the upstream Ursula client.
const std = @import("std");
const observations = @import("transit_observability");
pub const ursula = @import("ursula");
pub const Store = @import("Store.zig");
pub const PayloadStore = @import("PayloadStore.zig");
pub const PageStore = @import("PageStore.zig");
pub const PackedPageStore = @import("PackedPageStore.zig");
pub const max_record_bytes = 64 * 1024;
pub const read_window = 16;

/// Optional counters owned by the serialized backend caller. They survive log
/// sampling and count attempts, including errors, never unique durable commits.
pub const Metrics = struct {
    requests: u64 = 0,
    failures: u64 = 0,
    elapsed_ns: u64 = 0,
    request_payload_bytes: u64 = 0,
    response_bytes: u64 = 0,
};

test {
    _ = PackedPageStore;
}

/// Borrows its client and stream names. Never implicitly creates missing history.
pub const Journal = struct {
    client: *ursula.Client,
    stream: ursula.Stream,
    observer: ?*observations.telemetry.Runtime = null,
    parent_context: ?observations.telemetry.Context = null,
    metrics: ?*Metrics = null,

    pub fn send(self: Journal, operation: ursula.Operation) !ursula.Response {
        const counters = self.metrics orelse return self.client.send(operation);
        counters.requests +|= 1;
        switch (operation) {
            .append => |value| counters.request_payload_bytes +|= value.body.len,
            .append_batch => |value| for (value.frames) |frame| {
                counters.request_payload_bytes +|= frame.len;
            },
            else => {},
        }
        const started = std.Io.Clock.awake.now(self.client.http.io);
        defer counters.elapsed_ns +|= @intCast(@max(0, started.durationTo(std.Io.Clock.awake.now(self.client.http.io)).toNanoseconds()));
        const result = self.client.send(operation) catch |err| {
            counters.failures +|= 1;
            return err;
        };
        counters.response_bytes +|= result.body.len;
        return result;
    }

    pub fn create(self: Journal) !void {
        var observation = observations.begin(self.observer, .storage_operation, "journal.create", self.parent_context);
        defer observation.finish();
        const result = self.createImpl() catch |err| {
            observation.fail(err);
            return err;
        };
        return result;
    }

    fn createImpl(self: Journal) !void {
        var bucket = try self.send(.{ .create_bucket = self.stream.bucket });
        defer bucket.deinit();
        try bucket.head.requireSuccess();
        var stream = try self.send(.{ .create_stream = .{ .stream = self.stream, .options = .{ .content_type = "application/json" } } });
        defer stream.deinit();
        try stream.head.requireSuccess();
        _ = try self.tail();
    }

    /// HEAD is tail-sensitive. Refuse redirection instead of forwarding credentials.
    pub fn tail(self: Journal) !u64 {
        var observation = observations.begin(self.observer, .storage_operation, "journal.tail", self.parent_context);
        defer observation.finish();
        const result = self.tailImpl() catch |err| {
            observation.fail(err);
            return err;
        };
        return result;
    }

    fn tailImpl(self: Journal) !u64 {
        var response = try self.send(.{ .head = .{ .stream = self.stream } });
        defer response.deinit();
        try response.head.requireSuccess();
        const meta = try response.head.metadata();
        if (!meta.hasExtension("json-record-coordinates-v1")) return error.UnsupportedStorage;
        if (meta.closed orelse false) return error.ClosedJournal;
        return meta.record_next orelse error.MissingRecordCoordinate;
    }

    /// Exactly one object is one protocol record. No producer deduplication: a
    /// conditional-write conflict must not disguise a competing payload as ours.
    pub fn append(self: Journal, expected: u64, object: []const u8) !bool {
        var observation = observations.begin(self.observer, .storage_operation, "journal.append", self.parent_context);
        defer observation.finish();
        const result = self.appendImpl(expected, object) catch |err| {
            observation.fail(err);
            return err;
        };
        if (!result) observation.fail(error.Conflict);
        return result;
    }

    fn appendImpl(self: Journal, expected: u64, object: []const u8) !bool {
        try validateObject(self.client.http.allocator, object);
        var response = try self.send(.{ .append = .{
            .stream = self.stream,
            .body = object,
            .options = .{ .content_type = "application/json", .record_match = expected },
        } });
        defer response.deinit();
        if (response.head.status == .precondition_failed) return false;
        try response.head.requireSuccess();
        const meta = try response.head.metadata();
        if (meta.record_start != expected or meta.record_next != try std.math.add(u64, expected, 1)) return error.InvalidAppendReceipt;
        return true;
    }

    pub fn read(self: Journal, position: u64) !ursula.Response {
        var observation = observations.begin(self.observer, .storage_operation, "journal.read", self.parent_context);
        defer observation.finish();
        const result = self.readImpl(position) catch |err| {
            observation.fail(err);
            return err;
        };
        return result;
    }

    fn readImpl(self: Journal, position: u64) !ursula.Response {
        var response = try self.send(.{ .read = .{
            .stream = self.stream,
            .options = .{ .position = .{ .record = position }, .max_records = read_window },
        } });
        errdefer response.deinit();
        if (response.head.status == .gone) return error.HistoryReclaimed;
        try response.head.requireSuccess();
        const meta = try response.head.metadata();
        const next = meta.record_next orelse return error.MissingRecordCoordinate;
        if (meta.record_start != position or next < position or next - position > read_window) return error.InvalidReadRange;
        return response;
    }
};

pub fn validateObject(allocator: std.mem.Allocator, bytes: []const u8) !void {
    if (bytes.len > max_record_bytes) return error.RecordTooLarge;
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.ExpectedObject;
}

test "one append must be one bounded JSON object" {
    try validateObject(std.testing.allocator, "{\"version\":1}");
    try std.testing.expectError(error.ExpectedObject, validateObject(std.testing.allocator, "[{}]"));
    try std.testing.expectError(error.SyntaxError, validateObject(std.testing.allocator, "{}{}"));
    try std.testing.expectError(error.DuplicateField, validateObject(std.testing.allocator, "{\"x\":1,\"x\":2}"));
}
