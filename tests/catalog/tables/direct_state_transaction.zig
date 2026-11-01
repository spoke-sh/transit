//! Installed state/log composition through the shared signed transaction owner.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const KV = c.DirectKVClient;
const Tx = c.DirectTransactionClient;
const Stream = c.DirectStreamClient;
const Queue = c.DirectQueueClient;
const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = false };
const payload: [1024]u8 = @splat(0x75);
const log_columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "entity", .type = .int64, .nullable = false }};
const Logs = struct {
    stream: p.StreamQueue.Partition,
    queue: p.StreamQueue.Partition,
    claim: p.StreamQueue.ClaimReceipt,
    statements: [4]c.DirectTransactionLogWork.Request,
};
const LogInput = struct {
    stream: p.StreamQueue.Partition,
    queue: p.StreamQueue.Partition,
    claim: p.StreamQueue.ClaimReceipt,
    offset: c.DirectTransactionLogWork.Work,
    ack: c.DirectTransactionLogWork.Work,
};
const Saved = struct {
    definition: p.Growth.Definition,
    key: c.DirectClientToken.Key,
    object: d.Object,
    table_statement: c.DirectTransactionWorkspace.Request,
    kv_statement: c.DirectTransactionWorkspace.Request,
    commit: d.Operation,
    logs: ?Logs,
};
fn load(init: std.process.Init, path: []const u8) !Saved {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(64 * 1024));
    const parsed = try p.Json.parseFromSlice(Saved, init.gpa, bytes);
    defer parsed.deinit();
    try parsed.value.key.validate();
    try parsed.value.table_statement.validate();
    try parsed.value.kv_statement.validate();
    if (parsed.value.logs) |logs| for (logs.statements) |request| try request.validate();
    if (parsed.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    return parsed.value;
}
fn operation(client: c.DirectTableClient, id: u64) d.Operation {
    return .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = id };
}
fn logSchema(object: u64) c.fuze.TableSchema.Schema {
    return .{ .object = object, .revision = 1, .next_column = 2, .columns = &log_columns, .primary_key = &.{} };
}
fn createLog(init: std.process.Init, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, role: u64, kind: c.DirectLog.Kind) !p.StreamQueue.Partition {
    const object: u64 = if (kind == .stream) 642020 else 642030;
    const intent: c.DirectLog.Intent = .{ .kind = kind, .namespace = 1, .name = try .init(if (kind == .stream) "atomic_events" else "atomic_inbox"), .action = .{ .create = .{
        .owner = role,
        .schema = logSchema(object),
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = if (kind == .stream) .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } else .{ .queue = .{ .ordering = .key_fifo, .key_column = 1, .lease_ms = 300000, .maximum_lease_ms = 300000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = operation(client, if (kind == .stream) 642003 else 642004), .target = .{ .scope = client.connection.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(init.gpa) } };
    _ = try c.DirectLogClient.apply(output, client, .{ .admit = request });
    const completed = (try c.DirectLogClient.apply(output, client, .{ .operation = .{ .binding = request.binding, .command = .execute, .steps = 16 } })).operation.operation;
    try t.expectEqual(.complete, completed.phase);
    return .{ .definition = p.Growth.current_definition, .interpretation = completed.resulting.?.stored.declaration.interpretation, .partition = 0 };
}
fn appendPayload(target: p.StreamQueue.Partition, identity: d.Operation, kind: p.StreamQueueDeclaration.Kind, buffer: []u8) ![]const u8 {
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    return c.storage.LogBatch.encode(logSchema(target.interpretation.object.object), identity, kind, &.{.{ .cells = &cells }}, buffer);
}
fn prepareInputs(init: std.process.Init, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, role: u64) !LogInput {
    const stream = try createLog(init, client, output, role, .stream);
    const queue = try createLog(init, client, output, role, .queue);
    var buffer: [8192]u8 = undefined;
    const stream_bytes = try appendPayload(stream, operation(client, 642005), .stream, &buffer);
    _ = try Stream.apply(output, client, .{ .mutate = .{ .work = .{ .append = .{ .target = stream, .operation = operation(client, 642005), .kind = .stream, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(stream_bytes) } }, .payload = stream_bytes } });
    const queue_bytes = try appendPayload(queue, operation(client, 642006), .queue, &buffer);
    _ = try Queue.apply(output, client, .{ .mutate = .{ .work = .{ .enqueue = .{ .target = queue, .operation = operation(client, 642006), .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(queue_bytes) } }, .payload = queue_bytes } });
    const group: p.StreamQueue.Group = .{ .id = 7, .generation = 1, .principal = client.connection.principal };
    const cut = (try Stream.apply(output, client, .{ .observe = stream })).cut;
    _ = try Stream.apply(output, client, .{ .mutate = .{ .work = .{ .assign = .{ .operation = operation(client, 642007), .cut = cut, .expected = null, .group = group, .next = 0 } } } });
    const consumed = (try Stream.apply(output, client, .{ .mutate = .{ .work = .{ .consume = .{ .target = stream, .operation = operation(client, 642008), .group = group, .from = 0, .until = null, .timestamp = null } } } })).operation.?.consume;
    const cursor = (try Stream.apply(output, client, .{ .cursor = .{ .target = stream, .read = consumed.handle() } })).cursor;
    const page = (try Stream.apply(output, client, .{ .page = .{ .cursor = cursor, .limits = .{ .rows = 1, .encoded_bytes = 8192, .scanned_rows = 1 } } })).page;
    try t.expect(page.cursor.coverage.complete);
    const claim = (try Queue.apply(output, client, .{ .mutate = .{ .work = .{ .claim = .{ .target = queue, .operation = operation(client, 642009), .maximum = 1, .lease_ms = 300000 } } } })).operation.?.claim;
    const claimed = (try Queue.apply(output, client, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(usize, 1), claimed.rows.len);
    return .{ .stream = stream, .queue = queue, .claim = claim, .offset = .{ .stream_offset = .{ .commit = .{ .operation = operation(client, 642013), .group = group, .coverage = page.cursor.coverage, .expected_next = 0, .next = 1 }, .cursor = page.cursor } }, .ack = .{ .queue_ack = .{ .operation = operation(client, 642014), .lease = claimed.rows[0].lease.original, .action = .ack } } };
}
fn privateLogs(client: c.DirectTableClient, output: *std.heap.ArenaAllocator, key: c.DirectClientToken.Key, input: LogInput) !Logs {
    const tx: Tx = .{ .catalog = client };
    var logs: Logs = .{ .stream = input.stream, .queue = input.queue, .claim = input.claim, .statements = undefined };
    for ([_]c.DirectTransactionLogWork.Work{ input.offset, input.ack }, 0..) |work, i| {
        logs.statements[i] = try tx.stageLog(key, (try tx.inspect(key)).revision, 3 + i, work, null);
        try t.expect((try tx.executeLog(key, logs.statements[i])) == .provisional);
    }
    var buffer: [8192]u8 = undefined;
    for ([_]p.StreamQueue.Partition{ input.stream, input.queue }, 0..) |target, i| {
        const kind: p.StreamQueueDeclaration.Kind = if (i == 0) .stream else .queue;
        const identity = operation(client, 642015 + i);
        const bytes = try appendPayload(target, identity, kind, &buffer);
        const work: c.DirectTransactionLogWork.Work = .{ .append = .{ .target = target, .operation = identity, .kind = if (i == 0) .stream else .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(bytes) } };
        logs.statements[i + 2] = try tx.stageLog(key, (try tx.inspect(key)).revision, 5 + i, work, try c.DirectTableProtocol.Binary.encode(output.allocator(), bytes));
        if (i == 0) try t.expect((try tx.executeLog(key, logs.statements[i + 2])) == .provisional);
    }
    return logs;
}
fn visibleLogs(client: c.DirectTableClient, output: *std.heap.ArenaAllocator, logs: Logs, committed: bool) !void {
    const count: u64 = if (committed) 2 else 1;
    try t.expectEqual(count, (try Stream.apply(output, client, .{ .observe = logs.stream })).cut.next);
    try t.expectEqual(count, (try Queue.apply(output, client, .{ .observe = logs.queue })).cut.next);
    try t.expectEqual(@as(u64, @intFromBool(committed)), (try Stream.apply(output, client, .{ .group = .{ .target = logs.stream, .id = 7 } })).group.?.next);
    const claimed = (try Queue.apply(output, client, .{ .page = .{ .cursor = .{ .receipt = logs.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(p.QueueRead.State, if (committed) .acked else .acquired), claimed.rows[0].lease.state);
    const appended = (try Stream.apply(output, client, .{ .operation = .{ .append = logs.statements[2].work.append } })).operation;
    try t.expectEqual(committed, appended != null);
    if (appended) |receipt| {
        try t.expectEqual(@as(u64, 1), receipt.append.first);
        try t.expectEqual(@as(u64, 2), receipt.append.next);
    }
    const acked = (try Queue.apply(output, client, .{ .operation = .{ .settle = logs.statements[1].work.queue_ack } })).operation;
    try t.expectEqual(committed, acked != null);
    if (acked) |receipt| try t.expectEqualDeep(logs.statements[1].work.queue_ack, receipt.settle.settlement);
    const enqueued = (try Queue.apply(output, client, .{ .operation = .{ .enqueue = logs.statements[3].work.append } })).operation;
    try t.expectEqual(committed, enqueued != null);
    if (enqueued) |receipt| {
        try t.expectEqual(@as(u64, 1), receipt.enqueue.first);
        try t.expectEqual(@as(u64, 2), receipt.enqueue.next);
    }
    if (committed) {
        const consumed = (try Stream.apply(output, client, .{ .mutate = .{ .work = .{ .consume = .{ .target = logs.stream, .operation = operation(client, 642017), .group = null, .from = 1, .until = 2, .timestamp = null } } } })).operation.?.consume;
        const cursor = (try Stream.apply(output, client, .{ .cursor = .{ .target = logs.stream, .read = consumed.handle() } })).cursor;
        const page = (try Stream.apply(output, client, .{ .page = .{ .cursor = cursor, .limits = .{ .rows = 1, .encoded_bytes = 8192, .scanned_rows = 1 } } })).page;
        try t.expect(page.cursor.coverage.complete);
        try t.expectEqual(@as(usize, 1), page.rows.len);
        try t.expectEqual(@as(u64, 1), page.rows[0].offset);
        try t.expectEqual(@as(i64, 42), page.rows[0].value.cells[0].value.atom.signed);
        const next_claim = (try Queue.apply(output, client, .{ .mutate = .{ .work = .{ .claim = .{ .target = logs.queue, .operation = operation(client, 642018), .maximum = 1, .lease_ms = 300000 } } } })).operation.?.claim;
        const next_page = (try Queue.apply(output, client, .{ .page = .{ .cursor = .{ .receipt = next_claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
        try t.expectEqual(@as(usize, 1), next_page.rows.len);
        try t.expectEqual(@as(u64, 1), next_page.rows[0].lease.original.offset);
        try t.expectEqual(@as(i64, 42), next_page.rows[0].value.cells[0].value.atom.signed);
    }
}
fn visible(client: c.DirectTableClient, output: *std.heap.ArenaAllocator, object: d.Object, expected: bool) !void {
    const value = (try KV.apply(output, client, .{ .get = .{ .object = object, .key = "six" } })).value;
    try t.expectEqual(expected, value.value != null);
    try t.expect(value.workspace == null);
    if (value.value) |cell| try t.expectEqualSlices(u8, &payload, cell.value.atom.bytes);
    const table = try client.call(.{ .lookup = .{ .namespace = 1, .name = "atomic_rows" } });
    defer table.deinit();
    try t.expectEqual(@as(u64, @intFromBool(expected)), table.value.result.lookup.?.row_count);
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8, with_logs: bool) !void {
    (try client.call(.initialize)).deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    var ddl = try c.DirectTablePreparedDdl.prepare(init.gpa, client, 1, "CREATE TABLE atomic_rows (id BIGINT PRIMARY KEY)", .transit, null);
    defer ddl.deinit();
    var table = try ddl.bind(init.gpa, client, 642001, 642010);
    defer table.deinit();
    (try table.table.admit(client)).deinit();
    const created = try table.table.operation(client, .execute, 64);
    defer created.deinit();
    try t.expect(created.value.result.ddl == .committed);
    const declaration = try KV.prepareDeclaration(init.gpa, .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = operation(client, 642002), .target = .{ .scope = client.connection.scope, .branch = 1, .object = 642000 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = undefined },
        .namespace = 1,
        .name = try .init("atomic_state"),
        .action = .{ .create = .{ .owner = role, .spec = spec } },
    });
    _ = try KV.apply(&output, client, .{ .declaration = .{ .declaration = declaration, .command = .admit, .steps = 1 } });
    const kv_created = try KV.apply(&output, client, .{ .declaration = .{ .declaration = declaration, .command = .execute, .steps = 64 } });
    try t.expect(kv_created.declaration.operation == .committed);
    const metadata = (try KV.apply(&output, client, .{ .observe = declaration.binding.target })).definition;
    const input = if (with_logs) try prepareInputs(init, client, &output, role) else null;
    const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(9), .token = @splat(6) };
    const tx: Tx = .{ .catalog = client };
    var targets = [_]p.Transaction.Target{
        .{ .object = declaration.binding.target, .kind = .kv, .partition = null },
        .{ .object = created.value.result.ddl.committed.binding.target, .kind = .table, .partition = null },
        undefined,
        undefined,
    };
    if (input) |logs| {
        targets[2] = .{ .object = logs.stream.interpretation.object, .kind = .stream, .partition = 0 };
        targets[3] = .{ .object = logs.queue.interpretation.object, .kind = .queue, .partition = 0 };
    }
    _ = try tx.begin(.{ .key = key, .fingerprint = @splat(7), .operation = operation(client, 642100), .namespace = 1, .mode = .serializable, .selection = .{ .explicit_objects = targets[0..@as(usize, if (with_logs) 4 else 2)] }, .limits = c.DirectTransaction.default_limits, .budget = .{} });
    _ = try tx.acquire(key);
    var insert = try c.DirectTablePreparedDml.prepare(init.gpa, client, 1, "INSERT INTO atomic_rows (id) VALUES ($1)", .transit, null);
    defer insert.deinit();
    var work = try insert.bind(init.gpa, client, 642011, &.{.{ .signed = 42 }}, .bulk, null);
    defer work.deinit();
    const table_statement = try tx.stage(key, (try tx.inspect(key)).revision, 1, work.parsed.value.work);
    try t.expectEqual(@as(u64, 1), (try tx.execute(key, table_statement)).provisional.affected);
    var binding = declaration.binding;
    binding.identity = operation(client, 642012);
    binding.action = .insert;
    binding.expected_definition = metadata.interpretation.interpretation;
    const keys = [_][]const u8{ "one", "two", "three", "four", "five", "six" };
    var changes: [6]c.storage.KVPartition.Change = undefined;
    for (&changes, keys) |*change, name| change.* = .{ .put = .{ .key = name, .value = .{ .value = .{ .atom = .{ .bytes = &payload } } }, .expect = .absent } };
    const mutation = try KV.prepareMutation(&output, binding, spec, &changes);
    const kv_statement = try tx.stageKV(key, (try tx.inspect(key)).revision, 2, mutation);
    var saved: Saved = .{ .definition = p.Growth.current_definition, .key = key, .object = declaration.binding.target, .table_statement = table_statement, .kv_statement = kv_statement, .commit = operation(client, 642101), .logs = null };
    if (input) |logs| {
        try t.expectEqual(@as(u64, 6), (try tx.execute(key, kv_statement)).provisional.affected);
        saved.logs = try privateLogs(client, &output, key, logs);
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), saved, 64 * 1024) });
    if (saved.logs) |logs| {
        try t.expectError(error.InvalidTableResponse, tx.executeLog(key, logs.statements[3]));
    } else try t.expectError(error.InvalidTableResponse, tx.execute(key, kv_statement));
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    const tx: Tx = .{ .catalog = client };
    const original = (try tx.statementOutcome(saved.key, saved.kv_statement)).?;
    try t.expectEqual(@as(u64, 6), original.provisional.affected);
    try t.expectEqualDeep(original, try tx.execute(saved.key, saved.kv_statement));
    try t.expectEqual(@as(u64, 1), (try tx.statementOutcome(saved.key, saved.table_statement)).?.provisional.affected);
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    try visible(client, &output, saved.object, false);
    if (saved.logs) |logs| {
        for (logs.statements) |request| {
            const outcome = (try tx.logOutcome(saved.key, request)).?;
            try t.expect(outcome == .provisional);
            try t.expectEqualDeep(outcome, try tx.executeLog(saved.key, request));
        }
        try visibleLogs(client, &output, logs, false);
    }
    var private = client;
    private.transaction = .{ .key = saved.key, .revision = (try tx.inspect(saved.key)).revision };
    const value = (try KV.apply(&output, private, .{ .get = .{ .object = saved.object, .key = "six" } })).value;
    try t.expect(value.workspace != null);
    try t.expectEqualSlices(u8, &payload, value.value.?.value.atom.bytes);
    try t.expectError(error.InvalidTableResponse, tx.settle(saved.key, saved.commit, .commit, 8));
}
pub fn verify(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    const tx: Tx = .{ .catalog = client };
    const known = try tx.inspect(saved.key);
    try t.expect(known.observation == .decided and known.observation.decided.outcome == .committed);
    const result = try tx.settle(saved.key, saved.commit, .commit, 8);
    try t.expectEqualDeep(known.observation, result.observation);
    try t.expect(result.cleanup_complete);
    try t.expectEqual(@as(u64, 6), (try tx.statementOutcome(saved.key, saved.kv_statement)).?.provisional.affected);
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    try visible(client, &output, saved.object, true);
    if (saved.logs) |logs| try visibleLogs(client, &output, logs, true);
}
