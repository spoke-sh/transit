//! Conditional SQL name evidence over the actual HTTP catalog, including a
//! corrupted acceptance reply, name reuse and node replacement.
const std = @import("std");
const sql = @import("transit_sql");
const c = sql.catalog;
const q = @import("transit_query");
const t = std.testing;
const Ref = sql.IntentReference.Reference;
const Outcome = c.NameAssertion.Outcome;
pub const State = struct {
    unchanged: [2]Outcome,
    cancelled: Outcome,
    pending: c.NameAssertion.Binding,
    rejected: ?Outcome = null,
    created: Ref,
};
const options: q.RelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
fn bind(allocator: std.mem.Allocator, original: c.DirectTableClient, text: []const u8, operation: u64) !Ref {
    var client = original;
    var statement = try sql.Statement.prepare(allocator, &client, 1, text, .transit, .native, options);
    defer statement.deinit();
    var work = try statement.bindWrite(allocator, &client, &.{}, operation);
    defer work.deinit();
    const reference = try work.stage(client, 1);
    var bytes: [sql.IntentReference.max_bytes]u8 = undefined;
    return sql.IntentReference.decode(allocator, try sql.IntentReference.encode(reference, &bytes));
}
fn observe(client: c.DirectTableClient, ref: Ref) !c.DirectTableProtocol.Result {
    const response = try ref.operation(client, .inspect, 1);
    defer response.deinit();
    return response.value.result;
}
fn accept(client: c.DirectTableClient, ref: Ref) !Outcome {
    const response = try ref.admit(client);
    defer response.deinit();
    const result = response.value.result.name_assertion.outcome;
    _ = (try sql.Terminal.fromReference(ref, response.value.result)).?;
    return result;
}
fn mutate(client: c.DirectTableClient, ref: Ref) !void {
    try t.expect(ref == .table);
    const admitted = try ref.admit(client);
    defer admitted.deinit();
    const response = try ref.operation(client, .execute, 32);
    defer response.deinit();
    try t.expectEqual(.applied, (try sql.Terminal.fromReference(ref, response.value.result)).?.state);
}
pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient) !State {
    const original = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer original.deinit();
    const existing = try bind(allocator, client, "CREATE TABLE IF NOT EXISTS events (uninstalled TEXT)", 501);
    try t.expectEqualDeep(original.value.result.lookup.?.interpretation.interpretation, existing.name_assertion.expected.?);
    try t.expect((try observe(client, existing)).name_assertion == .not_observed);
    // The proxy loses this acceptance response. Inspection must recover it.
    try t.expectError(error.InvalidTableResponse, accept(client, existing));
    const unchanged = (try observe(client, existing)).name_assertion.outcome;
    try t.expectEqual(.unchanged, unchanged.state);
    const absent = try bind(allocator, client, "DROP TABLE IF EXISTS conditional_later", 502);
    const dropped = try accept(client, absent);
    try t.expectEqual(.unchanged, dropped.state);
    const pending = try bind(allocator, client, "DROP TABLE IF EXISTS conditional_later", 503);
    try t.expect((try observe(client, pending)).name_assertion == .not_observed);
    const cancelled = try bind(allocator, client, "DROP TABLE IF EXISTS conditional_cancelled", 504);
    const response = try cancelled.operation(client, .cancel, 1);
    defer response.deinit();
    try t.expectEqual(.cancelled, response.value.result.name_assertion.outcome.state);
    const created = try bind(allocator, client, "CREATE TABLE IF NOT EXISTS conditional_created (id BIGINT)", 505);
    try t.expect((try observe(client, created)).ddl == .not_observed);
    const current = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer current.deinit();
    try t.expectEqualDeep(original.value.result.lookup.?.position, current.value.result.lookup.?.position);
    return .{ .unchanged = .{ unchanged, dropped }, .cancelled = response.value.result.name_assertion.outcome, .pending = pending.name_assertion, .created = created };
}
pub fn verify(client: c.DirectTableClient, state: State) !void {
    for (state.unchanged) |outcome| try t.expectEqualDeep(outcome, try accept(client, .{ .name_assertion = outcome.binding }));
    try t.expectEqualDeep(state.cancelled, try accept(client, .{ .name_assertion = state.cancelled.binding }));
    if (state.rejected) |outcome| try t.expectEqualDeep(outcome, try accept(client, .{ .name_assertion = outcome.binding }));
}
pub fn recover(allocator: std.mem.Allocator, client: c.DirectTableClient, state: *State) !void {
    try verify(client, state.*);
    try t.expect((try observe(client, .{ .name_assertion = state.pending })).name_assertion == .not_observed);
    try mutate(client, try bind(allocator, client, "CREATE TABLE conditional_later (id BIGINT)", 506));
    state.rejected = try accept(client, .{ .name_assertion = state.pending });
    try t.expectEqual(.rejected, state.rejected.?.state);
    try t.expectEqual(.condition_changed, state.rejected.?.reason);
    try mutate(client, state.created);
    const now_present = try bind(allocator, client, "CREATE TABLE IF NOT EXISTS conditional_created (other TEXT)", 507);
    try t.expectEqual(.unchanged, (try accept(client, now_present)).state);
    try mutate(client, try bind(allocator, client, "DROP TABLE IF EXISTS conditional_created", 508));
    try verify(client, state.*);
    try sharedPreparation(allocator, client);
    try sharedHost(allocator, client);
}

fn sharedHost(allocator: std.mem.Allocator, client: c.DirectTableClient) !void {
    const Host = c.DirectTableBridge;
    var output = std.heap.ArenaAllocator.init(allocator);
    defer output.deinit();
    var original: Host.Session = .{ .allocator = allocator };
    const compiled = (try original.apply(&output, client, .{ .compile = .{ .namespace = 1, .operation = "513", .create_object = "1513", .sql = "CREATE TABLE host_prepared (id BIGINT PRIMARY KEY)", .dialect = .transit, .ingestion = .point } }, null)).compiled;
    const saved = try c.protocol.Json.valueAlloc(output.allocator(), Host.Action{ .load = compiled.saved });
    original.deinit();
    const loaded = try Host.parse(output.allocator(), saved);
    defer loaded.deinit();
    var recovered: Host.Session = .{ .allocator = allocator };
    defer recovered.deinit();
    const summary = (try recovered.apply(&output, client, loaded.value, null)).loaded;
    try t.expectEqualDeep(compiled.summary, summary);
    const reference = (try recovered.apply(&output, client, .{ .stage = summary.id }, null)).staged;
    try t.expect((try recovered.apply(&output, client, .{ .operation = .{ .reference = reference, .command = .inspect, .steps = 1 } }, null)).observation.ddl == .not_observed);
    _ = try recovered.apply(&output, client, .{ .admit = reference }, null);
    const accepted = (try recovered.apply(&output, client, .{ .operation = .{ .reference = reference, .command = .execute, .steps = 32 } }, null)).observation;
    try t.expect(accepted.ddl == .committed);
    const metadata = (try recovered.apply(&output, client, .{ .lookup = .{ .namespace = 1, .name = "host_prepared" } }, null)).metadata.?;
    try t.expectEqualStrings("1513", metadata.binding.interpretation.interpretation.object.object);
    try t.expectEqualStrings("0", metadata.row_count);
    const conditional = (try recovered.apply(&output, client, .{ .compile = .{ .namespace = 1, .operation = "514", .create_object = "1514", .sql = "CREATE TABLE IF NOT EXISTS host_prepared (ignored TEXT)", .dialect = .transit, .ingestion = .point } }, null)).compiled;
    const condition = (try recovered.apply(&output, client, .{ .stage = conditional.summary.id }, null)).staged;
    const unchanged = (try recovered.apply(&output, client, .{ .admit = condition }, null)).observation;
    try t.expectEqual(.unchanged, unchanged.name_assertion.outcome.state);
    try t.expectError(error.InvalidCatalogAssertion, recovered.apply(&output, client, .{ .operation = .{ .reference = condition, .command = .execute, .steps = 1 } }, null));
    const insert = (try recovered.apply(&output, client, .{ .compile = .{ .namespace = 1, .operation = "515", .create_object = null, .sql = "INSERT INTO host_prepared (id) VALUES (7)", .dialect = .transit, .ingestion = .point } }, null)).compiled;
    const inserted = (try recovered.apply(&output, client, .{ .stage = insert.summary.id }, null)).staged;
    _ = try recovered.apply(&output, client, .{ .admit = inserted }, null);
    const rows = (try recovered.apply(&output, client, .{ .operation = .{ .reference = inserted, .command = .execute, .steps = 32 } }, null)).observation.rows.committed;
    try t.expectEqualStrings("1", rows.outcome.matched);
    try t.expectEqualStrings("1", rows.outcome.affected);
    try mutate(client, try bind(allocator, client, "DROP TABLE host_prepared", 516));
    try t.expectEqualDeep(accepted, (try recovered.apply(&output, client, .{ .operation = .{ .reference = reference, .command = .inspect, .steps = 1 } }, null)).observation);
    _ = try recovered.apply(&output, client, .{ .forget = insert.summary.id }, null);
    try t.expect(recovered.active == null);
    // Recovery is independent of the ephemeral handle and keeps the same receipt.
    try t.expectEqualDeep(accepted, (try recovered.apply(&output, client, .{ .operation = .{ .reference = reference, .command = .inspect, .steps = 1 } }, null)).observation);
}

fn sharedPreparation(allocator: std.mem.Allocator, client: c.DirectTableClient) !void {
    var prepared = try c.DirectTablePreparedDdl.prepare(allocator, client, 1, "CREATE TABLE direct_prepared (id BIGINT PRIMARY KEY)", .transit, null);
    var created = try prepared.bind(allocator, client, 509, 1509);
    prepared.deinit();
    defer created.deinit();
    try t.expectEqual(@as(u64, 509), created.table.binding().identity.operation);
    try t.expectEqual(@as(u64, 1509), created.table.binding().target.object);
    var restored = try c.DirectTableIntent.restore(allocator, created.table.bytes);
    defer restored.deinit();
    const reference: Ref = .{ .table = try restored.stage(client, 1) };
    try t.expect((try observe(client, reference)).ddl == .not_observed);
    try mutate(client, reference);
    const accepted = try observe(client, reference);

    var stale = try c.DirectTablePreparedDdl.prepare(allocator, client, 1, "DROP TABLE direct_prepared", .transit, null);
    defer stale.deinit();
    try mutate(client, try bind(allocator, client, "ALTER TABLE direct_prepared ADD COLUMN note TEXT DEFAULT 'saved'", 510));
    try t.expectError(error.Conflict, stale.bind(allocator, client, 511, null));
    const after = try client.call(.{ .lookup = .{ .namespace = 1, .name = "direct_prepared" } });
    defer after.deinit();
    const metadata = after.value.result.lookup.?;
    try t.expectEqual(@as(u64, 1509), metadata.interpretation.interpretation.object.object);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var schema = try c.fuze.TableSchema.decode(allocator, try metadata.schema.decode(arena.allocator(), c.fuze.TableSchema.max_bytes));
    defer schema.deinit();
    try t.expectEqualStrings("saved", schema.schema.columns[1].default.?.value.atom.bytes);
    try mutate(client, try bind(allocator, client, "ALTER TABLE direct_prepared RENAME TO direct_prepared_renamed", 511));
    try mutate(client, try bind(allocator, client, "DROP TABLE direct_prepared_renamed", 512));
    try t.expectEqualDeep(accepted, try observe(client, reference));
}
