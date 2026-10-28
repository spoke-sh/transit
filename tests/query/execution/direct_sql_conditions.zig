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
const options: q.direct.DirectRelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
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
    try callers(allocator, client);
}

pub fn callers(allocator: std.mem.Allocator, client: c.DirectTableClient) !void {
    try sharedPreparation(allocator, client);
    try sharedHost(allocator, client);
    try sharedTypedHost(allocator, client);
    try sharedAdministration(allocator, client);
}

fn hostNamespace(arena: *std.heap.ArenaAllocator, session: *c.DirectTableBridge.Session, client: c.DirectTableClient, binding: c.DirectCatalogAdministration.NamespaceBinding) !c.DirectCatalogAdministration.NamespaceOperation {
    _ = try session.apply(arena, client, .{ .administration = .{ .namespace_operation = .{ .binding = binding, .command = .admit, .steps = 1 } } }, null);
    for (0..64) |_| {
        const result = (try session.apply(arena, client, .{ .administration = .{ .namespace_operation = .{ .binding = binding, .command = .execute, .steps = 32 } } }, null)).administration.namespace_observation.operation;
        if (result.phase != .admitted) return result;
    }
    return error.TableOperationPending;
}
fn sharedAdministration(allocator: std.mem.Allocator, client: c.DirectTableClient) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const Host = c.DirectTableBridge;
    var session: Host.Session = .{ .allocator = allocator };
    defer session.deinit();
    const binding = (try session.apply(&arena, client, .{ .administration = .{ .compile_namespace = .{ .namespace = 1, .operation = "530", .create_namespace = 43, .sql = "CREATE SCHEMA host_namespace" } } }, null)).administration.namespace_binding;
    const preview = (try session.apply(&arena, client, .{ .administration = .{ .preview_namespace = binding } }, null)).administration.namespace_preview;
    try t.expectEqual(.none, preview.reason);
    const action: Host.Action = .{ .administration = .{ .namespace_operation = .{ .binding = binding, .command = .inspect, .steps = 1 } } };
    const bytes = try c.protocol.Json.valueAlloc(arena.allocator(), action);
    const restored = try Host.parse(allocator, bytes);
    defer restored.deinit();
    try t.expect((try session.apply(&arena, client, restored.value, null)).administration.namespace_observation == .not_observed);
    const created = try hostNamespace(&arena, &session, client, restored.value.administration.namespace_operation.binding);
    try t.expectEqual(.applied, created.phase);
    try t.expectEqual(@as(u64, 43), created.resulting.?.id);
    const rename = (try session.apply(&arena, client, .{ .administration = .{ .compile_namespace = .{ .namespace = 1, .operation = "531", .create_namespace = null, .sql = "ALTER SCHEMA host_namespace RENAME TO host_renamed" } } }, null)).administration.namespace_binding;
    try t.expectEqual(.applied, (try hostNamespace(&arena, &session, client, rename)).phase);
    var stale = rename;
    stale.operation = "532";
    stale.action = .drop;
    try t.expectEqual(.stale_definition, (try session.apply(&arena, client, .{ .administration = .{ .preview_namespace = stale } }, null)).administration.namespace_preview.reason);
    const drop = (try session.apply(&arena, client, .{ .administration = .{ .compile_namespace = .{ .namespace = 1, .operation = "532", .create_namespace = null, .sql = "DROP SCHEMA host_renamed" } } }, null)).administration.namespace_binding;
    try t.expectEqual(.applied, (try hostNamespace(&arena, &session, client, drop)).phase);
    try t.expectEqualDeep(created, (try session.apply(&arena, client, restored.value, null)).administration.namespace_observation.operation);
    try t.expect(session.active == null);
}

fn applyHost(arena: *std.heap.ArenaAllocator, session: *c.DirectTableBridge.Session, client: c.DirectTableClient, compiled: c.DirectTableBridge.Compiled) !c.DirectTableValues.Observation {
    const reference = (try session.apply(arena, client, .{ .stage = compiled.summary.id }, null)).staged;
    var state = (try session.apply(arena, client, .{ .admit = reference }, null)).observation;
    for (0..64) |_| {
        switch (state) {
            .name_assertion => return state,
            inline .ddl, .rows => |value| if (value == .committed) return state else try t.expect(value == .admitted),
        }
        state = (try session.apply(arena, client, .{ .operation = .{ .reference = reference, .command = .execute, .steps = 32 } }, null)).observation;
    }
    return error.TableOperationPending;
}
fn sharedTypedHost(allocator: std.mem.Allocator, client: c.DirectTableClient) !void {
    const Host = c.DirectTableBridge;
    var output = std.heap.ArenaAllocator.init(allocator);
    defer output.deinit();
    const a = output.allocator();
    var session: Host.Session = .{ .allocator = allocator };
    defer session.deinit();
    const schema: c.fuze.TableSchema.Schema = .{ .object = 1517, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64, .nullable = false }, .{ .id = 2, .name = "payload", .type = .utf8 } }, .primary_key = &.{1} };
    var request: c.DirectTableTyped.Request = .{ .definition = c.protocol.Growth.current_definition, .namespace = 1, .operation = "517", .name = "host_typed", .action = .{ .create = .{ .schema = try c.fuze.TableSchemaJson.foreignInto(a, schema), .if_not_exists = false } } };
    const created = (try session.apply(&output, client, .{ .prepare = request }, null)).compiled;
    const proposal = (try session.apply(&output, client, .{ .preview = created.summary.id }, null)).preview.ddl;
    try t.expectEqual(.none, proposal.reason);
    try t.expect(proposal.current == null);
    try t.expectEqualDeep(proposal, (try session.apply(&output, client, .{ .preview = created.summary.id }, null)).preview.ddl);
    _ = try applyHost(&output, &session, client, created);
    var metadata = (try session.apply(&output, client, .{ .lookup = .{ .namespace = 1, .name = request.name } }, null)).metadata.?;
    const payload = try a.alloc(u8, 32 * 1024);
    @memset(payload, 'x');
    var assignments: [9][2]c.TableLowering.Assignment = undefined;
    var rows: [9][]const c.TableLowering.Assignment = undefined;
    for (&assignments, &rows, 0..) |*row, *slice, i| {
        row.* = .{ .{ .column = "1", .value = .{ .cell = .{ .value = .{ .atom = .{ .signed = try std.fmt.allocPrint(a, "{d}", .{i + 1}) } } } } }, .{ .column = "2", .value = .{ .cell = .{ .value = .{ .atom = .{ .utf8 = payload } } } } } };
        slice.* = row;
    }
    request.operation = "518";
    request.action = .{ .mutate = .{ .basis = metadata.binding, .mutation = .{ .action = .{ .insert = &rows }, .predicate = null }, .ingestion = .bulk } };
    const wire = try c.protocol.Json.valueAlloc(a, Host.Action{ .prepare = request });
    try t.expect(wire.len > c.protocol.max_body);
    const decoded = try Host.parse(a, wire);
    defer decoded.deinit();
    const inserted = (try session.apply(&output, client, decoded.value, null)).compiled;
    const preview = (try session.apply(&output, client, .{ .preview = inserted.summary.id }, null)).preview.rows;
    try t.expectEqual(.none, preview.reason);
    try t.expectEqualStrings("0", preview.current.row_count);
    try t.expectEqualDeep(preview, (try session.apply(&output, client, .{ .preview = inserted.summary.id }, null)).preview.rows);
    // Constructing this recovery identity performs no staging or admission.
    const unseen = try c.DirectTableValues.Reference.foreign(a, try session.active.?.work.table.reference(1));
    try t.expect((try session.apply(&output, client, .{ .operation = .{ .reference = .{ .table = unseen }, .command = .inspect, .steps = 1 } }, null)).observation.rows == .not_observed);
    const accepted = (try applyHost(&output, &session, client, inserted)).rows.committed;
    try t.expectEqualStrings("9", accepted.outcome.affected);
    const current = try client.call(.{ .lookup = .{ .namespace = 1, .name = request.name } });
    defer current.deinit();
    const source = current.value.result.lookup.?;
    const read = try client.call(.{ .read_current = .{ .namespace = 1, .interpretation = source.interpretation.interpretation, .expected = source.position, .selection = .{ .rows = .{ .after = null, .limits = .{ .rows = 1 } } } } });
    defer read.deinit();
    const prefix = read.value.result.current_read.selection.rows;
    var row = try c.fuze.TableRow.decode(allocator, schema, try prefix.rows[0].decode(a, c.fuze.TableRow.max_bytes));
    defer row.deinit();
    try t.expectEqualStrings(payload, row.row().cells[1].value.atom.bytes);
    metadata = (try session.apply(&output, client, .{ .lookup = .{ .namespace = 1, .name = request.name } }, null)).metadata.?;
    const stale = metadata.binding;
    request.operation = "519";
    request.action = .{ .alter = .{ .basis = metadata.binding, .change = .{ .add = .{ .name = "note", .type = .utf8, .nullable = true, .default = .{ .value = .{ .atom = .{ .utf8 = "typed" } } }, .max_characters = null, .encoding = .plain, .collation = .none } } } };
    _ = try applyHost(&output, &session, client, (try session.apply(&output, client, .{ .prepare = request }, null)).compiled);
    const old_insert = (try session.apply(&output, client, .{ .load = inserted.saved }, null)).loaded;
    try t.expectEqual(.stale_definition, (try session.apply(&output, client, .{ .preview = old_insert.id }, null)).preview.rows.reason);
    request.operation = "520";
    request.action = .{ .drop = .{ .basis = stale, .if_exists = false } };
    try t.expectError(error.TableDefinitionChanged, session.apply(&output, client, .{ .prepare = request }, null));
    metadata = (try session.apply(&output, client, .{ .lookup = .{ .namespace = 1, .name = request.name } }, null)).metadata.?;
    request.action = .{ .rename = .{ .basis = metadata.binding, .name = "host_typed_renamed" } };
    _ = try applyHost(&output, &session, client, (try session.apply(&output, client, .{ .prepare = request }, null)).compiled);
    request.name = "host_typed_renamed";
    metadata = (try session.apply(&output, client, .{ .lookup = .{ .namespace = 1, .name = request.name } }, null)).metadata.?;
    request.operation = "521";
    request.action = .{ .drop = .{ .basis = metadata.binding, .if_exists = false } };
    _ = try applyHost(&output, &session, client, (try session.apply(&output, client, .{ .prepare = request }, null)).compiled);
    request.operation = "522";
    request.action = .{ .drop = .{ .basis = null, .if_exists = true } };
    const absent = (try session.apply(&output, client, .{ .prepare = request }, null)).compiled;
    const condition = (try session.apply(&output, client, .{ .preview = absent.summary.id }, null)).preview.name_assertion;
    try t.expect(condition.matches and condition.current == null);
    try t.expectEqualDeep(condition, (try session.apply(&output, client, .{ .preview = absent.summary.id }, null)).preview.name_assertion);
    try t.expect((try session.apply(&output, client, .{ .operation = .{ .reference = .{ .name_assertion = absent.saved.name_assertion }, .command = .inspect, .steps = 1 } }, null)).observation.name_assertion == .not_observed);
    try t.expectEqual(.unchanged, (try applyHost(&output, &session, client, absent)).name_assertion.outcome.state);
    const retired = (try session.apply(&output, client, .{ .load = inserted.saved }, null)).loaded;
    try t.expectEqual(.object_conflict, (try session.apply(&output, client, .{ .preview = retired.id }, null)).preview.rows.reason);
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
    const capabilities = (try recovered.apply(&output, client, .{ .catalog = .capabilities }, null)).catalog.capabilities;
    try t.expectEqual(c.protocol.Growth.current_definition, capabilities.definition);
    const description = (try recovered.apply(&output, client, .{ .catalog = .describe }, null)).catalog.description;
    try t.expectEqualDeep(client.connection.scope, try description.configuration.scope.native());
    try t.expectEqual(client.connection.principal, description.subject.principal);
    const namespace = (try recovered.apply(&output, client, .{ .catalog = .{ .namespace = 1 } }, null)).catalog.namespace.?;
    try t.expectEqualStrings("public", namespace.name);
    const namespaces = (try recovered.apply(&output, client, .{ .catalog = .{ .namespaces = null } }, null)).catalog.namespaces;
    try t.expectEqualDeep(namespace, namespaces.entries[0].?);
    var cursor: ?c.DirectCatalogInspection.Cursor = null;
    var listed = false;
    var old_directory: c.DirectTableValues.Position = undefined;
    for (0..16) |_| {
        const page = (try recovered.apply(&output, client, .{ .catalog = .{ .tables = .{ .namespace = 1, .cursor = cursor } } }, null)).catalog.tables;
        for (page.entries) |slot| if (slot) |entry| {
            if (std.mem.eql(u8, entry.name, "host_prepared")) {
                try t.expectEqualDeep(metadata.binding.interpretation.interpretation, entry.interpretation);
                listed = true;
            }
        };
        old_directory = page.position;
        cursor = page.next;
        if (cursor == null) break;
    }
    try t.expect(listed and cursor == null);
    const policy = (try recovered.apply(&output, client, .{ .administration = .{ .compile_policy = .{ .namespace = 1, .sql = "GRANT SELECT ON TABLE public.host_prepared TO PUBLIC" } } }, null)).administration.policy_plan;
    try t.expectEqual(metadata.authorization, policy.action.authorization.grant.object.id);
    const prepared_policy = (try recovered.apply(&output, client, .{ .administration = .{ .prepare_policy = policy } }, null)).administration.policy_prepared;
    try t.expect(prepared_policy.record.change == null and prepared_policy.record.pending != null);
    try t.expectEqualDeep(policy.action.authorization, prepared_policy.record.begin.signed.request.command.authorization.begin.action);
    const policy_after = (try recovered.apply(&output, client, .{ .catalog = .describe }, null)).catalog.description;
    try t.expectEqual(policy.expected_revision, policy_after.policy_revision);
    const conditional = (try recovered.apply(&output, client, .{ .compile = .{ .namespace = 1, .operation = "514", .create_object = "1514", .sql = "CREATE TABLE IF NOT EXISTS host_prepared (ignored TEXT)", .dialect = .transit, .ingestion = .point } }, null)).compiled;
    try t.expect((try recovered.apply(&output, client, .{ .preview = conditional.summary.id }, null)).preview.name_assertion.matches);
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
    const update = (try recovered.apply(&output, client, .{ .compile = .{ .namespace = 1, .operation = "523", .create_object = null, .sql = "UPDATE host_prepared SET id = 8 WHERE id = 7", .dialect = .transit, .ingestion = .bulk } }, null)).compiled;
    const before = (try recovered.apply(&output, client, .{ .preview = update.summary.id }, null)).preview.rows;
    try t.expectEqual(.none, before.reason);
    try t.expectEqualStrings("1", before.current.row_count);
    const competing = (try recovered.apply(&output, client, .{ .compile = .{ .namespace = 1, .operation = "524", .create_object = null, .sql = "INSERT INTO host_prepared (id) VALUES (9)", .dialect = .transit, .ingestion = .point } }, null)).compiled;
    _ = try applyHost(&output, &recovered, client, competing);
    const restored_update = (try recovered.apply(&output, client, .{ .load = update.saved }, null)).loaded;
    const after = (try recovered.apply(&output, client, .{ .preview = restored_update.id }, null)).preview.rows;
    try t.expectEqual(.stale_data, after.reason);
    try t.expectEqualStrings("2", after.current.row_count);
    try t.expectEqualDeep(before.binding, after.binding);
    try mutate(client, try bind(allocator, client, "DROP TABLE host_prepared", 516));
    const invalidated: c.DirectCatalogInspection.Cursor = .{ .definition = c.protocol.Growth.current_definition, .connection = try c.DirectTableValues.Connection.foreign(output.allocator(), client.connection), .selection = .{ .tables = 1 }, .position = old_directory, .after = "1513" };
    try t.expectError(error.CatalogObservationChanged, recovered.apply(&output, client, .{ .catalog = .{ .tables = .{ .namespace = 1, .cursor = invalidated } } }, null));
    try t.expectEqualDeep(accepted, (try recovered.apply(&output, client, .{ .operation = .{ .reference = reference, .command = .inspect, .steps = 1 } }, null)).observation);
    const restored_condition = (try recovered.apply(&output, client, .{ .load = conditional.saved }, null)).loaded;
    try t.expect(!(try recovered.apply(&output, client, .{ .preview = restored_condition.id }, null)).preview.name_assertion.matches);
    _ = try recovered.apply(&output, client, .{ .forget = restored_condition.id }, null);
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
