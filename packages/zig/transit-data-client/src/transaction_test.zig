const std = @import("std");
const t = std.testing;
const data = @import("root.zig");
const c = data.catalog;
const Transaction = data.Transaction;
const Recovery = data.TransactionRecovery;
const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .audience = 4, .principal = 5, .role = null };
fn initial() Transaction.State {
    return .{
        .begin = .{ .key = .{ .definition = c.protocol.Growth.current_definition, .connection = connection, .account = @splat(6), .token = @splat(7) }, .fingerprint = @splat(8), .operation = .{ .scope = connection.scope, .principal = 5, .operation = 9 }, .namespace = 1, .mode = .serializable, .selection = .authorized_catalog_objects, .limits = c.DirectTransaction.default_limits, .deadline = null, .execution = null, .budget = .{} },
        .settlement = .{ .scope = connection.scope, .principal = 5, .operation = 10 },
    };
}
fn refuse(_: *anyopaque, _: Transaction.State, _: Transaction.State, _: Transaction.Event) !void {
    return error.InjectedJournalFailure;
}

test "transaction owns target memory and rejects unsafe state before any dispatch" {
    try t.checkAllAllocationFailures(t.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            var state = initial();
            var targets = [_]c.protocol.Transaction.Target{.{ .object = .{ .scope = connection.scope, .branch = 1, .object = 11 }, .kind = .kv, .partition = null }};
            state.begin.selection = .{ .explicit_objects = &targets };
            var sentinel: u8 = 0;
            var transaction = try Transaction.init(allocator, state, .{ .context = &sentinel, .save = refuse });
            defer transaction.deinit();
            targets[0].object.object = 12;
            try t.expectEqual(@as(u64, 11), transaction.state.begin.selection.explicit_objects[0].object.object);
        }
    }.run, .{});
    var state = initial();
    state.settlement = state.begin.operation;
    try t.expectError(error.InvalidTransactionSession, state.validate());
    state = initial();
    state.last_statement = state.begin.limits.statements + 1;
    try t.expectError(error.InvalidTransactionSession, state.validate());
}

test "journal refusal prevents transport mutation and context close preserves explicit control" {
    var context = try data.Context.init(t.allocator, t.io, .{ .catalogs = 2, .active = .{ .data = 1, .control = 1 } });
    defer {
        context.close(.none) catch unreachable;
        context.deinit() catch unreachable;
    }
    const handle = try context.openCatalog(.{ .url = "http://127.0.0.1:1", .connection = connection, .timeout_ms = 100 }, @splat(1));
    var sentinel: u8 = 0;
    var transaction = try Transaction.init(t.allocator, initial(), .{ .context = &sentinel, .save = refuse });
    defer transaction.deinit();
    const refused = try context.callTransaction(handle, &transaction, .begin);
    try t.expectEqual(error.InjectedJournalFailure, refused.value.failure.cause);
    try t.expect(refused.attempt.mutation == null);
    context.beginClose();
    try t.expectError(error.ClientContextClosed, context.callTransaction(handle, &transaction, .begin));
    const control = try context.callTransaction(handle, &transaction, .{ .settle = .{ .command = .abort } });
    try t.expectEqual(error.InjectedJournalFailure, control.value.failure.cause);
    try t.expect(control.attempt.mutation == null);
    try t.expect(transaction.state.command == null);
}

test "transaction journal reopens exact controls and rejects stale or foreign checkpoints" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const state = initial();
    const identity = try Recovery.key(state.begin);
    const request: c.DirectTransactionSavepoint.Request = .{
        .transaction = .{ .begin = state.begin.operation, .branch = 1 },
        .operation = .{ .scope = connection.scope, .principal = 5, .operation = 12 },
        .sequence = 1,
        .basis = .{ .partition = 13, .next_lsn = 14 },
        .action = .{ .create = try .init("checkpoint") },
    };
    {
        var store = try data.LocalRecoveryStore.open(t.allocator, t.io, tmp.dir, "transactions", .{ .record_bytes = 16384 });
        defer store.deinit();
        var recovery = try Recovery.init(t.allocator, &store);
        defer recovery.deinit();
        var transaction = try recovery.create(state);
        defer transaction.deinit();
        var next = state;
        next.control = request;
        try transaction.journal.save(transaction.journal.context, state, next, .control);
        var foreign = next;
        foreign.settlement.operation += 1;
        try t.expectError(error.RecoveryKeyConflict, transaction.journal.save(transaction.journal.context, next, foreign, .control));
    }
    {
        var store = try data.LocalRecoveryStore.open(t.allocator, t.io, tmp.dir, "transactions", .{ .record_bytes = 16384 });
        defer store.deinit();
        var recovery = try Recovery.init(t.allocator, &store);
        defer recovery.deinit();
        // Repeating create loads the existing pending control, never resets it.
        var transaction = try recovery.create(state);
        defer transaction.deinit();
        try t.expectEqualDeep(request, transaction.state.control.?);
        try t.expectEqual(@as(u64, 0), transaction.state.last_control);
        var stale = try Recovery.init(t.allocator, &store);
        defer stale.deinit();
        var second = try stale.load(identity);
        defer second.deinit();
        var next = transaction.state;
        next.control = null;
        next.last_control = 1;
        try transaction.journal.save(transaction.journal.context, transaction.state, next, .control_complete);
        next.command = .abort;
        try t.expectError(error.RecoveryRevisionConflict, second.journal.save(second.journal.context, second.state, next, .settlement));
        var reloaded = try stale.load(identity);
        defer reloaded.deinit();
        try t.expect(reloaded.state.control == null);
        try t.expectEqual(@as(u64, 1), reloaded.state.last_control);
        try t.expect(reloaded.state.command == null);
        // Reloading the same adapter cannot let its older context overwrite
        // progress merely because the adapter now knows the newer CAS revision.
        try t.expectError(error.RecoveryRevisionConflict, second.journal.save(second.journal.context, second.state, next, .settlement));
    }
}
