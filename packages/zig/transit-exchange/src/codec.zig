//! Fixed little-endian framework records. No native padding is serialized.
const std = @import("std");
const Value = @import("transit_station").protocol.Value;
fn width(comptime T: type) comptime_int {
    return switch (@typeInfo(T)) {
        .int => @bitSizeOf(T) / 8,
        .@"enum" => @bitSizeOf(@typeInfo(T).@"enum".tag_type) / 8,
        .array => |a| if (a.child == u8) a.len else @compileError("Byte arrays only"),
        else => @compileError("Unsupported record field"),
    };
}
pub fn size(comptime T: type) comptime_int {
    comptime var n = 4;
    inline for (@typeInfo(T).@"struct".field_types) |F| n += width(F);
    return n;
}
pub fn encode(value: anytype) !Value {
    const T = @TypeOf(value);
    try value.validate();
    var bytes: [size(T)]u8 = undefined;
    bytes[0..4].* = T.magic.*;
    comptime var offset = 4;
    inline for (@typeInfo(T).@"struct".field_names, @typeInfo(T).@"struct".field_types) |name, F| {
        const end = offset + width(F);
        switch (@typeInfo(F)) {
            .int => std.mem.writeInt(F, bytes[offset..end], @field(value, name), .little),
            .@"enum" => |e| std.mem.writeInt(e.tag_type, bytes[offset..end], @backingInt(@field(value, name)), .little),
            .array => bytes[offset..end].* = @field(value, name),
            else => unreachable,
        }
        offset = end;
    }
    return Value.init(&bytes);
}
pub fn decode(comptime T: type, value: Value) !T {
    try value.validate();
    if (value.len != size(T) or !std.mem.eql(u8, value.data[0..4], T.magic)) return error.InvalidExchangeRecord;
    var result: T = undefined;
    comptime var offset = 4;
    inline for (@typeInfo(T).@"struct".field_names, @typeInfo(T).@"struct".field_types) |name, F| {
        const end = offset + width(F);
        @field(result, name) = switch (@typeInfo(F)) {
            .int => std.mem.readInt(F, value.data[offset..end], .little),
            .@"enum" => |e| std.enums.fromInt(F, std.mem.readInt(e.tag_type, value.data[offset..end], .little)) orelse return error.InvalidExchangeRecord,
            .array => value.data[offset..end].*,
            else => unreachable,
        };
        offset = end;
    }
    try result.validate();
    return result;
}
