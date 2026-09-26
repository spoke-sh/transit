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
test "UTF-8 byte arrays and empty arrays preserve their declared wire shape" {
    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var out: std.json.Stringify = .{ .writer = &writer };
    try write(.{ .bytes = [_]u8{ 'i', 'd', 0 }, .text = @as([]const u8, "id"), .empty = [0]u8{}, .value = try @import("transit_protocol").Value.init("id") }, &out);
    try std.testing.expectEqualStrings("{\"bytes\":[105,100,0],\"text\":\"id\",\"empty\":[],\"value\":\"6964\"}", writer.buffered());
}
