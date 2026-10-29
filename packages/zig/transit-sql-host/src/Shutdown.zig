//! Host-owned lifecycle wakeup; signal handlers notify through their relay.
const std = @import("std");
const Self = @This();
requested: std.atomic.Value(bool) = .init(false),
mutex: std.Io.Mutex = .init,
changed: std.Io.Condition = .init,
pub fn stopping(self: *const Self) bool {
    return self.requested.load(.acquire);
}
pub fn request(self: *Self, io: std.Io) void {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    self.requested.store(true, .release);
    self.changed.broadcast(io);
}
pub fn wait(self: *Self, io: std.Io) !void {
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    while (!self.stopping()) try self.changed.wait(io, &self.mutex);
}
