//! Restartable native mark/sweep. Accepted roots and epoch/time fences own
//! deletion authority; this bounded private state records progress only.
const std = @import("std");
const core = @import("transit_core");
const Backend = @import("Backend.zig");
const Store = @import("Store.zig");
const PageStore = @import("PageStore.zig");
const Allocations = @import("NativeAllocations.zig");
const Files = @import("LocalFiles.zig");
const c = core.catalog;
const Self = @This();
const max_state_bytes = 256 * 1024;
const filename = ".native-collection";
pub const State = struct {
    definition: core.protocol.Growth.Definition,
    phase: enum { mark, wait, sweep, deleting, complete },
    aborted: bool = false,
    cut: core.growing.Head,
    grace_until_ms: u64,
    roots: core.StorageRoots,
    walk: ?core.StorageWalk = null,
    marks: c.Snapshot = .{},
    inventory_end: u64,
    pending: ?struct { cursor: u64, allocation: Allocations.Allocation } = null,
    verified_pages: u64 = 0,
    verified_blocks: u64 = 0,
    retained_objects: u64 = 0,
    reclaimed_objects: u64 = 0,
    /// Confirmed unlinks in this execution; a crash may undercount earlier work.
    reclaimed_bytes: u64 = 0,
};
backend: *Backend,

pub fn current(self: *Self) !?State {
    var bytes: [max_state_bytes + 32]u8 = undefined;
    const encoded = (try Files.read(self.backend.io, self.backend.directory, filename, &bytes)) orelse return null;
    if (encoded.len < 32) return error.InvalidStorageCollection;
    const body = encoded[0 .. encoded.len - 32];
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(body, &digest, .{});
    if (!std.mem.eql(u8, encoded[body.len..], &digest)) return error.InvalidStorageCollection;
    const parsed = try std.json.parseFromSlice(State, self.backend.allocator, body, .{});
    defer parsed.deinit();
    const state = parsed.value;
    if ((state.pending != null) != (state.phase == .deleting) or state.cut.storage_epoch < 2 or state.cut.history_floor >= state.cut.position) return error.InvalidStorageCollection;
    if (state.pending) |pending| if (pending.allocation.epoch >= state.cut.storage_epoch or pending.cursor >= state.inventory_end) return error.InvalidStorageCollection;
    try state.marks.validate();
    return state;
}
fn save(self: *Self, state: State) !void {
    var bytes: [max_state_bytes + 32]u8 = undefined;
    var writer: std.Io.Writer = .fixed(bytes[0..max_state_bytes]);
    std.json.Stringify.value(state, .{}, &writer) catch return error.StorageMaintenanceBudget;
    const size = writer.buffered().len;
    std.crypto.hash.sha2.Sha256.hash(bytes[0..size], bytes[size..][0..32], .{});
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    const old = self.backend.directory.openFile(self.backend.io, filename, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    const old_size = if (old) |file| blk: {
        defer file.close(self.backend.io);
        break :blk try file.length(self.backend.io);
    } else 0;
    try self.backend.reserve(size + 32 + 512, true);
    try Files.save(self.backend.io, self.backend.directory, filename, bytes[0 .. size + 32], true);
    self.backend.allocated -= @min(self.backend.allocated, old_size + 512);
}
pub fn start(self: *Self, engine: anytype, fence_position: u64) !void {
    if (engine.journal.backend != self.backend or engine.page_store.backend != self.backend) return error.InvalidStorageCollection;
    try self.backend.collection.lock(self.backend.io);
    defer self.backend.collection.unlock(self.backend.io);
    try engine.refresh();
    const entry = (try engine.journal.read(fence_position)) orelse return error.IncompleteHistory;
    if (entry != .operation or entry.operation.request.command != .storage_fence) return error.NoStorageFence;
    const cut = entry.operation.next;
    if (!std.mem.eql(u8, &cut.genesis, &engine.head.genesis) or cut.position > engine.head.position or cut.storage_epoch != engine.head.storage_epoch) return error.NoStorageFence;
    const now = entry.operation.time orelse return error.ClockUnavailable;
    try engine.validateTime(now);
    if (try self.current()) |previous| if (previous.phase != .complete) return error.ActiveStorageCollection;
    const grace = try std.math.add(u64, now.upper(), core.protocol.Growth.snapshot_lifetime_ms + 60_000);
    if (grace > core.protocol.max_counter) return error.InvalidStorageCollection;
    try self.backend.native_inventory.lock(self.backend.io);
    const end = (self.backend.allocations.current() catch |err| {
        self.backend.native_inventory.unlock(self.backend.io);
        return err;
    }).tail;
    self.backend.native_inventory.unlock(self.backend.io);
    try self.save(.{ .definition = core.protocol.Growth.current_definition, .phase = .mark, .cut = cut, .inventory_end = end, .grace_until_ms = grace, .roots = .init(cut) });
}

fn objectKey(kind: @FieldType(Allocations.Allocation, "kind"), address: [32]u8) !core.pages.Key {
    return c.key(.entry, 100 + @as(u64, @backingInt(kind)), 0, &address);
}
fn scopeKey(root: core.StorageWalk.Root) !core.pages.Key {
    return c.key(.entry, 1 + @as(u64, @backingInt(root.kind)), root.resource orelse 0, &root.reference.location);
}
fn mark(state: *State, pages: *PageStore, edge: core.StorageWalk.Edge) !void {
    var marks = try c.Catalog(PageStore).open(pages, state.marks);
    if (edge == .page) {
        const root = edge.page;
        const scope = try scopeKey(root);
        if (try marks.get([32]u8, scope)) |known| {
            if (!std.mem.eql(u8, &known, &root.reference.digest)) return error.InvalidStorageGraph;
            try state.walk.?.skip();
            return;
        }
        try marks.put(scope, root.reference.digest);
        try marks.put(try objectKey(.page, root.reference.location), root.reference.digest);
        state.verified_pages += 1;
    } else {
        const reference = edge.block;
        const key = try objectKey(.block, reference.location);
        if (try marks.get([32]u8, key)) |known| {
            if (!std.mem.eql(u8, &known, &reference.value.digest)) return error.InvalidStorageGraph;
        } else {
            var bytes: [core.protocol.Blocks.max_block_bytes]u8 = undefined;
            _ = try pages.loadBlock(reference, &bytes);
            try marks.put(key, reference.value.digest);
            state.verified_blocks += 1;
        }
    }
    state.marks = marks.snapshot;
}
fn reclaim(self: *Self, cursor: u64, allocation: Allocations.Allocation, cut: core.growing.Head) !u64 {
    // A paused creator must finish before its inventory item can be consumed.
    // Otherwise it could publish bytes after deletion discarded their marker.
    try self.backend.native_creators.lock(self.backend.io);
    defer self.backend.native_creators.unlock(self.backend.io);
    try self.backend.native_inventory.lock(self.backend.io);
    defer self.backend.native_inventory.unlock(self.backend.io);
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    const current_head = try Store.currentHeadLocked(self.backend);
    if (current_head.storage_epoch < cut.storage_epoch or !std.mem.eql(u8, &current_head.genesis, &cut.genesis) or allocation.epoch >= cut.storage_epoch) return error.NoStorageFence;
    const queue = try self.backend.allocations.current();
    if (queue.cursor > cursor) return 0; // The prior consume survived a lost reply.
    if (queue.cursor != cursor or !std.meta.eql((try self.backend.allocations.at(cursor)).item, @as(?Allocations.Allocation, allocation))) return error.AllocationConflict;
    try self.backend.reserve(512, true);
    const present = try self.backend.allocations.read(allocation.name());
    if (present) |record| if (!std.meta.eql(record, allocation)) return error.InvalidNativeAllocation;
    var key: [96]u8 = undefined;
    var removed = try self.backend.objects.reclaimImmutableObject(try allocation.key(&key), allocation.meta);
    try self.backend.allocations.remove(allocation);
    try self.backend.allocations.consume(cursor, allocation, false);
    if (present != null) removed += Allocations.record_bytes;
    self.backend.allocated -= @min(self.backend.allocated, removed);
    return removed;
}
fn sweep(self: *Self, state: *State, pages: *PageStore) !void {
    const selected = blk: {
        try self.backend.native_inventory.lock(self.backend.io);
        defer self.backend.native_inventory.unlock(self.backend.io);
        const head = try self.backend.allocations.current();
        if (head.cursor >= state.inventory_end) {
            state.phase = .complete;
            state.marks = .{};
            return;
        }
        const item = (try self.backend.allocations.at(head.cursor)).item orelse {
            try self.reserveInventory();
            try self.backend.allocations.consumeEmpty(state.inventory_end);
            return;
        };
        break :blk .{ .cursor = head.cursor, .allocation = item };
    };
    const item = selected.allocation;
    var marks = try c.Catalog(PageStore).open(pages, state.marks);
    if (item.epoch >= state.cut.storage_epoch or try marks.get([32]u8, try objectKey(item.kind, item.address)) != null) {
        try self.backend.native_inventory.lock(self.backend.io);
        defer self.backend.native_inventory.unlock(self.backend.io);
        try self.reserveInventory();
        try self.backend.allocations.consume(selected.cursor, item, true);
        state.retained_objects += 1;
    } else {
        state.pending = .{ .cursor = selected.cursor, .allocation = item };
        state.phase = .deleting;
    }
}
fn trim(self: *Self) !bool {
    try self.backend.native_inventory.lock(self.backend.io);
    defer self.backend.native_inventory.unlock(self.backend.io);
    return self.backend.allocations.trimUnit();
}

fn reserveInventory(self: *Self) !void {
    try self.backend.mutex.lock(self.backend.io);
    defer self.backend.mutex.unlock(self.backend.io);
    try self.backend.reserve(512, true);
}
/// At most four graph edges, one allocation, or 64 empty progress records per
/// step. The allocation FIFO carries retained items and trims consumed prefixes.
pub fn step(self: *Self, engine: anytype, now: core.Time.Sample) !bool {
    if (engine.journal.backend != self.backend or engine.page_store.backend != self.backend) return error.InvalidStorageCollection;
    try self.backend.collection.lock(self.backend.io);
    defer self.backend.collection.unlock(self.backend.io);
    try engine.refresh();
    try engine.validateTime(now);
    var state = (try self.current()) orelse return false;
    if (!std.mem.eql(u8, &state.cut.genesis, &engine.head.genesis) or state.cut.storage_epoch > engine.head.storage_epoch) return error.InvalidStorageCollection;
    switch (state.phase) {
        .complete => return !try self.trim(),
        .mark => {
            try engine.page_store.begin(engine.head.storage_epoch, true);
            defer engine.page_store.discard();
            for (0..4) |_| {
                if (state.walk) |*walk| {
                    if (try walk.next(engine.page_store)) |edge| try mark(&state, engine.page_store, edge) else state.walk = null;
                } else switch (state.roots.next(engine.journal, engine.page_store, state.cut) catch |err| {
                    if (err != error.HistoryReclaimed) return err;
                    // An incomplete graph can never authorize deletion.
                    state.phase = .complete;
                    state.aborted = true;
                    state.marks = .{};
                    state.walk = null;
                    break;
                }) {
                    .root => |root| state.walk = .init(root.root),
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
            if (engine.head.time_floor_ms <= state.grace_until_ms) return error.CollectionTimeFenceRequired;
            state.phase = .sweep;
        },
        .sweep => try self.sweep(&state, engine.page_store),
        .deleting => {
            const pending = state.pending.?;
            state.reclaimed_bytes += try self.reclaim(pending.cursor, pending.allocation, state.cut);
            state.reclaimed_objects += 1;
            state.pending = null;
            state.phase = .sweep;
        },
    }
    try self.save(state);
    if (state.phase == .complete) _ = try self.trim();
    return true;
}
