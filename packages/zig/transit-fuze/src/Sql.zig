//! Allocation-free SQL syntax and completion. Parsing owns its bounded AST;
//! the current Unified.Sql compiler resolves an explicitly supplied source.
const std = @import("std");
const f = @import("root.zig");
const m = f.model;
pub const max_statement_bytes = 4096;
/// Optional parser evidence. Offsets are UTF-8 byte offsets into this statement;
/// expected text is static grammar vocabulary, never a borrowed SQL value.
pub const Location = struct { offset: usize = 0, expected: ?[]const u8 = null };
pub const max_comment_depth = 16;
pub const max_literal_bytes = 2 + 2 * m.max_cell_bytes;

pub const Column = struct { qualifier: ?m.Name = null, name: m.Name, offset: ?usize = null };
pub const Binding = @import("SqlBinding.zig");
pub const ProjectionItem = struct { column: Column, alias: ?m.Name = null };
/// All null means star. Explicit names form a contiguous bounded prefix.
pub const Projection = [f.Unified.max_columns]?ProjectionItem;
pub const Selection = union(enum) { rows: Projection, count, sum: Column, count_values: Column };
pub const Text = struct {
    bytes: [max_literal_bytes]u8 = @splat(0),
    len: u16 = 0,
    pub fn slice(self: *const Text) []const u8 {
        return self.bytes[0..self.len];
    }
};
pub const Literal = union(enum) { null, int64: i64, uint64: u64, float64: f64, boolean: bool, utf8: Text, binary: Text };
pub const PredicateAtom = union(enum) {
    all,
    state: struct { column: Column, value: f.Unified.State },
    compare: struct { column: Column, op: f.Unified.Plan.Comparison, literal: Literal },
};
pub const PredicateProgram = @import("SqlPredicate.zig");
pub const Predicate = union(enum) {
    all,
    state: @FieldType(PredicateAtom, "state"),
    compare: @FieldType(PredicateAtom, "compare"),
    program: PredicateProgram,
};
pub const Input = struct { projection: Projection, limit: ?u64, alias: m.Name };
pub const Ast = struct {
    source: m.Name,
    source_offset: ?usize = null,
    source_alias: ?m.Name = null,
    selection: Selection,
    output_alias: ?m.Name = null,
    predicate: Predicate = .all,
    limit: ?u64 = null,
    input: ?Input = null,
    /// A template must bind every parameter before ordinary lowering.
    unbound_parameters: bool = false,
};
/// Parameter positions in the finite SELECT grammar, not a prepared-query catalog.
pub const ParameterSites = struct {
    comparison: ?Parameter = null,
    limit: ?Parameter = null,
    input_limit: ?Parameter = null,
    pub fn any(self: ParameterSites) bool {
        return self.comparison != null or self.limit != null or self.input_limit != null;
    }
};
pub const Parameter = struct { index: u32, offset: usize };
pub const TemplateAst = struct { ast: Ast, parameters: ParameterSites };
pub const Catalog = enum { tables, sources, sinks, connections };
pub const Inspection = union(enum) { describe: m.Name, show: Catalog, explain: Ast };
/// Returned AST contains no pointers into text, allocations, effects or authority.
pub fn parse(text: []const u8) !Ast {
    return parseLocated(text, null);
}
pub fn parseLocated(text: []const u8, location: ?*Location) !Ast {
    var result: Ast = undefined;
    try parseInto(text, &result, location);
    return result;
}
/// Fill caller-owned AST storage without intermediate large-value copies.
/// Discard result on failure; successful output owns all parsed bytes.
pub fn parseInto(text: []const u8, result: *Ast, location: ?*Location) !void {
    if (location) |value| value.* = .{};
    try validateText(text);
    var parser: Parser = .{ .lexer = .{ .text = text }, .location = location };
    return statement(&parser, result);
}
/// Separate compiler entry point. Ordinary queries reject unresolved parameters.
/// Placeholder values in the returned AST cannot pass ordinary lowering.
pub fn parseTemplate(text: []const u8, location: ?*Location) !TemplateAst {
    if (location) |value| value.* = .{};
    try validateText(text);
    var parameters: ParameterSites = .{};
    var parser: Parser = .{ .lexer = .{ .text = text, .parameters_enabled = true }, .location = location, .parameters = &parameters };
    var ast: Ast = undefined;
    try statement(&parser, &ast);
    // Template grammar retains its explicit single-atom binding profile.
    if (ast.predicate == .program) return error.UnsupportedConstruct;
    ast.unbound_parameters = parameters.any();
    return .{ .ast = ast, .parameters = parameters };
}
/// Offline state declaration syntax. No catalog lookup, provisioning or grants.
/// Omitted nullability remains unspecified; semantic validation is separate.
pub fn parseDeclaration(text: []const u8) !?f.Declaration.Definition {
    return parseDeclarationLocated(text, null);
}
pub fn parseDeclarationLocated(text: []const u8, location: ?*Location) !?f.Declaration.Definition {
    return parseDeclarationDetailed(text, location, null);
}
pub const DeclarationLocations = struct {
    columns: [f.Declaration.max_columns]?usize = @splat(null),
};
pub fn parseDeclarationDetailed(text: []const u8, location: ?*Location, locations: ?*DeclarationLocations) !?f.Declaration.Definition {
    if (location) |value| value.* = .{};
    if (locations) |value| value.* = .{};
    try validateText(text);
    var parser: Parser = .{ .lexer = .{ .text = text }, .location = location };
    return declaration(&parser, locations);
}
fn declaration(parser: *Parser, locations: ?*DeclarationLocations) !?f.Declaration.Definition {
    try parser.advance();
    if (!parser.word("CREATE")) return null;
    try parser.advance();
    const table = parser.word("TABLE");
    const kv = parser.word("KV");
    if (!table and !kv and !parser.word("DOCUMENT")) return error.UnsupportedDeclaration;
    try parser.advance();
    const name = try parser.name();
    const body: f.Declaration.Body = if (table) blk: {
        var columns: f.Declaration.Columns = @splat(null);
        try parser.require(.left);
        for (&columns, 0..) |*slot, index| {
            if (locations) |value| value.columns[index] = parser.lexer.start;
            const column_name = try parser.name();
            const data_type = try parser.declarationType();
            const nullability: f.Declaration.Nullability = if (parser.word("NOT")) nullable: {
                try parser.advance();
                try parser.requireWord("NULL");
                break :nullable .not_null;
            } else if (parser.word("NULL")) nullable: {
                try parser.advance();
                break :nullable .null;
            } else .unspecified;
            slot.* = .{ .name = column_name, .type = data_type, .nullability = nullability };
            if (!try parser.take(.comma)) break;
            if (index + 1 == columns.len) return error.DeclarationTooManyColumns;
        }
        try parser.require(.right);
        break :blk .{ .table = columns };
    } else if (kv) blk: {
        try parser.require(.left);
        const data_type = try parser.declarationType();
        try parser.require(.right);
        break :blk .{ .kv = data_type };
    } else .document;
    try parser.end();
    return .{ .name = name, .body = body };
}
pub fn validateText(text: []const u8) !void {
    if (text.len > max_statement_bytes) return error.StatementTooLarge;
    if (!std.unicode.utf8ValidateSlice(text) or std.mem.indexOfScalar(u8, text, 0) != null) return error.InvalidSqlEncoding;
}
/// Recognize inspection without making it an executable SELECT. A null result
/// leaves other statements to their owner; recognized forms consume all input.
/// Catalog resolution and current read authority belong to the query client.
pub fn parseInspection(text: []const u8) !?Inspection {
    return parseInspectionLocated(text, null);
}
pub fn parseInspectionLocated(text: []const u8, location: ?*Location) !?Inspection {
    if (location) |value| value.* = .{};
    try validateText(text);
    var parser: Parser = .{ .lexer = .{ .text = text }, .location = location };
    return inspection(&parser);
}
fn inspection(parser: *Parser) !?Inspection {
    try parser.advance();
    if (parser.word("EXPLAIN")) {
        var ast: Ast = undefined;
        try statement(parser, &ast);
        return .{ .explain = ast };
    }
    if (parser.word("DESCRIBE")) {
        try parser.advance();
        const name = try parser.name();
        try parser.end();
        return .{ .describe = name };
    }
    if (parser.word("SHOW")) {
        try parser.advance();
        inline for (comptime std.meta.fieldNames(Catalog)) |name| {
            if (parser.word(name)) {
                try parser.advance();
                try parser.end();
                return .{ .show = @field(Catalog, name) };
            }
        }
        if (parser.token.tag == .eof or parser.token.tag == .semi) {
            if (parser.location) |value| value.expected = "TABLES, SOURCES, SINKS or CONNECTIONS";
            return error.InvalidSqlSyntax;
        }
        return error.UnsupportedCatalog;
    }
    return null;
}
fn statement(parser: *Parser, ast: *Ast) !void {
    try parser.advance();
    if (!parser.word("SELECT")) return error.UnsupportedStatement;
    try parser.advance();
    ast.* = .{ .source = undefined, .selection = .count };
    try parser.selection(&ast.selection);
    ast.output_alias = if (ast.selection == .rows) null else try parser.outputAlias();
    if (parser.assistance) |h| h.aggregate = ast.selection != .rows;
    try parser.requireWord("FROM");
    const derived = if (ast.selection == .rows and parser.token.tag == .cursor) false else try parser.take(.left);
    if (derived) {
        if (ast.selection == .rows) return error.UnsupportedConstruct;
        if (parser.assistance) |h| h.aggregate = false;
        try parser.requireWord("SELECT");
        var projected: Projection = undefined;
        try parser.projection(&projected);
        try parser.requireWord("FROM");
        ast.source_offset = if (parser.location != null) parser.lexer.start else null;
        ast.source = try parser.name();
        if (parser.assistance) |h| h.source = ast.source;
        ast.source_alias = try parser.sourceAlias();
        try parser.predicate(&ast.predicate);
        const limit = try parser.limit(true);
        try parser.require(.right);
        try parser.requireWord("AS");
        parser.name_role = .alias;
        ast.input = .{ .projection = projected, .limit = limit, .alias = try parser.name() };
        if (parser.assistance) |h| h.aggregate = true;
        ast.limit = try parser.limit(false);
        try parser.end();
        return;
    }
    ast.source_offset = if (parser.location != null) parser.lexer.start else null;
    ast.source = try parser.name();
    if (parser.assistance) |h| h.source = ast.source;
    ast.source_alias = try parser.sourceAlias();
    try parser.predicate(&ast.predicate);
    ast.limit = try parser.limit(false);
    try parser.end();
    return;
}

/// Local presentation roles. These are neither wire fields nor proof of validity.
pub const TokenRole = enum(u8) { unknown, keyword, identifier, function, type_name, literal, number, parameter, comment };

/// Annotate the prefix consumed by the owning parser, including incomplete input.
/// No catalog, allocation or dispatch. Unclassified suffixes remain unknown.
/// Caller storage has one role per input byte and must not exceed the SQL bound.
pub fn classifyTokens(text: []const u8, roles: []TokenRole) void {
    @memset(roles, .unknown);
    if (roles.len != text.len) return;
    validateText(text) catch return;
    var probe: Lexer = .{ .text = text };
    const first = (probe.next() catch return);
    if (first.tag != .word) return;
    var parameters: ParameterSites = .{};
    var parser: Parser = .{ .lexer = .{ .text = text, .parameters_enabled = true }, .roles = roles, .parameters = &parameters };
    if (std.ascii.eqlIgnoreCase(first.text, "SELECT")) {
        var ast: Ast = undefined;
        statement(&parser, &ast) catch {};
    } else if (std.ascii.eqlIgnoreCase(first.text, "CREATE")) {
        _ = declaration(&parser, null) catch null;
    } else if (std.ascii.eqlIgnoreCase(first.text, "EXPLAIN") or std.ascii.eqlIgnoreCase(first.text, "DESCRIBE") or std.ascii.eqlIgnoreCase(first.text, "SHOW")) {
        _ = inspection(&parser) catch null;
    }
}

/// Shared checked SQL literal decoding; the returned value owns its bytes.
pub fn literalCell(literal: Literal) !m.Cell {
    switch (literal) {
        .utf8, .binary => |value| if (value.len > value.bytes.len) return error.LiteralTooLarge,
        else => {},
    }
    return switch (literal) {
        .null => .null,
        .int64 => |value| .{ .int64 = value },
        .uint64, .float64 => error.UnsupportedLiteral,
        .boolean => |value| .{ .boolean = value },
        .utf8 => |value| .{ .utf8 = try m.Bytes.init(value.slice()) },
        .binary => |value| blk: {
            const text = value.slice();
            if (!std.mem.startsWith(u8, text, "\\x") or (text.len - 2) % 2 != 0) return error.InvalidBinaryLiteral;
            var bytes: [m.max_cell_bytes]u8 = undefined;
            const decoded = std.fmt.hexToBytes(&bytes, text[2..]) catch return error.InvalidBinaryLiteral;
            break :blk .{ .binary = try m.Bytes.init(decoded) };
        },
    };
}

/// Case-insensitive reserved words shared by parsing and local presentation.
/// Contextual words such as VALUE and UPDATE remain valid identifiers.
pub fn isReserved(word: []const u8) bool {
    inline for (.{ "SELECT", "WHERE", "LIMIT", "COUNT", "SUM", "IS", "AND", "OR", "TRUE", "FALSE", "BYTEA", "CREATE", "CONNECTION", "CONNECTIONS", "SOURCE", "SOURCES", "SINK", "SINKS", "TABLE", "TABLES", "DOCUMENT", "KV", "TO", "FROM", "INTO", "WITH", "GRANT", "REVOKE", "ON", "SHOW", "DESCRIBE", "NOT", "NULL", "SECRET", "AS", "OF", "FOR", "SYSTEM_TIME", "INT64", "BOOL", "UTF8", "BINARY" }) |keyword| {
        if (std.ascii.eqlIgnoreCase(word, keyword)) return true;
    }
    return false;
}

pub const Tag = enum { cursor, eof, word, quoted, string, integer, left, right, comma, dot, star, cast, plus, minus, eq, ne, lt, le, gt, ge, semi };
pub const Token = struct { tag: Tag, text: []const u8 };
pub const Lexer = struct {
    text: []const u8,
    position: usize = 0,
    cursor_enabled: bool = false,
    parameters_enabled: bool = false,
    start: usize = 0,
    pub fn next(self: *Lexer) !Token {
        while (self.position < self.text.len) {
            self.start = self.position;
            const rest = self.text[self.position..];
            if (std.mem.indexOfScalar(u8, " \t\r\n", rest[0]) != null) {
                self.position += 1;
            } else if (std.mem.startsWith(u8, rest, "--")) {
                self.position += std.mem.indexOfAny(u8, rest, "\r\n") orelse rest.len;
            } else if (std.mem.startsWith(u8, rest, "/*")) {
                self.position += 2;
                var depth: usize = 1;
                while (depth > 0) {
                    if (self.position == self.text.len) return error.InvalidSqlSyntax;
                    const remaining = self.text[self.position..];
                    if (std.mem.startsWith(u8, remaining, "/*")) {
                        depth += 1;
                        if (depth > max_comment_depth) return error.CommentTooDeep;
                        self.position += 2;
                    } else if (std.mem.startsWith(u8, remaining, "*/")) {
                        depth -= 1;
                        self.position += 2;
                    } else self.position += 1;
                }
            } else break;
        }
        const start = self.position;
        self.start = start;
        if (start == self.text.len) return .{ .tag = .eof, .text = "" };
        const byte = self.text[start];
        self.position += 1;
        const tag: Tag = if (std.ascii.isAlphabetic(byte) or byte == '_') blk: {
            while (self.position < self.text.len and (std.ascii.isAlphanumeric(self.text[self.position]) or self.text[self.position] == '_')) self.position += 1;
            break :blk .word;
        } else if (std.ascii.isDigit(byte)) blk: {
            while (self.position < self.text.len and std.ascii.isDigit(self.text[self.position])) self.position += 1;
            break :blk .integer;
        } else switch (byte) {
            '\'', '"' => blk: {
                while (true) {
                    if (self.position == self.text.len) return error.InvalidSqlSyntax;
                    const current = self.text[self.position];
                    self.position += 1;
                    if (current == byte) {
                        if (self.position < self.text.len and self.text[self.position] == byte) {
                            self.position += 1;
                        } else break;
                    }
                }
                break :blk if (byte == '\'') .string else .quoted;
            },
            1 => if (self.cursor_enabled) .cursor else return error.UnsupportedConstruct,
            '$' => blk: {
                if (!self.parameters_enabled) return error.UnboundParameters;
                const first = self.position;
                while (self.position < self.text.len and std.ascii.isDigit(self.text[self.position])) self.position += 1;
                if (self.position == first) return error.InvalidParameterIndex;
                // Keep template-only syntax out of the ordinary assistance vocabulary.
                break :blk .integer;
            },
            '(' => .left,
            ')' => .right,
            ',' => .comma,
            '.' => .dot,
            '*' => .star,
            '+' => .plus,
            '-' => .minus,
            ';' => .semi,
            '=' => .eq,
            ':' => if (self.consume(':')) .cast else return error.UnsupportedConstruct,
            '!' => if (self.consume('=')) .ne else return error.UnsupportedConstruct,
            '<' => if (self.consume('=')) .le else if (self.consume('>')) .ne else .lt,
            '>' => if (self.consume('=')) .ge else .gt,
            else => return error.UnsupportedConstruct,
        };
        return .{ .tag = tag, .text = self.text[start..self.position] };
    }
    fn consume(self: *Lexer, byte: u8) bool {
        if (self.position == self.text.len or self.text[self.position] != byte) return false;
        self.position += 1;
        return true;
    }
};
const Parser = struct {
    lexer: Lexer,
    token: Token = .{ .tag = .eof, .text = "" },
    roles: ?[]TokenRole = null,
    assistance: ?*Hints = null,
    location: ?*Location = null,
    parameters: ?*ParameterSites = null,
    name_role: NameRole = .source,
    fn annotate(self: *Parser, role: TokenRole) void {
        if (self.roles) |roles| @memset(roles[self.lexer.start..][0..self.token.text.len], role);
    }
    fn advance(self: *Parser) !void {
        if (self.roles) |roles| if (self.token.text.len != 0 and roles[self.lexer.start] == .unknown) {
            self.annotate(switch (self.token.tag) {
                .word => .keyword,
                .quoted => .identifier,
                .string => .literal,
                .integer => if (self.token.text[0] == '$') .parameter else .number,
                else => .unknown,
            });
        };

        defer {
            if (self.location) |location| location.* = .{ .offset = self.lexer.start };
        }
        self.token = try self.lexer.next();
    }
    fn word(self: *const Parser, expected: []const u8) bool {
        if (self.token.tag == .cursor) if (self.assistance) |h| h.word(expected);
        return self.token.tag == .word and std.ascii.eqlIgnoreCase(self.token.text, expected);
    }
    fn requireWord(self: *Parser, expected: []const u8) !void {
        if (!self.word(expected)) {
            if (self.location) |location| location.expected = expected;
            return error.UnsupportedConstruct;
        }
        try self.advance();
    }
    fn take(self: *Parser, tag: Tag) !bool {
        if (self.token.tag == .cursor) if (self.assistance) |h| h.symbol(tag);
        if (self.token.tag != tag) return false;
        try self.advance();
        return true;
    }
    fn require(self: *Parser, tag: Tag) !void {
        if (!try self.take(tag)) {
            if (self.location) |location| location.expected = switch (tag) {
                .left => "(",
                .right => ")",
                .comma => ",",
                .eq => "=",
                .star => "*",
                else => @tagName(tag),
            };
            return error.InvalidSqlSyntax;
        }
    }
    fn end(self: *Parser) !void {
        _ = try self.take(.semi);
        if (self.token.tag != .eof) return error.UnsupportedConstruct;
    }
    fn declarationType(self: *Parser) !m.Type {
        if (self.location) |location| location.expected = "INT64, BOOL, UTF8 or BINARY";
        const result: m.Type = if (self.word("INT64")) .int64 else if (self.word("BOOL")) .boolean else if (self.word("UTF8")) .utf8 else if (self.word("BINARY")) .binary else return error.UnsupportedDeclarationType;
        self.annotate(.type_name);
        try self.advance();
        return result;
    }
    fn name(self: *Parser) !m.Name {
        var bytes: [16]u8 = undefined;
        const token = self.token;
        if (self.location) |location| location.expected = "an identifier";
        if (token.tag == .cursor) if (self.assistance) |h| {
            h.name_role = self.name_role;
            return error.IncompleteSql;
        };
        if (token.tag != .word and token.tag != .quoted) return error.InvalidSqlSyntax;
        if (token.tag == .word and isReserved(token.text)) return error.InvalidSqlSyntax;
        self.annotate(.identifier);
        const raw = if (token.tag == .quoted) token.text[1 .. token.text.len - 1] else token.text;
        if (raw.len > bytes.len) return error.InvalidColumnName;
        for (raw, 0..) |byte, i| bytes[i] = if (token.tag == .word) std.ascii.toLower(byte) else byte;
        const result = try m.Name.init(bytes[0..raw.len]);
        try self.advance();
        return result;
    }
    fn sourceAlias(self: *Parser) !?m.Name {
        const alias = try self.outputAlias();
        if (self.assistance) |h| h.source_alias = alias;
        return alias;
    }
    fn outputAlias(self: *Parser) !?m.Name {
        if (!self.word("AS")) return null;
        try self.advance();
        const previous = self.name_role;
        self.name_role = .alias;
        defer self.name_role = previous;
        return try self.name();
    }
    fn column(self: *Parser) !Column {
        const previous = self.name_role;
        self.name_role = .column;
        defer self.name_role = previous;
        const offset: ?usize = if (self.location != null) self.lexer.start else null;
        const first = try self.name();
        if (try self.take(.dot)) {
            if (self.assistance) |h| h.qualifier = first;
            const column_name = try self.name();
            if (self.assistance) |h| h.qualifier = null;
            return .{ .qualifier = first, .name = column_name, .offset = offset };
        }
        return .{ .name = first, .offset = offset };
    }
    fn projection(self: *Parser, result: *Projection) !void {
        result.* = @splat(null);
        if (try self.take(.star)) return;
        for (result, 0..) |*column_value, index| {
            const column_ref = try self.column();
            if (self.token.tag == .left) return error.UnsupportedAggregate;
            column_value.* = .{ .column = column_ref, .alias = try self.outputAlias() };
            if (index + 1 == result.len) {
                if (self.token.tag == .comma) return error.InvalidProjection;
                return;
            }
            if (!try self.take(.comma)) return;
        }
        unreachable;
    }
    fn selection(self: *Parser, result: *Selection) !void {
        const count = self.word("COUNT");
        if (count or self.word("SUM")) {
            self.annotate(.function);
            try self.advance();
            try self.require(.left);
            if (count) {
                result.* = if (try self.take(.star)) .count else .{ .count_values = try self.column() };
            } else {
                if (self.assistance) |h| h.sum_only = true;
                const column_value = try self.column();
                if (self.assistance) |h| h.sum_only = false;
                result.* = .{ .sum = column_value };
            }
            try self.require(.right);
            return;
        }
        result.* = .{ .rows = undefined };
        try self.projection(&result.rows);
    }
    fn predicate(self: *Parser, result: *Predicate) !void {
        // statement initializes the absent predicate; do not clear the entire
        // inline program again when this statement has no WHERE clause.
        if (!self.word("WHERE")) {
            std.debug.assert(result.* == .all);
            return;
        }
        try self.advance();
        // Keep a lone atom in its existing representation. Only initialize the
        // bounded instruction/literal pool when Boolean operators require it.
        const first: ?PredicateAtom = if (!self.word("NOT") and self.token.tag != .left and self.token.tag != .cursor) try self.predicateAtom() else null;
        if (first) |atom| if (!self.word("AND") and !self.word("OR")) {
            switch (atom) {
                inline else => |value, tag| result.* = @unionInit(Predicate, @tagName(tag), value),
            }
            return;
        };
        // Keep compound-only storage and stack probes out of the atom path.
        return @call(.never_inline, compoundPredicate, .{ self, result, if (first) |*atom| atom else null });
    }
    fn compoundPredicate(self: *Parser, result: *Predicate, first: ?*const PredicateAtom) !void {
        result.* = .{ .program = .{} };
        const program = &result.program;
        if (first) |atom| try program.appendAtom(atom.*);
        const Operator = enum { left, disjunction, conjunction, negate };
        var operators: [PredicateProgram.max_instructions]Operator = undefined;
        var count: usize = 0;
        var groups: usize = 0;
        var operand = first == null;
        while (true) {
            if (operand) {
                const op: ?Operator = if (self.word("NOT")) .negate else if (self.token.tag == .left) .left else null;
                if (self.token.tag == .cursor) if (self.assistance) |h| h.symbol(.left);
                if (op) |value| {
                    if (count == operators.len) return error.PredicateTooComplex;
                    operators[count] = value;
                    count += 1;
                    if (value == .left) groups += 1;
                    try self.advance();
                    continue;
                }
                try program.appendAtom(try self.predicateAtom());
                operand = false;
                continue;
            }
            const next: ?Operator = if (self.word("AND")) .conjunction else if (self.word("OR")) .disjunction else null;
            if (next) |op| {
                while (count > 0 and @backingInt(operators[count - 1]) >= @backingInt(op)) {
                    count -= 1;
                    try program.append(switch (operators[count]) {
                        .negate => .negate,
                        .conjunction => .conjunction,
                        .disjunction => .disjunction,
                        .left => unreachable,
                    });
                }
                if (count == operators.len) return error.PredicateTooComplex;
                operators[count] = op;
                count += 1;
                try self.advance();
                operand = true;
                continue;
            }
            if (groups > 0) {
                if (self.token.tag == .cursor) if (self.assistance) |h| h.symbol(.right);
                if (self.token.tag == .right) {
                    while (operators[count - 1] != .left) {
                        count -= 1;
                        try program.append(switch (operators[count]) {
                            .negate => .negate,
                            .conjunction => .conjunction,
                            .disjunction => .disjunction,
                            .left => unreachable,
                        });
                    }
                    count -= 1;
                    groups -= 1;
                    try self.advance();
                    continue;
                }
                if (self.location) |location| location.expected = ")";
                return error.InvalidSqlSyntax;
            }
            break;
        }
        while (count > 0) {
            count -= 1;
            try program.append(switch (operators[count]) {
                .negate => .negate,
                .conjunction => .conjunction,
                .disjunction => .disjunction,
                .left => unreachable,
            });
        }
        if (program.count == 1) switch (try program.expand(program.instructions[0].atom)) {
            inline else => |value, tag| result.* = @unionInit(Predicate, @tagName(tag), value),
        };
    }
    fn predicateAtom(self: *Parser) !PredicateAtom {
        const col = try self.column();
        if (self.assistance) |h| h.predicate_column = col;
        if (self.word("IS")) {
            try self.advance();
            const value: f.Unified.State = if (self.word("NULL")) .null else if (self.word("MISSING")) .missing else if (self.word("TYPE_ERROR")) .type_error else if (self.word("VALUE")) .value else if (self.word("CONFLICT")) .conflict else return error.UnsupportedConstruct;
            try self.advance();
            if (self.assistance) |h| h.predicate_column = null;
            return .{ .state = .{ .column = col, .value = value } };
        }
        if (self.token.tag == .cursor) if (self.assistance) |h| {
            for ([_]Tag{ .eq, .ne, .lt, .le, .gt, .ge }) |tag| h.symbol(tag);
        };
        const op: f.Unified.Plan.Comparison = switch (self.token.tag) {
            .eq => .eq,
            .ne => .ne,
            .lt => .lt,
            .le => .le,
            .gt => .gt,
            .ge => .ge,
            else => return error.UnsupportedConstruct,
        };
        try self.advance();
        if (self.assistance) |h| h.literal_column = col;
        const value = try self.literal();
        if (self.assistance) |h| {
            h.literal_column = null;
            h.predicate_column = null;
        }
        return .{ .compare = .{ .column = col, .op = op, .literal = value } };
    }
    fn literal(self: *Parser) !Literal {
        if (try self.parameter()) |index| {
            self.parameters.?.comparison = index;
            return .null;
        }
        if (self.word("NULL")) {
            self.annotate(.literal);
            try self.advance();
            return .null;
        }
        if (self.word("TRUE") or self.word("FALSE")) {
            const value = self.word("TRUE");
            self.annotate(.literal);
            try self.advance();
            return .{ .boolean = value };
        }
        if (self.token.tag == .string) {
            var value: Text = .{};
            const raw = self.token.text[1 .. self.token.text.len - 1];
            var pos: usize = 0;
            while (pos < raw.len) : (pos += 1) {
                if (value.len == max_literal_bytes) return error.LiteralTooLarge;
                value.bytes[value.len] = raw[pos];
                value.len += 1;
                if (raw[pos] == '\'') pos += 1;
            }
            try self.advance();
            if (try self.take(.cast)) {
                if (self.word("BYTEA") or self.word("UINT64") or self.word("FLOAT64")) self.annotate(.type_name);
                const result: Literal = if (self.word("BYTEA")) .{ .binary = value } else if (self.word("UINT64")) blk: {
                    const bytes = value.slice();
                    if (bytes.len == 0) return error.InvalidNumericLiteral;
                    for (bytes) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidNumericLiteral;
                    break :blk .{ .uint64 = std.fmt.parseInt(u64, bytes, 10) catch return error.LiteralOutOfRange };
                } else if (self.word("FLOAT64")) blk: {
                    const bytes = value.slice();
                    for (bytes) |byte| if (std.mem.indexOfScalar(u8, "0123456789+-.eE", byte) == null) return error.InvalidNumericLiteral;
                    const number = std.fmt.parseFloat(f64, bytes) catch return error.InvalidNumericLiteral;
                    if (!std.math.isFinite(number)) return error.LiteralOutOfRange;
                    break :blk .{ .float64 = number };
                } else return error.UnsupportedConstruct;
                try self.advance();
                return result;
            }
            return .{ .utf8 = value };
        }
        if (self.token.tag == .minus or self.token.tag == .plus) self.annotate(.number);
        const negative = try self.take(.minus);
        if (!negative) _ = try self.take(.plus);
        if (self.token.tag == .cursor) if (self.assistance) |h| h.symbol(.integer);
        if (self.token.tag != .integer) return error.InvalidSqlSyntax;
        const unsigned = std.fmt.parseInt(u64, self.token.text, 10) catch return error.LiteralOutOfRange;
        const value: i128 = if (negative) -@as(i128, unsigned) else unsigned;
        const result = std.math.cast(i64, value) orelse return error.LiteralOutOfRange;
        try self.advance();
        return .{ .int64 = result };
    }
    fn parameter(self: *Parser) !?Parameter {
        if (self.token.tag != .integer or self.token.text.len == 0 or self.token.text[0] != '$') return null;
        self.annotate(.parameter);
        if (self.parameters == null) return error.UnboundParameters;
        const index = std.fmt.parseInt(u32, self.token.text[1..], 10) catch return error.InvalidParameterIndex;
        if (index == 0) return error.InvalidParameterIndex;
        const offset = self.lexer.start;
        try self.advance();
        return .{ .index = index, .offset = offset };
    }
    fn limit(self: *Parser, comptime inner: bool) !?u64 {
        if (!self.word("LIMIT")) return null;
        try self.advance();
        if (try self.parameter()) |index| {
            if (inner) self.parameters.?.input_limit = index else self.parameters.?.limit = index;
            return 0;
        }
        if (self.token.tag == .cursor) if (self.assistance) |h| h.symbol(.integer);
        if (self.token.tag != .integer) return error.InvalidSqlSyntax;
        const result = std.fmt.parseInt(u64, self.token.text, 10) catch return error.LiteralOutOfRange;
        try self.advance();
        return result;
    }
};

pub const NameRole = enum { source, column, alias };
/// Expectations from the production parser at a token boundary. Static keyword
/// slices and owned names only; no catalog, I/O, authority or source-text borrow.
/// Consumers must apply their executable capability and authorized type profile.
pub const Hints = struct {
    words: [16]?[]const u8 = @splat(null),
    symbols: [16]?Tag = @splat(null),
    name_role: ?NameRole = null,
    source: ?m.Name = null,
    source_alias: ?m.Name = null,
    qualifier: ?m.Name = null,
    literal_column: ?Column = null,
    predicate_column: ?Column = null,
    sum_only: bool = false,
    aggregate: bool = false,
    fn word(self: *Hints, value: []const u8) void {
        for (&self.words) |*slot| {
            if (slot.*) |existing| {
                if (std.mem.eql(u8, existing, value)) return;
            } else {
                slot.* = value;
                return;
            }
        }
        unreachable; // finite alternatives in the parser, not catalog cardinality
    }
    fn symbol(self: *Hints, value: Tag) void {
        for (&self.symbols) |*slot| {
            if (slot.*) |existing| {
                if (existing == value) return;
            } else {
                slot.* = value;
                return;
            }
        }
        unreachable;
    }
};
/// `prefix` ends before the token being replaced. Incomplete quotes/comments
/// naturally suppress expectations because the parser cannot reach the cursor.
/// A malformed prefix produces no candidates; complete compilation is separate.
pub fn hints(prefix: []const u8) !Hints {
    if (prefix.len > max_statement_bytes) return error.StatementTooLarge;
    if (!std.unicode.utf8ValidateSlice(prefix) or std.mem.indexOfAny(u8, prefix, &.{ 0, 1 }) != null) return error.InvalidSqlEncoding;
    var bytes: [max_statement_bytes + 1]u8 = undefined;
    @memcpy(bytes[0..prefix.len], prefix);
    bytes[prefix.len] = 1;
    var result: Hints = .{};
    var parser: Parser = .{ .lexer = .{ .text = bytes[0 .. prefix.len + 1], .cursor_enabled = true }, .assistance = &result };
    var ast: Ast = undefined;
    statement(&parser, &ast) catch {};
    return result;
}
