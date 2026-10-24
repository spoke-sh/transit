//! Grammar continuations over an already authorized catalog. No native effects.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
const sql = q.fuze.Sql;
const input = q.fuze.SqlInput;
pub const max_items = 8;
/// Coverage describes matching candidates, never permission to execute SQL.
pub const Coverage = enum { complete, limited };
pub const Status = enum { ready, inside_text, unsupported };
pub const Request = struct { sql: []const u8, cursor: u16, generation: u32, mode: enum { sql, console } = .sql };
pub const Item = struct { text: []const u8, kind: enum { keyword, source, column, symbol, literal, meta }, detail: []const u8 };
pub const Completion = struct {
    coverage: Coverage = .complete,
    status: Status = .ready,
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
    coverage: Coverage,
    status: Status,
    profile: enum { unified_v1, catalog_v1, configuration_v1 } = .unified_v1,
    resource: u64,
    contract: [32]u8,
    resource_revision: u64,
    policy_revision: []const u8,
    range: ?input.Range,
    items: []const Item,
};
/// Shared console vocabulary; dispatchers must reject unimplemented operations.
pub const Meta = enum { connect, edit, execute, help, info, mode, quit, schema, show, sources, tables, timer };
pub fn metaSummary(command: Meta) []const u8 {
    return switch (command) {
        .connect => "Open a connection using a configuration file",
        .edit => "Edit the latest SQL statement in $EDITOR",
        .execute => "Run a JSON query file with typed parameters",
        .help => "Show command or topic help",
        .info => "Show account, database and source context",
        .mode => "Set the query result format",
        .quit => "Exit the console",
        .schema => "Show table columns, or list available tables",
        .show => "Show console settings and their sources",
        .sources => "Show session context; alias for .info",
        .tables => "List available tables",
        .timer => "Enable or disable query timing",
    };
}
const Builder = struct {
    allocator: std.mem.Allocator,
    prefix: []const u8,
    quoted: bool,
    items: [max_items]Item = undefined,
    exact: [max_items]bool = undefined,
    length: usize = 0,
    limited: bool = false,
    fn clear(self: *Builder) void {
        for (self.items[0..self.length]) |item| self.allocator.free(item.text);
    }
    fn add(self: *Builder, raw: []const u8, kind: @FieldType(Item, "kind"), detail: []const u8) !void {
        if (self.prefix.len > raw.len) return;
        if (self.quoted) {
            if (!std.mem.eql(u8, raw[0..self.prefix.len], self.prefix)) return;
        } else if (!std.ascii.eqlIgnoreCase(raw[0..self.prefix.len], self.prefix)) return;
        const identifier = kind == .source or kind == .column;
        if (self.quoted and !identifier) return;
        for (raw) |byte| if (byte < 32 or byte == 127) return;
        var buffer: [512]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        if (identifier) {
            try writer.writeByte('"');
            for (raw) |byte| {
                try writer.writeByte(byte);
                if (byte == '"') try writer.writeByte(byte);
            }
            try writer.writeByte('"');
        } else try writer.writeAll(raw);
        try offer(self.allocator, &self.items, &self.exact, &self.length, &self.limited, self.prefix, raw, writer.buffered(), kind, detail);
    }
    fn unsupported(self: *Builder, range: ?input.Range) !Completion {
        var result = try self.finish(range);
        result.status = .unsupported;
        return result;
    }
    fn finish(self: *Builder, range: ?input.Range) !Completion {
        return .{ .range = range, .coverage = if (self.limited) .limited else .complete, .status = if (range == null) .inside_text else .ready, .items = try self.allocator.dupe(Item, self.items[0..self.length]) };
    }
};
pub fn complete(allocator: std.mem.Allocator, name: []const u8, schema: q.fuze.Types.Type, request: Request) !Completion {
    const span = try input.active(request.sql, request.cursor, request.mode == .console);
    var result = try completeStatement(allocator, name, schema, .{ .sql = request.sql[span.start..span.end], .cursor = request.cursor - span.start, .generation = request.generation, .mode = request.mode });
    if (result.range) |*range| {
        range.start += span.start;
        range.end += span.start;
    }
    return result;
}
fn completeStatement(allocator: std.mem.Allocator, name: []const u8, schema: q.fuze.Types.Type, request: Request) !Completion {
    try schema.validate(.{});
    if (schema != .structure) return error.InvalidQuerySchema;
    _ = try input.Scan.init(request.sql);
    if (request.cursor > request.sql.len or !std.unicode.utf8ValidateSlice(request.sql[0..request.cursor])) return error.InvalidSqlCursor;
    if (request.mode == .console and std.mem.startsWith(u8, request.sql, ".")) return meta(allocator, request);
    const range = try input.replacement(request.sql, request.cursor);
    var builder: Builder = .{ .allocator = allocator, .prefix = "", .quoted = false };
    errdefer builder.clear();
    const selected = range orelse return builder.finish(null);
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const temporary = arena.allocator();
    var prefix = request.sql[selected.start..request.cursor];
    if (selected.quoted and prefix.len != 0) {
        prefix = prefix[1..];
        if (std.mem.endsWith(u8, prefix, "\"")) prefix = prefix[0 .. prefix.len - 1];
        prefix = try std.mem.replaceOwned(u8, temporary, prefix, "\"\"", "\"");
    }
    builder.prefix = prefix;
    builder.quoted = selected.quoted;
    const target = q.fuze.TableSelect.target(temporary, request.sql) catch |err| blk: {
        if (err == error.OutOfMemory) return err;
        break :blk null;
    };
    const qualifier = q.fuze.TableSelect.targetQualifier(temporary, request.sql) catch |err| blk: {
        if (err == error.OutOfMemory) return err;
        break :blk name;
    };
    var hints: q.fuze.SqlTyped.Editor = .{};
    if (q.fuze.TableSelect.compileWithEditor(temporary, request.sql[0..selected.start], name, schema, @splat(0), null, &hints)) |value| {
        var owned = value;
        owned.deinit();
    } else |err| if (err == error.OutOfMemory) return err;
    if (hints.name_role == null and hints.value_type == null and hints.words[0] == null and hints.symbols[0] == null) {
        var result = try builder.finish(range);
        result.status = .unsupported;
        return result;
    }
    if (hints.name_role != .source) if (target) |actual| if (!std.mem.eql(u8, actual, name)) return builder.unsupported(range);
    if (hints.qualifier) |actual| if (!std.mem.eql(u8, actual.slice(), qualifier)) return builder.unsupported(range);
    const has_sum = for (schema.structure) |column| {
        if (column.type == .int64) break true;
    } else false;
    if (hints.name_role) |role| switch (role) {
        .source => try builder.add(name, .source, "Authorized source"),
        .column => {
            for (schema.structure) |column| {
                if (hints.sum_only and column.type != .int64) continue;
                try builder.add(column.name, .column, @tagName(column.type));
            }
            if (hints.qualifier == null and (!hints.sum_only or has_sum)) try builder.add(qualifier, .source, "Column qualifier");
        },
        .proposed => {},
    };
    if (hints.value_type) |kind| switch (kind) {
        .utf8 => try builder.add("''", .literal, "UTF-8 literal"),
        .binary => try builder.add("X''", .literal, "Binary literal"),
        .uuid => try builder.add("'00000000-0000-0000-0000-000000000000'", .literal, "UUID literal"),
        .boolean, .date, .time, .timestamp, .interval, .structure, .list, .array, .map, .tagged_union, .json => {},
        else => try builder.add("0", .literal, "Typed numeric literal"),
    };
    for (hints.words) |word| if (word) |value| {
        if (std.mem.eql(u8, value, "SUM") and !has_sum) continue;
        if (hints.value_type != null and (std.mem.eql(u8, value, "NULL") or std.mem.eql(u8, value, "MISSING"))) continue;
        try builder.add(value, .keyword, "SQL grammar");
    };
    for (hints.symbols) |symbol| if (symbol) |tag| {
        if (hints.sum_only and tag == .star) continue;
        const value: ?[]const u8 = switch (tag) {
            .left => "(",
            .right => ")",
            .comma => ",",
            .dot => ".",
            .star => "*",
            .semi => null,
            .eq => "=",
            .ne => "<>",
            .lt => "<",
            .le => "<=",
            .gt => ">",
            .ge => ">=",
            else => null,
        };
        if (value) |text| try builder.add(text, .symbol, "SQL grammar");
    };
    return builder.finish(range);
}
/// Null means metadata is required; a local empty result is still definitive.
pub fn local(allocator: std.mem.Allocator, request: Request) !?Completion {
    const span = try input.active(request.sql, request.cursor, true);
    const text = request.sql[span.start..span.end];
    const cursor = request.cursor - span.start;
    if (!std.mem.startsWith(u8, text, ".")) return null;
    const end = std.mem.indexOfAny(u8, text, " \t\r\n") orelse text.len;
    if (cursor > end and std.mem.eql(u8, text[0..end], ".schema")) return null;
    var result = try meta(allocator, .{ .sql = text, .cursor = cursor, .generation = request.generation, .mode = .console });
    if (result.range) |*range| {
        range.start += span.start;
        range.end += span.start;
    }
    return result;
}

/// Retain a bounded, deterministic shortlist while continuing to establish
/// coverage. Exact-case prefix matches precede folded matches of the same role.
pub fn offer(allocator: std.mem.Allocator, items: *[max_items]Item, exact: *[max_items]bool, count: *usize, limited: *bool, prefix: []const u8, raw: []const u8, text: []const u8, kind: @FieldType(Item, "kind"), detail: []const u8) !void {
    for (items[0..count.*]) |item| if (std.mem.eql(u8, item.text, text)) return;
    const candidate: Item = .{ .text = text, .kind = kind, .detail = detail };
    const matches_exact = std.mem.startsWith(u8, raw, prefix);
    var position: usize = 0;
    while (position < count.* and !before(matches_exact, candidate, exact[position], items[position])) position += 1;
    if (count.* == max_items) {
        limited.* = true;
        if (position == max_items) return;
    }
    const owned = try allocator.dupe(u8, text);
    if (count.* == max_items) allocator.free(items[max_items - 1].text) else count.* += 1;
    std.mem.copyBackwards(Item, items[position + 1 .. count.*], items[position .. count.* - 1]);
    std.mem.copyBackwards(bool, exact[position + 1 .. count.*], exact[position .. count.* - 1]);
    exact[position] = matches_exact;
    items[position] = .{ .text = owned, .kind = kind, .detail = detail };
}
fn before(le: bool, lhs: Item, re: bool, rhs: Item) bool {
    if (le != re) return le;
    const lr = rank(lhs.kind);
    const rr = rank(rhs.kind);
    if (lr != rr) return lr < rr;
    return std.mem.order(u8, lhs.text, rhs.text) == .lt;
}
fn rank(kind: @FieldType(Item, "kind")) u8 {
    return switch (kind) {
        .column => 0,
        .source => 1,
        .keyword => 2,
        .literal => 3,
        .symbol => 4,
        .meta => 5,
    };
}

pub fn meta(allocator: std.mem.Allocator, request: Request) !Completion {
    const end = std.mem.indexOfAny(u8, request.sql, " \t\r\n") orelse request.sql.len;
    var builder: Builder = .{ .allocator = allocator, .prefix = request.sql[0..request.cursor], .quoted = false };
    errdefer builder.clear();
    if (request.cursor <= end) {
        inline for (@typeInfo(Meta).@"enum".field_names) |command| try builder.add("." ++ command, .meta, metaSummary(@field(Meta, command)));
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
        inline for (@typeInfo(Meta).@"enum".field_names) |command| try builder.add(command, .meta, metaSummary(@field(Meta, command)));
        for ([_][]const u8{ "--all", "sql", "settings", "shortcuts", "INSERT", "UPDATE", "DELETE", "CREATE TABLE", "ALTER TABLE", "DROP TABLE" }) |topic| try builder.add(topic, .meta, "Local help topic");
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
    const name = fixture.source;
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
            const columns = [_]q.fuze.Types.Field{ .{ .name = "id", .type = .int64 }, .{ .name = "value", .type = .utf8 } };
            const result = try complete(allocator, "items", .{ .structure = &columns }, .{ .sql = "SELECT ", .cursor = 7, .generation = 0 });
            defer result.deinit(allocator);
        }
    }.run, .{});
}

test "catalog widths and type capabilities do not exceed the SQL compiler" {
    const allocator = std.testing.allocator;
    const columns = [_]q.fuze.Types.Field{ .{ .name = "long_column_name_beyond_sql", .type = .int64 }, .{ .name = "value", .type = .utf8 } };
    const filtered = try complete(allocator, "items", .{ .structure = &columns }, .{ .sql = "SELECT long_", .cursor = 12, .generation = 1 });
    defer filtered.deinit(allocator);
    try std.testing.expectEqual(1, filtered.items.len);
    const unavailable = try complete(allocator, "long_source_name_beyond_sql", .{ .structure = &columns }, .{ .sql = "SE", .cursor = 2, .generation = 1 });
    defer unavailable.deinit(allocator);
    try std.testing.expectEqual(1, unavailable.items.len);
    const sum = try complete(allocator, "items", .{ .structure = &columns }, .{ .sql = "SELECT SU", .cursor = 9, .generation = 1 });
    defer sum.deinit(allocator);
    try std.testing.expectEqual(1, sum.items.len);
    const sum_column = try complete(allocator, "items", .{ .structure = &columns }, .{ .sql = "SELECT SUM(", .cursor = 11, .generation = 1 });
    defer sum_column.deinit(allocator);
    try std.testing.expectEqual(2, sum_column.items.len);
}

test "coverage distinguishes unique, bounded and empty matching sets" {
    const t = std.testing;
    var builder: Builder = .{ .allocator = t.allocator, .prefix = "", .quoted = false };
    defer builder.clear();
    for ([_][]const u8{ "z", "y", "x", "w", "v", "u", "t", "s" }) |name| try builder.add(name, .column, "int64");
    try t.expect(!builder.limited);
    try builder.add("a", .column, "int64");
    try t.expect(builder.limited);
    try t.expectEqual(max_items, builder.length);
    try t.expectEqualStrings("\"a\"", builder.items[0].text);
    try t.expectEqualStrings("\"y\"", builder.items[7].text);
    const local_result = (try local(t.allocator, .{ .sql = "SELECT 1;\n .mo", .cursor = 14, .generation = 1, .mode = .console })).?;
    defer local_result.deinit(t.allocator);
    try t.expectEqual(Coverage.complete, local_result.coverage);
    try t.expectEqualStrings(".mode", local_result.items[0].text);
    try t.expectEqual(11, local_result.range.?.start);
    try t.expect(try local(t.allocator, .{ .sql = ".schema it", .cursor = 10, .generation = 1, .mode = .console }) == null);
    const columns = [_]q.fuze.Types.Field{.{ .name = "value", .type = .utf8 }};
    const result = try complete(t.allocator, "items", .{ .structure = &columns }, .{ .sql = ".help\nSELECT va FROM items", .cursor = 15, .generation = 1, .mode = .console });
    defer result.deinit(t.allocator);
    try t.expectEqualStrings("\"value\"", result.items[0].text);
    try t.expectEqual(13, result.range.?.start);
    try t.expectEqual(15, result.range.?.end);
    const inside = try complete(t.allocator, "items", .{ .structure = &columns }, .{ .sql = "SELECT 'va", .cursor = 10, .generation = 1 });
    defer inside.deinit(t.allocator);
    try t.expectEqual(Status.inside_text, inside.status);
}
