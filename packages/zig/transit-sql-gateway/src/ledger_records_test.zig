const std = @import("std");
const g = @import("root.zig");
fn Case(comptime T: type) type {
    return struct { value: T, bytes: []const u8 };
}
test "independent ledger metadata bytes preserve full-width quota and outcome counts" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const Fixture = struct { head: Case(g.LedgerRecords.Head), operation: Case(g.LedgerRecords.Operation), terminal: Case(g.Terminal) };
    const fixture = try std.json.parseFromSlice(Fixture, a, @embedFile("fixtures/records.json"), .{});
    inline for (.{ fixture.value.head, fixture.value.operation, fixture.value.terminal }) |case| {
        const encoded = try g.LedgerRecords.encode(case.value);
        const bytes = try a.alloc(u8, case.bytes.len / 2);
        _ = try std.fmt.hexToBytes(bytes, case.bytes);
        try t.expectEqualSlices(u8, bytes, encoded.slice());
        try t.expectEqualDeep(case.value, try g.LedgerRecords.decode(@TypeOf(case.value), try g.catalog.protocol.Value.init(bytes)));
    }
}
