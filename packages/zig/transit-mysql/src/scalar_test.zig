const std = @import("std");
const g = @import("root.zig").gateway;
const Scalar = @import("Scalar.zig");
const Codec = @import("Codec.zig");
const Atom = g.fuze.Types.Values.Atom;
const Case = struct { kind: g.Type.Kind, value: []const u8, binary: []const u8, text: []const u8 };
fn unhex(a: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const out = try a.alloc(u8, bytes.len / 2);
    return std.fmt.hexToBytes(out, bytes);
}
fn expected(a: std.mem.Allocator, case: Case) !Atom {
    return switch (case.kind) {
        .int64 => .{ .signed = try std.fmt.parseInt(i64, case.value, 10) },
        .uint64 => .{ .unsigned = try std.fmt.parseInt(u64, case.value, 10) },
        .float64 => .{ .float = try std.fmt.parseFloat(f64, case.value) },
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
test "independent MySQL corpus preserves full width, signed zero and binary NUL" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cases = try std.json.parseFromSlice([]const Case, a, @embedFile("fixtures/scalars.json"), .{});
    for (cases.value) |case| {
        const want = try expected(a, case);
        const binary = try unhex(a, case.binary);
        const metadata = Scalar.descriptor(.{ .kind = case.kind, .nullable = true }, 309);
        var reader: Codec.Reader = .{ .bytes = binary };
        try same(want, (try Scalar.decode(&reader, case.kind, .{ .code = metadata.code, .unsigned = metadata.flags & 32 != 0 })).?);
        try reader.finish();
        var out: std.ArrayList(u8) = .empty;
        try Scalar.encode(a, &out, case.kind, want);
        try std.testing.expectEqualSlices(u8, binary, out.items);
        out.clearRetainingCapacity();
        try Scalar.text(a, &out, case.kind, want);
        reader = .{ .bytes = out.items };
        const rendered = try Codec.string(&reader, g.Limits.max_frame_bytes);
        try reader.finish();
        if (case.kind == .float64) {
            try same(want, .{ .float = try std.fmt.parseFloat(f64, rendered) });
        } else try std.testing.expectEqualSlices(u8, try unhex(a, case.text), out.items);
    }
}
