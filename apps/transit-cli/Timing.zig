//! Monotonic wall time for one explicit query attempt. Never query authority.
const std = @import("std");
const Self = @This();
pub const Phase = enum { prepare, compile, submit, wait, fetch, render, persist, open, release };
init: std.process.Init,
enabled: bool,
interactive: bool = false,
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
/// Freeze the measurements before command diagnostics and deferred reporting.
pub fn finish(self: *Self) ?Report {
    if (!self.enabled) return null;
    self.enter(self.phase);
    return .{ .init = self.init, .interactive = self.interactive, .elapsed = self.elapsed };
}

pub const Report = struct {
    init: std.process.Init,
    interactive: bool,
    elapsed: [@typeInfo(Phase).@"enum".field_names.len]u64,

    pub fn emit(self: Report, structured: bool) void {
        var total: u64 = 0;
        for (self.elapsed) |elapsed| total += elapsed;
        var buffer: [1024]u8 = undefined;
        var text: std.Io.Writer = .fixed(&buffer);
        if (structured) {
            std.json.Stringify.value(.{ .timing = .{ .unit = "ms", .total = total, .interactive = self.interactive, .phases = .{
                .prepare = self.elapsed[0],
                .compile = self.elapsed[1],
                .submit = self.elapsed[2],
                .wait = self.elapsed[3],
                .fetch = self.elapsed[4],
                .render = self.elapsed[5],
                .persist = self.elapsed[6],
                .open = self.elapsed[7],
                .release = self.elapsed[8],
            } } }, .{}, &text) catch return;
            text.writeByte('\n') catch return;
        } else {
            text.print("Time: {d} ms (", .{total}) catch return;
            const phases: []const Phase = if (self.interactive)
                &.{ .compile, .open, .fetch, .render, .release }
            else
                &.{ .prepare, .compile, .submit, .wait, .fetch, .render, .persist };
            for (phases, 0..) |phase, i| {
                text.print("{s}{s} {d} ms", .{ if (i == 0) "" else ", ", @tagName(phase), self.elapsed[@backingInt(phase)] }) catch return;
            }
            text.writeAll(")\n") catch return;
        }
        var output_buffer: [1024]u8 = undefined;
        var output = std.Io.File.stderr().writerStreaming(self.init.io, &output_buffer);
        @import("Output.zig").write(self.init, &output.interface, text.buffered()) catch {};
    }
};
