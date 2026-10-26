const std = @import("std");
const t = std.testing;
const p = @import("PhysicalCodecs.zig");
const s = @import("TableSchema.zig");
const Types = @import("Types.zig");
const v = Types.Values;
const a = @import("zarrow");

fn independentInteger(out: *[256]u8) []u8 {
    @memset(out, 0);
    @memcpy(out[0..4], "TCP1");
    @memcpy(out[4..36], &@import("transit_protocol").Growth.definition_bytes);
    out[36] = @backingInt(s.Encoding.plain);
    std.mem.writeInt(u32, out[37..41], 9, .little);
    @memcpy(out[41..50], &[_]u8{ 0, 1, 2, 3, 0, 0, 0, 0, 0 });
    out[50] = @backingInt(Types.Kind.utf8);
    out[64] = 0xf1;
    out[65] = 1;
    const words = [_]i64{ std.math.minInt(i64), 0, 0, 0, -1, 0, 1, std.math.maxInt(i64), 17 };
    for (words, 0..) |word, i| std.mem.writeInt(i64, out[128 + i * 8 ..][0..8], word, .little);
    return out;
}
test "plain column independent Arrow integer buffers preserve state and reject malformed padding" {
    const column: s.Column = .{ .id = 1, .name = "value", .type = .int64 };
    var input: [256]u8 align(64) = undefined;
    const bytes = independentInteger(&input);
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const decoded = try p.decodeColumnPage(arena.allocator(), column, bytes);
    const borrowed = try p.borrowPlainColumn(t.allocator, arena.allocator(), column, bytes);
    for (decoded, 0..) |cell, i| try t.expectEqualDeep(cell, borrowed.cell(i));
    try t.expectEqual(@as(usize, 1), borrowed.details.len);
    var buffers: [3]a.SharedBuffer = undefined;
    const data = try borrowed.buffers.arrowValues(&buffers);
    const integers: a.PrimitiveArray(i64) = .{ .data = &data };
    try t.expectEqual(std.math.minInt(i64), try integers.value(0));
    try t.expectEqual(std.math.maxInt(i64), try integers.value(7));
    try t.expect(integers.isNull(1) and integers.isNull(2) and integers.isNull(3));
    try t.expectEqual(input[128..].ptr, data.buffers[1].data.ptr);
    var encoded: [256]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try p.encodeColumnPage(t.allocator, column, decoded, &encoded));
    for ([_]usize{ 51, 63, 64, 65, 66, 127, 136, 200, 255 }) |at| {
        _ = independentInteger(&input);
        input[at] ^= 0x80;
        try t.expectError(error.InvalidColumnPage, p.borrowPlainColumn(t.allocator, arena.allocator(), column, bytes));
        try t.expectError(error.InvalidColumnPage, p.decodeColumnPageSelected(t.allocator, arena.allocator(), column, bytes, &.{}));
    }
    _ = independentInteger(&input);
    for (0..bytes.len) |length| {
        if (p.borrowPlainColumn(t.allocator, arena.allocator(), column, bytes[0..length])) |_| return error.AcceptedTruncation else |_| {}
    }
    var unaligned: [257]u8 align(64) = undefined;
    @memcpy(unaligned[1..], bytes);
    const moved = try p.borrowPlainColumn(t.allocator, arena.allocator(), column, unaligned[1..]);
    try t.expectError(error.UnalignedArrowBuffer, moved.buffers.arrowValues(&buffers));
}

fn allLayouts(allocator: std.mem.Allocator) !void {
    const cases = [_]struct { kind: Types.Type, atom: v.Atom }{
        .{ .kind = .int64, .atom = .{ .signed = std.math.minInt(i64) } },
        .{ .kind = .uint64, .atom = .{ .unsigned = std.math.maxInt(u64) } },
        .{ .kind = .float64, .atom = .{ .float = -0.0 } },
        .{ .kind = .boolean, .atom = .{ .boolean = true } },
        .{ .kind = .utf8, .atom = .{ .bytes = "Å🙂\x00" } },
        .{ .kind = .binary, .atom = .{ .bytes = "\xff\x00\x01" } },
        .{ .kind = .json, .atom = .{ .bytes = "{\"exact\":18446744073709551617}" } },
    };
    for (cases) |case| {
        const column: s.Column = .{ .id = 1, .name = "value", .type = case.kind };
        const value: v.Value = if (case.kind == .json) .{ .json = case.atom.bytes } else .{ .atom = case.atom };
        const alternatives = [_]v.Alternative{
            .{ .counter = 1, .replica = 1, .value = .null },
            .{ .counter = 2, .replica = 1, .value = .{ .value = value } },
        };
        const cells = [_]v.Cell{ .{ .value = value }, .null, .missing, .{ .type_error = .int8 }, .{ .conflict = &alternatives }, .{ .value = value } };
        var bytes: [4096]u8 align(64) = undefined;
        const encoded = try p.encodeColumnPage(allocator, column, &cells, &bytes);
        var arena: std.heap.ArenaAllocator = .init(allocator);
        defer arena.deinit();
        const borrowed = try p.borrowPlainColumn(allocator, arena.allocator(), column, encoded);
        const selected = try p.decodeColumnPageSelected(allocator, arena.allocator(), column, encoded, &.{ 0, 4, 5 });
        for (cells, 0..) |cell, i| try t.expectEqualDeep(cell, borrowed.cell(i));
        for ([_]usize{ 0, 4, 5 }, selected.cells) |i, cell| try t.expectEqualDeep(cells[i], cell);
        var buffers: [3]a.SharedBuffer = undefined;
        const data = try borrowed.buffers.arrowValues(&buffers);
        try t.expectEqual(@as(usize, 4), data.null_count.?);
        for (data.buffers) |buffer| {
            try t.expectEqual(@as(usize, 0), @intFromPtr(buffer.data.ptr) % 64);
            try t.expect(buffer.storage == null);
        }
        if (case.kind == .utf8 or case.kind == .json) {
            const strings: a.StringArray = .{ .data = &data };
            try t.expectEqualStrings(case.atom.bytes, try strings.value(5));
        }
        if (case.kind == .float64) try t.expectEqual(@as(u64, 1) << 63, std.mem.readInt(u64, data.buffers[1].data[0..8], .little));
        @memset(&bytes, 0xaa);
        for ([_]usize{ 0, 4, 5 }, selected.cells) |i, cell| try t.expectEqualDeep(cells[i], cell);
    }
}
test "plain column Arrow layouts preserve full width five states and detached selected output" {
    try allLayouts(t.allocator);
}
test "plain column Arrow allocation failures release only owned metadata" {
    try t.checkAllAllocationFailures(t.allocator, allLayouts, .{});
}
test "plain column Arrow empty buffers and offsets validate without value allocation" {
    const kinds = [_]Types.Type{ .int64, .uint64, .float64, .boolean, .utf8, .binary, .json };
    for (kinds) |kind| {
        const column: s.Column = .{ .id = 1, .name = "value", .type = kind };
        var bytes: [256]u8 align(64) = undefined;
        const encoded = try p.encodeColumnPage(t.allocator, column, &.{}, &bytes);
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        const borrowed = try p.borrowPlainColumn(t.allocator, arena.allocator(), column, encoded);
        var buffers: [3]a.SharedBuffer = undefined;
        const data = try borrowed.buffers.arrowValues(&buffers);
        try t.expectEqual(@as(usize, 0), data.length);
        try t.expectEqual(@as(usize, 0), borrowed.details.len);
    }
}

test "plain column Arrow offsets invalid UTF8 Boolean tails and foreign definitions reject" {
    const column: s.Column = .{ .id = 1, .name = "value", .type = .utf8 };
    const cells = [_]v.Cell{ .{ .value = .{ .atom = .{ .bytes = "a" } } }, .null, .{ .value = .{ .atom = .{ .bytes = "b" } } } };
    var bytes: [256]u8 align(64) = undefined;
    const encoded = try p.encodeColumnPage(t.allocator, column, &cells, &bytes);
    const valid = bytes;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    // Canonical offsets are 0,1,1,2 at 128; payload is at 192. Corruption
    // outside a selected prefix must still fail, including the last UTF8 value.
    for ([_]usize{ 128, 132, 136, 140, 193 }) |at| {
        bytes = valid;
        bytes[at] = 0xff;
        if (p.decodeColumnPageSelected(t.allocator, arena.allocator(), column, encoded, &.{0})) |_| return error.AcceptedCorruption else |_| {}
        if (p.borrowPlainColumn(t.allocator, arena.allocator(), column, encoded)) |_| return error.AcceptedCorruption else |_| {}
    }
    bytes = valid;
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, p.borrowPlainColumn(t.allocator, arena.allocator(), column, encoded));
    const boolean: s.Column = .{ .id = 1, .name = "value", .type = .boolean };
    const bools = try p.encodeColumnPage(t.allocator, boolean, &.{ .{ .value = .{ .atom = .{ .boolean = true } } }, .null }, &bytes);
    bytes[128] |= 0x80;
    try t.expectError(error.InvalidColumnPage, p.borrowPlainColumn(t.allocator, arena.allocator(), boolean, bools));
    bytes[128] = 3;
    try t.expectError(error.InvalidColumnPage, p.borrowPlainColumn(t.allocator, arena.allocator(), boolean, bools));
}
