const std = @import("std");
const t = std.testing;
const Cache = @import("QueueVisibilityCache.zig");
const Wheel = @import("QueueTimingWheel.zig");
const pages = @import("TreeStore.zig").pages;

fn reference(id: u8) pages.Reference {
    return .{ .digest = @splat(id) };
}

const events = [_]Wheel.Event{
    .{ .at_ms = 10, .offset = 4 },
    .{ .at_ms = 10, .offset = 8 },
    .{ .at_ms = 20, .offset = 2 },
    .{ .at_ms = 30, .offset = 1 },
    .{ .at_ms = 30, .offset = 3 },
};

// The oracle scans the complete population without using a wheel, root cache,
// prefix boundary or the implementation's comparator.
fn expected(active: [5]bool, now: u64, after: ?Wheel.Event) ?Wheel.Event {
    for (events, active) |event, present| {
        if (!present or event.at_ms > now) continue;
        if (after) |cursor| if (event.at_ms < cursor.at_ms or
            (event.at_ms == cursor.at_ms and event.offset <= cursor.offset)) continue;
        return event;
    }
    return null;
}

fn check(cache: *const Cache, root: pages.Reference, count: u64, active: [5]bool, now: u64) !void {
    for (0..events.len + 1) |cursor| {
        const after: ?Wheel.Event = if (cursor == 0) null else events[cursor - 1];
        const want = expected(active, now, after);
        switch (cache.lookup(root, count, now, after)) {
            .miss => {}, // A bounded hint is allowed to require durable lookup.
            .empty => try t.expect(want == null),
            .event => |event| try t.expectEqualDeep(want.?, event),
        }
    }
}

test "queue visibility prefix removal matches full population for every removal order" {
    var entries: [3]Wheel.Entry = undefined;
    for ([_]u64{ 5, 10, 25, 40 }) |now| {
        // Enumerate all 5! permutations, including removing uncached suffixes
        // before cached entries and removing in offset rather than time order.
        for (0..3125) |encoded| {
            var order: [5]usize = undefined;
            var used: [5]bool = @splat(false);
            var digits = encoded;
            var unique = true;
            for (&order) |*slot| {
                slot.* = digits % 5;
                digits /= 5;
                if (used[slot.*]) unique = false;
                used[slot.*] = true;
            }
            if (!unique) continue;
            var cache: Cache = .{ .wheel = try Wheel.init(&entries, now) };
            cache.reset(reference(1), 5, now);
            for (events[0..3]) |event| _ = try cache.wheel.insert(event);
            cache.last = events[2];
            cache.valid = true;
            cache.observed_ms = now;
            var active: [5]bool = @splat(true);
            var root = reference(1);
            var count: u64 = 5;
            try check(&cache, root, count, active, now);
            for (order, 0..) |offset, step| {
                const next = reference(@intCast(step + 2));
                cache.remove(root, next, count, events[offset]);
                active[offset] = false;
                count -= 1;
                try t.expectEqual(Cache.Lookup.miss, cache.lookup(root, count + 1, now, null));
                root = next;
                try check(&cache, root, count, active, now);
                try t.expectEqual(Cache.Lookup.miss, cache.lookup(root, count, now + 1, null));
            }
        }
    }
}

test "queue visibility rebinding requires exact basis and rejects missing known entries" {
    var entries: [3]Wheel.Entry = undefined;
    var cache: Cache = .{ .wheel = try Wheel.init(&entries, 40) };
    cache.reset(reference(1), 3, 40);
    for (events[0..3]) |event| _ = try cache.wheel.insert(event);
    cache.last = events[2];
    cache.valid = true;
    cache.covers_all = true;
    cache.observed_ms = 40;
    cache.retain(reference(2), reference(3), 3);
    cache.retain(reference(1), reference(3), 2);
    try t.expect(cache.matches(reference(1), 3));
    cache.retain(reference(1), reference(2), 3);
    try t.expect(!cache.matches(reference(1), 3));
    try t.expectEqualDeep(Cache.Lookup{ .event = events[0] }, cache.lookup(reference(2), 3, 40, null));
    cache.remove(reference(2), reference(3), 3, .{ .at_ms = 10, .offset = 5 });
    try t.expectEqual(Cache.Lookup.miss, cache.lookup(reference(3), 2, 40, null));
    try t.expect(!cache.valid);
}
