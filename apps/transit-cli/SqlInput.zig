//! Owned, bounded CLI inputs for the shared one-shot compiler. No retained
//! bindings, SQL interpolation, snapshot acquisition or operation dispatch.
const std = @import("std");
const q = @import("transit_query");
pub const Request = @FieldType(q.Workspace.Request, "compile");
pub const Parameters = []const q.Values.Scalar;
pub const max_file_bytes = 131072;

pub fn parse(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    if (bytes.len > max_file_bytes) return error.QueryInputTooLarge;
    const value = std.json.parseFromSliceLeaky(T, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.InvalidQueryInput;
    if (T == Request) {
        if (value.sql.len > q.fuze.Sql.max_statement_bytes) return error.StatementTooLarge;
        if (value.parameters) |parameters| try validate(parameters);
    } else if (T == Parameters) {
        try validate(value);
    } else @compileError("Only shared SQL requests or scalar arrays are CLI inputs");
    return value;
}

pub fn read(comptime T: type, init: std.process.Init, allocator: std.mem.Allocator, path: []const u8) !T {
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, path, allocator, .limited(max_file_bytes)) catch |err| return switch (err) {
        error.StreamTooLong => error.QueryInputTooLarge,
        else => err,
    };
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    return parse(T, allocator, bytes);
}

pub fn commandPath(allocator: std.mem.Allocator, line: []const u8) !?[]const u8 {
    if (std.mem.eql(u8, line, ".execute")) return error.MissingPath;
    if (std.mem.startsWith(u8, line, ".execute ") or std.mem.startsWith(u8, line, ".execute\t"))
        return try @import("Preferences.zig").argument(allocator, line[9..]);
    return null;
}

fn validate(parameters: Parameters) !void {
    if (parameters.len > q.fuze.LogicalPrepared.max_parameters) return error.ParameterCountMismatch;
}

test "query files own SQL and bindings, preserving omitted and empty inputs" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const bytes = try allocator.dupe(u8, "{\"sql\":\"SELECT value FROM items WHERE value = $1 LIMIT $2\",\"parameters\":[{\"utf8\":\"'; DROP TABLE items; -- $2\"},{\"unsigned\":\"18446744073709551615\"}]}");
    const request = try parse(Request, allocator, bytes);
    @memset(bytes, 0);
    try std.testing.expectEqualStrings("SELECT value FROM items WHERE value = $1 LIMIT $2", request.sql);
    try std.testing.expectEqualStrings("'; DROP TABLE items; -- $2", request.parameters.?[0].utf8);
    try std.testing.expectEqualStrings("18446744073709551615", request.parameters.?[1].unsigned);
    try std.testing.expect((try parse(Request, allocator, "{\"sql\":\"SELECT * FROM items\"}")).parameters == null);
    try std.testing.expectEqual(@as(usize, 0), (try parse(Request, allocator, "{\"sql\":\"SELECT * FROM items\",\"parameters\":[]}")).parameters.?.len);
    try std.testing.expectEqualStrings("file with spaces.json", (try commandPath(allocator, ".execute \"file with spaces.json\"")).?);
}

test "query input rejects malformed, ambiguous and over-bound input before compilation" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_][]const u8{
        "null",                                               "{}",                                                                  "{\"sql\":\"SELECT * FROM items\",\"sql\":\"SELECT 1\"}",
        "{\"sql\":\"SELECT * FROM items\",\"unknown\":true}", "{\"sql\":\"SELECT * FROM items\",\"parameters\":[{\"unsigned\":1}]}", "{\"sql\":\"SELECT * FROM items\",\"parameters\":[{\"unsigned\":\"1\",\"signed\":\"1\"}]}",
    }) |bytes| try std.testing.expectError(error.InvalidQueryInput, parse(Request, allocator, bytes));
    try std.testing.expectError(error.InvalidQueryInput, parse(Parameters, allocator, "null"));
    const too_many: [q.fuze.LogicalPrepared.max_parameters + 1]q.Values.Scalar = @splat(.{ .boolean = true });
    try std.testing.expectError(error.ParameterCountMismatch, parse(Parameters, allocator, try std.json.Stringify.valueAlloc(allocator, too_many, .{})));
    const oversized = try allocator.alloc(u8, max_file_bytes + 1);
    try std.testing.expectError(error.QueryInputTooLarge, parse(Request, allocator, oversized));
    try std.testing.expectError(error.MissingPath, commandPath(allocator, ".execute"));
}
