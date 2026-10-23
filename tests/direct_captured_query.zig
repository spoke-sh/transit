//! Public direct Table capture with native progress in an independent resource.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const w = c.DirectTableProtocol;
const t = std.testing;
const r = q.UnifiedRecords;
const budgets: q.Bundle.Limits = .{ .pages = 64, .segments = 64, .result_bytes = 1048576 };
pub const State = struct { connection: q.UnifiedClient.Connection, bundle: w.Binary, declaration: q.Values.Source, capture: q.Values.Capture, worker_generation: u64, requester_generation: u64, job: u64 };
const Provision = struct { pid: u64, resource: u64, generation: u64 };
fn key(byte: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(byte));
}
fn provision(admin: anytype, principal: u64, byte: u8) !Provision {
    const pid = try admin.submit(.{ .spawn = .{} });
    _ = try admin.submit(.{ .grant = .{ .subject = principal, .public_key = (try key(byte)).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = pid } });
    const resource = try admin.submit(.{ .create_resource = .{ .writer = pid } });
    for ([_]u64{ 0, principal, 101 }) |subject| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = subject, .permissions = p.State.all_permissions } });
    _ = try admin.submit(.{ .associate = .{ .pid = pid, .name = try p.Value.init("state"), .resource = resource } });
    return .{ .pid = pid, .resource = resource, .generation = 1 };
}
fn send(client: c.DirectTableClient, pid: u64, payload: p.Value) !void {
    const identity = try client.authority.query(.{ .realm = 42, .principal = 101, .kind = .identity }, client.key);
    _ = try client.authority.submit(try g.sign(.{ .realm = 42, .principal = 101, .sequence = identity.principal_sequence + 1, .command = .{ .send = .{ .pid = pid, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, client.key));
}
fn sourceReader(client: c.DirectTableClient, state: State) !s.client.ResourceReader.Reader {
    const reader: s.client.ResourceReader = .{ .wire = client.authority, .realm = 42, .principal = 0, .key = try key(17) };
    return reader.open(state.connection.resource);
}
fn observed(client: c.DirectTableClient, state: State, query_client: *q.UnifiedClient, namespace: u64) !?r.Job {
    const status = (try query_client.status(namespace)) orelse return null;
    if (status.correlation == 0) return null;
    var reader = try sourceReader(client, state);
    const index = (try reader.read(r.key('i', state.connection.requester, status.correlation))) orelse return null;
    return try q.UnifiedCapture.job(&reader, try r.readIdentity(index));
}
const Hosts = struct {
    source: s.GenServer,
    requester: s.GenServer,
    behavior: q.UnifiedBehavior.Source,
    requests: q.UnifiedBehavior.Requester,
    fn init(client: c.DirectTableClient, state: State, adapter: []u8, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation) !Hosts {
        var tables = client;
        tables.connection.principal = 103;
        tables.key = try key(43);
        var result: Hosts = .{
            .source = try s.GenServer.init(.{ .client = client.authority, .realm = 42, .principal = 103, .pid = state.connection.source, .generation = state.worker_generation, .key = tables.key }, "state"),
            .requester = try s.GenServer.init(.{ .client = client.authority, .realm = 42, .principal = 104, .pid = state.connection.requester, .generation = state.requester_generation, .key = try key(47) }, "state"),
            .behavior = .{ .peer = state.connection.requester, .initializer = 101, .resources = .{ .wire = client.authority, .realm = 42, .principal = 103, .key = tables.key }, .tables = tables, .adapter = adapter, .workspace = workspace, .cancellation = cancellation },
            .requests = .{ .principal = 101, .source = state.connection.source },
        };
        result.source.failure_policy = .stop;
        result.requester.failure_policy = .stop;
        return result;
    }
    fn step(self: *Hosts, io: std.Io, admin: anytype) !void {
        const deadline: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds() + 30000);
        const requesting = try self.requester.step(self.requests.interface(), deadline);
        if (requesting == .blocked) return self.requester.handler_error orelse error.Blocked;
        const producing = try self.source.step(self.behavior.interface(), deadline);
        if (producing == .blocked) return self.source.handler_error orelse error.Blocked;
        const delivery = try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .delivery }, try key(17));
        if (delivery.body.delivery.next) |next| _ = try admin.submit(.{ .deliver = next });
    }
};
fn caller(client: c.DirectTableClient, state: State) q.UnifiedClient {
    return .{ .wire = client.authority, .tables = client, .connection = state.connection, .key = client.key };
}
fn table(allocator: std.mem.Allocator, client: c.DirectTableClient, role: u64, object: u64, name: []const u8, operation: u64, count: usize) !void {
    const schema: q.fuze.TableSchema.Schema = .{ .object = object, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} };
    const changes = try allocator.alloc(w.RowChange, count);
    defer allocator.free(changes);
    for (changes, 0..) |*change, i| {
        var row_bytes: [q.fuze.TableRow.max_bytes]u8 = undefined;
        const row: q.fuze.TableRow.Row = .{ .identity = try w.Rows.insertIdentity(.{ .scope = client.connection.scope, .principal = 101, .operation = operation + 1 }, @intCast(i)), .cells = &.{.{ .value = .{ .atom = .{ .signed = @intCast(i) } } }} };
        change.* = .{ .insert = try .encode(allocator, try row.encode(schema, &row_bytes)) };
    }
    try tableRows(allocator, client, role, name, operation, schema, changes);
}
fn tableRows(allocator: std.mem.Allocator, client: c.DirectTableClient, role: u64, name: []const u8, operation: u64, schema: q.fuze.TableSchema.Schema, changes: []const w.RowChange) !void {
    var bytes: [q.fuze.TableSchema.max_bytes]u8 = undefined;
    const encoded = try w.Binary.encode(allocator, try schema.encode(&bytes));
    var ddl: w.Ddl = .{ .binding = .{ .definition = g.current_definition, .identity = .{ .scope = client.connection.scope, .principal = 101, .operation = operation }, .target = .{ .scope = client.connection.scope, .branch = 1, .object = schema.object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) }, .namespace = 1, .name = name, .action = .{ .create = .{ .owner = role, .schema = encoded } } };
    ddl.binding.intent = try ddl.digest(allocator);
    const admission = try client.call(.{ .admit_ddl = ddl });
    defer admission.deinit();
    const result = try client.call(.{ .operation = .{ .binding = ddl.binding, .command = .execute, .steps = 32 } });
    defer result.deinit();
    const created = result.value.result.ddl.committed;
    var rows: w.Rows = .{ .binding = ddl.binding, .interpretation = created.resulting, .schema = encoded, .changes = changes, .ingestion = .point };
    rows.binding.action = .insert;
    rows.binding.identity.operation = operation + 1;
    rows.binding.expected_definition = created.resulting.interpretation;
    rows.binding.expected_data = created.outcome.position;
    rows.binding.intent = try rows.digest(allocator);
    const accepted = try client.call(.{ .admit_rows = rows });
    defer accepted.deinit();
    const inserted = try client.call(.{ .operation = .{ .binding = rows.binding, .command = .execute, .steps = 32 } });
    defer inserted.deinit();
    try t.expectEqual(@as(u64, @intCast(changes.len)), inserted.value.result.rows.committed.outcome.live_rows);
}
/// Wide/nested source pages and composite-key seeks use the same original pin
/// after ALTER, DROP and name reuse. This does not admit a captured computation.
pub fn sourcePages(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !void {
    const f = q.fuze;
    const alloc = init.arena.allocator();
    var ddl = try f.TableDdl.compile(alloc, "CREATE TABLE source_pages (id INTEGER NOT NULL, tag TEXT NOT NULL, names LIST(UTF8), a INT128, b INT128, c INT128, d INT128, e INT128, f INT128, g INT128, h INT128, i INT128, j INT128, PRIMARY KEY (id, tag))", null, null);
    defer ddl.deinit();
    const schema = try ddl.statement.create.bind(65);
    var cells: [19][13]f.Types.Values.Cell = undefined;
    var changes: [19]w.RowChange = undefined;
    const scratch = try alloc.alloc(u8, f.TableRow.max_bytes);
    for (&cells, &changes, 0..) |*row, *change, i| {
        row[0] = .{ .value = .{ .atom = .{ .signed = @intCast(i) } } };
        row[1] = .{ .value = .{ .atom = .{ .bytes = "東京" } } };
        row[2] = .{ .value = .{ .list = &.{.{ .value = .{ .atom = .{ .bytes = "Ada" } } }} } };
        for (row[3..]) |*cell| cell.* = .{ .value = .{ .atom = .{ .signed = std.math.maxInt(i128) } } };
        change.* = .{ .insert = try w.Binary.encode(alloc, try (f.TableRow.Row{ .identity = try w.Rows.insertIdentity(.{ .scope = client.connection.scope, .principal = 101, .operation = 626 }, @intCast(i)), .cells = row }).encode(schema, scratch)) };
    }
    try tableRows(alloc, client, role, "source_pages", 625, schema, &changes);
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "source_pages" } });
    defer lookup.deinit();
    const definition = lookup.value.result.lookup.?;
    var source = try q.TableSource.from(init.gpa, client.connection, definition);
    defer source.deinit();
    const acquired = try client.call(.{ .pin = .{ .object = definition.interpretation.interpretation.object, .owner = .{ .scope = client.connection.scope, .principal = 101, .operation = 627 }, .expected = definition.position } });
    defer acquired.deinit();
    const snapshot: w.Snapshot = .{ .object = definition.interpretation.interpretation.object, .handle = acquired.value.result.pin };
    const basis = try source.source.capture(init.gpa, client, snapshot);
    var alter: w.Ddl = .{ .binding = .{ .definition = g.current_definition, .identity = .{ .scope = client.connection.scope, .principal = 101, .operation = 628 }, .target = snapshot.object, .action = .alter, .expected_definition = definition.interpretation.interpretation, .expected_data = null, .intent = @splat(0) }, .namespace = 1, .name = "source_pages", .action = .{ .alter = .{ .rename = .{ .column = 3, .name = "renamed_names" } } } };
    alter.binding.intent = try alter.digest(alloc);
    const admitted = try client.call(.{ .admit_ddl = alter });
    defer admitted.deinit();
    const altered = try client.call(.{ .operation = .{ .binding = alter.binding, .command = .execute, .steps = 32 } });
    defer altered.deinit();
    alter.binding.identity.operation = 629;
    alter.binding.expected_definition = altered.value.result.ddl.committed.resulting.interpretation;
    alter.binding.action = .drop;
    alter.action = .drop;
    alter.binding.intent = try alter.digest(alloc);
    const dropping = try client.call(.{ .admit_ddl = alter });
    defer dropping.deinit();
    const dropped = try client.call(.{ .operation = .{ .binding = alter.binding, .command = .execute, .steps = 32 } });
    defer dropped.deinit();
    try t.expect(dropped.value.result.ddl.committed.resulting.retired);
    try table(alloc, client, role, 66, "source_pages", 630, 1);
    const reused = try client.call(.{ .lookup = .{ .namespace = 1, .name = "source_pages" } });
    defer reused.deinit();
    try t.expectEqual(@as(u64, 66), reused.value.result.lookup.?.interpretation.interpretation.object.object);
    for ([_][]const u8{ "SELECT names FROM source_pages WHERE id = 11 AND tag = '東京'", "SELECT names FROM source_pages WHERE id = 99 AND tag = '東京'" }, 0..) |sql, i| {
        var query = try f.TableSelect.compile(init.gpa, sql, "source_pages", source.source.row_type, try basis.fingerprint(), null);
        defer query.deinit();
        var page = try source.source.page(init.gpa, basis, try q.TableSource.Cursor.start(basis), query.plan, client);
        defer page.deinit();
        try t.expectEqual(@as(u8, @intFromBool(i == 0)), page.count);
        try t.expect(page.next.done);
        try t.expectEqual(@as(u64, 1), page.next.ordinal);
        if (i == 0) {
            try t.expectEqual(@as(i128, 11), page.engine().rows[0].cells[0].value.atom.signed);
            try t.expectEqualStrings("Ada", page.engine().rows[0].cells[2].value.list[0].value.atom.bytes);
        }
        _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(basis.retained.authority.table), .owner = 0 } });
        try t.expectError(error.CatalogDenied, source.source.page(init.gpa, basis, try q.TableSource.Cursor.start(basis), query.plan, client));
        _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(basis.retained.authority.table), .owner = role } });
    }
    var query = try f.TableSelect.compile(init.gpa, "SELECT id, tag, names, j FROM source_pages", "source_pages", source.source.row_type, try basis.fingerprint(), null);
    defer query.deinit();
    var cursor = try q.TableSource.Cursor.start(basis);
    var progress = try f.LogicalStream.Progress.start(query.plan);
    const workspace = try alloc.alloc(u8, f.LogicalArrow.working_bytes);
    const output = try alloc.alloc(u8, f.LogicalArrow.segment_bytes);
    const cancellation = std.atomic.Value(bool).init(false);
    var output_fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    while (!cursor.done) {
        var page = try source.source.page(init.gpa, basis, cursor, query.plan, client);
        defer page.deinit();
        const next = try f.LogicalStream.step(query.plan, progress, page.engine(), workspace, output, &cancellation, null);
        const part = next.segment.?;
        var decoded = try f.LogicalInspect.decode(init.gpa, try query.plan.outputSchema(&output_fields), part.bytes, part.rows, workspace);
        defer decoded.deinit();
        for (decoded.rows, 0..) |row, i| {
            try t.expectEqual(@as(i128, @intCast(cursor.scanned + i)), row.cells[0].value.atom.signed);
            try t.expectEqualStrings("東京", row.cells[1].value.atom.bytes);
            try t.expectEqualStrings("Ada", row.cells[2].value.list[0].value.atom.bytes);
            try t.expectEqual(std.math.maxInt(i128), row.cells[3].value.atom.signed);
        }
        cursor = page.next;
        progress = next.progress;
    }
    try t.expectEqual(@as(u64, 19), cursor.scanned);
    try t.expectEqual(@as(u64, 3), cursor.ordinal);
    const closed = try client.call(.{ .release = snapshot });
    defer closed.deinit();
    try t.expectError(error.SourceChanged, source.source.capture(init.gpa, client, snapshot));
}

/// Stop after committed acquisition eligibility and before any remote pin.
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !State {
    const alloc = init.arena.allocator();
    const initialized = try client.call(.initialize);
    defer initialized.deinit();
    try table(alloc, client, role, 61, "captured_input", 610, 19);
    var worker = try provision(admin, 103, 43);
    var requester = try provision(admin, 104, 47);
    _ = try admin.submit(.{ .grant_resource = .{ .resource = requester.resource, .subject = 103, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    _ = try admin.submit(.{ .associate = .{ .pid = worker.pid, .name = try p.Value.init("requests"), .resource = requester.resource, .required = false } });
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = requester.pid }, .grantee = role, .privileges = p.permission(.inspect) | p.permission(.send) } });
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = worker.pid }, .grantee = role, .privileges = p.permission(.send) } });
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = role, .privileges = p.permission(.inspect) } });
    worker.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = worker.pid } }, try key(17))).body.process.process.generation;
    requester.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = requester.pid } }, try key(17))).body.process.process.generation;
    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = 103 } });
    worker.generation += 1;
    _ = try admin.submit(.{ .own = .{ .pid = requester.pid, .expected_generation = requester.generation, .worker = 104 } });
    requester.generation += 1;
    var state: State = .{ .connection = .{ .realm = 42, .principal = 101, .source = worker.pid, .resource = worker.resource, .requester = requester.pid, .requests = requester.resource }, .bundle = undefined, .declaration = undefined, .capture = undefined, .worker_generation = worker.generation, .requester_generation = requester.generation, .job = 0 };
    try t.expect(state.connection.resource != client.connection.scope.resource);
    try send(client, worker.pid, try q.UnifiedRequest.Command.encode(.initialize));
    var initializing = caller(client, state);
    _ = try initializing.submit(try initializing.prepare(.initialize));
    const policy: q.UnifiedBehavior.PolicyChange = .{ .expected_revision = 0, .policy = .{ .peer = requester.pid, .requests = requester.resource, .revision = 1, .allow = true, .limits = budgets, .target = .{ .catalog = .{ .scope = client.connection.scope, .owner = client.connection.audience, .principal = 101 } } } };
    try send(client, worker.pid, try policy.encode());
    const adapter = try alloc.alloc(u8, q.UnifiedBehavior.adapter_bytes);
    const workspace = try alloc.alloc(u8, q.fuze.LogicalArrow.working_bytes);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    var hosts = try Hosts.init(client, state, adapter, workspace, &cancellation);
    var query_client = caller(client, state);
    for (0..100) |_| {
        try hosts.step(init.io, admin);
        var reader = try sourceReader(client, state);
        if (try q.UnifiedCapture.policy(&reader, requester.pid) != null) break;
    } else return error.QueryPolicyPending;
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "captured_input" } });
    defer lookup.deinit();
    const definition = lookup.value.result.lookup.?;
    var source = try q.TableSource.from(init.gpa, client.connection, definition);
    defer source.deinit();
    const description = try q.Bundle.fromSql(alloc, .{ .resource = client.connection.scope.resource, .source = .{ .table = source.source } }, "captured_input", "SELECT COUNT(*) AS n FROM captured_input", budgets);
    state.declaration = try q.Values.Source.fromNative(alloc, description.source);
    state.capture = .{ .executor = 103, .operation = "612", .expected = .{ .partition = try std.fmt.allocPrint(alloc, "{d}", .{definition.position.partition}), .next_lsn = try std.fmt.allocPrint(alloc, "{d}", .{definition.position.next_lsn}) } };
    const bundle = try query_client.authorizeCapture(description, try state.capture.native());
    var buffer: [q.Bundle.max_bytes]u8 = undefined;
    state.bundle = try .encode(alloc, try bundle.encode(&buffer));
    for (0..10000) |_| {
        if (try query_client.prepareNext(1, bundle)) |prepared| {
            const receipt = try query_client.submit(prepared);
            for (0..100) |_| {
                try hosts.step(init.io, admin);
                switch (try query_client.observe(receipt.position)) {
                    .committed => break,
                    .rejected => return error.QueryUploadRejected,
                    .pending => {},
                }
            } else return error.QueryUploadPending;
        } else {
            const job = try observed(client, state, &query_client, 1);
            if (job) |value| {
                if (value.phase == .acquiring) {
                    state.job = value.id;
                    const pin = try client.call(.{ .pin_status = .{ .object = bundle.retention.?.binding.interpretation.object, .owner = bundle.retention.?.binding.owner } });
                    defer pin.deinit();
                    try t.expect(pin.value.result.pin_state.handle == null);
                    return state;
                }
                if (value.phase != .admitted) return error.UnexpectedQueryPhase;
            }
            try hosts.step(init.io, admin);
        }
    }
    return error.QueryCapturePending;
}
fn replacement(admin: anytype, saved: State) !State {
    var state = saved;
    _ = try admin.submit(.{ .own = .{ .pid = state.connection.source, .expected_generation = state.worker_generation, .worker = 103 } });
    state.worker_generation += 1;
    _ = try admin.submit(.{ .own = .{ .pid = state.connection.requester, .expected_generation = state.requester_generation, .worker = 104 } });
    state.requester_generation += 1;
    return state;
}
fn renamePinned(allocator: std.mem.Allocator, client: c.DirectTableClient) !void {
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "captured_input" } });
    defer lookup.deinit();
    const definition = lookup.value.result.lookup.?;
    var ddl: w.Ddl = .{ .binding = .{ .definition = g.current_definition, .identity = .{ .scope = client.connection.scope, .principal = 101, .operation = 613 }, .target = definition.interpretation.interpretation.object, .action = .rename, .expected_definition = definition.interpretation.interpretation, .expected_data = definition.position, .intent = @splat(0) }, .namespace = 1, .name = "captured_input", .action = .{ .rename = "captured_renamed" } };
    ddl.binding.intent = try ddl.digest(allocator);
    const admission = try client.call(.{ .admit_ddl = ddl });
    defer admission.deinit();
    const result = try client.call(.{ .operation = .{ .binding = ddl.binding, .command = .execute, .steps = 32 } });
    defer result.deinit();
    try t.expectEqual(@as(u64, 2), result.value.result.ddl.committed.resulting.interpretation.revision);
}
/// A malformed success reply leaves the exact pin decision and source basis
/// intact. Stop before a native progress commit, then replace both hosts.
pub fn uncertain(init: std.process.Init, client: c.DirectTableClient, admin: anytype, saved: State, acquisition: bool) !State {
    const state = try replacement(admin, saved);
    const alloc = init.arena.allocator();
    const adapter = try alloc.alloc(u8, q.UnifiedBehavior.adapter_bytes);
    const workspace = try alloc.alloc(u8, q.fuze.LogicalArrow.working_bytes);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    var hosts = try Hosts.init(client, state, adapter, workspace, &cancellation);
    for (0..1000) |_| {
        hosts.step(init.io, admin) catch |err| {
            try t.expectEqual(error.InvalidTableResponse, err);
            var reader = try sourceReader(client, state);
            const job = try q.UnifiedCapture.job(&reader, state.job);
            try t.expectEqual(if (acquisition) r.Phase.acquiring else .captured, job.phase);
            const bundle = try q.Bundle.decode(alloc, try state.bundle.decode(alloc, q.Bundle.max_bytes));
            const grant = bundle.retention.?;
            const pin = try client.call(.{ .pin_status = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner } });
            defer pin.deinit();
            try t.expect(pin.value.result.pin_state.handle != null);
            try t.expectEqual(!acquisition, pin.value.result.pin_state.released);
            if (acquisition) {
                try t.expectError(error.IncompleteSource, q.CapturedTablePin.source(alloc, &reader, .{ .job = state.job, .source = 0 }, state.connection.source));
                // Definition changes after remote acceptance cannot retarget
                // recovery, even before the native handle has been recorded.
                try renamePinned(alloc, client);
            }
            return state;
        };
    }
    return error.MissingExpectedReplyFault;
}
/// New native generations resume the exact accepted cut after node restart.
pub fn recover(init: std.process.Init, client: c.DirectTableClient, admin: anytype, saved: State) !void {
    const state = try replacement(admin, saved);
    const alloc = init.arena.allocator();
    const adapter = try alloc.alloc(u8, q.UnifiedBehavior.adapter_bytes);
    const workspace = try alloc.alloc(u8, q.fuze.LogicalArrow.working_bytes);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    var hosts = try Hosts.init(client, state, adapter, workspace, &cancellation);
    var query_client = caller(client, state);
    for (0..10000) |_| {
        try hosts.step(init.io, admin);
        if (try query_client.status(1)) |status| {
            if (status.phase == .complete) break;
            if (status.phase == .rejected or status.phase == .denied) return error.CapturedQueryFailed;
        }
    } else return error.QueryCapturePending;
    const bundle = try q.Bundle.decode(alloc, try state.bundle.decode(alloc, q.Bundle.max_bytes));
    const grant = bundle.retention.?;
    const pin = try client.call(.{ .pin_status = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner } });
    defer pin.deinit();
    try t.expect(pin.value.result.pin_state.released);
    var reader = try sourceReader(client, state);
    const recorded = try q.CapturedTablePin.source(alloc, &reader, .{ .job = state.job, .source = 0 }, state.connection.source);
    try t.expectEqualDeep(grant.binding.expected, recorded.accepted);
    try t.expectEqual(@as(u64, 19), recorded.row_count);
    const output = try alloc.alloc(u8, q.fuze.LogicalArrow.segment_bytes);
    var decoded: q.fuze.LogicalInspect.Batch = undefined;
    const page = try query_client.page(1, null, alloc, workspace, output, &decoded);
    defer decoded.deinit();
    try t.expect(page.next == null);
    try t.expectEqual(@as(usize, 1), decoded.rows.len);
    try t.expectEqual(@as(u128, 19), decoded.rows[0].cells[0].value.atom.unsigned);
    try t.expect(page.basis.cut.position == .table);
    try t.expectEqualSlices(u8, &try recorded.fingerprint(), &page.basis.cut.position.table);
    try t.expectEqual(@as(u64, 19), page.manifest.checkpoint.cursor.table_scanned);
    try t.expectEqual(@as(u64, 3), page.manifest.checkpoint.progress.pages);
    var executor = client;
    executor.connection.principal = 103;
    executor.key = try key(43);
    try t.expectError(error.AccessDenied, executor.call(.{ .lookup = .{ .namespace = 1, .name = "captured_renamed" } }));

    const original_role = (try query_client.authorizationClient().read(.identity)).body.authorization.body.identity.login_role;
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(recorded.authority.table), .owner = 0 } });
    var denied: q.fuze.LogicalInspect.Batch = undefined;
    try t.expectError(error.AccessDenied, query_client.page(1, null, alloc, workspace, output, &denied));
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(recorded.authority.table), .owner = original_role } });

    // A fresh result disclosure may use a rotated credential. It must not
    // replace the original execution proof or reopen its closed pin.
    const fresh_key = try key(53);
    _ = try admin.change(.{ .rotate_credential = .{ .principal = 101, .expected_epoch = grant.proof.claim.credential_epoch, .public_key = fresh_key.public_key.toBytes() } });
    var fresh = query_client;
    fresh.key = fresh_key;
    var disclosed: q.fuze.LogicalInspect.Batch = undefined;
    const after = try fresh.page(1, null, alloc, workspace, output, &disclosed);
    defer disclosed.deinit();
    try t.expectEqualDeep(page.basis, after.basis);
    try t.expectEqual(@as(u128, 19), disclosed.rows[0].cells[0].value.atom.unsigned);
    var fresh_tables = client;
    fresh_tables.key = fresh_key;
    try cleanupAfterRotation(init, fresh_tables, admin, state, &hosts);
}

/// Cancellation records closure before a credential rotation. A separate fresh
/// cleanup proof survives an uncertain release and native worker replacement.
fn cleanupAfterRotation(init: std.process.Init, client: c.DirectTableClient, admin: anytype, saved: State, hosts: *Hosts) !void {
    const alloc = init.arena.allocator();
    var query_client = caller(client, saved);
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "captured_renamed" } });
    defer lookup.deinit();
    const definition = lookup.value.result.lookup.?;
    var source = try q.TableSource.from(init.gpa, client.connection, definition);
    defer source.deinit();
    const description = try q.Bundle.fromSql(alloc, .{ .resource = client.connection.scope.resource, .source = .{ .table = source.source } }, "captured_renamed", "SELECT * FROM captured_renamed", budgets);
    const bundle = try query_client.authorizeCapture(description, .{ .executor = 103, .operation = 614, .expected = definition.position });
    const reference = try bundle.reference(saved.connection.requests, 2);
    var pending: r.Job = undefined;
    for (0..10000) |_| {
        if (try query_client.prepareNext(2, bundle)) |prepared| {
            const receipt = try query_client.submit(prepared);
            for (0..100) |_| {
                try hosts.step(init.io, admin);
                switch (try query_client.observe(receipt.position)) {
                    .committed => break,
                    .rejected => return error.QueryUploadRejected,
                    .pending => {},
                }
            } else return error.QueryUploadPending;
        } else {
            if (try observed(client, saved, &query_client, 2)) |job| if (job.phase == .capturing) {
                pending = job;
                break;
            };
            try hosts.step(init.io, admin);
        }
    } else return error.QueryCapturePending;
    var reader = try sourceReader(client, saved);
    const retained = try q.CapturedTablePin.source(alloc, &reader, .{ .job = pending.id, .source = 0 }, saved.connection.source);
    _ = try query_client.submit(try query_client.prepare(.{ .cancel = 2 }));
    for (0..1000) |_| {
        try hosts.step(init.io, admin);
        reader = try sourceReader(client, saved);
        pending = try q.UnifiedCapture.job(&reader, pending.id);
        if (pending.phase == .cancelled) break;
        if (pending.phase == .complete) return error.CancellationTooLate;
    } else return error.QueryCancellationPending;

    const grant = bundle.retention.?;
    var fresh = client;
    fresh.key = try key(59);
    _ = try admin.change(.{ .rotate_credential = .{ .principal = 101, .expected_epoch = grant.proof.claim.credential_epoch, .public_key = fresh.key.public_key.toBytes() } });
    // The original authorization cannot settle the pin after rotation.
    for (0..4) |_| try hosts.step(init.io, admin);
    const before = try fresh.call(.{ .pin_status = .{ .object = retained.snapshot.object, .owner = retained.snapshot.handle.owner } });
    defer before.deinit();
    try t.expect(!before.value.result.pin_state.released);
    query_client = caller(fresh, saved);
    // A malformed fresh closure is a rejected control, not a poisoned worker.
    // It must neither replace the old read grant nor release the live pin.
    var forged = try c.DirectReadDelegation.Closure.prepare(fresh, grant);
    forged.signature[0] ^= 1;
    _ = try query_client.submit(try query_client.prepare(.{ .retry_cleanup = .{ .namespace = 2, .authorization = forged } }));
    for (0..1000) |_| {
        try hosts.step(init.io, admin);
        if (hosts.source.confirmation) |confirmation| if (confirmation.kind == .commit) {
            reader = try sourceReader(fresh, saved);
            if (try reader.read(r.key('e', confirmation.input, 0))) |reason| {
                try t.expectEqualStrings("CatalogDenied", reason.slice());
                const closing = (try q.CapturedTablePin.observe(alloc, &reader, .{ .job = pending.id, .source = 0 }, saved.connection.source)).?;
                try t.expectEqual(q.CapturedTablePin.Phase.closing, closing.phase);
                try t.expectEqualDeep(grant, closing.grant);
                break;
            }
        };
    } else return error.MissingCleanupRejection;
    const still_pinned = try fresh.call(.{ .pin_status = .{ .object = retained.snapshot.object, .owner = retained.snapshot.handle.owner } });
    defer still_pinned.deinit();
    try t.expect(!still_pinned.value.result.pin_state.released);
    const prepared = try query_client.prepareCleanup(2, bundle);
    _ = try query_client.submit(prepared);
    for (0..1000) |_| {
        hosts.step(init.io, admin) catch |err| {
            try t.expectEqual(error.InvalidTableResponse, err);
            break;
        };
    } else return error.MissingExpectedCleanupFault;
    const state = try replacement(admin, saved);
    var resumed = try Hosts.init(fresh, state, hosts.behavior.adapter, hosts.behavior.workspace, hosts.behavior.cancellation);
    for (0..100) |_| {
        try resumed.step(init.io, admin);
        reader = try sourceReader(fresh, state);
        const status = (try q.CapturedTablePin.observe(alloc, &reader, .{ .job = pending.id, .source = 0 }, state.connection.source)).?;
        if (status.phase == .closed) break;
    } else return error.QueryCleanupPending;
    const released = try fresh.call(.{ .pin_status = .{ .object = retained.snapshot.object, .owner = retained.snapshot.handle.owner } });
    defer released.deinit();
    try t.expect(released.value.result.pin_state.released);
    reader = try sourceReader(fresh, state);
    try t.expectEqualDeep(retained, try q.CapturedTablePin.source(alloc, &reader, .{ .job = pending.id, .source = 0 }, state.connection.source));
    try t.expectEqualDeep(reference, try bundle.reference(saved.connection.requests, 2));
    try cleanupBeforeAcquisition(init, fresh, admin, state, &resumed, retained.authority.table);
}

/// Denial before committed acquisition eligibility has no remote or native pin.
/// Fresh terminal cleanup must preserve that absence and the original failure.
fn cleanupBeforeAcquisition(init: std.process.Init, client: c.DirectTableClient, admin: anytype, state: State, hosts: *Hosts, table_authority: u64) !void {
    const alloc = init.arena.allocator();
    var query_client = caller(client, state);
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "captured_renamed" } });
    defer lookup.deinit();
    const definition = lookup.value.result.lookup.?;
    var source = try q.TableSource.from(init.gpa, client.connection, definition);
    defer source.deinit();
    const description = try q.Bundle.fromSql(alloc, .{ .resource = client.connection.scope.resource, .source = .{ .table = source.source } }, "captured_renamed", "SELECT COUNT(*) AS n FROM captured_renamed", budgets);
    const bundle = try query_client.authorizeCapture(description, .{ .executor = 103, .operation = 615, .expected = definition.position });
    var pending: r.Job = undefined;
    for (0..10000) |_| {
        if (try query_client.prepareNext(3, bundle)) |prepared| {
            const receipt = try query_client.submit(prepared);
            for (0..100) |_| {
                try hosts.step(init.io, admin);
                switch (try query_client.observe(receipt.position)) {
                    .committed => break,
                    .rejected => return error.QueryUploadRejected,
                    .pending => {},
                }
            } else return error.QueryUploadPending;
        } else {
            if (try observed(client, state, &query_client, 3)) |job| {
                try t.expectEqual(r.Phase.admitted, job.phase);
                pending = job;
                break;
            }
            try hosts.step(init.io, admin);
        }
    } else return error.QueryAdmissionPending;
    const original_role = (try query_client.authorizationClient().read(.identity)).body.authorization.body.identity.login_role;
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(table_authority), .owner = 0 } });
    for (0..1000) |_| {
        try hosts.step(init.io, admin);
        if (try query_client.status(3)) |status| if (status.phase == .denied) break;
    } else return error.QueryDenialPending;
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(table_authority), .owner = original_role } });
    var reader = try sourceReader(client, state);
    const failed = try q.UnifiedCapture.job(&reader, pending.id);
    try t.expectEqual(r.Phase.denied, failed.phase);
    try t.expect(try q.CapturedTablePin.observe(alloc, &reader, .{ .job = pending.id, .source = 0 }, state.connection.source) == null);
    _ = try query_client.submit(try query_client.prepareCleanup(3, bundle));
    for (0..100) |_| try hosts.step(init.io, admin);
    reader = try sourceReader(client, state);
    const after = try q.UnifiedCapture.job(&reader, pending.id);
    try t.expectEqualDeep(failed.failure, after.failure);
    try t.expectEqual(r.Phase.denied, after.phase);
    try t.expect(try q.CapturedTablePin.observe(alloc, &reader, .{ .job = pending.id, .source = 0 }, state.connection.source) == null);
    const remote = try client.call(.{ .pin_status = .{ .object = bundle.retention.?.binding.interpretation.object, .owner = bundle.retention.?.binding.owner } });
    defer remote.deinit();
    try t.expect(remote.value.result.pin_state.handle == null);
}

const RelationalHost = struct {
    bundle: q.RelationalBundle,
    bytes: []const u8,
    reference: s.PublicationReference,
    clients: []const c.DirectTableClient,
    workspace: []u8,
    const correlation_key = p.Value.init("direct-relational-correlation") catch unreachable;
    fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) anyerror!void {
        const self: *@This() = @ptrCast(@alignCast(raw.?));
        const local = (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid;
        const external = switch (turn.delivery.input.origin) {
            .external => |origin| origin.principal == 101,
            else => false,
        };
        if (frame.kind == .reply) return;
        if (frame.kind == .call) {
            if (!local) return error.AccessDenied;
            _ = try q.RelationalCapture.start(turn, try s.PublicationReference.decode(frame.payload), self.clients, self.workspace);
            return;
        }
        if (frame.kind != .cast) return error.InvalidProofFrame;
        if (std.mem.eql(u8, frame.payload.slice(), "configure")) {
            if (!external) return error.AccessDenied;
            try q.RelationalCapture.setPolicy(turn, .{ .peer = turn.delivery.pid, .requests = turn.view.resource, .principal = 101, .revision = 1, .request = try self.bundle.fingerprint(), .allow = true });
            return;
        }
        if (std.mem.eql(u8, frame.payload.slice(), "upload")) {
            if (!local and !external) return error.AccessDenied;
            const ready = try s.PublicationUpload.step(turn, .{ .domain = .query_request, .namespace = self.reference.namespace, .identity_key = q.RelationalRecords.key('u', self.reference.namespace, 0), .identity = try self.reference.encode(), .limits = .{ .record_bytes = q.RelationalBundle.max_bytes, .staging_bytes = q.RelationalBundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = self.reference.spec, .bytes = self.bytes }} });
            if (ready) {
                const correlation = try turn.call(turn.delivery.pid, try self.reference.encode(), null);
                try turn.write(correlation_key, q.UnifiedRecords.identityValue(correlation));
            } else try turn.cast(turn.delivery.pid, frame.payload);
            return;
        }
        if (!local) return error.AccessDenied;
        _ = try q.RelationalCapture.advance(turn, try q.UnifiedRecords.Continuation.decode(frame.payload), self.clients, self.workspace);
    }
    fn interface(self: *@This()) s.GenServer.Handler {
        return .{ .context = self, .handle = handle };
    }
};
pub fn relational(init: std.process.Init, client: c.DirectTableClient, admin: anytype) !void {
    try relationalCase(init, client, admin, false);
    try relationalCase(init, client, admin, true);
}
fn relationalCase(init: std.process.Init, client: c.DirectTableClient, admin: anytype, independent: bool) !void {
    const alloc = init.arena.allocator();
    const principal: u64 = if (independent) 106 else 105;
    const seed: u8 = if (independent) 71 else 61;
    var worker = try provision(admin, principal, seed);
    const role = (try (s.client.AuthorizationClient{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }).read(.identity)).body.authorization.body.identity.login_role;
    const left_name = if (independent) "captured_left" else "captured_join";
    const right_name = if (independent) "captured_right" else left_name;
    try table(alloc, client, role, if (independent) 63 else 62, left_name, if (independent) 619 else 617, 2);
    if (independent) try table(alloc, client, role, 64, right_name, 621, 2);
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = worker.pid }, .grantee = role, .privileges = p.permission(.send) | p.permission(.inspect) } });
    worker.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = worker.pid } }, try key(17))).body.process.process.generation;
    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = principal } });
    worker.generation += 1;
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = left_name } });
    defer lookup.deinit();
    const definition = lookup.value.result.lookup.?;
    var source = try q.TableSource.from(init.gpa, client.connection, definition);
    defer source.deinit();
    var schema = try q.fuze.TableSchema.decode(alloc, try definition.schema.decode(alloc, q.fuze.TableSchema.max_bytes));
    defer schema.deinit();
    const second = try client.call(.{ .lookup = .{ .namespace = 1, .name = right_name } });
    defer second.deinit();
    const right_definition = second.value.result.lookup.?;
    var right_source = try q.TableSource.from(init.gpa, client.connection, right_definition);
    defer right_source.deinit();
    var right_schema = try q.fuze.TableSchema.decode(alloc, try right_definition.schema.decode(alloc, q.fuze.TableSchema.max_bytes));
    defer right_schema.deinit();
    const declarations = [_]q.fuze.Relational.Source{
        .{ .alias = "a", .realm = 42, .resource = client.connection.scope.resource, .catalog = client.connection.scope.catalog, .owner = client.connection.audience, .schema = schema.schema },
        .{ .alias = "b", .realm = 42, .resource = client.connection.scope.resource, .catalog = client.connection.scope.catalog, .owner = client.connection.audience, .schema = right_schema.schema },
    };
    var syntax = try q.fuze.RelationalSql.parse(alloc, try std.fmt.allocPrint(alloc, "SELECT COUNT(*) AS n FROM {s} a JOIN {s} b ON a.id = b.id WHERE a.id = 0 AND b.id = 0", .{ left_name, right_name }), null);
    defer syntax.deinit();
    const description: q.RelationalBundle = .{ .plan = try syntax.bind(&declarations, .captured, .{ .resident_bytes = q.RelationalCapture.resident_base + 8 * 1024 * 1024, .spill_bytes = 8 * 1024 * 1024, .result_bytes = 1024, .output_rows = 10, .work_steps = 10000, .source_pins = if (independent) 2 else 1 }, null), .sources = &.{ source.source, right_source.source } };
    const capture: q.Bundle.Capture = .{ .executor = principal, .operation = if (independent) 623 else 616, .expected = definition.position };
    const right_capture: q.Bundle.Capture = .{ .executor = principal, .operation = if (independent) 624 else 616, .expected = right_definition.position };
    const bundle = try description.authorizeCapture(alloc, .{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, &.{ client, client }, worker.pid, worker.resource, worker.pid, worker.resource, &.{ capture, right_capture });
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    var executor = client;
    executor.connection.principal = principal;
    executor.key = try key(seed);
    const clients = [_]c.DirectTableClient{ executor, executor };
    var behavior: RelationalHost = .{ .bundle = bundle, .bytes = try bundle.encode(&bytes), .reference = try bundle.reference(worker.resource, 1), .clients = &clients, .workspace = try alloc.alloc(u8, 4 * 1024 * 1024) };
    var host = try s.GenServer.init(.{ .client = client.authority, .realm = 42, .principal = principal, .pid = worker.pid, .generation = worker.generation, .key = executor.key }, "state");
    host.failure_policy = .stop;
    try send(client, worker.pid, try p.Value.init("configure"));
    try send(client, worker.pid, try p.Value.init("upload"));
    const resources: s.client.ResourceReader = .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key };
    var replaced = false;
    var job_id: u64 = 0;
    for (0..10000) |attempt| {
        const step = try host.step(behavior.interface(), @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000));
        if (step == .blocked) return host.handler_error orelse error.Blocked;
        const delivery = try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .delivery }, try key(17));
        if (delivery.body.delivery.next) |next| _ = try admin.submit(.{ .deliver = next });
        var reader = try resources.open(worker.resource);
        if (try reader.read(RelationalHost.correlation_key)) |value| {
            const correlation = try q.UnifiedRecords.readIdentity(value);
            if (try reader.read(q.RelationalRecords.key('i', worker.pid, correlation))) |index| {
                job_id = try q.UnifiedRecords.readIdentity(index);
                const stored = try q.RelationalCapture.job(&reader, job_id);
                if (attempt % 100 == 0) std.debug.print("Direct relational capture: independent={} attempt={d} phase={s} acquired={d} checkpoint={d} outputs={d}\n", .{ independent, attempt, @tagName(stored.phase), stored.acquired, stored.checkpoint, stored.outputs });
                if (!replaced and stored.phase == .acquiring and stored.acquired == @as(u8, if (independent) 1 else 0)) {
                    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = principal } });
                    worker.generation += 1;
                    host = try s.GenServer.init(.{ .client = client.authority, .realm = 42, .principal = principal, .pid = worker.pid, .generation = worker.generation, .key = executor.key }, "state");
                    host.failure_policy = .stop;
                    replaced = true;
                }
                if (stored.phase == .failed or stored.phase == .denied) return error.RelationalQueryFailed;
                if (stored.phase == .complete) {
                    const retained = (try q.CapturedTablePin.observe(alloc, &reader, .{ .job = job_id, .source = 0 }, worker.pid)).?;
                    const other = try q.CapturedTablePin.observe(alloc, &reader, .{ .job = job_id, .source = 1 }, worker.pid);
                    if (retained.phase == .closed and (!independent or (other != null and other.?.phase == .closed))) break;
                }
            }
        }
    } else return error.RelationalQueryPending;
    try t.expect(replaced);
    var reader = try resources.open(worker.resource);
    try t.expectEqual(independent, try q.CapturedTablePin.observe(alloc, &reader, .{ .job = job_id, .source = 1 }, worker.pid) != null);
    const vector = try q.RelationalCaptured.Vector.decode(bundle, (try reader.read(q.RelationalRecords.key('v', job_id, 0))).?);
    try t.expectEqual(independent, vector.entries[0].partition != vector.entries[1].partition);
    const options: q.RelationalResult.Options = .{ .owner = worker.pid, .peer = worker.pid, .resource = worker.resource, .job = job_id, .requests = 2000 };
    const disclosure = try q.ResultDisclosure.prepare(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, try options.selection(bundle));
    var result = try q.RelationalResult.open(resources, bundle, options, disclosure, @splat(67));
    defer result.close() catch {};
    const row = (try result.next()).?;
    try t.expectEqual(@as(u128, 1), row.cells[0].value.atom.unsigned);
    try t.expect(try result.next() == null);
    const retained = try q.CapturedTablePin.source(alloc, &reader, .{ .job = job_id, .source = if (independent) 1 else 0 }, worker.pid);
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(retained.authority.table), .owner = 0 } });
    try t.expectError(error.CatalogDenied, q.RelationalResult.open(resources, bundle, options, disclosure, @splat(68)));
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(retained.authority.table), .owner = role } });
    var restored = try q.RelationalResult.open(resources, bundle, options, disclosure, @splat(69));
    defer restored.close() catch {};
    try t.expectEqual(@as(u128, 1), (try restored.next()).?.cells[0].value.atom.unsigned);
    try t.expect(try restored.next() == null);
    try t.expectError(error.AccessDenied, executor.call(.{ .lookup = .{ .namespace = 1, .name = right_name } }));
}
