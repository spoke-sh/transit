const std = @import("std");
const Collation = @import("Collation.zig");
const GermanStringMod = @import("GermanString.zig");
const GermanString = GermanStringMod.GermanString;
const GermanCell = GermanStringMod.GermanCell;
const StringArena = GermanStringMod.StringArena;
const PhysicalCodecs = @import("PhysicalCodecs.zig");
const ColumnPredicate = @import("ColumnPredicate.zig");
const TableSchema = @import("TableSchema.zig");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const memory = @import("transit_memory");

test "GermanString 16-byte layout, inline vs arena threshold, and differential collation equivalence" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(GermanString));

    var backing: [4096]u8 = undefined;
    var arena = try StringArena.init(&backing);

    const profiles = [_]Collation.Profile{
        .none,
        .utf8_binary,
        .ascii_ci,
        .ebcdic_cp037,
        .ebcdic_037_pad,
        .ebcdic_1047_nopad,
    };

    const corpus = [_][]const u8{
        "",
        "a",
        "a   ",
        "A",
        "A ",
        "short_12_byt", // exactly 12 bytes: inline!
        "short_12_BYT",
        "medium_13_byt", // 13 bytes: out-of-line in StringArena!
        "medium_13_BYT",
        "shared_prefix_alpha_0001",
        "shared_prefix_alpha_0002",
        "shared_prefix_beta_0001",
        "0123456789abcdef0123456789abcdef",
        "[bracket_key_long_string]",
        "^caret_key_long_string^",
    };

    var probe: memory.AllocationProbe = .{ .parent = std.testing.allocator };
    probe.begin(true);

    for (profiles) |profile| {
        arena.reset();
        var gs_list: [corpus.len]GermanString = undefined;
        for (corpus, 0..) |s, i| {
            gs_list[i] = try GermanString.init(s, profile, &arena);
            const expected_len = try Collation.canonicalByteLenProfile(s, profile);
            try std.testing.expectEqual(expected_len <= 12, gs_list[i].isInline());
        }

        // Pairwise differential verification against scalar `Collation` oracle
        for (corpus, 0..) |left_s, li| {
            for (corpus, 0..) |right_s, ri| {
                const expected_ord = try Collation.compareBytesProfile(left_s, right_s, profile);
                const actual_ord = try gs_list[li].order(gs_list[ri], profile, &arena);
                try std.testing.expectEqual(expected_ord, actual_ord);

                const actual_eql = try gs_list[li].eql(gs_list[ri], profile, &arena);
                try std.testing.expectEqual(expected_ord == .eq, actual_eql);

                if (expected_ord == .eq) {
                    // Collation-equivalent strings (including PAD SPACE `'a'` and `'a   '`) must hash identically!
                    const hl = try gs_list[li].hash64(profile, &arena);
                    const hr = try gs_list[ri].hash64(profile, &arena);
                    try std.testing.expectEqual(hl, hr);
                }
            }
        }
    }

    // Stale generation handle detection after arena reset
    const long_gs = try GermanString.init("this_string_exceeds_twelve_bytes", .utf8_binary, &arena);
    try std.testing.expect(!long_gs.isInline());
    arena.reset();
    try std.testing.expectError(
        error.StaleStringArenaHandle,
        long_gs.eql(long_gs, .utf8_binary, &arena),
    );

    try probe.verify();
}

test "GermanString vectorized slice mask and 5-state GermanCell ordering" {
    var backing: [2048]u8 = undefined;
    var arena = try StringArena.init(&backing);

    const strings = [_]GermanString{
        try GermanString.init("alpha", .ascii_ci, &arena),
        try GermanString.init("BETA", .ascii_ci, &arena),
        try GermanString.init("beta_long_value_1", .ascii_ci, &arena),
        GermanString.empty, // null row (`tag = 1`)
        try GermanString.init("gamma", .ascii_ci, &arena),
    };
    const tags = [_]u8{ 0, 0, 0, 1, 0 };
    const lit = try GermanString.init("beta", .ascii_ci, &arena);

    const eq_mask = try GermanStringMod.filterSliceMask64(&strings, &tags, .eq, lit, .ascii_ci, &arena);
    try std.testing.expectEqual(@as(u64, 0b00010), eq_mask);

    const gt_mask = try GermanStringMod.filterSliceMask64(&strings, &tags, .gt, lit, .ascii_ci, &arena);
    try std.testing.expectEqual(@as(u64, 0b10100), gt_mask);

    // 5-state cell total order: missing < null < type_error < conflict < value
    const c_missing = try GermanCell.fromCell(.missing, .utf8_binary, &arena);
    const c_null = try GermanCell.fromCell(.null, .utf8_binary, &arena);
    const c_err = try GermanCell.fromCell(.{ .type_error = .utf8 }, .utf8_binary, &arena);
    const c_val = try GermanCell.fromCell(.{ .value = .{ .atom = .{ .bytes = "abc" } } }, .utf8_binary, &arena);
    try std.testing.expectEqual(std.math.Order.lt, try GermanCell.order(c_missing, c_null, .utf8_binary, &arena));
    try std.testing.expectEqual(std.math.Order.lt, try GermanCell.order(c_null, c_err, .utf8_binary, &arena));
    try std.testing.expectEqual(std.math.Order.lt, try GermanCell.order(c_err, c_val, .utf8_binary, &arena));
}

test "A1 & P3 compressed-domain .dictionary and .fsst string predicates and late materialization with zero steady-state allocations" {
    const raw_values = [_]Values.Cell{
        .{ .value = .{ .atom = .{ .bytes = "transit://accounts/alpha/stream" } } },
        .{ .value = .{ .atom = .{ .bytes = "transit://accounts/beta/queue" } } },
        .null,
        .missing,
        .{ .type_error = .utf8 },
        .{ .value = .{ .atom = .{ .bytes = "transit://accounts/alpha/table" } } },
        .{ .value = .{ .atom = .{ .bytes = "transit://system/catalog/manifest" } } },
        .{ .value = .{ .atom = .{ .bytes = "transit://accounts/gamma/document" } } },
    };

    const predicates = [_]ColumnPredicate.Predicate{
        .{ .compare = .{ .op = .eq, .value = .{ .bytes = "transit://accounts/alpha/table" } } },
        .{ .compare = .{ .op = .lt, .value = .{ .bytes = "transit://accounts/beta/queue" } } },
        .{ .in_set = &.{ "transit://accounts/beta/queue", "transit://system/catalog/manifest", "non_existent" } },
        .{ .starts_with = "transit://accounts/alpha/" },
        .{ .contains = "/catalog/" },
        .{ .like = .{ .pattern = "transit://accounts/%/table" } },
    };

    for ([_]TableSchema.Encoding{ .dictionary, .fsst }) |encoding| {
        for ([_]TableSchema.Collation{ .utf8_binary, .ascii_ci, .ebcdic_037_pad, .ebcdic_1047_nopad }) |collation| {
            const col: TableSchema.Column = .{
                .id = 1,
                .name = "uri",
                .type = .utf8,
                .encoding = encoding,
                .collation = collation,
            };

            var page_buf: [8192]u8 = undefined;
            const page = try PhysicalCodecs.encodeColumnPage(std.testing.allocator, col, &raw_values, &page_buf);

            var probe: memory.AllocationProbe = .{ .parent = std.testing.allocator };
            var workspace = std.heap.ArenaAllocator.init(probe.allocator());
            defer workspace.deinit();
            for (0..2) |pass| {
                for (predicates) |pred| {
                    try std.testing.expect(workspace.reset(.retain_capacity));
                    const a = workspace.allocator();
                    const result = try PhysicalCodecs.evaluateColumnPage(a, a, col, page, pred);
                    for (raw_values, result.outcomes) |cell, actual| try std.testing.expectEqual(try pred.evaluate(col, cell), actual);
                    if (encoding == .dictionary) try std.testing.expectEqual(@as(usize, 5), result.evaluated_values);
                    if (encoding == .fsst and (collation == .utf8_binary or collation == .ascii_ci) and (pred == .compare or pred == .starts_with)) {
                        try std.testing.expectEqual(@as(usize, 5), result.streamed_strings);
                        try std.testing.expectEqual(@as(usize, 0), result.materialized_strings);
                    }
                }
                try std.testing.expect(workspace.reset(.retain_capacity));
                const a = workspace.allocator();
                const selected = [_]u32{ 1, 2, 4, 6 };
                const materialized = try PhysicalCodecs.decodeColumnPageSelected(a, a, col, page, &selected);
                try std.testing.expectEqual(@as(usize, 4), materialized.cells.len);
                try std.testing.expectEqualStrings(raw_values[1].value.atom.bytes, materialized.cells[0].value.atom.bytes);
                try std.testing.expect(materialized.cells[1] == .null);
                try std.testing.expect(materialized.cells[2] == .type_error);
                try std.testing.expectEqualStrings(raw_values[6].value.atom.bytes, materialized.cells[3].value.atom.bytes);
                if (pass == 0) {
                    // Consolidation is part of warming the reusable arena.
                    // Wider logical cells can require more than one backing
                    // block on the initial materialization.
                    try std.testing.expect(workspace.reset(.retain_capacity));
                    probe.begin(true);
                } else try probe.verify();
            }
        }
    }
}

test "compressed collation predicates retain every byte-distinct equivalent dictionary code" {
    const t = std.testing;
    var workspace = std.heap.ArenaAllocator.init(t.allocator);
    defer workspace.deinit();
    const cells = [_]Values.Cell{
        .{ .value = .{ .atom = .{ .bytes = "A" } } },
        .{ .value = .{ .atom = .{ .bytes = "A " } } },
        .{ .value = .{ .atom = .{ .bytes = "a" } } },
        .{ .value = .{ .atom = .{ .bytes = "B" } } },
        .null,
    };
    for ([_]TableSchema.Encoding{ .dictionary, .fsst }) |encoding| {
        for ([_]struct { collation: TableSchema.Collation, mask: u8 }{
            .{ .collation = .utf8_binary, .mask = 0b00001 },
            .{ .collation = .ascii_ci, .mask = 0b00101 },
            .{ .collation = .ebcdic_cp037, .mask = 0b00001 },
            .{ .collation = .ebcdic_037_pad, .mask = 0b00011 },
            .{ .collation = .ebcdic_1047_nopad, .mask = 0b00001 },
        }) |case| {
            const column: TableSchema.Column = .{ .id = 1, .name = "code", .type = .utf8, .encoding = encoding, .collation = case.collation };
            var buffer: [8192]u8 = undefined;
            const page = try PhysicalCodecs.encodeColumnPage(t.allocator, column, &cells, &buffer);
            for ([_]ColumnPredicate.Predicate{
                .{ .compare = .{ .op = .eq, .value = .{ .bytes = "A" } } },
                .{ .compare = .{ .op = .ne, .value = .{ .bytes = "A" } } },
                .{ .in_set = &.{"A"} },
            }) |predicate| {
                _ = workspace.reset(.retain_capacity);
                const a = workspace.allocator();
                const result = try PhysicalCodecs.evaluateColumnPage(a, a, column, page, predicate);
                const outcomes = result.outcomes;
                for (outcomes[0..4], 0..) |actual, i| {
                    const equal = case.mask & (@as(u8, 1) << @intCast(i)) != 0;
                    const yes = if (predicate == .compare and predicate.compare.op == .ne) !equal else equal;
                    try t.expectEqual(if (yes) ColumnPredicate.Outcome.yes else .no, actual);
                }
                try t.expect(outcomes[4] != .yes);
            }
        }
    }
}

fn fsstPage(buffer: []u8, decoded_len: u32, symbol: []const u8, tokens: []const u8) ![]const u8 {
    var writer: std.Io.Writer = .fixed(buffer);
    try writer.writeAll("TCP1");
    try writer.writeAll(&@import("transit_protocol").Growth.definition_bytes);
    try writer.writeByte(@backingInt(TableSchema.Encoding.fsst));
    try writer.writeInt(u32, 1, .little);
    try writer.writeByte(0); // One value row.
    try writer.writeByte(1);
    try writer.writeByte(@intCast(symbol.len));
    try writer.writeAll(symbol);
    try writer.writeInt(u32, decoded_len, .little);
    try writer.writeInt(u32, @intCast(tokens.len), .little);
    try writer.writeAll(tokens);
    return writer.buffered();
}

test "FSST streaming validates malformed suffixes and unicode across symbol boundaries" {
    var workspace = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer workspace.deinit();
    const a = workspace.allocator();
    const col: TableSchema.Column = .{ .id = 1, .name = "text", .type = .utf8, .encoding = .fsst, .collation = .ascii_ci };
    const predicate: ColumnPredicate.Predicate = .{ .compare = .{ .op = .eq, .value = .{ .bytes = "not-a-match" } } };
    var bytes: [1024]u8 = undefined;
    const valid = try fsstPage(&bytes, 2, "\xc3", &.{ 0, 0xff, 0xa9 });
    const result = try PhysicalCodecs.evaluateColumnPage(a, a, col, valid, predicate);
    try std.testing.expectEqual(ColumnPredicate.Outcome.no, result.outcomes[0]);
    try std.testing.expectEqual(@as(usize, 1), result.streamed_strings);
    const invalid_cases = .{
        .{ @as(u32, 2), &[_]u8{ 0xff, 'a', 0xfe }, error.InvalidFsstStream },
        .{ @as(u32, 2), &[_]u8{ 0xff, 'a', 0xff }, error.InvalidFsstStream },
        .{ @as(u32, 1), &[_]u8{ 0xff, 'a', 0xff, 'b' }, error.InvalidFsstStream },
        .{ @as(u32, 3), &[_]u8{ 0xff, 'a', 0xff, 'b' }, error.InvalidFsstStream },
        .{ @as(u32, 2), &[_]u8{ 0xff, 0xc0, 0xff, 0x80 }, error.InvalidUtf8 },
        .{ @as(u32, 1), &[_]u8{0}, error.InvalidUtf8 },
    };
    inline for (invalid_cases) |case| {
        const page = try fsstPage(&bytes, case[0], "\xc3", case[1]);
        try std.testing.expectError(case[2], PhysicalCodecs.evaluateColumnPage(a, a, col, page, predicate));
        // An empty projection must not hide malformed unselected values either.
        try std.testing.expectError(case[2], PhysicalCodecs.decodeColumnPageSelected(a, a, col, page, &.{}));
    }
    var binary = col;
    binary.type = .binary;
    binary.collation = .none;
    const arbitrary = try fsstPage(&bytes, 1, "\xff", &.{0});
    try std.testing.expectEqual(ColumnPredicate.Outcome.yes, (try PhysicalCodecs.evaluateColumnPage(a, a, binary, arbitrary, .all)).outcomes[0]);
}

test "compressed pages preserve collation-equivalent dictionary codes and large FSST values" {
    var workspace = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer workspace.deinit();
    const a = workspace.allocator();
    var page_buffer: [65536]u8 = undefined;
    var col: TableSchema.Column = .{ .id = 1, .name = "text", .type = .utf8, .encoding = .dictionary, .collation = .ascii_ci };
    const equal = [_]Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "A" } } }, .{ .value = .{ .atom = .{ .bytes = "a" } } } };
    const duplicate_page = try PhysicalCodecs.encodeColumnPage(a, col, &equal, &page_buffer);
    const matches = try PhysicalCodecs.evaluateColumnPage(a, a, col, duplicate_page, .{ .compare = .{ .op = .eq, .value = .{ .bytes = "a" } } });
    try std.testing.expectEqualSlices(ColumnPredicate.Outcome, &.{ .yes, .yes }, matches.outcomes);
    try std.testing.expectEqual(@as(usize, 2), matches.evaluated_values);
    var values: [1025]Values.Cell = undefined;
    var names: [1025][4]u8 = undefined;
    for (&values, &names, 0..) |*value, *name, i| {
        _ = try std.fmt.bufPrint(name, "{d:0>4}", .{i});
        value.* = .{ .value = .{ .atom = .{ .bytes = name } } };
    }
    const large_dictionary = try PhysicalCodecs.encodeColumnPage(a, col, &values, &page_buffer);
    const many = try PhysicalCodecs.evaluateColumnPage(a, a, col, large_dictionary, .{ .starts_with = "10" });
    try std.testing.expectEqual(@as(usize, 1025), many.evaluated_values);
    for (many.outcomes, 0..) |out, i| try std.testing.expectEqual(if (i >= 1000) ColumnPredicate.Outcome.yes else .no, out);
    col.encoding = .fsst;
    const long: [8192]u8 = @splat('A');
    const input = [_]Values.Cell{.{ .value = .{ .atom = .{ .bytes = &long } } }};
    const long_page = try PhysicalCodecs.encodeColumnPage(a, col, &input, &page_buffer);
    const streamed = try PhysicalCodecs.evaluateColumnPage(a, a, col, long_page, .{ .starts_with = "aa" });
    try std.testing.expectEqual(ColumnPredicate.Outcome.yes, streamed.outcomes[0]);
    try std.testing.expectEqual(@as(usize, 1), streamed.streamed_strings);
    try std.testing.expectEqual(@as(usize, 0), streamed.materialized_strings);
    const selected = try PhysicalCodecs.decodeColumnPageSelected(a, a, col, long_page, &.{0});
    try std.testing.expectEqualStrings(&long, selected.cells[0].value.atom.bytes);
}

test "compressed predicates and empty selections validate unselected conflict details" {
    var workspace = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer workspace.deinit();
    const a = workspace.allocator();
    const alternatives = [_]Values.Alternative{
        .{ .counter = 1, .replica = 1, .value = .null },
        .{ .counter = 2, .replica = 1, .value = .null },
    };
    const cells = [_]Values.Cell{.{ .conflict = &alternatives }};
    var buffer: [256]u8 = undefined;
    for ([_]TableSchema.Encoding{ .dictionary, .fsst }) |encoding| {
        const col: TableSchema.Column = .{ .id = 1, .name = "text", .type = .utf8, .encoding = encoding, .collation = .utf8_binary };
        const page = try PhysicalCodecs.encodeColumnPage(a, col, &cells, &buffer);
        @memset(buffer[44..52], 0); // Invalid zero counter with otherwise valid framing.
        try std.testing.expectError(error.InvalidConflict, PhysicalCodecs.evaluateColumnPage(a, a, col, page, .all));
        try std.testing.expectError(error.InvalidConflict, PhysicalCodecs.decodeColumnPageSelected(a, a, col, page, &.{}));
    }
}
