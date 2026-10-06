//! Bounded, grammar-checked SQL candidates over one already authorized source.
//! This is a catalog of complete drafts, never a speculative execution planner.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
pub const Item = struct { label: []const u8, sql: []const u8 };
pub const max_items = 8;
pub const max_search_bytes = 128;

/// Caller owns the returned slice and each SQL string; labels are static.
pub fn candidates(allocator: std.mem.Allocator, name: []const u8, schema: q.fuze.Types.Type, search: []const u8) ![]const Item {
    if (search.len > max_search_bytes or !std.unicode.utf8ValidateSlice(search)) return error.InvalidQuerySearch;
    try schema.validate(.{});
    if (schema != .structure) return error.InvalidQuerySchema;
    var items: [max_items]Item = undefined;
    var count: usize = 0;
    errdefer for (items[0..count]) |item| allocator.free(item.sql);
    for (0..2 + schema.structure.len * 3) |index| {
        if (count == max_items) break;
        const column = if (index >= 2) schema.structure[(index - 2) / 3] else null;
        const operation = if (index >= 2) (index - 2) % 3 else 0;
        if (column != null and operation == 2 and column.?.type != .int64) continue;
        var buffer: [1200]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        try writer.writeAll("SELECT ");
        if (index == 0 or (index >= 2 and operation == 1)) try writer.writeByte('*') else if (index == 1) try writer.writeAll("COUNT(*)") else {
            if (operation == 2) try writer.writeAll("SUM(");
            try identifier(&writer, column.?.name);
            if (operation == 2) try writer.writeByte(')');
        }
        try writer.writeAll(" FROM ");
        try identifier(&writer, name);
        if (index >= 2 and operation == 1) {
            try writer.writeAll(" WHERE ");
            try identifier(&writer, column.?.name);
            try writer.writeAll(" IS NULL");
        }
        if (index == 0 or (index >= 2 and operation != 2)) try writer.writeAll(" LIMIT 8");
        const text = writer.buffered();
        if (!contains(text, search)) continue;
        var compiled = try q.fuze.TableSelect.compile(allocator, text, name, schema, @splat(0), null);
        defer compiled.deinit();
        const label = if (index == 0) "Rows" else if (index == 1) "Count" else switch (operation) {
            0 => "Column values",
            1 => "Explicit nulls",
            2 => "Checked int64 sum",
            else => unreachable,
        };
        items[count] = .{ .label = label, .sql = try allocator.dupe(u8, text) };
        count += 1;
    }
    return allocator.dupe(Item, items[0..count]);
}
fn identifier(writer: *std.Io.Writer, name: []const u8) !void {
    try writer.writeByte('"');
    for (name) |byte| {
        if (byte < 32 or byte == 127) return error.InvalidColumnName;
        try writer.writeByte(byte);
        if (byte == '"') try writer.writeByte(byte);
    }
    try writer.writeByte('"');
}
fn contains(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    for (0..haystack.len - needle.len + 1) |i| if (std.ascii.eqlIgnoreCase(haystack[i..][0..needle.len], needle)) return true;
    return false;
}
test "editor candidates use the real grammar and filter before the page bound" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var columns: [128]q.fuze.Types.Field = undefined;
    for (&columns, 0..) |*column, i| column.* = .{ .name = try std.fmt.allocPrint(allocator, "value{d}", .{i}), .type = if (i == 127) .uint64 else .int64 };
    const name = "items";
    const schema: q.fuze.Types.Type = .{ .structure = &columns };
    try std.testing.expectEqual(8, (try candidates(allocator, name, schema, "")).len);
    const last = try candidates(allocator, name, schema, "VALUE127");
    try std.testing.expectEqual(2, last.len);
    try std.testing.expectEqualStrings("SELECT \"value127\" FROM \"items\" LIMIT 8", last[0].sql);
    try std.testing.expectEqual(0, (try candidates(allocator, name, schema, "hidden_source")).len);
    try std.testing.expectError(error.InvalidQuerySearch, candidates(allocator, name, schema, &(@as([129]u8, @splat('x')))));
}
test "candidate allocation failures release every partially built draft" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            const columns = [_]q.fuze.Types.Field{.{ .name = "value", .type = .int64 }};
            const items = try candidates(allocator, "items", .{ .structure = &columns }, "");
            defer allocator.free(items);
            defer for (items) |item| allocator.free(item.sql);
        }
    }.run, .{});
}
