//! Match the generated schema: fixed arrays remain arrays even when their
//! bytes happen to form UTF-8. Text slices remain strings.
const std = @import("std");
pub fn write(value: anytype, out: *std.json.Stringify) std.Io.Writer.Error!void {
    const T = @TypeOf(value);
    if (T == std.json.Value) return out.write(value);
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
    // This writer has no external sink: its only write failure is allocation.
    // Preserve that classification for bounded callers and allocation proofs.
    write(value, &encoder) catch return error.OutOfMemory;
    return output.toOwnedSlice();
}

/// Count pure value serialization before allocating the final output. Limit
/// refusal is WriteFailed, as with a full fixed writer; backing failure remains
/// OutOfMemory. This trades a second encoding pass for no maximum-sized buffer
/// or intermediate growable copies. Custom jsonStringify methods must be pure.
pub fn valueAllocBounded(allocator: std.mem.Allocator, value: anytype, limit: usize) ![]u8 {
    var scratch: [256]u8 = undefined;
    var count: std.Io.Writer.Discarding = .init(&scratch);
    var counter: std.json.Stringify = .{ .writer = &count.writer };
    try write(value, &counter);
    if (count.fullCount() > limit) return error.WriteFailed;
    const size: usize = @intCast(count.fullCount());
    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);
    var writer: std.Io.Writer = .fixed(output);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try write(value, &encoder);
    std.debug.assert(writer.buffered().len == size);
    return output;
}

test "bounded JSON uses exact encoded bytes and refuses before allocating" {
    const value = .{ .bytes = [_]u8{ 'i', 'd', 0 }, .text = @as([]const u8, "\"\n"), .absent = @as(?u64, null) };
    const expected = "{\"bytes\":[105,100,0],\"text\":\"\\\"\\n\",\"absent\":null}";
    var memory: [expected.len]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&memory);
    try std.testing.expectError(error.WriteFailed, valueAllocBounded(fixed.allocator(), value, expected.len - 1));
    try std.testing.expectEqual(0, fixed.end_index);
    const encoded = try valueAllocBounded(fixed.allocator(), value, expected.len);
    try std.testing.expectEqualStrings(expected, encoded);
    try std.testing.expectEqual(expected.len, fixed.end_index);
}

test "bounded JSON counts escaped bytes across scratch drains" {
    const quotes: [300]u8 = @splat('"');
    var memory: [602]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&memory);
    const value: []const u8 = &quotes;
    try std.testing.expectError(error.WriteFailed, valueAllocBounded(fixed.allocator(), value, 601));
    try std.testing.expectEqual(0, fixed.end_index);
    const encoded = try valueAllocBounded(fixed.allocator(), value, 602);
    try std.testing.expectEqual(602, encoded.len);
    try std.testing.expectEqual('"', encoded[0]);
    for (0..quotes.len) |i| try std.testing.expectEqualStrings("\\\"", encoded[1 + 2 * i ..][0..2]);
    try std.testing.expectEqual('"', encoded[601]);
}

fn boundedAllocationSchedule(allocator: std.mem.Allocator) !void {
    const encoded = try valueAllocBounded(allocator, .{ .name = "bounded value", .values = [_]u64{ 1, 2, 3 } }, 1024);
    defer allocator.free(encoded);
}
test "bounded JSON reports backing allocation failure without leaks" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, boundedAllocationSchedule, .{});
}

fn allocationSchedule(allocator: std.mem.Allocator) !void {
    const encoded = try valueAlloc(allocator, .{ .name = "bounded value", .values = [_]u64{ 1, 2, 3 } });
    defer allocator.free(encoded);
}
test "allocated JSON reports allocation failures without leaking storage" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationSchedule, .{});
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
/// For custom decoders that delegate to an ordinary reflected wire type.
pub fn validateShape(comptime T: type, value: std.json.Value) anyerror!void {
    return shape(T, value);
}
fn shape(comptime T: type, value: std.json.Value) anyerror!void {
    switch (@typeInfo(T)) {
        .int => switch (value) {
            .integer => {},
            .number_string => |text| _ = std.fmt.parseInt(T, text, 10) catch return error.InvalidJsonShape,
            else => return error.InvalidJsonShape,
        },
        .bool => if (value != .bool) return error.InvalidJsonShape,
        .@"enum" => |info| {
            if (value != .string) return error.InvalidJsonShape;
            // The generic Zig parser also accepts a quoted numeric ordinal.
            // Public schemas permit only the declared string names, including
            // the exact current contract definition, never an ordinal alias.
            inline for (info.field_names) |name| {
                if (std.mem.eql(u8, value.string, name)) return;
            }
            return error.InvalidJsonShape;
        },
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

test "host enum strings require declared names and reject ordinal aliases" {
    const Tag = enum { current, @"7" };
    const a = std.testing.allocator;
    for ([_][]const u8{ "\"0\"", "\"0000\"", "\"1\"", "\"foreign\"", "0" }) |bytes| {
        try std.testing.expectError(error.InvalidJsonShape, parseFromSlice(Tag, a, bytes));
    }
    const named = try parseFromSlice(Tag, a, "\"7\"");
    defer named.deinit();
    try std.testing.expectEqual(Tag.@"7", named.value);
    const current = try parseFromSlice(Tag, a, "\"current\"");
    defer current.deinit();
    try std.testing.expectEqual(Tag.current, current.value);
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
