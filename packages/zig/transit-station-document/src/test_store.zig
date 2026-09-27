//! In-memory private-turn harness; this is not a durability proof.
const std = @import("std");
const t = std.testing;
const lib = @import("root.zig");
const p = lib.station.protocol;
const Turn = lib.station.GrowingTurn;
const Turns = @This();
state: std.AutoHashMapUnmanaged(p.Value, p.Value) = .empty,
resource: u64 = 7,
revision: u64 = 1,
input: u64 = 1,
denied: bool = false,
accepted_outputs: usize = 0,
pub fn deinit(self: *Turns) void {
    self.state.deinit(t.allocator);
}
fn read(raw: *anyopaque, _: p.Growth.View, address: p.Value) !?p.Value {
    const self: *Turns = @ptrCast(@alignCast(raw));
    if (self.denied) return error.AccessDenied;
    return self.state.get(address);
}
pub fn capture(self: *Turns) !Turn {
    return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = self.resource, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read });
}
pub fn commit(self: *Turns, turn: Turn) !void {
    try turn.validate();
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        if (mutation.value) |bytes| try self.state.put(t.allocator, mutation.key, bytes) else _ = self.state.remove(mutation.key);
    };
    for (turn.decision.outputs) |output| if (output != null) {
        self.accepted_outputs += 1;
    };
    self.revision += 1;
    self.input += 1;
}
