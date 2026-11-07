const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const x = root.http.exchange;
const p = x.p;
const Exchange = x.Exchange;
const Turn = x.station.Turn;
const Pub = x.Publication;
const Map = std.AutoHashMapUnmanaged(p.Value, p.Value);
pub const Store = struct {
    state: Map = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    reads: usize = 0,
    fail_read: bool = false,
    pub fn deinit(self: *Store) void {
        self.state.deinit(t.allocator);
    }
    pub fn capture(self: *Store) !Turn {
        self.input += 1;
        self.reads = 0;
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read });
    }
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.reads += 1;
        if (self.fail_read) return error.Unavailable;
        return self.state.get(key);
    }
    pub fn commit(self: *Store, turn: Turn) !void {
        try turn.validate();
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.state.put(t.allocator, mutation.key, value) else _ = self.state.remove(mutation.key);
        };
        self.revision += 1;
    }
    fn create(self: *Store, policy: Pub.Limits) !Pub {
        var turn = try self.capture();
        const pubn = try Pub.create(&turn, .exchange, std.math.maxInt(u64), policy);
        try self.commit(turn);
        return pubn;
    }
    fn stage(self: *Store, pubn: Pub, id: u64, bytes: []const u8) !Pub.Spec {
        const spec = try Pub.Digest.of(7, bytes);
        var turn = try self.capture();
        try t.expectEqual(.changed, try pubn.begin(&turn, id, spec));
        try self.commit(turn);
        for (0..spec.chunks()) |i| {
            turn = try self.capture();
            const part = bytes[i * Pub.chunk_bytes ..][0..try spec.size(@intCast(i))];
            try t.expectEqual(.changed, try pubn.append(&turn, id, @intCast(i), part));
            try t.expectEqual(.duplicate, try pubn.append(&turn, id, @intCast(i), part));
            try t.expect(self.reads <= 3);
            try self.commit(turn);
        }
        return spec;
    }
};
pub fn segment(store: *Store, ex: Exchange, ordinal: u32, kind: u32, bytes: []const u8) !void {
    const spec = try Pub.Digest.of(1, bytes);
    var turn = try store.capture();
    _ = try ex.beginSegment(&turn, ordinal, kind, spec);
    try store.commit(turn);
    for (0..spec.chunks()) |i| {
        turn = try store.capture();
        _ = try ex.append(&turn, ordinal, @intCast(i), bytes[i * 256 ..][0..try spec.size(@intCast(i))]);
        try store.commit(turn);
    }
    turn = try store.capture();
    try t.expectEqual(.changed, try ex.sealSegment(&turn, ordinal));
    for (turn.decision.mutations) |slot| try t.expect(slot != null);
    try store.commit(turn);
}
