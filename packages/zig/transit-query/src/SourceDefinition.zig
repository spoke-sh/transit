//! Owned identities and borrowed declaration arrays. Canonical UQS1 binds every
//! decoder and projection; source definitions never grant access or execution.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const m = q.fuze.Unified;
const d = q.document.Model;
const Self = @This();
pub const max_bytes = 8192;
version: u8 = 1,
resource: u64,
source: union(m.SourceKind) {
    kv: struct { prefix: p.Value, key: Decoder, value: Decoder },
    table: struct { id: u32, schema: q.fuze.model.Schema },
    document: struct {
        reference: q.document.Client.Reference,
        change_format: u32 = 1,
        expand: ?[]const d.Name = null,
        projections: []const Projection,
    },
},
pub const Decoder = struct {
    version: u8 = 1,
    type: m.Type,
    pub fn validate(self: Decoder) !void {
        if (self.version != 1) return error.UnsupportedDecoder;
    }
};
pub const Projection = struct {
    column: m.Column,
    path: []const d.Name,
    relative: bool = false,
    mode: enum(u8) { scalar = 0, text = 1, element_counter = 2, element_replica = 3 } = .scalar,
    text_bytes: u16 = m.max_cell_bytes,
    text_steps: u16 = 4096,
};
fn validatePath(path: []const d.Name, empty: bool) !void {
    if ((!empty and path.len == 0) or path.len > 8) return error.InvalidQueryPath;
    for (path) |name| {
        try name.validate(true);
        if (!std.unicode.utf8ValidateSlice(name.slice())) return error.InvalidQueryPath;
    }
}
pub fn schema(self: Self, output: *[m.max_columns]m.Column) !m.Schema {
    if (self.version != 1) return error.UnsupportedSource;
    if (self.resource == 0 or self.resource > p.max_counter) return error.InvalidQuerySource;
    const count: usize = switch (self.source) {
        .kv => |kv| blk: {
            try kv.prefix.validate();
            if (kv.prefix.len > p.Growth.key_bytes) return error.InvalidQueryPrefix;
            try kv.key.validate();
            try kv.value.validate();
            output[0] = .{ .name = try m.Name.init("key"), .type = kv.key.type };
            output[1] = .{ .name = try m.Name.init("value"), .type = kv.value.type };
            break :blk 2;
        },
        .table => |table| blk: {
            if (table.id == 0) return error.InvalidTableId;
            try table.schema.validate();
            output[0] = .{ .name = try m.Name.init(table.schema.names[0].slice()), .type = .int64 };
            output[1] = .{ .name = try m.Name.init(table.schema.names[1].slice()), .type = switch (table.schema.value_type) {
                .int64 => .int64,
                .boolean => .boolean,
                .utf8 => .utf8,
                .binary => .binary,
            } };
            break :blk 2;
        },
        .document => |document| blk: {
            _ = try document.reference.encode();
            if (document.reference.resource != self.resource or document.change_format != 1) return error.UnsupportedDocumentSource;
            if (document.expand) |path| try validatePath(path, false);
            if (document.projections.len == 0 or document.projections.len > m.max_columns) return error.InvalidProjection;
            for (document.projections, 0..) |projection, index| {
                if (projection.relative and document.expand == null) return error.InvalidQueryPath;
                try validatePath(projection.path, projection.relative);
                if (projection.text_bytes == 0 or projection.text_bytes > m.max_cell_bytes or projection.text_steps == 0 or projection.text_steps > 16384) return error.InvalidProjectionBudget;
                switch (projection.mode) {
                    .scalar => {},
                    .text => if (projection.column.type != .utf8) return error.InvalidTextProjection,
                    .element_counter, .element_replica => if (!projection.relative or projection.path.len != 0 or projection.column.type != .uint64) return error.InvalidElementProjection,
                }
                output[index] = projection.column;
            }
            break :blk document.projections.len;
        },
    };
    const result: m.Schema = .{ .columns = output[0..count] };
    try result.validate();
    return result;
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    var columns: [m.max_columns]m.Column = undefined;
    _ = try self.schema(&columns);
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll("UQS1");
    try writer.writeInt(u64, self.resource, .little);
    try writer.writeByte(@backingInt(std.meta.activeTag(self.source)));
    switch (self.source) {
        .kv => |kv| {
            try writer.writeByte(@intCast(kv.prefix.len));
            try writer.writeAll(kv.prefix.slice());
            try writer.writeAll(&.{ kv.key.version, @backingInt(kv.key.type), kv.value.version, @backingInt(kv.value.type) });
        },
        .table => |table| {
            try writer.writeInt(u32, table.id, .little);
            const encoded = try q.station.Table.encodeSchema(table.schema);
            try writer.writeByte(@intCast(encoded.len));
            try writer.writeAll(encoded.slice());
        },
        .document => |document| {
            try writer.writeAll((try document.reference.encode()).slice());
            try writer.writeInt(u32, document.change_format, .little);
            try writer.writeByte(@intFromBool(document.expand != null));
            if (document.expand) |path| try writePath(&writer, path);
            try writer.writeByte(@intCast(document.projections.len));
            for (document.projections) |projection| {
                try writer.writeByte(projection.column.name.len);
                try writer.writeAll(projection.column.name.slice());
                try writer.writeAll(&.{ @backingInt(projection.column.type), @intFromBool(projection.relative), @backingInt(projection.mode) });
                try writer.writeInt(u16, projection.text_bytes, .little);
                try writer.writeInt(u16, projection.text_steps, .little);
                try writePath(&writer, projection.path);
            }
        },
    }
    if (writer.end > max_bytes) return error.SourceDefinitionTooLarge;
    return writer.buffered();
}
fn writePath(writer: *std.Io.Writer, path: []const d.Name) !void {
    try writer.writeByte(@intCast(path.len));
    for (path) |name| {
        try writer.writeByte(@intCast(name.len));
        try writer.writeAll(name.slice());
    }
}
pub fn fingerprint(self: Self) ![32]u8 {
    var bytes: [max_bytes]u8 = undefined;
    const encoded = try self.encode(&bytes);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.source.v1\x00");
    hash.update(encoded);
    return hash.finalResult();
}
/// Every decoded slice belongs to allocator; use a bounded request arena.
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.SourceDefinitionTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "UQS1")) return error.InvalidSourceEncoding;
    var result: Self = .{ .resource = try reader.takeInt(u64, .little), .source = undefined };
    result.source = switch (try reader.takeByte()) {
        1 => .{ .kv = .{
            .prefix = try p.Value.init(try reader.take(try reader.takeByte())),
            .key = .{ .version = try reader.takeByte(), .type = std.enums.fromInt(m.Type, try reader.takeByte()) orelse return error.UnsupportedDecoder },
            .value = .{ .version = try reader.takeByte(), .type = std.enums.fromInt(m.Type, try reader.takeByte()) orelse return error.UnsupportedDecoder },
        } },
        2 => .{ .table = .{ .id = try reader.takeInt(u32, .little), .schema = try q.station.Table.decodeSchema(try p.Value.init(try reader.take(try reader.takeByte()))) } },
        3 => blk: {
            const reference = try q.document.Client.Reference.decode(try p.Value.init(try reader.take(40)));
            const format = try reader.takeInt(u32, .little);
            const expand: ?[]const d.Name = switch (try reader.takeByte()) {
                0 => null,
                1 => try readPath(allocator, &reader),
                else => return error.InvalidSourceEncoding,
            };
            const count = try reader.takeByte();
            if (count > m.max_columns) return error.InvalidProjection;
            const projections = try allocator.alloc(Projection, count);
            for (projections) |*projection| {
                const name = try m.Name.init(try reader.take(try reader.takeByte()));
                const data_type = std.enums.fromInt(m.Type, try reader.takeByte()) orelse return error.UnsupportedDecoder;
                const relative = try reader.takeByte();
                if (relative > 1) return error.InvalidSourceEncoding;
                const mode = std.enums.fromInt(@FieldType(Projection, "mode"), try reader.takeByte()) orelse return error.InvalidSourceEncoding;
                const text_bytes = try reader.takeInt(u16, .little);
                const text_steps = try reader.takeInt(u16, .little);
                projection.* = .{ .column = .{ .name = name, .type = data_type }, .relative = relative == 1, .mode = mode, .text_bytes = text_bytes, .text_steps = text_steps, .path = try readPath(allocator, &reader) };
            }
            break :blk .{ .document = .{ .reference = reference, .change_format = format, .expand = expand, .projections = projections } };
        },
        else => return error.UnsupportedSource,
    };
    var canonical: [max_bytes]u8 = undefined;
    if (reader.bufferedLen() != 0 or !std.mem.eql(u8, try result.encode(&canonical), bytes)) return error.InvalidSourceEncoding;
    return result;
}
fn readPath(allocator: std.mem.Allocator, reader: *std.Io.Reader) ![]const d.Name {
    const count = try reader.takeByte();
    if (count > 8) return error.InvalidQueryPath;
    const names = try allocator.alloc(d.Name, count);
    for (names) |*name| name.* = try d.Name.init(try reader.take(try reader.takeByte()));
    return names;
}
