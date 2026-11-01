//! Installed paired dead-letter publication and original-decision recovery.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const Tx = c.DirectTransactionClient;
const Queue = c.DirectQueueClient;
const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "entity", .type = .int64, .nullable = false }};
const Saved = struct {
    definition: p.Growth.Definition,
    key: c.DirectClientToken.Key,
    source: p.StreamQueue.Partition,
    destination: p.StreamQueue.Partition,
    claim: p.StreamQueue.ClaimReceipt,
    request: c.DirectTransactionLogWork.Request,
    commit: d.Operation,
};
fn operation(client: c.DirectTableClient, id: u64) d.Operation {
    return .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = id };
}
fn schema(object: u64) c.fuze.TableSchema.Schema {
    return .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{} };
}
fn load(init: std.process.Init, path: []const u8) !Saved {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(64 * 1024));
    const parsed = try p.Json.parseFromSlice(Saved, init.gpa, bytes);
    defer parsed.deinit();
    const value = parsed.value;
    try value.key.validate();
    try value.request.validate();
    try value.claim.validate();
    try value.commit.validate();
    if (value.definition != p.Growth.current_definition or value.request.work != .queue_transfer) return error.IncompatibleDefinition;
    try value.source.requireSame(value.request.work.target());
    try value.destination.requireSame(value.request.work.queue_transfer.destination.target);
    return value;
}
fn createQueue(init: std.process.Init, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, role: u64, destination: ?p.StreamQueue.Partition) !p.StreamQueue.Partition {
    const object: u64 = if (destination != null) 643010 else 643020;
    const intent: c.DirectLog.Intent = .{ .kind = .queue, .namespace = 1, .name = try .init(if (destination != null) "transfer_inbox" else "transfer_dead_letters"), .action = .{ .create = .{
        .owner = role,
        .schema = schema(object),
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .queue = .{ .ordering = .key_fifo, .key_column = 1, .lease_ms = 300000, .maximum_lease_ms = 300000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = if (destination) |target| target.interpretation else null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = operation(client, if (destination != null) 643001 else 643002), .target = .{ .scope = client.connection.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(init.gpa) } };
    _ = try c.DirectLogClient.apply(output, client, .{ .admit = request });
    const completed = (try c.DirectLogClient.apply(output, client, .{ .operation = .{ .binding = request.binding, .command = .execute, .steps = 16 } })).operation.operation;
    try t.expectEqual(.complete, completed.phase);
    return .{ .definition = p.Growth.current_definition, .interpretation = completed.resulting.?.stored.declaration.interpretation, .partition = 0 };
}
fn visible(client: c.DirectTableClient, output: *std.heap.ArenaAllocator, saved: Saved, committed: bool) !void {
    try t.expectEqual(@as(u64, 2), (try Queue.apply(output, client, .{ .observe = saved.source })).cut.next);
    try t.expectEqual(@as(u64, @intFromBool(committed)), (try Queue.apply(output, client, .{ .observe = saved.destination })).cut.next);
    const page = (try Queue.apply(output, client, .{ .page = .{ .cursor = .{ .receipt = saved.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(usize, 1), page.rows.len);
    try t.expectEqual(@as(p.QueueRead.State, if (committed) .archived else .acquired), page.rows[0].lease.state);
    const original = (try Queue.apply(output, client, .{ .operation = .{ .enqueue = saved.request.work.queue_transfer.destination } })).operation;
    try t.expectEqual(committed, original != null);
    if (original) |receipt| {
        try t.expectEqualDeep(saved.request.work.queue_transfer.destination, receipt.enqueue.append);
        try t.expectEqual(@as(u64, 0), receipt.enqueue.first);
        try t.expectEqual(@as(u64, 1), receipt.enqueue.next);
    }
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const destination = try createQueue(init, client, &output, role, null);
    const source = try createQueue(init, client, &output, role, destination);
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    var buffer: [8192]u8 = undefined;
    const input = try c.storage.LogBatch.encode(schema(source.interpretation.object.object), operation(client, 643004), .queue, &.{ .{ .cells = &cells }, .{ .cells = &cells } }, &buffer);
    _ = try Queue.apply(&output, client, .{ .mutate = .{ .work = .{ .enqueue = .{ .target = source, .operation = operation(client, 643004), .kind = .queue, .producer = null, .rows = 2, .payload = c.storage.LogBatch.content(input) } }, .payload = input } });
    const claim = (try Queue.apply(&output, client, .{ .mutate = .{ .work = .{ .claim = .{ .target = source, .operation = operation(client, 643005), .maximum = 1, .lease_ms = 300000 } } } })).operation.?.claim;
    const claimed = (try Queue.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(usize, 1), claimed.rows.len);
    const lease = claimed.rows[0].lease.original;
    try t.expectEqual(@as(u64, 0), lease.offset);
    const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(0x43), .token = @splat(0x44) };
    const targets = [_]p.Transaction.Target{
        .{ .object = source.interpretation.object, .kind = .queue, .partition = 0 },
        .{ .object = destination.interpretation.object, .kind = .queue, .partition = 0 },
    };
    const tx: Tx = .{ .catalog = client };
    _ = try tx.begin(.{ .key = key, .fingerprint = @splat(0x45), .operation = operation(client, 643100), .namespace = 1, .mode = .serializable, .selection = .{ .explicit_objects = &targets }, .limits = c.DirectTransaction.default_limits, .budget = .{} });
    _ = try tx.acquire(key);
    const payload = try c.storage.LogBatch.encode(schema(destination.interpretation.object.object), operation(client, 643007), .queue, &.{.{ .cells = &cells }}, &buffer);
    const work: c.DirectTransactionLogWork.Work = .{ .queue_transfer = .{ .operation = operation(client, 643006), .source = .{ .nack = lease }, .destination = .{ .target = destination, .operation = operation(client, 643007), .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) } } };
    const request = try tx.stageLog(key, (try tx.inspect(key)).revision, 1, work, try c.DirectTableProtocol.Binary.encode(output.allocator(), payload));
    const saved: Saved = .{ .definition = p.Growth.current_definition, .key = key, .source = source, .destination = destination, .claim = claim, .request = request, .commit = operation(client, 643101) };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), saved, 64 * 1024) });
    try t.expectError(error.InvalidTableResponse, tx.executeLog(key, request));
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    const tx: Tx = .{ .catalog = client };
    const original = (try tx.logOutcome(saved.key, saved.request)).?;
    try t.expect(original == .provisional);
    try t.expectEqualDeep(original, try tx.executeLog(saved.key, saved.request));
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    try visible(client, &output, saved, false);
    try t.expectError(error.InvalidTableResponse, tx.settle(saved.key, saved.commit, .commit, 8));
}
pub fn verify(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    const tx: Tx = .{ .catalog = client };
    const status = try tx.settle(saved.key, saved.commit, .abort, 8);
    try t.expect(status.cleanup_complete and status.observation == .decided and status.observation.decided.outcome == .committed);
    try t.expect((try tx.logOutcome(saved.key, saved.request)).? == .provisional);
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    try visible(client, &output, saved, true);
    for ([_]p.StreamQueue.Partition{ saved.source, saved.destination }, 0..) |target, i| {
        const claimed = (try Queue.apply(&output, client, .{ .mutate = .{ .work = .{ .claim = .{ .target = target, .operation = operation(client, 643008 + i), .maximum = 1, .lease_ms = 300000 } } } })).operation.?.claim;
        const page = (try Queue.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = claimed, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
        try t.expectEqual(@as(usize, 1), page.rows.len);
        try t.expectEqual(@as(u64, if (i == 0) 1 else 0), page.rows[0].lease.original.offset);
        try t.expectEqual(@as(i64, 42), page.rows[0].value.cells[0].value.atom.signed);
    }
}
