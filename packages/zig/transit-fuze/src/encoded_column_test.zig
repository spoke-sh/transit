const std = @import("std");
const t = std.testing;
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const Schema = @import("TableSchema.zig");
const Codecs = @import("PhysicalCodecs.zig");
const Predicate = @import("ColumnPredicate.zig");

fn page(out: []u8, encoding: Schema.Encoding, tags: []const u8, payload: []const u8) []u8 {
    @memcpy(out[0..4], "TCP1");
    @memcpy(out[4..36], &@import("transit_protocol").Growth.definition_bytes);
    out[36] = @backingInt(encoding);
    std.mem.writeInt(u32, out[37..41], @intCast(tags.len), .little);
    @memcpy(out[41..][0..tags.len], tags);
    @memcpy(out[41 + tags.len ..][0..payload.len], payload);
    return out[0 .. 41 + tags.len + payload.len];
}

test "encoded column independent streams compare values once per run or dictionary entry" {
    const cases = [_]struct { encoding: Schema.Encoding, payload: []const u8, expected: [3]Predicate.Outcome, evaluated: usize }{
        // Base 5, two-bit offsets [0,2,3].
        .{ .encoding = .bitpacked, .payload = &.{ 5, 0, 0, 0, 0, 0, 0, 0, 2, 0x38 }, .expected = .{ .no, .yes, .yes }, .evaluated = 3 },
        // Canonical int8 runs (5,2), (7,1).
        .{ .encoding = .rle, .payload = &.{ 2, 0, 0, 0, 2, 0, 0, 0, 3, 5, 2, 0, 0, 0, 2, 0, 0, 0, 3, 7, 1, 0, 0, 0 }, .expected = .{ .no, .no, .yes }, .evaluated = 2 },
        // Dictionary [5,7], codes [0,1,0].
        .{ .encoding = .dictionary, .payload = &.{ 2, 0, 0, 0, 2, 0, 0, 0, 3, 5, 2, 0, 0, 0, 3, 7, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 }, .expected = .{ .no, .yes, .no }, .evaluated = 2 },
    };
    for (cases) |case| {
        var bytes: [256]u8 = undefined;
        const encoded = page(&bytes, case.encoding, &.{ 0, 0, 0 }, case.payload);
        const column: Schema.Column = .{ .id = 1, .name = "v", .type = .int8, .encoding = case.encoding };
        var output: [3]u8 = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(&output);
        const result = try Codecs.evaluateColumnPage(t.allocator, fixed.allocator(), column, encoded, .{ .compare = .{ .op = .ge, .value = .{ .signed = 7 } } });
        try t.expectEqualSlices(Predicate.Outcome, &case.expected, result.outcomes);
        try t.expectEqual(case.evaluated, result.evaluated_values);
        try t.expectEqual(@as(usize, 3), fixed.end_index);
        for (0..encoded.len) |length| {
            fixed.reset();
            if (Codecs.evaluateColumnPage(t.allocator, fixed.allocator(), column, encoded[0..length], .all)) |_| return error.AcceptedTruncatedPage else |_| {}
        }
        fixed.reset();
        bytes[encoded.len] = 0;
        try t.expectError(error.InvalidColumnPage, Codecs.evaluateColumnPage(t.allocator, fixed.allocator(), column, bytes[0 .. encoded.len + 1], .all));
    }
}

test "encoded column outcomes preserve eager five-state semantics across every codec" {
    const cases = [_]struct { encoding: Schema.Encoding, kind: Types.Type, atom: Values.Atom }{
        .{ .encoding = .plain, .kind = .int64, .atom = .{ .signed = -17 } },
        .{ .encoding = .bitpacked, .kind = .int64, .atom = .{ .signed = -17 } },
        .{ .encoding = .rle, .kind = .utf8, .atom = .{ .bytes = "repeat🙂" } },
        .{ .encoding = .dictionary, .kind = .utf8, .atom = .{ .bytes = "dictionary🙂" } },
        .{ .encoding = .fsst, .kind = .utf8, .atom = .{ .bytes = "symbols🙂symbols🙂" } },
        .{ .encoding = .comp, .kind = .int32, .atom = .{ .signed = -123 } },
        .{ .encoding = .comp_3, .kind = .int64, .atom = .{ .signed = -123 } },
        .{ .encoding = .zoned, .kind = .int64, .atom = .{ .signed = -123 } },
        .{ .encoding = .ibm_hfp, .kind = .float64, .atom = .{ .float = -17.5 } },
        .{ .encoding = .ebcdic, .kind = .utf8, .atom = .{ .bytes = "café" } },
    };
    for (cases) |case| {
        const column: Schema.Column = .{ .id = 1, .name = "v", .type = case.kind, .encoding = case.encoding };
        const cells = [_]Values.Cell{ .{ .value = .{ .atom = case.atom } }, .null, .missing, .{ .conflict = &.{.{ .counter = 1, .replica = 2, .value = .null }} }, .{ .type_error = .binary }, .{ .value = .{ .atom = case.atom } } };
        var bytes: [8192]u8 = undefined;
        const encoded = try Codecs.encodeColumnPage(t.allocator, column, &cells, &bytes);
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        const decoded = try Codecs.decodeColumnPage(arena.allocator(), column, encoded);
        inline for (.{ .eq, .ne, .lt, .le, .gt, .ge }) |op| {
            const predicate: Predicate.Predicate = .{ .compare = .{ .op = op, .value = case.atom } };
            const result = try Codecs.evaluateColumnPage(t.allocator, arena.allocator(), column, encoded, predicate);
            const match: Predicate.Outcome = if (op == .eq or op == .le or op == .ge) .yes else .no;
            try t.expectEqualSlices(Predicate.Outcome, &.{ match, .unknown, .unknown, .conflict, .type_error, match }, result.outcomes);
            for (decoded, result.outcomes) |cell, outcome| try t.expectEqual(try predicate.evaluate(column, cell), outcome);
        }
        inline for (.{ .value, .null, .missing, .type_error, .conflict }) |state| {
            const result = try Codecs.evaluateColumnPage(t.allocator, arena.allocator(), column, encoded, .{ .state = state });
            for (cells, result.outcomes) |cell, outcome| try t.expectEqual(if (std.meta.activeTag(cell) == state) Predicate.Outcome.yes else .no, outcome);
        }
        const null_result = try Codecs.evaluateColumnPage(t.allocator, arena.allocator(), column, encoded, .null_compare);
        try t.expectEqualSlices(Predicate.Outcome, &.{ .unknown, .unknown, .unknown, .conflict, .type_error, .unknown }, null_result.outcomes);
        try t.expectError(error.QueryConflict, null_result.outcomes[3].truth());
        try t.expectError(error.QueryTypeError, null_result.outcomes[4].truth());
    }
}

test "encoded column declared collation matches independent byte order and folded equality" {
    const names = [_][]const u8{ "A", "a", "0", "é", "\x00", "AA", "aA" };
    const cases = [_]struct { collation: Schema.Collation, lower: [names.len]Predicate.Outcome, equal: [names.len]Predicate.Outcome }{
        .{ .collation = .utf8_binary, .lower = .{ .yes, .no, .yes, .no, .yes, .yes, .no }, .equal = .{ .no, .yes, .no, .no, .no, .no, .no } },
        .{ .collation = .ascii_ci, .lower = .{ .no, .no, .yes, .no, .yes, .no, .no }, .equal = .{ .yes, .yes, .no, .no, .no, .no, .no } },
        // CP037: a=0x81, A=0xc1, 0=0xf0, é=0x51, NUL=0.
        .{ .collation = .ebcdic_cp037, .lower = .{ .no, .no, .no, .yes, .yes, .no, .no }, .equal = .{ .no, .yes, .no, .no, .no, .no, .no } },
    };
    for (cases) |case| for ([_]Schema.Encoding{ .plain, .rle, .dictionary, .fsst, .ebcdic }) |encoding| {
        const column: Schema.Column = .{ .id = 1, .name = "v", .type = .utf8, .encoding = encoding, .collation = case.collation };
        var cells: [names.len]Values.Cell = undefined;
        for (&cells, names) |*cell, name| cell.* = .{ .value = .{ .atom = .{ .bytes = name } } };
        var bytes: [8192]u8 = undefined;
        const encoded = try Codecs.encodeColumnPage(t.allocator, column, &cells, &bytes);
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        const lower = try Codecs.evaluateColumnPage(t.allocator, arena.allocator(), column, encoded, .{ .compare = .{ .op = .lt, .value = .{ .bytes = "a" } } });
        const equal = try Codecs.evaluateColumnPage(t.allocator, arena.allocator(), column, encoded, .{ .compare = .{ .op = .eq, .value = .{ .bytes = "a" } } });
        try t.expectEqualSlices(Predicate.Outcome, &case.lower, lower.outcomes);
        try t.expectEqualSlices(Predicate.Outcome, &case.equal, equal.outcomes);
    };
}

test "encoded column malformed physical values retain source error outcomes" {
    const column: Schema.Column = .{ .id = 1, .name = "v", .type = .int64, .encoding = .comp_3 };
    var bytes: [128]u8 = undefined;
    var packed_bytes: [16]u8 = @splat(0);
    packed_bytes[15] = 0x1c;
    packed_bytes[0] = 0xfa; // Independently malformed decimal nibbles.
    const encoded = page(&bytes, .comp_3, &.{0}, &packed_bytes);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const result = try Codecs.evaluateColumnPage(t.allocator, arena.allocator(), column, encoded, .{ .compare = .{ .op = .eq, .value = .{ .signed = 999 } } });
    try t.expectEqualSlices(Predicate.Outcome, &.{.type_error}, result.outcomes);
    const state = try Codecs.evaluateColumnPage(t.allocator, arena.allocator(), column, encoded, .{ .state = .type_error });
    try t.expectEqualSlices(Predicate.Outcome, &.{.yes}, state.outcomes);
    try t.expectEqual(@as(u8, 0xfa), encoded[41 + 1]);
}

fn allocationCase(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const column: Schema.Column = .{ .id = 1, .name = "v", .type = .utf8, .encoding = .dictionary };
    const result = try Codecs.evaluateColumnPage(allocator, arena.allocator(), column, bytes, .{ .compare = .{ .op = .eq, .value = .{ .bytes = "hello" } } });
    try t.expectEqualSlices(Predicate.Outcome, &.{ .yes, .yes, .yes }, result.outcomes);
    try t.expectEqual(@as(usize, 1), result.evaluated_values);
}

test "encoded column allocation failures free dictionary and validation workspaces" {
    const column: Schema.Column = .{ .id = 1, .name = "v", .type = .utf8, .encoding = .dictionary };
    const cells: [3]Values.Cell = @splat(.{ .value = .{ .atom = .{ .bytes = "hello" } } });
    var bytes: [8192]u8 = undefined;
    const encoded = try Codecs.encodeColumnPage(t.allocator, column, &cells, &bytes);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), allocationCase, .{encoded});
}
