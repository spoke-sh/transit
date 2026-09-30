//! Test-only public-package consumer. AST reporting, durable codec round trips
//! and actual Arrow execution share no reference-parser implementation.
const std = @import("std");
const f = @import("transit_fuze");
const sql = f.Sql;
const m = f.Unified;
const Case = struct {
    id: []const u8,
    sql: []const u8,
    schema: struct { name: []const u8, columns: [2][]const u8, type: m.Type } = .{ .name = "items", .columns = .{ "id", "value" }, .type = .int64 },
};
fn writeColumn(out: anytype, column: *const sql.Column) !void {
    try out.write([2]?[]const u8{ if (column.qualifier) |*name| name.slice() else null, column.name.slice() });
}
fn writeProjection(out: anytype, projection: *const sql.Projection) !void {
    if (projection[0] == null) return out.write(null);
    try out.beginArray();
    for (projection) |*column| if (column.*) |*value| try writeColumn(out, value);
    try out.endArray();
}
const AstView = struct {
    ast: sql.Ast,
    pub fn jsonStringify(self: *const AstView, out: anytype) !void {
        const ast = &self.ast;
        try out.beginObject();
        try out.objectField("source");
        try out.write(ast.source.slice());
        try out.objectField("source_alias");
        try out.write(if (ast.source_alias) |*name| name.slice() else @as(?[]const u8, null));
        try out.objectField("selection");
        try out.beginObject();
        try out.objectField("kind");
        try out.write(@tagName(ast.selection));
        switch (ast.selection) {
            .rows => |*projection| {
                try out.objectField("columns");
                try writeProjection(out, projection);
            },
            .sum => |*column| {
                try out.objectField("column");
                try writeColumn(out, column);
            },
            .count => {},
        }
        try out.endObject();
        try out.objectField("predicate");
        switch (ast.predicate) {
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
                try out.write(@tagName(comparison.literal));
                try out.objectField("value");
                switch (comparison.literal) {
                    .null => try out.write(null),
                    inline .int64, .uint64, .float64 => |value| try out.write(value),
                    .boolean => |value| try out.write(value),
                    .utf8, .binary => |*value| try out.write(value.slice()),
                }
                try out.endObject();
                try out.endObject();
            },
        }
        try out.objectField("limit");
        try out.write(ast.limit);
        try out.objectField("input");
        if (ast.input) |*input| {
            try out.beginObject();
            try out.objectField("projection");
            try writeProjection(out, &input.projection);
            try out.objectField("limit");
            try out.write(input.limit);
            try out.objectField("alias");
            try out.write(input.alias.slice());
            try out.endObject();
        } else try out.write(null);
        try out.endObject();
    }
};
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
        const ast = sql.parse(case.sql) catch |err| {
            try std.json.Stringify.value(.{ .id = case.id, .parse_error = @errorName(err) }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
            continue;
        };
        const columns = [_]m.Column{
            .{ .name = try m.Name.init(case.schema.columns[0]), .type = .int64 },
            .{ .name = try m.Name.init(case.schema.columns[1]), .type = case.schema.type },
        };
        const source: m.Sql.Source = .{ .name = try m.Name.init(case.schema.name), .schema = .{ .columns = &columns } };
        const plan = m.Sql.compile(init.arena.allocator(), ast, source) catch |err| {
            try std.json.Stringify.value(.{ .id = case.id, .ast = AstView{ .ast = ast }, .compile_error = @errorName(err) }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
            continue;
        };
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
        try std.json.Stringify.value(.{ .id = case.id, .ast = AstView{ .ast = ast }, .encoded = hex[0 .. 2 * saved.len], .segments = segments }, .{}, &stdout.interface);
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
                .boolean => .{ .boolean = ordinal % 2 == 0 },
                .utf8 => .{ .utf8 = if (ordinal % 2 == 0) "it's 東京" else "a\\b" },
                .binary => .{ .binary = if (ordinal % 2 == 0) &.{ 0, 255 } else "" },
                else => return error.UnsupportedFixtureType,
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
