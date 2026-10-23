const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const TableSchema = @import("TableSchema.zig");
const TableRow = @import("TableRow.zig");
const Collation = @import("Collation.zig");
const PhysicalCodecs = @import("PhysicalCodecs.zig");
const TDel = @import("TDel.zig");
const TSeg = @import("TSeg.zig");
const VectorKernel = @import("VectorKernel.zig");
const LogicalQuery = @import("LogicalQuery.zig");

test "Collation: order-preserving sort keys agree with compareBytes across supported collations" {
    const samples = [_][]const u8{
        "",
        "a",
        "A",
        "b",
        "B",
        "0",
        "9",
        "apple",
        "Apple",
        "APPLE",
        "banana",
        "100",
    };

    // 1. In EBCDIC CP037, lowercase 'a' (0x81) < uppercase 'A' (0xC1) < digit '0' (0xF0)
    try std.testing.expectEqual(std.math.Order.lt, try Collation.compareBytes("a", "A", .ebcdic_cp037));
    try std.testing.expectEqual(std.math.Order.lt, try Collation.compareBytes("A", "0", .ebcdic_cp037));
    try std.testing.expectEqual(std.math.Order.gt, try Collation.compareBytes("a", "A", .utf8_binary));
    try std.testing.expectEqual(std.math.Order.gt, try Collation.compareBytes("A", "0", .utf8_binary));
    try std.testing.expectEqual(std.math.Order.eq, try Collation.compareBytes("Apple", "apple", .ascii_ci));

    const collations = [_]Collation.Collation{ .utf8_binary, .ascii_ci, .ebcdic_cp037 };
    for (collations) |coll| {
        for (samples) |left| {
            for (samples) |right| {
                const cell_l: Values.Cell = .{ .value = .{ .atom = .{ .bytes = left } } };
                const cell_r: Values.Cell = .{ .value = .{ .atom = .{ .bytes = right } } };
                var buf_l: [256]u8 = undefined;
                var buf_r: [256]u8 = undefined;
                const sk_l = try Collation.encodeSortKey(cell_l, .utf8, coll, &buf_l);
                const sk_r = try Collation.encodeSortKey(cell_r, .utf8, coll, &buf_r);
                const direct = try Collation.compareCell(cell_l, cell_r, .utf8, coll);
                const via_key = std.mem.order(u8, sk_l, sk_r);
                try std.testing.expectEqual(direct, via_key);
            }
        }
    }
}

test "PhysicalCodecs: mainframe COMP-3, ZONED, COMP-4, IBM_HFP, and EBCDIC round-trip and capture corrupt bytes as type_error" {
    // 1. COMP-3 (Packed Decimal)
    var comp3_buf: [8]u8 = undefined;
    const c3_pos = try PhysicalCodecs.encodeComp3(1234567, 5, &comp3_buf);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x12, 0x34, 0x56, 0x7C }, c3_pos);
    const dec_pos = PhysicalCodecs.decodeComp3(c3_pos, .{ .decimal = .{ .precision = 10, .scale = 2 } });
    try std.testing.expectEqual(@as(i128, 1234567), dec_pos.value.atom.decimal);

    const c3_neg = try PhysicalCodecs.encodeComp3(-98765, 4, &comp3_buf);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x98, 0x76, 0x5D }, c3_neg);
    const dec_neg = PhysicalCodecs.decodeComp3(c3_neg, .int64);
    try std.testing.expectEqual(@as(i128, -98765), dec_neg.value.atom.signed);

    // Corrupt BCD nibble (0xFA in high digit) surfaces as .type_error instead of aborting
    const bad_comp3 = PhysicalCodecs.decodeComp3(&.{ 0xFA, 0x1C }, .int64);
    try std.testing.expect(bad_comp3 == .type_error);
    try std.testing.expectEqual(Types.Kind.int64, bad_comp3.type_error);

    // 2. ZONED Decimal
    var zoned_buf: [8]u8 = undefined;
    const z_neg = try PhysicalCodecs.encodeZoned(-4321, 5, &zoned_buf);
    try std.testing.expectEqualSlices(u8, &.{ 0xF0, 0xF4, 0xF3, 0xF2, 0xD1 }, z_neg);
    const dec_z = PhysicalCodecs.decodeZoned(z_neg, .int64);
    try std.testing.expectEqual(@as(i128, -4321), dec_z.value.atom.signed);

    const bad_zoned = PhysicalCodecs.decodeZoned(&.{ 0x00, 0xFF }, .int64);
    try std.testing.expect(bad_zoned == .type_error);

    // 3. COMP-4 (Big-endian two's complement)
    var comp4_buf: [8]u8 = undefined;
    const c4 = try PhysicalCodecs.encodeComp4(-32000, 2, &comp4_buf);
    const dec_c4 = PhysicalCodecs.decodeComp4(c4, .int16);
    try std.testing.expectEqual(@as(i128, -32000), dec_c4.value.atom.signed);

    // 4. IBM System/360 Hexadecimal Floating-Point (IBM_HFP)
    const hfp_bytes = try PhysicalCodecs.encodeIbmHfp64(-125.5);
    const dec_hfp = PhysicalCodecs.decodeIbmHfp(&hfp_bytes, .float64);
    try std.testing.expectApproxEqAbs(@as(f64, -125.5), dec_hfp.value.atom.float, 1e-9);

    // 5. EBCDIC CP037 string transcoding
    var eb_buf: [16]u8 = undefined;
    var utf_buf: [16]u8 = undefined;
    const eb = try PhysicalCodecs.encodeEbcdic037("ACCT-01", &eb_buf);
    const rt = try PhysicalCodecs.decodeEbcdic037(eb, &utf_buf);
    try std.testing.expectEqualStrings("ACCT-01", rt);
}

test "PhysicalCodecs: column pages round-trip all 10 codecs and preserve 5-state cells" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const page_buf = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(page_buf);

    const alt_pair = [_]Values.Alternative{
        .{ .counter = 1, .replica = 1, .value = .{ .value = .{ .atom = .{ .signed = 10 } } } },
        .{ .counter = 1, .replica = 2, .value = .{ .value = .{ .atom = .{ .signed = 20 } } } },
    };

    // Test bitpacked, rle, plain, comp3, zoned, comp4 on int64 with 5-state cells
    const int_cells = [_]Values.Cell{
        .{ .value = .{ .atom = .{ .signed = 100 } } },
        .null,
        .{ .value = .{ .atom = .{ .signed = 100 } } },
        .missing,
        .{ .type_error = .utf8 },
        .{ .conflict = &alt_pair },
        .{ .value = .{ .atom = .{ .signed = 250 } } },
    };

    const int_codecs = [_]TableSchema.Encoding{ .plain, .bitpacked, .rle, .dictionary, .comp_3, .zoned, .comp };
    for (int_codecs) |enc| {
        const col: TableSchema.Column = .{
            .id = 1,
            .name = "amount",
            .type = .int64,
            .nullable = true,
            .encoding = enc,
        };
        const encoded = try PhysicalCodecs.encodeColumnPage(arena, col, &int_cells, page_buf);
        const decoded = try PhysicalCodecs.decodeColumnPage(arena, col, encoded);
        try std.testing.expectEqual(int_cells.len, decoded.len);
        try std.testing.expectEqual(@as(i128, 100), decoded[0].value.atom.signed);
        try std.testing.expect(decoded[1] == .null);
        try std.testing.expectEqual(@as(i128, 100), decoded[2].value.atom.signed);
        try std.testing.expect(decoded[3] == .missing);
        try std.testing.expectEqual(Types.Kind.utf8, decoded[4].type_error);
        try std.testing.expectEqual(@as(usize, 2), decoded[5].conflict.len);
        try std.testing.expectEqual(@as(i128, 250), decoded[6].value.atom.signed);
    }

    // Test string codecs: plain, rle, dictionary, fsst, ebcdic
    const str_cells = [_]Values.Cell{
        .{ .value = .{ .atom = .{ .bytes = "TRANSIT-SEGMENT-001" } } },
        .null,
        .{ .value = .{ .atom = .{ .bytes = "TRANSIT-SEGMENT-001" } } },
        .{ .value = .{ .atom = .{ .bytes = "TRANSIT-SEGMENT-002" } } },
        .{ .type_error = .binary },
    };
    const str_codecs = [_]TableSchema.Encoding{ .plain, .rle, .dictionary, .fsst, .ebcdic };
    for (str_codecs) |enc| {
        const col: TableSchema.Column = .{
            .id = 2,
            .name = "code",
            .type = .utf8,
            .nullable = true,
            .encoding = enc,
            .collation = if (enc == .ebcdic) .ebcdic_cp037 else .utf8_binary,
        };
        const encoded = try PhysicalCodecs.encodeColumnPage(arena, col, &str_cells, page_buf);
        const decoded = try PhysicalCodecs.decodeColumnPage(arena, col, encoded);
        try std.testing.expectEqual(str_cells.len, decoded.len);
        try std.testing.expectEqualStrings("TRANSIT-SEGMENT-001", decoded[0].value.atom.bytes);
        try std.testing.expect(decoded[1] == .null);
        try std.testing.expectEqualStrings("TRANSIT-SEGMENT-001", decoded[2].value.atom.bytes);
        try std.testing.expectEqualStrings("TRANSIT-SEGMENT-002", decoded[3].value.atom.bytes);
        try std.testing.expectEqual(Types.Kind.binary, decoded[4].type_error);
    }
}

test "TSeg and TDel: hybrid OLTP/OLAP segment lookup, collation zone-map pruning, deletion vectors, and OCC overlap check" {
    const allocator = std.testing.allocator;
    const cols = [_]TableSchema.Column{
        .{ .id = 1, .name = "code", .type = .utf8, .nullable = false, .encoding = .ebcdic, .collation = .ebcdic_cp037 },
        .{ .id = 2, .name = "balance", .type = .{ .decimal = .{ .precision = 12, .scale = 2 } }, .encoding = .comp_3 },
    };
    const pk = [_]u64{1};
    const schema: TableSchema.Schema = .{
        .object = 42,
        .revision = 1,
        .columns = &cols,
        .primary_key = &pk,
        .next_column = 3,
    };

    // Notice unsorted input rows: "001", "AAA", "aaa", "BBB"
    // Under EBCDIC CP037 collation: "aaa" < "AAA" < "BBB" < "001"!
    const c_001 = [_]Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "001" } } }, .{ .value = .{ .atom = .{ .decimal = 1000 } } } };
    const c_AAA = [_]Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "AAA" } } }, .{ .value = .{ .atom = .{ .decimal = 2000 } } } };
    const c_aaa = [_]Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "aaa" } } }, .{ .value = .{ .atom = .{ .decimal = 3000 } } } };
    const c_BBB = [_]Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "BBB" } } }, .{ .value = .{ .atom = .{ .decimal = 4000 } } } };

    const rows = [_]TableRow.Row{
        .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = 0 }, .cells = &c_001 },
        .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = 1 }, .cells = &c_AAA },
        .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = 2 }, .cells = &c_aaa },
        .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = 3 }, .cells = &c_BBB },
    };

    const seg_buf = try allocator.alloc(u8, 128 * 1024);
    defer allocator.free(seg_buf);

    // Build with 2 rows per row-group so we get 2 row groups:
    // Group 0: ["aaa", "AAA"], Group 1: ["BBB", "001"]
    const seg_bytes = try TSeg.writeSegment(allocator, schema, &rows, .{ .segment_id = 10, .rows_per_group = 2 }, seg_buf);
    var footer = try TSeg.readFooter(allocator, seg_bytes);
    defer footer.deinit();

    try std.testing.expectEqual(@as(u32, 4), footer.total_rows);
    try std.testing.expectEqual(@as(usize, 2), footer.row_groups.len);

    // Verify 64-byte alignment of column pages and footer
    for (footer.row_groups) |rg| {
        for (rg.pages) |pg| {
            try std.testing.expectEqual(@as(u64, 0), pg.offset % 64);
        }
    }

    // Verify ZoneMap pruning under EBCDIC CP037 collation:
    // Target "aaa" is in Group 0 (["aaa", "AAA"]), NOT in Group 1 (["BBB", "001"])
    var sk_buf: [128]u8 = undefined;
    const sk_aaa = try Collation.encodeSortKey(c_aaa[0], .utf8, .ebcdic_cp037, &sk_buf);
    try std.testing.expect(footer.row_groups[0].zone_maps[0].mayMatch(.eq, sk_aaa));
    try std.testing.expect(!footer.row_groups[1].zone_maps[0].mayMatch(.eq, sk_aaa));

    // O(log N) Primary-Key lookup for "AAA"
    const key_AAA = [_]Values.Cell{.{ .value = .{ .atom = .{ .bytes = "AAA" } } }};
    var found = (try TSeg.lookupPrimaryKey(allocator, schema, &footer, seg_bytes, null, &key_AAA)).?;
    defer found.deinit();
    try std.testing.expectEqual(@as(i128, 2000), found.cells[1].value.atom.decimal);

    // Apply a `.tdel` deletion vector deleting "AAA" (row offset 1 in EBCDIC order: 0="aaa", 1="AAA", 2="BBB", 3="001")
    var del = try TDel.DeletionVector.init(allocator, 10, 4);
    defer del.deinit();
    _ = try del.markDeleted(1);

    var del_buf: [1024]u8 = undefined;
    const del_bytes = try del.encode(&del_buf);
    var decoded_del = try TDel.DeletionVector.decode(allocator, del_bytes);
    defer decoded_del.deinit();

    try std.testing.expect((try TSeg.lookupPrimaryKey(allocator, schema, &footer, seg_bytes, &decoded_del, &key_AAA)) == null);

    // Test OCC primary-key overlap detection against a disjoint segment ("ZZZ")
    const c_ZZZ = [_]Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "ZZZ" } } }, .{ .value = .{ .atom = .{ .decimal = 5000 } } } };
    const rows2 = [_]TableRow.Row{
        .{ .identity = .{ .origin = 2, .operation = 1, .ordinal = 0 }, .cells = &c_ZZZ },
    };
    const seg_buf2 = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(seg_buf2);
    const seg_bytes2 = try TSeg.writeSegment(allocator, schema, &rows2, .{ .segment_id = 11, .rows_per_group = 2 }, seg_buf2);
    var footer2 = try TSeg.readFooter(allocator, seg_bytes2);
    defer footer2.deinit();

    // Note: "ZZZ" falls between "BBB" and "001" in EBCDIC CP037, so its min/max range overlaps Group 1's range,
    // yet `overlapsPrimaryKeys` checks exact sorted PK entries and confirms zero key conflict!
    try std.testing.expect(!footer.overlapsPrimaryKeys(&footer2));
    try std.testing.expect(footer.overlapsPrimaryKeys(&footer));
}

test "VectorKernel: bindCollation evaluates predicates using declared collation" {
    const atom_ci = VectorKernel.Atom.bindCollation(
        .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .bytes = "transit" } } },
        .utf8,
        .ascii_ci,
    );
    const view: VectorKernel.View = .{ .constant = .{
        .value = .{ .value = .{ .atom = .{ .bytes = "TRANSIT" } } },
        .len = 1,
    } };
    var out: [1]VectorKernel.Outcome = undefined;
    atom_ci.run(atom_ci, view, 0, &out);
    try std.testing.expectEqual(@import("Finite.zig").Truth.true_value, out[0].truth);
}

test "segment readers reject foreign definition, interpretation and deletion ownership" {
    const t = std.testing;
    const columns = [_]TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const rows = [_]TableRow.Row{.{ .identity = .{ .origin = 1, .operation = 1, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 9 } } }} }};
    var bytes: [8192]u8 = undefined;
    const encoded = try TSeg.writeSegment(t.allocator, schema, &rows, .{ .segment_id = 1 }, &bytes);
    var footer = try TSeg.readFooter(t.allocator, encoded);
    defer footer.deinit();
    var changed = schema;
    changed.revision = 2;
    // Even a key that does not exist must check interpretation before pruning.
    try t.expectError(error.TableSchemaChanged, TSeg.lookupPrimaryKey(t.allocator, changed, &footer, encoded, null, &.{.{ .value = .{ .atom = .{ .signed = 0 } } }}));
    var deletion = try TDel.DeletionVector.init(t.allocator, 2, 1);
    defer deletion.deinit();
    try t.expectError(error.IncompatibleDeletionVector, TSeg.lookupPrimaryKey(t.allocator, schema, &footer, encoded, &deletion, &.{.{ .value = .{ .atom = .{ .signed = 9 } } }}));
    const trailer = encoded[encoded.len - 16 ..];
    const start: usize = @intCast(std.mem.readInt(u64, trailer[0..8], .little));
    const length = std.mem.readInt(u32, trailer[8..12], .little);
    bytes[start + 4] ^= 1;
    std.crypto.hash.sha2.Sha256.hash(bytes[start .. start + length - 32], bytes[start + length - 32 ..][0..32], .{});
    try t.expectError(error.IncompatibleDefinition, TSeg.readFooter(t.allocator, encoded));
    var del_bytes: [128]u8 = undefined;
    const del_encoded = try deletion.encode(&del_bytes);
    del_bytes[5] ^= 1;
    std.crypto.hash.sha2.Sha256.hash(del_bytes[0 .. del_encoded.len - 32], del_bytes[del_encoded.len - 32 ..][0..32], .{});
    try t.expectError(error.IncompatibleDefinition, TDel.DeletionVector.decode(t.allocator, del_encoded));
}
