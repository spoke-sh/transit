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
    try testing.expectEqual(OperatorTraits.FiveStateRule.filters_to_true_only, traits.five_state_rule);
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
    try testing.expectEqual(OperatorTraits.ChangeMode.recomputed_delta, rel_traits.change_mode);
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
    try testing.expectEqual(StandardsLedger.StageState.staged, fk_feat.states.execute);
}

test "operator traits preserve comparison failures" {
    const fields = [_]f.Types.Field{.{ .name = "id", .type = .int64 }};
    const plan: f.LogicalQuery.Plan = .{ .schema = .{ .structure = &fields }, .source_basis = @splat(1), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = 1 } } } };
    try testing.expect((try OperatorTraits.forLogicalPlan(plan)).fallible);
}

test "operator traits count 256 collated columns without overflow" {
    var names: [128][4]u8 = undefined;
    var columns: [128]f.TableSchema.Column = undefined;
    for (&columns, 0..) |*column, i| column.* = .{
        .id = i + 1,
        .name = try std.fmt.bufPrint(&names[i], "c{d}", .{i}),
        .type = .utf8,
        .collation = .ascii_ci,
    };
    const schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 129, .columns = &columns };
    const sources = [_]f.Relational.Source{
        .{ .alias = "a", .realm = 1, .resource = 1, .catalog = 1, .owner = 1, .schema = schema },
        .{ .alias = "b", .realm = 1, .resource = 2, .catalog = 1, .owner = 2, .schema = schema },
    };
    const plan: f.Relational.Plan = .{
        .sources = &sources,
        .join = .{ .kind = .inner, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } },
        .outputs = &.{.{ .name = "code", .expression = .{ .column = .{ .source = 0, .id = 1 } } }},
        .lifetime = .interactive,
        .budgets = .{ .resident_bytes = 65536, .spill_bytes = 0, .result_bytes = 32768, .output_rows = 100, .work_steps = 1000, .source_pins = 2 },
    };
    try testing.expectEqual(@as(u16, 256), (try OperatorTraits.forRelationalPlan(plan)).active_collations);
}

test "standards ledger unsupported declarations match the production compiler" {
    const cases = .{
        .{ "F491", "CREATE TABLE t (id BIGINT CHECK (id > 0))", error.UnsupportedTableConstraint },
        .{ "F492", "CREATE TABLE t (id BIGINT REFERENCES parent(id))", error.UnsupportedTableConstraint },
        .{ "X001-RANGE", "CREATE TABLE t (span RANGE<BOOLEAN>)", error.UnsupportedRangeSubtype },
        .{ "X002-VECTOR", "CREATE TABLE t (embedding VECTOR(3, FLOAT64))", error.InvalidTypeParameters },
    };
    inline for (cases) |case| {
        try testing.expectError(case[2], f.TableDdl.compile(testing.allocator, case[1], null, null));
    }
    inline for (.{"ICU_ROOT"}) |collation| {
        try testing.expectEqual(StandardsLedger.StageState.rejected, StandardsLedger.findCollation(collation).?.states.parse);
        try testing.expectError(error.UnsupportedColumnCollation, f.TableDdl.compile(testing.allocator, "CREATE TABLE t (label UTF8 COLLATE " ++ collation ++ ")", null, null));
    }
    inline for (.{ "EBCDIC_037_PAD", "EBCDIC_1047_NOPAD" }) |collation| {
        const descriptor = StandardsLedger.findCollation(collation).?;
        try testing.expectEqual(StandardsLedger.StageState.implemented, descriptor.states.parse);
        var compiled = try f.TableDdl.compile(testing.allocator, "CREATE TABLE t (label UTF8 COLLATE " ++ collation ++ ")", null, null);
        defer compiled.deinit();
        try testing.expectEqual(descriptor.runtime_tag.?, compiled.statement.create.columns[0].collation);
    }
}

fn compilerAccepts(case: StandardsLedger.CompilerCase) !bool {
    switch (case.entrypoint) {
        .table_ddl_catalog => {
            const Parent = struct {
                fn lookup(_: *anyopaque, arena: std.mem.Allocator, name: []const u8) !f.TableDdl.ForeignKey.Resolver.Parent {
                    if (!std.mem.eql(u8, name, "parent")) return error.UnknownTable;
                    const columns = try arena.dupe(f.TableSchema.Column, &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }});
                    return .{ .schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = columns, .primary_key = &.{1} }, .definition = .{ .object = .{ .scope = .{ .realm = 1, .resource = 1, .catalog = 1 }, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(4) } };
                }
            };
            var context: u8 = 0;
            var compiled = f.TableDdl.compileWithForeignKeys(testing.allocator, case.sql, null, null, .transit, .{ .context = &context, .lookup = Parent.lookup }) catch |err| {
                if (err == error.OutOfMemory) return err;
                return false;
            };
            defer compiled.deinit();
            return true;
        },
        .table_ddl => {
            var compiled = f.TableDdl.compile(testing.allocator, case.sql, null, null) catch |err| {
                if (err == error.OutOfMemory) return err;
                return false;
            };
            defer compiled.deinit();
            return true;
        },
        .relational_sql => {
            var parsed = f.RelationalSql.parse(testing.allocator, case.sql, null) catch |err| {
                if (err == error.OutOfMemory) return err;
                return false;
            };
            defer parsed.deinit();
            return true;
        },
        .inspection => return (f.Sql.parseInspection(case.sql) catch return false) != null,
    }
}

test "standards ledger corpus exercises actual production compiler boundaries" {
    for (StandardsLedger.compiler_cases) |case| {
        const accepted = try compilerAccepts(case);
        if (accepted != case.accept) std.debug.print("\nCapability case {s} ({s}): {s}\n", .{ case.id, case.feature, case.sql });
        try testing.expectEqual(case.accept, accepted);
        const declared = StandardsLedger.findFeature(case.feature).?.states.parse;
        if (case.accept) try testing.expectEqual(StandardsLedger.StageState.implemented, declared);
    }
}

test "CHECK traits resolve through schema validation and compose with atomic mutation" {
    const t = std.testing;
    const check: f.TableConstraints.CheckConstraint = .{
        .id = 1,
        .name = "allowed_code",
        .atoms = &.{
            .{ .compare_literal = .{ .column = 2, .op = .eq, .literal = .{ .bytes = "ABC" } } },
            .{ .compare_columns = .{ .left_column = 2, .op = .eq, .right_column = 2 } },
        },
        .validated = false,
    };
    const columns = [_]f.TableSchema.Column{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
        .{ .id = 2, .name = "code", .type = .utf8, .collation = .ebcdic_037_pad },
    };
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .integrity = .{ .next_id = 2, .checks = &.{check} } };
    try schema.validate();
    const traits = try check.traits(schema);
    try t.expectEqualDeep(OperatorTraits.EffectSet.none, traits.effects);
    try t.expect(traits.deterministic and traits.fallible);
    try t.expectEqual(.check_constraint_true_or_null, traits.five_state_rule);
    try t.expectEqual(@as(u16, 1), traits.active_collations); // repeated comparisons do not multiply columns
    try t.expectEqual(@as(u8, 0), traits.work_bound.max_source_pins);
    try t.expect(!traits.work_bound.acquires_data_pins and !traits.work_bound.reads_storage_segments and !traits.work_bound.mutates_durable_state);
    try t.expect(!traits.forExplain().doesWork());
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = "ABC " } } } };
    const plan: f.TableDml.Plan = .{ .name = "events", .schema = schema, .action = .{ .insert = &.{&cells} } };
    try plan.validate();
    const mutation = try plan.traits();
    try t.expectEqualDeep(OperatorTraits.EffectSet.table_mutation, mutation.effects);
    try t.expectEqual(.atomic_mutation, mutation.change_mode);
    try t.expectEqual(.check_constraint_true_or_null, mutation.five_state_rule);
    try t.expect(mutation.work_bound.mutates_durable_state);
    try t.expectEqual(@as(?u64, 0), mutation.work_bound.max_output_rows);
    try t.expect(!mutation.forExplain().doesWork());
    var deletion = plan;
    deletion.action = .delete;
    try t.expectEqual(.checked_scalar, (try deletion.traits()).five_state_rule);
    var invalid = check;
    invalid.atoms = &.{.{ .compare_columns = .{ .left_column = 1, .op = .eq, .right_column = 2 } }};
    try t.expectError(error.IncompatibleCheckColumns, invalid.traits(schema));
    var rejected = cells;
    rejected[1] = .{ .value = .{ .atom = .{ .bytes = "NO" } } };
    var invalid_plan = plan;
    invalid_plan.action = .{ .insert = &.{&rejected} };
    try t.expectError(error.CheckConstraintViolation, invalid_plan.traits());
}

test "resolved schema projection traits preserve frozen defaults without storage effects" {
    const t = std.testing;
    const old_columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64 }};
    const new_columns = [_]f.TableSchema.Column{
        old_columns[0],
        .{ .id = 2, .name = "label", .type = .utf8, .collation = .ascii_ci, .default = .{ .value = .{ .atom = .{ .bytes = "later" } } } },
    };
    const before: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &old_columns };
    const after: f.TableSchema.Schema = .{ .object = 7, .revision = 3, .next_column = 3, .columns = &new_columns };
    const mapping = try f.TableSchemaProjection.init(before, after, &.{.{ .column = 2, .value = .{ .value = .{ .atom = .{ .bytes = "at add" } } } }});
    const traits = mapping.traits();
    try t.expectEqualDeep(OperatorTraits.EffectSet.none, traits.effects);
    try t.expect(traits.deterministic and traits.fallible);
    try t.expectEqual(.preserves_all_states, traits.five_state_rule);
    try t.expectEqual(@as(u16, 1), traits.active_collations);
    try t.expectEqual(@as(u8, 0), traits.work_bound.max_source_pins);
    try t.expectEqual(@as(?u64, 1), traits.work_bound.max_output_rows);
    try t.expect(!traits.forExplain().doesWork());
    var output: [2]f.Types.Values.Cell = undefined;
    const row = try mapping.row(&.{.null}, &output);
    try t.expect(row[0] == .null);
    try t.expectEqualStrings("at add", row[1].value.atom.bytes);
}

test "analytical component helpers do not advertise production SQL support" {
    // These are actual production parser calls, not searches for helper symbols.
    const cases = .{
        .{ "F401-JOIN", "SELECT a.id FROM a RIGHT JOIN b ON a.id = b.id", error.UnsupportedConstruct },
        .{ "T611-WINDOW", "SELECT SUM(a.id) OVER (PARTITION BY a.id) FROM a", error.InvalidSqlSyntax },
        .{ "T121-RECURSIVE-CTE", "WITH a AS (SELECT id FROM t) SELECT id FROM a", error.InvalidSqlSyntax },
        .{ "X009-CHANGES-STREAM-SLICE", "SELECT id FROM CHANGES(t)", error.UnsupportedConstruct },
        .{ "T182-BITEMPORAL-AS-OF", "SELECT id FROM t FOR SYSTEM_TIME AS OF 10", error.UnsupportedConstruct },
    };
    inline for (cases) |case| {
        const feature = StandardsLedger.findFeature(case[0]).?;
        try testing.expectEqual(StandardsLedger.StageState.rejected, feature.states.parse);
        try testing.expectEqual(StandardsLedger.StageState.rejected, feature.states.execute);
        try testing.expectError(case[2], f.RelationalSql.parse(testing.allocator, case[1], null));
    }
    // Preserve the existing, separately advertised two-source profile.
    var supported = try f.RelationalSql.parse(testing.allocator, "SELECT a.id FROM a LEFT JOIN b ON a.id = b.id", null);
    defer supported.deinit();
    try testing.expectEqual(@as(usize, 2), supported.targets.len);
    try testing.expectEqual(@FieldType(f.Relational.Join, "kind").left, supported.join.?.kind);
}

test "standards ledger rejects public search and constant IN syntax despite component helpers" {
    const schema: f.Types.Type = .{ .structure = &.{.{ .name = "text", .type = .utf8 }} };
    const cases = .{
        .{ "X007-PERFECT-HASH-IN", "SELECT text FROM docs WHERE text IN ('a', 'b')" },
        .{ "X007-PERFECT-HASH-IN", "SELECT text FROM docs WHERE text NOT IN ('a', 'b')" },
        .{ "X005-SEARCH-WAND", "SELECT text FROM docs WHERE MATCH(text, 'query')" },
        .{ "X005-SEARCH-WAND", "SELECT text FROM docs WHERE text NEAR 'query'" },
    };
    inline for (cases) |case| {
        try testing.expectEqual(StandardsLedger.StageState.rejected, StandardsLedger.findFeature(case[0]).?.states.parse);
        if (f.TableSelect.compile(testing.allocator, case[1], "docs", schema, @splat(14), null)) |compiled| {
            var owner = compiled;
            owner.deinit();
            return error.UnexpectedSyntaxAdmission;
        } else |_| {}
    }
}
