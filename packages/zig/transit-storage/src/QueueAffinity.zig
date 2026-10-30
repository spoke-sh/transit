//! Disposable full-key FIFO head cache. One serialized writer publishes while
//! concurrent readers copy immutable values. A miss always falls back to the
//! paged owner; neither residency nor a hit grants Queue execution authority.
const std = @import("std");
const pages = @import("TreeStore.zig").pages;
const Self = @This();
pub const Atomic = std.atomic.Value(u64);
pub const max_key_bytes = 256;
const busy: u64 = 1 << 31;
const readers_mask = busy - 1;
const generation_mask: u64 = @as(u64, std.math.maxInt(u32)) << 32;

pub const Slot = struct {
    state: Atomic align(64) = .init(0),
    // Only the serialized writer accesses mapped and the replacement cursor.
    mapped: bool = false,
    root: pages.Reference = undefined,
    key: [max_key_bytes]u8 = undefined,
    length: u16 = 0,
    value: [32]u8 = undefined,
};

buckets: []Atomic,
slots: []Slot,
next: usize = 0,

/// All memory is caller-owned and must outlive every reader and writer. Init
/// and destruction require quiescence; clear may overlap readers.
pub fn init(buckets: []Atomic, slots: []Slot) !Self {
    if (buckets.len == 0 or slots.len == 0 or slots.len >= std.math.maxInt(u32)) return error.InvalidQueueAffinityBudget;
    for (buckets) |*entry| entry.* = .init(0);
    for (slots) |*slot| slot.* = .{};
    return .{ .buckets = buckets, .slots = slots };
}
fn bucket(self: *const Self, key: []const u8) usize {
    return @intCast(std.hash.Wyhash.hash(0x5155455545484541, key) % self.buckets.len);
}
fn slotIndex(handle: u64) usize {
    return @as(u32, @truncate(handle)) - 1;
}
fn pin(self: *const Self, handle: u64) ?*Slot {
    if (handle == 0) return null;
    const slot = &self.slots[slotIndex(handle)];
    // A bounded attempt may miss under contention; it never waits for readers
    // or gives an obsolete generation access to a replacement payload.
    for (0..4) |_| {
        const state = slot.state.load(.acquire);
        if (state & generation_mask != handle & generation_mask or state & busy != 0 or state & readers_mask == readers_mask) return null;
        if (slot.state.cmpxchgStrong(state, state + 1, .acq_rel, .acquire) == null) return slot;
    }
    return null;
}
fn unpin(slot: *Slot) void {
    const before = slot.state.fetchSub(1, .release);
    std.debug.assert(before & readers_mask != 0 and before & busy == 0);
}

pub fn get(self: *const Self, root: ?pages.Reference, key: []const u8) ?[32]u8 {
    const basis = root orelse return null;
    if (key.len == 0 or key.len > max_key_bytes) return null;
    const at = self.bucket(key);
    const handle = self.buckets[at].load(.acquire);
    const slot = self.pin(handle) orelse return null;
    defer unpin(slot);
    if (self.buckets[at].load(.acquire) != handle or !std.meta.eql(basis, slot.root) or
        key.len != slot.length or !std.mem.eql(u8, key, slot.key[0..slot.length])) return null;
    return slot.value;
}

/// Single-writer operation. Pinned, busy or permanently exhausted slots are
/// skipped in one bounded pass. Insertion failure changes no durable state.
pub fn put(self: *Self, root: ?pages.Reference, key: []const u8, value: [32]u8) bool {
    const basis = root orelse return false;
    if (key.len == 0 or key.len > max_key_bytes) return false;
    const at = self.bucket(key);
    for (0..self.slots.len) |_| {
        const index = self.next;
        self.next = if (index + 1 == self.slots.len) 0 else index + 1;
        const slot = &self.slots[index];
        if (slot.mapped) continue;
        const state = slot.state.load(.acquire);
        if (state & ~generation_mask != 0 or state & generation_mask == generation_mask) continue;
        const generation = (state & generation_mask) + (@as(u64, 1) << 32);
        if (slot.state.cmpxchgStrong(state, generation | busy, .acq_rel, .acquire) != null) continue;
        slot.root = basis;
        @memcpy(slot.key[0..key.len], key);
        slot.length = @intCast(key.len);
        slot.value = value;
        slot.mapped = true;
        slot.state.store(generation, .release);
        const handle = generation | @as(u64, @intCast(index + 1));
        const previous = self.buckets[at].swap(handle, .acq_rel);
        if (previous != 0) self.slots[slotIndex(previous)].mapped = false;
        return true;
    }
    return false;
}

/// Single-writer invalidation. Existing pinned readers may finish; their slots
/// remain immutable until their last pin is released. No grace-period wait.
pub fn clear(self: *Self) void {
    for (self.buckets) |*entry| {
        const previous = entry.swap(0, .acq_rel);
        if (previous != 0) self.slots[slotIndex(previous)].mapped = false;
    }
}

test "queue affinity full keys roots and bounded saturation preserve misses" {
    const t = std.testing;
    var buckets: [1]Atomic = undefined;
    var slots: [2]Slot = undefined;
    var cache = try Self.init(&buckets, &slots);
    const first: pages.Reference = .{ .digest = @splat(1), .location = @splat(2) };
    var second = first;
    second.digest[0] = 3;
    try t.expect(cache.get(first, "same-prefix-A") == null);
    try t.expect(cache.put(first, "same-prefix-A", @splat(4)));
    try t.expectEqual(@as([32]u8, @splat(4)), cache.get(first, "same-prefix-A").?);
    try t.expect(cache.get(second, "same-prefix-A") == null);
    try t.expect(cache.get(first, "same-prefix-B") == null);
    try t.expect(cache.put(first, "same-prefix-B", @splat(5)));
    try t.expect(cache.get(first, "same-prefix-A") == null);
    try t.expectEqual(@as([32]u8, @splat(5)), cache.get(first, "same-prefix-B").?);
    const too_long: [max_key_bytes + 1]u8 = @splat('x');
    try t.expect(!cache.put(first, &too_long, @splat(6)));
    try t.expect(cache.get(first, &too_long) == null);
    cache.clear();
    try t.expect(cache.get(first, "same-prefix-B") == null);
    // A single resident slot remains usable; replacing it requires invalidation
    // first. The production owner reserves spare slots instead of waiting.
    cache = try Self.init(&buckets, slots[0..1]);
    try t.expect(cache.put(first, "a", @splat(1)));
    try t.expect(!cache.put(second, "b", @splat(2)));
    try t.expectEqual(@as([32]u8, @splat(1)), cache.get(first, "a").?);
    cache.clear();
    try t.expect(cache.put(second, "b", @splat(2)));
}

test "queue affinity reader pins fence reuse stale handles and generation exhaustion" {
    const t = std.testing;
    var buckets: [1]Atomic = undefined;
    var slots: [2]Slot = undefined;
    var cache = try Self.init(&buckets, &slots);
    const root: pages.Reference = .{ .digest = @splat(1), .location = @splat(2) };
    try t.expect(cache.put(root, "a", @splat(1)));
    const old = buckets[0].load(.acquire);
    const held = cache.pin(old).?;
    try t.expect(cache.put(root, "b", @splat(2)));
    try t.expect(!cache.put(root, "c", @splat(3)));
    try t.expectEqual(@as([32]u8, @splat(1)), held.value);
    unpin(held);
    try t.expect(cache.put(root, "c", @splat(3)));
    try t.expect(cache.pin(old) == null);
    try t.expectEqual(@as([32]u8, @splat(3)), cache.get(root, "c").?);
    cache.clear();
    // Exhausted generations cannot wrap to an earlier handle, even after all
    // readers have released and the table has been invalidated.
    for (&slots) |*slot| slot.state.store(generation_mask, .release);
    try t.expect(!cache.put(root, "d", @splat(4)));
    try t.expect(cache.pin(old) == null);
}

test "queue affinity concurrent readers observe only exact immutable root and key values" {
    const t = std.testing;
    const Shared = struct {
        cache: *Self,
        start: std.atomic.Value(bool) = .init(false),
        failed: std.atomic.Value(bool) = .init(false),
        hits: std.atomic.Value(usize) = .init(0),
        fn root(id: u8) pages.Reference {
            return .{ .digest = @splat(id), .location = @splat(id + 1) };
        }
        fn read(self: *@This()) void {
            while (!self.start.load(.acquire)) std.atomic.spinLoopHint();
            for (0..20000) |i| {
                const id: u8 = @intCast(i % 4 + 1);
                const key = if (i % 2 == 0) "collision-first" else "collision-second";
                if (self.cache.get(root(id), key)) |value| {
                    const expected: u8 = id + (if (i % 2 == 0) @as(u8, 10) else 20);
                    if (!std.mem.allEqual(u8, &value, expected)) self.failed.store(true, .release);
                    _ = self.hits.fetchAdd(1, .monotonic);
                }
            }
        }
    };
    var buckets: [1]Atomic = undefined; // Force every publication to collide.
    var slots: [3]Slot = undefined;
    var cache = try Self.init(&buckets, &slots);
    var shared: Shared = .{ .cache = &cache };
    var threads: [4]std.Thread = undefined;
    var started: usize = 0;
    defer {
        shared.start.store(true, .release);
        for (threads[0..started]) |thread| thread.join();
    }
    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, Shared.read, .{&shared});
        started += 1;
    }
    shared.start.store(true, .release);
    for (0..20000) |i| {
        const id: u8 = @intCast(i % 4 + 1);
        const even = i % 2 == 0;
        _ = cache.put(Shared.root(id), if (even) "collision-first" else "collision-second", @splat(id + (if (even) @as(u8, 10) else 20)));
        if (i % 31 == 0) cache.clear();
    }
    for (threads) |thread| thread.join();
    started = 0;
    try t.expect(!shared.failed.load(.acquire));
    // Verify a deterministic post-contention hit without requiring a particular
    // operating-system schedule to overlap reader and writer CPU slices.
    cache.clear();
    try t.expect(cache.put(Shared.root(1), "collision-first", @splat(11)));
    try t.expectEqual(@as([32]u8, @splat(11)), cache.get(Shared.root(1), "collision-first").?);
    for (slots) |slot| try t.expectEqual(@as(u64, 0), slot.state.load(.acquire) & ~generation_mask);
}
