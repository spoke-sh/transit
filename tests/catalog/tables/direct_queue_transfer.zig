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
fn createQueue(init: std.process.Init, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, role: u64, destination: ?p.StreamQueue.Partition, automatic: bool) !p.StreamQueue.Partition {
    const base: u64 = if (automatic) 644000 else 643000;
    const object: u64 = base + @as(u64, if (destination != null) 10 else 20);
    const intent: c.DirectLog.Intent = .{ .kind = .queue, .namespace = 1, .name = try .init(if (automatic) (if (destination != null) "automatic_transfer_inbox" else "automatic_dead_letters") else (if (destination != null) "transfer_inbox" else "transfer_dead_letters")), .action = .{ .create = .{
        .owner = role,
        .schema = schema(object),
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .queue = .{ .ordering = .key_fifo, .key_column = 1, .lease_ms = 300000, .maximum_lease_ms = 300000, .maximum_attempts = if (automatic) 1 else 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = if (destination) |target| target.interpretation else null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = operation(client, base + @as(u64, if (destination != null) 1 else 2)), .target = .{ .scope = client.connection.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(init.gpa) } };
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
    const destination = try createQueue(init, client, &output, role, null, false);
    const source = try createQueue(init, client, &output, role, destination, false);
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

const automatic_account: [32]u8 = @splat(0x51);
const AutomaticSaved = struct {
    definition: p.Growth.Definition,
    source: p.StreamQueue.Partition,
    destination: p.StreamQueue.Partition,
    claim: p.StreamQueue.ClaimReceipt,
};
pub const AutomaticObservation = struct {
    observed: bool = false,
    pending: bool = false,
    committed: bool = false,
    cleanup_complete: bool = false,
};
fn saveJson(init: std.process.Init, path: []const u8, value: anytype) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), value, 64 * 1024) });
}
fn loadAutomatic(init: std.process.Init, path: []const u8) !AutomaticSaved {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(64 * 1024));
    const parsed = try p.Json.parseFromSlice(AutomaticSaved, init.gpa, bytes);
    defer parsed.deinit();
    const saved = parsed.value;
    if (saved.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try saved.source.validate();
    try saved.destination.validate();
    try saved.claim.validate();
    try saved.source.requireSame(saved.claim.claim.target);
    return saved;
}
fn savedMutation(init: std.process.Init, client: c.DirectTableClient, output: *std.heap.ArenaAllocator, path: []const u8, action: @FieldType(Queue.Action, "mutate")) !Queue.Result {
    const original = try Queue.save(init.arena.allocator(), client.connection, action);
    const request_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}-{d}.request", .{ path, action.work.identity().operation });
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = request_path, .data = original });
    // Keep every original identity and payload even when dispatch is uncertain.
    return Queue.apply(output, client, .{ .mutate = action });
}
pub fn automaticPrepare(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    const destination = try createQueue(init, client, &output, role, null, true);
    const source = try createQueue(init, client, &output, role, destination, true);
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    var buffer: [8192]u8 = undefined;
    const input = try c.storage.LogBatch.encode(schema(source.interpretation.object.object), operation(client, 644004), .queue, &.{.{ .cells = &cells }}, &buffer);
    _ = try savedMutation(init, client, &output, path, .{ .work = .{ .enqueue = .{ .target = source, .operation = operation(client, 644004), .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(input) } }, .payload = input });
    const claim = (try savedMutation(init, client, &output, path, .{ .work = .{ .claim = .{ .target = source, .operation = operation(client, 644005), .maximum = 1, .lease_ms = 300000 } } })).operation.?.claim;
    const page = (try Queue.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(usize, 1), page.rows.len);
    try t.expectEqual(@as(u64, 0), page.rows[0].lease.original.offset);
    try saveJson(init, path, AutomaticSaved{ .definition = p.Growth.current_definition, .source = source, .destination = destination, .claim = claim });
    _ = try savedMutation(init, client, &output, path, .{ .work = .{ .settle = .{ .operation = operation(client, 644006), .lease = page.rows[0].lease.original, .action = .{ .nack = .{ .visible_ms = 0 } } } } });
    try t.expect(!(try automaticObserve(init, client, path)).observed);
}
pub fn automaticObserve(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !AutomaticObservation {
    _ = try loadAutomatic(init, path);
    const page = try c.DirectClientToken.list(client, automatic_account, null, false);
    try t.expect(page.next == null);
    for (page.entries[1..]) |entry| try t.expect(entry == null);
    const progress = page.entries[0] orelse return .{};
    try t.expect(progress.receipt.binding.intent == .transaction);
    try t.expect(progress.receipt.binding.intent.transaction.purpose == .queue_transfer);
    const receipt_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}.receipt", .{path});
    const original = std.Io.Dir.cwd().readFileAlloc(init.io, receipt_path, init.arena.allocator(), .limited(64 * 1024)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (original) |bytes| {
        const parsed = try p.Json.parseFromSlice(c.DirectClientToken.Receipt, init.gpa, bytes);
        defer parsed.deinit();
        try parsed.value.validate();
        try t.expectEqualDeep(parsed.value, progress.receipt);
    } else try saveJson(init, receipt_path, progress.receipt);
    const tx: Tx = .{ .catalog = client };
    const status = try tx.inspect(progress.receipt.binding.key);
    const committed = status.observation == .decided and status.observation.decided.outcome == .committed;
    if (status.observation == .decided) try t.expect(committed);
    return .{ .observed = true, .pending = progress.pending, .committed = committed, .cleanup_complete = status.cleanup_complete };
}
pub fn automaticVerify(init: std.process.Init, client: c.DirectTableClient, path: []const u8, reopen: bool) !void {
    const observed = try automaticObserve(init, client, path);
    try t.expect(observed.observed and observed.committed and observed.cleanup_complete and !observed.pending);
    const saved = try loadAutomatic(init, path);
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    try t.expectEqual(@as(u64, 1), (try Queue.apply(&output, client, .{ .observe = saved.source })).cut.next);
    try t.expectEqual(@as(u64, 1), (try Queue.apply(&output, client, .{ .observe = saved.destination })).cut.next);
    const source = (try Queue.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = saved.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(usize, 1), source.rows.len);
    try t.expectEqual(p.QueueRead.State.archived, source.rows[0].lease.state);
    const claim: c.DirectQueueMutation.Request = .{ .claim = .{ .target = saved.destination, .operation = operation(client, 644007), .maximum = 1, .lease_ms = 300000 } };
    const receipt = if (reopen)
        (try Queue.apply(&output, client, .{ .operation = claim })).operation.?.claim
    else
        (try savedMutation(init, client, &output, path, .{ .work = claim })).operation.?.claim;
    const receipt_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}.destination-claim", .{path});
    if (reopen) {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, receipt_path, init.arena.allocator(), .limited(64 * 1024));
        const parsed = try p.Json.parseFromSlice(p.StreamQueue.ClaimReceipt, init.gpa, bytes);
        defer parsed.deinit();
        try t.expectEqualDeep(parsed.value, receipt);
    } else try saveJson(init, receipt_path, receipt);
    const page = (try Queue.apply(&output, client, .{ .page = .{ .cursor = .{ .receipt = receipt, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } })).page;
    try t.expectEqual(@as(usize, 1), page.rows.len);
    try t.expectEqual(@as(u64, 0), page.rows[0].lease.original.offset);
    try t.expectEqual(@as(i64, 42), page.rows[0].value.cells[0].value.atom.signed);
}
