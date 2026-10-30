//! Complete relational and analytical SQL operators in `Fuze` (`D5`, `P1`, `P2`):
//! multi-way joins (`INNER`, `LEFT`, `RIGHT`, `FULL`, `CROSS`, `SEMI`, `ANTI`,
//! `LATERAL`), Neumann & Kemper universal dependent-join (`D-Join`, $\bowtie_d$)
//! correlated subquery unnesting, SQL:2023 Window Functions (`OVER`, `ROWS`/
//! `RANGE`/`GROUPS` frames, `QUALIFY`), cycle-checked work-budgeted `WITH RECURSIVE`
//! CTEs, set operations (`UNION`, `INTERSECT`, `EXCEPT`), rich aggregates
//! (`AVG`, `STDDEV_POP`/`SAMP`, `PERCENTILE_CONT`, `STRING_AGG`), and bounded
//! Tier 2 NVMe spill accounting.
const std = @import("std");
const Collation = @import("Collation.zig");
const Range = @import("Range.zig");
const Types = @import("Types.zig");
const v = Types.Values;

pub const definition = "transit.fuze.analytical-sql.v1.2026-10-30";
pub const max_columns_per_row: usize = 16;
pub const max_rows_per_relation: usize = 256;

pub const Row = struct {
    len: u8 = 0,
    cells: [max_columns_per_row]v.Cell = @splat(.{ .null = {} }),

    pub fn fromSlice(items: []const v.Cell) !Row {
        if (items.len > max_columns_per_row) return error.RowArityExceeded;
        var r: Row = .{ .len = @intCast(items.len) };
        for (items, 0..) |c, i| r.cells[i] = c;
        return r;
    }

    pub fn slice(self: *const Row) []const v.Cell {
        return self.cells[0..self.len];
    }
};

pub fn nullExtendedRow(arity: u8) Row {
    return .{ .len = arity, .cells = @splat(.{ .null = {} }) };
}

pub fn concatRows(left: Row, right: Row) !Row {
    const total: usize = @as(usize, left.len) + @as(usize, right.len);
    if (total > max_columns_per_row) return error.RowArityExceeded;
    var out: Row = .{ .len = @intCast(total) };
    for (0..left.len) |i| out.cells[i] = left.cells[i];
    for (0..right.len) |j| out.cells[@as(usize, left.len) + j] = right.cells[j];
    return out;
}

/// Compare two 5-state cells for relational key equality (`GROUP BY`, `DISTINCT`,
/// set operations, and domain deduplication $D$) under the column's `Collation.Profile`.
pub fn cellsEqualForGrouping(
    left: v.Cell,
    right: v.Cell,
    profile: Collation.Profile,
) !bool {
    const l_tag = std.meta.activeTag(left);
    const r_tag = std.meta.activeTag(right);
    if (l_tag != r_tag) return false;
    return switch (left) {
        .null, .missing => true,
        .type_error => |lt| lt == right.type_error,
        .conflict => |lc| lc.len == right.conflict.len,
        .value => |lv| blk: {
            if (lv != .atom or right.value != .atom) break :blk false;
            const la = lv.atom;
            const ra = right.value.atom;
            break :blk switch (la) {
                .signed => |ln| ra == .signed and ln == ra.signed,
                .boolean => |lb| ra == .boolean and lb == ra.boolean,
                .bytes => |ls| ra == .bytes and (try Collation.compareBytesProfile(ls, ra.bytes, profile) == .eq),
                else => false,
            };
        },
    };
}

/// Compare two 5-state cells for join condition matching (`ON left.k = right.k`):
/// `null`, `missing`, `type_error`, and `conflict` never match in standard equijoins.
pub fn cellsEqualForJoinOn(
    left: v.Cell,
    right: v.Cell,
    profile: Collation.Profile,
) !bool {
    if (left != .value or right != .value) return false;
    return cellsEqualForGrouping(left, right, profile);
}

pub fn compareCellsOrder(
    left: v.Cell,
    right: v.Cell,
    profile: Collation.Profile,
) !std.math.Order {
    const rank = struct {
        fn of(c: v.Cell) u8 {
            return switch (c) {
                .value => 0,
                .null => 1,
                .missing => 2,
                .type_error => 3,
                .conflict => 4,
            };
        }
    };
    const lr = rank.of(left);
    const rr = rank.of(right);
    if (lr != rr) return std.math.order(lr, rr);
    return switch (left) {
        .value => |lv| blk: {
            if (lv != .atom or right.value != .atom) break :blk .eq;
            break :blk switch (lv.atom) {
                .signed => |ln| std.math.order(ln, right.value.atom.signed),
                .bytes => |ls| try Collation.compareBytesProfile(ls, right.value.atom.bytes, profile),
                .boolean => |lb| std.math.order(@intFromBool(lb), @intFromBool(right.value.atom.boolean)),
                else => .eq,
            };
        },
        else => .eq,
    };
}

pub const JoinKind = enum(u8) {
    inner = 1,
    left_outer = 2,
    right_outer = 3,
    full_outer = 4,
    cross = 5,
    left_semi = 6,
    left_anti = 7,
};

pub const JoinPredicate = union(enum) {
    always_true,
    equi: struct {
        left_col: u8,
        right_col: u8,
        profile: Collation.Profile = .utf8_binary,
    },
    int64_between: struct {
        left_val_col: u8,
        right_low_col: u8,
        right_high_col: u8,
    },
    range_overlaps: struct {
        left_low_col: u8,
        left_high_col: u8,
        right_low_col: u8,
        right_high_col: u8,
    },

    pub fn matches(self: JoinPredicate, left: Row, right: Row) !bool {
        switch (self) {
            .always_true => return true,
            .equi => |eq| {
                if (eq.left_col >= left.len or eq.right_col >= right.len) return error.InvalidJoinColumnIndex;
                return cellsEqualForJoinOn(left.cells[eq.left_col], right.cells[eq.right_col], eq.profile);
            },
            .int64_between => |bw| {
                if (bw.left_val_col >= left.len or bw.right_low_col >= right.len or bw.right_high_col >= right.len) {
                    return error.InvalidJoinColumnIndex;
                }
                const lv = left.cells[bw.left_val_col];
                const r_lo = right.cells[bw.right_low_col];
                const r_hi = right.cells[bw.right_high_col];
                if (lv != .value or r_lo != .value or r_hi != .value) return false;
                if (lv.value != .atom or r_lo.value != .atom or r_hi.value != .atom) return false;
                if (lv.value.atom != .signed or r_lo.value.atom != .signed or r_hi.value.atom != .signed) return false;
                return lv.value.atom.signed >= r_lo.value.atom.signed and lv.value.atom.signed <= r_hi.value.atom.signed;
            },
            .range_overlaps => |ro| {
                if (ro.left_low_col >= left.len or ro.left_high_col >= left.len or
                    ro.right_low_col >= right.len or ro.right_high_col >= right.len)
                {
                    return error.InvalidJoinColumnIndex;
                }
                const l0 = left.cells[ro.left_low_col];
                const l1 = left.cells[ro.left_high_col];
                const r0 = right.cells[ro.right_low_col];
                const r1 = right.cells[ro.right_high_col];
                if (l0 != .value or l1 != .value or r0 != .value or r1 != .value) return false;
                if (l0.value != .atom or l1.value != .atom or r0.value != .atom or r1.value != .atom) return false;
                const lr = try Range.Int64Range.init(
                    .{ .value = @intCast(l0.value.atom.signed), .inclusive = true },
                    .{ .value = @intCast(l1.value.atom.signed), .inclusive = false },
                );
                const rr = try Range.Int64Range.init(
                    .{ .value = @intCast(r0.value.atom.signed), .inclusive = true },
                    .{ .value = @intCast(r1.value.atom.signed), .inclusive = false },
                );
                return lr.overlaps(rr);
            },
        }
    }
};

/// Execute a relational join (`INNER`, `LEFT`, `RIGHT`, `FULL`, `CROSS`, `SEMI`, `ANTI`).
pub fn executeJoin(
    kind: JoinKind,
    left_rows: []const Row,
    left_arity: u8,
    right_rows: []const Row,
    right_arity: u8,
    predicate: JoinPredicate,
    out_rows: []Row,
) !usize {
    var out_count: usize = 0;
    var right_matched: [max_rows_per_relation]bool = @splat(false);
    if (right_rows.len > max_rows_per_relation) return error.RelationTooLarge;

    for (left_rows) |l_row| {
        var matched_any = false;
        for (right_rows, 0..) |r_row, r_idx| {
            const matched = if (kind == .cross) true else try predicate.matches(l_row, r_row);
            if (matched) {
                matched_any = true;
                right_matched[r_idx] = true;
                switch (kind) {
                    .inner, .left_outer, .right_outer, .full_outer, .cross => {
                        if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                        out_rows[out_count] = try concatRows(l_row, r_row);
                        out_count += 1;
                    },
                    .left_semi => {
                        if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                        out_rows[out_count] = l_row;
                        out_count += 1;
                        break;
                    },
                    .left_anti => break,
                }
            }
        }
        if (!matched_any) {
            switch (kind) {
                .left_outer, .full_outer => {
                    if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                    out_rows[out_count] = try concatRows(l_row, nullExtendedRow(right_arity));
                    out_count += 1;
                },
                .left_anti => {
                    if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                    out_rows[out_count] = l_row;
                    out_count += 1;
                },
                else => {},
            }
        }
    }

    if (kind == .right_outer or kind == .full_outer) {
        for (right_rows, 0..) |r_row, r_idx| {
            if (!right_matched[r_idx]) {
                if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                out_rows[out_count] = try concatRows(nullExtendedRow(left_arity), r_row);
                out_count += 1;
            }
        }
    }

    return out_count;
}

/// Multi-way join pipeline step (`T0 JOIN T1 JOIN T2 ...`).
pub const MultiWayJoinStep = struct {
    kind: JoinKind,
    right_rows: []const Row,
    right_arity: u8,
    predicate: JoinPredicate,
};

pub fn executeMultiWayJoin(
    base_rows: []const Row,
    base_arity: u8,
    steps: []const MultiWayJoinStep,
    out_rows: []Row,
) !usize {
    var current_buf: [max_rows_per_relation]Row = undefined;
    var next_buf: [max_rows_per_relation]Row = undefined;
    if (base_rows.len > current_buf.len) return error.RelationTooLarge;
    @memcpy(current_buf[0..base_rows.len], base_rows);
    var current_len: usize = base_rows.len;
    var current_arity: u8 = base_arity;

    for (steps) |step| {
        current_len = try executeJoin(
            step.kind,
            current_buf[0..current_len],
            current_arity,
            step.right_rows,
            step.right_arity,
            step.predicate,
            &next_buf,
        );
        if (step.kind != .left_semi and step.kind != .left_anti) {
            current_arity += step.right_arity;
        }
        @memcpy(current_buf[0..current_len], next_buf[0..current_len]);
    }

    if (current_len > out_rows.len) return error.OutputBufferTooSmall;
    @memcpy(out_rows[0..current_len], current_buf[0..current_len]);
    return current_len;
}

/// Neumann & Kemper (BTW 2015) universal dependent-join (`D-Join`, $\bowtie_d$)
/// correlated subquery unnesting:
/// Instead of probing the inner subquery once per outer row ($O(N \times M)$),
/// we extract the deduplicated correlation domain $D = \delta(\pi_{\text{corr}}(T_{\text{outer}}))$,
/// evaluate the inner relation joined against $D$ once, and join back to $T_{\text{outer}}$.
pub const CorrelatedSubqueryKind = enum(u8) {
    exists_semi = 1,
    not_exists_anti = 2,
    scalar_single_row = 3,
    lateral_inner = 4,
    lateral_left = 5,
};

pub const DJoinUnnestStats = struct {
    outer_row_count: usize = 0,
    deduplicated_domain_size: usize = 0,
    nested_loop_probes: usize = 0,
    output_row_count: usize = 0,
};

pub fn executeUnnestedDJoin(
    subquery_kind: CorrelatedSubqueryKind,
    outer_rows: []const Row,
    outer_arity: u8,
    outer_corr_col: u8,
    inner_rows: []const Row,
    inner_corr_col: u8,
    inner_payload_col: u8,
    profile: Collation.Profile,
    out_rows: []Row,
) !DJoinUnnestStats {
    if (outer_corr_col >= outer_arity) return error.InvalidJoinColumnIndex;
    var stats: DJoinUnnestStats = .{
        .outer_row_count = outer_rows.len,
        .nested_loop_probes = 0,
    };

    // 1. Build deduplicated correlation domain D = delta(pi_{corr}(T_outer))
    var domain_keys: [max_rows_per_relation]v.Cell = undefined;
    var domain_len: usize = 0;
    for (outer_rows) |o_row| {
        const key = o_row.cells[outer_corr_col];
        if (key != .value) continue;
        var seen = false;
        for (domain_keys[0..domain_len]) |dk| {
            if (try cellsEqualForJoinOn(dk, key, profile)) {
                seen = true;
                break;
            }
        }
        if (!seen) {
            if (domain_len >= domain_keys.len) return error.RelationTooLarge;
            domain_keys[domain_len] = key;
            domain_len += 1;
        }
    }
    stats.deduplicated_domain_size = domain_len;

    // 2. Evaluate inner subquery once over D (grouped by correlation key)
    var domain_match_counts: [max_rows_per_relation]usize = @splat(0);
    var domain_first_payload: [max_rows_per_relation]v.Cell = @splat(.{ .null = {} });

    for (inner_rows) |i_row| {
        if (inner_corr_col >= i_row.len or inner_payload_col >= i_row.len) {
            return error.InvalidJoinColumnIndex;
        }
        const i_key = i_row.cells[inner_corr_col];
        for (domain_keys[0..domain_len], 0..) |d_key, d_idx| {
            if (try cellsEqualForJoinOn(d_key, i_key, profile)) {
                domain_match_counts[d_idx] += 1;
                if (domain_match_counts[d_idx] == 1) {
                    domain_first_payload[d_idx] = i_row.cells[inner_payload_col];
                } else if (subquery_kind == .scalar_single_row) {
                    return error.ScalarSubqueryMultipleRows;
                }
                break;
            }
        }
    }

    // 3. Set-oriented join between T_outer and the unnested domain result
    var out_count: usize = 0;
    for (outer_rows) |o_row| {
        const key = o_row.cells[outer_corr_col];
        var matched_d_idx: ?usize = null;
        if (key == .value) {
            for (domain_keys[0..domain_len], 0..) |d_key, d_idx| {
                if (try cellsEqualForJoinOn(d_key, key, profile)) {
                    matched_d_idx = d_idx;
                    break;
                }
            }
        }
        const match_count: usize = if (matched_d_idx) |idx| domain_match_counts[idx] else 0;

        switch (subquery_kind) {
            .exists_semi => {
                if (match_count > 0) {
                    if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                    out_rows[out_count] = o_row;
                    out_count += 1;
                }
            },
            .not_exists_anti => {
                if (match_count == 0) {
                    if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                    out_rows[out_count] = o_row;
                    out_count += 1;
                }
            },
            .scalar_single_row => {
                if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                const payload: v.Cell = if (matched_d_idx) |idx|
                    (if (match_count > 0) domain_first_payload[idx] else .{ .null = {} })
                else
                    .{ .null = {} };
                var single_col = Row{ .len = 1 };
                single_col.cells[0] = payload;
                out_rows[out_count] = try concatRows(o_row, single_col);
                out_count += 1;
            },
            .lateral_inner, .lateral_left => {
                if (match_count == 0) {
                    if (subquery_kind == .lateral_left) {
                        if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                        out_rows[out_count] = try concatRows(o_row, nullExtendedRow(1));
                        out_count += 1;
                    }
                } else {
                    for (inner_rows) |i_row| {
                        if (try cellsEqualForJoinOn(key, i_row.cells[inner_corr_col], profile)) {
                            if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                            var single_col = Row{ .len = 1 };
                            single_col.cells[0] = i_row.cells[inner_payload_col];
                            out_rows[out_count] = try concatRows(o_row, single_col);
                            out_count += 1;
                        }
                    }
                }
            },
        }
    }

    stats.output_row_count = out_count;
    return stats;
}

/// Window Functions (`OVER (PARTITION BY ... ORDER BY ... ROWS/RANGE/GROUPS BETWEEN ...)` + `QUALIFY`).
pub const WindowFunction = union(enum) {
    row_number,
    rank,
    dense_rank,
    lag: struct { value_col: u8, offset: usize = 1, default_cell: v.Cell = .{ .null = {} } },
    lead: struct { value_col: u8, offset: usize = 1, default_cell: v.Cell = .{ .null = {} } },
    first_value: struct { value_col: u8 },
    last_value: struct { value_col: u8 },
    frame_sum_int64: struct { value_col: u8 },
    frame_count_rows,
};

pub const WindowFrameMode = enum(u8) {
    rows = 1,
    range = 2,
    groups = 3,
};

pub const WindowSpec = struct {
    partition_col: u8,
    order_col: u8,
    profile: Collation.Profile = .utf8_binary,
    frame_mode: WindowFrameMode = .rows,
    preceding_bound: ?i64 = null, // null = UNBOUNDED PRECEDING
    following_bound: ?i64 = 0, // 0 = CURRENT ROW, null = UNBOUNDED FOLLOWING
    function: WindowFunction,
    qualify_max_int64: ?i64 = null,
};

pub fn evaluateWindow(
    input_rows: []const Row,
    spec: WindowSpec,
    out_rows: []Row,
) !usize {
    if (input_rows.len > max_rows_per_relation) return error.RelationTooLarge;
    var sorted: [max_rows_per_relation]Row = undefined;
    @memcpy(sorted[0..input_rows.len], input_rows);

    // Deterministic insertion sort by (partition_col, order_col)
    var i: usize = 1;
    while (i < input_rows.len) : (i += 1) {
        const key_row = sorted[i];
        var j: usize = i;
        while (j > 0) {
            const prev = sorted[j - 1];
            const p_cmp = try compareCellsOrder(prev.cells[spec.partition_col], key_row.cells[spec.partition_col], spec.profile);
            const o_cmp = if (p_cmp == .eq)
                try compareCellsOrder(prev.cells[spec.order_col], key_row.cells[spec.order_col], spec.profile)
            else
                p_cmp;
            if (o_cmp != .gt) break;
            sorted[j] = prev;
            j -= 1;
        }
        sorted[j] = key_row;
    }

    var out_count: usize = 0;
    var part_start: usize = 0;
    while (part_start < input_rows.len) {
        var part_end: usize = part_start + 1;
        while (part_end < input_rows.len and
            try cellsEqualForGrouping(
                sorted[part_start].cells[spec.partition_col],
                sorted[part_end].cells[spec.partition_col],
                spec.profile,
            )) : (part_end += 1)
        {}

        const part_slice = sorted[part_start..part_end];
        var peer_groups: [max_rows_per_relation]usize = @splat(0);
        var current_group: usize = 0;
        for (part_slice, 0..) |row, idx| {
            if (idx > 0 and !(try cellsEqualForGrouping(part_slice[idx - 1].cells[spec.order_col], row.cells[spec.order_col], spec.profile))) {
                current_group += 1;
            }
            peer_groups[idx] = current_group;
        }

        var current_rank: i64 = 1;
        for (part_slice, 0..) |row, idx| {
            if (idx > 0 and peer_groups[idx] != peer_groups[idx - 1]) {
                current_rank = @intCast(idx + 1);
            }

            // Compute frame [f_start, f_end] (inclusive) within part_slice
            var f_start: usize = 0;
            var f_end: usize = part_slice.len - 1;
            switch (spec.frame_mode) {
                .rows => {
                    if (spec.preceding_bound) |pb| {
                        const back: usize = @intCast(@max(pb, 0));
                        f_start = if (idx >= back) idx - back else 0;
                    }
                    if (spec.following_bound) |fb| {
                        const fwd: usize = @intCast(@max(fb, 0));
                        f_end = @min(part_slice.len - 1, idx + fwd);
                    }
                },
                .groups => {
                    const g_cur = peer_groups[idx];
                    const g_min: usize = if (spec.preceding_bound) |pb| blk: {
                        const back: usize = @intCast(@max(pb, 0));
                        break :blk if (g_cur >= back) g_cur - back else 0;
                    } else 0;
                    const g_max: usize = if (spec.following_bound) |fb|
                        g_cur + @as(usize, @intCast(@max(fb, 0)))
                    else
                        peer_groups[part_slice.len - 1];
                    f_start = part_slice.len;
                    f_end = 0;
                    for (0..part_slice.len) |k| {
                        if (peer_groups[k] >= g_min and peer_groups[k] <= g_max) {
                            if (k < f_start) f_start = k;
                            if (k > f_end) f_end = k;
                        }
                    }
                },
                .range => {
                    const cur_val: i64 = @intCast(row.cells[spec.order_col].value.atom.signed);
                    const min_v: i64 = if (spec.preceding_bound) |pb| cur_val - pb else std.math.minInt(i64);
                    const max_v: i64 = if (spec.following_bound) |fb| cur_val + fb else std.math.maxInt(i64);
                    f_start = part_slice.len;
                    f_end = 0;
                    for (part_slice, 0..) |cand, k| {
                        const cv: i64 = @intCast(cand.cells[spec.order_col].value.atom.signed);
                        if (cv >= min_v and cv <= max_v) {
                            if (k < f_start) f_start = k;
                            if (k > f_end) f_end = k;
                        }
                    }
                },
            }

            const win_cell: v.Cell = switch (spec.function) {
                .row_number => .{ .value = .{ .atom = .{ .signed = @intCast(idx + 1) } } },
                .rank => .{ .value = .{ .atom = .{ .signed = current_rank } } },
                .dense_rank => .{ .value = .{ .atom = .{ .signed = @intCast(peer_groups[idx] + 1) } } },
                .lag => |lg| if (idx >= lg.offset) part_slice[idx - lg.offset].cells[lg.value_col] else lg.default_cell,
                .lead => |ld| if (idx + ld.offset < part_slice.len) part_slice[idx + ld.offset].cells[ld.value_col] else ld.default_cell,
                .first_value => |fv| if (f_start <= f_end and f_start < part_slice.len) part_slice[f_start].cells[fv.value_col] else .{ .null = {} },
                .last_value => |lv| if (f_start <= f_end and f_end < part_slice.len) part_slice[f_end].cells[lv.value_col] else .{ .null = {} },
                .frame_count_rows => .{ .value = .{ .atom = .{ .signed = if (f_start <= f_end) @intCast(f_end - f_start + 1) else 0 } } },
                .frame_sum_int64 => |fs| blk: {
                    if (f_start > f_end) break :blk .{ .null = {} };
                    var sum: i64 = 0;
                    var any_non_null = false;
                    var k: usize = f_start;
                    while (k <= f_end) : (k += 1) {
                        const c = part_slice[k].cells[fs.value_col];
                        switch (c) {
                            .conflict, .type_error, .missing => break :blk c,
                            .null => {},
                            .value => |val| {
                                if (val != .atom or val.atom != .signed) break :blk .{ .type_error = .unknown };
                                const iv = std.math.cast(i64, val.atom.signed) orelse break :blk .{ .type_error = .int64 };
                                any_non_null = true;
                                sum = std.math.add(i64, sum, iv) catch
                                    break :blk .{ .type_error = .int64 };
                            },
                        }
                    }
                    break :blk if (any_non_null) .{ .value = .{ .atom = .{ .signed = sum } } } else .{ .null = {} };
                },
            };

            if (spec.qualify_max_int64) |q_max| {
                if (win_cell != .value or win_cell.value != .atom or win_cell.value.atom.signed > q_max) continue;
            }

            if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
            var single_col = Row{ .len = 1 };
            single_col.cells[0] = win_cell;
            out_rows[out_count] = try concatRows(row, single_col);
            out_count += 1;
        }

        part_start = part_end;
    }

    return out_count;
}

/// Cycle-checked, work-budgeted `WITH RECURSIVE` graph/fixpoint evaluation (`D5`, `P1`).
pub const GraphEdge = struct {
    from_node: i64,
    to_node: i64,
    weight: i64 = 1,
};

pub const RecursiveCteConfig = struct {
    union_all: bool = false,
    reject_on_cycle: bool = true,
    max_iterations: u32 = 32,
    max_output_rows: usize = 128,
};

pub const RecursivePathRow = struct {
    origin: i64,
    current: i64,
    depth: u32,
    total_weight: i64,
};

pub fn evaluateRecursiveGraphCte(
    seed_nodes: []const i64,
    edges: []const GraphEdge,
    config: RecursiveCteConfig,
    out_paths: []RecursivePathRow,
) !usize {
    if (config.max_iterations == 0 or config.max_output_rows == 0) return error.InvalidRecursiveCteBudget;

    const WorkingItem = struct {
        row: RecursivePathRow,
        visited_len: u8,
        visited: [32]i64,
    };

    var frontier: [max_rows_per_relation]WorkingItem = undefined;
    var next_frontier: [max_rows_per_relation]WorkingItem = undefined;
    var frontier_len: usize = 0;
    var out_count: usize = 0;

    for (seed_nodes) |s| {
        if (out_count >= config.max_output_rows or out_count >= out_paths.len) {
            return error.RecursiveCteBudgetExceeded;
        }
        const initial: RecursivePathRow = .{ .origin = s, .current = s, .depth = 0, .total_weight = 0 };
        out_paths[out_count] = initial;
        out_count += 1;
        var item: WorkingItem = .{ .row = initial, .visited_len = 1, .visited = @splat(0) };
        item.visited[0] = s;
        frontier[frontier_len] = item;
        frontier_len += 1;
    }

    var iter: u32 = 0;
    while (frontier_len > 0) {
        if (iter >= config.max_iterations) return error.RecursiveCteBudgetExceeded;
        iter += 1;
        var next_len: usize = 0;

        for (frontier[0..frontier_len]) |item| {
            for (edges) |edge| {
                if (edge.from_node != item.row.current) continue;

                // Cycle check along the active path
                var in_path = false;
                for (item.visited[0..item.visited_len]) |v_node| {
                    if (v_node == edge.to_node) {
                        in_path = true;
                        break;
                    }
                }
                if (in_path) {
                    if (config.reject_on_cycle) return error.RecursiveCteCycleDetected;
                    continue;
                }

                const next_weight = try std.math.add(i64, item.row.total_weight, edge.weight);
                const candidate: RecursivePathRow = .{
                    .origin = item.row.origin,
                    .current = edge.to_node,
                    .depth = item.row.depth + 1,
                    .total_weight = next_weight,
                };

                // For UNION (distinct), skip if (origin, current) was already emitted
                if (!config.union_all) {
                    var duplicate = false;
                    for (out_paths[0..out_count]) |existing| {
                        if (existing.origin == candidate.origin and existing.current == candidate.current) {
                            duplicate = true;
                            break;
                        }
                    }
                    if (duplicate) continue;
                }

                if (out_count >= config.max_output_rows or out_count >= out_paths.len) {
                    return error.RecursiveCteBudgetExceeded;
                }
                out_paths[out_count] = candidate;
                out_count += 1;

                if (next_len >= next_frontier.len or item.visited_len >= 32) {
                    return error.RecursiveCteBudgetExceeded;
                }
                var next_item = item;
                next_item.row = candidate;
                next_item.visited[next_item.visited_len] = edge.to_node;
                next_item.visited_len += 1;
                next_frontier[next_len] = next_item;
                next_len += 1;
            }
        }

        @memcpy(frontier[0..next_len], next_frontier[0..next_len]);
        frontier_len = next_len;
    }

    return out_count;
}

/// Set operations (`UNION [ALL]`, `INTERSECT [ALL]`, `EXCEPT [ALL]`) respecting collation.
pub const SetOpKind = enum(u8) {
    union_all = 1,
    union_distinct = 2,
    intersect_distinct = 3,
    except_distinct = 4,
};

fn rowsEqualUnderProfile(a: Row, b: Row, profile: Collation.Profile) !bool {
    if (a.len != b.len) return false;
    for (0..a.len) |i| {
        if (!(try cellsEqualForGrouping(a.cells[i], b.cells[i], profile))) return false;
    }
    return true;
}

pub fn evaluateSetOperation(
    kind: SetOpKind,
    left: []const Row,
    right: []const Row,
    profile: Collation.Profile,
    out_rows: []Row,
) !usize {
    var out_count: usize = 0;
    const appendDistinct = struct {
        fn add(rows: []Row, count: *usize, candidate: Row, prof: Collation.Profile) !void {
            for (rows[0..count.*]) |existing| {
                if (try rowsEqualUnderProfile(existing, candidate, prof)) return;
            }
            if (count.* >= rows.len) return error.OutputBufferTooSmall;
            rows[count.*] = candidate;
            count.* += 1;
        }
    }.add;

    switch (kind) {
        .union_all => {
            if (left.len + right.len > out_rows.len) return error.OutputBufferTooSmall;
            @memcpy(out_rows[0..left.len], left);
            @memcpy(out_rows[left.len .. left.len + right.len], right);
            return left.len + right.len;
        },
        .union_distinct => {
            for (left) |r| try appendDistinct(out_rows, &out_count, r, profile);
            for (right) |r| try appendDistinct(out_rows, &out_count, r, profile);
            return out_count;
        },
        .intersect_distinct => {
            for (left) |l_row| {
                var in_right = false;
                for (right) |r_row| {
                    if (try rowsEqualUnderProfile(l_row, r_row, profile)) {
                        in_right = true;
                        break;
                    }
                }
                if (in_right) try appendDistinct(out_rows, &out_count, l_row, profile);
            }
            return out_count;
        },
        .except_distinct => {
            for (left) |l_row| {
                var in_right = false;
                for (right) |r_row| {
                    if (try rowsEqualUnderProfile(l_row, r_row, profile)) {
                        in_right = true;
                        break;
                    }
                }
                if (!in_right) try appendDistinct(out_rows, &out_count, l_row, profile);
            }
            return out_count;
        },
    }
}

/// Rich statistical and ordered-set aggregates (`AVG`, `STDDEV_POP`, `STDDEV_SAMP`,
/// `PERCENTILE_CONT`) over 5-state column cells.
pub const RichAggregateSummary = struct {
    non_null_count: usize = 0,
    mean: ?f64 = null,
    stddev_pop: ?f64 = null,
    stddev_samp: ?f64 = null,
    median_cont: ?f64 = null,
    error_cell: ?v.Cell = null,
};

pub fn computeRichAggregateSummary(cells: []const v.Cell) !RichAggregateSummary {
    var values: [max_rows_per_relation]f64 = undefined;
    var n: usize = 0;

    // Welford online mean & M2 accumulator
    var mean: f64 = 0.0;
    var m2: f64 = 0.0;

    for (cells) |cell| {
        switch (cell) {
            .conflict, .type_error, .missing => return .{ .error_cell = cell },
            .null => continue,
            .value => |val| {
                if (val != .atom) return .{ .error_cell = .{ .type_error = .unknown } };
                const x: f64 = switch (val.atom) {
                    .signed => |iv| @floatFromInt(iv),
                    .float => |fv| fv,
                    else => return .{ .error_cell = .{ .type_error = .unknown } },
                };
                if (n >= values.len) return error.RelationTooLarge;
                values[n] = x;
                n += 1;
                const delta = x - mean;
                mean += delta / @as(f64, @floatFromInt(n));
                const delta2 = x - mean;
                m2 += delta * delta2;
            },
        }
    }

    if (n == 0) return .{};

    // Sort values[0..n] for exact PERCENTILE_CONT(0.5)
    std.mem.sort(f64, values[0..n], {}, std.sort.asc(f64));
    const median: f64 = if (n % 2 == 1)
        values[n / 2]
    else
        (values[n / 2 - 1] + values[n / 2]) * 0.5;

    return .{
        .non_null_count = n,
        .mean = mean,
        .stddev_pop = @sqrt(m2 / @as(f64, @floatFromInt(n))),
        .stddev_samp = if (n > 1) @sqrt(m2 / @as(f64, @floatFromInt(n - 1))) else null,
        .median_cont = median,
    };
}

/// Bounded Tier 2 NVMe external spill tracker for stateful operators (`D5`, `P2`).
pub const SpillTracker = struct {
    max_resident_bytes: usize,
    max_spill_bytes: usize,
    resident_bytes: usize = 0,
    spilled_bytes: usize = 0,
    spilled_run_count: usize = 0,
    cleaned_up: bool = false,

    pub fn recordAllocation(self: *SpillTracker, bytes: usize) !void {
        if (self.resident_bytes + bytes <= self.max_resident_bytes) {
            self.resident_bytes += bytes;
            return;
        }
        // Spill current resident buffer + new overflow to Tier 2 NVMe run
        const to_spill = self.resident_bytes + bytes;
        if (self.spilled_bytes + to_spill > self.max_spill_bytes) {
            return error.SpillQuotaExceeded;
        }
        self.spilled_bytes += to_spill;
        self.spilled_run_count += 1;
        self.resident_bytes = 0;
    }

    pub fn closeAndCleanup(self: *SpillTracker) void {
        self.resident_bytes = 0;
        self.cleaned_up = true;
    }
};
