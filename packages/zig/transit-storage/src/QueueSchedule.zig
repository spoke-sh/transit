//! Private durable scheduling roots: a bounded delta buffer, paged pending
//! chunks and size-tiered sorted runs. Only the Queue WAL owner publishes them.
const std = @import("std");
const p = @import("transit_protocol");
const Store = @import("TreeStore.zig");
const pages = Store.pages;
const Run = @import("QueueTimeRun.zig");
const Buffer = @import("QueueTimeBuffer.zig");
const Directory = @import("QueueTimeDirectory.zig");
const Merge = @import("QueueTimeMerge.zig");
const Records = @import("LogPartitionRecord.zig");
const Self = @This();

pub const Slot = struct {
    bucket: u64,
    level: u8,
    pub fn validate(self: Slot) !void {
        if (self.bucket > std.math.maxInt(u64) >> Run.bucket_bits or self.level > 63) return error.InvalidQueueSchedule;
    }
    pub fn key(self: Slot) !pages.Key {
        try self.validate();
        var bytes: [9]u8 = undefined;
        std.mem.writeInt(u64, bytes[0..8], self.bucket, .big);
        bytes[8] = self.level;
        return pages.Key.init(&bytes);
    }
    pub fn decode(value: pages.Key) !Slot {
        if (value.len != 9) return error.InvalidQueueSchedule;
        const result: Slot = .{ .bucket = std.mem.readInt(u64, value.data[0..8], .big), .level = value.data[8] };
        try result.validate();
        return result;
    }
};
pub const Work = struct {
    slot: Slot,
    mode: enum { promote, sweep },
    merge: Merge.State,
};
pub const Sweep = struct {
    /// Change detection only. No source root is dereferenced through this hash.
    epoch: [32]u8,
    after: ?Slot,
    complete: bool,
};
pub const Root = struct {
    active: ?p.DataLifecycle.Content,
    active_rows: u16,
    pending: ?pages.Reference,
    pending_chunks: u64,
    levels: ?pages.Reference,
    level_count: u64,
    work: ?Work,
    serial: u64,
    sweep: ?Sweep,
    pending_since_sweep: u8,
    pub const empty: Root = .{ .active = null, .active_rows = 0, .pending = null, .pending_chunks = 0, .levels = null, .level_count = 0, .work = null, .serial = 1, .sweep = null, .pending_since_sweep = 0 };
    pub fn validate(self: Root) !void {
        if ((self.active_rows == 0) != (self.active == null) or self.active_rows > Buffer.max_rows or
            (self.pending_chunks == 0) != (self.pending == null) or (self.level_count == 0) != (self.levels == null) or
            self.serial == 0 or self.pending_since_sweep > 8) return error.InvalidQueueSchedule;
        if (self.active) |content| {
            try content.validate();
            if (content.bytes != Buffer.header_bytes + @as(u64, self.active_rows) * 24) return error.InvalidQueueSchedule;
        }
        if (self.sweep) |sweep| {
            if (std.mem.allEqual(u8, &sweep.epoch, 0)) return error.InvalidQueueSchedule;
            if (sweep.after) |slot| try slot.validate();
        }
        if (self.work) |work| {
            try work.slot.validate();
            try work.merge.validate();
            if (work.merge.bucket != work.slot.bucket or work.merge.sources[0].rows == 0 or
                (work.mode == .promote and ((work.slot.level == 0) != (work.merge.sources[1].rows == 0))) or
                (work.mode == .sweep and (work.merge.sources[1].rows != 0 or self.sweep == null or
                    self.sweep.?.complete or !std.meta.eql(self.sweep.?.after, @as(?Slot, work.slot))))) return error.InvalidQueueSchedule;
        }
    }
};
pub const Workspace = struct {
    pending: [Buffer.max_rows]Run.Event,
    buffer_bytes: [Buffer.max_bytes]u8,
    merge: Merge.Workspace,
};
store: *Store,
scratch: *std.heap.ArenaAllocator,
workspace: *Workspace,
seed: p.StreamQueue.Partition,
kind: Run.Kind,

fn tree(self: Self) pages.Tree(Store) {
    return .{ .store = self.store };
}
fn require(self: Self, root: Root) !void {
    try self.seed.validate();
    try root.validate();
    if (self.seed.interpretation.revision != 1) return error.InvalidQueueSchedule;
    if (root.work) |work| if (!std.meta.eql(work.merge.seed, self.seed) or work.merge.kind != self.kind) return error.InvalidQueueSchedule;
}
fn directory(self: Self, bucket: u64) Directory {
    return .{ .store = self.store, .seed = self.seed, .kind = self.kind, .bucket = bucket };
}
pub fn pendingKey(chunk: Run.Descriptor) !pages.Key {
    try chunk.validate();
    var bytes: [32]u8 = undefined;
    const first = try Directory.eventKey(chunk.first);
    @memcpy(bytes[0..24], first.slice());
    std.mem.writeInt(u64, bytes[24..32], chunk.serial, .big);
    return pages.Key.init(&bytes);
}
fn decodePending(self: Self, entry: pages.Entry) !Run.Descriptor {
    const chunk = try Run.Descriptor.decode(entry.value);
    if (!std.meta.eql(chunk.seed, self.seed) or chunk.kind != self.kind or
        !std.meta.eql(entry.key, try pendingKey(chunk))) return error.InvalidQueueSchedule;
    return chunk;
}
fn decodeLevel(self: Self, slot: Slot, value: pages.Value) !Directory.Root {
    defer _ = self.scratch.reset(.retain_capacity);
    const root = try Records.valueDecode(Directory.Root, self.scratch.allocator(), value);
    if (root.rows == 0 or root.first.?.bucket() != slot.bucket or root.last.?.bucket() != slot.bucket) return error.InvalidQueueSchedule;
    return root;
}
fn loadBuffer(self: Self, root: Root) !Buffer {
    if (root.active) |content| {
        const buffer = try Buffer.load(self.seed, self.kind, self.store.store, content, &self.workspace.buffer_bytes, &self.workspace.pending);
        if (buffer.len != root.active_rows) return error.InvalidQueueSchedule;
        return buffer;
    }
    return Buffer.init(self.seed, self.kind, &self.workspace.pending);
}
fn saveBuffer(self: Self, root: *Root, buffer: *const Buffer) !void {
    root.active = if (buffer.len == 0) null else try buffer.stage(self.store.store, &self.workspace.buffer_bytes);
    root.active_rows = @intCast(buffer.len);
}
fn seal(self: Self, root: *Root, buffer: *Buffer) !void {
    var start: usize = 0;
    while (start < buffer.len) {
        var end = start + 1;
        while (end < buffer.len and buffer.entries[end].bucket() == buffer.entries[start].bucket()) end += 1;
        const serial = root.serial;
        root.serial = std.math.add(u64, serial, 1) catch return error.QueueTimerSerialExhausted;
        root.pending_chunks = try std.math.add(u64, root.pending_chunks, 1);
        const chunk = blk: {
            defer _ = self.scratch.reset(.retain_capacity);
            break :blk try Run.stage(self.scratch.allocator(), self.store.store, self.seed, self.kind, serial, buffer.entries[start..end], &self.workspace.merge.encoded);
        };
        const key = try pendingKey(chunk);
        if (try self.tree().get(root.pending, key) != null) return error.InvalidQueueSchedule;
        root.pending = try self.tree().put(root.pending, key, try chunk.encode());
        start = end;
    }
    buffer.clear();
    root.active = null;
    root.active_rows = 0;
}

/// A full delta seals by time bucket. Pending cardinality is paged, not bounded
/// by a resident fan-in array; provider/candidate budgets still apply.
pub fn append(self: Self, before: Root, event: Run.Event) !Root {
    try self.require(before);
    var next = before;
    var buffer = try self.loadBuffer(before);
    if (buffer.len == Buffer.max_rows) try self.seal(&next, &buffer);
    try buffer.append(event);
    if (buffer.len == Buffer.max_rows) try self.seal(&next, &buffer) else try self.saveBuffer(&next, &buffer);
    try next.validate();
    return next;
}

fn putLevel(self: Self, root: *Root, slot: Slot, run: Directory.Root) !void {
    if (run.rows == 0 or run.first.?.bucket() != slot.bucket or run.last.?.bucket() != slot.bucket or
        try self.tree().get(root.levels, try slot.key()) != null) return error.InvalidQueueSchedule;
    root.levels = try self.tree().put(root.levels, try slot.key(), try Records.valueEncode(run));
    root.level_count = try std.math.add(u64, root.level_count, 1);
}
fn removeLevel(self: Self, root: *Root, slot: Slot) !void {
    if (root.level_count == 0) return error.InvalidQueueSchedule;
    root.levels = try self.tree().remove(root.levels, try slot.key());
    root.level_count -= 1;
}
fn promote(self: Self, root: *Root, slot: Slot, incoming: Directory.Root, basis: Merge.Basis) !void {
    if (incoming.rows == 0) return;
    if (try self.tree().get(root.levels, try slot.key())) |value| {
        if (slot.level == 63) return error.QueueTimerLevelExhausted;
        const existing = try self.decodeLevel(slot, value);
        try self.removeLevel(root, slot);
        root.work = .{ .slot = .{ .bucket = slot.bucket, .level = slot.level + 1 }, .mode = .promote, .merge = try Merge.State.init(self.seed, self.kind, slot.bucket, basis, .{ existing, incoming }) };
    } else try self.putLevel(root, slot, incoming);
}
fn epoch(basis: Merge.Basis) ![32]u8 {
    try basis.validate();
    const encoded = try Records.valueEncode(basis);
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded.slice(), &result, .{});
    return result;
}

/// One private maintenance unit: bounded merge progress, one pending promotion,
/// or one finite-sweep transition. New appends may extend pending work without
/// replacing frozen merge inputs. No clock or current grant is retained here.
pub fn maintain(self: Self, before: Root, basis: Merge.Basis, budget: u16, filter: anytype) !?Root {
    try self.require(before);
    try basis.validate();
    if (budget == 0 or budget > Run.max_rows) return error.InvalidQueueTimerBudget;
    var next = before;
    if (before.work) |work| {
        var progress = work;
        progress.merge = try (Merge{ .store = self.store, .scratch = self.scratch, .workspace = &self.workspace.merge }).step(work.merge, before.serial, budget, filter);
        if (progress.merge.output.rows != work.merge.output.rows) next.serial = std.math.add(u64, before.serial, 1) catch return error.QueueTimerSerialExhausted;
        if (progress.merge.complete) {
            next.work = null;
            if (progress.mode == .promote) try self.promote(&next, progress.slot, progress.merge.output, basis) else if (progress.merge.output.rows != 0) try self.putLevel(&next, progress.slot, progress.merge.output);
        } else next.work = progress;
    } else if (before.sweep == null or (before.sweep.?.complete and !std.mem.eql(u8, &before.sweep.?.epoch, &try epoch(basis)))) {
        next.sweep = .{ .epoch = try epoch(basis), .after = null, .complete = false };
        // Bounded in-place filtering does not retain borrowed decode memory.
        var buffer = try self.loadBuffer(before);
        var kept: usize = 0;
        for (buffer.rows()) |event| if (try filter.keep(basis, self.kind, event)) {
            buffer.entries[kept] = event;
            kept += 1;
        };
        if (kept != buffer.len) {
            buffer.len = kept;
            try self.saveBuffer(&next, &buffer);
        }
    } else if (before.pending_chunks != 0 and (before.pending_since_sweep < 8 or before.sweep.?.complete)) {
        const entry = (try self.tree().scan(before.pending, null)).entries[0] orelse return error.InvalidQueueSchedule;
        const chunk = try self.decodePending(entry);
        const run = try self.directory(chunk.bucket).append(.empty, chunk);
        next.pending = try self.tree().remove(before.pending, entry.key);
        next.pending_chunks -= 1;
        next.pending_since_sweep = @min(8, before.pending_since_sweep + 1);
        const slot: Slot = .{ .bucket = chunk.bucket, .level = 0 };
        if (try self.tree().get(next.levels, try slot.key()) != null) {
            try self.promote(&next, slot, run, basis);
        } else {
            // A pending chunk must be filtered even when this level is empty;
            // otherwise an already completed sweep could leave stale new runs.
            next.work = .{ .slot = slot, .mode = .promote, .merge = try Merge.State.init(self.seed, self.kind, slot.bucket, basis, .{ run, .empty }) };
        }
    } else if (!before.sweep.?.complete) {
        const entry = (try self.tree().scan(before.levels, if (before.sweep.?.after) |slot| try slot.key() else null)).entries[0];
        next.pending_since_sweep = 0;
        if (entry) |value| {
            const slot = try Slot.decode(value.key);
            const run = try self.decodeLevel(slot, value.value);
            try self.removeLevel(&next, slot);
            next.sweep.?.after = slot;
            next.work = .{ .slot = slot, .mode = .sweep, .merge = try Merge.State.init(self.seed, self.kind, slot.bucket, basis, .{ run, .empty }) };
        } else next.sweep.?.complete = true;
    } else return null;
    try next.validate();
    return next;
}

const Budget = struct {
    remaining: u32,
    fn charge(self: *Budget) !void {
        if (self.remaining == 0) return error.QueueTimerReadBudget;
        self.remaining -= 1;
    }
};
fn afterCursor(event: Run.Event, after: ?Run.Event) bool {
    return after == null or Run.Event.less(after.?, event);
}
fn beforeBest(event: Run.Event, best: ?Run.Event) bool {
    return best == null or Run.Event.less(event, best.?);
}
fn inspectChunk(self: Self, chunk: Run.Descriptor, after: ?Run.Event, basis: Merge.Basis, budget: *Budget, best: *?Run.Event, filter: anytype) !void {
    if (!afterCursor(chunk.last, after) or !beforeBest(chunk.first, best.*)) return;
    try budget.charge();
    const rows = blk: {
        defer _ = self.scratch.reset(.retain_capacity);
        break :blk try Run.load(self.scratch.allocator(), self.store.store, chunk, &self.workspace.merge.output);
    };
    for (rows) |event| {
        if (!beforeBest(event, best.*)) break;
        if (!afterCursor(event, after)) continue;
        try budget.charge();
        if (try filter.keep(basis, self.kind, event)) {
            best.* = event;
            break;
        }
    }
}
fn inspectRun(self: Self, run: Directory.Root, after: ?Run.Event, basis: Merge.Basis, budget: *Budget, best: *?Run.Event, filter: anytype) !void {
    if (run.rows == 0 or !afterCursor(run.last.?, after) or !beforeBest(run.first.?, best.*)) return;
    var cursor = after;
    var expected: ?u64 = null;
    var first_row: ?u64 = null;
    var chunks: u64 = 0;
    while (true) {
        try budget.charge();
        const entry = try self.directory(run.first.?.bucket()).find(run, cursor) orelse {
            if (expected != null and expected.? != run.rows) return error.InvalidQueueSchedule;
            if (first_row == 0 and chunks != run.chunks) return error.InvalidQueueSchedule;
            return;
        };
        if (expected) |ordinal| if (entry.first_row != ordinal) return error.InvalidQueueSchedule;
        if (first_row == null) first_row = entry.first_row;
        chunks = try std.math.add(u64, chunks, 1);
        if (!beforeBest(entry.chunk.first, best.*)) return;
        const previous = best.*;
        try self.inspectChunk(entry.chunk, after, basis, budget, best, filter);
        if (!std.meta.eql(previous, best.*)) return;
        cursor = entry.chunk.last;
        expected = entry.first_row + entry.chunk.rows;
    }
}

/// Return the earliest matching event only after all possibly earlier sources
/// have been checked. Directory entries, chunk decodes and examined candidates
/// consume work; exhaustion refuses rather than reporting an empty schedule.
pub fn nextEvent(self: Self, root: Root, after: ?Run.Event, basis: Merge.Basis, work: u32, filter: anytype) !?Run.Event {
    try self.require(root);
    try basis.validate();
    if (work == 0) return error.InvalidQueueTimerBudget;
    var budget: Budget = .{ .remaining = work };
    var best: ?Run.Event = null;
    const buffer = try self.loadBuffer(root);
    for (buffer.rows()) |event| {
        if (!afterCursor(event, after)) continue;
        try budget.charge();
        if (try filter.keep(basis, self.kind, event)) {
            best = event;
            break;
        }
    }
    if (root.work) |merge| for (merge.merge.sources) |run| try self.inspectRun(run, after, basis, &budget, &best, filter);
    const first_bucket = if (after) |event| event.bucket() else 0;
    var pending_after: ?pages.Key = null;
    if (first_bucket != 0) {
        var bytes: [32]u8 = @splat(255);
        std.mem.writeInt(u64, bytes[0..8], (first_bucket << Run.bucket_bits) - 1, .big);
        pending_after = try pages.Key.init(&bytes);
    }
    var pending_seen: u64 = 0;
    while (root.pending != null) {
        try budget.charge();
        const entry = (try self.tree().scan(root.pending, pending_after)).entries[0] orelse {
            if (first_bucket == 0 and pending_seen != root.pending_chunks) return error.InvalidQueueSchedule;
            break;
        };
        pending_seen = try std.math.add(u64, pending_seen, 1);
        const chunk = try self.decodePending(entry);
        if (!beforeBest(chunk.first, best)) break;
        try self.inspectChunk(chunk, after, basis, &budget, &best, filter);
        pending_after = entry.key;
    }
    var level_after: ?pages.Key = if (first_bucket == 0) null else try (Slot{ .bucket = first_bucket - 1, .level = 63 }).key();
    var levels_seen: u64 = 0;
    while (root.levels != null) {
        try budget.charge();
        const entry = (try self.tree().scan(root.levels, level_after)).entries[0] orelse {
            if (first_bucket == 0 and levels_seen != root.level_count) return error.InvalidQueueSchedule;
            break;
        };
        levels_seen = try std.math.add(u64, levels_seen, 1);
        const slot = try Slot.decode(entry.key);
        if (best != null and slot.bucket > best.?.bucket()) break;
        const run = try self.decodeLevel(slot, entry.value);
        try self.inspectRun(run, after, basis, &budget, &best, filter);
        level_after = entry.key;
    }
    return best;
}
