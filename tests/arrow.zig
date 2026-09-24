//! Independent Arrow consumers read these actual Fuze-produced IPC fixtures.
const std = @import("std");
const fuze = @import("transit_fuze");
const a = fuze.arrow;
pub const std_options: std.Options = .{ .log_level = .info };

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.Usage;
    const empty = std.mem.eql(u8, args[1], "empty");
    if (std.mem.startsWith(u8, args[1], "query-")) return query(init, args[1][6..], args[2]);
    const types = [_]a.DataType{ .{ .int64 = {} }, .{ .string = {} } };
    const fields = [_]a.Field{
        .{ .name = "id", .data_type = &types[0], .nullable = false },
        .{ .name = "label", .data_type = &types[1], .nullable = true },
    };
    var ids = try a.Int64Builder.init(allocator, 3);
    defer ids.deinit();
    var labels = try a.StringBuilder.init(allocator, 3, 32);
    defer labels.deinit();
    if (!empty) {
        try ids.append(1);
        try ids.append(9007199254740993);
        try ids.append(std.math.maxInt(i64));
        try labels.append("ready");
        try labels.appendNull();
        try labels.append("東京");
    }
    var id_column = try ids.finish();
    defer id_column.release();
    var label_column = try labels.finish();
    defer label_column.release();
    var batch = try a.RecordBatch.initBorrowed(allocator, .{ .fields = &fields }, &.{ id_column, label_column });
    defer batch.deinit();
    var buffer: [4096]u8 = undefined;
    const encoded = try fuze.encode(allocator, batch, &buffer);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[2], .data = encoded });
}

fn query(init: std.process.Init, name: []const u8, path: []const u8) !void {
    const m = fuze.model;
    const data_type: m.Type = if (std.mem.eql(u8, name, "bool")) .boolean else if (std.mem.eql(u8, name, "text")) .utf8 else if (std.mem.eql(u8, name, "binary")) .binary else .int64;
    const schema: m.Schema = .{ .names = .{ try m.Name.init("id"), try m.Name.init("value") }, .value_type = data_type };
    const value: m.Cell = switch (data_type) {
        .int64 => .{ .int64 = 9007199254740993 },
        .boolean => .{ .boolean = true },
        .utf8 => .{ .utf8 = try m.Bytes.init("東京") },
        .binary => .{ .binary = try m.Bytes.init(&.{ 0, 255 }) },
    };
    const rows = [_]m.Row{ .{ .key = -1, .value = value }, .{ .key = 2, .value = .null } };
    const source: m.Source = .{ .basis = .{ .resource = 7, .revision = 3, .schema = try schema.fingerprint() }, .schema = schema, .rows = &rows };
    var plan: fuze.Plan = .{};
    if (std.mem.eql(u8, name, "sum")) {
        plan.aggregate = .sum;
        plan.projection = .{ 1, null };
    }
    if (std.mem.eql(u8, name, "count")) plan.aggregate = .count;
    if (std.mem.eql(u8, name, "null")) plan.predicate = .{ .is_null = 1 };
    if (std.mem.eql(u8, name, "empty")) plan.limit = 0;
    var workspace: [fuze.execution.working_bytes]u8 = undefined;
    var output: [672]u8 = undefined;
    const cancel = fuze.execution.Cancellation.init(false);
    const result = try fuze.execution.run(try plan.bind(source), source, &workspace, &output, &cancel);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = result.bytes });
}
