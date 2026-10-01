//! Test-only public-package consumer. AST reporting, durable codec round trips
//! and actual Arrow execution share no reference-parser implementation.
const std = @import("std");
const f = @import("transit_fuze");
const sql = f.Sql;
const m = f.Unified;
const q = @import("transit_query");
const Case = struct {
    id: []const u8,
    sql: []const u8,
    schema: struct { name: []const u8, columns: [2][]const u8, type: m.Type } = .{ .name = "items", .columns = .{ "id", "value" }, .type = .int64 },
    parameters: ?[]const q.Values.Scalar = null,
};
fn writeColumn(out: anytype, column: *const sql.Column) !void {
    try out.write([2]?[]const u8{ if (column.qualifier) |*name| name.slice() else null, column.name.slice() });
}
fn writeProjection(out: anytype, projection: *const sql.Projection) !void {
    if (projection[0] == null) return out.write(null);
    try out.beginArray();
    for (projection) |*column| if (column.*) |*value| {
        try out.beginObject();
        try out.objectField("column");
        try writeColumn(out, &value.column);
        try out.objectField("alias");
        try out.write(if (value.alias) |*name| name.slice() else @as(?[]const u8, null));
        try out.endObject();
    };
    try out.endArray();
}
fn writeAtom(out: anytype, atom: *const sql.PredicateAtom, parameter: ?u32) !void {
    switch (atom.*) {
        .all => try out.write(null),
        .state => |*state| {
            try out.beginObject();
            try out.objectField("column");
            try writeColumn(out, &state.column);
            try out.objectField("op");
            try out.write(switch (state.value) {
                .null => "is_null",
                .missing => "is_missing",
                .type_error => "is_type_error",
                .value => "is_value",
                .conflict => "is_conflict",
            });
            try out.endObject();
        },
        .compare => |*comparison| {
            try out.beginObject();
            try out.objectField("column");
            try writeColumn(out, &comparison.column);
            try out.objectField("op");
            try out.write(@tagName(comparison.op));
            try out.objectField("literal");
            try out.beginObject();
            try out.objectField("kind");
            try out.write(if (parameter != null) "parameter" else @tagName(comparison.literal));
            try out.objectField("value");
            if (parameter) |index| try out.write(index) else switch (comparison.literal) {
                .null => try out.write(null),
                inline .int64, .uint64, .float64 => |value| try out.write(value),
                .boolean => |value| try out.write(value),
                .utf8, .binary => |*value| try out.write(value.slice()),
            }
            try out.endObject();
            try out.endObject();
        },
    }
}
const AstView = struct {
    ast: sql.Ast,
    parameters: sql.ParameterSites = .{},
    pub fn jsonStringify(self: *const AstView, out: anytype) !void {
        const ast = &self.ast;
        try out.beginObject();
        try out.objectField("source");
        try out.write(ast.source.slice());
        try out.objectField("source_alias");
        try out.write(if (ast.source_alias) |*name| name.slice() else @as(?[]const u8, null));
        try out.objectField("output_alias");
        try out.write(if (ast.output_alias) |*name| name.slice() else @as(?[]const u8, null));
        try out.objectField("selection");
        try out.beginObject();
        try out.objectField("kind");
        try out.write(@tagName(ast.selection));
        switch (ast.selection) {
            .rows => |*projection| {
                try out.objectField("columns");
                try writeProjection(out, projection);
            },
            .sum, .count_values => |*column| {
                try out.objectField("column");
                try writeColumn(out, column);
            },
            .count => {},
        }
        try out.endObject();
        try out.objectField("predicate");
        switch (ast.predicate) {
            .program => |*program| {
                try out.beginObject();
                try out.objectField("op");
                try out.write("program");
                try out.objectField("instructions");
                try out.beginArray();
                for (program.instructions[0..program.count]) |instruction| switch (instruction) {
                    .atom => |atom| try writeAtom(out, &(program.expand(atom) catch unreachable), null),
                    else => {
                        try out.beginObject();
                        try out.objectField("op");
                        try out.write(switch (instruction) {
                            .negate => "not",
                            .conjunction => "and",
                            .disjunction => "or",
                            .atom => unreachable,
                        });
                        try out.endObject();
                    },
                };
                try out.endArray();
                try out.endObject();
            },
            inline else => |value, tag| try writeAtom(out, &@as(sql.PredicateAtom, @unionInit(sql.PredicateAtom, @tagName(tag), value)), self.parameters.comparison),
        }
        try out.objectField("limit");
        if (self.parameters.limit) |index| try out.write(.{ .parameter = index }) else try out.write(ast.limit);
        try out.objectField("input");
        if (ast.input) |*input| {
            try out.beginObject();
            try out.objectField("projection");
            try writeProjection(out, &input.projection);
            try out.objectField("limit");
            if (self.parameters.input_limit) |index| try out.write(.{ .parameter = index }) else try out.write(input.limit);
            try out.objectField("alias");
            try out.write(input.alias.slice());
            try out.endObject();
        } else try out.write(null);
        try out.endObject();
    }
};
const PlanOwner = union(enum) {
    ordinary: m.Plan,
    bound: f.Prepared.Bound,
    fn plan(self: *const PlanOwner) m.Plan {
        return switch (self.*) {
            .ordinary => |value| value,
            .bound => |value| value.plan,
        };
    }
    fn deinit(self: *PlanOwner) void {
        if (self.* == .bound) self.bound.deinit();
    }
};
fn compile(allocator: std.mem.Allocator, case: Case, ast: sql.Ast, source: m.Sql.Source) !PlanOwner {
    if (case.parameters) |values| {
        var prepared = try f.Prepared.init(allocator, case.sql, source);
        defer prepared.deinit();
        if (values.len > f.Prepared.max_parameters) return error.ParameterCountMismatch;
        var scalars: [f.Prepared.max_parameters]m.Scalar = undefined;
        for (values, scalars[0..values.len]) |value, *scalar| scalar.* = try value.native(allocator);
        return .{ .bound = try prepared.bind(allocator, source, scalars[0..values.len]) };
    }
    return .{ .ordinary = try m.Sql.compile(allocator, ast, source) };
}
fn parse(case: Case) !sql.TemplateAst {
    return if (case.parameters != null) try sql.parseTemplate(case.sql, null) else .{ .ast = try sql.parse(case.sql), .parameters = .{} };
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.Usage;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(2 * 1024 * 1024));
    defer init.gpa.free(bytes);
    const cases = try std.json.parseFromSlice([]const Case, init.gpa, bytes, .{ .ignore_unknown_fields = true });
    defer cases.deinit();
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases.value, 0..) |case, index| {
        const parsed = parse(case) catch |err| {
            try std.json.Stringify.value(.{ .id = case.id, .parse_error = @errorName(err) }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
            continue;
        };
        const ast_view: AstView = .{ .ast = parsed.ast, .parameters = parsed.parameters };
        const columns = [_]m.Column{
            .{ .name = try m.Name.init(case.schema.columns[0]), .type = .int64 },
            .{ .name = try m.Name.init(case.schema.columns[1]), .type = case.schema.type },
        };
        const source: m.Sql.Source = .{ .name = try m.Name.init(case.schema.name), .schema = .{ .columns = &columns } };
        var owner = compile(init.arena.allocator(), case, parsed.ast, source) catch |err| {
            try std.json.Stringify.value(.{ .id = case.id, .ast = ast_view, .compile_error = @errorName(err) }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
            continue;
        };
        defer owner.deinit();
        const plan = owner.plan();
        var encoded: [m.Codec.max_plan_bytes]u8 = undefined;
        const saved = try m.Codec.encode(plan, &encoded);
        var hex: [2 * m.Codec.max_plan_bytes]u8 = undefined;
        const alphabet = "0123456789abcdef";
        for (saved, 0..) |byte, i| {
            hex[2 * i] = alphabet[byte >> 4];
            hex[2 * i + 1] = alphabet[byte & 15];
        }
        const restored = try m.Codec.decode(saved);
        var canonical: [m.Codec.max_plan_bytes]u8 = undefined;
        if (!std.mem.eql(u8, saved, try m.Codec.encode(restored, &canonical))) return error.PlanRoundTrip;
        const segments = try execute(init, restored, source.schema, args[2], index);
        try std.json.Stringify.value(.{ .id = case.id, .ast = ast_view, .encoded = hex[0 .. 2 * saved.len], .segments = segments }, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
fn execute(init: std.process.Init, plan: m.Plan, schema: m.Schema, directory: []const u8, index: usize) !u64 {
    const bound = try plan.bind(.{ .kind = .table, .resource = 7, .revision = 9, .contract = @splat(7), .schema = try schema.fingerprint() }, schema);
    var progress: m.Stream.Progress = .start(bound);
    const workspace = try init.arena.allocator().alloc(u8, m.Arrow.working_bytes);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    var cells: [7][2]m.Cell = undefined;
    var rows: [7]m.Row = undefined;
    const cancellation = f.execution.Cancellation.init(false);
    var offset: usize = 0;
    while (progress.finished == null) {
        for (&rows, 0..) |*row, i| {
            const ordinal = offset + i;
            const value: m.Scalar = switch (schema.columns[1].type) {
                .int64 => .{ .int64 = @as(i64, @intCast(ordinal)) - 20 },
                .uint64 => .{ .uint64 = std.math.maxInt(u64) - ordinal },
                .float64 => .{ .float64 = if (ordinal == 0) -0.0 else @as(f64, @floatFromInt(ordinal)) + 0.5 },
                .boolean => .{ .boolean = ordinal % 2 == 0 },
                .utf8 => .{ .utf8 = if (ordinal % 2 == 0) "it's 東京" else "a\\b" },
                .binary => .{ .binary = if (ordinal % 2 == 0) &.{ 0, 255 } else "" },
            };
            cells[i] = .{ .{ .value = .{ .int64 = @as(i64, @intCast(ordinal)) - 35 } }, if (ordinal % 5 == 0) .null else .{ .value = value } };
            row.* = .{ .cells = &cells[i] };
        }
        const step = try m.Stream.step(bound, progress, .{ .ordinal = progress.pages, .basis = bound.basis, .rows = &rows, .end = offset + rows.len == 70 }, workspace, &output, &cancellation);
        if (step.segment) |segment| {
            var path: [4096]u8 = undefined;
            const name = try std.fmt.bufPrint(&path, "{s}/{d}-{d}.arrow", .{ directory, index, progress.segments });
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = name, .data = segment.bytes });
        }
        progress = try m.Stream.Progress.decode(&try step.progress.encode());
        offset += rows.len;
    }
    return progress.segments;
}
