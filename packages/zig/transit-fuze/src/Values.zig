//! Recursive logical values. Physical atoms remain specialized; containers
//! borrow bounded child arrays. No allocation, I/O or authority is implicit.
const std = @import("std");
const types = @import("Types.zig");
const sem = types.Semantics;
pub const Atom = sem.Atom;
pub const Alternative = struct { counter: u64, replica: u64, value: union(enum) { null, type_error: types.Tag, value: Value } };
pub const Cell = union(types.State) {
    missing,
    null,
    type_error: types.Tag,
    value: Value,
    conflict: []const Alternative,
    pub fn validate(self: Cell, field: types.Field, limits: types.Limits) !void {
        try field.type.validate(limits);
        var budget: Budget = .{ .limits = limits };
        try checkCell(self, field.type, field.nullable, field.optional, 0, &budget);
    }
};
pub const Entry = struct { key: Atom, value: Cell };
pub const Tagged = struct { index: u8, value: *const Cell };
pub const Value = union(enum) {
    atom: Atom,
    structure: []const Cell,
    list: []const Cell,
    array: []const Cell,
    map: []const Entry,
    tagged_union: Tagged,
    json: []const u8,
};
const Budget = struct {
    limits: types.Limits,
    bytes: usize = 0,
    children: usize = 0,
    fn child(self: *Budget, depth: usize) !void {
        if (depth >= self.limits.depth or self.children >= self.limits.children) return error.ValueBudgetExceeded;
        self.children += 1;
    }
    fn data(self: *Budget, bytes: usize) !void {
        if (bytes > self.limits.value_bytes -| self.bytes) return error.ValueBudgetExceeded;
        self.bytes += bytes;
    }
};
fn checkCell(cell: Cell, expected: types.Type, nullable: bool, optional: bool, depth: usize, budget: *Budget) anyerror!void {
    try budget.child(depth);
    switch (cell) {
        .missing => if (!optional) return error.MissingRequiredField,
        .null => if (!nullable) return error.NullNotAllowed,
        .type_error => {},
        .value => |value| try checkValue(value, expected, depth, budget),
        .conflict => |alternatives| {
            if (alternatives.len < 2 or alternatives.len > types.Query.max_conflicts) return error.InvalidConflict;
            for (alternatives, 0..) |alternative, i| {
                try budget.child(depth);
                if (alternative.counter == 0 or alternative.replica == 0) return error.InvalidConflict;
                if (i > 0) {
                    const previous = alternatives[i - 1];
                    if (previous.counter > alternative.counter or (previous.counter == alternative.counter and previous.replica >= alternative.replica)) return error.InvalidConflict;
                }
                switch (alternative.value) {
                    .null => if (!nullable) return error.NullNotAllowed,
                    .type_error => {},
                    .value => |value| try checkValue(value, expected, depth, budget),
                }
            }
        },
    }
}
fn checkValue(value: Value, expected: types.Type, depth: usize, budget: *Budget) anyerror!void {
    switch (value) {
        .atom => |atom| {
            try sem.validate(atom, expected);
            if (atom == .bytes) try budget.data(atom.bytes.len);
        },
        .structure => |cells| {
            if (expected != .structure or cells.len != expected.structure.len) return error.TypeMismatch;
            for (cells, expected.structure) |cell, field| try checkCell(cell, field.type, field.nullable, field.optional, depth + 1, budget);
        },
        .list, .array => |cells| {
            const element = if (value == .list and expected == .list) expected.list else if (value == .array and expected == .array) blk: {
                if (cells.len != expected.array.length) return error.InvalidArrayLength;
                break :blk expected.array.element;
            } else return error.TypeMismatch;
            for (cells) |cell| try checkCell(cell, element.type.*, element.nullable, false, depth + 1, budget);
        },
        .map => |entries| {
            if (expected != .map) return error.TypeMismatch;
            for (entries, 0..) |entry, i| {
                try budget.child(depth + 1);
                try sem.validate(entry.key, expected.map.key.*);
                if (entry.key == .bytes) try budget.data(entry.key.bytes.len);
                if (i > 0 and try atomOrder(entries[i - 1].key, entry.key, expected.map.key.*) != .lt) return error.MapKeyOrder;
                try checkCell(entry.value, expected.map.value.type.*, expected.map.value.nullable, false, depth + 1, budget);
            }
        },
        .tagged_union => |tagged| {
            if (expected != .tagged_union or tagged.index >= expected.tagged_union.len) return error.InvalidUnion;
            const field = expected.tagged_union[tagged.index];
            try checkCell(tagged.value.*, field.type, field.nullable, false, depth + 1, budget);
        },
        .json => |bytes| {
            if (expected != .json) return error.TypeMismatch;
            try budget.data(bytes.len);
            try @import("BoundedJson.zig").validate(bytes);
        },
    }
}
pub fn atomOrder(left: Atom, right: Atom, expected: types.Type) !std.math.Order {
    try sem.validate(left, expected);
    try sem.validate(right, expected);
    return switch (left) {
        .signed => |v| std.math.order(v, right.signed),
        .unsigned => |v| std.math.order(v, right.unsigned),
        .float => |v| std.math.order(v, right.float),
        .decimal => |v| std.math.order(v, right.decimal),
        .boolean => |v| std.math.order(@intFromBool(v), @intFromBool(right.boolean)),
        .bytes => |v| std.mem.order(u8, v, right.bytes),
        .date => |v| std.math.order(v, right.date),
        .time => |v| std.math.order(v, right.time),
        .timestamp => |v| std.math.order(v, right.timestamp),
        .uuid => |v| std.mem.order(u8, &v, &right.uuid),
        .interval => error.UnorderedType,
    };
}
pub fn fromQuery(value: types.Query.Cell) !Cell {
    return switch (value) {
        .missing => .missing,
        .null => .null,
        .type_error => error.UnsupportedQueryConversion,
        .conflict => error.UnsupportedQueryConversion,
        .value => |scalar| .{ .value = .{ .atom = switch (scalar) {
            .int64 => |v| .{ .signed = v },
            .uint64 => |v| .{ .unsigned = v },
            .float64 => |v| .{ .float = v },
            .boolean => |v| .{ .boolean = v },
            .utf8, .binary => |v| .{ .bytes = v },
        } } },
    };
}
test "recursive values bound children and preserve nested missing null and error" {
    const t = std.testing;
    const field: types.Field = .{ .name = "row", .type = .{ .structure = &.{
        .{ .name = "id", .type = .uint128 }, .{ .name = "optional", .type = .utf8, .nullable = true, .optional = true },
    } } };
    const cell: Cell = .{ .value = .{ .structure = &.{ .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u128) } } }, .missing } } };
    try cell.validate(field, .{});
    try t.expectError(error.ValueBudgetExceeded, cell.validate(field, .{ .children = 2 }));
    const bad: Cell = .{ .value = .{ .structure = &.{ .null, .missing } } };
    try t.expectError(error.NullNotAllowed, bad.validate(field, .{}));
    const map: types.Field = .{ .name = "map", .type = .{ .map = .{ .key = &.float64, .value = .{ .type = &.utf8 } } } };
    const duplicate: Cell = .{ .value = .{ .map = &.{
        .{ .key = .{ .float = -0.0 }, .value = .{ .value = .{ .atom = .{ .bytes = "a" } } } },
        .{ .key = .{ .float = 0.0 }, .value = .{ .value = .{ .atom = .{ .bytes = "b" } } } },
    } } };
    try t.expectError(error.MapKeyOrder, duplicate.validate(map, .{}));
}
