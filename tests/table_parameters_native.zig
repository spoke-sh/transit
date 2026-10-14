//! Real caller preparation lifetime; the Python owner mutates data, DDL and
//! policy between commands without recreating the prepared object.
const std = @import("std");
const q = @import("transit_query");
const c = @import("transit_catalog");
const f = c.fuze;
const Request = struct { values: []const ?f.Types.Values.Atom, operation: u64 = 0 };
fn execute(comptime helper: type, init: std.process.Init, caller: *c.TableClient, directory: []const u8, prepared: anytype, request: Request) !void {
    if (@TypeOf(prepared.*) == c.TablePreparedDml) {
        var intent = try prepared.bind(init.gpa, caller, request.values, .{ .operation = request.operation, .namespace = 1000 + request.operation }, null);
        defer intent.deinit();
        try helper.saveBytes(init, directory, "intent.bin", intent.bytes);
        return helper.print(init, .{ .kind = @tagName(intent.header.kind), .bytes = intent.body.len });
    }
    var nonce: [16]u8 = undefined;
    try init.io.randomSecure(&nonce);
    var query = try q.TableQuery.openPrepared(init.gpa, caller, prepared, request.values, nonce, .{ .requests = 10000, .rows = 128, .result_bytes = 8 * 1024 * 1024 }, null, null, .{});
    defer query.deinit();
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const a = arena.allocator();
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const schema = try query.schema(&fields);
    var result: std.ArrayList([]const []const u8) = .empty;
    while (try query.next()) |value| {
        var row = value;
        defer row.deinit();
        if (result.items.len == 128) return error.ProofRowLimit;
        const encoded = try a.alloc([]const u8, row.cells.len);
        for (row.cells, schema.structure, encoded) |cell, field, *out| out.* = try f.LogicalJson.encode(a, cell, field);
        try result.append(a, encoded);
    }
    if (!query.complete) return error.IncompleteSource;
    return helper.print(init, .{ .rows = result.items, .complete = true });
}
fn loop(comptime helper: type, init: std.process.Init, caller: *c.TableClient, directory: []const u8, prepared: anytype) !void {
    try helper.print(init, .{ .ready = true, .parameters = prepared.parameterTypes().len });
    var buffer: [16384]u8 = undefined;
    var input = std.Io.File.stdin().readerStreaming(init.io, &buffer);
    while (try input.interface.takeDelimiter('\n')) |line| {
        const request = try std.json.parseFromSlice(Request, init.gpa, line, .{});
        defer request.deinit();
        execute(helper, init, caller, directory, prepared, request.value) catch |err| try helper.print(init, .{ .err = @errorName(err) });
    }
}
pub fn run(comptime helper: type, init: std.process.Init, caller: *c.TableClient, directory: []const u8, args: []const [:0]const u8) !void {
    const dialect: f.Sql.Dialect = if (std.mem.eql(u8, args[5], "mysql")) .mysql else .transit;
    if (std.mem.eql(u8, args[2], "prepared-dml")) {
        var prepared = try c.TablePreparedDml.prepare(init.gpa, caller, args[4], dialect, null);
        defer prepared.deinit();
        return loop(helper, init, caller, directory, &prepared);
    }
    var prepared = try q.TablePrepared.prepare(init.gpa, caller, args[4], dialect, null);
    defer prepared.deinit();
    return loop(helper, init, caller, directory, &prepared);
}
