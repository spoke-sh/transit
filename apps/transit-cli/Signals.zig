//! Signal handlers set a flag only. Normal code owns persistence and cleanup.
const std = @import("std");
var stopped: std.atomic.Value(u8) = .init(0);
pub var cancellation: std.atomic.Value(bool) = .init(false);
var cancelling: std.atomic.Value(bool) = .init(false);
pub fn interrupted() bool {
    const signal = stopped.load(.monotonic);
    return signal == 2 or (signal == 1 and !cancelling.load(.monotonic));
}
pub fn terminating() bool {
    return stopped.load(.monotonic) == 2;
}
pub fn clear() void {
    stopped.store(0, .monotonic);
    cancellation.store(false, .release);
}
/// Coalesce repeated Ctrl-C while normal code settles cancellation. SIGTERM
/// still interrupts cleanup and must never be overwritten by a later SIGINT.
pub fn beginCancellation() void {
    cancelling.store(true, .monotonic);
}
pub fn endCancellation() void {
    cancellation.store(false, .release);
    _ = stopped.cmpxchgStrong(1, 0, .monotonic, .monotonic);
    cancelling.store(false, .monotonic);
}
fn handler(signal: std.c.SIG) callconv(.c) void {
    _ = stopped.fetchMax(if (signal == .TERM) 2 else 1, .monotonic);
    cancellation.store(true, .release);
}
const Self = @This();
old_int: std.c.Sigaction,
old_term: std.c.Sigaction,
pub fn install() !Self {
    clear();
    var action = std.mem.zeroes(std.c.Sigaction);
    action.handler.handler = handler;
    var self: Self = undefined;
    if (std.c.sigaction(.INT, &action, &self.old_int) != 0) return error.SignalSetupFailed;
    errdefer _ = std.c.sigaction(.INT, &self.old_int, null);
    if (std.c.sigaction(.TERM, &action, &self.old_term) != 0) return error.SignalSetupFailed;
    return self;
}
pub fn close(self: Self) void {
    _ = std.c.sigaction(.INT, &self.old_int, null);
    _ = std.c.sigaction(.TERM, &self.old_term, null);
}
/// Finite polling keeps idle pipe/TTY input responsive to stop signals.
pub fn readByte() !?u8 {
    while (true) switch (try pollByte(100)) {
        .byte => |byte| return byte,
        .eof => return null,
        .timeout => {},
    };
}
pub fn pending() bool {
    var fd: [1]std.c.pollfd = .{.{ .fd = 0, .events = std.c.POLL.IN, .revents = 0 }};
    return std.c.poll(&fd, 1, 0) > 0;
}
pub const Input = union(enum) { byte: u8, eof, timeout };
pub fn pollByte(timeout_ms: c_int) !Input {
    while (true) {
        if (interrupted()) return error.ConsoleInterrupted;
        var fd: [1]std.c.pollfd = .{.{ .fd = 0, .events = std.c.POLL.IN, .revents = 0 }};
        const ready = std.c.poll(&fd, 1, timeout_ms);
        if (ready <= 0) {
            if (ready < 0 and std.c._errno().* != @backingInt(std.c.E.INTR)) return error.ConsoleInputFailed;
            if (interrupted()) return error.ConsoleInterrupted;
            return .timeout;
        }
        var byte: u8 = undefined;
        const count = std.c.read(0, @ptrCast(&byte), 1);
        if (count == 0) return .eof;
        if (count == 1) return .{ .byte = byte };
        if (std.c._errno().* != @backingInt(std.c.E.INTR)) return error.ConsoleInputFailed;
    }
}
