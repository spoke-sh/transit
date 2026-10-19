//! Disk-backed collection fixture with an explicitly injected trusted clock.
//! Production hosts use their configured UTC source and the full grace interval.
const std = @import("std");
const core = @import("transit_core");
const backend = @import("transit_backend_ursula");
const g = core.protocol.Growth;
const t = std.testing;
const Engine = core.growing.Engine(backend.Store, backend.PackedPageStore);
const Clock = struct {
    now: u64 = 100,
    fn read(context: *anyopaque) anyerror!core.Time.Sample {
        return .{ .unix_ms = @as(*Clock, @ptrCast(@alignCast(context))).now };
    }
};
fn signed(engine: *Engine, command: g.Command) !g.SignedRequest {
    const key = try core.Ed25519.KeyPair.generateDeterministic(@splat(9));
    return g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = command }, key);
}
fn submit(engine: *Engine, command: g.Command) !u64 {
    return engine.submit(try signed(engine, command));
}
fn query(engine: *Engine, kind: @FieldType(g.Query, "kind")) !g.Response {
    return engine.query(try g.signQuery(.{ .realm = 42, .principal = 0, .kind = kind }, try core.Ed25519.KeyPair.generateDeterministic(@splat(9))));
}
fn proposal(engine: *Engine, pid: u64, resource: u64, now: u64) !g.TurnWithVersions {
    const input = try submit(engine, .{ .send = .{ .pid = pid, .value = .{} } });
    const process = try engine.process(pid);
    const data = (try query(engine, .{ .resource = resource })).body.resource;
    const view = try submit(engine, .{ .open_view = .{ .pid = pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .resource = resource, .revision = data.revision, .deadline_ms = now + 50 } });
    return .{ .turn = .{ .pid = pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .views = .{ view, null, null, null }, .write_view = view }, .retain = .{ view, null, null, null } };
}
fn values(engine: *Engine) !void {
    const data = (try query(engine, .{ .resource = 2 })).body.resource;
    var body: core.protocol.Blocks.Body = .{};
    const key = try core.Value.init("row");
    const request: g.Query = .{ .realm = 42, .principal = 0, .kind = .{ .block_entries = .{ .source = .{ .resource = .{ .id = 2, .revision = data.revision } }, .keys = .{ key, null, null, null, null, null, null, null } } } };
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(9));
    _ = try engine.queryBlocks(try g.signQuery(request, root), {}, &body);
    try t.expectEqualStrings("current complete value", body.slice());
    var state = try engine.state();
    const versions = try state.scan(core.growing.StoredReadVersion, .{ .namespace = .read_version }, null);
    var found = false;
    for (versions.records) |slot| if (slot) |record| {
        var read = request;
        read.kind.block_entries.source = .{ .version = .{ .id = record.value.meta.id, .generation = (try engine.process(1)).generation } };
        _ = try engine.queryBlocks(try g.signQuery(read, root), {}, &body);
        if (body.len != 0) {
            try t.expectEqualStrings("retained complete value", body.slice());
            found = true;
        }
    };
    try t.expect(found);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    var client = try backend.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 256 * 1024 });
    defer client.deinit();
    var journal: backend.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-collection-proof", .name = "authority" } } };
    var pages = try backend.PackedPageStore.init(init.gpa, journal.journal, 1);
    defer pages.deinit();
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const genesis: core.growing.Genesis = .{ .realm = 42, .root_key = root.public_key.toBytes(), .max_clock_error_ms = 100, .allow_history_trim = true };
    const initialize = std.mem.eql(u8, args[2], "initialize");
    if (initialize) {
        try journal.journal.create();
        try pages.create();
    }
    var engine = if (initialize) try Engine.bootstrap(&journal, &pages, genesis) else try Engine.open(&journal, &pages, genesis);
    var clock: Clock = .{ .now = @max(100, engine.head.time_floor_ms) };
    engine.clock = .{ .context = &clock, .read = Clock.read };
    var collection = backend.StorageCollection.init(journal.journal);
    var relocated_from: ?backend.Segment.Identity = null;
    if (initialize) {
        const pid = try submit(&engine, .{ .spawn = .{} });
        const resource = try submit(&engine, .{ .create_resource = .{ .writer = pid, .owned = false } });
        try t.expectEqual(@as(u64, 1), pid);
        try t.expectEqual(@as(u64, 2), resource);
        _ = try submit(&engine, .{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = 7 } });
        _ = try submit(&engine, .{ .associate = .{ .pid = pid, .resource = resource, .name = try .init("data"), .required = false } });
        _ = try submit(&engine, .{ .own = .{ .pid = pid, .worker = 0, .expected_generation = 1 } });
        for ([_][]const u8{ "retained complete value", "current complete value" }) |value| {
            var command = try proposal(&engine, pid, resource, clock.now);
            var batch: core.protocol.Blocks.Batch = .{};
            try batch.put(try .init("row"), value);
            command.turn.blocks = batch.mutations;
            _ = try engine.submitWithBlocks(try signed(&engine, .{ .turn_with_versions = command }), &batch.body);
        }
        try values(&engine);
        _ = try submit(&engine, .{ .checkpoint = {} });
        try journal.maintain(engine.head);
        var queue = try pages.allocations();
        for ([_]u8{ 61, 62 }) |nonce| {
            const identity: backend.Segment.Identity = .{ .epoch = 1, .nonce = @splat(nonce) };
            try queue.reserve(.{ .identity = identity, .bytes = 507, .data_bytes = 7, .frames = 1, .fenced = false, .digest = @splat(7), .control = false });
            if (nonce == 62) {
                const name = try identity.name(journal.journal.stream.bucket, journal.journal.stream.name);
                var open = try client.send(.{ .create_stream = .{ .stream = .{ .bucket = journal.journal.stream.bucket, .name = &name }, .options = .{ .content_type = "application/json", .body = "\"YQ==\"" } } });
                defer open.deinit();
                try open.head.requireSuccess();
            }
        }
        const admitted = try queue.current();
        const previous_head = engine.head;
        pages.limits.bytes = admitted.data_bytes;
        try t.expectError(error.StorageQuota, engine.prepare(try signed(&engine, .{ .spawn = .{} })));
        try t.expectEqualDeep(previous_head, engine.head);
        try t.expectEqualDeep(admitted, try queue.current());
        pages.limits.bytes = 8 * 1024 * 1024 * 1024;
        pages.limits.candidate_bytes = 1;
        try t.expectError(error.StorageCandidateBudget, engine.prepare(try signed(&engine, .{ .spawn = .{} })));
        try t.expectEqualDeep(admitted, try queue.current());
        pages.limits.candidate_bytes = backend.Segment.max_bytes;
        const old = try engine.prepare(try signed(&engine, .{ .spawn = .{} }));
        const fence = try submit(&engine, .{ .storage_fence = {} });
        try t.expectError(error.Conflict, engine.commit(old));
        try collection.start(&engine, fence);
        // A complete orphan is durable but owns no accepted execution root.
        // Its allocation remains visible even after the fixture process exits.
    } else if (std.mem.eql(u8, args[2], "compact")) {
        var current = try engine.state();
        const snapshot = (try current.get(core.catalog.Snapshot, core.growing.address(.resource_blocks, 2))).?;
        var index = try core.catalog.Catalog(backend.PackedPageStore).open(&pages, snapshot);
        const record = (try index.get(core.blocks.Record, try core.catalog.key(.entry, 0, 0, "row"))).?;
        relocated_from = (try backend.Segment.Address.decode(record.reference.location)).identity;
        var steps: usize = 0;
        while (engine.head.compaction.phase != .complete) : (steps += 1) {
            if (steps > 1024) return error.FixtureBudget;
            _ = try submit(&engine, .{ .storage_compact = {} });
        }
        try values(&engine);
        _ = try submit(&engine, .{ .checkpoint = {} });
        try journal.maintain(engine.head);
        try collection.start(&engine, try submit(&engine, .{ .storage_fence = {} }));
    } else if (std.mem.eql(u8, args[2], "mark")) {
        var steps: usize = 0;
        while ((try collection.current()).?.phase == .mark) : (steps += 1) {
            if (steps > 10000) return error.FixtureBudget;
            _ = try collection.step(&engine, .{ .unix_ms = clock.now });
        }
        try t.expectEqual(.wait, (try collection.current()).?.phase);
        var queue = try pages.allocations();
        const before = try queue.current();
        try t.expect(!try collection.step(&engine, .{ .unix_ms = clock.now }));
        try t.expectEqualDeep(before, try queue.current());
        try values(&engine);
    } else if (std.mem.eql(u8, args[2], "intent") or std.mem.eql(u8, args[2], "sweep")) {
        clock.now = @max(engine.head.time_floor_ms, (try collection.current()).?.grace_until_ms + 1);
        if (engine.head.time_floor_ms < clock.now) {
            try t.expectError(error.CollectionTimeFenceRequired, collection.step(&engine, .{ .unix_ms = clock.now }));
            _ = try submit(&engine, .{ .storage_fence = {} });
        }
        var steps: usize = 0;
        while (true) : (steps += 1) {
            if (steps > 10000) return error.FixtureBudget;
            const state = (try collection.current()).?;
            if (state.phase == .complete or (std.mem.eql(u8, args[2], "intent") and state.phase == .deleting)) break;
            _ = try collection.step(&engine, .{ .unix_ms = clock.now });
        }
        try values(&engine);
        if (std.mem.eql(u8, args[2], "sweep")) {
            const state = (try collection.current()).?;
            try t.expect(state.reclaimed_segments > 0 and state.reclaimed_bytes > 0);
            var queue = try pages.allocations();
            const current = try queue.current();
            try t.expect(current.reclaimed_bytes >= state.reclaimed_bytes);
            const before = current;
            try t.expect(!try collection.step(&engine, .{ .unix_ms = clock.now }));
            try t.expectEqualDeep(before, try queue.current());
        }
    } else if (std.mem.eql(u8, args[2], "verify")) {
        try values(&engine);
        for ([_]u8{ 61, 62 }) |nonce| {
            const identity: backend.Segment.Identity = .{ .epoch = 1, .nonce = @splat(nonce) };
            const name = try identity.name(journal.journal.stream.bucket, journal.journal.stream.name);
            const stream: backend.ursula.Stream = .{ .bucket = journal.journal.stream.bucket, .name = &name };
            var late = try client.send(.{ .create_stream = .{ .stream = stream, .options = .{ .content_type = "application/json", .body = "\"YQ==\"" } } });
            defer late.deinit();
            try t.expectEqual(.conflict, late.head.status);
            var head = try client.send(.{ .head = .{ .stream = stream } });
            defer head.deinit();
            const metadata = try head.head.metadata();
            try t.expectEqual(true, metadata.closed.?);
            try t.expectEqual(metadata.record_first, metadata.record_next);
        }
    } else return error.UnknownPhase;
    var buffer: [8192]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var queue = try pages.allocations();
    const status = (try collection.current()).?;
    try std.json.Stringify.value(.{ .phase = args[2], .relocated_from = relocated_from, .collection = status.phase, .verified_pages = status.verified_pages, .verified_blocks = status.verified_blocks, .retained_segments = status.retained_segments, .reclaimed_segments = status.reclaimed_segments, .reclaimed_bytes = status.reclaimed_bytes, .reclaimable_bytes = status.reclaimable_bytes, .protected_bytes = status.protected_bytes, .uncertain_segments = status.uncertain_segments, .accounting = try queue.current(), .resident_bytes = pages.residentBytes() }, .{}, &out.interface);
    try out.interface.writeByte('\n');
    try out.interface.flush();
}
