const std = @import("std");
const t = std.testing;
const c = @import("OrderedChange.zig");
const hash = @import("LogicalChange.zig").hash;

test "ordered canonical trees preserve duplicate names exact numbers and raw spans" {
    const raw = "{\"x\":12345678901234567890,\"x\":null}";
    const nodes = [_]c.Node{
        .{ .depth = 0, .kind = .map },
        .{ .depth = 1, .kind = .number, .name = "x", .value = "12345678901234567890", .span = .{ .part = 9, .start = 5, .end = 25 } },
        .{ .depth = 1, .kind = .null_value, .name = "x" },
    };
    const header: c.Header = .{ .definition = @splat(1), .document = @splat(2), .epoch = 1, .expected_revision = 0, .nodes = nodes.len, .parts = 1 };
    var bytes: [1024]u8 = undefined;
    const encoded = try c.encode(header, &.{.{ .id = 9, .bytes = raw, .digest = hash(raw) }}, &nodes, &bytes);
    // Independent prefix and offsets: fixed header before the part directory.
    try t.expectEqualStrings("DORDER01", encoded[0..8]);
    try t.expectEqual(@as(u64, 1), std.mem.readInt(u64, encoded[56..64], .little));
    try t.expectEqual(@as(u16, 0), std.mem.readInt(u16, encoded[72..74], .little));
    try t.expectEqual(@as(u32, 3), std.mem.readInt(u32, encoded[74..78], .little));
    var decoder = try c.Decoder.init(encoded);
    try t.expectEqualStrings(raw, (try decoder.nextPart()).?.bytes);
    try t.expect((try decoder.nextPart()) == null);
    var frames: [4]c.Frame = undefined;
    var validator: c.Validator = .{ .frames = &frames };
    for (nodes) |expected| {
        const actual = (try decoder.next()).?;
        try t.expectEqualDeep(expected, actual);
        try validator.push(actual);
    }
    try validator.finish();
    try t.expect((try decoder.next()) == null);
    // Every truncated prefix must fail before a verified complete tree.
    for (0..encoded.len) |length| {
        var partial = c.Decoder.init(encoded[0..length]) catch continue;
        var failed = false;
        while (true) {
            const value = partial.nextPart() catch {
                failed = true;
                break;
            };
            if (value == null) break;
        }
        if (!failed) while (true) {
            const value = partial.next() catch {
                failed = true;
                break;
            };
            if (value == null) break;
        };
        try t.expect(failed);
    }
    bytes[126] ^= 1; // first raw-part byte
    var corrupt = try c.Decoder.init(encoded);
    try t.expectError(error.InvalidOrderedPart, corrupt.nextPart());
}

test "ordered tree validates hierarchy conflicts lexical numbers and bounded depth" {
    var frames: [3]c.Frame = undefined;
    var v: c.Validator = .{ .frames = &frames };
    try t.expectError(error.InvalidOrderedTree, v.push(.{ .depth = 1, .kind = .map }));
    try v.push(.{ .depth = 0, .kind = .map });
    try v.push(.{ .depth = 1, .kind = .conflict });
    try v.push(.{ .depth = 2, .kind = .null_value });
    try v.push(.{ .depth = 2, .kind = .string, .value = "a" });
    try v.finish();
    try t.expectEqual(@as(u32, 1), v.conflicts);
    v = .{ .frames = &frames };
    try v.push(.{ .depth = 0, .kind = .string });
    try t.expectError(error.InvalidOrderedTree, v.push(.{ .depth = 1, .kind = .map }));
    v = .{ .frames = &frames };
    try v.push(.{ .depth = 0, .kind = .map });
    try t.expectError(error.InvalidOrderedTree, v.push(.{ .depth = 2, .kind = .map }));
    try t.expectError(error.DocumentDepthLimitExceeded, v.push(.{ .depth = 3, .kind = .map }));
    for ([_][]const u8{ "01", "+1", "1.", "1e", "NaN", "--1", "" }) |text| try t.expectError(error.InvalidOrderedNode, (c.Node{ .depth = 0, .kind = .number, .value = text }).validate());
    for ([_][]const u8{ "0", "-0", "1.25", "-9E+123456", "123456789012345678901234567890" }) |text| try (c.Node{ .depth = 0, .kind = .number, .value = text }).validate();
}
