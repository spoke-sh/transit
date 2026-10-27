const std = @import("std");
const t = std.testing;
const core = @import("transit_core");
const local = @import("root.zig");
const Allocations = @import("NativeAllocations.zig");
const g = core.protocol.Growth;
const Engine = core.growing.Engine(local.Store, local.PageStore);

pub const Fixture = struct {
    owner: local.Backend = undefined,
    pages: local.PageStore = undefined,
    journal: local.Store = undefined,
    engine: Engine = undefined,
    collector: local.StorageCollection = undefined,
    now: u64 = 100,

    fn key() !core.Ed25519.KeyPair {
        return core.Ed25519.KeyPair.generateDeterministic(@splat(17));
    }
    fn clock(raw: *anyopaque) anyerror!core.Time.Sample {
        return .{ .unix_ms = @as(*Fixture, @ptrCast(@alignCast(raw))).now };
    }
    pub fn open(self: *Fixture, directory: std.Io.Dir, fresh: bool) !void {
        return self.openWithIo(directory, fresh, t.io);
    }
    pub fn openWithIo(self: *Fixture, directory: std.Io.Dir, fresh: bool, io: std.Io) !void {
        self.owner = try local.Backend.open(t.allocator, io, directory, "native", .{});
        self.pages = try local.PageStore.init(&self.owner, 1);
        self.journal = .{ .backend = &self.owner };
        const genesis: core.growing.Genesis = .{ .realm = 42, .root_key = (try key()).public_key.toBytes(), .max_clock_error_ms = 5, .allow_history_trim = true };
        self.engine = if (fresh) try Engine.bootstrap(&self.journal, &self.pages, genesis) else try Engine.open(&self.journal, &self.pages, genesis);
        self.engine.clock = .{ .context = self, .read = clock };
        self.collector = .{ .backend = &self.owner };
    }
    pub fn close(self: *Fixture) void {
        self.pages.deinit();
        self.owner.deinit();
    }
    pub fn submit(self: *Fixture, command: g.Command) !u64 {
        return self.engine.submit(try self.signed(command));
    }
    pub fn signed(self: *Fixture, command: g.Command) !g.SignedRequest {
        return g.sign(.{ .realm = 42, .principal = 0, .sequence = (try self.engine.principal(0)).sequence + 1, .command = command }, try key());
    }
    pub fn query(self: *Fixture, kind: @FieldType(g.Query, "kind")) !g.Response {
        return self.engine.query(try g.signQuery(.{ .realm = 42, .principal = 0, .kind = kind }, try key()));
    }
    fn proposal(self: *Fixture, pid: u64, resource: u64) !g.TurnWithVersions {
        const input = try self.submit(.{ .send = .{ .pid = pid, .value = .{} } });
        const process = try self.engine.process(pid);
        const data = (try self.query(.{ .resource = resource })).body.resource;
        const view = try self.submit(.{ .open_view = .{ .pid = pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .resource = resource, .revision = data.revision, .deadline_ms = self.now + 50 } });
        return .{ .turn = .{ .pid = pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .views = .{ view, null, null, null }, .write_view = view }, .retain = .{ view, null, null, null } };
    }
    fn block(self: *Fixture, source: @FieldType(g.BlockRead.Query, "source"), expected: []const u8) !void {
        const request: g.Query = .{ .realm = 42, .principal = 0, .kind = .{ .block_entries = .{ .source = source, .keys = .{ try .init("row"), null, null, null, null, null, null, null } } } };
        var response: g.BlockRead.Response = undefined;
        response.response = try self.engine.queryBlocks(try g.signQuery(request, try key()), {}, &response.blocks);
        try g.BlockRead.verify(&response, request);
        try t.expectEqualStrings(expected, response.blocks.slice());
    }
    fn step(self: *Fixture) !bool {
        return self.collector.step(&self.engine, .{ .unix_ms = self.now });
    }
    fn until(self: *Fixture, phase: @FieldType(local.StorageCollection.State, "phase")) !void {
        for (0..2000) |_| {
            if ((try self.collector.current()).?.phase == phase) return;
            if (!try self.step()) return error.CollectionStopped;
        }
        return error.FixtureBudget;
    }
    fn elapse(self: *Fixture) !void {
        self.now = (try self.collector.current()).?.grace_until_ms + 1;
        try t.expectError(error.CollectionTimeFenceRequired, self.step());
        _ = try self.submit(.{ .storage_fence = {} });
    }
    fn orphan(self: *Fixture, bytes: []const u8) !core.blocks.Reference {
        try self.pages.begin(self.engine.head.storage_epoch, false);
        defer self.pages.discard();
        return self.pages.stageBlock(try core.protocol.Blocks.Spec.of(bytes), bytes);
    }
};

test "native collection joins a creator paused between inventory and object publication" {
    const Gate = struct {
        var real: *const std.Io.VTable = undefined;
        var armed: std.atomic.Value(bool) = .init(false);
        var entered: std.Io.Event = .unset;
        var release: std.Io.Event = .unset;
        // The first object-key lock follows the durable inventory record but
        // precedes any content. Pausing here exposes the untracked-recreation
        // race; pausing a payload sync would already hold the per-key lock.
        fn lock(context: ?*anyopaque, file: std.Io.File, kind: std.Io.File.Lock) std.Io.File.LockError!void {
            if (armed.swap(false, .acq_rel)) {
                entered.set(t.io);
                try release.wait(t.io);
            }
            return real.fileLock(context, file, kind);
        }
        fn reclaim(f: *Fixture, started: *std.Io.Event, done: *std.Io.Event) !void {
            started.set(t.io);
            defer done.set(t.io);
            try t.expect(try f.step());
        }
    };
    const waitFor = @import("native_test.zig").waitFor;
    Gate.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileLock = Gate.lock;
    var io = t.io;
    io.vtable = &vtable;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.openWithIo(tmp.dir, true, io);
    defer f.close();
    const address: [32]u8 = @splat(44);
    const body = "unpublished native creator";
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(body, &digest, .{});
    const allocation: Allocations.Allocation = .{ .epoch = 1, .kind = .block, .address = address, .meta = .{ .size = body.len, .sha256 = digest } };
    Gate.armed.store(true, .release);
    var creator = try t.io.concurrent(local.Backend.putNative, .{ &f.owner, 1, .block, address, body, false });
    defer _ = creator.cancel(t.io) catch {};
    defer Gate.release.set(t.io);
    try waitFor(&Gate.entered);
    try t.expectEqualDeep(allocation, (try f.owner.allocations.read(allocation.name())).?);
    // The private creator holds neither the journal nor the allocation queue
    // while waiting to publish. Accepted fencing and marking can still finish.
    const cut = try f.submit(.{ .storage_fence = {} });
    try f.collector.start(&f.engine, cut);
    try f.until(.wait);
    try f.elapse();
    try f.until(.deleting);
    // Bootstrap may leave earlier unreachable allocations. Reclamation joins
    // all in-flight creators before consuming any eligible allocation.
    var started: std.Io.Event = .unset;
    var done: std.Io.Event = .unset;
    var reclaim = try t.io.concurrent(Gate.reclaim, .{ &f, &started, &done });
    defer _ = reclaim.cancel(t.io) catch {};
    try waitFor(&started);
    try t.expectError(error.ProgressTimeout, waitFor(&done));
    try t.expect(!Gate.release.isSet());
    Gate.release.set(t.io);
    try creator.await(t.io);
    try reclaim.await(t.io);
    try f.until(.complete);
    var key: [96]u8 = undefined;
    try t.expect(try f.owner.objects.objectStore().head(try allocation.key(&key)) == null);
    try t.expect(try f.owner.allocations.read(allocation.name()) == null);
    f.close();
    try f.open(tmp.dir, false);
    try t.expect(try f.owner.objects.objectStore().head(try allocation.key(&key)) == null);
    try t.expect(try f.owner.allocations.read(allocation.name()) == null);
}

test "paused native collection publication and deletion permit independent data acceptance" {
    const Gate = struct {
        var real: *const std.Io.VTable = undefined;
        var armed: std.atomic.Value(bool) = .init(false);
        var entered: std.Io.Event = .unset;
        var release: std.Io.Event = .unset;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            if (armed.swap(false, .acq_rel)) {
                entered.set(t.io);
                try release.wait(t.io);
            }
            return real.fileSync(context, file);
        }
        fn collect(f: *Fixture, start: ?u64) !void {
            if (start) |cut| return f.collector.start(&f.engine, cut);
            try t.expect(try f.step());
        }
        fn readAndAppend(owner: *local.Backend, genesis: core.growing.Genesis, done: *std.Io.Event) !void {
            defer done.set(t.io);
            var pages = try local.PageStore.init(owner, 1);
            defer pages.deinit();
            var journal: local.Store = .{ .backend = owner };
            var engine = try Engine.open(&journal, &pages, genesis);
            try t.expect((try engine.principal(0)).sequence != 0);
            var data: local.DataStore = .{ .backend = owner };
            _ = try data.log().append(17, 0, engine.head.storage_epoch, engine.head.authorization.revision + 1, .row_delta, "accepted during native collection");
            try t.expectEqual(@as(u64, 1), try data.log().tail(17));
        }
    };
    const waitFor = @import("native_test.zig").waitFor;
    Gate.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Gate.sync;
    var io = t.io;
    io.vtable = &vtable;
    for ([_]bool{ false, true }) |deleting| {
        Gate.entered = .unset;
        Gate.release = .unset;
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var f: Fixture = .{};
        try f.openWithIo(tmp.dir, true, io);
        defer f.close();
        _ = try f.orphan("unreachable native block");
        const cut = try f.submit(.{ .storage_fence = {} });
        if (deleting) {
            try f.collector.start(&f.engine, cut);
            try f.until(.wait);
            try f.elapse();
            try f.until(.deleting);
        }
        const pending = if (deleting) (try f.collector.current()).?.pending else null;
        Gate.armed.store(true, .release);
        var collector = try t.io.concurrent(Gate.collect, .{ &f, if (deleting) @as(?u64, null) else cut });
        defer _ = collector.cancel(t.io) catch {};
        defer Gate.release.set(t.io);
        try waitFor(&Gate.entered);
        var done: std.Io.Event = .unset;
        var reader = try t.io.concurrent(Gate.readAndAppend, .{ &f.owner, f.engine.genesis, &done });
        defer _ = reader.cancel(t.io) catch {};
        try waitFor(&done);
        try reader.await(t.io);
        try t.expect(!Gate.release.isSet());
        Gate.release.set(t.io);
        try collector.await(t.io);
        f.close();
        try f.open(tmp.dir, false);
        var data: local.DataStore = .{ .backend = &f.owner };
        var accepted = try data.log().read(t.allocator, 17, 0, 1);
        defer accepted.deinit();
        try t.expectEqual(@as(usize, 1), accepted.frames.len);
        try t.expectEqualStrings("accepted during native collection", accepted.frames[0].payload);
        const state = (try f.collector.current()).?;
        try t.expectEqual(@as(@TypeOf(state.phase), if (deleting) .sweep else .mark), state.phase);
        if (pending) |item| {
            try t.expect(try f.owner.allocations.read(item.allocation.name()) == null);
            try t.expect((try f.owner.allocations.current()).cursor > item.cursor);
        }
    }
}

test "native collection retains history, fences delayed writers and resumes pending physical deletion" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    const first = try f.submit(.{ .spawn = .{} });
    try f.owner.put("table/unrelated.data", "independent Table owner", false);
    try t.expectError(error.NativeObjectReserved, f.owner.put("native/b/reserved", "bypass", false));
    const historical = f.engine.head.catalog;
    _ = try f.submit(.{ .spawn = .{} });
    const abandoned = try f.orphan("never accepted block");
    var stale = try local.PageStore.init(&f.owner, 0);
    // Stale creator retains its epoch across the accepted fence.
    try stale.begin(1, false);
    const cut = try f.submit(.{ .storage_fence = {} });
    try f.collector.start(&f.engine, cut);
    try t.expectError(error.ActiveStorageCollection, f.collector.start(&f.engine, cut));
    try t.expectError(error.StaleStorageEpoch, stale.stageBlock(try core.protocol.Blocks.Spec.of("late"), "late"));
    stale.deinit();
    const concurrent = try f.submit(.{ .spawn = .{} });
    try f.until(.wait);
    try t.expect(!try f.step());
    try f.elapse();
    try f.until(.deleting);
    const pending = (try f.collector.current()).?.pending.?;
    // A real disk reopen restores the exact pending deletion and private marks.
    f.close();
    try f.open(tmp.dir, false);
    try t.expectEqualDeep(pending, (try f.collector.current()).?.pending.?);
    try f.until(.complete);
    const final = (try f.collector.current()).?;
    try t.expect(!final.aborted);
    try t.expect(final.reclaimed_objects >= 1 and final.reclaimed_bytes > 0 and final.retained_objects > 0);
    f.pages.clearCache();
    var output: [128]u8 = undefined;
    try t.expectError(error.MissingStorageObject, f.pages.loadBlock(abandoned, &output));
    try t.expectEqual(first, (try f.engine.process(first)).pid);
    try t.expectEqual(concurrent, (try f.engine.process(concurrent)).pid);
    try t.expectEqualStrings("independent Table owner", try f.owner.read("table/unrelated.data", &output));
    var old = try core.catalog.Catalog(local.PageStore).open(&f.pages, historical);
    try t.expect((try old.get(g.Process, try core.catalog.key(.process, first, 0, ""))) != null);
    // Reopening confirms that physical cleanup preserved complete native recovery.
    f.close();
    try f.open(tmp.dir, false);
    try t.expectEqual(concurrent, (try f.engine.process(concurrent)).pid);
    // The saved complete phase finishes graph reclamation, but an interrupted
    // FIFO trim still resumes in bounded physical units after reopening.
    var cleanup_units: usize = 0;
    while (true) {
        const disk = f.owner.allocations.queue.disk.?;
        const entries = disk.trim_entries;
        const frames = disk.trim_frames;
        const segments = disk.trim_segments;
        const progressed = try f.step();
        try t.expect(disk.trim_entries - entries <= 32);
        try t.expect(disk.trim_frames - frames <= 1);
        try t.expect(disk.trim_segments - segments <= 1);
        if (!progressed) break;
        cleanup_units += 1;
        try t.expect(cleanup_units < 2000);
    }
    try t.expect(cleanup_units > 1);
    try t.expectEqual(concurrent, (try f.engine.process(concurrent)).pid);
}

test "native collection aborts an incomplete retained-root mark after authorized history trim" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    const abandoned = try f.orphan("retained on aborted mark");
    const cut = try f.submit(.{ .storage_fence = {} });
    try f.collector.start(&f.engine, cut);
    _ = try f.submit(.{ .checkpoint = {} });
    try f.journal.maintain(f.engine.head);
    try f.until(.complete);
    const final = (try f.collector.current()).?;
    try t.expect(final.aborted);
    try t.expectEqual(@as(u64, 0), final.reclaimed_objects);
    var output: [128]u8 = undefined;
    try t.expectEqualStrings("retained on aborted mark", try f.pages.loadBlock(abandoned, &output));
}

test "native allocation intents retain unpublished content and validate exact retry" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    const abandoned = try f.orphan("unpublished object content");
    var allocation: ?Allocations.Allocation = null;
    const queue = try f.owner.allocations.current();
    var cursor = queue.cursor;
    while (cursor < queue.tail) : (cursor += 1) {
        const item = (try f.owner.allocations.at(cursor)).item orelse continue;
        if (std.mem.eql(u8, &item.address, &abandoned.location)) allocation = item;
    }
    const item = allocation.?;
    try t.expect(!try f.owner.allocations.record(item));
    var wrong = item;
    wrong.meta.sha256[0] ^= 1;
    try t.expectError(error.InvalidNativeAllocation, f.owner.allocations.record(wrong));
    var name: [96]u8 = undefined;
    const key = try item.key(&name);
    // Descriptor loss/publication failure does not lose the physical inventory.
    try f.owner.objects.deleteObject(key);
    try t.expectEqual(null, try f.owner.objects.headObject(key));
    const cut = try f.submit(.{ .storage_fence = {} });
    try f.collector.start(&f.engine, cut);
    try f.until(.wait);
    try f.elapse();
    try f.until(.complete);
    try t.expectEqual(null, try f.owner.allocations.read(item.name()));
    try t.expectEqual(@as(u64, 0), try f.owner.objects.reclaimImmutableObject(key, item.meta));
    try t.expect((try f.collector.current()).?.reclaimed_bytes >= item.meta.size);
}

test "native collection preserves independent captured blocks across compaction and checkpoint" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    const pid = try f.submit(.{ .spawn = .{} });
    const resource = try f.submit(.{ .create_resource = .{ .writer = pid, .owned = false } });
    _ = try f.submit(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = 7 } });
    _ = try f.submit(.{ .associate = .{ .pid = pid, .resource = resource, .name = try .init("data"), .required = false } });
    _ = try f.submit(.{ .own = .{ .pid = pid, .worker = 0, .expected_generation = (try f.engine.process(pid)).generation } });
    var retained: g.ReadVersionId = undefined;
    for ([_][]const u8{ "retained complete value", "current complete value" }, 0..) |value, i| {
        var command = try f.proposal(pid, resource);
        var batch: core.protocol.Blocks.Batch = .{};
        try batch.put(try .init("row"), value);
        command.turn.blocks = batch.mutations;
        _ = try f.engine.submitWithBlocks(try f.signed(.{ .turn_with_versions = command }), &batch.body);
        if (i == 1) retained = .{ .pid = pid, .input = command.turn.input, .index = 0 };
    }
    var current = try f.engine.state();
    const snapshot = (try current.get(core.catalog.Snapshot, core.growing.address(.resource_blocks, resource))).?;
    var index = try core.catalog.Catalog(local.PageStore).open(&f.pages, snapshot);
    const old = (try index.get(core.blocks.Record, try core.catalog.key(.entry, 0, 0, "row"))).?.reference;
    const before = (try f.query(.{ .resource = resource })).body.resource;
    for (0..1024) |_| {
        if (f.engine.head.compaction.phase == .complete) break;
        _ = try f.submit(.{ .storage_compact = {} });
        try t.expectEqualDeep(before, (try f.query(.{ .resource = resource })).body.resource);
    } else return error.FixtureBudget;
    _ = try f.submit(.{ .checkpoint = {} });
    try f.journal.maintain(f.engine.head);
    const cut = try f.submit(.{ .storage_fence = {} });
    try f.collector.start(&f.engine, cut);
    try f.until(.wait);
    // Physical pressure cannot turn the live captured version into garbage.
    f.owner.limits.bytes = f.owner.allocated;
    try t.expectError(error.StorageQuota, f.submit(.{ .spawn = .{} }));
    try f.elapse();
    try f.until(.complete);
    f.pages.clearCache();
    var bytes: [128]u8 = undefined;
    try t.expectError(error.MissingStorageObject, f.pages.loadBlock(old, &bytes));
    const data = (try f.query(.{ .resource = resource })).body.resource;
    const generation = (try f.engine.process(pid)).generation;
    try f.block(.{ .resource = .{ .id = resource, .revision = data.revision } }, "current complete value");
    try f.block(.{ .version = .{ .id = retained, .generation = generation } }, "retained complete value");
    f.close();
    try f.open(tmp.dir, false);
    try f.block(.{ .resource = .{ .id = resource, .revision = data.revision } }, "current complete value");
    try f.block(.{ .version = .{ .id = retained, .generation = generation } }, "retained complete value");
    _ = try f.submit(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = 0 } });
    try t.expectError(error.Forbidden, f.block(.{ .version = .{ .id = retained, .generation = generation } }, "retained complete value"));
}

test "native allocation FIFO carries ownership exactly once across every consume sync fault" {
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var remaining: usize = 0;
        var calls: usize = 0;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            calls += 1;
            if (remaining != 0) {
                remaining -= 1;
                if (remaining == 0) return error.InputOutput;
            }
            return real.fileSync(context, file);
        }
    };
    Fault.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var io = t.io;
    io.vtable = &vtable;
    const item: Allocations.Allocation = .{ .epoch = 1, .kind = .block, .address = @splat(17), .meta = .{ .size = 9, .sha256 = @splat(31) } };
    var schedules: usize = 0;
    var failure: usize = 0;
    while (failure <= schedules) : (failure += 1) {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        try tmp.dir.createDirPath(t.io, "native-allocations");
        {
            var queue = try Allocations.open(t.allocator, io, tmp.dir);
            defer queue.deinit();
            try t.expect(try queue.record(item));
            Fault.calls = 0;
            Fault.remaining = failure;
            if (failure == 0) {
                try queue.consume(0, item, true);
                schedules = Fault.calls;
                try t.expect(schedules > 0 and schedules < 16);
            } else {
                try t.expectError(error.InputOutput, queue.consume(0, item, true));
                try t.expectEqual(@as(usize, 0), Fault.remaining);
            }
        }
        var reopened = try Allocations.open(t.allocator, t.io, tmp.dir);
        defer reopened.deinit();
        const before = try reopened.current();
        try t.expect(before.cursor <= 1);
        if (before.cursor == 0) try reopened.consume(0, item, true);
        const after = try reopened.current();
        try t.expectEqual(@as(u64, 1), after.cursor);
        try t.expectEqualDeep(item, (try reopened.at(after.tail - 1)).item.?);
        try t.expectError(error.AllocationConflict, reopened.consume(0, item, true));
        try reopened.trim();
        try t.expectEqualDeep(after, try reopened.current());
        try t.expectEqualDeep(item, (try reopened.read(item.name())).?);
    }
}

test "native collection refuses corrupted marks and allocation metadata before deletion" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    const abandoned = try f.orphan("protected by failed verification");
    const cut = try f.submit(.{ .storage_fence = {} });
    try f.collector.start(&f.engine, cut);
    const state = try f.owner.directory.openFile(t.io, ".native-collection", .{ .mode = .read_write });
    defer state.close(t.io);
    var original: [1]u8 = undefined;
    try t.expectEqual(@as(usize, 1), try state.readPositionalAll(t.io, &original, 0));
    try state.writePositionalAll(t.io, "!", 0);
    try t.expectError(error.InvalidStorageCollection, f.step());
    try state.writePositionalAll(t.io, &original, 0);
    try f.until(.wait);
    try f.elapse();
    try f.until(.deleting);
    const pending = (try f.collector.current()).?.pending.?.allocation;
    const record = try f.owner.allocations.directory.openFile(t.io, &pending.name(), .{ .mode = .read_write });
    defer record.close(t.io);
    try t.expectEqual(@as(usize, 1), try record.readPositionalAll(t.io, &original, 0));
    try record.writePositionalAll(t.io, "!", 0);
    try t.expectError(error.InvalidNativeAllocation, f.step());
    var bytes: [128]u8 = undefined;
    try t.expectEqualStrings("protected by failed verification", try f.pages.loadBlock(abandoned, &bytes));
    try record.writePositionalAll(t.io, &original, 0);
    try f.until(.complete);
}

test "native owner rejects missing allocation history without resetting persisted objects" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var f: Fixture = .{};
        try f.open(tmp.dir, true);
        defer f.close();
        _ = try f.submit(.{ .spawn = .{} });
    }
    try tmp.dir.deleteTree(t.io, "native/native-allocations/queue");
    try t.expectError(error.MissingAllocationHistory, local.Backend.open(t.allocator, t.io, tmp.dir, "native", .{}));
    try t.expectError(error.FileNotFound, tmp.dir.openDir(t.io, "native/native-allocations/queue", .{}));
    const directory = try tmp.dir.openDir(t.io, "native/keys", .{ .iterate = true });
    defer directory.close(t.io);
    var iterator = directory.iterate();
    try t.expect(try iterator.next(t.io) != null);
}
