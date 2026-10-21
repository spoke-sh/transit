//! Atomic private-turn fixture; this is not disk or native fencing evidence.
const std = @import("std");
const c = @import("root.zig").catalog;
const p = c.protocol;
const Turn = @import("root.zig").station.Turn;
const Self = @This();
state: std.AutoHashMapUnmanaged(p.Value, p.Value) = .empty,
revision: u64 = 1,
input: u64 = 1,
generation: u64 = 1,
origin: u64 = 5,
denied: bool = false,
batch_reads: bool = false,
reads: usize = 0,
batch_calls: usize = 0,
deny_batch: ?usize = null,
pub fn deinit(self: *Self) void {
    self.state.deinit(std.testing.allocator);
}
fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
    const self: *Self = @ptrCast(@alignCast(raw));
    self.reads += 1;
    if (self.denied) return error.AccessDenied;
    return self.state.get(key);
}
fn many(raw: *anyopaque, _: p.Growth.View, keys: [p.Growth.page_size]?p.Value) ![p.Growth.page_size]?p.Growth.Entry {
    const self: *Self = @ptrCast(@alignCast(raw));
    self.batch_calls += 1;
    if (self.denied or self.deny_batch == self.batch_calls) return error.AccessDenied;
    var result: [p.Growth.page_size]?p.Growth.Entry = @splat(null);
    for (keys, 0..) |key, i| if (key) |selected| {
        if (self.state.get(selected)) |value| result[i] = .{ .key = selected, .value = value, .revision = self.revision };
    };
    return result;
}
fn page(raw: *anyopaque, _: p.Growth.View, after: ?p.Value) !p.Growth.Batch(p.Growth.Entry, p.Value) {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.denied) return error.AccessDenied;
    var result: p.Growth.Batch(p.Growth.Entry, p.Value) = .{};
    var cursor = after;
    for (0..p.Growth.page_size + 1) |index| {
        var minimum: ?p.Value = null;
        var keys = self.state.keyIterator();
        while (keys.next()) |key| {
            if (cursor) |prior| if (std.mem.order(u8, key.slice(), prior.slice()) != .gt) continue;
            if (minimum == null or std.mem.order(u8, key.slice(), minimum.?.slice()) == .lt) minimum = key.*;
        }
        const key = minimum orelse break;
        if (index == p.Growth.page_size) {
            result.next = cursor;
            break;
        }
        result.entries[index] = .{ .key = key, .value = self.state.get(key).?, .revision = self.revision };
        cursor = key;
    }
    return result;
}
pub fn capture(self: *Self) !Turn {
    return Turn.init(.{ .realm = 1, .principal = 2, .pid = 3, .generation = self.generation, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = self.origin, .policy_revision = 1 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 3, .principal = 2, .generation = self.generation, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read, .page = page, .many = many, .cache_reads = self.batch_reads });
}
pub fn commit(self: *Self, turn: Turn) !void {
    try turn.validate();
    if (turn.delivery.generation != self.generation or turn.view.revision != self.revision) return error.StaleTestTurn;
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        if (mutation.value) |value| try self.state.put(std.testing.allocator, mutation.key, value) else _ = self.state.remove(mutation.key);
    };
    self.revision += 1;
    self.input += 1;
}
