const std = @import("std");
const testing = std.testing;
const f = @import("root.zig");
const OperatorTraits = f.OperatorTraits;
const StandardsLedger = f.StandardsLedger;

test "operator traits propagate read/capture/mutate effects, 5-state rules, collations and zero-work explain" {
    const fields = [_]f.Types.Field{
        .{ .name = "id", .type = .int64, .nullable = false },
        .{ .name = "code", .type = .utf8, .nullable = true },
    };
    const schema: f.Types.Type = .{ .structure = &fields };
    var collations: f.QueryCollations = .{};
    collations.columns[1] = .ebcdic_cp037;

    const logical_plan: f.LogicalQuery.Plan = .{
        .schema = schema,
        .source_basis = @splat(0x11),
        .collations = collations,
        .projection = &.{ 0, 1 },
        .predicate = .{ .state = .{ .column = 1, .value = .value } },
        .aggregate = .rows,
        .limit = 25,
    };

    const traits = try OperatorTraits.forLogicalPlan(logical_plan);
    try testing.expect(traits.effects.isPureRead());
    try testing.expect(traits.effects.read);
    try testing.expect(!traits.effects.mutate);
    try testing.expect(traits.deterministic);
    try testing.expect(!traits.fallible);
    try testing.expectEqual(OperatorTraits.FiveStateRule.total_state_predicate, traits.five_state_rule);
    try testing.expectEqual(OperatorTraits.CollationRule.column_bound, traits.collation_rule);
    try testing.expectEqual(@as(u8, 1), traits.active_collations);
    try testing.expectEqual(OperatorTraits.ChangeMode.snapshot_finite, traits.change_mode);
    try testing.expectEqual(@as(?u64, 25), traits.work_bound.max_output_rows);
    try testing.expect(traits.work_bound.acquires_data_pins);
    try testing.expect(traits.work_bound.reads_storage_segments);
    try testing.expect(!traits.work_bound.mutates_durable_state);

    const explain = OperatorTraits.Summary.forExplain(traits);
    try testing.expect(!explain.doesWork());
    try testing.expectEqual(OperatorTraits.ChangeMode.explanation_zero_work, explain.explain_change_mode);
    try testing.expectEqual(@as(u8, 0), explain.explain_work_bound.max_source_pins);
    try testing.expect(!explain.explain_work_bound.acquires_data_pins);
    try testing.expect(!explain.explain_work_bound.reads_storage_segments);
    try testing.expect(!explain.explain_work_bound.mutates_durable_state);

    const sum_plan: f.LogicalQuery.Plan = .{
        .schema = schema,
        .source_basis = @splat(0x22),
        .projection = &.{0},
        .aggregate = .sum,
    };
    const sum_traits = try OperatorTraits.forLogicalPlan(sum_plan);
    try testing.expect(sum_traits.fallible);
    try testing.expectEqual(OperatorTraits.FiveStateRule.checked_aggregate, sum_traits.five_state_rule);
    try testing.expectEqual(@as(?u64, 1), sum_traits.work_bound.max_output_rows);
}

test "relational operator traits distinguish interactive, captured and maintained lifetimes" {
    const columns = [_]f.TableSchema.Column{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
        .{ .id = 2, .name = "code", .type = .utf8, .nullable = false, .collation = .ascii_ci },
    };
    const pk = [_]f.TableSchema.ColumnId{1};
    const table_schema: f.TableSchema.Schema = .{
        .object = 10,
        .revision = 1,
        .next_column = 3,
        .columns = &columns,
        .primary_key = &pk,
    };
    const sources = [_]f.Relational.Source{.{
        .alias = "t",
        .realm = 1,
        .resource = 2,
        .catalog = 3,
        .owner = 4,
        .schema = table_schema,
    }};
    const outputs = [_]f.Relational.Output{
        .{ .name = "code", .expression = .{ .column = .{ .source = 0, .id = 2 } } },
        .{ .name = "total", .expression = .{ .sum = .{ .source = 0, .id = 1 } } },
    };
    const groups = [_]f.Relational.Column{.{ .source = 0, .id = 2 }};
    const relational_plan: f.Relational.Plan = .{
        .sources = &sources,
        .group_by = &groups,
        .outputs = &outputs,
        .lifetime = .maintained,
        .budgets = .{
            .resident_bytes = 65536,
            .spill_bytes = 131072,
            .result_bytes = 32768,
            .output_rows = 100,
            .work_steps = 1000,
            .source_pins = 1,
        },
    };
    const rel_traits = try OperatorTraits.forRelationalPlan(relational_plan);
    try testing.expect(rel_traits.effects.read);
    try testing.expect(rel_traits.effects.capture);
    try testing.expect(!rel_traits.effects.dispatch);
    try testing.expect(rel_traits.fallible);
    try testing.expectEqual(OperatorTraits.FiveStateRule.checked_aggregate, rel_traits.five_state_rule);
    try testing.expectEqual(OperatorTraits.CollationRule.column_bound, rel_traits.collation_rule);
    try testing.expectEqual(@as(u8, 1), rel_traits.active_collations);
    try testing.expectEqual(OperatorTraits.ChangeMode.retractable_zset, rel_traits.change_mode);
    try testing.expect(rel_traits.work_bound.mutates_durable_state);

    const rel_explain = OperatorTraits.Summary.forExplain(rel_traits);
    try testing.expect(!rel_explain.doesWork());
}

test "standards ledger binds collation, physical codec and feature lifecycle states" {
    const ucs = StandardsLedger.findCollation("UTF8_BINARY").?;
    try testing.expectEqualStrings("UCS_BASIC", ucs.id);
    try testing.expect(ucs.normalized_key_order_preserving);
    try testing.expect(ucs.zone_map_pruning_sound);
    try testing.expectEqual(StandardsLedger.StageState.implemented, ucs.states.execute);

    const uca = StandardsLedger.findCollation("ICU_ROOT").?;
    try testing.expectEqual(StandardsLedger.StageState.rejected, uca.states.execute);
    try testing.expect(!uca.normalized_key_order_preserving);

    const comp3 = StandardsLedger.findPhysicalCodec("COMP_3").?;
    try testing.expectEqual(f.PhysicalCodecs.Encoding.comp_3, comp3.encoding);
    try testing.expectEqualStrings("type_error", comp3.invalid_payload_cell_state);
    try testing.expect(comp3.zone_map_pruning_sound);

    const fk_feat = StandardsLedger.findFeature("F492").?;
    try testing.expectEqual(StandardsLedger.StageState.implemented, fk_feat.states.parse);
    try testing.expectEqual(StandardsLedger.StageState.implemented, fk_feat.states.lower);
}
