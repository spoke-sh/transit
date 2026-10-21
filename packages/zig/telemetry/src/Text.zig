//! The human projection of bounded telemetry records. No I/O or allocation.
const std = @import("std");
const t = @import("root.zig");

pub fn prefix(out: *std.Io.Writer, now: i64, service: []const u8, level: t.Level, name: []const u8) !void {
    const milliseconds: u64 = @intCast(@max(now, 0));
    const seconds: std.time.epoch.EpochSeconds = .{ .secs = milliseconds / 1000 };
    const date = seconds.getEpochDay().calculateYearDay();
    const month = date.calculateMonthDay();
    const time = seconds.getDaySeconds();
    try out.print("{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}Z {s} [{s}] {s}", .{
        date.year,              @backingInt(month.month),  @as(u8, month.day_index) + 1,
        time.getHoursIntoDay(), time.getMinutesIntoHour(), time.getSecondsIntoMinute(),
        milliseconds % 1000,
        switch (level) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .off => "OFF",
        },
        service,                name,
    });
}

/// Messages cannot insert a second record or terminal escape sequence.
pub fn message(out: *std.Io.Writer, value: []const u8) !void {
    for (value) |byte| switch (byte) {
        0...31, 127 => try out.print("\\x{x:0>2}", .{byte}),
        else => try out.writeByte(byte),
    };
}

pub fn fields(out: *std.Io.Writer, comptime parent: []const u8, value: anytype) anyerror!void {
    const T = @TypeOf(value);
    if (T == t.Snapshot) {
        try fields(out, parent ++ ".active", value.active);
        inline for (comptime std.meta.tags(t.Outcome)) |outcome| try fields(out, comptime parent ++ ".outcomes." ++ @tagName(outcome), value.outcomes[@backingInt(outcome)]);
        inline for (.{ "le_1ms", "gt_1ms_le_5ms", "gt_5ms_le_10ms", "gt_10ms_le_50ms", "gt_50ms_le_100ms", "gt_100ms_le_500ms", "gt_500ms_le_1s", "gt_1s_le_5s", "gt_5s" }, 0..) |name, i| try fields(out, parent ++ ".buckets." ++ name, value.buckets[i]);
        try fields(out, parent ++ ".duration_seconds", value.duration_seconds);
        return;
    }
    switch (@typeInfo(T)) {
        .@"struct" => inline for (@typeInfo(T).@"struct".field_names) |name| {
            try fields(out, if (parent.len == 0) name else parent ++ "." ++ name, @field(value, name));
        },
        .optional => if (value) |present| try fields(out, parent, present),
        else => {
            try out.print(" {s}=", .{parent});
            if (T == []const u8 or T == []u8) {
                try std.json.Stringify.value(value, .{}, out);
            } else if (@typeInfo(T) == .@"enum") {
                try out.writeAll(@tagName(value));
            } else try std.json.Stringify.value(value, .{}, out);
        },
    }
}

pub fn event(out: *std.Io.Writer, value: t.Event) !void {
    if (value.message) |text| {
        try out.writeByte(' ');
        try message(out, text);
    }
    inline for (@typeInfo(t.Event).@"struct".field_names) |name| {
        if (comptime std.mem.eql(u8, name, "name") or std.mem.eql(u8, name, "level") or std.mem.eql(u8, name, "message")) continue;
        if (comptime std.mem.eql(u8, name, "outcome")) {
            if (value.outcome != .ok) try fields(out, name, value.outcome);
        } else if (comptime std.mem.eql(u8, name, "protocol_outcome")) {
            if (value.protocol_outcome != .none) try fields(out, name, value.protocol_outcome);
        } else try fields(out, name, @field(value, name));
    }
}

test "human records have UTC timestamps and escape terminal controls" {
    var buffer: [1024]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    try prefix(&out, 0, "test", .err, "service.failed");
    try event(&out, .{ .name = "service.failed", .message = "failed\n\x1b[31m", .level = .err, .outcome = .failed, .error_type = "Unavailable" });
    try std.testing.expectEqualStrings("1970-01-01T00:00:00.000Z ERROR [test] service.failed failed\\x0a\\x1b[31m outcome=failed error_type=\"Unavailable\"", out.buffered());
}
