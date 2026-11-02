const std = @import("std");
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const v = t.Values;
const TableEvolution = @import("TableEvolution.zig");
const TableSchemaProjection = @import("TableSchemaProjection.zig");
const TableConstraints = @import("TableConstraints.zig");

test "persisted integrity preserves NOT VALID checks across binary and neutral schemas" {
    const testing = std.testing;
    const columns = [_]s.Column{.{ .id = 1, .name = "balance", .type = .int64, .nullable = true }};
    const checks = [_]TableConstraints.CheckConstraint{.{ .id = 7, .name = "positive_balance", .validated = false, .atoms = &.{.{ .compare_literal = .{ .column = 1, .op = .gte, .literal = .{ .signed = 0 } } }} }};
    const schema: s.Schema = .{ .object = 90, .revision = 3, .next_column = 2, .columns = &columns, .integrity = .{ .next_id = 8, .checks = &checks } };
    const previous = [_]v.Cell{.{ .value = .{ .atom = .{ .signed = -1 } } }};
    try schema.validateRow(&previous);
    try testing.expectError(error.CheckConstraintViolation, schema.validateWrite(&previous));
    try schema.validateWrite(&.{.null});
    try schema.validateWrite(&.{.{ .value = .{ .atom = .{ .signed = 0 } } }});
    var bytes: [s.max_bytes]u8 = undefined;
    var restored = try s.decode(testing.allocator, try schema.encode(&bytes));
    defer restored.deinit();
    try testing.expectEqual(@as(u32, 8), restored.schema.integrity.next_id);
    try testing.expect(!restored.schema.integrity.checks[0].validated);
    try testing.expectError(error.CheckConstraintViolation, restored.schema.validateWrite(&previous));
    const json = try @import("TableSchemaJson.zig").encode(testing.allocator, restored.schema);
    defer testing.allocator.free(json);
    var neutral = try @import("TableSchemaJson.zig").decode(testing.allocator, json);
    defer neutral.deinit();
    try testing.expectEqual(try schema.fingerprint(), try neutral.schema.fingerprint());
    const plan: @import("TableDml.zig").Plan = .{ .name = "balances", .schema = neutral.schema, .action = .{ .insert = &.{&previous} } };
    try testing.expectError(error.CheckConstraintViolation, plan.validate());
}

test "persisted integrity rejects reused identities malformed literals and false FK enforcement" {
    const testing = std.testing;
    const columns = [_]s.Column{.{ .id = 1, .name = "code", .type = .utf8, .collation = .ebcdic_1047_nopad }};
    var check: TableConstraints.CheckConstraint = .{ .id = 1, .name = "code_check", .atoms = &.{.{ .compare_literal = .{ .column = 1, .op = .eq, .literal = .{ .bytes = "\xe2\x82\xac" } } }} };
    var schema: s.Schema = .{ .object = 90, .revision = 3, .next_column = 2, .columns = &columns, .integrity = .{ .next_id = 2, .checks = (&check)[0..1] } };
    try testing.expectError(error.UnrepresentableEbcdic1047, schema.validate());
    check.atoms = &.{.{ .is_not_null = 1 }};
    schema.integrity.next_id = 1;
    try testing.expectError(error.InvalidConstraintIdentity, schema.validate());
    schema.integrity.next_id = 3;
    schema.integrity.foreign_keys = &.{.{ .id = 2, .name = "fk", .local_columns = &.{1}, .target_object = 91, .target_revision = 1, .target_columns = &.{1}, .enforcement = .enforced }};
    try testing.expectError(error.ForeignKeyIndexEnforcementUnavailable, schema.validate());
}

test "CHECK SQL binds later columns and keeps integrity identities through evolution" {
    const testing = std.testing;
    const ddl = @import("TableDdl.zig");
    var created = try ddl.compile(testing.allocator, "CREATE TABLE limits (CONSTRAINT ordered CHECK (low <= high AND low >= 0), low BIGINT, high BIGINT)", null, null);
    defer created.deinit();
    const schema = try created.statement.create.bind(20);
    try schema.validateWrite(&.{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .signed = 2 } } } });
    try testing.expectError(error.CheckConstraintViolation, schema.validateWrite(&.{ .{ .value = .{ .atom = .{ .signed = 3 } } }, .{ .value = .{ .atom = .{ .signed = 2 } } } }));
    var columns: [s.max_columns]s.Column = undefined;
    const evolution = @import("TableEvolution.zig");
    try testing.expectError(error.ColumnReferencedByCheckConstraint, evolution.apply(schema, .{ .drop = 1 }, &columns));
    var added = try ddl.compile(testing.allocator, "ALTER TABLE limits ADD CONSTRAINT ceiling CHECK (high < 100) NOT VALID", schema, null);
    defer added.deinit();
    const addition = try evolution.apply(schema, added.statement.alter.action.columns, &columns);
    try testing.expect(try addition.canProject());
    try testing.expect(!addition.after.integrity.checks[1].validated);
    var validate = try ddl.compile(testing.allocator, "ALTER TABLE limits VALIDATE CONSTRAINT ceiling", addition.after, null);
    defer validate.deinit();
    var validation_columns: [s.max_columns]s.Column = undefined;
    const validation = try evolution.apply(addition.after, validate.statement.alter.action.columns, &validation_columns);
    try testing.expectEqual(evolution.Work.validate_rows, validation.work);
    try testing.expect(!try validation.canProject());
    var row: [2]v.Cell = undefined;
    try testing.expectError(error.CheckConstraintViolation, validation.row(&.{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .signed = 100 } } } }, &row));
    var drop = try ddl.compile(testing.allocator, "ALTER TABLE limits DROP CONSTRAINT ceiling", addition.after, null);
    defer drop.deinit();
    var drop_columns: [s.max_columns]s.Column = undefined;
    const dropped = try evolution.apply(addition.after, drop.statement.alter.action.columns, &drop_columns);
    try testing.expectEqual(@as(u32, 3), dropped.after.integrity.next_id);
    try testing.expectEqual(@as(usize, 1), dropped.after.integrity.checks.len);
    var changed = addition.after.integrity;
    changed.next_id = 2;
    try testing.expectError(error.ReusedConstraintIdentity, TableConstraints.Integrity.evolution(dropped.after.integrity, changed));
}

test "5-state CHECK constraint evaluation passes value(true) and null and rejects false, missing, type_error, and conflict" {
    const columns = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "qty", .type = .{ .int64 = {} }, .nullable = true },
        .{ .id = 3, .name = "status", .type = .{ .utf8 = {} }, .nullable = true, .collation = .ascii_ci },
    };
    const pk = [_]s.ColumnId{1};
    const schema: s.Schema = .{
        .object = 42,
        .revision = 1,
        .next_column = 4,
        .columns = &columns,
        .primary_key = &pk,
    };

    const atoms = [_]TableConstraints.CheckAtom{
        .{ .compare_literal = .{ .column = 2, .op = .gt, .literal = .{ .signed = 0 } } },
        .{ .compare_literal = .{ .column = 3, .op = .eq, .literal = .{ .bytes = "ACTIVE" } } },
    };
    const check: TableConstraints.CheckConstraint = .{
        .id = 10,
        .name = "chk_positive_active",
        .atoms = &atoms,
    };
    try check.validate(schema);

    // 1. value(true) passes
    try TableConstraints.evaluateCheckRow(schema, check, &.{
        .{ .value = .{ .atom = .{ .signed = 1 } } },
        .{ .value = .{ .atom = .{ .signed = 5 } } },
        .{ .value = .{ .atom = .{ .bytes = "active" } } }, // matches under ascii_ci
    }, null);

    // 2. null (SQL UNKNOWN) passes SQL CHECK
    try TableConstraints.evaluateCheckRow(schema, check, &.{
        .{ .value = .{ .atom = .{ .signed = 2 } } },
        .{ .null = {} },
        .{ .null = {} },
    }, null);

    // 3. value(false) rejects with predicate_false
    var violation: TableConstraints.CheckViolation = undefined;
    try std.testing.expectError(
        error.CheckConstraintViolation,
        TableConstraints.evaluateCheckRow(schema, check, &.{
            .{ .value = .{ .atom = .{ .signed = 3 } } },
            .{ .value = .{ .atom = .{ .signed = -4 } } },
            .{ .value = .{ .atom = .{ .bytes = "ACTIVE" } } },
        }, &violation),
    );
    try std.testing.expectEqual(@as(u32, 10), violation.constraint_id);
    try std.testing.expectEqual(@as(s.ColumnId, 2), violation.column_id);
    try std.testing.expectEqual(t.State.value, violation.cell_state);
    try std.testing.expectEqual(TableConstraints.CheckViolationReason.predicate_false, violation.reason);

    // 4. missing, type_error, and conflict states never silently pass as SQL UNKNOWN
    for ([_]struct { cell: v.Cell, state: t.State, reason: TableConstraints.CheckViolationReason }{
        .{ .cell = .{ .missing = {} }, .state = .missing, .reason = .missing_cell },
        .{ .cell = .{ .type_error = .int64 }, .state = .type_error, .reason = .type_error_cell },
        .{ .cell = .{ .conflict = &.{} }, .state = .conflict, .reason = .conflict_cell },
    }) |tc| {
        try std.testing.expectError(
            error.CheckConstraintViolation,
            TableConstraints.evaluateCheckRow(schema, check, &.{
                .{ .value = .{ .atom = .{ .signed = 4 } } },
                tc.cell,
                .{ .value = .{ .atom = .{ .bytes = "ACTIVE" } } },
            }, &violation),
        );
        try std.testing.expectEqual(tc.state, violation.cell_state);
        try std.testing.expectEqual(tc.reason, violation.reason);
    }
}

test "ForeignKeyConstraint validation, M11 enforcement gate, and constraint-aware evolution protection" {
    const parent_cols = [_]s.Column{
        .{ .id = 1, .name = "account_id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "code", .type = .{ .utf8 = {} }, .nullable = false, .collation = .utf8_binary },
    };
    const parent_pk = [_]s.ColumnId{1};
    const parent_schema: s.Schema = .{
        .object = 100,
        .revision = 1,
        .next_column = 3,
        .columns = &parent_cols,
        .primary_key = &parent_pk,
    };

    const child_cols = [_]s.Column{
        .{ .id = 1, .name = "order_id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "account_id", .type = .{ .int64 = {} }, .nullable = true },
        .{ .id = 3, .name = "amount", .type = .{ .int64 = {} }, .nullable = false },
    };
    const child_pk = [_]s.ColumnId{1};
    const child_schema: s.Schema = .{
        .object = 200,
        .revision = 1,
        .next_column = 4,
        .columns = &child_cols,
        .primary_key = &child_pk,
    };

    const fk_local = [_]s.ColumnId{2};
    const fk_target = [_]s.ColumnId{1};
    const fk: TableConstraints.ForeignKeyConstraint = .{
        .id = 1,
        .name = "fk_order_account",
        .local_columns = &fk_local,
        .target_object = 100,
        .target_revision = 1,
        .target_columns = &fk_target,
        .on_delete = .set_null,
        .on_update = .restrict,
        .enforcement = .enforced,
    };
    try fk.validateAgainstSchemas(child_schema, parent_schema);

    // M11 handoff gate: enforced FK rejects writes when index enforcer is inactive
    try std.testing.expectError(error.ForeignKeyIndexEnforcementUnavailable, fk.checkWriteAdmission(false));
    try fk.checkWriteAdmission(true);

    const check_atoms = [_]TableConstraints.CheckAtom{
        .{ .compare_literal = .{ .column = 3, .op = .gte, .literal = .{ .signed = 0 } } },
    };
    const check: TableConstraints.CheckConstraint = .{
        .id = 2,
        .name = "chk_amount_non_negative",
        .atoms = &check_atoms,
    };

    // Dropping or altering a column referenced by CHECK or FOREIGN KEY is rejected
    try std.testing.expectError(
        error.ColumnReferencedByCheckConstraint,
        TableConstraints.validateChangeAgainstConstraints(child_schema, .{ .drop = 3 }, &.{check}, &.{fk}, &.{}),
    );
    try std.testing.expectError(
        error.ColumnReferencedByForeignKey,
        TableConstraints.validateChangeAgainstConstraints(child_schema, .{ .drop = 2 }, &.{check}, &.{fk}, &.{}),
    );
    try std.testing.expectError(
        error.ForeignKeySetNullRequiresNullableColumn,
        TableConstraints.validateChangeAgainstConstraints(
            child_schema,
            .{ .nullable = .{ .column = 2, .value = false } },
            &.{check},
            &.{fk},
            &.{},
        ),
    );
    // Inbound FK on parent table blocks dropping or altering parent PK column
    try std.testing.expectError(
        error.ColumnReferencedByInboundForeignKey,
        TableConstraints.validateChangeAgainstConstraints(
            parent_schema,
            .{ .type = .{ .column = 1, .type = .{ .utf8 = {} } } },
            &.{},
            &.{},
            &.{fk},
        ),
    );
}

test "ALTER TABLE evolution classifier separates lazy projection from online phased rewrite and tracks segment provenance" {
    const v1_cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "legacy_flag", .type = .{ .int64 = {} }, .nullable = true },
    };
    const pk = [_]s.ColumnId{1};
    const v1_schema: s.Schema = .{
        .object = 500,
        .revision = 1,
        .next_column = 3,
        .columns = &v1_cols,
        .primary_key = &pk,
    };

    // Evolution v1 -> v2: ADD COLUMN region UTF8 DEFAULT 'US-EAST'
    var v2_cols_buf: [s.max_columns]s.Column = undefined;
    const add_transition = try TableEvolution.apply(v1_schema, .{
        .add = .{
            .name = "region",
            .type = .{ .utf8 = {} },
            .nullable = false,
            .default = .{ .value = .{ .atom = .{ .bytes = "US-EAST" } } },
        },
    }, &v2_cols_buf);
    try std.testing.expectEqual(
        TableConstraints.RewriteKind.lazy_metadata_or_projection,
        try TableConstraints.checkSynchronousEvolutionAdmission(add_transition, true),
    );

    // Evolution v2 -> v3: DROP COLUMN legacy_flag (id = 2)
    var v3_cols_buf: [s.max_columns]s.Column = undefined;
    const drop_transition = try TableEvolution.apply(add_transition.after, .{ .drop = 2 }, &v3_cols_buf);
    try std.testing.expectEqual(
        TableConstraints.RewriteKind.lazy_metadata_or_projection,
        try TableConstraints.checkSynchronousEvolutionAdmission(drop_transition, true),
    );

    // Evolution v3 -> v4: ALTER COLUMN region physical encoding/collation requires online_phased_rewrite when rows exist
    var v4_cols_buf: [s.max_columns]s.Column = undefined;
    const type_transition = try TableEvolution.apply(drop_transition.after, .{
        .physical = .{ .column = 3, .encoding = .dictionary, .collation = .ascii_ci },
    }, &v4_cols_buf);
    try std.testing.expectError(
        error.OnlinePhasedRewriteRequired,
        TableConstraints.checkSynchronousEvolutionAdmission(type_transition, true),
    );
    // On an empty table (has_retained_rows == false), metadata update is allowed immediately
    try std.testing.expectEqual(
        TableConstraints.RewriteKind.lazy_metadata_or_projection,
        try TableConstraints.checkSynchronousEvolutionAdmission(type_transition, false),
    );

    // Segment projection coverage across v1, v2, and v3 segments targeting v3 schema
    const v1_initials = [_]TableSchemaProjection.Initial{
        .{ .column = 3, .value = .{ .value = .{ .atom = .{ .bytes = "US-EAST" } } } },
    };
    const segments = [_]TableConstraints.SegmentDescriptor{
        .{ .segment_id = 1, .physical_schema = v1_schema, .initials = &v1_initials, .row_count = 100 },
        .{ .segment_id = 2, .physical_schema = add_transition.after, .initials = &.{}, .row_count = 250 },
        .{ .segment_id = 3, .physical_schema = drop_transition.after, .initials = &.{}, .row_count = 400 },
    };
    const summary = try TableConstraints.inspectSegmentProjectionCoverage(&segments, drop_transition.after);
    try std.testing.expectEqual(@as(u32, 3), summary.total_segments);
    try std.testing.expectEqual(@as(u32, 1), summary.native_target_segments);
    try std.testing.expectEqual(@as(u32, 2), summary.lazily_projected_segments);
    try std.testing.expectEqual(@as(u16, 1), summary.synthesized_default_columns);
    try std.testing.expectEqual(@as(u16, 1), summary.omitted_dropped_columns);
    try std.testing.expectEqual(@as(u64, 750), summary.total_rows);
    try std.testing.expectEqual(@as(u64, 350), summary.lazily_projected_rows);
}

test "staged foreign key SQL freezes parent definitions and requires explicit non-enforcement" {
    const testing = std.testing;
    const ddl = @import("TableDdl.zig");
    const Fixture = struct {
        fn lookup(_: *anyopaque, _: std.mem.Allocator, name: []const u8) !ddl.ForeignKey.Resolver.Parent {
            try testing.expectEqualStrings("parent", name);
            return .{ .schema = .{ .object = 77, .revision = 3, .next_column = 10, .columns = &.{.{ .id = 9, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{9} }, .definition = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 77 }, .revision = 8, .digest = @splat(4) } };
        }
    };
    var context: u8 = 0;
    const resolver: ddl.ForeignKey.Resolver = .{ .context = &context, .lookup = Fixture.lookup };
    const sql = "CREATE TABLE child (CONSTRAINT parent_id FOREIGN KEY (parent_id) REFERENCES parent (id) ON DELETE SET NULL NOT ENFORCED, parent_id BIGINT)";
    try testing.expectError(error.ForeignKeyResolutionRequired, ddl.compile(testing.allocator, sql, null, null));
    try testing.expectError(error.ForeignKeyIndexEnforcementUnavailable, ddl.compile(testing.allocator, "CREATE TABLE child (parent_id BIGINT, FOREIGN KEY (parent_id) REFERENCES parent (id))", null, null));
    var compiled = try ddl.compileWithForeignKeys(testing.allocator, sql, null, null, .transit, resolver);
    defer compiled.deinit();
    const schema = try compiled.statement.create.bind(91);
    const fk = schema.integrity.foreign_keys[0];
    try testing.expectEqual(@as(u64, 3), fk.target_revision);
    try testing.expectEqual(@as(u64, 8), fk.target_definition.?.revision);
    try testing.expectEqual(@as(u64, 9), fk.target_columns[0]);
    try schema.validateWrite(&.{.{ .value = .{ .atom = .{ .signed = 999 } } }});
    var bytes: [s.max_bytes]u8 = undefined;
    var restored = try s.decode(testing.allocator, try schema.encode(&bytes));
    defer restored.deinit();
    try testing.expectEqualDeep(fk, restored.schema.integrity.foreign_keys[0]);
    const json = try @import("TableSchemaJson.zig").encode(testing.allocator, schema);
    defer testing.allocator.free(json);
    var neutral = try @import("TableSchemaJson.zig").decode(testing.allocator, json);
    defer neutral.deinit();
    try testing.expectEqualDeep(fk, neutral.schema.integrity.foreign_keys[0]);
    var altered = try ddl.compileWithForeignKeys(testing.allocator, "ALTER TABLE child ADD CONSTRAINT another FOREIGN KEY (parent_id) REFERENCES parent (id) NOT ENFORCED", schema, null, .transit, resolver);
    defer altered.deinit();
    try testing.expectEqual(@as(usize, 2), altered.statement.alter.action.columns.integrity.integrity.foreign_keys.len);
    try testing.expectError(error.ForeignKeySetNullRequiresNullableColumn, ddl.compileWithForeignKeys(testing.allocator, "CREATE TABLE child (parent_id BIGINT NOT NULL, FOREIGN KEY (parent_id) REFERENCES parent (id) ON DELETE SET NULL NOT ENFORCED)", null, null, .transit, resolver));
}
