const std = @import("std");
const t = std.testing;
const s = @import("TableSchema.zig");
const v = @import("Values.zig");
const p = @import("PhysicalCodecs.zig");
const c = @import("Collation.zig");

fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, bytes.len / 2);
    errdefer allocator.free(out);
    return std.fmt.hexToBytes(out, bytes);
}

test "independent CP037 repertoire HFP rational vectors and mainframe page bytes" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const Fixture = struct {
        cp037: []const u8,
        utf8: []const u8,
        floats: []const struct { ieee: []const u8, hfp: []const u8 },
        pages: []const struct { encoding: s.Encoding, value: []const u8, page: []const u8 },
    };
    const fixture = try std.json.parseFromSliceLeaky(Fixture, a, @embedFile("fixtures/column-codecs.json"), .{});
    const utf8 = try hex(a, fixture.utf8);
    const ebcdic = try hex(a, fixture.cp037);
    var output: [4096]u8 = undefined;
    try t.expectEqualSlices(u8, ebcdic, try p.encodeEbcdic037(utf8, &output));
    try t.expectEqualSlices(u8, utf8, try p.decodeEbcdic037(ebcdic, &output));
    var view = try std.unicode.Utf8View.init(utf8);
    var iterator = view.iterator();
    var scalars: [256][]const u8 = undefined;
    var i: usize = 0;
    while (iterator.nextCodepointSlice()) |scalar| : (i += 1) scalars[i] = scalar;
    // Every pair is checked against independent CP037 weights, including
    // controls, accents and punctuation where an ASCII subset table is wrong.
    for (scalars, 0..) |left, li| for (scalars, 0..) |right, ri| {
        const expected = std.math.order(ebcdic[li], ebcdic[ri]);
        try t.expectEqual(expected, try c.compareBytes(left, right, .ebcdic_cp037));
        var l: [16]u8 = undefined;
        var r: [16]u8 = undefined;
        const lk = try c.encodeSortKey(.{ .value = .{ .atom = .{ .bytes = left } } }, .utf8, .ebcdic_cp037, &l);
        const rk = try c.encodeSortKey(.{ .value = .{ .atom = .{ .bytes = right } } }, .utf8, .ebcdic_cp037, &r);
        try t.expectEqual(expected, std.mem.order(u8, lk, rk));
    };
    const text_column: s.Column = .{ .id = 1, .name = "v", .type = .utf8, .encoding = .ebcdic };
    const text_page = try p.encodeColumnPage(a, text_column, &.{.{ .value = .{ .atom = .{ .bytes = utf8 } } }}, &output);
    try t.expectEqual(@as(u32, 256), std.mem.readInt(u32, text_page[p.page_header_bytes + 1 ..][0..4], .little));
    try t.expectEqualSlices(u8, ebcdic, text_page[p.page_header_bytes + 5 ..]);
    try t.expectEqualSlices(u8, utf8, (try p.decodeColumnPage(a, text_column, text_page))[0].value.atom.bytes);
    for (fixture.floats) |item| {
        const ieee = try hex(a, item.ieee);
        const value: f64 = @bitCast(std.mem.readInt(u64, ieee[0..8], .big));
        const encoded = try hex(a, item.hfp);
        try t.expectEqualSlices(u8, encoded, &try p.encodeIbmHfp64(value));
        const decoded = p.decodeIbmHfp(encoded, .float64);
        try t.expect(decoded == .value);
        try t.expectEqual(@as(u64, @bitCast(value)), @as(u64, @bitCast(decoded.value.atom.float)));
    }
    for (fixture.pages) |item| {
        const column: s.Column = .{ .id = 1, .name = "v", .type = .int64, .encoding = item.encoding };
        const value = try std.fmt.parseInt(i128, item.value, 10);
        const bytes = try hex(a, item.page);
        const actual = try p.encodeColumnPage(a, column, &.{.{ .value = .{ .atom = .{ .signed = value } } }}, &output);
        try t.expectEqualSlices(u8, bytes, actual);
        try t.expectEqual(value, (try p.decodeColumnPage(a, column, bytes))[0].value.atom.signed);
    }
}

test "physical column admission rejects unsupported schemas and unrepresentable values" {
    const invalid = [_]s.Column{
        .{ .id = 1, .name = "v", .type = .int128, .encoding = .bitpacked },
        .{ .id = 1, .name = "v", .type = .uint128, .encoding = .bitpacked },
        .{ .id = 1, .name = "v", .type = .uint64, .encoding = .comp },
        .{ .id = 1, .name = "v", .type = .int128, .encoding = .comp },
        .{ .id = 1, .name = "v", .type = .uint64, .encoding = .comp_3 },
        .{ .id = 1, .name = "v", .type = .{ .decimal = .{ .precision = 32, .scale = 2 } }, .encoding = .zoned },
        .{ .id = 1, .name = "v", .type = .binary, .encoding = .ebcdic },
    };
    for (invalid) |column| try t.expectError(error.IncompatibleColumnEncoding, column.validateEncodingAndCollation());
    const icu: s.Column = .{ .id = 1, .name = "v", .type = .utf8, .collation = .icu_root };
    try t.expectError(error.UnsupportedColumnCollation, icu.validateEncodingAndCollation());
    try t.expectError(error.UnsupportedColumnCollation, c.compareBytes("a", "b", .icu_root));
    for ([_]s.Column{
        .{ .id = 1, .name = "v", .type = .utf8, .encoding = .ebcdic },
        .{ .id = 1, .name = "v", .type = .utf8, .collation = .ebcdic_cp037 },
    }) |column| try t.expectError(error.UnrepresentableEbcdic037, column.validateCell(.{ .value = .{ .atom = .{ .bytes = "€" } } }));
    const hfp: s.Column = .{ .id = 1, .name = "v", .type = .float64, .encoding = .ibm_hfp };
    try t.expectError(error.IbmHfpUnderflow, hfp.validateCell(.{ .value = .{ .atom = .{ .float = 0x1p-261 } } }));
    try t.expectError(error.IbmHfpOverflow, hfp.validateCell(.{ .value = .{ .atom = .{ .float = 0x1p252 } } }));
    // A valid HFP value requiring more than 53 significant bits cannot be
    // represented exactly by binary64; the foreign decoder preserves failure.
    try t.expect(p.decodeIbmHfp(&.{ 0x41, 0x80, 0, 0, 0, 0, 0, 1 }, .float64) == .type_error);
}

test "compressed columns retain floating zero signs and reject malformed pages" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const values = [_]v.Cell{ .{ .value = .{ .atom = .{ .float = 0.0 } } }, .{ .value = .{ .atom = .{ .float = -0.0 } } } };
    var output: [2048]u8 = undefined;
    for ([_]s.Encoding{ .plain, .rle, .dictionary, .ibm_hfp }) |encoding| {
        const column: s.Column = .{ .id = 1, .name = "v", .type = .float64, .encoding = encoding };
        const page = try p.encodeColumnPage(a, column, &values, &output);
        const decoded = try p.decodeColumnPage(a, column, page);
        for (values, decoded) |expected, actual| try t.expectEqual(@as(u64, @bitCast(expected.value.atom.float)), @as(u64, @bitCast(actual.value.atom.float)));
        output[page.len] = 0;
        try t.expectError(error.InvalidColumnPage, p.decodeColumnPage(a, column, output[0 .. page.len + 1]));
        output[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, p.decodeColumnPage(a, column, page));
    }
    const column: s.Column = .{ .id = 1, .name = "v", .type = .uint64, .encoding = .bitpacked };
    const page = try p.encodeColumnPage(a, column, &.{ .{ .value = .{ .atom = .{ .unsigned = 0 } } }, .{ .value = .{ .atom = .{ .unsigned = 1 } } } }, &output);
    std.mem.writeInt(u64, output[p.page_header_bytes + 2 ..][0..8], std.math.maxInt(u64), .little);
    try t.expectError(error.InvalidBitpackedPage, p.decodeColumnPage(a, column, page));
}
