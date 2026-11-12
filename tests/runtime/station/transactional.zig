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
        const page = (try Queue.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = found.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
        try t.expectEqual(@as(usize, 1), page.rows.len);
        try t.expectEqualDeep(enqueue, page.rows[0].operation);
        try t.expectEqual(@as(p.QueueRead.State, if (expected) .acked else .acquired), page.rows[0].lease.state);
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
fn caseMissingBegin(case: Case) bool {
    return case == .head;
}
pub fn run(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, profile: []const u8, command: []const u8) !void {
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
        }
        try t.expectEqual(@as(usize, 1), body.calls);
    }
}
