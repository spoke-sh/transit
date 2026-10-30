//! Paged Queue backlog, FIFO heads and deadline directories. All roots returned
//! here are private until the log owner publishes payload and state together.
//! Resident caches and operation buffers are independent of durable row count.
const std = @import("std");
const p = @import("transit_protocol");
const q = p.StreamQueue;
const f = @import("transit_fuze");
const Store = @import("TreeStore.zig");
const pages = Store.pages;
const Keys = @import("OrderedKeyIndex.zig");
const Bitmap = @import("BitmapDirectory.zig");
const Tack = @import("Tack.zig");
const Item = @import("QueueItem.zig");
const Batch = @import("LogBatch.zig");
const Declaration = @import("LogDeclaration.zig");
const Records = @import("LogPartitionRecord.zig");
const Schedule = @import("QueueSchedule.zig");
const Run = @import("QueueTimeRun.zig");
const Self = @This();

pub const Root = struct {
    next_offset: u64,
    items: ?pages.Reference,
    sidecars: ?pages.Reference,
    keys: ?pages.Reference,
    eligible: Schedule.Root,
    deadlines: Schedule.Root,
    timer_next: Run.Kind,
    scheduled: u64,
    active: u64,
    blocked: u64,
    terminal: u64,

    pub const empty: Root = .{ .next_offset = 0, .items = null, .sidecars = null, .keys = null, .eligible = .empty, .deadlines = .empty, .timer_next = .visible, .scheduled = 0, .active = 0, .blocked = 0, .terminal = 0 };
    pub fn validate(self: Root) !void {
        try self.eligible.validate();
        try self.deadlines.validate();
        if ((self.next_offset == 0) != (self.items == null) or (self.items == null) != (self.sidecars == null) or
            (self.scheduled != 0 and !self.eligible.hasSources()) or (self.active != 0 and !self.deadlines.hasSources()) or
            self.terminal > self.next_offset or self.active > self.next_offset - self.terminal or
            self.blocked > self.next_offset - self.terminal - self.active or
            self.scheduled > self.next_offset - self.terminal - self.active - self.blocked) return error.InvalidQueueRoot;
        if (self.keys != null and self.next_offset == self.terminal) return error.InvalidQueueRoot;
    }
};

pub const Head = struct {
    first: u64,
    last: u64,
    pub fn encode(self: Head) ![32]u8 {
        if (self.first > self.last or self.last == std.math.maxInt(u64)) return error.InvalidQueueHead;
        var bytes: [32]u8 = @splat(0);
        std.mem.writeInt(u64, bytes[0..8], self.first, .big);
        std.mem.writeInt(u64, bytes[8..16], self.last, .big);
        return bytes;
    }
    pub fn decode(bytes: [32]u8) !Head {
        const result: Head = .{ .first = std.mem.readInt(u64, bytes[0..8], .big), .last = std.mem.readInt(u64, bytes[8..16], .big) };
        if (!std.mem.eql(u8, &bytes, &try result.encode())) return error.InvalidQueueHead;
        return result;
    }
};

store: *Store,
scratch: *std.heap.ArenaAllocator,
bitmap: *Bitmap,
container: *Bitmap.Container,
key_buffer: []u8,
timer_workspace: *Schedule.Workspace,
timer_seed: q.Partition,
timer_read_work: u32 = 4096,
visibility: ?*@import("QueueVisibilityCache.zig") = null,

fn tree(self: Self) pages.Tree(Store) {
    return .{ .store = self.store };
}
fn keys(self: Self) Keys {
    return .{ .store = self.store };
}
pub fn timers(self: Self, kind: Run.Kind) Schedule {
    return .{ .store = self.store, .scratch = self.scratch, .workspace = self.timer_workspace, .seed = self.timer_seed, .kind = kind };
}
pub fn timedKey(at_ms: u64, offset: u64) !pages.Key {
    if (offset == std.math.maxInt(u64)) return error.InvalidQueueItem;
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], at_ms, .big);
    std.mem.writeInt(u64, bytes[8..16], offset, .big);
    return pages.Key.init(&bytes);
}
pub fn item(self: Self, root: Root, offset: u64) !Item {
    return self.itemAt(root.items, root.next_offset, offset);
}
fn itemAt(self: Self, items: ?pages.Reference, next_offset: u64, offset: u64) !Item {
    if (offset >= next_offset) return error.QueueOffsetOutOfRange;
    const value = try self.tree().get(items, try Records.integerKey(offset)) orelse return error.QueueItemMissing;
    defer _ = self.scratch.reset(.retain_capacity);
    const result = try Records.valueDecode(Item, self.scratch.allocator(), value);
    if (result.offset != offset or result.batch_next > next_offset or (result.next_key != null and result.next_key.? >= next_offset)) return error.InvalidQueueItem;
    return result;
}
fn putItem(self: Self, root: *Root, value: Item) !void {
    try value.validate();
    root.items = try self.tree().put(root.items, try Records.integerKey(value.offset), try Records.valueEncode(value));
}
pub fn sidecar(self: Self, root: Root, value: Item) !Tack {
    return self.sidecarAt(root.sidecars, value);
}
fn sidecarAt(self: Self, sidecars: ?pages.Reference, value: Item) !Tack {
    const encoded = try self.tree().get(sidecars, try Records.integerKey(value.batch_next)) orelse return error.QueueSidecarMissing;
    const result = try Tack.decode(encoded.data[0..encoded.len]);
    if (result.next != value.batch_next or result.first > value.offset or result.next <= value.offset) return error.QueueSidecarConflict;
    return result;
}
pub fn state(self: Self, root: Root, value: Item) !Tack.State {
    return self.stateAt(root.sidecars, value);
}
fn stateAt(self: Self, sidecars: ?pages.Reference, value: Item) !Tack.State {
    const manifest = try self.sidecarAt(sidecars, value);
    var found: ?Tack.State = null;
    for (manifest.states, 0..) |bitmap, index| if (try self.bitmap.contains(bitmap, value.offset)) {
        if (found != null) return error.QueueSidecarOverlap;
        found = @fromBackingInt(@intCast(index));
    };
    const result = found orelse return error.QueueStateConflict;
    try value.requireState(result);
    return result;
}

pub fn timerBasis(root: Root) @import("QueueTimeMerge.zig").Basis {
    return .{ .items = root.items, .sidecars = root.sidecars, .next_offset = root.next_offset };
}
pub const TimerFilter = struct {
    index: Self,
    /// A retained scheduling entry may become stale, but missing or inconsistent
    /// frozen state is corruption, never permission to discard it. Matching a
    /// timer establishes neither current authorization nor FIFO eligibility.
    pub fn keep(self: @This(), basis: @import("QueueTimeMerge.zig").Basis, kind: @import("QueueTimeRun.zig").Kind, event: @import("QueueTimeRun.zig").Event) !bool {
        try basis.validate();
        try event.validate(kind);
        const value = try self.index.itemAt(basis.items, basis.next_offset, event.offset);
        const current = try self.index.stateAt(basis.sidecars, value);
        if (event.epoch > value.epoch) return error.InvalidQueueSchedule;
        if (event.epoch < value.epoch) return false;
        return switch (kind) {
            .visible => current == .available and value.blocked == .none and event.at_ms == value.visible_ms,
            .lease => current == .acquired and event.at_ms == value.lease.?.expires_ms,
        };
    }
};
fn putSidecar(self: Self, root: *Root, value: Tack) !void {
    var buffer: [Tack.encoded_bytes]u8 = undefined;
    root.sidecars = try self.tree().put(root.sidecars, try Records.integerKey(value.next), try pages.Value.init(try value.encode(&buffer)));
}
pub fn head(self: Self, root: Root, key: []const u8) !?Head {
    const encoded = try self.keys().get(root.keys, key) orelse return null;
    const value = try Head.decode(encoded);
    if (value.last >= root.next_offset) return error.InvalidQueueHead;
    return value;
}
fn schedule(self: Self, root: *Root, value: Item) !void {
    if (value.lease != null or value.blocked != .none) return error.QueueStateConflict;
    root.eligible = try self.timers(.visible).append(root.eligible, .{ .at_ms = value.visible_ms, .offset = value.offset, .epoch = value.epoch });
    root.scheduled = try std.math.add(u64, root.scheduled, 1);
}
fn unschedule(self: Self, root: *Root, value: Item) !void {
    const event: Run.Event = .{ .at_ms = value.visible_ms, .offset = value.offset, .epoch = value.epoch };
    if (!try self.timers(.visible).contains(root.eligible, event, timerBasis(root.*), self.timer_read_work, TimerFilter{ .index = self })) return error.QueueNotEligible;
    if (root.scheduled == 0) return error.InvalidQueueSchedule;
    root.scheduled -= 1;
}
fn changeState(self: Self, root: *Root, value: Item, from: Tack.State, to: Tack.State, accepted: p.DataLifecycle.Position) !void {
    var manifest = try self.sidecar(root.*, value);
    try accepted.validate();
    // Multiple offsets in one private claim batch share its eventual WAL
    // position. The log owner separately requires its next original position.
    if (accepted.partition != manifest.accepted.partition or accepted.next_lsn < manifest.accepted.next_lsn) return error.QueueSidecarConflict;
    manifest.states = try manifest.transition(self.bitmap, value.offset, from, to, self.container);
    manifest.accepted = accepted;
    try self.putSidecar(root, manifest);
}
fn addDeadline(self: Self, root: *Root, value: Item) !void {
    const lease = value.lease orelse return error.InvalidQueueItem;
    root.deadlines = try self.timers(.lease).append(root.deadlines, .{ .at_ms = lease.expires_ms, .offset = value.offset, .epoch = value.epoch });
}
fn removeDeadline(self: Self, root: *Root, value: Item) !void {
    const lease = value.lease orelse return error.InvalidQueueItem;
    if (!try self.timers(.lease).contains(root.deadlines, .{ .at_ms = lease.expires_ms, .offset = value.offset, .epoch = value.epoch }, timerBasis(root.*), self.timer_read_work, TimerFilter{ .index = self })) return error.InvalidQueueSchedule;
}

pub fn acquire(self: Self, before: Root, offset: u64, claim: q.Claim, policy: p.StreamQueueDeclaration.Queue, now: @import("LogTime.zig").Sample, accepted: p.DataLifecycle.Position) !Root {
    try before.validate();
    const previous = try self.item(before, offset);
    const original = (try self.sidecar(before, previous)).target;
    try claim.target.validate();
    if (claim.target.partition != original.partition or !std.meta.eql(claim.target.interpretation.object, original.interpretation.object) or
        claim.target.interpretation.revision < original.interpretation.revision or
        (claim.target.interpretation.revision == original.interpretation.revision and !std.meta.eql(claim.target, original))) return error.LogPartitionConflict;
    const next_item = try previous.acquire(try self.state(before, previous), claim, policy, now);
    var next = before;
    try self.unschedule(&next, previous);
    try self.changeState(&next, previous, .available, .acquired, accepted);
    try self.putItem(&next, next_item);
    try self.addDeadline(&next, next_item);
    next.active = try std.math.add(u64, next.active, 1);
    try next.validate();
    return next;
}

/// ACK advances exactly one canonical FIFO head. The owner obtains key bytes
/// from this offset's original payload and declaration, not from client input.
fn advanceHead(self: Self, root: *Root, value: Item, key: []const u8) !void {
    const previous = try self.head(root.*, key) orelse return error.InvalidQueueHead;
    if (previous.first != value.offset) return error.QueueNotEligible;
    if (value.next_key) |offset| {
        if (previous.last < offset) return error.InvalidQueueHead;
        const successor = try self.item(root.*, offset);
        if (try self.state(root.*, successor) != .available or successor.attempts != 0) return error.InvalidQueueHead;
        root.keys = try self.keys().put(root.keys, key, try (Head{ .first = offset, .last = previous.last }).encode());
        try self.schedule(root, successor);
    } else {
        if (previous.last != value.offset) return error.InvalidQueueHead;
        root.keys = try self.keys().remove(root.keys, key);
    }
}

pub fn settle(self: Self, before: Root, request: q.Settlement, policy: p.StreamQueueDeclaration.Queue, now: @import("LogTime.zig").Sample, accepted: p.DataLifecycle.Position, canonical_key: ?[]const u8) !Root {
    try before.validate();
    const previous = try self.item(before, request.lease.offset);
    const change = try previous.settle(try self.state(before, previous), request, policy, now);
    var next = before;
    try self.removeDeadline(&next, previous);
    if (change.state != .acquired) {
        try self.changeState(&next, previous, .acquired, change.state, accepted);
        next.active -= 1;
        if (change.state == .acked) {
            next.terminal = try std.math.add(u64, next.terminal, 1);
            if (policy.ordering == .key_fifo) try self.advanceHead(&next, previous, canonical_key orelse return error.InvalidQueueHead);
        } else if (change.item.blocked != .none) {
            next.blocked = try std.math.add(u64, next.blocked, 1);
        } else try self.schedule(&next, change.item);
    } else try self.addDeadline(&next, change.item);
    try self.putItem(&next, change.item);
    try next.validate();
    return next;
}

pub fn expire(self: Self, before: Root, offset: u64, policy: p.StreamQueueDeclaration.Queue, now: @import("LogTime.zig").Sample, accepted: p.DataLifecycle.Position) !Root {
    try before.validate();
    const previous = try self.item(before, offset);
    const changed = try previous.expire(try self.state(before, previous), policy, now);
    var next = before;
    try self.removeDeadline(&next, previous);
    try self.changeState(&next, previous, .acquired, .available, accepted);
    try self.putItem(&next, changed);
    next.active -= 1;
    if (changed.blocked != .none) {
        next.blocked = try std.math.add(u64, next.blocked, 1);
    } else try self.schedule(&next, changed);
    try next.validate();
    return next;
}

/// One bounded append batch constructs every offset, state bit, and FIFO link.
/// Equal keys use canonical collation bytes, never hashes or truncated prefixes.
pub fn enqueue(self: Self, before: Root, declaration: *const Declaration.Owned, receipt: q.AppendReceipt, payload: []const u8) !Root {
    try before.validate();
    try receipt.validate();
    if (receipt.append.kind != .queue or declaration.definition.configuration.policy != .queue or receipt.first != before.next_offset) return error.QueueStateConflict;
    try Batch.validate(payload, declaration, receipt.append, self.scratch, self.key_buffer);
    var next = before;
    next.next_offset = receipt.next;
    var manifest: Tack = .{ .target = receipt.append.target, .segment = receipt.accepted.next_lsn, .first = receipt.first, .next = receipt.next, .accepted = receipt.accepted, .states = @splat(.empty) };
    var offset = receipt.first;
    while (offset < receipt.next) {
        const prefix = offset >> 16;
        self.container.clear();
        while (offset < receipt.next and offset >> 16 == prefix) : (offset += 1) _ = self.container.set(@truncate(offset));
        manifest.states[0] = try self.bitmap.replace(manifest.states[0], prefix, self.container);
    }
    try self.putSidecar(&next, manifest);
    var rows = try Batch.Iterator.init(payload, declaration.definition.schema, .queue, receipt.append.rows);
    const policy = declaration.definition.configuration.policy.queue;
    while (try rows.next()) |encoded| {
        _ = self.scratch.reset(.retain_capacity);
        const current = try Item.initial(receipt.first + encoded.ordinal, receipt.next, encoded.visible_ms);
        var eligible = true;
        if (policy.key_column) |column_id| {
            const row = try encoded.decode(self.scratch.allocator(), declaration.definition.schema, receipt.append.operation);
            const ci = try declaration.definition.schema.index(column_id);
            const column = declaration.definition.schema.columns[ci];
            const key = try f.Collation.encodeSortKey(row.cells[ci], column.type, column.collation, self.key_buffer);
            var changed: Head = .{ .first = current.offset, .last = current.offset };
            if (try self.head(next, key)) |previous| {
                var tail = try self.item(next, previous.last);
                if (tail.next_key != null) return error.InvalidQueueHead;
                tail.next_key = current.offset;
                try self.putItem(&next, tail);
                changed.first = previous.first;
                eligible = false;
            }
            next.keys = try self.keys().put(next.keys, key, try changed.encode());
        }
        try self.putItem(&next, current);
        if (eligible) try self.schedule(&next, current);
    }
    _ = self.scratch.reset(.retain_capacity);
    try next.validate();
    return next;
}

/// Inspect the earliest scheduled head only. An acquired or delayed FIFO head
/// prevents its successors from entering this directory, without hiding other
/// keys. No durable backlog is loaded into a resident array.
pub fn firstEligible(self: Self, root: Root, earliest_ms: u64) !?Item {
    return self.eligibleAfter(root, null, earliest_ms);
}

/// One bounded directory step for an original claim selection. The exclusive
/// cursor belongs to the frozen root; it does not mutate or skip a FIFO head.
pub fn eligibleAfter(self: Self, root: Root, after: ?pages.Key, earliest_ms: u64) !?Item {
    try root.validate();
    if (root.scheduled == 0) return null;
    if (self.visibility) |cache| {
        const cursor = if (after) |key| try scheduledEvent(key) else null;
        switch (cache.lookup(root.items, root.scheduled, earliest_ms, cursor)) {
            .miss => {},
            .empty => return null,
            .event => |event| return try self.scheduledItem(root, event),
        }
    }
    const event = try self.timers(.visible).nextEvent(root.eligible, try timerCursor(after), timerBasis(root), self.timer_read_work, TimerFilter{ .index = self }) orelse {
        if (after == null) return error.InvalidQueueSchedule;
        return null;
    };
    if (event.at_ms > earliest_ms) return null;
    return try self.scheduledItem(root, .{ .at_ms = event.at_ms, .offset = event.offset });
}

const Timer = @import("QueueTimingWheel.zig");
fn scheduledEvent(key: pages.Key) !Timer.Event {
    if (key.len != 16) return error.InvalidQueueSchedule;
    return .{ .at_ms = std.mem.readInt(u64, key.data[0..8], .big), .offset = std.mem.readInt(u64, key.data[8..16], .big) };
}
fn timerCursor(after: ?pages.Key) !?Run.Event {
    const event = try scheduledEvent(after orelse return null);
    return .{ .at_ms = event.at_ms, .offset = event.offset, .epoch = std.math.maxInt(u64) };
}
fn scheduledItem(self: Self, root: Root, event: Timer.Event) !Item {
    const value = try self.item(root, event.offset);
    if (value.visible_ms != event.at_ms or value.blocked != .none or try self.state(root, value) != .available) return error.InvalidQueueSchedule;
    return value;
}

/// Once per selection, load at most `steps` prefix entries and advance at most
/// `steps` wheel units. An incomplete cascade falls back to the paged directory.
/// The resident prefix and time horizon never limit the durable population.
pub fn prepareVisibility(self: Self, root: Root, earliest_ms: u64, steps: u32) !void {
    const cache = self.visibility orelse return;
    try root.validate();
    if (steps == 0) return error.InvalidQueueTimerBudget;
    if (!cache.matches(root.items, root.scheduled) or earliest_ms < cache.wheel.now_ms) {
        cache.reset(root.items, root.scheduled, earliest_ms);
        const limit = @min(cache.wheel.entries.len, steps, root.scheduled);
        var after: ?pages.Key = null;
        while (cache.wheel.len < limit) {
            const scheduled = try self.timers(.visible).nextEvent(root.eligible, try timerCursor(after), timerBasis(root), self.timer_read_work, TimerFilter{ .index = self }) orelse return error.InvalidQueueSchedule;
            const event: Timer.Event = .{ .at_ms = scheduled.at_ms, .offset = scheduled.offset };
            _ = try self.scheduledItem(root, event);
            _ = cache.wheel.insert(event) catch {
                // Generation-exhausted slots stay retired. Cache capacity may
                // fall without reducing the durable queue's capacity.
                cache.valid = false;
                return;
            };
            cache.last = event;
            after = try timedKey(event.at_ms, event.offset);
        }
        cache.covers_all = cache.wheel.len == root.scheduled;
        cache.valid = true;
    }
    cache.observed_ms = null;
    if ((try cache.wheel.advance(earliest_ms, steps)).complete) cache.observed_ms = earliest_ms;
}

pub fn firstExpired(self: Self, root: Root, earliest_ms: u64) !?Item {
    const value = try self.deadlineAfter(root, null) orelse return null;
    return if (value.lease.?.expires_ms <= earliest_ms) value else null;
}

/// One exact active lease from a frozen deadline directory, for bounded cache
/// loading. The caller must discard its cursor if that directory changes.
pub fn deadlineAfter(self: Self, root: Root, after: ?pages.Key) !?Item {
    try root.validate();
    if (root.active == 0) return null;
    const event = try self.timers(.lease).nextEvent(root.deadlines, try timerCursor(after), timerBasis(root), self.timer_read_work, TimerFilter{ .index = self }) orelse {
        if (after == null) return error.InvalidQueueSchedule;
        return null;
    };
    const value = try self.item(root, event.offset);
    if (try self.state(root, value) != .acquired or value.lease.?.expires_ms != event.at_ms or value.epoch != event.epoch) return error.InvalidQueueSchedule;
    return value;
}
