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
const Self = @This();

pub const Root = struct {
    next_offset: u64,
    items: ?pages.Reference,
    sidecars: ?pages.Reference,
    keys: ?pages.Reference,
    eligible: ?pages.Reference,
    deadlines: ?pages.Reference,
    scheduled: u64,
    active: u64,
    blocked: u64,
    terminal: u64,

    pub const empty: Root = .{ .next_offset = 0, .items = null, .sidecars = null, .keys = null, .eligible = null, .deadlines = null, .scheduled = 0, .active = 0, .blocked = 0, .terminal = 0 };
    pub fn validate(self: Root) !void {
        if ((self.next_offset == 0) != (self.items == null) or (self.items == null) != (self.sidecars == null) or
            (self.scheduled == 0) != (self.eligible == null) or (self.active == 0) != (self.deadlines == null) or
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

fn tree(self: Self) pages.Tree(Store) {
    return .{ .store = self.store };
}
fn keys(self: Self) Keys {
    return .{ .store = self.store };
}
pub fn timedKey(at_ms: u64, offset: u64) !pages.Key {
    if (offset == std.math.maxInt(u64)) return error.InvalidQueueItem;
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], at_ms, .big);
    std.mem.writeInt(u64, bytes[8..16], offset, .big);
    return pages.Key.init(&bytes);
}
pub fn item(self: Self, root: Root, offset: u64) !Item {
    if (offset >= root.next_offset) return error.QueueOffsetOutOfRange;
    const value = try self.tree().get(root.items, try Records.integerKey(offset)) orelse return error.QueueItemMissing;
    defer _ = self.scratch.reset(.retain_capacity);
    const result = try Records.valueDecode(Item, self.scratch.allocator(), value);
    if (result.offset != offset or result.batch_next > root.next_offset or (result.next_key != null and result.next_key.? >= root.next_offset)) return error.InvalidQueueItem;
    return result;
}
fn putItem(self: Self, root: *Root, value: Item) !void {
    try value.validate();
    root.items = try self.tree().put(root.items, try Records.integerKey(value.offset), try Records.valueEncode(value));
}
pub fn sidecar(self: Self, root: Root, value: Item) !Tack {
    const encoded = try self.tree().get(root.sidecars, try Records.integerKey(value.batch_next)) orelse return error.QueueSidecarMissing;
    const result = try Tack.decode(encoded.data[0..encoded.len]);
    if (result.next != value.batch_next or result.first > value.offset or result.next <= value.offset) return error.QueueSidecarConflict;
    return result;
}
pub fn state(self: Self, root: Root, value: Item) !Tack.State {
    const manifest = try self.sidecar(root, value);
    var found: ?Tack.State = null;
    for (manifest.states, 0..) |bitmap, index| if (try self.bitmap.contains(bitmap, value.offset)) {
        if (found != null) return error.QueueSidecarOverlap;
        found = @fromBackingInt(@intCast(index));
    };
    const result = found orelse return error.QueueStateConflict;
    try value.requireState(result);
    return result;
}
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
    const key = try timedKey(value.visible_ms, value.offset);
    if (try self.tree().get(root.eligible, key) != null) return error.QueueStateConflict;
    root.eligible = try self.tree().put(root.eligible, key, try pages.Value.init(&.{}));
    root.scheduled = try std.math.add(u64, root.scheduled, 1);
}
fn unschedule(self: Self, root: *Root, value: Item) !void {
    const key = try timedKey(value.visible_ms, value.offset);
    const found = try self.tree().get(root.eligible, key) orelse return error.QueueNotEligible;
    if (found.len != 0 or root.scheduled == 0) return error.InvalidQueueSchedule;
    root.eligible = try self.tree().remove(root.eligible, key);
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
    const key = try timedKey(lease.expires_ms, value.offset);
    if (try self.tree().get(root.deadlines, key) != null) return error.InvalidQueueSchedule;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, lease.epoch, .big);
    root.deadlines = try self.tree().put(root.deadlines, key, try pages.Value.init(&bytes));
}
fn removeDeadline(self: Self, root: *Root, value: Item) !void {
    const lease = value.lease orelse return error.InvalidQueueItem;
    const key = try timedKey(lease.expires_ms, value.offset);
    const found = try self.tree().get(root.deadlines, key) orelse return error.InvalidQueueSchedule;
    if (found.len != 8 or std.mem.readInt(u64, found.data[0..8], .big) != lease.epoch) return error.InvalidQueueSchedule;
    root.deadlines = try self.tree().remove(root.deadlines, key);
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
    try root.validate();
    const page = try self.tree().scan(root.eligible, null);
    const entry = page.entries[0] orelse return null;
    if (entry.key.len != 16 or entry.value.len != 0) return error.InvalidQueueSchedule;
    const at = std.mem.readInt(u64, entry.key.data[0..8], .big);
    const offset = std.mem.readInt(u64, entry.key.data[8..16], .big);
    if (at > earliest_ms) return null;
    const value = try self.item(root, offset);
    if (value.visible_ms != at or value.blocked != .none or try self.state(root, value) != .available) return error.InvalidQueueSchedule;
    return value;
}

pub fn firstExpired(self: Self, root: Root, earliest_ms: u64) !?Item {
    try root.validate();
    const page = try self.tree().scan(root.deadlines, null);
    const entry = page.entries[0] orelse return null;
    if (entry.key.len != 16 or entry.value.len != 8) return error.InvalidQueueSchedule;
    const at = std.mem.readInt(u64, entry.key.data[0..8], .big);
    if (at > earliest_ms) return null;
    const value = try self.item(root, std.mem.readInt(u64, entry.key.data[8..16], .big));
    if (try self.state(root, value) != .acquired or value.lease.?.expires_ms != at or
        value.epoch != std.mem.readInt(u64, entry.value.data[0..8], .big)) return error.InvalidQueueSchedule;
    return value;
}
