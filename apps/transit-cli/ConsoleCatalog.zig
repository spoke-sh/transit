//! Current-authorized general catalog inspection with one bounded resident page.
const std = @import("std");
const c = @import("transit_catalog");
const Console = @import("Console.zig").Console;
pub fn command(console: *Console, catalog: *c.TableClient, text: []const u8) !bool {
    if (std.mem.eql(u8, text, ".tables") or std.mem.eql(u8, text, ".schema") or std.mem.eql(u8, text, ".sources") or std.mem.eql(u8, text, ".schema writer")) {
        try inspect(console, catalog, null);
        return true;
    }
    var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
    defer arena.deinit();
    const statement = if (std.mem.startsWith(u8, text, ".schema ")) try std.fmt.allocPrint(arena.allocator(), "DESCRIBE {s}", .{text[8..]}) else text;
    if (std.mem.startsWith(u8, statement, ".")) return false;
    var parser = try c.fuze.SqlTyped.init(arena.allocator(), statement, null);
    if (try parser.takeWord("SHOW")) {
        try parser.requireWord("TABLES");
        try parser.finish();
        try inspect(console, catalog, null);
        return true;
    }
    if (try parser.takeWord("DESCRIBE")) {
        const name = try c.TableMetadata.Name.init(try parser.name());
        try parser.finish();
        try inspect(console, catalog, name);
        return true;
    }
    if (try parser.takeWord("EXPLAIN")) {
        try @import("ConsoleTableQuery.zig").explain(console, catalog, statement[parser.lexer.start..]);
        return true;
    }
    return false;
}
pub fn inspect(console: *Console, catalog: *c.TableClient, name: ?c.TableMetadata.Name) !void {
    var cursor: ?c.TableCatalog.Cursor = null;
    const deadline = std.Io.Clock.boot.now(console.init.io).toMilliseconds() + 300000;
    while (true) {
        if (@import("Signals.zig").interrupted()) return error.ConsoleInterrupted;
        if (std.Io.Clock.boot.now(console.init.io).toMilliseconds() >= deadline) return error.CatalogInspectionTimedOut;
        var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
        defer arena.deinit();
        // Type/default descriptors remain bounded by the actual schema budget.
        const buffer = try arena.allocator().alloc(u8, 1048576);
        var out: std.Io.Writer = .fixed(buffer);
        if (name) |selected| {
            var definition = (try catalog.lookup(arena.allocator(), selected)) orelse return error.CatalogNameNotFound;
            defer definition.deinit();
            try describe(console, &out, arena.allocator(), definition);
        } else {
            var page = try catalog.list(arena.allocator(), cursor);
            defer page.deinit();
            if (console.session.format == .json) {
                try std.json.Stringify.value(.{ .catalog_revision = page.resource_revision, .tables = blk: {
                    var names: std.array_list.Managed([]const u8) = .init(arena.allocator());
                    for (page.entries) |entry| if (entry) |value| try names.append(value.metadata.name.slice());
                    break :blk names.items;
                }, .complete = page.next == null }, .{}, &out);
                try out.writeByte('\n');
            } else {
                if (cursor == null) try out.print("Catalog tables (revision {d}):\n", .{page.resource_revision});
                for (page.entries) |entry| if (entry) |definition| {
                    try std.json.Stringify.value(definition.metadata.name.slice(), .{ .escape_unicode = true }, &out);
                    try out.writeByte('\n');
                };
            }
            cursor = page.next;
        }
        try @import("Output.zig").write(console.init, console.out, out.buffered());
        if (cursor == null) return;
    }
}
fn describe(console: *Console, out: *std.Io.Writer, allocator: std.mem.Allocator, definition: c.TableCatalog.Definition) !void {
    const schema = definition.schema.schema;
    if (console.session.format == .json) {
        var fields: [c.fuze.TableSchema.max_columns]c.fuze.Types.Field = undefined;
        var id: [20]u8 = undefined;
        var revision: [20]u8 = undefined;
        try std.json.Stringify.value(.{ .table = .{ .name = definition.metadata.name.slice(), .object = try std.fmt.bufPrint(&id, "{d}", .{schema.object}), .revision = try std.fmt.bufPrint(&revision, "{d}", .{schema.revision}), .schema = c.fuze.LogicalJson.TypeEnvelope{ .definition = c.fuze.Types.definition, .type = try schema.rowType(&fields) }, .columns = blk: {
            var columns: std.array_list.Managed(Column) = .init(allocator);
            for (schema.columns) |column| try columns.append(.{ .id = try std.fmt.allocPrint(allocator, "{d}", .{column.id}), .name = column.name, .max_characters = column.max_characters, .primary_key = std.mem.indexOfScalar(u64, schema.primary_key, column.id) != null, .default = if (column.default) |cell| try c.fuze.LogicalJson.foreignCell(allocator, cell, column.type) else null });
            break :blk columns.items;
        } } }, .{}, out);
        try out.writeByte('\n');
        return;
    }
    try out.writeAll("Table: ");
    try std.json.Stringify.value(definition.metadata.name.slice(), .{ .escape_unicode = true }, out);
    try out.print("; object: {d}; schema revision: {d}\n", .{ schema.object, schema.revision });
    for (schema.columns) |column| {
        try std.json.Stringify.value(column.name, .{ .escape_unicode = true }, out);
        try out.writeAll(": ");
        try c.fuze.LogicalDisplay.typeName(out, column.type);
        try out.writeAll(if (column.nullable) " NULL" else " NOT NULL");
        if (std.mem.indexOfScalar(u64, schema.primary_key, column.id) != null) try out.writeAll(" PRIMARY KEY");
        if (column.max_characters) |limit| try out.print(" (at most {d} Unicode scalars)", .{limit});
        if (column.default) |cell| {
            try out.writeAll(" DEFAULT ");
            try c.fuze.LogicalDisplay.cell(out, cell, column.type);
        }
        try out.writeByte('\n');
    }
    if (schema.primary_key.len == 0) try out.writeAll("Row identity: internal; duplicate rows are permitted.\n");
}
const Column = struct { id: []const u8, name: []const u8, max_characters: ?u32, primary_key: bool, default: ?c.fuze.LogicalJson.Cell };
