//! Real public typed caller; no node, core, backend or provider imports.
const std = @import("std");
const c = @import("transit_catalog");
const q = @import("transit_query");
const wire = c.station.client;
const p = c.protocol;
const g = p.Growth;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const t = std.testing;
const Lifecycle = @import("direct_table_lifecycle.zig");
const Conditions = @import("direct_sql_conditions.zig");
const SqlPins = @import("direct_sql_read_recovery.zig");
const Captured = @import("direct_captured_query.zig");
const Follow = @import("direct_follow_query.zig");
const Maintained = @import("direct_maintained_query.zig");
const RelationalFailures = @import("direct_relational_failures.zig");
const Predicates = @import("direct_table_predicates.zig");
const Delegation = @import("direct_table_delegation.zig");
const History = @import("direct_table_history.zig");
const Growth = @import("direct_table_growth.zig");
const Dependencies = @import("direct_dependencies.zig");
const NamedResources = @import("direct_named_resources.zig");
const sql_runtime = @import("transit_sql");
const Saved = struct { create: d.Binding, insert: d.Binding, snapshot: w.Snapshot, first: c.storage.TablePartition.Evidence, second: c.storage.TablePartition.Evidence };
const Profile = struct { dependency_growth: ?Dependencies.GrowthState = null, resource_growth: ?NamedResources.GrowthState = null, selected_login: ?u64 = null, growth: ?Growth.State = null, definition: g.Definition, catalog: c.DirectCatalog.Configuration, role: u64, saved: ?Saved = null, lifecycle: ?Lifecycle.State = null, conditions: ?Conditions.State = null, delegation: ?Delegation.State = null, history: ?History.State = null, captured: ?Captured.State = null, follow: ?Follow.State = null, maintained: ?[2]Maintained.State = null, dependencies: ?Dependencies.State = null, named_resources: ?NamedResources.State = null };
const Admin = struct {
    client: *wire.Client,
    pub fn query(self: *@This(), kind: @FieldType(p.Authorization.Query, "kind")) !g.Response {
        return self.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .authorization = .{ .kind = kind } } }, try key(17));
    }
    pub fn submit(self: *@This(), command: g.Command) !u64 {
        const identity = try self.query(.identity);
        return (try self.client.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = identity.principal_sequence + 1, .command = command }, try key(17)))).position;
    }
    pub fn change(self: *@This(), action: p.Authorization.Action) !?u64 {
        const revision = (try self.query(.identity)).body.authorization.revision;
        const id = try self.submit(.{ .authorization = .{ .begin = .{ .expected_revision = revision, .action = action } } });
        for (0..256) |_| {
            const found = (try self.query(.{ .change = id })).body.authorization.body.change;
            switch (found.status) {
                .preparing => _ = try self.submit(.{ .authorization = .{ .advance = id } }),
                .ready => _ = try self.submit(.{ .authorization = .{ .publish = id } }),
                .published => return found.created_id,
                .abandoned => return error.UnexpectedAbandonedChange,
            }
        }
        return error.AuthorizationStepBudget;
    }
};
fn key(seed: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(seed));
}
fn save(init: std.process.Init, path: []const u8, value: Profile) !void {
    const bytes = try p.Json.valueAlloc(init.arena.allocator(), value);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
}
fn provision(admin: *Admin) !Profile {
    const pid = try admin.submit(.{ .spawn = .{} });
    const resource = try admin.submit(.{ .create_resource = .{ .writer = pid, .owned = false } });
    const role = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("table-owner"), .login = true } })).?;
    _ = try admin.change(.{ .bind_credential = .{ .principal = 101, .role = role, .public_key = (try key(29)).public_key.toBytes() } });
    const executor_role = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("table-reader"), .login = true } })).?;
    _ = try admin.change(.{ .bind_credential = .{ .principal = 102, .role = executor_role, .public_key = (try key(31)).public_key.toBytes() } });
    const database_domain = (try admin.change(.{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.connect } })).?;
    const schema_domain = (try admin.change(.{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.usage | c.TableAuthority.create } })).?;
    const table_domain = (try admin.change(.{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.table_actions } })).?;
    const scope: d.Scope = .{ .realm = 42, .resource = resource, .catalog = 1 };
    const database = (try admin.change(.{ .register_object = .{ .domain = database_domain, .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
    const namespace = (try admin.change(.{ .register_object = .{ .domain = schema_domain, .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
    return .{ .definition = g.current_definition, .role = role, .catalog = .{
        .scope = scope,
        .branch = 1,
        .partition = 1,
        .audience = 100,
        .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .database = database, .initial_schema = 1, .initial_schema_authority = namespace },
        .database_name = try .init("transit"),
        .initial_schema_name = try .init("public"),
    } };
}
const columns = [_]c.fuze.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "payload", .type = .binary },
};
const schema: c.fuze.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} };
fn execute(client: c.DirectTableClient, binding: d.Binding) !w.Result {
    const response = try client.call(.{ .operation = .{ .binding = binding, .command = .execute, .steps = 32 } });
    defer response.deinit();
    // Operation results contain only fixed owning evidence.
    return response.value.result;
}
fn inspect(client: c.DirectTableClient, binding: d.Binding) !w.Result {
    const response = try client.call(.{ .operation = .{ .binding = binding, .command = .inspect, .steps = 1 } });
    defer response.deinit();
    return response.value.result;
}
fn binarySchema(allocator: std.mem.Allocator) !w.Binary {
    var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    return w.Binary.encode(allocator, try schema.encode(&bytes));
}
fn binaryRow(allocator: std.mem.Allocator, id: i64, operation: u64, payload: []const u8) !w.Binary {
    const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = id } } }, .{ .value = .{ .atom = .{ .bytes = payload } } } };
    const row: c.fuze.TableRow.Row = .{ .identity = .{ .origin = 102, .operation = operation, .ordinal = 0 }, .cells = &cells };
    const bytes = try allocator.alloc(u8, c.fuze.TableRow.max_bytes);
    defer allocator.free(bytes);
    return w.Binary.encode(allocator, try row.encode(schema, bytes));
}
fn write(init: std.process.Init, client: c.DirectTableClient, profile: *Profile) !void {
    const alloc = init.arena.allocator();
    const initialized = try client.call(.initialize);
    defer initialized.deinit();
    const intent: c.DirectCatalog.Intent = .{ .namespace = 1, .name = try .init("events"), .action = .{ .create = .{ .schema = schema, .owner = profile.role } } };
    const binding: d.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = profile.catalog.scope, .principal = 101, .operation = 1 }, .target = .{ .scope = profile.catalog.scope, .branch = 1, .object = 7 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(alloc) };
    const admitted = try client.call(.{ .admit_ddl = .{ .binding = binding, .namespace = 1, .name = "events", .action = .{ .create = .{ .owner = profile.role, .schema = try binarySchema(alloc) } } } });
    defer admitted.deinit();
    try t.expect(admitted.value.result.ddl == .admitted);
    const missing = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer missing.deinit();
    try t.expect(missing.value.result.lookup == null);
    const created = (try execute(client, binding)).ddl.committed;
    const empty = try client.call(.{ .observe = .{ .namespace = 1, .interpretation = created.resulting.interpretation, .rows = .{} } });
    defer empty.deinit();
    try t.expectEqualDeep(created.outcome.position, empty.value.result.observation.definition.position);
    try t.expectEqual(@as(usize, 0), empty.value.result.observation.page.?.rows.len);
    try t.expect(!empty.value.result.observation.page.?.more);
    var payload: [64 * 1024]u8 = undefined;
    for (&payload, 0..) |*byte, i| byte.* = @truncate(i);
    var work: w.Rows = .{ .binding = binding, .interpretation = created.resulting, .schema = try binarySchema(alloc), .changes = &.{.{ .insert = try binaryRow(alloc, 1, 2, &payload) }}, .ingestion = .point };
    work.binding.action = .insert;
    work.binding.identity.operation = 2;
    work.binding.expected_definition = created.resulting.interpretation;
    work.binding.intent = try work.digest(alloc);
    const row_admitted = try client.call(.{ .admit_rows = work });
    defer row_admitted.deinit();
    // The independent proxy corrupts the first successful execution reply.
    try t.expectError(error.InvalidTableResponse, execute(client, work.binding));
    const first = (try inspect(client, work.binding)).rows.committed;
    try t.expectEqual(@as(u64, 1), first.outcome.affected);
    const pinned = try client.call(.{ .pin = .{ .object = binding.target, .owner = .{ .scope = profile.catalog.scope, .principal = 101, .operation = 90 }, .expected = first.outcome.position } });
    defer pinned.deinit();
    const snapshot: w.Snapshot = .{ .object = binding.target, .handle = pinned.value.result.pin };
    work.binding.identity.operation = 3;
    work.binding.expected_data = first.outcome.position;
    work.changes = &.{.{ .insert = try binaryRow(alloc, 2, 3, "bulk") }};
    work.ingestion = .bulk;
    work.binding.intent = try work.digest(alloc);
    const bulk_admitted = try client.call(.{ .admit_rows = work });
    defer bulk_admitted.deinit();
    try t.expect(bulk_admitted.value.result.rows == .admitted);
    const second = (try execute(client, work.binding)).rows.committed;
    try t.expectEqual(@as(u64, 2), second.outcome.live_rows);
    profile.saved = .{ .create = binding, .insert = work.binding, .snapshot = snapshot, .first = first, .second = second };
}
fn recover(init: std.process.Init, client: c.DirectTableClient, admin: *Admin, profile: Profile, directory: std.Io.Dir) !void {
    const saved = profile.saved.?;
    try t.expectEqualDeep(saved.second, (try inspect(client, saved.insert)).rows.committed);
    try t.expectEqualDeep(saved.second, (try execute(client, saved.insert)).rows.committed);
    var reader = try c.DirectTableReader.open(init.gpa, client, saved.snapshot);
    defer reader.deinit();
    try t.expectEqual(@as(u64, 1), reader.basis.row_count);
    try t.expectEqualDeep(saved.first.outcome.position, reader.basis.accepted);
    var page = (try reader.next(client, .{})).?;
    defer page.deinit();
    try t.expect(page.complete);
    try t.expectEqual(@as(usize, 1), page.count);
    const value = page.rows[0].?.row().cells[1].value.atom.bytes;
    try t.expectEqual(@as(usize, 64 * 1024), value.len);
    for (value, 0..) |byte, i| try t.expectEqual(@as(u8, @truncate(i)), byte);
    try t.expect(try reader.next(client, .{}) == null);
    var foreign = client;
    foreign.connection.role = profile.role;
    try t.expectError(error.CatalogIdentityConflict, reader.check(foreign));
    const current = try client.call(.{ .lookup = .{ .namespace = 1, .name = "events" } });
    defer current.deinit();
    try t.expectEqual(@as(u64, 2), current.value.result.lookup.?.row_count);
    const observed_action: w.Action = .{ .observe = .{ .namespace = 1, .interpretation = current.value.result.lookup.?.interpretation.interpretation, .rows = .{ .rows = 1 } } };
    const observed = try client.call(observed_action);
    defer observed.deinit();
    const read_authority = try client.call(.{ .read_authority = saved.snapshot.object });
    defer read_authority.deinit();
    try t.expectEqualDeep(observed.value.result.observation.authority, read_authority.value.result.read_authority);
    try t.expectEqualDeep(current.value.result.lookup.?, observed.value.result.observation.definition);
    const observed_page = observed.value.result.observation.page.?;
    try t.expectEqual(@as(usize, 1), observed_page.rows.len);
    try t.expect(observed_page.more);
    const observed_bytes = try observed_page.rows[0].decode(init.gpa, c.fuze.TableRow.max_bytes);
    defer init.gpa.free(observed_bytes);
    var observed_row = try c.fuze.TableRow.decode(init.gpa, schema, observed_bytes);
    defer observed_row.deinit();
    try t.expectEqual(@as(i128, 1), observed_row.row().cells[0].value.atom.signed);
    try t.expectEqual(@as(usize, 64 * 1024), observed_row.row().cells[1].value.atom.bytes.len);
    const all = try client.call(.{ .observe = .{ .namespace = 1, .interpretation = current.value.result.lookup.?.interpretation.interpretation, .rows = .{} } });
    defer all.deinit();
    try t.expectEqual(@as(usize, 2), all.value.result.observation.page.?.rows.len);
    try t.expect(!all.value.result.observation.page.?.more);
    const metadata = try client.call(.{ .observe = .{ .namespace = 1, .interpretation = current.value.result.lookup.?.interpretation.interpretation, .rows = null } });
    defer metadata.deinit();
    try t.expect(metadata.value.result.observation.page == null);
    try t.expectEqualDeep(current.value.result.lookup.?, metadata.value.result.observation.definition);
    const suffix_request: w.Action = .{ .read_current = .{ .namespace = 1, .interpretation = current.value.result.lookup.?.interpretation.interpretation, .expected = current.value.result.lookup.?.position, .selection = .{ .rows = .{ .after = null, .limits = .{ .rows = 1 } } } } };
    const prefix = try client.call(suffix_request);
    defer prefix.deinit();
    try t.expectEqualDeep(current.value.result.lookup.?, prefix.value.result.current_read.definition);
    try t.expectEqual(@as(usize, 1), prefix.value.result.current_read.selection.rows.rows.len);
    try t.expectEqualDeep(observed_row.identity, prefix.value.result.current_read.selection.rows.next.?);
    var continuation = suffix_request;
    continuation.read_current.selection.rows.after = prefix.value.result.current_read.selection.rows.next;
    const suffix = try client.call(continuation);
    defer suffix.deinit();
    try t.expectEqual(@as(usize, 1), suffix.value.result.current_read.selection.rows.rows.len);
    try t.expect(suffix.value.result.current_read.selection.rows.next == null);
    const suffix_bytes = try suffix.value.result.current_read.selection.rows.rows[0].decode(init.gpa, c.fuze.TableRow.max_bytes);
    defer init.gpa.free(suffix_bytes);
    var last_row = try c.fuze.TableRow.decode(init.gpa, schema, suffix_bytes);
    defer last_row.deinit();
    try t.expectEqual(@as(i128, 2), last_row.row().cells[0].value.atom.signed);
    continuation.read_current.selection.rows.after = last_row.identity;
    const terminal = try client.call(continuation);
    defer terminal.deinit();
    try t.expectEqual(@as(usize, 0), terminal.value.result.current_read.selection.rows.rows.len);
    try t.expect(terminal.value.result.current_read.selection.rows.next == null);
    var storage_key: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    var point_request = suffix_request;
    point_request.read_current.selection = .{ .key = try w.Binary.encode(init.arena.allocator(), try observed_row.row().storageKey(schema, &storage_key)) };
    const point = try client.call(point_request);
    defer point.deinit();
    try t.expectEqualStrings(observed_page.rows[0].base64, point.value.result.current_read.selection.key.?.base64);
    var stale_request = suffix_request;
    stale_request.read_current.expected = saved.first.outcome.position;
    try t.expectError(error.Conflict, client.call(stale_request));
    const pin_state = try client.call(.{ .pin_status = .{ .object = saved.snapshot.object, .owner = saved.snapshot.handle.owner } });
    defer pin_state.deinit();
    try t.expectEqualDeep(saved.snapshot.handle, pin_state.value.result.pin_state.handle.?);
    try t.expect(!pin_state.value.result.pin_state.released);
    const namespaces = try client.call(.{ .namespaces = .{ .after = null } });
    defer namespaces.deinit();
    try t.expectEqual(@as(u64, 1), namespaces.value.result.namespaces.entries[0].?.id);
    try t.expect(namespaces.value.result.namespaces.entries[1] == null and namespaces.value.result.namespaces.next == null);
    var assistance_arena = std.heap.ArenaAllocator.init(init.gpa);
    defer assistance_arena.deinit();
    const source_hint = try q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = "SELECT id FROM eve", .cursor = 18, .generation = 1 });
    var source_found = false;
    for (source_hint.items) |item| if (item.kind == .source and std.mem.eql(u8, item.text, "\"events\"")) {
        source_found = true;
    };
    try t.expect(source_found);
    const column_hint = try q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = "SELECT i FROM events", .cursor = 8, .generation = 2 });
    var column_found = false;
    for (column_hint.items) |item| if (item.kind == .column and std.mem.eql(u8, item.text, "\"id\"")) {
        column_found = true;
    };
    try t.expect(column_found);
    try t.expectEqual(q.Assistance.Coverage.complete, column_hint.coverage);
    try t.expectEqual(q.Assistance.Status.ready, column_hint.status);
    try t.expect(column_hint.resource_revision == null);
    const local_statement = "SELECT id FROM events; SELECT i FROM events";
    const local_cursor: u16 = @intCast(std.mem.indexOf(u8, local_statement, "; SELECT i").? + "; SELECT i".len);
    const local_hint = try q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = local_statement, .cursor = local_cursor, .generation = 4 });
    try t.expectEqual(@as(u16, local_cursor - 1), local_hint.range.?.start);
    try t.expectEqual(local_cursor, local_hint.range.?.end);
    try t.expectEqualStrings("\"id\"", local_hint.items[0].text);
    const inside = try q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = "SELECT 'i", .cursor = 9, .generation = 5 });
    try t.expectEqual(q.Assistance.Status.inside_text, inside.status);
    try t.expectEqual(@as(usize, 0), inside.items.len);
    const missing = try q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = "SELECT i FROM missing", .cursor = 8, .generation = 6 });
    try t.expectEqual(q.Assistance.Status.unsupported, missing.status);
    try t.expectEqual(@as(usize, 0), missing.items.len);
    const starts = try q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = "", .cursor = 0, .generation = 7 });
    try t.expectEqual(q.Assistance.Coverage.limited, starts.coverage);
    try t.expectEqual(q.Assistance.max_items, starts.items.len);
    const schema_hint = try q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = ".schema\teve", .cursor = 11, .generation = 8, .mode = .console });
    try t.expectEqualStrings("\"events\"", schema_hint.items[0].text);
    for ([_]struct { text: []const u8, cursor: u16, start: u16, end: u16, expected: []const u8 }{
        .{ .text = "CREATE", .cursor = 6, .start = 6, .end = 6, .expected = "TABLE" },
        .{ .text = "create", .cursor = 6, .start = 6, .end = 6, .expected = "TABLE" },
        .{ .text = "CREATE ", .cursor = 7, .start = 7, .end = 7, .expected = "TABLE" },
        .{ .text = "CREATE;", .cursor = 6, .start = 6, .end = 6, .expected = "TABLE" },
        .{ .text = "SELECT 1; CREATE", .cursor = 16, .start = 16, .end = 16, .expected = "TABLE" },
        .{ .text = "CRE", .cursor = 3, .start = 0, .end = 3, .expected = "CREATE" },
        .{ .text = "CREATE", .cursor = 3, .start = 0, .end = 6, .expected = "CREATE" },
        .{ .text = "ALTER", .cursor = 5, .start = 5, .end = 5, .expected = "TABLE" },
        .{ .text = "DROP", .cursor = 4, .start = 4, .end = 4, .expected = "TABLE" },
        .{ .text = "DELETE", .cursor = 6, .start = 6, .end = 6, .expected = "FROM" },
        .{ .text = "INSERT", .cursor = 6, .start = 6, .end = 6, .expected = "INTO" },
    }) |case| {
        const hint = try q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = case.text, .cursor = case.cursor, .generation = 9, .mode = .console });
        try t.expectEqual(q.Assistance.Status.ready, hint.status);
        try t.expectEqual(q.Assistance.Coverage.complete, hint.coverage);
        try t.expectEqual(q.fuze.SqlInput.Range{ .start = case.start, .end = case.end }, hint.range.?);
        try t.expectEqual(@as(usize, 1), hint.items.len);
        try t.expectEqualStrings(case.expected, hint.items[0].text);
    }
    const sql_hint = try q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = "CREATE", .cursor = 6, .generation = 10 });
    try t.expectEqual(@as(u16, 0), sql_hint.range.?.start);
    try t.expectEqualStrings("CREATE", sql_hint.items[0].text);
    const options: q.DirectRelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 100, .work_steps = 10000, .source_pins = 2 }, .requests = 1000, .spill_work = 10000 };
    const clients = [_]c.DirectTableClient{ client, client };
    const prepared = try q.DirectRelationalCompilation.prepare(init.gpa, &clients, 1, "SELECT a.id AS id, COUNT(*) AS matches FROM events a LEFT JOIN events b ON a.id = b.id GROUP BY a.id", .interactive, options, null);
    defer prepared.deinit();
    const joined = try q.DirectRelationalQuery.openPreparedRetained(init.gpa, init.io, directory, "joined", client, prepared, &.{ saved.snapshot, saved.snapshot }, options, null);
    defer joined.deinit();
    const result = (try joined.next()).?;
    try t.expectEqual(@as(i128, 1), result.cells[0].value.atom.signed);
    try t.expectEqual(@as(u128, 1), result.cells[1].value.atom.unsigned);
    try t.expect(try joined.next() == null);
    try t.expect(joined.complete);
    var empty_query = try q.DirectTableQuery.openRetained(init.gpa, client, saved.snapshot, "events", "SELECT id FROM events LIMIT 0", .{ .requests = 100, .rows = 10, .result_bytes = 1024 }, null, null, .{});
    defer empty_query.deinit();
    var cleanup = try sql_runtime.ReadPins.init(init.gpa, init.io, directory, .{ .realm = 42, .owner = 100, .account = @splat(49) }, 1);
    defer cleanup.deinit();
    const cleanup_record = try cleanup.acquire(client, try c.DirectTableBinding.init(client.connection, current.value.result.lookup.?), current.value.result.lookup.?.position);
    const native_table = (try admin.query(.{ .binding = .{ .domain = profile.catalog.authority.table_domain, .key = try c.TableAuthority.binding(profile.catalog.scope, .table, 7) } })).body.authorization.body.binding.?.reference.id;
    var history_reader = try History.tail(client, profile.history.?, profile.history.?.no_op.?.position);
    defer history_reader.deinit();
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = 0 } });
    try t.expectError(error.AccessDenied, client.call(observed_action));
    try t.expectError(error.AccessDenied, client.call(suffix_request));
    try t.expectError(error.AccessDenied, client.call(point_request));
    try t.expectError(error.AccessDenied, client.call(continuation));
    try t.expectError(error.AccessDenied, client.call(.{ .read_authority = saved.snapshot.object }));
    try t.expectError(error.AccessDenied, client.call(.{ .scan = .{ .snapshot = saved.snapshot, .after = null, .limits = .{} } }));
    try t.expectError(error.AccessDenied, reader.check(client));
    try t.expectError(error.AccessDenied, history_reader.next());
    try t.expectEqualDeep(profile.history.?.checkpoint.?, history_reader.position);
    try t.expectError(error.AccessDenied, Delegation.verify(client, profile.delegation.?));
    try Delegation.deniedClosure(client, profile.delegation.?);
    try t.expectError(error.AccessDenied, reader.next(client, .{}));
    try t.expectError(error.AccessDenied, empty_query.nextBatch(8));
    try t.expectError(error.AccessDenied, joined.next());
    try t.expectError(error.AccessDenied, q.DirectTableAssistance.complete(assistance_arena.allocator(), client, 1, .{ .sql = "SELECT i FROM events", .cursor = 8, .generation = 3 }));
    try t.expectError(error.AccessDenied, client.call(.{ .pin_status = .{ .object = saved.snapshot.object, .owner = saved.snapshot.handle.owner } }));
    try t.expectError(error.AccessDenied, inspect(client, saved.insert));
    try t.expectError(error.AccessDenied, cleanup.close(client, cleanup_record));
    try t.expectError(error.AccessDenied, cleanup.tick(client, SqlPins.exactClient));
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = profile.role } });
    try t.expectEqualDeep(profile.history.?.checkpoint.?, try history_reader.checkpoint());
    (try client.call(observed_action)).deinit();
    (try client.call(suffix_request)).deinit();
    for (0..3) |_| _ = try cleanup.tick(client, SqlPins.exactClient);
    const cleanup_state = try client.call(.{ .pin_status = .{ .object = saved.snapshot.object, .owner = cleanup_record.owner() } });
    defer cleanup_state.deinit();
    try t.expect(cleanup_state.value.result.pin_state.released);
    try cleanup.close(client, cleanup_record);
    try reader.check(client);
    try reader.release(client);
    try reader.release(client);
    const released = try client.call(.{ .pin_status = .{ .object = saved.snapshot.object, .owner = saved.snapshot.handle.owner } });
    defer released.deinit();
    try t.expect(released.value.result.pin_state.released);
    try t.expectError(error.TableSnapshotReleased, reader.check(client));
    try t.expectError(error.Conflict, c.DirectTableReader.open(init.gpa, client, saved.snapshot));
    try t.expectEqual(p.ErrorCode.QueryExpired, client.service.last_rejection.?);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        var encoder: std.json.Stringify = .{ .writer = &output.interface };
        try p.Json.write((try key(17)).public_key.toBytes(), &encoder);
        return output.interface.flush();
    }
    if (args.len != 4) return error.ExpectedUrlPhaseProfile;
    var native = wire.Client.init(init.gpa, init.io, args[1]);
    defer native.deinit();
    native.timeout_ms = 30000;
    var service = wire.Client.init(init.gpa, init.io, args[1]);
    defer service.deinit();
    service.timeout_ms = 30000;
    var admin: Admin = .{ .client = &native };
    if (std.mem.eql(u8, args[2], "provision")) {
        try save(init, args[3], try provision(&admin));
    } else {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.arena.allocator(), .limited(1024 * 1024));
        var profile = (try p.Json.parseFromSlice(Profile, init.arena.allocator(), bytes)).value;
        const client: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &native, .service = &service, .connection = .{ .scope = profile.catalog.scope, .branch = 1, .audience = profile.catalog.audience, .principal = 101, .role = null }, .key = try key(29) };
        const directory = try std.Io.Dir.cwd().openDir(init.io, std.fs.path.dirname(args[3]) orelse ".", .{});
        defer directory.close(init.io);
        if (std.mem.eql(u8, args[2], "callers")) {
            (try client.call(.initialize)).deinit();
            try Conditions.callers(init.gpa, client);
        } else if (std.mem.eql(u8, args[2], "growth-write")) {
            (try client.call(.initialize)).deinit();
            profile.growth = try Growth.write(init, client, profile.role);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "growth-recover")) {
            try Growth.recover(init, client, profile.growth.?);
        } else if (std.mem.eql(u8, args[2], "dependency-growth-write")) {
            profile.dependency_growth = try Dependencies.growthWrite(client, &admin, profile.role);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "dependency-growth-recover")) {
            try Dependencies.growthRecover(client, &admin, profile.dependency_growth.?);
        } else if (std.mem.eql(u8, args[2], "resource-growth-write")) {
            const checkpoint = try std.fmt.allocPrint(init.gpa, "{s}.resource-growth", .{args[3]});
            defer init.gpa.free(checkpoint);
            profile.resource_growth = try NamedResources.growthWrite(init, client, &admin, profile.role, checkpoint);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "resource-growth-recover")) {
            try NamedResources.growthRecover(init.gpa, client, profile.resource_growth.?);
        } else if (std.mem.eql(u8, args[2], "prepared-lifetime")) {
            try @import("direct_table_prepared.zig").run(init.gpa, client, &admin, profile.role);
        } else if (std.mem.eql(u8, args[2], "count-ranges")) {
            try @import("direct_table_count_ranges.zig").run(client, &admin, profile.role);
        } else if (std.mem.eql(u8, args[2], "resource-save")) {
            var prepared_arena = std.heap.ArenaAllocator.init(init.gpa);
            defer prepared_arena.deinit();
            var preparing = client;
            preparing.allocator = prepared_arena.allocator();
            profile.named_resources = try NamedResources.prepare(preparing, &admin, profile.role);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "resource-admit")) {
            try NamedResources.admit(client, profile.named_resources.?);
        } else if (std.mem.startsWith(u8, args[2], "resource-prepare-")) {
            const index = try std.fmt.parseInt(u8, args[2]["resource-prepare-".len..], 10);
            if (index > 1) return error.UnexpectedPhase;
            try NamedResources.allocationPlan(client, profile.named_resources.?, index);
        } else if (std.mem.startsWith(u8, args[2], "resource-allocate-")) {
            const index = try std.fmt.parseInt(u8, args[2]["resource-allocate-".len..], 10);
            if (index > 1) return error.UnexpectedPhase;
            try NamedResources.allocate(client, &admin, profile.named_resources.?, index);
        } else if (std.mem.startsWith(u8, args[2], "resource-initialize-")) {
            const phase = try std.fmt.parseInt(u8, args[2]["resource-initialize-".len..], 10);
            if (phase > 2) return error.UnexpectedPhase;
            try NamedResources.initialize(init.io, client, &admin, profile.named_resources.?, phase);
        } else if (std.mem.eql(u8, args[2], "resource-publish")) {
            try NamedResources.publish(client, profile.named_resources.?);
        } else if (std.mem.eql(u8, args[2], "resource-dependency-save")) {
            profile.named_resources.?.dependencies = try NamedResources.dependencyPlan(client, profile.named_resources.?);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "resource-dependency-register")) {
            try NamedResources.dependencyUncertain(client, profile.named_resources.?, false);
        } else if (std.mem.eql(u8, args[2], "resource-dependency-recover")) {
            try NamedResources.dependencyRecover(client, &admin, profile.named_resources.?);
        } else if (std.mem.eql(u8, args[2], "resource-dependency-remove")) {
            try NamedResources.dependencyUncertain(client, profile.named_resources.?, true);
        } else if (std.mem.eql(u8, args[2], "resource-verify")) {
            try NamedResources.verify(init.io, client, &admin, profile.named_resources.?);
        } else if (std.mem.eql(u8, args[2], "dependency-prepare")) {
            var prepared_arena = std.heap.ArenaAllocator.init(init.gpa);
            defer prepared_arena.deinit();
            var preparing = client;
            preparing.allocator = prepared_arena.allocator();
            profile.dependencies = try Dependencies.prepare(preparing, &admin, profile.role);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "dependency-register")) {
            try Dependencies.uncertain(client, profile.dependencies.?.host_registration);
        } else if (std.mem.eql(u8, args[2], "dependency-recover")) {
            try Dependencies.recover(client, &admin, profile.dependencies.?);
        } else if (std.mem.eql(u8, args[2], "dependency-remove")) {
            try Dependencies.uncertain(client, profile.dependencies.?.host_removal);
        } else if (std.mem.eql(u8, args[2], "dependency-final")) {
            try Dependencies.finish(client, profile.dependencies.?);
        } else if (std.mem.eql(u8, args[2], "write")) {
            try write(init, client, &profile);
            profile.delegation = try Delegation.prepare(client);
            try SqlPins.prepare(init, client, directory);
            profile.conditions = try Conditions.prepare(init.gpa, client);
            profile.history = try History.prepare(client);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "recover")) {
            try Delegation.recover(client, &profile.delegation.?);
            std.debug.print("Direct Table recovery: retained delegation passed\n", .{});
            try History.recover(client, &profile.history.?);
            std.debug.print("Direct Table recovery: history checkpoint passed\n", .{});
            try SqlPins.recover(init, client, directory);
            std.debug.print("Direct Table recovery: SQL pin journal passed\n", .{});
            try Conditions.recover(init.gpa, client, &profile.conditions.?);
            std.debug.print("Direct Table recovery: conditional names passed\n", .{});
            try recover(init, client, &admin, profile, directory);
            std.debug.print("Direct Table recovery: original receipts and reads passed\n", .{});
            var lifecycle = try Lifecycle.evolve(init.gpa, init.io, directory, client, profile.role, profile.delegation.?);
            defer lifecycle.deinit();
            profile.lifecycle = lifecycle.value;
            std.debug.print("Direct Table recovery: lifecycle evolution passed\n", .{});
            try Delegation.verify(client, profile.delegation.?);
            std.debug.print("Direct Table recovery: delegated readback passed\n", .{});
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "history-position")) {
            var reader = try History.tail(client, profile.history.?, profile.history.?.checkpoint.?.source.point.position);
            defer reader.deinit();
            _ = try reader.checkpoint();
        } else if (std.mem.eql(u8, args[2], "lifecycle")) {
            try Delegation.verify(client, profile.delegation.?);
            std.debug.print("Direct Table lifecycle: delegated readback passed\n", .{});
            try Lifecycle.verify(init.gpa, client, profile.lifecycle.?, true);
            std.debug.print("Direct Table lifecycle: retained sources and closure passed\n", .{});
            try Conditions.verify(client, profile.conditions.?);
            std.debug.print("Direct Table lifecycle: conditional names passed\n", .{});
            try History.verify(client, profile.history.?);
            std.debug.print("Direct Table lifecycle: history replay passed\n", .{});
            try History.close(client, profile.history.?);
            std.debug.print("Direct Table lifecycle: history closure passed\n", .{});
            try Delegation.close(client, profile.delegation.?);
            std.debug.print("Direct Table lifecycle: delegation closure passed\n", .{});
        } else if (std.mem.eql(u8, args[2], "delegated-closed")) {
            try Delegation.closed(client, profile.delegation.?);
            try History.closed(client, profile.history.?);
        } else if (std.mem.eql(u8, args[2], "follow-prepare")) {
            profile.follow = try Follow.prepare(init, client, &admin, profile.role);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "follow-resume")) {
            try Follow.recover(init, client, &admin, profile.follow.?);
        } else if (std.mem.eql(u8, args[2], "follow-example")) {
            try Follow.example(init, client, &admin, profile.follow.?);
        } else if (std.mem.eql(u8, args[2], "installed-authorization")) {
            profile.selected_login = try @import("direct_table_authorization.zig").installed(client, &admin, profile.role);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "installed-deny") or std.mem.eql(u8, args[2], "installed-allow")) {
            try @import("direct_table_authorization.zig").selection(&admin, profile.selected_login.?, profile.role, std.mem.eql(u8, args[2], "installed-allow"));
        } else if (std.mem.eql(u8, args[2], "authorization-lifetime")) {
            try @import("direct_table_authorization.zig").run(init, client, &admin, profile.role);
        } else if (std.mem.eql(u8, args[2], "capture-prepare")) {
            profile.captured = try Captured.prepare(init, client, &admin, profile.role);
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "capture-resume")) {
            try Captured.recover(init, client, &admin, profile.captured.?);
        } else if (std.mem.eql(u8, args[2], "capture-relational")) {
            var fresh = client;
            fresh.key = try key(59);
            try Captured.relational(init, fresh, &admin);
        } else if (std.mem.eql(u8, args[2], "capture-named")) {
            var fresh = client;
            if (profile.captured != null) fresh.key = try key(59);
            try Captured.namedRelational(init, fresh, &admin);
        } else if (std.mem.eql(u8, args[2], "caller-deny") or std.mem.eql(u8, args[2], "caller-allow")) {
            const allow = std.mem.eql(u8, args[2], "caller-allow");
            const identity = try admin.client.query(.{ .realm = 42, .principal = 101, .kind = .{ .authorization = .{ .kind = .identity } } }, try key(if (allow) 55 else 29));
            _ = try admin.change(.{ .rotate_credential = .{ .principal = 101, .expected_epoch = identity.body.authorization.body.identity.credential_epoch, .public_key = (try key(if (allow) 29 else 55)).public_key.toBytes() } });
        } else if (std.mem.eql(u8, args[2], "initialize")) {
            (try client.call(.initialize)).deinit();
        } else if (std.mem.eql(u8, args[2], "board-inspector")) {
            const role = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("board-inspector"), .login = true } })).?;
            _ = try admin.change(.{ .bind_credential = .{ .principal = 104, .role = role, .public_key = (try key(12)).public_key.toBytes() } });
            _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = role, .privileges = p.permission(.inspect) } });
        } else if (std.mem.eql(u8, args[2], "maintained-initialize")) {
            (try client.call(.initialize)).deinit();
            _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = profile.role, .privileges = p.permission(.inspect) } });
        } else if (std.mem.eql(u8, args[2], "maintained-prepare")) {
            var fresh = client;
            if (profile.captured != null) fresh.key = try key(59);
            profile.maintained = .{ try Maintained.prepare(init, fresh, &admin, profile.role, false), try Maintained.prepare(init, fresh, &admin, profile.role, true) };
            try save(init, args[3], profile);
        } else if (std.mem.eql(u8, args[2], "maintained-resume") or std.mem.eql(u8, args[2], "maintained-backfill")) {
            var fresh = client;
            if (profile.captured != null) fresh.key = try key(59);
            for (profile.maintained.?) |state| try Maintained.recover(init, fresh, &admin, state, std.mem.eql(u8, args[2], "maintained-backfill"));
        } else if (std.mem.startsWith(u8, args[2], "relational-failure-")) {
            var fresh = client;
            if (profile.captured != null) fresh.key = try key(59);
            try RelationalFailures.run(init, fresh, &admin, profile.role, std.meta.stringToEnum(RelationalFailures.Case, args[2]["relational-failure-".len..]) orelse return error.UnknownProofPhase);
        } else if (std.mem.startsWith(u8, args[2], "unified-boundary-")) {
            var fresh = client;
            fresh.key = try key(if (profile.captured != null) 59 else 29);
            const boundaries = @import("direct_unified_boundaries.zig");
            try boundaries.run(init, fresh, &admin, profile.role, std.meta.stringToEnum(boundaries.Case, args[2]["unified-boundary-".len..]) orelse return error.UnknownProofPhase);
        } else if (std.mem.startsWith(u8, args[2], "capacity-captured-")) {
            const capacity = @import("direct_relational_capacity.zig");
            const path = std.fs.path.dirname(args[3]) orelse ".";
            const command = args[2]["capacity-captured-".len..];
            if (std.mem.eql(u8, command, "status")) {
                var encoder: std.json.Stringify = .{ .writer = &output.interface };
                try p.Json.write(try capacity.status(init, client, path), &encoder);
                return output.interface.flush();
            }
            try capacity.run(init, client, &admin, profile.role, path, std.meta.stringToEnum(capacity.Mode, command) orelse return error.UnknownProofPhase);
        } else if (std.mem.eql(u8, args[2], "capacity-exchange-status")) {
            var encoder: std.json.Stringify = .{ .writer = &output.interface };
            try p.Json.write(try @import("direct_relational_exchanges.zig").status(init, client, std.fs.path.dirname(args[3]) orelse "."), &encoder);
            return output.interface.flush();
        } else if (std.mem.eql(u8, args[2], "capture-exchange-workers")) {
            var fresh = client;
            fresh.key = try key(if (profile.captured != null) 59 else 29);
            try @import("direct_exchange_workers.zig").run(init, fresh, &admin, profile.role);
        } else if (std.mem.eql(u8, args[2], "capture-exchanges") or std.mem.eql(u8, args[2], "capture-exchanges-prepare") or std.mem.eql(u8, args[2], "capture-exchanges-resume") or std.mem.eql(u8, args[2], "capture-exchanges-pressure")) {
            var fresh = client;
            fresh.key = try key(if (profile.captured != null) 59 else 29);
            const mode: @import("direct_relational_exchanges.zig").Mode = if (std.mem.endsWith(u8, args[2], "-prepare")) .prepare else if (std.mem.endsWith(u8, args[2], "-resume")) .recover else if (std.mem.endsWith(u8, args[2], "-pressure")) .pressure else .all;
            try @import("direct_relational_exchanges.zig").run(init, fresh, &admin, profile.role, std.fs.path.dirname(args[3]) orelse ".", mode);
        } else if (std.mem.eql(u8, args[2], "capture-source-pages")) {
            var fresh = client;
            if (profile.captured != null) fresh.key = try key(59);
            try Captured.sourcePages(init, fresh, &admin, profile.role);
            try Predicates.run(init, fresh, &admin, profile.role);
        } else if (std.mem.eql(u8, args[2], "capture-uncertain-pin") or std.mem.eql(u8, args[2], "capture-uncertain-release")) {
            profile.captured = try Captured.uncertain(init, client, &admin, profile.captured.?, std.mem.eql(u8, args[2], "capture-uncertain-pin"));
            try save(init, args[3], profile);
        } else return error.UnknownProofPhase;
    }
    try output.interface.print("Direct Table {s}: passed\n", .{args[2]});
    try output.interface.flush();
}
