//! Bounded, local SQL failure presentation shared by query interfaces. No I/O,
//! authorization or runtime capability negotiation. Never put source in logs.
const std = @import("std");
const sql = @import("Sql.zig");
const input = @import("SqlInput.zig");
const Self = @This();

pub const Kind = enum { syntax, unsupported, grammar_only, interface, binding, limit };
pub const Route = enum { query, mutation, declaration, inspection };
kind: Kind,
route: Route = .query,
cause: anyerror,
summary: []const u8,
hint: []const u8,
location: ?sql.Location = null,
line: usize = 1,
column: usize = 1,
// Owned, redacted and escaped context survives the caller's input buffer.
context: [512]u8 = @splat(0),
context_len: usize = 0,
caret: usize = 0,

const mutation_hint = "Use explicit column names for INSERT, for example INSERT INTO items (id, value) VALUES (1, 100). Use .help INSERT in the console to configure an authorized Table writer and discover execution and recovery. A query connection does not grant writes.";
const read_hint = "Use SELECT for finite reads; check /reference/sql/ for the supported syntax and interface for each operation.";
const grammar_hint = "This statement family exists in the reference grammar only; its submitted syntax has not been validated and there is no executable SQL route. See /reference/sql/grammar-surface/.";

/// Call only at a SQL compilation/inspection failure boundary. Unknown errors
/// return null so transport, permission and uncertain-outcome advice survives.
/// `inspection` means this interface accepts DESCRIBE/SHOW TABLES/EXPLAIN.
pub fn query(text: []const u8, cause: anyerror, inspection: bool) ?Self {
    const semantic = switch (cause) {
        error.UnknownSource => "The source is not the configured source or Table writer name. Inspect the configured source and use its exact name; CREATE TABLE does not configure a query source.",
        error.UnknownColumn, error.UnknownQualifier => "Inspect the configured schema and use its exact column names and source qualifier.",
        error.DuplicateProjection, error.InvalidProjection, error.InvalidOutputNames => "Select one to eight output positions with distinct result names. Use explicit AS names when selecting an input column more than once.",
        error.UnsupportedNullComparison => "Use IS NULL to test explicit nulls; use IS MISSING for missing Document fields.",
        error.UnsupportedAggregateLimit => "To limit aggregate input, use the documented aggregate over a limited derived table; an outer LIMIT is not an input limit.",
        error.UnsupportedCompoundPredicate => "This query profile does not support compound predicates; check its documented syntax before submitting.",
        error.UnsupportedAggregate => "Use COUNT(*) or SUM on an int64 column; other aggregates and input types are unsupported.",
        error.UnsupportedTableColumnCount, error.UnspecifiedNullability, error.UnsupportedTableKey, error.UnsupportedTableNullability, error.UnsupportedTableType => "CREATE TABLE requires exactly two columns: an INT64 NOT NULL key and a nullable INT64, BOOL, UTF8 or BINARY value. Use .help CREATE TABLE in the console.",
        error.DuplicateColumn => "Use distinct result names in SELECT, assigning names with AS where needed. Declarations also require distinct column names.",
        error.ImmutablePrimaryKey, error.UnsupportedMutationPredicate, error.InvalidMutationColumns, error.DuplicateMutationKey => "Use .help INSERT, .help UPDATE or .help DELETE in the console for bounded literal mutations and key equality.",
        error.TypeMismatch, error.InvalidPredicate => "Match the literal type to the declared column type; implicit conversions are unsupported.",
        else => null,
    };
    if (semantic) |hint| return .{ .kind = .binding, .cause = cause, .summary = "SQL cannot be bound to the configured source", .hint = hint };
    switch (cause) {
        error.UnsupportedDeclaration,
        error.UnsupportedDeclarationType,
        error.MutationBatchTooLarge,
        error.DeclarationTooManyColumns,
        error.UnsupportedStatement,
        error.InvalidSqlSyntax,
        error.UnsupportedConstruct,
        error.UnsupportedCatalog,
        error.StatementTooLarge,
        error.InvalidSqlEncoding,
        error.CommentTooDeep,
        error.PredicateTooComplex,
        error.InvalidColumnName,
        error.LiteralTooLarge,
        error.LiteralOutOfRange,
        error.InvalidNumericLiteral,
        error.InvalidBinaryLiteral,
        error.UnsupportedLiteral,
        => {},
        else => return null,
    }
    if (text.len > sql.max_statement_bytes) return .{ .kind = .limit, .cause = error.StatementTooLarge, .summary = "SQL exceeds the 4096-byte statement limit", .hint = "Shorten the statement; do not split one atomic mutation into unrelated commands." };
    var scan = input.Scan.init(text) catch return .{ .kind = .syntax, .cause = error.InvalidSqlEncoding, .summary = "SQL contains invalid encoding", .hint = "Supply UTF-8 SQL without NUL or reserved control bytes." };
    var first: ?input.Token = null;
    var second: ?input.Token = null;
    while (scan.next() catch null) |token| {
        if (token.kind == .space or token.kind == .comment) continue;
        if (first == null) first = token else {
            second = token;
            break;
        }
    }
    const start = if (first) |token| token.start else 0;
    var location: sql.Location = .{};
    var result: Self = undefined;
    if (word(text, first, "INSERT") or word(text, first, "UPDATE") or word(text, first, "DELETE")) {
        _ = sql.parseMutationLocated(text, &location) catch |err| return parseFailure(text, err, location, mutation_hint, .mutation);
        result = .{ .kind = .interface, .route = .mutation, .cause = cause, .summary = "Table mutation syntax is supported, but this query interface is read-only", .hint = mutation_hint };
    } else if (word(text, first, "CREATE") and (word(text, second, "TABLE") or word(text, second, "KV") or word(text, second, "DOCUMENT"))) {
        _ = sql.parseDeclarationLocated(text, &location) catch |err| return parseFailure(text, err, location, "Check the state declaration syntax in /reference/sql/. Use .help CREATE TABLE in the console for executable Table declarations.", .declaration);
        result = .{ .kind = .interface, .route = .declaration, .cause = cause, .summary = "State declaration syntax is supported, but query interfaces do not publish definitions", .hint = if (word(text, second, "TABLE")) "Use .help CREATE TABLE in the console to configure an authorized catalog and discover the supported schema and recovery." else "Use the offline Declaration compiler for review. SQL publication of KV and Document definitions is unavailable." };
    } else if (word(text, first, "GRANT") or word(text, first, "REVOKE") or (word(text, first, "CREATE") and (word(text, second, "CONNECTION") or word(text, second, "SOURCE") or word(text, second, "SINK")))) {
        result = .{ .kind = .grammar_only, .cause = cause, .summary = "Statement family has reference grammar but no SQL execution", .hint = grammar_hint };
    } else if (word(text, first, "SHOW") or word(text, first, "DESCRIBE") or word(text, first, "EXPLAIN")) {
        const parsed = (sql.parseInspectionLocated(text, &location) catch |err| return parseFailure(text, err, location, read_hint, .query)).?;
        if (parsed == .show and parsed.show != .tables) {
            result = .{ .kind = .grammar_only, .cause = cause, .summary = "Catalog listing has reference grammar but no SQL execution", .hint = "SHOW SOURCES, SHOW SINKS and SHOW CONNECTIONS are grammar-only. Use SHOW TABLES in the console for its configured scope." };
        } else if (!inspection) {
            result = .{ .kind = .interface, .route = .inspection, .cause = cause, .summary = "SQL inspection is unavailable on this query interface", .hint = "Use DESCRIBE, SHOW TABLES or EXPLAIN in the console. Flight clients can use the supported Flight metadata operations." };
        } else return null;
    } else {
        _ = sql.parseLocated(text, &location) catch |err| return parseFailure(text, err, location, read_hint, .query);
        // A syntactically valid statement may fail later in literal lowering.
        return .{ .kind = .binding, .cause = cause, .summary = "SQL literal or construct cannot be compiled", .hint = read_hint };
    }
    result.source(text, .{ .offset = start });
    return result;
}

fn word(text: []const u8, token: ?input.Token, expected: []const u8) bool {
    const value = token orelse return false;
    return value.kind == .word and std.ascii.eqlIgnoreCase(text[value.start..value.end], expected);
}

fn parseFailure(text: []const u8, cause: anyerror, location: sql.Location, hint: []const u8, route: Route) Self {
    const kind: Kind = switch (cause) {
        error.InvalidSqlSyntax, error.InvalidSqlEncoding, error.InvalidNumericLiteral, error.InvalidBinaryLiteral => .syntax,
        error.StatementTooLarge, error.CommentTooDeep, error.PredicateTooComplex, error.LiteralTooLarge, error.LiteralOutOfRange, error.InvalidColumnName, error.MutationBatchTooLarge, error.DeclarationTooManyColumns => .limit,
        else => if (location.expected != null) .syntax else .unsupported,
    };
    var result: Self = .{ .kind = kind, .route = route, .cause = cause, .summary = switch (kind) {
        .syntax => "SQL parse error",
        .limit => "SQL exceeds a supported bound",
        else => "SQL syntax or construct is unsupported",
    }, .hint = hint };
    result.source(text, location);
    return result;
}

/// Keep one bounded line around the offset. Hide string/number literals,
/// quoted identifiers and comments, including unfinished tokens. Every rendered
/// byte is ASCII and caret width follows escaping, not raw UTF-8 byte width.
fn source(self: *Self, text: []const u8, location: sql.Location) void {
    self.location = location;
    const offset = @min(location.offset, text.len);
    var line_start: usize = 0;
    for (text[0..offset], 0..) |byte, i| if (byte == '\n') {
        self.line += 1;
        line_start = i + 1;
    };
    self.column = offset - line_start + 1;
    const line_end = if (std.mem.indexOfScalarPos(u8, text, offset, '\n')) |end| end else text.len;
    const begin = @max(line_start, offset -| 64);
    const end = @min(line_end, begin + 120);
    var hidden: [sql.max_statement_bytes]bool = @splat(false);
    var scan = input.Scan.init(text) catch return;
    while (true) {
        const before = scan.position;
        const token = (scan.next() catch {
            @memset(hidden[before..text.len], true);
            break;
        }) orelse break;
        if (token.kind == .string or token.kind == .quoted or token.kind == .number or token.kind == .comment) @memset(hidden[token.start..token.end], true);
    }
    var out: std.Io.Writer = .fixed(&self.context);
    if (begin > line_start) out.writeAll("...") catch unreachable;
    for (text[begin..end], begin..) |byte, i| {
        if (i == offset) self.caret = out.end;
        if (hidden[i]) {
            out.writeByte('*') catch unreachable;
        } else switch (byte) {
            0x20...0x7e => out.writeByte(byte) catch unreachable,
            '\t' => out.writeAll("    ") catch unreachable,
            else => out.print("\\x{x:0>2}", .{byte}) catch unreachable,
        }
    }
    if (offset == end) self.caret = out.end;
    if (end < line_end) out.writeAll("...") catch unreachable;
    self.context_len = out.end;
}

/// gRPC's existing 128-byte public-message budget admits only static vocabulary
/// and numeric coordinates. SQL excerpts and values never cross this boundary.
pub fn renderRemote(self: *const Self, out: *std.Io.Writer) !void {
    switch (self.kind) {
        .syntax, .unsupported => {
            try out.writeAll(if (self.kind == .syntax) "SQL parse error" else "SQL construct unsupported");
            if (self.location != null) try out.print(" at line {d}, column {d}", .{ self.line, self.column });
            try out.writeAll(if (self.route == .mutation)
                "; use explicit INSERT columns and an authorized writer: console .help INSERT"
            else
                "; check supported syntax in /reference/sql/.");
        },
        .interface => try out.writeAll(if (self.route == .mutation)
            "Table mutation syntax is supported; this query interface is read-only. Use console .help INSERT with an authorized writer."
        else if (self.route == .inspection)
            "SQL inspection is unavailable here. Use console DESCRIBE/SHOW TABLES/EXPLAIN or Flight metadata operations."
        else
            "Declaration syntax is supported; this query interface cannot publish it. Use console .help CREATE TABLE."),
        .grammar_only => try out.writeAll("Statement family has reference grammar only; no SQL execution. See /reference/sql/grammar-surface/."),
        .binding => {
            try out.print("{s}: ", .{@errorName(self.cause)});
            try out.writeAll(switch (self.cause) {
                error.UnsupportedNullComparison => "use IS NULL or IS MISSING instead of comparison with NULL.",
                error.UnknownSource, error.UnknownColumn, error.UnknownQualifier => "check exact source and column names against the configured schema.",
                error.DuplicateProjection, error.InvalidProjection, error.InvalidOutputNames, error.DuplicateColumn => "use distinct output or declaration names; AS names SELECT outputs.",
                else => "check supported types, literals and aggregates in /reference/sql/.",
            });
        },
        .limit => try out.writeAll("SQL exceeds a supported bound. See /reference/sql/ for statement, identifier, literal and batch limits."),
    }
}

pub fn render(self: *const Self, out: *std.Io.Writer) !void {
    try out.print("{s} [{s}] ({s})", .{ self.summary, @tagName(self.kind), @errorName(self.cause) });
    if (self.location) |location| {
        try out.print(" at line {d}, column {d}", .{ self.line, self.column });
        if (location.expected) |expected| try out.print(": expected {s}", .{expected});
        try out.print("\n  {s}\n  ", .{self.context[0..self.context_len]});
        try out.splatByteAll(' ', self.caret);
        try out.writeAll("^--- error here");
    }
    try out.print("\n\n{s}\n", .{self.hint});
}

test "query boundaries distinguish parser evidence, grammar families and binding" {
    const cases = .{
        .{ "SELECT;", error.InvalidSqlSyntax, Kind.syntax, @as(usize, 7) },
        .{ "SELECT *\nFROM", error.InvalidSqlSyntax, Kind.syntax, @as(usize, 5) },
        .{ "INSERT INTO items VALUES (1, 100);", error.UnsupportedStatement, Kind.syntax, @as(usize, 19) },
        .{ "/* context */ INSERT INTO items (id, value) VALUES (1, 100);", error.UnsupportedStatement, Kind.interface, @as(usize, 15) },
        .{ "CREATE KV items (UTF8);", error.UnsupportedStatement, Kind.interface, @as(usize, 1) },
        .{ "CREATE CONNECTION unfinished", error.UnsupportedStatement, Kind.grammar_only, @as(usize, 1) },
        .{ "SHOW SOURCES;", error.UnsupportedCatalog, Kind.grammar_only, @as(usize, 1) },
        .{ "SELEC * FROM items;", error.UnsupportedStatement, Kind.unsupported, @as(usize, 1) },
        .{ "SELECT * FROM items JOIN other;", error.UnsupportedConstruct, Kind.unsupported, @as(usize, 21) },
        .{ "SELECT value AS copy, value AS copy FROM items;", error.DuplicateProjection, Kind.binding, @as(usize, 1) },
        .{ "SELECT id AS copy, value AS copy FROM items;", error.DuplicateColumn, Kind.binding, @as(usize, 1) },
        .{ "SELECT value FROM items;", error.InvalidOutputNames, Kind.binding, @as(usize, 1) },
    };
    inline for (cases) |case| {
        const result = query(case[0], case[1], true).?;
        try std.testing.expectEqual(case[2], result.kind);
        try std.testing.expectEqual(case[3], result.column);
        var remote: [128]u8 = undefined;
        var out: std.Io.Writer = .fixed(&remote);
        try result.renderRemote(&out);
        for (out.buffered()) |byte| try std.testing.expect(byte >= 32 and byte <= 126 and byte != '%');
    }
    try std.testing.expect(query("SELECT * FROM items", error.AuthorityTimeout, true) == null);
    try std.testing.expectEqual(Kind.binding, query("SELECT bad FROM items", error.UnknownColumn, true).?.kind);
    try std.testing.expectEqual(Kind.interface, query("SHOW TABLES", error.UnsupportedStatement, false).?.kind);
}

test "SQL diagnostic owns bounded inert context and hides literals and comments" {
    const cases = [_][]const u8{
        "SELECT * FROM items WHERE value = 'private-must-not-appear' junk;",
        "SELECT * FROM items WHERE value = 'private-must-not-appear",
        "SELECT * /* private-must-not-appear",
        "SELECT *\n\tFROM items WHERE value = '\x1b[31m' junk;",
    };
    for (cases) |text| {
        const result = query(text, error.UnsupportedConstruct, true).?;
        var buffer: [2048]u8 = undefined;
        var out: std.Io.Writer = .fixed(&buffer);
        try result.render(&out);
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "private-must-not-appear") == null);
        try std.testing.expect(std.mem.indexOfScalar(u8, out.buffered(), 27) == null);
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "^--- error here") != null);
    }
}
