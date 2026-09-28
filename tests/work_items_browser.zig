//! Real generated application: separate publication, data and requester owners.
const std = @import("std");
const W = @import("work_items");
const app = W.app;
const q = W.query;
const s = app.station;
const p = app.protocol;
const proof = @import("work_items.zig");
const Admin = @import("growing_support.zig").Admin(51);
const Saved = struct { data: proof.Saved, requests: proof.Saved, publication: proof.Saved };
const limits: q.Bundle.Limits = .{ .pages = 64, .segments = 16, .result_bytes = 65536 };
fn key(seed: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(seed));
}
fn connection(saved: Saved) q.UnifiedClient.Connection {
    return .{ .realm = 51, .principal = 1234, .source = saved.data.pid, .resource = saved.data.resource, .requester = saved.requests.pid, .requests = saved.requests.resource };
}
fn publication() app.Publication {
    return .{ .configuration = .{ .application = 9, .realm = 51, .namespace = .{ .value = 19 }, .administrator = 65537, .name_digest = app.Publication.nameDigest("work_items") } };
}
fn policy(caller: *proof.Caller, init: std.process.Init, saved: Saved, revision: u64) !void {
    _ = try caller.sendPayload(init.io, try (q.UnifiedRecords.Policy{ .peer = saved.requests.pid, .requests = saved.requests.resource, .revision = revision, .declaration = try q.Bundle.declaration(try proof.owner(saved.data).source(@intCast(revision))), .allow = true, .limits = limits }).encode(), null);
}
fn publish(caller: *proof.Caller, init: std.process.Init, saved: Saved, revision: u64) !void {
    caller.saved = saved.publication;
    defer caller.saved = saved.data;
    var reader = try caller.read();
    const previous = try publication().head(&reader);
    var parsed = try app.Sql.parse(init.arena.allocator(), try std.Io.Dir.cwd().readFileAlloc(init.io, "examples/work-items/interface.sql", init.arena.allocator(), .limited(app.Model.max_program_bytes)));
    defer parsed.deinit();
    parsed.definition.revision = .{ .value = revision };
    parsed.definition.theme = if (revision == 1) "mono" else "dense";
    const bindings = try init.arena.allocator().dupe(app.Model.Binding, parsed.definition.bindings);
    parsed.definition.bindings = bindings;
    for (bindings) |*binding| if (binding.source == .query) {
        binding.source.query.resource = saved.data.resource;
        binding.source.query.schema = try (try proof.owner(saved.data).source(@intCast(revision))).fingerprint();
    };
    var buffer: [app.Model.max_program_bytes]u8 = undefined;
    const body = try app.Api.canonical(parsed.definition, &buffer);
    const proposal: app.Publication.Proposal = .{ .operation = .{ .value = revision }, .record = .{ .value = 100 + revision }, .expected = if (previous) |h| h.revision else .{}, .expected_digest = if (previous) |h| h.spec.digest else @splat(0), .revision = .{ .value = revision }, .spec = try s.Publication.Digest.of(app.Publication.format, body) };
    _ = try caller.sendPayload(init.io, try (app.Request.Command{ .begin = proposal }).encode(), null);
    var offset: usize = 0;
    while (offset < body.len) {
        const count = @min(s.PublicationParts.part_bytes, body.len - offset);
        _ = try caller.sendPayload(init.io, try (app.Request.Command{ .part = .{ .operation = proposal.operation, .ordinal = @intCast(offset / s.Publication.chunk_bytes), .second = offset % s.Publication.chunk_bytes != 0, .bytes = try p.Value.init(body[offset..][0..count]) } }).encode(), null);
        offset += count;
    }
    _ = try caller.sendPayload(init.io, try (app.Request.Command{ .publish = proposal.operation }).encode(), null);
    reader = try caller.read();
    const head = (try publication().head(&reader)) orelse return error.PublicationNotApplied;
    try std.testing.expectEqual(revision, head.revision.value);
    try std.testing.expectEqualSlices(u8, &proposal.spec.digest, &head.spec.digest);
}
fn path(init: std.process.Init, directory: []const u8, name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
}
fn seedFile(init: std.process.Init, directory: []const u8, name: []const u8, seed: u8) ![]const u8 {
    const result = try path(init, directory, name);
    const bytes: [32]u8 = @splat(seed);
    const hex = std.fmt.bytesToHex(bytes, .lower);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = result, .data = &hex });
    return result;
}
fn provision(admin: *Admin, principal: u64, seed: u8, foreign: ?u64) !proof.Saved {
    const v = try admin.provisionReader(principal, try key(seed), foreign);
    return .{ .pid = v.pid, .resource = v.resource, .generation = v.generation, .activation = seed };
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        var buffer: [1024]u8 = undefined;
        var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try std.json.Stringify.value((try key(7)).public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4) return error.Usage;
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &wire, .key = try key(7) };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    const phase = args[2];
    const directory = args[3];
    const saved_path = try path(init, directory, "application.json");
    if (std.mem.eql(u8, phase, "setup")) {
        const requests = try provision(&admin, 65539, 12, null);
        const data = try provision(&admin, 65536, 8, requests.resource);
        const pub_owner = try provision(&admin, 65540, 13, null);
        const saved: Saved = .{ .data = data, .requests = requests, .publication = pub_owner };
        for ([_]struct { id: u64, seed: u8, permissions: u16, pid: ?u64 }{
            .{ .id = 65537, .seed = 9, .permissions = p.permission(.inspect) | p.permission(.send), .pid = null },
            .{ .id = 65538, .seed = 11, .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery), .pid = null },
            .{ .id = 1234, .seed = 10, .permissions = p.permission(.inspect) | p.permission(.send), .pid = null },
            .{ .id = 65541, .seed = 14, .permissions = p.permission(.inspect), .pid = pub_owner.pid },
        }) |v| _ = try admin.submit(.{ .grant = .{ .subject = v.id, .public_key = (try key(v.seed)).public_key.toBytes(), .permissions = v.permissions, .pid = v.pid } });
        for ([_]struct { subject: u64, resource: u64 }{
            .{ .subject = 65537, .resource = data.resource },      .{ .subject = 65537, .resource = pub_owner.resource },
            .{ .subject = 1234, .resource = data.resource },       .{ .subject = 1234, .resource = requests.resource },
            .{ .subject = 65541, .resource = pub_owner.resource },
        }) |v| _ = try admin.submit(.{ .grant_resource = .{ .resource = v.resource, .subject = v.subject, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        try proof.write(init, saved_path, saved);
        try proof.write(init, try path(init, directory, "data.json"), .{ .url = args[1], .principal = @as(u64, 65536), .pid = data.pid, .generation = data.generation, .seed_file = try seedFile(init, directory, "data.seed", 8), .activation_directory = directory, .application = proof.owner(data).configuration, .query_peer = requests.pid });
        try proof.write(init, try path(init, directory, "publication.json"), .{ .url = args[1], .principal = @as(u64, 65540), .pid = pub_owner.pid, .generation = pub_owner.generation, .seed_file = try seedFile(init, directory, "publication.seed", 13), .activation_directory = directory, .application = proof.owner(pub_owner).configuration, .publication = publication().configuration });
        try proof.write(init, try path(init, directory, "requester.json"), .{ .url = args[1], .realm = @as(u64, 51), .principal = @as(u64, 65539), .pid = requests.pid, .generation = requests.generation, .seed_file = try seedFile(init, directory, "requester.seed", 12), .activation_directory = directory, .role = .{ .unified_requester = .{ .principal = @as(u64, 1234), .source = data.pid } } });
        try proof.write(init, try path(init, directory, "courier.json"), .{ .url = args[1], .realm = @as(u64, 51), .principal = @as(u64, 65538), .seed_file = try seedFile(init, directory, "courier.seed", 11), .role = .{ .courier = .{ .destinations = [2]u64{ data.pid, requests.pid } } } });
        return proof.write(init, try path(init, directory, "gateway-base.json"), .{ .url = args[1], .inspection = .{ .principal = @as(u64, 65541), .seed_file = try seedFile(init, directory, "inspection.seed", 14) }, .application = app.Host.Config{ .scope = .{ .realm = 51, .application = 9, .pid = pub_owner.pid, .resource = pub_owner.resource, .namespace = .{ .value = 19 } }, .operators = .{65537} ++ @as([15]?u64, @splat(null)) }, .data = proof.owner(data).configuration, .query = .{ .connection = connection(saved), .seed_file = try seedFile(init, directory, "query.seed", 10), .limits = try q.Values.Limits.fromNative(init.arena.allocator(), limits) } });
    }
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, saved_path, init.arena.allocator(), .limited(4096));
    const saved = (try std.json.parseFromSlice(Saved, init.arena.allocator(), bytes, .{})).value;
    var caller: proof.Caller = .{ .wire = &wire, .key = try key(9), .saved = saved.data, .sequence = 0 };
    caller.sequence = (try caller.resources().query(.{ .capabilities = {} })).principal_sequence;
    if (std.mem.eql(u8, phase, "seed")) {
        _ = try caller.send(init.io, .initialize, null);
        _ = try caller.send(init.io, .{ .policy = .{ .principal = 65537, .expected = .{}, .next = .{ .revision = .{ .value = 1 }, .migrate = true } } }, null);
        for (0..19) |i| _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 1 }, .id = @as(i64, @intCast(i)) - 10, .state = @intCast(i % 2) } }, null);
        try policy(&caller, init, saved, 1);
        _ = try caller.sendPayload(init.io, try p.Value.init("not-a-query-control"), "WorkItemDenied");
        var query: q.UnifiedClient = .{ .wire = &wire, .connection = connection(saved), .key = try key(10) };
        const receipt = try query.submit(try query.prepare(.initialize));
        for (0..400) |_| {
            if (try query.observe(receipt.position) == .committed) break;
            try init.io.sleep(.fromMilliseconds(25), .awake);
        } else return error.RequesterTimeout;
        caller.saved = saved.publication;
        _ = try caller.sendPayload(init.io, try app.Request.Command.encode(.initialize), null);
        _ = try caller.sendPayload(init.io, try (app.Request.Command{ .policy = .{ .principal = 65537, .expected = .{}, .next = .{ .revision = .{ .value = 1 }, .publish = true } } }).encode(), null);
        caller.saved = saved.data;
        try publish(&caller, init, saved, 1);
    } else if (std.mem.eql(u8, phase, "migrate")) {
        _ = try caller.send(init.io, .{ .begin = try proof.owner(saved.data).proposal(2) }, null);
        const ledger = try proof.owner(saved.data).ledger();
        for (0..64) |_| {
            var reader = try caller.read();
            const progress = try ledger.progress(&reader, .{ .value = 2 });
            if (progress.phase == .applied) break;
            const cursor = try W.Cursor.decode(progress.cursor);
            _ = try caller.send(init.io, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = progress.next, .operation = if (cursor.phase == .ready) 2 else 1, .arguments = progress.cursor } }, null);
        } else return error.MigrationTimeout;
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 2 }, .id = 99, .state = 20 } }, "WorkItemPublicationPaused");
        try policy(&caller, init, saved, 2);
        try publish(&caller, init, saved, 2);
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 99, .state = 1 } }, "WorkItemEpochChanged");
        _ = try caller.send(init.io, .{ .release_writes = .{ .epoch = .{ .value = 2 }, .contract = try (try proof.owner(saved.data).source(2)).fingerprint() } }, null);
    } else if (std.mem.eql(u8, phase, "deny")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.data.resource, .subject = 1234, .permissions = p.State.permission(.inspect) } });
    } else return error.UnknownPhase;
}
