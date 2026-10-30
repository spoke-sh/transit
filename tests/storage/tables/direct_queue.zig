//! Installed Queue schedule through the public signed data client only.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const data = @import("transit_data_client");
const p = c.protocol;
const State = struct {
    definition: p.Growth.Definition,
    enqueue: []const u8,
    claim: p.StreamQueue.Claim,
    claimed: ?p.StreamQueue.ClaimReceipt,
    ack: ?[]const u8,
    acked: ?p.StreamQueue.SettlementReceipt,
};
fn callerFor(init: std.process.Init, client: c.DirectTableClient) !data.Catalog {
    return data.Catalog.init(init.gpa, init.io, .{ .url = client.authority.url, .service_url = client.service.url, .connection = client.connection, .timeout_ms = 30000 }, client.key.secret_key.seed());
}
fn call(caller: *data.Catalog, output: *std.heap.ArenaAllocator, action: c.DirectQueueClient.Action) !c.DirectQueueClient.Result {
    const outcome = try caller.callQueue(output, action);
    return switch (outcome.value) {
        .result => |result| result,
        .failure => |failure| failure.cause,
    };
}
fn unknown(caller: *data.Catalog, output: *std.heap.ArenaAllocator, work: @FieldType(c.DirectQueueClient.Action, "mutate")) !void {
    const outcome = try caller.callQueue(output, .{ .mutate = work });
    try t.expect(outcome.value == .failure);
    try t.expectEqual(error.InvalidTableResponse, outcome.value.failure.cause);
    try t.expect(outcome.mutationAttempted());
    try t.expectEqualDeep(work.work.identity(), outcome.attempt.mutation.?.identity.?);
    try t.expectEqual(.unknown, outcome.value.failure.diagnostic.?.outcome);
}
fn logCall(caller: *data.Catalog, output: *std.heap.ArenaAllocator, action: c.DirectLogClient.Action) !c.DirectLogClient.Result {
    const outcome = try caller.callLog(output, action);
    return switch (outcome.value) {
        .result => |result| result,
        .failure => |failure| failure.cause,
    };
}
fn finish(caller: *data.Catalog, output: *std.heap.ArenaAllocator, request: c.DirectLog.Request) !c.DirectLog.Definition {
    _ = try logCall(caller, output, .{ .admit = request });
    const outcome = (try logCall(caller, output, .{ .operation = .{ .binding = request.binding, .command = .execute, .steps = 32 } })).operation.operation;
    try t.expectEqual(.complete, outcome.phase);
    return outcome.resulting.?;
}
fn save(init: std.process.Init, path: []const u8, state: State) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAlloc(init.arena.allocator(), state) });
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    var caller = try callerFor(init, client);
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "entity", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 633000, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{} };
    const intent: c.DirectLog.Intent = .{ .kind = .queue, .namespace = 1, .name = try .init("queued_work"), .action = .{ .create = .{
        .owner = role,
        .schema = schema,
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .queue = .{ .ordering = .key_fifo, .key_column = 1, .lease_ms = 60000, .maximum_lease_ms = 60000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const creation: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 633000 }, .target = .{ .scope = client.connection.scope, .branch = 1, .object = schema.object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(init.gpa) } };
    const declared = try finish(&caller, &output, creation);
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declared.stored.declaration.interpretation, .partition = 0 };
    var operation = creation.binding.identity;
    operation.operation = 633001;
    const a = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 1 } } }};
    const b = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 2 } } }};
    var buffer: [8192]u8 = undefined;
    const payload = try c.storage.LogBatch.encode(schema, operation, .queue, &.{ .{ .cells = &a }, .{ .cells = &a }, .{ .cells = &b } }, &buffer);
    const enqueue: c.DirectQueueMutation.Request = .{ .enqueue = .{ .target = target, .operation = operation, .kind = .queue, .producer = .{ .id = @splat(13), .epoch = 1, .sequence = 1 }, .rows = 3, .payload = c.storage.LogBatch.content(payload) } };
    operation.operation = 633002;
    var state: State = .{ .definition = p.Growth.current_definition, .enqueue = try c.DirectQueueClient.save(init.arena.allocator(), client.connection, .{ .work = enqueue, .payload = payload }), .claim = .{ .target = target, .operation = operation, .maximum = 3, .lease_ms = 60000 }, .claimed = null, .ack = null, .acked = null };
    try save(init, path, state);
    try unknown(&caller, &output, .{ .work = enqueue, .payload = payload });
    const enqueued = (try call(&caller, &output, .{ .operation = enqueue })).operation.?.enqueue;
    try t.expectEqual(@as(u64, 3), enqueued.next);
    try t.expectEqualDeep(enqueued, (try call(&caller, &output, .{ .mutate = .{ .work = enqueue, .payload = payload } })).operation.?.enqueue);
    try unknown(&caller, &output, .{ .work = .{ .claim = state.claim } });
    state.claimed = (try call(&caller, &output, .{ .operation = .{ .claim = state.claim } })).operation.?.claim;
    try save(init, path, state);
    try t.expectEqual(@as(u32, 2), state.claimed.?.rows);
    const first = (try call(&caller, &output, .{ .page = .{ .cursor = .{ .receipt = state.claimed.?, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(u64, 0), first.rows[0].lease.original.offset);
    const second = (try call(&caller, &output, .{ .page = .{ .cursor = first.cursor, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(u64, 2), second.rows[0].lease.original.offset);
    try t.expect(second.cursor.complete());
    try t.expectEqual(@as(i64, 1), first.rows[0].value.cells[0].value.atom.signed);
    try t.expectEqual(@as(i64, 2), second.rows[0].value.cells[0].value.atom.signed);
    var empty_request = state.claim;
    empty_request.operation.operation = 633003;
    const empty = (try call(&caller, &output, .{ .mutate = .{ .work = .{ .claim = empty_request } } })).operation.?.claim;
    try t.expectEqual(@as(u32, 0), empty.rows);
    operation.operation = 633004;
    const ack: c.DirectQueueMutation.Request = .{ .settle = .{ .operation = operation, .lease = first.rows[0].lease.original, .action = .ack } };
    state.ack = try c.DirectQueueClient.save(init.arena.allocator(), client.connection, .{ .work = ack });
    try save(init, path, state);
    try unknown(&caller, &output, .{ .work = ack });
    state.acked = (try call(&caller, &output, .{ .operation = ack })).operation.?.settle;
    try save(init, path, state);
    try t.expectEqualDeep(empty, (try call(&caller, &output, .{ .mutate = .{ .work = .{ .claim = empty_request } } })).operation.?.claim);
    empty_request.operation.operation = 633005;
    const successor = (try call(&caller, &output, .{ .mutate = .{ .work = .{ .claim = empty_request } } })).operation.?.claim;
    try t.expectEqual(@as(u32, 1), successor.rows);
    const head = (try call(&caller, &output, .{ .page = .{ .cursor = .{ .receipt = successor, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(u64, 1), head.rows[0].lease.original.offset);
    const drop_intent: c.DirectLog.Intent = .{ .kind = .queue, .namespace = 1, .name = intent.name, .action = .drop };
    var drop = creation;
    drop.intent = drop_intent;
    drop.binding.identity.operation = 633006;
    drop.binding.action = .drop;
    drop.binding.expected_definition = target.interpretation;
    drop.binding.intent = try drop_intent.digest(init.gpa);
    try t.expect((try finish(&caller, &output, drop)).stored.retired);
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(1024 * 1024));
    const state = (try p.Json.parseFromSlice(State, init.arena.allocator(), bytes)).value;
    try t.expectEqual(p.Growth.current_definition, state.definition);
    var caller = try callerFor(init, client);
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const enqueued = try c.DirectQueueClient.load(init.gpa, state.enqueue);
    defer enqueued.deinit();
    const payload = try enqueued.value.work.payload.?.decode(init.arena.allocator(), 8192);
    const original = (try call(&caller, &output, .{ .operation = enqueued.value.work.work })).operation.?.enqueue;
    try t.expectEqual(@as(u64, 3), original.next);
    try t.expectEqualDeep(original, (try call(&caller, &output, .{ .mutate = .{ .work = enqueued.value.work.work, .payload = payload } })).operation.?.enqueue);
    try t.expectEqualDeep(state.claimed.?, (try call(&caller, &output, .{ .mutate = .{ .work = .{ .claim = state.claim } } })).operation.?.claim);
    const ack = try c.DirectQueueClient.load(init.gpa, state.ack.?);
    defer ack.deinit();
    try t.expectEqualDeep(state.acked.?, (try call(&caller, &output, .{ .mutate = .{ .work = ack.value.work.work } })).operation.?.settle);
    const page = (try call(&caller, &output, .{ .page = .{ .cursor = .{ .receipt = state.claimed.?, .next = 0 }, .limits = .{ .rows = 2, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(usize, 2), page.rows.len);
    try t.expect(page.cursor.complete());
    try t.expectEqual(.acked, page.rows[0].lease.state);
    try t.expectEqual(.fenced, page.rows[0].lease.liveness);
    try t.expectEqual(@as(u64, 2), page.rows[1].lease.original.offset);
    try t.expectEqualStrings("entity", page.source.schema.columns[0].name);
    const terminal = (try call(&caller, &output, .{ .page = .{ .cursor = page.cursor, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expect(terminal.cursor.complete() and terminal.rows.len == 0);
    try t.expectEqual(@as(i64, 1), page.rows[0].value.cells[0].value.atom.signed);
    var fresh = state.claim;
    fresh.operation.operation = 633007;
    const refused = try caller.callQueue(&output, .{ .mutate = .{ .work = .{ .claim = fresh } } });
    try t.expect(refused.value == .failure and refused.value.failure.protocol_error == .Conflict);
}
