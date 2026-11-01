//! Lossless neutral JSON for logical descriptors and cells. Exact integers and
//! decimal coefficients use canonical strings; floats carry little-endian bits.
//! Generated language declarations can reflect these wire types separately from
//! native public APIs. Every decode owns its complete recursively validated value.
const std = @import("std");
const types = @import("Types.zig");
const values = types.Values;
pub const max_input_bytes = 256 * 1024;
pub const TypeEnvelope = struct { definition: []const u8, type: types.Type };
pub const Atom = union(enum) {
    signed: []const u8,
    unsigned: []const u8,
    decimal: []const u8,
    float_bits: []const u8,
    boolean: bool,
    utf8: []const u8,
    binary: []const u8,
    date_days: []const u8,
    time_nanos: []const u8,
    timestamp_micros: []const u8,
    interval: struct { months: []const u8, days: []const u8, nanos: []const u8 },
    uuid: []const u8,
};
pub const Cell = union(types.State) {
    pub const json_schema_sequence_bounds = .{ .conflict = 65536 };
    missing,
    null,
    type_error: types.Kind,
    value: Value,
    conflict: []const Alternative,
};
pub const Alternative = struct { counter: []const u8, replica: []const u8, value: union(enum) { null, type_error: types.Kind, value: Value } };
pub const Entry = struct { key: Atom, value: Cell };
pub const Range = struct {
    is_empty: bool,
    lower: ?Bound,
    upper: ?Bound,
    pub const Bound = struct { value: Atom, inclusive: bool };
};
pub const Value = union(enum) {
    pub const json_schema_sequence_bounds = .{ .structure = 65536, .list = 65536, .array = 65536, .map = 65536, .multirange = 65536 };
    atom: Atom,
    structure: []const Cell,
    list: []const Cell,
    array: []const Cell,
    map: []const Entry,
    tagged_union: struct { index: u8, value: *const Cell },
    json: []const u8,
    range: Range,
    multirange: []const Range,
    vector: []const u8,
};
pub const Envelope = struct { definition: []const u8, field: types.Field, cell: Cell };
pub const Decoded = struct {
    arena: std.heap.ArenaAllocator,
    field: types.Field,
    cell: values.Cell,
    pub fn deinit(self: *Decoded) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Decoded {
    try types.Json.preflight(bytes, .{ .bytes = max_input_bytes, .depth = 96, .tokens = 32768, .fields = 256 });
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const wire = try std.json.parseFromSliceLeaky(Envelope, arena.allocator(), bytes, .{ .allocate = .alloc_always, .max_value_len = max_input_bytes });
    if (!std.mem.eql(u8, wire.definition, types.definition)) return error.IncompatibleDefinition;
    const cell = try fromForeign(arena.allocator(), wire.cell, wire.field);
    return .{ .arena = arena, .field = wire.field, .cell = cell };
}
/// Shared admission for neutral values embedded in a larger typed contract.
/// Allocate through the caller's arena; text/JSON borrow the neutral input.
/// Transport byte limits remain separate from logical depth/child/value bounds.
pub fn fromForeign(allocator: std.mem.Allocator, cell: Cell, field: types.Field) !values.Cell {
    try field.type.validate(.{});
    var budget: Budget = .{};
    const result = try nativeCell(allocator, cell, field.type, 0, &budget);
    try result.validate(field, .{});
    return result;
}
/// Schema-bound scalar parameters embedded in another neutral contract.
pub fn atomFromForeign(allocator: std.mem.Allocator, value: Atom, expected: types.Type) !values.Atom {
    try expected.validate(.{});
    var budget: Budget = .{};
    return nativeAtom(allocator, value, expected, &budget);
}
pub fn atomToForeign(allocator: std.mem.Allocator, value: values.Atom, expected: types.Type) !Atom {
    try types.Semantics.validate(value, expected);
    return foreignAtom(allocator, value, expected);
}
test "embedded neutral logical results own text and JSON beyond their decoded source" {
    const Run = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var arena: std.heap.ArenaAllocator = .init(allocator);
            defer arena.deinit();
            const alloc = arena.allocator();
            var text = [_]u8{ 'A', 'd', 'a' };
            var json = [_]u8{ '{', '"', 'a', '"', ':', '1', '}' };
            const schema: types.Type = .{ .structure = &.{ .{ .name = "text", .type = .utf8 }, .{ .name = "data", .type = .json } } };
            const cell: values.Cell = .{ .value = .{ .structure = &.{ .{ .value = .{ .atom = .{ .bytes = &text } } }, .{ .value = .{ .json = &json } } } } };
            const result = try foreignCell(alloc, cell, schema);
            @memset(&text, 0);
            @memset(&json, 0);
            try std.testing.expectEqualStrings("Ada", result.value.structure[0].value.atom.utf8);
            try std.testing.expectEqualStrings("{\"a\":1}", result.value.structure[1].value.json);
            const wide = try atomFromForeign(alloc, .{ .unsigned = "340282366920938463463374607431768211455" }, .uint128);
            try std.testing.expectEqual(std.math.maxInt(u128), wide.unsigned);
            try std.testing.expectEqualStrings("340282366920938463463374607431768211455", (try atomToForeign(alloc, wide, .uint128)).unsigned);
        }
    };
    try Run.run(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{});
}
pub fn decodeType(allocator: std.mem.Allocator, bytes: []const u8) !types.Decoded {
    return decodeTypeDiagnostic(allocator, bytes, null);
}
pub fn decodeTypeDiagnostic(allocator: std.mem.Allocator, bytes: []const u8, diagnostic: ?*?types.Json.BudgetDiagnostic) !types.Decoded {
    return decodeTypeContext(allocator, bytes, diagnostic, null);
}
pub fn decodeTypeContext(allocator: std.mem.Allocator, bytes: []const u8, diagnostic: ?*?types.Json.BudgetDiagnostic, failure: ?*?types.Diagnostic) !types.Decoded {
    return decodeTypeFullContext(allocator, bytes, diagnostic, failure, null);
}
pub fn decodeTypeFullContext(allocator: std.mem.Allocator, bytes: []const u8, diagnostic: ?*?types.Json.BudgetDiagnostic, failure: ?*?types.Diagnostic, lexical: ?*?types.Json.Diagnostic) !types.Decoded {
    try types.Json.preflightContext(bytes, .{ .bytes = 65536, .depth = 64, .tokens = 4096 }, diagnostic, lexical);
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const parsed = try @import("DescriptorJson.zig").parseContext(TypeEnvelope, arena.allocator(), bytes, failure, lexical);
    if (!std.mem.eql(u8, parsed.definition, types.definition)) return error.IncompatibleDefinition;
    try parsed.type.validateDiagnostic(.{}, failure);
    var buffer: [types.max_encoding_bytes]u8 = undefined;
    return types.decode(allocator, try parsed.type.encode(&buffer));
}
pub fn encode(allocator: std.mem.Allocator, cell: values.Cell, field: types.Field) ![]const u8 {
    try cell.validate(field, .{});
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const envelope: Envelope = .{ .definition = types.definition, .field = field, .cell = try foreignCell(arena.allocator(), cell, field.type) };
    const result = try std.json.Stringify.valueAlloc(allocator, envelope, .{});
    errdefer allocator.free(result);
    if (result.len > max_input_bytes) return error.JsonByteBudgetExceeded;
    return result;
}
pub fn encodeType(allocator: std.mem.Allocator, descriptor: types.Type) ![]const u8 {
    try descriptor.validate(.{});
    return std.json.Stringify.valueAlloc(allocator, TypeEnvelope{ .definition = types.definition, .type = descriptor }, .{});
}
fn decimal(allocator: std.mem.Allocator, value: anytype) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, bytes.len * 2);
    const alphabet = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        result[i * 2] = alphabet[byte >> 4];
        result[i * 2 + 1] = alphabet[byte & 15];
    }
    return result;
}
fn unsigned(text: []const u8) !u128 {
    if (text.len == 0 or text.len > 39 or (text.len > 1 and text[0] == '0')) return error.InvalidIntegerEncoding;
    for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidIntegerEncoding;
    return std.fmt.parseInt(u128, text, 10) catch error.InvalidIntegerEncoding;
}
fn signed(text: []const u8) !i128 {
    if (text.len == 0 or std.mem.eql(u8, text, "-0")) return error.InvalidIntegerEncoding;
    _ = try unsigned(if (text[0] == '-') text[1..] else text);
    return std.fmt.parseInt(i128, text, 10) catch error.InvalidIntegerEncoding;
}
const Budget = struct {
    children: usize = 0,
    bytes: usize = 0,
    fn child(self: *Budget, depth: usize) !void {
        if (depth >= 16 or self.children == 65536) return error.ValueBudgetExceeded;
        self.children += 1;
    }
    fn count(self: *Budget, length: usize) !void {
        if (length > 65536 - self.children) return error.ValueBudgetExceeded;
    }
    fn data(self: *Budget, length: usize) !void {
        if (length > 1024 * 1024 - self.bytes) return error.ValueBudgetExceeded;
        self.bytes += length;
    }
};
fn unhex(allocator: std.mem.Allocator, text: []const u8, budget: *Budget) ![]const u8 {
    if (text.len % 2 != 0) return error.InvalidHexEncoding;
    try budget.data(text.len / 2);
    for (text) |byte| if (!(std.ascii.isDigit(byte) or (byte >= 'a' and byte <= 'f'))) return error.InvalidHexEncoding;
    const bytes = try allocator.alloc(u8, text.len / 2);
    return std.fmt.hexToBytes(bytes, text);
}
fn nativeAtom(allocator: std.mem.Allocator, atom: Atom, expected: types.Type, budget: *Budget) !types.Semantics.Atom {
    const value: types.Semantics.Atom = switch (atom) {
        .signed => |text| .{ .signed = try signed(text) },
        .unsigned => |text| .{ .unsigned = try unsigned(text) },
        .decimal => |text| .{ .decimal = try signed(text) },
        .float_bits => |text| blk: {
            if ((expected != .float32 and expected != .float64) or text.len != @as(usize, if (expected == .float32) 8 else 16)) return error.TypeMismatch;
            const bytes = try unhex(allocator, text, budget);
            break :blk .{ .float = if (expected == .float32) @as(f32, @bitCast(std.mem.readInt(u32, bytes[0..4], .little))) else @as(f64, @bitCast(std.mem.readInt(u64, bytes[0..8], .little))) };
        },
        .boolean => |value| .{ .boolean = value },
        .utf8 => |text| blk: {
            if (expected != .utf8) return error.TypeMismatch;
            try budget.data(text.len);
            break :blk .{ .bytes = text };
        },
        .binary => |text| blk: {
            if (expected != .binary) return error.TypeMismatch;
            break :blk .{ .bytes = try unhex(allocator, text, budget) };
        },
        .date_days => |text| .{ .date = std.math.cast(i32, try signed(text)) orelse return error.Overflow },
        .time_nanos => |text| .{ .time = std.math.cast(u64, try unsigned(text)) orelse return error.Overflow },
        .timestamp_micros => |text| .{ .timestamp = std.math.cast(i64, try signed(text)) orelse return error.Overflow },
        .interval => |value| .{ .interval = .{
            .months = std.math.cast(i32, try signed(value.months)) orelse return error.Overflow,
            .days = std.math.cast(i32, try signed(value.days)) orelse return error.Overflow,
            .nanos = std.math.cast(i64, try signed(value.nanos)) orelse return error.Overflow,
        } },
        .uuid => |text| blk: {
            if (text.len != 32) return error.InvalidUuid;
            break :blk .{ .uuid = (try unhex(allocator, text, budget))[0..16].* };
        },
    };
    try types.Semantics.validate(value, expected);
    return value;
}
fn nativeCell(allocator: std.mem.Allocator, cell: Cell, expected: types.Type, depth: usize, budget: *Budget) anyerror!values.Cell {
    try budget.child(depth);
    return switch (cell) {
        .missing => .missing,
        .null => .null,
        .type_error => |tag| .{ .type_error = tag },
        .value => |value| .{ .value = try nativeValue(allocator, value, expected, depth, budget) },
        .conflict => |alternatives| blk: {
            if (alternatives.len < 2 or alternatives.len > 8) return error.InvalidConflict;
            const result = try allocator.alloc(values.Alternative, alternatives.len);
            for (result, alternatives) |*out, item| {
                try budget.child(depth);
                out.* = .{ .counter = std.math.cast(u64, try unsigned(item.counter)) orelse return error.Overflow, .replica = std.math.cast(u64, try unsigned(item.replica)) orelse return error.Overflow, .value = switch (item.value) {
                    .null => .null,
                    .type_error => |tag| .{ .type_error = tag },
                    .value => |value| .{ .value = try nativeValue(allocator, value, expected, depth, budget) },
                } };
            }
            break :blk .{ .conflict = result };
        },
    };
}
fn nativeValue(allocator: std.mem.Allocator, value: Value, expected: types.Type, depth: usize, budget: *Budget) anyerror!values.Value {
    return switch (value) {
        .range => |range| blk: {
            if (expected != .range) return error.TypeMismatch;
            break :blk .{ .range = try nativeRange(allocator, range, expected.range.*, budget) };
        },
        .multirange => |ranges| blk: {
            if (expected != .multirange) return error.TypeMismatch;
            try budget.count(ranges.len);
            const result = try allocator.alloc(types.Ranges.Value, ranges.len);
            for (result, ranges) |*out, range| {
                try budget.child(depth + 1);
                out.* = try nativeRange(allocator, range, expected.multirange.*, budget);
            }
            break :blk .{ .multirange = result };
        },
        .vector => |text| blk: {
            if (expected != .vector) return error.TypeMismatch;
            const size = try expected.vector.byteLen();
            if (text.len != size * 2) return error.VectorDimensionMismatch;
            try budget.data(size);
            for (text) |byte| if (!(std.ascii.isDigit(byte) or (byte >= 'a' and byte <= 'f'))) return error.InvalidHexEncoding;
            const result = try allocator.alignedAlloc(u8, .fromByteUnits(types.Vectors.alignment), size);
            _ = try std.fmt.hexToBytes(result, text);
            break :blk .{ .vector = result };
        },
        .atom => |atom| .{ .atom = try nativeAtom(allocator, atom, expected, budget) },
        .structure => |cells| blk: {
            if (expected != .structure or cells.len != expected.structure.len) return error.TypeMismatch;
            try budget.count(cells.len);
            const result = try allocator.alloc(values.Cell, cells.len);
            for (cells, result, expected.structure) |cell, *out, field| out.* = try nativeCell(allocator, cell, field.type, depth + 1, budget);
            break :blk .{ .structure = result };
        },
        .list, .array => |cells| blk: {
            const child = if (value == .list and expected == .list) expected.list.type else if (value == .array and expected == .array) expected.array.element.type else return error.TypeMismatch;
            if (value == .array and cells.len != expected.array.length) return error.InvalidArrayLength;
            try budget.count(cells.len);
            const result = try allocator.alloc(values.Cell, cells.len);
            for (cells, result) |cell, *out| out.* = try nativeCell(allocator, cell, child.*, depth + 1, budget);
            break :blk if (value == .list) .{ .list = result } else .{ .array = result };
        },
        .map => |entries| blk: {
            if (expected != .map) return error.TypeMismatch;
            try budget.count(entries.len);
            const result = try allocator.alloc(values.Entry, entries.len);
            for (entries, result) |entry, *out| {
                try budget.child(depth + 1);
                out.* = .{ .key = try nativeAtom(allocator, entry.key, expected.map.key.*, budget), .value = try nativeCell(allocator, entry.value, expected.map.value.type.*, depth + 1, budget) };
            }
            break :blk .{ .map = result };
        },
        .tagged_union => |tagged| blk: {
            if (expected != .tagged_union or tagged.index >= expected.tagged_union.len) return error.InvalidUnion;
            const cell = try allocator.create(values.Cell);
            cell.* = try nativeCell(allocator, tagged.value.*, expected.tagged_union[tagged.index].type, depth + 1, budget);
            break :blk .{ .tagged_union = .{ .index = tagged.index, .value = cell } };
        },
        .json => |bytes| blk: {
            if (expected != .json) return error.TypeMismatch;
            try budget.data(bytes.len);
            break :blk .{ .json = bytes };
        },
    };
}
fn nativeRange(allocator: std.mem.Allocator, range: Range, subtype: types.Type, budget: *Budget) !types.Ranges.Value {
    return .{
        .is_empty = range.is_empty,
        .lower = if (range.lower) |bound| .{ .value = try nativeAtom(allocator, bound.value, subtype, budget), .inclusive = bound.inclusive } else null,
        .upper = if (range.upper) |bound| .{ .value = try nativeAtom(allocator, bound.value, subtype, budget), .inclusive = bound.inclusive } else null,
    };
}
fn foreignAtom(allocator: std.mem.Allocator, atom: types.Semantics.Atom, expected: types.Type) !Atom {
    return switch (atom) {
        .signed => |number| .{ .signed = try decimal(allocator, number) },
        .unsigned => |number| .{ .unsigned = try decimal(allocator, number) },
        .decimal => |number| .{ .decimal = try decimal(allocator, number) },
        .float => |number| blk: {
            var bytes: [8]u8 = undefined;
            if (expected == .float32) std.mem.writeInt(u32, bytes[0..4], @bitCast(@as(f32, @floatCast(number))), .little) else std.mem.writeInt(u64, &bytes, @bitCast(number), .little);
            break :blk .{ .float_bits = try hex(allocator, bytes[0..if (expected == .float32) @as(usize, 4) else 8]) };
        },
        .boolean => |boolean| .{ .boolean = boolean },
        .bytes => |bytes| if (expected == .utf8) .{ .utf8 = try allocator.dupe(u8, bytes) } else .{ .binary = try hex(allocator, bytes) },
        .date => |number| .{ .date_days = try decimal(allocator, number) },
        .time => |number| .{ .time_nanos = try decimal(allocator, number) },
        .timestamp => |number| .{ .timestamp_micros = try decimal(allocator, number) },
        .interval => |interval| .{ .interval = .{ .months = try decimal(allocator, interval.months), .days = try decimal(allocator, interval.days), .nanos = try decimal(allocator, interval.nanos) } },
        .uuid => |bytes| .{ .uuid = try hex(allocator, &bytes) },
    };
}
pub fn foreignCell(allocator: std.mem.Allocator, cell: values.Cell, expected: types.Type) anyerror!Cell {
    return switch (cell) {
        .missing => .missing,
        .null => .null,
        .type_error => |tag| .{ .type_error = tag },
        .value => |value| .{ .value = try foreignValue(allocator, value, expected) },
        .conflict => |alternatives| blk: {
            const result = try allocator.alloc(Alternative, alternatives.len);
            for (result, alternatives) |*out, item| out.* = .{ .counter = try decimal(allocator, item.counter), .replica = try decimal(allocator, item.replica), .value = switch (item.value) {
                .null => .null,
                .type_error => |tag| .{ .type_error = tag },
                .value => |value| .{ .value = try foreignValue(allocator, value, expected) },
            } };
            break :blk .{ .conflict = result };
        },
    };
}
fn foreignValue(allocator: std.mem.Allocator, value: values.Value, expected: types.Type) anyerror!Value {
    return switch (value) {
        .range => |range| .{ .range = try foreignRange(allocator, range, expected.range.*) },
        .multirange => |ranges| blk: {
            const result = try allocator.alloc(Range, ranges.len);
            for (result, ranges) |*out, range| out.* = try foreignRange(allocator, range, expected.multirange.*);
            break :blk .{ .multirange = result };
        },
        .vector => |bytes| .{ .vector = try hex(allocator, bytes) },
        .atom => |atom| .{ .atom = try foreignAtom(allocator, atom, expected) },
        .structure => |cells| blk: {
            const result = try allocator.alloc(Cell, cells.len);
            for (cells, result, expected.structure) |cell, *out, field| out.* = try foreignCell(allocator, cell, field.type);
            break :blk .{ .structure = result };
        },
        .list, .array => |cells| blk: {
            const result = try allocator.alloc(Cell, cells.len);
            const child = if (value == .list) expected.list.type else expected.array.element.type;
            for (cells, result) |cell, *out| out.* = try foreignCell(allocator, cell, child.*);
            break :blk if (value == .list) .{ .list = result } else .{ .array = result };
        },
        .map => |entries| blk: {
            const result = try allocator.alloc(Entry, entries.len);
            for (entries, result) |entry, *out| out.* = .{ .key = try foreignAtom(allocator, entry.key, expected.map.key.*), .value = try foreignCell(allocator, entry.value, expected.map.value.type.*) };
            break :blk .{ .map = result };
        },
        .tagged_union => |tagged| blk: {
            const cell = try allocator.create(Cell);
            cell.* = try foreignCell(allocator, tagged.value.*, expected.tagged_union[tagged.index].type);
            break :blk .{ .tagged_union = .{ .index = tagged.index, .value = cell } };
        },
        .json => |bytes| .{ .json = try allocator.dupe(u8, bytes) },
    };
}
fn foreignRange(allocator: std.mem.Allocator, range: types.Ranges.Value, subtype: types.Type) !Range {
    return .{
        .is_empty = range.is_empty,
        .lower = if (range.lower) |bound| .{ .value = try foreignAtom(allocator, bound.value, subtype), .inclusive = bound.inclusive } else null,
        .upper = if (range.upper) |bound| .{ .value = try foreignAtom(allocator, bound.value, subtype), .inclusive = bound.inclusive } else null,
    };
}
test "neutral JSON owns recursive descriptors and never rounds full width numbers" {
    const t = std.testing;
    const field: types.Field = .{ .name = "x", .type = .{ .structure = &.{ .{ .name = "wide", .type = .uint128 }, .{ .name = "values", .type = .{ .list = .{ .type = &.float32, .nullable = true } } } } } };
    const cell: values.Cell = .{ .value = .{ .structure = &.{ .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u128) } } }, .{ .value = .{ .list = &.{ .null, .{ .value = .{ .atom = .{ .float = -0.0 } } } } } } } } };
    const encoded = try encode(t.allocator, cell, field);
    defer t.allocator.free(encoded);
    try t.expect(std.mem.indexOf(u8, encoded, "\"340282366920938463463374607431768211455\"") != null);
    var decoded = try decode(t.allocator, encoded);
    defer decoded.deinit();
    const again = try encode(t.allocator, decoded.cell, decoded.field);
    defer t.allocator.free(again);
    try t.expectEqualStrings(encoded, again);
    try t.checkAllAllocationFailures(t.allocator, struct {
        fn run(allocator: std.mem.Allocator, bytes: []const u8) !void {
            var owner = try decode(allocator, bytes);
            defer owner.deinit();
        }
    }.run, .{encoded});
    const descriptor = try encodeType(t.allocator, field.type);
    defer t.allocator.free(descriptor);
    var owned_type = try decodeType(t.allocator, descriptor);
    defer owned_type.deinit();
    try t.expect(try field.type.eql(owned_type.type));
}
test "neutral JSON rejects missing definitions noncanonical numbers and mismatched types" {
    const t = std.testing;
    try t.expectError(error.MissingField, decodeType(t.allocator, "{\"type\":{\"int64\":{}}}"));
    try t.expectError(error.IncompatibleDefinition, decodeType(t.allocator, "{\"definition\":\"foreign\",\"type\":{\"int64\":{}}}"));
    try t.expectError(error.InvalidIntegerEncoding, unsigned("001"));
    try t.expectError(error.InvalidIntegerEncoding, signed("-0"));
    try t.expectError(error.InvalidIntegerEncoding, signed("+1"));
}

fn compareDescriptorJson(bytes: []const u8) !void {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var failure: ?types.Diagnostic = null;
    const instrumented = @import("DescriptorJson.zig").parse(TypeEnvelope, arena.allocator(), bytes, &failure);
    if (std.json.parseFromSlice(TypeEnvelope, t.allocator, bytes, .{ .allocate = .alloc_always })) |reference| {
        defer reference.deinit();
        const actual = try instrumented;
        const original_json = try std.json.Stringify.valueAlloc(t.allocator, reference.value, .{});
        defer t.allocator.free(original_json);
        const actual_json = try std.json.Stringify.valueAlloc(t.allocator, actual, .{});
        defer t.allocator.free(actual_json);
        try t.expectEqualStrings(original_json, actual_json);
        try t.expect(failure == null);
    } else |err| {
        try t.expectError(err, instrumented);
    }
}
test "descriptor attribution preserves standard typed JSON acceptance and first error" {
    for ([_][]const u8{
        "{}",                                                   "[]",                                                                  "null", "{\"definition\":\"foreign\"}",
        "{\"type\":{\"int64\":{}},\"definition\":\"foreign\"}", "{\"definition\":\"a\",\"definition\":\"b\",\"type\":{\"int64\":{}}}",
    }) |bytes| try compareDescriptorJson(bytes);
    for ([_][]const u8{
        "null",                                                          "[]",                                                                        "{}",                                                          "{\"mystery\":{}}",                                                                "{\"int64\":true}",
        "{\"int64\":{},\"uint64\":{}}",                                  "{\"int64\":{},\"int64\":{}}",                                               "{\"decimal\":{\"precision\":256,\"scale\":0}}",               "{\"decimal\":{\"precision\":3}}",                                                 "{\"decimal\":{\"precision\":\"3\",\"scale\":\"0\"}}",
        "{\"decimal\":{\"precision\":3.0,\"scale\":0e0}}",               "{\"decimal\":{\"precision\":3.5,\"scale\":0}}",                             "{\"decimal\":{\"precision\":3,\"precision\":4,\"scale\":0}}", "{\"timestamp\":\"utc\"}",                                                         "{\"timestamp\":\"local\"}",
        "{\"timestamp\":0}",                                             "{\"list\":{}}",                                                             "{\"list\":{\"type\":{\"int64\":{}}}}",                        "{\"array\":{\"element\":{\"type\":{\"utf8\":{}}},\"length\":2}}",                 "{\"map\":{\"key\":{\"utf8\":{}},\"value\":{\"type\":{\"int64\":{}}}}}",
        "{\"tagged_union\":[{\"name\":\"a\",\"type\":{\"int64\":{}}}]}", "{\"structure\":[{\"name\":\"a\",\"type\":{\"int64\":{}},\"nullable\":1}]}", "{\"structure\":[{\"name\":[65],\"type\":{\"int64\":{}}}]}",   "{\"structure\":[{\"name\":\"a\",\"na\\u006de\":\"b\",\"type\":{\"int64\":{}}}]}", "{\"structure\":[{\"name\":\"a\",\"type\":{\"decimal\":{\"precision\":3,\"scale\":0}},\"optional\":true}]}",
    }) |descriptor| {
        const bytes = try std.fmt.allocPrint(std.testing.allocator, "{{\"definition\":\"{s}\",\"type\":{s}}}", .{ types.definition, descriptor });
        defer std.testing.allocator.free(bytes);
        try compareDescriptorJson(bytes);
    }
}
fn descriptorAllocation(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var failure: ?types.Diagnostic = null;
    var owner = decodeTypeContext(allocator, bytes, null, &failure) catch |err| {
        if (err == error.OutOfMemory) try std.testing.expect(failure == null);
        return err;
    };
    defer owner.deinit();
}
test "descriptor diagnostic decode releases all allocations without inventing input rejection on OOM" {
    const descriptor: types.Type = .{ .structure = &.{.{ .name = "α/~", .type = .{ .list = .{ .type = &.{ .decimal = .{ .precision = 5, .scale = 2 } } } }, .optional = true }} };
    const bytes = try encodeType(std.testing.allocator, descriptor);
    defer std.testing.allocator.free(bytes);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, descriptorAllocation, .{bytes});
}
