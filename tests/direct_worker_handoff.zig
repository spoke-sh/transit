//! Recorded worker replacement preserves a borrowed direct Table history cut.
const std = @import("std");
const t = std.testing;
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const h = s.client.WorkerHandoff;
const files = @import("native_proof_files.zig");
const support = @import("direct_captured_query.zig");

fn process(client: c.DirectTableClient, pid: u64) !g.Process {
    return (try client.authority.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = pid } }, try support.key(17))).body.process.process;
}
fn retained(init: std.process.Init, directory: []const u8, record: h.Record) !h.Record {
    const encoded = try record.save(init.gpa);
    defer init.gpa.free(encoded);
    try files.saveBytes(init, directory, "direct-worker-handoff.json", encoded);
    const restored = try files.loadBytes(init, directory, "direct-worker-handoff.json", h.Record.max_bytes);
    defer init.gpa.free(restored);
    const result = try h.Record.restore(init.gpa, restored);
    try t.expectEqualDeep(record, result);
    return result;
}
fn command(init: std.process.Init, directory: []const u8, client: c.DirectTableClient, record: h.Record) !void {
    const current = try client.authority.query(.{ .realm = 42, .principal = 0, .kind = .capabilities }, try support.key(17));
    const signed = try g.sign(.{ .realm = 42, .principal = 0, .sequence = current.principal_sequence + 1, .command = try record.command() }, try support.key(17));
    try files.save(init, directory, "direct-worker-command.json", signed);
    const saved = try files.load(g.SignedRequest, init, directory, "direct-worker-command.json");
    const accepted = try client.authority.submit(saved);
    // Recover exactly the saved command after acceptance, independently of the
    // host's later phase observation. This is not another control operation.
    const repeated = try client.authority.submit(try files.load(g.SignedRequest, init, directory, "direct-worker-command.json"));
    try t.expectEqualDeep(accepted, repeated);
}
fn snapshot(client: c.DirectTableClient, resource_id: u64) !h.State {
    const scoped: s.client.ResourceReader = .{ .wire = client.authority, .realm = 42, .principal = client.connection.principal, .key = client.key };
    const resource = (try scoped.query(.{ .resource = resource_id })).body.resource;
    var source = try scoped.open(resource_id);
    return h.snapshot(&source, resource, 10000);
}
pub fn run(init: std.process.Init, directory: []const u8, client: c.DirectTableClient, worker: support.Provision, bundle: q.RelationalBundle, vector: q.RelationalHistory.Vector, authorization: q.ExchangeAuthorization, borrows: []const c.DirectReadDelegation.Borrow) !struct { key: p.Ed25519.KeyPair, generation: u64 } {
    const fresh = try support.key(114);
    var cuts: [q.fuze.Relational.max_sources]q.fuze.Relational.Cut = undefined;
    try vector.boundCuts(bundle, &cuts);
    const application = try (q.fuze.Relational.Bound{ .plan = bundle.plan, .cuts = cuts[0..vector.count] }).fingerprint();
    var record = try retained(init, directory, try h.Record.start(.{
        .id = authorization.assignment.exchange,
        .realm = 42,
        .pid = worker.pid,
        .resource = worker.resource,
        .worker = client.connection.principal,
        .generation = worker.generation,
        .resume_before_ms = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 60000),
        .expected_public_key = client.key.public_key.toBytes(),
        .public_key = fresh.public_key.toBytes(),
        .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish),
        .application = application,
        .old_instance = @splat(1),
        .new_instance = @splat(2),
    }));
    try command(init, directory, client, record);
    record = try retained(init, directory, try record.quiesce(try process(client, worker.pid)));
    record = try retained(init, directory, try record.capture(try process(client, worker.pid), try snapshot(client, worker.resource)));
    try command(init, directory, client, record);
    const fenced = try process(client, worker.pid);
    record = try retained(init, directory, try record.fence(fenced));
    try t.expect(fenced.owner == null);
    // Restoration checks the exact source vector through current borrowed read
    // rights while this worker has no execution ownership. No Table pin changes.
    for (borrows, bundle.retention, vector.entries[0..vector.count], 0..) |borrow, grant, entry, i| {
        try t.expectEqualDeep(try authorization.readBinding(bundle, vector, i, client.connection.principal), borrow.binding);
        const borrowed = try q.CapturedTablePin.borrowedClient(client, grant, borrow);
        var source = try c.DirectTableReader.openHistory(init.gpa, borrowed, .{ .object = entry.record.basis.snapshot.object, .point = entry.record.point() orelse return error.ExpectedHistoryCut });
        defer source.deinit();
        try t.expectEqualDeep(entry.record.basis, source.basis);
        try t.expectEqualSlices(u8, &try bundle.plan.sources[i].schema.fingerprint(), &try source.schema.schema.fingerprint());
    }
    record = try retained(init, directory, try record.restored(fenced, try snapshot(client, worker.resource), application));
    try command(init, directory, client, record);
    const identity = (try client.authority.query(.{ .realm = 42, .principal = client.connection.principal, .kind = .identity }, fresh)).body.identity;
    record = try retained(init, directory, try record.activate(try process(client, worker.pid), .{ .subject = identity.principal, .pid = identity.pid, .permissions = identity.permissions, .public_key = fresh.public_key.toBytes() }));
    try t.expectError(error.AccessDenied, client.authority.query(.{ .realm = 42, .principal = client.connection.principal, .kind = .identity }, client.key));
    // The replaced in-process host is discarded by the caller. No provider or
    // OS-process termination is claimed by this reconstruction schedule.
    record = try retained(init, directory, try record.retire(record.plan.old_instance));
    try t.expectEqual(.retired, record.phase);
    return .{ .key = fresh, .generation = record.plan.generation + 3 };
}
