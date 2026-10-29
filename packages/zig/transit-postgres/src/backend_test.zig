const std = @import("std");
const pg = @import("root.zig");
fn check(expected: []const u8, actual: []const u8) !void {
    const bytes = try std.testing.allocator.alloc(u8, expected.len / 2);
    defer std.testing.allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, expected);
    try std.testing.expectEqualSlices(u8, bytes, actual);
}
test "independent PostgreSQL backend frames cover metadata, binary NULL, uint64 and classified failures" {
    const t = std.testing;
    const Fixtures = struct { ready: []const u8, mechanisms: []const u8, parameters: []const u8, metadata: []const u8, binary_row: []const u8, text_row: []const u8, max_update: []const u8, failure: []const u8, negotiate: []const u8 };
    const fixtures = try std.json.parseFromSlice(Fixtures, t.allocator, @embedFile("fixtures/backend.json"), .{});
    defer fixtures.deinit();
    const expected = fixtures.value;
    var backend: pg.Backend = .{ .allocator = t.allocator };
    defer backend.deinit();
    try check(expected.ready, try backend.ready(.idle));
    try check(expected.mechanisms, try backend.authenticate(.mechanisms, ""));
    try check(expected.parameters, try backend.parameters(&.{ 1700, 25 }));
    var formats: pg.Frontend.Formats = .{ .count = 1 };
    formats.values[0] = .binary;
    const columns = [_]pg.Backend.Column{ .{ .name = "value", .type = .{ .kind = .uint64, .nullable = false } }, .{ .name = "label", .type = .{ .kind = .utf8, .nullable = true } } };
    const cells = [_]pg.gateway.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } }, .null };
    try check(expected.metadata, try backend.describe(&columns, &formats));
    try check(expected.binary_row, try backend.row(&columns, &formats, &cells));
    formats.count = 0;
    try check(expected.text_row, try backend.row(&columns, &formats, &cells));
    try check(expected.max_update, try backend.complete(.update, std.math.maxInt(u64)));
    try check(expected.failure, try backend.failure(false, "57014".*, "Request cancelled", null));
    try check(expected.negotiate, try backend.negotiate(&.{"_pq_.unsupported"}));
}
