//! One verified page at a time. Cell states and exact scalars stay distinct.
const std = @import("std");
const q = @import("transit_query");
pub fn write(allocator: std.mem.Allocator, out: *std.Io.Writer, page: q.Workspace.Page, as_json: bool) !void {
    if (as_json) {
        try std.json.Stringify.value(.{ .manifest = page.evidence.manifest, .ordinal = page.evidence.ordinal, .columns = page.evidence.columns, .cells = page.cells, .complete_coverage = page.evidence.next == null }, .{ .escape_unicode = true }, out);
        return out.writeByte('\n');
    }
    var widths: [8]usize = @splat(0);
    const count = page.evidence.columns.len;
    var names: [8][]const u8 = undefined;
    for (page.evidence.columns, 0..) |column, i| {
        names[i] = try escaped(allocator, column.name);
        widths[i] = names[i].len;
    }
    const rows = try allocator.alloc([][]const u8, page.cells.len);
    for (page.cells, rows) |cells, *rendered| {
        rendered.* = try allocator.alloc([]const u8, count);
        for (cells, rendered.*, 0..) |cell, *text, i| {
            text.* = switch (cell) {
                .value => |v| switch (v) {
                    .int64, .uint64 => |n| n,
                    .boolean => |b| if (b) "true" else "false",
                    .utf8 => |s| try std.json.Stringify.valueAlloc(allocator, s, .{ .escape_unicode = true }),
                    .binary => |s| try std.fmt.allocPrint(allocator, "0x{s}", .{s}),
                    .float_bits => |s| try std.fmt.allocPrint(allocator, "float64:0x{s}", .{s}),
                },
                else => try std.json.Stringify.valueAlloc(allocator, cell, .{ .escape_unicode = true }),
            };
            widths[i] = @max(widths[i], text.len);
        }
    }
    try border(out, widths[0..count]);
    try row(out, names[0..count], widths[0..count]);
    try border(out, widths[0..count]);
    for (rows) |cells| try row(out, cells, widths[0..count]);
    try border(out, widths[0..count]);
}
fn escaped(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{ .escape_unicode = true });
    return encoded[1 .. encoded.len - 1];
}
fn border(out: *std.Io.Writer, widths: []const usize) !void {
    try out.writeByte('+');
    for (widths) |width| {
        try out.splatByteAll('-', width + 2);
        try out.writeByte('+');
    }
    try out.writeByte('\n');
}
fn row(out: *std.Io.Writer, cells: []const []const u8, widths: []const usize) !void {
    try out.writeByte('|');
    for (cells, widths) |cell, width| {
        try out.writeByte(' ');
        try out.writeAll(cell);
        try out.splatByteAll(' ', width - cell.len + 1);
        try out.writeByte('|');
    }
    try out.writeByte('\n');
}
