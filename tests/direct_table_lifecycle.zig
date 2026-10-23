//! Public CRUD/DDL and retained-source checks across replacement and restart.
const std = @import("std");
const c = @import("transit_catalog");
const q = @import("transit_query");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const f = c.fuze;
const E = c.storage.TablePartition.Evidence;
const t = std.testing;
pub const State = struct { updated: E, deleted: E, altered: E, renamed: E, dropped: E, recreated: E, original: w.Snapshot, rewritten: w.Snapshot, statements: [4]E, prepared: c.DirectTableBinding };

fn execute(client: c.DirectTableClient, original: d.Binding) !w.Result {
    const response = try client.call(.{ .operation = .{ .binding = original, .command = .execute, .steps = 32 } });
    defer response.deinit();
    return response.value.result;
}
fn binding(client: c.DirectTableClient, operation: u64, action: d.Action, basis: w.Definition) d.Binding {
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation }, .target = basis.interpretation.interpretation.object, .action = action, .expected_definition = basis.interpretation.interpretation, .expected_data = basis.position, .intent = @splat(0) };
}
fn lookup(client: c.DirectTableClient, name: []const u8) !std.json.Parsed(w.Response) {
    return client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
}
fn absent(client: c.DirectTableClient, name: []const u8) !void {
    const response = try lookup(client, name);
    defer response.deinit();
    try t.expect(response.value.result.lookup == null);
}
fn pin(client: c.DirectTableClient, operation: u64, basis: w.Definition) !w.Snapshot {
    const response = try client.call(.{ .pin = .{ .object = basis.interpretation.interpretation.object, .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation }, .expected = basis.position } });
    defer response.deinit();
    return .{ .object = basis.interpretation.interpretation.object, .handle = response.value.result.pin };
}
fn rows(allocator: std.mem.Allocator, client: c.DirectTableClient, input: w.Rows) !E {
    var work = input;
    work.binding.intent = try work.digest(allocator);
    const admitted = try client.call(.{ .admit_rows = work });
    defer admitted.deinit();
    try t.expect(admitted.value.result.rows == .admitted);
    return (try execute(client, work.binding)).rows.committed;
}
fn ddl(allocator: std.mem.Allocator, client: c.DirectTableClient, input: w.Ddl) !E {
    var work = input;
    work.binding.intent = try work.digest(allocator);
    const proposed = try client.call(.{ .preview = work });
    defer proposed.deinit();
    try t.expectEqual(.none, proposed.value.result.preview.reason);
    try t.expect(proposed.value.result.preview.work != null);
    const unobserved = try client.call(.{ .operation = .{ .binding = work.binding, .command = .inspect, .steps = 1 } });
    defer unobserved.deinit();
    try t.expect(unobserved.value.result.ddl == .not_observed);
    const admitted = try client.call(.{ .admit_ddl = work });
    defer admitted.deinit();
    try t.expect(admitted.value.result.ddl == .admitted);
    return (try execute(client, work.binding)).ddl.committed;
}
fn predicateWork(allocator: std.mem.Allocator, client: c.DirectTableClient) ![4]E {
    const response = try lookup(client, "events");
    defer response.deinit();
    var basis = response.value.result.lookup.?;
    var schema = try f.TableSchema.decode(allocator, try basis.schema.decode(allocator, f.TableSchema.max_bytes));
    defer schema.deinit();
    const scratch = try allocator.alloc(u8, f.TableDmlCodec.max_bytes);
    defer allocator.free(scratch);
    const exact = binding(client, 10, .insert, basis);
    var inserts: [2]w.RowChange = undefined;
    for (&inserts, 0..) |*change, i| {
        const row: f.TableRow.Row = .{ .identity = try w.Rows.insertIdentity(exact.identity, @intCast(i)), .cells = &.{ .{ .value = .{ .atom = .{ .signed = @intCast(i + 1) } } }, .{ .value = .{ .atom = .{ .bytes = "predicate" } } } } };
        change.* = .{ .insert = try w.Binary.encode(allocator, try row.encode(schema.schema, scratch)) };
    }
    var results: [4]E = undefined;
    results[0] = try rows(allocator, client, .{ .binding = exact, .interpretation = basis.interpretation, .schema = basis.schema, .changes = &inserts, .ingestion = .point });
    basis.position = results[0].outcome.position;
    for ([_][]const u8{ "UPDATE events SET id = 3 WHERE id = 1", "DELETE FROM events WHERE id = 2", "DELETE FROM events WHERE id = 3" }, 0..) |sql, i| {
        var compiled = try f.TableDml.compile(allocator, sql, "events", schema.schema, null);
        defer compiled.deinit();
        var work: w.Statement = .{ .binding = binding(client, 11 + i, if (i == 0) .update else .delete, basis), .interpretation = basis.interpretation, .schema = basis.schema, .plan = try w.Binary.encode(allocator, try f.TableDmlCodec.encode(allocator, compiled.plan, scratch)) };
        work.binding.intent = try work.digest(allocator);
        const admitted = try client.call(.{ .admit_statement = work });
        defer admitted.deinit();
        try t.expect(admitted.value.result.rows == .admitted);
        results[i + 1] = (try execute(client, work.binding)).rows.committed;
        try t.expectEqual(@as(u64, 1), results[i + 1].outcome.matched);
        try t.expectEqual(@as(u64, 1), results[i + 1].outcome.affected);
        const repeated = try client.call(.{ .admit_statement = work });
        defer repeated.deinit();
        try t.expectEqualDeep(results[i + 1], repeated.value.result.rows.committed);
        basis.position = results[i + 1].outcome.position;
    }
    return results;
}
fn key(allocator: std.mem.Allocator, schema: f.TableSchema.Schema, id: i64) !w.Binary {
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = id } } }, .{ .value = .{ .atom = .{ .bytes = "" } } } };
    const row: f.TableRow.Row = .{ .identity = .{ .origin = 102, .operation = 1, .ordinal = 0 }, .cells = &cells };
    const scratch = try allocator.alloc(u8, f.Collation.max_sort_key_bytes);
    defer allocator.free(scratch);
    return w.Binary.encode(allocator, try row.storageKey(schema, scratch));
}
pub fn evolve(allocator: std.mem.Allocator, client: c.DirectTableClient, role: u64) !State {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const initial = try lookup(client, "events");
    defer initial.deinit();
    const prepared = try c.DirectTableBinding.init(client.connection, initial.value.result.lookup.?);
    const subject = try prepared.require(client, .read);
    try t.expectEqual(role, subject.role);
    const namespace = try client.call(.{ .namespace = 1 });
    defer namespace.deinit();
    try t.expectEqual(@as(u64, 1), namespace.value.result.namespace.?.id);
    const missing_namespace = try client.call(.{ .namespace = 2 });
    defer missing_namespace.deinit();
    try t.expect(missing_namespace.value.result.namespace == null);
    const original = try pin(client, 91, initial.value.result.lookup.?);
    var schema = try f.TableSchema.decode(alloc, try initial.value.result.lookup.?.schema.decode(alloc, f.TableSchema.max_bytes));
    defer schema.deinit();
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 10 } } }, .{ .value = .{ .atom = .{ .bytes = "updated" } } } };
    const replacement: f.TableRow.Row = .{ .identity = .{ .origin = 102, .operation = 2, .ordinal = 0 }, .cells = &cells };
    const scratch = try alloc.alloc(u8, f.TableRow.max_bytes);
    const updated = try rows(alloc, client, .{ .binding = binding(client, 4, .update, initial.value.result.lookup.?), .interpretation = initial.value.result.lookup.?.interpretation, .schema = initial.value.result.lookup.?.schema, .ingestion = .point, .changes = &.{.{ .update = .{ .key = try key(alloc, schema.schema, 1), .row = try w.Binary.encode(alloc, try replacement.encode(schema.schema, scratch)) } }} });
    try t.expectEqual(@as(u64, 1), updated.outcome.matched);
    try t.expectEqual(@as(u64, 1), updated.outcome.affected);
    _ = try prepared.require(client, .update);
    const after_update = try lookup(client, "events");
    defer after_update.deinit();
    const deleted = try rows(alloc, client, .{ .binding = binding(client, 5, .delete, after_update.value.result.lookup.?), .interpretation = after_update.value.result.lookup.?.interpretation, .schema = after_update.value.result.lookup.?.schema, .ingestion = .bulk, .changes = &.{.{ .delete = try key(alloc, schema.schema, 2) }} });
    try t.expectEqual(@as(u64, 1), deleted.outcome.affected);
    try t.expectEqual(@as(u64, 1), deleted.outcome.live_rows);
    const after_delete = try lookup(client, "events");
    defer after_delete.deinit();
    const altered = try ddl(alloc, client, .{ .binding = binding(client, 6, .alter, after_delete.value.result.lookup.?), .namespace = 1, .name = "events", .action = .{ .alter = .{ .add = .{ .name = "extra", .type = .int64, .nullable = true, .default = null, .max_characters = null, .encoding = .plain, .collation = .none } } } });
    const after_alter = try lookup(client, "events");
    defer after_alter.deinit();
    try t.expectError(error.Conflict, prepared.require(client, .read));
    const rewritten = try pin(client, 92, after_alter.value.result.lookup.?);
    // The pin advances physical/control progress; the inspected logical basis
    // still permits the conditional rename.
    const renamed = try ddl(alloc, client, .{ .binding = binding(client, 7, .rename, after_alter.value.result.lookup.?), .namespace = 1, .name = "events", .action = .{ .rename = "renamed" } });
    try absent(client, "events");
    const after_rename = try lookup(client, "renamed");
    defer after_rename.deinit();
    try t.expectEqual(@as(u64, 7), after_rename.value.result.lookup.?.interpretation.interpretation.object.object);
    const dropped = try ddl(alloc, client, .{ .binding = binding(client, 8, .drop, after_rename.value.result.lookup.?), .namespace = 1, .name = "renamed", .action = .drop });
    try t.expect(dropped.resulting.retired);
    try absent(client, "renamed");
    var new_schema = schema.schema;
    new_schema.object = 8;
    var create_binding = binding(client, 9, .create, initial.value.result.lookup.?);
    create_binding.target.object = 8;
    create_binding.expected_definition = null;
    create_binding.expected_data = null;
    const recreated = try ddl(alloc, client, .{ .binding = create_binding, .namespace = 1, .name = "events", .action = .{ .create = .{ .owner = role, .schema = try w.Binary.encode(alloc, try new_schema.encode(scratch)) } } });
    const state: State = .{ .updated = updated, .deleted = deleted, .altered = altered, .renamed = renamed, .dropped = dropped, .recreated = recreated, .original = original, .rewritten = rewritten, .statements = try predicateWork(alloc, client), .prepared = prepared };
    try verify(allocator, client, state, false);
    return state;
}
pub fn verify(allocator: std.mem.Allocator, client: c.DirectTableClient, state: State, release: bool) !void {
    try t.expectError(error.AccessDenied, state.prepared.require(client, .read));
    for (state.statements) |result| {
        const response = try client.call(.{ .operation = .{ .binding = result.binding, .command = .inspect, .steps = 1 } });
        defer response.deinit();
        try t.expectEqualDeep(result, response.value.result.rows.committed);
    }
    // SQL uses the retained source binding, including after live name reuse.
    const limits: q.DirectTableQuery.Limits = .{ .requests = 100, .rows = 10, .result_bytes = 1024 * 1024 };
    var too_few_requests = limits;
    too_few_requests.requests = 2;
    try t.expectError(error.QueryPageBudget, q.DirectTableQuery.openRetained(allocator, client, state.original, "events", "SELECT id FROM events", too_few_requests, null, null, .{}));
    {
        var query = try q.DirectTableQuery.openRetained(allocator, client, state.original, "events", "SELECT payload FROM events WHERE id = 1 LIMIT 1", limits, null, null, .{});
        defer query.deinit();
        var batch = try query.nextBatch(8);
        defer batch.deinit();
        try t.expect(batch.complete and batch.len == 1);
        try t.expectEqual(@as(usize, 64 * 1024), batch.rows[0].?.cells[0].value.atom.bytes.len);
        try t.expectEqualDeep(state.original, query.source().snapshot);
        query.close();
        try t.expectError(error.QueryClosed, query.nextBatch(8));
    }
    {
        var query = try q.DirectTableQuery.openRetained(allocator, client, state.original, "events", "SELECT COUNT(*) AS total FROM events", limits, null, null, .{});
        defer query.deinit();
        var batch = try query.nextBatch(8);
        defer batch.deinit();
        try t.expect(batch.complete and batch.len == 1);
        try t.expectEqual(@as(u64, 2), batch.rows[0].?.cells[0].value.atom.unsigned);
    }
    {
        var small = limits;
        small.result_bytes = 1024;
        var query = try q.DirectTableQuery.openRetained(allocator, client, state.original, "events", "SELECT payload FROM events WHERE id = 1", small, null, null, .{});
        defer query.deinit();
        try t.expectError(error.QueryResultBudget, query.nextBatch(8));
        try t.expectError(error.FailedQuery, query.nextBatch(8));
    }
    const replacement = try lookup(client, "events");
    defer replacement.deinit();
    try t.expectEqual(@as(u64, 8), replacement.value.result.lookup.?.interpretation.interpretation.object.object);
    try t.expectEqual(@as(u64, 0), replacement.value.result.lookup.?.row_count);
    if (release) {
        const empty = try pin(client, 93, replacement.value.result.lookup.?);
        var reader = try c.DirectTableReader.open(allocator, client, empty);
        defer reader.deinit();
        var page = (try reader.next(client, .{})).?;
        defer page.deinit();
        try t.expect(page.complete and page.count == 0 and reader.complete);
        try t.expect(try reader.next(client, .{}) == null);
        try reader.release(client);
    }
    try absent(client, "renamed");
    for ([_]E{ state.updated, state.deleted, state.altered, state.renamed, state.dropped, state.recreated }) |evidence| {
        const result = try client.call(.{ .operation = .{ .binding = evidence.binding, .command = .inspect, .steps = 1 } });
        defer result.deinit();
        const observed = switch (result.value.result) {
            .ddl => |value| value.committed,
            .rows => |value| value.committed,
            else => return error.UnexpectedResult,
        };
        try t.expectEqualDeep(evidence, observed);
    }
    try t.expectEqualDeep(state.updated, (try execute(client, state.updated.binding)).rows.committed);
    for ([_]w.Snapshot{ state.original, state.rewritten }, 0..) |snapshot, source_index| {
        var reader = try c.DirectTableReader.open(allocator, client, snapshot);
        defer reader.deinit();
        try t.expectEqual(@as(usize, if (source_index == 0) 2 else 3), reader.schema.schema.columns.len);
        var seen: u64 = 0;
        while (try reader.next(client, .{ .rows = 1 })) |input| {
            var page = input;
            defer page.deinit();
            try t.expectEqual(@as(usize, 1), page.count);
            const row = page.rows[0].?.row();
            const id = row.cells[0].value.atom.signed;
            const payload = row.cells[1].value.atom.bytes;
            if (source_index == 0) {
                try t.expect(id == 1 or id == 2);
                if (id == 1) {
                    try t.expectEqual(@as(usize, 64 * 1024), payload.len);
                    for (payload, 0..) |byte, i| try t.expectEqual(@as(u8, @truncate(i)), byte);
                } else try t.expectEqualStrings("bulk", payload);
            } else {
                try t.expectEqual(@as(i64, 10), id);
                try t.expectEqualStrings("updated", payload);
                try t.expect(row.cells[2] == .null);
                try t.expectEqualDeep(f.TableRow.Identity{ .origin = 102, .operation = 2, .ordinal = 0 }, row.identity);
            }
            seen += 1;
        }
        try t.expectEqual(@as(u64, if (source_index == 0) 2 else 1), seen);
        if (release) try reader.release(client);
    }
}
