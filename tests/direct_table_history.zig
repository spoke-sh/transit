//! Public history retention across uncertain acquisition/closure, replacement,
//! no-op acceptance, schema evolution and retirement of the original object.
const std = @import("std");
const c = @import("transit_catalog");
const q = @import("transit_query");
const w = c.DirectTableProtocol;
const p = c.protocol;
const P = c.storage.TablePartition;
const t = std.testing;
pub const State = struct { grant: c.DirectReadDelegation, snapshot: ?w.Snapshot, initial: ?P.HistoryPoint, no_op: ?P.HistoryPoint, checkpoint: ?q.TableChangeReader.Position };
fn executor(client: c.DirectTableClient, state: State) !c.DirectTableClient {
    var result = client;
    result.delegation = state.grant;
    result.key = try p.Ed25519.KeyPair.generateDeterministic(@splat(31));
    return result;
}
fn acquisition(state: State) w.Action {
    const binding = state.grant.binding;
    return .{ .retain_history = .{ .object = binding.interpretation.object, .owner = binding.owner, .expected = binding.expected } };
}
fn status(client: c.DirectTableClient, state: State) !std.json.Parsed(w.Response) {
    return client.call(.{ .pin_status = .{ .object = state.grant.binding.interpretation.object, .owner = state.grant.binding.owner } });
}
pub fn prepare(client: c.DirectTableClient) !State {
    const current = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer current.deinit();
    const definition = current.value.result.lookup.?;
    const state: State = .{ .grant = try c.DirectReadDelegation.prepare(client, .{
        .definition = p.Growth.current_definition,
        .connection = client.connection,
        .executor = 102,
        .interpretation = definition.interpretation.interpretation,
        .expected = definition.position,
        .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 8300 },
        .retention = .history,
        .purpose = @splat(24),
    }), .snapshot = null, .initial = null, .no_op = null, .checkpoint = null };
    const delegated = try executor(client, state);
    try t.expectError(error.InvalidTableResponse, delegated.call(acquisition(state)));
    return state;
}
pub fn recover(client: c.DirectTableClient, state: *State) !void {
    const delegated = try executor(client, state.*);
    const found = try status(delegated, state.*);
    defer found.deinit();
    state.snapshot = .{ .object = state.grant.binding.interpretation.object, .handle = found.value.result.pin_state.handle.? };
    const retry = try delegated.call(acquisition(state.*));
    defer retry.deinit();
    try t.expectEqualDeep(state.snapshot.?.handle, retry.value.result.pin);
    var reader = try c.DirectTableReader.openHistoryStart(client.allocator, delegated, state.snapshot.?);
    defer reader.deinit();
    state.initial = reader.history_point.?;
    var cancelled: std.atomic.Value(bool) = .init(false);
    var backfill = try q.TableChangeReader.open(client.allocator, delegated, state.snapshot.?, state.initial.?.position, .{ .requests = 1000, .cancellation = &cancelled });
    defer backfill.deinit();
    try t.expectError(error.IncompleteTableChanges, backfill.checkpoint());
    try t.expectError(error.IncompleteTableChanges, backfill.next());
    var exhausted = try q.TableChangeReader.open(client.allocator, delegated, state.snapshot.?, state.initial.?.position, .{ .requests = 2 });
    defer exhausted.deinit();
    try t.expectError(error.QueryPageBudget, exhausted.snapshotNext());
    try t.expectEqual(@as(u64, 0), exhausted.snapshot_rows);
    cancelled.store(true, .release);
    try t.expectError(error.Cancelled, backfill.snapshotNext());
    cancelled.store(false, .release);
    try t.expectEqualDeep(state.grant.binding.expected, reader.basis.accepted);
    try rows(&reader, delegated);
    // Keep a logical no-op in the saved stream, independent of changed_lsn.
    var scratch: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    const missing = try w.Binary.encode(client.allocator, try c.fuze.Collation.encodePrimaryKeySortKey(reader.schema.schema, &.{.{ .value = .{ .atom = .{ .signed = 999 } } }}, false, &scratch));
    defer client.allocator.free(missing.base64);
    const schema_bytes = try client.allocator.alloc(u8, c.fuze.TableSchema.max_bytes);
    defer client.allocator.free(schema_bytes);
    const encoded_schema = try w.Binary.encode(client.allocator, try reader.schema.schema.encode(schema_bytes));
    defer client.allocator.free(encoded_schema.base64);
    var mutation: w.Rows = .{ .binding = .{ .definition = p.Growth.current_definition, .identity = state.grant.binding.owner, .target = state.snapshot.?.object, .action = .delete, .expected_definition = reader.basis.interpretation.interpretation, .expected_data = null, .intent = @splat(1) }, .interpretation = reader.basis.interpretation, .schema = encoded_schema, .changes = &.{.{ .delete = missing }}, .ingestion = .point };
    mutation.binding.identity.operation = 8301;
    mutation.binding.intent = try mutation.digest(client.allocator);
    const admitted = try client.call(.{ .admit_rows = mutation });
    admitted.deinit();
    const accepted = try client.call(.{ .operation = .{ .binding = mutation.binding, .command = .execute, .steps = 1 } });
    defer accepted.deinit();
    const upper = accepted.value.result.rows.committed.outcome.position;
    var at = state.initial.?.position;
    var count: usize = 0;
    var empty: usize = 0;
    while (at.next_lsn < upper.next_lsn) {
        const result = try delegated.call(.{ .history = .{ .snapshot = state.snapshot.?, .from = at, .through = upper, .frames = 1 } });
        defer result.deinit();
        const page = result.value.result.history;
        if (page.entries.len == 0) empty += 1;
        for (page.entries) |entry| {
            count += 1;
            try t.expectEqual(@as(u64, 8301), entry.receipt.binding.identity.operation);
            try t.expectEqual(@as(u64, 0), entry.receipt.outcome.affected);
            try t.expectEqual(reader.basis.changed_lsn, entry.changed_lsn);
            state.no_op = entry.point;
        }
        at = page.next;
    }
    try t.expectEqual(@as(usize, 1), count);
    try t.expect(empty >= 2);
    // Changes accepted while backfill is paused cannot alter its frozen rows.
    const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 3 } } }, .{ .value = .{ .atom = .{ .bytes = "tail" } } } };
    mutation.binding.identity.operation = 8302;
    const extra: c.fuze.TableRow.Row = .{ .identity = try c.storage.TableDmlIntent.insertIdentity(mutation.binding.identity, 0), .cells = &cells };
    const row_bytes = try client.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
    defer client.allocator.free(row_bytes);
    const encoded_row = try w.Binary.encode(client.allocator, try extra.encode(reader.schema.schema, row_bytes));
    defer client.allocator.free(encoded_row.base64);
    mutation.binding.identity.operation = 8302;
    mutation.binding.action = .insert;
    mutation.changes = &.{.{ .insert = encoded_row }};
    mutation.binding.intent = try mutation.digest(client.allocator);
    (try client.call(.{ .admit_rows = mutation })).deinit();
    const inserted = try client.call(.{ .operation = .{ .binding = mutation.binding, .command = .execute, .steps = 1 } });
    defer inserted.deinit();
    try t.expectEqual(@as(u64, 1), inserted.value.result.rows.committed.outcome.affected);
    const extra_key = try w.Binary.encode(client.allocator, try c.fuze.Collation.encodePrimaryKeySortKey(reader.schema.schema, &.{.{ .value = .{ .atom = .{ .signed = 3 } } }}, false, &scratch));
    defer client.allocator.free(extra_key.base64);
    mutation.binding.identity.operation = 8303;
    mutation.binding.action = .delete;
    mutation.changes = &.{.{ .delete = extra_key }};
    mutation.binding.intent = try mutation.digest(client.allocator);
    (try client.call(.{ .admit_rows = mutation })).deinit();
    const removed = try client.call(.{ .operation = .{ .binding = mutation.binding, .command = .execute, .steps = 1 } });
    defer removed.deinit();
    try t.expectEqual(@as(u64, 1), removed.value.result.rows.committed.outcome.affected);
    var backfilled: usize = 0;
    while (try backfill.snapshotNext()) |value| {
        var row = value;
        defer row.deinit();
        try t.expectEqual(@as(i128, @intCast(backfilled + 1)), row.row().cells[0].value.atom.signed);
        backfilled += 1;
    }
    try t.expectEqual(@as(usize, 2), backfilled);
    state.checkpoint = try backfill.checkpoint();
    try t.expectEqualDeep(state.initial.?, state.checkpoint.?.source.point);
    try t.expect(try backfill.next() == .caught_up);
    backfill.close();
    try t.expectError(error.QueryClosed, backfill.next());
}
pub fn tail(client: c.DirectTableClient, state: State, upper: p.DataLifecycle.Position) !q.TableChangeReader {
    return q.TableChangeReader.openTail(client.allocator, try executor(client, state), state.checkpoint.?, upper, .{ .requests = 10000 });
}
fn rows(reader: *c.DirectTableReader, client: c.DirectTableClient) !void {
    try t.expectEqual(@as(u64, 2), reader.basis.row_count);
    var count: usize = 0;
    while (try reader.next(client, .{ .rows = 1 })) |batch_value| {
        var batch = batch_value;
        defer batch.deinit();
        for (batch.rows[0..batch.count]) |row| {
            try t.expectEqual(@as(i128, @intCast(count + 1)), row.?.row().cells[0].value.atom.signed);
            count += 1;
        }
    }
    try t.expectEqual(@as(usize, 2), count);
    try reader.check(client);
}
pub fn verify(client: c.DirectTableClient, state: State) !void {
    const delegated = try executor(client, state);
    var original = try c.DirectTableReader.openHistory(client.allocator, delegated, .{ .object = state.snapshot.?.object, .point = state.initial.? });
    defer original.deinit();
    try rows(&original, delegated);
    var unchanged = try c.DirectTableReader.openHistory(client.allocator, delegated, .{ .object = state.snapshot.?.object, .point = state.no_op.? });
    defer unchanged.deinit();
    try rows(&unchanged, delegated);
    try t.expectEqual(original.basis.changed_lsn, unchanged.basis.changed_lsn);
    std.debug.print("Direct Table history: original and no-op sources passed\n", .{});
    const observed = try status(delegated, state);
    defer observed.deinit();
    const upper = observed.value.result.pin_state.position;
    try t.expect(observed.value.result.pin_state.retired);
    var at = state.initial.?.position;
    var dropped = false;
    var schema_changed = false;
    var no_ops: usize = 0;
    while (at.next_lsn < upper.next_lsn) {
        const response = try delegated.call(.{ .history = .{ .snapshot = state.snapshot.?, .from = at, .through = upper, .frames = 2 } });
        defer response.deinit();
        const page = response.value.result.history;
        for (page.entries) |entry| {
            if (entry.receipt.binding.identity.operation == 8301) {
                no_ops += 1;
                try t.expectEqualDeep(state.no_op.?, entry.point);
            }
            if (!std.mem.eql(u8, &entry.interpretation.schema_fingerprint, &original.basis.interpretation.schema_fingerprint)) schema_changed = true;
            if (entry.interpretation.retired) {
                try t.expect(!dropped);
                dropped = true;
                const retired = try delegated.call(.{ .history_source = .{ .object = state.snapshot.?.object, .point = entry.point } });
                defer retired.deinit();
                try t.expect(retired.value.result.history_source.source.interpretation.retired);
            }
        }
        at = page.next;
    }
    try t.expect(dropped and schema_changed);
    try t.expectEqual(@as(usize, 1), no_ops);
    std.debug.print("Direct Table history: bounded acceptance scan passed\n", .{});
    // Restarted callers decode the saved original lease/point. A row prefix
    // cannot become a checkpoint; reopening replays the complete transaction.
    var partial = try tail(client, state, upper);
    defer partial.deinit();
    var allocation_failed = false;
    for (0..1000) |_| {
        var event = try partial.next();
        if (event == .progress and partial.following != null and partial.after != null and !allocation_failed) {
            const before_cursor = partial.after;
            const before_count = partial.changes;
            var empty: [0]u8 = .{};
            var failing: std.heap.FixedBufferAllocator = .init(&empty);
            partial.allocator = failing.allocator();
            try t.expectError(error.OutOfMemory, partial.next());
            partial.allocator = client.allocator;
            try t.expectEqualDeep(before_cursor, partial.after);
            try t.expectEqual(before_count, partial.changes);
            allocation_failed = true;
        }
        if (event == .change) {
            event.change.deinit();
            try t.expectError(error.IncompleteTableChanges, partial.checkpoint());
            break;
        }
        try t.expect(event != .caught_up);
    } else return error.TableTailNotCaughtUp;
    try t.expect(allocation_failed);
    std.debug.print("Direct Table history: partial delivery and allocation failure passed\n", .{});
    for (0..2) |replay| {
        var changes = try tail(client, state, upper);
        defer changes.deinit();
        const operations = [_]u64{ 8301, 8302, 8303, 4, 5, 6, 7, 8 };
        const expected_changes = [_]u64{ 0, 1, 1, 1, 1, 1, 0, 0 };
        var transactions: usize = 0;
        var changed: u64 = 0;
        var inserted_identity: ?c.fuze.TableRow.Identity = null;
        for (0..1000) |_| {
            var event = try changes.next();
            switch (event) {
                .progress => {},
                .change => |*change| {
                    defer change.deinit();
                    changed += 1;
                    switch (transactions) {
                        1 => {
                            try t.expect(change.before == null and change.after != null);
                            try t.expectEqual(@as(i128, 3), change.after.?.row().cells[0].value.atom.signed);
                            inserted_identity = change.identity;
                        },
                        2 => {
                            try t.expect(change.before != null and change.after == null);
                            try t.expectEqualDeep(inserted_identity.?, change.identity);
                        },
                        3 => {
                            try t.expectEqual(@as(i128, 1), change.before.?.row().cells[0].value.atom.signed);
                            try t.expectEqual(@as(i128, 10), change.after.?.row().cells[0].value.atom.signed);
                            try t.expectEqualStrings("updated", change.after.?.row().cells[1].value.atom.bytes);
                        },
                        4 => {
                            try t.expect(change.after == null);
                            try t.expectEqual(@as(i128, 2), change.before.?.row().cells[0].value.atom.signed);
                        },
                        5 => {
                            try t.expectEqual(@as(usize, 2), change.before.?.row().cells.len);
                            try t.expectEqual(@as(usize, 3), change.after.?.row().cells.len);
                            try t.expect(change.after.?.row().cells[2] == .null);
                        },
                        else => return error.UnexpectedTableChange,
                    }
                },
                .transaction => |transaction| {
                    try t.expect(transactions < operations.len);
                    try t.expectEqual(operations[transactions], transaction.receipt.binding.identity.operation);
                    try t.expectEqual(expected_changes[transactions], changed);
                    try t.expectEqual(changed, transaction.changes);
                    try t.expectEqualDeep(transaction.next, try changes.checkpoint());
                    try t.expectEqualDeep(state.snapshot.?.handle, transaction.next.source.point.lease);
                    try t.expectEqual(@as(u64, 7), transaction.after.snapshot.object.object);
                    try t.expectEqual(transactions == operations.len - 1, transaction.after.interpretation.retired);
                    transactions += 1;
                    changed = 0;
                    std.debug.print("Direct Table history: replay {d} transaction {d} passed ({d} charged requests)\n", .{ replay, transactions, changes.requests });
                },
                .caught_up => break,
            }
        } else return error.TableTailNotCaughtUp;
        std.debug.print("Direct Table history: replay {d} final checkpoint passed\n", .{replay});
        try t.expectEqual(operations.len, transactions);
        try t.expectEqual(@as(u64, 0), changed);
        const checkpoint = try changes.checkpoint();
        var resumed = try q.TableChangeReader.openTail(client.allocator, delegated, checkpoint, upper, .{ .requests = 100 });
        defer resumed.deinit();
        for (0..100) |_| {
            const event = try resumed.next();
            if (event == .caught_up) break;
            try t.expect(event == .progress);
        } else return error.TableTailNotCaughtUp;
    }
}
pub fn close(client: c.DirectTableClient, state: State) !void {
    const delegated = try executor(client, state);
    try t.expectError(error.InvalidTableResponse, delegated.closeOriginalHistory(state.snapshot.?.object, state.grant.binding.owner, state.grant.binding.expected, state.snapshot.?.handle));
}
pub fn closed(client: c.DirectTableClient, state: State) !void {
    const delegated = try executor(client, state);
    const observed = try status(delegated, state);
    defer observed.deinit();
    try t.expect(observed.value.result.pin_state.released);
    try delegated.closeOriginalHistory(state.snapshot.?.object, state.grant.binding.owner, state.grant.binding.expected, state.snapshot.?.handle);
    try t.expectError(error.Conflict, delegated.call(.{ .history_source = .{ .object = state.snapshot.?.object, .point = state.initial.? } }));
    try t.expectError(error.Conflict, delegated.call(acquisition(state)));
    try t.expectError(error.Conflict, tail(client, state, state.initial.?.position));
}
