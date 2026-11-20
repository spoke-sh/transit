//! Installed private behavior proof: signed callers, ordinary data owners and
//! native PID authority. No backend or node imports are available to this host.
const std = @import("std");
const s = @import("station_transaction_internal");
const c = s.catalog;
const p = c.protocol;
const d = p.DataLifecycle;
const t = std.testing;
const KV = c.DirectKVClient;
const Queue = c.DirectQueueClient;
const Stream = c.DirectStreamClient;
const Actor = s.Actor;
const Runner = s.Runner;
pub const Case = enum { small, large, head, begin, claim, input, acquire, dispatch, draft, staged, executed, decision, cleared, poison, exception, capacity, stop, stale, measured };
const Saved = struct { definition: p.Growth.Definition, actor: Actor.Declaration, activation: p.Transaction.Execution, case: Case, enqueue: p.StreamQueue.Append };
fn replacement(case: Case) u64 {
    return 1000 + @as(u64, @backingInt(case));
}
fn replacementKey(case: Case) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(@as(u8, 80) + @backingInt(case)));
}
fn op(client: c.DirectTableClient, id: u64) d.Operation {
    return .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = id };
}
fn value(large: bool) []const u8 {
    return if (large) &large_value else &small_value;
}
fn sequenceValue(index: usize) [128]u8 {
    var result: [128]u8 = undefined;
    for (&result, 0..) |*byte, i| byte.* = @intCast((index * 17 + i * 31 + 7) % 256);
    return result;
}
const small_value = sequenceValue(0);
const large_value: [1024]u8 = @splat(0xff);
fn createKV(init: std.process.Init, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, role: u64, object: u64, name: []const u8) !d.Definition {
    const declaration = try KV.prepareDeclaration(init.gpa, .{ .binding = .{ .definition = p.Growth.current_definition, .identity = op(client, object + 100), .target = .{ .scope = client.connection.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = undefined }, .namespace = 1, .name = try .init(name), .action = .{ .create = .{ .owner = role, .spec = Actor.spec } } });
    _ = try KV.apply(output, client, .{ .declaration = .{ .declaration = declaration, .command = .admit, .steps = 1 } });
    try t.expect((try KV.apply(output, client, .{ .declaration = .{ .declaration = declaration, .command = .execute, .steps = 64 } })).declaration.operation == .committed);
    return (try KV.apply(output, client, .{ .observe = declaration.binding.target })).definition.interpretation.interpretation;
}
fn createLog(init: std.process.Init, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, role: u64, object: u64, name: []const u8, kind: c.DirectLog.Kind) !p.StreamQueue.Partition {
    const intent: c.DirectLog.Intent = .{ .kind = kind, .namespace = 1, .name = try .init(name), .action = .{ .create = .{
        .owner = role,
        .schema = Runner.logSchema(object),
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = if (kind == .stream) .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } else .{ .queue = .{ .ordering = .key_fifo, .key_column = 1, .lease_ms = 300000, .maximum_lease_ms = 300000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = op(client, object + 100), .target = .{ .scope = client.connection.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(init.gpa) } };
    _ = try c.DirectLogClient.apply(output, client, .{ .admit = request });
    const completed = (try c.DirectLogClient.apply(output, client, .{ .operation = .{ .binding = request.binding, .command = .execute, .steps = 16 } })).operation.operation;
    try t.expectEqual(.complete, completed.phase);
    return .{ .definition = p.Growth.current_definition, .interpretation = completed.resulting.?.stored.declaration.interpretation, .partition = 0 };
}
fn save(init: std.process.Init, path: []const u8, data: anytype) !void {
    const bytes = try p.Json.valueAlloc(init.gpa, data);
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
}
fn setup(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, path: []const u8, case: Case) !void {
    (try client.call(.initialize)).deinit();
    const base: u64 = 700000 + @as(u64, @backingInt(case)) * 1000;
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const allocator = output.allocator();
    const pid = try admin.submit(.{ .spawn = .{} });
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = pid }, .grantee = role, .privileges = p.permission(.execute) | p.permission(.inspect) } });
    _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 101 } });
    const activation: p.Transaction.Execution = .{ .realm = client.connection.scope.realm, .pid = pid, .principal = 101, .generation = 1, .code = 1, .workload = null, .input = null };
    const table_name = try std.fmt.allocPrint(allocator, "actor_rows_{s}", .{@tagName(case)});
    const sql = try std.fmt.allocPrint(allocator, "CREATE TABLE {s} (id BIGINT PRIMARY KEY)", .{table_name});
    var ddl = try c.DirectTablePreparedDdl.prepare(init.gpa, client, 1, sql, .transit, null);
    defer ddl.deinit();
    var table = try ddl.bind(init.gpa, client, base + 100, base);
    defer table.deinit();
    (try table.table.admit(client)).deinit();
    const created = try table.table.operation(client, .execute, 64);
    defer created.deinit();
    try t.expect(created.value.result.ddl == .committed);
    const control = try createKV(init, client, &output, role, base + 1, try std.fmt.allocPrint(allocator, "actor_control_{s}", .{@tagName(case)}));
    const state = try createKV(init, client, &output, role, base + 2, try std.fmt.allocPrint(allocator, "actor_state_{s}", .{@tagName(case)}));
    const inbox = try createLog(init, client, &output, role, base + 3, try std.fmt.allocPrint(allocator, "actor_inbox_{s}", .{@tagName(case)}), .queue);
    const journal = try createLog(init, client, &output, role, base + 4, try std.fmt.allocPrint(allocator, "actor_journal_{s}", .{@tagName(case)}), .stream);
    const outbox = try createLog(init, client, &output, role, base + 5, try std.fmt.allocPrint(allocator, "actor_outbox_{s}", .{@tagName(case)}), .queue);
    const fields = [_]c.fuze.WorkloadProjection.Field{ .{ .column = 1 }, .{ .column = 2 } };
    const layout = try c.fuze.WorkloadProjection.schemaLayout(Runner.logSchema(inbox.interpretation.object.object), &fields, .claim);
    const predicate = try c.fuze.QueuePredicate.encode(allocator, inbox, Runner.logSchema(inbox.interpretation.object.object), &fields, .{ .schema = layout.typeOf(), .source_basis = @splat(0), .collations = layout.collations, .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = @intCast(pid) } } } });
    const actor: Actor.Declaration = .{ .definition = p.Growth.current_definition, .connection = client.connection, .namespace = 1, .pid = pid, .code = 1, .workload = null, .behavior = @splat(61), .control = control, .state = state, .table = created.value.result.ddl.committed.resulting.interpretation, .table_name = try .init(table_name), .inbox = inbox, .journal = journal, .outbox = outbox, .predicate = predicate, .lease_ms = 300000, .limits = .{}, .transaction = c.DirectTransaction.default_limits };
    var runner = try Runner.init(init.gpa, client, actor, activation);
    defer runner.deinit();
    try runner.bootstrap();
    const identity = op(client, base + 200);
    const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = @intCast(pid) } } }, .{ .value = .{ .atom = .{ .bytes = value(case == .large) } } } };
    var buffer: [8192]u8 = undefined;
    const payload = try c.storage.LogBatch.encode(Runner.logSchema(inbox.interpretation.object.object), identity, .queue, &.{.{ .cells = &cells }}, &buffer);
    const enqueue: p.StreamQueue.Append = .{ .target = inbox, .operation = identity, .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) };
    _ = try Queue.apply(&output, client, .{ .mutate = .{ .work = .{ .enqueue = enqueue }, .payload = payload } });
    try save(init, path, Saved{ .definition = p.Growth.current_definition, .actor = actor, .activation = activation, .case = case, .enqueue = enqueue });
}
const Body = struct {
    case: Case,
    table: []const u8,
    calls: usize = 0,
    index: usize = 0,
    fn run(raw: *anyopaque, turn: *s.Turn) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.calls += 1;
        const current = sequenceValue(self.index);
        const expected: []const u8 = if (self.case == .large) &large_value else &current;
        try t.expectEqualSlices(u8, expected, turn.input);
        const previous = try turn.get("value");
        if (self.index == 0) try t.expect(previous == null) else try t.expectEqualSlices(u8, &sequenceValue(self.index - 1), previous.?);
        try turn.put("value", expected);
        if (self.case == .large) for ([_][]const u8{ "two", "three", "four", "five", "six" }) |name| try turn.put(name, expected);
        const sql = try std.fmt.allocPrint(turn.allocator, "INSERT INTO {s} (id) VALUES ($1)", .{self.table});
        try t.expect(try turn.readTable(&.{.{ .value = .{ .atom = .{ .signed = @intCast(42 + self.index) } } }}) == null);
        try turn.table(sql, &.{.{ .signed = @intCast(42 + self.index) }});
        const row = (try turn.readTable(&.{.{ .value = .{ .atom = .{ .signed = @intCast(42 + self.index) } } }})).?;
        try t.expectEqual(@as(i128, @intCast(42 + self.index)), row[0].value.atom.signed);
        try turn.journal("handled");
        try turn.emit(expected);
        if (self.case == .exception or self.case == .stop) return error.DeliberateHandlerFailure;
        if (self.case == .capacity) {
            var huge: [65537]u8 = @splat(1);
            _ = turn.put("huge", &huge) catch {};
        }
        if (self.case == .poison) {
            const bad: [c.storage.KVPartition.max_key_bytes + 1]u8 = @splat(1);
            _ = turn.get(&bad) catch null;
        }
    }
};
const Interrupt = struct {
    init: std.process.Init,
    path: []const u8,
    at: Runner.Point,
    fn hit(raw: *anyopaque, point: Runner.Point) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (point != self.at) return;
        try save(self.init, self.path, .{ .point = point });
        while (true) try self.init.io.sleep(.fromSeconds(1), .awake);
    }
};
fn load(init: std.process.Init, path: []const u8) !Saved {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(1024 * 1024));
    const saved = (try p.Json.parseFromSlice(Saved, init.arena.allocator(), bytes)).value;
    if (saved.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try saved.actor.validate();
    return saved;
}
fn committed(case: Case) bool {
    return case == .measured or case == .small or case == .large or case == .decision or case == .cleared;
}
fn verify(init: std.process.Init, client: c.DirectTableClient, saved: Saved, index: usize) !void {
    const count: usize = if (saved.case == .measured) 23 else 1;
    const turn = index + 1;
    var enqueue = saved.enqueue.operation;
    enqueue.operation += index;
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const expected = committed(saved.case);
    const keys = [_][]const u8{ "value", "two", "three", "four", "five", "six" };
    for (keys[0..@as(usize, if (saved.case == .large) 6 else 1)]) |key| {
        const read = (try KV.apply(&output, client, .{ .get = .{ .object = saved.actor.state.object, .key = key } })).value;
        try t.expectEqual(expected, read.value != null);
        try t.expect(read.workspace == null);
        if (read.value) |cell| try t.expectEqualSlices(u8, if (saved.case == .large) &large_value else &sequenceValue(count - 1), cell.value.atom.bytes);
    }
    const table = try client.call(.{ .lookup = .{ .namespace = 1, .name = saved.actor.table_name.slice() } });
    defer table.deinit();
    try t.expectEqual(@as(u64, if (expected) count else 0), table.value.result.lookup.?.row_count);
    const digest = try saved.actor.digest(init.gpa);
    const metadata = table.value.result.lookup.?;
    const pinned = try client.call(.{ .pin = .{ .object = saved.actor.table.object, .owner = Actor.operation(client.connection, digest, metadata.position.next_lsn, "oracle", 0), .expected = metadata.position, .interpretation = saved.actor.table } });
    defer pinned.deinit();
    var rows = try c.DirectTableReader.open(init.gpa, client, .{ .object = saved.actor.table.object, .handle = pinned.value.result.pin });
    defer rows.deinit();
    var seen: usize = 0;
    // A physical Table scan does not promise primary-key order. Check the
    // complete independent value set, including duplicates and foreign rows.
    var values: [23]bool = @splat(false);
    while (try rows.next(client, .{})) |page| {
        var batch = page;
        defer batch.deinit();
        for (batch.rows[0..batch.count]) |row| {
            const id = row.?.row().cells[0].value.atom.signed;
            try t.expect(id >= 42 and id < 42 + @as(i128, @intCast(count)));
            const ordinal: usize = @intCast(id - 42);
            try t.expect(!values[ordinal]);
            values[ordinal] = true;
            seen += 1;
        }
    }
    try t.expectEqual(@as(usize, if (expected) count else 0), seen);
    try rows.release(client);
    const read: p.StreamRead.Request = .{ .target = saved.actor.journal, .operation = Actor.operation(client.connection, digest, turn, "journal-oracle", 0), .group = null, .from = index, .until = if (expected) turn else 0, .timestamp = null };
    const journal = (try Stream.apply(&output, client, .{ .mutate = .{ .work = .{ .consume = read } } })).operation.?.consume;
    const cursor = (try Stream.apply(&output, client, .{ .cursor = .{ .target = saved.actor.journal, .read = journal.handle() } })).cursor;
    const entries = (try Stream.apply(&output, client, .{ .page = .{ .cursor = cursor, .limits = .{ .rows = 8, .encoded_bytes = 8192 } } })).page;
    try t.expect(entries.cursor.coverage.complete);
    try t.expectEqual(@as(usize, @intFromBool(expected)), entries.rows.len);
    if (expected) {
        const Journal = struct { definition: [32]u8, transaction: d.Operation, input: p.StreamQueue.RecordIdentity, body: c.DirectTableProtocol.Binary };
        const recorded = (try p.Json.parseFromSlice(Journal, output.allocator(), entries.rows[0].value.cells[1].value.atom.bytes)).value;
        try t.expectEqual(digest, recorded.definition);
        try t.expectEqualDeep(Actor.operation(saved.actor.connection, digest, turn, "begin", 0), recorded.transaction);
        try t.expectEqualDeep(enqueue, recorded.input.operation);
        try t.expectEqualDeep(saved.actor.inbox, recorded.input.target);
        try t.expectEqual(@as(u32, 0), recorded.input.ordinal);
        try t.expectEqualSlices(u8, "handled", try recorded.body.decode(output.allocator(), 8192));
        try t.expectEqualDeep(Actor.operation(saved.actor.connection, digest, turn, "statement", if (saved.case == .large) 7 else 2), entries.rows[0].operation);
        const outbound: p.StreamQueue.Claim = .{ .target = saved.actor.outbox, .operation = Actor.operation(client.connection, digest, turn, "outbox-oracle", 0), .maximum = 1, .lease_ms = saved.actor.lease_ms, .predicate = null };
        const accepted = (try Queue.apply(&output, client, .{ .mutate = .{ .work = .{ .claim = outbound } } })).operation.?.claim;
        const output_rows = (try Queue.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = accepted, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
        try t.expect(output_rows.cursor.complete());
        try t.expectEqual(@as(usize, 1), output_rows.rows.len);
        try t.expectEqualSlices(u8, if (saved.case == .large) &large_value else &sequenceValue(index), output_rows.rows[0].value.cells[1].value.atom.bytes);
        try t.expectEqualDeep(Actor.operation(saved.actor.connection, digest, turn, "statement", if (saved.case == .large) 8 else 3), output_rows.rows[0].operation);
        _ = try Queue.apply(&output, client, .{ .mutate = .{ .work = .{ .settle = .{ .operation = Actor.operation(client.connection, digest, turn, "outbox-oracle-ack", 0), .lease = output_rows.rows[0].lease.original, .action = .ack } } } });
    }

    try t.expectEqual(@as(u64, if (expected) count else 0), (try Stream.apply(&output, client, .{ .observe = saved.actor.journal })).cut.next);
    try t.expectEqual(@as(u64, if (expected) count else 0), (try Queue.apply(&output, client, .{ .observe = saved.actor.outbox })).cut.next);
    const claim: p.StreamQueue.Claim = .{ .target = saved.actor.inbox, .operation = Actor.operation(saved.actor.connection, digest, turn, "claim", 0), .maximum = 1, .lease_ms = saved.actor.lease_ms, .predicate = saved.actor.predicate };
    var recovery_client = client;
    recovery_client.connection.principal = replacement(saved.case);
    recovery_client.key = try replacementKey(saved.case);
    var execution = saved.activation;
    execution.input = claim;
    const recovered = try (c.DirectTransactionClient{ .catalog = recovery_client }).recover(.{ .key = Actor.token(saved.actor.connection, digest, turn), .execution = execution, .work = .inspect, .close_input = false });
    if (recovered) |original| {
        try t.expect(original.status.cleanup_complete);
        try t.expectEqual(if (expected) @FieldType(p.Transaction.Decision, "outcome").committed else @FieldType(p.Transaction.Decision, "outcome").aborted, original.status.observation.decided.outcome);
        try t.expectEqualDeep(Actor.operation(saved.actor.connection, digest, turn, "commit", 0), original.status.attempt.?.operation);
        try t.expectEqualDeep(execution, original.status.begin.execution.?);
    } else try t.expect(caseMissingBegin(saved.case));
    const receipt = (try Queue.apply(&output, client, .{ .operation = .{ .claim = claim } })).operation;
    if (receipt) |found| if (found == .claim) {
        if (saved.case == .large) {
            const release: p.QueueRead.Release = .{ .operation = Actor.operation(saved.actor.connection, digest, turn, "claim-release", 0), .claim = found.claim };
            const released = (try Queue.apply(&output, client, .{ .operation = .{ .release = release } })).operation.?;
            try t.expect(released == .release);
            try released.release.requireRelease(release);
            try t.expectError(error.Conflict, Queue.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = found.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } }));
            try t.expectEqual(p.ErrorCode.QueryExpired, client.service.last_rejection.?);
        } else {
            const page = (try Queue.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = found.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
            try t.expectEqual(@as(usize, 1), page.rows.len);
            try t.expectEqualDeep(enqueue, page.rows[0].operation);
            try t.expectEqual(@as(p.QueueRead.State, if (expected) .acked else .acquired), page.rows[0].lease.state);
        }
    };
}
fn emit(init: std.process.Init, out: *std.Io.Writer, data: anytype) !void {
    const bytes = try p.Json.valueAlloc(init.gpa, data);
    defer init.gpa.free(bytes);
    try out.writeAll(bytes);
    try out.writeByte('\n');
    try out.flush();
}
fn measure(init: std.process.Init, client: c.DirectTableClient, saved: Saved) !void {
    if (saved.case != .measured) return error.InvalidMeasurement;
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const out = &stdout.interface;
    var probe: @import("transit_memory").AllocationProbe = .{ .parent = init.gpa };
    var wire = c.client.Client.init(probe.allocator(), init.io, client.service.url);
    defer wire.deinit();
    wire.timeout_ms = client.service.timeout_ms;
    var selected = client;
    selected.authority = &wire;
    selected.service = &wire;
    selected.allocator = probe.allocator();
    var runner = try Runner.init(probe.allocator(), selected, saved.actor, saved.activation);
    defer runner.deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    var body: Body = .{ .case = .measured, .table = saved.actor.table_name.slice() };
    const digest = try saved.actor.digest(init.gpa);
    for (0..23) |index| {
        _ = output.reset(.retain_capacity);
        var identity = saved.enqueue.operation;
        identity.operation += index;
        try emit(init, out, .{ .event = "input_attempt", .index = index, .operation = identity });
        if (index != 0) {
            const current = sequenceValue(index);
            const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = @intCast(saved.actor.pid) } } }, .{ .value = .{ .atom = .{ .bytes = &current } } } };
            var payload_buffer: [8192]u8 = undefined;
            const payload = try c.storage.LogBatch.encode(Runner.logSchema(saved.actor.inbox.interpretation.object.object), identity, .queue, &.{.{ .cells = &cells }}, &payload_buffer);
            var request = saved.enqueue;
            request.operation = identity;
            request.payload = c.storage.LogBatch.content(payload);
            _ = try Queue.apply(&output, client, .{ .mutate = .{ .work = .{ .enqueue = request }, .payload = payload } });
        }
        try emit(init, out, .{ .event = "attempt", .index = index, .operation = identity });
        body.index = index;
        probe.begin(false);
        const start = std.Io.Clock.awake.now(init.io);
        var result = runner.advance(.{ .context = &body, .run = Body.run, .failure = .stop }) catch |err| {
            try emit(init, out, .{ .event = "failure", .index = index, .cause = @errorName(err), .rejection = wire.last_rejection });
            return err;
        };
        for (0..16) |_| {
            if (result != .recovering) break;
            result = try runner.advance(.{ .context = &body, .run = Body.run, .failure = .stop });
        }
        const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        const allocations = probe.counts;
        const peak = probe.peak_bytes;
        try t.expectEqual(Runner.Result.committed, result);
        try t.expectEqual(index + 1, body.calls);
        try emit(init, out, .{ .event = "confirmed", .index = index, .operation = Actor.operation(saved.actor.connection, digest, index + 1, "commit", 0) });
        const state = (try KV.apply(&output, client, .{ .get = .{ .object = saved.actor.state.object, .key = "value" } })).value.value.?.value.atom.bytes;
        try t.expectEqualSlices(u8, &sequenceValue(index), state);
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(state, &hash, .{});
        const hex = std.fmt.bytesToHex(hash, .lower);
        try emit(init, out, .{ .event = "sample", .index = index, .stage = if (index < 3) "warmup" else "measured", .ns = elapsed, .backing = allocations, .client_peak_live_bytes = peak, .runner_peak_bytes = runner.memory.peak, .sha256 = hex[0..] });
    }
    try emit(init, out, .{ .event = "complete", .definition = p.Growth.current_definition, .turns = 23, .build_mode = @import("builtin").mode });
}
fn createActor(init: std.process.Init, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, admin: anytype, role: u64, worker_principal: u64, base: u64, label: []const u8, inbox: p.StreamQueue.Partition, mailboxes: []const p.StreamQueue.Partition) !struct { pid: u64, actor: Actor.Declaration, activation: p.Transaction.Execution } {
    const allocator = output.allocator();
    const pid = try admin.submit(.{ .spawn = .{} });
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = pid }, .grantee = role, .privileges = p.permission(.execute) | p.permission(.inspect) } });
    _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = worker_principal } });
    var actor_conn = client.connection;
    actor_conn.principal = worker_principal;
    const activation: p.Transaction.Execution = .{ .realm = client.connection.scope.realm, .pid = pid, .principal = worker_principal, .generation = 1, .code = 1, .workload = null, .input = null };
    const table_name = try std.fmt.allocPrint(allocator, "actor_rows_{s}", .{label});
    const sql = try std.fmt.allocPrint(allocator, "CREATE TABLE {s} (id BIGINT PRIMARY KEY)", .{table_name});
    var ddl = try c.DirectTablePreparedDdl.prepare(init.gpa, client, 1, sql, .transit, null);
    defer ddl.deinit();
    var table = try ddl.bind(init.gpa, client, base + 100, base);
    defer table.deinit();
    (try table.table.admit(client)).deinit();
    const created = try table.table.operation(client, .execute, 64);
    defer created.deinit();
    try t.expect(created.value.result.ddl == .committed);
    const control = try createKV(init, client, output, role, base + 1, try std.fmt.allocPrint(allocator, "actor_control_{s}", .{label}));
    const state = try createKV(init, client, output, role, base + 2, try std.fmt.allocPrint(allocator, "actor_state_{s}", .{label}));
    const journal = try createLog(init, client, output, role, base + 4, try std.fmt.allocPrint(allocator, "actor_journal_{s}", .{label}), .stream);
    const outbox = try createLog(init, client, output, role, base + 5, try std.fmt.allocPrint(allocator, "actor_outbox_{s}", .{label}), .queue);
    const fields = [_]c.fuze.WorkloadProjection.Field{ .{ .column = 1 }, .{ .column = 2 } };
    const layout = try c.fuze.WorkloadProjection.schemaLayout(Runner.logSchema(inbox.interpretation.object.object), &fields, .claim);
    const predicate = try c.fuze.QueuePredicate.encode(allocator, inbox, Runner.logSchema(inbox.interpretation.object.object), &fields, .{ .schema = layout.typeOf(), .source_basis = @splat(0), .collations = layout.collations, .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = @intCast(pid) } } } });
    const actor: Actor.Declaration = .{
        .definition = p.Growth.current_definition,
        .connection = actor_conn,
        .namespace = 1,
        .pid = pid,
        .code = 1,
        .workload = null,
        .behavior = @splat(62),
        .control = control,
        .state = state,
        .table = created.value.result.ddl.committed.resulting.interpretation,
        .table_name = try .init(table_name),
        .inbox = inbox,
        .journal = journal,
        .outbox = outbox,
        .predicate = predicate,
        .lease_ms = 300000,
        .limits = .{},
        .transaction = c.DirectTransaction.default_limits,
        .protocol = .envelope,
        .mailboxes = mailboxes,
    };
    return .{ .pid = pid, .actor = actor, .activation = activation };
}

fn enqueueEnvelope(output: *std.heap.ArenaAllocator, client: c.DirectTableClient, target: p.StreamQueue.Partition, op_id: u64, pid: u64, env: s.Envelope) !void {
    const raw = try env.encodeAlloc(output.allocator());
    const identity = op(client, op_id);
    const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = @intCast(pid) } } }, .{ .value = .{ .atom = .{ .bytes = raw } } } };
    var buffer: [8192]u8 = undefined;
    const payload = try c.storage.LogBatch.encode(Runner.logSchema(target.interpretation.object.object), identity, .queue, &.{.{ .cells = &cells }}, &buffer);
    const enqueue: p.StreamQueue.Append = .{ .target = target, .operation = identity, .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) };
    _ = try Queue.apply(output, client, .{ .mutate = .{ .work = .{ .enqueue = enqueue }, .payload = payload } });
}

fn settleHeadFor(output: *std.heap.ArenaAllocator, client: c.DirectTableClient, actor: Actor.Declaration, failure_turn: u64, op_id: u64) !void {
    const digest = try actor.digest(output.allocator());
    const claim: p.StreamQueue.Claim = .{ .target = actor.inbox, .operation = Actor.operation(actor.connection, digest, failure_turn, "claim", 0), .maximum = 1, .lease_ms = actor.lease_ms, .predicate = actor.predicate };
    const accepted = (try Queue.apply(output, client, .{ .operation = .{ .claim = claim } })).operation.?.claim;
    try t.expectEqual(@as(u32, 1), accepted.rows);
    const page = (try Queue.apply(output, client, .{ .page = .{ .cursor = .{ .receipt = accepted, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    _ = try Queue.apply(output, client, .{ .mutate = .{ .work = .{ .settle = .{ .operation = op(client, op_id), .lease = page.rows[0].lease.original, .action = .ack } } } });
}

fn advanceComplete(runner: *Runner, handler: Runner.Handler) !Runner.Result {
    var result = try runner.advance(handler);
    for (0..16) |_| {
        if (result != .recovering) break;
        result = try runner.advance(handler);
    }
    return result;
}

fn exerciseCalls(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !void {
    (try client.call(.initialize)).deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();

    const key_1202 = try p.Ed25519.KeyPair.generateDeterministic(@splat(122));
    _ = try admin.change(.{ .bind_credential = .{ .principal = 1202, .role = role, .public_key = key_1202.public_key.toBytes() } });
    var client_1202 = client;
    client_1202.connection.principal = 1202;
    client_1202.key = key_1202;

    const shared_inbox = try createLog(init, client, &output, role, 810001, "calls_shared_inbox", .queue);
    const peer_inbox = try createLog(init, client, &output, role, 810002, "calls_peer_inbox", .queue);

    const caller_spec = try createActor(init, client, &output, admin, role, 101, 811000, "caller_a", shared_inbox, &.{peer_inbox});
    const callee_spec = try createActor(init, client, &output, admin, role, 1202, 812000, "callee_b", peer_inbox, &.{shared_inbox});
    // Spoofer C shares worker principal 1202 with Callee B, but owns a distinct PID.
    const spoofer_spec = try createActor(init, client, &output, admin, role, 1202, 813000, "spoofer_c", shared_inbox, &.{shared_inbox});

    var caller_runner = try Runner.init(init.gpa, client, caller_spec.actor, caller_spec.activation);
    defer caller_runner.deinit();
    try caller_runner.bootstrap();

    var callee_runner = try Runner.init(init.gpa, client_1202, callee_spec.actor, callee_spec.activation);
    defer callee_runner.deinit();
    try callee_runner.bootstrap();

    var spoofer_runner = try Runner.init(init.gpa, client_1202, spoofer_spec.actor, spoofer_spec.activation);
    defer spoofer_runner.deinit();
    try spoofer_runner.bootstrap();

    const CallerState = struct {
        peer_inbox: p.StreamQueue.Partition,
        callee_pid: u64,
        corr1: u64 = 0,
        corr2: u64 = 0,
        replies_seen: usize = 0,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const env = turn.context.envelope.?;
            switch (env.kind) {
                .cast => {
                    if (std.mem.eql(u8, turn.input, "start")) {
                        self.corr1 = try turn.call(self.peer_inbox, self.callee_pid, "compute:21");
                        try turn.put("status", "waiting-1");
                    } else if (std.mem.eql(u8, turn.input, "start-cancel")) {
                        self.corr2 = try turn.call(self.peer_inbox, self.callee_pid, "slow-op");
                    } else if (std.mem.eql(u8, turn.input, "do-cancel")) {
                        try turn.cancelWait(self.corr2);
                        try turn.put("status", "cancelled-2");
                    }
                },
                .reply => {
                    self.replies_seen += 1;
                    try turn.put("answer", turn.input);
                    try turn.put("status", "replied-1");
                },
                else => return error.UnexpectedEnvelopeKind,
            }
        }
    };

    const CalleeState = struct {
        return_inbox: p.StreamQueue.Partition,
        caller_pid: u64,
        calls_seen: usize = 0,
        cancels_seen: usize = 0,
        send_duplicate: bool = true,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const env = turn.context.envelope.?;
            switch (env.kind) {
                .call => {
                    try t.expectEqual(self.caller_pid, turn.context.origin.?.actor.pid);
                    self.calls_seen += 1;
                    try turn.put("last_request", turn.input);
                    try turn.reply(self.return_inbox, "42");
                    if (self.send_duplicate) {
                        self.send_duplicate = false;
                        try turn.sendEnvelope(self.return_inbox, self.caller_pid, .{ .kind = .reply, .correlation = env.correlation, .payload = "duplicate-99" });
                    }
                },
                .cancel => {
                    try t.expectEqual(self.caller_pid, turn.context.origin.?.actor.pid);
                    self.cancels_seen += 1;
                },
                else => return error.UnexpectedEnvelopeKind,
            }
        }
    };

    var caller_state: CallerState = .{ .peer_inbox = peer_inbox, .callee_pid = callee_spec.pid };
    var callee_state: CalleeState = .{ .return_inbox = shared_inbox, .caller_pid = caller_spec.pid };

    // 1. Concurrent enqueue mid-turn triggers optimistic TransactionConflict retry without blocking
    //    (both during statement evaluation at .acquire and during commit preparation at .executed).
    try enqueueEnvelope(&output, client, shared_inbox, 820001, caller_spec.pid, .{ .kind = .cast, .payload = "start" });
    const ConflictInjector = struct {
        alloc_arena: *std.heap.ArenaAllocator,
        caller: c.DirectTableClient,
        inbox: p.StreamQueue.Partition,
        spoofer_pid: u64,
        target_point: Runner.Point,
        op_id: u64,
        injected: bool = false,
        fn hit(raw: *anyopaque, pt: Runner.Point) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (pt != self.target_point or self.injected) return;
            self.injected = true;
            try enqueueEnvelope(self.alloc_arena, self.caller, self.inbox, self.op_id, self.spoofer_pid, .{ .kind = .cast, .payload = "spoof" });
        }
    };
    var injector_acquire: ConflictInjector = .{ .alloc_arena = &output, .caller = client, .inbox = shared_inbox, .spoofer_pid = spoofer_spec.pid, .target_point = .acquire, .op_id = 820002 };
    caller_runner.hook = .{ .context = &injector_acquire, .hit = ConflictInjector.hit };
    const first_step = try caller_runner.advance(.{ .context = &caller_state, .run = CallerState.handle });
    caller_runner.hook = null;
    try t.expect(injector_acquire.injected);
    try t.expectEqual(Runner.Result.recovering, first_step);
    try t.expectEqual(@as(u8, 1), (try caller_runner.inspect()).conflict_retries);
    try t.expect(!(try caller_runner.inspect()).blocked);

    var injector_commit: ConflictInjector = .{ .alloc_arena = &output, .caller = client, .inbox = shared_inbox, .spoofer_pid = spoofer_spec.pid, .target_point = .executed, .op_id = 820009 };
    caller_runner.hook = .{ .context = &injector_commit, .hit = ConflictInjector.hit };
    const second_step = try caller_runner.advance(.{ .context = &caller_state, .run = CallerState.handle });
    caller_runner.hook = null;
    try t.expect(injector_commit.injected);
    try t.expectEqual(Runner.Result.recovering, second_step);
    try t.expectEqual(@as(u8, 2), (try caller_runner.inspect()).conflict_retries);
    try t.expect(!(try caller_runner.inspect()).blocked);

    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &caller_state, .run = CallerState.handle }));
    try t.expectEqual(@as(u8, 0), (try caller_runner.inspect()).conflict_retries);
    try t.expect(caller_state.corr1 != 0);

    // 2. Direct Queue.enqueue forging a reply (execution == null) is rejected before handler execution.
    try enqueueEnvelope(&output, client, shared_inbox, 820003, caller_spec.pid, .{ .kind = .reply, .correlation = caller_state.corr1, .payload = "forged-direct" });
    try t.expectError(error.HandlerStopped, caller_runner.advance(.{ .context = &caller_state, .run = CallerState.handle, .failure = .stop }));
    try t.expectEqual(@as(usize, 0), caller_state.replies_seen);
    _ = try advanceComplete(&caller_runner, .{ .context = &caller_state, .run = CallerState.handle, .failure = .block_input });
    const blocked_1 = try caller_runner.inspect();
    try t.expect(blocked_1.blocked);
    try settleHeadFor(&output, client, caller_spec.actor, blocked_1.failure, 820010);
    try caller_runner.retryBlocked();

    // 3. Same-principal cross-PID spoofing (Spoofer C replying under principal 1202 for Callee B) is rejected.
    const SpoofBody = struct {
        inbox: p.StreamQueue.Partition,
        victim_pid: u64,
        corr: u64,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            try turn.sendEnvelope(self.inbox, self.victim_pid, .{ .kind = .reply, .correlation = self.corr, .payload = "forged-cross-pid" });
        }
    };
    var spoof_body: SpoofBody = .{ .inbox = shared_inbox, .victim_pid = caller_spec.pid, .corr = caller_state.corr1 };
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&spoofer_runner, .{ .context = &spoof_body, .run = SpoofBody.handle }));
    try t.expectError(error.HandlerStopped, caller_runner.advance(.{ .context = &caller_state, .run = CallerState.handle, .failure = .stop }));
    try t.expectEqual(@as(usize, 0), caller_state.replies_seen);
    _ = try advanceComplete(&caller_runner, .{ .context = &caller_state, .run = CallerState.handle, .failure = .block_input });
    const blocked_2 = try caller_runner.inspect();
    try t.expect(blocked_2.blocked);
    try settleHeadFor(&output, client, caller_spec.actor, blocked_2.failure, 820020);
    try caller_runner.retryBlocked();

    // 4. Legitimate Callee B processes call, sends reply + duplicate; Caller A runs once and absorbs duplicate as closed.
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&callee_runner, .{ .context = &callee_state, .run = CalleeState.handle }));
    try t.expectEqual(@as(usize, 1), callee_state.calls_seen);

    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &caller_state, .run = CallerState.handle }));
    try t.expectEqual(@as(usize, 1), caller_state.replies_seen);
    try t.expectEqualStrings("42", (try KV.apply(&output, client, .{ .get = .{ .object = caller_spec.actor.state.object, .key = "answer" } })).value.value.?.value.atom.bytes);

    // Second (duplicate) reply commits as closed disposition without re-invoking CallerState.handle.
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &caller_state, .run = CallerState.handle }));
    try t.expectEqual(@as(usize, 1), caller_state.replies_seen);
    try t.expectEqualStrings("42", (try KV.apply(&output, client, .{ .get = .{ .object = caller_spec.actor.state.object, .key = "answer" } })).value.value.?.value.atom.bytes);
    try t.expectEqualStrings(s.Wait.closed_reply_disposition, (try KV.apply(&output, client, .{ .get = .{ .object = caller_spec.actor.state.object, .key = s.Wait.disposition_key } })).value.value.?.value.atom.bytes);

    // 5. Explicit cancelWait closes the wait, delivers advisory cancel, and absorbs late callee reply.
    try enqueueEnvelope(&output, client, shared_inbox, 820030, caller_spec.pid, .{ .kind = .cast, .payload = "start-cancel" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &caller_state, .run = CallerState.handle }));
    try t.expect(caller_state.corr2 != 0);

    try enqueueEnvelope(&output, client, shared_inbox, 820031, caller_spec.pid, .{ .kind = .cast, .payload = "do-cancel" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &caller_state, .run = CallerState.handle }));

    // Callee B processes both the original call (emitting a now-late reply) and the advisory cancel.
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&callee_runner, .{ .context = &callee_state, .run = CalleeState.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&callee_runner, .{ .context = &callee_state, .run = CalleeState.handle }));
    try t.expectEqual(@as(usize, 2), callee_state.calls_seen);
    try t.expectEqual(@as(usize, 1), callee_state.cancels_seen);

    // Caller A absorbs the late reply after cancellation without invoking CallerState.handle.
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &caller_state, .run = CallerState.handle }));
    try t.expectEqual(@as(usize, 1), caller_state.replies_seen);
    try t.expectEqualStrings("cancelled-2", (try KV.apply(&output, client, .{ .get = .{ .object = caller_spec.actor.state.object, .key = "status" } })).value.value.?.value.atom.bytes);
}

fn createTimerQueue(init: std.process.Init, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, role: u64, object: u64, name: []const u8, lease_ms: u64) !p.StreamQueue.Partition {
    const intent: c.DirectLog.Intent = .{ .kind = .queue, .namespace = 1, .name = try .init(name), .action = .{ .create = .{
        .owner = role,
        .schema = Runner.logSchema(object),
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = lease_ms, .maximum_lease_ms = 300000, .maximum_attempts = 8, .backoff = .{ .initial_ms = 10, .maximum_ms = 100, .multiplier = 1 }, .dead_letter = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = op(client, object + 100), .target = .{ .scope = client.connection.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(init.gpa) } };
    _ = try c.DirectLogClient.apply(output, client, .{ .admit = request });
    const completed = (try c.DirectLogClient.apply(output, client, .{ .operation = .{ .binding = request.binding, .command = .execute, .steps = 16 } })).operation.operation;
    try t.expectEqual(.complete, completed.phase);
    return .{ .definition = p.Growth.current_definition, .interpretation = completed.resulting.?.stored.declaration.interpretation, .partition = 0 };
}

fn exerciseTimersAndPool(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !void {
    (try client.call(.initialize)).deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();

    // Dedicated observer principal 1209 (no actor execution provenance).
    const key_1209 = try p.Ed25519.KeyPair.generateDeterministic(@splat(129));
    _ = try admin.change(.{ .bind_credential = .{ .principal = 1209, .role = role, .public_key = key_1209.public_key.toBytes() } });
    var obs_client = client;
    obs_client.connection.principal = 1209;
    obs_client.key = key_1209;

    const key_1203 = try p.Ed25519.KeyPair.generateDeterministic(@splat(123));
    _ = try admin.change(.{ .bind_credential = .{ .principal = 1203, .role = role, .public_key = key_1203.public_key.toBytes() } });
    var callee_client = client;
    callee_client.connection.principal = 1203;
    callee_client.key = key_1203;

    const timers_queue = try createTimerQueue(init, client, &output, role, 830001, "station_timers_q", 30000);
    const caller_inbox = try createLog(init, client, &output, role, 830002, "timer_caller_inbox", .queue);
    const callee_inbox = try createLog(init, client, &output, role, 830003, "timer_callee_inbox", .queue);

    var caller_spec = try createActor(init, client, &output, admin, role, 101, 831000, "timer_caller", caller_inbox, &.{callee_inbox});
    caller_spec.actor.timers = timers_queue;
    const callee_spec = try createActor(init, client, &output, admin, role, 1203, 832000, "timer_callee", callee_inbox, &.{caller_inbox});

    var caller_runner = try Runner.init(init.gpa, client, caller_spec.actor, caller_spec.activation);
    defer caller_runner.deinit();
    try caller_runner.bootstrap();

    var callee_runner = try Runner.init(init.gpa, callee_client, callee_spec.actor, callee_spec.activation);
    defer callee_runner.deinit();
    try callee_runner.bootstrap();

    var inspector: s.Observer.NativeInspector = .{
        .client = client.authority,
        .realm = client.connection.scope.realm,
        .principal = 1209,
        .key = key_1209,
    };
    var observer = try s.Observer.init(init.gpa, obs_client, timers_queue, null, 2000, 1, inspector.view());
    defer observer.deinit();

    const TimedCaller = struct {
        caller_client: c.DirectTableClient,
        timers_q: p.StreamQueue.Partition,
        peer_inbox: p.StreamQueue.Partition,
        callee_pid: u64,
        delay_ms: u64 = 2000,
        deadline_ms: u64 = 0,
        corr1: u64 = 0,
        corr2: u64 = 0,
        timeouts_seen: usize = 0,
        replies_seen: usize = 0,
        fn sampleDeadline(self: *@This(), alloc: std.mem.Allocator) !u64 {
            var tmp: std.heap.ArenaAllocator = .init(alloc);
            defer tmp.deinit();
            const now = (try Queue.apply(&tmp, self.caller_client, .{ .current_time = self.timers_q })).current_time.time.earliest_ms;
            self.deadline_ms = now + self.delay_ms;
            return self.deadline_ms;
        }
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            switch (turn.context.envelope.?.kind) {
                .cast => {
                    if (std.mem.eql(u8, turn.input, "slow")) {
                        const dl = try self.sampleDeadline(turn.allocator);
                        self.corr1 = try turn.callWithTimer(self.peer_inbox, self.callee_pid, "slow-op", dl, 1209);
                        try turn.put("timer_result", "waiting-slow");
                    } else if (std.mem.eql(u8, turn.input, "fast")) {
                        const dl = try self.sampleDeadline(turn.allocator);
                        self.corr2 = try turn.callWithTimer(self.peer_inbox, self.callee_pid, "fast-op", dl, 1209);
                        try turn.put("timer_result", "waiting-fast");
                    }
                },
                .timeout => {
                    self.timeouts_seen += 1;
                    const obs = try s.Timer.Observation.decode(turn.input);
                    try t.expect(obs.observed_ms >= self.deadline_ms);
                    try turn.put("timer_result", "timed-out");
                },
                .reply => {
                    self.replies_seen += 1;
                    try turn.put("timer_result", turn.input);
                },
                else => return error.UnexpectedEnvelopeKind,
            }
        }
    };
    const TimedCallee = struct {
        return_inbox: p.StreamQueue.Partition,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (std.mem.eql(u8, turn.input, "slow-op")) {
                try turn.reply(self.return_inbox, "late-slow-reply");
            } else {
                try turn.reply(self.return_inbox, "fast-ok");
            }
        }
    };

    var timed_caller: TimedCaller = .{ .caller_client = client, .timers_q = timers_queue, .peer_inbox = callee_inbox, .callee_pid = callee_spec.pid, .delay_ms = 4500 };
    var timed_callee: TimedCallee = .{ .return_inbox = caller_inbox };

    // 1. Schedule timed call; ticket stays unclaimable on QueueTimingWheel before deadline_ms.
    try enqueueEnvelope(&output, client, caller_inbox, 835001, caller_spec.pid, .{ .kind = .cast, .payload = "slow" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &timed_caller, .run = TimedCaller.handle }));
    try t.expectEqual(s.Observer.Result.idle, try observer.step(10));

    // 2. Observer crash between TMO1 enqueue and ticket ACK deduplicates via deterministic d.Operation on restart.
    const CrashAtEnqueued = struct {
        crashed: bool = false,
        fn hit(raw: *anyopaque, pt: s.Observer.Point) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (pt == .enqueued and !self.crashed) {
                self.crashed = true;
                return error.SimulatedObserverCrash;
            }
        }
    };
    var crash_hook: CrashAtEnqueued = .{};
    observer.hook = .{ .context = &crash_hook, .hit = CrashAtEnqueued.hit };
    for (0..16) |_| {
        const res = observer.step(500) catch |err| {
            try t.expectEqual(error.SimulatedObserverCrash, err);
            break;
        };
        try t.expectEqual(s.Observer.Result.idle, res);
    }
    observer.hook = null;
    try t.expect(crash_hook.crashed);

    // Wait for un-ACKed timer ticket lease (2s + configured 2*10s clock error bound) to expire so restarted observer re-claims at epoch 2.
    var observer_restarted = try s.Observer.init(init.gpa, obs_client, timers_queue, null, 30000, 2, inspector.view());
    defer observer_restarted.deinit();
    var redelivered = false;
    for (0..120) |_| {
        if (try observer_restarted.step(500) == .delivered) {
            redelivered = true;
            break;
        }
    }
    try t.expect(redelivered);
    // QueuePartition deduplicated the identical deliver d.Operation: caller inbox cut has only 2 total rows (initial cast + 1 TMO1).
    try t.expectEqual(@as(u64, 2), (try Queue.apply(&output, client, .{ .observe = caller_inbox })).cut.next);

    // Caller processes TMO1 once; late callee reply is absorbed as closed-reply without invoking handler.
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &timed_caller, .run = TimedCaller.handle }));
    try t.expectEqual(@as(usize, 1), timed_caller.timeouts_seen);
    try t.expectEqualStrings("timed-out", (try KV.apply(&output, client, .{ .get = .{ .object = caller_spec.actor.state.object, .key = "timer_result" } })).value.value.?.value.atom.bytes);

    try t.expectEqual(Runner.Result.committed, try advanceComplete(&callee_runner, .{ .context = &timed_callee, .run = TimedCallee.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &timed_caller, .run = TimedCaller.handle }));
    try t.expectEqual(@as(usize, 0), timed_caller.replies_seen);
    try t.expectEqualStrings("timed-out", (try KV.apply(&output, client, .{ .get = .{ .object = caller_spec.actor.state.object, .key = "timer_result" } })).value.value.?.value.atom.bytes);

    // 3. Reply-before-timeout race: fast reply closes wait, late TMO1 is absorbed as closed-timeout.
    timed_caller.delay_ms = 4500;
    try enqueueEnvelope(&output, client, caller_inbox, 835002, caller_spec.pid, .{ .kind = .cast, .payload = "fast" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &timed_caller, .run = TimedCaller.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&callee_runner, .{ .context = &timed_callee, .run = TimedCallee.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &timed_caller, .run = TimedCaller.handle }));
    try t.expectEqual(@as(usize, 1), timed_caller.replies_seen);
    try t.expectEqualStrings("fast-ok", (try KV.apply(&output, client, .{ .get = .{ .object = caller_spec.actor.state.object, .key = "timer_result" } })).value.value.?.value.atom.bytes);

    var delivered_second = false;
    for (0..40) |_| {
        if (try observer_restarted.step(500) == .delivered) {
            delivered_second = true;
            break;
        }
    }
    try t.expect(delivered_second);
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &timed_caller, .run = TimedCaller.handle }));
    try t.expectEqual(@as(usize, 1), timed_caller.timeouts_seen);
    try t.expectEqualStrings("fast-ok", (try KV.apply(&output, client, .{ .get = .{ .object = caller_spec.actor.state.object, .key = "timer_result" } })).value.value.?.value.atom.bytes);
    try t.expectEqualStrings(s.Wait.closed_timeout_disposition, (try KV.apply(&output, client, .{ .get = .{ .object = caller_spec.actor.state.object, .key = s.Wait.disposition_key } })).value.value.?.value.atom.bytes);

    // 4. Terminated target PID settles obsolete ticket cleanly; mismatched observer ticket is refused without settlement.
    const dead_pid = try admin.submit(.{ .spawn = .{} });
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = dead_pid }, .grantee = role, .privileges = p.permission(.inspect) } });
    _ = try admin.submit(.{ .terminate = dead_pid });
    const enqueueTicket = struct {
        fn send(arena: *std.heap.ArenaAllocator, caller_c: c.DirectTableClient, q: p.StreamQueue.Partition, op_num: u64, ticket: s.Timer.Ticket) !void {
            const raw = try ticket.encodeAlloc(arena.allocator());
            const id = op(caller_c, op_num);
            const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = @intCast(ticket.observer) } } }, .{ .value = .{ .atom = .{ .bytes = raw } } } };
            var buf: [8192]u8 = undefined;
            const payload = try c.storage.LogBatch.encode(Runner.logSchema(q.interpretation.object.object), id, .queue, &.{.{ .cells = &cells, .visible_ms = 0 }}, &buf);
            const append: p.StreamQueue.Append = .{ .target = q, .operation = id, .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) };
            _ = try Queue.apply(arena, caller_c, .{ .mutate = .{ .work = .{ .enqueue = append }, .payload = payload } });
        }
    }.send;
    try enqueueTicket(&output, client, timers_queue, 835010, .{
        .definition = p.Growth.current_definition,
        .kind = .wait_timeout,
        .target_pid = dead_pid,
        .target_inbox = caller_inbox,
        .correlation = 0x90001,
        .deadline_ms = 1,
        .observer = 1209,
    });
    try t.expectEqual(s.Observer.Result.settled_obsolete, try observer_restarted.step(100));

    try enqueueTicket(&output, client, timers_queue, 835011, .{
        .definition = p.Growth.current_definition,
        .kind = .wait_timeout,
        .target_pid = caller_spec.pid,
        .target_inbox = caller_inbox,
        .correlation = 0x90002,
        .deadline_ms = 1,
        .observer = 9999,
    });
    try t.expectError(error.UnexpectedObserverTicket, observer_restarted.step(100));

    // 5. Zero-worker idle Pool: 1,000 durable actors in paged KV over 4 active Runner slots.
    const pool_inbox = try createLog(init, client, &output, role, 836001, "pool_shared_inbox", .queue);
    const seed_actor = try createActor(init, client, &output, admin, role, 101, 837000, "pool_seed", pool_inbox, &.{});
    {
        var seed_runner = try Runner.init(init.gpa, client, seed_actor.actor, seed_actor.activation);
        defer seed_runner.deinit();
        try seed_runner.bootstrap();
    }

    const active_indices = [_]usize{ 0, 137, 289, 412, 577, 701, 864, 999 };
    var pids: [1000]u64 = undefined;
    pids[0] = seed_actor.pid;
    for (1..1000) |idx| {
        var is_active = false;
        for (active_indices) |active_idx| if (active_idx == idx) {
            is_active = true;
            break;
        };
        if (is_active) {
            const spawned = try admin.submit(.{ .spawn = .{} });
            _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = spawned }, .grantee = role, .privileges = p.permission(.execute) | p.permission(.inspect) } });
            _ = try admin.submit(.{ .own = .{ .pid = spawned, .expected_generation = 0, .worker = 101 } });
            pids[idx] = spawned;
        } else {
            pids[idx] = 900_000 + idx;
        }
    }

    const makePoolDeclaration = struct {
        fn build(alloc: std.mem.Allocator, template: Actor.Declaration, pid: u64) !Actor.Declaration {
            const fields = [_]c.fuze.WorkloadProjection.Field{ .{ .column = 1 }, .{ .column = 2 } };
            const layout = try c.fuze.WorkloadProjection.schemaLayout(Runner.logSchema(template.inbox.interpretation.object.object), &fields, .claim);
            const pred = try c.fuze.QueuePredicate.encode(alloc, template.inbox, Runner.logSchema(template.inbox.interpretation.object.object), &fields, .{
                .schema = layout.typeOf(),
                .source_basis = @splat(0),
                .collations = layout.collations,
                .projection = &.{0},
                .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = @intCast(pid) } } },
            });
            var decl = template;
            decl.pid = pid;
            decl.predicate = pred;
            return decl;
        }
    }.build;

    // Persist the remaining 999 initialized Actor.Head rows in two paged KV batches.
    for ([_]struct { start: usize, end: usize, op_num: u64 }{
        .{ .start = 1, .end = 500, .op_num = 838001 },
        .{ .start = 500, .end = 1000, .op_num = 838002 },
    }) |batch| {
        var batch_arena: std.heap.ArenaAllocator = .init(init.gpa);
        defer batch_arena.deinit();
        var changes = try batch_arena.allocator().alloc(c.storage.KVPartition.Change, batch.end - batch.start);
        var keys = try batch_arena.allocator().alloc([14]u8, batch.end - batch.start);
        for (batch.start..batch.end, 0..) |idx, slot| {
            const decl = try makePoolDeclaration(batch_arena.allocator(), seed_actor.actor, pids[idx]);
            var head = Actor.Head.initial(try decl.digest(batch_arena.allocator()));
            head.initialized = true;
            keys[slot] = Actor.key(pids[idx]);
            const raw_head = try p.Json.valueAllocBounded(batch_arena.allocator(), head, Actor.max_bytes);
            changes[slot] = .{ .put = .{ .key = &keys[slot], .value = .{ .value = .{ .atom = .{ .bytes = raw_head } } }, .expect = .absent } };
        }
        const mut = try KV.prepareMutation(&batch_arena, .{
            .definition = p.Growth.current_definition,
            .identity = op(client, batch.op_num),
            .target = seed_actor.actor.control.object,
            .action = .insert,
            .expected_definition = seed_actor.actor.control,
            .expected_data = null,
            .intent = undefined,
        }, Actor.spec, changes);
        _ = try KV.apply(&batch_arena, client, .{ .mutate = mut });
    }

    const PoolDirectory = struct {
        template: Actor.Declaration,
        pids: []const u64,
        turns_handled: usize = 0,
        fn handleActor(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.turns_handled += 1;
            const k = try std.fmt.allocPrint(turn.allocator, "actor:{d}", .{turn.context.actor_pid});
            try turn.put(k, turn.input);
        }
        fn resolve(raw: *anyopaque, alloc: std.mem.Allocator, pid: u64) !?s.Pool.Binding {
            const self: *@This() = @ptrCast(@alignCast(raw));
            var found = false;
            for (self.pids) |candidate| if (candidate == pid) {
                found = true;
                break;
            };
            if (!found) return null;
            const decl = try makePoolDeclaration(alloc, self.template, pid);
            return .{
                .actor = decl,
                .activation = .{ .realm = decl.connection.scope.realm, .pid = pid, .principal = decl.connection.principal, .generation = 1, .code = decl.code, .workload = decl.workload, .input = null },
                .handler = .{ .context = raw, .run = handleActor },
            };
        }
    };

    var directory: PoolDirectory = .{ .template = seed_actor.actor, .pids = &pids };
    var pool = try s.Pool.init(init.gpa, client, pool_inbox, 300000, 16384, 4, 1, .{ .context = &directory, .resolve = PoolDirectory.resolve });
    defer pool.deinit();

    // Idle check: 1,000 durable actors hold zero resident Runners.
    try t.expectEqual(@as(usize, 0), pool.activeCount());
    try t.expectEqual(s.Pool.StepResult.idle, try pool.step(20));
    try t.expectEqual(@as(usize, 0), pool.activeCount());

    // Enqueue 8 messages across scattered actors in the 1,000 population.
    for (active_indices, 0..) |actor_idx, msg_i| {
        const msg = try std.fmt.allocPrint(output.allocator(), "payload-{d}", .{actor_idx});
        try enqueueEnvelope(&output, client, pool_inbox, 839000 + msg_i, pids[actor_idx], .{ .kind = .cast, .payload = msg });
    }

    // Fill the 4 slots and prove the 5th claim defers until a slot frees up.
    for (0..4) |_| try t.expect(try pool.claimIntoSlot(100));
    try t.expectEqual(@as(usize, 4), pool.activeCount());
    try t.expect(!(try pool.claimIntoSlot(null)));

    while (pool.completed_turns < active_indices.len) {
        _ = try pool.step(50);
    }
    try t.expectEqual(@as(u64, active_indices.len), pool.completed_turns);
    try t.expectEqual(@as(usize, 4), pool.peak_active_runners);
    try t.expectEqual(@as(usize, 0), pool.activeCount());
    try t.expectEqual(active_indices.len, directory.turns_handled);

    for (active_indices) |actor_idx| {
        const key_name = try std.fmt.allocPrint(output.allocator(), "actor:{d}", .{pids[actor_idx]});
        const expected_val = try std.fmt.allocPrint(output.allocator(), "payload-{d}", .{actor_idx});
        const actual_val = (try KV.apply(&output, client, .{ .get = .{ .object = seed_actor.actor.state.object, .key = key_name } })).value.value.?.value.atom.bytes;
        try t.expectEqualStrings(expected_val, actual_val);
    }

    pool.shutdown();
    try t.expectEqual(@as(usize, 0), pool.activeCount());
    try t.expectError(error.PoolStopped, pool.step(10));
}

fn exerciseServices(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !void {
    (try client.call(.initialize)).deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();

    const key_1210 = try p.Ed25519.KeyPair.generateDeterministic(@splat(130));
    _ = try admin.change(.{ .bind_credential = .{ .principal = 1210, .role = role, .public_key = key_1210.public_key.toBytes() } });
    var obs_client = client;
    obs_client.connection.principal = 1210;
    obs_client.key = key_1210;

    const svc_inbox = try createLog(init, client, &output, role, 850001, "svc_shared_inbox", .queue);
    const timers_queue = try createTimerQueue(init, client, &output, role, 850002, "svc_timers_q", 30000);

    const reg_spec = try createActor(init, client, &output, admin, role, 101, 851000, "svc_registry", svc_inbox, &.{});
    const caller_spec = try createActor(init, client, &output, admin, role, 101, 852000, "svc_caller", svc_inbox, &.{});
    const target1_spec = try createActor(init, client, &output, admin, role, 101, 853000, "svc_target1", svc_inbox, &.{});
    const target2_spec = try createActor(init, client, &output, admin, role, 101, 854000, "svc_target2", svc_inbox, &.{});
    var sup_spec = try createActor(init, client, &output, admin, role, 101, 855000, "svc_supervisor", svc_inbox, &.{});
    sup_spec.actor.timers = timers_queue;

    const child_pid = try admin.submit(.{ .spawn = .{} });
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = child_pid }, .grantee = role, .privileges = p.permission(.execute) | p.permission(.inspect) } });
    _ = try admin.submit(.{ .own = .{ .pid = child_pid, .expected_generation = 0, .worker = 101 } });

    const replacement_pid = try admin.submit(.{ .spawn = .{} });
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = replacement_pid }, .grantee = role, .privileges = p.permission(.execute) | p.permission(.inspect) } });
    _ = try admin.submit(.{ .own = .{ .pid = replacement_pid, .expected_generation = 0, .worker = 101 } });

    var reg_runner = try Runner.init(init.gpa, client, reg_spec.actor, reg_spec.activation);
    defer reg_runner.deinit();
    try reg_runner.bootstrap();

    var caller_runner = try Runner.init(init.gpa, client, caller_spec.actor, caller_spec.activation);
    defer caller_runner.deinit();
    try caller_runner.bootstrap();

    var target1_runner = try Runner.init(init.gpa, client, target1_spec.actor, target1_spec.activation);
    defer target1_runner.deinit();
    try target1_runner.bootstrap();

    var target2_runner = try Runner.init(init.gpa, client, target2_spec.actor, target2_spec.activation);
    defer target2_runner.deinit();
    try target2_runner.bootstrap();

    var sup_runner = try Runner.init(init.gpa, client, sup_spec.actor, sup_spec.activation);
    defer sup_runner.deinit();
    try sup_runner.bootstrap();

    // 1. Scoped Registry: register, route in caller transaction, then rebind/unregister without redirecting already-routed message.
    const RegistryBody = struct {
        state_object: u64,
        return_inbox: p.StreamQueue.Partition,
        caller_pid: u64,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            switch (turn.context.envelope.?.kind) {
                .cast => {
                    if (std.mem.eql(u8, turn.input, "provision")) {
                        try s.Registry.create(turn, self.state_object, 1);
                        try s.Registry.grant(turn, 1, .{ .process = self.caller_pid }, .{ .lookup = true, .mutate = true });
                    }
                },
                .call => try s.Registry.handle(turn, self.state_object, self.return_inbox),
                else => return error.UnexpectedEnvelopeKind,
            }
        }
    };
    const RouteCallerBody = struct {
        inbox: p.StreamQueue.Partition,
        reg_pid: u64,
        target1: u64,
        target2: u64,
        last_routed: u64 = 0,
        last_revision: u64 = 0,
        phase: enum { idle, registering, looking_up_1, rebinding, looking_up_2, unregistering } = .idle,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const ledger = try s.Registry.Name.init("ledger");
            switch (turn.context.envelope.?.kind) {
                .cast => {
                    if (std.mem.eql(u8, turn.input, "register")) {
                        self.phase = .registering;
                        const req = try (s.Registry.Request{ .scope = 1, .name = ledger, .operation = .register, .destination = self.target1 }).encodeAlloc(turn.allocator);
                        _ = try turn.call(self.inbox, self.reg_pid, req);
                    } else if (std.mem.eql(u8, turn.input, "lookup-and-route-1")) {
                        self.phase = .looking_up_1;
                        const req = try (s.Registry.Request{ .scope = 1, .name = ledger, .operation = .lookup }).encodeAlloc(turn.allocator);
                        _ = try turn.call(self.inbox, self.reg_pid, req);
                    } else if (std.mem.eql(u8, turn.input, "rebind")) {
                        self.phase = .rebinding;
                        const req = try (s.Registry.Request{ .scope = 1, .name = ledger, .operation = .rebind, .expected_revision = 1, .destination = self.target2 }).encodeAlloc(turn.allocator);
                        _ = try turn.call(self.inbox, self.reg_pid, req);
                    } else if (std.mem.eql(u8, turn.input, "lookup-and-route-2")) {
                        self.phase = .looking_up_2;
                        const req = try (s.Registry.Request{ .scope = 1, .name = ledger, .operation = .lookup }).encodeAlloc(turn.allocator);
                        _ = try turn.call(self.inbox, self.reg_pid, req);
                    } else if (std.mem.eql(u8, turn.input, "unregister")) {
                        self.phase = .unregistering;
                        const req = try (s.Registry.Request{ .scope = 1, .name = ledger, .operation = .unregister, .expected_revision = 2 }).encodeAlloc(turn.allocator);
                        _ = try turn.call(self.inbox, self.reg_pid, req);
                    }
                },
                .reply => {
                    const b = try s.Registry.Binding.decode(turn.input);
                    self.last_revision = b.revision;
                    if (self.phase == .looking_up_1) {
                        self.last_routed = try s.Registry.route(turn, self.reg_pid, self.inbox, "first-order");
                    } else if (self.phase == .looking_up_2) {
                        self.last_routed = try s.Registry.route(turn, self.reg_pid, self.inbox, "second-order");
                    }
                },
                else => return error.UnexpectedEnvelopeKind,
            }
        }
    };
    const TargetBody = struct {
        received: usize = 0,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.received += 1;
            try turn.put("last", turn.input);
        }
    };

    var reg_body: RegistryBody = .{ .state_object = reg_spec.actor.state.object.object, .return_inbox = svc_inbox, .caller_pid = caller_spec.pid };
    var route_caller: RouteCallerBody = .{ .inbox = svc_inbox, .reg_pid = reg_spec.pid, .target1 = target1_spec.pid, .target2 = target2_spec.pid };
    var target1_body: TargetBody = .{};
    var target2_body: TargetBody = .{};

    try enqueueEnvelope(&output, client, svc_inbox, 856001, reg_spec.pid, .{ .kind = .cast, .payload = "provision" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&reg_runner, .{ .context = &reg_body, .run = RegistryBody.handle }));

    // Register "ledger" -> target1
    try enqueueEnvelope(&output, client, svc_inbox, 856002, caller_spec.pid, .{ .kind = .cast, .payload = "register" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&reg_runner, .{ .context = &reg_body, .run = RegistryBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(@as(u64, 1), route_caller.last_revision);

    // Lookup and route "first-order" to target1 BEFORE target1 runs; then rebind "ledger" -> target2 and unregister!
    try enqueueEnvelope(&output, client, svc_inbox, 856003, caller_spec.pid, .{ .kind = .cast, .payload = "lookup-and-route-1" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&reg_runner, .{ .context = &reg_body, .run = RegistryBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(target1_spec.pid, route_caller.last_routed);

    try enqueueEnvelope(&output, client, svc_inbox, 856004, caller_spec.pid, .{ .kind = .cast, .payload = "rebind" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&reg_runner, .{ .context = &reg_body, .run = RegistryBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(@as(u64, 2), route_caller.last_revision);

    try enqueueEnvelope(&output, client, svc_inbox, 856005, caller_spec.pid, .{ .kind = .cast, .payload = "lookup-and-route-2" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&reg_runner, .{ .context = &reg_body, .run = RegistryBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(target2_spec.pid, route_caller.last_routed);

    try enqueueEnvelope(&output, client, svc_inbox, 856006, caller_spec.pid, .{ .kind = .cast, .payload = "unregister" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&reg_runner, .{ .context = &reg_body, .run = RegistryBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &route_caller, .run = RouteCallerBody.handle }));
    try t.expectEqual(@as(u64, 3), route_caller.last_revision);

    // Target1 still receives "first-order" and Target2 receives "second-order" despite subsequent rebind and tombstone.
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&target1_runner, .{ .context = &target1_body, .run = TargetBody.handle }));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&target2_runner, .{ .context = &target2_body, .run = TargetBody.handle }));
    try t.expectEqual(@as(usize, 1), target1_body.received);
    try t.expectEqual(@as(usize, 1), target2_body.received);
    try t.expectEqualStrings("first-order", (try KV.apply(&output, client, .{ .get = .{ .object = target1_spec.actor.state.object, .key = "last" } })).value.value.?.value.atom.bytes);
    try t.expectEqualStrings("second-order", (try KV.apply(&output, client, .{ .get = .{ .object = target2_spec.actor.state.object, .key = "last" } })).value.value.?.value.atom.bytes);

    // 2. Transactional Supervisor + Observer BackoffResponder over declared data and Timer Queue.
    const SupervisorBody = struct {
        child_id: u64,
        replacement_id: u64,
        retire_cut: u64 = 0,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (std.mem.eql(u8, turn.input, "register-child")) {
                try s.Supervisor.register(turn, .{ .pid = self.child_id, .observer = 1210, .limit = 1, .backoff_ms = 2500 });
                return;
            }
            if (std.mem.eql(u8, turn.input, "replace-child")) {
                try s.Supervisor.replace(turn, self.child_id, self.retire_cut, .{ .pid = self.replacement_id, .observer = 1210, .limit = 2, .backoff_ms = 0 });
                return;
            }
            try s.Supervisor.handle(turn);
        }
    };
    var sup_body: SupervisorBody = .{ .child_id = child_pid, .replacement_id = replacement_pid };
    try enqueueEnvelope(&output, client, svc_inbox, 856101, sup_spec.pid, .{ .kind = .cast, .payload = "register-child" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&sup_runner, .{ .context = &sup_body, .run = SupervisorBody.handle }));

    var inspector: s.Observer.NativeInspector = .{
        .client = client.authority,
        .realm = client.connection.scope.realm,
        .principal = 1210,
        .key = key_1210,
    };
    var backoff_responder: s.Supervisor.BackoffResponder = .{ .process_view = inspector.view() };
    var observer = try s.Observer.init(init.gpa, obs_client, timers_queue, null, 30000, 10, inspector.view());
    defer observer.deinit();
    observer.backoff_builder = backoff_responder.builder();

    const now_ms = (try Queue.apply(&output, client, .{ .current_time = timers_queue })).current_time.time.earliest_ms;
    const proc_before = try inspector.view().inspect(&inspector, child_pid);
    const fail_obs = try (s.Supervisor.Observation{
        .pid = child_pid,
        .generation = proc_before.generation,
        .failure = 1,
        .cut = proc_before.position,
        .observed_ms = now_ms,
        .kind = .failed,
    }).encode();
    try enqueueEnvelope(&output, obs_client, svc_inbox, 856102, sup_spec.pid, .{ .kind = .cast, .payload = &fail_obs });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&sup_runner, .{ .context = &sup_body, .run = SupervisorBody.handle }));

    const child_k = s.Supervisor.key(child_pid);
    const waiting_child = try s.Supervisor.Child.decode((try KV.apply(&output, client, .{ .get = .{ .object = sup_spec.actor.state.object, .key = &child_k } })).value.value.?.value.atom.bytes);
    try t.expectEqual(s.Supervisor.Phase.retry_wait, waiting_child.phase);

    // Observer claims due supervisor_backoff ticket from timers Queue and delivers SUP1 to transition to retry_requested.
    var backoff_delivered = false;
    for (0..16) |_| {
        if (try observer.step(500) == .delivered) {
            backoff_delivered = true;
            break;
        }
    }
    try t.expect(backoff_delivered);
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&sup_runner, .{ .context = &sup_body, .run = SupervisorBody.handle }));
    const requested_child = try s.Supervisor.Child.decode((try KV.apply(&output, client, .{ .get = .{ .object = sup_spec.actor.state.object, .key = &child_k } })).value.value.?.value.atom.bytes);
    try t.expectEqual(s.Supervisor.Phase.retry_requested, requested_child.phase);
    try t.expectEqual(@as(u8, 1), requested_child.attempts);

    // Permanent termination retires child; conditional replace binds replacement_pid.
    _ = try admin.submit(.{ .terminate = child_pid });
    const proc_term = try inspector.view().inspect(&inspector, child_pid);
    sup_body.retire_cut = proc_term.position;
    const term_obs = try (s.Supervisor.Observation{
        .pid = child_pid,
        .generation = proc_term.generation,
        .failure = 0,
        .cut = proc_term.position,
        .observed_ms = requested_child.observed_ms + 10,
        .kind = .terminated,
    }).encode();
    try enqueueEnvelope(&output, obs_client, svc_inbox, 856103, sup_spec.pid, .{ .kind = .cast, .payload = &term_obs });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&sup_runner, .{ .context = &sup_body, .run = SupervisorBody.handle }));

    try enqueueEnvelope(&output, client, svc_inbox, 856104, sup_spec.pid, .{ .kind = .cast, .payload = "replace-child" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&sup_runner, .{ .context = &sup_body, .run = SupervisorBody.handle }));

    const retired_child = try s.Supervisor.Child.decode((try KV.apply(&output, client, .{ .get = .{ .object = sup_spec.actor.state.object, .key = &child_k } })).value.value.?.value.atom.bytes);
    try t.expectEqual(s.Supervisor.Phase.retired, retired_child.phase);
    try t.expectEqual(@as(?u64, replacement_pid), retired_child.successor);
    const succ_k = s.Supervisor.key(replacement_pid);
    const succ_child = try s.Supervisor.Child.decode((try KV.apply(&output, client, .{ .get = .{ .object = sup_spec.actor.state.object, .key = &succ_k } })).value.value.?.value.atom.bytes);
    try t.expectEqual(s.Supervisor.Phase.watching, succ_child.phase);
}

const ServerServicesSaved = struct {
    definition: p.Growth.Definition,
    obs_principal: u64,
    local_life_principal: u64,
    replacement_worker: u64,
    obs_watch: s.ServiceController.Watch,
    local_life_watch: s.ServiceController.Watch,
    sup_actor: Actor.Declaration,
    sup_activation: p.Transaction.Execution,
    caller_actor: Actor.Declaration,
    caller_activation: p.Transaction.Execution,
    local_child_actor: Actor.Declaration,
    local_child_pid: u64,
    corr: u64,
};

const ProfileAuthority = struct {
    catalog: struct {
        authority: c.TableAuthority.Profile,
    },
};

fn grantDataObject(admin: anytype, auth_id: u64, grantee: u64, privileges: u64) !void {
    _ = try admin.change(.{ .grant = .{
        .object = c.TableAuthority.reference(auth_id),
        .grantee = grantee,
        .privileges = privileges,
    } });
}

fn serverServicesSetup(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, profile_path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();

    const prof_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, profile_path, output.allocator(), .limited(1024 * 1024));
    const prof = (try std.json.parseFromSlice(ProfileAuthority, output.allocator(), prof_bytes, .{ .ignore_unknown_fields = true })).value;
    const db_auth = prof.catalog.authority.database;
    const schema_auth = prof.catalog.authority.initial_schema_authority;

    const svc_inbox = try createLog(init, client, &output, role, 860001, "srv_shared_inbox", .queue);
    const timers_queue = try createTimerQueue(init, client, &output, role, 860002, "srv_timers_q", 30000);
    const inbox_auth = (try c.DirectLogClient.apply(&output, client, .{ .lookup = .{ .namespace = 1, .name = "srv_shared_inbox" } })).lookup.?.declaration.properties.authorization;
    const timers_auth = (try c.DirectLogClient.apply(&output, client, .{ .lookup = .{ .namespace = 1, .name = "srv_timers_q" } })).lookup.?.declaration.properties.authorization;

    var sup_spec = try createActor(init, client, &output, admin, role, 101, 861000, "srv_supervisor", svc_inbox, &.{});
    sup_spec.actor.timers = timers_queue;

    var caller_spec = try createActor(init, client, &output, admin, role, 101, 862000, "srv_caller", svc_inbox, &.{svc_inbox});
    caller_spec.actor.timers = timers_queue;

    var sub_child_spec = try createActor(init, client, &output, admin, role, 101, 863000, "srv_sub_child", svc_inbox, &.{});
    sub_child_spec.actor.workload = @splat(13);

    const key_repl_worker = try p.Ed25519.KeyPair.generateDeterministic(@splat(134));
    _ = try admin.change(.{ .bind_credential = .{ .principal = 1214, .role = role, .public_key = key_repl_worker.public_key.toBytes() } });
    var local_worker_client = client;
    local_worker_client.connection.principal = 1214;
    local_worker_client.key = key_repl_worker;

    const local_child_spec = try createActor(init, client, &output, admin, role, 1214, 864000, "srv_local_child", svc_inbox, &.{});

    const sup_state_auth = (try KV.apply(&output, client, .{ .observe = sup_spec.actor.state.object })).definition.authorization;
    const sub_ctrl_auth = (try KV.apply(&output, client, .{ .observe = sub_child_spec.actor.control.object })).definition.authorization;
    const local_ctrl_auth = (try KV.apply(&output, client, .{ .observe = local_child_spec.actor.control.object })).definition.authorization;

    // Provision least-privilege service principals:
    // 1211: observe (seed 131), 1212: Substrate child lifecycle (seed 132),
    // 1213: local child lifecycle (seed 133), 1214: local child worker (seed 134),
    // 1215: Substrate child worker (seed 135).
    const key_obs = try p.Ed25519.KeyPair.generateDeterministic(@splat(131));
    const key_sub_life = try p.Ed25519.KeyPair.generateDeterministic(@splat(132));
    const key_local_life = try p.Ed25519.KeyPair.generateDeterministic(@splat(133));
    const key_sub_worker_init = try p.Ed25519.KeyPair.generateDeterministic(@splat(135));
    const key_sub_worker_act1 = try p.Ed25519.KeyPair.generateDeterministic(@splat(136));
    const key_sub_worker_act2 = try p.Ed25519.KeyPair.generateDeterministic(@splat(137));

    const obs_role = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("srv-obs-role"), .login = true } })).?;
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = obs_role, .privileges = p.permission(.inspect) } });
    try grantDataObject(admin, db_auth, obs_role, c.TableAuthority.connect);
    try grantDataObject(admin, schema_auth, obs_role, c.TableAuthority.usage);
    try grantDataObject(admin, timers_auth, obs_role, c.LogAuthority.inspect | c.LogAuthority.read | c.LogAuthority.acquire | c.LogAuthority.settle);
    try grantDataObject(admin, inbox_auth, obs_role, c.LogAuthority.inspect | c.LogAuthority.append);
    try grantDataObject(admin, sup_state_auth, obs_role, c.KVAuthority.inspect | c.KVAuthority.read);
    try grantDataObject(admin, sub_ctrl_auth, obs_role, c.KVAuthority.inspect | c.KVAuthority.read);
    try grantDataObject(admin, local_ctrl_auth, obs_role, c.KVAuthority.inspect | c.KVAuthority.read);
    _ = try admin.change(.{ .bind_credential = .{ .principal = 1211, .role = obs_role, .public_key = key_obs.public_key.toBytes() } });

    const sub_life_role = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("srv-sub-life-role"), .login = true } })).?;
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = sub_child_spec.pid }, .grantee = sub_life_role, .privileges = p.permission(.inspect) | p.permission(.admin) } });
    try grantDataObject(admin, db_auth, sub_life_role, c.TableAuthority.connect);
    try grantDataObject(admin, schema_auth, sub_life_role, c.TableAuthority.usage);
    try grantDataObject(admin, sup_state_auth, sub_life_role, c.KVAuthority.inspect | c.KVAuthority.read);
    try grantDataObject(admin, sub_ctrl_auth, sub_life_role, c.KVAuthority.inspect | c.KVAuthority.read | c.KVAuthority.write);
    _ = try admin.change(.{ .bind_credential = .{ .principal = 1212, .role = sub_life_role, .pid = sub_child_spec.pid, .public_key = key_sub_life.public_key.toBytes() } });

    const local_life_role = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("srv-local-life-role"), .login = true } })).?;
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = local_child_spec.pid }, .grantee = local_life_role, .privileges = p.permission(.inspect) | p.permission(.admin) } });
    try grantDataObject(admin, db_auth, local_life_role, c.TableAuthority.connect);
    try grantDataObject(admin, schema_auth, local_life_role, c.TableAuthority.usage);
    try grantDataObject(admin, sup_state_auth, local_life_role, c.KVAuthority.inspect | c.KVAuthority.read);
    try grantDataObject(admin, local_ctrl_auth, local_life_role, c.KVAuthority.inspect | c.KVAuthority.read | c.KVAuthority.write);
    _ = try admin.change(.{ .bind_credential = .{ .principal = 1213, .role = local_life_role, .pid = local_child_spec.pid, .public_key = key_local_life.public_key.toBytes() } });

    const sub_worker_role = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("srv-sub-worker-role"), .login = true } })).?;
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = sub_child_spec.pid }, .grantee = sub_worker_role, .privileges = p.permission(.execute) | p.permission(.inspect) } });
    _ = try admin.change(.{ .membership = .{ .member = sub_worker_role, .role = role, .inherit = true } });
    _ = try admin.change(.{ .bind_credential = .{ .principal = 1215, .role = sub_worker_role, .pid = sub_child_spec.pid, .public_key = key_sub_worker_init.public_key.toBytes() } });

    // Substrate-bind and activate sub_child at generation 3.
    const op_intent1 = try admin.submit(.{ .runtime_intent = .{
        .pid = sub_child_spec.pid,
        .expected_revision = 0,
        .instance = @splat(11),
        .resource = @splat(12),
        .workload = @splat(13),
        .desired = .running,
    } });
    _ = try admin.submit(.{ .runtime_observe = .{
        .pid = sub_child_spec.pid,
        .revision = 1,
        .operation = op_intent1,
        .incarnation = @splat(14),
        .outcome = .ready,
    } });
    _ = try admin.submit(.{ .activate = .{
        .pid = sub_child_spec.pid,
        .revision = 1,
        .expected_generation = 2,
        .worker = 1215,
        .worker_incarnation = @splat(15),
        .public_key = key_sub_worker_act1.public_key.toBytes(),
    } });
    sub_child_spec.actor.connection.principal = 1215;
    sub_child_spec.activation = .{
        .realm = client.connection.scope.realm,
        .pid = sub_child_spec.pid,
        .principal = 1215,
        .generation = 3,
        .code = 1,
        .workload = @splat(13),
        .input = null,
    };
    var sub_worker_client = client;
    sub_worker_client.connection.principal = 1215;
    sub_worker_client.key = key_sub_worker_act1;

    var sup_runner = try Runner.init(init.gpa, client, sup_spec.actor, sup_spec.activation);
    defer sup_runner.deinit();
    try sup_runner.bootstrap();

    var caller_runner = try Runner.init(init.gpa, client, caller_spec.actor, caller_spec.activation);
    defer caller_runner.deinit();
    try caller_runner.bootstrap();

    var sub_child_runner = try Runner.init(init.gpa, sub_worker_client, sub_child_spec.actor, sub_child_spec.activation);
    defer sub_child_runner.deinit();
    try sub_child_runner.bootstrap();

    var local_child_runner = try Runner.init(init.gpa, local_worker_client, local_child_spec.actor, local_child_spec.activation);
    defer local_child_runner.deinit();
    try local_child_runner.bootstrap();

    var obs_conn = client.connection;
    obs_conn.principal = 1211;
    var sub_life_conn = client.connection;
    sub_life_conn.principal = 1212;
    var local_life_conn = client.connection;
    local_life_conn.principal = 1213;

    const sub_obs_watch: s.ServiceController.Watch = .{
        .connection = obs_conn,
        .timers = timers_queue,
        .supervisor_pid = sup_spec.pid,
        .supervisor_state = sup_spec.actor.state,
        .supervisor_inbox = svc_inbox,
        .child = .{ .pid = sub_child_spec.pid, .control = sub_child_spec.actor.control, .worker_principal = 1215 },
    };
    const sub_life_watch: s.ServiceController.Watch = .{
        .connection = sub_life_conn,
        .supervisor_pid = sup_spec.pid,
        .supervisor_state = sup_spec.actor.state,
        .child = .{ .pid = sub_child_spec.pid, .control = sub_child_spec.actor.control, .worker_principal = 1215 },
    };

    // 1. Readiness check() neither advances principal_sequence nor accepts foreign PIDs/rotated keys.
    var obs_ctrl = try s.ServiceController.init(init.gpa, client.authority, client.service, client.connection.scope.realm, 1211, key_obs, .observe, &.{sub_obs_watch}, 30000, 101);
    defer obs_ctrl.deinit();
    try obs_ctrl.check();
    try t.expectEqual(@as(u64, 0), (try client.authority.query(.{ .realm = 42, .principal = 1211, .kind = .identity }, key_obs)).principal_sequence);

    var sub_life_ctrl = try s.ServiceController.init(init.gpa, client.authority, client.service, client.connection.scope.realm, 1212, key_sub_life, .lifecycle, &.{sub_life_watch}, 30000, 102);
    defer sub_life_ctrl.deinit();
    try sub_life_ctrl.check();
    try t.expectEqual(@as(u64, 0), (try client.authority.query(.{ .realm = 42, .principal = 1212, .kind = .identity }, key_sub_life)).principal_sequence);

    var wrong_key_ctrl = try s.ServiceController.init(init.gpa, client.authority, client.service, client.connection.scope.realm, 1212, key_local_life, .lifecycle, &.{sub_life_watch}, 30000, 103);
    defer wrong_key_ctrl.deinit();
    try t.expectError(error.AccessDenied, wrong_key_ctrl.check());

    var cross_pid_watch = sub_life_watch;
    cross_pid_watch.child = .{ .pid = local_child_spec.pid, .control = local_child_spec.actor.control, .worker_principal = 1214 };
    var cross_pid_ctrl = try s.ServiceController.init(init.gpa, client.authority, client.service, client.connection.scope.realm, 1212, key_sub_life, .lifecycle, &.{cross_pid_watch}, 30000, 104);
    defer cross_pid_ctrl.deinit();
    try t.expectError(error.UnsafeControllerPrincipal, cross_pid_ctrl.check());

    // 2. Substrate stop-before-retry + post-intent crash recovery (`Point.after_own`).
    const SupSetupBody = struct {
        sub_pid: u64,
        local_pid: u64,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (std.mem.eql(u8, turn.input, "register-children")) {
                try s.Supervisor.register(turn, .{ .pid = self.sub_pid, .observer = 1211, .limit = 2, .backoff_ms = 0 });
                try s.Supervisor.register(turn, .{ .pid = self.local_pid, .observer = 1211, .limit = 1, .backoff_ms = 100 });
                return;
            }
            try s.Supervisor.handle(turn);
        }
    };
    var sup_body: SupSetupBody = .{ .sub_pid = sub_child_spec.pid, .local_pid = local_child_spec.pid };
    try enqueueEnvelope(&output, client, svc_inbox, 865001, sup_spec.pid, .{ .kind = .cast, .payload = "register-children" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&sup_runner, .{ .context = &sup_body, .run = SupSetupBody.handle }));

    const FailBody = struct {
        fail: bool = true,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (self.fail) return error.DeliberateChildFailure;
            try turn.put("handled", turn.input);
        }
    };
    var fail_body: FailBody = .{ .fail = true };
    try enqueueEnvelope(&output, client, svc_inbox, 865002, sub_child_spec.pid, .{ .kind = .cast, .payload = "sub-fail-then-succeed" });
    try t.expectEqual(Runner.Result.blocked, try advanceComplete(&sub_child_runner, .{ .context = &fail_body, .run = FailBody.handle }));
    try t.expect((try sub_child_runner.inspect()).blocked);

    // Observe failure -> Supervisor records retry_requested immediately (backoff_ms = 0).
    try t.expect(try obs_ctrl.step(null));
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&sup_runner, .{ .context = &sup_body, .run = SupSetupBody.handle }));

    // Lifecycle step 1: submits runtime_intent(.desired = .stopped), fencing old worker while Actor.Head stays blocked!
    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(17));
    try t.expect(try sub_life_ctrl.step(null));
    const after_stop_intent = (try client.authority.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = sub_child_spec.pid } }, root_key)).body.process.process;
    try t.expectEqual(.stopped, after_stop_intent.binding.?.desired);
    try t.expectEqual(.pending, after_stop_intent.binding.?.phase);
    try t.expectError(error.Rejected, sub_child_runner.inspect());
    try t.expect((try sub_life_ctrl.inspectBlockedFailure(sub_life_watch, sub_child_spec.pid)) != null);

    // Lifecycle step 2 before provider stopped confirmation: refuses to advance!
    try t.expect(!try sub_life_ctrl.step(null));
    try t.expect((try sub_life_ctrl.inspectBlockedFailure(sub_life_watch, sub_child_spec.pid)) != null);

    // Substrate provider confirms physical stop.
    _ = try admin.submit(.{ .runtime_observe = .{
        .pid = sub_child_spec.pid,
        .revision = after_stop_intent.binding.?.revision,
        .operation = after_stop_intent.binding.?.operation,
        .incarnation = @splat(14),
        .outcome = .stopped,
    } });

    // Crash after runtime_intent(.desired = .running) commits, before Actor.Head unblock.
    const CrashHook = struct {
        crashed: bool = false,
        fn hit(raw: *anyopaque, pt: s.ServiceController.Point) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (pt == .after_own and !self.crashed) {
                self.crashed = true;
                return error.SimulatedControllerCrash;
            }
        }
    };
    var crash_hook: CrashHook = .{};
    sub_life_ctrl.hook = .{ .context = &crash_hook, .hit = CrashHook.hit };
    try t.expectError(error.SimulatedControllerCrash, sub_life_ctrl.step(null));
    try t.expect(crash_hook.crashed);
    const after_crash = (try client.authority.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = sub_child_spec.pid } }, root_key)).body.process.process;
    try t.expectEqual(.running, after_crash.binding.?.desired);
    try t.expectEqual(@as(u64, 3), after_crash.binding.?.revision);
    try t.expect((try sub_life_ctrl.inspectBlockedFailure(sub_life_watch, sub_child_spec.pid)) != null);

    // Fresh restarted lifecycle controller finishes unblocking Actor.Head without another runtime_intent.
    var sub_life_ctrl2 = try s.ServiceController.init(init.gpa, client.authority, client.service, client.connection.scope.realm, 1212, key_sub_life, .lifecycle, &.{sub_life_watch}, 30000, 105);
    defer sub_life_ctrl2.deinit();
    try t.expect(try sub_life_ctrl2.step(null));
    const after_recover = (try client.authority.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = sub_child_spec.pid } }, root_key)).body.process.process;
    try t.expectEqual(@as(u64, 3), after_recover.binding.?.revision);
    try t.expect((try sub_life_ctrl2.inspectBlockedFailure(sub_life_watch, sub_child_spec.pid)) == null);

    // Substrate provider activates replacement worker incarnation; original held input commits!
    _ = try admin.submit(.{ .runtime_observe = .{
        .pid = sub_child_spec.pid,
        .revision = 3,
        .operation = after_recover.binding.?.operation,
        .incarnation = @splat(14),
        .outcome = .ready,
    } });
    _ = try admin.submit(.{ .activate = .{
        .pid = sub_child_spec.pid,
        .revision = 3,
        .expected_generation = after_recover.generation,
        .worker = 1215,
        .worker_incarnation = @splat(16),
        .public_key = key_sub_worker_act2.public_key.toBytes(),
    } });
    const activated_proc = (try client.authority.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = sub_child_spec.pid } }, root_key)).body.process.process;
    var sub_worker_client2 = sub_worker_client;
    sub_worker_client2.key = key_sub_worker_act2;
    var sub_activation2 = sub_child_spec.activation;
    sub_activation2.generation = activated_proc.generation;
    var sub_child_runner2 = try Runner.init(init.gpa, sub_worker_client2, sub_child_spec.actor, sub_activation2);
    defer sub_child_runner2.deinit();
    fail_body.fail = false;
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&sub_child_runner2, .{ .context = &fail_body, .run = FailBody.handle }));
    try t.expectEqualStrings("sub-fail-then-succeed", (try KV.apply(&output, client, .{ .get = .{ .object = sub_child_spec.actor.state.object, .key = "handled" } })).value.value.?.value.atom.bytes);

    // 3. Stage local_child failure + caller timer ticket for OS `transit __transit_role_v1 station` processes.
    fail_body.fail = true;
    try enqueueEnvelope(&output, client, svc_inbox, 865003, local_child_spec.pid, .{ .kind = .cast, .payload = "local-fail-then-succeed" });
    try t.expectEqual(Runner.Result.blocked, try advanceComplete(&local_child_runner, .{ .context = &fail_body, .run = FailBody.handle }));
    try t.expect((try local_child_runner.inspect()).blocked);

    const now_earliest_ms = (try Queue.apply(&output, client, .{ .current_time = timers_queue })).current_time.time.earliest_ms;
    const CallerTimerBody = struct {
        inbox: p.StreamQueue.Partition,
        target: u64,
        deadline_ms: u64,
        corr: u64 = 0,
        fn handle(raw: *anyopaque, turn: *s.Turn) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (turn.context.envelope.?.kind == .cast) {
                self.corr = try turn.callWithTimer(self.inbox, self.target, "unanswered-call", self.deadline_ms, 1211);
                try turn.put("timer", "waiting");
            } else if (turn.context.envelope.?.kind == .timeout) {
                try turn.put("timer", "timed_out");
            }
        }
    };
    // Target sub_child_spec.pid so the call stays unanswered while caller's timer fires.
    var caller_timer: CallerTimerBody = .{ .inbox = svc_inbox, .target = sub_child_spec.pid, .deadline_ms = now_earliest_ms + 100 };
    try enqueueEnvelope(&output, client, svc_inbox, 865004, caller_spec.pid, .{ .kind = .cast, .payload = "start-timer" });
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&caller_runner, .{ .context = &caller_timer, .run = CallerTimerBody.handle }));
    try t.expect(caller_timer.corr != 0);

    const local_obs_watch: s.ServiceController.Watch = .{
        .connection = obs_conn,
        .timers = timers_queue,
        .supervisor_pid = sup_spec.pid,
        .supervisor_state = sup_spec.actor.state,
        .supervisor_inbox = svc_inbox,
        .child = .{ .pid = local_child_spec.pid, .control = local_child_spec.actor.control, .worker_principal = 1214 },
    };
    const local_life_watch: s.ServiceController.Watch = .{
        .connection = local_life_conn,
        .supervisor_pid = sup_spec.pid,
        .supervisor_state = sup_spec.actor.state,
        .child = .{ .pid = local_child_spec.pid, .control = local_child_spec.actor.control, .worker_principal = 1214 },
    };
    const saved_path = try std.fmt.allocPrint(output.allocator(), "{s}.server-services", .{profile_path});
    try save(init, saved_path, ServerServicesSaved{
        .definition = p.Growth.current_definition,
        .obs_principal = 1211,
        .local_life_principal = 1213,
        .replacement_worker = 1214,
        .obs_watch = local_obs_watch,
        .local_life_watch = local_life_watch,
        .sup_actor = sup_spec.actor,
        .sup_activation = sup_spec.activation,
        .caller_actor = caller_spec.actor,
        .caller_activation = caller_spec.activation,
        .local_child_actor = local_child_spec.actor,
        .local_child_pid = local_child_spec.pid,
        .corr = caller_timer.corr,
    });
}

fn serverServicesPump(init: std.process.Init, client: c.DirectTableClient, profile_path: []const u8) !void {
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const saved_path = try std.fmt.allocPrint(output.allocator(), "{s}.server-services", .{profile_path});
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, saved_path, output.allocator(), .limited(1024 * 1024));
    const saved = (try p.Json.parseFromSlice(ServerServicesSaved, output.allocator(), bytes)).value;

    var sup_runner = try Runner.init(init.gpa, client, saved.sup_actor, saved.sup_activation);
    defer sup_runner.deinit();
    const SupPump = struct {
        fn handle(_: *anyopaque, turn: *s.Turn) !void {
            try s.Supervisor.handle(turn);
        }
    };
    var dummy: u8 = 0;
    const ck = s.Supervisor.key(saved.local_child_pid);
    for (0..80) |_| {
        _ = try advanceComplete(&sup_runner, .{ .context = &dummy, .run = SupPump.handle });
        const raw = (try KV.apply(&output, client, .{ .get = .{ .object = saved.sup_actor.state.object, .key = &ck } })).value.value.?.value.atom.bytes;
        const child = try s.Supervisor.Child.decode(raw);
        if (child.phase == .retry_requested) return;
        try init.io.sleep(.fromMilliseconds(50), .awake);
    }
    return error.SupervisorRetryNotRequested;
}

fn serverServicesCheckGated(init: std.process.Init, client: c.DirectTableClient, profile_path: []const u8) !void {
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(17));
    const saved_path = try std.fmt.allocPrint(output.allocator(), "{s}.server-services", .{profile_path});
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, saved_path, output.allocator(), .limited(1024 * 1024));
    const saved = (try p.Json.parseFromSlice(ServerServicesSaved, output.allocator(), bytes)).value;
    const proc = (try client.authority.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = saved.local_child_pid } }, root_key)).body.process.process;
    try t.expectEqual(@as(u64, 1), proc.generation);
    const key_repl = try p.Ed25519.KeyPair.generateDeterministic(@splat(134));
    var worker_client = client;
    worker_client.connection.principal = 1214;
    worker_client.key = key_repl;
    const dummy_act: p.Transaction.Execution = .{ .realm = 42, .pid = saved.local_child_pid, .principal = 1214, .generation = 1, .code = 1, .workload = null, .input = null };
    var child_runner = try Runner.init(init.gpa, worker_client, saved.local_child_actor, dummy_act);
    defer child_runner.deinit();
    try t.expect((try child_runner.inspect()).blocked);
}

fn serverServicesVerify(init: std.process.Init, client: c.DirectTableClient, admin: anytype, profile_path: []const u8) !void {
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const saved_path = try std.fmt.allocPrint(output.allocator(), "{s}.server-services", .{profile_path});
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, saved_path, output.allocator(), .limited(1024 * 1024));
    const saved = (try p.Json.parseFromSlice(ServerServicesSaved, output.allocator(), bytes)).value;

    // 1. Caller actor processes TMO1 delivered by the OS observer role.
    var caller_runner = try Runner.init(init.gpa, client, saved.caller_actor, saved.caller_activation);
    defer caller_runner.deinit();
    const CallerVerify = struct {
        fn handle(_: *anyopaque, turn: *s.Turn) !void {
            try t.expectEqual(s.Envelope.Kind.timeout, turn.context.envelope.?.kind);
            try turn.put("timer", "timed_out");
        }
    };
    var dummy: u8 = 0;
    var caller_done = false;
    for (0..100) |_| {
        if (try advanceComplete(&caller_runner, .{ .context = &dummy, .run = CallerVerify.handle }) == .committed) {
            caller_done = true;
            break;
        }
        try init.io.sleep(.fromMilliseconds(50), .awake);
    }
    try t.expect(caller_done);
    try t.expectEqualStrings("timed_out", (try KV.apply(&output, client, .{ .get = .{ .object = saved.caller_actor.state.object, .key = "timer" } })).value.value.?.value.atom.bytes);
    const wk = s.Wait.key(saved.corr);
    const wait_rec = try s.Wait.Record.decode(output.allocator(), (try KV.apply(&output, client, .{ .get = .{ .object = saved.caller_actor.state.object, .key = &wk } })).value.value.?.value.atom.bytes);
    try t.expectEqual(s.Wait.Phase.timed_out, wait_rec.phase);

    // 2. Wait for OS lifecycle role to finish own + unblockChildHead, then run replacement worker (1214, gen 2).
    const key_repl = try p.Ed25519.KeyPair.generateDeterministic(@splat(134));
    var repl_client = client;
    repl_client.connection.principal = 1214;
    repl_client.key = key_repl;
    const repl_activation: p.Transaction.Execution = .{
        .realm = client.connection.scope.realm,
        .pid = saved.local_child_pid,
        .principal = 1214,
        .generation = 2,
        .code = 1,
        .workload = null,
        .input = null,
    };
    var repl_runner = try Runner.init(init.gpa, repl_client, saved.local_child_actor, repl_activation);
    defer repl_runner.deinit();

    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(17));
    var unblocked = false;
    for (0..100) |_| {
        const proc = (try client.authority.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = saved.local_child_pid } }, root_key)).body.process.process;
        if (proc.owner == @as(?u64, 1214) and proc.generation == 2 and !(try repl_runner.inspect()).blocked) {
            unblocked = true;
            break;
        }
        try init.io.sleep(.fromMilliseconds(50), .awake);
    }
    try t.expect(unblocked);

    const SucceedBody = struct {
        fn handle(_: *anyopaque, turn: *s.Turn) !void {
            try turn.put("handled", turn.input);
        }
    };
    try t.expectEqual(Runner.Result.committed, try advanceComplete(&repl_runner, .{ .context = &dummy, .run = SucceedBody.handle }));
    try t.expectEqualStrings("local-fail-then-succeed", (try KV.apply(&output, client, .{ .get = .{ .object = saved.local_child_actor.state.object, .key = "handled" } })).value.value.?.value.atom.bytes);

    // 3. Rotate lifecycle principal 1213's credential key while OS lifecycle process is running idle!
    const key_local_life = try p.Ed25519.KeyPair.generateDeterministic(@splat(133));
    const rotated_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(138));
    const auth_id = (try client.authority.query(.{ .realm = 42, .principal = 1213, .kind = .{ .authorization = .{ .kind = .identity } } }, key_local_life)).body.authorization.body.identity;
    _ = try admin.change(.{ .rotate_credential = .{ .principal = 1213, .expected_epoch = auth_id.credential_epoch, .public_key = rotated_key.public_key.toBytes() } });
}

fn caseMissingBegin(case: Case) bool {
    return case == .head;
}
pub fn run(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, profile: []const u8, command: []const u8) !void {
    if (std.mem.eql(u8, command, "calls")) return exerciseCalls(init, client, admin, role);
    if (std.mem.eql(u8, command, "timers_pool")) return exerciseTimersAndPool(init, client, admin, role);
    if (std.mem.eql(u8, command, "services")) return exerciseServices(init, client, admin, role);
    if (std.mem.eql(u8, command, "server_services_setup")) return serverServicesSetup(init, client, admin, role, profile);
    if (std.mem.eql(u8, command, "server_services_pump")) return serverServicesPump(init, client, profile);
    if (std.mem.eql(u8, command, "server_services_check_gated")) return serverServicesCheckGated(init, client, profile);
    if (std.mem.eql(u8, command, "server_services_verify")) return serverServicesVerify(init, client, admin, profile);
    var parts = std.mem.splitScalar(u8, command, '-');
    const phase = parts.next() orelse return error.InvalidPhase;
    const case = std.meta.stringToEnum(Case, parts.next() orelse return error.InvalidCase) orelse return error.InvalidCase;
    if (parts.next() != null) return error.InvalidPhase;
    const path = try std.fmt.allocPrint(init.arena.allocator(), "{s}.station-{s}", .{ profile, @tagName(case) });
    if (std.mem.eql(u8, phase, "setup")) return setup(init, client, admin, role, path, case);
    var saved = try load(init, path);
    if (std.mem.eql(u8, phase, "verify")) {
        for (0..@as(usize, if (case == .measured) 23 else 1)) |index| try verify(init, client, saved, index);
        return;
    }
    if (std.mem.eql(u8, phase, "measure")) return measure(init, client, saved);
    var selected = client;
    if (std.mem.eql(u8, phase, "execute") and case == .stale)
        _ = try admin.change(.{ .bind_credential = .{ .principal = replacement(case), .role = role, .public_key = (try replacementKey(case)).public_key.toBytes() } });
    if (std.mem.eql(u8, phase, "recover")) {
        if (case != .stale) _ = try admin.change(.{ .bind_credential = .{ .principal = replacement(case), .role = role, .public_key = (try replacementKey(case)).public_key.toBytes() } });
        _ = try admin.submit(.{ .own = .{ .pid = saved.actor.pid, .expected_generation = if (case == .stale) 2 else 1, .worker = replacement(case) } });
        selected.connection.principal = replacement(case);
        selected.key = try replacementKey(case);
        saved.activation.principal = replacement(case);
        saved.activation.generation = if (case == .stale) 3 else 2;
    }
    var runner = try Runner.init(init.gpa, selected, saved.actor, saved.activation);
    defer runner.deinit();
    var body: Body = .{ .case = case, .table = saved.actor.table_name.slice() };
    var interrupt: Interrupt = .{ .init = init, .path = try std.fmt.allocPrint(init.arena.allocator(), "{s}.ready", .{path}), .at = std.meta.stringToEnum(Runner.Point, @tagName(case)) orelse .original };
    if (std.mem.eql(u8, phase, "execute") and interrupt.at != .original) runner.hook = .{ .context = &interrupt, .hit = Interrupt.hit };
    const Takeover = struct {
        authority: @TypeOf(admin),
        pid: u64,
        changed: bool = false,
        worker: u64,
        fn hit(raw: *anyopaque, point: Runner.Point) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (point != .draft) return;
            _ = try self.authority.submit(.{ .own = .{ .pid = self.pid, .expected_generation = 1, .worker = self.worker } });
            self.changed = true;
        }
    };
    var takeover: Takeover = .{ .authority = admin, .pid = saved.actor.pid, .worker = replacement(case) };
    if (std.mem.eql(u8, phase, "execute") and case == .stale) runner.hook = .{ .context = &takeover, .hit = Takeover.hit };

    if (std.mem.eql(u8, phase, "recover")) {
        const before = try runner.inspect();
        if (before.pending) |pending| try save(init, try std.fmt.allocPrint(init.arena.allocator(), "{s}.original", .{path}), pending);
        for (0..16) |_| {
            if ((try runner.inspect()).pending == null) break;
            _ = try runner.advance(.{ .context = &body, .run = Body.run });
        }
        const final = try runner.inspect();
        try t.expect(final.pending == null);
        try t.expectEqual(@as(u64, if (case == .measured) 23 else @intFromBool(committed(case))), final.completed);
        try t.expectEqual(@as(usize, 0), body.calls);
    } else {
        if (case == .stale) {
            try t.expectError(error.Rejected, runner.advance(.{ .context = &body, .run = Body.run }));
            try t.expect(takeover.changed);
        } else if (case == .stop) try t.expectError(error.HandlerStopped, runner.advance(.{ .context = &body, .run = Body.run, .failure = .stop })) else {
            var result = try runner.advance(.{ .context = &body, .run = Body.run });
            for (0..16) |_| {
                if (result != .recovering) break;
                result = try runner.advance(.{ .context = &body, .run = Body.run });
            }
            try t.expectEqual(if (committed(case)) Runner.Result.committed else Runner.Result.blocked, result);
            if (case == .large) {
                var verify_output: std.heap.ArenaAllocator = .init(init.gpa);
                defer verify_output.deinit();
                const digest = try saved.actor.digest(init.gpa);
                const claim: p.StreamQueue.Claim = .{ .target = saved.actor.inbox, .operation = Actor.operation(saved.actor.connection, digest, 1, "claim", 0), .maximum = 1, .lease_ms = saved.actor.lease_ms, .predicate = saved.actor.predicate };
                const found = (try Queue.apply(&verify_output, selected, .{ .operation = .{ .claim = claim } })).operation.?.claim;
                const first_release = try runner.releaseClaimRead(1, found);
                try t.expectEqualDeep(first_release, try runner.releaseClaimRead(1, found));
            }
        }
        try t.expectEqual(@as(usize, 1), body.calls);
    }
}
