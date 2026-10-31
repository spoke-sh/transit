const std = @import("std");
const m = @import("root.zig");
fn bytes(hex: []const u8) ![]u8 {
    const result = try std.testing.allocator.alloc(u8, hex.len / 2);
    errdefer std.testing.allocator.free(result);
    _ = try std.fmt.hexToBytes(result, hex);
    return result;
}
fn check(hex: []const u8, actual: []const u8) !void {
    const expected = try bytes(hex);
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, actual);
}
test "independent MySQL handshake, metadata, text/binary rows and command reply bytes" {
    const t = std.testing;
    const Fixtures = struct { metadata: []const []const u8, binary_row: []const u8, text_row: []const u8, maximum_ok: []const u8, eof: []const u8, terminator: []const u8, prepared: []const u8, failure: []const u8, greeting: []const u8, full_auth: []const u8, upgrade: []const u8, response: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixtures, t.allocator, @embedFile("fixtures/backend.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    const columns = [_]m.Backend.Column{
        .{ .name = "n", .type = .{ .kind = .uint64, .nullable = false } },
        .{ .name = "label", .type = .{ .kind = .utf8, .nullable = true } },
        .{ .name = "bytes", .type = .{ .kind = .binary, .nullable = false } },
        .{ .name = "f", .type = .{ .kind = .float64, .nullable = false } },
        .{ .name = "b", .type = .{ .kind = .boolean, .nullable = false } },
        .{ .name = "i", .type = .{ .kind = .int64, .nullable = false } },
    };
    const cells = [_]m.wire.fuze.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } }, .null,
        .{ .value = .{ .atom = .{ .bytes = "a\x00\xff" } } },             .{ .value = .{ .atom = .{ .float = -1.25 } } },
        .{ .value = .{ .atom = .{ .boolean = true } } },                  .{ .value = .{ .atom = .{ .signed = std.math.minInt(i64) } } },
    };
    var backend: m.Backend = .{ .allocator = t.allocator };
    defer backend.deinit();
    for (fixture.metadata, columns) |expected, column| {
        backend.sequence = 1;
        try check(expected, try backend.describe(column));
    }
    backend.sequence = 1;
    try check(fixture.binary_row, try backend.row(&columns, &cells, true));
    backend.sequence = 1;
    try check(fixture.text_row, try backend.row(&columns, &cells, false));
    backend.sequence = 1;
    try check(fixture.maximum_ok, try backend.ok(std.math.maxInt(u64), false));
    backend.sequence = 1;
    try check(fixture.eof, try backend.eof());
    backend.sequence = 1;
    try check(fixture.terminator, try backend.ok(0, true));
    backend.sequence = 1;
    try check(fixture.prepared, try backend.prepared(42, 6, 2));
    backend.sequence = 1;
    try check(fixture.failure, try backend.failure(1317, "70100".*, "Request cancelled"));
    backend.sequence = 0;
    var nonce: [20]u8 = undefined;
    for (&nonce, 1..) |*value, i| value.* = @intCast(i);
    try check(fixture.greeting, try backend.greeting(42, nonce, m.Handshake.capabilities));
    try check(fixture.full_auth, try backend.fullAuthentication());
    const request = try bytes(fixture.upgrade);
    defer t.allocator.free(request);
    const response = try bytes(fixture.response);
    defer t.allocator.free(response);
    const handshake = try m.Handshake.response(response, try m.Handshake.upgrade(request));
    try t.expectEqualStrings("user", handshake.account);
    try t.expectEqualStrings("database", handshake.database.?);
    try t.expectEqualSlices(u8, &@as([32]u8, @splat(3)), handshake.proof);
}
