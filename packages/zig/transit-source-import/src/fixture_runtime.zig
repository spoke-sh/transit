//! Test-only resources shared by unit and separate-process component fixtures.
const std = @import("std");
pub var supplied: ?struct { allocator: std.mem.Allocator, io: std.Io } = null;
pub var boundary: ?struct { context: *anyopaque, run: *const fn (*anyopaque, []const u8) anyerror!void } = null;
pub fn allocator() std.mem.Allocator {
    return if (supplied) |value| value.allocator else if (@import("builtin").is_test) std.testing.allocator else unreachable;
}
pub fn io() std.Io {
    return if (supplied) |value| value.io else if (@import("builtin").is_test) std.testing.io else unreachable;
}
pub fn hit(name: []const u8) !void {
    if (boundary) |hook| try hook.run(hook.context, name);
}
