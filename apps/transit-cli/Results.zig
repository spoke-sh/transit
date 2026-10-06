//! Render one verified native Arrow batch or a lossless foreign page envelope.
const std = @import("std");
const q = @import("transit_query");
const m = q.fuze.Unified;
/// One verified logical output row. Projection can repeat source cells; escaped
/// JSON size is not the storage row size or an implicit result byte budget.
pub fn logicalRow(allocator: std.mem.Allocator, out: *std.Io.Writer, schema: q.fuze.Types.Type, cells: []const q.fuze.Types.Values.Cell) !void {
    try std.json.Stringify.value(.{ .row = try q.fuze.LogicalJson.foreignCell(allocator, .{ .value = .{ .structure = cells } }, schema), .complete_coverage = false }, .{ .escape_unicode = true }, out);
    try out.writeByte('\n');
}
pub fn logicalTable(allocator: std.mem.Allocator, out: *std.Io.Writer, schema: q.fuze.Types.Type, values: []const []const q.fuze.Types.Values.Cell) !void {
    try schema.validate(.{});
    if (schema != .structure or schema.structure.len > q.fuze.TableSchema.max_columns or values.len > 8) return error.InvalidArrowResult;
    const count = schema.structure.len;
    var widths: [128]usize = @splat(0);
    var names: [128][]const u8 = undefined;
    var types: [128][]const u8 = undefined;
    var alignments: [128]Alignment = @splat(.left);
    const heading: [128]Alignment = @splat(.center);
    const display = @import("transit_query").fuze.LogicalDisplay;
    for (schema.structure, 0..) |field, i| {
        names[i] = try escaped(allocator, field.name);
        var bytes: [256]u8 = undefined;
        var label: std.Io.Writer = .fixed(&bytes);
        var truncated = false;
        display.typeName(&label, field.type) catch |err| {
            if (err != error.WriteFailed) return err;
            truncated = true;
        };
        types[i] = if (truncated) try std.fmt.allocPrint(allocator, "{s}...", .{label.buffered()}) else try allocator.dupe(u8, label.buffered());
        widths[i] = @max(names[i].len, types[i].len);
        if (q.fuze.Types.Semantics.integer(field.type) != null or field.type == .decimal or field.type == .float32 or field.type == .float64) alignments[i] = .right;
    }
    const rows = try allocator.alloc([][]const u8, values.len);
    for (values, rows) |cells, *rendered| {
        if (cells.len != count) return error.InvalidArrowResult;
        rendered.* = try allocator.alloc([]const u8, count);
        for (cells, schema.structure, rendered.*, 0..) |cell, field, *text, i| {
            text.* = try display.preview(allocator, cell, field.type);
            widths[i] = @max(widths[i], text.len);
        }
    }
    try border(out, widths[0..count], "┌", "┬", "┐");
    try row(out, names[0..count], widths[0..count], heading[0..count]);
    try row(out, types[0..count], widths[0..count], heading[0..count]);
    try border(out, widths[0..count], "├", "┼", "┤");
    for (rows) |cells| try row(out, cells, widths[0..count], alignments[0..count]);
    try border(out, widths[0..count], "└", "┴", "┘");
}
test {
    _ = @import("transit_query").fuze.LogicalDisplay;
}
test "escaped projected Table rows stream beyond the old fixed render buffer" {
    const f = q.fuze;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const bytes = try allocator.alloc(u8, 256 * 1024);
    @memset(bytes, 27);
    const stored: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .bytes = bytes } } };
    const source: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "value", .type = .utf8 }} };
    try source.validateRow(&.{stored});
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var plan = try f.TableSelect.compile(allocator, "SELECT value AS a, value AS b, value AS c, value AS d, value AS e, value AS f, value AS g, value AS h FROM items", "items", try source.rowType(&fields), @splat(1), null);
    defer plan.deinit();
    const output = try plan.plan.outputSchema(&fields);
    const cells: [8]f.Types.Values.Cell = @splat(stored);
    var result: std.Io.Writer.Allocating = .init(allocator);
    defer result.deinit();
    var buffer: [16384]u8 = undefined;
    var stream = @import("Output.zig").Stream.init(std.testing.io, &result.writer, &buffer);
    try logicalRow(allocator, &stream.interface, output, &cells);
    try stream.flush();
    try std.testing.expect(result.written().len > 8 * 1024 * 1024);
    try std.testing.expect(std.mem.indexOfScalar(u8, result.written(), 27) == null);
    const decoded = try std.json.parseFromSliceLeaky(struct { row: f.LogicalJson.Cell, complete_coverage: bool }, allocator, result.written(), .{});
    try std.testing.expect(!decoded.complete_coverage);
    try std.testing.expectEqual(@as(usize, 8), decoded.row.value.structure.len);
    for (decoded.row.value.structure) |cell| try std.testing.expectEqualStrings(bytes, cell.value.atom.utf8);
}
pub fn write(allocator: std.mem.Allocator, out: *std.Io.Writer, page: q.UnifiedResult.Page, batch: *const m.Inspect.Batch, ordinal: u64, as_json: bool) !void {
    if (as_json) {
        const rows = try allocator.alloc([]q.Values.Cell, batch.count);
        for (rows, 0..) |*cells, i| {
            const native = try batch.row(i);
            cells.* = try allocator.alloc(q.Values.Cell, native.cells.len);
            for (cells.*, native.cells) |*cell, value| cell.* = try q.Values.Cell.fromNative(allocator, value);
        }
        try std.json.Stringify.value(.{ .manifest = try q.Bridge.Manifest.fromNative(allocator, page.manifest), .ordinal = try q.document.JsonValues.decimal(allocator, ordinal), .columns = try q.Values.foreignColumns(allocator, page.schema), .cells = rows, .complete_coverage = page.next == null }, .{ .escape_unicode = true }, out);
        return out.writeByte('\n');
    }
    try table(allocator, out, page.schema, batch);
}
pub fn table(allocator: std.mem.Allocator, out: *std.Io.Writer, schema: m.Schema, batch: *const m.Inspect.Batch) !void {
    try schema.validate();
    const count = schema.columns.len;
    if (batch.columns != count or batch.count > m.max_rows) return error.InvalidArrowResult;
    var widths: [m.max_columns]usize = @splat(0);
    var names: [m.max_columns][]const u8 = undefined;
    var types: [m.max_columns][]const u8 = undefined;
    var alignments: [m.max_columns]Alignment = undefined;
    const heading: [m.max_columns]Alignment = @splat(.center);
    for (schema.columns, 0..) |column, i| {
        names[i] = try escaped(allocator, column.name.slice());
        types[i] = @tagName(column.type);
        widths[i] = @max(names[i].len, types[i].len);
        alignments[i] = switch (column.type) {
            .int64, .uint64, .float64 => .right,
            else => .left,
        };
    }
    const rows = try allocator.alloc([][]const u8, batch.count);
    for (rows, 0..) |*rendered, index| {
        rendered.* = try allocator.alloc([]const u8, count);
        const native = try batch.row(index);
        for (native.cells, rendered.*, 0..) |cell, *text, i| {
            text.* = try cellText(allocator, cell);
            widths[i] = @max(widths[i], text.len);
        }
    }
    try border(out, widths[0..count], "┌", "┬", "┐");
    try row(out, names[0..count], widths[0..count], heading[0..count]);
    try row(out, types[0..count], widths[0..count], heading[0..count]);
    try border(out, widths[0..count], "├", "┼", "┤");
    for (rows) |cells| try row(out, cells, widths[0..count], alignments[0..count]);
    try border(out, widths[0..count], "└", "┴", "┘");
}
fn cellText(allocator: std.mem.Allocator, cell: m.Cell) ![]const u8 {
    return switch (cell) {
        .missing => "MISSING",
        .null => "NULL",
        .type_error => |kind| try std.fmt.allocPrint(allocator, "TYPE_ERROR({s})", .{@tagName(kind)}),
        .conflict => try std.json.Stringify.valueAlloc(allocator, try q.Values.Cell.fromNative(allocator, cell), .{ .escape_unicode = true }),
        .value => |value| switch (value) {
            inline .int64, .uint64 => |number| try std.fmt.allocPrint(allocator, "{d}", .{number}),
            .float64 => |number| try std.fmt.allocPrint(allocator, "{d}", .{number}),
            .boolean => |boolean| if (boolean) "true" else "false",
            .utf8 => |bytes| try std.json.Stringify.valueAlloc(allocator, bytes, .{ .escape_unicode = true }),
            .binary => |bytes| try std.fmt.allocPrint(allocator, "0x{s}", .{try q.document.JsonValues.hex(allocator, bytes)}),
        },
    };
}
fn escaped(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{ .escape_unicode = true });
    return encoded[1 .. encoded.len - 1];
}
fn border(out: *std.Io.Writer, widths: []const usize, left: []const u8, middle: []const u8, right: []const u8) !void {
    try out.writeAll(left);
    for (widths, 0..) |width, i| {
        for (0..width + 2) |_| try out.writeAll("─");
        try out.writeAll(if (i + 1 == widths.len) right else middle);
    }
    try out.writeByte('\n');
}
const Alignment = enum { left, center, right };
fn row(out: *std.Io.Writer, cells: []const []const u8, widths: []const usize, alignment: []const Alignment) !void {
    try out.writeAll("│");
    for (cells, widths, alignment) |cell, width, selected_alignment| {
        const spare = width - cell.len;
        const before = switch (selected_alignment) {
            .left => 0,
            .center => spare / 2,
            .right => spare,
        };
        try out.splatByteAll(' ', before + 1);
        try out.writeAll(cell);
        try out.splatByteAll(' ', spare - before + 1);
        try out.writeAll("│");
    }
    try out.writeByte('\n');
}

test "native table renders schema, wide numbers and distinct cell states safely" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const columns = [_]m.Column{
        .{ .name = try .init("signed"), .type = .int64 },
        .{ .name = try .init("unsigned"), .type = .uint64 },
        .{ .name = try .init("measure"), .type = .float64 },
        .{ .name = try .init("text"), .type = .utf8 },
        .{ .name = try .init("flag"), .type = .boolean },
        .{ .name = try .init("blob"), .type = .binary },
    };
    const batch = try allocator.create(m.Inspect.Batch);
    batch.* = .{ .count = 2, .columns = 6 };
    batch.cells[0][0] = .{ .value = .{ .int64 = std.math.minInt(i64) } };
    batch.cells[0][1] = .{ .value = .{ .uint64 = std.math.maxInt(u64) } };
    batch.cells[0][2] = .{ .value = .{ .float64 = 1.5 } };
    batch.cells[0][3] = .{ .value = .{ .utf8 = "\x1b[31m\n" } };
    batch.cells[0][4] = .{ .value = .{ .boolean = true } };
    batch.cells[0][5] = .{ .value = .{ .binary = "\x00\xff" } };
    batch.cells[1][0] = .null;
    batch.cells[1][1] = .missing;
    batch.cells[1][2] = .{ .type_error = .utf8 };
    batch.cells[1][3] = .{ .value = .{ .utf8 = "NULL" } };
    batch.cells[1][4] = .{ .value = .{ .boolean = false } };
    const alternatives = [_]m.Alternative{
        .{ .counter = std.math.maxInt(u64), .replica = 1, .value = .null },
        .{ .counter = std.math.maxInt(u64), .replica = 2, .value = .{ .value = .{ .binary = "\x1b" } } },
    };
    batch.cells[1][5] = .{ .conflict = &alternatives };
    var storage: [4096]u8 = undefined;
    var out: std.Io.Writer = .fixed(&storage);
    try table(allocator, &out, .{ .columns = &columns }, batch);
    const text = out.buffered();
    inline for (.{ "┌", "int64", "uint64", "float64", "utf8", "boolean", "binary", "-9223372036854775808", "18446744073709551615", "1.5", "NULL", "MISSING", "TYPE_ERROR(utf8)", "\"NULL\"", "true", "false", "0x00ff", "\"conflict\"", "\"counter\":\"18446744073709551615\"", "\"binary\":\"1b\"" }) |fragment| try std.testing.expect(std.mem.indexOf(u8, text, fragment) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, text, 27) == null);
    try std.testing.expect(std.mem.indexOf(u8, text, "│                 NULL │") != null);
}
