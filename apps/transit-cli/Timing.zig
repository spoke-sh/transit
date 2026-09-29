//! Monotonic wall time for one explicit query attempt. Never query authority.
const std = @import("std");
const Self = @This();
pub const Phase = enum { prepare, compile, submit, wait, fetch, render, persist };
init: std.process.Init,
enabled: bool,
phase: Phase = .prepare,
last: i64,
elapsed: [@typeInfo(Phase).@"enum".field_names.len]u64 = @splat(0),

pub fn start(init: std.process.Init, enabled: bool) Self {
    return .{ .init = init, .enabled = enabled, .last = std.Io.Clock.boot.now(init.io).toMilliseconds() };
}
pub fn enter(self: *Self, phase: Phase) void {
    if (!self.enabled) return;
    const now = std.Io.Clock.boot.now(self.init.io).toMilliseconds();
    self.elapsed[@backingInt(self.phase)] += @intCast(@max(0, now - self.last));
    self.last = now;
    self.phase = phase;
}
pub fn report(self: *Self) void {
    if (!self.enabled) return;
    self.enter(self.phase);
    var total: u64 = 0;
    for (self.elapsed) |elapsed| total += elapsed;
    var buffer: [1024]u8 = undefined;
    var text: std.Io.Writer = .fixed(&buffer);
    text.print("Time: {d} ms (", .{total}) catch return;
    inline for (@typeInfo(Phase).@"enum".field_names, 0..) |name, i| {
        text.print("{s}{s} {d} ms", .{ if (i == 0) "" else ", ", name, self.elapsed[i] }) catch return;
    }
    text.writeAll(")\n") catch return;
    var output_buffer: [1024]u8 = undefined;
    var output = std.Io.File.stderr().writerStreaming(self.init.io, &output_buffer);
    @import("Output.zig").write(self.init, &output.interface, text.buffered()) catch {};
}
