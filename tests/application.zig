//! Actual public Station caller: signed operator input, fenced workers and AP1.
const std = @import("std");
const app = @import("transit_station_app");
const s = app.station;
const client = s.client;
const p = s.protocol;
const g = p.Growth;
const t = std.testing;
const Server = s.GrowingGenServer;
const Owner = app.Publication;
const Realm = 49;
const Worker = 65536;
const Operator = 65537;
const Admin = @import("growing_support.zig").Admin(Realm);
const Saved = struct { phase: []const u8, pid: u64, resource: u64, generation: u64, stale: ?g.SignedRequest = null };
fn owner() Owner {
    return .{ .configuration = .{ .application = 9, .namespace = .{ .value = 19 }, .realm = Realm, .administrator = Operator, .name_digest = Owner.nameDigest("board") } };
}
fn definition(allocator: std.mem.Allocator) ![]u8 {
    const source =
        \\CREATE INTERFACE board WITH (realm = 49, revision = 1, components = 1, entry = 'atlas', theme = 'mono');
        \\CREATE THEME board.mono WITH (density = 'comfortable');
        \\CREATE THEME board.dense WITH (density = 'compact');
        \\CREATE BINDING board.catalog WITH (kind = 'inspection', projection = 'atlas', page_budget = 1);
        \\CREATE SCREEN board.atlas WITH (path = '/atlas', label = 'Atlas', area = 'workspace', renderer = 'atlas', binding = 'catalog');
        \\CREATE SCREEN board.resources WITH (path = '/resources', label = 'Resources', area = 'workspace', renderer = 'records', binding = 'catalog');
        \\CREATE SCREEN board.operations WITH (path = '/operations', label = 'Operations', area = 'operations', renderer = 'operations', binding = 'catalog');
        \\CREATE SCREEN board.activity WITH (path = '/activity', label = 'Activity', area = 'workspace', renderer = 'activity', binding = 'catalog');
        \\CREATE ACTION board.open WITH (label = 'Open resources', kind = 'navigate', target = 'resources');
    ;
    var parsed = try app.Sql.parse(allocator, source);
    defer parsed.deinit();
    var buffer: [app.Model.max_program_bytes]u8 = undefined;
    return allocator.dupe(u8, try app.Api.canonical(parsed.definition, &buffer));
}
const Handler = struct {
    behavior: app.Behavior,
    handled: usize = 0,
    lost: usize = 0,
    fn initialize(raw: ?*anyopaque, turn: *s.GrowingTurn) !void {
        const self: *Handler = @ptrCast(@alignCast(raw.?));
        const target = self.behavior.interface();
        try target.initialize.?(target.context, turn);
    }
    fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) !void {
        const self: *Handler = @ptrCast(@alignCast(raw.?));
        self.handled += 1;
        const target = self.behavior.interface();
        try target.handle(target.context, turn, frame);
    }
    fn interface(self: *Handler) Server.Handler {
        return .{ .context = self, .initialize = initialize, .handle = handle };
    }
};
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.real.now(io).toMilliseconds());
}
fn drive(io: std.Io, server: *Server, handler: *Handler, freeze: bool) !void {
    for (0..24) |_| {
        if (freeze and server.pending != null and server.pending_kind == .commit) return;
        const before = handler.handled;
        const result = server.step(handler.interface(), now(io) + 30000) catch |err| {
            if (err != error.InvalidAuthorityResponse or server.pending == null) return err;
            try t.expectEqual(before, handler.handled);
            handler.lost += 1;
            continue;
        };
        switch (result) {
            .committed => return,
            .blocked => return server.handler_error orelse error.BehaviorBlocked,
            .idle => return error.MissingInput,
            .progress => {},
        }
    }
    return error.StepBudgetExceeded;
}
const Caller = struct {
    scope: app.Native.Scope,
    wire: *client.Client,
    key: p.Ed25519.KeyPair,
    sequence: u64,
    last_input: u64 = 0,
    fn send(self: *Caller, io: std.Io, server: *Server, handler: *Handler, command: app.Request.Command, freeze: bool) !void {
        const prepared = try app.Native.prepare(self.scope, Operator, .{ .value = self.sequence + 1 }, command);
        self.last_input = (try app.Native.submit(self.wire, self.scope, .{ .prepared = prepared, .signature = (try self.key.sign(&prepared.digest, null)).toBytes() })).position;
        self.sequence += 1;
        try drive(io, server, handler, freeze);
    }
};
fn sendPart(caller: *Caller, io: std.Io, server: *Server, handler: *Handler, proposal: Owner.Proposal, body: []const u8, ordinal: u32, second: bool, freeze: bool) !void {
    const length = try proposal.spec.size(ordinal);
    const offset: usize = if (second) s.PublicationParts.part_bytes else 0;
    try caller.send(io, server, handler, .{ .part = .{
        .operation = proposal.operation,
        .ordinal = ordinal,
        .second = second,
        .bytes = try p.Value.init(body[@as(usize, ordinal) * s.Publication.chunk_bytes + offset ..][0..@min(s.PublicationParts.part_bytes, length - offset)]),
    } }, freeze);
}
fn expectDenied(source: client.ResourceReader, resource: u64, input: u64) !void {
    var reader = try source.open(resource);
    const value = (try reader.read(app.Records.key(9, 'e', Operator, input))) orelse return error.MissingDisposition;
    try t.expectEqualStrings("ApplicationDenied", value.slice());
}
fn observe(source: client.ResourceReader, scope: app.Native.Scope, selection: app.Native.Selection) !app.Native.Observation {
    const prepared = try app.Native.prepareRead(scope, source.principal, selection);
    return app.Native.read(source.wire, scope, .{ .prepared = prepared, .signature = (try source.key.sign(&prepared.digest, null)).toBytes() });
}
fn descriptor(source: client.ResourceReader, resource: u64) !s.Publication.Descriptor {
    var reader = try source.open(resource);
    return (s.Publication{ .resource = resource, .namespace = 19 }).inspect(&reader, 100);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        var encoder: std.json.Stringify = .{ .writer = &output.interface };
        try p.Json.write(root_key.public_key.toBytes(), &encoder);
        return output.interface.flush();
    }
    if (args.len != 4) return error.Usage;
    var wire = client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &wire, .key = root_key };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    const worker_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const operator_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const phase = args[2];
    var saved: Saved = undefined;
    if (std.mem.eql(u8, phase, "stage")) {
        const created = try admin.provision(Worker, worker_key);
        saved = .{ .phase = phase, .pid = created.pid, .resource = created.resource, .generation = created.generation };
        _ = try admin.submit(.{ .grant = .{ .subject = Operator, .public_key = operator_key.public_key.toBytes(), .permissions = p.permission(.send) | p.permission(.inspect), .pid = saved.pid } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Operator, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    } else {
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.arena.allocator(), .limited(client.max_body));
        saved = (try std.json.parseFromSlice(Saved, init.arena.allocator(), data, .{})).value;
        saved.phase = phase;
        _ = try admin.submit(.{ .own = .{ .pid = saved.pid, .expected_generation = saved.generation, .worker = Worker } });
        saved.generation += 1;
        if (saved.stale) |request| {
            try t.expectError(error.Rejected, wire.submitGrowing(request));
            try t.expectEqual(.StaleGeneration, wire.last_rejection.?);
            saved.stale = null;
        }
    }
    const source: client.ResourceReader = .{ .wire = &wire, .realm = Realm, .principal = Operator, .key = operator_key };
    const native_scope: app.Native.Scope = .{ .realm = Realm, .application = 9, .pid = saved.pid, .resource = saved.resource, .namespace = .{ .value = 19 } };
    var caller: Caller = .{ .scope = native_scope, .wire = &wire, .key = operator_key, .sequence = (try observe(source, native_scope, .identity)).identity.sequence.value };
    var server = try Server.init(.{ .client = &wire, .realm = Realm, .principal = Worker, .pid = saved.pid, .generation = saved.generation, .key = worker_key }, "state");
    const body = try definition(init.gpa);
    defer init.gpa.free(body);
    const proposal: Owner.Proposal = .{ .operation = .{ .value = 1 }, .record = .{ .value = 100 }, .expected = .{}, .expected_digest = @splat(0), .revision = .{ .value = 1 }, .spec = try s.Publication.Digest.of(Owner.format, body) };
    var handler: Handler = .{ .behavior = .{ .allocator = init.gpa, .owner = owner() } };
    server.input_guard = handler.behavior.guard();
    if (std.mem.eql(u8, phase, "stage")) {
        try caller.send(init.io, &server, &handler, .{ .policy = .{ .principal = Operator, .expected = .{}, .next = .{ .revision = .{ .value = 1 }, .publish = true } } }, false);
        try caller.send(init.io, &server, &handler, .{ .begin = proposal }, false);
        for (0..3) |i| {
            try sendPart(&caller, init.io, &server, &handler, proposal, body, @intCast(i), false, false);
            try sendPart(&caller, init.io, &server, &handler, proposal, body, @intCast(i), true, false);
        }
        try sendPart(&caller, init.io, &server, &handler, proposal, body, 3, false, true);
        saved.stale = server.pending.?.signed;
        try t.expectEqual(@as(u32, 3), (try descriptor(source, saved.resource)).written);
        try t.expectEqual(@as(usize, 1), handler.lost);
    } else if (std.mem.eql(u8, phase, "seal")) {
        try drive(init.io, &server, &handler, false);
        var current = try descriptor(source, saved.resource);
        while (current.written < current.spec.chunks()) {
            try sendPart(&caller, init.io, &server, &handler, proposal, body, current.written, false, false);
            if (try current.spec.size(current.written) > s.PublicationParts.part_bytes) try sendPart(&caller, init.io, &server, &handler, proposal, body, current.written, true, false);
            current = try descriptor(source, saved.resource);
        }
        try caller.send(init.io, &server, &handler, .{ .publish = proposal.operation }, true);
        saved.stale = server.pending.?.signed;
        try t.expectEqual(s.Publication.State.staging, (try descriptor(source, saved.resource)).state);
        var reader = try source.open(saved.resource);
        try t.expect(try owner().head(&reader) == null);
    } else if (std.mem.eql(u8, phase, "publish")) {
        try drive(init.io, &server, &handler, false);
        try t.expectEqual(@as(usize, 1), handler.lost);
        try caller.send(init.io, &server, &handler, .{ .publish = proposal.operation }, false); // exact application duplicate
        const observed = (try observe(source, native_scope, .{ .state = .{ .operation = proposal.operation, .record = proposal.record, .input = caller.last_input } })).state;
        const head = observed.head.?;
        const receipt = observed.receipt.?;
        try t.expectEqual(s.Publication.State.published, observed.upload.?.state);
        try t.expectEqual(Owner.Phase.applied, receipt.phase);
        try t.expectEqual(Operator, head.principal);
        try t.expectEqual(head.input, receipt.input);
        var bytes: [app.Model.max_program_bytes]u8 = undefined;
        try t.expectEqualStrings(body, try owner().reference(saved.resource, head).read(source, &bytes));
        try caller.send(init.io, &server, &handler, .{ .policy = .{ .principal = Operator, .expected = .{ .value = 1 }, .next = .{ .revision = .{ .value = 2 }, .publish = false } } }, false);
        try caller.send(init.io, &server, &handler, .{ .publish = proposal.operation }, false);
        try expectDenied(source, saved.resource, caller.last_input);
        _ = try admin.submit(.{ .checkpoint = {} });
    } else if (std.mem.eql(u8, phase, "finish")) {
        try caller.send(init.io, &server, &handler, .{ .publish = proposal.operation }, false);
        try expectDenied(source, saved.resource, caller.last_input); // denial persists across disk restart
        try caller.send(init.io, &server, &handler, .{ .policy = .{ .principal = Operator, .expected = .{ .value = 2 }, .next = .{ .revision = .{ .value = 3 }, .publish = true } } }, false); // independent bootstrap recovery
        try caller.send(init.io, &server, &handler, .{ .publish = proposal.operation }, false);
        const observed = (try observe(source, native_scope, .{ .state = .{ .operation = proposal.operation, .record = proposal.record } })).state;
        const head = observed.head.?;
        try t.expect(observed.policy.?.publish);
        try t.expectEqual(@as(u64, 1), head.revision.value);
        var bytes: [app.Model.max_program_bytes]u8 = undefined;
        const reference = owner().reference(saved.resource, head);
        try t.expectEqualStrings(body, try reference.read(source, &bytes));
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Operator, .permissions = 0 } });
        try t.expectError(error.AccessDenied, reference.read(source, &bytes));
        try t.expectError(error.AccessDenied, observe(source, native_scope, .{ .state = .{} }));
        try output.interface.print("Application: {d} body bytes, signed operator={d}, four mutations, exact retries, policy and resource denial passed\n", .{ body.len, Operator });
    } else return error.UnknownPhase;
    const encoded = try p.Json.valueAlloc(init.gpa, saved);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = encoded });
    try output.interface.print("Application {s}: generation={d}\n", .{ phase, saved.generation });
    try output.interface.flush();
    if (!std.mem.eql(u8, phase, "finish")) while (true) try init.io.sleep(.fromSeconds(30), .awake);
}
