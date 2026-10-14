const std = @import("std");
const f = @import("root.zig");
const e = std.testing;
const Atom = f.Types.Values.Atom;
const Cell = f.Types.Values.Cell;
const columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "name", .type = .utf8, .nullable = true },
    .{ .id = 3, .name = "total", .type = .uint64, .default = .{ .value = .{ .atom = .{ .unsigned = 7 } } } },
};
const schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 4, .columns = &columns, .primary_key = &.{1} };

fn owned(allocator: std.mem.Allocator) !void {
    var name = "Ada'; DELETE FROM people; ? $1".*;
    var template = try f.TableDmlPrepared.init(allocator, "INSERT INTO people (id, name, total) VALUES ($1, $2, DEFAULT), ($3, NULL, $4)", "people", schema, .transit, null);
    var live = true;
    defer if (live) template.deinit();
    try e.expectEqual(@as(usize, 4), template.parameterTypes().len);
    var bound = try template.bind(allocator, "people", schema, &.{ .{ .signed = 1 }, .{ .bytes = &name }, .{ .signed = 2 }, .{ .unsigned = std.math.maxInt(u64) } }, null);
    defer bound.deinit();
    template.deinit();
    live = false;
    @memset(&name, 0);
    const rows = bound.plan.action.insert;
    try e.expectEqualStrings("Ada'; DELETE FROM people; ? $1", rows[0][1].value.atom.bytes);
    try e.expectEqual(@as(u128, 7), rows[0][2].value.atom.unsigned);
    try e.expectEqual(Cell.null, rows[1][1]);
    try e.expectEqual(@as(u128, std.math.maxInt(u64)), rows[1][2].value.atom.unsigned);
}
test "prepared DML owns bindings and preserves defaults and full-width values" {
    try owned(e.allocator);
    try e.checkAllAllocationFailures(e.allocator, owned, .{});
}
test "prepared DML uses MySQL lexer positions without substituting quoted bytes" {
    var template = try f.TableDmlPrepared.init(e.allocator, "UPDATE `people` SET `name` = ? WHERE id = ? /* ? $4 */", "people", schema, .mysql, null);
    defer template.deinit();
    var bound = try template.bind(e.allocator, "people", schema, &.{ null, .{ .signed = 8 } }, null);
    defer bound.deinit();
    try e.expectEqual(Cell.null, bound.plan.action.update[0].value.cell);
    try e.expectEqual(@as(i128, 8), bound.plan.predicate.?.instructions[0].atom.compare.value.signed);
    try e.expectError(error.InvalidParameterIndex, f.TableDmlPrepared.init(e.allocator, "DELETE FROM people WHERE id = $1", "people", schema, .mysql, null));
    try e.expectError(error.ParameterGap, f.TableDmlPrepared.init(e.allocator, "DELETE FROM people WHERE id = $2", "people", schema, .transit, null));
    try e.expectError(error.ParameterTypeConflict, f.TableDmlPrepared.init(e.allocator, "UPDATE people SET name = $1 WHERE id = $1", "people", schema, .transit, null));
    try e.expectError(error.ParameterCountMismatch, template.bind(e.allocator, "people", schema, &.{null}, null));
    var changed = schema;
    changed.object = 2;
    try e.expectError(error.TableSchemaChanged, template.bind(e.allocator, "people", changed, &.{ null, .{ .signed = 8 } }, null));
}
test "NULL comparison retains unknown truth and eager failures through canonical plans" {
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const row_type = try schema.rowType(&fields);
    var template = try f.LogicalPrepared.init(e.allocator, "SELECT id FROM people WHERE NOT (id = $1) OR name = $2", "people", row_type, @splat(1), null);
    defer template.deinit();
    var bound = try template.bind(e.allocator, "people", row_type, @splat(1), &.{ null, .{ .bytes = "Ada" } }, null);
    defer bound.deinit();
    const program = bound.plan.predicate.program;
    const rows = [_][2]Cell{
        .{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = "Bob" } } } },
        .{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = "Ada" } } } },
    };
    try e.expectEqual(.unknown, try program.truth(row_type, &rows[0]));
    try e.expectEqual(.true_value, try program.truth(row_type, &rows[1]));
    try e.expectError(error.QueryTypeError, program.truth(row_type, &.{ .{ .type_error = .int64 }, rows[1][1] }));
    var update = try f.TableDmlPrepared.init(e.allocator, "UPDATE people SET name = $1 WHERE NOT (id = $2)", "people", schema, .transit, null);
    defer update.deinit();
    var intent = try update.bind(e.allocator, "people", schema, &.{ null, null }, null);
    defer intent.deinit();
    try e.expect(!try intent.plan.matches(&.{ rows[0][0], rows[0][1], .{ .value = .{ .atom = .{ .unsigned = 7 } } } }));
    try e.expect(intent.plan.predicate.?.instructions[0].atom == .null_compare);
}

test "NULL comparisons preserve all vector lane states without accessing values" {
    const k = @import("VectorKernel.zig");
    const states = [_]f.Types.State{ .value, .null, .missing, .type_error, .conflict };
    const details: [states.len]k.Detail = @splat(.none);
    const view: k.View = .{ .flat = .{ .type = .int64, .data = .states_only, .states = &states, .details = &details } };
    const operators = std.meta.tags(@import("Finite.zig").Comparison);
    for (operators) |op| {
        const kernel = k.Atom.bindType(.{ .null_compare = .{ .column = 0, .op = op } }, .int64);
        var outcomes: [states.len]k.Outcome = undefined;
        kernel.run(kernel, view, 0, &outcomes);
        for (outcomes[0..3]) |outcome| try e.expectEqual(@import("Finite.zig").Truth.unknown, outcome.truth);
        try e.expect(outcomes[3] == .type_error);
        try e.expect(outcomes[4] == .conflict);
    }
}

test "prepared NULL respects non-null constraints and LIMIT instead of applying defaults" {
    var insert = try f.TableDmlPrepared.init(e.allocator, "INSERT INTO people (id) VALUES ($1)", "people", schema, .transit, null);
    defer insert.deinit();
    try e.expectError(error.NullNotAllowed, insert.bind(e.allocator, "people", schema, &.{null}, null));
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const row_type = try schema.rowType(&fields);
    var select = try f.LogicalPrepared.initDialect(e.allocator, "SELECT `id` FROM `people` WHERE id = ? LIMIT ?", "people", row_type, @splat(1), null, .mysql);
    defer select.deinit();
    try e.expectError(error.NullLimitParameter, select.bind(e.allocator, "people", row_type, @splat(1), &.{ null, null }, null));
    var fresh = try select.instantiate(e.allocator, "people", row_type, @splat(1), @splat(2), &.{ null, .{ .unsigned = 0 } }, null);
    defer fresh.deinit();
    try e.expectEqual(@as([32]u8, @splat(2)), fresh.plan.source_basis);
    try e.expectError(error.SourceChanged, select.instantiate(e.allocator, "people", row_type, @splat(3), @splat(2), &.{ null, .{ .unsigned = 0 } }, null));
}
