//! Shared allocator-owned SQL identifiers, logical types and typed literals.
//! This parser uses Sql's lexer; it performs no source binding or execution.
const std = @import("std");
const sql = @import("Sql.zig");
const t = @import("Types.zig");
const names = @import("SqlTypes.zig");
const Cell = t.Values.Cell;
const Self = @This();
pub const Literal = @import("SqlLiteral.zig");
allocator: std.mem.Allocator,
lexer: sql.Lexer,
token: sql.Token = .{ .tag = .eof, .text = "" },
location: ?*sql.Location = null,
depth: usize = 0,
previous_end: usize = 0,
editor: ?*Editor = null,
roles: ?[]sql.TokenRole = null,
pub const NameRole = enum { source, column, proposed };
pub const Identifier = struct {
    bytes: [255]u8 = undefined,
    len: u8,
    pub fn init(raw: []const u8) Identifier {
        std.debug.assert(raw.len <= 255);
        var result: Identifier = .{ .len = @intCast(raw.len) };
        @memcpy(result.bytes[0..raw.len], raw);
        return result;
    }
    pub fn slice(self: *const Identifier) []const u8 {
        return self.bytes[0..self.len];
    }
};
pub const Editor = struct {
    words: [32]?[]const u8 = @splat(null),
    symbols: [16]?sql.Tag = @splat(null),
    name_role: ?NameRole = null,
    type_name: bool = false,
    value_type: ?std.meta.Tag(t.Type) = null,
    qualifier: ?Identifier = null,
    sum_only: bool = false,
    pub fn word(self: *Editor, value_: []const u8) void {
        for (&self.words) |*slot| {
            if (slot.*) |prior| {
                if (std.mem.eql(u8, prior, value_)) return;
            } else {
                slot.* = value_;
                return;
            }
        }
        unreachable;
    }
    pub fn symbol(self: *Editor, value_: sql.Tag) void {
        for (&self.symbols) |*slot| {
            if (slot.* == value_) return;
            if (slot.* == null) {
                slot.* = value_;
                return;
            }
        }
        unreachable;
    }
};
pub fn boundary(self: *Self) ?*Editor {
    return if (self.token.tag == .eof) self.editor else null;
}
pub fn named(self: *Self, role: NameRole) ![]const u8 {
    if (self.boundary()) |editor| editor.name_role = role;
    return self.name();
}
pub fn init(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location) !Self {
    if (location) |detail| detail.* = .{};
    try sql.validateText(text);
    var self: Self = .{ .allocator = allocator, .lexer = .{ .text = text }, .location = location };
    try self.advance();
    return self;
}
pub fn advance(self: *Self) !void {
    self.previous_end = self.lexer.position;
    self.token = self.lexer.next() catch |err| {
        if (self.location) |location| location.* = .{ .offset = self.lexer.start };
        return err;
    };
    if (self.location) |location| location.* = .{ .offset = self.lexer.start };
}
pub fn word(self: Self, expected: []const u8) bool {
    if (self.token.tag == .eof) if (self.editor) |editor| editor.word(expected);
    return self.token.tag == .word and std.ascii.eqlIgnoreCase(self.token.text, expected);
}
pub fn annotate(self: *Self, role: sql.TokenRole) void {
    const roles = self.roles orelse return;
    if (roles.len != self.lexer.text.len) return;
    @memset(roles[self.lexer.start..self.lexer.position], role);
}
pub fn takeWord(self: *Self, expected: []const u8) !bool {
    return self.takeWordRole(expected, .keyword);
}
pub fn takeWordRole(self: *Self, expected: []const u8, role: sql.TokenRole) !bool {
    if (!self.word(expected)) return false;
    self.annotate(role);
    try self.advance();
    return true;
}
pub fn requireWord(self: *Self, expected: []const u8) !void {
    if (try self.takeWord(expected)) return;
    if (self.location) |location| location.expected = expected;
    return error.InvalidSqlSyntax;
}
pub fn take(self: *Self, tag: sql.Tag) !bool {
    if (self.boundary()) |editor| editor.symbol(tag);
    if (self.token.tag != tag) return false;
    try self.advance();
    return true;
}
pub fn require(self: *Self, tag: sql.Tag) !void {
    if (!try self.take(tag)) return error.InvalidSqlSyntax;
}
pub fn finish(self: *Self) !void {
    _ = try self.take(.semi);
    if (self.token.tag != .eof) return error.UnsupportedConstruct;
}
fn unquote(self: *Self, tag: sql.Tag) ![]const u8 {
    if (self.token.tag != tag) return error.InvalidSqlSyntax;
    self.annotate(if (tag == .quoted) .identifier else .literal);
    const quote = self.token.text[0];
    const raw = self.token.text[1 .. self.token.text.len - 1];
    const output = try self.allocator.alloc(u8, raw.len);
    var written: usize = 0;
    var i: usize = 0;
    while (i < raw.len) : (i += 1) {
        output[written] = raw[i];
        written += 1;
        if (raw[i] == quote) {
            if (i + 1 >= raw.len or raw[i + 1] != quote) return error.InvalidSqlSyntax;
            i += 1;
        }
    }
    try self.advance();
    return output[0..written];
}
pub fn name(self: *Self) ![]const u8 {
    const result = if (self.token.tag == .quoted) try self.unquote(.quoted) else blk: {
        if (self.token.tag != .word or sql.isReserved(self.token.text)) return error.InvalidSqlSyntax;
        self.annotate(.identifier);
        const identifier = try self.allocator.dupe(u8, self.token.text);
        for (identifier) |*byte| byte.* = std.ascii.toLower(byte.*);
        try self.advance();
        break :blk identifier;
    };
    if (result.len == 0 or result.len > 255 or std.mem.indexOfScalar(u8, result, 0) != null) return error.InvalidColumnName;
    return result;
}
fn number(self: *Self) ![]const u8 {
    if (self.token.tag == .minus or self.token.tag == .plus) self.annotate(.number);
    const negative = try self.take(.minus);
    if (!negative) _ = try self.take(.plus);
    if (self.token.tag != .integer) return error.InvalidSqlSyntax;
    const start = self.lexer.start;
    self.annotate(.number);
    var end = start + self.token.text.len;
    try self.advance();
    if (self.token.tag == .dot and self.lexer.start == end) {
        self.annotate(.number);
        end += self.token.text.len;
        try self.advance();
        if (self.token.tag != .integer or self.lexer.start != end) return error.InvalidLiteral;
        self.annotate(.number);
        end += self.token.text.len;
        try self.advance();
    }
    if (self.token.tag == .word and self.lexer.start == end and std.ascii.toLower(self.token.text[0]) == 'e') {
        const exponent_only = self.token.text.len == 1;
        self.annotate(.number);
        end += self.token.text.len;
        try self.advance();
        if (exponent_only) {
            if ((self.token.tag == .plus or self.token.tag == .minus) and self.lexer.start == end) {
                self.annotate(.number);
                end += 1;
                try self.advance();
            }
            if (self.token.tag != .integer or self.lexer.start != end) return error.InvalidLiteral;
            self.annotate(.number);
            end += self.token.text.len;
            try self.advance();
        }
    }
    const raw = self.lexer.text[start..end];
    return if (negative) std.fmt.allocPrint(self.allocator, "-{s}", .{raw}) else raw;
}
fn unsigned(self: *Self) !u32 {
    if (self.token.tag != .integer) return error.InvalidTypeParameters;
    const result = std.fmt.parseInt(u32, self.token.text, 10) catch return error.InvalidTypeParameters;
    try self.advance();
    return result;
}
pub fn nullability(self: *Self, default: bool) !struct { value: bool, explicit: bool } {
    if (try self.takeWord("NOT")) {
        try self.requireWord("NULL");
        return .{ .value = false, .explicit = true };
    }
    if (try self.takeWord("NULL")) return .{ .value = true, .explicit = true };
    return .{ .value = default, .explicit = false };
}
fn nested(self: *Self) anyerror!t.Type {
    const result = try self.dataType();
    if (result.max_characters != null) return error.UnsupportedNestedCharacterLimit;
    return result.type;
}
pub fn dataType(self: *Self) anyerror!names.Resolved {
    if (self.boundary()) |editor| editor.type_name = true;
    if (self.depth == 16) return error.TypeBudgetExceeded;
    self.depth += 1;
    defer self.depth -= 1;
    if (self.token.tag != .word) {
        if (self.location) |location| location.expected = "a logical type name";
        return error.InvalidSqlSyntax;
    }
    self.annotate(.type_name);
    var name_text = self.token.text;
    try self.advance();
    if (std.ascii.eqlIgnoreCase(name_text, "STRUCT") or std.ascii.eqlIgnoreCase(name_text, "UNION")) {
        try self.require(.left);
        var fields: std.ArrayList(t.Field) = .empty;
        while (true) {
            if (fields.items.len == 255) return error.TypeBudgetExceeded;
            const field_name = try self.name();
            const field_type = try self.nested();
            const nullable = try self.nullability(true);
            const optional = try self.takeWord("OPTIONAL");
            try fields.append(self.allocator, .{ .name = field_name, .type = field_type, .nullable = nullable.value, .optional = optional });
            if (!try self.take(.comma)) break;
        }
        try self.require(.right);
        return .{ .type = if (std.ascii.eqlIgnoreCase(name_text, "STRUCT")) .{ .structure = try fields.toOwnedSlice(self.allocator) } else .{ .tagged_union = try fields.toOwnedSlice(self.allocator) } };
    }
    if (std.ascii.eqlIgnoreCase(name_text, "LIST") or std.ascii.eqlIgnoreCase(name_text, "ARRAY") or std.ascii.eqlIgnoreCase(name_text, "MAP")) {
        try self.require(.left);
        const first = try self.allocator.create(t.Type);
        first.* = try self.nested();
        const nullable = try self.nullability(true);
        const result: t.Type = if (std.ascii.eqlIgnoreCase(name_text, "MAP")) blk: {
            if (nullable.explicit and nullable.value) return error.NullableMapKey;
            try self.require(.comma);
            const value_type = try self.allocator.create(t.Type);
            value_type.* = try self.nested();
            const value_nullable = try self.nullability(true);
            break :blk .{ .map = .{ .key = first, .value = .{ .type = value_type, .nullable = value_nullable.value } } };
        } else if (std.ascii.eqlIgnoreCase(name_text, "ARRAY")) blk: {
            try self.require(.comma);
            break :blk .{ .array = .{ .element = .{ .type = first, .nullable = nullable.value }, .length = try self.unsigned() } };
        } else .{ .list = .{ .type = first, .nullable = nullable.value } };
        try self.require(.right);
        try result.validate(.{});
        return .{ .type = result };
    }
    if (std.ascii.eqlIgnoreCase(name_text, "DOUBLE") and try self.takeWordRole("PRECISION", .type_name)) name_text = "DOUBLE PRECISION";
    if (std.ascii.eqlIgnoreCase(name_text, "CHARACTER") and try self.takeWordRole("VARYING", .type_name)) name_text = "CHARACTER VARYING";
    var parameters: [2]u32 = undefined;
    var count: usize = 0;
    if (try self.take(.left)) {
        while (true) {
            if (count == parameters.len) return error.InvalidTypeParameters;
            parameters[count] = try self.unsigned();
            count += 1;
            if (!try self.take(.comma)) break;
        }
        try self.require(.right);
    }
    var zone: names.Zone = .unspecified;
    if (try self.takeWord("WITH")) zone = .with else if (try self.takeWord("WITHOUT")) zone = .without;
    if (zone != .unspecified) {
        try self.requireWord("TIME");
        try self.requireWord("ZONE");
    }
    return names.resolve(name_text, parameters[0..count], zone);
}
pub fn value(self: *Self, expected: t.Type) anyerror!Cell {
    const syntax = try self.literal(expected);
    var failure: ?Literal.Span = null;
    return syntax.bind(self.allocator, expected, &failure) catch |err| {
        if (self.location) |at| if (failure) |span| {
            at.* = .{ .offset = span.start };
        };
        return err;
    };
}
/// Parse literal grammar independently of a source schema. The optional type
/// supplies editor continuations only; bind performs actual type admission.
pub fn literal(self: *Self, expected: ?t.Type) anyerror!Literal {
    if (self.boundary()) |editor| {
        editor.word("NULL");
        editor.word("MISSING");
        if (expected) |kind| {
            editor.value_type = std.meta.activeTag(kind);
            switch (kind) {
                .boolean => {
                    editor.word("TRUE");
                    editor.word("FALSE");
                },
                .structure => editor.word("STRUCT"),
                .list => editor.word("LIST"),
                .array => editor.word("ARRAY"),
                .map => editor.word("MAP"),
                .tagged_union => editor.word("UNION"),
                .interval => editor.word("INTERVAL"),
                .date => editor.word("DATE"),
                .time => editor.word("TIME"),
                .timestamp => editor.word("TIMESTAMP"),
                .uuid => editor.word("UUID"),
                .binary => editor.word("X"),
                .json => editor.word("JSON"),
                else => {},
            }
        }
    }
    if (self.depth == 16) return error.ValueBudgetExceeded;
    self.depth += 1;
    defer self.depth -= 1;
    const start = self.lexer.start;
    const result = try self.literalValue(expected);
    return .{ .span = .{ .start = start, .end = self.previous_end }, .value = result };
}
fn literalValue(self: *Self, expected: ?t.Type) anyerror!@FieldType(Literal, "value") {
    if (self.token.tag == .string) return .{ .string = try self.unquote(.string) };
    if (self.token.tag == .integer or self.token.tag == .minus or self.token.tag == .plus) return .{ .number = try self.number() };
    if (self.token.tag == .word) {
        if (try self.takeWordRole("NULL", .literal)) return .null;
        if (try self.takeWordRole("MISSING", .literal)) return .missing;
        if (try self.takeWordRole("TRUE", .literal)) return .{ .boolean = true };
        if (try self.takeWordRole("FALSE", .literal)) return .{ .boolean = false };
        inline for (.{ .{ "X", "binary" }, .{ "DATE", "date" }, .{ "TIME", "time" }, .{ "TIMESTAMP", "timestamp" }, .{ "UUID", "uuid" }, .{ "JSON", "json" } }) |prefix| {
            if (try self.takeWordRole(prefix[0], .type_name)) return @unionInit(@FieldType(Literal, "value"), prefix[1], try self.unquote(.string));
        }
        if (try self.takeWordRole("UNION", .function)) {
            try self.require(.left);
            const start = self.lexer.start;
            const selected = try self.name();
            const selected_span: Literal.Span = .{ .start = start, .end = self.previous_end };
            var child_type: ?t.Type = null;
            if (expected) |kind| if (kind == .tagged_union) {
                for (kind.tagged_union) |field| if (std.mem.eql(u8, field.name, selected)) {
                    child_type = field.type;
                    break;
                };
            };
            try self.require(.comma);
            const child = try self.allocator.create(Literal);
            child.* = try self.literal(child_type);
            try self.require(.right);
            return .{ .tagged_union = .{ .name = selected, .selected = selected_span, .value = child } };
        }
        inline for (.{ .{ "STRUCT", "structure" }, .{ "LIST", "list" }, .{ "ARRAY", "array" }, .{ "MAP", "map" }, .{ "INTERVAL", "interval" } }) |constructor| {
            if (try self.takeWordRole(constructor[0], .function)) {
                try self.require(.left);
                var children: std.ArrayList(Literal) = .empty;
                if (self.token.tag != .right) while (true) {
                    if (children.items.len == 65536) return error.ValueBudgetExceeded;
                    const child_type = childType(expected, constructor[1], children.items.len);
                    try children.append(self.allocator, try self.literal(child_type));
                    if (!try self.take(.comma)) break;
                };
                try self.require(.right);
                return @unionInit(@FieldType(Literal, "value"), constructor[1], try children.toOwnedSlice(self.allocator));
            }
        }
    }
    if (expected) |kind| switch (kind) {
        .binary => return error.InvalidBinaryLiteral,
        .boolean => return error.InvalidLiteral,
        else => {},
    };
    return error.InvalidSqlSyntax;
}
fn childType(expected: ?t.Type, comptime constructor: []const u8, index: usize) ?t.Type {
    const kind = expected orelse return null;
    if (!std.mem.eql(u8, @tagName(kind), constructor)) return null;
    return switch (kind) {
        .structure => |fields| if (index < fields.len) fields[index].type else null,
        .list => |element| element.type.*,
        .array => |array| array.element.type.*,
        .map => |map| if (index % 2 == 0) map.key.* else map.value.type.*,
        .interval => if (index < 2) .int32 else if (index == 2) .int64 else null,
        else => null,
    };
}

test {
    _ = @import("sql_typed_test.zig");
}
