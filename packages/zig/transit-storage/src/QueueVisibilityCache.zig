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

/// The owning deterministic transition has proved that eligibility is unchanged.
/// Rebinding a cache is private work, not publication; readers still require the
/// exact resulting item root, count and clock observation before using it.
pub fn retain(self: *Self, before: ?pages.Reference, after: ?pages.Reference, scheduled: u64) void {
    if (self.matches(before, scheduled)) self.root = after;
}

/// Carry a verified earliest prefix across removal of one known scheduled
/// event. Nothing is inserted and the original suffix boundary remains valid.
/// Exhausting a partial prefix requires another bounded durable fill.
pub fn remove(self: *Self, before: ?pages.Reference, after: ?pages.Reference, scheduled: u64, event: Wheel.Event) void {
    if (!self.matches(before, scheduled) or scheduled == 0) return;
    var found = false;
    for (self.wheel.entries, 0..) |entry, index| {
        if ((entry.state == .waiting or entry.state == .ready) and std.meta.eql(entry.event, event)) {
            self.wheel.cancel(.{ .index = @intCast(index), .generation = entry.generation }) catch {
                self.valid = false;
                return;
            };
            found = true;
            break;
        }
    }
    if (!found and (self.covers_all or (self.last != null and !Wheel.Event.less(self.last.?, event)))) {
        self.valid = false;
        return;
    }
    self.root = after;
    self.scheduled = scheduled - 1;
    self.covers_all = self.wheel.len == self.scheduled;
    if (self.wheel.len == 0 and !self.covers_all) self.valid = false;
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
