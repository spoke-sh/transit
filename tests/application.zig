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
    allocator: std.mem.Allocator,
    body: []const u8,
    proposal: Owner.Proposal,
    handled: usize = 0,
    lost: usize = 0,
    fn initialize(_: ?*anyopaque, turn: *s.GrowingTurn) !void {
        try owner().initialize(turn);
        try owner().setPolicy(turn, Operator, .{}, .{ .revision = .{ .value = 1 }, .publish = true });
    }
    fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) !void {
        const self: *Handler = @ptrCast(@alignCast(raw.?));
        self.handled += 1;
        switch (try frame.payload.asInteger()) {
            0 => {},
            1 => _ = try owner().step(self.allocator, turn, self.proposal, self.body),
            2 => try owner().setPolicy(turn, Operator, .{ .value = 1 }, .{ .revision = .{ .value = 2 }, .publish = false }),
            3 => try t.expectError(error.ApplicationDenied, owner().step(self.allocator, turn, self.proposal, self.body)),
            4 => try owner().setPolicy(turn, Operator, .{ .value = 2 }, .{ .revision = .{ .value = 3 }, .publish = true }),
            else => return error.UnknownCommand,
        }
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
    wire: *client.Client,
    key: p.Ed25519.KeyPair,
    sequence: u64,
    fn send(self: *Caller, io: std.Io, server: *Server, handler: *Handler, code: i64, freeze: bool) !void {
        _ = try self.wire.submitGrowing(try g.sign(.{ .realm = Realm, .principal = Operator, .sequence = self.sequence + 1, .command = .{ .send = .{ .pid = server.session.pid, .value = try (s.Frame{ .kind = .cast, .payload = p.Value.integer(code) }).encode() } } }, self.key));
        self.sequence += 1;
        try drive(io, server, handler, freeze);
    }
};
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
    var caller: Caller = .{ .wire = &wire, .key = operator_key, .sequence = (try source.query(.{ .capabilities = {} })).principal_sequence };
    var server = try Server.init(.{ .client = &wire, .realm = Realm, .principal = Worker, .pid = saved.pid, .generation = saved.generation, .key = worker_key }, "state");
    const body = try definition(init.gpa);
    defer init.gpa.free(body);
    const proposal: Owner.Proposal = .{ .operation = .{ .value = 1 }, .record = .{ .value = 100 }, .expected = .{}, .expected_digest = @splat(0), .revision = .{ .value = 1 }, .spec = try s.Publication.Digest.of(Owner.format, body) };
    var handler: Handler = .{ .allocator = init.gpa, .body = body, .proposal = proposal };
    if (std.mem.eql(u8, phase, "stage")) {
        try caller.send(init.io, &server, &handler, 0, false);
        try caller.send(init.io, &server, &handler, 1, false);
        for (0..3) |_| try caller.send(init.io, &server, &handler, 1, false);
        try caller.send(init.io, &server, &handler, 1, true);
        saved.stale = server.pending.?.signed;
        try t.expectEqual(@as(u32, 3), (try descriptor(source, saved.resource)).written);
        try t.expectEqual(@as(usize, 1), handler.lost);
    } else if (std.mem.eql(u8, phase, "seal")) {
        try drive(init.io, &server, &handler, false);
        var current = try descriptor(source, saved.resource);
        while (current.written < current.spec.chunks()) {
            try caller.send(init.io, &server, &handler, 1, false);
            current = try descriptor(source, saved.resource);
        }
        try caller.send(init.io, &server, &handler, 1, true);
        saved.stale = server.pending.?.signed;
        try t.expectEqual(s.Publication.State.staging, (try descriptor(source, saved.resource)).state);
        var reader = try source.open(saved.resource);
        try t.expect(try owner().head(&reader) == null);
    } else if (std.mem.eql(u8, phase, "publish")) {
        try drive(init.io, &server, &handler, false);
        try t.expectEqual(@as(usize, 1), handler.lost);
        try caller.send(init.io, &server, &handler, 1, false); // exact application duplicate
        var reader = try source.open(saved.resource);
        const head = (try owner().head(&reader)).?;
        const receipt = (try owner().receipt(&reader, Operator, proposal.operation)).?;
        try t.expectEqual(Owner.Phase.applied, receipt.phase);
        try t.expectEqual(Operator, head.principal);
        try t.expectEqual(head.input, receipt.input);
        var bytes: [app.Model.max_program_bytes]u8 = undefined;
        try t.expectEqualStrings(body, try owner().reference(saved.resource, head).read(source, &bytes));
        try caller.send(init.io, &server, &handler, 2, false);
        try caller.send(init.io, &server, &handler, 3, false);
        _ = try admin.submit(.{ .checkpoint = {} });
    } else if (std.mem.eql(u8, phase, "finish")) {
        try caller.send(init.io, &server, &handler, 3, false); // denial persists across disk restart
        try caller.send(init.io, &server, &handler, 4, false); // independent bootstrap recovery
        try caller.send(init.io, &server, &handler, 1, false);
        var reader = try source.open(saved.resource);
        const head = (try owner().head(&reader)).?;
        try t.expectEqual(@as(u64, 1), head.revision.value);
        var bytes: [app.Model.max_program_bytes]u8 = undefined;
        const reference = owner().reference(saved.resource, head);
        try t.expectEqualStrings(body, try reference.read(source, &bytes));
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Operator, .permissions = 0 } });
        try t.expectError(error.AccessDenied, reference.read(source, &bytes));
        try output.interface.print("Application: {d} body bytes, signed operator={d}, four mutations, exact retries, policy and resource denial passed\n", .{ body.len, Operator });
    } else return error.UnknownPhase;
    const encoded = try p.Json.valueAlloc(init.gpa, saved);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = encoded });
    try output.interface.print("Application {s}: generation={d}\n", .{ phase, saved.generation });
    try output.interface.flush();
    if (!std.mem.eql(u8, phase, "finish")) while (true) try init.io.sleep(.fromSeconds(30), .awake);
}
