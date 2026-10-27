//! Maintained direct Tables through public HTTP and native query progress.
const std = @import("std");
const t = std.testing;
const q = @import("transit_query");
const c = q.catalog;
const p = q.protocol;
const s = q.station;
const w = c.DirectTableProtocol;
const r = q.RelationalMaintenanceRecords;
const support = @import("fixture_direct_captured_query");
const app = @import("transit_station_app");
pub const State = struct { worker: support.Provision, principal: u64, seed: u8, bundle: w.Binary, identity: r.Identity, job: u64, independent: bool, named: ?app.NamedRelationalRecords.Reference = null };
fn naming(state: State) app.NamedRelational {
    return .{ .configuration = .{ .scope = .{ .realm = 42, .resource = state.worker.resource, .owner = state.worker.pid, .namespace = 55 }, .administrator = 101, .records = 4096, .bytes = 32 * 1024 * 1024 } };
}
pub fn executor(client: c.DirectTableClient, state: State) !c.DirectTableClient {
    var result = client;
    result.connection.principal = state.principal;
    result.key = try support.key(state.seed);
    return result;
}
pub fn source(client: c.DirectTableClient, state: State) !s.client.ResourceReader.Reader {
    const reader: s.client.ResourceReader = .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key };
    return reader.open(state.worker.resource);
}
fn observed(client: c.DirectTableClient, state: State) !r.Head {
    var reader = try source(client, state);
    return q.RelationalMaintenance.head(&reader, state.identity);
}
pub fn host(client: c.DirectTableClient, state: State) !s.GenServer {
    var result = try s.GenServer.init(.{ .client = client.authority, .realm = 42, .principal = state.principal, .pid = state.worker.pid, .generation = state.worker.generation, .key = try support.key(state.seed) }, "state");
    result.failure_policy = .stop;
    return result;
}
fn step(init: std.process.Init, owner: *s.GenServer, behavior: *support.RelationalHost, admin: anytype) !void {
    if (try support.namedStep(init, owner, behavior, admin) == .blocked) return owner.handler_error orelse error.Blocked;
    const pending = try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .delivery }, try support.key(17));
    if (pending.body.delivery.next) |next| _ = try admin.submit(.{ .deliver = next });
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, independent: bool) !State {
    return prepareWithExchange(init, client, admin, role, independent, false);
}
pub fn prepareWithExchange(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, independent: bool, exchanged: bool) !State {
    const alloc = init.arena.allocator();
    const principal: u64 = if (exchanged) 140 else if (independent) 108 else 107;
    const seed: u8 = if (exchanged) 112 else if (independent) 79 else 73;
    var worker = try support.provision(admin, principal, seed);
    const left = if (exchanged) "exchange_input" else if (independent) "maintained_left" else "maintained_alias";
    const right = if (independent) "maintained_right" else left;
    const object: u64 = if (exchanged) 90 else if (independent) 71 else 70;
    const operation: u64 = if (exchanged) 1100 else if (independent) 643 else 640;
    try support.table(alloc, client, role, object, left, operation, 2);
    if (independent) try support.table(alloc, client, role, 72, right, 646, 2);
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = worker.pid }, .grantee = role, .privileges = p.permission(.send) | p.permission(.inspect) } });
    worker.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = worker.pid } }, try support.key(17))).body.process.process.generation;
    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = principal } });
    worker.generation += 1;
    const first = try client.call(.{ .lookup = .{ .namespace = 1, .name = left } });
    defer first.deinit();
    const second = try client.call(.{ .lookup = .{ .namespace = 1, .name = right } });
    defer second.deinit();
    const definitions = [_]w.Definition{ first.value.result.lookup.?, second.value.result.lookup.? };
    var sources: [2]q.TableSource = undefined;
    var declarations: [2]q.fuze.Relational.Source = undefined;
    for (definitions, 0..) |definition, i| {
        const owned = try q.TableSource.from(alloc, client.connection, definition);
        const schema = try q.fuze.TableSchema.decode(alloc, try definition.schema.decode(alloc, q.fuze.TableSchema.max_bytes));
        sources[i] = owned.source;
        declarations[i] = .{ .alias = if (i == 0) "a" else "b", .realm = 42, .resource = client.connection.scope.resource, .catalog = client.connection.scope.catalog, .owner = client.connection.audience, .schema = schema.schema };
    }
    var syntax = try q.fuze.RelationalSql.parse(alloc, try std.fmt.allocPrint(alloc, "SELECT COUNT(*) AS n FROM {s} a JOIN {s} b ON a.id = b.id", .{ left, right }), null);
    defer syntax.deinit();
    const description: q.RelationalBundle = .{ .sources = &sources, .plan = try syntax.bind(&declarations, .maintained, .{ .resident_bytes = q.RelationalMaintenance.resident_base + 8 * 1024 * 1024, .spill_bytes = 32 * 1024 * 1024, .result_bytes = 1024, .output_rows = 10, .work_steps = 10000, .source_pins = if (independent) 2 else 1 }, null) };
    const bundle = try description.authorizeCapture(alloc, .{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, &.{ client, client }, worker.pid, worker.resource, worker.pid, worker.resource, &.{ .{ .executor = principal, .operation = operation + 2, .expected = definitions[0].position }, .{ .executor = principal, .operation = if (independent) 648 else operation + 2, .expected = definitions[1].position } });
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    const body = try bundle.encode(&bytes);
    var state: State = .{ .worker = worker, .principal = principal, .seed = seed, .bundle = try .encode(alloc, body), .identity = undefined, .job = 0, .independent = independent };
    const client_set = [_]c.DirectTableClient{ try executor(client, state), try executor(client, state) };
    var behavior: support.RelationalHost = .{ .exchanged = exchanged, .bundle = bundle, .bytes = body, .reference = try bundle.reference(worker.resource, 1), .clients = &client_set, .workspace = try alloc.alloc(u8, 4 * 1024 * 1024) };
    if (!exchanged) behavior.named = naming(state);
    var running = try host(client, state);
    if (behavior.named != null) try support.send(client, worker.pid, try .init("prime"));
    try support.send(client, worker.pid, try .init("configure"));
    try support.send(client, worker.pid, try .init("upload"));
    if (behavior.named) |named| {
        for (0..1000) |_| {
            try step(init, &running, &behavior, admin);
            var reader = try source(client, state);
            const descriptor = behavior.reference.publication().inspect(&reader, behavior.reference.record) catch |err| {
                if (err == error.PublicationNotFound or err == error.PublicationUninitialized or err == error.RecordNotFound) continue;
                return err;
            };
            if (descriptor.state == .published) break;
        } else return error.NamedUploadPending;
        const name = try app.NamedRelationalRecords.Name.init("totals");
        var publication = try support.prepareNamed(init, client, named, .{ .name = name, .object = 1001, .expected = 0, .peer = worker.pid, .request = behavior.reference }, bundle);
        defer publication.deinit();
        const control = try (try publication.value.publication(alloc, &.{client})).encode();
        try support.send(client, worker.pid, control);
        for (0..1000) |_| {
            try step(init, &running, &behavior, admin);
            var reader = try source(client, state);
            state.named = try named.lookup(&reader, name);
            if (state.named != null) break;
        } else return error.NamedPublicationPending;
        var reader = try source(client, state);
        const definition = try named.definition(&reader, state.named.?);
        try t.expectEqual(.maintained, definition.lifetime);
        try t.expectEqualDeep(definition, try named.definition(&reader, state.named.?));
        try t.expect(try q.RelationalCapture.policy(&reader, worker.pid) == null);
        try t.expect(try reader.read(support.RelationalHost.correlation_key) == null);
        for (bundle.retention, 0..) |grant, i| {
            if (try bundle.sourceOrdinal(i) != i) continue;
            const status = try client.call(.{ .pin_status = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner } });
            defer status.deinit();
            try t.expect(status.value.result.pin_state.handle == null);
        }
        try support.send(client, worker.pid, control);
        try support.send(client, worker.pid, try (app.NamedRelationalRecords.Control{ .authorize = .{ .reference = state.named.?, .expected = 0, .principal = 101, .allow = true } }).encode());
        for (0..1000) |_| {
            try step(init, &running, &behavior, admin);
            reader = try source(client, state);
            if (try q.RelationalCapture.policy(&reader, worker.pid)) |policy| {
                try t.expectEqual(@as(u64, 1), policy.revision);
                break;
            }
        } else return error.NamedAuthorizationPending;
        try t.expect(try reader.read(support.RelationalHost.correlation_key) == null);
        try support.send(client, worker.pid, try (app.NamedRelationalRecords.Activation{ .reference = state.named.?, .policy_revision = 1 }).encode());
    }
    for (0..2000) |_| {
        try step(init, &running, &behavior, admin);
        var reader = try source(client, state);
        if (try reader.read(support.RelationalHost.correlation_key)) |value| {
            state.identity = .{ .peer = worker.pid, .correlation = try q.UnifiedRecords.readIdentity(value) };
            const head = q.RelationalMaintenance.head(&reader, state.identity) catch |err| {
                if (err == error.QueryNotFound) continue;
                return err;
            };
            if (head.phase == .acquiring) {
                state.job = head.id;
                const grant = bundle.retention[0];
                const delegated = try q.CapturedTablePin.delegatedClient(behavior.clients[0], grant);
                const acquired = try delegated.call(.{ .retain_history = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner, .expected = grant.binding.expected } });
                acquired.deinit();
                // The remote lease exists; its native handle commit is absent.
                // The runner replaces the node before continuing this input.
                try t.expectError(error.IncompleteSource, q.CapturedTablePin.source(alloc, &reader, .{ .job = head.id, .source = 0 }, worker.pid));
                state.worker.generation = running.session.generation;
                state.seed = behavior.recovery_seed orelse state.seed;
                return state;
            }
        }
    }
    return error.MaintainedQueryPending;
}
pub fn mutation(init: std.process.Init, client: c.DirectTableClient, name: []const u8, operation: u64, id: i64, cancel: bool) !void {
    const alloc = init.arena.allocator();
    const found = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer found.deinit();
    const definition = found.value.result.lookup.?;
    var schema = try q.fuze.TableSchema.decode(alloc, try definition.schema.decode(alloc, q.fuze.TableSchema.max_bytes));
    defer schema.deinit();
    var scratch: [q.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    const key = try w.Binary.encode(alloc, try q.fuze.Collation.encodePrimaryKeySortKey(schema.schema, &.{.{ .value = .{ .atom = .{ .signed = id } } }}, false, &scratch));
    var rows: w.Rows = .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = 101, .operation = operation }, .target = definition.interpretation.interpretation.object, .action = .delete, .expected_definition = definition.interpretation.interpretation, .expected_data = definition.position, .intent = @splat(1) }, .interpretation = definition.interpretation, .schema = definition.schema, .changes = &.{.{ .delete = key }}, .ingestion = .point };
    rows.binding.intent = try rows.digest(alloc);
    (try client.call(.{ .admit_rows = rows })).deinit();
    const result = try client.call(.{ .operation = .{ .binding = rows.binding, .command = if (cancel) .cancel else .execute, .steps = 1 } });
    defer result.deinit();
    if (cancel) {
        try t.expect(result.value.result.rows == .cancelled);
        return;
    }
    try t.expectEqual(@as(u64, if (id == 999) 0 else 1), result.value.result.rows.committed.outcome.affected);
}
pub fn readResult(client: c.DirectTableClient, bundle: q.RelationalBundle, state: State, revision: u64, expected: u128) !q.RelationalRevision.Position {
    const options: q.RelationalRevision.Options = .{ .owner = state.worker.pid, .resource = state.worker.resource, .identity = state.identity, .revision = revision, .requests = 4000 };
    const disclosure = try q.ResultDisclosure.prepare(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, try options.selection(bundle));
    const reader = try q.RelationalRevision.open(client.allocator, .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key }, bundle, options, disclosure, @splat(@intCast(100 + revision)));
    defer reader.deinit();
    if (state.named) |reference| {
        const named = naming(state);
        try t.expectEqualDeep(reference, try (try named.maintainedDefinition(reader)).reference());
        try t.expectEqual(@as(u64, 0), reader.ordinal);
        try t.expectError(error.IncompleteResult, reader.checkpoint());
        var foreign = named;
        foreign.configuration.scope.resource += 1;
        try t.expectError(error.NamedQueryChanged, foreign.maintainedDefinition(reader));
    }
    var output = (try reader.next()).?;
    defer output.deinit();
    try t.expectEqual(expected, output.row.cells[0].value.atom.unsigned);
    try t.expect(try reader.next() == null);
    if (state.named != null) try t.expectError(error.QueryClosed, naming(state).maintainedDefinition(reader));
    return reader.checkpoint();
}
fn freshness(client: c.DirectTableClient, bundle: q.RelationalBundle, state: State, revision: u64, expected: bool) !void {
    const before = try observed(client, state);
    const options: q.RelationalRevision.Options = .{ .owner = state.worker.pid, .resource = state.worker.resource, .identity = state.identity, .revision = revision, .requests = 4000 };
    const disclosure = try q.ResultDisclosure.prepare(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, try options.selection(bundle));
    const reader = try q.RelationalRevision.open(client.allocator, .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key }, bundle, options, disclosure, @splat(@intCast(150 + revision)));
    defer reader.deinit();
    const result = try reader.freshness(&.{ client, client });
    try t.expectEqual(expected, result.fresh());
    if (state.named) |reference| try t.expectEqualDeep(reference, try (try naming(state).maintainedDefinition(reader)).reference());
    // Inspecting source progress cannot verify unread output or wake maintenance.
    try t.expectError(error.IncompleteResult, reader.checkpoint());
    try t.expectEqualDeep(before, try observed(client, state));
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, admin: anytype, state: State, backfill: bool) !void {
    const alloc = init.arena.allocator();
    const bytes = try state.bundle.decode(alloc, q.RelationalBundle.max_bytes);
    var owned = try q.RelationalBundle.decode(alloc, bytes);
    defer owned.deinit();
    const bundle = owned.bundle;
    const client_set = [_]c.DirectTableClient{ try executor(client, state), try executor(client, state) };
    var behavior: support.RelationalHost = .{ .bundle = bundle, .bytes = bytes, .reference = try bundle.reference(state.worker.resource, 1), .clients = &client_set, .workspace = try alloc.alloc(u8, 4 * 1024 * 1024) };
    if (state.named != null) behavior.named = naming(state);
    var running = try host(client, state);
    if (backfill) {
        var changed = false;
        for (0..3000) |_| {
            try step(init, &running, &behavior, admin);
            const head = try observed(client, state);
            if (!changed and head.phase == .running) {
                const left = if (state.independent) "maintained_left" else "maintained_alias";
                // Accepted/cancelled operation records form a physical-only
                // prefix longer than one history page. They create no revision.
                for (0..12) |i| try mutation(init, client, left, (if (state.independent) @as(u64, 900) else 800) + i, 999, true);
                // New rows during backfill cannot substitute for its saved cut.
                try mutation(init, client, left, if (state.independent) 652 else 650, 0, false);
                try mutation(init, client, if (state.independent) "maintained_right" else left, if (state.independent) 653 else 651, 999, false);
                changed = true;
            }
            if (head.phase == .failed) return error.MaintainedQueryFailed;
            if (head.phase == .idle) break;
        } else return error.MaintainedQueryPending;
        try t.expect(changed);
        _ = try readResult(client, bundle, state, 1, 2);
        if (state.named) |reference| {
            // Publish a new name revision after execution and node restart.
            // The old query keeps its original policy and immutable attribution.
            const before_publication = try observed(client, state);
            var publication = try support.prepareNamed(init, client, naming(state), .{ .name = reference.identity.name, .object = reference.identity.object, .expected = 1, .peer = state.worker.pid, .request = behavior.reference }, bundle);
            defer publication.deinit();
            try support.send(client, state.worker.pid, try (try publication.value.publication(init.arena.allocator(), &.{client})).encode());
            for (0..1000) |_| {
                try step(init, &running, &behavior, admin);
                var reader = try source(client, state);
                const current = (try naming(state).lookup(&reader, reference.identity.name)).?;
                if (current.identity.revision == 2) break;
            } else return error.NamedPublicationPending;
            try t.expectEqualDeep(before_publication, try observed(client, state));
            _ = try readResult(client, bundle, state, 1, 2);
        }
        try freshness(client, bundle, state, 1, false);
        try support.send(client, state.worker.pid, try .init("wake"));
        for (0..100) |_| {
            try step(init, &running, &behavior, admin);
            const head = try observed(client, state);
            if (head.phase != .seeking) continue;
            var reader = try source(client, state);
            const manifest = (try q.RelationalMaintenance.manifest(&reader, bundle, head)).?;
            const scan = try q.RelationalHistory.Scan.decode(bundle, manifest.vector, (try reader.read(r.key('s', head.id, 2, 0))).?);
            if (scan.cursors[0] > manifest.vector.entries[0].position) {
                try t.expect(scan.cursors[0] < scan.uppers[0]);
                try t.expectEqual(@as(u64, 1), head.revision);
                return; // Restart the node with this physical progress committed.
            }
        }
        return error.MaintainedScanDidNotProgress;
    }
    const first = try readResult(client, bundle, state, 1, 2);
    var previous = first;
    var previous_count: u128 = 2;
    var initial_reader = try source(client, state);
    const restored_head = try observed(client, state);
    try t.expectEqual(.seeking, restored_head.phase);
    const restored_manifest = (try q.RelationalMaintenance.manifest(&initial_reader, bundle, restored_head)).?;
    const restored_scan = try q.RelationalHistory.Scan.decode(bundle, restored_manifest.vector, (try initial_reader.read(r.key('s', state.job, 2, 0))).?);
    try t.expect(restored_scan.cursors[0] > restored_manifest.vector.entries[0].position);
    for (2..4) |revision| {
        if (revision != 2) try support.send(client, state.worker.pid, try .init("wake"));
        for (0..3000) |_| {
            try step(init, &running, &behavior, admin);
            const head = try observed(client, state);
            if (head.phase == .failed) return error.MaintainedQueryFailed;
            if (head.phase == .idle and head.revision == revision) break;
        } else return error.MaintainedQueryPending;
        var current_reader = try source(client, state);
        const complete = (try q.RelationalMaintenance.manifest(&current_reader, bundle, try observed(client, state))).?;
        const expected: u128 = complete.vector.entries[0].record.basis.row_count;
        const position = try readResult(client, bundle, state, revision, expected);
        const options = try previous.nextOptions(4000, null);
        const disclosure = try q.ResultDisclosure.prepare(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, try options.selection(bundle));
        const delta = try q.RelationalRevision.openNext(client.allocator, .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key }, bundle, previous, disclosure, @splat(@intCast(110 + revision)), 4000, null);
        defer delta.deinit();
        if (state.named) |reference| {
            try t.expectEqualDeep(reference, try (try naming(state).maintainedDefinition(delta)).reference());
            try t.expectError(error.IncompleteResult, delta.checkpoint());
        }
        if (expected != previous_count) {
            var event = (try delta.next()).?.delta;
            defer event.deinit();
            try t.expectEqual(previous_count, event.before.?.row.cells[0].value.atom.unsigned);
            try t.expectEqual(expected, event.after.?.row.cells[0].value.atom.unsigned);
        }
        try t.expect(try delta.next() == null);
        try t.expectEqualDeep(position, try delta.checkpoint());
        previous = position;
        previous_count = expected;
    }
    try t.expectEqual(@as(u128, 1), previous_count);
    try freshness(client, bundle, state, 1, false);
    try freshness(client, bundle, state, 3, true);
    const before_idle = try observed(client, state);
    try support.send(client, state.worker.pid, try .init("wake"));
    for (0..100) |_| {
        try step(init, &running, &behavior, admin);
        const head = try observed(client, state);
        if (head.phase == .idle and head.continuation > before_idle.continuation) {
            try t.expectEqual(@as(u64, 3), head.revision);
            break;
        }
    } else return error.MaintainedQueryPending;
    try support.send(client, state.worker.pid, try .init("close"));
    for (0..100) |_| {
        try step(init, &running, &behavior, admin);
        const head = try observed(client, state);
        if (head.phase == .cancelled and head.cleanup_cursor == head.count) break;
    } else return error.MaintainedQueryPending;
    for (bundle.retention, 0..) |grant, i| {
        if (try bundle.sourceOrdinal(i) != i) continue;
        const status = try client.call(.{ .pin_status = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner } });
        defer status.deinit();
        try t.expect(status.value.result.pin_state.released);
    }
    _ = try readResult(client, bundle, state, 1, 2);
    _ = try readResult(client, bundle, state, 3, 1);
    var reader = try source(client, state);
    const retained = try q.CapturedTablePin.source(alloc, &reader, .{ .job = state.job, .source = if (state.independent) 1 else 0 }, state.worker.pid);
    const role = (try (s.client.AuthorizationClient{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }).read(.identity)).body.authorization.body.identity.login_role;
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(retained.authority.table), .owner = 0 } });
    try t.expectError(error.CatalogDenied, readResult(client, bundle, state, 3, 1));
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(retained.authority.table), .owner = role } });
    _ = try readResult(client, bundle, state, 3, 1);
    if (state.named) |reference| {
        const left = if (state.independent) "maintained_left" else "maintained_alias";
        const operation = 7000000 + state.worker.resource * 10;
        try support.namedDrop(client, left, operation, true);
        try support.retireNamed(init, client, admin, &running, &behavior);
        var metadata = try source(client, state);
        try t.expect(try naming(state).lookup(&metadata, reference.identity.name) == null);
        try t.expectEqualDeep(reference, try naming(state).attribution(&metadata, state.worker.pid, 1));
        try support.namedDrop(client, left, operation + 1, false);
        _ = try readResult(client, bundle, state, 3, 1);
    }
    try support.send(client, state.worker.pid, try .init("retire"));
    for (0..100) |_| {
        try step(init, &running, &behavior, admin);
        if ((try observed(client, state)).phase == .retired) break;
    } else return error.MaintainedQueryPending;
    try t.expectError(error.MaintainedResetRequired, readResult(client, bundle, state, 3, 1));
}
