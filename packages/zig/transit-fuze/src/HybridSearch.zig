//! Single-snapshot hybrid search operator combining Block-Max BM25 lexical
//! execution (`VectorizedSearch`) with dense/binary vector slab candidate scoring
//! (`VectorMetric`) under one pinned `(snapshot_lsn, catalog_revision, policy_epoch)`
//! and shared `.tdel` / relational / RLS Roaring bitmasks.
const std = @import("std");
const bitmap = @import("transit_bitmap");
const memory = @import("transit_memory");
const Collation = @import("Collation.zig");
const GermanString = @import("GermanString.zig");
const SearchOracle = @import("SearchOracle.zig");
const TSearchSegment = @import("TSearchSegment.zig");
const VectorizedSearch = @import("VectorizedSearch.zig");
const VectorMetric = @import("VectorMetric.zig");

pub const SnapshotBinding = struct {
    snapshot_lsn: u64,
    catalog_revision: u64,
    policy_epoch: u64,

    pub fn verifyDisclosure(self: SnapshotBinding, current_policy_epoch: u64) !void {
        if (current_policy_epoch != self.policy_epoch) return error.PolicyEpochRevoked;
    }
};

pub const VectorSlab = struct {
    descriptor: VectorMetric.Descriptor,
    /// Packed vector bytes for `doc_count` rows (`doc_count * row_byte_stride`).
    bytes: []const u8,
    doc_count: u32,
    valid_bitmap: ?*const bitmap.Container = null,

    pub fn validate(self: VectorSlab) !usize {
        try self.descriptor.validate();
        const stride = try self.descriptor.element.byteSizeForDimensions(self.descriptor.dimensions);
        if (self.bytes.len != @as(usize, self.doc_count) * stride) return error.VectorSlabSizeMismatch;
        return stride;
    }

    pub fn vectorBytesForDoc(self: VectorSlab, stride: usize, doc_id: u32) []const u8 {
        const start = @as(usize, doc_id) * stride;
        return self.bytes[start .. start + stride];
    }
};

pub const FusionMode = union(enum) {
    rrf: struct {
        lexical_weight: f64 = 1.0,
        vector_weight: f64 = 1.0,
        rrf_k: u32 = 60,
    },
    linear: struct {
        alpha: f64,
        norm_mode: SearchOracle.NormMode = .min_max,
        lexical_max_bound: f64 = 1.0,
        vector_max_bound: f64 = 1.0,
    },
};

pub const ExplainSummary = struct {
    snapshot_lsn: u64,
    catalog_revision: u64,
    policy_epoch: u64,
    segmenter_profile: SearchOracle.SegmenterProfile,
    index_profile: TSearchSegment.IndexProfile,
    blocks_inspected: u32,
    blocks_skipped_by_wand: u32,
    blocks_skipped_by_visibility: u32,
    positional_verifications: u32,
    lexical_docs_scored: u32,
    vector_candidates_scored: u32,
    late_materialized_rows: u32,
};

pub const HybridResultRow = struct {
    doc_id: u32,
    fused_score: f64,
    lexical_score: f64,
    vector_score: f64,
    materialized_text: ?GermanString.GermanCell = null,
};

pub const HybridRequest = struct {
    binding: SnapshotBinding,
    current_policy_epoch: u64,
    lexical_segment: *const TSearchSegment.Segment,
    lexical_query: VectorizedSearch.SearchQuery,
    vector_slab: VectorSlab,
    query_vector_bytes: []const u8,
    fusion: FusionMode,
    k: usize,
    overfetch_k: usize = 0,
    deleted_bitmap: ?*const bitmap.Container = null,
    visibility_bitmap: ?*const bitmap.Container = null,
    source_texts: ?[]const []const u8 = null,
    text_collation: Collation.Profile = .utf8_binary,
};

pub const HybridExecutionResult = struct {
    explain: ExplainSummary,
    count: usize,
};

/// Similarity conversion from `VectorMetric.evaluateBytes` so higher scores
/// always indicate stronger similarity across all metrics.
pub fn similarityFromMetricEval(metric: VectorMetric.Metric, raw_eval: f64, dimensions: u32) f64 {
    return switch (metric) {
        .dot_product => raw_eval,
        .cosine => 1.0 - (raw_eval / 2.0),
        .l2_squared => 1.0 / (1.0 + raw_eval),
        .hamming => blk: {
            const max_bits: f64 = @floatFromInt(dimensions);
            if (max_bits <= 0.0) break :blk 0.0;
            break :blk 1.0 - (raw_eval / max_bits);
        },
    };
}

/// Scores vector slab candidates under the same `.tdel` and visibility masks
/// and returns top-`limit` candidates ordered by `score` descending, `doc_id` ascending.
pub fn scoreVectorSlabCandidates(
    slab: VectorSlab,
    query_vector_bytes: []const u8,
    deleted_bitmap: ?*const bitmap.Container,
    visibility_bitmap: ?*const bitmap.Container,
    out_candidates: []SearchOracle.ScoredDoc,
    candidates_scored_out: *u32,
) ![]SearchOracle.ScoredDoc {
    const stride = try slab.validate();
    if (query_vector_bytes.len != stride) return error.VectorDimensionMismatch;

    const k = out_candidates.len;
    var heap_len: usize = 0;
    var scored_count: u32 = 0;

    var doc_id: u32 = 0;
    while (doc_id < slab.doc_count) : (doc_id += 1) {
        const doc_u16: u16 = @intCast(doc_id);
        if (deleted_bitmap) |del| {
            if (del.contains(doc_u16)) continue;
        }
        if (visibility_bitmap) |vis| {
            if (!vis.contains(doc_u16)) continue;
        }
        if (slab.valid_bitmap) |valid| {
            if (!valid.contains(doc_u16)) continue;
        }

        const doc_vec = slab.vectorBytesForDoc(stride, doc_id);
        const raw_eval = try VectorMetric.evaluateBytes(slab.descriptor, query_vector_bytes, doc_vec);
        const sim = similarityFromMetricEval(slab.descriptor.metric, raw_eval, slab.descriptor.dimensions);
        scored_count += 1;

        if (k == 0) continue;
        const candidate: SearchOracle.ScoredDoc = .{ .doc_id = doc_id, .score = sim };
        if (heap_len < k) {
            out_candidates[heap_len] = candidate;
            heap_len += 1;
        } else {
            var worst_idx: usize = 0;
            for (1..heap_len) |idx| {
                if (SearchOracle.ScoredDoc.lessThan({}, out_candidates[worst_idx], out_candidates[idx])) {
                    worst_idx = idx;
                }
            }
            if (SearchOracle.ScoredDoc.lessThan({}, candidate, out_candidates[worst_idx])) {
                out_candidates[worst_idx] = candidate;
            }
        }
    }

    std.mem.sort(SearchOracle.ScoredDoc, out_candidates[0..heap_len], {}, SearchOracle.ScoredDoc.lessThan);
    candidates_scored_out.* = scored_count;
    return out_candidates[0..heap_len];
}

/// Executes single-snapshot hybrid search (`RRF` or calibrated linear fusion)
/// using preallocated scratch buffers (`lex_scratch`, `vec_scratch`, `fused_scratch`)
/// with zero steady-state heap allocations and optional late materialization of
/// surviving top-`k` rows into `string_arena`.
pub fn executeHybridSearch(
    req: HybridRequest,
    quota: ?*memory.Quota,
    lex_scratch: []SearchOracle.ScoredDoc,
    vec_scratch: []SearchOracle.ScoredDoc,
    fused_scratch: []SearchOracle.ScoredDoc,
    string_arena: ?*GermanString.StringArena,
    out_rows: []HybridResultRow,
) !HybridExecutionResult {
    // Verify authorization epoch before executing and again before disclosing results.
    try req.binding.verifyDisclosure(req.current_policy_epoch);
    if (req.lexical_segment.row_count != req.vector_slab.doc_count) {
        return error.SnapshotDocCountMismatch;
    }

    const working_k = if (req.overfetch_k > req.k) req.overfetch_k else req.k;
    if (lex_scratch.len < working_k or vec_scratch.len < working_k) {
        return error.ScratchBufferTooSmall;
    }
    if (fused_scratch.len < working_k * 2 or out_rows.len < req.k) {
        return error.ScratchBufferTooSmall;
    }

    const working_bytes = (working_k * 4) * @sizeOf(SearchOracle.ScoredDoc);
    if (quota) |q| try q.reserve(working_bytes);
    defer if (quota) |q| q.release(working_bytes);

    var lex_query = req.lexical_query;
    lex_query.top_k = working_k;

    var lex_stats: VectorizedSearch.SearchExecutionStats = .{};
    const lex_hits = try VectorizedSearch.executeBlockMaxSearch(
        req.lexical_segment,
        lex_query,
        req.deleted_bitmap,
        req.visibility_bitmap,
        lex_scratch[0..working_k],
        &lex_stats,
    );

    var vec_scored: u32 = 0;
    const vec_hits = try scoreVectorSlabCandidates(
        req.vector_slab,
        req.query_vector_bytes,
        req.deleted_bitmap,
        req.visibility_bitmap,
        vec_scratch[0..working_k],
        &vec_scored,
    );

    const fused_hits = switch (req.fusion) {
        .rrf => |cfg| try SearchOracle.fuseRrf(
            lex_hits,
            vec_hits,
            cfg.lexical_weight,
            cfg.vector_weight,
            cfg.rrf_k,
            req.k,
            fused_scratch,
        ),
        .linear => |cfg| try SearchOracle.fuseLinear(
            lex_hits,
            vec_hits,
            cfg.alpha,
            cfg.norm_mode,
            cfg.lexical_max_bound,
            cfg.vector_max_bound,
            req.k,
            fused_scratch,
        ),
    };

    // Recheck policy_epoch before disclosing batch rows or materializing strings.
    try req.binding.verifyDisclosure(req.current_policy_epoch);

    const final_count = @min(req.k, fused_hits.len);
    var late_materialized: u32 = 0;

    for (0..final_count) |idx| {
        const hit = fused_hits[idx];
        const lex_score = lookupScore(lex_hits, hit.doc_id);
        const vec_score = lookupScore(vec_hits, hit.doc_id);
        var cell: ?GermanString.GermanCell = null;
        if (req.source_texts) |texts| {
            if (hit.doc_id >= texts.len) return error.SourceTextOutOfBounds;
            const arena = string_arena orelse return error.MissingStringArena;
            cell = .{
                .state = .value,
                .string = try GermanString.GermanString.init(texts[hit.doc_id], req.text_collation, arena),
            };
            late_materialized += 1;
        }
        out_rows[idx] = .{
            .doc_id = hit.doc_id,
            .fused_score = hit.score,
            .lexical_score = lex_score,
            .vector_score = vec_score,
            .materialized_text = cell,
        };
    }

    return .{
        .explain = .{
            .snapshot_lsn = req.binding.snapshot_lsn,
            .catalog_revision = req.binding.catalog_revision,
            .policy_epoch = req.binding.policy_epoch,
            .segmenter_profile = req.lexical_segment.descriptor.segmenter_profile,
            .index_profile = req.lexical_segment.descriptor.index_profile,
            .blocks_inspected = lex_stats.blocks_inspected,
            .blocks_skipped_by_wand = lex_stats.blocks_skipped_by_wand,
            .blocks_skipped_by_visibility = lex_stats.blocks_skipped_by_visibility,
            .positional_verifications = lex_stats.positional_verifications,
            .lexical_docs_scored = lex_stats.docs_scored,
            .vector_candidates_scored = vec_scored,
            .late_materialized_rows = late_materialized,
        },
        .count = final_count,
    };
}

fn lookupScore(items: []const SearchOracle.ScoredDoc, doc_id: u32) f64 {
    for (items) |item| {
        if (item.doc_id == doc_id) return item.score;
    }
    return 0.0;
}
