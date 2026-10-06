//! Shared allocator-owned SQL identifiers, logical types and typed literals.
//! This parser uses Sql's lexer; it performs no source binding or execution.
const std = @import("std");
const sql = @import("Sql.zig");
const t = @import("Types.zig");
const names = @import("SqlTypes.zig");
const Cell = t.Values.Cell;
const Self = @This();
allocator: std.mem.Allocator,
lexer: sql.Lexer,
token: sql.Token = .{ .tag = .eof, .text = "" },
location: ?*sql.Location = null,
depth: usize = 0,
pub fn init(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location) !Self {
    if (location) |detail| detail.* = .{};
    try sql.validateText(text);
    var self: Self = .{ .allocator = allocator, .lexer = .{ .text = text }, .location = location };
    try self.advance();
    return self;
}
pub fn advance(self: *Self) !void {
    self.token = self.lexer.next() catch |err| {
        if (self.location) |location| location.* = .{ .offset = self.lexer.start };
        return err;
    };
    if (self.location) |location| location.* = .{ .offset = self.lexer.start };
}
pub fn word(self: Self, expected: []const u8) bool {
    return self.token.tag == .word and std.ascii.eqlIgnoreCase(self.token.text, expected);
}
pub fn takeWord(self: *Self, expected: []const u8) !bool {
    if (!self.word(expected)) return false;
    try self.advance();
    return true;
}
pub fn requireWord(self: *Self, expected: []const u8) !void {
    if (try self.takeWord(expected)) return;
    if (self.location) |location| location.expected = expected;
    return error.InvalidSqlSyntax;
}
pub fn take(self: *Self, tag: sql.Tag) !bool {
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
        const identifier = try self.allocator.dupe(u8, self.token.text);
        for (identifier) |*byte| byte.* = std.ascii.toLower(byte.*);
        try self.advance();
        break :blk identifier;
    };
    if (result.len == 0 or result.len > 255 or std.mem.indexOfScalar(u8, result, 0) != null) return error.InvalidColumnName;
    return result;
}
fn number(self: *Self) ![]const u8 {
    const negative = try self.take(.minus);
    if (!negative) _ = try self.take(.plus);
    if (self.token.tag != .integer) return error.InvalidSqlSyntax;
    const start = self.lexer.start;
    var end = start + self.token.text.len;
    try self.advance();
    if (self.token.tag == .dot and self.lexer.start == end) {
        end += self.token.text.len;
        try self.advance();
        if (self.token.tag != .integer or self.lexer.start != end) return error.InvalidLiteral;
        end += self.token.text.len;
        try self.advance();
    }
    if (self.token.tag == .word and self.lexer.start == end and std.ascii.toLower(self.token.text[0]) == 'e') {
        const exponent_only = self.token.text.len == 1;
        end += self.token.text.len;
        try self.advance();
        if (exponent_only) {
            if ((self.token.tag == .plus or self.token.tag == .minus) and self.lexer.start == end) {
                end += 1;
                try self.advance();
            }
            if (self.token.tag != .integer or self.lexer.start != end) return error.InvalidLiteral;
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
    if (self.depth == 16) return error.TypeBudgetExceeded;
    self.depth += 1;
    defer self.depth -= 1;
    if (self.token.tag != .word) {
        if (self.location) |location| location.expected = "a logical type name";
        return error.InvalidSqlSyntax;
    }
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
    if (std.ascii.eqlIgnoreCase(name_text, "DOUBLE") and try self.takeWord("PRECISION")) name_text = "DOUBLE PRECISION";
    if (std.ascii.eqlIgnoreCase(name_text, "CHARACTER") and try self.takeWord("VARYING")) name_text = "CHARACTER VARYING";
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
    if (self.depth == 16) return error.ValueBudgetExceeded;
    self.depth += 1;
    defer self.depth -= 1;
    if (try self.takeWord("NULL")) return .null;
    if (try self.takeWord("MISSING")) return .missing;
    switch (expected) {
        .structure, .list, .array => {
            try self.requireWord(switch (expected) {
                .structure => "STRUCT",
                .list => "LIST",
                else => "ARRAY",
            });
            try self.require(.left);
            var cells: std.ArrayList(Cell) = .empty;
            if (self.token.tag != .right) while (true) {
                if (cells.items.len == 65536) return error.ValueBudgetExceeded;
                const child = switch (expected) {
                    .structure => |fields| if (cells.items.len < fields.len) fields[cells.items.len].type else return error.InvalidRowWidth,
                    .list => |element| element.type.*,
                    .array => |array| array.element.type.*,
                    else => unreachable,
                };
                try cells.append(self.allocator, try self.value(child));
                if (!try self.take(.comma)) break;
            };
            try self.require(.right);
            const owned = try cells.toOwnedSlice(self.allocator);
            return .{ .value = switch (expected) {
                .structure => .{ .structure = owned },
                .list => .{ .list = owned },
                else => .{ .array = owned },
            } };
        },
        .map => |map| {
            try self.requireWord("MAP");
            try self.require(.left);
            var entries: std.ArrayList(t.Values.Entry) = .empty;
            if (self.token.tag != .right) while (true) {
                if (entries.items.len == 65536) return error.ValueBudgetExceeded;
                const key = try self.value(map.key.*);
                if (key != .value or key.value != .atom) return error.InvalidMapKey;
                try self.require(.comma);
                const cell = try self.value(map.value.type.*);
                var position = entries.items.len;
                for (entries.items, 0..) |entry, i| switch (try t.Values.atomOrder(key.value.atom, entry.key, map.key.*)) {
                    .eq => return error.DuplicateMapKey,
                    .lt => {
                        position = i;
                        break;
                    },
                    .gt => {},
                };
                try entries.insert(self.allocator, position, .{ .key = key.value.atom, .value = cell });
                if (!try self.take(.comma)) break;
            };
            try self.require(.right);
            // SQL constructor order is immaterial; persist canonical unique keys.
            return .{ .value = .{ .map = try entries.toOwnedSlice(self.allocator) } };
        },
        .tagged_union => |fields| {
            try self.requireWord("UNION");
            try self.require(.left);
            const selected = try self.name();
            var index: ?usize = null;
            for (fields, 0..) |field, i| if (std.mem.eql(u8, selected, field.name)) {
                index = i;
                break;
            };
            const i = index orelse return error.UnknownUnionAlternative;
            try self.require(.comma);
            const cell = try self.allocator.create(Cell);
            cell.* = try self.value(fields[i].type);
            try self.require(.right);
            return .{ .value = .{ .tagged_union = .{ .index = @intCast(i), .value = cell } } };
        },
        .interval => {
            try self.requireWord("INTERVAL");
            try self.require(.left);
            const months = try t.Semantics.bind(try self.number(), .int32);
            try self.require(.comma);
            const days = try t.Semantics.bind(try self.number(), .int32);
            try self.require(.comma);
            const nanos = try t.Semantics.bind(try self.number(), .int64);
            try self.require(.right);
            return .{ .value = .{ .atom = .{ .interval = .{ .months = @intCast(months.signed), .days = @intCast(days.signed), .nanos = @intCast(nanos.signed) } } } };
        },
        .json => {
            _ = try self.takeWord("JSON");
            return .{ .value = .{ .json = try self.unquote(.string) } };
        },
        .binary => {
            if (!try self.takeWord("X")) return error.InvalidBinaryLiteral;
            const encoded = try self.unquote(.string);
            if (encoded.len % 2 != 0) return error.InvalidBinaryLiteral;
            const bytes = try self.allocator.alloc(u8, encoded.len / 2);
            return .{ .value = .{ .atom = .{ .bytes = std.fmt.hexToBytes(bytes, encoded) catch return error.InvalidBinaryLiteral } } };
        },
        .utf8 => return .{ .value = .{ .atom = .{ .bytes = try self.unquote(.string) } } },
        .boolean => {
            const boolean = if (try self.takeWord("TRUE")) true else if (try self.takeWord("FALSE")) false else return error.InvalidLiteral;
            return .{ .value = .{ .atom = .{ .boolean = boolean } } };
        },
        .date, .time, .timestamp, .uuid => {
            _ = try self.takeWord(switch (expected) {
                .date => "DATE",
                .time => "TIME",
                .timestamp => "TIMESTAMP",
                else => "UUID",
            });
            return .{ .value = .{ .atom = try t.Semantics.bind(try self.unquote(.string), expected) } };
        },
        else => return .{ .value = .{ .atom = try t.Semantics.bind(try self.number(), expected) } },
    }
}
