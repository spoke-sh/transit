//! Logical descriptors, independent of physical execution/transport layouts.
//! All slices borrow their owner. Decode returns an arena owner explicitly.
const std = @import("std");
pub const Query = @import("Scalar.zig");
pub const State = Query.State;
pub const definition = "transit.fuze.types.v1.2026-09-30";
pub const max_encoding_bytes = 16384;
pub const Limits = struct {
    depth: usize = 16,
    nodes: usize = 256,
    name_bytes: usize = 4096,
    value_bytes: usize = 1024 * 1024,
    children: usize = 65536,
};
pub const Tag = enum(u8) {
    int64 = 1,
    uint64,
    float64,
    boolean,
    utf8,
    binary,
    int8,
    int16,
    int32,
    int128,
    uint8,
    uint16,
    uint32,
    uint128,
    float32,
    decimal,
    date,
    time,
    timestamp,
    interval,
    uuid,
    structure,
    list,
    array,
    map,
    tagged_union,
    json,
};
pub const Decimal = struct { precision: u8, scale: u8 };
pub const Timestamp = enum(u8) { civil, utc };
pub const Element = struct { type: *const Type, nullable: bool = false };
pub const Array = struct { element: Element, length: u32 };
pub const Map = struct { key: *const Type, value: Element };
pub const Field = struct { name: []const u8, type: Type, nullable: bool = false, optional: bool = false };
pub const Type = union(Tag) {
    int64,
    uint64,
    float64,
    boolean,
    utf8,
    binary,
    int8,
    int16,
    int32,
    int128,
    uint8,
    uint16,
    uint32,
    uint128,
    float32,
    decimal: Decimal,
    date,
    time,
    timestamp: Timestamp,
    interval,
    uuid,
    structure: []const Field,
    list: Element,
    array: Array,
    map: Map,
    tagged_union: []const Field,
    json,

    pub fn tag(self: Type) Tag {
        return std.meta.activeTag(self);
    }
    pub fn fromQuery(value: Query.Type) Type {
        return switch (value) {
            .int64 => .int64,
            .uint64 => .uint64,
            .float64 => .float64,
            .boolean => .boolean,
            .utf8 => .utf8,
            .binary => .binary,
        };
    }
    pub fn queryType(self: Type) !Query.Type {
        return switch (self) {
            .int64 => .int64,
            .uint64 => .uint64,
            .float64 => .float64,
            .boolean => .boolean,
            .utf8 => .utf8,
            .binary => .binary,
            else => error.UnsupportedQueryType,
        };
    }
    pub fn validate(self: Type, limits: Limits) !void {
        var budget: Budget = .{ .limits = limits };
        try validateType(self, 0, &budget);
    }
    pub fn encode(self: Type, output: []u8) ![]const u8 {
        try self.validate(.{});
        var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_encoding_bytes)]);
        try writer.writeAll("FTY1");
        try writer.writeByte(definition.len);
        try writer.writeAll(definition);
        try writeType(self, &writer);
        return writer.buffered();
    }
    pub fn fingerprint(self: Type) ![32]u8 {
        var buffer: [max_encoding_bytes]u8 = undefined;
        const bytes = try self.encode(&buffer);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        return digest;
    }
    pub fn eql(self: Type, other: Type) !bool {
        return std.mem.eql(u8, &try self.fingerprint(), &try other.fingerprint());
    }
};
const Budget = struct {
    limits: Limits,
    nodes: usize = 0,
    names: usize = 0,
    bytes: usize = 0,
    children: usize = 0,
    fn node(self: *Budget, depth: usize) !void {
        if (depth >= self.limits.depth or self.nodes >= self.limits.nodes) return error.TypeBudgetExceeded;
        self.nodes += 1;
    }
    fn name(self: *Budget, bytes: []const u8) !void {
        if (bytes.len == 0 or bytes.len > 255 or !std.unicode.utf8ValidateSlice(bytes) or std.mem.indexOfScalar(u8, bytes, 0) != null) return error.InvalidFieldName;
        if (bytes.len > self.limits.name_bytes -| self.names) return error.TypeBudgetExceeded;
        self.names += bytes.len;
    }
};
fn validateType(value: Type, depth: usize, budget: *Budget) anyerror!void {
    try budget.node(depth);
    switch (value) {
        .decimal => |d| if (d.precision == 0 or d.precision > 38 or d.scale > d.precision) return error.InvalidDecimal,
        .structure, .tagged_union => |fields| {
            if (fields.len == 0 or fields.len > 255) return error.InvalidFieldCount;
            for (fields, 0..) |field, i| {
                try budget.name(field.name);
                for (fields[0..i]) |earlier| if (std.mem.eql(u8, field.name, earlier.name)) return error.DuplicateField;
                if (value == .tagged_union and field.optional) return error.InvalidUnion;
                try validateType(field.type, depth + 1, budget);
            }
        },
        .list => |element| try validateType(element.type.*, depth + 1, budget),
        .array => |array| {
            if (array.length == 0) return error.InvalidArrayLength;
            try validateType(array.element.type.*, depth + 1, budget);
        },
        .map => |map| {
            if (!isMapKey(map.key.*)) return error.InvalidMapKey;
            try validateType(map.key.*, depth + 1, budget);
            try validateType(map.value.type.*, depth + 1, budget);
        },
        else => {},
    }
}
pub fn isMapKey(value: Type) bool {
    return switch (value) {
        .structure, .list, .array, .map, .tagged_union, .json, .interval => false,
        else => true,
    };
}
fn writeType(value: Type, writer: *std.Io.Writer) anyerror!void {
    try writer.writeByte(@backingInt(value.tag()));
    switch (value) {
        .decimal => |d| try writer.writeAll(&.{ d.precision, d.scale }),
        .timestamp => |zone| try writer.writeByte(@backingInt(zone)),
        .structure, .tagged_union => |fields| {
            try writer.writeByte(@intCast(fields.len));
            for (fields) |field| {
                try writer.writeByte(@intCast(field.name.len));
                try writer.writeAll(field.name);
                try writer.writeByte(@intFromBool(field.nullable) | (@as(u8, @intFromBool(field.optional)) << 1));
                try writeType(field.type, writer);
            }
        },
        .list => |element| try writeElement(element, writer),
        .array => |array| {
            try writer.writeInt(u32, array.length, .little);
            try writeElement(array.element, writer);
        },
        .map => |map| {
            try writeType(map.key.*, writer);
            try writeElement(map.value, writer);
        },
        else => {},
    }
}
fn writeElement(element: Element, writer: *std.Io.Writer) !void {
    try writer.writeByte(@intFromBool(element.nullable));
    try writeType(element.type.*, writer);
}
pub const Decoded = struct {
    arena: std.heap.ArenaAllocator,
    type: Type,
    pub fn deinit(self: *Decoded) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Decoded {
    if (bytes.len > max_encoding_bytes) return error.TypeBudgetExceeded;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FTY1")) return error.InvalidTypeEncoding;
    if (!std.mem.eql(u8, try reader.take(try reader.takeByte()), definition)) return error.IncompatibleDefinition;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    var budget: Budget = .{ .limits = .{} };
    const value = try readType(arena.allocator(), &reader, 0, &budget);
    if (reader.bufferedLen() != 0) return error.InvalidTypeEncoding;
    try value.validate(.{});
    return .{ .arena = arena, .type = value };
}
fn readType(allocator: std.mem.Allocator, reader: *std.Io.Reader, depth: usize, budget: *Budget) anyerror!Type {
    try budget.node(depth);
    const kind = std.enums.fromInt(Tag, try reader.takeByte()) orelse return error.InvalidTypeEncoding;
    return switch (kind) {
        .decimal => .{ .decimal = .{ .precision = try reader.takeByte(), .scale = try reader.takeByte() } },
        .timestamp => .{ .timestamp = std.enums.fromInt(Timestamp, try reader.takeByte()) orelse return error.InvalidTypeEncoding },
        .structure, .tagged_union => blk: {
            const count = try reader.takeByte();
            if (count > budget.limits.nodes -| budget.nodes) return error.TypeBudgetExceeded;
            const fields = try allocator.alloc(Field, count);
            for (fields) |*field| {
                const name = try reader.take(try reader.takeByte());
                try budget.name(name);
                const flags = try reader.takeByte();
                if (flags > 3) return error.InvalidTypeEncoding;
                field.* = .{ .name = try allocator.dupe(u8, name), .nullable = flags & 1 != 0, .optional = flags & 2 != 0, .type = try readType(allocator, reader, depth + 1, budget) };
            }
            break :blk if (kind == .structure) .{ .structure = fields } else .{ .tagged_union = fields };
        },
        .list => .{ .list = try readElement(allocator, reader, depth, budget) },
        .array => .{ .array = .{ .length = try reader.takeInt(u32, .little), .element = try readElement(allocator, reader, depth, budget) } },
        .map => blk: {
            const key = try allocator.create(Type);
            key.* = try readType(allocator, reader, depth + 1, budget);
            break :blk .{ .map = .{ .key = key, .value = try readElement(allocator, reader, depth, budget) } };
        },
        inline else => |scalar| @unionInit(Type, @tagName(scalar), {}),
    };
}
fn readElement(allocator: std.mem.Allocator, reader: *std.Io.Reader, depth: usize, budget: *Budget) !Element {
    const nullable = try reader.takeByte();
    if (nullable > 1) return error.InvalidTypeEncoding;
    const child = try allocator.create(Type);
    child.* = try readType(allocator, reader, depth + 1, budget);
    return .{ .type = child, .nullable = nullable == 1 };
}
pub const Codec = @import("ValueCodec.zig");
pub const Values = @import("Values.zig");
pub const Json = @import("BoundedJson.zig");
pub const Semantics = @import("TypeSemantics.zig");
pub const Operations = @import("TypeOps.zig");
test {
    _ = Codec;
    _ = Values;
    _ = Json;
    _ = Operations;
    _ = @import("types_test.zig");
}
