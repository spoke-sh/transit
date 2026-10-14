//! Async signal handlers only set a flag; joined tasks own drain and cleanup.
const std = @import("std");
const Self = @This();
var requested: std.atomic.Value(bool) = .init(false);
old_int: std.c.Sigaction,
old_term: std.c.Sigaction,
pub fn stopping() bool {
    return requested.load(.acquire);
}
fn handler(_: std.c.SIG) callconv(.c) void {
    requested.store(true, .release);
}
pub fn init() !Self {
    requested.store(false, .release);
    var action = std.mem.zeroes(std.c.Sigaction);
    action.handler.handler = handler;
    var self: Self = undefined;
    if (std.c.sigaction(.INT, &action, &self.old_int) != 0) return error.SignalSetupFailed;
    errdefer _ = std.c.sigaction(.INT, &self.old_int, null);
    if (std.c.sigaction(.TERM, &action, &self.old_term) != 0) return error.SignalSetupFailed;
    return self;
}
pub fn deinit(self: Self) void {
    _ = std.c.sigaction(.INT, &self.old_int, null);
    _ = std.c.sigaction(.TERM, &self.old_term, null);
}
pub fn wait(io: std.Io) anyerror!void {
    while (!stopping()) try io.sleep(.fromMilliseconds(10), .awake);
}
