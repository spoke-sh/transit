const std = @import("std");
const t = std.testing;
const core = @import("transit_core");
const backend = @import("root.zig");
const g = core.protocol.Growth;
const Engine = core.growing.Engine(backend.Store, backend.PageStore);

fn rootKey() !core.Ed25519.KeyPair {
    return core.Ed25519.KeyPair.generateDeterministic(@splat(17));
}
fn genesis() !core.growing.Genesis {
    return .{ .realm = 42, .root_key = (try rootKey()).public_key.toBytes(), .max_clock_error_ms = 5, .allow_history_trim = true };
}
fn submit(engine: *Engine, command: g.Command) !u64 {
    const sequence = (try engine.principal(0)).sequence + 1;
    return engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = sequence, .command = command }, try rootKey()));
}
fn query(engine: *Engine, kind: @FieldType(g.Query, "kind")) !g.Response {
    return engine.query(try g.signQuery(.{ .realm = 42, .principal = 0, .kind = kind }, try rootKey()));
}
fn clock(_: *anyopaque) anyerror!core.Time.Sample {
    return .{ .unix_ms = 100 };
}

pub fn waitFor(event: *std.Io.Event) !void {
    const Result = union(enum) { ready: anyerror!void, timeout: anyerror!void };
    var results: [2]Result = undefined;
    var select: std.Io.Select(Result) = .init(t.io, &results);
    defer select.cancelDiscard();
    try select.concurrent(.timeout, std.Io.sleep, .{ t.io, .fromSeconds(10), .awake });
    try select.concurrent(.ready, std.Io.Event.wait, .{ event, t.io });
    switch (try select.await()) {
        .ready => |result| try result,
        .timeout => |result| {
            try result;
            return error.ProgressTimeout;
        },
    }
}

test "paused private object sync permits native reads and quota-reserved control publication" {
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

        fn control(owner: *backend.Backend, done: *std.Io.Event) !void {
            defer done.set(t.io);
            var bytes: [32]u8 = undefined;
            try t.expectEqualStrings("already durable", try owner.read("ready", &bytes));
            var data: backend.DataStore = .{ .backend = owner };
            try t.expect(try data.objects().head("ready") != null);
            try t.expectEqualStrings("already durable", try data.objects().getRange("ready", 0, bytes.len, &bytes));
            try t.expect(try data.objects().head("private") == null);
            var pages = try backend.PageStore.init(owner, 1);
            defer pages.deinit();
            var journal: backend.Store = .{ .backend = owner };
            var engine = try Engine.open(&journal, &pages, try genesis());
            try t.expectEqual(@as(u64, 0), (try engine.principal(0)).sequence);
            // The paused write has already reserved its bytes. Other staging
            // still obeys the data quota; control publication uses its reserve.
            try owner.mutex.lock(owner.io);
            const limits = owner.limits;
            owner.limits.bytes = owner.allocated;
            owner.mutex.unlock(owner.io);
            defer {
                owner.mutex.lockUncancelable(owner.io);
                owner.limits = limits;
                owner.mutex.unlock(owner.io);
            }
            try t.expectError(error.StorageQuota, owner.put("over-quota", "data", false));
            _ = try submit(&engine, .{ .checkpoint = {} });
            try t.expectEqual(@as(u64, 2), try journal.tail());
        }
    };
    Gate.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Gate.sync;
    var io = t.io;
    io.vtable = &vtable;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var owner = try backend.Backend.open(t.allocator, io, tmp.dir, "native", .{});
        defer owner.deinit();
        var pages = try backend.PageStore.init(&owner, 1);
        defer pages.deinit();
        var journal: backend.Store = .{ .backend = &owner };
        _ = try Engine.bootstrap(&journal, &pages, try genesis());
        try owner.put("ready", "already durable", false);
        Gate.armed.store(true, .release);
        var writer = try t.io.concurrent(backend.Backend.put, .{ &owner, "private", "staged bytes", false });
        defer _ = writer.cancel(t.io) catch {};
        defer Gate.release.set(t.io);
        try waitFor(&Gate.entered);
        var done: std.Io.Event = .unset;
        var control = try t.io.concurrent(Gate.control, .{ &owner, &done });
        defer _ = control.cancel(t.io) catch {};
        try waitFor(&done);
        try control.await(t.io);
        try t.expect(!Gate.release.isSet());
        Gate.release.set(t.io);
        try writer.await(t.io);
    }
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.open(&journal, &pages, try genesis());
    try t.expectEqual(@as(u64, 1), (try engine.principal(0)).sequence);
    var bytes: [32]u8 = undefined;
    try t.expectEqualStrings("staged bytes", try owner.read("private", &bytes));
    try t.expect(try owner.objects.objectStore().head("over-quota") == null);
}

test "paused native allocation sync permits native reads and independent data acceptance" {
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
        fn readAndAppend(owner: *backend.Backend, done: *std.Io.Event) !void {
            defer done.set(t.io);
            var pages = try backend.PageStore.init(owner, 1);
            defer pages.deinit();
            var journal: backend.Store = .{ .backend = owner };
            var engine = try Engine.open(&journal, &pages, try genesis());
            try t.expectEqual(@as(u64, 0), (try engine.principal(0)).sequence);
            var data: backend.DataStore = .{ .backend = owner };
            _ = try data.log().append(17, 0, engine.head.storage_epoch, engine.head.authorization.revision + 1, .row_delta, "independent accepted frame");
            try t.expectEqual(@as(u64, 1), try data.log().tail(17));
        }
    };
    Gate.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Gate.sync;
    var io = t.io;
    io.vtable = &vtable;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var owner = try backend.Backend.open(t.allocator, io, tmp.dir, "native", .{});
        defer owner.deinit();
        var pages = try backend.PageStore.init(&owner, 1);
        defer pages.deinit();
        var journal: backend.Store = .{ .backend = &owner };
        _ = try Engine.bootstrap(&journal, &pages, try genesis());
        Gate.armed.store(true, .release);
        var writer = try t.io.concurrent(backend.Backend.putNative, .{ &owner, 1, .block, @as([32]u8, @splat(44)), "private native bytes", false });
        defer _ = writer.cancel(t.io) catch {};
        defer Gate.release.set(t.io);
        try waitFor(&Gate.entered);
        var done: std.Io.Event = .unset;
        var reader = try t.io.concurrent(Gate.readAndAppend, .{ &owner, &done });
        defer _ = reader.cancel(t.io) catch {};
        try waitFor(&done);
        try reader.await(t.io);
        try t.expect(!Gate.release.isSet());
        Gate.release.set(t.io);
        try writer.await(t.io);
    }
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var data: backend.DataStore = .{ .backend = &owner };
    var accepted = try data.log().read(t.allocator, 17, 0, 1);
    defer accepted.deinit();
    try t.expectEqual(@as(usize, 1), accepted.frames.len);
    try t.expectEqualStrings("independent accepted frame", accepted.frames[0].payload);
}

test "native publication survives a lost reply and restart without repeating accepted work" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const intent = try g.sign(.{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .spawn = .{} } }, try rootKey());
    var accepted_head: core.growing.Head = undefined;
    {
        var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
        defer owner.deinit();
        var pages = try backend.PageStore.init(&owner, 2);
        defer pages.deinit();
        var journal: backend.Store = .{ .backend = &owner };
        var engine = try Engine.bootstrap(&journal, &pages, try genesis());
        journal.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, engine.submit(intent));
        journal.lose_reply = false;
        try engine.refresh();
        accepted_head = engine.head;
        try t.expectEqual(@as(u64, 2), try journal.tail());
    }
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.open(&journal, &pages, try genesis());
    try t.expect(std.meta.eql(accepted_head, engine.head));
    try t.expectEqual(@as(u64, 1), try engine.submit(intent));
    try t.expectEqual(@as(u64, 2), try journal.tail());
    try t.expectEqual(@as(u64, 1), (try engine.process(1)).pid);
}

test "native pages and immutable blocks grow beyond a one-page cache and reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var root: ?core.pages.Reference = null;
    var block: core.blocks.Reference = undefined;
    {
        var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
        defer owner.deinit();
        var pages = try backend.PageStore.init(&owner, 1);
        defer pages.deinit();
        const tree: core.pages.Tree(backend.PageStore) = .{ .store = &pages };
        for (0..129) |i| {
            try pages.begin(1, false);
            var key: [8]u8 = undefined;
            std.mem.writeInt(u64, &key, i, .big);
            root = try tree.mutate(root, &.{.{ .key = try core.pages.Key.init(&key), .value = try core.pages.Value.init(&key) }});
            try pages.finish();
        }
        try pages.begin(1, false);
        block = try pages.stageBlock(try core.protocol.Blocks.Spec.of("document bytes"), "document bytes");
        try pages.finish();
        try t.expect(pages.misses > 1);
    }
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    const tree: core.pages.Tree(backend.PageStore) = .{ .store = &pages };
    for (0..129) |i| {
        var key: [8]u8 = undefined;
        std.mem.writeInt(u64, &key, i, .big);
        const value = (try tree.get(root, try core.pages.Key.init(&key))).?;
        try t.expectEqualSlices(u8, &key, value.slice());
    }
    var output: [64]u8 = undefined;
    try t.expectEqualStrings("document bytes", try pages.loadBlock(block, &output));
}

test "local quota reserves control capacity and never turns a failed candidate into visibility" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 0);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.bootstrap(&journal, &pages, try genesis());
    const accepted = engine.head;
    owner.limits.bytes = owner.allocated;
    try t.expectError(error.StorageQuota, submit(&engine, .{ .spawn = .{} }));
    try t.expect(std.meta.eql(accepted, engine.head));
    try t.expectEqual(@as(u64, 1), try journal.tail());
    try t.expectEqual(@as(u64, 0), (try engine.principal(0)).sequence);
    // The explicit checkpoint is a control operation. Exhausted data admission
    // cannot prevent its publication or authorize deleting other objects.
    _ = try submit(&engine, .{ .checkpoint = {} });
    try journal.maintain(engine.head);
    try t.expectEqual(@as(u64, 2), try journal.tail());
}

test "local native turn atomically recovers state, blocks, input progress, outputs and undispatched effect" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var pid: u64 = undefined;
    var resource: u64 = undefined;
    var accepted: u64 = undefined;
    var intent: g.SignedRequest = undefined;
    const row_key = try core.Value.init("row");
    const block_key = try core.Value.init("document");
    var clock_context: u8 = 0;
    {
        var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
        defer owner.deinit();
        var pages = try backend.PageStore.init(&owner, 2);
        defer pages.deinit();
        var journal: backend.Store = .{ .backend = &owner };
        var engine = try Engine.bootstrap(&journal, &pages, try genesis());
        engine.clock = .{ .context = &clock_context, .read = clock };
        pid = try submit(&engine, .{ .spawn = .{} });
        resource = try submit(&engine, .{ .create_resource = .{ .writer = pid } });
        _ = try submit(&engine, .{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
        _ = try submit(&engine, .{ .associate = .{ .pid = pid, .name = try core.Value.init("data"), .resource = resource } });
        _ = try submit(&engine, .{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 0 } });
        const input = try submit(&engine, .{ .send = .{ .pid = pid, .value = .{} } });
        const process = try engine.process(pid);
        const view = try submit(&engine, .{ .open_view = .{ .pid = pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .resource = resource, .revision = resource, .deadline_ms = 150 } });
        var batch: core.protocol.Blocks.Batch = .{};
        try batch.put(block_key, "verified document payload");
        const turn: g.Turn = .{
            .pid = pid,
            .generation = process.generation,
            .input = input,
            .expected_revision = process.revision,
            .views = .{ view, null, null, null },
            .write_view = view,
            .mutations = .{ .{ .key = row_key, .value = core.Value.integer(42) }, null, null, null },
            .blocks = batch.mutations,
            .outputs = .{ .{ .pid = pid, .value = try core.Value.init("outcome") }, null, null, null },
            .effect = try core.Value.init("recorded intent"),
        };
        intent = try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = .{ .turn = turn } }, try rootKey());
        const prepared = try engine.prepareWithBlocks(intent, &batch.body);
        accepted = engine.head.position;
        try t.expectEqual(@as(u64, 0), (try engine.process(pid)).consumed);
        try t.expectEqual(@as(u64, 0), (try query(&engine, .{ .resource = resource })).body.resource.entries);
        try t.expectEqual(@as(u64, 0), engine.head.outputs);
        journal.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, engine.commit(prepared));
    }
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.open(&journal, &pages, try genesis());
    engine.clock = .{ .context = &clock_context, .read = clock };
    const writes = pages.created;
    try t.expectEqual(accepted, try engine.submit(intent));
    try t.expectEqual(writes, pages.created);
    try t.expectEqual(@as(u64, 1), (try engine.process(pid)).consumed);
    try t.expectEqual(@as(u64, 1), engine.head.outputs);
    const data = (try query(&engine, .{ .resource = resource })).body.resource;
    try t.expectEqual(@as(u64, 1), data.entries);
    try t.expectEqual(@as(u64, 1), data.block_entries);
    const rows = try query(&engine, .{ .read_entries = .{ .resource = resource, .keys = .{ row_key, null, null, null, null, null, null, null } } });
    try t.expectEqual(@as(i64, 42), try rows.body.read_entries.entries[0].?.value.asInteger());
    const effects = try query(&engine, .{ .effects = .{ .pid = pid } });
    try t.expectEqual(.pending, effects.body.effects.entries[0].?.phase);
    try t.expectEqual(@as(?u64, null), effects.body.effects.entries[0].?.attempt);
    const read: g.Query = .{ .realm = 42, .principal = 0, .kind = .{ .block_entries = .{ .source = .{ .resource = .{ .id = resource, .revision = data.revision } }, .keys = .{ block_key, null, null, null, null, null, null, null } } } };
    var result: g.BlockRead.Response = undefined;
    result.response = try engine.queryBlocks(try g.signQuery(read, try rootKey()), {}, &result.blocks);
    try g.BlockRead.verify(&result, read);
    try t.expectEqualStrings("verified document payload", result.blocks.slice());
    _ = try submit(&engine, .{ .checkpoint = {} });
    try journal.maintain(engine.head);
    // Receipt identity survives physical removal of its old log entry.
    try t.expectEqual(accepted, try engine.submit(intent));
    _ = try submit(&engine, .{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = 0 } });
    try t.expectError(error.Forbidden, engine.queryBlocks(try g.signQuery(read, try rootKey()), {}, &result.blocks));
    try t.expectEqual(@as(u32, 0), result.blocks.len);
}

test "local effect attempts and terminal outcomes survive lost replies and trimmed restart" {
    for ([_]bool{ false, true }) |abandon| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var clock_context: u8 = 0;
        var pid: u64 = undefined;
        var effect: u64 = undefined;
        var attempt: u64 = undefined;
        var terminal: u64 = undefined;
        var dispatch: g.SignedRequest = undefined;
        var outcome: g.SignedRequest = undefined;
        for (0..5) |phase| {
            var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
            defer owner.deinit();
            var pages = try backend.PageStore.init(&owner, 1);
            defer pages.deinit();
            var journal: backend.Store = .{ .backend = &owner };
            var engine = if (phase == 0) try Engine.bootstrap(&journal, &pages, try genesis()) else try Engine.open(&journal, &pages, try genesis());
            engine.clock = .{ .context = &clock_context, .read = clock };
            if (phase == 0) {
                pid = try submit(&engine, .{ .spawn = .{ .allow_collection = true } });
                _ = try submit(&engine, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 0 } });
                const input = try submit(&engine, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
                const process = try engine.process(pid);
                effect = try submit(&engine, .{ .turn = .{
                    .pid = pid,
                    .generation = process.generation,
                    .input = input,
                    .expected_revision = process.revision,
                    .effect = core.Value.integer(9),
                } });
                dispatch = try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = .{ .dispatch = .{ .pid = pid, .effect = effect } } }, try rootKey());
                attempt = engine.head.position;
                journal.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, engine.submit(dispatch));
                continue;
            }
            const saved = (try query(&engine, .{ .effects = .{ .pid = pid } })).body.effects.entries[0].?;
            try t.expectEqual(effect, saved.id);
            try t.expectEqual(@as(?u64, attempt), saved.attempt);
            try t.expectEqual(@as(i64, 9), try saved.payload.asInteger());
            if (phase == 1) {
                // Reopening an authorized attempt neither invents its outcome
                // nor creates another dispatch. Resolve the original request.
                try t.expectEqual(.authorized, saved.phase);
                const position = engine.head.position;
                const created = pages.created;
                try t.expectEqual(attempt, try engine.submit(dispatch));
                try t.expectEqual(position, engine.head.position);
                try t.expectEqual(created, pages.created);
                try t.expectError(error.AttemptAlreadyAuthorized, submit(&engine, .{ .dispatch = .{ .pid = pid, .effect = effect } }));
                _ = try submit(&engine, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = null } });
                _ = try submit(&engine, .{ .checkpoint = {} });
                try journal.maintain(engine.head);
            } else if (phase == 2) {
                try t.expectError(error.HistoryReclaimed, journal.read(0));
                try t.expectEqual(.unknown, saved.phase);
                try t.expect(saved.result == null and saved.closure == null);
                _ = try submit(&engine, .{ .terminate = pid });
                const command: g.Command = if (abandon)
                    .{ .close_effect = .{ .pid = pid, .effect = effect, .attempt = attempt } }
                else
                    .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = core.Value.integer(10) } };
                outcome = try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = command }, try rootKey());
                terminal = engine.head.position;
                journal.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, engine.submit(outcome));
            } else {
                try t.expectEqual(@as(@TypeOf(saved.phase), if (abandon) .closed_unknown else .observed), saved.phase);
                try t.expectEqual(@as(@TypeOf(saved.closure.?.reason), if (abandon) .abandoned else .observed), saved.closure.?.reason);
                try t.expectEqual(if (abandon) @as(?i64, null) else 10, if (saved.result) |value| try value.asInteger() else null);
                const process = try engine.process(pid);
                try t.expectEqual(.terminated, process.lifecycle);
                try t.expectEqual(@as(u64, 1), process.admitted);
                try t.expectEqual(@as(u64, 1), process.consumed);
                const position = engine.head.position;
                const created = pages.created;
                try t.expectEqual(terminal, try engine.submit(outcome));
                try t.expectEqual(position, engine.head.position);
                try t.expectEqual(created, pages.created);
                try t.expectError(error.ReconciliationClosed, submit(&engine, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = core.Value.integer(99) } }));
                try t.expectError(error.RetiredProcess, submit(&engine, .{ .dispatch = .{ .pid = pid, .effect = effect } }));
                if (phase == 3) {
                    _ = try submit(&engine, .{ .checkpoint = {} });
                    try journal.maintain(engine.head);
                } else try t.expectError(error.HistoryReclaimed, journal.read(0));
            }
        }
    }
}

test "native owner rejects a second owner, foreign marker and unrelated object history" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
        defer owner.deinit();
        try t.expectError(error.NativeStorageInUse, backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{}));
    }
    {
        const marker = try tmp.dir.openFile(t.io, "native/.native-owner", .{ .mode = .read_write });
        defer marker.close(t.io);
        try marker.writePositionalAll(t.io, "x", 8);
        try marker.sync(t.io);
    }
    try t.expectError(error.IncompatibleDefinition, backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{}));
    {
        var objects = try @import("transit_storage").LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "unrelated");
        defer objects.deinit();
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash("accepted elsewhere", &digest, .{});
        _ = try objects.objectStore().putImmutable("existing", "accepted elsewhere", digest);
    }
    try t.expectError(error.NativeStorageUnmarked, backend.Backend.open(t.allocator, t.io, tmp.dir, "unrelated", .{}));
}

test "two native candidates share only conditional WAL acceptance" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages_a = try backend.PageStore.init(&owner, 1);
    defer pages_a.deinit();
    var pages_b = try backend.PageStore.init(&owner, 1);
    defer pages_b.deinit();
    var journal_a: backend.Store = .{ .backend = &owner };
    var journal_b: backend.Store = .{ .backend = &owner };
    var a = try Engine.bootstrap(&journal_a, &pages_a, try genesis());
    var b = try Engine.open(&journal_b, &pages_b, try genesis());
    const first = try g.sign(.{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .spawn = .{ .code = 2 } } }, try rootKey());
    const second = try g.sign(.{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .spawn = .{ .code = 3 } } }, try rootKey());
    const proposed_a = try a.prepare(first);
    const proposed_b = try b.prepare(second);
    try t.expectEqual(@as(u64, 1), try journal_a.tail());
    _ = try a.commit(proposed_a);
    try t.expectError(error.Conflict, b.commit(proposed_b));
    try b.refresh();
    try t.expectEqual(@as(u64, 2), (try b.process(1)).code);
    try t.expectEqual(@as(u64, 2), try journal_b.tail());
    try t.expect(std.meta.eql(a.head, b.head));
}
