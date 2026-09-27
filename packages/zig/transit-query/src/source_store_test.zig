//! Private-turn in-memory reference store, not a durability/authority proof.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const t = std.testing;
const Turn = q.station.GrowingTurn;
const Self = @This();
state: std.AutoHashMapUnmanaged(p.Value, p.Value) = .empty,
resource: u64 = 7,
revision: u64 = 1,
input: u64 = 1,
denied: bool = false,
pub fn deinit(self: *Self) void {
    self.state.deinit(t.allocator);
}
pub fn clone(self: *Self) !Self {
    var copy: Self = .{ .resource = self.resource, .revision = self.revision, .input = self.input };
    copy.state = try self.state.clone(t.allocator);
    return copy;
}
fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.denied) return error.AccessDenied;
    return self.state.get(key);
}
fn page(raw: *anyopaque, _: p.Growth.View, after: ?p.Value) !p.Growth.Batch(p.Growth.Entry, p.Value) {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.denied) return error.AccessDenied;
    var next: p.Growth.Batch(p.Growth.Entry, p.Value) = .{};
    var cursor = after;
    for (0..p.Growth.page_size + 1) |index| {
        var minimum: ?p.Value = null;
        var entries = self.state.keyIterator();
        while (entries.next()) |key| {
            if (cursor) |previous| if (std.mem.order(u8, key.slice(), previous.slice()) != .gt) continue;
            if (minimum == null or std.mem.order(u8, key.slice(), minimum.?.slice()) == .lt) minimum = key.*;
        }
        const key = minimum orelse break;
        if (index == p.Growth.page_size) {
            next.next = cursor;
            break;
        }
        next.entries[index] = .{ .key = key, .value = self.state.get(key).?, .revision = self.revision };
        cursor = key;
    }
    return next;
}
pub fn capture(self: *Self) !Turn {
    return Turn.init(.{ .realm = 1, .principal = 2, .pid = 3, .generation = 1, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 3, .principal = 2, .generation = 1, .input = self.input, .process_revision = self.revision, .resource = self.resource, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read, .page = page });
}
pub fn commit(self: *Self, turn: Turn) !void {
    try turn.validate();
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        if (mutation.value) |value| try self.state.put(t.allocator, mutation.key, value) else _ = self.state.remove(mutation.key);
    };
    self.revision += 1;
    self.input += 1;
}
