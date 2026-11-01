//! Shared operator traits and read/mutate/capture/dispatch effect propagation.
//! Explanation (EXPLAIN) inspects plan traits and work bounds without acquiring
//! data pins, reading storage segments, or mutating state.
const std = @import("std");
const Collation = @import("Collation.zig").Collation;
const LogicalQuery = @import("LogicalQuery.zig");
const Relational = @import("Relational.zig");

pub const definition = "transit.fuze.operator-traits.v1.2026-11-01.scalars";

/// Orthogonal effect classification across data, capture, and external dispatch.
pub const EffectSet = packed struct(u8) {
    read: bool = false,
    mutate: bool = false,
    capture: bool = false,
    dispatch: bool = false,
    _reserved: u4 = 0,

    pub const none: EffectSet = .{};
    pub const read_only: EffectSet = .{ .read = true };
    pub const table_mutation: EffectSet = .{ .read = true, .mutate = true };
    pub const captured_read: EffectSet = .{ .read = true, .capture = true };
    pub const external_dispatch: EffectSet = .{ .read = true, .capture = true, .dispatch = true };

    pub fn merge(a: EffectSet, b: EffectSet) EffectSet {
        return .{
            .read = a.read or b.read,
            .mutate = a.mutate or b.mutate,
            .capture = a.capture or b.capture,
            .dispatch = a.dispatch or b.dispatch,
        };
    }

    pub fn isPureRead(self: EffectSet) bool {
        return !self.mutate and !self.capture and !self.dispatch;
    }
};

/// Five-state cell propagation contract (`value`, `null`, `missing`, `type_error`, `conflict`).
pub const FiveStateRule = enum(u8) {
    /// Output preserves all 5 cell states verbatim (e.g. projection).
    preserves_all_states = 1,
    /// Boolean filter admits only `value(true)`; `null`/`missing` are not true; evaluated `type_error`/`conflict` fail.
    filters_to_true_only = 2,
    /// Aggregate ignores `null`/`missing` on nullable inputs and propagates checked overflow/type_error.
    checked_aggregate = 3,
    /// SQL CHECK constraint passes on `value(true)` or `null` and rejects `value(false)`, `missing`, `type_error`, `conflict`.
    check_constraint_true_or_null = 4,
    /// Explicit state predicate (`IS NULL`, `IS MISSING`, `IS VALUE`, `IS TYPE_ERROR`, `IS CONFLICT`) maps all 5 states to `value(bool)`.
    total_state_predicate = 5,
    /// Scalar expressions preserve NULL/missing and fail on evaluated errors.
    checked_scalar = 6,
};

/// How comparison and ordering operators bind collation descriptors ($\kappa$).
pub const CollationRule = enum(u8) {
    none = 0,
    column_bound = 1,
    explicit_override = 2,
    mixed_rejected = 3,
};

/// Execution lifetime and incremental change mode of an operator or plan.
pub const ChangeMode = enum(u8) {
    /// Metadata-only explanation; performs zero data work.
    explanation_zero_work = 0,
    /// Bounded finite evaluation over supplied values or an immutable source cut.
    snapshot_finite = 1,
    /// Append-only stream consumption over monotonic offsets.
    append_only_stream = 2,
    /// Retractable Z-set delta stream (weight +1 / -1) for incremental maintenance.
    retractable_zset = 3,
    /// Atomic single-statement or transactional data mutation.
    atomic_mutation = 4,
    /// Finite recomputation per recorded basis, publishing an ordered paired delta.
    recomputed_delta = 5,
};

/// Execution data-work bounds, excluding metadata loading, compilation and
/// result framing. Zero data work does not mean zero CPU or allocation.
pub const WorkBound = struct {
    max_source_pins: u8,
    max_output_rows: ?u64,
    max_resident_bytes: ?u64,
    max_spill_bytes: ?u64,
    max_work_steps: ?u64,
    acquires_data_pins: bool,
    reads_storage_segments: bool,
    mutates_durable_state: bool,

    pub const zero_work_explain: WorkBound = .{
        .max_source_pins = 0,
        .max_output_rows = 0,
        .max_resident_bytes = 0,
        .max_spill_bytes = 0,
        .max_work_steps = 0,
        .acquires_data_pins = false,
        .reads_storage_segments = false,
        .mutates_durable_state = false,
    };
};

/// Complete resolved operator trait and effect summary for a plan or operator node.
pub const Summary = struct {
    effects: EffectSet,
    deterministic: bool,
    /// True when evaluation can surface a runtime failure or 5-state error cell (e.g. checked SUM overflow).
    fallible: bool,
    five_state_rule: FiveStateRule,
    collation_rule: CollationRule,
    active_collations: u16,
    change_mode: ChangeMode,
    work_bound: WorkBound,

    /// Construct the zero-work EXPLAIN projection of an execution summary.
    /// EXPLAIN reports the target plan's resolved traits while guaranteeing
    /// that the explanation step itself performs no storage reads, pin acquisitions, or mutations.
    pub fn forExplain(target: Summary) ExplainSummary {
        return .{
            .target = target,
            .explain_effects = EffectSet.none,
            .explain_change_mode = .explanation_zero_work,
            .explain_work_bound = WorkBound.zero_work_explain,
        };
    }
};

pub const ExplainSummary = struct {
    target: Summary,
    explain_effects: EffectSet,
    explain_change_mode: ChangeMode,
    explain_work_bound: WorkBound,

    pub fn doesWork(self: ExplainSummary) bool {
        return self.explain_effects.read or
            self.explain_effects.mutate or
            self.explain_effects.capture or
            self.explain_effects.dispatch or
            self.explain_work_bound.acquires_data_pins or
            self.explain_work_bound.reads_storage_segments or
            self.explain_work_bound.mutates_durable_state;
    }
};

/// Derive operator traits and effect bounds for a source-bound `LogicalQuery.Plan`.
pub fn forLogicalPlan(plan: LogicalQuery.Plan) !Summary {
    try plan.schema.validate(.{});
    try plan.validateShape();
    var active_collations: u16 = 0;
    for (plan.collations.columns[0..plan.schema.structure.len]) |entry| {
        if (entry != .none) active_collations += 1;
    }
    const fallible = plan.scalars.instructions.len != 0 or plan.aggregate != .rows or switch (plan.predicate) {
        .all, .state => false,
        else => true,
    };
    const five_state_rule: FiveStateRule = switch (plan.aggregate) {
        .rows => if (plan.scalars.instructions.len != 0) .checked_scalar else switch (plan.predicate) {
            .all => .preserves_all_states,
            .state => .filters_to_true_only,
            .compare, .null_compare, .program => .filters_to_true_only,
        },
        .count, .count_values, .sum => .checked_aggregate,
    };
    return .{
        .effects = EffectSet.read_only,
        .deterministic = true,
        .fallible = fallible,
        .five_state_rule = five_state_rule,
        .collation_rule = if (active_collations > 0) .column_bound else .none,
        .active_collations = active_collations,
        .change_mode = .snapshot_finite,
        .work_bound = .{
            .max_source_pins = 1,
            .max_output_rows = switch (plan.aggregate) {
                .rows => plan.limit,
                .count, .count_values, .sum => 1,
            },
            .max_resident_bytes = null,
            .max_spill_bytes = 0,
            .max_work_steps = null,
            .acquires_data_pins = true,
            .reads_storage_segments = true,
            .mutates_durable_state = false,
        },
    };
}

/// Derive operator traits and effect bounds for a relational `Relational.Plan`.
pub fn forRelationalPlan(plan: Relational.Plan) !Summary {
    try plan.validateShape();
    var active_collations: u16 = 0;
    for (plan.sources) |source| {
        for (source.schema.columns) |col| {
            if (col.collation != .none) active_collations += 1;
        }
    }
    var has_aggregate = plan.group_by.len > 0;
    for (plan.outputs) |out| switch (out.expression) {
        .column => {},
        .count_all, .count => has_aggregate = true,
        .sum => {
            has_aggregate = true;
        },
    };
    var has_filter = plan.filter.instructions.len > 0;
    for (plan.source_filters[0..plan.sources.len]) |pred| {
        if (pred.instructions.len > 0) has_filter = true;
    }
    const effects: EffectSet = switch (plan.lifetime) {
        .interactive => EffectSet.read_only,
        .captured, .maintained => EffectSet.captured_read,
    };
    const change_mode: ChangeMode = switch (plan.lifetime) {
        .interactive, .captured => .snapshot_finite,
        .maintained => .recomputed_delta,
    };
    return .{
        .effects = effects,
        .deterministic = true,
        .fallible = has_aggregate or has_filter or plan.join != null,
        .five_state_rule = if (has_aggregate)
            .checked_aggregate
        else if (has_filter)
            .filters_to_true_only
        else
            .preserves_all_states,
        .collation_rule = if (active_collations > 0) .column_bound else .none,
        .active_collations = active_collations,
        .change_mode = change_mode,
        .work_bound = .{
            .max_source_pins = plan.budgets.source_pins,
            .max_output_rows = plan.budgets.output_rows,
            .max_resident_bytes = plan.budgets.resident_bytes,
            .max_spill_bytes = plan.budgets.spill_bytes,
            .max_work_steps = plan.budgets.work_steps,
            .acquires_data_pins = true,
            .reads_storage_segments = true,
            .mutates_durable_state = plan.lifetime != .interactive,
        },
    };
}

/// Pure evaluation of one provided candidate row. CHECK never opens a source,
/// acquires a pin or writes an outcome; the enclosing mutation owns those effects.
/// Validation intentionally uses the expression shape, not Schema.validate,
/// because schema validation derives these same traits for each declaration.
pub fn forCheck(schema: @import("TableSchema.zig").Schema, check: @import("TableConstraints.zig").CheckConstraint) !Summary {
    const ts = @import("TableSchema.zig");
    if (schema.columns.len == 0 or schema.columns.len > ts.max_columns) return error.InvalidColumnCount;
    try check.validateExpression(schema);
    var referenced: [ts.max_columns]bool = @splat(false);
    for (check.atoms) |atom| switch (atom) {
        .compare_literal => |value| referenced[try schema.index(value.column)] = true,
        .compare_columns => |value| {
            referenced[try schema.index(value.left_column)] = true;
            referenced[try schema.index(value.right_column)] = true;
        },
        .is_null, .is_not_null => {},
    };
    var collations: u16 = 0;
    for (schema.columns, 0..) |column, index| {
        if (referenced[index] and column.collation != .none) collations += 1;
    }
    return localRow(.check_constraint_true_or_null, collations);
}

/// The exact mapping has already been validated by TableSchemaProjection.init.
/// This reports one row's pure mapping, including fallible destination validation.
/// Retention and storage effects belong to the enclosing scan, not this mapping.
pub fn forSchemaProjection(projection: *const @import("TableSchemaProjection.zig")) Summary {
    var collations: u16 = 0;
    for (projection.logical.columns) |column| if (column.collation != .none) {
        collations += 1;
    };
    return localRow(.preserves_all_states, collations);
}
fn localRow(rule: FiveStateRule, collations: u16) Summary {
    return .{
        .effects = .none,
        .deterministic = true,
        .fallible = true,
        .five_state_rule = rule,
        .collation_rule = if (collations != 0) .column_bound else .none,
        .active_collations = collations,
        .change_mode = .snapshot_finite,
        .work_bound = .{
            .max_source_pins = 0,
            .max_output_rows = 1,
            // Recursive cells and comparisons have input-dependent validation
            // work; an instruction count is not a CPU or resident-byte budget.
            .max_resident_bytes = null,
            .max_spill_bytes = 0,
            .max_work_steps = null,
            .acquires_data_pins = false,
            .reads_storage_segments = false,
            .mutates_durable_state = false,
        },
    };
}

/// Atomic Table mutation plus its row-local constraints. No CHECK gains effects
/// merely because its caller publishes an atomic successor. Private candidate
/// roots belong to that owner; this plan acquires no query snapshot pins.
pub fn forTableDmlPlan(plan: @import("TableDml.zig").Plan) !Summary {
    try plan.validateShape();
    var summary: Summary = .{
        .effects = .table_mutation,
        .deterministic = true,
        .fallible = true,
        .five_state_rule = .checked_scalar,
        .collation_rule = .none,
        .active_collations = 0,
        .change_mode = .atomic_mutation,
        .work_bound = .{
            .max_source_pins = 0,
            .max_output_rows = 0,
            .max_resident_bytes = null,
            .max_spill_bytes = 0,
            .max_work_steps = null,
            .acquires_data_pins = false,
            .reads_storage_segments = plan.action != .insert,
            .mutates_durable_state = true,
        },
    };
    for (plan.schema.columns) |column| if (column.collation != .none) {
        summary.active_collations += 1;
    };
    if (summary.active_collations != 0) summary.collation_rule = .column_bound;
    if (plan.action != .delete) for (plan.schema.integrity.checks) |check| {
        const constraint = try forCheck(plan.schema, check);
        summary.effects = summary.effects.merge(constraint.effects);
        summary.deterministic = summary.deterministic and constraint.deterministic;
        summary.fallible = summary.fallible or constraint.fallible;
        summary.five_state_rule = constraint.five_state_rule;
    };
    return summary;
}

/// Derive operator traits and effect bounds for a Block-Max WAND or single-snapshot
/// hybrid search query with bounded `top_k` and `resident_bytes`.
pub fn forSearchQuery(top_k: u64, resident_bytes: u64, active_collations: u8) Summary {
    return .{
        .effects = EffectSet.read_only,
        .deterministic = true,
        .fallible = true,
        .five_state_rule = .filters_to_true_only,
        .collation_rule = if (active_collations > 0) .column_bound else .none,
        .active_collations = active_collations,
        .change_mode = .snapshot_finite,
        .work_bound = .{
            .max_source_pins = 1,
            .max_output_rows = top_k,
            .max_resident_bytes = resident_bytes,
            .max_spill_bytes = 0,
            .max_work_steps = null,
            .acquires_data_pins = true,
            .reads_storage_segments = true,
            .mutates_durable_state = false,
        },
    };
}
