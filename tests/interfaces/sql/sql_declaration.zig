//! Independent grammar consumer for general Table DDL and offline KV/Document
//! declarations. This compiler has no authority or durable publication effects.
const std = @import("std");
const f = @import("transit_fuze");
fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, bytes.len * 2);
    const alphabet = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        result[i * 2] = alphabet[byte >> 4];
        result[i * 2 + 1] = alphabet[byte & 15];
    }
    return result;
}
const Case = struct { sql: []const u8, basis: ?[]const u8 = null };
fn emit(init: std.process.Init, out: *std.Io.Writer, case: Case, index: usize) !void {
    var names = try f.SqlTyped.init(init.arena.allocator(), case.sql, null);
    const creating = try names.takeWord("CREATE");
    var header = names;
    if (!creating) _ = (try header.takeWord("ALTER")) or (try header.takeWord("DROP"));
    if (header.word("STREAM") or header.word("QUEUE")) return emitLog(init, out, case, index);
    if (creating and !names.word("TABLE")) {
        const definition = try f.Declaration.compile(case.sql);
        var buffer: [4096]u8 = undefined;
        const formatted = try definition.format(&buffer);
        return std.json.Stringify.value(.{ .index = index, .kind = @tagName(definition.body), .name = definition.name.slice(), .type = if (definition.body == .kv) definition.body.kv else @as(?f.model.Type, null), .formatted = formatted }, .{}, out);
    }
    var basis: ?f.TableDdl.Owned = if (case.basis) |text| try f.TableDdl.compile(init.gpa, text, null, null) else null;
    defer if (basis) |*value| value.deinit();
    const schema: ?f.TableSchema.Schema = if (basis) |value| try value.statement.create.bind(7) else null;
    var result = try f.TableDdl.compile(init.gpa, case.sql, schema, null);
    defer result.deinit();
    switch (result.statement) {
        .create => |value| {
            const created = try value.bind(7);
            var buffer: [f.TableSchema.max_bytes]u8 = undefined;
            try std.json.Stringify.value(.{ .index = index, .kind = "table", .name = value.name, .if_not_exists = value.if_not_exists, .schema = try f.TableSchemaJson.foreign(init.arena, created), .schema_hex = try hex(init.arena.allocator(), try created.encode(&buffer)) }, .{}, out);
        },
        .alter => |value| {
            var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
            const changed = if (value.action == .columns) (try f.TableEvolution.apply(schema.?, value.action.columns, &columns)).after else schema.?;
            try std.json.Stringify.value(.{ .index = index, .kind = "alter", .name = value.name, .rename = if (value.action == .rename_table) value.action.rename_table else @as(?[]const u8, null), .schema = try f.TableSchemaJson.foreign(init.arena, changed) }, .{}, out);
        },
        .drop => |value| try std.json.Stringify.value(.{ .index = index, .kind = "drop", .name = value.name, .if_exists = value.if_exists, .object = value.object }, .{}, out),
    }
}
fn emitLog(init: std.process.Init, out: *std.Io.Writer, case: Case, index: usize) !void {
    var result = try f.LogDdl.compile(init.gpa, case.sql, .transit, null);
    defer result.deinit();
    const statement = result.statement;
    var original: ?f.LogDdl.Owned = if (case.basis) |text| try f.LogDdl.compile(init.gpa, text, .transit, null) else null;
    defer if (original) |*value| value.deinit();
    const schema: ?f.TableSchema.Schema = if (statement.action == .create) try statement.action.create.bind(7) else if (original) |value| try value.statement.action.create.bind(7) else null;
    const basis: ?f.LogDdl.Basis = if (original) |value| blk: {
        const configured = try value.statement.configure(null, schema.?);
        break :blk .{ .schema = schema.?, .configuration = configured.configuration, .limits = configured.limits };
    } else null;
    const configured: ?f.LogDdl.Configured = if (statement.action == .create or statement.action == .alter) try statement.configure(basis, schema orelse return error.TableSchemaRequired) else null;
    try std.json.Stringify.value(.{ .index = index, .kind = @tagName(statement.kind), .action = @tagName(statement.action), .name = statement.name, .rename = if (statement.action == .rename) statement.action.rename else @as(?[]const u8, null), .configured = configured }, .{}, out);
}
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 2) return error.Usage;
    const cases = try std.json.parseFromSlice([]const Case, allocator, try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(4 * 1024 * 1024)), .{});
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases.value, 0..) |case, index| {
        emit(init, &stdout.interface, case, index) catch |err| {
            try std.json.Stringify.value(.{ .index = index, .err = @errorName(err) }, .{}, &stdout.interface);
        };
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
