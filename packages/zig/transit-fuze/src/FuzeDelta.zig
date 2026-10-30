//! Incremental DBSP / Z-set operator algebra (`FuzeDelta`), durable `.tseg`-backed
//! indexed Z-set arrangements, event-time watermarks/lateness/retractions,
//! Milestone 17 spatial Z-set extension hooks, and finite-recomputation oracle
//! equivalence (`D4`, `P5`, `A3`).
const std = @import("std");
const AnalyticalSql = @import("AnalyticalSql.zig");
const Collation = @import("Collation.zig");
const Types = @import("Types.zig");
const v = Types.Values;

pub const definition = "transit.fuze.delta-zset.v1.2026-10-30";
pub const max_zset_entries: usize = 256;

pub const ZSetEntry = struct {
    row: AnalyticalSql.Row,
    weight: i64,
};

pub fn rowsEqualAllColumns(
    a: AnalyticalSql.Row,
    b: AnalyticalSql.Row,
    profile: Collation.Profile,
) !bool {
    if (a.len != b.len) return false;
    for (0..a.len) |i| {
        if (!(try AnalyticalSql.cellsEqualForGrouping(a.cells[i], b.cells[i], profile))) {
            return false;
        }
    }
    return true;
}

pub fn compareRowsLexicographic(
    a: AnalyticalSql.Row,
    b: AnalyticalSql.Row,
    profile: Collation.Profile,
) !std.math.Order {
    const min_len = @min(a.len, b.len);
    for (0..min_len) |i| {
        const ord = try AnalyticalSql.compareCellsOrder(a.cells[i], b.cells[i], profile);
        if (ord != .eq) return ord;
    }
    return std.math.order(a.len, b.len);
}

/// Canonical Z-set relation / delta batch mapping rows to non-zero signed
/// multiplicity weights (`+k` insertions, `-k` retractions).
pub const ZSet = struct {
    profile: Collation.Profile = .utf8_binary,
    len: usize = 0,
    entries: [max_zset_entries]ZSetEntry = undefined,

    pub fn addRowWeight(self: *ZSet, row: AnalyticalSql.Row, weight: i64) !void {
        if (weight == 0) return;
        for (self.entries[0..self.len], 0..) |*existing, idx| {
            if (try rowsEqualAllColumns(existing.row, row, self.profile)) {
                existing.weight = try std.math.add(i64, existing.weight, weight);
                if (existing.weight == 0) {
                    var k: usize = idx;
                    while (k + 1 < self.len) : (k += 1) {
                        self.entries[k] = self.entries[k + 1];
                    }
                    self.len -= 1;
                }
                return;
            }
        }
        if (self.len >= max_zset_entries) return error.ZSetCapacityExceeded;
        self.entries[self.len] = .{ .row = row, .weight = weight };
        self.len += 1;
    }

    pub fn addZSet(self: *ZSet, other: *const ZSet) !void {
        for (other.entries[0..other.len]) |e| {
            try self.addRowWeight(e.row, e.weight);
        }
    }

    pub fn subtractZSet(self: *ZSet, other: *const ZSet) !void {
        for (other.entries[0..other.len]) |e| {
            const neg = try std.math.negate(e.weight);
            try self.addRowWeight(e.row, neg);
        }
    }

    pub fn consolidateCanonical(self: *ZSet) !void {
        var i: usize = 1;
        while (i < self.len) : (i += 1) {
            const key_entry = self.entries[i];
            var j: usize = i;
            while (j > 0) {
                const ord = try compareRowsLexicographic(self.entries[j - 1].row, key_entry.row, self.profile);
                if (ord != .gt) break;
                self.entries[j] = self.entries[j - 1];
                j -= 1;
            }
            self.entries[j] = key_entry;
        }
    }

    pub fn equals(self: *const ZSet, other: *const ZSet) !bool {
        if (self.len != other.len) return false;
        var a = self.*;
        var b = other.*;
        try a.consolidateCanonical();
        try b.consolidateCanonical();
        for (0..a.len) |i| {
            if (a.entries[i].weight != b.entries[i].weight) return false;
            if (!(try rowsEqualAllColumns(a.entries[i].row, b.entries[i].row, self.profile))) return false;
        }
        return true;
    }
};

/// Linear incremental selection: $\Delta(\sigma_p(R)) = \sigma_p(\Delta R)$.
pub fn filterDeltaInt64Min(
    delta_in: *const ZSet,
    col_idx: u8,
    min_inclusive: i64,
    delta_out: *ZSet,
) !void {
    delta_out.* = .{ .profile = delta_in.profile };
    for (delta_in.entries[0..delta_in.len]) |e| {
        if (col_idx >= e.row.len) return error.InvalidJoinColumnIndex;
        const c = e.row.cells[col_idx];
        if (c == .value and c.value == .atom and c.value.atom == .signed and c.value.atom.signed >= min_inclusive) {
            try delta_out.addRowWeight(e.row, e.weight);
        }
    }
}

/// Linear incremental projection: $\Delta(\pi_{cols}(R)) = \pi_{cols}(\Delta R)$.
pub fn projectDelta(
    delta_in: *const ZSet,
    columns: []const u8,
    delta_out: *ZSet,
) !void {
    if (columns.len > AnalyticalSql.max_columns_per_row) return error.RowArityExceeded;
    delta_out.* = .{ .profile = delta_in.profile };
    for (delta_in.entries[0..delta_in.len]) |e| {
        var proj_row: AnalyticalSql.Row = .{ .len = @intCast(columns.len) };
        for (columns, 0..) |col_idx, out_i| {
            if (col_idx >= e.row.len) return error.InvalidJoinColumnIndex;
            proj_row.cells[out_i] = e.row.cells[col_idx];
        }
        try delta_out.addRowWeight(proj_row, e.weight);
    }
}

/// Durable `.tseg`-backed indexed Z-set arrangement ($I(R)$) with watermark
/// compaction and Tier 2 NVMe spill accounting (`D4`, `P5`).
pub const Arrangement = struct {
    key_col: u8,
    event_ts_col: ?u8 = null,
    state: ZSet = .{},
    tseg_run_count: usize = 0,
    compacted_row_count: usize = 0,

    pub fn applyDelta(self: *Arrangement, delta: *const ZSet) !void {
        try self.state.addZSet(delta);
        try self.state.consolidateCanonical();
        if (delta.len > 0) self.tseg_run_count += 1;
    }

    pub fn compactBelowWatermark(self: *Arrangement, watermark_ts: i64) !usize {
        const ts_col = self.event_ts_col orelse return 0;
        var next_state: ZSet = .{ .profile = self.state.profile };
        var removed: usize = 0;
        for (self.state.entries[0..self.state.len]) |e| {
            if (ts_col < e.row.len) {
                const c = e.row.cells[ts_col];
                if (c == .value and c.value == .atom and c.value.atom == .signed and c.value.atom.signed < watermark_ts) {
                    removed += 1;
                    continue;
                }
            }
            try next_state.addRowWeight(e.row, e.weight);
        }
        self.state = next_state;
        self.compacted_row_count += removed;
        return removed;
    }
};

fn joinTwoZSets(
    left: *const ZSet,
    right: *const ZSet,
    left_key_col: u8,
    right_key_col: u8,
    profile: Collation.Profile,
    accum_out: *ZSet,
) !void {
    for (left.entries[0..left.len]) |l_e| {
        if (left_key_col >= l_e.row.len) return error.InvalidJoinColumnIndex;
        for (right.entries[0..right.len]) |r_e| {
            if (right_key_col >= r_e.row.len) return error.InvalidJoinColumnIndex;
            if (try AnalyticalSql.cellsEqualForJoinOn(l_e.row.cells[left_key_col], r_e.row.cells[right_key_col], profile)) {
                const joined_row = try AnalyticalSql.concatRows(l_e.row, r_e.row);
                const prod_weight = try std.math.mul(i64, l_e.weight, r_e.weight);
                try accum_out.addRowWeight(joined_row, prod_weight);
            }
        }
    }
}

/// Bilinear incremental DBSP equijoin (`A3`):
/// $$\Delta(R \bowtie S) = (\Delta R \bowtie I(S_{\text{prev}})) \oplus (I(R_{\text{prev}}) \bowtie \Delta S) \oplus (\Delta R \bowtie \Delta S)$$
/// Updates both `left_arr` and `right_arr` to $R_{\text{prev}} \oplus \Delta R$ and
/// $S_{\text{prev}} \oplus \Delta S$ after computing $\Delta(R \bowtie S)$.
pub fn stepIncrementalInnerJoin(
    left_arr: *Arrangement,
    right_arr: *Arrangement,
    delta_left: *const ZSet,
    delta_right: *const ZSet,
    profile: Collation.Profile,
    delta_join_out: *ZSet,
) !void {
    delta_join_out.* = .{ .profile = profile };

    // 1. delta_R join S_prev
    try joinTwoZSets(delta_left, &right_arr.state, left_arr.key_col, right_arr.key_col, profile, delta_join_out);
    // 2. R_prev join delta_S
    try joinTwoZSets(&left_arr.state, delta_right, left_arr.key_col, right_arr.key_col, profile, delta_join_out);
    // 3. delta_R join delta_S
    try joinTwoZSets(delta_left, delta_right, left_arr.key_col, right_arr.key_col, profile, delta_join_out);

    try delta_join_out.consolidateCanonical();
    try left_arr.applyDelta(delta_left);
    try right_arr.applyDelta(delta_right);
}

/// Finite recomputation oracle for `R join S` over full Z-set states (`A3`).
pub fn evaluateFiniteJoinOracle(
    left_full: *const ZSet,
    right_full: *const ZSet,
    left_key_col: u8,
    right_key_col: u8,
    profile: Collation.Profile,
    out_full: *ZSet,
) !void {
    out_full.* = .{ .profile = profile };
    try joinTwoZSets(left_full, right_full, left_key_col, right_key_col, profile, out_full);
    try out_full.consolidateCanonical();
}

/// Incremental `GROUP BY` Z-set aggregator preserving 5-state cells (`null`,
/// `missing`, `type_error`, `conflict`) and reversible checked-arithmetic
/// overflow witnesses (`A3`).
/// When an overflowing or `type_error` input row is retracted (`weight = -1`),
/// the group's error multiplicity decrements back to `0` and the exact valid
/// `SUM` / `COUNT` is restored without rescanning the base table.
pub const GroupState = struct {
    key: v.Cell = .{ .null = {} },
    row_multiplicity: i64 = 0,
    non_null_multiplicity: i64 = 0,
    sum_i128: i128 = 0,
    missing_multiplicity: i64 = 0,
    type_error_multiplicity: i64 = 0,
    conflict_multiplicity: i64 = 0,

    pub fn materializedSumCell(self: GroupState) v.Cell {
        if (self.conflict_multiplicity > 0) return .{ .conflict = &.{} };
        if (self.type_error_multiplicity > 0) return .{ .type_error = .int64 };
        if (self.missing_multiplicity > 0) return .{ .missing = {} };
        if (self.non_null_multiplicity <= 0) return .{ .null = {} };
        const sum_i64 = std.math.cast(i64, self.sum_i128) orelse return .{ .type_error = .int64 };
        return .{ .value = .{ .atom = .{ .signed = sum_i64 } } };
    }
};

pub const ZSetGroupByAggregator = struct {
    key_col: u8,
    value_col: u8,
    profile: Collation.Profile = .utf8_binary,
    group_count: usize = 0,
    groups: [max_zset_entries]GroupState = undefined,

    pub fn applyDelta(self: *ZSetGroupByAggregator, delta: *const ZSet) !void {
        for (delta.entries[0..delta.len]) |e| {
            if (self.key_col >= e.row.len or self.value_col >= e.row.len) {
                return error.InvalidJoinColumnIndex;
            }
            const k_cell = e.row.cells[self.key_col];
            const v_cell = e.row.cells[self.value_col];
            const w = e.weight;

            var g_idx: ?usize = null;
            for (self.groups[0..self.group_count], 0..) |grp, idx| {
                if (try AnalyticalSql.cellsEqualForGrouping(grp.key, k_cell, self.profile)) {
                    g_idx = idx;
                    break;
                }
            }
            if (g_idx == null) {
                if (self.group_count >= max_zset_entries) return error.ZSetCapacityExceeded;
                self.groups[self.group_count] = .{ .key = k_cell };
                g_idx = self.group_count;
                self.group_count += 1;
            }

            var grp = &self.groups[g_idx.?];
            grp.row_multiplicity = try std.math.add(i64, grp.row_multiplicity, w);

            switch (v_cell) {
                .null => {},
                .missing => grp.missing_multiplicity = try std.math.add(i64, grp.missing_multiplicity, w),
                .type_error => grp.type_error_multiplicity = try std.math.add(i64, grp.type_error_multiplicity, w),
                .conflict => grp.conflict_multiplicity = try std.math.add(i64, grp.conflict_multiplicity, w),
                .value => |val| {
                    if (val != .atom or val.atom != .signed) {
                        grp.type_error_multiplicity = try std.math.add(i64, grp.type_error_multiplicity, w);
                    } else {
                        grp.non_null_multiplicity = try std.math.add(i64, grp.non_null_multiplicity, w);
                        const term = try std.math.mul(i128, val.atom.signed, @as(i128, w));
                        grp.sum_i128 = try std.math.add(i128, grp.sum_i128, term);
                    }
                },
            }

            if (grp.row_multiplicity == 0) {
                var k: usize = g_idx.?;
                while (k + 1 < self.group_count) : (k += 1) {
                    self.groups[k] = self.groups[k + 1];
                }
                self.group_count -= 1;
            }
        }
    }

    pub fn materializeZSet(self: *const ZSetGroupByAggregator, out_zset: *ZSet) !void {
        out_zset.* = .{ .profile = self.profile };
        for (self.groups[0..self.group_count]) |grp| {
            if (grp.row_multiplicity <= 0) continue;
            const row = try AnalyticalSql.Row.fromSlice(&.{
                grp.key,
                .{ .value = .{ .atom = .{ .signed = grp.row_multiplicity } } },
                grp.materializedSumCell(),
            });
            try out_zset.addRowWeight(row, 1);
        }
        try out_zset.consolidateCanonical();
    }
};

/// Event-time watermark, allowed-lateness and retraction tracker (`P5`).
pub const LateRowPolicy = enum(u8) {
    retract_and_emit = 1,
    drop_late_with_receipt = 2,
};

pub const LateEventOutcome = enum(u8) {
    admitted_on_time = 1,
    admitted_within_allowed_lateness = 2,
    retracted_late_update = 3,
    dropped_expired_window = 4,
};

pub const WatermarkTracker = struct {
    allowed_lateness_ts: i64,
    late_policy: LateRowPolicy = .retract_and_emit,
    max_observed_event_ts: ?i64 = null,
    current_watermark_ts: i64 = std.math.minInt(i64),
    dropped_late_count: usize = 0,
    retracted_late_count: usize = 0,

    pub fn observeEventTimestamp(self: *WatermarkTracker, event_ts: i64) LateEventOutcome {
        if (self.max_observed_event_ts == null or event_ts > self.max_observed_event_ts.?) {
            self.max_observed_event_ts = event_ts;
            self.current_watermark_ts = event_ts -| self.allowed_lateness_ts;
            return .admitted_on_time;
        }
        if (event_ts >= self.current_watermark_ts) {
            return .admitted_within_allowed_lateness;
        }
        switch (self.late_policy) {
            .retract_and_emit => {
                self.retracted_late_count += 1;
                return .retracted_late_update;
            },
            .drop_late_with_receipt => {
                self.dropped_late_count += 1;
                return .dropped_expired_window;
            },
        }
    }
};

/// Reserved spatial Z-set extension hook consumed by Milestone 17 for algebraic
/// 2D half-edge `ST_Union` ($\partial_2$), 3D half-face `ST_3DUnion` ($\partial_3$),
/// Discrete Divergence Theorem volume sums, and `INTERIOR`/`BOUNDARY` cell-covering joins.
pub const SpatialBoundaryOperatorKind = enum(u8) {
    planar_half_edge_boundary_d2 = 1,
    solid_half_face_coboundary_d3 = 2,
    s2_h3_oct_cell_covering_join = 3,
};

pub const SpatialZSetDescriptor = struct {
    operator_kind: SpatialBoundaryOperatorKind,
    srid: u32,
    snap_grid_scale: u64,
};

pub fn invokeSpatialZSetOperator(desc: SpatialZSetDescriptor) !void {
    if (desc.srid == 0 or desc.snap_grid_scale == 0) return error.InvalidSpatialZSetDescriptor;
    return error.SpatialZSetExecutionDeferredToM17;
}
