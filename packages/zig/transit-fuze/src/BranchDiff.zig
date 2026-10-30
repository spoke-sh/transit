//! Segment-skipping two-way and three-way relational/spatial `DIFF` (`A4`),
//! catalog `DIFF_SCHEMA` over `CatalogId`/`DefinitionId`/`ColumnId` lineage,
//! compaction-invariant multiset equivalence, 2D/3D topological and volumetric
//! conflict promotion, and five-state `IS CONFLICT` (`v.Cell.conflict`) cell projection.
const std = @import("std");
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const v = t.Values;
const Collation = @import("Collation.zig");
const TableConstraints = @import("TableConstraints.zig");
const TableSchemaProjection = @import("TableSchemaProjection.zig");

pub const DiffOp = enum(u8) {
    added = 1,
    modified = 2,
    removed = 3,
    conflict = 4,

    pub fn asText(self: DiffOp) []const u8 {
        return switch (self) {
            .added => "added",
            .modified => "modified",
            .removed => "removed",
            .conflict => "conflict",
        };
    }
};

pub const BBox2D = struct {
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,

    pub fn validate(self: BBox2D) !void {
        if (std.math.isNan(self.min_x) or std.math.isNan(self.min_y) or
            std.math.isNan(self.max_x) or std.math.isNan(self.max_y) or
            self.min_x > self.max_x or self.min_y > self.max_y)
        {
            return error.InvalidBBox2D;
        }
    }

    pub fn intersects(self: BBox2D, other: BBox2D) bool {
        return !(self.max_x < other.min_x or self.min_x > other.max_x or
            self.max_y < other.min_y or self.min_y > other.max_y);
    }
};

pub const BBox3D = struct {
    min_x: f64,
    min_y: f64,
    min_z: f64,
    max_x: f64,
    max_y: f64,
    max_z: f64,

    pub fn validate(self: BBox3D) !void {
        if (std.math.isNan(self.min_x) or std.math.isNan(self.min_y) or std.math.isNan(self.min_z) or
            std.math.isNan(self.max_x) or std.math.isNan(self.max_y) or std.math.isNan(self.max_z) or
            self.min_x > self.max_x or self.min_y > self.max_y or self.min_z > self.max_z)
        {
            return error.InvalidBBox3D;
        }
    }

    pub fn intersects(self: BBox3D, other: BBox3D) bool {
        return !(self.max_x < other.min_x or self.min_x > other.max_x or
            self.max_y < other.min_y or self.min_y > other.max_y or
            self.max_z < other.min_z or self.min_z > other.max_z);
    }

    pub fn minDistance(self: BBox3D, other: BBox3D) f64 {
        const dx = @max(@as(f64, 0.0), @max(self.min_x - other.max_x, other.min_x - self.max_x));
        const dy = @max(@as(f64, 0.0), @max(self.min_y - other.max_y, other.min_y - self.max_y));
        const dz = @max(@as(f64, 0.0), @max(self.min_z - other.max_z, other.min_z - self.max_z));
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

pub const CellRange = struct {
    min_cell: u64,
    max_cell: u64,

    pub fn intersects(self: CellRange, min_other: u64, max_other: u64) bool {
        return !(self.max_cell < min_other or self.min_cell > max_other);
    }
};

pub const SpatialZoneSummary = struct {
    bbox2d: ?BBox2D = null,
    bbox3d: ?BBox3D = null,
    s2_hilbert_min: u64 = 0,
    s2_hilbert_max: u64 = 0,
    oct_cell_min: u64 = 0,
    oct_cell_max: u64 = 0,
};

pub const SpatialViewportFilter = struct {
    bbox2d: ?BBox2D = null,
    bbox3d: ?BBox3D = null,
    s2_range: ?CellRange = null,
    oct_range: ?CellRange = null,

    pub fn matchesZone(self: SpatialViewportFilter, zone: SpatialZoneSummary) !bool {
        if (self.bbox2d) |vp2d| {
            try vp2d.validate();
            if (zone.bbox2d) |zb2d| {
                try zb2d.validate();
                if (!vp2d.intersects(zb2d)) return false;
            }
        }
        if (self.bbox3d) |vp3d| {
            try vp3d.validate();
            if (zone.bbox3d) |zb3d| {
                try zb3d.validate();
                if (!vp3d.intersects(zb3d)) return false;
            }
        }
        if (self.s2_range) |s2r| {
            if (s2r.min_cell > s2r.max_cell) return error.InvalidSpatialCellRange;
            if (zone.s2_hilbert_max != 0 and !s2r.intersects(zone.s2_hilbert_min, zone.s2_hilbert_max)) {
                return false;
            }
        }
        if (self.oct_range) |octr| {
            if (octr.min_cell > octr.max_cell) return error.InvalidSpatialCellRange;
            if (zone.oct_cell_max != 0 and !octr.intersects(zone.oct_cell_min, zone.oct_cell_max)) {
                return false;
            }
        }
        return true;
    }
};

pub const SegmentDigestInfo = struct {
    segment_id: u64,
    segment_sha256: [32]u8,
    tdel_sha256: [32]u8 = @splat(0),
    logical_row_multiset_hash: [32]u8,
    row_count: u64,
    spatial: SpatialZoneSummary = .{},

    pub fn matchesIdentical(self: SegmentDigestInfo, other: SegmentDigestInfo) bool {
        return std.mem.eql(u8, &self.segment_sha256, &other.segment_sha256) and
            std.mem.eql(u8, &self.tdel_sha256, &other.tdel_sha256);
    }
};

/// Records a physical compaction rewrite (`{input_segments} -> output_segment`)
/// so that `DIFF` and `MERGE` never invent false logical changes or conflicts
/// when one branch compacts segments without mutating logical rows.
pub const CompactionLineageEdge = struct {
    input_segment_sha256s: []const [32]u8,
    input_tdel_sha256s: []const [32]u8,
    output_segment_sha256: [32]u8,
    output_tdel_sha256: [32]u8 = @splat(0),
    logical_row_multiset_hash: [32]u8,

    pub fn validate(self: CompactionLineageEdge) !void {
        if (self.input_segment_sha256s.len == 0 or
            self.input_segment_sha256s.len != self.input_tdel_sha256s.len)
        {
            return error.InvalidCompactionLineageEdge;
        }
    }
};

pub const SegmentSkipSummary = struct {
    identical_skipped_segments: u32 = 0,
    compaction_equivalent_skipped_segments: u32 = 0,
    spatial_viewport_skipped_segments: u32 = 0,
    active_from_segments: u32 = 0,
    active_to_segments: u32 = 0,
    active_base_segments: u32 = 0,
    active_source_segments: u32 = 0,
    active_target_segments: u32 = 0,
};

fn isMatchedByCompactionEdge(
    seg: SegmentDigestInfo,
    peer_segments: []const SegmentDigestInfo,
    edges: []const CompactionLineageEdge,
) bool {
    for (edges) |edge| {
        if (std.mem.eql(u8, &seg.segment_sha256, &edge.output_segment_sha256) and
            std.mem.eql(u8, &seg.tdel_sha256, &edge.output_tdel_sha256) and
            std.mem.eql(u8, &seg.logical_row_multiset_hash, &edge.logical_row_multiset_hash))
        {
            var all_inputs_present = true;
            for (edge.input_segment_sha256s, edge.input_tdel_sha256s) |in_seg, in_tdel| {
                var found = false;
                for (peer_segments) |peer| {
                    if (std.mem.eql(u8, &peer.segment_sha256, &in_seg) and
                        std.mem.eql(u8, &peer.tdel_sha256, &in_tdel))
                    {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    all_inputs_present = false;
                    break;
                }
            }
            if (all_inputs_present) return true;
        }

        // Or `seg` is one of the uncompacted inputs and `peer_segments` has the compacted output
        for (edge.input_segment_sha256s, edge.input_tdel_sha256s) |in_seg, in_tdel| {
            if (std.mem.eql(u8, &seg.segment_sha256, &in_seg) and
                std.mem.eql(u8, &seg.tdel_sha256, &in_tdel))
            {
                for (peer_segments) |peer| {
                    if (std.mem.eql(u8, &peer.segment_sha256, &edge.output_segment_sha256) and
                        std.mem.eql(u8, &peer.tdel_sha256, &edge.output_tdel_sha256) and
                        std.mem.eql(u8, &peer.logical_row_multiset_hash, &edge.logical_row_multiset_hash))
                    {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

/// Plan a two-way segment diff (`from` vs `to`), skipping identical `(tseg, tdel)`
/// pairs, compaction-equivalent rewrites, and out-of-viewport spatial segments in $O(1)$.
pub fn planTwoWaySegmentDiff(
    from_segments: []const SegmentDigestInfo,
    to_segments: []const SegmentDigestInfo,
    compaction_edges: []const CompactionLineageEdge,
    viewport: ?SpatialViewportFilter,
) !SegmentSkipSummary {
    for (compaction_edges) |edge| try edge.validate();
    var summary: SegmentSkipSummary = .{};

    for (from_segments) |f_seg| {
        if (viewport) |vp| {
            if (!try vp.matchesZone(f_seg.spatial)) {
                summary.spatial_viewport_skipped_segments += 1;
                continue;
            }
        }
        var identical = false;
        for (to_segments) |t_seg| {
            if (f_seg.matchesIdentical(t_seg)) {
                identical = true;
                break;
            }
        }
        if (identical) {
            summary.identical_skipped_segments += 1;
            continue;
        }
        if (isMatchedByCompactionEdge(f_seg, to_segments, compaction_edges)) {
            summary.compaction_equivalent_skipped_segments += 1;
            continue;
        }
        summary.active_from_segments += 1;
    }

    for (to_segments) |t_seg| {
        if (viewport) |vp| {
            if (!try vp.matchesZone(t_seg.spatial)) {
                summary.spatial_viewport_skipped_segments += 1;
                continue;
            }
        }
        var identical = false;
        for (from_segments) |f_seg| {
            if (t_seg.matchesIdentical(f_seg)) {
                identical = true;
                break;
            }
        }
        if (identical) continue;
        if (isMatchedByCompactionEdge(t_seg, from_segments, compaction_edges)) {
            summary.compaction_equivalent_skipped_segments += 1;
            continue;
        }
        summary.active_to_segments += 1;
    }

    return summary;
}

/// Plan a three-way segment diff/merge (`base`, `source`, `target`), skipping
/// `.tseg` segments and `.tdel` bitmaps shared identically across all three cuts
/// (`A4: BranchMergeAlgebra.lean`) or rewritten by physical compaction without logical change.
pub fn planThreeWaySegmentDiff(
    base_segments: []const SegmentDigestInfo,
    source_segments: []const SegmentDigestInfo,
    target_segments: []const SegmentDigestInfo,
    compaction_edges: []const CompactionLineageEdge,
    viewport: ?SpatialViewportFilter,
) !SegmentSkipSummary {
    for (compaction_edges) |edge| try edge.validate();
    var summary: SegmentSkipSummary = .{};

    for (base_segments) |b_seg| {
        if (viewport) |vp| {
            if (!try vp.matchesZone(b_seg.spatial)) {
                summary.spatial_viewport_skipped_segments += 1;
                continue;
            }
        }
        var in_source = false;
        for (source_segments) |s_seg| {
            if (b_seg.matchesIdentical(s_seg)) {
                in_source = true;
                break;
            }
        }
        var in_target = false;
        for (target_segments) |t_seg| {
            if (b_seg.matchesIdentical(t_seg)) {
                in_target = true;
                break;
            }
        }
        if (in_source and in_target) {
            summary.identical_skipped_segments += 1;
            continue;
        }
        const comp_source = in_source or isMatchedByCompactionEdge(b_seg, source_segments, compaction_edges);
        const comp_target = in_target or isMatchedByCompactionEdge(b_seg, target_segments, compaction_edges);
        if (comp_source and comp_target) {
            summary.compaction_equivalent_skipped_segments += 1;
            continue;
        }
        summary.active_base_segments += 1;
    }

    for (source_segments) |s_seg| {
        if (viewport) |vp| {
            if (!try vp.matchesZone(s_seg.spatial)) continue;
        }
        var in_base = false;
        for (base_segments) |b_seg| if (s_seg.matchesIdentical(b_seg)) {
            in_base = true;
            break;
        };
        var in_target = false;
        for (target_segments) |t_seg| if (s_seg.matchesIdentical(t_seg)) {
            in_target = true;
            break;
        };
        const comp_base = in_base or isMatchedByCompactionEdge(s_seg, base_segments, compaction_edges);
        const comp_target = in_target or isMatchedByCompactionEdge(s_seg, target_segments, compaction_edges);
        if (comp_base and comp_target) continue;
        summary.active_source_segments += 1;
    }

    for (target_segments) |t_seg| {
        if (viewport) |vp| {
            if (!try vp.matchesZone(t_seg.spatial)) continue;
        }
        var in_base = false;
        for (base_segments) |b_seg| if (t_seg.matchesIdentical(b_seg)) {
            in_base = true;
            break;
        };
        var in_source = false;
        for (source_segments) |s_seg| if (t_seg.matchesIdentical(s_seg)) {
            in_source = true;
            break;
        };
        const comp_base = in_base or isMatchedByCompactionEdge(t_seg, base_segments, compaction_edges);
        const comp_source = in_source or isMatchedByCompactionEdge(t_seg, source_segments, compaction_edges);
        if (comp_base and comp_source) continue;
        summary.active_target_segments += 1;
    }

    return summary;
}

pub const CollationProfileBinding = struct {
    column: s.ColumnId,
    profile: Collation.Profile,
};

pub const RowEntry = struct {
    cells: []const v.Cell,
};

pub const BranchTableSnapshot = struct {
    branch_id: u64,
    commit_lsn: u64,
    schema: s.Schema,
    collation_profiles: []const CollationProfileBinding = &.{},
    column_origins: []const TableSchemaProjection.Initial = &.{},
    rows: []const RowEntry = &.{},

    pub fn profileForColumn(self: BranchTableSnapshot, column_id: s.ColumnId) !Collation.Profile {
        for (self.collation_profiles) |cp| {
            if (cp.column == column_id) return cp.profile;
        }
        const idx = try self.schema.index(column_id);
        return Collation.Profile.fromCollation(self.schema.columns[idx].collation);
    }
};

pub const DiffRowResult = struct {
    op: DiffOp,
    key_cell: v.Cell,
    cells: [s.max_columns]v.Cell = undefined,
    column_count: usize,
    conflict_alternatives: [s.max_columns][2]v.Alternative = undefined,
    conflict_columns: [s.max_columns]bool = @splat(false),
    conflict_count: u16 = 0,
    delete_modify_conflict: bool = false,

    /// Evaluates SQL `WHERE <col> IS CONFLICT` on the projected diff row.
    pub fn isColumnConflict(self: *const DiffRowResult, column_index: usize) bool {
        if (column_index >= self.column_count) return false;
        return self.conflict_columns[column_index] or self.cells[column_index] == .conflict;
    }
};

fn projectRowToTarget(
    source_snap: BranchTableSnapshot,
    target_schema: s.Schema,
    target_origins: []const TableSchemaProjection.Initial,
    row_cells: []const v.Cell,
    out_cells: *[s.max_columns]v.Cell,
) ![]const v.Cell {
    var init_buf: [s.max_columns]TableSchemaProjection.Initial = undefined;
    var init_count: usize = 0;
    for (target_origins) |init| {
        const in_target = if (target_schema.index(init.column)) |_| true else |_| false;
        const in_source = if (source_snap.schema.index(init.column)) |_| true else |_| false;
        if (in_target and !in_source) {
            init_buf[init_count] = init;
            init_count += 1;
        }
    }
    const proj = try TableSchemaProjection.init(source_snap.schema, target_schema, init_buf[0..init_count]);
    return proj.row(row_cells, out_cells[0..target_schema.columns.len]);
}

pub fn compareCellsUnderProfile(
    left: v.Cell,
    right: v.Cell,
    col_type: t.Type,
    profile: Collation.Profile,
) !std.math.Order {
    const tag_l = @backingInt(std.meta.activeTag(left));
    const tag_r = @backingInt(std.meta.activeTag(right));
    if (tag_l != tag_r) return std.math.order(tag_l, tag_r);
    return switch (left) {
        .missing, .null => .eq,
        .type_error => |kl| std.math.order(@backingInt(kl), @backingInt(right.type_error)),
        .value => |vl| switch (vl) {
            .atom => |al| switch (al) {
                .bytes => |lb| Collation.compareBytesProfile(lb, right.value.atom.bytes, profile),
                else => Collation.compareAtom(al, right.value.atom, col_type, .none),
            },
            else => if (std.meta.eql(vl, right.value)) .eq else .lt,
        },
        .conflict => .lt,
    };
}

fn findRowByPrimaryKey(
    snap: BranchTableSnapshot,
    target_schema: s.Schema,
    target_origins: []const TableSchemaProjection.Initial,
    pk_col_id: s.ColumnId,
    pk_target_idx: usize,
    pk_type: t.Type,
    pk_profile: Collation.Profile,
    needle_key: v.Cell,
    out_projected: *[s.max_columns]v.Cell,
) !?[]const v.Cell {
    _ = pk_col_id;
    for (snap.rows) |r| {
        const projected = try projectRowToTarget(snap, target_schema, target_origins, r.cells, out_projected);
        const ord = try compareCellsUnderProfile(projected[pk_target_idx], needle_key, pk_type, pk_profile);
        if (ord == .eq) return projected;
    }
    return null;
}

fn makeAlternative(counter: u64, replica: u64, cell: v.Cell) !v.Alternative {
    if (counter == 0 or replica == 0) return error.InvalidConflict;
    return switch (cell) {
        .null, .missing => .{ .counter = counter, .replica = replica, .value = .null },
        .type_error => |k| .{ .counter = counter, .replica = replica, .value = .{ .type_error = k } },
        .value => |val| .{ .counter = counter, .replica = replica, .value = .{ .value = val } },
        .conflict => |alts| alts[0],
    };
}

pub fn populateConflictCell(
    row_out: *DiffRowResult,
    col_idx: usize,
    source_lsn: u64,
    source_branch_id: u64,
    source_cell: v.Cell,
    target_lsn: u64,
    target_branch_id: u64,
    target_cell: v.Cell,
) !void {
    const eff_target_lsn = if (source_lsn == target_lsn and source_branch_id == target_branch_id)
        target_lsn + 1
    else
        target_lsn;
    const alt_s = try makeAlternative(source_lsn, source_branch_id, source_cell);
    const alt_t = try makeAlternative(eff_target_lsn, target_branch_id, target_cell);

    if (alt_s.counter < alt_t.counter or (alt_s.counter == alt_t.counter and alt_s.replica < alt_t.replica)) {
        row_out.conflict_alternatives[col_idx] = .{ alt_s, alt_t };
    } else {
        row_out.conflict_alternatives[col_idx] = .{ alt_t, alt_s };
    }
    row_out.cells[col_idx] = .{ .conflict = &row_out.conflict_alternatives[col_idx] };
    row_out.conflict_columns[col_idx] = true;
    row_out.conflict_count += 1;
}

/// Compute a key-aligned two-way relational diff (`DIFF(table, FROM => a, TO => b)`),
/// projecting across compatible `ColumnId` schema evolutions.
pub fn computeTwoWayRowDiff(
    from_snap: BranchTableSnapshot,
    to_snap: BranchTableSnapshot,
    out_rows: []DiffRowResult,
) !usize {
    if (to_snap.schema.primary_key.len == 0) return error.DiffRequiresPrimaryKey;
    const pk_id = to_snap.schema.primary_key[0];
    const pk_idx = try to_snap.schema.index(pk_id);
    const pk_col = to_snap.schema.columns[pk_idx];
    const pk_profile = try to_snap.profileForColumn(pk_id);
    const col_count = to_snap.schema.columns.len;

    var count: usize = 0;
    var from_proj_buf: [s.max_columns]v.Cell = undefined;
    var to_proj_buf: [s.max_columns]v.Cell = undefined;

    // 1. Check rows in `to_snap` (added or modified relative to `from_snap`)
    for (to_snap.rows) |t_row| {
        const t_cells = try projectRowToTarget(to_snap, to_snap.schema, to_snap.column_origins, t_row.cells, &to_proj_buf);
        const key_cell = t_cells[pk_idx];
        if (try findRowByPrimaryKey(
            from_snap,
            to_snap.schema,
            to_snap.column_origins,
            pk_id,
            pk_idx,
            pk_col.type,
            pk_profile,
            key_cell,
            &from_proj_buf,
        )) |f_cells| {
            var any_diff = false;
            for (to_snap.schema.columns, 0..) |col, c_idx| {
                const prof = try to_snap.profileForColumn(col.id);
                if (try compareCellsUnderProfile(f_cells[c_idx], t_cells[c_idx], col.type, prof) != .eq) {
                    any_diff = true;
                    break;
                }
            }
            if (any_diff) {
                if (count >= out_rows.len) return error.DiffOutputBufferTooSmall;
                out_rows[count] = .{
                    .op = .modified,
                    .key_cell = key_cell,
                    .column_count = col_count,
                };
                @memcpy(out_rows[count].cells[0..col_count], t_cells[0..col_count]);
                count += 1;
            }
        } else {
            if (count >= out_rows.len) return error.DiffOutputBufferTooSmall;
            out_rows[count] = .{
                .op = .added,
                .key_cell = key_cell,
                .column_count = col_count,
            };
            @memcpy(out_rows[count].cells[0..col_count], t_cells[0..col_count]);
            count += 1;
        }
    }

    // 2. Check rows in `from_snap` that were removed in `to_snap`
    for (from_snap.rows) |f_row| {
        const f_cells = try projectRowToTarget(from_snap, to_snap.schema, to_snap.column_origins, f_row.cells, &from_proj_buf);
        const key_cell = f_cells[pk_idx];
        const in_to = (try findRowByPrimaryKey(
            to_snap,
            to_snap.schema,
            to_snap.column_origins,
            pk_id,
            pk_idx,
            pk_col.type,
            pk_profile,
            key_cell,
            &to_proj_buf,
        )) != null;
        if (!in_to) {
            if (count >= out_rows.len) return error.DiffOutputBufferTooSmall;
            out_rows[count] = .{
                .op = .removed,
                .key_cell = key_cell,
                .column_count = col_count,
            };
            @memcpy(out_rows[count].cells[0..col_count], f_cells[0..col_count]);
            count += 1;
        }
    }

    return count;
}

/// Compute a three-way relational diff/merge preview (`DIFF(table, BASE => b, SOURCE => s, TARGET => t)`),
/// representing conflicting cell edits natively using Transit's five-state `conflict` cell tag (`IS CONFLICT`).
pub fn computeThreeWayRowDiff(
    base_snap: BranchTableSnapshot,
    source_snap: BranchTableSnapshot,
    target_snap: BranchTableSnapshot,
    out_rows: []DiffRowResult,
) !usize {
    if (target_snap.schema.primary_key.len == 0) return error.DiffRequiresPrimaryKey;
    const out_schema = target_snap.schema;
    const out_origins = target_snap.column_origins;
    const pk_id = out_schema.primary_key[0];
    const pk_idx = try out_schema.index(pk_id);
    const pk_col = out_schema.columns[pk_idx];
    const pk_profile = try target_snap.profileForColumn(pk_id);
    const col_count = out_schema.columns.len;

    var count: usize = 0;
    var base_buf: [s.max_columns]v.Cell = undefined;
    var src_buf: [s.max_columns]v.Cell = undefined;
    var tgt_buf: [s.max_columns]v.Cell = undefined;

    // Collect distinct candidate primary keys across base, source, target
    var seen_keys: [128]v.Cell = undefined;
    var seen_count: usize = 0;

    for ([_]BranchTableSnapshot{ base_snap, source_snap, target_snap }) |snap| {
        for (snap.rows) |r| {
            var tmp_buf: [s.max_columns]v.Cell = undefined;
            const proj = try projectRowToTarget(snap, out_schema, out_origins, r.cells, &tmp_buf);
            const k = proj[pk_idx];
            var exists = false;
            for (seen_keys[0..seen_count]) |prev_k| {
                if (try compareCellsUnderProfile(prev_k, k, pk_col.type, pk_profile) == .eq) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                if (seen_count >= seen_keys.len) return error.TooManyCandidateKeys;
                seen_keys[seen_count] = k;
                seen_count += 1;
            }
        }
    }

    for (seen_keys[0..seen_count]) |key_cell| {
        const maybe_base = try findRowByPrimaryKey(base_snap, out_schema, out_origins, pk_id, pk_idx, pk_col.type, pk_profile, key_cell, &base_buf);
        const maybe_src = try findRowByPrimaryKey(source_snap, out_schema, out_origins, pk_id, pk_idx, pk_col.type, pk_profile, key_cell, &src_buf);
        const maybe_tgt = try findRowByPrimaryKey(target_snap, out_schema, out_origins, pk_id, pk_idx, pk_col.type, pk_profile, key_cell, &tgt_buf);

        if (maybe_base) |b_cells| {
            if (maybe_src != null and maybe_tgt != null) {
                const s_cells = maybe_src.?;
                const t_cells = maybe_tgt.?;
                if (count >= out_rows.len) return error.DiffOutputBufferTooSmall;
                var row_res: DiffRowResult = .{
                    .op = .modified,
                    .key_cell = key_cell,
                    .column_count = col_count,
                };
                var any_change = false;
                for (out_schema.columns, 0..) |col, c_idx| {
                    const prof = try target_snap.profileForColumn(col.id);
                    const s_eq_b = (try compareCellsUnderProfile(s_cells[c_idx], b_cells[c_idx], col.type, prof)) == .eq;
                    const t_eq_b = (try compareCellsUnderProfile(t_cells[c_idx], b_cells[c_idx], col.type, prof)) == .eq;
                    const s_eq_t = (try compareCellsUnderProfile(s_cells[c_idx], t_cells[c_idx], col.type, prof)) == .eq;

                    if (s_eq_b and t_eq_b) {
                        row_res.cells[c_idx] = t_cells[c_idx];
                    } else if (!s_eq_b and t_eq_b) {
                        row_res.cells[c_idx] = s_cells[c_idx];
                        any_change = true;
                    } else if (s_eq_b and !t_eq_b) {
                        row_res.cells[c_idx] = t_cells[c_idx];
                        any_change = true;
                    } else if (s_eq_t) {
                        // Both branches modified the cell to the same value -> convergent edit
                        row_res.cells[c_idx] = s_cells[c_idx];
                        any_change = true;
                    } else {
                        // Divergent cell edit -> native 5-state `IS CONFLICT` cell
                        any_change = true;
                        row_res.op = .conflict;
                        try populateConflictCell(
                            &row_res,
                            c_idx,
                            source_snap.commit_lsn,
                            source_snap.branch_id,
                            s_cells[c_idx],
                            target_snap.commit_lsn,
                            target_snap.branch_id,
                            t_cells[c_idx],
                        );
                    }
                }
                if (any_change) {
                    out_rows[count] = row_res;
                    count += 1;
                }
            } else if (maybe_src == null and maybe_tgt == null) {
                // Both branches deleted the row -> convergent removal
                if (count >= out_rows.len) return error.DiffOutputBufferTooSmall;
                out_rows[count] = .{
                    .op = .removed,
                    .key_cell = key_cell,
                    .column_count = col_count,
                };
                @memcpy(out_rows[count].cells[0..col_count], b_cells[0..col_count]);
                count += 1;
            } else {
                // Deleted on one branch; check if modified on the surviving branch
                const surviving = maybe_src orelse maybe_tgt.?;
                const surviving_snap = if (maybe_src != null) source_snap else target_snap;
                const deleting_snap = if (maybe_src == null) source_snap else target_snap;

                var modified_on_survivor = false;
                for (out_schema.columns, 0..) |col, c_idx| {
                    const prof = try target_snap.profileForColumn(col.id);
                    if (try compareCellsUnderProfile(surviving[c_idx], b_cells[c_idx], col.type, prof) != .eq) {
                        modified_on_survivor = true;
                        break;
                    }
                }
                if (count >= out_rows.len) return error.DiffOutputBufferTooSmall;
                if (!modified_on_survivor) {
                    // Clean delete on one side, untouched on the other
                    out_rows[count] = .{
                        .op = .removed,
                        .key_cell = key_cell,
                        .column_count = col_count,
                    };
                    @memcpy(out_rows[count].cells[0..col_count], b_cells[0..col_count]);
                    count += 1;
                } else {
                    // Delete vs. modify conflict!
                    var row_res: DiffRowResult = .{
                        .op = .conflict,
                        .key_cell = key_cell,
                        .column_count = col_count,
                        .delete_modify_conflict = true,
                    };
                    for (out_schema.columns, 0..) |col, c_idx| {
                        const prof = try target_snap.profileForColumn(col.id);
                        if (c_idx == pk_idx or (try compareCellsUnderProfile(surviving[c_idx], b_cells[c_idx], col.type, prof)) == .eq) {
                            row_res.cells[c_idx] = surviving[c_idx];
                        } else {
                            try populateConflictCell(
                                &row_res,
                                c_idx,
                                surviving_snap.commit_lsn,
                                surviving_snap.branch_id,
                                surviving[c_idx],
                                deleting_snap.commit_lsn,
                                deleting_snap.branch_id,
                                .null,
                            );
                        }
                    }
                    out_rows[count] = row_res;
                    count += 1;
                }
            }
        } else {
            // Absent in base: added on source, target, or both
            if (maybe_src != null and maybe_tgt == null) {
                if (count >= out_rows.len) return error.DiffOutputBufferTooSmall;
                out_rows[count] = .{
                    .op = .added,
                    .key_cell = key_cell,
                    .column_count = col_count,
                };
                @memcpy(out_rows[count].cells[0..col_count], maybe_src.?[0..col_count]);
                count += 1;
            } else if (maybe_src == null and maybe_tgt != null) {
                if (count >= out_rows.len) return error.DiffOutputBufferTooSmall;
                out_rows[count] = .{
                    .op = .added,
                    .key_cell = key_cell,
                    .column_count = col_count,
                };
                @memcpy(out_rows[count].cells[0..col_count], maybe_tgt.?[0..col_count]);
                count += 1;
            } else if (maybe_src != null and maybe_tgt != null) {
                const s_cells = maybe_src.?;
                const t_cells = maybe_tgt.?;
                if (count >= out_rows.len) return error.DiffOutputBufferTooSmall;
                var row_res: DiffRowResult = .{
                    .op = .added,
                    .key_cell = key_cell,
                    .column_count = col_count,
                };
                for (out_schema.columns, 0..) |col, c_idx| {
                    const prof = try target_snap.profileForColumn(col.id);
                    if (try compareCellsUnderProfile(s_cells[c_idx], t_cells[c_idx], col.type, prof) == .eq) {
                        row_res.cells[c_idx] = s_cells[c_idx];
                    } else {
                        row_res.op = .conflict;
                        try populateConflictCell(
                            &row_res,
                            c_idx,
                            source_snap.commit_lsn,
                            source_snap.branch_id,
                            s_cells[c_idx],
                            target_snap.commit_lsn,
                            target_snap.branch_id,
                            t_cells[c_idx],
                        );
                    }
                }
                out_rows[count] = row_res;
                count += 1;
            }
        }
    }

    return count;
}

/// Topological shared-boundary (`.topo_arc` / `.topo_face`) concurrent edit descriptor.
pub const TopologicalChainEdit = struct {
    primitive_id: u64,
    base_wkb_digest: [32]u8,
    source_wkb_digest: [32]u8,
    target_wkb_digest: [32]u8,
    source_lsn: u64,
    source_branch_id: u64,
    target_lsn: u64,
    target_branch_id: u64,
    preserves_manifold_closure: bool,
};

/// Evaluate a three-way edit to a shared `.topo_arc` chain or `.topo_face` surface.
/// If both branches modified the shared primitive incompatibly or violated planar/manifold
/// closure under $\kappa_{\text{spatial}}$, promote the cell to a five-state `IS CONFLICT` cell.
pub fn evaluateTopologicalEditConflict(
    edit: TopologicalChainEdit,
    out_alternatives: *[2]v.Alternative,
) !v.Cell {
    const src_changed = !std.mem.eql(u8, &edit.source_wkb_digest, &edit.base_wkb_digest);
    const tgt_changed = !std.mem.eql(u8, &edit.target_wkb_digest, &edit.base_wkb_digest);
    const same_target = std.mem.eql(u8, &edit.source_wkb_digest, &edit.target_wkb_digest);

    if (src_changed and tgt_changed and (!same_target or !edit.preserves_manifold_closure)) {
        const alt_s = try makeAlternative(edit.source_lsn, edit.source_branch_id, .{ .value = .{ .atom = .{ .bytes = &edit.source_wkb_digest } } });
        const alt_t = try makeAlternative(edit.target_lsn, edit.target_branch_id, .{ .value = .{ .atom = .{ .bytes = &edit.target_wkb_digest } } });
        if (alt_s.counter < alt_t.counter or (alt_s.counter == alt_t.counter and alt_s.replica < alt_t.replica)) {
            out_alternatives.* = .{ alt_s, alt_t };
        } else {
            out_alternatives.* = .{ alt_t, alt_s };
        }
        return .{ .conflict = out_alternatives };
    }
    if (src_changed) {
        return .{ .value = .{ .atom = .{ .bytes = &edit.source_wkb_digest } } };
    }
    return .{ .value = .{ .atom = .{ .bytes = &edit.target_wkb_digest } } };
}

/// 3D assembly (`SCENE3D`) concurrent sub-assembly transform clash descriptor.
pub const Scene3DClashEdit = struct {
    assembly_node_id: u64,
    source_bbox3d: BBox3D,
    target_bbox3d: BBox3D,
    required_clearance: f64,
    source_lsn: u64,
    source_branch_id: u64,
    target_lsn: u64,
    target_branch_id: u64,
    source_transform_bytes: []const u8,
    target_transform_bytes: []const u8,
};

/// Promote concurrent 3D assembly (`SCENE3D`) edits that violate volumetric clearance
/// (`minDistance < required_clearance`) into a five-state `IS CONFLICT` cell.
pub fn evaluateScene3DClashConflict(
    clash: Scene3DClashEdit,
    out_alternatives: *[2]v.Alternative,
) !v.Cell {
    try clash.source_bbox3d.validate();
    try clash.target_bbox3d.validate();
    if (clash.required_clearance < 0.0 or std.math.isNan(clash.required_clearance)) {
        return error.InvalidScene3DClearance;
    }
    const dist = clash.source_bbox3d.minDistance(clash.target_bbox3d);
    if (dist < clash.required_clearance or clash.source_bbox3d.intersects(clash.target_bbox3d)) {
        const alt_s = try makeAlternative(clash.source_lsn, clash.source_branch_id, .{ .value = .{ .atom = .{ .bytes = clash.source_transform_bytes } } });
        const alt_t = try makeAlternative(clash.target_lsn, clash.target_branch_id, .{ .value = .{ .atom = .{ .bytes = clash.target_transform_bytes } } });
        if (alt_s.counter < alt_t.counter or (alt_s.counter == alt_t.counter and alt_s.replica < alt_t.replica)) {
            out_alternatives.* = .{ alt_s, alt_t };
        } else {
            out_alternatives.* = .{ alt_t, alt_s };
        }
        return .{ .conflict = out_alternatives };
    }
    return .{ .value = .{ .atom = .{ .bytes = clash.source_transform_bytes } } };
}

pub const SchemaDiffKind = enum(u8) {
    table_renamed = 1,
    table_recreated = 2,
    column_added_lazy = 3,
    column_dropped = 4,
    column_renamed = 5,
    column_type_rewritten = 6,
    column_collation_rewritten = 7,
};

pub const SchemaDiffEntry = struct {
    kind: SchemaDiffKind,
    object: u64,
    column_id: ?s.ColumnId = null,
    old_name: []const u8,
    new_name: []const u8,
    rewrite_kind: TableConstraints.RewriteKind = .lazy_metadata_or_projection,
};

/// Compare `CatalogId` (`object`), `DefinitionId` (`revision`), and `ColumnId` graphs
/// between two table definitions (`DIFF_SCHEMA`), distinguishing `ColumnId`-preserving
/// renames and Class A lazy projections from drop-and-recreate or Class B physical rewrites.
pub fn diffTableSchemas(
    from_table_name: []const u8,
    from_schema: s.Schema,
    to_table_name: []const u8,
    to_schema: s.Schema,
    out_entries: []SchemaDiffEntry,
) !usize {
    try from_schema.validate();
    try to_schema.validate();
    var count: usize = 0;

    // If `object` changed, the table was dropped and recreated rather than evolved in place!
    if (from_schema.object != to_schema.object) {
        if (count >= out_entries.len) return error.SchemaDiffBufferTooSmall;
        out_entries[count] = .{
            .kind = .table_recreated,
            .object = to_schema.object,
            .old_name = from_table_name,
            .new_name = to_table_name,
            .rewrite_kind = .online_phased_rewrite,
        };
        return 1;
    }

    if (!std.mem.eql(u8, from_table_name, to_table_name)) {
        if (count >= out_entries.len) return error.SchemaDiffBufferTooSmall;
        out_entries[count] = .{
            .kind = .table_renamed,
            .object = to_schema.object,
            .old_name = from_table_name,
            .new_name = to_table_name,
            .rewrite_kind = .lazy_metadata_or_projection,
        };
        count += 1;
    }

    // Check columns in `from_schema` (dropped, renamed, or type/collation rewritten)
    for (from_schema.columns) |f_col| {
        if (to_schema.index(f_col.id)) |t_idx| {
            const t_col = to_schema.columns[t_idx];
            if (!std.mem.eql(u8, f_col.name, t_col.name)) {
                if (count >= out_entries.len) return error.SchemaDiffBufferTooSmall;
                out_entries[count] = .{
                    .kind = .column_renamed,
                    .object = to_schema.object,
                    .column_id = f_col.id,
                    .old_name = f_col.name,
                    .new_name = t_col.name,
                    .rewrite_kind = .lazy_metadata_or_projection,
                };
                count += 1;
            }
            if (!try f_col.type.eql(t_col.type)) {
                if (count >= out_entries.len) return error.SchemaDiffBufferTooSmall;
                out_entries[count] = .{
                    .kind = .column_type_rewritten,
                    .object = to_schema.object,
                    .column_id = f_col.id,
                    .old_name = f_col.name,
                    .new_name = t_col.name,
                    .rewrite_kind = .online_phased_rewrite,
                };
                count += 1;
            } else if (f_col.collation != t_col.collation) {
                if (count >= out_entries.len) return error.SchemaDiffBufferTooSmall;
                out_entries[count] = .{
                    .kind = .column_collation_rewritten,
                    .object = to_schema.object,
                    .column_id = f_col.id,
                    .old_name = f_col.name,
                    .new_name = t_col.name,
                    .rewrite_kind = .online_phased_rewrite,
                };
                count += 1;
            }
        } else |_| {
            if (count >= out_entries.len) return error.SchemaDiffBufferTooSmall;
            out_entries[count] = .{
                .kind = .column_dropped,
                .object = to_schema.object,
                .column_id = f_col.id,
                .old_name = f_col.name,
                .new_name = "",
                .rewrite_kind = .lazy_metadata_or_projection,
            };
            count += 1;
        }
    }

    // Check columns in `to_schema` added since `from_schema`
    for (to_schema.columns) |t_col| {
        if (from_schema.index(t_col.id)) |_| {} else |_| {
            if (count >= out_entries.len) return error.SchemaDiffBufferTooSmall;
            out_entries[count] = .{
                .kind = .column_added_lazy,
                .object = to_schema.object,
                .column_id = t_col.id,
                .old_name = "",
                .new_name = t_col.name,
                .rewrite_kind = if (t_col.nullable or t_col.default != null) .lazy_metadata_or_projection else .online_phased_rewrite,
            };
            count += 1;
        }
    }

    return count;
}
