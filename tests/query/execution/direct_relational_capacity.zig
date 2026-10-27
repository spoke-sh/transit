//! Partial relational checkpoints survive physical storage refusal unchanged.
const std = @import("std");
const t = std.testing;
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const support = @import("fixture_direct_captured_query");
const exchange = @import("fixture_direct_relational_exchanges");
const files = @import("fixture_native_proof_files");
const principal = 145;
const seed = 117;
const checkpoint_file = "direct-relational-capacity.json";
pub const Mode = enum { prepare, pressure, recover };
const Saved = struct {
    definition: p.Growth.Definition,
    worker: support.Provision,
    bundle: c.DirectTableProtocol.Binary,
    job: u64,
};

fn resources(client: c.DirectTableClient) s.client.ResourceReader {
    return .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key };
}
pub fn snapshot(client: c.DirectTableClient, resource: u64) !s.client.WorkerHandoff.State {
    const access = resources(client);
    const metadata = (try access.query(.{ .resource = resource })).body.resource;
    var source = try access.open(resource);
    return s.client.WorkerHandoff.snapshot(&source, metadata, 10000);
}
fn load(init: std.process.Init, directory: []const u8) !Saved {
    const saved = try files.load(Saved, init, directory, checkpoint_file);
    if (saved.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    return saved;
}
pub fn status(init: std.process.Init, client: c.DirectTableClient, directory: []const u8) !s.client.WorkerHandoff.State {
    return snapshot(client, (try load(init, directory)).worker.resource);
}
fn prepare(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !Saved {
    const alloc = init.arena.allocator();
    var worker = try support.provision(admin, principal, seed);
    try support.table(alloc, client, role, 91, "pressure_left", 1900, 3);
    try support.table(alloc, client, role, 92, "pressure_right", 1910, 2);
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = worker.pid }, .grantee = role, .privileges = p.permission(.send) | p.permission(.inspect) } });
    worker.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = worker.pid } }, try support.key(17))).body.process.process.generation;
    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = principal } });
    worker.generation += 1;
    var sources: [2]q.TableSource = undefined;
    var declarations: [2]q.fuze.Relational.Source = undefined;
    var captures: [2]q.Bundle.Capture = undefined;
    for ([_][]const u8{ "pressure_left", "pressure_right" }, 0..) |name, i| {
        const found = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
        defer found.deinit();
        const definition = found.value.result.lookup.?;
        sources[i] = (try q.TableSource.from(alloc, client.connection, definition)).source;
        const schema = try q.fuze.TableSchema.decode(alloc, try definition.schema.decode(alloc, q.fuze.TableSchema.max_bytes));
        declarations[i] = .{ .alias = if (i == 0) "a" else "b", .realm = 42, .resource = client.connection.scope.resource, .catalog = client.connection.scope.catalog, .owner = client.connection.audience, .schema = schema.schema };
        captures[i] = .{ .executor = principal, .operation = 1902 + i * 10, .expected = definition.position };
    }
    var syntax = try q.fuze.RelationalSql.parse(alloc, "SELECT a.id AS id, COUNT(b.id) AS n, SUM(b.id) AS total FROM pressure_left a LEFT JOIN pressure_right b ON a.id = b.id GROUP BY a.id", null);
    defer syntax.deinit();
    const description: q.RelationalBundle = .{ .sources = &sources, .plan = try syntax.bind(&declarations, .captured, .{ .resident_bytes = q.RelationalCapture.resident_base + 8 * 1024 * 1024, .spill_bytes = 8 * 1024 * 1024, .result_bytes = 1024, .output_rows = 10, .work_steps = 10000, .source_pins = 2 }, null) };
    const bundle = try description.authorizeCapture(alloc, .{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, &.{ client, client }, worker.pid, worker.resource, worker.pid, worker.resource, &captures);
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    return .{ .definition = p.Growth.current_definition, .worker = worker, .bundle = try .encode(alloc, try bundle.encode(&bytes)), .job = 0 };
}
pub fn run(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64, directory: []const u8, mode: Mode) !void {
    const alloc = init.arena.allocator();
    var saved = if (mode == .prepare) try prepare(init, client, admin, role) else try load(init, directory);
    if (mode == .recover) {
        // Replacement is recorded before this executor resumes accepted work.
        // The immutable checkpoint still identifies the original selection.
        _ = try admin.submit(.{ .own = .{ .pid = saved.worker.pid, .expected_generation = saved.worker.generation, .worker = principal } });
        saved.worker.generation += 1;
    }
    const bytes = try saved.bundle.decode(alloc, q.RelationalBundle.max_bytes);
    var decoded = try q.RelationalBundle.decode(alloc, bytes);
    defer decoded.deinit();
    const bundle = decoded.bundle;
    var executor = client;
    executor.connection.principal = principal;
    executor.key = try support.key(seed);
    const clients = [_]c.DirectTableClient{ executor, executor };
    var behavior: support.RelationalHost = .{ .bundle = bundle, .bytes = bytes, .reference = try bundle.reference(saved.worker.resource, 1), .clients = &clients, .workspace = try alloc.alloc(u8, 4 * 1024 * 1024) };
    var host = try s.GenServer.init(.{ .client = client.authority, .realm = 42, .principal = principal, .pid = saved.worker.pid, .generation = saved.worker.generation, .key = executor.key }, "state");
    host.failure_policy = .stop;
    if (mode == .prepare) {
        try support.send(client, saved.worker.pid, try .init("configure"));
        try support.send(client, saved.worker.pid, try .init("upload"));
    }
    for (0..3000) |iteration| {
        // Under pressure this bounded attempt must return the authority's
        // failure. It cannot classify an interrupted write as a query failure.
        if (mode == .pressure and iteration == 32) return error.ExpectedStorageRefusal;
        try exchange.step(init, &host, behavior.interface(), admin);
        var source = try resources(client).open(saved.worker.resource);
        if (saved.job == 0) {
            const correlation = (try source.read(support.RelationalHost.correlation_key)) orelse continue;
            const index = (try source.read(q.RelationalRecords.key('i', saved.worker.pid, try q.UnifiedRecords.readIdentity(correlation)))) orelse continue;
            saved.job = try q.UnifiedRecords.readIdentity(index);
        }
        const job = try q.RelationalCapture.job(&source, saved.job);
        if (job.phase == .failed or job.phase == .denied) return error.RelationalQueryFailed;
        if (mode == .prepare and job.phase == .capturing and job.checkpoint != 0 and host.pending == null and host.delivery == null and host.ready == null) {
            try files.save(init, directory, checkpoint_file, saved);
            return;
        }
        if (job.phase != .complete) continue;
        if (mode != .recover) return error.MissingPartialCheckpoint;
        var closed = true;
        for (0..bundle.sources.len) |i| {
            const pin = (try q.CapturedTablePin.observe(alloc, &source, .{ .job = saved.job, .source = @intCast(i) }, saved.worker.pid)) orelse return error.MissingSourcePin;
            if (pin.phase != .closed) closed = false;
        }
        if (closed) break;
    } else return error.RelationalQueryPending;
    const options: q.RelationalResult.Options = .{ .owner = saved.worker.pid, .peer = saved.worker.pid, .resource = saved.worker.resource, .job = saved.job, .requests = 2000 };
    const disclosure = try q.ResultDisclosure.prepare(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, try options.selection(bundle));
    var result = try q.RelationalResult.open(resources(client), bundle, options, disclosure, @splat(185));
    defer result.close() catch {};
    var seen: [3]bool = @splat(false);
    while (try result.next()) |row| {
        const id = row.cells[0].value.atom.signed;
        try t.expect(id >= 0 and id < seen.len);
        const i: usize = @intCast(id);
        try t.expect(!seen[i]);
        seen[i] = true;
        try t.expectEqual(@as(u128, if (i == 2) 0 else 1), row.cells[1].value.atom.unsigned);
        if (i == 2) try t.expect(row.cells[2] == .null) else try t.expectEqual(id, row.cells[2].value.atom.signed);
    }
    try t.expectEqualDeep([_]bool{ true, true, true }, seen);
}
