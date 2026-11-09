//! Structural Queue program parser using the shared bounded source lexer.
const std = @import("std");
const a = @import("ApplicationProgram.zig");
const input = @import("SqlInput.zig");
const sql = @import("Sql.zig");
const Self = @This();
allocator: std.mem.Allocator,
scan: input.SourceScan,
token: ?input.SourceScan.Token = null,
location: ?*sql.Location,
nodes: u16 = 0,
depth: usize = 0,
atomic_depth: usize = 0,

pub fn parse(allocator: std.mem.Allocator, source: []const u8, location: ?*sql.Location) !a.Owned {
    if (location) |value| value.* = .{};
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    // Bound before copying and retain immutable source with the owned tree.
    _ = try input.SourceScan.init(source);
    const owned = try arena.allocator().dupe(u8, source);
    var parser: Self = .{ .allocator = arena.allocator(), .scan = try input.SourceScan.init(owned), .location = location };
    try parser.advance();
    const parsed = try parser.program();
    return .{ .arena = arena, .source = owned, .program = parsed };
}
fn offset(self: Self) u32 {
    return if (self.token) |token| token.start else @intCast(self.scan.text.len);
}
fn advance(self: *Self) !void {
    while (try self.scan.next()) |token| {
        if (self.location) |location| location.offset = token.start;
        if (!token.closed and !(token.kind == .comment and std.mem.startsWith(u8, self.scan.text[token.start..token.end], "--"))) return error.UnterminatedSqlToken;
        if (token.kind == .space or token.kind == .comment) continue;
        self.token = token;
        return;
    }
    self.token = null;
    if (self.location) |location| location.offset = self.scan.text.len;
}
fn raw(self: Self) []const u8 {
    const token = self.token orelse return "";
    return self.scan.text[token.start..token.end];
}
fn word(self: Self, expected: []const u8) bool {
    return if (self.token) |token| token.kind == .word and std.ascii.eqlIgnoreCase(self.raw(), expected) else false;
}
fn takeWord(self: *Self, expected: []const u8) !bool {
    if (!self.word(expected)) return false;
    try self.advance();
    return true;
}
fn requireWord(self: *Self, expected: []const u8) !void {
    if (!try self.takeWord(expected)) {
        if (self.location) |location| location.expected = expected;
        return error.InvalidSqlSyntax;
    }
}
fn symbol(self: Self, expected: u8) bool {
    return if (self.token) |token| token.kind == .symbol and self.raw()[0] == expected else false;
}
fn take(self: *Self, expected: u8) !bool {
    if (!self.symbol(expected)) return false;
    try self.advance();
    return true;
}
fn require(self: *Self, expected: u8) !void {
    if (!try self.take(expected)) return error.InvalidSqlSyntax;
}
fn name(self: *Self) ![]const u8 {
    const token = self.token orelse return error.InvalidSqlSyntax;
    if (token.kind == .quoted) return self.quoted(.quoted);
    if (token.kind != .word) return error.InvalidSqlSyntax;
    if (self.raw().len > 255) return error.InvalidColumnName;
    const result = try self.allocator.dupe(u8, self.raw());
    for (result) |*byte| byte.* = std.ascii.toLower(byte.*);
    try self.advance();
    return result;
}
fn quoted(self: *Self, kind: input.Kind) ![]const u8 {
    const token = self.token orelse return error.InvalidSqlSyntax;
    if (token.kind != kind) return error.InvalidSqlSyntax;
    const raw_ = self.raw();
    const result = try self.allocator.alloc(u8, raw_.len - 2);
    var position: usize = 1;
    var count: usize = 0;
    while (position < raw_.len - 1) : (position += 1) {
        result[count] = raw_[position];
        count += 1;
        if (raw_[position] == raw_[0]) position += 1;
    }
    if (kind == .quoted and (count == 0 or count > 255)) return error.InvalidColumnName;
    try self.advance();
    return result[0..count];
}
fn id(self: *Self) !a.Id {
    if (self.nodes == a.max_nodes) return error.ProgramTooComplex;
    self.nodes += 1;
    return self.nodes;
}
fn enter(self: *Self) !void {
    if (self.depth == a.max_depth) return error.ProgramTooDeep;
    self.depth += 1;
}
fn node(self: *Self, start: u32, value: @FieldType(a.Expression, "value")) !*a.Expression {
    const result = try self.allocator.create(a.Expression);
    result.* = .{ .id = try self.id(), .span = .{ .start = start, .end = self.offset() }, .value = value };
    return result;
}
fn expression(self: *Self) anyerror!*a.Expression {
    return self.binary(0);
}
fn binary(self: *Self, minimum: u8) anyerror!*a.Expression {
    try self.enter();
    defer self.depth -= 1;
    const start = self.offset();
    var left = try self.primary();
    while (true) {
        if (minimum <= 3 and self.word("IS")) {
            try self.advance();
            const invert = try self.takeWord("NOT");
            try self.requireWord("NULL");
            left = try self.node(start, .{ .unary = .{ .operator = if (invert) .is_not_null else .is_null, .operand = left } });
            continue;
        }
        const operator: a.Binary, const precedence: u8 = if (self.word("OR")) .{ .or_, 1 } else if (self.word("AND")) .{ .and_, 2 } else if (self.symbol('=')) .{ .equal, 3 } else if (self.symbol('<')) .{ .less, 3 } else if (self.symbol('>')) .{ .greater, 3 } else if (self.symbol('|')) .{ .concatenate, 4 } else if (self.symbol('+')) .{ .add, 5 } else if (self.symbol('-')) .{ .subtract, 5 } else break;
        if (precedence < minimum) break;
        const end = self.token.?.end;
        try self.advance();
        var selected = operator;
        if (operator == .concatenate) {
            if (self.offset() != end) return error.InvalidSqlSyntax;
            try self.require('|');
        } else if (operator == .less or operator == .greater) {
            if (self.offset() == end and try self.take('=')) selected = if (operator == .less) .less_equal else .greater_equal else if (operator == .less and self.offset() == end and try self.take('>')) selected = .not_equal;
        }
        const right = try self.binary(precedence + 1);
        left = try self.node(start, .{ .binary = .{ .operator = selected, .left = left, .right = right } });
    }
    return left;
}
fn primary(self: *Self) anyerror!*a.Expression {
    const start = self.offset();
    var result: *a.Expression = undefined;
    if (try self.takeWord("NOT")) {
        result = try self.node(start, .{ .unary = .{ .operator = .not_, .operand = try self.binary(3) } });
    } else if (try self.take('-')) {
        result = try self.node(start, .{ .unary = .{ .operator = .negate, .operand = try self.binary(6) } });
    } else if (try self.take('(')) {
        result = try self.expression();
        try self.require(')');
    } else if (try self.takeWord("NULL")) {
        result = try self.node(start, .null);
    } else if (self.word("TRUE") or self.word("FALSE")) {
        const value = self.word("TRUE");
        try self.advance();
        result = try self.node(start, .{ .boolean = value });
    } else if (try self.takeWord("CASE")) {
        try self.requireWord("WHEN");
        const condition = try self.expression();
        try self.requireWord("THEN");
        const yes = try self.expression();
        try self.requireWord("ELSE");
        const no = try self.expression();
        try self.requireWord("END");
        result = try self.node(start, .{ .case = .{ .condition = condition, .yes = yes, .no = no } });
    } else if (try self.takeWord("CAST")) {
        try self.require('(');
        const value = try self.expression();
        try self.requireWord("AS");
        try self.requireWord("TEXT");
        try self.require(')');
        result = try self.node(start, .{ .text_cast = value });
    } else if (try self.takeWord("ROW")) {
        result = try self.node(start, .{ .row = try self.arguments() });
    } else {
        const token = self.token orelse return error.InvalidSqlSyntax;
        switch (token.kind) {
            .number => {
                const value = std.fmt.parseInt(i64, self.raw(), 10) catch return error.LiteralOutOfRange;
                try self.advance();
                result = try self.node(start, .{ .integer = value });
            },
            .string => result = try self.node(start, .{ .text = try self.quoted(.string) }),
            .word, .quoted => {
                const value = try self.name();
                if (self.symbol('(')) {
                    const function = std.meta.stringToEnum(a.Function, value) orelse return error.UnknownProgramFunction;
                    result = try self.node(start, .{ .call = .{ .function = function, .arguments = try self.arguments() } });
                } else result = try self.node(start, .{ .name = value });
            },
            else => return error.InvalidSqlSyntax,
        }
    }
    while (try self.take('.')) result = try self.node(start, .{ .field = .{ .base = result, .name = try self.name() } });
    return result;
}
fn arguments(self: *Self) ![]const *a.Expression {
    try self.require('(');
    var values: std.ArrayList(*a.Expression) = .empty;
    if (!try self.take(')')) while (true) {
        if (values.items.len == a.max_arguments) return error.ProgramTooComplex;
        try values.append(self.allocator, try self.expression());
        if (try self.take(')')) break;
        try self.require(',');
    };
    return values.toOwnedSlice(self.allocator);
}
fn names(self: *Self) ![]const []const u8 {
    try self.require('(');
    var values: std.ArrayList([]const u8) = .empty;
    while (true) {
        if (values.items.len == a.max_arguments) return error.ProgramTooComplex;
        const value = try self.name();
        for (values.items) |prior| if (std.mem.eql(u8, prior, value)) return error.DuplicateProgramField;
        try values.append(self.allocator, value);
        if (try self.take(')')) break;
        try self.require(',');
    }
    return values.toOwnedSlice(self.allocator);
}
fn fields(self: *Self) ![]const a.Field {
    try self.require('(');
    var values: std.ArrayList(a.Field) = .empty;
    while (true) {
        if (values.items.len == a.max_arguments) return error.ProgramTooComplex;
        const key = try self.name();
        for (values.items) |prior| if (std.mem.eql(u8, prior.name, key)) return error.DuplicateProgramField;
        try self.require('=');
        try values.append(self.allocator, .{ .name = key, .value = try self.expression() });
        if (try self.take(')')) break;
        try self.require(',');
    }
    return values.toOwnedSlice(self.allocator);
}
fn select(self: *Self) !a.Select {
    try self.requireWord("SELECT");
    var columns: ?[]const []const u8 = null;
    if (!try self.take('*')) {
        var values: std.ArrayList([]const u8) = .empty;
        while (true) {
            if (values.items.len == a.max_arguments) return error.ProgramTooComplex;
            try values.append(self.allocator, try self.name());
            if (!try self.take(',')) break;
        }
        columns = try values.toOwnedSlice(self.allocator);
    }
    try self.requireWord("FROM");
    const target = try self.name();
    const predicate = if (try self.takeWord("WHERE")) try self.expression() else null;
    return .{ .target = target, .columns = columns, .predicate = predicate };
}
fn effect(self: *Self) !a.Effect {
    if (self.atomic_depth != 0) return error.EffectInsideAtomic;
    try self.requireWord("EXECUTE");
    try self.requireWord("SINK");
    const sink = try self.name();
    try self.requireWord("EFFECT");
    const identity = try self.expression();
    try self.requireWord("GUARD");
    const guard = try self.expression();
    const request: @FieldType(a.Effect, "request") = if (try self.takeWord("FORM")) .{ .form = try self.fields() } else blk: {
        try self.requireWord("HEADERS");
        break :blk .{ .headers = try self.fields() };
    };
    try self.requireWord("ON");
    try self.requireWord("REPLAY");
    try self.requireWord("OBSERVE");
    try self.requireWord("ONLY");
    return .{ .sink = sink, .identity = identity, .guard = guard, .request = request };
}
fn binding(self: *Self) !a.Binding {
    const variable = try self.name();
    try self.require('=');
    const value: @FieldType(a.Binding, "value") = if (try self.takeWord("GET")) blk: {
        try self.requireWord("FROM");
        const target = try self.name();
        try self.requireWord("KEY");
        break :blk .{ .get = .{ .target = target, .key = try self.expression() } };
    } else if (self.word("SELECT")) .{ .select = try self.select() } else if (self.word("EXECUTE")) .{ .effect = try self.effect() } else .{ .expression = try self.expression() };
    return .{ .name = variable, .value = value };
}
fn response(self: *Self) !a.Response {
    try self.requireWord("TO");
    const request = try self.expression();
    try self.requireWord("STATUS");
    if (self.token == null or self.token.?.kind != .number) return error.InvalidProgramStatus;
    const status = std.fmt.parseInt(u16, self.raw(), 10) catch return error.InvalidProgramStatus;
    if (status < 200 or status > 599) return error.InvalidProgramStatus;
    try self.advance();
    var guard: ?*a.Expression = null;
    var body: @FieldType(a.Response, "body") = .empty;
    var cookies: std.ArrayList(a.Cookie) = .empty;
    while (true) {
        if (try self.takeWord("GUARD")) {
            if (guard != null) return error.DuplicateProgramField;
            guard = try self.expression();
        } else if (self.word("JSON") or self.word("LOCATION")) {
            if (body != .empty) return error.DuplicateProgramField;
            const is_json = self.word("JSON");
            try self.advance();
            const value = try self.expression();
            body = if (is_json) .{ .json = value } else .{ .location = value };
        } else if (self.word("SET") or self.word("CLEAR")) {
            if (cookies.items.len == 8) return error.ProgramTooComplex;
            const set = self.word("SET");
            try self.advance();
            try self.requireWord("COOKIE");
            const key = try self.quoted(.string);
            for (cookies.items) |cookie| if (std.mem.eql(u8, cookie.name, key)) return error.DuplicateProgramField;
            const value = if (set) blk: {
                try self.requireWord("VALUE");
                break :blk try self.expression();
            } else null;
            try self.requireWord("SECURE");
            try self.requireWord("HTTPONLY");
            try self.requireWord("SAMESITE");
            try self.requireWord("LAX");
            try self.requireWord("PATH");
            if (!std.mem.eql(u8, try self.quoted(.string), "/")) return error.InvalidProgramCookie;
            const max_age = if (set) blk: {
                try self.requireWord("MAX");
                try self.requireWord("AGE");
                break :blk try self.expression();
            } else null;
            try cookies.append(self.allocator, .{ .name = key, .value = value, .max_age = max_age });
        } else break;
    }
    return .{ .request = request, .status = status, .guard = guard, .body = body, .cookies = try cookies.toOwnedSlice(self.allocator) };
}
fn block(self: *Self) anyerror![]const a.Instruction {
    try self.enter();
    defer self.depth -= 1;
    var instructions: std.ArrayList(a.Instruction) = .empty;
    while (!self.word("END") and !self.word("ELSE") and !self.word("ON")) {
        if (self.token == null) return error.UnbalancedSqlBlock;
        try instructions.append(self.allocator, try self.instruction());
    }
    return instructions.toOwnedSlice(self.allocator);
}
fn instruction(self: *Self) anyerror!a.Instruction {
    const start = self.offset();
    const identity = try self.id();
    const value: @FieldType(a.Instruction, "value") = if (try self.takeWord("LET")) .{ .let = try self.binding() } else if (try self.takeWord("REQUIRE")) blk: {
        const condition = try self.expression();
        try self.requireWord("ELSE");
        break :blk .{ .require = .{ .condition = condition, .refusal = try self.quoted(.string) } };
    } else if (try self.takeWord("BEGIN")) blk: {
        if (self.atomic_depth != 0) return error.NestedAtomicProgram;
        try self.requireWord("ATOMIC");
        self.atomic_depth += 1;
        defer self.atomic_depth -= 1;
        const instructions = try self.block();
        try self.requireWord("END");
        break :blk .{ .atomic = instructions };
    } else if (try self.takeWord("IF")) blk: {
        const condition = try self.expression();
        try self.requireWord("THEN");
        const yes = try self.block();
        const no = if (try self.takeWord("ELSE")) try self.block() else &.{};
        try self.requireWord("END");
        try self.requireWord("IF");
        break :blk .{ .conditional = .{ .condition = condition, .yes = yes, .no = no } };
    } else if (try self.takeWord("PUT")) blk: {
        if (self.atomic_depth == 0) return error.MutationOutsideAtomic;
        try self.requireWord("INTO");
        const target = try self.name();
        try self.requireWord("KEY");
        const key = try self.expression();
        try self.requireWord("VALUE");
        const value = try self.expression();
        const fields_ = if (try self.takeWord("WITH")) try self.fields() else &.{};
        try self.requireWord("IF");
        const expected: @FieldType(@FieldType(@FieldType(a.Instruction, "value"), "put"), "expected") = if (try self.takeWord("ABSENT")) .absent else expected: {
            try self.requireWord("REVISION");
            try self.require('=');
            break :expected .{ .revision = try self.expression() };
        };
        break :blk .{ .put = .{ .target = target, .key = key, .value = value, .fields = fields_, .expected = expected } };
    } else if (try self.takeWord("INSERT")) blk: {
        if (self.atomic_depth == 0) return error.MutationOutsideAtomic;
        try self.requireWord("INTO");
        const target = try self.name();
        try self.requireWord("VALUES");
        const values = try self.arguments();
        try self.requireWord("ON");
        try self.requireWord("CONFLICT");
        const columns = try self.names();
        try self.requireWord("DO");
        try self.requireWord("ASSERT");
        try self.requireWord("SAME");
        try self.requireWord("ROW");
        break :blk .{ .insert = .{ .target = target, .values = values, .conflict_columns = columns } };
    } else if (self.word("PRODUCE") or self.word("ENQUEUE")) blk: {
        if (self.atomic_depth == 0) return error.MutationOutsideAtomic;
        const stream = self.word("PRODUCE");
        try self.advance();
        try self.requireWord("INTO");
        const target = try self.name();
        try self.requireWord("VALUES");
        break :blk .{ .append = .{ .kind = if (stream) .stream else .queue, .target = target, .values = try self.arguments() } };
    } else if (try self.takeWord("HANDOFF")) blk: {
        if (self.atomic_depth == 0) return error.MutationOutsideAtomic;
        const request = try self.expression();
        try self.requireWord("TO");
        const queue = try self.name();
        try self.requireWord("EFFECT");
        break :blk .{ .handoff = .{ .request = request, .queue = queue, .effect = try self.expression() } };
    } else if (try self.takeWord("RESPOND")) blk: {
        if (try self.takeWord("ERROR")) {
            try self.requireWord("TO");
            const request = try self.expression();
            try self.requireWord("USING");
            const failure = try self.name();
            try self.requireWord("PUBLIC");
            try self.requireWord("PROFILE");
            break :blk .{ .respond_error = .{ .request = request, .failure = failure, .profile = try self.quoted(.string) } };
        }
        break :blk .{ .respond = try self.response() };
    } else return error.UnsupportedProgramInstruction;
    const end = self.offset();
    try self.require(';');
    return .{ .id = identity, .span = .{ .start = start, .end = end }, .value = value };
}
fn program(self: *Self) !a.Program {
    try self.requireWord("CREATE");
    try self.requireWord("DATAFLOW");
    const program_name = try self.name();
    try self.requireWord("FROM");
    try self.requireWord("QUEUE");
    const queue = try self.name();
    try self.requireWord("AS");
    const variable = try self.name();
    const predicate = if (try self.takeWord("WHERE")) try self.expression() else null;
    var deadline: ?[]const u8 = null;
    if (try self.takeWord("WITH")) {
        try self.require('(');
        try self.requireWord("DEADLINE");
        try self.require('=');
        deadline = try self.quoted(.string);
        try self.require(')');
    }
    try self.requireWord("AS");
    var failure: @FieldType(a.Program, "failure") = null;
    const body: @FieldType(a.Program, "body") = if (try self.takeWord("BEGIN")) blk: {
        const instructions = try self.block();
        if (try self.takeWord("ON")) {
            try self.requireWord("FAILURE");
            const failure_name = try self.name();
            failure = .{ .name = failure_name, .instructions = try self.block() };
        }
        try self.requireWord("END");
        break :blk .{ .instructions = instructions };
    } else blk: {
        const query = try self.select();
        try self.requireWord("RESPOND");
        try self.requireWord("TO");
        const request = try self.expression();
        try self.requireWord("USING");
        const profile = try self.quoted(.string);
        try self.requireWord("PAGE");
        try self.requireWord("SIZE");
        if (self.token == null or self.token.?.kind != .number) return error.InvalidProgramPage;
        const size = std.fmt.parseInt(u16, self.raw(), 10) catch return error.InvalidProgramPage;
        if (size == 0 or size > 256) return error.InvalidProgramPage;
        try self.advance();
        break :blk .{ .page = .{ .select = query, .request = request, .profile = profile, .size = size } };
    };
    _ = try self.take(';');
    if (self.token != null) return error.UnsupportedConstruct;
    return .{ .name = program_name, .queue = queue, .input = variable, .predicate = predicate, .deadline = deadline, .body = body, .failure = failure, .nodes = self.nodes };
}
