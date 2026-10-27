//! Restartable direct-data collection. Graph semantics belong to the data
//! owner; this adapter owns epoch/time fences, private progress and exact unlink.
const std = @import("std");
const core = @import("transit_core");
const storage = @import("transit_storage");
const Backend = @import("Backend.zig");
const Store = @import("Store.zig");
const DataStore = @import("DataStore.zig");
const Cuts = @import("DataCuts.zig");
const Marks = @import("DataMarkWork.zig");
const Allocations = @import("DataAllocations.zig");
const Files = @import("LocalFiles.zig");
const MemoryBudget = @import("transit_fuze").MemoryBudget;
const filename = ".data-collection";
const max_state_bytes = 256 * 1024;
const progress_reservation = storage.TransitLog.alignedFrameSize(Allocations.queue_record_bytes) + 1024;
pub const step_resident_bytes = 64 * 1024 * 1024;

/// Graph owns Work, fromFrame(allocator, frame), step(allocator, index, log,
/// *work, workspace) -> finished, and collectible(key). Work owns all fields.
/// A step must bound expansion and enqueue every discovered dependency before
/// completing. Unknown namespaces and permanent identity reservations are kept.
pub fn Collector(comptime Graph: type) type {
    return struct {
        const Self = @This();
        pub const State = struct {
            definition: core.protocol.Growth.Definition,
            phase: enum { mark, wait, sweep, deleting, complete },
            aborted: bool = false,
            cut: core.growing.Head,
            grace_until_ms: u64,
            cuts: Cuts,
            work: Marks.State = .{},
            active: ?Graph.Work = null,
            inventory_end: u64,
            pending: ?struct { cursor: u64, allocation: Allocations.Allocation } = null,
            retained_objects: u64 = 0,
            reclaimed_objects: u64 = 0,
            /// Confirmed bytes in this execution; lost replies may undercount.
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
            try state.work.validate();
            if ((state.pending != null) != (state.phase == .deleting) or state.cut.storage_epoch < 2 or
                state.cuts.epoch != state.cut.storage_epoch or !std.mem.eql(u8, &state.cuts.genesis, &state.cut.genesis) or
                (state.phase != .mark and state.active != null) or
                (state.phase != .mark and state.phase != .complete and (!state.cuts.complete or state.work.queue != null))) return error.InvalidStorageCollection;
            if (state.pending) |pending| if (pending.allocation.epoch >= state.cut.storage_epoch or pending.cursor >= state.inventory_end or
                !Graph.collectible(pending.allocation.object_key.slice())) return error.InvalidStorageCollection;
            return state;
        }

        fn save(self: *Self, state: State) !void {
            var bytes: [max_state_bytes + 32]u8 = undefined;
            var writer: std.Io.Writer = .fixed(bytes[0..max_state_bytes]);
            std.json.Stringify.value(state, .{}, &writer) catch return error.StorageMaintenanceBudget;
            const size = writer.end;
            std.crypto.hash.sha2.Sha256.hash(bytes[0..size], bytes[size..][0..32], .{});
            // Only reservation and accounting hold the native journal mutex.
            // The collection mutex separately serializes this private filename.
            const old = self.backend.directory.openFile(self.backend.io, filename, .{ .follow_symlinks = false }) catch |err| switch (err) {
                error.FileNotFound => null,
                else => return err,
            };
            const old_size = if (old) |file| blk: {
                defer file.close(self.backend.io);
                break :blk try file.length(self.backend.io);
            } else 0;
            try self.reserve(size + 32 + 512);
            try Files.save(self.backend.io, self.backend.directory, filename, bytes[0 .. size + 32], true);
            try self.backend.mutex.lock(self.backend.io);
            defer self.backend.mutex.unlock(self.backend.io);
            self.backend.allocated -= @min(self.backend.allocated, old_size + 512);
        }

        fn reserve(self: *Self, bytes: usize) !void {
            try self.backend.mutex.lock(self.backend.io);
            defer self.backend.mutex.unlock(self.backend.io);
            try self.backend.reserve(bytes, true);
        }

        pub fn start(self: *Self, engine: anytype, fence_position: u64) !void {
            if (engine.journal.backend != self.backend or engine.page_store.backend != self.backend) return error.InvalidStorageCollection;
            try self.backend.collection.lock(self.backend.io);
            defer self.backend.collection.unlock(self.backend.io);
            try engine.refresh();
            const entry = (try engine.journal.read(fence_position)) orelse return error.IncompleteHistory;
            if (entry != .operation or entry.operation.request.command != .storage_fence) return error.NoStorageFence;
            const cut = entry.operation.next;
            if (!std.mem.eql(u8, &cut.genesis, &engine.head.genesis) or cut.position > engine.head.position or
                cut.storage_epoch != engine.head.storage_epoch) return error.NoStorageFence;
            const now = entry.operation.time orelse return error.ClockUnavailable;
            try engine.validateTime(now);
            if (try self.current()) |previous| if (previous.phase != .complete) return error.ActiveStorageCollection;
            const grace = try std.math.add(u64, now.upper(), core.protocol.Growth.snapshot_lifetime_ms + 60_000);
            if (grace > core.protocol.max_counter) return error.InvalidStorageCollection;
            const end = blk: {
                try self.backend.data_inventory.lock(self.backend.io);
                defer self.backend.data_inventory.unlock(self.backend.io);
                break :blk (try self.backend.data_allocations.current()).tail;
            };
            try self.save(.{ .definition = core.protocol.Growth.current_definition, .phase = .mark, .cut = cut, .grace_until_ms = grace, .cuts = try Cuts.init(cut), .inventory_end = end });
        }

        fn mark(self: *Self, allocator: std.mem.Allocator, state: *State, data: *DataStore, index: *storage.TreeStore) !void {
            var workspace: Marks.Workspace(Graph.Work) = .{ .state = &state.work, .index = index };
            try index.begin(8 * 1024 * 1024);
            defer index.end();
            if (state.active) |*work| {
                if (try Graph.step(allocator, index, data.log(), work, &workspace)) state.active = null;
            } else if (try workspace.take(allocator)) |work| {
                state.active = work;
            } else switch (try state.cuts.next(self.backend)) {
                .progress => {},
                .complete => state.phase = .wait,
                .cut => |cut| {
                    var batch = try data.log().read(allocator, cut.header.partition_id, cut.header.lsn, 1);
                    defer batch.deinit();
                    if (batch.frames.len != 1 or !std.meta.eql(batch.frames[0].header, cut.header)) return error.IncompleteHistory;
                    var digest: [32]u8 = undefined;
                    std.crypto.hash.sha2.Sha256.hash(batch.frames[0].payload, &digest, .{});
                    if (!std.mem.eql(u8, &digest, &cut.payload_hash)) return error.InvalidStorageGraph;
                    try workspace.enqueue(try Graph.fromFrame(allocator, batch.frames[0]));
                },
            }
        }

        fn sweep(self: *Self, state: *State, index: *storage.TreeStore) !void {
            const selected = blk: {
                try self.backend.data_inventory.lock(self.backend.io);
                defer self.backend.data_inventory.unlock(self.backend.io);
                const head = try self.backend.data_allocations.current();
                if (head.cursor >= state.inventory_end) {
                    state.phase = .complete;
                    state.work = .{};
                    return;
                }
                const item = (try self.backend.data_allocations.at(head.cursor)).item orelse {
                    try self.reserve(progress_reservation);
                    try self.backend.data_allocations.consumeEmpty(state.inventory_end);
                    return;
                };
                break :blk .{ .cursor = head.cursor, .allocation = item };
            };
            const item = selected.allocation;
            var workspace: Marks.Workspace(Graph.Work) = .{ .state = &state.work, .index = index };
            if (item.epoch >= state.cut.storage_epoch or !Graph.collectible(item.object_key.slice()) or
                try workspace.marked(item.object_key.slice(), item.meta))
            {
                try self.backend.data_inventory.lock(self.backend.io);
                defer self.backend.data_inventory.unlock(self.backend.io);
                try self.reserve(progress_reservation);
                try self.backend.data_allocations.consume(selected.cursor, item, true);
                state.retained_objects +|= 1;
            } else {
                state.pending = .{ .cursor = selected.cursor, .allocation = item };
                state.phase = .deleting;
            }
        }

        fn reclaim(self: *Self, cursor: u64, item: Allocations.Allocation, cut: core.growing.Head) !u64 {
            // Exclude both paused creators and later content reuse through the
            // entire marker check, physical removal and consumed-prefix append.
            try self.backend.data_creators.lock(self.backend.io);
            defer self.backend.data_creators.unlock(self.backend.io);
            try self.backend.data_inventory.lock(self.backend.io);
            defer self.backend.data_inventory.unlock(self.backend.io);
            {
                try self.backend.mutex.lock(self.backend.io);
                defer self.backend.mutex.unlock(self.backend.io);
                const head = try Store.currentHeadLocked(self.backend);
                if (head.storage_epoch < cut.storage_epoch or !std.mem.eql(u8, &head.genesis, &cut.genesis) or
                    item.epoch >= cut.storage_epoch) return error.NoStorageFence;
                try self.backend.reserve(progress_reservation, true);
            }
            const queue = try self.backend.data_allocations.current();
            if (queue.cursor > cursor) return 0; // Earlier consume survived.
            if (queue.cursor != cursor or !std.meta.eql((try self.backend.data_allocations.at(cursor)).item, @as(?Allocations.Allocation, item))) return error.AllocationConflict;
            const latest = try self.backend.data_allocations.latest(item.name());
            if (latest) |known| {
                if (!std.meta.eql(known.object_key, item.object_key) or !std.meta.eql(known.meta, item.meta)) return error.InvalidDataAllocation;
                if (known.epoch != item.epoch) {
                    // Newer markers have their own durable intent. An older
                    // marker means this newer intent never completed publication;
                    // its original allocation still owns the content. Neither
                    // case lets this queue entry remove a different marker.
                    try self.backend.data_allocations.consume(cursor, item, false);
                    return 0;
                }
            }
            var removed = try self.backend.objects.reclaimImmutableObject(item.object_key.slice(), item.meta);
            try self.backend.data_allocations.remove(item);
            try self.backend.data_allocations.consume(cursor, item, false);
            if (latest != null) removed += Allocations.record_bytes;
            try self.backend.mutex.lock(self.backend.io);
            defer self.backend.mutex.unlock(self.backend.io);
            self.backend.allocated -= @min(self.backend.allocated, removed);
            return removed;
        }

        fn trim(self: *Self) !void {
            try self.backend.data_inventory.lock(self.backend.io);
            defer self.backend.data_inventory.unlock(self.backend.io);
            try self.backend.data_allocations.trim();
        }

        pub fn step(self: *Self, engine: anytype, now: core.Time.Sample) !bool {
            if (engine.journal.backend != self.backend or engine.page_store.backend != self.backend) return error.InvalidStorageCollection;
            try self.backend.collection.lock(self.backend.io);
            defer self.backend.collection.unlock(self.backend.io);
            try engine.refresh();
            try engine.validateTime(now);
            var state = (try self.current()) orelse return false;
            if (!std.mem.eql(u8, &state.cut.genesis, &engine.head.genesis) or state.cut.storage_epoch > engine.head.storage_epoch) return error.InvalidStorageCollection;
            var data: DataStore = .{ .backend = self.backend, .control = true };
            var memory: MemoryBudget = .{ .parent = self.backend.allocator, .limit = step_resident_bytes };
            var index = try storage.TreeStore.init(memory.allocator(), data.objects(), 1);
            defer index.deinit();
            switch (state.phase) {
                .complete => {
                    try self.trim();
                    return false;
                },
                .mark => for (0..4) |_| {
                    self.mark(memory.allocator(), &state, &data, &index) catch |err| {
                        if (err == error.OutOfMemory and memory.exhausted) return error.StorageMaintenanceBudget;
                        if (err != error.WalHistoryTrimmed) return err;
                        state.phase = .complete;
                        state.aborted = true;
                        state.active = null;
                        state.work = .{};
                    };
                    if (state.phase != .mark) break;
                },
                .wait => {
                    if (now.lower() <= state.grace_until_ms) return false;
                    if (engine.head.time_floor_ms <= state.grace_until_ms) return error.CollectionTimeFenceRequired;
                    state.phase = .sweep;
                },
                .sweep => try self.sweep(&state, &index),
                .deleting => {
                    const pending = state.pending.?;
                    const removed = try self.reclaim(pending.cursor, pending.allocation, state.cut);
                    state.reclaimed_bytes +|= removed;
                    if (removed != 0) state.reclaimed_objects +|= 1;
                    state.pending = null;
                    state.phase = .sweep;
                },
            }
            try self.save(state);
            if (state.phase == .complete) try self.trim();
            return true;
        }
    };
}
