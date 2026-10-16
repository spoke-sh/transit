//! One phase per invocation, with a private fsynced manager record and exact
//! root-signed pending request. Native history remains the only execution owner.
const std = @import("std");
const q = @import("transit_query");
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const h = s.client.WorkerHandoff;
const Pending = struct { definition: g.Definition, id: u64, phase: h.Phase, pending: s.client.Session.Pending };
fn hash(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
pub fn run(comptime Test: type, init: std.process.Init, wire: *s.client.Client, directory: []const u8, bundle: q.RelationalBundle, basis: q.RelationalHistory.Vector, metadata: anytype, index: usize, mode: []const u8) !void {
    const worker = metadata.workers[index];
    var cuts: [2]q.fuze.Relational.Cut = undefined;
    try basis.boundCuts(bundle, &cuts);
    const application = try (q.fuze.Relational.Bound{ .plan = bundle.plan, .cuts = cuts[0..basis.count] }).fingerprint();
    const reader: s.client.ResourceReader = .{ .wire = wire, .realm = 46, .principal = 0, .key = try Test.key(7) };
    const name = try std.fmt.allocPrint(init.arena.allocator(), "handoff-{d}.json", .{worker.process.pid});
    const pending_name = try std.fmt.allocPrint(init.arena.allocator(), "handoff-pending-{d}.json", .{worker.process.pid});
    if (std.mem.eql(u8, mode, "begin")) {
        const previous = Test.loadBytes(init, directory, name, h.Record.max_bytes) catch |err| switch (err) {
            error.FileNotFound => null,
            else => return err,
        };
        if (previous) |bytes| {
            defer init.gpa.free(bytes);
            const record = try h.Record.restore(init.gpa, bytes);
            if (record.plan.id != metadata.id or record.plan.pid != worker.process.pid) return error.InvalidProofHandoff;
            return Test.print(init, .{ .phase = record.phase });
        }
        const worker_pending_name = try std.fmt.allocPrint(init.arena.allocator(), "exchange-worker-{d}.json", .{worker.process.pid});
        const worker_pending = Test.loadBytes(init, directory, worker_pending_name, p.max_body) catch |err| switch (err) {
            error.FileNotFound => null,
            else => return err,
        };
        if (worker_pending) |bytes| {
            init.gpa.free(bytes);
            return error.PendingOperation;
        }
        if (worker.fresh_key) return error.InvalidProofPhase;
        const old = try std.fmt.allocPrint(init.arena.allocator(), "producer:{d}:{d}:old", .{ worker.process.pid, worker.process.generation });
        const fresh = try std.fmt.allocPrint(init.arena.allocator(), "producer:{d}:{d}:new", .{ worker.process.pid, worker.process.generation });
        const record = try h.Record.start(.{ .id = metadata.id, .realm = 46, .pid = worker.process.pid, .resource = worker.process.resource, .worker = worker.principal, .generation = worker.process.generation, .resume_before_ms = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 60000), .expected_public_key = (try Test.key(8)).public_key.toBytes(), .public_key = (try Test.key(11)).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .application = application, .old_instance = hash(old), .new_instance = hash(fresh) });
        const bytes = try record.save(init.gpa);
        defer init.gpa.free(bytes);
        // Explicit fixture admission occurs once. Recovery always calls step.
        try Test.saveBytes(init, directory, name, bytes);
        return Test.print(init, .{ .phase = record.phase });
    }
    const bytes = try Test.loadBytes(init, directory, name, h.Record.max_bytes);
    defer init.gpa.free(bytes);
    var record = try h.Record.restore(init.gpa, bytes);
    if (record.plan.id != metadata.id or record.plan.pid != worker.process.pid or record.plan.resource != worker.process.resource or !std.mem.eql(u8, &record.plan.application, &application)) return error.InvalidProofHandoff;
    if (std.mem.eql(u8, mode, "status")) return Test.print(init, record);
    if (!std.mem.eql(u8, mode, "step")) return error.InvalidProofCommand;
    var saved = Test.load(Pending, init, directory, pending_name) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (saved == null and (record.phase == .planned or record.phase == .checkpointed or record.phase == .restored)) {
        const current = try reader.query(.capabilities);
        saved = .{ .definition = g.current_definition, .id = record.plan.id, .phase = record.phase, .pending = .{ .signed = try g.sign(.{ .realm = 46, .principal = 0, .sequence = current.principal_sequence + 1, .command = try record.command() }, try Test.key(7)) } };
        try Test.save(init, directory, pending_name, saved.?);
    }
    var advance = true;
    if (saved) |pending| {
        if (pending.definition != g.current_definition or pending.id != record.plan.id) return error.InvalidProofHandoff;
        _ = try pending.pending.submit(wire);
        if (record.phase != pending.phase) {
            const expected: h.Phase = switch (pending.phase) {
                .planned => .quiesced,
                .checkpointed => .fenced,
                .restored => .activated,
                else => return error.InvalidProofHandoff,
            };
            if (record.phase != expected) return error.InvalidProofHandoff;
            advance = false;
        }
    }
    const process = (try reader.query(.{ .process = worker.process.pid })).body.process.process;
    if (advance) switch (record.phase) {
        .planned => record = try record.quiesce(process),
        .quiesced, .fenced => {
            // Read with the scoped worker's current grants, while it has no
            // execution ownership. All application source dependencies apply.
            const scoped: s.client.ResourceReader = .{ .wire = wire, .realm = 46, .principal = worker.principal, .key = try Test.key(8) };
            const resource = (try scoped.query(.{ .resource = worker.process.resource })).body.resource;
            var source = try scoped.open(resource.id);
            const snapshot = try h.snapshot(&source, resource, 10000);
            if (record.phase == .quiesced) {
                record = try record.capture(process, snapshot);
            } else {
                const assignment: q.ExchangeAuthorization.Assignment = .{ .exchange = metadata.id, .producer = worker.process.pid, .options = .{ .partitions = metadata.partitions, .workers = metadata.workers.len, .worker = index, .batch = metadata.batch, .epoch = 1, .quota = 4 * 1024 * 1024 } };
                const original = try worker.authorization.subject(assignment, bundle, basis);
                for (bundle.sources, basis.entries[0..basis.count], 0..) |declared, entry, ordinal| {
                    var data = try scoped.open(declared.scope.resource);
                    var current = q.QueryAuthorization.readerContext(scoped, original, null).wrap(&data);
                    _ = try declared.checkCurrent(&current, 1234);
                    const observed = try s.TableHistory.at(&current, try s.TableHistory.current(&current, declared.object), entry.position);
                    if (!(try observed.encode()).eql(try entry.record.encode())) return error.TableHistoryConflict;
                    var schema = try entry.record.head.readSchema(init.gpa, &current);
                    defer schema.deinit();
                    if (!std.mem.eql(u8, &try schema.schema.fingerprint(), &try bundle.plan.sources[ordinal].schema.fingerprint())) return error.TableSchemaChanged;
                    try current.finish();
                }
                record = try record.restored(process, snapshot, application);
            }
        },
        .checkpointed => record = try record.fence(process),
        .restored => {
            const identity = (try wire.query(.{ .realm = 46, .principal = worker.principal, .kind = .identity }, try Test.key(11))).body.identity;
            record = try record.activate(process, .{ .subject = identity.principal, .pid = identity.pid, .permissions = identity.permissions, .public_key = (try Test.key(11)).public_key.toBytes() });
            try std.testing.expectError(error.AccessDenied, wire.query(.{ .realm = 46, .principal = worker.principal, .kind = .identity }, try Test.key(8)));
        },
        .activated => record = try record.retire(record.plan.old_instance),
        .retired => {},
    };
    const encoded = try record.save(init.gpa);
    defer init.gpa.free(encoded);
    try Test.saveBytes(init, directory, name, encoded);
    if (record.phase == .activated or record.phase == .retired) {
        metadata.workers[index].process.generation = record.plan.generation + 3;
        metadata.workers[index].fresh_key = true;
        try Test.save(init, directory, "exchange-native.json", metadata.*);
    }
    if (saved != null) try std.Io.Dir.cwd().deleteFile(init.io, try Test.path(init, directory, pending_name));
    return Test.print(init, .{ .phase = record.phase });
}
