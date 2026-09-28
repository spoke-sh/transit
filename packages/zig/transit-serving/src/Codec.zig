//! SV1's canonical binary layout: declaration-order fields, LE integers,
//! one-byte enums/bools, fixed arrays, and length-prefixed bounded opaque bytes.
const std = @import("std");
const p = @import("root.zig").protocol;
pub fn encode(comptime tag: u8, value: anytype) !p.Value {
    var bytes: [p.Value.max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try writer.writeAll("SV1");
    try writer.writeByte(tag);
    try write(&writer, value);
    return p.Value.init(writer.buffered());
}
pub fn decode(comptime T: type, comptime tag: u8, value: p.Value) !T {
    try value.validate();
    var reader: std.Io.Reader = .fixed(value.slice());
    if (!std.mem.eql(u8, try reader.take(3), "SV1") or try reader.takeByte() != tag) return error.InvalidServingRecord;
    const result = try read(&reader, T);
    if (reader.bufferedLen() != 0) return error.InvalidServingRecord;
    return result;
}
fn write(writer: *std.Io.Writer, value: anytype) anyerror!void {
    const T = @TypeOf(value);
    if (T == p.Value) {
        try value.validate();
        if (value.len > 64) return error.ServingPayloadTooLarge;
        try writer.writeByte(@intCast(value.len));
        return writer.writeAll(value.slice());
    }
    switch (@typeInfo(T)) {
        .int => try writer.writeInt(T, value, .little),
        .bool => try writer.writeByte(@intFromBool(value)),
        .@"enum" => try writer.writeByte(@backingInt(value)),
        .array => for (value) |item| try write(writer, item),
        .@"struct" => |info| inline for (info.field_names) |name| try write(writer, @field(value, name)),
        .@"union" => {
            try writer.writeByte(@backingInt(std.meta.activeTag(value)));
            switch (value) {
                inline else => |item| try write(writer, item),
            }
        },
        .void => {},
        else => @compileError("Unsupported serving field"),
    }
}
fn read(reader: *std.Io.Reader, comptime T: type) anyerror!T {
    if (T == p.Value) {
        const len = try reader.takeByte();
        if (len > 64) return error.ServingPayloadTooLarge;
        return p.Value.init(try reader.take(len));
    }
    return switch (@typeInfo(T)) {
        .int => try reader.takeInt(T, .little),
        .bool => switch (try reader.takeByte()) {
            0 => false,
            1 => true,
            else => return error.InvalidServingRecord,
        },
        .@"enum" => std.enums.fromInt(T, try reader.takeByte()) orelse return error.InvalidServingRecord,
        .array => |info| blk: {
            var result: T = undefined;
            for (&result) |*item| item.* = try read(reader, info.child);
            break :blk result;
        },
        .@"struct" => |info| blk: {
            var result: T = undefined;
            inline for (info.field_names, info.field_types) |name, F| @field(result, name) = try read(reader, F);
            break :blk result;
        },
        .@"union" => |info| blk: {
            const tag = std.enums.fromInt(std.meta.Tag(T), try reader.takeByte()) orelse return error.InvalidServingRecord;
            inline for (info.field_names, info.field_types) |name, F| if (tag == @field(std.meta.Tag(T), name)) break :blk @unionInit(T, name, try read(reader, F));
            unreachable;
        },
        .void => {},
        else => @compileError("Unsupported serving field"),
    };
}
