//! Security-barrier Row-Level Security (RLS, including 2D/3D Geospatial RLS),
//! Column-Level Security (CLS), and vectorized Dynamic Data Masking
//! (`RLS_MASKING_V1` / `RLM1`, magic `0x524C4D31`, `Step 6`, `D6`, `P5`).
//!
//! Enforces two formal security-barrier guarantees (`A6: PolicyLattice.lean`):
//! 1. **RLS non-interference:** `SecurityBarrierFilter` evaluates $P_{\text{read}}(r)$
//!    on source batches (`FiveStateRule.filters_to_true_only`) **before** any
//!    untrusted user `WHERE` predicate, UDF, join, aggregate, or 5-state
//!    `type_error` / division-by-zero check executes, and suppresses zone-map /
//!    index statistics on excluded rows.
//! 2. **Pre-filter column masking:** `MaskingPolicyDescriptor` transforms restricted
//!    columns (`full_redact`, `partial_string_mask` scrubbing 4-byte `GermanString`
//!    sort prefixes, `keyed_hash_hmac`, `numeric_bucket`, and `spatial_coarsen_s2`)
//!    on surviving rows **before** user projections, `WHERE` filters, or `ORDER BY`
//!    comparators inspect them.
const std = @import("std");
const Types = @import("Types.zig");
const v = Types.Values;
const GermanString = @import("GermanString.zig");
const Collation = @import("Collation.zig");

pub const magic_rlm1: u32 = 0x524C4D31; // "RLM1"
pub const contract_id = "transit.fuze.rls-masking.v1";

pub const RlsPolicyMode = enum(u8) {
    permissive = 1, // Combined via OR across permissive policies
    restrictive = 2, // Combined via AND across restrictive policies
};

pub const RlsCommandScope = enum(u8) {
    all = 1,
    select = 2,
    insert = 3,
    update = 4,
    delete = 5,
};

pub const RlsPredicate = union(enum) {
    column_equals_utf8: struct {
        column_idx: usize,
        expected: []const u8,
    },
    column_equals_int64: struct {
        column_idx: usize,
        expected: i64,
    },
    /// 2D Geospatial RLS (`ST_CoveredBy(point, bbox2d)`).
    spatial_covered_by_bbox2d: struct {
        x_col_idx: usize,
        y_col_idx: usize,
        min_x: f64,
        min_y: f64,
        max_x: f64,
        max_y: f64,
    },
    /// 3D Volumetric Geospatial RLS (`ST_3DCoveredBy(point3d, bbox3d)`).
    spatial_covered_by_bbox3d: struct {
        x_col_idx: usize,
        y_col_idx: usize,
        z_col_idx: usize,
        min_x: f64,
        min_y: f64,
        min_z: f64,
        max_x: f64,
        max_y: f64,
        max_z: f64,
    },
    /// Hierarchical `S2_CELL` / `H3_CELL` / `OCT_CELL` prefix containment (`(cell & mask) == prefix`).
    s2_cell_prefix_match: struct {
        s2_col_idx: usize,
        authorized_prefix: u64,
        prefix_mask: u64,
    },

    /// Evaluates the predicate under `FiveStateRule.filters_to_true_only`:
    /// any `null`, `missing`, `type_error`, or `conflict` cell evaluates to `false`
    /// without propagating an error side channel.
    pub fn evaluateRow(self: RlsPredicate, cells: []const v.Cell) bool {
        switch (self) {
            .column_equals_utf8 => |p| {
                if (p.column_idx >= cells.len) return false;
                const bytes = extractBytes(cells[p.column_idx]) orelse return false;
                return std.mem.eql(u8, bytes, p.expected);
            },
            .column_equals_int64 => |p| {
                if (p.column_idx >= cells.len) return false;
                const val = extractSigned(cells[p.column_idx]) orelse return false;
                return val == p.expected;
            },
            .spatial_covered_by_bbox2d => |p| {
                if (p.x_col_idx >= cells.len or p.y_col_idx >= cells.len) return false;
                const x = extractFloat(cells[p.x_col_idx]) orelse return false;
                const y = extractFloat(cells[p.y_col_idx]) orelse return false;
                return x >= p.min_x and x <= p.max_x and y >= p.min_y and y <= p.max_y;
            },
            .spatial_covered_by_bbox3d => |p| {
                if (p.x_col_idx >= cells.len or p.y_col_idx >= cells.len or p.z_col_idx >= cells.len) return false;
                const x = extractFloat(cells[p.x_col_idx]) orelse return false;
                const y = extractFloat(cells[p.y_col_idx]) orelse return false;
                const z = extractFloat(cells[p.z_col_idx]) orelse return false;
                return x >= p.min_x and x <= p.max_x and
                    y >= p.min_y and y <= p.max_y and
                    z >= p.min_z and z <= p.max_z;
            },
            .s2_cell_prefix_match => |p| {
                if (p.s2_col_idx >= cells.len) return false;
                const cell_id = extractUnsigned(cells[p.s2_col_idx]) orelse return false;
                return (cell_id & p.prefix_mask) == (p.authorized_prefix & p.prefix_mask);
            },
        }
    }
};

pub const RlsPolicyDescriptor = struct {
    magic: u32 = magic_rlm1,
    policy_id: u64,
    name: []const u8,
    table_object: u64,
    mode: RlsPolicyMode = .permissive,
    command_scope: RlsCommandScope = .all,
    using_predicate: RlsPredicate,
    with_check_predicate: ?RlsPredicate = null,
    policy_epoch: u64 = 1,
};

pub const ZoneMapSummary = struct {
    row_count: u64,
    min_int64: i64,
    max_int64: i64,
    bbox2d_min_x: f64,
    bbox2d_max_x: f64,
    redacted_by_rls_barrier: bool = false,
};

/// Mandatory Security-Barrier RLS evaluator (`Step 6`, `D6`, `P5`).
pub const SecurityBarrierFilter = struct {
    table_rls_enabled: bool = true,
    policies: []const RlsPolicyDescriptor,

    /// Evaluates $P_{\text{read}}(r) = (\bigvee_{p \in \text{Permissive}} p(r)) \wedge (\bigwedge_{q \in \text{Restrictive}} q(r))$.
    /// When `table_rls_enabled == true` and zero permissive policies match, defaults to deny (`false`).
    pub fn evaluateReadRow(self: SecurityBarrierFilter, cells: []const v.Cell) bool {
        if (!self.table_rls_enabled) return true;

        var has_permissive = false;
        var permissive_pass = false;
        for (self.policies) |pol| {
            if (pol.command_scope != .all and pol.command_scope != .select) continue;
            switch (pol.mode) {
                .permissive => {
                    has_permissive = true;
                    if (pol.using_predicate.evaluateRow(cells)) {
                        permissive_pass = true;
                    }
                },
                .restrictive => {
                    if (!pol.using_predicate.evaluateRow(cells)) {
                        return false;
                    }
                },
            }
        }
        return has_permissive and permissive_pass;
    }

    /// Evaluates `WITH CHECK` policies on `INSERT` / `UPDATE` / `MERGE` candidate rows.
    pub fn validateMutationRow(self: SecurityBarrierFilter, cells: []const v.Cell) !void {
        if (!self.table_rls_enabled) return;
        var has_permissive = false;
        var permissive_pass = false;
        for (self.policies) |pol| {
            const pred = pol.with_check_predicate orelse pol.using_predicate;
            switch (pol.mode) {
                .permissive => {
                    has_permissive = true;
                    if (pred.evaluateRow(cells)) permissive_pass = true;
                },
                .restrictive => {
                    if (!pred.evaluateRow(cells)) return error.RlsWithCheckViolation;
                },
            }
        }
        if (!has_permissive or !permissive_pass) return error.RlsWithCheckViolation;
    }

    /// Evaluates an untrusted user expression (`100 / divisor`) ONLY on rows that
    /// first pass `SecurityBarrierFilter.evaluateReadRow`, proving that `divisor = 0`
    /// or `Cell.type_error` on unauthorized rows never leaks an error or side channel.
    pub fn evaluateCheckedDivisionAfterBarrier(
        self: SecurityBarrierFilter,
        rows: []const []const v.Cell,
        numerator: i64,
        divisor_col_idx: usize,
        out_quotients: []i64,
    ) !usize {
        var out_len: usize = 0;
        for (rows) |row| {
            if (!self.evaluateReadRow(row)) continue; // Barrier drops unauthorized row BEFORE division!
            if (divisor_col_idx >= row.len) return error.ColumnIndexOutOfBounds;
            const divisor = extractSigned(row[divisor_col_idx]) orelse switch (row[divisor_col_idx]) {
                .null, .missing, .conflict => continue,
                else => return error.TypeErrorInAuthorizedRow,
            };
            if (divisor == 0) return error.DivisionByZeroInAuthorizedRow;
            if (out_len < out_quotients.len) {
                out_quotients[out_len] = @divTrunc(numerator, divisor);
                out_len += 1;
            }
        }
        return out_len;
    }

    /// Suppresses raw segment-level zone-map statistics (`min`/`max`/`bbox2d`/`row_count`)
    /// when RLS is active so callers cannot infer extreme values of unauthorized rows.
    pub fn sanitizeZoneMapForCaller(self: SecurityBarrierFilter, raw: ZoneMapSummary) ZoneMapSummary {
        if (!self.table_rls_enabled) return raw;
        return .{
            .row_count = 0,
            .min_int64 = 0,
            .max_int64 = 0,
            .bbox2d_min_x = 0.0,
            .bbox2d_max_x = 0.0,
            .redacted_by_rls_barrier = true,
        };
    }
};

/// Column-Level Security (CLS) & Dynamic Data Masking (`Step 6`, `D6`, `P5`).
pub const MaskingTransform = union(enum) {
    unmasked: void,
    full_redact: void,
    /// Masks prefix (`"***-**-"`) and scrubs the 4-byte `GermanString` inline sort prefix.
    partial_string_mask: struct {
        visible_suffix_len: usize = 4,
    },
    /// Deterministic keyed SHA-256 pseudonymization (`u64` digest projection).
    keyed_hash_hmac: struct {
        key_id: u64,
    },
    /// Quantizes numeric values to a coarse bucket multiple (e.g., `10_000`).
    numeric_bucket: struct {
        bucket_width: i64,
    },
    /// Coarsens an `S2_CELL` / `H3_CELL` / `OCT_CELL` identifier by masking low resolution bits.
    spatial_coarsen_s2: struct {
        keep_high_mask: u64,
    },
};

pub const MaskingPolicyDescriptor = struct {
    policy_id: u64,
    name: []const u8,
    column_idx: usize,
    transform_for_restricted: MaskingTransform,
    unmasked_roles: []const u64 = &.{},

    pub fn isUnmaskedForRole(self: MaskingPolicyDescriptor, active_role: u64) bool {
        return std.mem.indexOfScalar(u64, self.unmasked_roles, active_role) != null;
    }

    /// Applies the masking transformation to a single `v.Cell` and returns a scrubbed
    /// 4-byte `GermanString` inline prefix (`[4]u8`) when masking strings.
    pub fn applyToCell(
        self: MaskingPolicyDescriptor,
        active_role: u64,
        input: v.Cell,
        scratch_buf: *[16]u8,
    ) struct { cell: v.Cell, german_prefix: [4]u8 } {
        if (self.isUnmaskedForRole(active_role)) {
            return .{
                .cell = input,
                .german_prefix = extractPrefix(input),
            };
        }
        switch (self.transform_for_restricted) {
            .unmasked => return .{ .cell = input, .german_prefix = extractPrefix(input) },
            .full_redact => return .{ .cell = .missing, .german_prefix = @splat(0) },
            .partial_string_mask => |pm| {
                const raw = extractBytes(input) orelse return .{ .cell = .missing, .german_prefix = @splat(0) };
                const prefix = "***-**-";
                @memset(scratch_buf, 0);
                @memcpy(scratch_buf[0..prefix.len], prefix);
                const suffix_len = @min(pm.visible_suffix_len, raw.len);
                const start = raw.len - suffix_len;
                @memcpy(scratch_buf[prefix.len .. prefix.len + suffix_len], raw[start..]);
                const masked_slice = scratch_buf[0 .. prefix.len + suffix_len];
                return .{
                    .cell = .{ .value = .{ .atom = .{ .bytes = masked_slice } } },
                    // Scrubbed 4-byte GermanString sort prefix is "***-", NEVER the unmasked raw prefix!
                    .german_prefix = .{ '*', '*', '*', '-' },
                };
            },
            .keyed_hash_hmac => |kh| {
                const raw = extractBytes(input) orelse return .{ .cell = .missing, .german_prefix = @splat(0) };
                var hasher = std.crypto.hash.sha2.Sha256.init(.{});
                hasher.update("transit.fuze.masking-hmac.v1\x00");
                var kbuf: [8]u8 = undefined;
                std.mem.writeInt(u64, &kbuf, kh.key_id, .little);
                hasher.update(&kbuf);
                hasher.update(raw);
                const digest = hasher.finalResult();
                const hashed_u64 = std.mem.readInt(u64, digest[0..8], .little);
                return .{
                    .cell = .{ .value = .{ .atom = .{ .unsigned = hashed_u64 } } },
                    .german_prefix = @splat(0),
                };
            },
            .numeric_bucket => |nb| {
                if (nb.bucket_width <= 0) return .{ .cell = .missing, .german_prefix = @splat(0) };
                const val = extractSigned(input) orelse return .{ .cell = .missing, .german_prefix = @splat(0) };
                const bucketed = @divFloor(val, nb.bucket_width) * nb.bucket_width;
                return .{
                    .cell = .{ .value = .{ .atom = .{ .signed = bucketed } } },
                    .german_prefix = @splat(0),
                };
            },
            .spatial_coarsen_s2 => |sc| {
                const cell_id = extractUnsigned(input) orelse return .{ .cell = .missing, .german_prefix = @splat(0) };
                return .{
                    .cell = .{ .value = .{ .atom = .{ .unsigned = cell_id & sc.keep_high_mask } } },
                    .german_prefix = @splat(0),
                };
            },
        }
    }
};

/// Computes the audience-specific RLS + CLS policy digest for `ReadCache` and Flight tickets (`Step 6`).
pub fn audiencePolicyDigest(
    table_object: u64,
    active_role: u64,
    policy_epoch: u64,
    rls_policies: []const RlsPolicyDescriptor,
    masking_policies: []const MaskingPolicyDescriptor,
) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(contract_id);
    hasher.update("\x00");
    var buf: [24]u8 = undefined;
    std.mem.writeInt(u64, buf[0..8], table_object, .little);
    std.mem.writeInt(u64, buf[8..16], active_role, .little);
    std.mem.writeInt(u64, buf[16..24], policy_epoch, .little);
    hasher.update(&buf);
    for (rls_policies) |rp| {
        var pbuf: [8]u8 = undefined;
        std.mem.writeInt(u64, &pbuf, rp.policy_id, .little);
        hasher.update(&pbuf);
    }
    for (masking_policies) |mp| {
        const unmasked: u8 = if (mp.isUnmaskedForRole(active_role)) 1 else 0;
        hasher.update(&.{unmasked});
    }
    return hasher.finalResult();
}

fn extractBytes(cell: v.Cell) ?[]const u8 {
    return switch (cell) {
        .value => |val| switch (val) {
            .atom => |a| switch (a) {
                .bytes => |b| b,
                else => null,
            },
            else => null,
        },
        else => null,
    };
}

fn extractSigned(cell: v.Cell) ?i64 {
    return switch (cell) {
        .value => |val| switch (val) {
            .atom => |a| switch (a) {
                .signed => |s| std.math.cast(i64, s),
                else => null,
            },
            else => null,
        },
        else => null,
    };
}

fn extractUnsigned(cell: v.Cell) ?u64 {
    return switch (cell) {
        .value => |val| switch (val) {
            .atom => |a| switch (a) {
                .unsigned => |u| std.math.cast(u64, u),
                else => null,
            },
            else => null,
        },
        else => null,
    };
}

fn extractFloat(cell: v.Cell) ?f64 {
    return switch (cell) {
        .value => |val| switch (val) {
            .atom => |a| switch (a) {
                .float => |f| f,
                .signed => |s| @floatFromInt(s),
                else => null,
            },
            else => null,
        },
        else => null,
    };
}

fn extractPrefix(cell: v.Cell) [4]u8 {
    var out: [4]u8 = @splat(0);
    if (extractBytes(cell)) |b| {
        const len = @min(b.len, 4);
        @memcpy(out[0..len], b[0..len]);
    }
    return out;
}
