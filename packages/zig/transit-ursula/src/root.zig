//! The only Rey package importing the upstream Ursula client.
const std = @import("std");
pub const ursula = @import("ursula");
pub const Store = @import("Store.zig");
pub const max_record_bytes = 64 * 1024;
pub const read_window = 16;

/// Borrows its client and stream names. Never implicitly creates missing history.
pub const Journal = struct {
    client: *ursula.Client,
    stream: ursula.Stream,

    pub fn create(self: Journal) !void {
        var bucket = try self.client.send(.{ .create_bucket = self.stream.bucket });
        defer bucket.deinit();
        try bucket.head.requireSuccess();
        var stream = try self.client.send(.{ .create_stream = .{ .stream = self.stream, .options = .{ .content_type = "application/json" } } });
        defer stream.deinit();
        try stream.head.requireSuccess();
        _ = try self.tail();
    }

    /// HEAD is tail-sensitive. Refuse redirection instead of forwarding credentials.
    pub fn tail(self: Journal) !u64 {
        var response = try self.client.send(.{ .head = .{ .stream = self.stream } });
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
        try validateObject(self.client.http.allocator, object);
        var response = try self.client.send(.{ .append = .{
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
        var response = try self.client.send(.{ .read = .{
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
