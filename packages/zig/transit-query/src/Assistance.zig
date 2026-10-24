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
/// A local draft edit, not metadata evidence or permission to execute SQL.
pub const Edit = struct { text: []const u8, cursor: usize };
/// Apply an already validated candidate with separators at adjacent word/value
/// tokens. Output borrows the caller's buffer, which must not overlap the inputs.
/// Existing whitespace, punctuation, quoting and the statement suffix survive.
pub fn edit(text: []const u8, range: input.Range, candidate: []const u8, output: []u8) !Edit {
    _ = try input.Scan.init(text);
    var inserted = try input.Scan.init(candidate);
    if (range.start > range.end or range.end > text.len or
        !std.unicode.utf8ValidateSlice(text[0..range.start]) or
        !std.unicode.utf8ValidateSlice(text[0..range.end])) return error.InvalidSqlCursor;
    const first = try inserted.next() orelse return error.InvalidSqlResponse;
    var last = first;
    while (try inserted.next()) |token| last = token;
    var prefix = try input.Scan.init(text[0..range.start]);
    var left: ?input.Token = null;
    while (try prefix.next()) |token| left = token;
    var suffix = try input.Scan.init(text[range.end..]);
    const right = try suffix.next();
    const leading = separates(left, first);
    const trailing = separates(last, right);
    const cursor = range.start + @as(usize, @intFromBool(leading)) + candidate.len;
    const length = cursor + @intFromBool(trailing) + text.len - range.end;
    if (length > sql.max_statement_bytes or length > output.len) return error.StatementTooLarge;
    @memcpy(output[0..range.start], text[0..range.start]);
    if (leading) output[range.start] = ' ';
    @memcpy(output[cursor - candidate.len .. cursor], candidate);
    if (trailing) output[cursor] = ' ';
    @memcpy(output[cursor + @intFromBool(trailing) .. length], text[range.end..]);
    return .{ .text = output[0..length], .cursor = cursor };
}
fn separates(left: ?input.Token, right: ?input.Token) bool {
    return atom(left) and atom(right);
}
fn atom(token: ?input.Token) bool {
    const value = token orelse return false;
    return switch (value.kind) {
        .word, .number, .string, .quoted => true,
        .space, .comment, .symbol => false,
    };
}
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

/// Filter an already disclosed shortlist for presentation only. A preview has
/// no current metadata evidence and cannot establish coverage or authorize an
/// insertion. Keep the surrounding statement (including its suffix) identical.
pub fn refine(previous: Request, current: Request, prior: Response, matches: *[max_items]Item) !usize {
    const range = prior.range orelse return 0;
    if (prior.status != .ready) return 0;
    if (previous.mode != current.mode or range.start > range.end or range.end > previous.sql.len) return 0;
    const span = try input.active(current.sql, current.cursor, current.mode == .console);
    const statement = current.sql[span.start..span.end];
    const cursor = current.cursor - span.start;
    if (range.start < span.start) return 0;
    var next = (if (prior.profile == .configuration_v1)
        q.SettingsAssistance.replacement(statement, range.start - span.start, cursor)
    else if (current.mode == .console and std.mem.startsWith(u8, statement, "."))
        metaRange(statement, cursor)
    else
        try input.replacement(statement, cursor)) orelse return 0;
    next.start += span.start;
    next.end += span.start;
    if (range.start != next.start or range.quoted != next.quoted or
        !std.mem.eql(u8, previous.sql[0..range.start], current.sql[0..next.start]) or
        !std.mem.eql(u8, previous.sql[range.end..], current.sql[next.end..])) return 0;
    var count: usize = 0;
    for (prior.items) |item| {
        const identifier = item.kind == .source or item.kind == .column;
        if (next.quoted and !identifier) continue;
        var prefix = Spelling.init(current.sql[next.start..current.cursor], next.quoted);
        var candidate = if (identifier) try Spelling.identifier(item.text) else Spelling.init(item.text, false);
        const matches_prefix = while (prefix.next()) |byte| {
            const actual = candidate.next() orelse break false;
            if (if (next.quoted) byte != actual else std.ascii.toLower(byte) != std.ascii.toLower(actual)) break false;
        } else true;
        if (!matches_prefix) continue;
        if (count == matches.len) break;
        matches[count] = item;
        count += 1;
    }
    return count;
}
const Spelling = struct {
    text: []const u8,
    quoted: bool,
    fn identifier(text: []const u8) !Spelling {
        // A disambiguated column is inserted as "alias"."column", but its
        // matching prefix belongs to the column's raw name, not the alias.
        var scan = try input.Scan.init(text);
        var name = text;
        while (try scan.next()) |token| if (token.kind == .quoted) {
            name = text[token.start..token.end];
        };
        return init(name, true);
    }
    fn init(text: []const u8, quoted: bool) Spelling {
        var value = text;
        if (quoted and std.mem.startsWith(u8, value, "\"")) {
            value = value[1..];
            if (std.mem.endsWith(u8, value, "\"")) value = value[0 .. value.len - 1];
        }
        return .{ .text = value, .quoted = quoted };
    }
    fn next(self: *Spelling) ?u8 {
        if (self.text.len == 0) return null;
        const byte = self.text[0];
        self.text = self.text[1..];
        if (self.quoted and byte == '"' and std.mem.startsWith(u8, self.text, "\"")) self.text = self.text[1..];
        return byte;
    }
};

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
        return builder.finish(metaRange(request.sql, request.cursor));
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
    return builder.finish(metaRange(request.sql, request.cursor));
}

fn metaRange(text: []const u8, cursor: u16) input.Range {
    const end = std.mem.indexOfAny(u8, text, " \t\r\n") orelse text.len;
    if (cursor <= end) return .{ .start = 0, .end = @intCast(end) };
    var start = end;
    while (start < cursor and std.mem.indexOfScalar(u8, " \t", text[start]) != null) start += 1;
    var finish: usize = cursor;
    while (finish < text.len and std.mem.indexOfScalar(u8, " \t\r\n", text[finish]) == null) finish += 1;
    return .{ .start = @intCast(start), .end = @intCast(finish) };
}

test "completion edits separate adjacent tokens without reformatting the draft" {
    const Case = struct { text: []const u8, start: u16, end: u16, candidate: []const u8, expected: []const u8 };
    var output: [sql.max_statement_bytes]u8 = undefined;
    for ([_]Case{
        .{ .text = "SHOW", .start = 4, .end = 4, .candidate = "ALL", .expected = "SHOW ALL|" },
        .{ .text = "SHOW ", .start = 5, .end = 5, .candidate = "ALL", .expected = "SHOW ALL|" },
        .{ .text = "SHOW\t\n", .start = 6, .end = 6, .candidate = "ALL", .expected = "SHOW\t\nALL|" },
        .{ .text = "show;", .start = 4, .end = 4, .candidate = "ALL", .expected = "show ALL|;" },
        .{ .text = "SH", .start = 0, .end = 2, .candidate = "SHOW", .expected = "SHOW|" },
        .{ .text = "SHOW AL;", .start = 5, .end = 7, .candidate = "ALL", .expected = "SHOW ALL|;" },
        .{ .text = "SHOW ALL", .start = 5, .end = 8, .candidate = "ALL", .expected = "SHOW ALL|" },
        .{ .text = "SET", .start = 3, .end = 3, .candidate = "query.statement_timeout", .expected = "SET query.statement_timeout|" },
        .{ .text = "RESET", .start = 5, .end = 5, .candidate = "ALL", .expected = "RESET ALL|" },
        .{ .text = "SELECT i.", .start = 9, .end = 9, .candidate = "\"id\"", .expected = "SELECT i.\"id\"|" },
        .{ .text = "SELECT na FROM items", .start = 7, .end = 9, .candidate = "\"name\"", .expected = "SELECT \"name\"| FROM items" },
        .{ .text = "SELECT \"na\"FROM items", .start = 7, .end = 11, .candidate = "\"name\"", .expected = "SELECT \"name\"| FROM items" },
        .{ .text = "SELECT na,other", .start = 7, .end = 9, .candidate = "\"name\"", .expected = "SELECT \"name\"|,other" },
        .{ .text = "SELECT COUNT()", .start = 13, .end = 13, .candidate = "*", .expected = "SELECT COUNT(*|)" },
        .{ .text = "SELECT SUM", .start = 10, .end = 10, .candidate = "(", .expected = "SELECT SUM(|" },
        .{ .text = "SELECT n=0", .start = 7, .end = 8, .candidate = "\"n\"", .expected = "SELECT \"n\"|=0" },
        .{ .text = "SELECT /* keep */na-- tail", .start = 17, .end = 19, .candidate = "\"name\"", .expected = "SELECT /* keep */\"name\"|-- tail" },
        .{ .text = "SELECT 1;SHOW", .start = 13, .end = 13, .candidate = "ALL", .expected = "SELECT 1;SHOW ALL|" },
        .{ .text = "SELECT \"🌱\",na", .start = 14, .end = 16, .candidate = "\"a\"\"b\"", .expected = "SELECT \"🌱\",\"a\"\"b\"|" },
        .{ .text = "SELECT \"a\"\"b\"", .start = 13, .end = 13, .candidate = "FROM", .expected = "SELECT \"a\"\"b\" FROM|" },
        .{ .text = "SELECT", .start = 6, .end = 6, .candidate = "''", .expected = "SELECT ''|" },
        .{ .text = "SELECT 1", .start = 8, .end = 8, .candidate = "FROM", .expected = "SELECT 1 FROM|" },
        .{ .text = "SELECT 'a'", .start = 10, .end = 10, .candidate = "'b'", .expected = "SELECT 'a' 'b'|" },
        .{ .text = ".timer o", .start = 7, .end = 8, .candidate = "on", .expected = ".timer on|" },
    }) |case| {
        const result = try edit(case.text, .{ .start = case.start, .end = case.end }, case.candidate, &output);
        errdefer std.debug.print("completion edit: {s} + {s}\n", .{ case.text, case.candidate });
        const cursor = std.mem.indexOfScalar(u8, case.expected, '|').?;
        try std.testing.expectEqual(cursor, result.cursor);
        try std.testing.expectEqualStrings(case.expected[0..cursor], result.text[0..result.cursor]);
        try std.testing.expectEqualStrings(case.expected[cursor + 1 ..], result.text[result.cursor..]);
    }
}

test "completion edits check UTF-8 ranges and count separators in the byte budget" {
    const t = std.testing;
    var output: [sql.max_statement_bytes]u8 = @splat(0xaa);
    try t.expectError(error.InvalidSqlCursor, edit("SHOW", .{ .start = 4, .end = 3 }, "ALL", &output));
    try t.expectError(error.InvalidSqlCursor, edit("SHOW", .{ .start = 4, .end = 5 }, "ALL", &output));
    try t.expectError(error.InvalidSqlCursor, edit("\"🌱\"", .{ .start = 2, .end = 5 }, "name", &output));
    try t.expectError(error.InvalidSqlEncoding, edit("SHOW", .{ .start = 4, .end = 4 }, "\xff", &output));
    try t.expectError(error.InvalidSqlResponse, edit("SHOW", .{ .start = 4, .end = 4 }, "", &output));
    try t.expectError(error.StatementTooLarge, edit("SHOW", .{ .start = 4, .end = 4 }, "ALL", output[0..7]));
    const full: [sql.max_statement_bytes - 1]u8 = @splat('a');
    try t.expectError(error.StatementTooLarge, edit(&full, .{ .start = full.len, .end = full.len }, "b", &output));
    try t.expectEqualSlices(u8, &(@as([sql.max_statement_bytes]u8, @splat(0xaa))), &output);
    const exact: [sql.max_statement_bytes - 2]u8 = @splat('a');
    const result = try edit(&exact, .{ .start = exact.len, .end = exact.len }, "b", &output);
    try t.expectEqual(sql.max_statement_bytes, result.text.len);
    try t.expectEqualStrings(" b", result.text[result.text.len - 2 ..]);
}

test "shortlist previews preserve token context and identifier spelling" {
    const items: []const Item = &.{
        .{ .text = "SELECT", .kind = .keyword, .detail = "" },
        .{ .text = "SET", .kind = .keyword, .detail = "" },
        .{ .text = "\"name\"", .kind = .column, .detail = "" },
        .{ .text = "\"a\"\"bc\"", .kind = .column, .detail = "" },
        .{ .text = "\"🌱name\"", .kind = .column, .detail = "" },
    };
    const Case = struct { before: []const u8, after: []const u8, start: u16, end: u16, cursor: u16, quoted: bool = false, expected: []const []const u8 };
    for ([_]Case{
        .{ .before = "SE", .after = "SEL", .start = 0, .end = 2, .cursor = 3, .expected = &.{"SELECT"} },
        .{ .before = "SEL", .after = "se", .start = 0, .end = 3, .cursor = 2, .expected = &.{ "SELECT", "SET" } },
        .{ .before = "SE", .after = "SE ", .start = 0, .end = 2, .cursor = 3, .expected = &.{} },
        .{ .before = "SELECT na FROM items", .after = "SELECT nam FROM items", .start = 7, .end = 9, .cursor = 10, .expected = &.{"\"name\""} },
        .{ .before = "SELECT na FROM items", .after = "SELECT nam FROM other", .start = 7, .end = 9, .cursor = 10, .expected = &.{} },
        .{ .before = "SELECT na FROM items", .after = "SELECT 'na FROM items", .start = 7, .end = 9, .cursor = 10, .expected = &.{} },
        .{ .before = "SELECT na FROM items", .after = "SELECT /*na FROM items", .start = 7, .end = 9, .cursor = 11, .expected = &.{} },
        .{ .before = "SELECT \"n", .after = "SELECT \"na", .start = 7, .end = 9, .cursor = 10, .quoted = true, .expected = &.{"\"name\""} },
        .{ .before = "SELECT \"n", .after = "SELECT \"N", .start = 7, .end = 9, .cursor = 9, .quoted = true, .expected = &.{} },
        .{ .before = "SELECT \"a", .after = "SELECT \"a\"\"b", .start = 7, .end = 9, .cursor = 12, .quoted = true, .expected = &.{"\"a\"\"bc\""} },
        .{ .before = "SELECT \"", .after = "SELECT \"🌱", .start = 7, .end = 8, .cursor = 12, .quoted = true, .expected = &.{"\"🌱name\""} },
        .{ .before = "SELECT 1;\nSELECT n FROM items", .after = "SELECT 1;\nSELECT na FROM items", .start = 17, .end = 18, .cursor = 19, .expected = &.{"\"name\""} },
        .{ .before = ".schema n", .after = ".schema na", .start = 8, .end = 9, .cursor = 10, .expected = &.{"\"name\""} },
    }) |case| {
        var matches: [max_items]Item = undefined;
        const count = try refine(.{ .sql = case.before, .cursor = case.end, .generation = 1, .mode = .console }, .{ .sql = case.after, .cursor = case.cursor, .generation = 2, .mode = .console }, .{ .generation = 1, .coverage = .limited, .status = .ready, .resource = 4, .contract = @splat(7), .resource_revision = 1, .policy_revision = "1", .range = .{ .start = case.start, .end = case.end, .quoted = case.quoted }, .items = items }, &matches);
        errdefer std.debug.print("preview: {s} -> {s}\n", .{ case.before, case.after });
        try std.testing.expectEqual(case.expected.len, count);
        for (case.expected, matches[0..count]) |expected, actual| try std.testing.expectEqualStrings(expected, actual.text);
    }
}

test "previews match disambiguated columns and dotted settings by owner spelling" {
    var matches: [max_items]Item = undefined;
    var prior: Response = .{ .generation = 1, .coverage = .limited, .status = .ready, .resource = 4, .contract = @splat(7), .resource_revision = 1, .policy_revision = "1", .range = .{ .start = 7, .end = 8 }, .items = &.{
        .{ .text = "\"left\".\"name\"", .kind = .column, .detail = "" },
        .{ .text = "\"right\".\"name\"", .kind = .column, .detail = "" },
    } };
    const columns = try refine(.{ .sql = "SELECT n FROM items", .cursor = 8, .generation = 1 }, .{ .sql = "SELECT na FROM items", .cursor = 9, .generation = 2 }, prior, &matches);
    try std.testing.expectEqual(2, columns);
    try std.testing.expectEqualStrings("\"left\".\"name\"", matches[0].text);
    try std.testing.expectEqualStrings("\"right\".\"name\"", matches[1].text);
    prior.profile = .configuration_v1;
    prior.range = .{ .start = 5, .end = 12 };
    prior.items = &.{.{ .text = "query.statement_timeout", .kind = .keyword, .detail = "" }};
    const settings = try refine(.{ .sql = "SHOW query.s", .cursor = 12, .generation = 1 }, .{ .sql = "SHOW query.st", .cursor = 13, .generation = 2 }, prior, &matches);
    try std.testing.expectEqual(1, settings);
    try std.testing.expectEqualStrings("query.statement_timeout", matches[0].text);
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
