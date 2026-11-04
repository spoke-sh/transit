const std = @import("std");
const g = @import("root.zig").wire;
const Scalar = @import("Scalar.zig");
const Atom = g.fuze.Types.Values.Atom;
const Case = struct {
    kind: std.meta.Tag(g.Type.Kind),
    value: []const u8,
    binary: []const u8,
    text: []const u8,
    precision: u8 = 38,
    scale: u8 = 0,
    fn logical(self: Case) g.Type.Kind {
        return switch (self.kind) {
            .decimal => .{ .decimal = .{ .precision = self.precision, .scale = self.scale } },
            inline else => |tag| @unionInit(g.Type.Kind, @tagName(tag), {}),
        };
    }
};
fn unhex(a: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const out = try a.alloc(u8, bytes.len / 2);
    return std.fmt.hexToBytes(out, bytes);
}
fn expected(a: std.mem.Allocator, case: Case) !Atom {
    return switch (case.kind) {
        .int8, .int16, .int32, .int64 => .{ .signed = try std.fmt.parseInt(i64, case.value, 10) },
        .uint8, .uint16, .uint32, .uint64 => .{ .unsigned = try std.fmt.parseInt(u64, case.value, 10) },
        .float32, .float64 => .{ .float = try std.fmt.parseFloat(f64, case.value) },
        .decimal => .{ .decimal = try std.fmt.parseInt(i128, case.value, 10) },
        .boolean => .{ .boolean = std.mem.eql(u8, case.value, "true") },
        .utf8, .binary => .{ .bytes = try unhex(a, case.value) },
    };
}
fn same(want: Atom, got: Atom) !void {
    switch (want) {
        .bytes => |value| try std.testing.expectEqualSlices(u8, value, got.bytes),
        .float => |value| try std.testing.expectEqual(@as(u64, @bitCast(value)), @as(u64, @bitCast(got.float))),
        else => try std.testing.expectEqualDeep(want, got),
    }
}
test "independent PostgreSQL scalar corpus validates text and binary values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cases = try std.json.parseFromSlice([]const Case, a, @embedFile("fixtures/scalars.json"), .{});
    for (cases.value) |case| {
        const want = try expected(a, case);
        const binary = try unhex(a, case.binary);
        const text = try unhex(a, case.text);
        const oid = Scalar.descriptor(case.logical()).oid;
        try same(want, (try Scalar.decode(a, case.logical(), oid, .binary, binary)).?);
        try same(want, (try Scalar.decode(a, case.logical(), oid, .text, text)).?);
        var out: std.ArrayList(u8) = .empty;
        try Scalar.encode(a, &out, case.logical(), .binary, want);
        try std.testing.expectEqualSlices(u8, binary, out.items);
        out.clearRetainingCapacity();
        try Scalar.encode(a, &out, case.logical(), .text, want);
        try same(want, (try Scalar.decode(a, case.logical(), oid, .text, out.items)).?);
    }
}
