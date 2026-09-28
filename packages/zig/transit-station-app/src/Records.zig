//! Application-owned fixed records. No host layout, pointers or unbounded lists.
const std = @import("std");
const p = @import("root.zig").protocol;
pub fn key(application: u64, tag: u8, principal: u64, operation: u64) p.Value {
    var bytes: [27]u8 = undefined;
    bytes[0..2].* = "\x00A".*;
    std.mem.writeInt(u64, bytes[2..10], application, .big);
    bytes[10] = tag;
    std.mem.writeInt(u64, bytes[11..19], principal, .big);
    std.mem.writeInt(u64, bytes[19..27], operation, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn encode(comptime tag: u8, value: anytype) !p.Value {
    var bytes: [p.Value.max_bytes]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try out.writeAll("AP1");
    try out.writeByte(tag);
    try write(&out, value);
    return p.Value.init(out.buffered());
}
pub fn decode(comptime T: type, comptime tag: u8, value: p.Value) !T {
    try value.validate();
    var input: std.Io.Reader = .fixed(value.slice());
    if (!std.mem.eql(u8, try input.take(3), "AP1") or try input.takeByte() != tag) return error.InvalidApplicationRecord;
    const result = try read(&input, T);
    if (input.bufferedLen() != 0) return error.InvalidApplicationRecord;
    return result;
}
fn write(out: *std.Io.Writer, value: anytype) anyerror!void {
    if (@TypeOf(value) == p.Value) {
        try value.validate();
        if (value.len > 128) return error.ApplicationPartTooLarge;
        try out.writeByte(@intCast(value.len));
        return out.writeAll(value.slice());
    }
    switch (@typeInfo(@TypeOf(value))) {
        .int => try out.writeInt(@TypeOf(value), value, .little),
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
        .void => {},
        else => @compileError("Application records require bounded fixed fields"),
    }
}
fn read(input: *std.Io.Reader, comptime T: type) anyerror!T {
    if (T == p.Value) {
        const length = try input.takeByte();
        if (length > 128) return error.ApplicationPartTooLarge;
        return p.Value.init(try input.take(length));
    }
    return switch (@typeInfo(T)) {
        .int => try input.takeInt(T, .little),
        .bool => switch (try input.takeByte()) {
            0 => false,
            1 => true,
            else => return error.InvalidApplicationRecord,
        },
        .@"enum" => std.enums.fromInt(T, try input.takeByte()) orelse error.InvalidApplicationRecord,
        .array => |info| blk: {
            var result: T = undefined;
            for (&result) |*item| item.* = try read(input, info.child);
            break :blk result;
        },
        .@"struct" => |info| blk: {
            var result: T = undefined;
            inline for (info.field_names, info.field_types) |name, F| @field(result, name) = try read(input, F);
            break :blk result;
        },
        .@"union" => |info| blk: {
            const tag = std.enums.fromInt(std.meta.Tag(T), try input.takeByte()) orelse return error.InvalidApplicationRecord;
            inline for (info.field_names, info.field_types) |name, F| if (tag == @field(std.meta.Tag(T), name)) break :blk @unionInit(T, name, try read(input, F));
            unreachable;
        },
        .void => {},
        else => @compileError("Application records require bounded fixed fields"),
    };
}
