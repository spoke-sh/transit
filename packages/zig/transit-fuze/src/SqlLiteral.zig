//! Parsed SQL literal syntax, independent of a bound column. Text and children
//! borrow the parser input/arena. Binding allocates cells in the caller arena;
//! byte values continue to borrow the parsed syntax and share its lifetime.
const std = @import("std");
const t = @import("Types.zig");
const Self = @This();
pub const Span = struct { start: usize, end: usize };
span: Span,
value: union(enum) {
    null,
    missing,
    boolean: bool,
    number: []const u8,
    string: []const u8,
    binary: []const u8,
    date: []const u8,
    time: []const u8,
    timestamp: []const u8,
    uuid: []const u8,
    json: []const u8,
    structure: []const Self,
    list: []const Self,
    array: []const Self,
    map: []const Self,
    interval: []const Self,
    tagged_union: struct { name: []const u8, selected: Span, value: *const Self },
},

/// The descriptor and row constraints remain authoritative. Syntax acceptance
/// alone never admits a stored cell, constructor type or column assignment.
pub fn bind(self: Self, allocator: std.mem.Allocator, expected: t.Type, failure: ?*?Span) anyerror!t.Values.Cell {
    if (failure) |at| at.* = null;
    errdefer if (failure) |at| if (at.* == null) {
        at.* = self.span;
    };
    try expected.validate(.{});
    var budget: SyntaxBudget = .{};
    try self.check(0, &budget, failure);
    return self.bindInner(allocator, expected, failure);
}
// Public callers may construct syntax values directly. Bound depth, total
// children and borrowed text before recursive binding allocates any cells.
const SyntaxBudget = struct { nodes: usize = 0, bytes: usize = 0 };
fn check(self: Self, depth: usize, budget: *SyntaxBudget, failure: ?*?Span) anyerror!void {
    errdefer if (failure) |at| if (at.* == null) {
        at.* = self.span;
    };
    const maximum = @import("Sql.zig").max_statement_bytes;
    if (depth == 16 or budget.nodes == maximum) return error.ValueBudgetExceeded;
    budget.nodes += 1;
    if (self.span.start > self.span.end) return error.InvalidSqlSyntax;
    const text: []const u8 = switch (self.value) {
        .number, .string, .binary, .date, .time, .timestamp, .uuid, .json => |raw| raw,
        .tagged_union => |selected| selected.name,
        else => "",
    };
    if (text.len > maximum - budget.bytes) return error.ValueBudgetExceeded;
    budget.bytes += text.len;
    switch (self.value) {
        .structure, .list, .array, .map, .interval => |children| {
            if (children.len > maximum - budget.nodes) return error.ValueBudgetExceeded;
            for (children) |child| try child.check(depth + 1, budget, failure);
        },
        .tagged_union => |selected| try selected.value.check(depth + 1, budget, failure),
        else => {},
    }
}
fn bindInner(self: Self, allocator: std.mem.Allocator, expected: t.Type, failure: ?*?Span) anyerror!t.Values.Cell {
    errdefer if (failure) |at| if (at.* == null) {
        at.* = self.span;
    };
    switch (self.value) {
        .null => return .null,
        .missing => return .missing,
        else => {},
    }
    switch (expected) {
        .structure, .list, .array => {
            const input = switch (expected) {
                .structure => if (self.value == .structure) self.value.structure else return error.InvalidSqlSyntax,
                .list => if (self.value == .list) self.value.list else return error.InvalidSqlSyntax,
                .array => if (self.value == .array) self.value.array else return error.InvalidSqlSyntax,
                else => unreachable,
            };
            if (input.len > 65536) return error.ValueBudgetExceeded;
            if (expected == .structure and input.len > expected.structure.len) return error.InvalidRowWidth;
            const cells = try allocator.alloc(t.Values.Cell, input.len);
            for (input, cells, 0..) |child, *cell, i| {
                const kind = switch (expected) {
                    .structure => expected.structure[i].type,
                    .list => expected.list.type.*,
                    .array => expected.array.element.type.*,
                    else => unreachable,
                };
                cell.* = try child.bindInner(allocator, kind, failure);
            }
            return .{ .value = switch (expected) {
                .structure => .{ .structure = cells },
                .list => .{ .list = cells },
                else => .{ .array = cells },
            } };
        },
        .map => |map| {
            if (self.value != .map) return error.InvalidSqlSyntax;
            const input = self.value.map;
            if (input.len % 2 != 0) return error.InvalidSqlSyntax;
            if (input.len / 2 > 65536) return error.ValueBudgetExceeded;
            var entries: std.ArrayList(t.Values.Entry) = .empty;
            var i: usize = 0;
            while (i < input.len) : (i += 2) {
                const key = try input[i].bindInner(allocator, map.key.*, failure);
                if (key != .value or key.value != .atom) {
                    if (failure) |at| at.* = input[i].span;
                    return error.InvalidMapKey;
                }
                const cell = try input[i + 1].bindInner(allocator, map.value.type.*, failure);
                var position = entries.items.len;
                for (entries.items, 0..) |entry, ordinal| switch (try t.Values.atomOrder(key.value.atom, entry.key, map.key.*)) {
                    .eq => {
                        if (failure) |at| at.* = input[i].span;
                        return error.DuplicateMapKey;
                    },
                    .lt => {
                        position = ordinal;
                        break;
                    },
                    .gt => {},
                };
                try entries.insert(allocator, position, .{ .key = key.value.atom, .value = cell });
            }
            return .{ .value = .{ .map = try entries.toOwnedSlice(allocator) } };
        },
        .tagged_union => |fields| {
            if (self.value != .tagged_union) return error.InvalidSqlSyntax;
            const selected = self.value.tagged_union;
            for (fields, 0..) |field, i| if (std.mem.eql(u8, field.name, selected.name)) {
                const cell = try allocator.create(t.Values.Cell);
                cell.* = try selected.value.bindInner(allocator, field.type, failure);
                return .{ .value = .{ .tagged_union = .{ .index = @intCast(i), .value = cell } } };
            };
            if (failure) |at| at.* = selected.selected;
            return error.UnknownUnionAlternative;
        },
        .interval => {
            if (self.value != .interval or self.value.interval.len != 3) return error.InvalidSqlSyntax;
            const parts = self.value.interval;
            const months = try parts[0].bindInner(allocator, .int32, failure);
            const days = try parts[1].bindInner(allocator, .int32, failure);
            const nanos = try parts[2].bindInner(allocator, .int64, failure);
            for ([_]t.Values.Cell{ months, days, nanos }, parts) |part, source| if (part != .value) {
                if (failure) |at| at.* = source.span;
                return error.InvalidSqlSyntax;
            };
            return .{ .value = .{ .atom = .{ .interval = .{ .months = @intCast(months.value.atom.signed), .days = @intCast(days.value.atom.signed), .nanos = @intCast(nanos.value.atom.signed) } } } };
        },
        .json => {
            const bytes = if (self.value == .json) self.value.json else if (self.value == .string) self.value.string else return error.InvalidSqlSyntax;
            // Validate while this literal still owns the failure span. A later
            // schema/value check must not attribute malformed JSON to the end
            // of the enclosing statement or a neighboring column.
            try t.Json.validate(bytes);
            return .{ .value = .{ .json = bytes } };
        },
        .binary => {
            if (self.value != .binary) return error.InvalidBinaryLiteral;
            const encoded = self.value.binary;
            if (encoded.len % 2 != 0) return error.InvalidBinaryLiteral;
            const bytes = try allocator.alloc(u8, encoded.len / 2);
            return .{ .value = .{ .atom = .{ .bytes = std.fmt.hexToBytes(bytes, encoded) catch return error.InvalidBinaryLiteral } } };
        },
        .utf8 => return .{ .value = .{ .atom = .{ .bytes = if (self.value == .string) self.value.string else return error.InvalidSqlSyntax } } },
        .boolean => return .{ .value = .{ .atom = .{ .boolean = if (self.value == .boolean) self.value.boolean else return error.InvalidLiteral } } },
        .date, .time, .timestamp, .uuid => {
            const raw = if (self.value == .string) self.value.string else switch (expected) {
                .date => if (self.value == .date) self.value.date else return error.InvalidSqlSyntax,
                .time => if (self.value == .time) self.value.time else return error.InvalidSqlSyntax,
                .timestamp => if (self.value == .timestamp) self.value.timestamp else return error.InvalidSqlSyntax,
                .uuid => if (self.value == .uuid) self.value.uuid else return error.InvalidSqlSyntax,
                else => unreachable,
            };
            return .{ .value = .{ .atom = try t.Semantics.bind(raw, expected) } };
        },
        else => return .{ .value = .{ .atom = try t.Semantics.bind(if (self.value == .number) self.value.number else return error.InvalidSqlSyntax, expected) } },
    }
}
