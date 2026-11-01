//! Verify a prepared log successor using the owning storage graph. Resident
//! work follows graph depth, never the number of durable records or segments.
const std = @import("std");
const c = @import("root.zig");
const s = c.storage;
const Graph = c.DirectStorageGraph;
const Frame = struct { work: Graph.Work, scope: ?[32]u8 = null, complete: bool = false };
const Verifier = struct {
    allocator: std.mem.Allocator,
    objects: s.TransitObjectStore.ObjectStore,
    frames: std.ArrayList(Frame) = .empty,
    // Graph.step has an explicit maximum of three children per step. This is
    // a transient fan-out bound, not a bound on collection size or graph depth.
    children: [3]Graph.Work = undefined,
    child_count: usize = 0,
    buffer: []u8,

    pub fn enqueue(self: *@This(), work: Graph.Work) !void {
        if (self.child_count == self.children.len) return error.InvalidTransactionGraph;
        self.children[self.child_count] = work;
        self.child_count += 1;
    }
    pub fn visited(self: *@This(), scope: [32]u8) !bool {
        const current = self.frames.items.len - 1;
        for (self.frames.items[0..current]) |frame| if (frame.scope) |ancestor| {
            if (std.mem.eql(u8, &scope, &ancestor)) return true;
        };
        self.frames.items[current].scope = scope;
        return false;
    }
    pub fn mark(self: *@This(), key: []const u8, expected: s.TransitObjectStore.ObjectMeta) !void {
        const found = try self.objects.head(key) orelse return error.TransactionObjectMissing;
        if (found.size != expected.size or !std.mem.eql(u8, &found.sha256, &expected.sha256)) return error.InvalidTransactionGraph;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        var offset: u64 = 0;
        while (offset < expected.size) {
            const length: u32 = @intCast(@min(self.buffer.len, expected.size - offset));
            const bytes = try self.objects.getRange(key, offset, length, self.buffer);
            if (bytes.len != length) return error.InvalidTransactionGraph;
            hash.update(bytes);
            offset += length;
        }
        if (!std.mem.eql(u8, &hash.finalResult(), &expected.sha256)) return error.InvalidTransactionGraph;
    }
};

/// allocator belongs to the transaction's resident budget. Exhaustion leaves
/// preparation and original accepted work intact; the caller can still abort.
pub fn verifyLog(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, log: s.TransitLog.Log, preparation: s.LogTransaction.Preparation) !void {
    var verifier: Verifier = .{ .allocator = allocator, .objects = objects, .buffer = try allocator.alloc(u8, 64 * 1024) };
    defer allocator.free(verifier.buffer);
    defer verifier.frames.deinit(allocator);
    var index = try s.TreeStore.init(allocator, objects, 1);
    defer index.deinit();
    try verifier.frames.append(allocator, .{ .work = .{ .log_root = .{ .root = preparation.successor, .archive = preparation.predecessor.archive } } });
    while (verifier.frames.items.len != 0) {
        const at = verifier.frames.items.len - 1;
        if (verifier.frames.items[at].complete) {
            _ = verifier.frames.pop();
            continue;
        }
        // enqueue buffers children until step returns, so no list growth can
        // invalidate the current cursor or its ancestor verification scopes.
        verifier.child_count = 0;
        verifier.frames.items[at].complete = try Graph.step(allocator, &index, log, &verifier.frames.items[at].work, &verifier);
        var next = verifier.child_count;
        while (next != 0) {
            next -= 1;
            try verifier.frames.append(allocator, .{ .work = verifier.children[next] });
        }
    }
}
