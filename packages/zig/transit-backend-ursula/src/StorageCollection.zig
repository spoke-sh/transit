//! Resumable physical mark/sweep. Accepted authority roots select ownership;
//! this private ledger records verified work, never execution permissions.
const std = @import("std");
const core = @import("transit_core");
const a = @import("root.zig");
const c = core.catalog;
const Self = @This();
pub const State = struct {
    definition: core.protocol.Growth.Definition,
    position: u64,
    phase: enum { mark, wait, sweep, deleting, complete },
    aborted: bool = false,
    cut: core.growing.Head,
    inventory_end: u64,
    grace_until_ms: u64,
    roots: core.StorageRoots,
    walk: ?core.StorageWalk = null,
    owner: core.StorageRoots.Owner = .current,
    protected_bytes: struct { current: u64 = 0, captured: u64 = 0, history: u64 = 0, epoch: u64 = 0, fences: u64 = 0 } = .{},
    reclaimable_bytes: u64 = 0,
    marks: c.Snapshot = .{},
    pending: ?struct { fence: bool, cursor: u64, allocation: a.AllocationQueue.Allocation } = null,
    verified_pages: u64 = 0,
    verified_blocks: u64 = 0,
    retained_segments: u64 = 0,
    reclaimed_segments: u64 = 0,
    reclaimed_bytes: u64 = 0,
    uncertain_segments: u64 = 0,
};
authority: a.Journal,
name: [45]u8,
pub fn init(authority: a.Journal) Self {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.storage.collection.v1\x00");
    hash.update(authority.stream.bucket);
    hash.update("\x00");
    hash.update(authority.stream.name);
    var name: [45]u8 = undefined;
    name[0..2].* = "m-".*;
    _ = std.base64.url_safe_no_pad.Encoder.encode(name[2..], &hash.finalResult());
    return .{ .authority = authority, .name = name };
}
fn journal(self: *Self) a.Journal {
    var value = self.authority;
    value.stream.name = &self.name;
    return value;
}
pub fn create(self: *Self) !void {
    try self.journal().create();
}
pub fn current(self: *Self) !?State {
    const tail = try self.journal().tail();
    if (tail == 0) return null;
    var response = try self.authority.send(.{ .read = .{ .stream = self.journal().stream, .options = .{ .position = .{ .record = tail - 1 }, .max_records = 1 } } });
    defer response.deinit();
    try response.head.requireSuccess();
    const metadata = try response.head.metadata();
    if (metadata.record_start != tail - 1 or metadata.record_next != tail or response.body.len > a.max_record_bytes) return error.InvalidStorageCollection;
    const parsed = try std.json.parseFromSlice(State, self.authority.client.http.allocator, response.body, .{});
    defer parsed.deinit();
    const state = parsed.value;
    if (state.position != tail - 1 or (state.pending != null) != (state.phase == .deleting) or state.cut.storage_epoch < 2 or state.cut.history_floor >= state.cut.position) return error.InvalidStorageCollection;
    try state.marks.validate();
    return state;
}
fn save(self: *Self, state: State) !void {
    var bytes: [a.max_record_bytes]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    std.json.Stringify.value(state, .{}, &out) catch return error.StorageMaintenanceBudget;
    if (!try self.journal().append(state.position, out.buffered())) return error.Conflict;
}
/// The supplied record must be a committed signed storage fence. Independent
/// hosts therefore reject old prepared roots through the ordinary authority CAS.
pub fn start(self: *Self, engine: anytype, fence_position: u64) !void {
    try engine.refresh();
    const entry = (try engine.journal.read(fence_position)) orelse return error.IncompleteHistory;
    if (entry != .operation or entry.operation.request.command != .storage_fence) return error.NoStorageFence;
    const cut = entry.operation.next;
    if (!std.mem.eql(u8, &cut.genesis, &engine.head.genesis) or cut.position > engine.head.position or cut.storage_epoch != engine.head.storage_epoch) return error.NoStorageFence;
    const now = entry.operation.time orelse return error.ClockUnavailable;
    try engine.validateTime(now);
    const previous = try self.current();
    if (previous) |state| if (state.phase != .complete) return error.ActiveStorageCollection;
    var queue = try engine.page_store.allocations();
    const end = (try queue.current()).position + 1;
    // Every native host caps requests at 60 seconds and snapshots at five
    // minutes. Both bounds are part of the current definition, not local hints.
    const grace = try std.math.add(u64, now.upper(), core.protocol.Growth.snapshot_lifetime_ms + 60_000);
    if (grace > core.protocol.max_counter) return error.InvalidStorageCollection;
    try self.save(.{ .definition = core.protocol.Growth.current_definition, .position = if (previous) |state| state.position + 1 else 0, .phase = .mark, .cut = cut, .inventory_end = end, .grace_until_ms = grace, .roots = .init(cut) });
}
fn segmentKey(identity: a.Segment.Identity) !core.pages.Key {
    return c.key(.entry, 0, 0, &(try identity.locate(0))[0..24].*);
}
fn objectKey(edge: core.StorageWalk.Edge, owner: core.StorageRoots.Owner) !core.pages.Key {
    return switch (edge) {
        .page => |root| c.key(.entry, 1 + @as(u64, @backingInt(root.kind)) + @as(u64, @backingInt(owner)) * 4, root.resource orelse 0, &root.reference.location),
        .block => |reference| c.key(.entry, 4 + @as(u64, @backingInt(owner)) * 4, 0, &reference.location),
    };
}

test "mark reuse distinguishes captured resource scope and root ownership" {
    const t = std.testing;
    var page: core.StorageWalk.Edge = .{ .page = .{ .reference = .{ .location = @splat(3), .digest = @splat(7) }, .kind = .catalog, .resource = 1 } };
    const first = try objectKey(page, .captured);
    page.page.resource = 2;
    const second = try objectKey(page, .captured);
    try t.expect(!std.mem.eql(u8, first.slice(), second.slice()));
    page.page.resource = null;
    const current_key = try objectKey(page, .current);
    const history = try objectKey(page, .history);
    try t.expect(!std.mem.eql(u8, current_key.slice(), history.slice()));
    try t.expect(!std.mem.eql(u8, first.slice(), current_key.slice()));
}
fn mark(state: *State, pages: *a.PackedPageStore, edge: core.StorageWalk.Edge) !void {
    var marks = try c.Catalog(a.PackedPageStore).open(pages, state.marks);
    const key = try objectKey(edge, state.owner);
    const digest = switch (edge) {
        .page => |root| root.reference.digest,
        .block => |reference| reference.value.digest,
    };
    if (try marks.get([32]u8, key)) |known| {
        if (!std.mem.eql(u8, &known, &digest)) return error.InvalidStorageGraph;
        if (edge == .page) try state.walk.?.skip();
        return;
    }
    const location = switch (edge) {
        .page => |root| blk: {
            state.verified_pages += 1;
            break :blk root.reference.location;
        },
        .block => |reference| blk: {
            var bytes: [core.protocol.Blocks.max_block_bytes]u8 = undefined;
            _ = try pages.loadBlock(reference, &bytes);
            state.verified_blocks += 1;
            break :blk reference.location;
        },
    };
    const identity = (try a.Segment.Address.decode(location)).identity;
    try marks.put(key, digest);
    const segment_key = try segmentKey(identity);
    const mask: u8 = @as(u8, 1) << @as(u3, @intCast(@backingInt(state.owner)));
    try marks.put(segment_key, (try marks.get(u8, segment_key) orelse 0) | mask);
    state.marks = marks.snapshot;
}
fn target(self: *Self, item: a.AllocationQueue.Allocation, name: *[45]u8) !a.ursula.Stream {
    name.* = try item.identity.name(self.authority.stream.bucket, self.authority.stream.name);
    return .{ .bucket = self.authority.stream.bucket, .name = name };
}
/// Only a creator's exact closing seal makes deletion safe. Absent or unsealed
/// creations instead retain a permanent closed-name fence after trimming data.
fn sealed(self: *Self, item: a.AllocationQueue.Allocation) !bool {
    var name: [45]u8 = undefined;
    const stream = try self.target(item, &name);
    var head = try self.authority.send(.{ .head = .{ .stream = stream } });
    defer head.deinit();
    if (head.head.status == .not_found) return false;
    try head.head.requireSuccess();
    const metadata = try head.head.metadata();
    if (metadata.closed != true) return false;
    if (metadata.record_next != @as(u64, item.frames) + 1) return false;
    var read = try self.authority.send(.{ .read = .{ .stream = stream, .options = .{ .position = .{ .record = item.frames }, .max_records = 1 } } });
    defer read.deinit();
    try read.head.requireSuccess();
    const range = try read.head.metadata();
    if (range.record_start != item.frames or range.record_next != metadata.record_next or read.body.len > 2048) return false;
    const parsed = std.json.parseFromSlice(a.PackedPageStore.Seal, self.authority.client.http.allocator, read.body, .{}) catch return false;
    defer parsed.deinit();
    const seal = parsed.value;
    if (!std.meta.eql(seal.identity, item.identity) or seal.frames != item.frames or !std.mem.eql(u8, &seal.digest, &item.digest) or seal.bytes + read.body.len != item.bytes) return false;
    return true;
}
fn remove(self: *Self, item: a.AllocationQueue.Allocation) !void {
    var name: [45]u8 = undefined;
    const stream = try self.target(item, &name);
    var removed = try self.authority.send(.{ .delete_stream = stream });
    defer removed.deinit();
    if (removed.head.status != .not_found) try removed.head.requireSuccess();
    var head = try self.authority.send(.{ .head = .{ .stream = stream } });
    defer head.deinit();
    if (head.head.status != .not_found) return error.StorageDeletionUnconfirmed;
}
fn fence(self: *Self, item: a.AllocationQueue.Allocation) !void {
    var name: [45]u8 = undefined;
    const stream = try self.target(item, &name);
    // Keep this identity permanently. A delayed creator asks for an open
    // stream, so it cannot recreate bytes behind the closed-name fence.
    var created = try self.authority.send(.{ .create_stream = .{ .stream = stream, .options = .{ .content_type = "application/json", .closed = true } } });
    defer created.deinit();
    if (created.head.status != .conflict) try created.head.requireSuccess();
    for (0..4) |_| {
        var head = try self.authority.send(.{ .head = .{ .stream = stream } });
        defer head.deinit();
        try head.head.requireSuccess();
        const metadata = try head.head.metadata();
        const tail = metadata.record_next orelse return error.MissingRecordCoordinate;
        if (metadata.closed != true) {
            var closed = try self.authority.send(.{ .append = .{ .stream = stream, .body = "", .options = .{ .content_type = "application/json", .record_match = tail, .closed = true } } });
            defer closed.deinit();
            if (closed.head.status == .precondition_failed or closed.head.status == .conflict) continue;
            try closed.head.requireSuccess();
            continue;
        }
        var bytes: [1024]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try std.json.Stringify.value(.{ .definition = core.protocol.Growth.current_definition, .identity = item.identity, .fenced = true }, .{}, &out);
        if (out.buffered().len > item.bytes - item.data_bytes) return error.StorageMaintenanceBudget;
        var saved = try self.authority.send(.{ .publish_snapshot = .{ .stream = stream, .at = .{ .record = tail }, .body = out.buffered(), .content_type = "application/json" } });
        defer saved.deinit();
        try saved.head.requireSuccess();
        if (tail != 0) {
            var trimmed = try self.authority.send(.{ .advance_retention = .{ .stream = stream, .at = .{ .record = tail } } });
            defer trimmed.deinit();
            try trimmed.head.requireSuccess();
        }
        var verified = try self.authority.send(.{ .head = .{ .stream = stream } });
        defer verified.deinit();
        try verified.head.requireSuccess();
        const final = try verified.head.metadata();
        if (final.closed != true or final.record_first != tail or final.record_next != tail) return error.StorageDeletionUnconfirmed;
        return;
    }
    return error.Conflict;
}
/// One bounded unit: at most four verified graph edges or one allocation.
/// All candidates and provider calls are private until save/queue CAS succeeds.
pub fn step(self: *Self, engine: anytype, now: core.Time.Sample) !bool {
    try engine.refresh();
    try engine.validateTime(now);
    var state = (try self.current()) orelse return false;
    if (!std.mem.eql(u8, &state.cut.genesis, &engine.head.genesis) or state.cut.storage_epoch > engine.head.storage_epoch) return error.InvalidStorageCollection;
    if (state.phase == .complete) return false;
    state.position += 1;
    switch (state.phase) {
        .mark => {
            try engine.page_store.begin(engine.head.storage_epoch, true);
            defer engine.page_store.discard();
            for (0..4) |_| {
                if (state.walk) |*walk| {
                    if (try walk.next(engine.page_store)) |edge| try mark(&state, engine.page_store, edge) else state.walk = null;
                } else switch (state.roots.next(engine.journal, engine.page_store, state.cut) catch |err| {
                    if (err != error.HistoryReclaimed) return err;
                    // A separately authorized trim can remove an unvisited root
                    // record. No incomplete mark set can authorize deletion.
                    state.phase = .complete;
                    state.aborted = true;
                    state.marks = .{};
                    state.walk = null;
                    break;
                }) {
                    .root => |root| {
                        state.walk = .init(root.root);
                        state.owner = root.owner;
                    },
                    .progress => {},
                    .complete => {
                        state.phase = .wait;
                        break;
                    },
                }
            }
            try engine.page_store.finish();
        },
        .wait => {
            if (now.lower() <= state.grace_until_ms) return false;
            // Persist the elapsed grace in authority time before deletion. A
            // host with an older clock must fail its ordinary current check.
            if (engine.head.time_floor_ms <= state.grace_until_ms) return error.CollectionTimeFenceRequired;
            state.phase = .sweep;
        },
        .sweep => {
            var queue = try engine.page_store.allocations();
            const queue_head = try queue.current();
            if (queue_head.cursor >= state.inventory_end) {
                state.phase = .complete;
                state.marks = .{};
            } else {
                const entry = try queue.read(queue_head.cursor);
                if (entry.item) |item| {
                    var marks = try c.Catalog(a.PackedPageStore).open(engine.page_store, state.marks);
                    const owners = try marks.get(u8, try segmentKey(item.identity)) orelse 0;
                    if (item.fenced or item.identity.epoch >= state.cut.storage_epoch or owners != 0) {
                        try queue.consume(queue_head.cursor, item, true);
                        state.retained_segments += 1;
                        const charge = if (item.fenced) &state.protected_bytes.fences else if (owners & 1 != 0) &state.protected_bytes.current else if (owners & 4 != 0) &state.protected_bytes.captured else if (owners & 2 != 0) &state.protected_bytes.history else &state.protected_bytes.epoch;
                        charge.* += item.bytes;
                    } else if (try self.sealed(item)) {
                        state.reclaimable_bytes += item.bytes;
                        state.pending = .{ .fence = false, .cursor = queue_head.cursor, .allocation = item };
                        state.phase = .deleting;
                    } else {
                        state.reclaimable_bytes += item.data_bytes;
                        state.pending = .{ .fence = true, .cursor = queue_head.cursor, .allocation = item };
                        state.phase = .deleting;
                        state.uncertain_segments += 1;
                    }
                } else try queue.consume(queue_head.cursor, null, false);
            }
        },
        .deleting => {
            const pending = state.pending.?;
            if (pending.fence) try self.fence(pending.allocation) else try self.remove(pending.allocation);
            var queue = try engine.page_store.allocations();
            const queue_head = try queue.current();
            if (queue_head.cursor == pending.cursor) {
                if (pending.fence) try queue.fence(pending.cursor, pending.allocation) else try queue.consume(pending.cursor, pending.allocation, false);
            } else if (queue_head.cursor < pending.cursor) return error.InvalidStorageCollection;
            state.pending = null;
            state.phase = .sweep;
            state.reclaimed_segments += 1;
            state.reclaimed_bytes += if (pending.fence) pending.allocation.data_bytes else pending.allocation.bytes;
        },
        .complete => unreachable,
    }
    try self.save(state);
    if (state.position % 32 == 0 or state.phase == .complete) {
        var queue = try engine.page_store.allocations();
        try queue.trim();
        try @import("LedgerTrim.zig").run(self.journal(), state.position);
    }
    return true;
}
