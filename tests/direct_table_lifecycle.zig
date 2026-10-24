//! Public CRUD/DDL and retained-source checks across replacement and restart.
const std = @import("std");
const c = @import("transit_catalog");
const q = @import("transit_query");
const sql_runtime = @import("transit_sql");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const f = c.fuze;
const E = c.storage.TablePartition.Evidence;
const t = std.testing;
pub const State = struct { updated: E, deleted: E, altered: E, renamed: E, dropped: E, recreated: E, original: w.Snapshot, rewritten: w.Snapshot, statements: [4]E, intents: [4]w.Binary, unsubmitted: w.Binary, staged: c.DirectTableIntent.Reference, prepared: c.DirectTableBinding, codecs: CodecState, namespaces: NamespaceState };
const NamespaceState = struct { created: c.DirectNamespace.Operation, renamed: c.DirectNamespace.Operation, dropped: c.DirectNamespace.Operation, retained: w.Snapshot, statements: [5]c.DirectNamespace.Operation };
const CodecState = struct { snapshots: [2]w.Snapshot, rejected: d.Binding };
pub const OwnedState = struct {
    arena: std.heap.ArenaAllocator,
    value: State,
    pub fn deinit(self: *OwnedState) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

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
    var saved = try c.DirectTableIntent.create(allocator, client.connection, .{ .ddl = work });
    defer saved.deinit();
    const staged = try saved.stage(client, work.namespace);
    const after_stage = try saved.operation(client, .inspect, 1);
    defer after_stage.deinit();
    try t.expect(after_stage.value.result.ddl == .not_observed);
    const admitted = try staged.admit(client);
    defer admitted.deinit();
    try t.expect(admitted.value.result.ddl == .admitted);
    return (try execute(client, work.binding)).ddl.committed;
}
const PredicateWork = struct { outcomes: [4]E, intents: [4]w.Binary, unsubmitted: w.Binary, staged: c.DirectTableIntent.Reference };
fn preparedReads(allocator: std.mem.Allocator, client: c.DirectTableClient) !void {
    const before = try lookup(client, "events");
    defer before.deinit();
    var prepared = try q.DirectTablePrepared.prepare(allocator, client, 1, "SELECT payload FROM events WHERE id = $1 LIMIT 1", .transit, null);
    defer prepared.deinit();
    try t.expectEqual(@as(usize, 1), prepared.parameterTypes().len);
    const after = try lookup(client, "events");
    defer after.deinit();
    try t.expectEqualDeep(before.value.result.lookup.?.position, after.value.result.lookup.?.position);
    const source = try pin(client, 94, after.value.result.lookup.?);
    const limits: q.DirectTableQuery.Limits = .{ .requests = 100, .rows = 10, .result_bytes = 1024 };
    var insufficient = limits;
    insufficient.requests = 4;
    try t.expectError(error.QueryPageBudget, q.DirectTableQuery.openPreparedRetained(allocator, client, source, &prepared, &.{.{ .signed = 1 }}, insufficient, null, null, .{}));
    try t.expectError(error.ParameterCountMismatch, q.DirectTableQuery.openPreparedRetained(allocator, client, source, &prepared, &.{}, limits, null, null, .{}));
    for ([_]?f.Types.Values.Atom{ .{ .signed = 1 }, .{ .signed = 2 }, null }, 0..) |value, i| {
        var query = try q.DirectTableQuery.openPreparedRetained(allocator, client, source, &prepared, &.{value}, limits, null, null, .{});
        defer query.deinit();
        var batch = try query.nextBatch(8);
        defer batch.deinit();
        try t.expect(batch.complete);
        try t.expectEqual(@as(u8, if (i == 2) 0 else 1), batch.len);
        if (i == 0) try t.expectEqualStrings("predicate", batch.rows[0].?.cells[0].value.atom.bytes);
        if (i == 1) try t.expect(batch.rows[0].?.cells[0] == .null);
        try t.expectEqualDeep(source, query.source().snapshot);
    }
    const released = try client.call(.{ .release = source });
    released.deinit();
    try t.expectError(error.Conflict, q.DirectTableQuery.openPreparedRetained(allocator, client, source, &prepared, &.{.{ .signed = 1 }}, limits, null, null, .{}));
}
fn predicateWork(allocator: std.mem.Allocator, client: c.DirectTableClient) !PredicateWork {
    var result: PredicateWork = undefined;
    const statements = [_][]const u8{
        "INSERT INTO events (id, payload) VALUES ($1, $2), ($3, $4)",
        "UPDATE events SET id = $1 WHERE id = $2",
        "DELETE FROM events WHERE id = $1",
        "DELETE FROM events WHERE id = $1",
    };
    const operands = [_][]const ?f.Types.Values.Atom{
        &.{ .{ .signed = 1 }, .{ .bytes = "predicate" }, .{ .signed = 2 }, null },
        &.{ .{ .signed = 3 }, .{ .signed = 1 } },
        &.{.{ .signed = 2 }},
        &.{.{ .signed = 3 }},
    };
    for (statements, operands, 0..) |sql, values, i| {
        const before = try lookup(client, "events");
        defer before.deinit();
        var work: c.DirectTableIntent = undefined;
        {
            var prepared = try c.DirectTablePreparedDml.prepare(allocator, client, 1, sql, .transit, null);
            defer prepared.deinit();
            try t.expectEqual(values.len, prepared.parameterTypes().len);
            work = try prepared.bind(allocator, client, 10 + i, values, .point, null);
        }
        defer work.deinit();
        const after = try lookup(client, "events");
        defer after.deinit();
        try t.expectEqualDeep(before.value.result.lookup.?.position, after.value.result.lookup.?.position);
        const unobserved = try work.operation(client, .inspect, 1);
        defer unobserved.deinit();
        try t.expect(unobserved.value.result.rows == .not_observed);
        result.intents[i] = try w.Binary.encode(allocator, work.bytes);
        const staged = try work.stage(client, 1);
        try staged.requireSame(try work.stage(client, 1));
        const after_staging = try lookup(client, "events");
        defer after_staging.deinit();
        try t.expectEqualDeep(after.value.result.lookup.?.position, after_staging.value.result.lookup.?.position);
        const still_unobserved = try staged.operation(client, .inspect, 1);
        defer still_unobserved.deinit();
        try t.expect(still_unobserved.value.result.rows == .not_observed);
        var missing = staged;
        missing.content.sha256[0] ^= 1;
        try t.expectError(error.AuthorityUnavailable, missing.admit(client));
        const admitted = try staged.admit(client);
        defer admitted.deinit();
        try t.expect(admitted.value.result.rows == .admitted);
        const executed = try work.operation(client, .execute, 32);
        defer executed.deinit();
        result.outcomes[i] = executed.value.result.rows.committed;
        const count: u64 = if (i == 0) 2 else 1;
        try t.expectEqual(count, result.outcomes[i].outcome.matched);
        try t.expectEqual(count, result.outcomes[i].outcome.affected);
        var restored = try c.DirectTableIntent.restore(allocator, work.bytes);
        defer restored.deinit();
        const repeated = try (try restored.reference(1)).admit(client);
        defer repeated.deinit();
        try t.expectEqualDeep(result.outcomes[i], repeated.value.result.rows.committed);
        if (i == 0) try preparedReads(allocator, client);
    }
    var pending_template = try c.DirectTablePreparedDml.prepare(allocator, client, 1, "DELETE FROM events WHERE id = ?", .mysql, null);
    defer pending_template.deinit();
    var pending = try pending_template.bind(allocator, client, 14, &.{.{ .signed = 42 }}, .bulk, null);
    defer pending.deinit();
    result.unsubmitted = try w.Binary.encode(allocator, pending.bytes);
    result.staged = try pending.stage(client, 1);
    return result;
}
fn key(allocator: std.mem.Allocator, schema: f.TableSchema.Schema, id: i64) !w.Binary {
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = id } } }, .{ .value = .{ .atom = .{ .bytes = "" } } } };
    const row: f.TableRow.Row = .{ .identity = .{ .origin = 102, .operation = 1, .ordinal = 0 }, .cells = &cells };
    const scratch = try allocator.alloc(u8, f.Collation.max_sort_key_bytes);
    defer allocator.free(scratch);
    return w.Binary.encode(allocator, try row.storageKey(schema, scratch));
}
fn physicalColumns(allocator: std.mem.Allocator, client: c.DirectTableClient, role: u64) !CodecState {
    const schema: f.TableSchema.Schema = .{ .object = 700, .revision = 1, .next_column = 4, .columns = &.{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false, .encoding = .bitpacked },
        .{ .id = 2, .name = "body", .type = .utf8, .encoding = .ebcdic },
        .{ .id = 3, .name = "outside", .type = .utf8 },
    }, .primary_key = &.{1} };
    const scratch = try allocator.alloc(u8, f.TableRow.max_bytes);
    const encoded_schema = try w.Binary.encode(allocator, try schema.encode(scratch));
    const create: d.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 7000 }, .target = .{ .scope = client.connection.scope, .branch = 1, .object = 700 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) };
    _ = try ddl(allocator, client, .{ .binding = create, .namespace = 1, .name = "physical", .action = .{ .create = .{ .owner = role, .schema = encoded_schema } } });
    var snapshots: [2]w.Snapshot = undefined;
    for (0..2) |i| {
        const current = try lookup(client, "physical");
        defer current.deinit();
        const exact = binding(client, 7001 + i, .insert, current.value.result.lookup.?);
        const cells = [_]f.Types.Values.Cell{
            .{ .value = .{ .atom = .{ .signed = @intCast(i + 1) } } },
            .{ .value = .{ .atom = .{ .bytes = "é£¬^\x00\u{0085}ÿ" } } },
            .{ .value = .{ .atom = .{ .bytes = "€" } } },
        };
        const row: f.TableRow.Row = .{ .identity = try w.Rows.insertIdentity(exact.identity, 0), .cells = &cells };
        _ = try rows(allocator, client, .{ .binding = exact, .interpretation = current.value.result.lookup.?.interpretation, .schema = encoded_schema, .changes = &.{.{ .insert = try w.Binary.encode(allocator, try row.encode(schema, scratch)) }}, .ingestion = if (i == 0) .point else .bulk });
        const after = try lookup(client, "physical");
        defer after.deinit();
        snapshots[i] = try pin(client, 7100 + i, after.value.result.lookup.?);
    }
    const before = try lookup(client, "physical");
    defer before.deinit();
    var invalid: w.Ddl = .{ .binding = binding(client, 7003, .alter, before.value.result.lookup.?), .namespace = 1, .name = "physical", .action = .{ .alter = .{ .physical = .{ .column = 3, .encoding = .ebcdic, .collation = .none } } } };
    invalid.binding.intent = try invalid.digest(allocator);
    const admission = try client.call(.{ .admit_ddl = invalid });
    defer admission.deinit();
    try t.expect(admission.value.result.ddl == .admitted);
    const rejected = (try execute(client, invalid.binding)).ddl;
    try t.expect(rejected == .rejected);
    try t.expectEqual(.constraint, rejected.rejected.reason);
    const after = try lookup(client, "physical");
    defer after.deinit();
    try t.expectEqualDeep(before.value.result.lookup.?.interpretation, after.value.result.lookup.?.interpretation);
    try t.expectEqual(before.value.result.lookup.?.changed_lsn, after.value.result.lookup.?.changed_lsn);
    _ = try ddl(allocator, client, .{ .binding = binding(client, 7004, .alter, after.value.result.lookup.?), .namespace = 1, .name = "physical", .action = .{ .alter = .{ .physical = .{ .column = 2, .encoding = .ebcdic, .collation = .ascii_ci } } } });
    const changed = try lookup(client, "physical");
    defer changed.deinit();
    const nonbinary = try pin(client, 7102, changed.value.result.lookup.?);
    try t.expectError(error.UnsupportedTableQueryCollation, q.DirectTableQuery.openRetained(allocator, client, nonbinary, "physical", "SELECT COUNT(*) FROM physical", .{ .requests = 100, .rows = 10, .result_bytes = 4096 }, null, null, .{}));
    const released = try client.call(.{ .release = nonbinary });
    released.deinit();
    return .{ .snapshots = snapshots, .rejected = invalid.binding };
}
fn verifyPhysical(allocator: std.mem.Allocator, client: c.DirectTableClient, state: CodecState, release: bool) !void {
    const terminal = try client.call(.{ .operation = .{ .binding = state.rejected, .command = .inspect, .steps = 1 } });
    defer terminal.deinit();
    try t.expect(terminal.value.result.ddl == .rejected);
    try t.expectEqual(.constraint, terminal.value.result.ddl.rejected.reason);
    for (state.snapshots, 0..) |snapshot, i| {
        var query = try q.DirectTableQuery.openRetained(allocator, client, snapshot, "physical", "SELECT id, body, outside FROM physical WHERE id >= 1", .{ .requests = 100, .rows = 10, .result_bytes = 4096 }, null, null, .{});
        defer query.deinit();
        var batch = try query.nextBatch(8);
        defer batch.deinit();
        try t.expect(batch.complete and batch.len == i + 1);
        for (batch.rows[0..batch.len], 0..) |row, index| {
            try t.expectEqual(index + 1, row.?.cells[0].value.atom.signed);
            try t.expectEqualStrings("é£¬^\x00\u{0085}ÿ", row.?.cells[1].value.atom.bytes);
            try t.expectEqualStrings("€", row.?.cells[2].value.atom.bytes);
        }
        if (release) {
            const response = try client.call(.{ .release = snapshot });
            response.deinit();
        }
    }
}
fn administration(client: c.DirectTableClient) !void {
    const before = try lookup(client, "events");
    defer before.deinit();
    const grant = try c.DirectAuthorizationSql.compile(client, 1, "GRANT SELECT ON TABLE public.events TO PUBLIC", .{}, null);
    try t.expectEqual(before.value.result.lookup.?.authorization, grant.action.authorization.grant.object.id);
    try t.expectEqual(p.Authorization.public_role, grant.action.authorization.grant.grantee);
    try t.expectEqual(c.TableAuthority.select, grant.action.authorization.grant.privileges);
    const revoke = try c.DirectAuthorizationSql.compile(client, 1, "REVOKE SELECT ON events FROM PUBLIC CASCADE", .{}, null);
    try t.expectEqualDeep(grant.action.authorization.grant.object, revoke.action.authorization.revoke_privileges.object);
    const defaults = try c.DirectAuthorizationSql.compile(client, 1, "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO PUBLIC", .{}, null);
    try t.expectEqual(before.value.subject.role, defaults.action.authorization.default_grant.creator);
    _ = try c.DirectAuthorizationSql.compile(client, 1, "SET ROLE NONE", .{}, null);
    try t.expectError(error.QueryPageBudget, c.DirectAuthorizationSql.compile(client, 1, "GRANT SELECT ON TABLE public.events TO PUBLIC", .{ .requests = 1 }, null));
    try t.expectError(error.UnsupportedDirectSchemaAdministration, c.DirectAuthorizationSql.compile(client, 1, "CREATE SCHEMA other", .{}, null));
    try t.expectError(error.TableNotFound, c.DirectAuthorizationSql.compile(client, 1, "GRANT SELECT ON TABLE absent TO PUBLIC", .{}, null));
    const after = try lookup(client, "events");
    defer after.deinit();
    try t.expectEqual(before.value.policy_revision, after.value.policy_revision);
    try t.expectEqualDeep(before.value.result.lookup.?.position, after.value.result.lookup.?.position);
}

fn namespaceApply(client: c.DirectTableClient, binding_value: c.DirectNamespace.Binding) !c.DirectNamespace.Operation {
    (try client.call(.{ .namespace_operation = .{ .binding = binding_value, .command = .admit, .steps = 1 } })).deinit();
    for (0..128) |_| {
        const response = try client.call(.{ .namespace_operation = .{ .binding = binding_value, .command = .execute, .steps = 32 } });
        defer response.deinit();
        const operation = response.value.result.namespace_operation.operation;
        if (operation.phase != .admitted) return operation;
    }
    return error.UnfinishedNamespaceOperation;
}
const sql_options: q.RelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
fn namespaceStatement(allocator: std.mem.Allocator, original: c.DirectTableClient, text: []const u8, operation: u64) !sql_runtime.IntentReference.Reference {
    var client = original;
    var statement = try sql_runtime.Statement.prepare(allocator, &client, 1, text, .transit, .native, sql_options);
    defer statement.deinit();
    var work = try statement.bindWrite(allocator, &client, &.{}, operation);
    defer work.deinit();
    const reference = try work.stage(client, 1);
    try t.expectEqual(@as(u64, 1), reference.namespace());
    const unseen = try reference.operation(client, .inspect, 1);
    defer unseen.deinit();
    try t.expect(unseen.value.result.namespace_operation == .not_observed);
    var bytes: [sql_runtime.IntentReference.max_bytes]u8 = undefined;
    return sql_runtime.IntentReference.decode(allocator, try sql_runtime.IntentReference.encode(reference, &bytes));
}
fn namespaceStatements(allocator: std.mem.Allocator, original: c.DirectTableClient) ![5]c.DirectNamespace.Operation {
    var client = original;
    const create = try namespaceStatement(allocator, client, "CREATE SCHEMA sql_namespace", 65100);
    const created = try namespaceApply(client, create.namespace_change.binding);
    try t.expectEqual(.applied, created.phase);
    try t.expectEqual(@as(u64, 65100), created.resulting.?.id);
    var prepared = try sql_runtime.Statement.prepare(allocator, &client, 1, "DROP SCHEMA sql_namespace", .transit, .native, sql_options);
    defer prepared.deinit();
    const stale = try namespaceStatement(allocator, client, "DROP SCHEMA sql_namespace", 65101);
    const rename = try namespaceStatement(allocator, client, "ALTER SCHEMA sql_namespace RENAME TO sql_renamed", 65102);
    const renamed = try namespaceApply(client, rename.namespace_change.binding);
    try t.expectEqual(.applied, renamed.phase);
    try t.expectError(error.CatalogDefinitionChanged, prepared.bindWrite(allocator, &client, &.{}, 65105));
    const rejected = try namespaceApply(client, stale.namespace_change.binding);
    try t.expectEqual(.stale_definition, rejected.reason);
    const drop = try namespaceStatement(allocator, client, "DROP SCHEMA sql_renamed", 65103);
    const dropped = try namespaceApply(client, drop.namespace_change.binding);
    try t.expectEqual(.applied, dropped.phase);
    const replace = try namespaceStatement(allocator, client, "CREATE SCHEMA sql_renamed", 65104);
    const replaced = try namespaceApply(client, replace.namespace_change.binding);
    try t.expectEqual(.applied, replaced.phase);
    try t.expect(created.resulting.?.id != replaced.resulting.?.id);
    const operations: [5]c.DirectNamespace.Operation = .{ created, renamed, rejected, dropped, replaced };
    for (operations) |operation| {
        const reference: sql_runtime.IntentReference.Reference = .{ .namespace_change = .{ .namespace = 1, .binding = operation.binding } };
        const response = try reference.operation(client, .inspect, 1);
        defer response.deinit();
        const terminal = (try sql_runtime.Terminal.fromReference(reference, response.value.result)).?;
        try t.expectEqual(.namespace_change, terminal.kind);
        try t.expectEqual(operation.binding.namespace, terminal.object);
    }
    return operations;
}
fn namespaces(allocator: std.mem.Allocator, client: c.DirectTableClient, role: u64) !NamespaceState {
    const compiled = try c.DirectAuthorizationSql.compileNamespace(client, 1, "CREATE SCHEMA lifecycle_app", .{ .operation = 65000, .schema = 31 }, .{}, null);
    const unseen = try client.call(.{ .namespace_operation = .{ .binding = compiled, .command = .inspect, .steps = 1 } });
    defer unseen.deinit();
    try t.expect(unseen.value.result.namespace_operation == .not_observed);
    (try client.call(.{ .namespace_operation = .{ .binding = compiled, .command = .admit, .steps = 1 } })).deinit();
    try t.expectError(error.InvalidTableResponse, client.call(.{ .namespace_operation = .{ .binding = compiled, .command = .execute, .steps = 32 } }));
    const recovered = try client.call(.{ .namespace_operation = .{ .binding = compiled, .command = .inspect, .steps = 1 } });
    defer recovered.deinit();
    const created = recovered.value.result.namespace_operation.operation;
    try t.expectEqual(.applied, created.phase);
    const schema: f.TableSchema.Schema = .{ .object = 6000, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} };
    var buffer: [f.TableSchema.max_bytes]u8 = undefined;
    const created_table = try ddl(allocator, client, .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 65001 }, .target = .{ .scope = client.connection.scope, .branch = 1, .object = 6000 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) }, .namespace = 31, .name = "records", .action = .{ .create = .{ .owner = role, .schema = try w.Binary.encode(allocator, try schema.encode(&buffer)) } } });
    const definition = try client.call(.{ .lookup = .{ .namespace = 31, .name = "records" } });
    defer definition.deinit();
    const retained = try pin(client, 65002, definition.value.result.lookup.?);
    const blocked = try namespaceApply(client, try c.DirectAuthorizationSql.compileNamespace(client, 1, "DROP SCHEMA lifecycle_app", .{ .operation = 65003 }, .{}, null));
    try t.expectEqual(.dependency, blocked.reason);
    const renamed = try namespaceApply(client, try c.DirectAuthorizationSql.compileNamespace(client, 1, "ALTER SCHEMA lifecycle_app RENAME TO renamed_app", .{ .operation = 65004 }, .{}, null));
    try t.expectEqual(.applied, renamed.phase);
    // Renaming a namespace preserves the Table's stable namespace/native parent.
    const after_rename = try client.call(.{ .lookup = .{ .namespace = 31, .name = "records" } });
    defer after_rename.deinit();
    try t.expectEqualDeep(created_table.resulting, after_rename.value.result.lookup.?.interpretation);
    _ = try ddl(allocator, client, .{ .binding = binding(client, 65005, .drop, after_rename.value.result.lookup.?), .namespace = 31, .name = "records", .action = .drop });
    const dropped = try namespaceApply(client, try c.DirectAuthorizationSql.compileNamespace(client, 1, "DROP SCHEMA renamed_app", .{ .operation = 65006 }, .{}, null));
    try t.expectEqual(.applied, dropped.phase);
    const replacement = try namespaceApply(client, try c.DirectAuthorizationSql.compileNamespace(client, 1, "CREATE SCHEMA renamed_app", .{ .operation = 65007, .schema = 32 }, .{}, null));
    try t.expectEqual(@as(u64, 32), replacement.resulting.?.id);
    return .{ .created = created, .renamed = renamed, .dropped = dropped, .retained = retained, .statements = try namespaceStatements(allocator, client) };
}
fn verifyNamespaces(allocator: std.mem.Allocator, client: c.DirectTableClient, state: NamespaceState, release: bool) !void {
    for ([_]c.DirectNamespace.Operation{ state.created, state.renamed, state.dropped } ++ state.statements) |operation| {
        const response = try client.call(.{ .namespace_operation = .{ .binding = operation.binding, .command = .inspect, .steps = 1 } });
        defer response.deinit();
        try t.expectEqualDeep(operation, response.value.result.namespace_operation.operation);
    }
    const retired = try client.call(.{ .namespace = 31 });
    defer retired.deinit();
    try t.expect(retired.value.result.namespace == null);
    var reader = try c.DirectTableReader.open(allocator, client, state.retained);
    defer reader.deinit();
    var page = (try reader.next(client, .{})).?;
    defer page.deinit();
    try t.expect(page.complete and page.count == 0);
    if (release) try reader.release(client);
}

pub fn evolve(allocator: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, client: c.DirectTableClient, role: u64, delegation: @import("direct_table_delegation.zig").State) !OwnedState {
    try administration(client);
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    const codecs = try physicalColumns(alloc, client, role);
    const namespace_state = try namespaces(alloc, client, role);
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
    try @import("direct_table_delegation.zig").afterAlter(client, delegation);
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
    const relational_options: q.DirectRelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 100, .work_steps = 10000, .source_pins = 2 }, .requests = 1000, .spill_work = 10000 };
    const regrouped = try q.DirectRelationalCompilation.prepare(allocator, &.{client}, 1, "SELECT id, COUNT(*) AS total FROM renamed GROUP BY id", .interactive, relational_options, null);
    defer regrouped.deinit();
    // Rename preserves columns, but changes the prepared interpretation. The
    // old pin cannot be substituted merely because its schema hash matches.
    try t.expectError(error.RelationalSourceChanged, q.DirectRelationalQuery.openPreparedRetained(allocator, io, directory, "changed-definition", client, regrouped, &.{rewritten}, relational_options, null));
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
    const predicates = try predicateWork(alloc, client);
    const state: State = .{ .updated = updated, .deleted = deleted, .altered = altered, .renamed = renamed, .dropped = dropped, .recreated = recreated, .original = original, .rewritten = rewritten, .statements = predicates.outcomes, .intents = predicates.intents, .unsubmitted = predicates.unsubmitted, .staged = predicates.staged, .prepared = prepared, .codecs = codecs, .namespaces = namespace_state };
    try verify(allocator, client, state, false);
    return .{ .arena = arena, .value = state };
}
pub fn verify(allocator: std.mem.Allocator, client: c.DirectTableClient, state: State, release: bool) !void {
    try verifyPhysical(allocator, client, state.codecs, release);
    try verifyNamespaces(allocator, client, state.namespaces, release);
    // Current observation cannot masquerade as a retained read after DROP and
    // name reuse. The original durable snapshots below remain independently valid.
    try t.expectError(error.Conflict, client.call(.{ .observe = .{ .namespace = 1, .interpretation = state.renamed.resulting.interpretation, .rows = null } }));
    try t.expectEqual(p.ErrorCode.TableDefinitionChanged, client.service.last_rejection.?);
    const authority = try client.call(.{ .read_authority = state.original.object });
    defer authority.deinit();
    try t.expectError(error.AccessDenied, state.prepared.require(client, .read));
    for (state.statements, state.intents) |result, encoded| {
        const bytes = try encoded.decode(allocator, c.DirectTableIntent.max_bytes);
        defer allocator.free(bytes);
        var restored = try c.DirectTableIntent.restore(allocator, bytes);
        defer restored.deinit();
        try t.expectEqualDeep(result.binding, restored.binding());
        const response = try restored.operation(client, .inspect, 1);
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
        try t.expectEqualDeep(authority.value.result.read_authority, query.source().authority);
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
    const pending_bytes = try state.unsubmitted.decode(allocator, c.DirectTableIntent.max_bytes);
    defer allocator.free(pending_bytes);
    var pending = try c.DirectTableIntent.restore(allocator, pending_bytes);
    defer pending.deinit();
    try state.staged.requireSame(try pending.reference(1));
    const unseen = try pending.operation(client, .inspect, 1);
    defer unseen.deinit();
    try t.expect(unseen.value.result.rows == .not_observed);
    if (release) {
        const admitted = try state.staged.admit(client);
        defer admitted.deinit();
        try t.expect(admitted.value.result.rows == .admitted);
        const completed = try pending.operation(client, .execute, 32);
        defer completed.deinit();
        try t.expectEqual(@as(u64, 0), completed.value.result.rows.committed.outcome.matched);
        try t.expectEqual(@as(u64, 0), completed.value.result.rows.committed.outcome.affected);
        // A new pin requires the exact physical frontier, even after unchanged
        // SQL advances only operation/control history.
        const current = try lookup(client, "events");
        defer current.deinit();
        try t.expectEqual(replacement.value.result.lookup.?.changed_lsn, current.value.result.lookup.?.changed_lsn);
        const empty = try pin(client, 93, current.value.result.lookup.?);
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
