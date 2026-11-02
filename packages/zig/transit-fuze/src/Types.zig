//! Logical descriptors, independent of physical execution/transport layouts.
//! All slices borrow their owner. Decode and clone return an explicit arena owner.
const std = @import("std");
pub const Diagnostic = @import("TypeDiagnostic.zig");
pub const Query = @import("Scalar.zig");
pub const State = Query.State;
pub const definition = "transit.fuze.types.v1.2026-11-01.companions";
pub const Ranges = @import("RangeValue.zig");
pub const Vectors = @import("VectorValue.zig");
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
    range,
    multirange,
    vector,
};
/// Observed source kinds are evidence, not admissible logical descriptors.
/// Logical kinds retain Tag's IDs; the extra cases preserve decoder/Document
/// distinctions without inventing a scalar type or losing an unknown cause.
pub const Kind = enum(u8) {
    unknown = 0,
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
    range,
    multirange,
    vector,
    null_value,
    text,
    character,
    pub fn fromTag(tag: Tag) Kind {
        return @fromBackingInt(@backingInt(tag));
    }
    pub fn fromQuery(kind: Query.Kind) Kind {
        return switch (kind) {
            inline else => |value| @field(Kind, @tagName(value)),
        };
    }
};
comptime {
    for (@typeInfo(Tag).@"enum".field_names, @typeInfo(Tag).@"enum".field_values) |name, value| {
        if (@backingInt(@field(Kind, name)) != value) @compileError("Logical source kinds must preserve descriptor tag IDs");
    }
}
pub const Decimal = struct { precision: u8, scale: u8 };
pub const Timestamp = enum(u8) { civil, utc };
pub const Element = struct { type: *const Type, nullable: bool = false };
pub const Array = struct { element: Element, length: u32 };
pub const Map = struct { key: *const Type, value: Element };
pub const Field = struct { name: []const u8, type: Type, nullable: bool = false, optional: bool = false };
pub const Type = union(Tag) {
    pub const json_schema_sequence_bounds = .{ .structure = 256, .tagged_union = 256 };
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
    range: *const Type,
    multirange: *const Type,
    vector: Vectors.Descriptor,

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
        try self.validateDiagnostic(limits, null);
    }
    pub fn validateDiagnostic(self: Type, limits: Limits, failure: ?*?Diagnostic) !void {
        var budget: Budget = .{ .limits = limits, .failure = failure };
        try validateType(self, 0, &budget, (Diagnostic.Path{}).field("type"));
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
    /// Validate and own every descriptor child/name without a wire round trip.
    /// The canonical encoder still checks the independent encoded-byte bound.
    pub fn clone(self: Type, allocator: std.mem.Allocator) !Decoded {
        var arena: std.heap.ArenaAllocator = .init(allocator);
        errdefer arena.deinit();
        const value = try self.cloneInto(arena.allocator());
        return .{ .arena = arena, .type = value };
    }
    /// Compose within an existing request arena. The caller owns every success
    /// and partial-failure allocation; no independent owner is returned.
    pub fn cloneInto(self: Type, arena: std.mem.Allocator) !Type {
        try self.validate(.{});
        var buffer: [256]u8 = undefined;
        var encoded: std.Io.Writer.Discarding = .init(&buffer);
        try writeType(self, &encoded.writer);
        if (encoded.fullCount() > max_encoding_bytes - 5 - definition.len) return error.WriteFailed;
        return cloneType(arena, self);
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
    failure: ?*?Diagnostic = null,
    path: Diagnostic.Path = .{},
    nodes: usize = 0,
    names: usize = 0,
    bytes: usize = 0,
    children: usize = 0,
    fn reject(self: *Budget, kind: Diagnostic.Kind, actual: ?usize, limit: ?usize, bytes: []const u8, earlier: ?usize, err: anyerror) anyerror {
        if (self.failure) |failure| if (failure.* == null) {
            var detail: Diagnostic = .{ .path = self.path, .kind = kind, .actual = actual, .limit = limit, .earlier = earlier };
            detail.capture(bytes);
            failure.* = detail;
        };
        return err;
    }
    fn node(self: *Budget, depth: usize) !void {
        if (depth >= self.limits.depth) return self.reject(.depth, depth +| 1, self.limits.depth, "", null, error.TypeBudgetExceeded);
        if (self.nodes >= self.limits.nodes) return self.reject(.nodes, self.nodes +| 1, self.limits.nodes, "", null, error.TypeBudgetExceeded);
        self.nodes += 1;
    }
    fn name(self: *Budget, bytes: []const u8) !void {
        if (bytes.len == 0) return self.reject(.name_empty, 0, null, bytes, null, error.InvalidFieldName);
        if (bytes.len > 255) return self.reject(.name_length, bytes.len, 255, bytes, null, error.InvalidFieldName);
        if (!std.unicode.utf8ValidateSlice(bytes)) return self.reject(.name_utf8, null, null, bytes, null, error.InvalidFieldName);
        if (std.mem.indexOfScalar(u8, bytes, 0) != null) return self.reject(.name_nul, null, null, bytes, null, error.InvalidFieldName);
        if (bytes.len > self.limits.name_bytes -| self.names) return self.reject(.name_bytes, self.names +| bytes.len, self.limits.name_bytes, bytes, null, error.TypeBudgetExceeded);
        self.names += bytes.len;
    }
};
fn validateType(value: Type, depth: usize, budget: *Budget, path: Diagnostic.Path) anyerror!void {
    budget.path = path;
    try budget.node(depth);
    switch (value) {
        .decimal => |d| {
            var buffer: [32]u8 = undefined;
            const supplied = std.fmt.bufPrint(&buffer, "decimal({d},{d})", .{ d.precision, d.scale }) catch unreachable;
            if (d.precision == 0 or d.precision > 38) {
                budget.path = path.field("decimal").field("precision");
                return budget.reject(.precision, d.precision, 38, supplied, null, error.InvalidDecimal);
            }
            if (d.scale > d.precision) {
                budget.path = path.field("decimal").field("scale");
                return budget.reject(.scale, d.scale, d.precision, supplied, null, error.InvalidDecimal);
            }
        },
        .structure, .tagged_union => |fields| {
            const members = path.field(@tagName(value));
            budget.path = members;
            if (fields.len == 0 or fields.len > 255) return budget.reject(.field_count, fields.len, 255, "", null, error.InvalidFieldCount);
            for (fields, 0..) |field, i| {
                const member = members.index(i);
                budget.path = member.field("name");
                try budget.name(field.name);
                for (fields[0..i], 0..) |earlier, index| if (std.mem.eql(u8, field.name, earlier.name)) return budget.reject(.duplicate_name, i, null, field.name, index, error.DuplicateField);
                if (value == .tagged_union and field.optional) {
                    budget.path = member.field("optional");
                    return budget.reject(.optional_variant, null, null, "true", null, error.InvalidUnion);
                }
                try validateType(field.type, depth + 1, budget, member.field("type"));
            }
        },
        .list => |element| try validateType(element.type.*, depth + 1, budget, path.field("list").field("type")),
        .array => |array| {
            budget.path = path.field("array").field("length");
            if (array.length == 0) return budget.reject(.array_length, 0, null, "", null, error.InvalidArrayLength);
            try validateType(array.element.type.*, depth + 1, budget, path.field("array").field("element").field("type"));
        },
        .map => |map| {
            budget.path = path.field("map").field("key");
            if (!isMapKey(map.key.*)) return budget.reject(.map_key, null, null, @tagName(map.key.*), null, error.InvalidMapKey);
            try validateType(map.key.*, depth + 1, budget, path.field("map").field("key"));
            try validateType(map.value.type.*, depth + 1, budget, path.field("map").field("value").field("type"));
        },
        .range, .multirange => |subtype| {
            try Ranges.validateSubtype(subtype.*);
            try validateType(subtype.*, depth + 1, budget, path.field(@tagName(value)));
        },
        .vector => |vector| try vector.validate(),
        else => {},
    }
}

pub fn isMapKey(value: Type) bool {
    return switch (value) {
        .structure, .list, .array, .map, .tagged_union, .json, .interval, .range, .multirange, .vector => false,
        else => true,
    };
}
fn writeType(value: Type, writer: *std.Io.Writer) anyerror!void {
    try writer.writeByte(@backingInt(value.tag()));
    switch (value) {
        .decimal => |d| try writer.writeAll(&.{ d.precision, d.scale }),
        .timestamp => |zone| try writer.writeByte(@backingInt(zone)),
        .range, .multirange => |subtype| try writeType(subtype.*, writer),
        .vector => |vector| {
            try writer.writeInt(u32, vector.dimensions, .little);
            try writer.writeByte(@backingInt(vector.element));
        },
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
fn cloneType(allocator: std.mem.Allocator, value: Type) anyerror!Type {
    return switch (value) {
        .range, .multirange => |subtype| blk: {
            const child = try allocator.create(Type);
            child.* = try cloneType(allocator, subtype.*);
            break :blk if (value == .range) .{ .range = child } else .{ .multirange = child };
        },
        .structure, .tagged_union => |fields| blk: {
            const owned = try allocator.alloc(Field, fields.len);
            for (fields, owned) |field, *copy| copy.* = .{
                .name = try allocator.dupe(u8, field.name),
                .type = try cloneType(allocator, field.type),
                .nullable = field.nullable,
                .optional = field.optional,
            };
            break :blk if (value == .structure) .{ .structure = owned } else .{ .tagged_union = owned };
        },
        .list => |element| .{ .list = try cloneElement(allocator, element) },
        .array => |array| .{ .array = .{ .length = array.length, .element = try cloneElement(allocator, array.element) } },
        .map => |map| blk: {
            const key = try allocator.create(Type);
            key.* = try cloneType(allocator, map.key.*);
            break :blk .{ .map = .{ .key = key, .value = try cloneElement(allocator, map.value) } };
        },
        else => value,
    };
}
fn cloneElement(allocator: std.mem.Allocator, element: Element) !Element {
    const child = try allocator.create(Type);
    child.* = try cloneType(allocator, element.type.*);
    return .{ .type = child, .nullable = element.nullable };
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Decoded {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const value = try decodeInto(arena.allocator(), bytes);
    return .{ .arena = arena, .type = value };
}
/// Validate the same canonical descriptor into a caller-owned request arena.
/// The arena owns every returned slice and any allocation preceding a failure.
pub fn decodeInto(arena: std.mem.Allocator, bytes: []const u8) !Type {
    if (bytes.len > max_encoding_bytes) return error.TypeBudgetExceeded;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FTY1")) return error.InvalidTypeEncoding;
    if (!std.mem.eql(u8, try reader.take(try reader.takeByte()), definition)) return error.IncompatibleDefinition;
    var budget: Budget = .{ .limits = .{} };
    const value = try readType(arena, &reader, 0, &budget);
    if (reader.bufferedLen() != 0) return error.InvalidTypeEncoding;
    try value.validate(.{});
    return value;
}

fn readType(allocator: std.mem.Allocator, reader: *std.Io.Reader, depth: usize, budget: *Budget) anyerror!Type {
    try budget.node(depth);
    const kind = std.enums.fromInt(Tag, try reader.takeByte()) orelse return error.InvalidTypeEncoding;
    return switch (kind) {
        .decimal => .{ .decimal = .{ .precision = try reader.takeByte(), .scale = try reader.takeByte() } },
        .timestamp => .{ .timestamp = std.enums.fromInt(Timestamp, try reader.takeByte()) orelse return error.InvalidTypeEncoding },
        .range, .multirange => blk: {
            const child = try allocator.create(Type);
            child.* = try readType(allocator, reader, depth + 1, budget);
            break :blk if (kind == .range) .{ .range = child } else .{ .multirange = child };
        },
        .vector => .{ .vector = .{ .dimensions = try reader.takeInt(u32, .little), .element = std.enums.fromInt(@import("VectorMetric.zig").ElementType, try reader.takeByte()) orelse return error.InvalidTypeEncoding } },
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
    _ = @import("companion_values_test.zig");
}
