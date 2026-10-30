const std = @import("std");
const bitmap = @import("transit_bitmap");
const memory = @import("transit_memory");
const Collation = @import("Collation.zig");
const GermanString = @import("GermanString.zig");
const HybridSearch = @import("HybridSearch.zig");
const SearchOracle = @import("SearchOracle.zig");
const TSearchSegment = @import("TSearchSegment.zig");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const VectorizedSearch = @import("VectorizedSearch.zig");
const VectorMetric = @import("VectorMetric.zig");

test "P4: selectSearchAccessPath verifies segmenter_digest, collation, positions_enabled and .ready state" {
    const digest_unicode = SearchOracle.computeSegmenterDigest(.unicode_word_v1, .utf8_binary, &.{});
    const digest_ascii = SearchOracle.computeSegmenterDigest(.ascii_fold_v1, .utf8_binary, &.{});

    const desc: TSearchSegment.SearchIndexDescriptor = .{
        .index_id = 701,
        .column_id = 2,
        .collation = .utf8_binary,
        .segmenter_profile = .unicode_word_v1,
        .segmenter_digest = digest_unicode,
        .index_profile = .block_max_bm25_v1,
        .positions_enabled = true,
        .state = .ready,
    };

    const indices = [_]TSearchSegment.SearchIndexDescriptor{desc};

    // Matching index is selected.
    const matched = try TSearchSegment.selectSearchAccessPath(&indices, .{
        .column_id = 2,
        .collation = .utf8_binary,
        .segmenter_profile = .unicode_word_v1,
        .segmenter_digest = digest_unicode,
        .requires_positions = true,
        .require_index = true,
    });
    try std.testing.expectEqual(TSearchSegment.AccessPathSelection{ .index = 701 }, matched);

    // Mismatched segmenter falls back to scalar_oracle_fallback when require_index is false, and rejects when require_index is true.
    const fallback_seg = try TSearchSegment.selectSearchAccessPath(&indices, .{
        .column_id = 2,
        .collation = .utf8_binary,
        .segmenter_profile = .ascii_fold_v1,
        .segmenter_digest = digest_ascii,
    });
    try std.testing.expectEqual(
        TSearchSegment.AccessPathSelection{ .scalar_oracle_fallback = .segmenter_digest_mismatch },
        fallback_seg,
    );

    try std.testing.expectError(error.RequiredSearchIndexUnavailable, TSearchSegment.selectSearchAccessPath(&indices, .{
        .column_id = 2,
        .collation = .utf8_binary,
        .segmenter_profile = .ascii_fold_v1,
        .segmenter_digest = digest_ascii,
        .require_index = true,
    }));

    // Non-ready index is never selected.
    var building_desc = desc;
    building_desc.index_id = 702;
    building_desc.state = .backfilling;
    const building_slice = [_]TSearchSegment.SearchIndexDescriptor{building_desc};
    try std.testing.expectEqual(
        TSearchSegment.AccessPathSelection{ .scalar_oracle_fallback = .index_not_ready },
        try TSearchSegment.selectSearchAccessPath(&building_slice, .{
            .column_id = 2,
            .collation = .utf8_binary,
            .segmenter_profile = .unicode_word_v1,
            .segmenter_digest = digest_unicode,
        }),
    );
}

test "P5 & P6: 256-doc Block-Max BM25 segment, header CRC32, WAND pruning, NEAR/WITHIN and SearchOracle equivalence" {
    const allocator = std.testing.allocator;

    // Build a 600-document corpus (3 windows of 256 docs: [0..255], [256..511], [512..599]).
    const doc_count: usize = 600;
    var cells = try allocator.alloc(Values.Cell, doc_count);
    defer allocator.free(cells);
    var doc_strings = try allocator.alloc([]u8, doc_count);
    defer {
        for (doc_strings) |s| allocator.free(s);
        allocator.free(doc_strings);
    }

    for (0..doc_count) |idx| {
        if (idx == 17) {
            doc_strings[idx] = try allocator.dupe(u8, "");
            cells[idx] = .missing;
            continue;
        }
        if (idx == 42) {
            doc_strings[idx] = try allocator.dupe(u8, "");
            cells[idx] = .null;
            continue;
        }
        if (idx == 550) {
            // High-relevance document in window 2 with both "transit" and "vectorized" repeated and adjacent.
            doc_strings[idx] = try std.fmt.allocPrint(
                allocator,
                "transit vectorized query engine transit vectorized search transit doc_{d}",
                .{idx},
            );
        } else if (idx == 520) {
            // Document in window 2 with "transit" and "vectorized" separated by 3 intermediate tokens.
            doc_strings[idx] = try std.fmt.allocPrint(
                allocator,
                "transit storage durable log vectorized execution doc_{d}",
                .{idx},
            );
        } else if (idx < 300) {
            // Ensure "transit" has > 256 postings so it spans multiple 256-doc posting blocks (`block_doc_capacity = 256`),
            // with low term frequency (tf = 1) and longer document length so window 0 & 1 have a lower Block-Max bound than doc 550.
            doc_strings[idx] = try std.fmt.allocPrint(
                allocator,
                "transit background telemetry metric observation counter sample filler padding extra words item_{d}",
                .{idx},
            );
        } else {
            doc_strings[idx] = try std.fmt.allocPrint(
                allocator,
                "background telemetry metric observation counter sample filler padding text item_{d}",
                .{idx},
            );
        }
        cells[idx] = .{ .value = .{ .atom = .{ .bytes = doc_strings[idx] } } };
    }

    const digest = SearchOracle.computeSegmenterDigest(.unicode_word_v1, .utf8_binary, &.{});
    const descriptor: TSearchSegment.SearchIndexDescriptor = .{
        .index_id = 801,
        .column_id = 1,
        .collation = .utf8_binary,
        .segmenter_profile = .unicode_word_v1,
        .segmenter_digest = digest,
        .index_profile = .block_max_bm25_v1,
        .positions_enabled = true,
        .state = .ready,
    };

    var segment = try TSearchSegment.Segment.build(
        allocator,
        descriptor,
        &.{},
        cells,
    );
    defer segment.deinit();

    // Verify "TSS1" header envelope round-trip and CRC32 corruption rejection.
    var hdr_buf: [256]u8 = undefined;
    const hdr_bytes = try segment.encodeHeaderEnvelope(&hdr_buf);
    const decoded_hdr = try TSearchSegment.Segment.validateHeaderEnvelope(hdr_bytes);
    try std.testing.expectEqual(@as(u64, 801), decoded_hdr.index_id);
    try std.testing.expectEqual(@as(u32, 600), decoded_hdr.row_count);

    var corrupt_hdr: [256]u8 = undefined;
    @memcpy(corrupt_hdr[0..hdr_bytes.len], hdr_bytes);
    corrupt_hdr[40] ^= 0x01;
    try std.testing.expectError(
        error.SearchSegmentChecksumMismatch,
        TSearchSegment.Segment.validateHeaderEnvelope(corrupt_hdr[0..hdr_bytes.len]),
    );

    const q_terms = [_][]const u8{ "transit", "vectorized" };
    const t0_meta = (try segment.findTerm("transit")).?;
    const t1_meta = (try segment.findTerm("vectorized")).?;
    // "transit" appears in > 256 documents so it spans 2 posting blocks.
    try std.testing.expect(t0_meta.block_count >= 2);

    for ([_]usize{ 1, 5, 10, 50 }) |k| {
        const wand_out = try allocator.alloc(SearchOracle.ScoredDoc, k);
        defer allocator.free(wand_out);
        var stats: VectorizedSearch.SearchExecutionStats = .{};

        var probe: memory.AllocationProbe = .{ .parent = allocator };
        probe.begin(true);

        const hits = try VectorizedSearch.executeBlockMaxSearch(
            &segment,
            .{
                .terms = &q_terms,
                .mode = .disjunctive_or,
                .top_k = k,
            },
            null,
            null,
            wand_out,
            &stats,
        );

        try probe.verify();
        try std.testing.expect(hits.len > 0);
        try std.testing.expectEqual(@as(u32, 550), hits[0].doc_id);

        // Compare every returned document's score against SearchOracle.scoreTermQuantized.
        var tok_buf: [64]SearchOracle.TokenSpan = undefined;
        var byte_scratch: [1024]u8 = undefined;
        for (hits) |hit| {
            const doc_tokens = try SearchOracle.segmentText(
                doc_strings[hit.doc_id],
                .unicode_word_v1,
                &.{},
                &tok_buf,
                &byte_scratch,
            );
            const tf0 = SearchOracle.countTermFrequency(doc_tokens, "transit");
            const tf1 = SearchOracle.countTermFrequency(doc_tokens, "vectorized");
            const norm = segment.norm_dl[hit.doc_id];
            const oracle_score =
                SearchOracle.scoreTermQuantized(tf0, norm, segment.avg_doc_len, t0_meta.idf, segment.descriptor.bm25_params) +
                SearchOracle.scoreTermQuantized(tf1, norm, segment.avg_doc_len, t1_meta.idf, segment.descriptor.bm25_params);
            try std.testing.expectApproxEqAbs(oracle_score, hit.score, 1e-12);
        }
    }

    // Verify Block-Max WAND block skipping when searching in conjunctive mode (`AND`):
    // Windows 0 and 1 have 0 occurrences of "vectorized", so WAND skips their "transit" blocks!
    var and_out: [10]SearchOracle.ScoredDoc = undefined;
    var and_stats: VectorizedSearch.SearchExecutionStats = .{};
    const and_hits = try VectorizedSearch.executeBlockMaxSearch(
        &segment,
        .{
            .terms = &q_terms,
            .mode = .conjunctive_and,
            .top_k = 10,
        },
        null,
        null,
        &and_out,
        &and_stats,
    );
    try std.testing.expectEqual(@as(usize, 2), and_hits.len);
    try std.testing.expect(and_stats.blocks_skipped_by_wand > 0);

    // Test NEAR / WITHIN proximity verification:
    // max_distance == 0 (exact adjacent phrase "transit vectorized") matches doc 550, excluding doc 520 (3 tokens between).
    var near_out: [10]SearchOracle.ScoredDoc = undefined;
    var near_stats: VectorizedSearch.SearchExecutionStats = .{};
    const near_tight = try VectorizedSearch.executeBlockMaxSearch(
        &segment,
        .{
            .terms = &q_terms,
            .mode = .conjunctive_and,
            .proximity = .{ .max_distance = 0, .ordered = true },
            .top_k = 10,
        },
        null,
        null,
        &near_out,
        &near_stats,
    );
    try std.testing.expectEqual(@as(usize, 1), near_tight.len);
    try std.testing.expectEqual(@as(u32, 550), near_tight[0].doc_id);
    try std.testing.expect(near_stats.positional_verifications > 0);

    // max_distance == 3 matches both doc 550 and doc 520.
    const near_wide = try VectorizedSearch.executeBlockMaxSearch(
        &segment,
        .{
            .terms = &q_terms,
            .mode = .conjunctive_and,
            .proximity = .{ .max_distance = 3, .ordered = true },
            .top_k = 10,
        },
        null,
        null,
        &near_out,
        &near_stats,
    );
    try std.testing.expectEqual(@as(usize, 2), near_wide.len);
    try std.testing.expectEqual(@as(u32, 550), near_wide[0].doc_id);
    try std.testing.expectEqual(@as(u32, 520), near_wide[1].doc_id);

    // Test .tdel tombstone and visibility mask block skipping:
    var tdel: bitmap.Container = .{};
    _ = tdel.set(550);

    var vis: bitmap.Container = .{};
    // Only allow window 2 documents [512..599]. Windows 0 and 1 must be skipped by visibility!
    for (512..600) |d| _ = vis.set(@intCast(d));

    var vis_stats: VectorizedSearch.SearchExecutionStats = .{};
    const filtered_hits = try VectorizedSearch.executeBlockMaxSearch(
        &segment,
        .{
            .terms = &q_terms,
            .mode = .disjunctive_or,
            .top_k = 10,
        },
        &tdel,
        &vis,
        &near_out,
        &vis_stats,
    );
    try std.testing.expect(filtered_hits.len > 0);
    try std.testing.expectEqual(@as(u32, 520), filtered_hits[0].doc_id);
    try std.testing.expect(vis_stats.blocks_skipped_by_visibility >= 2);

    // Test 5-state type_error and conflict frontier enforcement when not masked out:
    cells[10] = .{ .type_error = .int64 };
    var err_segment = try TSearchSegment.Segment.build(
        allocator,
        descriptor,
        &.{},
        cells[0..32],
    );
    defer err_segment.deinit();

    try std.testing.expectError(
        error.QueryTypeError,
        VectorizedSearch.executeBlockMaxSearch(
            &err_segment,
            .{ .terms = &q_terms, .mode = .disjunctive_or, .top_k = 5 },
            null,
            null,
            &near_out,
            null,
        ),
    );

    // When doc 10 is tombstoned in .tdel, the query succeeds without raising QueryTypeError.
    _ = tdel.set(10);
    _ = try VectorizedSearch.executeBlockMaxSearch(
        &err_segment,
        .{ .terms = &q_terms, .mode = .disjunctive_or, .top_k = 5 },
        &tdel,
        null,
        &near_out,
        null,
    );
}

test "P7: Single-snapshot hybrid search (RRF and linear fusion), policy_epoch fencing and late materialization" {
    const allocator = std.testing.allocator;

    const docs = [_][]const u8{
        "transit durable log storage segment",
        "vectorized string perfect hash execution",
        "hybrid search lexical bm25 and dense vector similarity",
        "background noise document without target keywords",
    };
    const cells = [_]Values.Cell{
        .{ .value = .{ .atom = .{ .bytes = docs[0] } } },
        .{ .value = .{ .atom = .{ .bytes = docs[1] } } },
        .{ .value = .{ .atom = .{ .bytes = docs[2] } } },
        .{ .value = .{ .atom = .{ .bytes = docs[3] } } },
    };

    const digest = SearchOracle.computeSegmenterDigest(.unicode_word_v1, .utf8_binary, &.{});
    const descriptor: TSearchSegment.SearchIndexDescriptor = .{
        .index_id = 901,
        .column_id = 1,
        .collation = .utf8_binary,
        .segmenter_profile = .unicode_word_v1,
        .segmenter_digest = digest,
        .index_profile = .block_max_bm25_v1,
        .positions_enabled = true,
        .state = .ready,
    };

    var segment = try TSearchSegment.Segment.build(
        allocator,
        descriptor,
        &.{},
        &cells,
    );
    defer segment.deinit();

    // 4-dimensional float32 vectors for the 4 documents.
    const doc_vectors_f32 = [_]f32{
        0.1, 0.2, 0.1, 0.0, // doc 0
        0.2, 0.9, 0.1, 0.1, // doc 1 (strong vector similarity)
        0.9, 0.8, 0.2, 0.1, // doc 2 (strong lexical + strong vector similarity)
        0.0, 0.1, 0.9, 0.9, // doc 3
    };
    const query_vec_f32 = [_]f32{ 0.9, 0.85, 0.15, 0.1 };

    const slab: HybridSearch.VectorSlab = .{
        .descriptor = .{
            .dimensions = 4,
            .element = .float32,
            .metric = .cosine,
        },
        .bytes = std.mem.sliceAsBytes(&doc_vectors_f32),
        .doc_count = 4,
    };

    var arena_backing: [512]u8 = undefined;
    var arena = try GermanString.StringArena.init(&arena_backing);
    var quota: memory.Quota = .{ .limit = 4096 };

    var lex_scratch: [4]SearchOracle.ScoredDoc = undefined;
    var vec_scratch: [4]SearchOracle.ScoredDoc = undefined;
    var fused_scratch: [8]SearchOracle.ScoredDoc = undefined;
    var out_rows: [2]HybridSearch.HybridResultRow = undefined;

    const terms = [_][]const u8{ "hybrid", "vector", "vectorized" };

    var probe: memory.AllocationProbe = .{ .parent = allocator };
    probe.begin(true);

    const rrf_res = try HybridSearch.executeHybridSearch(
        .{
            .binding = .{ .snapshot_lsn = 900, .catalog_revision = 12, .policy_epoch = 5 },
            .current_policy_epoch = 5,
            .lexical_segment = &segment,
            .lexical_query = .{
                .terms = &terms,
                .mode = .disjunctive_or,
                .top_k = 2,
            },
            .vector_slab = slab,
            .query_vector_bytes = std.mem.sliceAsBytes(&query_vec_f32),
            .fusion = .{ .rrf = .{ .rrf_k = 60 } },
            .k = 2,
            .overfetch_k = 4,
            .source_texts = &docs,
        },
        &quota,
        &lex_scratch,
        &vec_scratch,
        &fused_scratch,
        &arena,
        &out_rows,
    );

    try probe.verify();
    try std.testing.expectEqual(@as(usize, 0), quota.used.load(.acquire));
    try std.testing.expect(quota.peak.load(.acquire) > 0);
    try std.testing.expectEqual(@as(usize, 2), rrf_res.count);
    try std.testing.expectEqual(@as(u32, 2), out_rows[0].doc_id);
    try std.testing.expectEqual(@as(u32, 1), out_rows[1].doc_id);
    try std.testing.expectEqual(@as(u32, 2), rrf_res.explain.late_materialized_rows);
    try std.testing.expectEqualStrings(docs[2], try arena.resolve(out_rows[0].materialized_text.?.string.handle()));

    // Also verify calibrated linear combination and tombstone consistency across both legs.
    var tdel: bitmap.Container = .{};
    _ = tdel.set(2); // Tombstone doc 2; neither lexical nor vector leg may return doc 2!

    arena.reset();
    const lin_res = try HybridSearch.executeHybridSearch(
        .{
            .binding = .{ .snapshot_lsn = 901, .catalog_revision = 12, .policy_epoch = 5 },
            .current_policy_epoch = 5,
            .lexical_segment = &segment,
            .lexical_query = .{
                .terms = &terms,
                .mode = .disjunctive_or,
                .top_k = 2,
            },
            .vector_slab = slab,
            .query_vector_bytes = std.mem.sliceAsBytes(&query_vec_f32),
            .fusion = .{ .linear = .{ .alpha = 0.5 } },
            .k = 2,
            .overfetch_k = 4,
            .deleted_bitmap = &tdel,
            .source_texts = &docs,
        },
        &quota,
        &lex_scratch,
        &vec_scratch,
        &fused_scratch,
        &arena,
        &out_rows,
    );
    try std.testing.expectEqual(@as(usize, 2), lin_res.count);
    try std.testing.expectEqual(@as(u32, 1), out_rows[0].doc_id);
    for (out_rows[0..lin_res.count]) |row| {
        try std.testing.expect(row.doc_id != 2);
    }

    // Policy epoch mismatch must reject disclosure with error.PolicyEpochRevoked.
    try std.testing.expectError(error.PolicyEpochRevoked, HybridSearch.executeHybridSearch(
        .{
            .binding = .{ .snapshot_lsn = 901, .catalog_revision = 12, .policy_epoch = 5 },
            .current_policy_epoch = 6,
            .lexical_segment = &segment,
            .lexical_query = .{
                .terms = &terms,
                .mode = .disjunctive_or,
                .top_k = 2,
            },
            .vector_slab = slab,
            .query_vector_bytes = std.mem.sliceAsBytes(&query_vec_f32),
            .fusion = .{ .rrf = .{ .rrf_k = 60 } },
            .k = 2,
        },
        &quota,
        &lex_scratch,
        &vec_scratch,
        &fused_scratch,
        &arena,
        &out_rows,
    ));
}
