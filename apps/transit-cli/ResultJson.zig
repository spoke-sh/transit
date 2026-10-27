//! Lossless presentation of semantic outcomes. Wide integers are decimal strings;
//! fixed byte identities remain arrays. This is console output, not SQL carriage.
const std = @import("std");
pub fn write(value: anytype, out: *std.json.Stringify) std.Io.Writer.Error!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .int => |info| if (info.bits >= 64) {
            var buffer: [128]u8 = undefined;
            const text = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch unreachable;
            try out.write(text);
        } else try out.write(value),
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
test "result presentation retains wide counts and fixed byte identities" {
    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var json: std.json.Stringify = .{ .writer = &writer };
    try write(.{ .rows = @as(u64, std.math.maxInt(u64)), .small = @as(u8, 7), .identity = [_]u8{ 65, 66 } }, &json);
    try std.testing.expectEqualStrings("{\"rows\":\"18446744073709551615\",\"small\":7,\"identity\":[65,66]}", writer.buffered());
}
