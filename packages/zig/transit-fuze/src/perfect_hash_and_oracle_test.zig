const std = @import("std");
const Collation = @import("Collation.zig");
const PerfectHash = @import("PerfectHash.zig");
const SearchOracle = @import("SearchOracle.zig");
const Sql = @import("Sql.zig");
const TableSchema = @import("TableSchema.zig");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const memory = @import("transit_memory");

test "A2 collation 4-byte sort prefix and canonical length soundness across all profiles" {
    const profiles = [_]Collation.Profile{
        .none,
        .utf8_binary,
        .ascii_ci,
        .ebcdic_cp037,
        .ebcdic_037_pad,
        .ebcdic_1047_nopad,
    };
    const samples = [_][]const u8{
        "",
        "a",
        "a ",
        "a   ",
        "A",
        "A  ",
        "ab",
        "abc",
        "abcd",
        "abcde",
        "abcdef",
        "abcdZ",
        "abcdz",
        "0",
        "00",
        "9",
        "[bracket]",
        "^caret^",
        "alpha_1",
        "alpha_2",
        "ALPHA_1",
    };

    for (profiles) |profile| {
        for (samples) |left| {
            const len_l = try Collation.canonicalByteLenProfile(left, profile);
            const pref_l = try Collation.computeSortPrefix4BProfile(left, profile);
            for (samples) |right| {
                const len_r = try Collation.canonicalByteLenProfile(right, profile);
                const pref_r = try Collation.computeSortPrefix4BProfile(right, profile);
                const ground_truth = try Collation.compareBytesProfile(left, right, profile);
                const pref_order = Collation.compareSortPrefix4B(pref_l, pref_r);

                // Invariant 1: Whenever the 4-byte prefixes differ, prefix order equals full collation order!
                if (pref_order != .eq) {
                    try std.testing.expectEqual(ground_truth, pref_order);
                }
                // Invariant 2: Whenever canonical lengths or 4-byte prefixes differ, strings are not collation-equal!
                if (len_l != len_r or pref_order != .eq) {
                    try std.testing.expect(ground_truth != .eq);
                }
            }
        }
    }

    // Specifically verify PAD SPACE (`ebcdic_037_pad`) normalizes `'a'` and `'a   '` to identical header fields
    try std.testing.expectEqual(
        try Collation.canonicalByteLenProfile("a", .ebcdic_037_pad),
        try Collation.canonicalByteLenProfile("a   ", .ebcdic_037_pad),
    );
    try std.testing.expectEqualSlices(
        u8,
        &(try Collation.computeSortPrefix4BProfile("a", .ebcdic_037_pad)),
        &(try Collation.computeSortPrefix4BProfile("a   ", .ebcdic_037_pad)),
    );
}

test "PerfectHash ComptimeMap and FrozenDirectory exactness, non-member rejection, and zero allocations" {
    // 1. Verify SQL reserved words via ComptimeMap
    try std.testing.expect(Sql.isReserved("select"));
    try std.testing.expect(Sql.isReserved("SELECT"));
    try std.testing.expect(Sql.isReserved("SYSTEM_TIME"));
    try std.testing.expect(!Sql.isReserved("VALUE"));
    try std.testing.expect(!Sql.isReserved("UPDATE"));
    try std.testing.expect(!Sql.isReserved("select_all"));
    try std.testing.expect(!Sql.isReserved(""));

    // 2. Verify DDL and wire header ComptimeMaps
    try std.testing.expectEqual(PerfectHash.DdlOptionTag.encoding_fsst, PerfectHash.DdlOptionMap.get("fsst").?);
    try std.testing.expectEqual(PerfectHash.DdlOptionTag.index_block_max_bm25, PerfectHash.DdlOptionMap.get("BLOCK_MAX_BM25").?);
    try std.testing.expect(PerfectHash.DdlOptionMap.get("UNKNOWN_CODEC") == null);
    try std.testing.expectEqual(PerfectHash.WireHeaderTag.x_transit_snapshot, PerfectHash.WireHeaderMap.get("X-Transit-Snapshot").?);

    // 3. Verify FrozenDirectory under AllocationProbe (zero steady-state heap allocations)
    const keys = [_][]const u8{
        "tenant_id",
        "account_id",
        "event_timestamp",
        "payload_utf8",
        "status_code",
        "region_code",
        "request_id",
        "trace_span_id",
        "currency",
        "amount_cents",
        "merchant_name",
        "settlement_date",
    };

    var probe: memory.AllocationProbe = .{ .parent = std.testing.allocator };
    probe.begin(true);
    const dir = try PerfectHash.FrozenDirectory.init(&keys, .utf8_binary);
    try std.testing.expectEqual(PerfectHash.Mode.perfect_hash, dir.mode);

    for (keys, 0..) |k, expected_idx| {
        const found = try dir.lookup(&keys, k);
        try std.testing.expectEqual(@as(?u16, @intCast(expected_idx)), found);
    }
    const non_members = [_][]const u8{
        "",
        "tenant",
        "tenant_id_2",
        "account_id!",
        "unknown_column",
        "trace_span_ic",
        "settlement_datf",
        "0123456789abcdef0123456789abcdef",
    };
    for (non_members) |nm| {
        try std.testing.expectEqual(@as(?u16, null), try dir.lookup(&keys, nm));
    }
    try probe.verify();

    // 4. Verify TableSchema.NameDirectory integration
    const cols = [_]TableSchema.Column{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
        .{ .id = 2, .name = "title", .type = .utf8, .collation = .utf8_binary },
        .{ .id = 3, .name = "body", .type = .utf8, .collation = .utf8_binary },
    };
    const schema: TableSchema.Schema = .{
        .object = 42,
        .revision = 1,
        .next_column = 4,
        .columns = &cols,
        .primary_key = &.{1},
    };
    const schema_dir = try schema.buildNameDirectory();
    try std.testing.expectEqual(@as(usize, 0), try schema_dir.resolve("id"));
    try std.testing.expectEqual(@as(usize, 1), try schema_dir.resolve("title"));
    try std.testing.expectEqual(@as(usize, 2), try schema_dir.resolve("body"));
    try std.testing.expectError(error.UnknownColumn, schema_dir.resolve("missing"));
}

test "PerfectHash SIMD comparison accepts exact external allocations and every short tail" {
    for (0..17) |len| {
        const bytes = try std.testing.allocator.alloc(u8, len);
        defer std.testing.allocator.free(bytes);
        @memset(bytes, 'A');
        var expected: [16]u8 = @splat(0xCC);
        @memset(expected[0..len], 'a');
        try std.testing.expect(PerfectHash.simdEql16PageSafe(bytes, expected, expected, @intCast(len), true));
        if (len != 0) {
            try std.testing.expect(!PerfectHash.simdEql16PageSafe(bytes, expected, expected, @intCast(len), false));
            bytes[len - 1] = 'B';
            try std.testing.expect(!PerfectHash.simdEql16PageSafe(bytes, expected, expected, @intCast(len), true));
        }
        try std.testing.expect(!PerfectHash.simdEql16PageSafe(bytes, expected, expected, @intCast((len + 1) % 17), true));
    }
}

test "PerfectHash 16-byte SIMD string comparison at a protected page boundary" {
    if (@import("builtin").os.tag != .linux) return;
    const linux = std.os.linux;
    const page_len: usize = 4096;
    const map_addr = linux.mmap(
        null,
        page_len * 2,
        .{ .READ = true, .WRITE = true },
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    );
    try std.testing.expect(map_addr <= std.math.maxInt(usize) - 4096);
    const base: [*]align(4096) u8 = @ptrFromInt(map_addr);
    defer _ = linux.munmap(base, page_len * 2);

    // Protect the second 4 KiB page with PROT_NONE so any 16-byte SIMD overread faults immediately
    try std.testing.expectEqual(@as(usize, 0), linux.mprotect(@ptrCast(base + page_len), page_len, .{}));

    const word = "select";
    var expected_bytes: [16]u8 = @splat(0);
    @memcpy(expected_bytes[0..word.len], word);
    const expected_vec: @Vector(16, u8) = expected_bytes;

    // Every short tail must actually perform a comparison, rather than return
    // early on a mismatched length. Include the full-width boundary load.
    for (1..17) |len| {
        const start_offset = page_len - len;
        const slice = base[start_offset..page_len];
        @memset(slice, 'X');
        var expected: [16]u8 = @splat(0);
        @memset(expected[0..len], 'x');
        try std.testing.expect(PerfectHash.simdEql16PageSafe(slice, expected, expected, @intCast(len), true));
        slice[len - 1] = 'Y';
        try std.testing.expect(!PerfectHash.simdEql16PageSafe(slice, expected, expected, @intCast(len), true));
        if (len == word.len) {
            @memcpy(slice, "SELECT");
            try std.testing.expect(PerfectHash.simdEql16PageSafe(slice, expected_vec, expected_bytes, @intCast(word.len), true));
            try std.testing.expect(Sql.isReserved(slice));
        } else {
            try std.testing.expect(!PerfectHash.simdEql16PageSafe(slice, expected_vec, expected_bytes, @intCast(word.len), true));
        }
    }
}

test "SearchOracle segmentation, 5-state pattern matching, NEAR proximity, BM25 and hybrid fusion" {
    var tokens_buf: [64]SearchOracle.TokenSpan = undefined;
    var scratch_buf: [512]u8 = undefined;

    // 1. Segmenter profiles (`ascii_fold_v1` and `code_identifier_v1`)
    const doc_text = "TransitLog durable WAL and VectorKernel SIMD execution";
    const stop_words = [_][]const u8{"and"};
    const tokens = try SearchOracle.segmentText(
        doc_text,
        .ascii_fold_v1,
        &stop_words,
        &tokens_buf,
        &scratch_buf,
    );
    try std.testing.expectEqual(@as(usize, 6), tokens.len);
    try std.testing.expectEqualStrings("transitlog", tokens[0].term);
    try std.testing.expectEqualStrings("durable", tokens[1].term);
    try std.testing.expectEqualStrings("wal", tokens[2].term);
    try std.testing.expectEqualStrings("vectorkernel", tokens[3].term);
    try std.testing.expectEqualStrings("simd", tokens[4].term);
    try std.testing.expectEqualStrings("execution", tokens[5].term);

    // 2. `MATCH` and `NEAR` proximity
    try std.testing.expect(try SearchOracle.matchTokens(tokens, &.{ "durable", "simd" }, .conjunctive_and));
    try std.testing.expect(!try SearchOracle.matchTokens(tokens, &.{ "durable", "missing" }, .conjunctive_and));
    try std.testing.expect(try SearchOracle.nearTokens(tokens, &.{ "durable", "wal" }, 0, true));
    try std.testing.expect(!try SearchOracle.nearTokens(tokens, &.{ "wal", "durable" }, 0, true));
    try std.testing.expect(try SearchOracle.nearTokens(tokens, &.{ "wal", "durable" }, 0, false));
    try std.testing.expect(try SearchOracle.nearTokens(tokens, &.{ "transitlog", "wal" }, 1, true));
    try std.testing.expect(!try SearchOracle.nearTokens(tokens, &.{ "transitlog", "wal" }, 0, true));

    // 3. Code identifier segmentation (`camelCase` + `snake_case`)
    const code_tokens = try SearchOracle.segmentText(
        "computeSortPrefix4B_fast",
        .code_identifier_v1,
        &.{},
        &tokens_buf,
        &scratch_buf,
    );
    try std.testing.expectEqual(@as(usize, 4), code_tokens.len);
    try std.testing.expectEqualStrings("compute", code_tokens[0].term);
    try std.testing.expectEqualStrings("sort", code_tokens[1].term);
    try std.testing.expectEqualStrings("prefix4b", code_tokens[2].term);
    try std.testing.expectEqualStrings("fast", code_tokens[3].term);

    // 4. Five-state pattern predicates (`STARTS_WITH`, `CONTAINS`, `LIKE`)
    const val_cell: Values.Cell = .{ .value = .{ .atom = .{ .bytes = "TransitObjectStore" } } };
    const m1 = try SearchOracle.evaluatePatternCell(val_cell, .starts_with, "transitobject", null, .ascii_ci);
    try std.testing.expect(m1 == .value and m1.value);
    const m2 = try SearchOracle.evaluatePatternCell(val_cell, .like, "Transit%Store", null, .utf8_binary);
    try std.testing.expect(m2 == .value and m2.value);
    const err_cell: Values.Cell = .{ .type_error = .utf8 };
    const m3 = try SearchOracle.evaluatePatternCell(err_cell, .contains, "Transit", null, .utf8_binary);
    try std.testing.expect(m3 == .type_error and m3.type_error == .utf8);

    // 5. Quantized document length and Q16 impact upper-bound soundness (`A5`)
    for ([_]u32{ 1, 5, 16, 17, 31, 64, 129, 512, 4096 }) |dl| {
        const q = SearchOracle.quantizeNormDl(dl);
        const deq = SearchOracle.dequantizeNormDl(q);
        try std.testing.expect(deq <= dl);
    }
    const idf = SearchOracle.computeIdf(1000, 25);
    const exact_score = SearchOracle.scoreTermQuantized(4, SearchOracle.quantizeNormDl(120), 150.0, idf, .{});
    const q16 = SearchOracle.quantizeImpactQ16(exact_score);
    try std.testing.expect(SearchOracle.dequantizeImpactQ16(q16) >= exact_score);

    // 6. RRF and calibrated linear fusion
    const lex_top = [_]SearchOracle.ScoredDoc{
        .{ .doc_id = 10, .score = 8.5 },
        .{ .doc_id = 20, .score = 6.0 },
    };
    const vec_top = [_]SearchOracle.ScoredDoc{
        .{ .doc_id = 20, .score = 0.95 },
        .{ .doc_id = 30, .score = 0.80 },
    };
    var fused_scratch: [8]SearchOracle.ScoredDoc = undefined;
    const rrf = try SearchOracle.fuseRrf(&lex_top, &vec_top, 1.0, 1.0, 60, 3, &fused_scratch);
    try std.testing.expectEqual(@as(usize, 3), rrf.len);
    // Doc 20 appears in both lists so its RRF score is highest
    try std.testing.expectEqual(@as(u32, 20), rrf[0].doc_id);
}
