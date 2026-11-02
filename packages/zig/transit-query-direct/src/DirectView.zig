//! Expansion of an accepted single-Table view. Text is never an execution input.
//! The source scan applies the view predicate before the outer plan evaluates.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const c = q.catalog;
const Self = @This();
stored: c.CatalogDefinition.Stored,
schema: f.TableSchema.Owned,
plan: f.LogicalPlanCodec.Owned,
pub fn deinit(self: *Self) void {
    self.plan.deinit();
    self.schema.deinit();
    self.* = undefined;
}
fn column(projection: []const u8, ordinal: u8) !u8 {
    if (ordinal >= projection.len) return error.InvalidCatalogDescriptor;
    return projection[ordinal];
}
fn atom(projection: []const u8, value: f.LogicalQuery.Plan.Atom) !f.LogicalQuery.Plan.Atom {
    return switch (value) {
        .all => .all,
        inline else => |input, tag| blk: {
            var result = input;
            result.column = try column(projection, input.column);
            break :blk @unionInit(f.LogicalQuery.Plan.Atom, @tagName(tag), result);
        },
    };
}
/// Owns all remapped fields/literals. View filtering stays in the source stage:
/// merging it with the outer Boolean program could expose errors in rows that
/// the view already excluded.
pub fn expand(self: *const Self, allocator: std.mem.Allocator, outer: f.LogicalQuery.Plan) !f.LogicalPlanCodec.Owned {
    try outer.validate();
    const base = self.plan.plan;
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    if (!try (try self.schema.schema.rowType(&fields)).eql(outer.schema)) return error.InvalidCatalogDescriptor;
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const arena = scratch.allocator();
    var result = outer;
    result.schema = base.schema;
    result.collations = base.collations;
    const projection = try arena.alloc(u8, outer.projection.len);
    for (outer.projection, projection) |index, *out| out.* = if (index < outer.schema.structure.len) try column(base.projection, index) else @intCast(base.schema.structure.len + index - outer.schema.structure.len);
    result.projection = projection;
    const output = try outer.outputSchema(&fields);
    const names = try arena.alloc(?[]const u8, output.structure.len);
    for (output.structure, names) |field, *name| name.* = field.name;
    result.output_names = names;
    const scalars = try arena.dupe(f.ScalarProgram.Instruction, outer.scalars.instructions);
    for (scalars) |*instruction| if (instruction.* == .input) {
        instruction.input = try column(base.projection, instruction.input);
    };
    result.scalars.instructions = scalars;
    result.predicate = switch (outer.predicate) {
        .program => |program| blk: {
            const instructions = try arena.dupe(f.LogicalPredicate.Program.Instruction, program.instructions);
            for (instructions) |*instruction| if (instruction.* == .atom) {
                instruction.atom = try atom(base.projection, instruction.atom);
            };
            break :blk .{ .program = .{ .instructions = instructions } };
        },
        inline else => |value, tag| @unionInit(@FieldType(f.LogicalQuery.Plan, "predicate"), @tagName(tag), @field(try atom(base.projection, @unionInit(f.LogicalQuery.Plan.Atom, @tagName(tag), value)), @tagName(tag))),
    };
    var bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    return f.LogicalPlanCodec.decode(allocator, base.schema, result.source_basis, try f.LogicalPlanCodec.encode(result, &bytes));
}

test "accepted view expansion preserves output names and remaps predicate and aggregate ordinals" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const base_schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 4, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64 }, .{ .id = 2, .name = "unused", .type = .utf8 }, .{ .id = 3, .name = "amount", .type = .int64 } } };
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const base: f.LogicalQuery.Plan = .{ .schema = try base_schema.rowType(&fields), .source_basis = @splat(1), .projection = &.{2}, .output_names = &.{"total"}, .predicate = .{ .compare = .{ .column = 0, .op = .gt, .value = .{ .signed = 5 } } } };
    var encoded: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    var view: Self = .{ .stored = undefined, .schema = try (f.TableSchema.Schema{ .object = 2, .revision = 1, .next_column = 12, .columns = &.{.{ .id = 11, .name = "total", .type = .int64 }} }).clone(t.allocator), .plan = try f.LogicalPlanCodec.decode(t.allocator, base.schema, base.source_basis, try f.LogicalPlanCodec.encode(base, &encoded)) };
    defer view.deinit();
    var template = try f.LogicalPrepared.init(a, "SELECT total FROM selected WHERE total > $1", "selected", try view.schema.schema.rowType(&fields), @splat(2), null);
    defer template.deinit();
    var outer = try template.bind(a, "selected", template.descriptor.type, @splat(2), &.{.{ .signed = 10 }}, null);
    defer outer.deinit();
    var result = try view.expand(t.allocator, outer.plan);
    defer result.deinit();
    try t.expectEqualSlices(u8, &.{2}, result.plan.projection);
    try t.expectEqualStrings("total", (try result.plan.outputSchema(&fields)).structure[0].name);
    try t.expectEqual(@as(u8, 2), result.plan.predicate.compare.column);
    var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
    // The base filter must exclude this row before the outer predicate touches
    // its error cell. A conjunction of both predicates would change behavior.
    const rejected: [3]f.Types.Values.Cell = .{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = "unused" } } }, .{ .type_error = .int64 } };
    try t.expect(!try view.plan.plan.matches(&rejected, &failure));
    try t.expectError(error.QueryTypeError, result.plan.matches(&rejected, &failure));
    var aggregate = try f.TableSelect.compile(a, "SELECT SUM(total) FROM selected", "selected", template.descriptor.type, @splat(2), null);
    defer aggregate.deinit();
    var sum = try view.expand(t.allocator, aggregate.plan);
    defer sum.deinit();
    try t.expectEqual(.sum, sum.plan.aggregate);
    try t.expectEqual(@as(u8, 2), sum.plan.projection[0]);
    // A synthetic scalar output follows the base row's fields after expansion;
    // its input instruction still names the original projected source column.
    var scalar = outer.plan;
    scalar.scalars = .{ .instructions = &.{.{ .input = 0 }} };
    scalar.projection = &.{1};
    scalar.output_names = &.{"copied"};
    var copied = try view.expand(t.allocator, scalar);
    defer copied.deinit();
    try t.expectEqual(@as(u8, 2), copied.plan.scalars.instructions[0].input);
    try t.expectEqualSlices(u8, &.{3}, copied.plan.projection);
    try t.expectEqualStrings("copied", (try copied.plan.outputSchema(&fields)).structure[0].name);
}
