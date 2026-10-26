//! Physical input columns for a finite Table plan. Column identities, names,
//! codecs and collations remain those of the exact original declaration.
const std = @import("std");
const table = @import("TableSchema.zig");
const logical = @import("LogicalQuery.zig");
const types = @import("Types.zig");
const collations = @import("QueryCollations.zig");
const Self = @This();

indices: [table.max_columns]u8 = undefined,
len: u8 = 0,

pub fn columns(self: *const Self) []const u8 {
    return self.indices[0..self.len];
}

/// Canonical increasing ordinals; full keys remain available to verify the
/// row directory independently of the caller's output projection.
pub fn init(schema: table.Schema, selected: []const u8) !Self {
    try schema.validate();
    const result = try fromColumns(selected);
    if (selected[selected.len - 1] >= schema.columns.len) return error.InvalidProjection;
    for (schema.primary_key) |id| {
        const index: u8 = @intCast(try schema.index(id));
        if (std.mem.indexOfScalar(u8, selected, index) == null) return error.InvalidProjection;
    }
    return result;
}

/// Shape admission before a source's exact declaration is acquired.
pub fn fromColumns(selected: []const u8) !Self {
    if (selected.len == 0 or selected.len > table.max_columns) return error.InvalidProjection;
    for (selected, 0..) |index, i| {
        if (index >= table.max_columns or (i != 0 and selected[i - 1] >= index)) return error.InvalidProjection;
    }
    var result: Self = .{ .len = @intCast(selected.len) };
    @memcpy(result.indices[0..selected.len], selected);
    return result;
}

pub fn fromPlan(schema: table.Schema, plan: logical.Plan) !Self {
    try plan.validate();
    var fields: [table.max_columns]types.Field = undefined;
    if (!std.mem.eql(u8, &try (try schema.rowType(&fields)).fingerprint(), &try plan.schema.fingerprint()) or
        !std.meta.eql(plan.collations, collations.fromTable(schema))) return error.SourceChanged;
    var needed: [table.max_columns]bool = @splat(false);
    for (schema.primary_key) |id| needed[try schema.index(id)] = true;
    for (plan.projection) |index| needed[index] = true;
    switch (plan.predicate) {
        .program => |program| for (program.instructions) |instruction| {
            if (instruction == .atom) needAtom(&needed, instruction.atom);
        },
        inline else => |value, tag| needAtom(&needed, @unionInit(logical.Plan.Atom, @tagName(tag), value)),
    }
    var result: Self = .{};
    for (needed[0..schema.columns.len], 0..) |required, index| if (required) {
        result.indices[result.len] = @intCast(index);
        result.len += 1;
    };
    return init(schema, result.columns());
}

fn needAtom(needed: *[table.max_columns]bool, atom: logical.Plan.Atom) void {
    switch (atom) {
        .all => {},
        inline else => |value| needed[value.column] = true,
    }
}

pub fn ordinal(self: *const Self, original: u8) !u8 {
    return @intCast(std.mem.indexOfScalar(u8, self.columns(), original) orelse return error.InvalidProjection);
}

/// Bind continuation to both the retained source and physical column set.
pub fn cursorSource(self: *const Self, source: @import("transit_protocol").DataLifecycle.Content) !@import("transit_protocol").DataLifecycle.Content {
    try source.validate();
    if (self.len == 0 or self.len > table.max_columns) return error.InvalidProjection;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    const domain = "transit.table.projected-cursor.v1\x00";
    hash.update(domain);
    hash.update(&@import("transit_protocol").Growth.definition_bytes);
    var size: [8]u8 = undefined;
    std.mem.writeInt(u64, &size, source.bytes, .little);
    hash.update(&size);
    hash.update(&source.sha256);
    hash.update(&.{self.len});
    hash.update(self.columns());
    return .{ .bytes = domain.len + 32 + 8 + 32 + 1 + @as(u64, self.len), .sha256 = hash.finalResult() };
}

/// The result borrows both the original schema and the supplied column buffer.
/// It describes a read representation, never an independently accepted Table.
pub fn projectedSchema(self: *const Self, original: table.Schema, output: *[table.max_columns]table.Column) !table.Schema {
    _ = try init(original, self.columns());
    for (self.columns(), output[0..self.len]) |index, *column| column.* = original.columns[index];
    var result = original;
    result.columns = output[0..self.len];
    try result.validate();
    return result;
}

pub const Workspace = struct {
    columns: [table.max_columns]table.Column = undefined,
    fields: [table.max_columns]types.Field = undefined,
    outputs: [table.max_columns]u8 = undefined,
    instructions: [logical.Program.max_instructions]logical.Program.Instruction = undefined,
};

/// Remap execution inputs only. Hosts retain the original plan fingerprint for
/// public attribution; this private plan borrows workspace and original names.
pub fn remap(self: *const Self, original: table.Schema, plan: logical.Plan, work: *Workspace) !logical.Plan {
    const required = try fromPlan(original, plan);
    for (required.columns()) |index| _ = try self.ordinal(index);
    const projected = try self.projectedSchema(original, &work.columns);
    var result = plan;
    result.schema = try projected.rowType(&work.fields);
    result.collations = collations.fromTable(projected);
    for (plan.projection, work.outputs[0..plan.projection.len]) |index, *out| out.* = try self.ordinal(index);
    result.projection = work.outputs[0..plan.projection.len];
    result.predicate = switch (plan.predicate) {
        .program => |program| blk: {
            for (program.instructions, work.instructions[0..program.instructions.len]) |instruction, *out| out.* = switch (instruction) {
                .atom => |atom| .{ .atom = try self.remapAtom(atom) },
                else => instruction,
            };
            break :blk .{ .program = .{ .instructions = work.instructions[0..program.instructions.len] } };
        },
        inline else => |value, tag| @unionInit(@FieldType(logical.Plan, "predicate"), @tagName(tag), @field(try self.remapAtom(@unionInit(logical.Plan.Atom, @tagName(tag), value)), @tagName(tag))),
    };
    try result.validate();
    return result;
}

fn remapAtom(self: *const Self, atom: logical.Plan.Atom) !logical.Plan.Atom {
    return switch (atom) {
        .all => .all,
        inline else => |value, tag| blk: {
            var mapped = value;
            mapped.column = try self.ordinal(value.column);
            break :blk @unionInit(logical.Plan.Atom, @tagName(tag), mapped);
        },
    };
}

test "Table projection retains keys predicate inputs collation and named duplicate outputs" {
    const t = std.testing;
    const original: table.Schema = .{ .object = 7, .revision = 1, .next_column = 6, .primary_key = &.{1}, .columns = &.{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
        .{ .id = 2, .name = "unused", .type = .binary },
        .{ .id = 3, .name = "name", .type = .utf8, .collation = .ascii_ci },
        .{ .id = 4, .name = "unused_too", .type = .int64 },
        .{ .id = 5, .name = "score", .type = .int64 },
    } };
    var fields: [table.max_columns]types.Field = undefined;
    const plan: logical.Plan = .{ .schema = try original.rowType(&fields), .source_basis = @splat(17), .collations = collations.fromTable(original), .projection = &.{ 4, 4 }, .output_names = &.{ "a", "b" }, .limit = 1, .predicate = .{ .program = .{ .instructions = &.{
        .{ .atom = .{ .compare = .{ .column = 2, .op = .eq, .value = .{ .bytes = "aLPHa" } } } },
        .{ .atom = .{ .state = .{ .column = 4, .value = .value } } },
        .conjunction,
    } } } };
    const selected = try fromPlan(original, plan);
    try t.expectEqualSlices(u8, &.{ 0, 2, 4 }, selected.columns());
    var work: Workspace = .{};
    const mapped = try selected.remap(original, plan, &work);
    try t.expectEqualSlices(u8, &.{ 2, 2 }, mapped.projection);
    try t.expectEqual(.ascii_ci, mapped.collations.columns[1]);
    try t.expectEqualDeep(plan.source_basis, mapped.source_basis);
    try t.expectEqual(plan.limit, mapped.limit);
    var original_out: [table.max_columns]types.Field = undefined;
    var mapped_out: [table.max_columns]types.Field = undefined;
    try t.expectEqualDeep(try (try plan.outputSchema(&original_out)).fingerprint(), try (try mapped.outputSchema(&mapped_out)).fingerprint());
    const full = [_]types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .null, .{ .value = .{ .atom = .{ .bytes = "Alpha" } } }, .null, .{ .value = .{ .atom = .{ .signed = 9 } } } };
    const partial = [_]types.Values.Cell{ full[0], full[2], full[4] };
    var failure: ?logical.Plan.PredicateFailure = null;
    try t.expectEqual(try plan.matches(&full, &failure), try mapped.matches(&partial, &failure));
    var changed = partial;
    changed[1] = .{ .type_error = .int64 };
    try t.expectError(error.QueryTypeError, mapped.matches(&changed, &failure));
    try t.expectEqual(@as(u8, 1), failure.?.column);
    try t.expectEqual(@as(u8, 0), failure.?.instruction);
    try t.expectError(error.InvalidProjection, init(original, &.{ 2, 4 }));
    try t.expectError(error.InvalidProjection, init(original, &.{ 0, 4, 2 }));
    try t.expectError(error.InvalidProjection, init(original, &.{ 0, 0, 2 }));
}
