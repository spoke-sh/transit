//! Recursive logical values. Physical atoms remain specialized; containers
//! borrow bounded child arrays. No allocation, I/O or authority is implicit.
const std = @import("std");
const types = @import("Types.zig");
const sem = types.Semantics;
pub const Atom = sem.Atom;
pub const Alternative = struct { counter: u64, replica: u64, value: union(enum) { null, type_error: types.Kind, value: Value } };
pub const Cell = union(types.State) {
    missing,
    null,
    type_error: types.Kind,
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
    range: types.Ranges.Value,
    multirange: []const types.Ranges.Value,
    vector: types.Vectors.Bytes,

    /// Internal catalog intents also persist native values as JSON. The
    /// generic JSON parser cannot allocate an over-aligned byte slice. Keep
    /// its tagged-union representation, copying vector bytes into an owned
    /// aligned slab before the request can be validated or recovered.
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!Value {
        if (try source.next() != .object_begin) return error.UnexpectedToken;
        const token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
        defer if (token == .allocated_string) allocator.free(token.allocated_string);
        const name = switch (token) {
            .string, .allocated_string => |bytes| bytes,
            else => return error.UnexpectedToken,
        };
        const info = @typeInfo(Value).@"union";
        inline for (info.field_names, info.field_types) |field, T| {
            if (std.mem.eql(u8, name, field)) {
                const result: Value = if (comptime std.mem.eql(u8, field, "vector")) blk: {
                    const bytes = try std.json.innerParse([]const u8, allocator, source, options);
                    if (bytes.len > (types.Limits{}).value_bytes) return error.ValueTooLong;
                    const owned = try allocator.alignedAlloc(u8, .fromByteUnits(types.Vectors.alignment), bytes.len);
                    @memcpy(owned, bytes);
                    break :blk .{ .vector = owned };
                } else @unionInit(Value, field, try std.json.innerParse(T, allocator, source, options));
                if (try source.next() != .object_end) return error.UnexpectedToken;
                return result;
            }
        }
        return error.UnknownField;
    }
};

/// Deep-copy an already validated cell into an enclosing owned arena. The
/// caller releases that arena on both success and failure; source validation
/// establishes recursive depth/child bounds before this operation.
pub fn cloneValidated(allocator: std.mem.Allocator, cell: Cell) anyerror!Cell {
    return switch (cell) {
        .value => |value| .{ .value = try cloneValue(allocator, value) },
        .conflict => |alternatives| blk: {
            const owned = try allocator.dupe(Alternative, alternatives);
            for (owned) |*alternative| if (alternative.value == .value) {
                alternative.value.value = try cloneValue(allocator, alternative.value.value);
            };
            break :blk .{ .conflict = owned };
        },
        else => cell,
    };
}
fn cloneValue(a: std.mem.Allocator, value: Value) anyerror!Value {
    return switch (value) {
        .atom => |atom| .{ .atom = try cloneAtom(a, atom) },
        .json => |bytes| .{ .json = try a.dupe(u8, bytes) },
        .range => value,
        .multirange => |ranges| .{ .multirange = try a.dupe(types.Ranges.Value, ranges) },
        .vector => |bytes| blk: {
            const owned = try a.alignedAlloc(u8, .fromByteUnits(types.Vectors.alignment), bytes.len);
            @memcpy(owned, bytes);
            break :blk .{ .vector = owned };
        },
        .structure, .list, .array => |cells, tag| blk: {
            const owned = try a.alloc(Cell, cells.len);
            for (owned, cells) |*out, in| out.* = try cloneValidated(a, in);
            break :blk switch (tag) {
                .structure => .{ .structure = owned },
                .list => .{ .list = owned },
                .array => .{ .array = owned },
                else => unreachable,
            };
        },
        .map => |entries| blk: {
            const owned = try a.alloc(Entry, entries.len);
            for (owned, entries) |*out, in| out.* = .{ .key = try cloneAtom(a, in.key), .value = try cloneValidated(a, in.value) };
            break :blk .{ .map = owned };
        },
        .tagged_union => |tagged| blk: {
            const owned = try a.create(Cell);
            owned.* = try cloneValidated(a, tagged.value.*);
            break :blk .{ .tagged_union = .{ .index = tagged.index, .value = owned } };
        },
    };
}
pub fn cloneAtom(a: std.mem.Allocator, atom: Atom) !Atom {
    return if (atom == .bytes) .{ .bytes = try a.dupe(u8, atom.bytes) } else atom;
}
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
        .range => |range| {
            if (expected != .range) return error.TypeMismatch;
            try types.Ranges.validate(expected.range.*, range);
        },
        .multirange => |ranges| {
            if (expected != .multirange) return error.TypeMismatch;
            for (ranges) |_| try budget.child(depth + 1);
            try types.Ranges.validateMulti(expected.multirange.*, ranges);
        },
        .vector => |bytes| {
            if (expected != .vector) return error.TypeMismatch;
            try budget.data(bytes.len);
            try types.Vectors.validate(expected.vector, bytes);
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
fn queryValue(allocator: std.mem.Allocator, scalar: types.Query.Scalar) !Value {
    return .{ .atom = switch (scalar) {
        .int64 => |v| .{ .signed = v },
        .uint64 => |v| .{ .unsigned = v },
        .float64 => |v| .{ .float = v },
        .boolean => |v| .{ .boolean = v },
        .utf8, .binary => |v| .{ .bytes = try allocator.dupe(u8, v) },
    } };
}
/// Lossless six-scalar source conversion, including every state and observed
/// source kind. All copied bytes/alternatives belong to the supplied arena;
/// release that arena after success or failure. No source authority is implied.
pub fn fromQuery(allocator: std.mem.Allocator, expected: types.Query.Type, value: types.Query.Cell) !Cell {
    try value.validate(expected);
    return switch (value) {
        .missing => .missing,
        .null => .null,
        .type_error => |kind| .{ .type_error = types.Kind.fromQuery(kind) },
        .conflict => |alternatives| blk: {
            const result = try allocator.alloc(Alternative, alternatives.len);
            for (result, alternatives) |*out, in| out.* = .{ .counter = in.counter, .replica = in.replica, .value = switch (in.value) {
                .null => .null,
                .type_error => |kind| .{ .type_error = types.Kind.fromQuery(kind) },
                .value => |scalar| .{ .value = try queryValue(allocator, scalar) },
            } };
            break :blk .{ .conflict = result };
        },
        .value => |scalar| .{ .value = try queryValue(allocator, scalar) },
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
