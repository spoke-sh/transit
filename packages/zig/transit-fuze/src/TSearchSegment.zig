//! Declarative text/span search index profiles (`P4`) and `.tseg`-aligned
//! 256-document Block-Max BM25 search segments (`TSS1`, `P5`).
//!
//! Separates declarative segmentation ($\kappa_{\text{search}}$) and match/proximity
//! semantics from physical `.tseg` index layouts ($\epsilon$). Each inverted posting
//! list is partitioned into fixed 256-document blocks with conservative Block-Max
//! impact headers (`max_tf`, `min_norm_dl`, `max_impact_q16`), optional positional
//! streams for `NEAR`/`WITHIN`, and `transit-bitmap` (`RBC1`) 5-state cell bitmaps.
const std = @import("std");
const bitmap = @import("transit_bitmap");
const protocol = @import("transit_protocol");
const Collation = @import("Collation.zig");
const PerfectHash = @import("PerfectHash.zig");
const SearchOracle = @import("SearchOracle.zig");
const Types = @import("Types.zig");
const Values = @import("Values.zig");

pub const magic = "TSS1";
pub const definition = protocol.Growth.definition_bytes;
pub const block_doc_capacity: usize = 256;
pub const max_segment_docs: usize = bitmap.values_per_container; // 65,536 rows per segment
pub const max_segment_terms: usize = PerfectHash.max_runtime_keys; // up to 1,024 distinct terms per segment block

pub const Error = SearchOracle.Error || PerfectHash.Error || error{
    InvalidSearchSegment,
    IncompatibleDefinition,
    SearchSegmentChecksumMismatch,
    SearchSegmentRowLimitExceeded,
    SearchSegmentTermLimitExceeded,
    RequiredSearchIndexUnavailable,
    OutOfMemory,
};

pub const IndexProfile = enum(u8) {
    block_max_bm25_v1 = 1,
    trigram_bitmap_v1 = 2,
    vector_ann_v1 = 3,
};

pub const LifecycleState = enum(u8) {
    building = 1,
    backfilling = 2,
    catching_up = 3,
    ready = 4,
    failed = 5,
    dropped = 6,
};

pub const SearchIndexDescriptor = struct {
    index_id: u64,
    column_id: u64,
    collation: Collation.Profile = .utf8_binary,
    segmenter_profile: SearchOracle.SegmenterProfile = .ascii_fold_v1,
    segmenter_digest: [32]u8,
    index_profile: IndexProfile = .block_max_bm25_v1,
    positions_enabled: bool = true,
    bm25_params: SearchOracle.Bm25Params = .{},
    state: LifecycleState = .ready,
};

pub const QuerySearchBinding = struct {
    column_id: u64,
    collation: Collation.Profile = .utf8_binary,
    segmenter_profile: SearchOracle.SegmenterProfile = .ascii_fold_v1,
    segmenter_digest: [32]u8,
    requires_positions: bool = false,
    require_index: bool = false,
};

pub const FallbackReason = enum(u8) {
    no_matching_column = 1,
    index_not_ready = 2,
    segmenter_digest_mismatch = 3,
    collation_mismatch = 4,
    positions_not_indexed = 5,
};

pub const AccessPathSelection = union(enum) {
    index: u64,
    scalar_oracle_fallback: FallbackReason,
};

/// Select a qualified `.ready` search index profile whose bound `(column_id,
/// collation, segmenter_digest, positions_enabled)` matches the query (`D4`, `P4`).
/// Falls back to `.scalar_oracle_fallback` (or rejects with `error.RequiredSearchIndexUnavailable`
/// when `query.require_index == true`) if no `.ready` index satisfies the contract.
pub fn selectSearchAccessPath(
    candidates: []const SearchIndexDescriptor,
    query: QuerySearchBinding,
) Error!AccessPathSelection {
    var last_reason: FallbackReason = .no_matching_column;
    for (candidates) |cand| {
        if (cand.column_id != query.column_id) continue;
        if (cand.collation != query.collation) {
            last_reason = .collation_mismatch;
            continue;
        }
        if (cand.segmenter_profile != query.segmenter_profile or
            !std.mem.eql(u8, &cand.segmenter_digest, &query.segmenter_digest))
        {
            last_reason = .segmenter_digest_mismatch;
            continue;
        }
        if (query.requires_positions and !cand.positions_enabled) {
            last_reason = .positions_not_indexed;
            continue;
        }
        if (cand.state != .ready) {
            last_reason = .index_not_ready;
            continue;
        }
        return .{ .index = cand.index_id };
    }
    if (query.require_index) return error.RequiredSearchIndexUnavailable;
    return .{ .scalar_oracle_fallback = last_reason };
}

/// Per-block impact and offset header for a 256-document posting block (`P5`).
pub const BlockHeader = extern struct {
    first_doc_id: u32 = 0,
    max_doc_id: u32 = 0,
    doc_count: u16 = 0,
    max_tf: u16 = 0,
    min_norm_dl: u8 = 0,
    flags: u8 = 0,
    max_impact_q16: u16 = 0,
    posting_start: u32 = 0,
    pos_offset_start: u32 = 0,
    reserved: u32 = 0,

    comptime {
        std.debug.assert(@sizeOf(BlockHeader) == 28);
    }

    pub inline fn maxImpactUpperBound(self: BlockHeader) f64 {
        return SearchOracle.dequantizeImpactQ16(self.max_impact_q16);
    }
};

pub const TermMetadata = struct {
    term: []const u8,
    doc_freq: u32,
    idf: f64,
    max_term_impact_q16: u16,
    block_start: u32,
    block_count: u32,

    pub inline fn maxTermImpactUpperBound(self: TermMetadata) f64 {
        return SearchOracle.dequantizeImpactQ16(self.max_term_impact_q16);
    }
};

/// Immutable `.tseg`-aligned 256-document Block-Max BM25 search segment (`TSS1`).
/// Owns its contiguous backing buffers at build time; query execution (`VectorizedSearch`)
/// reads these slices with zero heap allocations.
pub const Segment = struct {
    allocator: std.mem.Allocator,
    descriptor: SearchIndexDescriptor,
    row_count: u32,
    valid_doc_count: u32,
    avg_doc_len: f64,
    norm_dl: []u8,
    valid_bitmap: bitmap.Container = .{},
    error_bitmap: bitmap.Container = .{},
    conflict_bitmap: bitmap.Container = .{},
    first_error_kind: ?Types.Kind = null,
    terms_arena: []u8,
    term_slices: [][]const u8,
    terms: []TermMetadata,
    term_directory: PerfectHash.FrozenDirectory,
    blocks: []BlockHeader,
    posting_doc_ids: []u32,
    posting_tfs: []u16,
    pos_offsets: []u32,
    positions: []u32,

    pub fn deinit(self: *Segment) void {
        self.allocator.free(self.norm_dl);
        self.allocator.free(self.terms_arena);
        self.allocator.free(self.term_slices);
        self.allocator.free(self.terms);
        self.allocator.free(self.blocks);
        self.allocator.free(self.posting_doc_ids);
        self.allocator.free(self.posting_tfs);
        self.allocator.free(self.pos_offsets);
        self.allocator.free(self.positions);
        self.* = undefined;
    }

    /// Look up `query_term` in $O(1)$ via the segment-sealed `PerfectHash.FrozenDirectory`.
    pub fn findTerm(self: *const Segment, query_term: []const u8) Error!?TermMetadata {
        const idx = (try self.term_directory.lookup(self.term_slices, query_term)) orelse return null;
        return self.terms[idx];
    }

    /// Return the 256-document `BlockHeader` slice for `term_meta`.
    pub inline fn termBlocks(self: *const Segment, term_meta: TermMetadata) []const BlockHeader {
        return self.blocks[term_meta.block_start .. term_meta.block_start + term_meta.block_count];
    }

    /// Return the document IDs in `block`.
    pub inline fn blockDocIds(self: *const Segment, block: BlockHeader) []const u32 {
        return self.posting_doc_ids[block.posting_start .. block.posting_start + block.doc_count];
    }

    /// Return the term frequencies (`tf`) in `block`.
    pub inline fn blockTfs(self: *const Segment, block: BlockHeader) []const u16 {
        return self.posting_tfs[block.posting_start .. block.posting_start + block.doc_count];
    }

    /// Return the token positions for the `doc_idx_in_block`-th document in `block`
    /// (decoded lazily only when `NEAR` / `WITHIN` proximity verification is active).
    pub inline fn docPositions(
        self: *const Segment,
        block: BlockHeader,
        doc_idx_in_block: usize,
    ) []const u32 {
        if (!self.descriptor.positions_enabled) return &.{};
        const off_idx = block.pos_offset_start + doc_idx_in_block;
        const start = self.pos_offsets[off_idx];
        const end = self.pos_offsets[off_idx + 1];
        return self.positions[start..end];
    }

    /// Build an immutable 256-document Block-Max BM25 search segment over `cells`
    /// (`0..cells.len`, up to 65,536 rows per `.tseg` segment).
    pub fn build(
        allocator: std.mem.Allocator,
        descriptor: SearchIndexDescriptor,
        stop_words: []const []const u8,
        cells: []const Values.Cell,
    ) Error!Segment {
        try descriptor.bm25_params.validate();
        if (cells.len > max_segment_docs) return error.SearchSegmentRowLimitExceeded;

        const norm_dl = try allocator.alloc(u8, cells.len + PerfectHash.padding_bytes);
        errdefer allocator.free(norm_dl);
        @memset(norm_dl, 0);

        var valid_bitmap: bitmap.Container = .{};
        var error_bitmap: bitmap.Container = .{};
        var conflict_bitmap: bitmap.Container = .{};
        var first_error_kind: ?Types.Kind = null;

        const RawPosting = struct {
            doc_id: u32,
            tf: u16,
            pos_start: u32,
            pos_count: u16,
        };
        const TempTerm = struct {
            term_owned: []u8,
            postings: std.ArrayListUnmanaged(RawPosting) = .empty,
        };

        var temp_terms = std.ArrayListUnmanaged(TempTerm).empty;
        defer {
            for (temp_terms.items) |*tt| {
                allocator.free(tt.term_owned);
                tt.postings.deinit(allocator);
            }
            temp_terms.deinit(allocator);
        }

        var all_temp_positions = std.ArrayListUnmanaged(u32).empty;
        defer all_temp_positions.deinit(allocator);

        var token_buf: [SearchOracle.max_tokens_per_doc]SearchOracle.TokenSpan = undefined;
        var byte_scratch: [8192]u8 = undefined;

        var valid_doc_count: u32 = 0;
        var total_tokens: u64 = 0;

        for (cells, 0..) |cell, row_idx| {
            const doc_id: u16 = @intCast(row_idx);
            switch (cell) {
                .missing, .null => {},
                .type_error => |k| {
                    _ = error_bitmap.set(doc_id);
                    if (first_error_kind == null) first_error_kind = k;
                },
                .conflict => {
                    _ = conflict_bitmap.set(doc_id);
                },
                .value => |v| {
                    const bytes = if (v == .json) v.json else v.atom.bytes;
                    const tokens = try SearchOracle.segmentText(
                        bytes,
                        descriptor.segmenter_profile,
                        stop_words,
                        &token_buf,
                        &byte_scratch,
                    );
                    _ = valid_bitmap.set(doc_id);
                    valid_doc_count += 1;
                    total_tokens += tokens.len;
                    norm_dl[row_idx] = SearchOracle.quantizeNormDl(@intCast(tokens.len));

                    // Group token positions by distinct term within this document
                    var i: usize = 0;
                    while (i < tokens.len) : (i += 1) {
                        const t_str = tokens[i].term;
                        var earlier = false;
                        for (0..i) |prev| {
                            if (std.mem.eql(u8, tokens[prev].term, t_str)) {
                                earlier = true;
                                break;
                            }
                        }
                        if (earlier) continue;

                        const pos_start: u32 = @intCast(all_temp_positions.items.len);
                        var tf: u16 = 0;
                        for (tokens[i..]) |cand_tok| {
                            if (std.mem.eql(u8, cand_tok.term, t_str)) {
                                tf = std.math.add(u16, tf, 1) catch std.math.maxInt(u16);
                                if (descriptor.positions_enabled) {
                                    try all_temp_positions.append(allocator, cand_tok.position);
                                }
                            }
                        }

                        var term_idx: ?usize = null;
                        for (temp_terms.items, 0..) |tt, ti| {
                            if (std.mem.eql(u8, tt.term_owned, t_str)) {
                                term_idx = ti;
                                break;
                            }
                        }
                        if (term_idx == null) {
                            if (temp_terms.items.len >= max_segment_terms) {
                                return error.SearchSegmentTermLimitExceeded;
                            }
                            const copy = try allocator.dupe(u8, t_str);
                            errdefer allocator.free(copy);
                            try temp_terms.append(allocator, .{ .term_owned = copy });
                            term_idx = temp_terms.items.len - 1;
                        }
                        try temp_terms.items[term_idx.?].postings.append(allocator, .{
                            .doc_id = @intCast(row_idx),
                            .tf = tf,
                            .pos_start = pos_start,
                            .pos_count = tf,
                        });
                    }
                },
            }
        }

        // Sort terms lexicographically so dictionary order is canonical
        std.mem.sort(TempTerm, temp_terms.items, {}, struct {
            fn lessThan(_: void, a: TempTerm, b: TempTerm) bool {
                return std.mem.order(u8, a.term_owned, b.term_owned) == .lt;
            }
        }.lessThan);

        const avg_doc_len: f64 = if (valid_doc_count > 0)
            @as(f64, @floatFromInt(total_tokens)) / @as(f64, @floatFromInt(valid_doc_count))
        else
            1.0;

        // Calculate total arena bytes, blocks, postings, and positions
        var total_term_bytes: usize = 0;
        var total_blocks: usize = 0;
        var total_postings: usize = 0;
        for (temp_terms.items) |tt| {
            total_term_bytes += tt.term_owned.len;
            total_postings += tt.postings.items.len;
            total_blocks += (tt.postings.items.len + block_doc_capacity - 1) / block_doc_capacity;
        }

        const terms_arena = try allocator.alloc(u8, total_term_bytes + PerfectHash.padding_bytes);
        errdefer allocator.free(terms_arena);
        @memset(terms_arena, 0);

        const term_slices = try allocator.alloc([]const u8, temp_terms.items.len);
        errdefer allocator.free(term_slices);

        const terms = try allocator.alloc(TermMetadata, temp_terms.items.len);
        errdefer allocator.free(terms);

        const blocks = try allocator.alloc(BlockHeader, total_blocks);
        errdefer allocator.free(blocks);

        const posting_doc_ids = try allocator.alloc(u32, total_postings + 16);
        errdefer allocator.free(posting_doc_ids);
        @memset(posting_doc_ids, 0);

        const posting_tfs = try allocator.alloc(u16, total_postings + 16);
        errdefer allocator.free(posting_tfs);
        @memset(posting_tfs, 0);

        const pos_offsets = try allocator.alloc(u32, total_postings + 1);
        errdefer allocator.free(pos_offsets);

        const positions = try allocator.alloc(u32, all_temp_positions.items.len + 16);
        errdefer allocator.free(positions);
        @memset(positions, 0);

        var arena_cursor: usize = 0;
        var block_cursor: u32 = 0;
        var posting_cursor: u32 = 0;
        var pos_cursor: u32 = 0;

        for (temp_terms.items, 0..) |tt, ti| {
            const t_slice = terms_arena[arena_cursor .. arena_cursor + tt.term_owned.len];
            @memcpy(t_slice, tt.term_owned);
            arena_cursor += tt.term_owned.len;
            term_slices[ti] = t_slice;

            const df: u32 = @intCast(tt.postings.items.len);
            const idf = SearchOracle.computeIdf(valid_doc_count, df);
            const term_block_start = block_cursor;
            var max_term_q16: u16 = 0;

            var p_idx: usize = 0;
            while (p_idx < tt.postings.items.len) : (p_idx += block_doc_capacity) {
                const chunk = tt.postings.items[p_idx..@min(p_idx + block_doc_capacity, tt.postings.items.len)];
                const b_posting_start = posting_cursor;
                var max_tf: u16 = 0;
                var min_norm_dl: u8 = 255;

                for (chunk) |post| {
                    posting_doc_ids[posting_cursor] = post.doc_id;
                    posting_tfs[posting_cursor] = post.tf;
                    pos_offsets[posting_cursor] = pos_cursor;
                    if (descriptor.positions_enabled) {
                        const src_pos = all_temp_positions.items[post.pos_start .. post.pos_start + post.pos_count];
                        @memcpy(positions[pos_cursor .. pos_cursor + src_pos.len], src_pos);
                        pos_cursor += @intCast(src_pos.len);
                    }
                    if (post.tf > max_tf) max_tf = post.tf;
                    const doc_norm = norm_dl[post.doc_id];
                    if (doc_norm < min_norm_dl) min_norm_dl = doc_norm;
                    posting_cursor += 1;
                }

                // Conservative upper bound over all documents in this 256-doc block (`A5`):
                // BM25 is strictly increasing in `tf` and strictly decreasing in `dequantizeNormDl(norm_dl)`.
                const block_upper_score = SearchOracle.scoreTermQuantized(
                    max_tf,
                    min_norm_dl,
                    avg_doc_len,
                    idf,
                    descriptor.bm25_params,
                );
                const block_q16 = SearchOracle.quantizeImpactQ16(block_upper_score);
                if (block_q16 > max_term_q16) max_term_q16 = block_q16;

                blocks[block_cursor] = .{
                    .first_doc_id = chunk[0].doc_id,
                    .max_doc_id = chunk[chunk.len - 1].doc_id,
                    .doc_count = @intCast(chunk.len),
                    .max_tf = max_tf,
                    .min_norm_dl = min_norm_dl,
                    .flags = if (descriptor.positions_enabled) 1 else 0,
                    .max_impact_q16 = block_q16,
                    .posting_start = b_posting_start,
                    .pos_offset_start = b_posting_start,
                };
                block_cursor += 1;
            }

            terms[ti] = .{
                .term = t_slice,
                .doc_freq = df,
                .idf = idf,
                .max_term_impact_q16 = max_term_q16,
                .block_start = term_block_start,
                .block_count = block_cursor - term_block_start,
            };
        }
        pos_offsets[posting_cursor] = pos_cursor;

        const term_directory = try PerfectHash.FrozenDirectory.init(term_slices, .utf8_binary);

        return .{
            .allocator = allocator,
            .descriptor = descriptor,
            .row_count = @intCast(cells.len),
            .valid_doc_count = valid_doc_count,
            .avg_doc_len = avg_doc_len,
            .norm_dl = norm_dl,
            .valid_bitmap = valid_bitmap,
            .error_bitmap = error_bitmap,
            .conflict_bitmap = conflict_bitmap,
            .first_error_kind = first_error_kind,
            .terms_arena = terms_arena,
            .term_slices = term_slices,
            .terms = terms,
            .term_directory = term_directory,
            .blocks = blocks,
            .posting_doc_ids = posting_doc_ids,
            .posting_tfs = posting_tfs,
            .pos_offsets = pos_offsets,
            .positions = positions,
        };
    }

    /// Encode the segment header and block directory into a wire/storage envelope
    /// with `"TSS1"` magic, current definition bytes, and trailing CRC32 checksum.
    pub fn encodeHeaderEnvelope(self: *const Segment, out: []u8) Error![]const u8 {
        if (out.len < 128) return error.SearchScratchExhausted;
        var writer: std.Io.Writer = .fixed(out[0 .. out.len - 4]);
        writer.writeAll(magic) catch return error.SearchScratchExhausted;
        writer.writeAll(&definition) catch return error.SearchScratchExhausted;
        writer.writeInt(u64, self.descriptor.index_id, .little) catch return error.SearchScratchExhausted;
        writer.writeInt(u64, self.descriptor.column_id, .little) catch return error.SearchScratchExhausted;
        writer.writeByte(@backingInt(self.descriptor.index_profile)) catch return error.SearchScratchExhausted;
        writer.writeByte(@backingInt(self.descriptor.segmenter_profile)) catch return error.SearchScratchExhausted;
        writer.writeAll(&self.descriptor.segmenter_digest) catch return error.SearchScratchExhausted;
        writer.writeInt(u32, self.row_count, .little) catch return error.SearchScratchExhausted;
        writer.writeInt(u32, self.valid_doc_count, .little) catch return error.SearchScratchExhausted;
        writer.writeInt(u32, @intCast(self.terms.len), .little) catch return error.SearchScratchExhausted;
        writer.writeInt(u32, @intCast(self.blocks.len), .little) catch return error.SearchScratchExhausted;

        const payload = writer.buffered();
        const crc = std.hash.Crc32.hash(payload);
        std.mem.writeInt(u32, out[payload.len..][0..4], crc, .little);
        return out[0 .. payload.len + 4];
    }

    pub fn validateHeaderEnvelope(bytes: []const u8) Error!struct {
        index_id: u64,
        column_id: u64,
        row_count: u32,
        term_count: u32,
        block_count: u32,
    } {
        if (bytes.len < 102) return error.InvalidSearchSegment;
        if (!std.mem.eql(u8, bytes[0..4], magic)) return error.InvalidSearchSegment;
        if (!std.mem.eql(u8, bytes[4..36], &definition)) return error.IncompatibleDefinition;
        const payload = bytes[0 .. bytes.len - 4];
        const expected_crc = std.mem.readInt(u32, bytes[bytes.len - 4 ..][0..4], .little);
        if (std.hash.Crc32.hash(payload) != expected_crc) return error.SearchSegmentChecksumMismatch;

        const index_id = std.mem.readInt(u64, bytes[36..44], .little);
        const column_id = std.mem.readInt(u64, bytes[44..52], .little);
        const row_count = std.mem.readInt(u32, bytes[86..90], .little);
        const term_count = std.mem.readInt(u32, bytes[94..98], .little);
        const block_count = std.mem.readInt(u32, bytes[98..102], .little);
        return .{
            .index_id = index_id,
            .column_id = column_id,
            .row_count = row_count,
            .term_count = term_count,
            .block_count = block_count,
        };
    }
};
