//! Match the generated schema: fixed arrays remain arrays even when their
//! bytes happen to form UTF-8. Text slices remain strings.
const std = @import("std");
pub fn write(value: anytype, out: *std.json.Stringify) std.Io.Writer.Error!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .void => {
            try out.beginObject();
            try out.endObject();
        },
        .array => {
            try out.beginArray();
            for (value) |item| try write(item, out);
            try out.endArray();
        },
        .pointer => |info| {
            if (comptime info.size == .slice and info.child != u8) {
                try out.beginArray();
                for (value) |item| try write(item, out);
                try out.endArray();
            } else try out.write(value);
        },
        .optional => if (value) |item| try write(item, out) else try out.write(null),
        .@"struct" => |info| {
            if (@hasDecl(T, "jsonStringify")) return out.write(value);
            if (comptime info.is_tuple) {
                try out.beginArray();
                inline for (info.field_names) |name| try write(@field(value, name), out);
                return out.endArray();
            }
            try out.beginObject();
            inline for (info.field_names) |name| {
                try out.objectField(name);
                try write(@field(value, name), out);
            }
            try out.endObject();
        },
        .@"union" => {
            try out.beginObject();
            switch (value) {
                inline else => |item, tag| {
                    try out.objectField(@tagName(tag));
                    try write(item, out);
                },
            }
            try out.endObject();
        },
        else => try out.write(value),
    }
}
test "UTF-8 byte arrays and empty arrays preserve their declared wire shape" {
    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var out: std.json.Stringify = .{ .writer = &writer };
    try write(.{ .bytes = [_]u8{ 'i', 'd', 0 }, .text = @as([]const u8, "id"), .empty = [0]u8{}, .value = try @import("root.zig").Value.init("id") }, &out);
    try std.testing.expectEqualStrings("{\"bytes\":[105,100,0],\"text\":\"id\",\"empty\":[],\"value\":\"6964\"}", writer.buffered());
}

test "bounded host sequences recursively preserve fixed byte-array schema" {
    const Item = struct { digest: [2]u8, label: []const u8 };
    const items = [_]Item{.{ .digest = .{ 0, 0 }, .label = "text" }};
    const encoded = try valueAlloc(std.testing.allocator, @as([]const Item, &items));
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualStrings("[{\"digest\":[0,0],\"label\":\"text\"}]", encoded);
    const parsed = try parseFromSlice([]const Item, std.testing.allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqualDeep(items[0], parsed.value[0]);
    try std.testing.expectError(error.InvalidJsonShape, parseFromSlice([]const Item, std.testing.allocator, "[{\"digest\":\"aa\",\"label\":\"text\"}]"));
}

pub fn valueAlloc(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    var encoder: std.json.Stringify = .{ .writer = &output.writer };
    try write(value, &encoder);
    return output.toOwnedSlice();
}

/// Validate reflected host wire shapes before typed decoding. Zig's generic
/// parser also accepts strings for byte arrays; public host schemas do not.
pub fn parseFromSlice(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(T) {
    return parseWithOptions(T, allocator, bytes, .{});
}

/// Own decoded strings as well as collections; safe after releasing input bytes.
pub fn parseFromSliceOwned(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(T) {
    return parseWithOptions(T, allocator, bytes, .{ .allocate = .alloc_always });
}
fn parseWithOptions(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8, options: std.json.ParseOptions) !std.json.Parsed(T) {
    const tree = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer tree.deinit();
    try shape(T, tree.value);
    return std.json.parseFromSlice(T, allocator, bytes, options);
}
fn shape(comptime T: type, value: std.json.Value) anyerror!void {
    switch (@typeInfo(T)) {
        .int => switch (value) {
            .integer => {},
            .number_string => |text| _ = std.fmt.parseInt(T, text, 10) catch return error.InvalidJsonShape,
            else => return error.InvalidJsonShape,
        },
        .bool => if (value != .bool) return error.InvalidJsonShape,
        .@"enum" => if (value != .string) return error.InvalidJsonShape,
        .void => if (value != .object or value.object.count() != 0) return error.InvalidJsonShape,
        .array => |info| {
            if (value != .array or value.array.items.len != info.len) return error.InvalidJsonShape;
            for (value.array.items) |item| try shape(info.child, item);
        },
        .optional => |info| if (value != .null) try shape(info.child, value),
        .@"struct" => |info| {
            if (comptime @hasDecl(T, "jsonParse") or @hasDecl(T, "jsonParseFromValue")) return;
            if (value != .object) return error.InvalidJsonShape;
            inline for (info.field_names, info.field_types) |name, F| if (value.object.get(name)) |item| {
                if (comptime @hasDecl(T, "json_schema_fields") and @hasField(@TypeOf(T.json_schema_fields), name)) {
                    const constraint = @field(T.json_schema_fields, name);
                    if (comptime @hasField(@TypeOf(constraint), "const")) {
                        if (value.object.get(name).? != .integer or value.object.get(name).?.integer != constraint.@"const") return error.InvalidJsonConstant;
                    }
                }
                try shape(F, item);
            };
        },
        .@"union" => |info| {
            if (value != .object or value.object.count() != 1) return error.InvalidJsonShape;
            inline for (info.field_names, info.field_types) |name, F| if (value.object.get(name)) |item| try shape(F, item);
        },
        .pointer => |info| {
            if (comptime info.size == .slice and info.child == u8) {
                if (value != .string) return error.InvalidJsonShape;
            } else if (comptime info.size == .slice) {
                if (value != .array) return error.InvalidJsonShape;
                for (value.array.items) |item| try shape(info.child, item);
            }
        },
        else => {},
    }
}
test "reflected array and version shape cannot silently diverge from public schema" {
    const Message = struct {
        pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
        version: u8 = 1,
        nonce: [2]u8,
    };
    const allocator = std.testing.allocator;
    const valid = try parseFromSlice(Message, allocator, "{\"nonce\":[105,100]}");
    defer valid.deinit();
    try std.testing.expectEqual(@as([2]u8, .{ 105, 100 }), valid.value.nonce);
    try std.testing.expectError(error.InvalidJsonShape, parseFromSlice(Message, allocator, "{\"nonce\":\"id\"}"));
    try std.testing.expectError(error.InvalidJsonConstant, parseFromSlice(Message, allocator, "{\"version\":2,\"nonce\":[105,100]}"));
}

test "host JSON rejects quoted integers and preserves escaped UTF-8 at wide values" {
    const Message = struct { position: u64, text: []const u8 };
    const a = std.testing.allocator;
    const bytes = try valueAlloc(a, Message{ .position = @import("root.zig").max_counter, .text = "\x00\n\"é" });
    defer a.free(bytes);
    const decoded = try parseFromSlice(Message, a, bytes);
    defer decoded.deinit();
    try std.testing.expectEqual(@import("root.zig").max_counter, decoded.value.position);
    try std.testing.expectEqualStrings("\x00\n\"é", decoded.value.text);
    try std.testing.expectError(error.InvalidJsonShape, parseFromSlice(Message, a, "{\"position\":\"1\",\"text\":\"ok\"}"));
}

test "owned host JSON survives input buffer reuse" {
    var bytes = "{\"label\":\"kept\"}".*;
    const decoded = try parseFromSliceOwned(struct { label: []const u8 }, std.testing.allocator, &bytes);
    defer decoded.deinit();
    @memset(&bytes, 0);
    try std.testing.expectEqualStrings("kept", decoded.value.label);
}

test "anonymous tuple configuration values preserve array shape" {
    const encoded = try valueAlloc(std.testing.allocator, .{ .destinations = .{ @as(u64, 5), @as(u64, 1) } });
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualStrings("{\"destinations\":[5,1]}", encoded);
}
