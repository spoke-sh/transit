//! Source syntax only. File and repository I/O stay with the caller.
const std = @import("std");
const f = @import("transit_fuze");
pub const Token = f.SqlInput.CompilerScan.Token;
pub const Span = struct { start: u32, end: u32 };
pub const Name = struct { qualifier: ?[]const u8 = null, member: []const u8 };
pub const Kind = union(enum) { integer, text, boolean, identifier, type, module: Name };
pub const Parameter = struct { name: []const u8, kind: Kind };
pub const ScalarType = enum { bigint, text, boolean };
pub const Binary = enum { add, subtract, multiply, equal, not_equal, less, less_equal, greater, greater_equal, and_, or_ };
pub const Expr = struct {
    span: Span,
    value: union(enum) {
        integer: i64,
        text: []const u8,
        boolean: bool,
        identifier: []const u8,
        type: ScalarType,
        reference: Name,
        binary: struct { op: Binary, left: *Expr, right: *Expr },
        unary: struct { negative: bool, operand: *Expr },
    },
};
pub const Call = struct { name: Name, arguments: []const *Expr };
pub const Case = struct { name: []const u8, setup: []const Call, body: []const Statement };
pub const Assertion = struct {
    sql: []const Token,
    expected: union(enum) {
        rows: []const Token,
        command: struct { matched: u64, changed: u64 },
        refusal: enum { duplicate_key, check_violation },
    },
};
pub const Statement = struct { span: Span, value: union(enum) {
    use: Call,
    conditional: struct { condition: *Expr, yes: []const Statement, no: []const Statement },
    sql: []const Token,
    test_case: Case,
    assertion: Assertion,
} };
pub const Definition = struct { name: []const u8, public: bool, kind: enum { module, interface, target, test_target }, parameters: []const Parameter, body: []const Statement, span: Span };
pub const Import = struct { alias: []const u8, package: ?[]const u8, path: []const u8, span: Span };
pub const Dependency = struct { name: []const u8, repository: []const u8, revision: []const u8, subdirectory: []const u8, span: Span };
pub const File = struct { definitions: []const Definition, imports: []const Import, dependencies: []const Dependency };
const Self = @This();
a: std.mem.Allocator,
text: []const u8,
tokens: []const Token,
index: usize = 0,
location: *usize,
depth: usize = 0,

pub fn parse(a: std.mem.Allocator, text: []const u8, location: *usize) !File {
    // Shared framing is a prerequisite, not semantic acceptance.
    var framed = try f.SqlScript.Compiler.init(text);
    while (framed.next() catch |err| {
        location.* = framed.scan.position;
        return err;
    }) |_| {}
    var scan = try f.SqlInput.CompilerScan.init(text);
    var tokens: std.ArrayList(Token) = .empty;
    while (try scan.next()) |token| {
        if (token.kind == .space or token.kind == .comment) continue;
        try tokens.append(a, token);
    }
    var self: Self = .{ .a = a, .text = text, .tokens = try tokens.toOwnedSlice(a), .location = location };
    var definitions: std.ArrayList(Definition) = .empty;
    var imports: std.ArrayList(Import) = .empty;
    var dependencies: std.ArrayList(Dependency) = .empty;
    while (self.index < self.tokens.len) {
        if (self.take(";")) continue;
        const start = self.at();
        if (self.take("IMPORT")) {
            const alias = try self.identifier();
            try self.require("FROM");
            const package = if (self.take("PACKAGE")) try self.identifier() else null;
            if (package != null) try self.require("FILE");
            const path = try self.string();
            try self.require(";");
            try imports.append(a, .{ .alias = alias, .package = package, .path = path, .span = self.span(start) });
        } else if (self.take("DEPENDENCY")) {
            const name = try self.identifier();
            try self.require("FROM");
            const repository = try self.string();
            try self.require("REVISION");
            const revision = try self.string();
            const subdirectory = if (self.take("SUBDIRECTORY")) try self.string() else "";
            try self.require(";");
            try dependencies.append(a, .{ .name = name, .repository = repository, .revision = revision, .subdirectory = subdirectory, .span = self.span(start) });
        } else {
            try self.require("CREATE");
            const public = self.take("PUBLIC");
            const kind: @FieldType(Definition, "kind") = if (self.take("MODULE")) .module else if (self.take("INTERFACE")) .interface else if (self.take("TARGET")) .target else if (self.take("TEST")) blk: {
                try self.require("TARGET");
                break :blk .test_target;
            } else return error.UnsupportedSourceDeclaration;
            const name = try self.identifier();
            const parameters = if (kind == .module or kind == .interface) try self.parseParameters() else &.{};
            const body: []const Statement = if (kind == .interface) &.{} else blk: {
                try self.require("AS");
                try self.require("BEGIN");
                const result = try self.parseBody(false);
                try self.require("END");
                break :blk result;
            };
            try self.require(";");
            try definitions.append(a, .{ .name = name, .public = public, .kind = kind, .parameters = parameters, .body = body, .span = self.span(start) });
        }
    }
    return .{ .definitions = try definitions.toOwnedSlice(a), .imports = try imports.toOwnedSlice(a), .dependencies = try dependencies.toOwnedSlice(a) };
}
fn at(self: *Self) u32 {
    const offset: u32 = if (self.index < self.tokens.len) self.tokens[self.index].start else @intCast(self.text.len);
    self.location.* = offset;
    return offset;
}
fn span(self: *Self, start: u32) Span {
    return .{ .start = start, .end = if (self.index > 0) self.tokens[self.index - 1].end else start };
}
fn is(self: *Self, value: []const u8) bool {
    _ = self.at();
    if (self.index == self.tokens.len) return false;
    const token = self.tokens[self.index];
    if (token.kind != .word and token.kind != .symbol) return false;
    return std.ascii.eqlIgnoreCase(self.text[token.start..token.end], value);
}
fn take(self: *Self, value: []const u8) bool {
    if (!self.is(value)) return false;
    self.index += 1;
    return true;
}
fn require(self: *Self, value: []const u8) !void {
    if (!self.take(value)) return error.InvalidSourceSyntax;
}
fn identifier(self: *Self) ![]const u8 {
    _ = self.at();
    if (self.index == self.tokens.len or self.tokens[self.index].kind != .word) return error.InvalidSourceName;
    const token = self.tokens[self.index];
    self.index += 1;
    if (token.end - token.start > 63) return error.InvalidSourceName;
    return std.ascii.allocLowerString(self.a, self.text[token.start..token.end]);
}
fn parseName(self: *Self) !Name {
    const first = try self.identifier();
    return if (self.take(".")) .{ .qualifier = first, .member = try self.identifier() } else .{ .member = first };
}
fn string(self: *Self) ![]const u8 {
    _ = self.at();
    if (self.index == self.tokens.len or self.tokens[self.index].kind != .string) return error.InvalidSourceSyntax;
    const token = self.tokens[self.index];
    self.index += 1;
    return decodeString(self.a, self.text[token.start..token.end]);
}
pub fn decodeString(a: std.mem.Allocator, text: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    var i: usize = 1;
    while (i + 1 < text.len) : (i += 1) {
        try result.append(a, text[i]);
        if (text[i] == '\'') i += 1;
    }
    return result.toOwnedSlice(a);
}
fn parseParameters(self: *Self) ![]const Parameter {
    try self.require("(");
    var result: std.ArrayList(Parameter) = .empty;
    if (self.take(")")) return &.{};
    while (true) {
        if (result.items.len == 64) return error.SourceParameterLimit;
        const parameter_name = try self.identifier();
        for (result.items) |prior| if (std.mem.eql(u8, prior.name, parameter_name)) return error.DuplicateSourceName;
        const kind: Kind = if (self.take("BIGINT")) .integer else if (self.take("TEXT")) .text else if (self.take("BOOLEAN")) .boolean else if (self.take("IDENTIFIER")) .identifier else if (self.take("TYPE")) .type else if (self.take("MODULE")) .{ .module = try self.parseName() } else return error.InvalidParameterType;
        try result.append(self.a, .{ .name = parameter_name, .kind = kind });
        if (self.take(")")) break;
        try self.require(",");
    }
    return result.toOwnedSlice(self.a);
}
fn parseBody(self: *Self, conditional: bool) anyerror![]const Statement {
    self.depth += 1;
    defer self.depth -= 1;
    if (self.depth > 64) return error.SourceDepthLimit;
    var result: std.ArrayList(Statement) = .empty;
    while (!self.is("END") and !(conditional and self.is("ELSE"))) {
        if (self.index == self.tokens.len) return error.InvalidSourceSyntax;
        const start = self.at();
        const value: @FieldType(Statement, "value") = if (self.take("USE")) blk: {
            const call = try self.parseCall();
            try self.require(";");
            break :blk .{ .use = call };
        } else if (self.take("TEST")) blk: {
            const name = try self.string();
            if (name.len == 0 or name.len > 128 or !std.unicode.utf8ValidateSlice(name)) return error.InvalidTestName;
            for (name) |byte| if (std.ascii.isControl(byte)) return error.InvalidTestName;
            try self.require("USING");
            try self.require("MODULES");
            try self.require("(");
            var setup: std.ArrayList(Call) = .empty;
            if (!self.take(")")) while (true) {
                if (setup.items.len == 64) return error.SourceParameterLimit;
                try setup.append(self.a, try self.parseCall());
                if (self.take(")")) break;
                try self.require(",");
            };
            try self.require("AS");
            try self.require("BEGIN");
            const body = try self.parseBody(false);
            try self.require("END");
            try self.require(";");
            break :blk .{ .test_case = .{ .name = name, .setup = try setup.toOwnedSlice(self.a), .body = body } };
        } else if (self.take("ASSERT")) blk: {
            const kind: enum { rows, command, refusal } = if (self.take("ROWS")) .rows else if (self.take("COMMAND")) .command else if (self.take("STATEMENT")) .refusal else return error.UnsupportedTestAssertion;
            const sql = try self.parenthesized();
            const expected: @FieldType(Assertion, "expected") = switch (kind) {
                .rows => rows: {
                    try self.require("EQUAL");
                    break :rows .{ .rows = try self.parenthesized() };
                },
                .command => command: {
                    try self.require("MATCHED");
                    const matched = try self.count();
                    try self.require("CHANGED");
                    break :command .{ .command = .{ .matched = matched, .changed = try self.count() } };
                },
                .refusal => refusal: {
                    try self.require("FAILS");
                    try self.require("WITH");
                    break :refusal .{ .refusal = std.meta.stringToEnum(@FieldType(@FieldType(Assertion, "expected"), "refusal"), try self.string()) orelse return error.UnsupportedTestRefusal };
                },
            };
            try self.require(";");
            break :blk .{ .assertion = .{ .sql = sql, .expected = expected } };
        } else if (self.take("IF")) blk: {
            const condition = try self.expression(0);
            try self.require("THEN");
            const yes = try self.parseBody(true);
            const no = if (self.take("ELSE")) try self.parseBody(false) else &.{};
            try self.require("END");
            try self.require("IF");
            try self.require(";");
            break :blk .{ .conditional = .{ .condition = condition, .yes = yes, .no = no } };
        } else blk: {
            const begin = self.index;
            var script: f.SqlScript.Compiler = .{ .scan = .{ .text = self.text, .position = start } };
            const frame = (try script.next()) orelse return error.InvalidSourceSyntax;
            while (self.index < self.tokens.len and self.tokens[self.index].end <= frame.end) self.index += 1;
            const sql = self.tokens[begin..self.index];
            try self.require(";");
            break :blk .{ .sql = sql };
        };
        try result.append(self.a, .{ .span = self.span(start), .value = value });
    }
    return result.toOwnedSlice(self.a);
}
fn parseCall(self: *Self) !Call {
    const name = try self.parseName();
    try self.require("(");
    var arguments: std.ArrayList(*Expr) = .empty;
    if (!self.take(")")) while (true) {
        if (arguments.items.len == 64) return error.SourceParameterLimit;
        try arguments.append(self.a, try self.expression(0));
        if (self.take(")")) break;
        try self.require(",");
    };
    return .{ .name = name, .arguments = try arguments.toOwnedSlice(self.a) };
}
fn parenthesized(self: *Self) ![]const Token {
    try self.require("(");
    const start = self.index;
    var depth: usize = 1;
    while (self.index < self.tokens.len) {
        if (self.take("(")) {
            depth += 1;
            if (depth > 64) return error.SourceDepthLimit;
        } else if (self.take(")")) {
            depth -= 1;
            if (depth == 0) return self.tokens[start .. self.index - 1];
        } else {
            if (self.is(";")) return error.InvalidTestStatement;
            self.index += 1;
        }
    }
    return error.InvalidSourceSyntax;
}
fn count(self: *Self) !u64 {
    _ = self.at();
    if (self.index == self.tokens.len) return error.InvalidTestCount;
    const token = self.tokens[self.index];
    const bytes = self.text[token.start..token.end];
    for (bytes) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidTestCount;
    self.index += 1;
    return std.fmt.parseInt(u64, bytes, 10) catch return error.InvalidTestCount;
}
fn expression(self: *Self, minimum: u8) anyerror!*Expr {
    self.depth += 1;
    defer self.depth -= 1;
    if (self.depth > 64) return error.SourceDepthLimit;
    const start = self.at();
    const value: @FieldType(Expr, "value") = if (self.take("-")) blk: {
        if (self.index < self.tokens.len and self.tokens[self.index].kind == .number) {
            const token = self.tokens[self.index];
            const magnitude = try std.fmt.parseInt(u64, self.text[token.start..token.end], 10);
            if (magnitude > @as(u64, std.math.maxInt(i64)) + 1) return error.Overflow;
            self.index += 1;
            break :blk .{ .integer = if (magnitude == @as(u64, std.math.maxInt(i64)) + 1) std.math.minInt(i64) else -@as(i64, @intCast(magnitude)) };
        }
        break :blk .{ .unary = .{ .negative = true, .operand = try self.expression(6) } };
    } else if (self.take("NOT")) .{ .unary = .{ .negative = false, .operand = try self.expression(6) } } else if (self.take("(")) blk: {
        const inner = try self.expression(0);
        try self.require(")");
        break :blk inner.value;
    } else if ((self.index + 1 < self.tokens.len and self.tokens[self.index + 1].kind == .string and self.take("NAME"))) .{ .identifier = try self.string() } else if (self.take("TYPE")) .{ .type = if (self.take("BIGINT")) .bigint else if (self.take("TEXT")) .text else if (self.take("BOOLEAN")) .boolean else return error.UnsupportedSourceType } else if (self.take("TRUE")) .{ .boolean = true } else if (self.take("FALSE")) .{ .boolean = false } else if (self.index < self.tokens.len and self.tokens[self.index].kind == .string) .{ .text = try self.string() } else if (self.index < self.tokens.len and self.tokens[self.index].kind == .number) blk: {
        const token = self.tokens[self.index];
        self.index += 1;
        break :blk .{ .integer = try std.fmt.parseInt(i64, self.text[token.start..token.end], 10) };
    } else .{ .reference = try self.parseName() };
    var left = try self.a.create(Expr);
    left.* = .{ .span = self.span(start), .value = value };
    while (true) {
        const saved = self.index;
        const op: Binary = if (self.take("OR")) .or_ else if (self.take("AND")) .and_ else if (self.take("=")) .equal else if (self.take("<")) (if (self.take("=")) .less_equal else if (self.take(">")) .not_equal else .less) else if (self.take(">")) (if (self.take("=")) .greater_equal else .greater) else if (self.take("+")) .add else if (self.take("-")) .subtract else if (self.take("*")) .multiply else break;
        const precedence: u8 = switch (op) {
            .or_ => 1,
            .and_ => 2,
            .equal, .not_equal, .less, .less_equal, .greater, .greater_equal => 3,
            .add, .subtract => 4,
            .multiply => 5,
        };
        if (precedence < minimum) {
            self.index = saved;
            break;
        }
        const right = try self.expression(precedence + 1);
        const combined = try self.a.create(Expr);
        combined.* = .{ .span = self.span(start), .value = .{ .binary = .{ .op = op, .left = left, .right = right } } };
        left = combined;
    }
    return left;
}
