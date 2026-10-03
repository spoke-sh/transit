//! Bounded, local SQL failure presentation shared by query interfaces. No I/O,
//! authorization or runtime capability negotiation. Never put source in logs.
const std = @import("std");
const sql = @import("Sql.zig");
const d = @import("transit_protocol").Diagnostic;
const input = @import("SqlInput.zig");
const Self = @This();

pub const Kind = enum { syntax, unsupported, grammar_only, interface, binding, limit };
pub const category = @import("SqlCodes.zig").category;
pub const Route = enum { query, mutation, declaration, inspection };
kind: Kind,
route: Route = .query,
cause: anyerror,
summary: []const u8,
hint: []const u8,
location: ?sql.Location = null,
binding: sql.Binding = .{},
line: usize = 1,
column: usize = 1,
// Owned, redacted and escaped context survives the caller's input buffer.
context: [512]u8 = @splat(0),
context_len: usize = 0,
caret: usize = 0,
detail: [1024]u8 = @splat(0),
detail_len: usize = 0,

const mutation_hint = "Use explicit column names for INSERT, for example INSERT INTO items (id, value) VALUES (1, 100). Use .help INSERT in the console to configure an authorized Table writer and discover execution and recovery. A query connection does not grant writes.";
const read_hint = "Use .help SQL in the console for supported syntax; .schema and .sources show the configured columns and source.";
const grammar_hint = "This statement family has no executable SQL route; its submitted syntax has not been validated. Use .help SQL in the console for supported statements.";

/// Project only the compiler's original evidence. No follow-up metadata reads.
pub fn structured(self: Self) !d {
    const classification: d.Category = switch (self.kind) {
        .syntax => .syntax,
        .binding => @import("SqlCodes.zig").category(self.cause) orelse return error.UnmappedSqlDiagnostic,
        .limit => .limit,
        .unsupported, .grammar_only, .interface => .unsupported,
    };
    var value = try d.init(@import("SqlCodes.zig").fromError(self.cause) orelse return error.UnmappedSqlDiagnostic, classification, if (self.kind == .binding) .bind else .parse, .not_submitted, .local_before_dispatch, self.summary);
    value.cause = try d.Code.init(@errorName(self.cause));
    if (self.location) |location| value.location = .{ .offset = .init(location.offset), .length = .init(0), .line = .init(self.line), .byte_column = .init(self.column) };
    const context = self.binding;
    if (context.subject) |subject| try value.text(if (self.cause == error.UnknownQualifier) .qualifier else .column, .caller, subject.slice());
    if (context.scope_len != 0) try value.text(.scope, .caller, context.scope[0..context.scope_len]);
    if (context.expected) |expected| try value.text(.expected_type, .schema, expected);
    if (context.actual) |actual| try value.text(.actual_type, .caller, actual);
    if (context.literal_len != 0) try value.add(.{
        .field = .supplied_value,
        .origin = .caller,
        .availability = if (context.literal_truncated) .truncated else .provided,
        .value = .{ .text = try d.Text.init(context.literal[0..context.literal_len]) },
    });
    if (context.key) |key| try value.fact(.key, .caller, .{ .signed = .init(key) });
    inline for (.{ .{ "input_row", d.Field.input_row }, .{ "previous_row", d.Field.first_occurrence }, .{ "parameter", d.Field.parameter }, .{ "expected_count", d.Field.expected_count }, .{ "actual_count", d.Field.actual_count } }) |mapping| {
        if (@field(context, mapping[0])) |number| try value.fact(mapping[1], .caller, .{ .unsigned = .init(number) });
    }
    if (context.missing_parameter) |index| try value.fact(.parameter, .caller, .{ .unsigned = .init(index) });
    for (context.parameter_sites) |site| if (site) |offset| try value.fact(.parameter_use, .caller, .{ .unsigned = .init(offset) });
    if (context.expected_schema) |digest| try value.fact(.expected_schema, .caller, .{ .digest = digest });
    if (context.actual_schema) |digest| try value.fact(.actual_schema, .schema, .{ .digest = digest });
    try value.action(if (self.cause == error.SourceChanged or self.cause == error.QuerySourceChanged) .recompile else if (self.kind == .interface or self.kind == .grammar_only) .inspect_scope else .correct_input);
    try value.validate();
    return value;
}

test "SQL structured diagnostics preserve binding evidence without console commands" {
    var context: sql.Binding = .{ .subject = try @import("model.zig").Name.init("value"), .expected = "int64", .actual = "utf8", .parameter = 1, .parameter_sites = .{ 12, 35, null }, .location = .{ .offset = 12 } };
    sql.Binding.supplied(&context, @import("Unified.zig").Scalar{ .utf8 = "secret-is-caller-input" });
    const diagnostic = bound("SELECT $1 FROM items WHERE value = $1", error.TypeMismatch, false, context).?;
    const result = try diagnostic.structured();
    try std.testing.expectEqualStrings("sql.type_mismatch", result.code.slice());
    try std.testing.expectEqual(d.Outcome.not_submitted, result.outcome);
    try std.testing.expectEqual(@as(u64, 12), try result.location.?.offset.value());
    try std.testing.expectEqual(d.Field.parameter_use, result.facts[5].?.field);
    try std.testing.expectEqual(@as(u64, 35), try result.facts[6].?.value.?.unsigned.value());
    try std.testing.expectEqual(d.ActionKind.correct_input, result.actions[0].?.kind);
    try std.testing.expect(std.mem.indexOf(u8, result.message.slice(), ".help") == null);
}

test "SQL code registry is unique and every entry projects a valid bounded value" {
    const entries = @import("SqlCodes.zig").entries;
    for (entries, 0..) |entry, i| {
        for (entries[0..i]) |previous| {
            try std.testing.expect(entry.cause != previous.cause);
            try std.testing.expect(!std.mem.eql(u8, entry.code, previous.code));
        }
        const value: Self = .{ .kind = .binding, .cause = entry.cause, .summary = "Invalid SQL.", .hint = "Inspect the supplied statement." };
        _ = try value.structured();
    }
    try std.testing.expect(query("SELECT * FROM items", error.OutOfMemory, true) == null);
}

/// Call only at a SQL compilation/inspection failure boundary. Unknown errors
/// return null so transport, permission and uncertain-outcome advice survives.
/// `inspection` means this interface accepts DESCRIBE/SHOW TABLES/EXPLAIN.
pub fn query(text: []const u8, cause: anyerror, inspection: bool) ?Self {
    const semantic = switch (cause) {
        error.InvalidColumnCount => "Check the column count allowed by this source profile.",
        error.InvalidMutationPlan => "Supply one to three distinct typed INSERT rows, one value UPDATE or one primary-key DELETE.",
        error.UnknownSource => "The source is not the configured source or Table writer name. Use .sources in the console and use the exact configured name; CREATE TABLE does not configure a query source.",
        error.UnknownColumn, error.UnknownQualifier => "Use .schema and .sources in the console to check exact column names and the source qualifier.",
        error.DuplicateProjection, error.InvalidProjection, error.InvalidOutputNames => "Select one to eight output positions with distinct result names. Use explicit AS names when selecting an input column more than once.",
        error.UnsupportedNullComparison => "Use IS NULL to test explicit nulls; use IS MISSING for missing Document fields.",
        error.UnsupportedAggregateLimit => "To limit aggregate input, use an aggregate over a limited derived table; an outer LIMIT is not an input limit. Use .help SQL in the console for an example.",
        error.UnsupportedAggregate => "Use COUNT(*), COUNT(column), or SUM on an int64 column; other aggregate forms are unsupported.",
        error.UnsupportedTableColumnCount, error.UnspecifiedNullability, error.UnsupportedTableKey, error.UnsupportedTableNullability, error.UnsupportedTableType => "CREATE TABLE requires exactly two columns: an INT64 NOT NULL key and a nullable INT64, BOOL, UTF8 or BINARY value. Use .help CREATE TABLE in the console.",
        error.NotTableDeclaration => "This catalog compiler accepts CREATE TABLE. KV and Document SQL declarations have no publication route.",
        error.DuplicateColumn => "Use distinct result names in SELECT, assigning names with AS where needed. Declarations also require distinct column names.",
        error.NullPrimaryKey => "Supply a non-NULL INT64 primary key. No mutation command was prepared.",
        error.ParameterCountMismatch, error.ParameterGap, error.ParameterTypeConflict, error.InvalidParameterIndex, error.InvalidParameterSite, error.UnboundParameters => "Use consecutive positional parameters beginning with $1 and supply one exact scalar binding for each index. Repeated indices must have the same type.",
        error.SourceChanged, error.QuerySourceChanged => "Inspect the current source declaration and explicitly prepare the statement again against it.",
        error.InvalidUtf8, error.NonFiniteValue, error.CellTooLarge => "Supply a finite scalar with valid UTF-8 text and within the configured cell byte bound.",
        error.InvalidDocumentInteger, error.InvalidQueryInteger, error.InvalidQueryScalar, error.InvalidHex => "Supply the exact canonical scalar encoding required by the parameter type; integer bindings use decimal strings and binary bindings use hexadecimal bytes.",
        error.ImmutablePrimaryKey, error.UnsupportedMutationPredicate, error.InvalidMutationColumns, error.DuplicateMutationKey => "Use .help INSERT, .help UPDATE or .help DELETE in the console for bounded literal mutations and key equality.",
        error.TypeMismatch, error.InvalidPredicate => "Match the literal type to the declared column type; implicit conversions are unsupported.",
        else => null,
    };
    if (semantic) |hint| return .{ .kind = .binding, .cause = cause, .summary = switch (cause) {
        error.UnknownSource => "Unknown SQL source",
        error.UnknownColumn => "Unknown column in this scope",
        error.UnknownQualifier => "Unknown source qualifier in this scope",
        error.DuplicateProjection => "Duplicate result column; assign distinct output names",
        error.DuplicateColumn => "Duplicate column name",
        error.TypeMismatch => "SQL value has the wrong type",
        error.ImmutablePrimaryKey => "UPDATE cannot change the primary key",
        error.DuplicateMutationKey => "INSERT repeats a primary key within the statement",
        error.NullPrimaryKey => "The primary key cannot be NULL",
        error.UnsupportedAggregate => "Unsupported aggregate function or input type",
        error.ParameterCountMismatch => "The number of bindings does not match the SQL parameters",
        error.ParameterGap => "SQL parameter indices must be consecutive from $1",
        error.ParameterTypeConflict => "A repeated parameter requires incompatible types",
        error.InvalidParameterIndex => "SQL parameter indices start at $1",
        error.InvalidParameterSite => "A parameter is not supported at this SQL position",
        error.UnboundParameters => "SQL parameters require explicit bindings",
        error.SourceChanged, error.QuerySourceChanged => "The prepared SQL source or schema changed",
        error.InvalidUtf8 => "The SQL value contains invalid UTF-8",
        error.NonFiniteValue => "The SQL value must be finite",
        error.CellTooLarge => "The SQL value exceeds the cell byte bound",
        error.InvalidDocumentInteger, error.InvalidQueryInteger, error.InvalidQueryScalar, error.InvalidHex => "The parameter binding has an invalid scalar encoding",
        else => "SQL cannot be bound to the configured source",
    }, .hint = hint };
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
        const hint = if (word(text, second, "TABLE")) "Use .help CREATE TABLE in the console for supported types, nullability, catalog configuration and recovery." else "SQL publication of KV and Document definitions is unavailable. Use .help SQL in the console for supported statements.";
        _ = sql.parseDeclarationLocated(text, &location) catch |err| return parseFailure(text, err, location, hint, .declaration);
        result = .{ .kind = .interface, .route = .declaration, .cause = cause, .summary = "State declaration syntax is supported, but query interfaces do not publish definitions", .hint = hint };
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

/// Consume context captured by the failing compiler operation, never by a
/// later catalog read or a guess at similarly spelled source text.
pub fn bound(text: []const u8, cause: anyerror, inspection: bool, binding: sql.Binding) ?Self {
    var result = query(text, cause, inspection) orelse return null;
    result.binding = binding;
    var out: std.Io.Writer = .fixed(&result.detail);
    if (binding.subject) |subject| {
        out.print("Subject: \"{s}\"", .{subject.slice()}) catch unreachable;
        if (binding.scope_len != 0) out.print("; scope: \"{s}\"", .{binding.scope[0..binding.scope_len]}) catch unreachable;
        out.writeByte('.') catch unreachable;
    }
    if (binding.expected) |expected| out.print(" Expected {s}; supplied {s}.", .{ expected, binding.actual orelse "unknown" }) catch unreachable;
    if (binding.literal_len != 0) out.print(" Value: {s}.", .{binding.literal[0..binding.literal_len]}) catch unreachable;
    if (binding.key) |key| out.print(" Key: {d}.", .{key}) catch unreachable;
    if (binding.input_row) |row| out.print(" Input row: {d}.", .{row}) catch unreachable;
    if (binding.previous_row) |row| out.print(" First occurrence: row {d}.", .{row}) catch unreachable;
    if (binding.parameter) |index| out.print(" Parameter: ${d}.", .{index}) catch unreachable;
    if (binding.missing_parameter) |index| out.print(" Missing parameter: ${d}.", .{index}) catch unreachable;
    if (binding.expected_count) |count| out.print(" Expected bindings: {d}; supplied: {d}.", .{ count, binding.actual_count orelse 0 }) catch unreachable;
    for (binding.parameter_sites) |site| if (site) |offset| {
        var line: usize = 1;
        var begin: usize = 0;
        for (text[0..@min(offset, text.len)], 0..) |byte, i| if (byte == '\n') {
            line += 1;
            begin = i + 1;
        };
        out.print(" Use at line {d}, byte column {d}.", .{ line, offset -| begin + 1 }) catch unreachable;
    };
    if (binding.expected_schema) |fingerprint| out.print(" Expected schema: {x}.", .{&fingerprint}) catch unreachable;
    if (binding.actual_schema) |fingerprint| out.print(" Current schema: {x}.", .{&fingerprint}) catch unreachable;
    result.detail_len = out.end;
    if (binding.location) |location| result.source(text, location);
    return result;
}

/// A write compiler has already selected its owning route. Do not describe a
/// valid declaration or mutation as unavailable on a read-only query interface.
pub fn writeCompiler(text: []const u8, cause: anyerror, route: Route, binding: sql.Binding) ?Self {
    var result = bound(text, cause, false, binding) orelse return null;
    result.route = route;
    if (cause == error.UnsupportedStatement or cause == error.NotTableDeclaration) {
        result.kind = .unsupported;
        result.summary = if (route == .declaration) "This catalog compiler requires a supported CREATE TABLE declaration" else "This writer compiler requires a supported INSERT, UPDATE or DELETE statement";
        result.hint = if (route == .declaration) "Supply CREATE TABLE with an INT64 NOT NULL key and a nullable value column." else mutation_hint;
    }
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
    self.line = 1;
    self.caret = 0;
    self.context_len = 0;
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

/// Authenticated compiler response, never telemetry. Relevant caller-supplied
/// binding detail is escaped and explicitly truncated to the 128-byte budget.
/// Source excerpts and unrelated stored values never cross this boundary.
pub fn renderRemote(self: *const Self, out: *std.Io.Writer) !void {
    if (self.detail_len != 0) {
        var bytes: [1280]u8 = undefined;
        var detail: std.Io.Writer = .fixed(&bytes);
        try detail.print("{s}: {s}", .{ @errorName(self.cause), self.detail[0..self.detail_len] });
        if (self.location != null) try detail.print(" at line {d}, column {d}", .{ self.line, self.column });
        const suffix = " [truncated]";
        if (detail.end > 128) {
            try out.writeAll(detail.buffered()[0 .. 128 - suffix.len]);
            try out.writeAll(suffix);
        } else try out.writeAll(detail.buffered());
        return;
    }
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

test "remote binding context remains printable bounded and explicitly truncated" {
    var binding: sql.Binding = .{};
    sql.Binding.at(&binding, .{ .name = try @import("model.zig").Name.init("long_column_name"), .offset = 7 }, "configured_source");
    binding.expected = "int64";
    binding.actual = "utf8";
    sql.Binding.supplied(&binding, @import("Unified.zig").Scalar{ .utf8 = "%\x1b[31m\n\"\\aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" });
    const diagnostic = Self.bound("SELECT long_column_name FROM configured_source", error.TypeMismatch, false, binding).?;
    var bytes: [128]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try diagnostic.renderRemote(&out);
    try std.testing.expectEqual(@as(usize, 128), out.end);
    try std.testing.expect(std.mem.startsWith(u8, out.buffered(), "TypeMismatch:"));
    try std.testing.expect(std.mem.endsWith(u8, out.buffered(), " [truncated]"));
    for (out.buffered()) |byte| try std.testing.expect(byte >= 32 and byte <= 126);
}

pub fn render(self: *const Self, out: *std.Io.Writer) !void {
    return self.renderStyled(out, Plain{});
}

pub const Part = enum { summary, category, cause, location, expected, source, marker, hint };
const Plain = struct {
    pub fn write(_: Plain, out: *std.Io.Writer, _: Part, text: []const u8) !void {
        try out.writeAll(text);
    }
};

/// The caller decorates semantic parts through style.write(out, part, text).
/// Excerpts remain owned, escaped and redacted; terminal policy stays with the caller.
pub fn renderStyled(self: *const Self, out: *std.Io.Writer, style: anytype) !void {
    try style.write(out, .summary, self.summary);
    try out.writeAll(" [");
    try style.write(out, .category, @tagName(self.kind));
    try out.writeAll("] (");
    try style.write(out, .cause, @errorName(self.cause));
    try out.writeByte(')');
    if (self.detail_len != 0) {
        try out.writeByte('\n');
        try style.write(out, .summary, self.detail[0..self.detail_len]);
    }
    if (self.location) |location| {
        var buffer: [80]u8 = undefined;
        try out.writeAll(" at ");
        try style.write(out, .location, try std.fmt.bufPrint(&buffer, "line {d}, column {d}", .{ self.line, self.column }));
        if (location.expected) |expected| {
            try out.writeAll(": expected ");
            try style.write(out, .expected, expected);
        }
        try out.writeAll("\n  ");
        try style.write(out, .source, self.context[0..self.context_len]);
        try out.writeAll("\n  ");
        try out.splatByteAll(' ', self.caret);
        try style.write(out, .marker, "^--- error here");
    }
    try out.writeAll("\n\n");
    try style.write(out, .hint, self.hint);
    try out.writeByte('\n');
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

test "SQL categories and scalar truncation are machine facts" {
    for ([_]struct { cause: anyerror, category: d.Category }{
        .{ .cause = error.UnsupportedAggregate, .category = .unsupported },
        .{ .cause = error.NullPrimaryKey, .category = .constraint },
        .{ .cause = error.DuplicateMutationKey, .category = .constraint },
        .{ .cause = error.SourceChanged, .category = .conflict },
        .{ .cause = error.CellTooLarge, .category = .limit },
    }) |fixture| {
        const result = try query("SELECT value FROM items", fixture.cause, true).?.structured();
        try std.testing.expectEqual(fixture.category, result.category);
        try std.testing.expectEqual(d.Stage.bind, result.stage);
    }
    var binding: sql.Binding = .{};
    sql.Binding.supplied(&binding, @import("Unified.zig").Scalar{ .binary = &@as([33]u8, @splat(255)) });
    const value = try bound("SELECT value FROM items", error.TypeMismatch, true, binding).?.structured();
    try std.testing.expectEqual(d.Availability.truncated, value.facts[0].?.availability);
    sql.Binding.supplied(&binding, @import("Unified.zig").Scalar{ .int64 = 1 });
    try std.testing.expect(!binding.literal_truncated);
}
