//! Public direct-source failures preserve durable witnesses and completed work.
const std = @import("std");
const t = std.testing;
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const w = c.DirectTableProtocol;
const finite = q.RelationalRecords;
const maintained = q.RelationalMaintenanceRecords;
const support = @import("fixture_direct_captured_query");
pub const Case = enum { captured_work, captured_spill, captured_overflow, maintained_overflow, maintained_gap };

fn step(init: std.process.Init, running: *s.GenServer, behavior: *support.RelationalHost, admin: anytype) !void {
    if (try running.step(behavior.interface(), @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000)) == .blocked) return running.handler_error orelse error.Blocked;
    const pending = try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .delivery }, try support.key(17));
    if (pending.body.delivery.next) |next| _ = try admin.submit(.{ .deliver = next });
}
fn insert(client: c.DirectTableClient, name: []const u8, operation: u64, overflow: bool) !void {
    const alloc = client.allocator;
    const found = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer found.deinit();
    const definition = found.value.result.lookup.?;
    const schema_bytes = try definition.schema.decode(alloc, q.fuze.TableSchema.max_bytes);
    defer alloc.free(schema_bytes);
    var schema = try q.fuze.TableSchema.decode(alloc, schema_bytes);
    defer schema.deinit();
    const identity: p.DataLifecycle.Operation = .{ .scope = client.connection.scope, .principal = 101, .operation = operation };
    var changes: [3]w.RowChange = undefined;
    var buffers: [3][q.fuze.TableRow.max_bytes]u8 = undefined;
    const values: [3]i64 = if (overflow) .{ std.math.maxInt(i64), 1, -std.math.maxInt(i64) } else .{ 1, 2, 3 };
    for (values, 0..) |value, i| {
        const row: q.fuze.TableRow.Row = .{ .identity = try w.Rows.insertIdentity(identity, @intCast(i)), .cells = &.{.{ .value = .{ .atom = .{ .signed = value } } }} };
        changes[i] = .{ .insert = try .encode(alloc, try row.encode(schema.schema, &buffers[i])) };
    }
    defer for (changes) |change| alloc.free(change.insert.base64);
    var rows: w.Rows = .{ .binding = .{ .definition = p.Growth.current_definition, .identity = identity, .target = definition.interpretation.interpretation.object, .action = .insert, .expected_definition = definition.interpretation.interpretation, .expected_data = definition.position, .intent = @splat(0) }, .interpretation = definition.interpretation, .schema = definition.schema, .changes = &changes, .ingestion = .point };
    rows.binding.intent = try rows.digest(alloc);
    (try client.call(.{ .admit_rows = rows })).deinit();
    const result = try client.call(.{ .operation = .{ .binding = rows.binding, .command = .execute, .steps = 1 } });
    defer result.deinit();
    try t.expect(result.value.result.rows == .committed);
    try t.expectEqual(@as(u64, 3), result.value.result.rows.committed.outcome.affected);
}
fn readResult(client: c.DirectTableClient, bundle: q.RelationalBundle, worker: support.Provision, identity: maintained.Identity, expected_count: u128, expected_sum: i128) !q.RelationalRevision.Position {
    const options: q.RelationalRevision.Options = .{ .owner = worker.pid, .resource = worker.resource, .identity = identity, .revision = 1, .requests = 4000 };
    const disclosure = try q.ResultDisclosure.prepare(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, try options.selection(bundle));
    var read = try q.RelationalRevision.open(.{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key }, bundle, options, disclosure, @splat(180));
    defer read.close() catch {};
    const output = (try read.next()).?.row;
    try t.expectEqual(expected_count, output.cells[0].value.atom.unsigned);
    try t.expectEqual(expected_sum, output.cells[1].value.atom.signed);
    try t.expect(try read.next() == null);
    return read.checkpoint();
}
pub fn run(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, case: Case) !void {
    const alloc = init.arena.allocator();
    const ordinal: u64 = @backingInt(case);
    const principal = 120 + ordinal;
    const seed: u8 = @intCast(90 + ordinal);
    const operation = 1000 + 10 * ordinal;
    const name = @tagName(case);
    const continuous = case == .maintained_overflow or case == .maintained_gap;
    var worker = try support.provision(admin, principal, seed);
    try support.table(alloc, client, role, 80 + ordinal, name, operation, 1);
    if (case == .captured_overflow) try insert(client, name, operation + 3, case != .maintained_gap);
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = worker.pid }, .grantee = role, .privileges = p.permission(.send) | p.permission(.inspect) } });
    worker.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = worker.pid } }, try support.key(17))).body.process.process.generation;
    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = principal } });
    worker.generation += 1;
    const found = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer found.deinit();
    const definition = found.value.result.lookup.?;
    const source = try q.TableSource.from(alloc, client.connection, definition);
    const schema = try q.fuze.TableSchema.decode(alloc, try definition.schema.decode(alloc, q.fuze.TableSchema.max_bytes));
    const declarations = [_]q.fuze.Relational.Source{.{ .alias = "i", .realm = 42, .resource = client.connection.scope.resource, .catalog = client.connection.scope.catalog, .owner = client.connection.audience, .schema = schema.schema }};
    const sources = [_]q.TableSource{source.source};
    var syntax = try q.fuze.RelationalSql.parse(alloc, try std.fmt.allocPrint(alloc, "SELECT COUNT(*) AS n, SUM(id) AS total FROM {s} i", .{name}), null);
    defer syntax.deinit();
    const description: q.RelationalBundle = .{ .sources = &sources, .plan = try syntax.bind(&declarations, if (continuous) .maintained else .captured, .{ .resident_bytes = @max(q.RelationalCapture.resident_base, q.RelationalMaintenance.resident_base) + 8 * 1024 * 1024, .spill_bytes = if (case == .captured_spill) 0 else 32 * 1024 * 1024, .result_bytes = 1024, .output_rows = 10, .work_steps = if (case == .captured_work) 1 else 10000, .source_pins = 1 }, null) };
    const bundle = try description.authorizeCapture(alloc, .{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, &.{client}, worker.pid, worker.resource, worker.pid, worker.resource, &.{.{ .executor = principal, .operation = operation + 2, .expected = definition.position }});
    var executor = client;
    executor.connection.principal = principal;
    executor.key = try support.key(seed);
    const clients = [_]c.DirectTableClient{executor};
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    var behavior: support.RelationalHost = .{ .bundle = bundle, .bytes = try bundle.encode(&bytes), .reference = try bundle.reference(worker.resource, 1), .clients = &clients, .workspace = try alloc.alloc(u8, 4 * 1024 * 1024) };
    const configuration: s.client.Session = .{ .client = client.authority, .realm = 42, .principal = principal, .pid = worker.pid, .generation = worker.generation, .key = executor.key };
    var running = try s.GenServer.init(configuration, "state");
    running.failure_policy = .stop;
    const resources: s.client.ResourceReader = .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key };
    try support.send(client, worker.pid, try .init("configure"));
    try support.send(client, worker.pid, try .init("upload"));
    var id: u64 = 0;
    var identity: maintained.Identity = undefined;
    var previous: ?q.RelationalRevision.Position = null;
    var previous_manifest: u64 = 0;
    var checkpoint: u64 = 0;
    var vector: q.RelationalHistory.Vector = undefined;
    var cuts: [q.fuze.Relational.max_sources]q.fuze.Relational.Cut = undefined;
    for (0..3000) |iteration| {
        // Recreate host memory while retaining the same durable worker identity.
        if (iteration != 0 and iteration % 17 == 0) {
            running = try s.GenServer.init(configuration, "state");
            running.failure_policy = .stop;
        }
        try step(init, &running, &behavior, admin);
        var reader = try resources.open(worker.resource);
        const correlation_value = (try reader.read(support.RelationalHost.correlation_key)) orelse continue;
        identity = .{ .peer = worker.pid, .correlation = try q.UnifiedRecords.readIdentity(correlation_value) };
        if (continuous) {
            const head = q.RelationalMaintenance.head(&reader, identity) catch |err| {
                if (err == error.QueryNotFound) continue;
                return err;
            };
            id = head.id;
            if (previous == null and head.phase == .idle) {
                previous = try readResult(client, bundle, worker, identity, 1, 0);
                previous_manifest = head.manifest;
                try insert(client, name, operation + 3, case != .maintained_gap);
                try support.send(client, worker.pid, try .init("wake"));
            }
            if (head.phase != .failed or head.cleanup_cursor != head.count) continue;
            try t.expect(previous != null);
            try t.expectEqual(@as(u64, 1), head.revision);
            try t.expectEqual(previous_manifest, head.manifest);
            const failure = try finite.Failure.decode((try reader.read(maintained.key('f', id, 2, 0))).?);
            try t.expectEqualStrings(if (case == .maintained_gap) "TableHistoryGap" else "Overflow", failure.cause.slice());
            try t.expectEqualDeep(previous.?, try readResult(client, bundle, worker, identity, 1, 0));
            if (case == .maintained_overflow) {
                const work = try maintained.Work.decode((try reader.read(maintained.key('w', id, 2, 0))).?);
                try t.expectEqual(.failed, work.phase);
                checkpoint = work.checkpoint;
                vector = try q.RelationalMaintenance.readBasis(&reader, bundle, head);
                try vector.boundCuts(bundle, &cuts);
            }
            break;
        } else {
            const index = (try reader.read(finite.key('i', worker.pid, identity.correlation))) orelse continue;
            id = try q.UnifiedRecords.readIdentity(index);
            const job = try q.RelationalCapture.job(&reader, id);
            if (job.phase != .failed) continue;
            const pin = (try q.CapturedTablePin.observe(alloc, &reader, .{ .job = id, .source = 0 }, worker.pid)).?;
            if (pin.phase != .closed) continue;
            try t.expect(job.released and job.manifest == 0);
            const failure = try finite.Failure.decode((try reader.read(finite.key('f', id, 0))).?);
            try t.expectEqualStrings(switch (case) {
                .captured_work => "RelationalWorkBudget",
                .captured_spill => "RelationalSpillBudget",
                else => "Overflow",
            }, failure.cause.slice());
            const retained = try q.RelationalCaptured.Vector.decode(bundle, (try reader.read(finite.key('v', id, 0))).?);
            try retained.boundCuts(bundle, &cuts);
            checkpoint = job.checkpoint;
            const options: q.RelationalResult.Options = .{ .owner = worker.pid, .peer = worker.pid, .resource = worker.resource, .job = id, .requests = 4000 };
            const disclosure = try q.ResultDisclosure.prepare(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, try options.selection(bundle));
            try t.expectError(error.IncompleteResult, q.RelationalResult.open(resources, bundle, options, disclosure, @splat(181)));
            break;
        }
    } else return error.RelationalFailurePending;
    var reader = try resources.open(worker.resource);
    if (case == .captured_overflow or case == .maintained_overflow) {
        const pages: q.RelationalState = .{ .publication = .{ .resource = worker.resource, .domain = .query_result, .namespace = (@as(u64, 1) << 63) | id } };
        const progress = try pages.checkpoint(&reader, checkpoint, .{ .plan = bundle.plan, .cuts = cuts[0..1] });
        try t.expectEqual(.failed, progress.phase);
        try t.expectEqual(@as(u8, 1), progress.failure.?.output);
        try t.expectEqual(operation + 3, progress.failure.?.pair.left.operation);
        try t.expectEqual(@as(u32, 1), progress.failure.?.pair.left.ordinal);
    }
    const grant = bundle.retention[0];
    const status = try client.call(.{ .pin_status = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner } });
    defer status.deinit();
    try t.expect(status.value.result.pin_state.released);
    if (continuous) {
        const before = try q.RelationalMaintenance.head(&reader, identity);
        const previous_wake = (try reader.read(support.RelationalHost.wake_key)).?;
        try support.send(client, worker.pid, try .init("wake"));
        for (0..100) |_| {
            try step(init, &running, &behavior, admin);
            reader = try resources.open(worker.resource);
            if (!(try reader.read(support.RelationalHost.wake_key)).?.eql(previous_wake)) break;
        } else return error.WakeDidNotCommit;
        reader = try resources.open(worker.resource);
        try t.expectEqualDeep(before, try q.RelationalMaintenance.head(&reader, identity));
        try t.expectEqualDeep(previous.?, try readResult(client, bundle, worker, identity, 1, 0));
        if (case == .maintained_gap) {
            try rebuild(init, client, admin, role, description, operation + 4);
            reader = try resources.open(worker.resource);
            try t.expectEqualDeep(before, try q.RelationalMaintenance.head(&reader, identity));
            try t.expectEqualDeep(previous.?, try readResult(client, bundle, worker, identity, 1, 0));
        }
    } else {
        try support.send(client, worker.pid, try .init("collect"));
        for (0..3000) |_| {
            try step(init, &running, &behavior, admin);
            reader = try resources.open(worker.resource);
            if (try reader.read(support.RelationalHost.collected_key)) |value| {
                try t.expectEqual(id, try q.UnifiedRecords.readIdentity(value));
                break;
            }
        } else return error.CollectionDidNotFinish;
        const job = try q.RelationalCapture.job(&reader, id);
        try t.expectEqual(std.math.maxInt(u64), job.cleanup);
        for (1..job.next_record) |record| {
            const publication = try job.publication(worker.resource).inspect(&reader, record);
            if (record == checkpoint) {
                try t.expectEqual(.published, publication.state);
            } else {
                try t.expectEqual(.retired, publication.state);
                try t.expectEqual(publication.written, publication.collected);
            }
        }
    }
}

/// Recovery after a terminal coverage failure requires another accepted identity,
/// its own current cut and a fresh lease. It cannot revive the failed query.
fn rebuild(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, description: q.RelationalBundle, operation: u64) !void {
    const alloc = init.arena.allocator();
    var worker = try support.provision(admin, 134, 104);
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = worker.pid }, .grantee = role, .privileges = p.permission(.send) | p.permission(.inspect) } });
    worker.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = worker.pid } }, try support.key(17))).body.process.process.generation;
    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = 134 } });
    worker.generation += 1;
    const found = try client.call(.{ .lookup = .{ .namespace = 1, .name = "maintained_gap" } });
    defer found.deinit();
    const current = found.value.result.lookup.?;
    try t.expectEqual(@as(u64, 4), current.row_count);
    const bundle = try description.authorizeCapture(alloc, .{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, &.{client}, worker.pid, worker.resource, worker.pid, worker.resource, &.{.{ .executor = 134, .operation = operation, .expected = current.position }});
    var executor = client;
    executor.connection.principal = 134;
    executor.key = try support.key(104);
    const clients = [_]c.DirectTableClient{executor};
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    var behavior: support.RelationalHost = .{ .bundle = bundle, .bytes = try bundle.encode(&bytes), .reference = try bundle.reference(worker.resource, 1), .clients = &clients, .workspace = try alloc.alloc(u8, 4 * 1024 * 1024) };
    const configuration: s.client.Session = .{ .client = client.authority, .realm = 42, .principal = 134, .pid = worker.pid, .generation = worker.generation, .key = executor.key };
    var running = try s.GenServer.init(configuration, "state");
    running.failure_policy = .stop;
    const resources: s.client.ResourceReader = .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key };
    try support.send(client, worker.pid, try .init("configure"));
    try support.send(client, worker.pid, try .init("upload"));
    var identity: maintained.Identity = undefined;
    for (0..3000) |iteration| {
        if (iteration != 0 and iteration % 17 == 0) {
            running = try s.GenServer.init(configuration, "state");
            running.failure_policy = .stop;
        }
        try step(init, &running, &behavior, admin);
        var reader = try resources.open(worker.resource);
        const correlation = (try reader.read(support.RelationalHost.correlation_key)) orelse continue;
        identity = .{ .peer = worker.pid, .correlation = try q.UnifiedRecords.readIdentity(correlation) };
        const head = q.RelationalMaintenance.head(&reader, identity) catch |err| {
            if (err == error.QueryNotFound) continue;
            return err;
        };
        if (head.phase == .failed) return error.RebuildFailed;
        if (head.phase == .idle and head.revision == 1) break;
    } else return error.RebuildPending;
    _ = try readResult(client, bundle, worker, identity, 4, 6);
    try support.send(client, worker.pid, try .init("close"));
    for (0..200) |_| {
        try step(init, &running, &behavior, admin);
        var reader = try resources.open(worker.resource);
        const head = try q.RelationalMaintenance.head(&reader, identity);
        if (head.phase == .cancelled and head.cleanup_cursor == head.count) break;
    } else return error.RebuildCleanupPending;
    const grant = bundle.retention[0];
    const status = try client.call(.{ .pin_status = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner } });
    defer status.deinit();
    try t.expect(status.value.result.pin_state.released);
    _ = try readResult(client, bundle, worker, identity, 4, 6);
}
