//! One effective server policy, translated explicitly into isolated child environments.
const telemetry = @import("transit_query").wire.observability.telemetry;
const Self = @This();
format: telemetry.Format = .text,
level: enum { debug, info, warn, @"error", off } = .info,

pub fn config(self: Self) telemetry.Config {
    return .{ .format = self.format, .level = switch (self.level) {
        .debug => .debug,
        .info => .info,
        .warn => .warn,
        .@"error" => .err,
        .off => .off,
    } };
}
pub fn environment(self: Self) [2]@import("Process.zig").Variable {
    return .{
        .{ .name = "LOG_FORMAT", .value = @tagName(self.format) },
        .{ .name = "LOG_LEVEL", .value = @tagName(self.level) },
    };
}
