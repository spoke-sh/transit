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
pub fn invalidate(self: *Self) void {
    self.valid = false;
    self.covers_all = false;
    self.last = null;
    self.observed_ms = null;
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
    if (self.covers_all) self.last = self.wheel.maxEvent();
    if (self.wheel.len == 0 and !self.covers_all) self.valid = false;
}

/// Maintain the verified earliest prefix across one newly scheduled event.
/// Events beyond a partial prefix update the durable count without eviction;
/// events inside a full prefix evict the resident maximum to tighten `last`.
pub fn insert(self: *Self, before: ?pages.Reference, after: ?pages.Reference, before_scheduled: u64, event: Wheel.Event) void {
    if (!self.matches(before, before_scheduled)) return;
    const next_scheduled = std.math.add(u64, before_scheduled, 1) catch {
        self.valid = false;
        return;
    };
    if (self.covers_all) {
        if (self.wheel.hasCapacity()) {
            _ = self.wheel.insert(event) catch {
                self.valid = false;
                return;
            };
            if (self.last == null or Wheel.Event.less(self.last.?, event)) self.last = event;
            self.root = after;
            self.scheduled = next_scheduled;
            self.covers_all = true;
            return;
        }
        const max_active = self.wheel.maxActive() orelse {
            self.valid = false;
            return;
        };
        if (Wheel.Event.less(event, max_active.event)) {
            self.wheel.cancel(max_active.handle) catch {
                self.valid = false;
                return;
            };
            _ = self.wheel.insert(event) catch {
                self.valid = false;
                return;
            };
            self.last = self.wheel.maxEvent();
        } else {
            self.last = max_active.event;
        }
        self.root = after;
        self.scheduled = next_scheduled;
        self.covers_all = false;
        if (self.last == null) self.valid = false;
        return;
    }
    const bound = self.last orelse {
        self.valid = false;
        return;
    };
    if (!Wheel.Event.less(bound, event)) {
        if (self.wheel.hasCapacity()) {
            _ = self.wheel.insert(event) catch {
                self.valid = false;
                return;
            };
        } else {
            const max_active = self.wheel.maxActive() orelse {
                self.valid = false;
                return;
            };
            if (Wheel.Event.less(event, max_active.event)) {
                self.wheel.cancel(max_active.handle) catch {
                    self.valid = false;
                    return;
                };
                _ = self.wheel.insert(event) catch {
                    self.valid = false;
                    return;
                };
                self.last = self.wheel.maxEvent();
            } else {
                self.last = max_active.event;
            }
        }
    }
    self.root = after;
    self.scheduled = next_scheduled;
    self.covers_all = self.wheel.len == self.scheduled;
    if (self.last == null and !self.covers_all) self.valid = false;
}

pub fn earliest(self: *const Self, root: ?pages.Reference, scheduled: u64) ?Wheel.Event {
    if (!self.matches(root, scheduled) or self.wheel.len == 0) return null;
    return self.wheel.earliestAny();
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
