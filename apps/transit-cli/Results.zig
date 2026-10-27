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
/// One logical table with fixed widths from a bounded initial sample. Later
/// rows reuse bounded scratch and clip visibly instead of changing the layout.
pub const Table = struct {
    header: std.heap.ArenaAllocator,
    scratch: std.heap.ArenaAllocator,
    schema: q.fuze.Types.Type,
    widths: [128]usize = @splat(3),
    names: [128][]const u8 = undefined,
    types: [128][]const u8 = undefined,
    alignment: [128]Alignment = @splat(.left),
    pub const maximum_width = 80;
    pub fn init(allocator: std.mem.Allocator, schema: q.fuze.Types.Type, sample: []const []const q.fuze.Types.Values.Cell) !Table {
        try schema.validate(.{});
        if (schema != .structure or schema.structure.len > 128 or sample.len > 64) return error.InvalidArrowResult;
        var self: Table = .{ .header = .init(allocator), .scratch = .init(allocator), .schema = schema };
        errdefer self.deinit();
        const a = self.header.allocator();
        for (schema.structure, 0..) |field, i| {
            self.names[i] = try escaped(a, field.name);
            var buffer: [256]u8 = undefined;
            var text: std.Io.Writer = .fixed(&buffer);
            q.fuze.LogicalDisplay.typeName(&text, field.type) catch |err| {
                if (err != error.WriteFailed) return err;
            };
            self.types[i] = try a.dupe(u8, text.buffered());
            self.widths[i] = @min(maximum_width, @max(3, @max(self.names[i].len, self.types[i].len)));
            if (q.fuze.Types.Semantics.integer(field.type) != null or field.type == .decimal or field.type == .float32 or field.type == .float64) self.alignment[i] = .right;
        }
        for (sample) |cells| {
            if (cells.len != schema.structure.len) return error.InvalidArrowResult;
            _ = self.scratch.reset(.retain_capacity);
            for (cells, schema.structure, 0..) |cell, field, i| {
                const text = try q.fuze.LogicalDisplay.preview(self.scratch.allocator(), cell, field.type);
                self.widths[i] = @min(maximum_width, @max(self.widths[i], text.len));
            }
        }
        return self;
    }
    pub fn deinit(self: *Table) void {
        self.scratch.deinit();
        self.header.deinit();
    }
    fn clipped(self: *Table, text: []const u8, width: usize) ![]const u8 {
        if (text.len <= width) return text;
        var length = width - 3;
        while (length != 0 and text[length] & 0xc0 == 0x80) length -= 1;
        return std.fmt.allocPrint(self.scratch.allocator(), "{s}...", .{text[0..length]});
    }
    pub fn begin(self: *Table, out: *std.Io.Writer) !void {
        const count = self.schema.structure.len;
        var labels: [128][]const u8 = undefined;
        const centered: [128]Alignment = @splat(.center);
        _ = self.scratch.reset(.retain_capacity);
        try border(out, self.widths[0..count], "┌", "┬", "┐");
        for (self.names[0..count], self.widths[0..count], labels[0..count]) |name, width, *label| label.* = try self.clipped(name, width);
        try row(out, labels[0..count], self.widths[0..count], centered[0..count]);
        for (self.types[0..count], self.widths[0..count], labels[0..count]) |name, width, *label| label.* = try self.clipped(name, width);
        try row(out, labels[0..count], self.widths[0..count], centered[0..count]);
        try border(out, self.widths[0..count], "├", "┼", "┤");
    }
    pub fn write(self: *Table, out: *std.Io.Writer, cells: []const q.fuze.Types.Values.Cell) !void {
        if (cells.len != self.schema.structure.len) return error.InvalidArrowResult;
        _ = self.scratch.reset(.retain_capacity);
        var values: [128][]const u8 = undefined;
        for (cells, self.schema.structure, self.widths[0..cells.len], values[0..cells.len]) |cell, field, width, *text| text.* = try self.clipped(try q.fuze.LogicalDisplay.preview(self.scratch.allocator(), cell, field.type), width);
        try row(out, values[0..cells.len], self.widths[0..cells.len], self.alignment[0..cells.len]);
    }
    pub fn end(self: *Table, out: *std.Io.Writer) !void {
        try border(out, self.widths[0..self.schema.structure.len], "└", "┴", "┘");
    }
};
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
pub fn write(allocator: std.mem.Allocator, out: *std.Io.Writer, page: q.UnifiedResult.Page, batch: *const q.fuze.LogicalInspect.Batch, ordinal: u64, as_json: bool) !void {
    if (as_json) {
        try std.json.Stringify.value(.{ .manifest = try q.Bridge.Manifest.fromNative(allocator, page.manifest, page.basis), .ordinal = try q.document.JsonValues.decimal(allocator, ordinal), .columns = try q.Values.foreignColumns(allocator, page.schema), .cells = try q.Values.rows(allocator, batch), .complete_coverage = page.next == null }, .{ .escape_unicode = true }, out);
        return out.writeByte('\n');
    }
    try table(allocator, out, page.schema, batch);
}
pub fn table(allocator: std.mem.Allocator, out: *std.Io.Writer, schema: q.fuze.Types.Type, batch: *const q.fuze.LogicalInspect.Batch) !void {
    var rows: [q.fuze.LogicalArrow.max_rows][]const q.fuze.Types.Values.Cell = undefined;
    if (batch.rows.len > rows.len) return error.InvalidArrowResult;
    for (batch.rows, rows[0..batch.rows.len]) |cells, *row_| row_.* = cells.cells;
    return logicalTable(allocator, out, schema, rows[0..batch.rows.len]);
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
    var fields: [columns.len]q.fuze.Types.Field = undefined;
    var values: [2][columns.len]q.fuze.Types.Values.Cell = undefined;
    var logical_rows: [2][]const q.fuze.Types.Values.Cell = undefined;
    for (&columns, &fields) |*column, *field| field.* = .{ .name = column.name.slice(), .type = q.fuze.Types.Type.fromQuery(column.type), .nullable = true, .optional = true };
    for (&values, &logical_rows, 0..) |*cells, *logical_row, i| {
        for (cells, batch.cells[i][0..columns.len], columns) |*cell, original, column| cell.* = try q.fuze.Types.Values.fromQuery(allocator, column.type, original);
        logical_row.* = cells;
    }
    try logicalTable(allocator, &out, .{ .structure = &fields }, &logical_rows);
    const text = out.buffered();
    inline for (.{ "┌", "int64", "uint64", "float64", "utf8", "boolean", "binary", "-9223372036854775808", "18446744073709551615", "1.5", "NULL", "MISSING", "TYPE_ERROR(utf8)", "\"NULL\"", "true", "false", "0x00ff", "CONFLICT[", "18446744073709551615@", "0x1b" }) |fragment| try std.testing.expect(std.mem.indexOf(u8, text, fragment) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, text, 27) == null);
    try std.testing.expect(std.mem.indexOf(u8, text, "│                 NULL │") != null);
}
