const std = @import("std");
const r = @import("Relational.zig");
const table = @import("TableSchema.zig");
const types = @import("Types.zig");
const testing = std.testing;
const columns = [_]table.Column{
    .{ .id = 1, .name = "key", .type = .int64 },
    .{ .id = 2, .name = "value", .type = .int64 },
};
const sources = [_]r.Source{
    .{ .alias = "l", .realm = 1, .resource = 101, .catalog = 9, .owner = 7, .schema = .{ .object = 11, .revision = 1, .next_column = 3, .columns = &columns } },
    .{ .alias = "r", .realm = 1, .resource = 202, .catalog = 9, .owner = 7, .schema = .{ .object = 22, .revision = 1, .next_column = 3, .columns = &columns } },
};
const left_key: r.Column = .{ .source = 0, .id = 1 };
const right_key: r.Column = .{ .source = 1, .id = 1 };
const left_value: r.Column = .{ .source = 0, .id = 2 };
const right_value: r.Column = .{ .source = 1, .id = 2 };
const outputs = [_]r.Output{
    .{ .name = "key", .expression = .{ .column = left_key } },
    .{ .name = "rows", .expression = .count_all },
    .{ .name = "values", .expression = .{ .count = right_value } },
    .{ .name = "total", .expression = .{ .sum = right_value } },
};
fn plan() r.Plan {
    return .{
        .sources = &sources,
        .join = .{ .kind = .left, .left = left_key, .right = right_key },
        .group_by = &.{left_key},
        .outputs = &outputs,
        .lifetime = .captured,
        .budgets = .{ .resident_bytes = 4096, .spill_bytes = 8192, .result_bytes = 16384, .output_rows = 1000, .work_steps = 10000, .source_pins = 2 },
    };
}
fn cuts() ![2]r.Cut {
    return .{
        .{ .resource = 101, .revision = 7, .commitment = @splat(17), .schema = try sources[0].schema.fingerprint() },
        .{ .resource = 202, .revision = 12, .commitment = @splat(34), .schema = try sources[1].schema.fingerprint() },
    };
}
const Fixture = struct {
    definition: []const u8,
    identity: struct { prepared: []const u8, bound: []const u8 },
    nulls: []const struct { left: ?i64, right: ?i64, join: bool, order: i8 },
    sums: []const struct { values: []const ?i64, error_at: ?usize, value: ?i64 },
};

test "relational names resolve stable columns and reject ambiguous or hidden qualifiers" {
    try testing.expectEqualDeep(right_value, try r.resolve(&sources, "r", "value"));
    try testing.expectError(error.AmbiguousRelationalColumn, r.resolve(&sources, null, "key"));
    try testing.expectError(error.UnknownRelationalSource, r.resolve(&sources, "hidden", "key"));
    try testing.expectError(error.UnknownColumn, r.resolve(&sources, "l", "missing"));
    var changed = columns;
    changed[0].name = "renamed";
    var declarations = sources;
    declarations[0].schema.columns = &changed;
    try testing.expectEqualDeep(left_key, try r.resolve(&declarations, null, "renamed"));
    try testing.expectError(error.UnknownColumn, r.resolve(&declarations, "l", "key"));
}

test "relational identities match an independent Python schema and plan oracle" {
    const parsed = try std.json.parseFromSlice(Fixture, testing.allocator, @embedFile("fixtures/relational.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try testing.expectEqualStrings(r.definition, parsed.value.definition);
    try testing.expectEqualStrings(parsed.value.identity.prepared, &std.fmt.bytesToHex(&try plan().fingerprint(), .lower));
    const basis = try cuts();
    const bound: r.Bound = .{ .plan = plan(), .cuts = &basis };
    try testing.expectEqualStrings(parsed.value.identity.bound, &std.fmt.bytesToHex(&try bound.fingerprint(), .lower));
    try testing.expect(!std.mem.eql(u8, &try bound.fingerprint(), &try plan().fingerprint()));
}

test "relational null routing and canonical checked arithmetic match independent fixtures" {
    const parsed = try std.json.parseFromSlice(Fixture, testing.allocator, @embedFile("fixtures/relational.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    for (parsed.value.nulls) |sample| {
        try testing.expectEqual(sample.join, r.joinMatches(sample.left, sample.right));
        const order: std.math.Order = if (sample.order < 0) .lt else if (sample.order > 0) .gt else .eq;
        try testing.expectEqual(order, r.groupOrder(sample.left, sample.right));
    }
    for (parsed.value.sums) |sample| {
        var state: r.AggregateState = .{};
        for (sample.values, 0..) |value, i| {
            if (sample.error_at == i) {
                const before = state;
                try testing.expectError(error.Overflow, state.observe(.sum, value));
                try testing.expectEqualDeep(before, state);
                break;
            }
            try state.observe(.sum, value);
        }
        if (sample.error_at == null) try testing.expectEqual(sample.value, state.sum);
    }
    var count: r.AggregateState = .{ .rows = std.math.maxInt(u64) };
    try testing.expectError(error.Overflow, count.observe(.count_all, null));
    try testing.expectEqual(std.math.maxInt(u64), count.rows);
    count = .{};
    try count.observe(.count, null);
    try count.observe(.count, 7);
    try testing.expectEqual(@as(u64, 2), count.rows);
    try testing.expectEqual(@as(u64, 1), count.values);
}

test "relational admission rejects invalid shape aliases keys types and output grouping" {
    var value = plan();
    value.sources = &.{};
    try testing.expectError(error.InvalidRelationalSources, value.validate());
    value = plan();
    value.join = null;
    try testing.expectError(error.InvalidRelationalJoin, value.validate());
    value = plan();
    value.join.?.left = right_key;
    try testing.expectError(error.InvalidRelationalJoin, value.validate());
    value = plan();
    value.outputs = &.{};
    try testing.expectError(error.InvalidRelationalOutputs, value.validate());
    value = plan();
    value.group_by = &.{ left_key, left_key };
    try testing.expectError(error.DuplicateRelationalGroup, value.validate());
    value = plan();
    value.group_by = &.{};
    try testing.expectError(error.UngroupedRelationalColumn, value.validate());
    value = plan();
    value.outputs = &.{ outputs[0], outputs[0] };
    try testing.expectError(error.DuplicateRelationalOutput, value.validate());
    value = plan();
    value.outputs = &.{.{ .name = "value", .expression = .{ .column = left_value } }};
    try testing.expectError(error.UngroupedRelationalColumn, value.validate());
    var changed_sources = sources;
    value = plan();
    value.sources = &changed_sources;
    changed_sources[1].alias = "l";
    try testing.expectError(error.DuplicateRelationalAlias, value.validate());
    changed_sources = sources;
    changed_sources[1].realm = 2;
    try testing.expectError(error.CrossRealmRelationalQuery, value.validate());
    changed_sources = sources;
    changed_sources[1].resource = 0;
    try testing.expectError(error.InvalidRelationalSourceIdentity, value.validate());
    changed_sources = sources;
    changed_sources[1].alias = "bad\x00name";
    try testing.expectError(error.InvalidRelationalName, value.validate());
    changed_sources = sources;
    var changed_columns = columns;
    changed_sources[1].schema.columns = &changed_columns;
    changed_columns[0].type = .utf8;
    try testing.expectError(error.UnsupportedRelationalType, value.validate());
    changed_columns = columns;
    changed_columns[0].id = 3;
    changed_sources[1].schema.next_column = 4;
    try testing.expectError(error.UnknownColumn, value.validate());
}

test "relational output schema accounts for left null extension and independent aggregates" {
    var value = plan();
    var fields: [r.max_outputs]types.Field = undefined;
    var schema = try value.outputSchema(&fields);
    try testing.expectEqual(types.Tag.int64, std.meta.activeTag(schema.structure[0].type));
    try testing.expectEqual(types.Tag.uint64, std.meta.activeTag(schema.structure[1].type));
    try testing.expect(!schema.structure[1].nullable and !schema.structure[2].nullable and schema.structure[3].nullable);
    var changed_sources = sources;
    var required = columns;
    required[0].nullable = false;
    changed_sources[1].schema.columns = &required;
    value.sources = &changed_sources;
    value.outputs = &.{.{ .name = "right_key", .expression = .{ .column = right_key } }};
    value.group_by = &.{};
    schema = try value.outputSchema(&fields);
    try testing.expect(schema.structure[0].nullable);
    value.join.?.kind = .inner;
    schema = try value.outputSchema(&fields);
    try testing.expect(!schema.structure[0].nullable);
    try testing.expectError(error.RelationalOutputBufferTooSmall, value.outputSchema(&.{}));
}

test "relational source and post-join predicates have distinct scope identity and stack admission" {
    const positive = [_]r.Instruction{.{ .compare = .{ .column = right_value, .op = .greater, .value = 0 } }};
    var value = plan();
    value.source_filters[0] = .{ .instructions = &positive };
    try testing.expectError(error.InvalidRelationalFilterScope, value.validate());
    value = plan();
    value.source_filters[1] = .{ .instructions = &positive };
    const prefiltered = try value.fingerprint();
    value = plan();
    value.filter = .{ .instructions = &positive };
    try testing.expect(!std.mem.eql(u8, &prefiltered, &try value.fingerprint()));
    value.filter = .{ .instructions = &.{.conjunction} };
    try testing.expectError(error.InvalidRelationalPredicate, value.validate());
    value.filter = .{ .instructions = &.{ .{ .is_null = left_key }, .{ .is_not_null = right_key } } };
    try testing.expectError(error.InvalidRelationalPredicate, value.validate());
    value.filter = .{ .instructions = &.{ .{ .is_null = left_key }, .{ .is_not_null = right_key }, .disjunction, .negate } };
    try value.validate();
    var instructions: [65]r.Instruction = @splat(.negate);
    instructions[0] = .{ .is_null = left_key };
    value.filter = .{ .instructions = &instructions };
    try testing.expectError(error.InvalidRelationalPredicate, value.validate());
    value.filter = .{ .instructions = instructions[0..64] };
    try value.validate();
}

test "relational source vectors seal every alias and prohibit mixed cuts for one resource" {
    var basis = try cuts();
    var bound: r.Bound = .{ .plan = plan(), .cuts = basis[0..1] };
    try testing.expectError(error.IncompleteRelationalBasis, bound.validate());
    bound.cuts = &basis;
    basis[1].schema[0] ^= 1;
    try testing.expectError(error.RelationalSourceChanged, bound.validate());
    basis = try cuts();
    basis[1].commitment = @splat(0);
    try testing.expectError(error.InvalidRelationalCut, bound.validate());
    var aliases = sources;
    aliases[1] = sources[0];
    aliases[1].alias = "r";
    bound.plan.sources = &aliases;
    basis = .{ (try cuts())[0], (try cuts())[0] };
    bound.plan.budgets.source_pins = 1;
    try bound.validate();
    basis[1].revision += 1;
    try testing.expectError(error.InconsistentRelationalCut, bound.validate());
    basis[1] = basis[0];
    basis[1].commitment[0] ^= 1;
    try testing.expectError(error.InconsistentRelationalCut, bound.validate());
    basis[1] = basis[0];
    aliases[1].schema.revision += 1;
    try testing.expectError(error.RelationalSourceChanged, bound.validate());
    aliases[1] = sources[0];
    aliases[1].alias = "r";
    aliases[1].resource = 303;
    try testing.expectError(error.RelationalSourceChanged, bound.validate());
}

test "relational prepared and bound identities retain budgets lifetime schemas and exact cuts" {
    const original = try plan().fingerprint();
    var value = plan();
    value.lifetime = .interactive;
    try testing.expect(!std.mem.eql(u8, &original, &try value.fingerprint()));
    value = plan();
    value.budgets.output_rows += 1;
    try testing.expect(!std.mem.eql(u8, &original, &try value.fingerprint()));
    var changed = sources;
    value = plan();
    value.sources = &changed;
    changed[1].schema.object += 1;
    try testing.expect(!std.mem.eql(u8, &original, &try value.fingerprint()));
    changed = sources;
    changed[1].schema.revision += 1;
    try testing.expect(!std.mem.eql(u8, &original, &try value.fingerprint()));
    var basis = try cuts();
    const bound: r.Bound = .{ .plan = plan(), .cuts = &basis };
    const first = try bound.fingerprint();
    basis[1].revision += 1;
    try testing.expect(!std.mem.eql(u8, &first, &try bound.fingerprint()));
    basis = try cuts();
    basis[1].commitment[0] ^= 1;
    try testing.expect(!std.mem.eql(u8, &first, &try bound.fingerprint()));
}

test "relational plan and working budgets do not impose a retained row cardinality ceiling" {
    var value = plan();
    value.budgets.output_rows = std.math.maxInt(u64);
    value.budgets.work_steps = std.math.maxInt(u64);
    value.budgets.spill_bytes = 0;
    try value.validate();
    value.budgets.resident_bytes = 0;
    try testing.expectError(error.InvalidRelationalBudgets, value.validate());
    value = plan();
    value.budgets.source_pins = 1;
    try testing.expectError(error.InvalidRelationalBudgets, value.validate());
    value = plan();
    var too_many: [129]r.Output = @splat(outputs[0]);
    value.outputs = &too_many;
    try testing.expectError(error.InvalidRelationalOutputs, value.validate());
}

test "relational plan byte budget rejects a wide valid descriptor before fingerprinting" {
    var names: [128][32]u8 = @splat(@splat('n'));
    var wide_columns: [128]table.Column = undefined;
    var keys: [128]r.Column = undefined;
    var selections: [128]r.Output = undefined;
    for (0..128) |i| {
        names[i][0] = 'A' + @as(u8, @intCast(i / 26));
        names[i][1] = 'a' + @as(u8, @intCast(i % 26));
        wide_columns[i] = .{ .id = i + 1, .name = &names[i], .type = .int64 };
        keys[i] = .{ .source = 0, .id = i + 1 };
        selections[i] = .{ .name = &names[i], .expression = .{ .column = keys[i] } };
    }
    var declarations = sources;
    declarations[0].schema.columns = &wide_columns;
    declarations[0].schema.next_column = 129;
    var instructions: [2][63]r.Instruction = undefined;
    for (&instructions, 0..) |*program, source| {
        for (program[0..32]) |*instruction| instruction.* = .{ .compare = .{
            .column = .{ .source = @intCast(source), .id = 1 },
            .op = .equal,
            .value = 7,
        } };
        @memset(program[32..], .conjunction);
    }
    var value = plan();
    value.sources = &declarations;
    value.outputs = &selections;
    value.group_by = &keys;
    value.source_filters = .{ .{ .instructions = &instructions[0] }, .{ .instructions = &instructions[1] } };
    value.filter = .{ .instructions = &instructions[0] };
    try testing.expectError(error.RelationalPlanTooLarge, value.validate());
    try testing.expectError(error.RelationalPlanTooLarge, value.fingerprint());
    value.outputs = selections[0..64];
    value.group_by = keys[0..64];
    try value.validate();
    _ = try value.fingerprint();
}
