//! Real v1 journal/page persistence. No service or Station capability claim.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_local");
const g = core.protocol.Growth;
const t = std.testing;
const Journal = struct {
    store: adapter.Store,
    fault: enum { none, before, after } = .none,
    pub fn tail(self: *@This()) !u64 {
        return self.store.tail();
    }
    pub fn read(self: *@This(), at: u64) !?core.growing.Entry {
        return self.store.read(at);
    }
    pub fn appendControlled(self: *@This(), at: u64, entry: core.growing.Entry, control: bool) !bool {
        if (self.fault == .before) return error.InjectedStorageFailure;
        const accepted = try self.store.appendControlled(at, entry, control);
        if (accepted and self.fault == .after) return error.InjectedLostAcknowledgement;
        return accepted;
    }
};
const Engine = core.growing.Engine(Journal, adapter.PageStore);
const Expected = struct {
    pid: u64,
    reader: u64,
    retired: u64,
    resource: u64,
    view: u64 = 0,
    revision: u64 = 0,
    rows: u64,
    last: g.SignedRequest = undefined,
    receipt: u64 = 0,
    views: [16]?u64 = @splat(null),
};
const Measurements = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    operations: std.ArrayList(u64) = .empty,
    turns: std.ArrayList(u64) = .empty,
    orphan_page_bytes: u64 = 0,
    fn now(self: *@This()) std.Io.Timestamp {
        return std.Io.Clock.awake.now(self.io);
    }
    fn elapsed(self: *@This(), start: std.Io.Timestamp) u64 {
        return @intCast(start.durationTo(self.now()).toNanoseconds());
    }
};
const Clock = struct {
    fn read(_: *anyopaque) anyerror!core.Time.Sample {
        return .{ .unix_ms = 100, .error_ms = 1 };
    }
};
const Caller = struct {
    engine: *Engine,
    key: core.Ed25519.KeyPair,
    measurements: *Measurements,
    fn signed(self: @This(), command: g.Command) !g.SignedRequest {
        return g.sign(.{ .realm = 42, .principal = 0, .sequence = (try self.engine.principal(0)).sequence + 1, .command = command }, self.key);
    }
    fn submit(self: @This(), command: g.Command) !u64 {
        const start = self.measurements.now();
        const result = try self.engine.submit(try self.signed(command));
        try self.measurements.operations.append(self.measurements.allocator, self.measurements.elapsed(start));
        return result;
    }
    fn query(self: @This(), kind: @FieldType(g.Query, "kind")) !g.Response {
        return self.engine.query(try g.signQuery(.{ .realm = 42, .principal = 0, .kind = kind }, self.key));
    }
};
fn key(index: usize) core.Value {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, index, .big);
    return core.Value.init(&bytes) catch unreachable;
}
fn value(index: usize) core.Value {
    var bytes: [256]u8 = @splat(42);
    std.mem.writeInt(u64, bytes[0..8], index, .big);
    return core.Value.init(&bytes) catch unreachable;
}
fn incompatibleHistory(journal: *Journal, page_store: *adapter.PageStore, genesis: core.growing.Genesis, writing: bool) !void {
    const owner = journal.store.backend;
    const allocator = owner.allocator;
    const position = try journal.tail();
    const writes = page_store.created;
    const requests = page_store.misses;
    for ([_][]const u8{ "foreign-definition", "missing-definition" }, 0..) |name, index| {
        var invalid_owner = try adapter.Backend.open(allocator, owner.io, owner.directory, name, .{});
        defer invalid_owner.deinit();
        var incompatible: Journal = .{ .store = .{ .backend = &invalid_owner } };
        if (writing) {
            const encoded = try std.json.Stringify.valueAlloc(allocator, (try journal.store.read(0)).?, .{});
            defer allocator.free(encoded);
            var parsed = try std.json.parseFromSlice(std.json.Value, allocator, encoded, .{});
            defer parsed.deinit();
            const head = parsed.value.object.getPtr("genesis").?.object.getPtr("head").?;
            if (index == 0) head.object.getPtr("definition").?.* = .{ .string = "0000000000000000000000000000000000000000000000000000000000000000" } else try t.expect(head.object.swapRemove("definition"));
            const bytes = try std.json.Stringify.valueAlloc(allocator, parsed.value, .{});
            defer allocator.free(bytes);
            _ = try invalid_owner.wal.log().append(0, 0, 1, 1, .genesis, bytes);
        }
        var before = try invalid_owner.wal.log().read(allocator, 0, 0, 1);
        defer before.deinit();
        const expected_error = if (index == 0) error.InvalidEnumTag else error.MissingField;
        try t.expectError(expected_error, incompatible.store.read(0));
        try t.expectError(expected_error, Engine.open(&incompatible, page_store, genesis));
        try t.expectEqual(@as(u64, 1), try incompatible.tail());
        var after = try invalid_owner.wal.log().read(allocator, 0, 0, 1);
        defer after.deinit();
        try t.expectEqualStrings(before.frames[0].payload, after.frames[0].payload);
    }
    try t.expectEqual(position, try journal.tail());
    try t.expectEqual(writes, page_store.created);
    try t.expectEqual(requests, page_store.misses);
}
fn verifyRows(caller: Caller, expected: Expected, mode: enum { current, view, retained }) !void {
    var after: ?core.Value = null;
    var count: usize = 0;
    while (true) {
        const response = try caller.query(if (mode == .retained) .{ .version_entries = .{
            .id = .{ .pid = expected.pid, .input = expected.last.request.command.turn_with_versions.turn.input, .index = 0 },
            .generation = 2,
            .after = after,
        } } else .{ .entries = .{
            .view = if (mode == .view) expected.view else null,
            .resource = if (mode == .view) null else expected.resource,
            .revision = if (mode == .view) null else expected.revision,
            .after = after,
        } });
        const page = if (mode == .retained) response.body.version_entries.page else response.body.entries.page;
        for (page.entries) |slot| if (slot) |entry| {
            try t.expect(entry.key.eql(key(count)));
            try t.expect(entry.value.eql(value(count)));
            count += 1;
        };
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(switch (mode) {
        .current => expected.rows,
        .view => expected.rows / 2,
        .retained => expected.rows - 4,
    }, count);
}
fn verify(caller: Caller, expected: Expected) !void {
    const engine = caller.engine;
    const before = try engine.journal.tail();
    const writes = engine.page_store.created;
    try verifyRows(caller, expected, .current);
    try verifyRows(caller, expected, .view);
    try verifyRows(caller, expected, .retained);
    for (expected.views) |slot| if (slot) |view| {
        const page = (try caller.query(.{ .entries = .{ .view = view, .key = key(0) } })).body.entries.page;
        try t.expect(page.entries[0].?.value.eql(value(0)));
    };
    try t.expectEqual(expected.receipt, try engine.submit(expected.last));
    try t.expectEqual(before, try engine.journal.tail());
    try t.expectEqual(writes, engine.page_store.created);
    const process = (try caller.query(.{ .process = expected.pid })).body.process;
    try t.expectEqual(expected.rows / 4, process.process.consumed);
    try t.expectEqual(expected.rows / 4, process.process.admitted);
    try t.expect(process.input == null);
    const reader = (try caller.query(.{ .process = expected.reader })).body.process;
    try t.expectEqual(@as(u64, 1), reader.process.admitted);
    try t.expectEqualStrings("capture", reader.input.?.value.slice());
    try t.expectEqual(.terminated, (try engine.process(expected.retired)).lifecycle);
    try t.expectError(error.RetiredProcess, caller.submit(.{ .own = .{ .pid = expected.retired, .expected_generation = 0, .worker = 0 } }));
    var after: ?u64 = null;
    var count: usize = 0;
    while (true) {
        const page = (try caller.query(.{ .processes = .{ .after = after, .position = before } })).body.processes;
        for (page.entries) |slot| if (slot) |process_row| {
            if (process_row.pid != expected.retired) {
                const name = if (process_row.pid == expected.pid or process_row.pid == expected.reader) "state" else "shared";
                const association = (try caller.query(.{ .association = .{ .pid = process_row.pid, .name = try core.Value.init(name) } })).body.association;
                try t.expectEqual(expected.resource, association.?.resource);
            }
            count += 1;
        };
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(@as(usize, 70), count);
    after = null;
    count = 0;
    while (true) {
        const page = (try caller.query(.{ .outputs = .{ .after = after, .position = before } })).body.outputs;
        for (page.entries) |slot| if (slot) |output| {
            try t.expectEqual(expected.reader, output.destination);
            try t.expectEqual(.pending, output.phase);
            count += 1;
        };
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(expected.rows / 4, count);
    // The earlier prepared send was fenced by revocation. It cannot enter the
    // recovered mailbox even though the immutable candidate pages still exist.
    const denied = try g.sign(.{ .realm = 42, .principal = 65536, .sequence = 1, .command = .{ .send = .{ .pid = expected.reader, .value = .{} } } }, caller.key);
    try t.expectError(error.Forbidden, engine.submit(denied));
}
fn write(caller: Caller, rows: usize, views: usize) !Expected {
    const engine = caller.engine;
    for (0..20) |i| _ = try caller.submit(.{ .grant = .{ .subject = 65536 + i, .public_key = caller.key.public_key.toBytes(), .permissions = core.all_permissions } });
    const pid = try caller.submit(.{ .spawn = .{} });
    const reader = try caller.submit(.{ .spawn = .{} });
    const retired = try caller.submit(.{ .spawn = .{} });
    var other_pids: [67]u64 = undefined;
    for (&other_pids) |*id| id.* = try caller.submit(.{ .spawn = .{} });
    _ = try caller.submit(.{ .terminate = retired });
    const resource = try caller.submit(.{ .create_resource = .{ .writer = pid } });
    for (0..5) |_| _ = try caller.submit(.{ .create_resource = .{ .writer = pid } });
    _ = try caller.submit(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    for ([_]u64{ pid, reader }) |id| {
        _ = try caller.submit(.{ .associate = .{ .pid = id, .name = try core.Value.init("state"), .resource = resource } });
        _ = try caller.submit(.{ .own = .{ .pid = id, .expected_generation = 1, .worker = 0 } });
    }
    // Optional associations exceed the legacy 64-slot catalog without adding
    // lifetime graph edges or changing its explicit per-operation budget.
    for (other_pids) |id| _ = try caller.submit(.{ .associate = .{ .pid = id, .name = try core.Value.init("shared"), .resource = resource } });
    const input = try caller.submit(.{ .send = .{ .pid = reader, .value = try core.Value.init("capture") } });
    const before_stale = engine.page_store.create_payload_bytes_attempted;
    const stale = try engine.prepare(try g.sign(.{ .realm = 42, .principal = 65536, .sequence = 1, .command = .{ .send = .{ .pid = reader, .value = .{} } } }, caller.key));
    caller.measurements.orphan_page_bytes = engine.page_store.create_payload_bytes_attempted - before_stale;
    _ = try caller.submit(.{ .revoke = 65536 });
    try t.expectError(error.Conflict, engine.commit(stale));
    var expected: Expected = .{ .pid = pid, .reader = reader, .retired = retired, .resource = resource, .revision = resource, .rows = rows };
    for (0..rows / 4) |turn| {
        const start = caller.measurements.now();
        const head = try caller.submit(.{ .send = .{ .pid = pid, .value = .{} } });
        const revision = if (turn == 0) 0 else expected.revision;
        const view = try caller.submit(.{ .open_view = .{ .pid = pid, .generation = 2, .input = head, .expected_revision = revision, .resource = resource, .revision = expected.revision, .deadline_ms = 1000 } });
        var mutations: [g.turn_mutations]?g.Mutation = @splat(null);
        for (&mutations, 0..) |*slot, index| slot.* = .{ .key = key(turn * 4 + index), .value = value(turn * 4 + index) };
        const proposal: g.Turn = .{ .pid = pid, .generation = 2, .input = head, .expected_revision = revision, .views = .{ view, null, null, null }, .write_view = view, .mutations = mutations, .outputs = .{ .{ .pid = reader, .value = key(turn) }, null, null, null } };
        const command: g.Command = if (turn + 1 == rows / 4) .{ .turn_with_versions = .{ .turn = proposal, .retain = .{ view, null, null, null } } } else .{ .turn = proposal };
        const request = try caller.signed(command);
        const candidate = try engine.prepare(request);
        try t.expectEqual(@as(u64, turn), (try engine.process(pid)).consumed);
        const data = (try caller.query(.{ .resource = resource })).body.resource;
        try t.expectEqual(@as(u64, turn * 4), data.entries);
        if (turn == 0) {
            engine.journal.fault = .before;
            try t.expectError(error.InjectedStorageFailure, engine.commit(candidate));
            engine.journal.fault = .none;
            try t.expectEqual(data.entries, (try caller.query(.{ .resource = resource })).body.resource.entries);
        }
        if (turn + 1 == rows / 4) {
            engine.journal.fault = .after;
            try t.expectError(error.InjectedLostAcknowledgement, engine.commit(candidate));
            engine.journal.fault = .none;
            // Recovery, not a second append, reconciles an accepted proposal.
            expected.last = request;
            expected.receipt = candidate.record.position;
            try engine.refresh();
            expected.revision = expected.receipt;
        } else expected.revision = try engine.commit(candidate);
        try caller.measurements.turns.append(caller.measurements.allocator, caller.measurements.elapsed(start));
        if (turn + 1 == rows / 8) {
            for (0..views) |index| expected.views[index] = try caller.submit(.{ .open_view = .{ .pid = reader, .generation = 2, .input = input, .expected_revision = 0, .resource = resource, .revision = expected.revision, .deadline_ms = 1000 } });
            expected.view = expected.views[0].?;
        }
    }
    return expected;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 4 or args.len > 6) return error.ExpectedUrlPhaseRowsCacheViews;
    const rows = try std.fmt.parseInt(usize, args[3], 10);
    if (rows < 64 or rows > 4096 or rows % 8 != 0) return error.InvalidDataset;
    const Config = struct { directory: []const u8, object_storage: ?adapter.Backend.ObjectStorage = null };
    const raw = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(16384));
    defer init.gpa.free(raw);
    const configured = try std.json.parseFromSlice(Config, init.gpa, raw, .{});
    defer configured.deinit();
    var owner = try adapter.Backend.openWithObjectStorage(init.gpa, init.io, std.Io.Dir.cwd(), configured.value.directory, .{}, configured.value.object_storage);
    defer owner.deinit();
    var journal: Journal = .{ .store = .{ .backend = &owner } };
    const cache = if (args.len >= 5) try std.fmt.parseInt(usize, args[4], 10) else 1;
    const views = if (args.len == 6) try std.fmt.parseInt(usize, args[5], 10) else 1;
    if (views == 0 or views > 16) return error.InvalidViewDataset;
    var page_store = try adapter.PageStore.init(&owner, cache);
    defer page_store.deinit();
    const root_key = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const genesis: core.growing.Genesis = .{ .realm = 42, .root_key = root_key.public_key.toBytes(), .max_clock_error_ms = 5, .allow_history_trim = true };
    const writing = std.mem.eql(u8, args[2], "write");
    const checkpoint = std.mem.eql(u8, args[2], "checkpoint");
    const trimmed = std.mem.eql(u8, args[2], "trim_recover");
    if (!writing and !checkpoint and !trimmed and !std.mem.eql(u8, args[2], "recover")) return error.UnknownPhase;
    var measurements: Measurements = .{ .io = init.io, .allocator = init.gpa };
    defer measurements.operations.deinit(init.gpa);
    defer measurements.turns.deinit(init.gpa);
    const open_start = measurements.now();
    var engine = if (writing) try Engine.bootstrap(&journal, &page_store, genesis) else try Engine.open(&journal, &page_store, genesis);
    const open_ns = measurements.elapsed(open_start);
    var clock: u8 = 0;
    engine.clock = .{ .context = &clock, .read = Clock.read };
    const caller: Caller = .{ .engine = &engine, .key = root_key, .measurements = &measurements };
    const expected = if (writing) blk: {
        const result = try write(caller, rows, views);
        // Separate test oracle: production recovery never consults this file.
        const bytes = try std.json.Stringify.valueAlloc(init.gpa, result, .{});
        defer init.gpa.free(bytes);
        const file = try owner.directory.createFile(init.io, ".proof-expectations", .{ .permissions = .fromMode(0o600) });
        defer file.close(init.io);
        try file.writeStreamingAll(init.io, bytes);
        try file.sync(init.io);
        const dir: std.Io.File = .{ .handle = owner.directory.handle, .flags = .{ .nonblocking = false } };
        try dir.sync(init.io);
        break :blk result;
    } else blk: {
        const bytes = try owner.directory.readFileAlloc(init.io, ".proof-expectations", init.gpa, .limited(65536));
        defer init.gpa.free(bytes);
        const parsed = try std.json.parseFromSlice(Expected, init.gpa, bytes, .{});
        defer parsed.deinit();
        try t.expectEqual(rows, parsed.value.rows);
        break :blk parsed.value;
    };
    page_store.clearCache();
    try verify(caller, expected);
    var checkpoint_ns: ?u64 = null;
    if (checkpoint) {
        const start = measurements.now();
        try t.expectError(error.NoCheckpointIntent, journal.store.maintain(engine.head));
        const candidate = try engine.prepare(try caller.signed(.{ .checkpoint = {} }));
        try t.expectError(error.NoCheckpointIntent, journal.store.maintain(candidate.record.next));
        _ = try engine.commit(candidate);
        try journal.store.maintain(engine.head);
        checkpoint_ns = measurements.elapsed(start);
        const saved = (try journal.store.read(engine.head.position - 1)).?;
        try t.expect(std.meta.eql(engine.head, saved.operation.next));
        // Idempotent maintenance cannot advance authority or staged page state.
        const position = try journal.tail();
        const writes = page_store.created;
        try journal.store.maintain(engine.head);
        try t.expectEqual(position, try journal.tail());
        try t.expectEqual(writes, page_store.created);
        try verify(caller, expected);
    }
    if (trimmed) {
        try t.expectError(error.HistoryReclaimed, journal.store.read(0));
        try t.expect(engine.head.history_floor > 0);
        try t.expect(std.meta.eql(engine.head, (try journal.store.read(engine.head.position - 1)).?.operation.next));
    }
    var wrong = genesis;
    wrong.realm += 1;
    try t.expectError(error.WrongProtocolRealm, Engine.open(&journal, &page_store, wrong));
    if (!checkpoint and !trimmed) {
        var reopened: adapter.Store = .{ .backend = &owner };
        try t.expect(std.meta.eql((try reopened.read(0)).?, (try journal.store.read(0)).?));
    }
    try incompatibleHistory(&journal, &page_store, genesis, writing);
    // Drain exact recorded uploads before process death; retained references on
    // the next open must fetch original objects with a fresh memory/disk cache.
    if (owner.objects.tier) |tier| while ((try tier.queue.current()).pending_objects != 0) try owner.tierStep();
    // Remove only the current descriptor in this disposable fault fixture.
    // Missing trusted identity must not become an empty state or remote adoption.
    if (trimmed) {
        var name: [96]u8 = undefined;
        const object_key = try std.fmt.bufPrint(&name, "native/p/{x}", .{&engine.head.catalog.root.?.location});
        try owner.objects.local.deleteObject(object_key);
        try t.expectEqual(null, try owner.objects.local.headObject(object_key));
        const position = try journal.tail();
        const writes = page_store.created;
        page_store.clearCache();
        try t.expectError(error.MissingStorageObject, Engine.open(&journal, &page_store, genesis));
        try t.expectEqual(position, try journal.tail());
        try t.expectEqual(writes, page_store.created);
    }
    var bytes: [2048]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &bytes);
    try std.json.Stringify.value(.{ .phase = args[2], .rows = rows, .retained_value_bytes = rows * 256, .position = engine.head.position, .catalog_records = engine.head.catalog.records, .cache_bytes = page_store.residentBytes(), .created_pages = page_store.created, .page_reads = page_store.misses, .page_payload_bytes = page_store.create_payload_bytes_attempted, .cache_hits = page_store.hits, .cache_misses = page_store.misses, .open_ns = open_ns, .checkpoint_ns = checkpoint_ns, .orphan_page_bytes = measurements.orphan_page_bytes, .operation_ns = measurements.operations.items, .turn_ns = measurements.turns.items }, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
    try init.io.sleep(.fromSeconds(30), .awake);
    return error.ExpectedProcessDeath;
}
