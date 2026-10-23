//! Public history retention across uncertain acquisition/closure, replacement,
//! no-op acceptance, schema evolution and retirement of the original object.
const std = @import("std");
const c = @import("transit_catalog");
const w = c.DirectTableProtocol;
const p = c.protocol;
const P = c.storage.TablePartition;
const t = std.testing;
pub const State = struct { grant: c.DirectReadDelegation, snapshot: ?w.Snapshot, initial: ?P.HistoryPoint, no_op: ?P.HistoryPoint };
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
    }), .snapshot = null, .initial = null, .no_op = null };
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
}
