//! Bounded structural Table templates. No catalog, dummy bindings or evaluation.
//! Fuze owns scanning, reserved SQL names and later type/statement preparation.
const std = @import("std");
const f = @import("transit_fuze");
const Token = f.SqlInput.CompilerScan.Token;
pub const Role = enum { identifier, type, value, operand };
pub const Hole = struct { name: []const u8, role: Role, start: u32, end: u32 };
pub const Kind = enum { create, insert, update, delete, select, rows };
pub const Syntax = struct { kind: Kind, tokens: []const Token, holes: []const Hole };
const Self = @This();
a: std.mem.Allocator,
text: []const u8,
tokens: []const Token,
location: *usize,
end: u32,
i: usize = 0,
depth: usize = 0,
holes: std.ArrayList(Hole) = .empty,

pub fn parse(a: std.mem.Allocator, text: []const u8, tokens: []const Token, end: u32, expected_rows: bool, location: *usize) !Syntax {
    var self: Self = .{ .a = a, .text = text, .tokens = tokens, .end = end, .location = location };
    const kind = if (expected_rows) blk: {
        if (tokens.len != 0) try self.rows(false);
        break :blk Kind.rows;
    } else try self.statement();
    if (self.i != tokens.len) return self.invalid();
    return .{ .kind = kind, .tokens = tokens, .holes = try self.holes.toOwnedSlice(a) };
}
fn at(self: *Self) u32 {
    const offset = if (self.i < self.tokens.len) self.tokens[self.i].start else self.end;
    self.location.* = offset;
    return offset;
}
fn raw(self: *Self) []const u8 {
    _ = self.at();
    return if (self.i < self.tokens.len) self.text[self.tokens[self.i].start..self.tokens[self.i].end] else "";
}
fn is(self: *Self, word: []const u8) bool {
    return std.ascii.eqlIgnoreCase(self.raw(), word);
}
fn take(self: *Self, word: []const u8) bool {
    if (!self.is(word)) return false;
    self.i += 1;
    return true;
}
fn invalid(self: *Self) error{InvalidSourceTemplate} {
    _ = self.at();
    return error.InvalidSourceTemplate;
}
fn require(self: *Self, word: []const u8) !void {
    if (!self.take(word)) return self.invalid();
}
fn tag(self: *Self, kind: f.SqlInput.Kind) bool {
    _ = self.at();
    return self.i < self.tokens.len and self.tokens[self.i].kind == kind;
}
fn enter(self: *Self) !void {
    if (self.depth == 64) return error.SourceDepthLimit;
    self.depth += 1;
}
fn hole(self: *Self, role: Role) !bool {
    const start = self.at();
    if (!self.take("$")) return false;
    if (!self.tag(.word)) {
        self.location.* = start;
        return error.InvalidSourceOperand;
    }
    const operand_name = self.raw();
    if (operand_name.len > 63) return error.InvalidSourceName;
    const end = self.tokens[self.i].end;
    self.i += 1;
    try self.holes.append(self.a, .{ .name = try std.ascii.allocLowerString(self.a, operand_name), .role = role, .start = start, .end = end });
    return true;
}
fn name(self: *Self) !void {
    if (try self.hole(.identifier)) return;
    if (!self.tag(.quoted) and (!self.tag(.word) or f.Sql.isReserved(self.raw()))) return self.invalid();
    self.i += 1;
}
fn reference(self: *Self) !void {
    try self.name();
    if (self.take(".")) try self.name();
}
fn unsigned(self: *Self) !void {
    if (try self.hole(.value)) return;
    if (!self.tag(.number)) return self.invalid();
    self.i += 1;
}
fn string(self: *Self) !void {
    if (try self.hole(.value)) return;
    if (!self.tag(.string)) return self.invalid();
    self.i += 1;
}
fn nullable(self: *Self) !void {
    if (self.take("NOT")) try self.require("NULL") else _ = self.take("NULL");
}
fn dataType(self: *Self) anyerror!void {
    try self.enter();
    defer self.depth -= 1;
    if (try self.hole(.type)) return;
    if (!self.tag(.word)) return self.invalid();
    const word = self.raw();
    self.i += 1;
    const types = std.StaticStringMap(enum { fields, list, array, map, range, vector, double, character }).initComptime(.{
        .{ "STRUCT", .fields }, .{ "ROW", .fields }, .{ "UNION", .fields }, .{ "LIST", .list }, .{ "ARRAY", .array }, .{ "MAP", .map }, .{ "RANGE", .range }, .{ "MULTIRANGE", .range }, .{ "VECTOR", .vector }, .{ "DOUBLE", .double }, .{ "CHARACTER", .character },
    });
    var upper: [64]u8 = undefined;
    const special = if (word.len <= upper.len) types.get(std.ascii.upperString(upper[0..word.len], word)) else null;
    if (special) |kind| switch (kind) {
        .fields => {
            try self.require("(");
            while (true) {
                try self.name();
                try self.dataType();
                try self.nullable();
                _ = self.take("OPTIONAL");
                if (!self.take(",")) break;
            }
            return self.require(")");
        },
        .list, .array, .map => {
            try self.require("(");
            try self.dataType();
            try self.nullable();
            if (kind != .list) {
                try self.require(",");
                if (kind == .map) {
                    try self.dataType();
                    try self.nullable();
                } else try self.unsigned();
            }
            return self.require(")");
        },
        .range => {
            try self.require("<");
            try self.dataType();
            return self.require(">");
        },
        .vector => {
            try self.require("(");
            try self.unsigned();
            try self.require(",");
            if (!try self.hole(.type)) {
                if (!self.tag(.word)) return self.invalid();
                self.i += 1;
            }
            return self.require(")");
        },
        .double => {
            _ = self.take("PRECISION");
        },
        .character => {
            _ = self.take("VARYING");
        },
    };
    if (self.take("(")) {
        try self.unsigned();
        if (self.take(",")) try self.unsigned();
        try self.require(")");
    }
    if (self.take("WITH") or self.take("WITHOUT")) {
        try self.require("TIME");
        try self.require("ZONE");
    }
}
fn literal(self: *Self) anyerror!void {
    try self.enter();
    defer self.depth -= 1;
    if (try self.hole(.value)) return self.cast();
    if (self.take("TRUE") or self.take("FALSE") or self.take("NULL") or self.take("MISSING")) return;
    if (self.tag(.string)) {
        self.i += 1;
        try self.cast();
        return;
    }
    if (self.take("X") or self.take("DATE") or self.take("TIME") or self.take("TIMESTAMP") or self.take("UUID") or self.take("JSON")) return self.string();
    if (self.take("STRUCT") or self.take("ROW") or self.take("LIST") or self.take("ARRAY") or self.take("MAP") or self.take("INTERVAL")) {
        try self.require("(");
        if (!self.take(")")) {
            while (true) {
                try self.literal();
                if (!self.take(",")) break;
            }
            try self.require(")");
        }
        return;
    }
    if (self.take("UNION")) {
        try self.require("(");
        try self.name();
        try self.require(",");
        try self.literal();
        return self.require(")");
    }
    if (self.take("+") or self.take("-")) if (try self.hole(.value)) return self.cast();
    if (!self.tag(.number)) return self.invalid();
    self.i += 1;
    // SqlInput retains punctuation separately. A numeric literal must stay contiguous.
    if (self.i < self.tokens.len and self.tokens[self.i - 1].end == self.tokens[self.i].start and self.take(".")) {
        if (!self.tag(.number) or self.tokens[self.i - 1].end != self.tokens[self.i].start) return self.invalid();
        self.i += 1;
    }
    if (self.i < self.tokens.len and self.tokens[self.i - 1].end == self.tokens[self.i].start and self.tag(.word)) {
        const exponent = self.raw();
        if (exponent.len > 0 and (exponent[0] == 'e' or exponent[0] == 'E')) {
            self.i += 1;
            if (exponent.len == 1) {
                if (self.i == self.tokens.len or self.tokens[self.i - 1].end != self.tokens[self.i].start) return self.invalid();
                _ = self.take("+") or self.take("-");
                if (!self.tag(.number) or self.tokens[self.i - 1].end != self.tokens[self.i].start) return self.invalid();
                self.i += 1;
            } else for (exponent[1..]) |byte| if (!std.ascii.isDigit(byte)) return self.invalid();
        }
    }
}
fn cast(self: *Self) !void {
    if (!self.take(":")) return;
    if (self.i == self.tokens.len or self.tokens[self.i - 1].end != self.tokens[self.i].start) return self.invalid();
    try self.require(":");
    if (!self.take("BYTEA") and !self.take("UINT64") and !self.take("FLOAT64")) return self.invalid();
}
fn comparison(self: *Self) !void {
    if (self.take("=")) return;
    if (self.is("<") or self.is(">") or self.is("!")) {
        const required = self.is("!");
        const less = self.is("<");
        self.i += 1;
        if (self.i < self.tokens.len and self.tokens[self.i - 1].end == self.tokens[self.i].start) {
            if (self.take("=") or (less and self.take(">"))) return;
        }
        if (!required) return;
    }
    return self.invalid();
}
fn predicate(self: *Self) anyerror!void {
    try self.conjunction();
    while (self.take("OR")) try self.conjunction();
}
fn conjunction(self: *Self) !void {
    try self.negation();
    while (self.take("AND")) try self.negation();
}
fn negation(self: *Self) anyerror!void {
    try self.enter();
    defer self.depth -= 1;
    if (self.take("NOT")) return self.negation();
    if (self.take("(")) {
        try self.predicate();
        return self.require(")");
    }
    try self.reference();
    if (self.take("IS")) {
        _ = self.take("NOT");
        if (!self.take("NULL") and !self.take("MISSING") and !self.take("TYPE_ERROR") and !self.take("VALUE") and !self.take("CONFLICT")) return self.invalid();
    } else {
        try self.comparison();
        try self.literal();
    }
}
fn rows(self: *Self, defaults: bool) !void {
    while (true) {
        try self.require("(");
        while (true) {
            if (!defaults or !self.take("DEFAULT")) try self.literal();
            if (!self.take(",")) break;
        }
        try self.require(")");
        if (!self.take(",")) break;
    }
}
fn check(self: *Self) !void {
    try self.require("CHECK");
    try self.require("(");
    while (true) {
        try self.reference();
        if (self.take("IS")) {
            _ = self.take("NOT");
            try self.require("NULL");
        } else {
            try self.comparison();
            if (self.qualifiedHole()) {
                try self.reference();
            } else if (!try self.hole(.operand)) {
                const literal_tail = self.i + 1 < self.tokens.len and (self.tokens[self.i + 1].kind == .string or self.nextIs("$") or self.nextIs("("));
                if (self.tag(.quoted) or (self.tag(.word) and !f.Sql.isReserved(self.raw()) and !literal_tail)) try self.reference() else try self.literal();
            }
        }
        if (!self.take("AND")) break;
    }
    try self.require(")");
    if (self.take("NOT")) try self.require("VALID");
}
fn tableElement(self: *Self) !void {
    if (self.take("PRIMARY")) {
        try self.require("KEY");
        try self.require("(");
        try self.name();
        while (self.take(",")) try self.name();
        return self.require(")");
    }
    if (self.take("CONSTRAINT")) {
        try self.name();
        return self.check();
    }
    if (self.is("CHECK")) return self.check();
    try self.name();
    try self.dataType();
    while (true) {
        if (self.is("NOT") or self.is("NULL")) try self.nullable() else if (self.take("DEFAULT")) try self.literal() else if (self.take("PRIMARY")) try self.require("KEY") else if (self.take("COLLATE")) {
            if (!self.take("UTF8_BINARY") and !self.take("ASCII_CI") and !self.take("EBCDIC_CP037") and !self.take("EBCDIC_037_PAD") and !self.take("EBCDIC_1047_NOPAD")) return self.invalid();
        } else if (self.take("ROUNDING") or self.take("METRIC")) try self.name() else if (self.take("TIMEZONE")) {
            try self.string();
            try self.require("TZDB");
            try self.string();
            try self.require("TZIF");
            try self.require("X");
            try self.string();
        } else break;
    }
}
fn scalar(self: *Self) anyerror!void {
    try self.enter();
    defer self.depth -= 1;
    const functions = std.StaticStringMap(void).initComptime(.{
        .{ "DECIMAL_ADD", {} }, .{ "DECIMAL_SUBTRACT", {} }, .{ "DECIMAL_MULTIPLY", {} }, .{ "DECIMAL_DIVIDE", {} }, .{ "DECIMAL_RESCALE", {} }, .{ "RANGE_OVERLAPS", {} }, .{ "RANGE_CONTAINS", {} }, .{ "RANGE_ADJACENT", {} }, .{ "RANGE_COMPARE", {} }, .{ "VECTOR_DISTANCE", {} }, .{ "TIME_BUCKET", {} }, .{ "LOCAL_TO_UTC", {} },
    });
    var upper: [32]u8 = undefined;
    const word = self.raw();
    const function = word.len <= upper.len and functions.has(std.ascii.upperString(upper[0..word.len], word)) and self.i + 1 < self.tokens.len and std.mem.eql(u8, self.text[self.tokens[self.i + 1].start..self.tokens[self.i + 1].end], "(");
    if (function) {
        self.i += 2;
        while (true) {
            if (self.qualifiedHole()) {
                try self.scalar();
            } else if (try self.hole(.operand)) {
                try self.timeZone();
            } else if (self.tag(.string)) {
                self.i += 1;
            } else if (self.tag(.number) or self.is("+") or self.is("-")) {
                _ = self.take("+") or self.take("-");
                if (!self.tag(.number)) return self.invalid();
                self.i += 1;
            } else try self.scalar();
            if (!self.take(",")) break;
        }
        try self.require(")");
    } else try self.reference();
    try self.timeZone();
}
fn nextIs(self: *Self, value: []const u8) bool {
    return self.i + 1 < self.tokens.len and std.ascii.eqlIgnoreCase(self.text[self.tokens[self.i + 1].start..self.tokens[self.i + 1].end], value);
}
fn qualifiedHole(self: *Self) bool {
    return self.is("$") and self.i + 2 < self.tokens.len and std.mem.eql(u8, self.text[self.tokens[self.i + 2].start..self.tokens[self.i + 2].end], ".");
}
fn timeZone(self: *Self) !void {
    if (self.take("AT")) {
        try self.require("TIME");
        try self.require("ZONE");
        try self.string();
    }
}
fn selection(self: *Self) !bool {
    const aggregate = (self.is("COUNT") or self.is("SUM")) and self.i + 1 < self.tokens.len and std.mem.eql(u8, self.text[self.tokens[self.i + 1].start..self.tokens[self.i + 1].end], "(");
    if (aggregate) {
        const count = self.is("COUNT");
        self.i += 2;
        if (!count or !self.take("*")) try self.scalar();
        try self.require(")");
        if (self.take("AS")) try self.name();
    } else if (!self.take("*")) {
        // Qualified wildcard is only allowed as the complete projection.
        const name_end = self.i + @as(usize, if (self.is("$")) 2 else 1);
        if (name_end + 1 < self.tokens.len and std.mem.eql(u8, self.text[self.tokens[name_end].start..self.tokens[name_end].end], ".") and std.mem.eql(u8, self.text[self.tokens[name_end + 1].start..self.tokens[name_end + 1].end], "*")) {
            try self.name();
            self.i += 2;
        } else while (true) {
            try self.scalar();
            if (self.take("AS")) try self.name();
            if (!self.take(",")) break;
        }
    }
    try self.require("FROM");
    return aggregate;
}
fn select(self: *Self) !void {
    const aggregate = try self.selection();
    const derived = aggregate and self.take("(");
    if (derived) {
        try self.require("SELECT");
        if (try self.selection()) return self.invalid();
    }
    try self.name();
    if (self.take("AS")) try self.name() else if (self.is("$") or self.tag(.quoted) or (self.tag(.word) and !f.Sql.isReserved(self.raw()) and !self.clauseWord())) try self.name();
    if (self.take("WHERE")) try self.predicate();
    if (self.take("LIMIT")) try self.unsigned();
    if (derived) {
        try self.require(")");
        try self.require("AS");
        try self.name();
    }
}
fn clauseWord(self: *Self) bool {
    inline for (.{ "JOIN", "INNER", "LEFT", "OUTER", "RIGHT", "FULL", "CROSS", "NATURAL", "GROUP", "HAVING", "ORDER" }) |word| if (self.is(word)) return true;
    return false;
}
fn statement(self: *Self) !Kind {
    if (self.take("CREATE")) {
        if (!self.take("PUBLIC") or !self.take("TABLE")) return error.RuntimePrivateOrUnsupportedDeclaration;
        try self.name();
        try self.require("(");
        try self.tableElement();
        while (self.take(",")) try self.tableElement();
        try self.require(")");
        return .create;
    }
    if (self.take("INSERT")) {
        try self.require("INTO");
        try self.name();
        if (self.take("(")) {
            try self.name();
            while (self.take(",")) try self.name();
            try self.require(")");
        }
        try self.require("VALUES");
        try self.rows(true);
        return .insert;
    }
    if (self.take("UPDATE")) {
        try self.name();
        try self.require("SET");
        while (true) {
            try self.reference();
            try self.require("=");
            if (!self.take("DEFAULT")) try self.literal();
            if (!self.take(",")) break;
        }
        if (self.take("WHERE")) try self.predicate();
        return .update;
    }
    if (self.take("DELETE")) {
        try self.require("FROM");
        try self.name();
        if (self.take("WHERE")) try self.predicate();
        return .delete;
    }
    if (self.take("SELECT")) {
        try self.select();
        return .select;
    }
    return error.UnsupportedBuildStatement;
}

/// SqlInput splits punctuation/exponents for source expressions. SQL emission
/// must retain lexical units; whitespace cannot be inserted inside a cast,
/// decimal, exponent or two-byte comparison. No source operand is expanded here.
pub fn joinsLexeme(text: []const u8, tokens: []const Token, index: usize) bool {
    if (index == 0 or tokens[index - 1].end != tokens[index].start) return false;
    const previous = tokens[index - 1];
    const current = tokens[index];
    const left = text[previous.start..previous.end];
    const right = text[current.start..current.end];
    if (previous.kind == .symbol and current.kind == .symbol) {
        return (std.mem.indexOfAny(u8, left, "<>!") != null and std.mem.indexOfAny(u8, right, "=>") != null) or
            (std.mem.eql(u8, left, ":") and std.mem.eql(u8, right, ":"));
    }
    if (previous.kind == .number and (std.mem.eql(u8, right, ".") or (current.kind == .word and (right[0] == 'e' or right[0] == 'E')))) return true;
    if (current.kind == .number and std.mem.eql(u8, left, ".") and index >= 2 and tokens[index - 2].kind == .number and tokens[index - 2].end == previous.start) return true;
    if ((std.mem.eql(u8, right, "+") or std.mem.eql(u8, right, "-")) and std.ascii.eqlIgnoreCase(left, "e") and index >= 2 and tokens[index - 2].kind == .number and tokens[index - 2].end == previous.start) return true;
    return current.kind == .number and index >= 3 and (std.mem.eql(u8, left, "+") or std.mem.eql(u8, left, "-")) and tokens[index - 2].end == previous.start and std.ascii.eqlIgnoreCase(text[tokens[index - 2].start..tokens[index - 2].end], "e");
}

/// The exponent's spelling belongs to its numeric literal, not a SQL keyword.
/// This is called only on structurally validated template tokens.
pub fn numericWord(text: []const u8, token: Token) bool {
    return token.kind == .word and token.start > 0 and std.ascii.isDigit(text[token.start - 1]) and (text[token.start] == 'e' or text[token.start] == 'E');
}
