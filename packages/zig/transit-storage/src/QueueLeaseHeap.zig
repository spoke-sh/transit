//! Bounded volatile deadline ordering. Entries are exact accepted leases; a
//! cached deadline never proves current authority, clock time or durable state.
//! The partition owner binds this prefix to its immutable deadline directory.
const std = @import("std");
const p = @import("transit_protocol");
const Lease = p.StreamQueue.Lease;
const Self = @This();

entries: []Lease,
len: usize = 0,

pub fn clear(self: *Self) void {
    self.len = 0;
}
pub fn peek(self: *const Self) ?Lease {
    return if (self.len == 0) null else self.entries[0];
}
fn less(a: Lease, b: Lease) bool {
    return a.expires_ms < b.expires_ms or (a.expires_ms == b.expires_ms and a.offset < b.offset);
}
pub fn insert(self: *Self, lease: Lease) !void {
    try lease.validate();
    for (self.entries[0..self.len]) |current| {
        if (!std.meta.eql(current.target.interpretation.object, lease.target.interpretation.object) or
            current.target.partition != lease.target.partition or current.offset == lease.offset) return error.InvalidQueueSchedule;
    }
    if (self.len == self.entries.len) return error.QueueLeaseCapacityExceeded;
    var at = self.len;
    while (at != 0) {
        const parent = (at - 1) / 2;
        if (!less(lease, self.entries[parent])) break;
        self.entries[at] = self.entries[parent];
        at = parent;
    }
    self.entries[at] = lease;
    self.len += 1;
}

/// Renewal, reassignment and a different original claim all fence removal.
/// Call only after the owning accepted transition; failures leave the heap intact.
pub fn removeExact(self: *Self, expected: Lease) !void {
    try expected.validate();
    const first = self.peek() orelse return error.QueueLeaseFenced;
    if (!std.meta.eql(first, expected)) return error.QueueLeaseFenced;
    self.len -= 1;
    if (self.len == 0) return;
    const last = self.entries[self.len];
    var at: usize = 0;
    while (at * 2 + 1 < self.len) {
        var child = at * 2 + 1;
        if (child + 1 < self.len and less(self.entries[child + 1], self.entries[child])) child += 1;
        if (!less(self.entries[child], last)) break;
        self.entries[at] = self.entries[child];
        at = child;
    }
    self.entries[at] = last;
}

fn fixture(offset: u64, expires: u64) Lease {
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    return .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(5) }, .partition = 0 },
        .claim = .{ .scope = scope, .principal = 1, .operation = 10 },
        .offset = offset,
        .epoch = 1,
        .attempt = 1,
        .expires_ms = expires,
    };
}

test "queue lease heap orders exact deadlines and fences stale removals without allocation" {
    const t = std.testing;
    var entries: [4]Lease = undefined;
    var heap: Self = .{ .entries = &entries };
    for ([_]Lease{ fixture(3, 300), fixture(2, 100), fixture(0, 100), fixture(1, 200) }) |lease| try heap.insert(lease);
    try t.expectError(error.QueueLeaseCapacityExceeded, heap.insert(fixture(4, 50)));
    try t.expectError(error.InvalidQueueSchedule, heap.insert(fixture(0, 90)));
    const original = heap.peek().?;
    var foreign = original;
    foreign.target.partition = 1;
    try t.expectError(error.QueueLeaseFenced, heap.removeExact(foreign));
    var stale = original;
    stale.epoch += 1;
    try t.expectError(error.QueueLeaseFenced, heap.removeExact(stale));
    stale = original;
    stale.expires_ms += 1;
    try t.expectError(error.QueueLeaseFenced, heap.removeExact(stale));
    stale = original;
    stale.claim.operation += 1;
    try t.expectError(error.QueueLeaseFenced, heap.removeExact(stale));
    try t.expectEqual(@as(usize, 4), heap.len);
    for ([_]Lease{ fixture(0, 100), fixture(2, 100), fixture(1, 200), fixture(3, 300) }) |lease| {
        try t.expectEqualDeep(lease, heap.peek().?);
        try heap.removeExact(lease);
    }
    try t.expect(heap.peek() == null);
    try t.expectError(error.QueueLeaseFenced, heap.removeExact(original));
    for (0..100) |_| {
        try heap.insert(original);
        heap.clear();
    }
}
