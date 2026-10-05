//! Volatile scheduling hints, always used under the authority mutex.
const std = @import("std");
const g = @import("transit_client").protocol.Growth;
const Self = @This();
pub const capacity = 4;
const Scope = union(enum) { process: u64, outputs };
const Slot = struct { scope: ?Scope = null, changed: std.Io.Condition = .init };
slots: [capacity]Slot = @splat(.{}),
pub fn wait(self: *Self, io: std.Io, mutex: *std.Io.Mutex, query: g.Query, milliseconds: u32) !void {
    const slot = for (&self.slots) |*slot| {
        if (slot.scope == null) break slot;
    } else return error.ControlCapacity;
    slot.scope = switch (query.kind) {
        .process => |pid| .{ .process = pid },
        .outputs, .delivery => .outputs,
        else => return error.InvalidWaitHint,
    };
    defer slot.scope = null;
    slot.changed.waitTimeout(io, mutex, .{ .duration = .{ .raw = .fromMilliseconds(milliseconds), .clock = .awake } }) catch |err| switch (err) {
        error.Timeout => {},
        else => return err,
    };
}
fn relevant(scope: Scope, command: g.Command) bool {
    switch (command) {
        .send, .open_view, .close_view, .begin_turn => return scope == .process and g.commandPid(command) == scope.process,
        .turn, .turn_with_versions => {
            const turn = if (command == .turn) command.turn else command.turn_with_versions.turn;
            if (scope == .process) return turn.pid == scope.process;
            for (turn.outputs) |slot| if (slot != null) return true;
            return false;
        },
        // Grants, retirement, delivery and less frequent controls can affect
        // dependencies beyond a single PID. Revalidate broadly after these.
        else => return true,
    }
}
pub fn publish(self: *Self, io: std.Io, command: g.Command) void {
    for (&self.slots) |*slot| if (slot.scope) |scope| {
        if (relevant(scope, command)) slot.changed.broadcast(io);
    };
}
test "point publications avoid unrelated wakeups while controls invalidate all scopes" {
    const t = std.testing;
    const value = try @import("transit_client").protocol.Value.init("work");
    const send: g.Command = .{ .send = .{ .pid = 1, .value = value } };
    try t.expect(relevant(.{ .process = 1 }, send));
    try t.expect(!relevant(.{ .process = 2 }, send));
    try t.expect(!relevant(.outputs, send));
    try t.expect(relevant(.outputs, .{ .revoke = 1 }));
    try t.expect(relevant(.{ .process = 2 }, .{ .revoke = 1 }));
}
