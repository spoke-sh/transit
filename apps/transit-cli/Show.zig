//! Local settings inspection, independent of query result presentation.
const std = @import("std");

pub fn write(out: *std.Io.Writer, settings: anytype) !void {
    const names = @typeInfo(@TypeOf(settings)).@"struct".field_names;
    const width = comptime width: {
        var longest: usize = 0;
        for (names) |name| longest = @max(longest, name.len);
        break :width longest;
    };
    inline for (names) |name| {
        try out.splatByteAll(' ', width - name.len);
        try out.print("{s}: ", .{name});
        try value(out, @field(settings, name));
        try out.writeByte('\n');
    }
}

fn value(out: *std.Io.Writer, setting: anytype) !void {
    switch (@typeInfo(@TypeOf(setting))) {
        .optional => if (setting) |selected| try value(out, selected) else try out.writeAll("(automatic)"),
        .bool => try out.writeAll(if (setting) "on" else "off"),
        .@"enum" => try out.writeAll(@tagName(setting)),
        else => try std.json.Stringify.encodeJsonStringChars(setting, .{ .escape_unicode = true }, out),
    }
}

test "settings align names, render automatic and boolean values, and escape controls" {
    var buffer: [1024]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    try write(&out, .{
        .connection = @as(?[]const u8, null),
        .connection_source = "local installation",
        .format = @as(enum { json }, .json),
        .enabled = true,
        .disabled = false,
        .path = @as(?[]const u8, "a\n\r\t\x1b\\\".yaml"),
    });
    try std.testing.expectEqualStrings(
        "       connection: (automatic)\n" ++
            "connection_source: local installation\n" ++
            "           format: json\n" ++
            "          enabled: on\n" ++
            "         disabled: off\n" ++
            "             path: a\\n\\r\\t\\u001b\\\\\\\".yaml\n",
        out.buffered(),
    );
}
