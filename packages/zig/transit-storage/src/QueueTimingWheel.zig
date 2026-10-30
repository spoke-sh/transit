//! Volatile visibility/retry wakeups. Eight radix-256 levels cover u64
//! milliseconds; empty time ranges are skipped without ticking through them.
//! This wheel owns no leases, durable state, clock source or authority.
const std = @import("std");
const Self = @This();
const none = std.math.maxInt(u32);
const levels = 8;
const slots = 256;
const ready_bucket = levels * slots;

pub const Event = struct {
    at_ms: u64,
    offset: u64,
    pub fn less(a: Event, b: Event) bool {
        return a.at_ms < b.at_ms or (a.at_ms == b.at_ms and a.offset < b.offset);
    }
};
pub const Handle = struct { index: u32, generation: u64 };
pub const Entry = struct {
    generation: u64 = 0,
    state: enum { free, waiting, ready, retired } = .free,
    event: Event = undefined,
    previous: u32 = none,
    next: u32 = none,
    bucket: u16 = ready_bucket,
};
pub const Ready = struct { handle: Handle, event: Event };
pub const Progress = struct { complete: bool, steps: u32 };

entries: []Entry,
heads: [levels * slots]u32 = @splat(none),
occupied: [levels][4]u64 = @splat(@splat(0)),
ready: u32 = none,
free: u32 = none,
active_bucket: ?u16 = null,
now_ms: u64,
len: u32 = 0,

/// First initialization only; entries and this owner outlive all handles.
pub fn init(entries: []Entry, now_ms: u64) !Self {
    if (entries.len == 0 or entries.len >= none) return error.InvalidQueueTimerBudget;
    @memset(entries, .{});
    var result: Self = .{ .entries = entries, .now_ms = now_ms };
    result.clear(now_ms);
    return result;
}

/// Discards speculative work but preserves generations. An exhausted slot is
/// permanently retired rather than wrapping a handle back to an earlier use.
pub fn clear(self: *Self, now_ms: u64) void {
    self.heads = @splat(none);
    self.occupied = @splat(@splat(0));
    self.ready = none;
    self.free = none;
    self.active_bucket = null;
    self.now_ms = now_ms;
    self.len = 0;
    var i = self.entries.len;
    while (i != 0) {
        i -= 1;
        const entry = &self.entries[i];
        entry.previous = none;
        if (entry.generation == std.math.maxInt(u64)) {
            entry.state = .retired;
            entry.next = none;
        } else {
            entry.state = .free;
            entry.next = self.free;
            self.free = @intCast(i);
        }
    }
}

pub fn insert(self: *Self, event: Event) !Handle {
    if (self.free == none) return error.QueueTimerCapacityExceeded;
    const id = self.free;
    const entry = &self.entries[id];
    self.free = entry.next;
    std.debug.assert(entry.state == .free and entry.generation != std.math.maxInt(u64));
    entry.generation += 1;
    entry.event = event;
    self.place(id);
    self.len += 1;
    return .{ .index = id, .generation = entry.generation };
}

fn place(self: *Self, id: u32) void {
    const entry = &self.entries[id];
    const at = entry.event.at_ms;
    const bucket: u16 = if (at <= self.now_ms) ready_bucket else blk: {
        const level: u6 = @intCast((63 - @clz(at ^ self.now_ms)) / 8);
        const slot: u16 = @intCast((at >> (level * 8)) & 255);
        break :blk @as(u16, level) * slots + slot;
    };
    const head = if (bucket == ready_bucket) &self.ready else &self.heads[bucket];
    entry.previous = none;
    entry.next = head.*;
    entry.bucket = bucket;
    entry.state = if (bucket == ready_bucket) .ready else .waiting;
    if (head.* != none) self.entries[head.*].previous = id;
    head.* = id;
    if (bucket != ready_bucket) {
        const slot = bucket % slots;
        self.occupied[bucket / slots][slot / 64] |= @as(u64, 1) << @as(u6, @intCast(slot % 64));
    }
}

fn unlink(self: *Self, id: u32) void {
    const entry = &self.entries[id];
    const head = if (entry.bucket == ready_bucket) &self.ready else &self.heads[entry.bucket];
    if (entry.previous == none) head.* = entry.next else self.entries[entry.previous].next = entry.next;
    if (entry.next != none) self.entries[entry.next].previous = entry.previous;
    if (entry.bucket != ready_bucket and head.* == none) {
        const slot = entry.bucket % slots;
        self.occupied[entry.bucket / slots][slot / 64] &= ~(@as(u64, 1) << @as(u6, @intCast(slot % 64)));
    }
}

pub fn cancel(self: *Self, handle: Handle) !void {
    if (handle.index >= self.entries.len) return error.QueueTimerFenced;
    const entry = &self.entries[handle.index];
    if (entry.generation != handle.generation or (entry.state != .waiting and entry.state != .ready)) return error.QueueTimerFenced;
    self.unlink(handle.index);
    self.len -= 1;
    if (entry.generation == std.math.maxInt(u64)) {
        entry.state = .retired;
        entry.next = none;
    } else {
        entry.state = .free;
        entry.next = self.free;
        self.free = handle.index;
    }
}

const Boundary = struct { bucket: u16, at_ms: u64 };
/// Each occupied level shares the current higher prefix. The lowest occupied
/// slot therefore supplies its earliest boundary. At most 32 mask words are read.
fn nextBoundary(self: *const Self) ?Boundary {
    var result: ?Boundary = null;
    for (self.occupied, 0..) |words, level| {
        for (words, 0..) |word, ordinal| {
            if (word == 0) continue;
            const slot = ordinal * 64 + @ctz(word);
            const prefix = if (level == levels - 1) 0 else self.now_ms & (@as(u64, std.math.maxInt(u64)) << @as(u6, @intCast((level + 1) * 8)));
            const at = prefix | (@as(u64, slot) << @as(u6, @intCast(level * 8)));
            std.debug.assert(at >= self.now_ms);
            if (result == null or at < result.?.at_ms) result = .{ .bucket = @intCast(level * slots + slot), .at_ms = at };
            break;
        }
    }
    return result;
}

/// A boundary jump and each individual cascade count as one step. An incomplete
/// result is never evidence that no due event exists. Resumption needs the same
/// or later observation; authoritative time validation remains with the owner.
pub fn advance(self: *Self, now_ms: u64, budget: u32) !Progress {
    if (now_ms < self.now_ms) return error.QueueTimerTimeRegression;
    if (budget == 0) return error.InvalidQueueTimerBudget;
    var steps: u32 = 0;
    while (true) {
        if (self.active_bucket) |bucket| {
            const id = self.heads[bucket];
            if (id == none) {
                self.active_bucket = null;
                continue;
            }
            if (steps == budget) return .{ .complete = false, .steps = steps };
            self.unlink(id);
            self.place(id);
            steps += 1;
            continue;
        }
        const next = self.nextBoundary();
        if (next == null or next.?.at_ms > now_ms) {
            self.now_ms = now_ms;
            return .{ .complete = true, .steps = steps };
        }
        if (steps == budget) return .{ .complete = false, .steps = steps };
        self.now_ms = next.?.at_ms;
        self.active_bucket = next.?.bucket;
        steps += 1;
    }
}

/// Bounded selection over resident ready entries; insertion and cancellation
/// remain O(1). The caller separately validates durable eligibility and ordering.
pub fn earliestReady(self: *const Self, after: ?Event) ?Ready {
    var result: ?Ready = null;
    var id = self.ready;
    while (id != none) {
        const entry = self.entries[id];
        if ((after == null or Event.less(after.?, entry.event)) and (result == null or Event.less(entry.event, result.?.event)))
            result = .{ .handle = .{ .index = id, .generation = entry.generation }, .event = entry.event };
        id = entry.next;
    }
    return result;
}

test "queue timing wheel skips empty time ranges with bounded resumable cascades" {
    const t = std.testing;
    var entries: [12]Entry = undefined;
    var wheel = try Self.init(&entries, 0);
    const times = [_]u64{ 0, 1, 255, 256, 65535, 65536, 1 << 24, 1 << 32, 1 << 56, 1 << 63, std.math.maxInt(u64) };
    for (times, 0..) |at, offset| _ = try wheel.insert(.{ .at_ms = at, .offset = offset });
    var total: u32 = 0;
    while (true) {
        const progress = try wheel.advance(std.math.maxInt(u64), 1);
        try t.expect(progress.steps <= 1);
        total += progress.steps;
        if (total > 180) return error.FixtureBudget;
        if (progress.complete) break;
    }
    for (times, 0..) |at, offset| {
        const event = wheel.earliestReady(null).?;
        try t.expectEqualDeep(Event{ .at_ms = at, .offset = offset }, event.event);
        try wheel.cancel(event.handle);
    }
    try t.expect(wheel.earliestReady(null) == null);
    try t.expectEqual(@as(u32, 0), wheel.len);
}

test "queue timing wheel fences cancellation reuse clear and generation exhaustion" {
    const t = std.testing;
    var entries: [2]Entry = undefined;
    var wheel = try Self.init(&entries, 100);
    const first = try wheel.insert(.{ .at_ms = 100, .offset = 1 });
    const second = try wheel.insert(.{ .at_ms = 256, .offset = 2 });
    try t.expectError(error.QueueTimerCapacityExceeded, wheel.insert(.{ .at_ms = 0, .offset = 3 }));
    try wheel.cancel(first);
    const third = try wheel.insert(.{ .at_ms = 101, .offset = 3 });
    try t.expectEqual(first.index, third.index);
    try t.expectError(error.QueueTimerFenced, wheel.cancel(first));
    const before = wheel.now_ms;
    try t.expectError(error.QueueTimerTimeRegression, wheel.advance(99, 1));
    try t.expectError(error.InvalidQueueTimerBudget, wheel.advance(101, 0));
    try t.expectEqual(before, wheel.now_ms);
    try t.expect((try wheel.advance(101, 8)).complete);
    try t.expectEqual(@as(u64, 3), wheel.earliestReady(null).?.event.offset);
    wheel.clear(0);
    try t.expectError(error.QueueTimerFenced, wheel.cancel(second));
    try t.expectError(error.QueueTimerFenced, wheel.cancel(third));
    entries[0].generation = std.math.maxInt(u64);
    wheel.clear(0);
    _ = try wheel.insert(.{ .at_ms = 0, .offset = 4 });
    try t.expectError(error.QueueTimerCapacityExceeded, wheel.insert(.{ .at_ms = 0, .offset = 5 }));
    try t.expectEqual(.retired, entries[0].state);
}

test "queue timing wheel agrees with a finite reference through interleaved insert cancel and jumps" {
    const t = std.testing;
    var entries: [32]Entry = undefined;
    var wheel = try Self.init(&entries, 0);
    var expected: [32]?Ready = @splat(null);
    var seed: u64 = 421;
    var now: u64 = 0;
    for (0..3000) |step| {
        seed = seed *% 6364136223846793005 +% 1;
        if (step % 137 == 0) {
            wheel.clear(now);
            for (&expected) |*value| {
                if (value.*) |old| try t.expectError(error.QueueTimerFenced, wheel.cancel(old.handle));
                value.* = null;
            }
        } else if (seed % 3 == 0) {
            const position = (seed >> 8) % expected.len;
            if (expected[position]) |value| {
                try wheel.cancel(value.handle);
                try t.expectError(error.QueueTimerFenced, wheel.cancel(value.handle));
                expected[position] = null;
            }
        } else if (wheel.len < expected.len) {
            const event: Event = .{ .at_ms = if (seed & 16 == 0) now -| 1 else now +| (seed >> 32), .offset = step };
            const handle = try wheel.insert(event);
            try t.expect(expected[handle.index] == null);
            expected[handle.index] = .{ .event = event, .handle = handle };
        }
        now +|= if (step % 41 == 0) @as(u64, 1) << 56 else (seed >> 40);
        var spent: u32 = 0;
        while (true) {
            const progress = try wheel.advance(now, @intCast(seed % 3 + 1));
            spent += progress.steps;
            if (spent > 1024) return error.FixtureBudget;
            if (progress.complete) break;
        }
        var after: ?Event = null;
        while (true) {
            var next: ?Ready = null;
            for (expected) |optional| if (optional) |candidate| {
                if (candidate.event.at_ms <= now and (after == null or Event.less(after.?, candidate.event)) and
                    (next == null or Event.less(candidate.event, next.?.event))) next = candidate;
            };
            try t.expectEqualDeep(next, wheel.earliestReady(after));
            after = (next orelse break).event;
        }
    }
}
