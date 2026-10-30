//! Vectorized 256-document Block-Max BM25 (`MAXSCORE` and Block-Max WAND)
//! search execution in `Fuze` (`P6`).
//!
//! Intersects 256-document posting blocks in SIMD registers with `transit-bitmap`
//! (`RBC1`) `.tdel` tombstones, MVCC snapshot visibility, security-barrier RLS,
//! and relational filter masks before scoring, enforces the 5-state eager failure
//! frontier (`A1`), skips 256-document blocks whose Block-Max upper bound cannot
//! enter the top-$k$ (`A5`), and lazily decodes positional streams only for
//! surviving `NEAR`/`WITHIN` candidates. Zero steady-state heap allocations.
const std = @import("std");
const bitmap = @import("transit_bitmap");
const SearchOracle = @import("SearchOracle.zig");
const TSearchSegment = @import("TSearchSegment.zig");

pub const max_query_terms = SearchOracle.max_query_terms;
pub const window_docs: u32 = 256;
pub const words_per_window: usize = window_docs / 64; // 4 x u64 (256 bits)

pub const Error = TSearchSegment.Error || error{
    InvalidSearchQuery,
    QueryTypeError,
    QueryConflict,
};

pub const ProximitySpec = struct {
    max_distance: u32,
    ordered: bool = true,
};

pub const SearchQuery = struct {
    terms: []const []const u8,
    mode: SearchOracle.MatchMode = .disjunctive_or,
    proximity: ?ProximitySpec = null,
    top_k: usize = 10,
};

pub const SearchExecutionStats = struct {
    terms_resolved: u32 = 0,
    windows_inspected: u32 = 0,
    blocks_inspected: u32 = 0,
    blocks_skipped_by_visibility: u32 = 0,
    blocks_skipped_by_wand: u32 = 0,
    docs_scored: u32 = 0,
    positional_verifications: u32 = 0,
};

const TermCursor = struct {
    meta: TSearchSegment.TermMetadata,
    blocks: []const TSearchSegment.BlockHeader,
    block_idx: usize = 0,
    query_idx: u8 = 0,

    inline fn advanceToWindow(self: *TermCursor, window_start_doc: u32) void {
        while (self.block_idx < self.blocks.len and self.blocks[self.block_idx].max_doc_id < window_start_doc) {
            self.block_idx += 1;
        }
    }
};

/// Execute a vectorized `MAXSCORE` / Block-Max WAND search query over `segment`,
/// writing the top-$k$ `(doc_id, score)` winners in canonical `(score DESC, doc_id ASC)`
/// order into `results_out` with zero heap allocations.
pub fn executeBlockMaxSearch(
    segment: *const TSearchSegment.Segment,
    query: SearchQuery,
    deleted_bitmap: ?*const bitmap.Container,
    visibility_bitmap: ?*const bitmap.Container,
    results_out: []SearchOracle.ScoredDoc,
    stats_out: ?*SearchExecutionStats,
) Error![]SearchOracle.ScoredDoc {
    if (query.terms.len == 0 or query.terms.len > max_query_terms) return error.InvalidSearchQuery;
    if (query.proximity != null and (query.terms.len < 2 or !segment.descriptor.positions_enabled)) {
        return error.InvalidSearchQuery;
    }
    if (query.top_k == 0 or segment.row_count == 0) {
        if (stats_out) |s| s.* = .{};
        return results_out[0..0];
    }
    if (results_out.len < query.top_k) return error.SearchScratchExhausted;

    // 1. Check 5-state eager failure frontier (`A1`) across all live visible rows
    const total_words = (segment.row_count + 63) / 64;
    for (0..total_words) |w| {
        const del_w: u64 = if (deleted_bitmap) |del| del.words[w] else 0;
        const vis_w: u64 = if (visibility_bitmap) |vis| vis.words[w] else std.math.maxInt(u64);
        const active_w: u64 = (~del_w) & vis_w;
        if ((active_w & segment.error_bitmap.words[w]) != 0) return error.QueryTypeError;
        if ((active_w & segment.conflict_bitmap.words[w]) != 0) return error.QueryConflict;
    }

    // 2. Resolve query terms in $O(1)$ via segment-sealed `PerfectHash.FrozenDirectory`
    var stats: SearchExecutionStats = .{};
    var cursors: [max_query_terms]TermCursor = undefined;
    var active_terms: usize = 0;
    const effective_mode: SearchOracle.MatchMode = if (query.proximity != null) .conjunctive_and else query.mode;

    for (query.terms) |qt| {
        const found = (try segment.findTerm(qt)) orelse {
            if (effective_mode == .conjunctive_and) {
                if (stats_out) |s| s.* = stats;
                return results_out[0..0];
            }
            continue;
        };
        cursors[active_terms] = .{
            .meta = found,
            .blocks = segment.termBlocks(found),
            .block_idx = 0,
            .query_idx = @intCast(active_terms),
        };
        active_terms += 1;
        stats.terms_resolved += 1;
    }

    if (active_terms == 0) {
        if (stats_out) |s| s.* = stats;
        return results_out[0..0];
    }

    // Sort cursors by descending `max_term_impact_q16` for `MAXSCORE` essential/non-essential partitioning
    std.mem.sort(TermCursor, cursors[0..active_terms], {}, struct {
        fn lessThan(_: void, a: TermCursor, b: TermCursor) bool {
            return a.meta.max_term_impact_q16 > b.meta.max_term_impact_q16;
        }
    }.lessThan);

    var heap_len: usize = 0;
    const num_windows: u32 = (segment.row_count + window_docs - 1) / window_docs;

    // Reusable 256-element window accumulators on the stack (zero heap allocation!)
    var window_scores: [window_docs]f64 = undefined;
    var window_term_hits: [window_docs]u8 = undefined;
    var window_doc_off_idx: [max_query_terms][window_docs]u32 = undefined;

    var w_idx: u32 = 0;
    while (w_idx < num_windows) : (w_idx += 1) {
        const win_start: u32 = w_idx * window_docs;
        const win_end: u32 = @min(win_start + window_docs, segment.row_count);
        const word_base: usize = @as(usize, w_idx) * words_per_window;

        // Compose 256-bit live `.value` mask in SIMD / 64-bit registers (`valid & ~deleted & visible`)
        var live_words: [words_per_window]u64 = @splat(0);
        var any_live: u64 = 0;
        for (0..words_per_window) |wi| {
            const global_w = word_base + wi;
            if (global_w >= bitmap.word_count) break;
            const valid_w = segment.valid_bitmap.words[global_w];
            const del_w = if (deleted_bitmap) |del| del.words[global_w] else 0;
            const vis_w = if (visibility_bitmap) |vis| vis.words[global_w] else std.math.maxInt(u64);
            const lw = valid_w & (~del_w) & vis_w;
            live_words[wi] = lw;
            any_live |= lw;
        }

        // Advance all term block cursors to `win_start`
        var overlapping_terms: usize = 0;
        var window_max_upper_bound: f64 = 0.0;
        for (cursors[0..active_terms]) |*cur| {
            cur.advanceToWindow(win_start);
            var term_overlaps = false;
            var term_win_max: f64 = 0.0;
            var scan_idx = cur.block_idx;
            while (scan_idx < cur.blocks.len) : (scan_idx += 1) {
                const blk = cur.blocks[scan_idx];
                if (blk.first_doc_id >= win_end) break;
                if (blk.max_doc_id >= win_start) {
                    term_overlaps = true;
                    const ub = blk.maxImpactUpperBound();
                    if (ub > term_win_max) term_win_max = ub;
                }
            }
            if (term_overlaps) {
                overlapping_terms += 1;
                window_max_upper_bound += term_win_max;
            }
        }

        if (overlapping_terms == 0) continue;
        if (effective_mode == .conjunctive_and and overlapping_terms < active_terms) {
            stats.blocks_skipped_by_wand += @intCast(overlapping_terms);
            continue;
        }

        // Fast visibility/tombstone/relational-filter skip (`transit-bitmap` intersection)
        if (any_live == 0) {
            stats.blocks_skipped_by_visibility += @intCast(overlapping_terms);
            continue;
        }

        // Block-Max WAND upper-bound skip (`A5` soundness: skip 256-doc window if upper bound < worst top-k score)
        const threshold: f64 = if (heap_len == query.top_k) results_out[0].score else -1.0;
        if (heap_len == query.top_k and window_max_upper_bound < threshold) {
            stats.blocks_skipped_by_wand += @intCast(overlapping_terms);
            continue;
        }

        stats.windows_inspected += 1;
        @memset(&window_scores, 0.0);
        @memset(&window_term_hits, 0);

        // Score postings inside this 256-document window
        for (cursors[0..active_terms]) |*cur| {
            var b_idx = cur.block_idx;
            while (b_idx < cur.blocks.len) : (b_idx += 1) {
                const blk = cur.blocks[b_idx];
                if (blk.first_doc_id >= win_end) break;
                stats.blocks_inspected += 1;

                const doc_ids = segment.blockDocIds(blk);
                const tfs = segment.blockTfs(blk);
                for (doc_ids, tfs, 0..) |doc_id, tf, idx_in_blk| {
                    if (doc_id < win_start) continue;
                    if (doc_id >= win_end) break;
                    const local_id: usize = doc_id - win_start;
                    const bit_ok = (live_words[local_id / 64] & (@as(u64, 1) << @as(u6, @truncate(local_id)))) != 0;
                    if (!bit_ok) continue;

                    const norm = segment.norm_dl[doc_id];
                    const term_score = SearchOracle.scoreTermQuantized(
                        tf,
                        norm,
                        segment.avg_doc_len,
                        cur.meta.idf,
                        segment.descriptor.bm25_params,
                    );
                    window_scores[local_id] += term_score;
                    window_term_hits[local_id] += 1;
                    window_doc_off_idx[cur.query_idx][local_id] = blk.pos_offset_start + @as(u32, @intCast(idx_in_blk));
                }
            }
        }

        // Collect qualifying documents in this 256-document window
        const required_hits: u8 = if (effective_mode == .conjunctive_and) @intCast(active_terms) else 1;
        for (0..win_end - win_start) |local_id| {
            if (window_term_hits[local_id] < required_hits) continue;
            stats.docs_scored += 1;
            const doc_id: u32 = win_start + @as(u32, @intCast(local_id));
            const score = window_scores[local_id];

            if (heap_len == query.top_k) {
                const worst = results_out[0];
                if (score < worst.score or (score == worst.score and doc_id >= worst.doc_id)) {
                    continue;
                }
            }

            // Lazy positional verification for `NEAR` / `WITHIN` proximity (`P6`)
            if (query.proximity) |prox| {
                stats.positional_verifications += 1;
                if (!verifyDocProximity(
                    segment,
                    active_terms,
                    &window_doc_off_idx,
                    local_id,
                    prox,
                )) continue;
            }

            insertTopK(results_out[0..query.top_k], &heap_len, .{ .doc_id = doc_id, .score = score });
        }
    }

    std.mem.sort(SearchOracle.ScoredDoc, results_out[0..heap_len], {}, SearchOracle.ScoredDoc.lessThan);
    if (stats_out) |s| s.* = stats;
    return results_out[0..heap_len];
}

fn verifyDocProximity(
    segment: *const TSearchSegment.Segment,
    term_count: usize,
    doc_off_idx: *const [max_query_terms][window_docs]u32,
    local_id: usize,
    prox: ProximitySpec,
) bool {
    if (!segment.descriptor.positions_enabled) return false;
    var pos_lists: [max_query_terms][]const u32 = undefined;
    for (0..term_count) |ti| {
        const off_idx = doc_off_idx[ti][local_id];
        const start = segment.pos_offsets[off_idx];
        const end = segment.pos_offsets[off_idx + 1];
        pos_lists[ti] = segment.positions[start..end];
        if (pos_lists[ti].len == 0) return false;
    }
    var chosen: [max_query_terms]u32 = undefined;
    return searchPositionsRecursive(pos_lists[0..term_count], 0, &chosen, prox.max_distance, prox.ordered);
}

fn searchPositionsRecursive(
    pos_lists: []const []const u32,
    term_idx: usize,
    chosen: *[max_query_terms]u32,
    max_distance: u32,
    ordered: bool,
) bool {
    if (term_idx == pos_lists.len) {
        var min_p: u32 = chosen[0];
        var max_p: u32 = chosen[0];
        for (chosen[0..pos_lists.len]) |p| {
            if (p < min_p) min_p = p;
            if (p > max_p) max_p = p;
        }
        const span = max_p - min_p;
        const req: u32 = @intCast(pos_lists.len - 1);
        if (span < req) return false;
        return (span - req) <= max_distance;
    }

    for (pos_lists[term_idx]) |p| {
        if (ordered and term_idx > 0 and p <= chosen[term_idx - 1]) continue;
        var dup = false;
        for (chosen[0..term_idx]) |prev_p| {
            if (prev_p == p) {
                dup = true;
                break;
            }
        }
        if (dup) continue;
        chosen[term_idx] = p;
        if (searchPositionsRecursive(pos_lists, term_idx + 1, chosen, max_distance, ordered)) return true;
    }
    return false;
}

/// Maintain `results[0..*len]` with `results[0]` always holding the *worst*
/// top-$k$ candidate (lowest `score`, or highest `doc_id` on score tie) so
/// `results[0].score` serves as the dynamic Block-Max WAND threshold $\theta$.
fn insertTopK(
    results: []SearchOracle.ScoredDoc,
    len: *usize,
    candidate: SearchOracle.ScoredDoc,
) void {
    if (len.* < results.len) {
        results[len.*] = candidate;
        len.* += 1;
    } else {
        results[0] = candidate;
    }
    // Bubble the worst candidate (where `ScoredDoc.lessThan(worst, other) == false`) to index 0
    var worst_idx: usize = 0;
    for (1..len.*) |i| {
        if (SearchOracle.ScoredDoc.lessThan({}, results[worst_idx], results[i])) {
            worst_idx = i;
        }
    }
    if (worst_idx != 0) {
        const tmp = results[0];
        results[0] = results[worst_idx];
        results[worst_idx] = tmp;
    }
}
