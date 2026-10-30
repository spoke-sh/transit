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
        for ([_]TableSchema.Collation{ .utf8_binary, .ascii_ci }) |collation| {
            const col: TableSchema.Column = .{
                .id = 1,
                .name = "uri",
                .type = .utf8,
                .encoding = encoding,
                .collation = collation,
            };

            var page_buf: [8192]u8 = undefined;
            const page = try PhysicalCodecs.encodeColumnPage(std.testing.allocator, col, &raw_values, &page_buf);

            // Seal allocator with AllocationProbe to verify zero steady-state heap allocations!
            var probe: memory.AllocationProbe = .{ .parent = std.testing.allocator };
            probe.begin(true);

            var outcomes_buf: [raw_values.len]ColumnPredicate.Outcome = undefined;
            for (predicates) |pred| {
                var stats: PhysicalCodecs.CompressedStringStats = .{};
                const outcomes = try PhysicalCodecs.evaluateCompressedStringPage(
                    col,
                    page,
                    pred,
                    &outcomes_buf,
                    &stats,
                );
                for (raw_values, outcomes) |cell, actual_outcome| {
                    const expected_outcome = try pred.evaluate(col, cell);
                    try std.testing.expectEqual(expected_outcome, actual_outcome);
                }
                if (encoding == .dictionary and (pred == .compare and pred.compare.op == .eq)) {
                    try std.testing.expectEqual(@as(u32, 1), stats.dictionary_perfect_hash_probes);
                }
            }

            // Verify late materialization of selected rows `[1, 2, 4, 6]` into GermanCell + StringArena
            var str_backing: [2048]u8 = undefined;
            var str_arena = try StringArena.init(&str_backing);
            var late_cells: [4]GermanCell = undefined;
            var late_stats: PhysicalCodecs.CompressedStringStats = .{};
            const selected = [_]u32{ 1, 2, 4, 6 };
            const mat = try PhysicalCodecs.lateMaterializeSelectedGermanStrings(
                col,
                page,
                &selected,
                &str_arena,
                &late_cells,
                &late_stats,
            );
            try std.testing.expectEqual(@as(usize, 4), mat.len);
            try std.testing.expectEqual(@as(u32, 2), late_stats.late_materialized_rows);
            try std.testing.expectEqual(@as(u32, 3), late_stats.skipped_unselected_rows);
            try std.testing.expectEqual(Types.State.value, mat[0].state);
            try std.testing.expectEqual(Types.State.null, mat[1].state);
            try std.testing.expectEqual(Types.State.type_error, mat[2].state);
            try std.testing.expectEqual(Types.State.value, mat[3].state);

            const profile = Collation.Profile.fromCollation(collation);
            const exp_row1 = try GermanString.init("transit://accounts/beta/queue", profile, &str_arena);
            const exp_row6 = try GermanString.init("transit://system/catalog/manifest", profile, &str_arena);
            try std.testing.expect(try mat[0].string.eql(exp_row1, profile, &str_arena));
            try std.testing.expect(try mat[3].string.eql(exp_row6, profile, &str_arena));

            try probe.verify();
        }
    }
}
