//! A bounded earliest prefix of one immutable eligibility directory. A missing
//! cache entry is never evidence that durable work is absent.
const std = @import("std");
const pages = @import("TreeStore.zig").pages;
const Wheel = @import("QueueTimingWheel.zig");
const Self = @This();

wheel: Wheel,
root: ?pages.Reference = null,
scheduled: u64 = 0,
valid: bool = false,
covers_all: bool = false,
last: ?Wheel.Event = null,
observed_ms: ?u64 = null,

pub fn matches(self: *const Self, root: ?pages.Reference, scheduled: u64) bool {
    return self.valid and std.meta.eql(self.root, root) and self.scheduled == scheduled;
}
pub fn reset(self: *Self, root: ?pages.Reference, scheduled: u64, now_ms: u64) void {
    self.wheel.clear(now_ms);
    self.root = root;
    self.scheduled = scheduled;
    self.valid = false;
    self.covers_all = false;
    self.last = null;
    self.observed_ms = null;
}
pub const Lookup = union(enum) { miss, empty, event: Wheel.Event };
pub fn lookup(self: *const Self, root: ?pages.Reference, scheduled: u64, now_ms: u64, after: ?Wheel.Event) Lookup {
    if (!self.matches(root, scheduled) or self.observed_ms == null or self.observed_ms.? != now_ms) return .miss;
    if (after) |cursor| if (self.last) |last| {
        if (!Wheel.Event.less(cursor, last)) return if (self.covers_all) .empty else .miss;
    };
    if (self.wheel.earliestReady(after)) |ready| return .{ .event = ready.event };
    if (self.covers_all) return .empty;
    // Every uncached event follows this prefix's last key. A known future
    // suffix proves absence at this time, but exhaustion of a due prefix does not.
    if (self.last) |last| if (last.at_ms > now_ms) return .empty;
    return .miss;
}
