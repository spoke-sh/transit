//! Fixed catalog records bound to the single current native definition. No
//! fallback decoding, host layout, pointers or resident catalog-sized arrays.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const m = c.fuze.model;
pub fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
pub fn prefix(catalog: u64, tag: u8) p.Value {
    var bytes: [11]u8 = undefined;
    bytes[0..2].* = "\x00C".*;
    std.mem.writeInt(u64, bytes[2..10], catalog, .big);
    bytes[10] = tag;
    return p.Value.init(&bytes) catch unreachable;
}
pub fn key(catalog: u64, tag: u8, id: u64, revision: u64) p.Value {
    var bytes: [27]u8 = undefined;
    bytes[0..11].* = prefix(catalog, tag).data[0..11].*;
    std.mem.writeInt(u64, bytes[11..19], id, .big);
    std.mem.writeInt(u64, bytes[19..27], revision, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn nameKey(catalog: u64, name: m.Name) !p.Value {
    try c.Model.validName(name);
    var bytes: [27]u8 = undefined;
    bytes[0..11].* = prefix(catalog, 'n').data[0..11].*;
    @memcpy(bytes[11..][0..name.len], name.slice());
    return p.Value.init(bytes[0 .. 11 + name.len]);
}
pub fn encode(comptime tag: u8, value: anytype) !p.Value {
    try value.validate();
    var bytes: [p.Value.max_bytes]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    try writer.writeAll("TCA1");
    try writer.writeByte(tag);
    try writer.writeAll(&definition());
    try write(&writer, value);
    return p.Value.init(writer.buffered());
}
pub fn decode(comptime T: type, comptime tag: u8, value: p.Value) !T {
    try value.validate();
    var reader = std.Io.Reader.fixed(value.slice());
    if (!std.mem.eql(u8, try reader.take(4), "TCA1") or try reader.takeByte() != tag) return error.InvalidCatalogRecord;
    if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
    const result = try read(&reader, T);
    if (reader.bufferedLen() != 0) return error.InvalidCatalogRecord;
    try result.validate();
    return result;
}
fn write(out: *std.Io.Writer, value: anytype) anyerror!void {
    const T = @TypeOf(value);
    if (T == m.Name) {
        try c.Model.validName(value);
        try out.writeByte(value.len);
        return out.writeAll(value.slice());
    }
    if (T == m.Schema) {
        const schema = try c.station.Table.encodeSchema(value);
        try out.writeByte(@intCast(schema.len));
        return out.writeAll(schema.slice());
    }
    switch (@typeInfo(T)) {
        .void => {},
        .int => try out.writeInt(T, value, .little),
        .bool => try out.writeByte(@intFromBool(value)),
        .@"enum" => try out.writeByte(@backingInt(value)),
        .array => for (value) |item| try write(out, item),
        .@"struct" => |info| inline for (info.field_names) |name| try write(out, @field(value, name)),
        .@"union" => {
            try out.writeByte(@backingInt(std.meta.activeTag(value)));
            switch (value) {
                inline else => |item| try write(out, item),
            }
        },
        else => @compileError("Catalog records require bounded owned fields"),
    }
}
fn read(input: *std.Io.Reader, comptime T: type) anyerror!T {
    if (T == m.Name) return m.Name.init(try input.take(try input.takeByte()));
    if (T == m.Schema) return c.station.Table.decodeSchema(try p.Value.init(try input.take(try input.takeByte())));
    return switch (@typeInfo(T)) {
        .void => {},
        .int => try input.takeInt(T, .little),
        .bool => switch (try input.takeByte()) {
            0 => false,
            1 => true,
            else => error.InvalidCatalogRecord,
        },
        .@"enum" => std.enums.fromInt(T, try input.takeByte()) orelse error.InvalidCatalogRecord,
        .array => |info| blk: {
            var values: T = undefined;
            for (&values) |*item| item.* = try read(input, info.child);
            break :blk values;
        },
        .@"struct" => |info| blk: {
            var result: T = undefined;
            inline for (info.field_names) |name| @field(result, name) = try read(input, @FieldType(T, name));
            break :blk result;
        },
        .@"union" => |info| blk: {
            const tag = try read(input, info.tag_type.?);
            inline for (info.field_names) |name| if (tag == @field(info.tag_type.?, name)) break :blk @unionInit(T, name, try read(input, @FieldType(T, name)));
            return error.InvalidCatalogRecord;
        },
        else => @compileError("Catalog records require bounded owned fields"),
    };
}
