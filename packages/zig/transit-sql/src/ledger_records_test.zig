const std = @import("std");
const g = @import("root.zig");
fn Case(comptime T: type) type {
    return struct { value: T, bytes: []const u8 };
}
test "independent native gateway controls encode complete unsigned counts and padded parts" {
    const t = std.testing;
    const fixtures = try std.json.parseFromSlice([]const Case(g.Control.Command), t.allocator, @embedFile("fixtures/controls.json"), .{});
    defer fixtures.deinit();
    for (fixtures.value) |case| {
        const bytes = try t.allocator.alloc(u8, case.bytes.len / 2);
        defer t.allocator.free(bytes);
        _ = try std.fmt.hexToBytes(bytes, case.bytes);
        try t.expectEqualSlices(u8, bytes, (try case.value.encode()).slice());
        try t.expectEqualDeep(case.value, try g.Control.Command.decode(try g.catalog.protocol.Value.init(bytes)));
    }
}
test "independent ledger metadata bytes preserve full-width quota and outcome counts" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const Fixture = struct { head: Case(g.LedgerRecords.Head), operation: Case(g.LedgerRecords.Operation), terminal: Case(g.Terminal), assertion: Case(g.Terminal) };
    const fixture = try std.json.parseFromSlice(Fixture, a, @embedFile("fixtures/records.json"), .{});
    inline for (.{ fixture.value.head, fixture.value.operation, fixture.value.terminal, fixture.value.assertion }) |case| {
        const encoded = try g.LedgerRecords.encode(case.value);
        const bytes = try a.alloc(u8, case.bytes.len / 2);
        _ = try std.fmt.hexToBytes(bytes, case.bytes);
        try t.expectEqualSlices(u8, bytes, encoded.slice());
        try t.expectEqualDeep(case.value, try g.LedgerRecords.decode(@TypeOf(case.value), try g.catalog.protocol.Value.init(bytes)));
    }
}
