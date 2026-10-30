//! Finite scalar reference oracle for Milestone 14 declarative text/span
//! segmentation ($\kappa_{\text{search}}$), 5-state pattern matching
//! (`STARTS_WITH`, `CONTAINS`, `LIKE`), `NEAR`/`WITHIN` span proximity,
//! exact IEEE 754 `f64` BM25 scoring, and single-snapshot hybrid search fusion.
//!
//! Operates inside caller-owned scratch slices with zero heap allocations so
//! compressed-domain codecs and vectorized Block-Max WAND / `MAXSCORE` operators
//! can be verified differentially against an unpruned ground-truth model.
const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const Collation = @import("Collation.zig");

pub const max_tokens_per_doc: usize = 512;
pub const max_token_bytes: usize = 128;
pub const max_query_terms: usize = 32;

pub const Error = error{
    InvalidUtf8,
    InvalidLikePattern,
    InvalidSearchQuery,
    InvalidProximityDistance,
    InvalidBm25Parameters,
    InvalidHybridParameters,
    SearchScratchExhausted,
    UnsupportedColumnCollation,
    UnrepresentableEbcdic037,
    UnrepresentableEbcdic1047,
    EncounteredTypeErrorCell,
    EncounteredConflictCell,
    EncounteredMissingCell,
};

pub const SegmenterProfile = enum(u8) {
    unicode_word_v1 = 1,
    ascii_fold_v1 = 2,
    code_identifier_v1 = 3,
    ngram_3_v1 = 4,
    raw_bytes_v1 = 5,
};

pub const MatchMode = enum(u8) {
    conjunctive_and = 1,
    disjunctive_or = 2,
};

pub const FiveStateMatch = union(Types.State) {
    missing: void,
    null: void,
    type_error: Types.Kind,
    value: bool,
    conflict: []const Values.Alternative,
};

pub const TokenSpan = struct {
    term: []const u8,
    position: u32,
    start_byte: u32,
    end_byte: u32,
};

pub const Bm25Params = struct {
    k1: f64 = 1.2,
    b: f64 = 0.75,

    pub fn validate(self: Bm25Params) Error!void {
        if (!std.math.isFinite(self.k1) or self.k1 < 0.0) return error.InvalidBm25Parameters;
        if (!std.math.isFinite(self.b) or self.b < 0.0 or self.b > 1.0) return error.InvalidBm25Parameters;
    }
};

pub const ScoredDoc = struct {
    doc_id: u32,
    score: f64,

    /// Canonical deterministic search ordering: `(score DESC, doc_id ASC)`.
    pub fn lessThan(_: void, a: ScoredDoc, b: ScoredDoc) bool {
        if (a.score != b.score) return a.score > b.score;
        return a.doc_id < b.doc_id;
    }
};

/// Compute the deterministic 32-byte SHA-256 digest pinning a segmenter profile,
/// collation profile, and sorted stop-word list.
pub fn computeSegmenterDigest(
    segmenter: SegmenterProfile,
    collation: Collation.Profile,
    stop_words: []const []const u8,
) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update("transit.search.segmenter.v1");
    hasher.update(&.{ @backingInt(segmenter), @backingInt(collation) });
    var count_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &count_buf, @intCast(stop_words.len), .little);
    hasher.update(&count_buf);
    for (stop_words) |sw| {
        std.mem.writeInt(u32, &count_buf, @intCast(sw.len), .little);
        hasher.update(&count_buf);
        hasher.update(sw);
    }
    var out: [32]u8 = undefined;
    hasher.final(&out);
    return out;
}

inline fn isAsciiWordChar(b: u8) bool {
    return std.ascii.isAlphanumeric(b) or b == '_';
}

inline fn isStopWord(term: []const u8, stop_words: []const []const u8) bool {
    for (stop_words) |sw| {
        if (std.mem.eql(u8, term, sw)) return true;
    }
    return false;
}

/// Segment `text` into ordered `TokenSpan`s inside `tokens_out` and `byte_scratch`
/// with zero heap allocations.
pub fn segmentText(
    text: []const u8,
    profile: SegmenterProfile,
    stop_words: []const []const u8,
    tokens_out: []TokenSpan,
    byte_scratch: []u8,
) Error![]TokenSpan {
    if (profile != .raw_bytes_v1 and !std.unicode.utf8ValidateSlice(text)) {
        return error.InvalidUtf8;
    }
    var token_count: usize = 0;
    var scratch_used: usize = 0;
    var ordinal_pos: u32 = 0;

    switch (profile) {
        .raw_bytes_v1 => {
            if (text.len == 0) return tokens_out[0..0];
            if (tokens_out.len < 1 or byte_scratch.len < text.len) return error.SearchScratchExhausted;
            @memcpy(byte_scratch[0..text.len], text);
            const term = byte_scratch[0..text.len];
            if (!isStopWord(term, stop_words)) {
                tokens_out[0] = .{
                    .term = term,
                    .position = 0,
                    .start_byte = 0,
                    .end_byte = @intCast(text.len),
                };
                token_count = 1;
            }
        },
        .unicode_word_v1, .ascii_fold_v1 => {
            var i: usize = 0;
            while (i < text.len) {
                const cp_len = std.unicode.utf8ByteSequenceLength(text[i]) catch return error.InvalidUtf8;
                const cp = std.unicode.utf8Decode(text[i .. i + cp_len]) catch return error.InvalidUtf8;
                const is_word = if (cp < 128) isAsciiWordChar(@intCast(cp)) else (cp >= 0xA0);
                if (!is_word) {
                    i += cp_len;
                    continue;
                }
                const start_byte = i;
                const term_start = scratch_used;
                while (i < text.len) {
                    const step_len = std.unicode.utf8ByteSequenceLength(text[i]) catch return error.InvalidUtf8;
                    const step_cp = std.unicode.utf8Decode(text[i .. i + step_len]) catch return error.InvalidUtf8;
                    const step_word = if (step_cp < 128) isAsciiWordChar(@intCast(step_cp)) else (step_cp >= 0xA0);
                    if (!step_word) break;
                    if (scratch_used + step_len > byte_scratch.len) return error.SearchScratchExhausted;
                    if (step_len == 1 and profile == .ascii_fold_v1) {
                        byte_scratch[scratch_used] = Collation.asciiLower(text[i]);
                    } else {
                        @memcpy(byte_scratch[scratch_used .. scratch_used + step_len], text[i .. i + step_len]);
                    }
                    scratch_used += step_len;
                    i += step_len;
                }
                const term = byte_scratch[term_start..scratch_used];
                if (!isStopWord(term, stop_words)) {
                    if (token_count >= tokens_out.len) return error.SearchScratchExhausted;
                    tokens_out[token_count] = .{
                        .term = term,
                        .position = ordinal_pos,
                        .start_byte = @intCast(start_byte),
                        .end_byte = @intCast(i),
                    };
                    token_count += 1;
                    ordinal_pos += 1;
                } else {
                    scratch_used = term_start;
                }
            }
        },
        .code_identifier_v1 => {
            // Splits on non-alphanumeric boundaries AND camelCase / snake_case sub-tokens
            var i: usize = 0;
            while (i < text.len) {
                if (!std.ascii.isAlphanumeric(text[i])) {
                    i += 1;
                    continue;
                }
                const start_byte = i;
                const term_start = scratch_used;
                while (i < text.len and std.ascii.isAlphanumeric(text[i])) {
                    if (scratch_used >= byte_scratch.len) return error.SearchScratchExhausted;
                    byte_scratch[scratch_used] = Collation.asciiLower(text[i]);
                    scratch_used += 1;
                    i += 1;
                    if (i < text.len and std.ascii.isUpper(text[i]) and std.ascii.isLower(text[i - 1])) {
                        break;
                    }
                }
                const term = byte_scratch[term_start..scratch_used];
                if (!isStopWord(term, stop_words)) {
                    if (token_count >= tokens_out.len) return error.SearchScratchExhausted;
                    tokens_out[token_count] = .{
                        .term = term,
                        .position = ordinal_pos,
                        .start_byte = @intCast(start_byte),
                        .end_byte = @intCast(i),
                    };
                    token_count += 1;
                    ordinal_pos += 1;
                } else {
                    scratch_used = term_start;
                }
            }
        },
        .ngram_3_v1 => {
            if (text.len < 3) return tokens_out[0..0];
            var i: usize = 0;
            while (i + 3 <= text.len) : (i += 1) {
                if (token_count >= tokens_out.len or scratch_used + 3 > byte_scratch.len) {
                    return error.SearchScratchExhausted;
                }
                for (0..3) |k| {
                    byte_scratch[scratch_used + k] = Collation.asciiLower(text[i + k]);
                }
                const term = byte_scratch[scratch_used .. scratch_used + 3];
                scratch_used += 3;
                tokens_out[token_count] = .{
                    .term = term,
                    .position = ordinal_pos,
                    .start_byte = @intCast(i),
                    .end_byte = @intCast(i + 3),
                };
                token_count += 1;
                ordinal_pos += 1;
            }
        },
    }
    return tokens_out[0..token_count];
}

/// Scalar `STARTS_WITH(haystack, prefix)` respecting `Collation.Profile`.
pub fn startsWithBytes(
    haystack: []const u8,
    prefix: []const u8,
    collation: Collation.Profile,
) Error!bool {
    try Collation.validateBytesProfile(haystack, collation);
    try Collation.validateBytesProfile(prefix, collation);
    const h = Collation.canonicalSliceProfile(haystack, collation);
    const p = Collation.canonicalSliceProfile(prefix, collation);
    if (p.len > h.len) return false;
    return (try Collation.compareBytesProfile(h[0..p.len], p, collation)) == .eq;
}

/// Scalar `CONTAINS(haystack, needle)` respecting `Collation.Profile`.
pub fn containsBytes(
    haystack: []const u8,
    needle: []const u8,
    collation: Collation.Profile,
) Error!bool {
    try Collation.validateBytesProfile(haystack, collation);
    try Collation.validateBytesProfile(needle, collation);
    const h = Collation.canonicalSliceProfile(haystack, collation);
    const n = Collation.canonicalSliceProfile(needle, collation);
    if (n.len == 0) return true;
    if (n.len > h.len) return false;
    var i: usize = 0;
    while (i + n.len <= h.len) : (i += 1) {
        if ((try Collation.compareBytesProfile(h[i .. i + n.len], n, collation)) == .eq) {
            return true;
        }
    }
    return false;
}

/// Scalar `LIKE` pattern matcher supporting `%` (0 or more characters), `_` (1 character),
/// and an optional `escape` character under `Collation.Profile`.
pub fn likeBytes(
    haystack: []const u8,
    pattern: []const u8,
    escape: ?u8,
    collation: Collation.Profile,
) Error!bool {
    try Collation.validateBytesProfile(haystack, collation);
    try Collation.validateBytesProfile(pattern, collation);
    const h = Collation.canonicalSliceProfile(haystack, collation);
    return likeMatchRecursive(h, pattern, escape, collation);
}

fn likeMatchRecursive(
    h: []const u8,
    p: []const u8,
    escape: ?u8,
    collation: Collation.Profile,
) Error!bool {
    var hi: usize = 0;
    var pi: usize = 0;
    var star_pi: ?usize = null;
    var star_hi: usize = 0;

    while (hi < h.len) {
        if (pi < p.len) {
            const pc = p[pi];
            if (escape != null and pc == escape.?) {
                if (pi + 1 >= p.len) return error.InvalidLikePattern;
                const lit = p[pi + 1];
                if (bytesEqualChar(h[hi], lit, collation)) {
                    hi += 1;
                    pi += 2;
                    continue;
                }
            } else if (pc == '%') {
                star_pi = pi;
                pi += 1;
                star_hi = hi;
                continue;
            } else if (pc == '_') {
                const step = std.unicode.utf8ByteSequenceLength(h[hi]) catch 1;
                hi += @min(step, h.len - hi);
                pi += 1;
                continue;
            } else if (bytesEqualChar(h[hi], pc, collation)) {
                hi += 1;
                pi += 1;
                continue;
            }
        }
        if (star_pi) |sp| {
            pi = sp + 1;
            const step = std.unicode.utf8ByteSequenceLength(h[star_hi]) catch 1;
            star_hi += @min(step, h.len - star_hi);
            hi = star_hi;
        } else {
            return false;
        }
    }

    while (pi < p.len and p[pi] == '%') {
        if (escape != null and p[pi] == escape.?) break;
        pi += 1;
    }
    if (pi < p.len and escape != null and p[pi] == escape.? and pi + 1 >= p.len) {
        return error.InvalidLikePattern;
    }
    return pi == p.len;
}

inline fn bytesEqualChar(a: u8, b: u8, collation: Collation.Profile) bool {
    return switch (collation) {
        .ascii_ci => Collation.asciiLower(a) == Collation.asciiLower(b),
        else => a == b,
    };
}

/// Evaluate a 5-state Cell against `STARTS_WITH`, `CONTAINS`, or `LIKE`, preserving
/// `.missing`, `.null`, `.type_error`, and `.conflict` states (`A1`).
pub fn evaluatePatternCell(
    cell: Values.Cell,
    kind: enum { starts_with, contains, like },
    pattern: []const u8,
    escape: ?u8,
    collation: Collation.Profile,
) Error!FiveStateMatch {
    return switch (cell) {
        .missing => .{ .missing = {} },
        .null => .{ .null = {} },
        .type_error => |e| .{ .type_error = e },
        .conflict => |c| .{ .conflict = c },
        .value => |v| blk: {
            const bytes = switch (v) {
                .atom => |a| a.bytes,
                .json => |j| j,
                else => return error.InvalidSearchQuery,
            };
            const matched = switch (kind) {
                .starts_with => try startsWithBytes(bytes, pattern, collation),
                .contains => try containsBytes(bytes, pattern, collation),
                .like => try likeBytes(bytes, pattern, escape, collation),
            };
            break :blk .{ .value = matched };
        },
    };
}

/// Count occurrences (`tf`) of `query_term` in `tokens`.
pub fn countTermFrequency(tokens: []const TokenSpan, query_term: []const u8) u32 {
    var tf: u32 = 0;
    for (tokens) |tok| {
        if (std.mem.eql(u8, tok.term, query_term)) tf += 1;
    }
    return tf;
}

/// Scalar `MATCH` evaluation over a segmented document's `TokenSpan` list.
pub fn matchTokens(
    tokens: []const TokenSpan,
    query_terms: []const []const u8,
    mode: MatchMode,
) Error!bool {
    if (query_terms.len == 0 or query_terms.len > max_query_terms) return error.InvalidSearchQuery;
    switch (mode) {
        .conjunctive_and => {
            for (query_terms) |qt| {
                if (countTermFrequency(tokens, qt) == 0) return false;
            }
            return true;
        },
        .disjunctive_or => {
            for (query_terms) |qt| {
                if (countTermFrequency(tokens, qt) > 0) return true;
            }
            return false;
        },
    }
}

/// Scalar `NEAR(query_terms, max_distance, ordered)` / `WITHIN` proximity evaluation
/// over a segmented document's `TokenSpan` list.
///
/// A span of occurrences $(p_0, p_1, \dots, p_{m-1})$ satisfies `NEAR` when:
/// - Every query term $i \in [0, m)$ occurs at token position $p_i$,
/// - When `ordered == true`, $p_0 < p_1 < \dots < p_{m-1}$,
/// - When `ordered == false`, all positions $p_i$ are distinct, and
/// - The span width $(\max_i p_i - \min_i p_i) - (m - 1) \le \text{max\_distance}$
///   (so `max_distance == 0` with `ordered == true` is exact contiguous phrase matching!).
pub fn nearTokens(
    tokens: []const TokenSpan,
    query_terms: []const []const u8,
    max_distance: u32,
    ordered: bool,
) Error!bool {
    if (query_terms.len < 2 or query_terms.len > max_query_terms) return error.InvalidSearchQuery;
    var chosen_positions: [max_query_terms]u32 = undefined;
    return searchNearRecursive(tokens, query_terms, 0, &chosen_positions, max_distance, ordered);
}

fn searchNearRecursive(
    tokens: []const TokenSpan,
    query_terms: []const []const u8,
    term_idx: usize,
    chosen: *[max_query_terms]u32,
    max_distance: u32,
    ordered: bool,
) bool {
    if (term_idx == query_terms.len) {
        var min_p: u32 = chosen[0];
        var max_p: u32 = chosen[0];
        for (chosen[0..query_terms.len]) |p| {
            if (p < min_p) min_p = p;
            if (p > max_p) max_p = p;
        }
        const span_span = max_p - min_p;
        const min_required: u32 = @intCast(query_terms.len - 1);
        if (span_span < min_required) return false;
        const slop = span_span - min_required;
        return slop <= max_distance;
    }

    for (tokens) |tok| {
        if (!std.mem.eql(u8, tok.term, query_terms[term_idx])) continue;
        if (ordered and term_idx > 0 and tok.position <= chosen[term_idx - 1]) continue;
        var duplicate_pos = false;
        for (chosen[0..term_idx]) |prev_p| {
            if (prev_p == tok.position) {
                duplicate_pos = true;
                break;
            }
        }
        if (duplicate_pos) continue;
        chosen[term_idx] = tok.position;
        if (searchNearRecursive(tokens, query_terms, term_idx + 1, chosen, max_distance, ordered)) {
            return true;
        }
    }
    return false;
}

/// Quantize a document token length `dl` into an 8-bit bucket (`0..255`) and
/// dequantize it monotonically (`dequantizeNormDl(quantizeNormDl(dl)) <= dl`)
/// so Block-Max `min_norm_dl` upper bounds are provably conservative (`A5`).
pub inline fn quantizeNormDl(doc_len: u32) u8 {
    if (doc_len < 16) return @intCast(doc_len);
    const msb: u32 = 31 - @clz(doc_len);
    const shift: u5 = @intCast(@min(14, msb - 4));
    const shifted = doc_len >> shift;
    const mantissa: u32 = if (shifted > 0x1F) 0x0F else (shifted & 0x0F);
    const code: u32 = ((@as(u32, shift) + 1) << 4) | mantissa;
    return @intCast(@min(255, code));
}

pub inline fn dequantizeNormDl(norm: u8) u32 {
    if (norm < 16) return norm;
    const shift: u5 = @intCast((norm >> 4) - 1);
    const mantissa: u32 = norm & 0x0F;
    return (mantissa | 0x10) << shift;
}

/// Exact Lucene/Robertson non-negative BM25 Inverse Document Frequency:
/// $\text{IDF}(t) = \ln\left(1 + \frac{N - df_t + 0.5}{df_t + 0.5}\right)$.
pub fn computeIdf(total_docs: u32, doc_freq: u32) f64 {
    if (total_docs == 0 or doc_freq == 0) return 0.0;
    const n: f64 = @floatFromInt(total_docs);
    const df: f64 = @floatFromInt(@min(total_docs, doc_freq));
    return @log(1.0 + (n - df + 0.5) / (df + 0.5));
}

/// Exact BM25 contribution of a single term with `tf` in a document of quantized
/// length `dequantizeNormDl(norm_dl)` given corpus `avg_doc_len` and `idf`.
pub fn scoreTermQuantized(
    tf: u32,
    norm_dl: u8,
    avg_doc_len: f64,
    idf: f64,
    params: Bm25Params,
) f64 {
    if (tf == 0 or idf <= 0.0) return 0.0;
    const f: f64 = @floatFromInt(tf);
    const dl: f64 = @floatFromInt(dequantizeNormDl(norm_dl));
    const safe_avg = if (avg_doc_len > 0.0) avg_doc_len else 1.0;
    const norm_factor = 1.0 - params.b + params.b * (dl / safe_avg);
    return idf * (f * (params.k1 + 1.0)) / (f + params.k1 * norm_factor);
}

/// Quantize a term's maximum block score `[0.0, max_possible]` into a 16-bit
/// ceiling (`u16`) with `scale = 1024.0` (`Q6.10` fixed-point with ceiling rounding)
/// so `dequantizeImpactQ16(quantizeImpactQ16(score)) >= score` always holds (`A5`).
pub inline fn quantizeImpactQ16(score: f64) u16 {
    if (score <= 0.0) return 0;
    const scaled = @ceil(score * 1024.0);
    if (scaled >= 65535.0) return 65535;
    return @intFromFloat(scaled);
}

pub inline fn dequantizeImpactQ16(q16: u16) f64 {
    return @as(f64, @floatFromInt(q16)) / 1024.0;
}

pub const NormMode = enum(u8) {
    min_max = 1,
    theoretical_bounds = 2,
};

/// Single-snapshot Reciprocal Rank Fusion (`RRF`) oracle:
/// $\text{score}_{\text{RRF}}(d) = \sum_{m} \frac{w_m}{k_{\text{rrf}} + \text{rank}_m(d)}$
/// where $\text{rank}_m(d) \ge 1$ is the 1-based ordinal rank of document $d$ in modality $m$.
pub fn fuseRrf(
    lexical_ranked: []const ScoredDoc,
    vector_ranked: []const ScoredDoc,
    lexical_weight: f64,
    vector_weight: f64,
    k_rrf: u32,
    top_k: usize,
    scratch: []ScoredDoc,
) Error![]ScoredDoc {
    if (k_rrf == 0 or lexical_weight < 0.0 or vector_weight < 0.0 or (lexical_weight == 0.0 and vector_weight == 0.0)) {
        return error.InvalidHybridParameters;
    }
    const max_needed = lexical_ranked.len + vector_ranked.len;
    if (scratch.len < max_needed) return error.SearchScratchExhausted;

    var count: usize = 0;
    const k_f: f64 = @floatFromInt(k_rrf);

    for (lexical_ranked, 0..) |entry, idx| {
        const rank: f64 = @floatFromInt(idx + 1);
        scratch[count] = .{
            .doc_id = entry.doc_id,
            .score = lexical_weight / (k_f + rank),
        };
        count += 1;
    }

    for (vector_ranked, 0..) |entry, idx| {
        const rank: f64 = @floatFromInt(idx + 1);
        const contrib = vector_weight / (k_f + rank);
        var found = false;
        for (scratch[0..count]) |*existing| {
            if (existing.doc_id == entry.doc_id) {
                existing.score += contrib;
                found = true;
                break;
            }
        }
        if (!found) {
            scratch[count] = .{ .doc_id = entry.doc_id, .score = contrib };
            count += 1;
        }
    }

    std.mem.sort(ScoredDoc, scratch[0..count], {}, ScoredDoc.lessThan);
    return scratch[0..@min(count, top_k)];
}

/// Single-snapshot calibrated linear combination oracle:
/// $\text{score}_{\text{lin}}(d) = \alpha \cdot \text{norm}_{\text{lex}}(s_{\text{lex}}(d)) + (1 - \alpha) \cdot \text{norm}_{\text{vec}}(s_{\text{vec}}(d))$.
pub fn fuseLinear(
    lexical_ranked: []const ScoredDoc,
    vector_ranked: []const ScoredDoc,
    alpha: f64,
    norm_mode: NormMode,
    lexical_max_bound: f64,
    vector_max_bound: f64,
    top_k: usize,
    scratch: []ScoredDoc,
) Error![]ScoredDoc {
    if (!std.math.isFinite(alpha) or alpha < 0.0 or alpha > 1.0) {
        return error.InvalidHybridParameters;
    }
    const max_needed = lexical_ranked.len + vector_ranked.len;
    if (scratch.len < max_needed) return error.SearchScratchExhausted;

    var lex_min: f64 = 0.0;
    var lex_max: f64 = lexical_max_bound;
    if (norm_mode == .min_max and lexical_ranked.len > 0) {
        lex_min = lexical_ranked[lexical_ranked.len - 1].score;
        lex_max = lexical_ranked[0].score;
    }

    var vec_min: f64 = 0.0;
    var vec_max: f64 = vector_max_bound;
    if (norm_mode == .min_max and vector_ranked.len > 0) {
        vec_min = vector_ranked[vector_ranked.len - 1].score;
        vec_max = vector_ranked[0].score;
    }

    var count: usize = 0;
    for (lexical_ranked) |entry| {
        const norm_s = normalizeScore(entry.score, lex_min, lex_max);
        scratch[count] = .{
            .doc_id = entry.doc_id,
            .score = alpha * norm_s,
        };
        count += 1;
    }

    for (vector_ranked) |entry| {
        const norm_s = normalizeScore(entry.score, vec_min, vec_max);
        const contrib = (1.0 - alpha) * norm_s;
        var found = false;
        for (scratch[0..count]) |*existing| {
            if (existing.doc_id == entry.doc_id) {
                existing.score += contrib;
                found = true;
                break;
            }
        }
        if (!found) {
            scratch[count] = .{ .doc_id = entry.doc_id, .score = contrib };
            count += 1;
        }
    }

    std.mem.sort(ScoredDoc, scratch[0..count], {}, ScoredDoc.lessThan);
    return scratch[0..@min(count, top_k)];
}

inline fn normalizeScore(val: f64, lo: f64, hi: f64) f64 {
    if (hi <= lo) return if (val > 0.0) 1.0 else 0.0;
    return std.math.clamp((val - lo) / (hi - lo), 0.0, 1.0);
}
