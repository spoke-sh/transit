const std = @import("std");
const t = std.testing;
const Types = @import("Types.zig");
const v = @import("Values.zig");
const s = @import("TableSchema.zig");
const p = @import("PhysicalCodecs.zig");

fn compare(field: Types.Field, expected: v.Cell, actual: v.Cell) !void {
    var left: [8192]u8 = undefined;
    var right: [8192]u8 = undefined;
    try t.expectEqualSlices(u8, try Types.Codec.encodeBound(expected, field, &left), try Types.Codec.encodeBound(actual, field, &right));
}

test "selected column cells preserve all codecs states provenance and detached ownership" {
    const cases = [_]struct { encoding: s.Encoding, kind: Types.Type, value: v.Value }{
        .{ .encoding = .plain, .kind = .{ .list = .{ .type = &.utf8, .nullable = true } }, .value = .{ .list = &.{ .null, .{ .value = .{ .atom = .{ .bytes = "nested🙂" } } } } } },
        .{ .encoding = .bitpacked, .kind = .int64, .value = .{ .atom = .{ .signed = -17 } } },
        .{ .encoding = .rle, .kind = .utf8, .value = .{ .atom = .{ .bytes = "repeat🙂" } } },
        .{ .encoding = .dictionary, .kind = .utf8, .value = .{ .atom = .{ .bytes = "dictionary🙂" } } },
        .{ .encoding = .fsst, .kind = .utf8, .value = .{ .atom = .{ .bytes = "symbols🙂symbols🙂" } } },
        .{ .encoding = .comp, .kind = .int32, .value = .{ .atom = .{ .signed = -123 } } },
        .{ .encoding = .comp_3, .kind = .int64, .value = .{ .atom = .{ .signed = -123 } } },
        .{ .encoding = .zoned, .kind = .int64, .value = .{ .atom = .{ .signed = -123 } } },
        .{ .encoding = .ibm_hfp, .kind = .float64, .value = .{ .atom = .{ .float = -17.5 } } },
        .{ .encoding = .ebcdic, .kind = .utf8, .value = .{ .atom = .{ .bytes = "café" } } },
    };
    for (cases) |case| {
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        const column: s.Column = .{ .id = 1, .name = "v", .type = case.kind, .encoding = case.encoding };
        var field = column.field();
        field.optional = true;
        const alternatives = [_]v.Alternative{
            .{ .counter = 1, .replica = 2, .value = .{ .value = case.value } },
            .{ .counter = 2, .replica = 1, .value = .null },
            .{ .counter = 3, .replica = 1, .value = .{ .type_error = .int128 } },
        };
        const cells = [_]v.Cell{ .{ .value = case.value }, .null, .missing, .{ .type_error = .binary }, .{ .conflict = &alternatives }, .{ .value = case.value }, .{ .value = case.value } };
        var bytes: [8192]u8 = undefined;
        const encoded = try p.encodeColumnPage(t.allocator, column, &cells, &bytes);
        // Every singleton and a non-contiguous selection use the declared
        // logical cells as their oracle, including every conflict stamp.
        var selected: [cells.len]p.Selected = undefined;
        for (&selected, 0..) |*out, i| out.* = try p.decodeColumnPageSelected(t.allocator, arena.allocator(), column, encoded, &.{@intCast(i)});
        const indices = [_]u32{ 0, 2, 4, 6 };
        const sparse = try p.decodeColumnPageSelected(t.allocator, arena.allocator(), column, encoded, &indices);
        const all = try p.decodeColumnPage(arena.allocator(), column, encoded);
        const empty = try p.decodeColumnPageSelected(t.allocator, arena.allocator(), column, encoded, &.{});
        try t.expectEqual(@as(usize, 0), empty.cells.len);
        const borrowed = try p.decodeColumnPageBorrowingBytes(t.allocator, arena.allocator(), column, encoded, null);
        const borrowed_sparse = try p.decodeColumnPageBorrowingBytes(t.allocator, arena.allocator(), column, encoded, &indices);
        for (cells, borrowed.cells) |expected, actual| try compare(field, expected, actual);
        for (indices, borrowed_sparse.cells) |index, actual| try compare(field, cells[index], actual);
        if (case.encoding == .plain) {
            // Recursive arrays and conflict records survive temporary resets;
            // their text points into the immutable page instead of a copy.
            for ([_][]const u8{
                borrowed.cells[0].value.list[1].value.atom.bytes,
                borrowed.cells[4].conflict[0].value.value.list[1].value.atom.bytes,
                borrowed_sparse.cells[2].conflict[0].value.value.list[1].value.atom.bytes,
            }) |text| {
                try t.expect(@intFromPtr(text.ptr) >= @intFromPtr(encoded.ptr));
                try t.expect(@intFromPtr(text.ptr) + text.len <= @intFromPtr(encoded.ptr) + encoded.len);
            }
        }
        @memset(&bytes, 0xaa);
        if (case.encoding != .plain) for (cells, borrowed.cells) |expected, actual| try compare(field, expected, actual);
        for (cells, selected, all) |expected, actual, full| {
            try t.expectEqual(@as(u32, cells.len), actual.row_count);
            try compare(field, expected, actual.cells[0]);
            try compare(field, expected, full);
        }
        for (indices, sparse.cells) |index, actual| try compare(field, cells[index], actual);
    }
}

// Independent TCP1 bytes: six mixed states and two int8 values. This fixture
// never calls the production encoder, including for conflict alternatives.
fn fixture(out: []u8) []u8 {
    const payload = [_]u8{
        0, 1, 2, 3, 4, 0, // tags
        @backingInt(Types.Kind.utf8), // type-error detail
        2, 0, // conflict count
        1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, // (1,2,null)
        2, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 2, // (2,1,value)
        2, 0, 0, 0, 3, 99, // canonical int8
        2, 0, 0, 0, 3, 7, // first value
        2, 0, 0, 0, 3, 0xfd, // last value = -3
    };
    @memcpy(out[0..4], "TCP1");
    @memcpy(out[4..36], &@import("transit_protocol").Growth.definition_bytes);
    out[36] = @backingInt(s.Encoding.plain);
    std.mem.writeInt(u32, out[37..41], 6, .little);
    @memcpy(out[41..][0..payload.len], &payload);
    return out[0 .. 41 + payload.len];
}

test "selected column independent bytes reject skipped corruption truncation and invalid ordinals" {
    const column: s.Column = .{ .id = 1, .name = "v", .type = .int8 };
    var bytes: [256]u8 = undefined;
    const encoded = fixture(&bytes);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const selected = try p.decodeColumnPageSelected(t.allocator, a, column, encoded, &.{ 0, 4, 5 });
    try t.expectEqual(@as(i128, 7), selected.cells[0].value.atom.signed);
    try t.expectEqual(@as(u64, 2), selected.cells[1].conflict[1].counter);
    try t.expectEqual(@as(i128, 99), selected.cells[1].conflict[1].value.value.atom.signed);
    try t.expectEqual(@as(i128, -3), selected.cells[2].value.atom.signed);
    for (0..encoded.len) |length| {
        var partial = std.heap.ArenaAllocator.init(t.allocator);
        defer partial.deinit();
        if (p.decodeColumnPageSelected(t.allocator, partial.allocator(), column, encoded[0..length], &.{0})) |_| return error.AcceptedTruncatedPage else |_| {}
    }
    for ([_][]const u32{ &.{6}, &.{ 0, 0 }, &.{ 5, 1 } }) |indices| try t.expectError(error.InvalidColumnSelection, p.decodeColumnPageSelected(t.allocator, a, column, encoded, indices));
    bytes[encoded.len] = 0;
    try t.expectError(error.InvalidColumnPage, p.decodeColumnPageSelected(t.allocator, a, column, bytes[0 .. encoded.len + 1], &.{}));
    // Skipped final value has an illegal logical state. Even an empty
    // selection must reject; the valid first value cannot hide a bad suffix.
    bytes[encoded.len - 2] = 0xff;
    for ([_][]const u32{ &.{0}, &.{} }) |indices| try t.expectError(error.InvalidValueEncoding, p.decodeColumnPageSelected(t.allocator, a, column, encoded, indices));
    _ = fixture(&bytes);
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, p.decodeColumnPageSelected(t.allocator, a, column, encoded, &.{}));
}

test "selected column plain strings avoid retaining skipped payloads" {
    const column: s.Column = .{ .id = 1, .name = "v", .type = .utf8 };
    const text: [2048]u8 = @splat('x');
    const cells: [128]v.Cell = @splat(.{ .value = .{ .atom = .{ .bytes = &text } } });
    const bytes = try t.allocator.alloc(u8, 512 * 1024);
    defer t.allocator.free(bytes);
    const encoded = try p.encodeColumnPage(t.allocator, column, &cells, bytes);
    var output: [8192]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&output);
    const selected = try p.decodeColumnPageSelected(t.allocator, fixed.allocator(), column, encoded, &.{127});
    try t.expectEqualStrings(&text, selected.cells[0].value.atom.bytes);
    try t.expect(fixed.end_index < 4096);
    fixed.reset();
    try t.expectError(error.OutOfMemory, p.decodeColumnPage(fixed.allocator(), column, encoded));
}

test "selected column borrowed payloads fit metadata budget and detach explicitly" {
    const column: s.Column = .{ .id = 1, .name = "v", .type = .utf8 };
    const text: [2048]u8 = @splat('x');
    const cells: [128]v.Cell = @splat(.{ .value = .{ .atom = .{ .bytes = &text } } });
    const bytes = try t.allocator.alloc(u8, 512 * 1024);
    defer t.allocator.free(bytes);
    const encoded = try p.encodeColumnPage(t.allocator, column, &cells, bytes);
    var output: [32 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&output);
    const borrowed = try p.decodeColumnPageBorrowingBytes(t.allocator, fixed.allocator(), column, encoded, null);
    try t.expectEqual(cells.len, borrowed.cells.len);
    try t.expect(fixed.end_index < output.len);
    for (borrowed.cells) |cell| {
        const payload = cell.value.atom.bytes;
        try t.expectEqualStrings(&text, payload);
        try t.expect(@intFromPtr(payload.ptr) >= @intFromPtr(encoded.ptr));
        try t.expect(@intFromPtr(payload.ptr) + payload.len <= @intFromPtr(encoded.ptr) + encoded.len);
    }
    var detached = std.heap.ArenaAllocator.init(t.allocator);
    defer detached.deinit();
    const copy = try v.cloneValidated(detached.allocator(), borrowed.cells[127]);
    @memset(bytes, 0xaa);
    try t.expectEqualStrings(&text, copy.value.atom.bytes);
}

test "selected column borrowed independent bytes reject skipped corruption and partial input" {
    const column: s.Column = .{ .id = 1, .name = "v", .type = .int8 };
    var bytes: [256]u8 = undefined;
    const encoded = fixture(&bytes);
    for (0..encoded.len) |length| {
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        if (p.decodeColumnPageBorrowingBytes(t.allocator, arena.allocator(), column, encoded[0..length], &.{0})) |_| return error.AcceptedTruncatedPage else |_| {}
    }
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const selected = try p.decodeColumnPageBorrowingBytes(t.allocator, arena.allocator(), column, encoded, &.{ 0, 4, 5 });
    try t.expectEqual(@as(i128, 7), selected.cells[0].value.atom.signed);
    try t.expectEqual(@as(u64, 2), selected.cells[1].conflict[1].counter);
    try t.expectEqual(@as(i128, 99), selected.cells[1].conflict[1].value.value.atom.signed);
    try t.expectEqual(@as(i128, -3), selected.cells[2].value.atom.signed);
    for ([_][]const u32{ &.{6}, &.{ 0, 0 }, &.{ 5, 1 } }) |indices| try t.expectError(error.InvalidColumnSelection, p.decodeColumnPageBorrowingBytes(t.allocator, arena.allocator(), column, encoded, indices));
    bytes[encoded.len] = 0;
    try t.expectError(error.InvalidColumnPage, p.decodeColumnPageBorrowingBytes(t.allocator, arena.allocator(), column, bytes[0 .. encoded.len + 1], &.{}));
    bytes[encoded.len - 2] = 0xff;
    for ([_]?[]const u32{ null, &.{0}, &.{} }) |indices| try t.expectError(error.InvalidValueEncoding, p.decodeColumnPageBorrowingBytes(t.allocator, arena.allocator(), column, encoded, indices));
    _ = fixture(&bytes);
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, p.decodeColumnPageBorrowingBytes(t.allocator, arena.allocator(), column, encoded, &.{}));
}

fn borrowingAllocationCase(allocator: std.mem.Allocator, column: s.Column, bytes: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const decoded = try p.decodeColumnPageBorrowingBytes(allocator, arena.allocator(), column, bytes, &.{ 0, 1 });
    try t.expectEqualStrings("nested", decoded.cells[0].value.list[0].value.atom.bytes);
    try t.expectEqualStrings("nested", decoded.cells[1].conflict[0].value.value.list[0].value.atom.bytes);
    const detached = try v.cloneValidated(arena.allocator(), decoded.cells[1]);
    try t.expectEqual(@as(u64, 9), detached.conflict[0].counter);
}

test "selected column borrowed recursive ownership releases partial allocations" {
    const column: s.Column = .{ .id = 1, .name = "v", .type = .{ .list = .{ .type = &.utf8, .nullable = true } } };
    const value: v.Value = .{ .list = &.{.{ .value = .{ .atom = .{ .bytes = "nested" } } }} };
    const cells = [_]v.Cell{
        .{ .value = value },
        .{ .conflict = &.{ .{ .counter = 9, .replica = 1, .value = .{ .value = value } }, .{ .counter = 10, .replica = 1, .value = .null } } },
        .{ .value = value },
    };
    var buffer: [4096]u8 = undefined;
    const bytes = try p.encodeColumnPage(t.allocator, column, &cells, &buffer);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), borrowingAllocationCase, .{ column, bytes });
}

test "selected column independent compressed streams preserve sparse values and validate skipped suffixes" {
    const cases = [_]struct { encoding: s.Encoding, payload: []const u8, values: [3]i128, corrupt: anyerror }{
        // Base 5, two-bit deltas [0,2,3].
        .{ .encoding = .bitpacked, .payload = &.{ 5, 0, 0, 0, 0, 0, 0, 0, 2, 0x38 }, .values = .{ 5, 7, 8 }, .corrupt = error.InvalidBitpackedPage },
        // Two canonical int8 runs: (5,2), (7,1).
        .{ .encoding = .rle, .payload = &.{ 2, 0, 0, 0, 2, 0, 0, 0, 3, 5, 2, 0, 0, 0, 2, 0, 0, 0, 3, 7, 1, 0, 0, 0 }, .values = .{ 5, 5, 7 }, .corrupt = error.InvalidRlePage },
        // Two dictionary entries 5,7, followed by codes 0,1,0.
        .{ .encoding = .dictionary, .payload = &.{ 2, 0, 0, 0, 2, 0, 0, 0, 3, 5, 2, 0, 0, 0, 3, 7, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 }, .values = .{ 5, 7, 5 }, .corrupt = error.InvalidDictionaryCode },
    };
    for (cases) |case| {
        var bytes: [256]u8 = undefined;
        _ = fixture(&bytes);
        bytes[36] = @backingInt(case.encoding);
        std.mem.writeInt(u32, bytes[37..41], 3, .little);
        @memset(bytes[41..44], 0);
        @memcpy(bytes[44..][0..case.payload.len], case.payload);
        const page = bytes[0 .. 44 + case.payload.len];
        const column: s.Column = .{ .id = 1, .name = "v", .type = .int8, .encoding = case.encoding };
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        const selected = try p.decodeColumnPageSelected(t.allocator, arena.allocator(), column, page, &.{ 0, 2 });
        try t.expectEqual(case.values[0], selected.cells[0].value.atom.signed);
        try t.expectEqual(case.values[2], selected.cells[1].value.atom.signed);
        if (case.encoding == .bitpacked) {
            // Offset addition overflows even when selecting no values.
            @memset(bytes[44..52], 0xff);
        } else bytes[page.len - 1] = 0xff;
        try t.expectError(case.corrupt, p.decodeColumnPageSelected(t.allocator, arena.allocator(), column, page, &.{}));
    }
}
