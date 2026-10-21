//! Canonical session JSON: fixed byte arrays are arrays even when their bytes
//! happen to be printable UTF-8. Slices of bytes are protocol text.
const std = @import("std");
pub fn write(value: anytype, json: *std.json.Stringify) std.Io.Writer.Error!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .void => {
            try json.beginObject();
            try json.endObject();
        },
        .optional => if (value) |present| try write(present, json) else try json.write(null),
        .array => {
            try json.beginArray();
            for (value) |item| try write(item, json);
            try json.endArray();
        },
        .pointer => |info| {
            if (info.size == .slice and info.child != u8) {
                try json.beginArray();
                for (value) |item| try write(item, json);
                try json.endArray();
            } else try json.write(value);
        },
        .@"struct" => |info| {
            if (info.is_tuple) try json.beginArray() else try json.beginObject();
            inline for (info.field_names) |name| {
                if (!info.is_tuple) try json.objectField(name);
                try write(@field(value, name), json);
            }
            if (info.is_tuple) try json.endArray() else try json.endObject();
        },
        .@"union" => {
            try json.beginObject();
            switch (value) {
                inline else => |item, tag| {
                    try json.objectField(@tagName(tag));
                    try write(item, json);
                },
            }
            try json.endObject();
        },
        else => try json.write(value),
    }
}
pub fn encode(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    var json: std.json.Stringify = .{ .writer = &output.writer };
    try write(value, &json);
    return output.toOwnedSlice();
}
/// std.json also accepts strings for [N]u8. Require the reflected array shape
/// before typed parsing so all language implementations agree on the contract.
pub fn shape(comptime T: type, value: std.json.Value) !void {
    switch (@typeInfo(T)) {
        .void => if (value != .object or value.object.count() != 0) return error.InvalidSqlJsonShape,
        .optional => |info| if (value != .null) try shape(info.child, value),
        .array => |info| {
            if (value != .array or value.array.items.len != info.len) return error.InvalidSqlJsonShape;
            for (value.array.items) |item| try shape(info.child, item);
        },
        .pointer => |info| if (info.size == .slice) {
            if (info.child == u8) {
                if (value != .string) return error.InvalidSqlJsonShape;
            } else {
                if (value != .array) return error.InvalidSqlJsonShape;
                for (value.array.items) |item| try shape(info.child, item);
            }
        },
        .@"struct" => |info| {
            if (value != .object) return error.InvalidSqlJsonShape;
            inline for (info.field_names) |name| if (value.object.get(name)) |item| try shape(@FieldType(T, name), item);
        },
        .@"union" => |info| {
            if (value != .object or value.object.count() != 1) return error.InvalidSqlJsonShape;
            inline for (info.field_names) |name| if (value.object.get(name)) |item| return shape(@FieldType(T, name), item);
            return error.InvalidSqlJsonShape;
        },
        .int => if (value != .integer and value != .number_string) return error.InvalidSqlJsonShape,
        else => {},
    }
}
test "printable byte identities have the same JSON shape as arbitrary bytes" {
    const a = std.testing.allocator;
    const value: [2]u8 = .{ 65, 66 };
    const bytes = try encode(a, .{ .id = value, .name = @as([]const u8, "AB") });
    defer a.free(bytes);
    try std.testing.expectEqualStrings("{\"id\":[65,66],\"name\":\"AB\"}", bytes);
    const input = try std.json.parseFromSlice(std.json.Value, a, "\"AB\"", .{});
    defer input.deinit();
    try std.testing.expectError(error.InvalidSqlJsonShape, shape([2]u8, input.value));
}
