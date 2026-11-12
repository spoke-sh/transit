//! Installed state/log composition through the shared signed transaction owner.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const data = @import("transit_data_client");
const Transaction = data.Transaction;
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
    recovery: data.LocalRecoveryStore.Key,
    object: d.Object,
    table_statement: c.DirectTransactionWorkspace.Request,
    kv_statement: c.DirectTransactionWorkspace.Request,
    commit: d.Operation,
    logs: ?Logs,
};
const Caller = struct {
    context: *data.Context,
    handle: data.Context.Handle,
    fn deinit(self: *Caller) void {
        const allocator = self.context.allocator;
        self.context.close(.none) catch unreachable;
        self.context.deinit() catch unreachable;
        allocator.destroy(self.context);
    }
    fn call(self: *Caller, transaction: *Transaction, action: Transaction.Action) !Transaction.Result {
        const outcome = try self.context.callTransaction(self.handle, transaction, action);
        return switch (outcome.value) {
            .result => |value| value,
            .failure => |failure| failure.cause,
        };
    }
    fn unknown(self: *Caller, transaction: *Transaction, action: Transaction.Action) !void {
        const outcome = try self.context.callTransaction(self.handle, transaction, action);
        try t.expect(outcome.value == .failure);
        try t.expectEqual(error.InvalidTableResponse, outcome.value.failure.cause);
        try t.expect(outcome.mutationAttempted());
        try t.expectEqual(.transaction, outcome.attempt.mutation.?.action);
        try t.expectEqual(.unknown, outcome.value.failure.diagnostic.?.outcome);
    }
};
fn callerFor(init: std.process.Init, client: c.DirectTableClient) !Caller {
    const context = try init.gpa.create(data.Context);
    errdefer init.gpa.destroy(context);
    context.* = try data.Context.init(init.gpa, init.io, .{ .catalogs = 2, .active = .{ .data = 1, .control = 1 } });
    errdefer {
        context.close(.none) catch unreachable;
        context.deinit() catch unreachable;
    }
    const handle = try context.openCatalog(.{ .url = client.authority.url, .service_url = client.service.url, .connection = client.connection, .timeout_ms = 30000 }, client.key.secret_key.seed());
    return .{ .context = context, .handle = handle };
}
fn recoveryStore(init: std.process.Init, path: []const u8) !data.LocalRecoveryStore {
    const parent = try std.Io.Dir.cwd().openDir(init.io, std.fs.path.dirname(path) orelse ".", .{});
    defer parent.close(init.io);
    const name = try std.fmt.allocPrint(init.arena.allocator(), "{s}.recovery", .{std.fs.path.basename(path)});
    return data.LocalRecoveryStore.open(init.gpa, init.io, parent, name, .{});
}
const CheckpointFault = struct {
    journal: Transaction.Journal,
    failed: bool = false,
    fn save(raw: *anyopaque, previous: Transaction.State, state: Transaction.State, event: Transaction.Event) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.failed and event == .statement_complete) {
            self.failed = true;
            return error.InjectedCheckpointFailure;
        }
        try self.journal.save(self.journal.context, previous, state, event);
    }
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
    const input_cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    const stream_bytes = try c.storage.LogBatch.encode(logSchema(stream.interpretation.object.object), operation(client, 642005), .stream, &.{ .{ .cells = &input_cells }, .{ .cells = &input_cells } }, &buffer);
    _ = try Stream.apply(output, client, .{ .mutate = .{ .work = .{ .append = .{ .target = stream, .operation = operation(client, 642005), .kind = .stream, .producer = null, .rows = 2, .payload = c.storage.LogBatch.content(stream_bytes) } }, .payload = stream_bytes } });
    const queue_bytes = try appendPayload(queue, operation(client, 642006), .queue, &buffer);
    _ = try Queue.apply(output, client, .{ .mutate = .{ .work = .{ .enqueue = .{ .target = queue, .operation = operation(client, 642006), .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(queue_bytes) } }, .payload = queue_bytes } });
    const group: p.StreamQueue.Group = .{ .id = 7, .generation = 1, .principal = client.connection.principal };
    const cut = (try Stream.apply(output, client, .{ .observe = stream })).cut;
    _ = try Stream.apply(output, client, .{ .mutate = .{ .work = .{ .assign = .{ .operation = operation(client, 642007), .cut = cut, .expected = null, .group = group, .next = 0 } } } });
    const consumed = (try Stream.apply(output, client, .{ .mutate = .{ .work = .{ .consume = .{ .target = stream, .operation = operation(client, 642008), .group = group, .from = 0, .until = null, .timestamp = null } } } })).operation.?.consume;
    const cursor = (try Stream.apply(output, client, .{ .cursor = .{ .target = stream, .read = consumed.handle() } })).cursor;
    const page = (try Stream.apply(output, client, .{ .page = .{ .cursor = cursor, .limits = .{ .rows = 1, .encoded_bytes = 8192, .scanned_rows = 1 } } })).page;
    try t.expect(!page.cursor.coverage.complete);
    try t.expectEqual(@as(u64, 2), page.cursor.coverage.until);
    const progress = try p.StreamRead.Progress.between(cursor, page.cursor);
    try t.expect(progress == .interval);
    const claim = (try Queue.apply(output, client, .{ .mutate = .{ .work = .{ .claim = .{ .target = queue, .operation = operation(client, 642009), .maximum = 1, .lease_ms = 300000, .predicate = null } } } })).operation.?.claim;
    const claimed = (try Queue.apply(output, client, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(usize, 1), claimed.rows.len);
    return .{ .stream = stream, .queue = queue, .claim = claim, .offset = .{ .stream_offset = .{ .commit = .{ .operation = operation(client, 642013), .group = group, .coverage = try progress.coverage(), .expected_next = 0, .next = 1 }, .progress = progress } }, .ack = .{ .queue_ack = .{ .operation = operation(client, 642014), .lease = claimed.rows[0].lease.original, .action = .ack } } };
}
fn privateLogs(client: c.DirectTableClient, caller: *Caller, transaction: *Transaction, output: *std.heap.ArenaAllocator, input: LogInput) !Logs {
    var logs: Logs = .{ .stream = input.stream, .queue = input.queue, .claim = input.claim, .statements = undefined };
    for ([_]c.DirectTransactionLogWork.Work{ input.offset, input.ack }, 0..) |work, i| {
        const completion = (try caller.call(transaction, .{ .write = .{ .log = .{ .work = work } } })).statement.log;
        logs.statements[i] = completion.request;
        try t.expect(completion.outcome == .provisional);
    }
    var buffer: [8192]u8 = undefined;
    for ([_]p.StreamQueue.Partition{ input.stream, input.queue }, 0..) |target, i| {
        const kind: p.StreamQueueDeclaration.Kind = if (i == 0) .stream else .queue;
        const identity = operation(client, 642015 + i);
        const bytes = try appendPayload(target, identity, kind, &buffer);
        const work: c.DirectTransactionLogWork.Work = .{ .append = .{ .target = target, .operation = identity, .kind = if (i == 0) .stream else .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(bytes) } };
        const action: Transaction.Action = .{ .write = .{ .log = .{ .work = work, .payload = try c.DirectTableProtocol.Binary.encode(output.allocator(), bytes) } } };
        if (i == 0) {
            const completion = (try caller.call(transaction, action)).statement.log;
            logs.statements[i + 2] = completion.request;
            try t.expect(completion.outcome == .provisional);
        } else {
            try caller.unknown(transaction, action);
            logs.statements[i + 2] = transaction.state.statement.?.log;
        }
    }
    return logs;
}
fn visibleLogs(client: c.DirectTableClient, output: *std.heap.ArenaAllocator, logs: Logs, committed: bool) !?p.StreamQueue.Lease {
    const count: u64 = if (committed) 2 else 1;
    try t.expectEqual(count + 1, (try Stream.apply(output, client, .{ .observe = logs.stream })).cut.next);
    try t.expectEqual(count, (try Queue.apply(output, client, .{ .observe = logs.queue })).cut.next);
    try t.expectEqual(@as(u64, @intFromBool(committed)), (try Stream.apply(output, client, .{ .group = .{ .target = logs.stream, .id = 7 } })).group.?.next);
    const claimed = (try Queue.apply(output, client, .{ .page = .{ .cursor = .{ .receipt = logs.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(p.QueueRead.State, if (committed) .acked else .acquired), claimed.rows[0].lease.state);
    const appended = (try Stream.apply(output, client, .{ .operation = .{ .append = logs.statements[2].work.append } })).operation;
    try t.expectEqual(committed, appended != null);
    if (appended) |receipt| {
        try t.expectEqual(@as(u64, 2), receipt.append.first);
        try t.expectEqual(@as(u64, 3), receipt.append.next);
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
        // Settlement advances only the first input interval. The original read
        // still exposes its remaining input after replacement and excludes this
        // transaction's later append, whose offset is checked separately.
        const progress = logs.statements[0].work.stream_offset.progress;
        try t.expect(progress == .interval);
        const remainder = (try Stream.apply(output, client, .{ .page = .{ .cursor = progress.end(), .limits = .{ .rows = 1, .encoded_bytes = 8192, .scanned_rows = 1 } } })).page;
        try t.expect(remainder.cursor.coverage.complete);
        try t.expectEqual(@as(u64, 2), remainder.cursor.coverage.until);
        try t.expectEqual(@as(usize, 1), remainder.rows.len);
        try t.expectEqual(@as(u64, 1), remainder.rows[0].offset);
        const consumed = (try Stream.apply(output, client, .{ .mutate = .{ .work = .{ .consume = .{ .target = logs.stream, .operation = operation(client, 642017), .group = null, .from = 2, .until = 3, .timestamp = null } } } })).operation.?.consume;
        const cursor = (try Stream.apply(output, client, .{ .cursor = .{ .target = logs.stream, .read = consumed.handle() } })).cursor;
        const page = (try Stream.apply(output, client, .{ .page = .{ .cursor = cursor, .limits = .{ .rows = 1, .encoded_bytes = 8192, .scanned_rows = 1 } } })).page;
        try t.expect(page.cursor.coverage.complete);
        try t.expectEqual(@as(usize, 1), page.rows.len);
        try t.expectEqual(@as(u64, 2), page.rows[0].offset);
        try t.expectEqual(@as(i64, 42), page.rows[0].value.cells[0].value.atom.signed);
        const next_claim = (try Queue.apply(output, client, .{ .mutate = .{ .work = .{ .claim = .{ .target = logs.queue, .operation = operation(client, 642018), .maximum = 1, .lease_ms = 300000, .predicate = null } } } })).operation.?.claim;
        const next_page = (try Queue.apply(output, client, .{ .page = .{ .cursor = .{ .receipt = next_claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
        try t.expectEqual(@as(usize, 1), next_page.rows.len);
        try t.expectEqual(@as(u64, 1), next_page.rows[0].lease.original.offset);
        try t.expectEqual(@as(i64, 42), next_page.rows[0].value.cells[0].value.atom.signed);
        return next_page.rows[0].lease.original;
    }
    return null;
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
    var caller = try callerFor(init, client);
    defer caller.deinit();
    var store = try recoveryStore(init, path);
    defer store.deinit();
    var recovery = try data.TransactionRecovery.init(init.gpa, &store);
    defer recovery.deinit();
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
    var transaction = try recovery.create(.{ .begin = .{ .key = key, .fingerprint = @splat(7), .operation = operation(client, 642100), .namespace = 1, .mode = .serializable, .deadline = null, .execution = null, .selection = .{ .explicit_objects = targets[0..@as(usize, if (with_logs) 4 else 2)] }, .limits = c.DirectTransaction.default_limits, .budget = .{} }, .settlement = operation(client, 642101) });
    defer transaction.deinit();
    _ = try caller.call(&transaction, .begin);
    _ = try caller.call(&transaction, .acquire);
    var insert = try c.DirectTablePreparedDml.prepare(init.gpa, client, 1, "INSERT INTO atomic_rows (id) VALUES ($1)", .transit, null);
    defer insert.deinit();
    var work = try insert.bind(init.gpa, client, 642011, &.{.{ .signed = 42 }}, .bulk, null);
    defer work.deinit();
    var fault: CheckpointFault = .{ .journal = transaction.journal };
    transaction.journal = .{ .context = &fault, .save = CheckpointFault.save };
    const known = try caller.call(&transaction, .{ .write = .{ .table = work.parsed.value.work } });
    try t.expect(known == .checkpoint_failed);
    try t.expectEqual(error.InjectedCheckpointFailure, known.checkpoint_failed.cause);
    try t.expectEqual(@as(u64, 1), known.checkpoint_failed.completion.statement.state.outcome.provisional.affected);
    const table_statement = transaction.state.statement.?.state;
    try t.expectError(error.TransactionSessionPending, caller.call(&transaction, .{ .write = .{ .table = work.parsed.value.work } }));
    const resumed = (try caller.call(&transaction, .{ .advance = 8 })).statement.state;
    try t.expectEqualDeep(table_statement, resumed.request);
    try t.expectEqual(@as(u64, 1), resumed.outcome.provisional.affected);
    var binding = declaration.binding;
    binding.identity = operation(client, 642012);
    binding.action = .insert;
    binding.expected_definition = metadata.interpretation.interpretation;
    const keys = [_][]const u8{ "one", "two", "three", "four", "five", "six" };
    var changes: [6]c.storage.KVPartition.Change = undefined;
    for (&changes, keys) |*change, name| change.* = .{ .put = .{ .key = name, .value = .{ .value = .{ .atom = .{ .bytes = &payload } } }, .expect = .absent } };
    const mutation = try KV.prepareMutation(&output, binding, spec, &changes);
    var saved: Saved = .{ .definition = p.Growth.current_definition, .key = key, .recovery = recovery.identity.?, .object = declaration.binding.target, .table_statement = table_statement, .kv_statement = undefined, .commit = operation(client, 642101), .logs = null };
    if (input) |logs| {
        const completion = (try caller.call(&transaction, .{ .write = .{ .kv = mutation } })).statement.state;
        try t.expectEqual(@as(u64, 6), completion.outcome.provisional.affected);
        saved.kv_statement = completion.request;
        saved.logs = try privateLogs(client, &caller, &transaction, &output, logs);
    } else {
        try caller.unknown(&transaction, .{ .write = .{ .kv = mutation } });
        saved.kv_statement = transaction.state.statement.?.state;
    }
    try t.expect(transaction.state.statement != null);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), saved, 64 * 1024) });
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    const tx: Tx = .{ .catalog = client };
    var caller = try callerFor(init, client);
    defer caller.deinit();
    var store = try recoveryStore(init, path);
    defer store.deinit();
    var recovery = try data.TransactionRecovery.init(init.gpa, &store);
    defer recovery.deinit();
    var transaction = try recovery.load(saved.recovery);
    defer transaction.deinit();
    try t.expect(transaction.state.statement != null);
    const pending = transaction.state.statement.?;
    const resumed = (try caller.call(&transaction, .{ .advance = 8 })).statement;
    try t.expectEqualDeep(pending, resumed.request());
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
        _ = try visibleLogs(client, &output, logs, false);
    }
    const private = try transaction.privateClient(client);
    const value = (try KV.apply(&output, private, .{ .get = .{ .object = saved.object, .key = "six" } })).value;
    try t.expect(value.workspace != null);
    try t.expectEqualSlices(u8, &payload, value.value.?.value.atom.bytes);
    try caller.unknown(&transaction, .{ .settle = .{ .command = .commit } });
}
pub fn verify(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    const tx: Tx = .{ .catalog = client };
    var caller = try callerFor(init, client);
    defer caller.deinit();
    var store = try recoveryStore(init, path);
    defer store.deinit();
    var recovery = try data.TransactionRecovery.init(init.gpa, &store);
    defer recovery.deinit();
    var transaction = try recovery.load(saved.recovery);
    defer transaction.deinit();
    try t.expectEqual(.commit, transaction.state.command.?);
    const known = (try caller.call(&transaction, .inspect)).status;
    try t.expect(known.observation == .decided and known.observation.decided.outcome == .committed);
    caller.context.beginClose();
    const result = (try caller.call(&transaction, .{ .settle = .{ .command = .commit } })).status;
    try t.expectEqualDeep(known.observation, result.observation);
    try t.expect(result.cleanup_complete);
    try t.expectEqual(@as(u64, 6), (try tx.statementOutcome(saved.key, saved.kv_statement)).?.provisional.affected);
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    try visible(client, &output, saved.object, true);
    try verifySavepoints(init, client, saved, &store);
    if (saved.logs) |logs| {
        const held_lease = (try visibleLogs(client, &output, logs, true)).?;
        // 4-participant Transaction.Deadline expiry: when commit runs after the
        // transaction deadline has elapsed (even while the Queue lease remains live),
        // native settlement refuses commit with TransactionDeadlineElapsed and
        // allows original abort cleanup with zero participant visibility.
        const expired_key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(9), .token = @splat(7) };
        const targets = [_]p.Transaction.Target{
            .{ .object = saved.object, .kind = .kv, .partition = null },
            .{ .object = saved.table_statement.binding.target, .kind = .table, .partition = null },
            .{ .object = logs.stream.interpretation.object, .kind = .stream, .partition = 0 },
            .{ .object = logs.queue.interpretation.object, .kind = .queue, .partition = 0 },
        };
        const observed_ms = held_lease.expires_ms - 300000;
        _ = try tx.begin(.{
            .key = expired_key,
            .fingerprint = @splat(8),
            .operation = operation(client, 642200),
            .namespace = 1,
            .mode = .serializable,
            .deadline = .{ .floor_ms = observed_ms -| 1000, .expires_ms = observed_ms },
            .execution = null,
            .selection = .{ .explicit_objects = &targets },
            .limits = c.DirectTransaction.default_limits,
            .budget = .{},
        });
        _ = try tx.acquire(expired_key);
        var insert = try c.DirectTablePreparedDml.prepare(init.gpa, client, 1, "INSERT INTO atomic_rows (id) VALUES ($1)", .transit, null);
        defer insert.deinit();
        var table_work = try insert.bind(init.gpa, client, 642201, &.{.{ .signed = 99 }}, .bulk, null);
        defer table_work.deinit();
        const staged_table = try tx.stage(expired_key, (try tx.inspect(expired_key)).revision, 1, table_work.parsed.value.work);
        try t.expectEqual(@as(u64, 1), (try tx.execute(expired_key, staged_table)).provisional.affected);
        var kv_binding = saved.kv_statement.binding;
        kv_binding.identity = operation(client, 642202);
        const kv_changes = [_]c.storage.KVPartition.Change{.{ .put = .{ .key = "seven", .value = .{ .value = .{ .atom = .{ .bytes = &payload } } }, .expect = .absent } }};
        const staged_kv = try tx.stageKV(expired_key, (try tx.inspect(expired_key)).revision, 2, try KV.prepareMutation(&output, kv_binding, spec, &kv_changes));
        try t.expectEqual(@as(u64, 1), (try tx.execute(expired_key, staged_kv)).provisional.affected);
        var buffer: [8192]u8 = undefined;
        const stream_id = operation(client, 642203);
        const stream_bytes = try appendPayload(logs.stream, stream_id, .stream, &buffer);
        const staged_stream = try tx.stageLog(expired_key, (try tx.inspect(expired_key)).revision, 3, .{ .append = .{ .target = logs.stream, .operation = stream_id, .kind = .stream, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(stream_bytes) } }, try c.DirectTableProtocol.Binary.encode(output.allocator(), stream_bytes));
        try t.expect((try tx.executeLog(expired_key, staged_stream)) == .provisional);
        const staged_ack = try tx.stageLog(expired_key, (try tx.inspect(expired_key)).revision, 4, .{ .queue_ack = .{ .operation = operation(client, 642204), .lease = held_lease, .action = .ack } }, null);
        try t.expect((try tx.executeLog(expired_key, staged_ack)) == .provisional);

        try t.expectError(error.TransactionDeadlineElapsed, tx.settle(expired_key, operation(client, 642205), .commit, 8));
        const aborted = try tx.settle(expired_key, operation(client, 642205), .abort, 16);
        try t.expect(aborted.observation == .decided and aborted.observation.decided.outcome == .aborted);
        try t.expect(aborted.cleanup_complete);
        try t.expect((try KV.apply(&output, client, .{ .get = .{ .object = saved.object, .key = "seven" } })).value.value == null);
        const table_after = try client.call(.{ .lookup = .{ .namespace = 1, .name = "atomic_rows" } });
        defer table_after.deinit();
        try t.expectEqual(@as(u64, 1), table_after.value.result.lookup.?.row_count);
        try t.expectEqual(@as(u64, 3), (try Stream.apply(&output, client, .{ .observe = logs.stream })).cut.next);
        try t.expectEqual(@as(u64, 2), (try Queue.apply(&output, client, .{ .observe = logs.queue })).cut.next);
    }
}

fn verifySavepoints(init: std.process.Init, client: c.DirectTableClient, saved: Saved, store: *data.LocalRecoveryStore) !void {
    var caller = try callerFor(init, client);
    defer caller.deinit();
    var recovery = try data.TransactionRecovery.init(init.gpa, store);
    defer recovery.deinit();
    var key = saved.key;
    key.token = @splat(8);
    const targets = [_]p.Transaction.Target{.{ .object = saved.object, .kind = .kv, .partition = null }};
    var transaction = try recovery.create(.{
        .begin = .{ .key = key, .fingerprint = @splat(9), .operation = operation(client, 642300), .namespace = 1, .mode = .serializable, .selection = .{ .explicit_objects = &targets }, .limits = c.DirectTransaction.default_limits, .deadline = null, .execution = null, .budget = .{} },
        .settlement = operation(client, 642306),
    });
    defer transaction.deinit();
    _ = try caller.call(&transaction, .begin);
    _ = try caller.call(&transaction, .acquire);
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const name = try c.TableAuthority.Name.init("keep_seven");
    for ([_][]const u8{ "seven", "eight" }, 0..) |word, index| {
        var binding = saved.kv_statement.binding;
        binding.identity = operation(client, 642301 + 2 * index);
        const mutation = try KV.prepareMutation(&output, binding, spec, &.{.{ .put = .{ .key = word, .value = .{ .value = .{ .atom = .{ .bytes = &payload } } }, .expect = .absent } }});
        const result = (try caller.call(&transaction, .{ .write = .{ .kv = mutation } })).statement.state;
        try t.expectEqual(@as(u64, 1), result.outcome.provisional.affected);
        if (index == 0) {
            const control = (try caller.call(&transaction, .{ .savepoint = .{ .operation = operation(client, 642302), .action = .{ .create = name }, .steps = 1 } })).savepoint;
            try t.expect(control.completed != null);
        }
    }
    var rollback = (try caller.call(&transaction, .{ .savepoint = .{ .operation = operation(client, 642304), .action = .{ .rollback = name }, .steps = 1 } })).savepoint;
    for (0..4) |_| {
        if (rollback.completed != null) break;
        rollback = (try caller.call(&transaction, .{ .advance = 1 })).savepoint;
    }
    try t.expect(rollback.completed != null);
    try t.expectEqual(@as(u64, 2), transaction.state.last_statement);
    const private = try transaction.privateClient(client);
    try t.expect((try KV.apply(&output, private, .{ .get = .{ .object = saved.object, .key = "seven" } })).value.value != null);
    try t.expect((try KV.apply(&output, private, .{ .get = .{ .object = saved.object, .key = "eight" } })).value.value == null);
    try t.expect((try caller.call(&transaction, .{ .savepoint = .{ .operation = operation(client, 642305), .action = .{ .release = name }, .steps = 1 } })).savepoint.completed != null);
    var closed = (try caller.call(&transaction, .{ .settle = .{ .command = .abort, .steps = 1 } })).status;
    for (0..16) |_| {
        if (closed.cleanup_complete) break;
        closed = (try caller.call(&transaction, .{ .settle = .{ .command = .abort, .steps = 1 } })).status;
    }
    try t.expect(closed.cleanup_complete);
    try t.expect(closed.observation == .decided and closed.observation.decided.outcome == .aborted);
    for ([_][]const u8{ "seven", "eight" }) |word|
        try t.expect((try KV.apply(&output, client, .{ .get = .{ .object = saved.object, .key = word } })).value.value == null);
}
