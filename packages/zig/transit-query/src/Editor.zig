//! Bounded, grammar-checked SQL candidates over one already authorized source.
//! This is a catalog of complete drafts, never a speculative execution planner.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
pub const Item = struct { label: []const u8, sql: []const u8 };
pub const max_items = 8;
pub const max_search_bytes = 128;

/// Caller owns the returned slice and each SQL string; labels are static.
pub fn candidates(allocator: std.mem.Allocator, name: m.Name, schema: m.Schema, search: []const u8) ![]const Item {
    if (search.len > max_search_bytes or !std.unicode.utf8ValidateSlice(search)) return error.InvalidQuerySearch;
    try schema.validate();
    var items: [max_items]Item = undefined;
    var count: usize = 0;
    errdefer for (items[0..count]) |item| allocator.free(item.sql);
    // Every candidate is parsed and lowered by the same compiler as Run.
    // Filtering precedes the page bound, so every column remains discoverable.
    for (0..2 + schema.columns.len * 3) |index| {
        if (count == max_items) break;
        const column = if (index >= 2) schema.columns[(index - 2) / 3] else null;
        const operation = if (index >= 2) (index - 2) % 3 else 0;
        if (column != null and operation == 2 and column.?.type != .int64) continue;
        var buffer: [256]u8 = undefined;
        var output: std.Io.Writer = .fixed(&buffer);
        const writer = &output;
        if (index == 0) {
            try writer.print("SELECT * FROM {s} LIMIT 8", .{name.slice()});
        } else if (index == 1) {
            try writer.print("SELECT COUNT(*) FROM {s}", .{name.slice()});
        } else switch (operation) {
            0 => try writer.print("SELECT {s} FROM {s} LIMIT 8", .{ column.?.name.slice(), name.slice() }),
            1 => try writer.print("SELECT * FROM {s} WHERE {s} IS NULL LIMIT 8", .{ name.slice(), column.?.name.slice() }),
            2 => try writer.print("SELECT SUM({s}) FROM {s}", .{ column.?.name.slice(), name.slice() }),
            else => unreachable,
        }
        const sql = output.buffered();
        if (!contains(sql, search)) continue;
        var arena: std.heap.ArenaAllocator = .init(allocator);
        defer arena.deinit();
        _ = try q.fuze.Unified.Sql.plan(arena.allocator(), sql, .{ .name = name, .schema = schema });
        const label = if (index == 0) "Rows" else if (index == 1) "Count" else switch (operation) {
            0 => "Column values",
            1 => "Explicit nulls",
            2 => "Checked int64 sum",
            else => unreachable,
        };
        items[count] = .{ .label = label, .sql = try allocator.dupe(u8, sql) };
        count += 1;
    }
    return allocator.dupe(Item, items[0..count]);
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
    var columns: [8]m.Column = undefined;
    for (&columns, 0..) |*column, i| column.* = .{ .name = try m.Name.init(try std.fmt.allocPrint(allocator, "value{d}", .{i})), .type = if (i == 7) .uint64 else .int64 };
    const name = try m.Name.init("items");
    const schema: m.Schema = .{ .columns = &columns };
    try std.testing.expectEqual(8, (try candidates(allocator, name, schema, "")).len);
    const last = try candidates(allocator, name, schema, "VALUE7");
    try std.testing.expectEqual(2, last.len);
    try std.testing.expectEqualStrings("SELECT value7 FROM items LIMIT 8", last[0].sql);
    try std.testing.expectEqual(0, (try candidates(allocator, name, schema, "hidden_source")).len);
    try std.testing.expectError(error.InvalidQuerySearch, candidates(allocator, name, schema, &(@as([129]u8, @splat('x')))));
}
test "candidate allocation failures release every partially built draft" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            const columns = [_]m.Column{.{ .name = try m.Name.init("value"), .type = .int64 }};
            const items = try candidates(allocator, try m.Name.init("items"), .{ .columns = &columns }, "");
            defer allocator.free(items);
            defer for (items) |item| allocator.free(item.sql);
        }
    }.run, .{});
}
