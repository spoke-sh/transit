//! Closed, effect-free PostgreSQL 18 psql catalog-query adapter. Match complete
//! token streams, including predicates and ordering; never recognize a query by
//! a substring or silently discard caller SQL. Templates are upstream SQL, not
//! a second catalog or a general PostgreSQL query evaluator.
const std = @import("std");
const Self = @This();
pub const Kind = enum { relations, schemas, databases, schema_publications, resolve, relation, columns, indexes, foreign_keys, references, policies, statistics, publications, parents, children };
kind: Kind,
pattern: ?[]const u8 = null,
schema: ?[]const u8 = null,
object: ?u64 = null,
pattern_escaped: bool = false,
schema_escaped: bool = false,
hide_system: bool = false,

pub fn parse(sql: []const u8) !?Self {
    var scan: Lexer = .{ .sql = sql };
    var catalog = false;
    var qualifier = false;
    while (try scan.next()) |token| {
        if (qualifier and std.mem.eql(u8, token.text, ".")) catalog = true;
        qualifier = (token.kind == .word and std.ascii.eqlIgnoreCase(token.text, "pg_catalog")) or
            (token.kind == .quoted and std.mem.eql(u8, token.text, "\"pg_catalog\""));
    }
    if (!catalog) return null;
    var parser: Parser = .{ .lexer = .{ .sql = sql } };
    if (try parser.take(prefix(@embedFile("psql/relations.sql"), "WHERE"))) {
        try parser.need("WHERE c.relkind IN (");
        // The table-bearing \d and \dt shapes. Other relation families need
        // their own semantics; an empty fabricated catalog would be misleading.
        if (!try parser.take("'r','p','v','m','S','f','')") and
            !try parser.take("'r','p','')") and
            !try parser.take("'r','p','t','s','')")) return error.UnsupportedPostgresCatalogQuery;
        var result: Self = .{ .kind = .relations };
        result.hide_system = try parser.take("AND n.nspname <> 'pg_catalog' AND n.nspname !~ '^pg_toast' AND n.nspname <> 'information_schema'");
        if (!result.hide_system) {
            if (try parser.take("AND c.relname OPERATOR(pg_catalog.~)")) result.pattern = try parser.pattern(&result.pattern_escaped);
        }
        if (try parser.take("AND n.nspname OPERATOR(pg_catalog.~)")) {
            result.schema = try parser.pattern(&result.schema_escaped);
        } else try parser.need("AND pg_catalog.pg_table_is_visible(c.oid)");
        try parser.need("ORDER BY 1,2");
        try parser.finish();
        return result;
    }
    if (try parser.take("SELECT c.oid, n.nspname, c.relname FROM pg_catalog.pg_class c LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace WHERE")) {
        var result: Self = .{ .kind = .resolve };
        if (try parser.take("c.relname OPERATOR(pg_catalog.~)")) result.pattern = try parser.pattern(&result.pattern_escaped);
        if (try parser.take(if (result.pattern != null) "AND n.nspname OPERATOR(pg_catalog.~)" else "n.nspname OPERATOR(pg_catalog.~)")) {
            result.schema = try parser.pattern(&result.schema_escaped);
        } else try parser.need(if (result.pattern != null) "AND pg_catalog.pg_table_is_visible(c.oid)" else "pg_catalog.pg_table_is_visible(c.oid)");
        try parser.need("ORDER BY 2,3");
        try parser.finish();
        return result;
    }
    if (try parser.take(prefix(@embedFile("psql/schemas.sql"), "WHERE"))) {
        var result: Self = .{ .kind = .schemas };
        result.hide_system = try parser.take("WHERE n.nspname !~ '^pg_' AND n.nspname <> 'information_schema'");
        if (!result.hide_system) {
            try parser.need("WHERE n.nspname OPERATOR(pg_catalog.~)");
            result.pattern = try parser.pattern(&result.pattern_escaped);
        }
        try parser.need("ORDER BY 1");
        try parser.finish();
        return result;
    }
    if (try parser.take(prefix(@embedFile("psql/databases.sql"), "ORDER BY"))) {
        var result: Self = .{ .kind = .databases };
        if (try parser.take("WHERE d.datname OPERATOR(pg_catalog.~)")) result.pattern = try parser.pattern(&result.pattern_escaped);
        try parser.need("ORDER BY 1");
        try parser.finish();
        return result;
    }
    if (try parser.take("SELECT pubname FROM pg_catalog.pg_publication p JOIN pg_catalog.pg_publication_namespace pn ON p.oid = pn.pnpubid JOIN pg_catalog.pg_namespace n ON n.oid = pn.pnnspid WHERE n.nspname =")) {
        const escaped = try parser.take("E");
        const name = try parser.lexer.next() orelse return error.UnsupportedPostgresCatalogQuery;
        if (name.kind != .string) return error.UnsupportedPostgresCatalogQuery;
        var buffer: [4096]u8 = undefined;
        _ = try Pattern.decode(name.text[1 .. name.text.len - 1], escaped, &buffer);
        try parser.need("ORDER BY 1");
        try parser.finish();
        return .{ .kind = .schema_publications };
    }
    const templates = .{
        .{ Kind.relation, @embedFile("psql/relation.sql") },
        .{ Kind.columns, @embedFile("psql/columns.sql") },
        .{ Kind.indexes, @embedFile("psql/indexes.sql") },
        .{ Kind.foreign_keys, @embedFile("psql/foreign_keys.sql") },
        .{ Kind.references, @embedFile("psql/references.sql") },
        .{ Kind.policies, @embedFile("psql/policies.sql") },
        .{ Kind.statistics, @embedFile("psql/statistics.sql") },
        .{ Kind.publications, @embedFile("psql/publications.sql") },
        .{ Kind.parents, @embedFile("psql/parents.sql") },
        .{ Kind.children, @embedFile("psql/children.sql") },
    };
    inline for (templates) |entry| {
        var candidate: Parser = .{ .lexer = .{ .sql = sql } };
        var model: Lexer = .{ .sql = entry[1] };
        var object: ?u64 = null;
        const matched = while (try model.next()) |expected| {
            if (std.mem.eql(u8, expected.text, ";")) continue;
            const actual = try candidate.lexer.next() orelse break false;
            if (expected.kind == .word and std.mem.eql(u8, expected.text, "TRANSIT_OBJECT")) {
                if (actual.kind != .string) break false;
                const value = std.fmt.parseInt(u64, actual.text[1 .. actual.text.len - 1], 10) catch break false;
                if (value == 0 or (object != null and object.? != value)) break false;
                object = value;
            } else if (!equal(expected, actual)) break false;
        } else true;
        if (matched) {
            try candidate.finish();
            return .{ .kind = entry[0], .object = object orelse return error.UnsupportedPostgresCatalogQuery };
        }
    }
    return error.UnsupportedPostgresCatalogQuery;
}
fn prefix(comptime sql: []const u8, comptime end: []const u8) []const u8 {
    return sql[0..std.mem.indexOf(u8, sql, end).?];
}
const Token = struct { kind: enum { word, string, quoted, symbol }, text: []const u8 };
fn equal(a: Token, b: Token) bool {
    return a.kind == b.kind and (if (a.kind == .word) std.ascii.eqlIgnoreCase(a.text, b.text) else std.mem.eql(u8, a.text, b.text));
}
const Lexer = struct {
    sql: []const u8,
    offset: usize = 0,
    fn next(self: *Lexer) !?Token {
        while (self.offset < self.sql.len) {
            const rest = self.sql[self.offset..];
            if (std.ascii.isWhitespace(rest[0])) {
                self.offset += 1;
                continue;
            }
            if (std.mem.startsWith(u8, rest, "--")) {
                self.offset += std.mem.indexOfAny(u8, rest, "\r\n") orelse rest.len;
                continue;
            }
            if (std.mem.startsWith(u8, rest, "/*")) {
                self.offset += 2;
                var depth: usize = 1;
                while (depth != 0) {
                    if (self.offset == self.sql.len) return error.InvalidSqlSyntax;
                    const tail = self.sql[self.offset..];
                    if (std.mem.startsWith(u8, tail, "/*")) {
                        depth += 1;
                        if (depth > 16) return error.InvalidSqlSyntax;
                        self.offset += 2;
                    } else if (std.mem.startsWith(u8, tail, "*/")) {
                        depth -= 1;
                        self.offset += 2;
                    } else self.offset += 1;
                }
                continue;
            }
            break;
        }
        if (self.offset == self.sql.len) return null;
        const start = self.offset;
        const byte = self.sql[start];
        self.offset += 1;
        if (byte == '\'' or byte == '"') {
            while (self.offset < self.sql.len) {
                const current = self.sql[self.offset];
                self.offset += 1;
                if (current != byte) continue;
                if (self.offset < self.sql.len and self.sql[self.offset] == byte) {
                    self.offset += 1;
                    continue;
                }
                return .{ .kind = if (byte == '\'') .string else .quoted, .text = self.sql[start..self.offset] };
            }
            return error.InvalidSqlSyntax;
        }
        const word = std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$';
        if (!word) {
            // SQL multi-byte operators are single tokens. Whitespace or a
            // comment inside one must not become an accepted template match.
            for ([_][]const u8{ "!~*", "::", "<>", "!=", "<=", ">=", "||", "!~", "~*" }) |operator| {
                if (std.mem.startsWith(u8, self.sql[start..], operator)) {
                    self.offset = start + operator.len;
                    return .{ .kind = .symbol, .text = self.sql[start..self.offset] };
                }
            }
        }
        if (word) while (self.offset < self.sql.len) {
            const byte_after = self.sql[self.offset];
            if (!std.ascii.isAlphanumeric(byte_after) and byte_after != '_' and byte_after != '$') break;
            self.offset += 1;
        };
        return .{ .kind = if (word) .word else .symbol, .text = self.sql[start..self.offset] };
    }
};
const Parser = struct {
    lexer: Lexer,
    fn take(self: *Parser, sql: []const u8) !bool {
        var model: Lexer = .{ .sql = sql };
        var candidate = self.lexer;
        while (try model.next()) |expected| {
            const actual = try candidate.next() orelse return false;
            if (!equal(expected, actual)) return false;
        }
        self.lexer = candidate;
        return true;
    }
    fn need(self: *Parser, sql: []const u8) !void {
        if (!try self.take(sql)) return error.UnsupportedPostgresCatalogQuery;
    }
    fn finish(self: *Parser) !void {
        _ = try self.take(";");
        if (try self.lexer.next() != null) return error.UnsupportedPostgresCatalogQuery;
    }
    fn pattern(self: *Parser, escaped: *bool) ![]const u8 {
        escaped.* = try self.take("E");
        const token = try self.lexer.next() orelse return error.UnsupportedPostgresCatalogQuery;
        if (token.kind != .string) return error.UnsupportedPostgresCatalogQuery;
        try self.need("COLLATE pg_catalog.default");
        const value = token.text[1 .. token.text.len - 1];
        var buffer: [4096]u8 = undefined;
        try Pattern.validate(try Pattern.decode(value, escaped.*, &buffer));
        return value;
    }
};

/// psql's anchored literal / * / ? name patterns. Arbitrary regex syntax fails
/// explicitly. SQL doubled quotes are decoded without allocating. Matching is
/// polynomial and bounded by the SQL and identifier byte limits, not recursive.
pub const Pattern = struct {
    fn decode(value: []const u8, escaped: bool, buffer: []u8) ![]const u8 {
        if (!escaped) return value;
        var index: usize = 0;
        var length: usize = 0;
        while (index < value.len) : (index += 1) {
            if (length == buffer.len) return error.UnsupportedPostgresCatalogPattern;
            const byte = value[index];
            if (byte == '\\') {
                index += 1;
                // psql doubles backslashes in E literals. Other escape forms
                // are outside this closed producer profile.
                if (index == value.len or value[index] != '\\') return error.UnsupportedPostgresCatalogPattern;
            }
            buffer[length] = byte;
            length += 1;
        }
        return buffer[0..length];
    }
    pub fn matchesEscaped(pattern: ?[]const u8, escaped: bool, name: []const u8) !bool {
        const value = pattern orelse return true;
        var buffer: [4096]u8 = undefined;
        return matches(try decode(value, escaped, &buffer), name);
    }

    fn validate(value: []const u8) !void {
        if (!std.mem.startsWith(u8, value, "^(") or !std.mem.endsWith(u8, value, ")$")) return error.UnsupportedPostgresCatalogPattern;
        var index: usize = 2;
        while (index < value.len - 2) {
            const byte = value[index];
            index += 1;
            if (byte == '\\') {
                if (index == value.len - 2 or std.ascii.isAlphanumeric(value[index])) return error.UnsupportedPostgresCatalogPattern;
                index += 1;
            } else if (byte == '.') {
                if (index < value.len - 2 and value[index] == '*') index += 1;
            } else if (std.mem.indexOfScalar(u8, "*+?[](){}|^$", byte) != null) return error.UnsupportedPostgresCatalogPattern;
        }
    }
    pub fn matches(pattern: ?[]const u8, name: []const u8) !bool {
        const value = pattern orelse return true;
        try validate(value);
        // Native names fit 63 bytes; keep Unicode wildcard boundaries intact.
        if (name.len > 255) return error.UnsupportedPostgresCatalogPattern;
        var before: [256]bool = @splat(false);
        before[0] = true;
        var index: usize = 2;
        while (index < value.len - 2) {
            var after: [256]bool = @splat(false);
            const byte = value[index];
            index += 1;
            if (byte == '.') {
                const star = index < value.len - 2 and value[index] == '*';
                if (star) index += 1;
                var pos: usize = 0;
                if (star) after[0] = before[0];
                while (pos < name.len) {
                    const width = std.unicode.utf8ByteSequenceLength(name[pos]) catch return error.InvalidCatalogName;
                    if (pos + width > name.len) return error.InvalidCatalogName;
                    after[pos + width] = before[pos] or (star and after[pos]) or (star and before[pos + width]);
                    pos += width;
                }
            } else {
                const literal = if (byte == '\\') blk: {
                    const b = value[index];
                    index += 1;
                    break :blk b;
                } else byte;
                if (literal == '\'' and index < value.len - 2 and value[index] == '\'') index += 1;
                for (name, 0..) |actual, pos| after[pos + 1] = before[pos] and actual == literal;
            }
            before = after;
        }
        return before[name.len];
    }
};

test "psql catalog templates reject changed semantics and extra statements" {
    const t = std.testing;
    const sql = @embedFile("psql/relations.sql");
    try t.expectEqual(Kind.relations, (try parse(sql)).?.kind);
    try t.expectEqual(Kind.schemas, (try parse(@embedFile("psql/schemas.sql"))).?.kind);
    try t.expectEqual(Kind.databases, (try parse(@embedFile("psql/databases.sql"))).?.kind);
    try t.expect(try parse("SELECT 'pg_catalog.pg_class' FROM items") == null);
    try t.expect(try parse("SELECT pg_catalog FROM items") == null);
    try t.expect(try parse("SELECT * FROM items /* pg_catalog */") == null);
    try t.expectError(error.UnsupportedPostgresCatalogQuery, parse(sql ++ " SELECT 1"));
    try t.expectError(error.UnsupportedPostgresCatalogQuery, parse("SELECT * FROM pg_catalog.pg_class"));
    const changed = try std.mem.replaceOwned(u8, t.allocator, sql, "ORDER BY 1,2", "ORDER BY 2,1");
    defer t.allocator.free(changed);
    try t.expectError(error.UnsupportedPostgresCatalogQuery, parse(changed));
    const broken_operator = try std.mem.replaceOwned(u8, t.allocator, sql, "<>", "< >");
    defer t.allocator.free(broken_operator);
    try t.expectError(error.UnsupportedPostgresCatalogQuery, parse(broken_operator));
}
test "psql name patterns preserve quoted names Unicode and bounded glob semantics" {
    const t = std.testing;
    try t.expect(try Pattern.matches("^(it.*)$", "items"));
    try t.expect(!try Pattern.matches("^(it.*)$", "other"));
    try t.expect(try Pattern.matches("^(.*)$", ""));
    try t.expect(try Pattern.matches("^(a.b)$", "a雪b"));
    try t.expect(try Pattern.matches("^(a''b)$", "a'b"));
    try t.expect(try Pattern.matches("^(a\\.b)$", "a.b"));
    try t.expectError(error.UnsupportedPostgresCatalogPattern, Pattern.matches("^(a|b)$", "a"));
}

test "psql descriptions preserve full object identity and require repeated references to agree" {
    const t = std.testing;
    const object = "'18446744073709551614'";
    const sql = try std.mem.replaceOwned(u8, t.allocator, @embedFile("psql/publications.sql"), "TRANSIT_OBJECT", object);
    defer t.allocator.free(sql);
    try t.expectEqual(@as(u64, 18446744073709551614), (try parse(sql)).?.object.?);
    const altered = try t.allocator.dupe(u8, sql);
    defer t.allocator.free(altered);
    const index = std.mem.indexOf(u8, altered, object).?;
    altered[index + object.len - 2] = '3';
    try t.expectError(error.UnsupportedPostgresCatalogQuery, parse(altered));
}

test "psql escape string patterns decode the SQL and regex layers separately" {
    const t = std.testing;
    const plan = (try parse(
        \\SELECT c.oid, n.nspname, c.relname FROM pg_catalog.pg_class c
        \\LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        \\WHERE c.relname OPERATOR(pg_catalog.~) E'^(psql_雪\\.O''Brien)$' COLLATE pg_catalog.default
        \\AND pg_catalog.pg_table_is_visible(c.oid) ORDER BY 2,3;
    )).?;
    try t.expect(plan.pattern_escaped);
    try t.expect(try Pattern.matchesEscaped(plan.pattern, plan.pattern_escaped, "psql_雪.O'Brien"));
    try t.expect(!try Pattern.matchesEscaped(plan.pattern, plan.pattern_escaped, "psql_雪XO'Brien"));
}
