//! Versioned foreign values around the shared v1 source/plan/Arrow model.
//! Integers wider than the protocol counter and float bits never pass as JSON
//! numbers. All returned byte strings belong to the supplied result allocator.
const std = @import("std");
pub const query = @import("root.zig");
const q = query;
const m = q.fuze.Unified;
const f = q.fuze;
const types = f.Types;
const j = f.LogicalJson;
const d = q.document.JsonValues;
const a = d;
const Allocator = std.mem.Allocator;
pub const maximum_json_bytes = q.protocol.max_body;
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
pub const unsigned = d.unsigned;
pub const unhex = d.unhex;
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
    if (values.len == 0 or values.len > q.SourceDefinition.max_columns) return error.InvalidColumnCount;
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
/// KV/Document decoding remains explicitly limited to its six scalar decoders.
pub const DecoderColumn = struct {
    name: []const u8,
    type: m.Type,
    pub fn native(self: DecoderColumn) !m.Column {
        return .{ .name = try m.Name.init(self.name), .type = self.type };
    }
    pub fn fromNative(alloc: Allocator, value: m.Column) !DecoderColumn {
        return .{ .name = try alloc.dupe(u8, value.name.slice()), .type = value.type };
    }
};
pub const Projection = struct {
    pub const json_schema_sequence_bounds = .{ .path = 8 };
    column: DecoderColumn,
    path: []const []const u8,
    relative: bool = false,
    mode: @FieldType(q.SourceDefinition.Projection, "mode") = .scalar,
    text_bytes: u16 = m.max_cell_bytes,
    text_steps: u16 = 4096,
};
fn path(alloc: Allocator, names: []const []const u8) ![]const q.document.Model.Name {
    if (names.len > 8) return error.InvalidQueryPath;
    const result = try alloc.alloc(q.document.Model.Name, names.len);
    for (result, names) |*out, in| out.* = try q.document.Model.Name.init(in);
    return result;
}
fn foreignPath(alloc: Allocator, names: []const q.document.Model.Name) ![]const []const u8 {
    const result = try alloc.alloc([]const u8, names.len);
    for (result, names) |*out, in| out.* = try alloc.dupe(u8, in.slice());
    return result;
}
pub const Source = struct {
    version: u8 = 1,
    resource: u64,
    source: union(enum) {
        kv: struct { prefix: []const u8, key: q.SourceDefinition.Decoder, value: q.SourceDefinition.Decoder },
        table: struct {
            scope: q.catalog.TableValues.Scope,
            owner: u64,
            object: []const u8,
            metadata: struct { id: []const u8, spec: q.station.Publication.Spec },
            row_type: types.Type,
        },
        document: struct {
            pub const json_schema_sequence_bounds = .{ .expand = 8, .projections = m.max_columns };
            reference: d.Reference,
            change_format: u32 = 1,
            expand: ?[]const []const u8 = null,
            projections: []const Projection,
        },
    },
    pub fn native(self: Source, alloc: Allocator) !q.SourceDefinition {
        const source: @FieldType(q.SourceDefinition, "source") = switch (self.source) {
            .kv => |v| .{ .kv = .{ .prefix = try q.protocol.Value.init(try unhex(alloc, v.prefix, q.protocol.Growth.key_bytes)), .key = v.key, .value = v.value } },
            .table => |v| .{ .table = .{ .scope = try v.scope.native(), .owner = v.owner, .object = try unsigned(v.object), .metadata = .{ .id = try unsigned(v.metadata.id), .spec = v.metadata.spec }, .row_type = try v.row_type.cloneInto(alloc) } },
            .document => |v| blk: {
                if (v.projections.len == 0 or v.projections.len > m.max_columns) return error.InvalidProjection;
                const projections = try alloc.alloc(q.SourceDefinition.Projection, v.projections.len);
                for (projections, v.projections) |*out, in| out.* = .{ .column = try in.column.native(), .path = try path(alloc, in.path), .relative = in.relative, .mode = in.mode, .text_bytes = in.text_bytes, .text_steps = in.text_steps };
                break :blk .{ .document = .{ .reference = try v.reference.native(), .change_format = v.change_format, .expand = if (v.expand) |names| try path(alloc, names) else null, .projections = projections } };
            },
        };
        const result: q.SourceDefinition = .{ .version = self.version, .resource = self.resource, .source = source };
        var storage: [q.SourceDefinition.max_columns]types.Field = undefined;
        _ = try result.schema(&storage);
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: q.SourceDefinition) !Source {
        return .{ .version = value.version, .resource = value.resource, .source = switch (value.source) {
            .kv => |v| .{ .kv = .{ .prefix = try a.hex(alloc, v.prefix.slice()), .key = v.key, .value = v.value } },
            .table => |v| .{ .table = .{ .scope = try q.catalog.TableValues.Scope.foreign(alloc, v.scope), .owner = v.owner, .object = try a.decimal(alloc, v.object), .metadata = .{ .id = try a.decimal(alloc, v.metadata.id), .spec = v.metadata.spec }, .row_type = try v.row_type.cloneInto(alloc) } },
            .document => |v| blk: {
                const projections = try alloc.alloc(Projection, v.projections.len);
                for (projections, v.projections) |*out, in| out.* = .{ .column = try DecoderColumn.fromNative(alloc, in.column), .path = try foreignPath(alloc, in.path), .relative = in.relative, .mode = in.mode, .text_bytes = in.text_bytes, .text_steps = in.text_steps };
                break :blk .{ .document = .{ .reference = try d.Reference.fromNative(alloc, v.reference), .change_format = v.change_format, .expand = if (v.expand) |names| try foreignPath(alloc, names) else null, .projections = projections } };
            },
        } };
    }
};
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
    version: u8 = 1,
    projection: []const u32,
    output_names: ?[]const ?[]const u8 = null,
    limit: ?[]const u8 = null,
    aggregate: m.Plan.Aggregate = .rows,
    predicate: Predicate = .all,
    pub fn native(self: Plan, alloc: Allocator, schema: types.Type, binding: [32]u8) !f.LogicalQuery.Plan {
        if (self.version != 1) return error.UnsupportedPlan;
        if (self.projection.len == 0 or self.projection.len > q.SourceDefinition.max_columns) return error.InvalidProjection;
        const selected = try alloc.alloc(u8, self.projection.len);
        for (selected, self.projection) |*out, in| {
            if (in >= q.SourceDefinition.max_columns) return error.UnknownColumn;
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
        const result: f.LogicalQuery.Plan = .{ .schema = try schema.cloneInto(alloc), .source_basis = binding, .projection = selected, .output_names = names, .limit = if (self.limit) |v| try unsigned(v) else null, .aggregate = self.aggregate, .predicate = try self.predicate.native(alloc, schema) };
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
        return .{ .projection = selected, .output_names = names, .limit = if (value.limit) |v| try a.decimal(alloc, v) else null, .aggregate = value.aggregate, .predicate = try Predicate.fromNative(alloc, value.predicate, value.schema) };
    }
};
pub const Limits = struct {
    pages: []const u8,
    segments: []const u8,
    result_bytes: []const u8,
    pub fn native(self: Limits) !q.Bundle.Limits {
        const result: q.Bundle.Limits = .{ .pages = try unsigned(self.pages), .segments = try unsigned(self.segments), .result_bytes = try unsigned(self.result_bytes) };
        try result.validate();
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: q.Bundle.Limits) !Limits {
        return .{ .pages = try a.decimal(alloc, value.pages), .segments = try a.decimal(alloc, value.segments), .result_bytes = try a.decimal(alloc, value.result_bytes) };
    }
};
pub const Bundle = struct {
    source: Source,
    plan: Plan,
    limits: Limits,
    pub fn native(self: Bundle, alloc: Allocator) !q.Bundle {
        const source = try self.source.native(alloc);
        var fields: [q.SourceDefinition.max_columns]types.Field = undefined;
        const schema = try (try source.schema(&fields)).cloneInto(alloc);
        const result: q.Bundle = .{ .source = source, .plan = try self.plan.native(alloc, schema, try source.fingerprint()), .limits = try self.limits.native() };
        try result.validate();
        return result;
    }
    pub fn fromNative(alloc: Allocator, value: q.Bundle) !Bundle {
        return .{ .source = try Source.fromNative(alloc, value.source), .plan = try Plan.fromNative(alloc, value.plan), .limits = try Limits.fromNative(alloc, value.limits) };
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
pub const Action = union(enum) {
    prepare: Bundle,
    decode: []const u8,
    source: Source,
    inspect_arrow: struct { columns: []const Column, rows: u8, ipc: []const u8 },
};
pub const Result = union(enum) {
    pub const json_schema_sequence_bounds = .{ .rows = q.SourceDefinition.max_columns };
    pub const json_schema_outer_sequence_bounds = .{ .rows = f.LogicalArrow.max_rows };
    prepared: struct { bytes: []const u8, spec: q.station.Publication.Spec },
    bundle: Bundle,
    source: struct { bytes: []const u8, digest: [32]u8, declaration: [32]u8, columns: []const Column },
    rows: []const []const Cell,
};
pub fn apply(alloc: Allocator, action: Action) !Result {
    switch (action) {
        .prepare => |v| {
            var buffer: [q.Bundle.max_bytes]u8 = undefined;
            const bytes = try (try v.native(alloc)).encode(&buffer);
            return .{ .prepared = .{ .bytes = try a.hex(alloc, bytes), .spec = try q.station.Publication.Digest.of(q.Bundle.format, bytes) } };
        },
        .decode => |v| return .{ .bundle = try Bundle.fromNative(alloc, try q.Bundle.decode(alloc, try unhex(alloc, v, q.Bundle.max_bytes))) },
        .source => |v| {
            const native = try v.native(alloc);
            var storage: [q.SourceDefinition.max_columns]types.Field = undefined;
            var buffer: [q.SourceDefinition.max_bytes]u8 = undefined;
            return .{ .source = .{ .bytes = try a.hex(alloc, try native.encode(&buffer)), .digest = try native.fingerprint(), .declaration = try q.Bundle.declaration(native), .columns = try foreignColumns(alloc, try native.schema(&storage)) } };
        },
        .inspect_arrow => |v| {
            const workspace = try alloc.alloc(u8, m.Arrow.working_bytes);
            var decoded = try f.LogicalInspect.decode(alloc, try columns(alloc, v.columns), try unhex(alloc, v.ipc, f.LogicalArrow.segment_bytes), v.rows, workspace);
            defer decoded.deinit();
            return .{ .rows = try rows(alloc, &decoded) };
        },
    }
}

test "neutral programs retain owned literals and exact bundle publication identity" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var literal = [_]u8{ 'o', 'k' };
    const bundle: Bundle = .{
        .source = .{ .resource = 7, .source = .{ .kv = .{ .prefix = "", .key = .{ .type = .binary }, .value = .{ .type = .utf8 } } } },
        .plan = .{ .projection = &.{1}, .output_names = &.{"label"}, .predicate = .{ .program = &.{
            .{ .atom = .{ .compare = .{ .column = 1, .op = .eq, .value = .{ .utf8 = &literal } } } },
            .negate,
            .{ .atom = .{ .state = .{ .column = 1, .value = .null } } },
            .disjunction,
        } } },
        .limits = .{ .pages = "100", .segments = "100", .result_bytes = "1048576" },
    };
    const prepared = (try apply(alloc, .{ .prepare = bundle })).prepared;
    var restored = (try apply(alloc, .{ .decode = prepared.bytes })).bundle;
    literal[0] = 'n';
    try t.expectEqualStrings("ok", restored.plan.predicate.program[0].atom.compare.value.utf8);
    const repeated = (try apply(alloc, .{ .prepare = restored })).prepared;
    try t.expectEqualStrings(prepared.bytes, repeated.bytes);
    try t.expectEqualDeep(prepared.spec, repeated.spec);
    restored.plan.predicate = .{ .program = &.{.conjunction} };
    try t.expectError(error.InvalidPredicateProgram, apply(alloc, .{ .prepare = restored }));
    restored.plan.predicate = .{ .program = &@as([65]PredicateInstruction, @splat(.negate)) };
    try t.expectError(error.PredicateTooLarge, apply(alloc, .{ .prepare = restored }));
    restored.plan.predicate = .{ .program = &.{ .{ .atom = .all }, .{ .atom = .{ .compare = .{ .column = 1, .op = .eq, .value = .{ .unsigned = "1" } } } }, .disjunction } };
    try t.expectError(error.TypeMismatch, apply(alloc, .{ .prepare = restored }));
    restored.plan.predicate = .{ .program = &.{ .{ .atom = .all }, .{ .atom = .{ .state = .{ .column = 2, .value = .null } } }, .disjunction } };
    try t.expectError(error.UnknownColumn, apply(alloc, .{ .prepare = restored }));
}

test "neutral JSON rejects recursive input before allocating and retains typed validation" {
    const t = std.testing;
    var no_memory = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    var bytes: [512]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try out.writeAll("{\"unknown\":");
    for (0..json_limits.depth) |_| try out.writeByte('[');
    for (0..json_limits.depth) |_| try out.writeByte(']');
    try out.writeByte('}');
    try t.expectError(error.JsonDepthExceeded, parse(q.Workspace.Request, no_memory.allocator(), out.buffered()));
    try t.expectError(error.InvalidUtf8, parse(q.Workspace.Request, no_memory.allocator(), "{\"compile\":{\"sql\":\"\xff\"}}"));
    try t.expectError(error.OutOfMemory, parse(q.Workspace.Request, no_memory.allocator(), "{\"compile\":{\"sql\":\"SELECT * FROM items\"}}"));
    try t.expectError(error.UnknownField, parse(q.Workspace.Request, t.allocator, "{\"compile\":{\"sql\":\"SELECT * FROM items\",\"extra\":[]}}"));
    try t.expectError(error.DuplicateField, parse(q.Workspace.Request, t.allocator, "{\"compile\":{\"sql\":\"SELECT * FROM items\",\"sql\":\"SELECT 1\"}}"));
    const oversized = try t.allocator.alloc(u8, maximum_json_bytes + 1);
    defer t.allocator.free(oversized);
    try t.expectError(error.JsonByteBudgetExceeded, parse(q.Workspace.Request, no_memory.allocator(), oversized));
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
