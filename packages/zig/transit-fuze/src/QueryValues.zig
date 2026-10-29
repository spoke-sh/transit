//! Deterministic neutral query columns, values, predicates and plans.
//! No source acquisition, publication, credentials, transport or scheduling.
//! Composite conversions use the caller's operation arena. Column admission
//! borrows names/descriptors; Plan.native and foreign projections detach values.
const std = @import("std");
const f = @import("root.zig");
const m = f.Unified;
const types = f.Types;
const j = f.LogicalJson;
const Allocator = std.mem.Allocator;
const encoding = f.NeutralEncoding;
pub const unsigned = encoding.unsigned;
pub const unhex = encoding.unhex;
pub const decimal = encoding.decimal;
pub const hex = encoding.hex;
pub const maximum_json_bytes = @import("transit_protocol").max_body;
/// A logical type level uses several JSON containers (field, descriptor and
/// child collection). The wrapper budget admits all 16 logical levels while
/// bounding recursive typed decoding before its first allocation.
pub const json_limits: types.Json.Limits = .{ .bytes = maximum_json_bytes, .depth = 96, .tokens = maximum_json_bytes + 1 };
pub fn preflight(bytes: []const u8) !void {
    try types.Json.preflight(bytes, json_limits);
}
pub fn parse(comptime T: type, allocator: Allocator, bytes: []const u8) !std.json.Parsed(T) {
    try preflight(bytes);
    return std.json.parseFromSlice(T, allocator, bytes, .{});
}

pub const Column = struct {
    name: []const u8,
    type: types.Type,
    nullable: bool = false,
    optional: bool = false,
    pub fn native(self: Column) !types.Field {
        const field: types.Field = .{ .name = self.name, .type = self.type, .nullable = self.nullable, .optional = self.optional };
        try (types.Type{ .structure = &.{field} }).validate(.{});
        return field;
    }
    pub fn fromNative(alloc: Allocator, value: types.Field) !Column {
        return .{ .name = try alloc.dupe(u8, value.name), .type = try value.type.cloneInto(alloc), .nullable = value.nullable, .optional = value.optional };
    }
};
pub fn columns(alloc: Allocator, values: []const Column) !types.Type {
    if (values.len == 0 or values.len > f.TableSchema.max_columns) return error.InvalidColumnCount;
    const items = try alloc.alloc(types.Field, values.len);
    for (items, values) |*out, in| out.* = try in.native();
    const schema: types.Type = .{ .structure = items };
    try schema.validate(.{});
    return schema;
}
pub fn foreignColumns(alloc: Allocator, schema: types.Type) ![]const Column {
    try schema.validate(.{});
    if (schema != .structure) return error.InvalidQuerySchema;
    const items = try alloc.alloc(Column, schema.structure.len);
    for (items, schema.structure) |*out, in| out.* = try Column.fromNative(alloc, in);
    return items;
}
pub const Scalar = j.Atom;
pub const scalar = j.atomFromForeign;
pub const foreignScalar = j.atomToForeign;

pub const PredicateAtom = union(enum) {
    all,
    state: struct { column: u8, value: types.State },
    compare: struct { column: u8, op: m.Plan.Comparison, value: Scalar },
    null_compare: struct { column: u8, op: m.Plan.Comparison },
    pub fn native(self: PredicateAtom, alloc: Allocator, schema: types.Type) !f.LogicalQuery.Plan.Atom {
        const atom: f.LogicalQuery.Plan.Atom = switch (self) {
            .all => .all,
            .state => |v| .{ .state = .{ .column = v.column, .value = v.value } },
            .null_compare => |v| .{ .null_compare = .{ .column = v.column, .op = v.op } },
            .compare => |v| blk: {
                if (schema != .structure or v.column >= schema.structure.len) return error.UnknownColumn;
                break :blk .{ .compare = .{ .column = v.column, .op = v.op, .value = try scalar(alloc, v.value, schema.structure[v.column].type) } };
            },
        };
        try atom.validate(schema);
        return atom;
    }
    pub fn fromNative(alloc: Allocator, value: f.LogicalQuery.Plan.Atom, schema: types.Type) !PredicateAtom {
        try value.validate(schema);
        return switch (value) {
            .all => .all,
            .state => |v| .{ .state = .{ .column = v.column, .value = v.value } },
            .compare => |v| .{ .compare = .{ .column = v.column, .op = v.op, .value = try foreignScalar(alloc, v.value, schema.structure[v.column].type) } },
            .null_compare => |v| .{ .null_compare = .{ .column = v.column, .op = v.op } },
        };
    }
};
pub const PredicateInstruction = union(enum) { atom: PredicateAtom, negate, conjunction, disjunction };
pub const Predicate = union(enum) {
    pub const json_schema_sequence_bounds = .{ .program = f.LogicalPredicate.Program.max_instructions };
    all,
    state: @FieldType(PredicateAtom, "state"),
    compare: @FieldType(PredicateAtom, "compare"),
    null_compare: @FieldType(PredicateAtom, "null_compare"),
    program: []const PredicateInstruction,
    pub fn native(self: Predicate, alloc: Allocator, schema: types.Type) !@FieldType(f.LogicalQuery.Plan, "predicate") {
        return switch (self) {
            .program => |instructions| blk: {
                if (instructions.len == 0) return error.InvalidPredicateProgram;
                if (instructions.len > f.LogicalPredicate.Program.max_instructions) return error.PredicateTooLarge;
                const owned = try alloc.alloc(f.LogicalPredicate.Program.Instruction, instructions.len);
                for (instructions, owned) |instruction, *out| out.* = switch (instruction) {
                    .atom => |atom| .{ .atom = try atom.native(alloc, schema) },
                    inline else => |_, tag| @unionInit(f.LogicalPredicate.Program.Instruction, @tagName(tag), {}),
                };
                const program: f.LogicalPredicate.Program = .{ .instructions = owned };
                try program.validate(schema);
                break :blk .{ .program = program };
            },
            inline else => |value, tag| switch (try @as(PredicateAtom, @unionInit(PredicateAtom, @tagName(tag), value)).native(alloc, schema)) {
                inline else => |atom_value, atom_tag| @unionInit(@FieldType(f.LogicalQuery.Plan, "predicate"), @tagName(atom_tag), atom_value),
            },
        };
    }
    pub fn fromNative(alloc: Allocator, value: @FieldType(f.LogicalQuery.Plan, "predicate"), schema: types.Type) !Predicate {
        return switch (value) {
            .program => |program| blk: {
                try program.validate(schema);
                const result = try alloc.alloc(PredicateInstruction, program.instructions.len);
                for (program.instructions, result) |instruction, *out| out.* = switch (instruction) {
                    .atom => |atom| .{ .atom = try PredicateAtom.fromNative(alloc, atom, schema) },
                    inline else => |_, tag| @unionInit(PredicateInstruction, @tagName(tag), {}),
                };
                break :blk .{ .program = result };
            },
            inline else => |atom_value, atom_tag| switch (try PredicateAtom.fromNative(alloc, @unionInit(f.LogicalQuery.Plan.Atom, @tagName(atom_tag), atom_value), schema)) {
                inline else => |v, tag| @unionInit(Predicate, @tagName(tag), v),
            },
        };
    }
};
pub const Plan = struct {
    pub const json_schema_sequence_bounds = .{ .collations = f.TableSchema.max_columns };
    /// Null selects binary comparison; Table bundles still require exact source semantics.
    collations: ?[]const f.TableSchema.Collation = null,
    version: u8 = 1,
    projection: []const u32,
    output_names: ?[]const ?[]const u8 = null,
    limit: ?[]const u8 = null,
    aggregate: m.Plan.Aggregate = .rows,
    predicate: Predicate = .all,
    pub fn native(self: Plan, alloc: Allocator, schema: types.Type, binding: [32]u8) !f.LogicalQuery.Plan {
        if (self.version != 1) return error.UnsupportedPlan;
        if (self.projection.len == 0 or self.projection.len > f.TableSchema.max_columns) return error.InvalidProjection;
        const selected = try alloc.alloc(u8, self.projection.len);
        for (selected, self.projection) |*out, in| {
            if (in >= f.TableSchema.max_columns) return error.UnknownColumn;
            out.* = @intCast(in);
        }
        const names = if (self.output_names) |input| owned: {
            if (input.len != selected.len) return error.InvalidOutputNames;
            const result = try alloc.dupe(?[]const u8, input);
            for (result) |*name| if (name.*) |text| {
                name.* = try alloc.dupe(u8, text);
            };
            break :owned result;
        } else &.{};
        const result: f.LogicalQuery.Plan = .{ .schema = try schema.cloneInto(alloc), .source_basis = binding, .collations = if (self.collations) |columns_| try f.QueryCollations.fromSlice(schema, columns_) else .{}, .projection = selected, .output_names = names, .limit = if (self.limit) |v| try unsigned(v) else null, .aggregate = self.aggregate, .predicate = try self.predicate.native(alloc, schema) };
        try result.validate();
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: f.LogicalQuery.Plan) !Plan {
        try value.validate();
        const names: ?[]?[]const u8 = if (value.output_names.len != 0) try alloc.alloc(?[]const u8, value.projection.len) else null;
        if (names) |output| for (output, value.output_names) |*out, name| {
            out.* = if (name) |text| try alloc.dupe(u8, text) else null;
        };
        const selected = try alloc.alloc(u32, value.projection.len);
        for (selected, value.projection) |*out, in| out.* = in;
        return .{ .collations = try alloc.dupe(f.TableSchema.Collation, value.collations.columns[0..value.schema.structure.len]), .projection = selected, .output_names = names, .limit = if (value.limit) |v| try decimal(alloc, v) else null, .aggregate = value.aggregate, .predicate = try Predicate.fromNative(alloc, value.predicate, value.schema) };
    }
};

pub const Alternative = j.Alternative;
pub const Cell = j.Cell;
pub const foreignCell = j.foreignCell;
pub fn rows(alloc: Allocator, decoded: *const f.LogicalInspect.Batch) ![]const []const Cell {
    const result = try alloc.alloc([]const Cell, decoded.rows.len);
    for (result, decoded.rows) |*out, row| {
        const cells = try alloc.alloc(Cell, row.cells.len);
        for (cells, row.cells, decoded.descriptor.type.structure) |*cell, value, field| cell.* = try foreignCell(alloc, value, field.type);
        out.* = cells;
    }
    return result;
}

test "neutral JSON admits full logical descriptor depth and owns recursive parse storage" {
    const Run = struct {
        fn run(allocator: Allocator) !void {
            // Sixteen logical levels: row structure, fourteen array descriptors
            // and the leaf. Each array has three JSON object wrappers.
            var descriptors: [15]types.Type = undefined;
            descriptors[0] = .int128;
            for (1..descriptors.len) |i| descriptors[i] = .{ .array = .{ .element = .{ .type = &descriptors[i - 1] }, .length = 1 } };
            const schema: types.Type = .{ .structure = &.{.{ .name = "nested", .type = descriptors[14] }} };
            try schema.validate(.{});
            const original = [_]Column{.{ .name = "record", .type = schema }};
            const encoded = try std.json.Stringify.valueAlloc(allocator, original, .{});
            defer allocator.free(encoded);
            const decoded = try parse([]const Column, allocator, encoded);
            defer decoded.deinit();
            try std.testing.expect(try schema.eql(decoded.value[0].type));
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{});
}

test "neutral plans own schema and output names across every allocation failure" {
    const Run = struct {
        fn run(allocator: Allocator) !void {
            var arena: std.heap.ArenaAllocator = .init(allocator);
            defer arena.deinit();
            var original_name = "original".*;
            var output_name = "renamed".*;
            var fields = [_]types.Field{.{ .name = &original_name, .type = .utf8 }};
            var names = [_]?[]const u8{&output_name};
            const plan = try (Plan{ .projection = &.{0}, .output_names = &names }).native(arena.allocator(), .{ .structure = &fields }, @splat(7));
            @memset(&original_name, 'x');
            @memset(&output_name, 'x');
            fields[0].type = .int64;
            names[0] = null;
            try std.testing.expectEqualStrings("original", plan.schema.structure[0].name);
            try std.testing.expectEqualStrings("renamed", plan.output_names[0].?);
            try std.testing.expect(plan.schema.structure[0].type == .utf8);
            try plan.validate();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{});
}
