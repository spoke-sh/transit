const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const data = @import("transit_data_client");
const Transaction = data.Transaction;
const p = c.protocol;
const KV = c.DirectKVClient;
const support = @import("fixture_direct_state_transaction");
const callerFor = support.callerFor;
const recoveryStore = support.recoveryStore;
const operation = support.operation;

fn stale(caller: *support.Caller, transaction: *Transaction, output: *std.heap.ArenaAllocator, action: Transaction.Read.Action) !void {
    const outcome = try caller.context.readTransaction(caller.handle, transaction, output, action);
    try t.expectEqual(error.Conflict, outcome.value.failure.cause);
    try t.expectEqual(p.ErrorCode.QueryExpired, outcome.value.failure.protocol_error.?);
    try t.expect(!outcome.mutationAttempted());
}

/// A data-only host exercises owned reads independently of Station's handlers.
pub fn run(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, path: []const u8) !void {
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    var ddl = try c.DirectTablePreparedDdl.prepare(init.gpa, client, 1, "CREATE TABLE read_rows (region TEXT COLLATE ASCII_CI NOT NULL, id BIGINT NOT NULL, payload BINARY, PRIMARY KEY (region, id))", .transit, null);
    defer ddl.deinit();
    var table = try ddl.bind(init.gpa, client, 642501, 642500);
    defer table.deinit();
    (try table.table.admit(client)).deinit();
    const created = try table.table.operation(client, .execute, 64);
    defer created.deinit();
    try t.expect(created.value.result.ddl == .committed);
    const nullable: c.storage.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = true };
    const declaration = try KV.prepareDeclaration(init.gpa, .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = operation(client, 642502), .target = .{ .scope = client.connection.scope, .branch = 1, .object = 642490 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = undefined },
        .namespace = 1,
        .name = try .init("read_nullable"),
        .action = .{ .create = .{ .owner = role, .spec = nullable } },
    });
    _ = try KV.apply(&output, client, .{ .declaration = .{ .declaration = declaration, .command = .admit, .steps = 1 } });
    try t.expect((try KV.apply(&output, client, .{ .declaration = .{ .declaration = declaration, .command = .execute, .steps = 64 } })).declaration.operation == .committed);
    const metadata = (try KV.apply(&output, client, .{ .observe = declaration.binding.target })).definition;
    var caller = try callerFor(init, client);
    var caller_live = true;
    defer if (caller_live) caller.deinit();
    const read_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}.reads", .{path});
    var store = try recoveryStore(init, read_path);
    defer store.deinit();
    var recovery = try data.TransactionRecovery.init(init.gpa, &store);
    defer recovery.deinit();
    const targets = [_]p.Transaction.Target{
        .{ .object = declaration.binding.target, .kind = .kv, .partition = null },
        .{ .object = created.value.result.ddl.committed.binding.target, .kind = .table, .partition = null },
    };
    const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(9), .token = @splat(10) };
    var transaction = try recovery.create(.{
        .begin = .{ .key = key, .fingerprint = @splat(11), .operation = operation(client, 642510), .namespace = 1, .mode = .serializable, .selection = .{ .explicit_objects = &targets }, .limits = c.DirectTransaction.default_limits, .deadline = null, .execution = null, .budget = .{} },
        .settlement = operation(client, 642599),
    });
    defer transaction.deinit();
    _ = try caller.call(&transaction, .begin);
    _ = try caller.call(&transaction, .acquire);
    const open: Transaction.Read.Action = .{ .open_table = .{ .allocator = init.gpa, .table = .{ .namespace = 1, .name = try .init("read_rows"), .expected = created.value.result.ddl.committed.resulting.interpretation } } };
    // The existing proxy corrupts the first pin reply. A private descriptor
    // accepts no durable mutation; the caller explicitly opens a fresh reader.
    const lost = try caller.context.readTransaction(caller.handle, &transaction, &output, open);
    try t.expectEqual(error.InvalidTableResponse, lost.value.failure.cause);
    try t.expect(!lost.mutationAttempted());
    // Fail every retained-schema allocation depth, preserving local cleanup and
    // the original transaction-owned pins. Transport scratch is independent.
    try t.checkAllAllocationFailures(init.gpa, struct {
        fn run(allocator: std.mem.Allocator, owner: *support.Caller, tx: *Transaction, arena: *std.heap.ArenaAllocator, selected: c.DirectTransactionReader.Table) !void {
            var value = (try owner.read(tx, arena, .{ .open_table = .{ .allocator = allocator, .table = selected } })).opened;
            defer value.deinit();
        }
    }.run, .{ &caller, &transaction, &output, open.open_table.table });
    var empty = (try caller.read(&transaction, &output, open)).opened;
    defer empty.deinit();
    var empty_page = (try caller.read(&transaction, &output, .{ .table = .{ .reader = &empty, .command = .{ .next = .{} } } })).batch.?;
    defer empty_page.deinit();
    try t.expect(empty_page.complete and empty_page.count == 0);
    try t.expect((try caller.read(&transaction, &output, .{ .table = .{ .reader = &empty, .command = .{ .next = .{} } } })).batch == null);
    var empty_description = (try caller.read(&transaction, &output, .{ .table = .{ .reader = &empty, .command = .describe } })).description;
    defer empty_description.deinit();
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(empty_description.basis.authority.table), .owner = 0 } });
    for ([_]Transaction.Read.Command{ .describe, .{ .next = .{} } }) |command|
        try t.expectError(error.AccessDenied, caller.read(&transaction, &output, .{ .table = .{ .reader = &empty, .command = command } }));
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(empty_description.basis.authority.table), .owner = role } });

    const blob: [4096]u8 = @splat(0xa7);
    const insert_sql = comptime blk: {
        var sql: []const u8 = "INSERT INTO read_rows (region, id, payload) VALUES ";
        for (0..33) |i| sql = sql ++ (if (i == 0) "" else ", ") ++ std.fmt.comptimePrint("(${d}, ${d}, ${d})", .{ 3 * i + 1, 3 * i + 2, 3 * i + 3 });
        break :blk sql;
    };
    var values: [99]?c.fuze.Types.Values.Atom = undefined;
    for (0..33) |i| {
        values[3 * i] = .{ .bytes = "West" };
        values[3 * i + 1] = .{ .signed = @intCast(i) };
        values[3 * i + 2] = .{ .bytes = &blob };
    }
    var insert = try c.DirectTablePreparedDml.prepare(init.gpa, client, 1, insert_sql, .transit, null);
    defer insert.deinit();
    var work = try insert.bind(init.gpa, client, 642520, &values, .bulk, null);
    defer work.deinit();
    try t.expectEqual(@as(u64, 33), (try caller.call(&transaction, .{ .write = .{ .table = work.parsed.value.work } })).statement.state.outcome.provisional.affected);
    try stale(&caller, &transaction, &output, .{ .table = .{ .reader = &empty, .command = .describe } });
    var binding = declaration.binding;
    binding.identity = operation(client, 642521);
    binding.action = .insert;
    binding.expected_definition = metadata.interpretation.interpretation;
    _ = try caller.call(&transaction, .{ .write = .{ .kv = try KV.prepareMutation(&output, binding, nullable, &.{.{ .put = .{ .key = "null", .value = .null, .expect = .absent } }}) } });
    const null_value = (try caller.read(&transaction, &output, .{ .kv = .{ .object = binding.target, .key = "null", .expected = binding.expected_definition } })).kv;
    try t.expect(null_value.value.? == .null);
    try t.expect((try caller.read(&transaction, &output, .{ .kv = .{ .object = binding.target, .key = "missing" } })).kv.value == null);
    try t.expect((try KV.apply(&output, client, .{ .get = .{ .object = binding.target, .key = "null" } })).value.value == null);
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(metadata.authorization), .owner = 0 } });
    for ([_][]const u8{ "null", "missing" }) |word|
        try t.expectError(error.AccessDenied, caller.read(&transaction, &output, .{ .kv = .{ .object = binding.target, .key = word } }));
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(metadata.authorization), .owner = role } });

    var reader = (try caller.read(&transaction, &output, open)).opened;
    var reader_live = true;
    defer if (reader_live) reader.deinit();
    var description = (try caller.read(&transaction, &output, .{ .table = .{ .reader = &reader, .command = .describe } })).description;
    defer description.deinit();
    try t.expectEqualDeep(null_value.workspace.?.cut, description.basis.workspace.?.cut);
    try t.expectEqualDeep(null_value.workspace.?.revision, description.basis.workspace.?.revision);
    try t.expectEqual(@as(u64, 33), description.basis.row_count);
    const point = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "wEsT" } } }, .{ .value = .{ .atom = .{ .signed = 7 } } } };
    var retained = (try caller.read(&transaction, &output, .{ .table = .{ .reader = &reader, .command = .{ .key = &point } } })).row.?;
    defer retained.deinit();
    try t.expectEqualSlices(u8, &blob, retained.row().cells[2].value.atom.bytes);
    var missing = point;
    missing[1].value.atom.signed = 99;
    try t.expect((try caller.read(&transaction, &output, .{ .table = .{ .reader = &reader, .command = .{ .key = &missing } } })).row == null);
    // Refused output allocation cannot consume the first page or mark it done.
    var failing = std.testing.FailingAllocator.init(init.gpa, .{ .fail_index = 0 });
    var refused: std.heap.ArenaAllocator = .init(failing.allocator());
    defer refused.deinit();
    const next: Transaction.Read.Action = .{ .table = .{ .reader = &reader, .command = .{ .next = .{ .rows = 2, .encoded_bytes = 32 * 1024 } } } };
    try t.expectError(error.OutOfMemory, caller.read(&transaction, &refused, next));
    try t.expectEqual(@as(u64, 0), reader.native.reader.consumed);
    try t.expect(!reader.native.reader.complete);
    var probe: c.fuze.memory.AllocationProbe = .{ .parent = init.gpa };
    var budget: c.fuze.MemoryBudget = .{ .parent = probe.allocator(), .limit = 96 * 1024 };
    var batch_output: std.heap.ArenaAllocator = .init(budget.allocator());
    defer batch_output.deinit();
    var count: usize = 0;
    var pages: usize = 0;
    while (true) {
        _ = batch_output.reset(.retain_capacity);
        var page = (try caller.read(&transaction, &batch_output, next)).batch orelse break;
        defer page.deinit();
        for (page.rows[0..page.count]) |row| {
            try t.expectEqual(@as(i64, @intCast(count)), row.?.row().cells[1].value.atom.signed);
            try t.expectEqualSlices(u8, "West", row.?.row().cells[0].value.atom.bytes);
            try t.expectEqualSlices(u8, &blob, row.?.row().cells[2].value.atom.bytes);
            count += 1;
        }
        pages += 1;
        if (page.complete) try t.expectEqual(@as(usize, 33), count);
    }
    try t.expectEqual(@as(usize, 33), count);
    try t.expect(pages > 1 and count * blob.len > budget.limit and budget.peak <= budget.limit);
    try t.expectEqualSlices(u8, &blob, retained.row().cells[2].value.atom.bytes);
    // Revocation applies to cached metadata, missing keys and repeated EOF.
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(description.basis.authority.table), .owner = 0 } });
    for ([_]Transaction.Read.Command{ .describe, .{ .key = &missing }, .{ .next = .{} } }) |command|
        try t.expectError(error.AccessDenied, caller.read(&transaction, &output, .{ .table = .{ .reader = &reader, .command = command } }));
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(description.basis.authority.table), .owner = role } });
    // Independent authenticated host advances the original transaction. Old
    // readers must fail on its revision, not silently attach to the new one.
    var peer = try Transaction.borrowed(transaction.state, transaction.journal);
    const name = try c.TableAuthority.Name.init("read_savepoint");
    _ = try peer.apply(client, .{ .savepoint = .{ .operation = operation(client, 642530), .action = .{ .create = name }, .steps = 8 } });
    try stale(&caller, &transaction, &output, next);
    const reloaded = try recovery.load(recovery.identity.?);
    transaction.deinit();
    transaction = reloaded;
    for ([_]@FieldType(c.DirectTransactionSavepoint.Request, "action"){ .{ .rollback = name }, .{ .release = name } }, 0..) |action, index| {
        var old = (try caller.read(&transaction, &output, open)).opened;
        defer old.deinit();
        var control = (try caller.call(&transaction, .{ .savepoint = .{ .operation = operation(client, 642531 + index), .action = action, .steps = 1 } })).savepoint;
        if (control.completed == null) try t.expectError(error.TransactionSessionPending, caller.read(&transaction, &output, .{ .table = .{ .reader = &old, .command = .describe } }));
        for (0..16) |_| {
            if (control.completed != null) break;
            control = (try caller.call(&transaction, .{ .advance = 1 })).savepoint;
        }
        try t.expect(control.completed != null);
        try stale(&caller, &transaction, &output, .{ .table = .{ .reader = &old, .command = .describe } });
    }
    // Idle readers hold neither admission nor a transport borrow. Closing data
    // admission still permits original abort and its transaction-owned cleanup.
    caller.context.beginClose();
    try t.expectError(error.ClientContextClosed, caller.read(&transaction, &output, next));
    const closed = (try caller.call(&transaction, .{ .settle = .{ .command = .abort, .steps = 64 } })).status;
    try t.expect(closed.cleanup_complete and closed.observation.decided.outcome == .aborted);
    reader.deinit();
    reader_live = false;
    caller.deinit();
    caller_live = false;
    try t.expectEqualSlices(u8, &blob, retained.row().cells[2].value.atom.bytes);
    const public = try client.call(.{ .lookup = .{ .namespace = 1, .name = "read_rows" } });
    defer public.deinit();
    try t.expectEqual(@as(u64, 0), public.value.result.lookup.?.row_count);
    std.debug.print("transaction reads: rows={d} pages={d} payload_bytes={d} output_limit={d} output_peak={d} backing_allocations={d}\n", .{ count, pages, count * blob.len, budget.limit, budget.peak, probe.counts.alloc_successes });
}
