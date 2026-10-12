const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const m = q.RelationalMaintenanceRecords;
fn hex(expected: []const u8, value: q.protocol.Value) !void {
    var bytes: [q.protocol.Value.max_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, expected), value.slice());
}
fn rejects(comptime T: type, value: q.protocol.Value) !void {
    for (0..value.len) |length| {
        if (T.decode(try q.protocol.Value.init(value.slice()[0..length]))) |_| return error.AcceptedTruncatedRecord else |_| {}
    }
    var wrong = value;
    wrong.data[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, T.decode(wrong));
    wrong = value;
    wrong.data[wrong.len] = 0;
    wrong.len += 1;
    try t.expectError(error.InvalidMaintainedRecord, T.decode(wrong));
}
test "maintained control and work records match independent bytes and reject missing definitions" {
    const Fixture = struct { definition: []const u8, delta: []const u8, head: []const u8, work: []const u8, continuation: []const u8, key: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/relational-maintenance.json"), .{});
    defer parsed.deinit();
    try t.expectEqualStrings(@tagName(q.protocol.Growth.current_definition), parsed.value.definition);
    const head: m.Head = .{ .id = 11, .peer = 3, .correlation = 5, .policy_revision = 1, .request = .{ .resource = 7, .domain = .query_request, .namespace = 9, .record = 1, .spec = .{ .format = q.RelationalBundle.format, .length = 100, .digest = @splat(17) } }, .request_version = .{ .pid = 3, .input = 11, .index = 0 }, .continuation = 11, .positions = .{ 17, 19 }, .count = 2, .preference = 1 };
    try hex(parsed.value.head, try head.encode());
    try hex(parsed.value.key, head.identity().address());
    try t.expectEqualDeep(head, try m.Head.decode(try head.encode()));
    try rejects(m.Head, try head.encode());
    const work: m.Work = .{ .revision = 1, .next_record = 1, .state_bytes = 0 };
    try hex(parsed.value.work, try work.encode());
    try t.expectEqualDeep(work, try m.Work.decode(try work.encode()));
    try rejects(m.Work, try work.encode());
    const continuation: m.Continuation = .{ .identity = head.identity(), .input = 11 };
    try hex(parsed.value.continuation, try continuation.encode());
    try t.expectEqualDeep(continuation, try m.Continuation.decode(try continuation.encode()));
    try rejects(m.Continuation, try continuation.encode());
    const delta: m.Delta = .{ .ordinal = 3, .reference = .{ .resource = 7, .domain = .query_result, .namespace = 9, .record = 2, .spec = .{ .format = m.delta_format, .length = 100, .digest = @splat(17) } } };
    try hex(parsed.value.delta, try delta.encode());
    try t.expectEqualDeep(delta, try m.Delta.decode(try delta.encode()));
    try rejects(m.Delta, try delta.encode());
    var invalid = head;
    invalid.phase = .idle;
    try t.expectError(error.InvalidMaintainedRecord, invalid.encode());
    invalid = head;
    invalid.released = true;
    try t.expectError(error.InvalidMaintainedRecord, invalid.encode());
    var missing = work;
    missing.phase = .delta;
    try t.expectError(error.InvalidMaintainedRecord, missing.encode());
    missing = work;
    missing.outputs = 1;
    try t.expectError(error.InvalidMaintainedRecord, missing.encode());
}
