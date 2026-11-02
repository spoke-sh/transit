const std = @import("std");
const t = std.testing;
const m = @import("Types.zig");
const s = m.Semantics;
const nested: m.Type = .{ .structure = &.{
    .{ .name = "id", .type = .uint128 },
    .{ .name = "price", .type = .{ .decimal = .{ .precision = 38, .scale = 9 } }, .nullable = true },
    .{ .name = "values", .type = .{ .list = .{ .type = &.utf8, .nullable = true } }, .optional = true },
} };
fn roundtrip(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var decoded = try m.decode(allocator, bytes);
    defer decoded.deinit();
    try t.expect(try nested.eql(decoded.type));
}
test "logical descriptors own decoded names and reject incompatible incomplete or unbounded trees" {
    var buffer: [m.max_encoding_bytes]u8 = undefined;
    const bytes = try nested.encode(&buffer);
    try t.checkAllAllocationFailures(t.allocator, roundtrip, .{bytes});
    for (0..bytes.len) |length| {
        if (m.decode(t.allocator, bytes[0..length])) |owned| {
            var owner = owned;
            owner.deinit();
            return error.AcceptedTruncation;
        } else |_| {}
    }
    buffer[bytes.len] = 0;
    try t.expectError(error.InvalidTypeEncoding, m.decode(t.allocator, buffer[0 .. bytes.len + 1]));
    buffer[5] ^= 1;
    try t.expectError(error.IncompatibleDefinition, m.decode(t.allocator, bytes));
    const previous = "transit.fuze.types.v1.2026-09-30";
    const retired = "FTY1" ++ [_]u8{previous.len} ++ previous ++ "\x01";
    try t.expectError(error.IncompatibleDefinition, m.decode(t.allocator, retired));
    try t.expectError(error.TypeBudgetExceeded, nested.validate(.{ .depth = 2 }));
    try t.expectError(error.TypeBudgetExceeded, nested.validate(.{ .nodes = 2 }));
    const duplicate: m.Type = .{ .structure = &.{ .{ .name = "x", .type = .int8 }, .{ .name = "x", .type = .int16 } } };
    try t.expectError(error.DuplicateField, duplicate.validate(.{}));
    var cycle: m.Type = undefined;
    cycle = .{ .list = .{ .type = &cycle } };
    try t.expectError(error.TypeBudgetExceeded, cycle.validate(.{}));
}
fn cloneAfterRelease(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var copy = blk: {
        var original = try m.decode(t.allocator, bytes);
        defer original.deinit();
        break :blk try original.type.clone(allocator);
    };
    defer copy.deinit();
    var buffer: [m.max_encoding_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try copy.type.encode(&buffer));
}
test "descriptor copies own recursive children after source release and clean up every allocation failure" {
    const descriptor: m.Type = .{ .structure = &.{
        .{ .name = "nested", .type = nested, .nullable = true },
        .{ .name = "array", .type = .{ .array = .{ .length = 17, .element = .{ .type = &.{ .timestamp = .utc }, .nullable = true } } } },
        .{ .name = "map", .type = .{ .map = .{ .key = &.binary, .value = .{ .type = &.{ .list = .{ .type = &.int8 } }, .nullable = true } } }, .optional = true },
        .{ .name = "union", .type = .{ .tagged_union = &.{ .{ .name = "left", .type = .{ .timestamp = .civil } }, .{ .name = "right", .type = nested, .nullable = true } } } },
    } };
    var buffer: [m.max_encoding_bytes]u8 = undefined;
    try t.checkAllAllocationFailures(t.allocator, cloneAfterRelease, .{try descriptor.encode(&buffer)});
    const duplicate: m.Type = .{ .structure = &.{ .{ .name = "x", .type = .int8 }, .{ .name = "x", .type = .int16 } } };
    try t.expectError(error.DuplicateField, duplicate.clone(t.allocator));
    const invalid: m.Type = .{ .array = .{ .length = 0, .element = .{ .type = &.int64 } } };
    try t.expectError(error.InvalidArrayLength, invalid.clone(t.allocator));
    var cycle: m.Type = undefined;
    cycle = .{ .list = .{ .type = &cycle } };
    try t.expectError(error.TypeBudgetExceeded, cycle.clone(t.allocator));
}
test "descriptor copies preserve default node and name budgets at their boundaries" {
    var names: [17][255]u8 = @splat(@splat('x'));
    var fields: [17]m.Field = undefined;
    for (&fields, 0..) |*field, i| {
        names[i][0] = 'A' + @as(u8, @intCast(i));
        field.* = .{ .name = names[i][0..if (i == 16) @as(usize, 16) else 255], .type = .int64 };
    }
    var buffer: [m.max_encoding_bytes]u8 = undefined;
    const descriptor: m.Type = .{ .structure = &fields };
    try cloneAfterRelease(t.allocator, try descriptor.encode(&buffer));
    fields[16].name = names[16][0..17];
    try t.expectError(error.TypeBudgetExceeded, descriptor.clone(t.allocator));

    var node_names: [255][2]u8 = undefined;
    var nodes: [255]m.Field = undefined;
    for (&nodes, 0..) |*field, i| {
        node_names[i] = std.fmt.bytesToHex(&[_]u8{@intCast(i)}, .lower);
        field.* = .{ .name = &node_names[i], .type = .int64 };
    }
    const full: m.Type = .{ .structure = &nodes };
    try cloneAfterRelease(t.allocator, try full.encode(&buffer));
    nodes[0].type = .{ .list = .{ .type = &.int64 } };
    try t.expectError(error.TypeBudgetExceeded, full.clone(t.allocator));
}
test "exact literals and casts preserve integer bits and require explicit rounding" {
    try t.expectEqual(std.math.maxInt(u128), (try s.bind("340282366920938463463374607431768211455", .uint128)).unsigned);
    try t.expectEqual(std.math.minInt(i128), (try s.bind("-170141183460469231731687303715884105728", .int128)).signed);
    try t.expectError(error.Overflow, s.bind("256", .uint8));
    try t.expectError(error.InvalidLiteral, s.bind("1_000", .int64));
    try t.expectError(error.Inexact, s.cast(.{ .unsigned = 9007199254740993 }, .uint64, .float64, .reject));
    try t.expectEqual(@as(f64, 9007199254740992), (try s.cast(.{ .unsigned = 9007199254740993 }, .uint64, .float64, .nearest_even)).float);
    const d: m.Type = .{ .decimal = .{ .precision = 6, .scale = 2 } };
    try t.expectEqual(@as(i128, -12345), (try s.bind("-123.45", d)).decimal);
    try t.expectError(error.Inexact, s.bind("1.005", d));
    const cents: m.Type = .{ .decimal = .{ .precision = 3, .scale = 1 } };
    try t.expectEqual(@as(i128, 12), (try s.cast(.{ .decimal = 125 }, d, cents, .nearest_even)).decimal);
    try t.expectEqual(@as(i128, -14), (try s.cast(.{ .decimal = -135 }, d, cents, .nearest_even)).decimal);
    try t.expectError(error.Overflow, s.bind("9999.99", .{ .decimal = .{ .precision = 5, .scale = 2 } }));
    try t.expectEqual(@as(u64, 1) << 63, @as(u64, @bitCast((try s.bind("-0.0", .float64)).float)));
}
test "integer float casts preserve exactness at the full signed and unsigned boundaries" {
    for ([_]m.Type{ .float32, .float64 }) |target| {
        try t.expectEqual(@as(f64, -0x1p127), (try s.cast(.{ .signed = std.math.minInt(i128) }, .int128, target, .reject)).float);
        try t.expectError(error.Inexact, s.cast(.{ .signed = std.math.minInt(i128) + 1 }, .int128, target, .reject));
        try t.expectError(error.Inexact, s.cast(.{ .signed = std.math.maxInt(i128) }, .int128, target, .reject));
        try t.expectEqual(@as(f64, 0x1p127), (try s.cast(.{ .signed = std.math.maxInt(i128) }, .int128, target, .nearest_even)).float);
        try t.expectEqual(@as(f64, 0x1p127), (try s.cast(.{ .unsigned = @as(u128, 1) << 127 }, .uint128, target, .reject)).float);
        try t.expectError(error.Inexact, s.cast(.{ .unsigned = (@as(u128, 1) << 127) + 1 }, .uint128, target, .reject));
        try t.expectEqual(@as(f64, 0), (try s.cast(.{ .unsigned = 0 }, .uint128, target, .reject)).float);
    }
    try t.expectError(error.Inexact, s.cast(.{ .unsigned = std.math.maxInt(u128) }, .uint128, .float64, .reject));
    try t.expectEqual(@as(f64, 0x1p128), (try s.cast(.{ .unsigned = std.math.maxInt(u128) }, .uint128, .float64, .nearest_even)).float);
    try t.expectError(error.Overflow, s.cast(.{ .unsigned = std.math.maxInt(u128) }, .uint128, .float32, .reject));
    try t.expectError(error.Overflow, s.cast(.{ .unsigned = std.math.maxInt(u128) }, .uint128, .float32, .nearest_even));
}
test "promotion is domain based while CSV inference protects identifiers" {
    try t.expectEqual(m.Tag.int128, (try s.promote(.int64, .uint64)).tag());
    try t.expectError(error.NoLosslessPromotion, s.promote(.int128, .uint128));
    try t.expectError(error.NoLosslessPromotion, s.promote(.int64, .float64));
    for ([_][]const u8{ "00123", "+123", "-0", "1.0", "1e3", " 123", "123 ", "" }) |text| try t.expectEqual(m.Tag.utf8, s.inferText(text).tag());
    try t.expectEqual(m.Tag.uint64, s.inferText("18446744073709551615").tag());
    try t.expectEqual(m.Tag.int64, s.inferText("9007199254740993").tag());
}
test "temporal literals reject calendar ambiguity and UUID binding is exact" {
    try t.expectEqual(@as(i32, 0), (try s.bind("1970-01-01", .date)).date);
    try t.expectEqual(@as(i32, -1), (try s.bind("1969-12-31", .date)).date);
    try t.expectError(error.InvalidDate, s.bind("1900-02-29", .date));
    _ = try s.bind("2000-02-29", .date);
    try t.expectEqual(@as(i64, -1), (try s.bind("1969-12-31T23:59:59.999999Z", .{ .timestamp = .utc })).timestamp);
    try t.expectError(error.Inexact, s.bind("1970-01-01T00:00:00.000000001Z", .{ .timestamp = .utc }));
    try t.expectError(error.InvalidTime, s.bind("23:59:60", .time));
    try t.expectError(error.InvalidTimestamp, s.bind("1970-01-01T00:00:00", .{ .timestamp = .utc }));
    try t.expectEqualSlices(u8, &.{ 0, 17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255 }, &(try s.bind("00112233-4455-6677-8899-aAbBcCdDeEfF", .uuid)).uuid);
}

test "Python independent scalar oracle matches literal binding fingerprints and neutral bytes" {
    const Case = struct { name: []const u8, kind: []const u8, literal: []const u8, type_hex: []const u8, fingerprint: []const u8, value_hex: []const u8, logical_hash: []const u8 };
    const Fixture = struct { definition: []const u8, oracle: []const u8, cases: []Case };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/types.json"), .{});
    defer parsed.deinit();
    try t.expectEqualStrings(m.definition, parsed.value.definition);
    for (parsed.value.cases) |fixture| {
        var type_bytes: [1024]u8 = undefined;
        const encoded_type = try std.fmt.hexToBytes(&type_bytes, fixture.type_hex);
        var descriptor = try m.decode(t.allocator, encoded_type);
        defer descriptor.deinit();
        var copied = try descriptor.type.clone(t.allocator);
        defer copied.deinit();
        var copied_bytes: [1024]u8 = undefined;
        try t.expectEqualSlices(u8, encoded_type, try copied.type.encode(&copied_bytes));
        var digest: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&digest, fixture.fingerprint);
        try t.expectEqualSlices(u8, &digest, &try descriptor.type.fingerprint());
        const atom = try s.bind(fixture.literal, descriptor.type);
        const cell: m.Values.Cell = .{ .value = .{ .atom = atom } };
        _ = try std.fmt.hexToBytes(&digest, fixture.logical_hash);
        try t.expectEqualSlices(u8, &digest, &try m.Operations.hash(.{ .name = "value", .type = descriptor.type }, cell));
        var expected: [2048]u8 = undefined;
        const expected_bytes = try std.fmt.hexToBytes(&expected, fixture.value_hex);
        var actual: [2048]u8 = undefined;
        try t.expectEqualSlices(u8, expected_bytes, try m.Codec.encode(cell, .{ .name = "value", .type = descriptor.type }, &actual));
        var decoded = try m.Codec.decode(t.allocator, expected_bytes);
        defer decoded.deinit();
        try t.expectEqual(std.math.Order.eq, try m.Values.atomOrder(atom, decoded.cell.value.atom, descriptor.type));
    }
}

test "descriptor validation retains first exact nested rule and owned values" {
    const bad: m.Type = .{ .decimal = .{ .precision = 7, .scale = 8 } };
    const descriptor: m.Type = .{ .map = .{ .key = &.utf8, .value = .{ .type = &.{ .array = .{ .length = 2, .element = .{ .type = &.{ .list = .{ .type = &bad } } } } } } } };
    var failure: ?m.Diagnostic = null;
    try t.expectError(error.InvalidDecimal, descriptor.validateDiagnostic(.{}, &failure));
    try t.expectEqualStrings("/type/map/value/type/array/element/type/list/type/decimal/scale", failure.?.path.slice());
    try t.expectEqual(m.Diagnostic.Kind.scale, failure.?.kind);
    try t.expectEqual(@as(?usize, 8), failure.?.actual);
    try t.expectEqual(@as(?usize, 7), failure.?.limit);
    try t.expectEqualStrings("decimal(7,8)", failure.?.supplied());
    const other: m.Type = .{ .decimal = .{ .precision = 0, .scale = 0 } };
    try t.expectError(error.InvalidDecimal, other.validateDiagnostic(.{}, &failure));
    try t.expectEqual(m.Diagnostic.Kind.scale, failure.?.kind);
    failure = null;
    var name = [_]u8{ 'x', '/', '~' };
    const duplicate: m.Type = .{ .structure = &.{ .{ .name = &name, .type = .int8 }, .{ .name = &name, .type = .int64 } } };
    try t.expectError(error.DuplicateField, duplicate.validateDiagnostic(.{}, &failure));
    @memset(&name, '?');
    try t.expectEqualStrings("/type/structure/1/name", failure.?.path.slice());
    try t.expectEqualStrings("x/~", failure.?.supplied());
    try t.expectEqual(@as(?usize, 1), failure.?.actual);
    try t.expectEqual(@as(?usize, 0), failure.?.earlier);
}

test "descriptor budgets report stopping dimension and preserve cyclic input bounds" {
    for ([_]struct { limits: m.Limits, kind: m.Diagnostic.Kind, actual: usize, limit: usize, path: []const u8 }{
        .{ .limits = .{ .depth = 1 }, .kind = .depth, .actual = 2, .limit = 1, .path = "/type/structure/0/type" },
        .{ .limits = .{ .nodes = 1 }, .kind = .nodes, .actual = 2, .limit = 1, .path = "/type/structure/0/type" },
        .{ .limits = .{ .name_bytes = 1 }, .kind = .name_bytes, .actual = 2, .limit = 1, .path = "/type/structure/0/name" },
    }) |case| {
        var failure: ?m.Diagnostic = null;
        try t.expectError(error.TypeBudgetExceeded, nested.validateDiagnostic(case.limits, &failure));
        try t.expectEqual(case.kind, failure.?.kind);
        try t.expectEqual(@as(?usize, case.actual), failure.?.actual);
        try t.expectEqual(@as(?usize, case.limit), failure.?.limit);
        try t.expectEqualStrings(case.path, failure.?.path.slice());
    }
    var cycle: m.Type = undefined;
    cycle = .{ .array = .{ .length = 1, .element = .{ .type = &cycle } } };
    var failure: ?m.Diagnostic = null;
    try t.expectError(error.TypeBudgetExceeded, cycle.validateDiagnostic(.{}, &failure));
    try t.expectEqual(m.Diagnostic.Kind.depth, failure.?.kind);
    try t.expectEqual(@as(?usize, 17), failure.?.actual);
    try t.expect(failure.?.path.truncated);
    try t.expect(std.unicode.utf8ValidateSlice(failure.?.path.slice()));
}

test "descriptor names retain invalid bytes safely and bound owned previews" {
    const long: [300]u8 = @splat('x');
    for ([_]struct { name: []const u8, kind: m.Diagnostic.Kind }{
        .{ .name = "", .kind = .name_empty },
        .{ .name = &long, .kind = .name_length },
        .{ .name = "\xff", .kind = .name_utf8 },
        .{ .name = "a\x00b", .kind = .name_nul },
    }) |case| {
        const descriptor: m.Type = .{ .structure = &.{.{ .name = case.name, .type = .int64 }} };
        var failure: ?m.Diagnostic = null;
        try t.expectError(error.InvalidFieldName, descriptor.validateDiagnostic(.{}, &failure));
        try t.expectEqual(case.kind, failure.?.kind);
        try t.expectEqualStrings("/type/structure/0/name", failure.?.path.slice());
        try t.expectEqualSlices(u8, case.name[0..@min(256, case.name.len)], failure.?.supplied());
        try t.expectEqual(case.name.len > 256, failure.?.value_truncated);
    }
}
