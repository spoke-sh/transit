//! Grammar continuations over an already authorized catalog. No native effects.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
const sql = q.fuze.Sql;
const input = q.fuze.SqlInput;
pub const max_items = 8;
pub const Request = struct { sql: []const u8, cursor: u16, generation: u32, mode: enum { sql, console } = .sql };
pub const Item = struct { text: []const u8, kind: enum { keyword, source, column, symbol, literal, meta }, detail: []const u8 };
pub const Completion = struct {
    range: ?input.Range,
    items: []const Item,
    pub fn deinit(self: Completion, allocator: std.mem.Allocator) void {
        for (self.items) |item| allocator.free(item.text);
        allocator.free(self.items);
    }
};
pub const Response = struct {
    version: u8 = 1,
    generation: u32,
    profile: enum { unified_v1, catalog_v1 } = .unified_v1,
    resource: u64,
    contract: [32]u8,
    resource_revision: u64,
    policy_revision: []const u8,
    range: ?input.Range,
    items: []const Item,
};
/// Shared console vocabulary; dispatchers must reject unimplemented operations.
pub const Meta = enum { help, info, tables, sources, schema, status, @"resume", cancel, mode, quit, connect, show, timer, execute };
const Builder = struct {
    allocator: std.mem.Allocator,
    prefix: []const u8,
    quoted: bool,
    items: [max_items]Item = undefined,
    length: usize = 0,
    fn clear(self: *Builder) void {
        for (self.items[0..self.length]) |item| self.allocator.free(item.text);
    }
    fn add(self: *Builder, raw: []const u8, kind: @FieldType(Item, "kind"), detail: []const u8) !void {
        if (self.length == max_items or self.prefix.len > raw.len) return;
        if (self.quoted) {
            if (!std.mem.eql(u8, raw[0..self.prefix.len], self.prefix)) return;
        } else if (!std.ascii.eqlIgnoreCase(raw[0..self.prefix.len], self.prefix)) return;
        const identifier = kind == .source or kind == .column;
        // The v1 schema permits 32-byte names; the shared SQL AST's named
        // identifiers remain 16 bytes. Star can still expose wider columns.
        if (identifier and raw.len > 16) return;
        if (self.quoted and !identifier) return;
        const text = if (identifier) try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{raw}) else try self.allocator.dupe(u8, raw);
        self.items[self.length] = .{ .text = text, .kind = kind, .detail = detail };
        self.length += 1;
    }
    fn finish(self: *Builder, range: ?input.Range) !Completion {
        return .{ .range = range, .items = try self.allocator.dupe(Item, self.items[0..self.length]) };
    }
};
pub fn complete(allocator: std.mem.Allocator, name: m.Name, schema: m.Schema, request: Request) !Completion {
    try schema.validate();
    _ = try input.Scan.init(request.sql);
    if (request.cursor > request.sql.len or !std.unicode.utf8ValidateSlice(request.sql[0..request.cursor])) return error.InvalidSqlCursor;
    if (request.mode == .console and std.mem.startsWith(u8, request.sql, ".")) return meta(allocator, request);
    const range = try input.replacement(request.sql, request.cursor);
    var builder: Builder = .{ .allocator = allocator, .prefix = "", .quoted = false };
    errdefer builder.clear();
    const selected = range orelse return builder.finish(null);
    if (name.len > 16) return builder.finish(range);
    var prefix = request.sql[selected.start..request.cursor];
    if (selected.quoted) {
        if (prefix.len == 0) return builder.finish(range);
        prefix = prefix[1..];
        if (std.mem.endsWith(u8, prefix, "\"")) prefix = prefix[0 .. prefix.len - 1];
    }
    builder.prefix = prefix;
    builder.quoted = selected.quoted;
    const hints = try sql.hints(request.sql[0..selected.start]);
    if (hints.source) |source| if (!std.mem.eql(u8, source.slice(), name.slice())) return builder.finish(range);
    const source_qualifier = if (hints.source_alias) |alias| try m.Name.init(alias.slice()) else name;
    if (hints.qualifier) |qualifier| if (!std.mem.eql(u8, qualifier.slice(), source_qualifier.slice())) return builder.finish(range);
    var predicate_type: ?m.Type = null;
    if (hints.predicate_column) |column| {
        if (column.qualifier) |qualifier| if (!std.mem.eql(u8, qualifier.slice(), source_qualifier.slice())) return builder.finish(range);
        for (schema.columns) |candidate| if (std.mem.eql(u8, candidate.name.slice(), column.name.slice())) {
            predicate_type = candidate.type;
            break;
        };
        if (predicate_type == null) {
            // The parsed name can still become a qualified column. It is not
            // itself a scalar, so only the grammar's dot continuation is valid.
            if (column.qualifier == null and std.mem.eql(u8, column.name.slice(), source_qualifier.slice()) and
                std.mem.indexOfScalar(?sql.Tag, &hints.symbols, .dot) != null)
                try builder.add(".", .symbol, "SQL grammar");
            return builder.finish(range);
        }
    }
    var has_int64 = false;
    for (schema.columns) |column| if (column.type == .int64 and column.name.len <= 16) {
        has_int64 = true;
        break;
    };
    if (hints.name_role) |role| switch (role) {
        .source => try builder.add(name.slice(), .source, "Authorized source"),
        .column => {
            for (schema.columns) |column| {
                if (hints.sum_only and column.type != .int64) continue;
                try builder.add(column.name.slice(), .column, @tagName(column.type));
            }
            if (hints.qualifier == null and (!hints.sum_only or has_int64)) try builder.add(source_qualifier.slice(), .source, "Column qualifier");
        },
        .alias => {}, // User-chosen names are not a catalog; no invented authority.
    };
    var literal_type: ?m.Type = null;
    if (hints.literal_column) |column| {
        if (column.qualifier) |qualifier| if (!std.mem.eql(u8, qualifier.slice(), source_qualifier.slice())) return builder.finish(range);
        for (schema.columns) |candidate| if (std.mem.eql(u8, candidate.name.slice(), column.name.slice())) {
            literal_type = candidate.type;
            break;
        };
        if (literal_type == null) return builder.finish(range);
        switch (literal_type.?) {
            .int64 => try builder.add("0", .literal, "int64 literal"),
            .utf8 => try builder.add("''", .literal, "UTF-8 literal"),
            .binary => try builder.add("'\\x'::bytea", .literal, "Binary literal"),
            .uint64 => try builder.add("'0'::uint64", .literal, "uint64 literal"),
            .float64 => try builder.add("'0'::float64", .literal, "finite float64 literal"),
            .boolean => {},
        }
    }
    for (hints.words) |word| if (word) |value| {
        if (hints.aggregate and std.mem.eql(u8, value, "LIMIT")) continue;
        if (std.mem.eql(u8, value, "SUM") and !has_int64) continue;
        if (literal_type) |kind| {
            if (std.mem.eql(u8, value, "NULL")) continue;
            if ((std.mem.eql(u8, value, "TRUE") or std.mem.eql(u8, value, "FALSE")) and kind != .boolean) continue;
        }
        try builder.add(value, .keyword, "SQL grammar");
    };
    for (hints.symbols) |symbol| if (symbol) |tag| {
        if (tag == .dot) if (hints.predicate_column) |column| {
            if (column.qualifier != null or !std.mem.eql(u8, column.name.slice(), source_qualifier.slice())) continue;
        };
        if (literal_type != null) continue; // Typed literals above; no invalid numeric/sign suggestions.
        const value: ?[]const u8 = switch (tag) {
            .left => "(",
            .right => ")",
            .comma => ",",
            .dot => ".",
            .star => "*",
            .semi => ";",
            .eq => "=",
            .ne => "<>",
            .lt => "<",
            .le => "<=",
            .gt => ">",
            .ge => ">=",
            .integer => "8",
            .cast => "::",
            else => null,
        };
        if (value) |text| try builder.add(text, if (tag == .integer) .literal else .symbol, "SQL grammar");
    };
    return builder.finish(range);
}
pub fn meta(allocator: std.mem.Allocator, request: Request) !Completion {
    const end = std.mem.indexOfAny(u8, request.sql, " \t\r\n") orelse request.sql.len;
    var builder: Builder = .{ .allocator = allocator, .prefix = request.sql[0..request.cursor], .quoted = false };
    errdefer builder.clear();
    if (request.cursor <= end) {
        inline for (@typeInfo(Meta).@"enum".field_names) |command| try builder.add("." ++ command, .meta, "Local console command");
        return builder.finish(.{ .start = 0, .end = @intCast(end) });
    }
    var start = end;
    while (start < request.cursor and std.mem.indexOfScalar(u8, " \t", request.sql[start]) != null) start += 1;
    builder.prefix = request.sql[start..request.cursor];
    if (std.mem.eql(u8, request.sql[1..end], "mode")) {
        try builder.add("table", .meta, "Human rendering");
        try builder.add("json", .meta, "Machine rendering");
    } else if (std.mem.eql(u8, request.sql[1..end], "schema")) {
        try builder.add("writer", .meta, "Inspect the configured authorized Table writer");
    } else if (std.mem.eql(u8, request.sql[1..end], "help")) {
        for ([_][]const u8{ "SQL", "INSERT", "UPDATE", "DELETE", "CREATE TABLE", "ALTER TABLE", "DROP TABLE" }) |topic| try builder.add(topic, .meta, "Local SQL help");
    } else if (std.mem.eql(u8, request.sql[1..end], "timer")) {
        try builder.add("on", .meta, "Enable query timing");
        try builder.add("off", .meta, "Disable query timing");
    }
    var finish = request.cursor;
    while (finish < request.sql.len and std.mem.indexOfScalar(u8, " \t\r\n", request.sql[finish]) == null) finish += 1;
    return builder.finish(.{ .start = @intCast(start), .end = @intCast(finish) });
}

test "independent cursor fixtures preserve grammar, scope, type and range boundaries" {
    const t = std.testing;
    const Fixture = struct {
        version: u8,
        source: []const u8,
        columns: []const q.Values.Column,
        cases: []const struct { sql: []const u8, cursor: u16, start: u16, end: u16, mode: @FieldType(Request, "mode") = .sql, items: []const []const u8 },
    };
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fixture = (try std.json.parseFromSlice(Fixture, allocator, @embedFile("fixtures/assistance-v1.json"), .{})).value;
    try t.expectEqual(1, fixture.version);
    const name = try m.Name.init(fixture.source);
    const schema = try q.Values.columns(allocator, fixture.columns);
    for (fixture.cases) |case| {
        const result = try complete(allocator, name, schema, .{ .sql = case.sql, .cursor = case.cursor, .generation = 7, .mode = case.mode });
        errdefer std.debug.print("fixture: {s} at {d}\n", .{ case.sql, case.cursor });
        try t.expectEqual(case.start, result.range.?.start);
        try t.expectEqual(case.end, result.range.?.end);
        try t.expectEqual(case.items.len, result.items.len);
        for (case.items, result.items) |expected, item| try t.expectEqualStrings(expected, item.text);
    }
    for ([_][]const u8{ "SELECT 'private", "SELECT /* private", "-- private" }) |text| {
        const result = try complete(allocator, name, schema, .{ .sql = text, .cursor = @intCast(text.len), .generation = 1 });
        try t.expect(result.range == null);
        try t.expectEqual(0, result.items.len);
    }
    const all = try complete(allocator, name, schema, .{ .sql = "SELECT ", .cursor = 7, .generation = 1 });
    try t.expectEqual(max_items, all.items.len);
    try t.expectError(error.InvalidSqlCursor, complete(allocator, name, schema, .{ .sql = "SELECT '🌱'", .cursor = 9, .generation = 1 }));
}
test "completion allocation failures release every partially constructed suggestion" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            const columns = [_]m.Column{ .{ .name = try m.Name.init("id"), .type = .int64 }, .{ .name = try m.Name.init("value"), .type = .utf8 } };
            const result = try complete(allocator, try m.Name.init("items"), .{ .columns = &columns }, .{ .sql = "SELECT ", .cursor = 7, .generation = 0 });
            defer result.deinit(allocator);
        }
    }.run, .{});
}

test "catalog widths and type capabilities do not exceed the SQL compiler" {
    const allocator = std.testing.allocator;
    const columns = [_]m.Column{ .{ .name = try m.Name.init("long_column_name_beyond_sql"), .type = .int64 }, .{ .name = try m.Name.init("value"), .type = .utf8 } };
    const filtered = try complete(allocator, try m.Name.init("items"), .{ .columns = &columns }, .{ .sql = "SELECT long_", .cursor = 12, .generation = 1 });
    defer filtered.deinit(allocator);
    try std.testing.expectEqual(0, filtered.items.len);
    const unavailable = try complete(allocator, try m.Name.init("long_source_name_beyond_sql"), .{ .columns = &columns }, .{ .sql = "SE", .cursor = 2, .generation = 1 });
    defer unavailable.deinit(allocator);
    try std.testing.expectEqual(0, unavailable.items.len);
    const sum = try complete(allocator, try m.Name.init("items"), .{ .columns = &columns }, .{ .sql = "SELECT SU", .cursor = 9, .generation = 1 });
    defer sum.deinit(allocator);
    try std.testing.expectEqual(0, sum.items.len);
    const sum_column = try complete(allocator, try m.Name.init("items"), .{ .columns = &columns }, .{ .sql = "SELECT SUM(", .cursor = 11, .generation = 1 });
    defer sum_column.deinit(allocator);
    try std.testing.expectEqual(0, sum_column.items.len);
}
