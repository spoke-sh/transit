//! Source syntax only. File and repository I/O stay with the caller.
const std = @import("std");
const f = @import("transit_fuze");
pub const Template = @import("Template.zig");
pub const Token = f.SqlInput.CompilerScan.Token;
pub const Span = struct { start: u32, end: u32 };
pub const Name = struct { qualifier: ?[]const u8 = null, member: []const u8, constructor: ?[]const u8 = null };
pub const Kind = union(enum) { integer, text, boolean, identifier, type, module: Name, named: Name, table: []const Column, stream: []const Column, queue: []const Column };
pub const Parameter = struct { name: []const u8, kind: Kind };
pub const ScalarType = enum { bigint, text, boolean };
pub const TypeRef = union(enum) { scalar: ScalarType, named: Name };
pub const Column = struct { name: []const u8, type: TypeRef, nullable: bool = true, primary: bool = false, collation: []const u8 = "none" };
pub const Constructor = struct { name: []const u8, fields: []const Parameter };
pub const Domain = struct { base: ScalarType, identity: []const u8 };
pub const Binary = enum { add, subtract, multiply, equal, not_equal, less, less_equal, greater, greater_equal, and_, or_ };
pub const Expr = struct {
    span: Span,
    value: union(enum) {
        integer: i64,
        text: []const u8,
        boolean: bool,
        identifier: []const u8,
        type: ScalarType,
        named_type: Name,
        reference: Name,
        construct: Call,
        binary: struct { op: Binary, left: *Expr, right: *Expr },
        unary: struct { negative: bool, operand: *Expr },
    },
};
pub const Call = struct { name: Name, arguments: []const *Expr, result: ?[]const u8 = null };
pub const Arm = struct { constructor: Name, names: []const []const u8, body: []const Statement, span: Span };
pub const Case = struct { name: []const u8, setup: []const Call, body: []const Statement };
pub const Assertion = struct {
    sql: Template.Syntax,
    expected: union(enum) {
        rows: Template.Syntax,
        command: struct { matched: u64, changed: u64 },
        refusal: enum { duplicate_key, check_violation },
    },
};
pub const Workflow = struct { name: *Expr, completed: u64, refused: u64, observations: u64 };
pub const Statement = struct { span: Span, value: union(enum) {
    use: Call,
    table_export: struct { source: Name, operand: bool, alias: []const u8 },
    log_export: struct { kind: enum { stream, queue }, source: Name, operand: bool, alias: []const u8 },
    match: struct { value: *Expr, arms: []const Arm },
    conditional: struct { condition: *Expr, yes: []const Statement, no: []const Statement },
    sql: Template.Syntax,
    test_case: Case,
    assertion: Assertion,
    workflow: Workflow,
} };
pub const Definition = struct { name: []const u8, public: bool, kind: enum { module, interface, target, test_target, domain, variant }, parameters: []const Parameter, body: []const Statement, span: Span, domain: ?Domain = null, constructors: []const Constructor = &.{} };
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
            const kind: @FieldType(Definition, "kind") = if (self.take("DOMAIN")) .domain else if (self.take("VARIANT")) .variant else if (self.take("MODULE")) .module else if (self.take("INTERFACE")) .interface else if (self.take("TARGET")) .target else if (self.take("TEST")) blk: {
                try self.require("TARGET");
                break :blk .test_target;
            } else return error.UnsupportedSourceDeclaration;
            const name = try self.identifier();
            const parameters = if (kind == .module or kind == .interface) try self.parseParameters() else &.{};
            var domain: ?Domain = null;
            var constructors: std.ArrayList(Constructor) = .empty;
            if (kind == .domain) {
                try self.require("AS");
                const base = try self.scalarType();
                try self.require("IDENTITY");
                domain = .{ .base = base, .identity = try self.string() };
                if (domain.?.identity.len == 0 or domain.?.identity.len > 128) return error.InvalidDomainIdentity;
            } else if (kind == .variant) {
                try self.require("AS");
                try self.require("(");
                while (true) {
                    if (constructors.items.len == 64) return error.SourceConstructorLimit;
                    const constructor = try self.identifier();
                    for (constructors.items) |prior| if (std.mem.eql(u8, prior.name, constructor)) return error.DuplicateSourceName;
                    try constructors.append(a, .{ .name = constructor, .fields = try self.parseParameters() });
                    if (!self.take(",")) break;
                }
                try self.require(")");
            }
            const body: []const Statement = if (kind == .interface or kind == .domain or kind == .variant) &.{} else blk: {
                try self.require("AS");
                try self.require("BEGIN");
                const result = try self.parseBody(.end);
                try self.require("END");
                break :blk result;
            };
            try self.require(";");
            try definitions.append(a, .{ .name = name, .public = public, .kind = kind, .parameters = parameters, .body = body, .span = self.span(start), .domain = domain, .constructors = try constructors.toOwnedSlice(a) });
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
    if (!self.take(".")) return .{ .member = first };
    const second = try self.identifier();
    return .{ .qualifier = first, .member = second, .constructor = if (self.take(".")) try self.identifier() else null };
}
fn scalarType(self: *Self) !ScalarType {
    return if (self.take("BIGINT")) .bigint else if (self.take("TEXT")) .text else if (self.take("BOOLEAN")) .boolean else error.UnsupportedSourceType;
}
fn typeRef(self: *Self) !TypeRef {
    if (self.is("BIGINT") or self.is("TEXT") or self.is("BOOLEAN")) return .{ .scalar = try self.scalarType() };
    return .{ .named = try self.parseName() };
}
fn tableSignature(self: *Self) ![]const Column {
    try self.require("(");
    var columns: std.ArrayList(Column) = .empty;
    while (true) {
        if (columns.items.len == f.TableSchema.max_columns) return error.SourceParameterLimit;
        const name = try self.identifier();
        for (columns.items) |prior| if (std.mem.eql(u8, prior.name, name)) return error.DuplicateSourceName;
        var column: Column = .{ .name = name, .type = try self.typeRef() };
        var explicit_null = false;
        if (self.take("NOT")) {
            try self.require("NULL");
            column.nullable = false;
        } else explicit_null = self.take("NULL");
        if (self.take("PRIMARY")) {
            try self.require("KEY");
            if (explicit_null) return error.NullablePrimaryKey;
            column.primary = true;
            column.nullable = false;
        }
        if (self.take("COLLATE")) column.collation = try self.identifier();
        try columns.append(self.a, column);
        if (!self.take(",")) break;
    }
    try self.require(")");
    return columns.toOwnedSlice(self.a);
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
fn takeSignature(self: *Self, word: []const u8) bool {
    if (!self.is(word) or self.index + 1 == self.tokens.len) return false;
    const next = self.tokens[self.index + 1];
    if (!std.mem.eql(u8, self.text[next.start..next.end], "(")) return false;
    self.index += 1;
    return true;
}
fn parseParameters(self: *Self) ![]const Parameter {
    try self.require("(");
    var result: std.ArrayList(Parameter) = .empty;
    if (self.take(")")) return &.{};
    while (true) {
        if (result.items.len == 64) return error.SourceParameterLimit;
        const parameter_name = try self.identifier();
        for (result.items) |prior| if (std.mem.eql(u8, prior.name, parameter_name)) return error.DuplicateSourceName;
        const kind: Kind = if (self.take("BIGINT")) .integer else if (self.take("TEXT")) .text else if (self.take("BOOLEAN")) .boolean else if (self.take("IDENTIFIER")) .identifier else if (self.take("TYPE")) .type else if (self.take("MODULE")) .{ .module = try self.parseName() } else if (self.take("TABLE")) .{ .table = try self.tableSignature() } else if (self.takeSignature("STREAM")) .{ .stream = try self.tableSignature() } else if (self.takeSignature("QUEUE")) .{ .queue = try self.tableSignature() } else .{ .named = try self.parseName() };
        try result.append(self.a, .{ .name = parameter_name, .kind = kind });
        if (self.take(")")) break;
        try self.require(",");
    }
    return result.toOwnedSlice(self.a);
}
fn parseBody(self: *Self, stop: enum { end, conditional, arm }) anyerror![]const Statement {
    self.depth += 1;
    defer self.depth -= 1;
    if (self.depth > 64) return error.SourceDepthLimit;
    var result: std.ArrayList(Statement) = .empty;
    while (!self.is("END") and !(stop == .conditional and self.is("ELSE")) and !(stop == .arm and self.is("WHEN"))) {
        if (self.index == self.tokens.len) return error.InvalidSourceSyntax;
        const start = self.at();
        const value: @FieldType(Statement, "value") = if (self.take("USE")) blk: {
            var call = try self.parseCall();
            if (self.take("AS")) call.result = try self.identifier();
            try self.require(";");
            break :blk .{ .use = call };
        } else if (self.take("EXPORT")) blk: {
            const kind: enum { table, stream, queue } = if (self.take("TABLE")) .table else if (self.take("STREAM")) .stream else if (self.take("QUEUE")) .queue else return error.InvalidSourceSyntax;
            const operand = self.take("$");
            const source = try self.parseName();
            try self.require("AS");
            const alias = try self.identifier();
            try self.require(";");
            break :blk if (kind == .table) .{ .table_export = .{ .source = source, .operand = operand, .alias = alias } } else .{ .log_export = .{ .kind = if (kind == .stream) .stream else .queue, .source = source, .operand = operand, .alias = alias } };
        } else if (self.take("MATCH")) blk: {
            const value = try self.expression(0);
            var arms: std.ArrayList(Arm) = .empty;
            while (self.is("WHEN")) {
                const arm_start = self.at();
                try self.require("WHEN");
                if (arms.items.len == 64) return error.SourceConstructorLimit;
                const constructor = try self.parseName();
                try self.require("(");
                var names: std.ArrayList([]const u8) = .empty;
                if (!self.take(")")) while (true) {
                    if (names.items.len == 64) return error.SourceParameterLimit;
                    const name = try self.identifier();
                    for (names.items) |prior| if (std.mem.eql(u8, prior, name)) return error.DuplicateSourceName;
                    try names.append(self.a, name);
                    if (self.take(")")) break;
                    try self.require(",");
                };
                try self.require("THEN");
                const body = try self.parseBody(.arm);
                try arms.append(self.a, .{ .constructor = constructor, .names = try names.toOwnedSlice(self.a), .body = body, .span = self.span(arm_start) });
            }
            if (arms.items.len == 0) return error.InvalidSourceSyntax;
            try self.require("END");
            try self.require("MATCH");
            try self.require(";");
            break :blk .{ .match = .{ .value = value, .arms = try arms.toOwnedSlice(self.a) } };
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
            const body = try self.parseBody(.end);
            try self.require("END");
            try self.require(";");
            break :blk .{ .test_case = .{ .name = name, .setup = try setup.toOwnedSlice(self.a), .body = body } };
        } else if (self.take("ASSERT")) blk: {
            if (self.take("WORKFLOW")) {
                const name = try self.expression(0);
                try self.require("COMPLETED");
                const completed = try self.count();
                try self.require("REFUSED");
                const refused = try self.count();
                try self.require("WITHIN");
                const observations = try self.count();
                try self.require("OBSERVATIONS");
                try self.require(";");
                break :blk .{ .workflow = .{ .name = name, .completed = completed, .refused = refused, .observations = observations } };
            }
            const kind: enum { rows, command, refusal } = if (self.take("ROWS")) .rows else if (self.take("COMMAND")) .command else if (self.take("STATEMENT")) .refusal else return error.UnsupportedTestAssertion;
            const sql = try self.template(try self.parenthesized(), false);
            // Assertions contain simple statements in the reference grammar.
            // An empty compound body can otherwise pass shared SQL framing.
            if (sql.kind == .program) return error.UnsupportedTestAssertion;
            const expected: @FieldType(Assertion, "expected") = switch (kind) {
                .rows => rows: {
                    try self.require("EQUAL");
                    break :rows .{ .rows = try self.template(try self.parenthesized(), true) };
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
            const yes = try self.parseBody(.conditional);
            const no = if (self.take("ELSE")) try self.parseBody(.end) else &.{};
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
            break :blk .{ .sql = try self.template(sql, false) };
        };
        try result.append(self.a, .{ .span = self.span(start), .value = value });
    }
    return result.toOwnedSlice(self.a);
}
fn template(self: *Self, tokens: []const Token, rows: bool) !Template.Syntax {
    const end = if (self.index > 0) self.tokens[self.index - 1].start else self.at();
    return Template.parse(self.a, self.text, tokens, end, rows, self.location);
}
fn parseCall(self: *Self) !Call {
    return self.callAfterName(try self.parseName());
}
fn callAfterName(self: *Self, name: Name) !Call {
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
    } else if ((self.index + 1 < self.tokens.len and self.tokens[self.index + 1].kind == .string and self.take("NAME"))) .{ .identifier = try self.string() } else if (self.take("TYPE")) blk: {
        const kind = try self.typeRef();
        break :blk switch (kind) {
            .scalar => |scalar| .{ .type = scalar },
            .named => |name| .{ .named_type = name },
        };
    } else if (self.take("TRUE")) .{ .boolean = true } else if (self.take("FALSE")) .{ .boolean = false } else if (self.index < self.tokens.len and self.tokens[self.index].kind == .string) .{ .text = try self.string() } else if (self.index < self.tokens.len and self.tokens[self.index].kind == .number) blk: {
        const token = self.tokens[self.index];
        self.index += 1;
        break :blk .{ .integer = try std.fmt.parseInt(i64, self.text[token.start..token.end], 10) };
    } else blk: {
        const name = try self.parseName();
        break :blk if (self.is("(")) .{ .construct = try self.callAfterName(name) } else .{ .reference = name };
    };
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
