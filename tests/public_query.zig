//! Provision a real Table using public APIs. The actual shell and daemon are
//! separate executables exercised by public_query.py, never test-only handlers.
const std = @import("std");
const q = @import("transit_query");
const s = @import("transit_station");
const p = s.protocol;
const Admin = @import("growing_support.zig").Admin(45);
const Seed = struct {
    peer: u64,
    fn initialize(raw: ?*anyopaque, turn: *s.GrowingTurn) anyerror!void {
        const self: *Seed = @ptrCast(@alignCast(raw.?));
        _ = try s.Table.create(turn, 1, .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 });
        try s.GrowingQuery.setPolicy(turn, self.peer, 1, 0, true);
    }
    fn handle(_: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) anyerror!void {
        const first = try frame.payload.asInteger();
        if (first < 0) return;
        const table = try s.Table.open(turn, 1);
        var i = first;
        while (i < @min(first + 4, 41)) : (i += 1) try table.insert(turn, .{ .key = i, .value = if (@mod(i, 5) == 0) .null else .{ .int64 = 9007199254740993 + i } });
    }
};
fn drive(init: std.process.Init, server: *s.GrowingGenServer, handler: s.GrowingGenServer.Handler) !void {
    for (0..20) |_| switch (try server.step(handler, @as(u64, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds())) + 30000)) {
        .committed => return,
        .blocked => return server.handler_error orelse error.Blocked,
        .idle => return error.NoInput,
        .progress => {},
    };
    return error.StepBudgetExceeded;
}
fn save(init: std.process.Init, directory: []const u8, name: []const u8, value: anytype) !void {
    const path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{}) });
}
fn seedFile(init: std.process.Init, directory: []const u8, name: []const u8, byte: u8) ![]const u8 {
    const path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}.seed", .{ directory, name });
    const text = std.fmt.bytesToHex(@as([32]u8, @splat(byte)), .lower);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = &text });
    return path;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(root.public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4) return error.Usage;
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &wire, .key = root };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    if (std.mem.eql(u8, args[2], "provision")) {
        const writer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
        const requester_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
        const caller_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
        const courier_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(11));
        const writer = try admin.provision(65536, writer_key);
        const requester = try admin.provision(65537, requester_key);
        _ = try admin.submit(.{ .grant = .{ .subject = 1234, .public_key = caller_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) } });
        _ = try admin.submit(.{ .grant = .{ .subject = 65538, .public_key = courier_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery) } });
        _ = try admin.submit(.{ .grant = .{ .subject = 55, .public_key = (try p.Ed25519.KeyPair.generateDeterministic(@splat(12))).public_key.toBytes(), .permissions = p.permission(.inspect) } });
        for ([_]u64{ writer.resource, requester.resource }) |resource| for ([_]u64{ 1234, 55 }) |principal| {
            _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        };
        var server = try s.GrowingGenServer.init(.{ .client = &wire, .realm = 45, .principal = 65536, .pid = writer.pid, .generation = 2, .key = writer_key }, "state");
        var seed: Seed = .{ .peer = requester.pid };
        const handler: s.GrowingGenServer.Handler = .{ .context = &seed, .initialize = Seed.initialize, .handle = Seed.handle };
        try admin.send(writer.pid, -1);
        try drive(init, &server, handler);
        for (0..11) |i| {
            try admin.send(writer.pid, @intCast(i * 4));
            try drive(init, &server, handler);
        }
        var requests = try s.GrowingGenServer.init(.{ .client = &wire, .realm = 45, .principal = 65537, .pid = requester.pid, .generation = 2, .key = requester_key }, "state");
        var behavior: q.Behavior.Requester = .{ .principal = 1234, .source = writer.pid };
        _ = try wire.submitGrowing(try p.Growth.sign(.{ .realm = 45, .principal = 1234, .sequence = 1, .command = .{ .send = .{ .pid = requester.pid, .value = try (s.Frame{ .kind = .cast, .payload = try .init("PQI1") }).encode() } } }, caller_key));
        try drive(init, &requests, behavior.interface());
        _ = try admin.submit(.{ .own = .{ .pid = writer.pid, .expected_generation = 2, .worker = 65536 } });
        _ = try admin.submit(.{ .own = .{ .pid = requester.pid, .expected_generation = 2, .worker = 65537 } });
        const source_seed = try seedFile(init, args[3], "source", 8);
        const request_seed = try seedFile(init, args[3], "requester", 9);
        const caller_seed = try seedFile(init, args[3], "caller", 10);
        const courier_seed = try seedFile(init, args[3], "courier", 11);
        const inspector_seed = try seedFile(init, args[3], "inspector", 12);
        const connection: q.Model.Connection = .{ .realm = 45, .principal = 1234, .source = writer.pid, .resource = writer.resource, .table = 1, .name = "items", .requester = requester.pid, .requests = requester.resource };
        try save(init, args[3], "cli.json", .{ .url = args[1], .seed_file = caller_seed, .connection = connection, .request_timeout_ms = 10000 });
        var inspector = connection;
        inspector.principal = 55;
        try save(init, args[3], "inspector.json", .{ .url = args[1], .seed_file = inspector_seed, .connection = inspector });
        try save(init, args[3], "source.json", .{ .url = args[1], .realm = 45, .principal = 65536, .pid = writer.pid, .generation = 3, .seed_file = source_seed, .activation_directory = args[3], .role = .{ .source = .{ .table = 1, .peer = requester.pid } } });
        try save(init, args[3], "requester.json", .{ .url = args[1], .realm = 45, .principal = 65537, .pid = requester.pid, .generation = 3, .seed_file = request_seed, .activation_directory = args[3], .role = .{ .requester = behavior } });
        try save(init, args[3], "courier.json", .{ .url = args[1], .realm = 45, .principal = 65538, .seed_file = courier_seed, .role = .{ .courier = .{ .destinations = .{ writer.pid, requester.pid } } } });
        return;
    }
    const config = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(8192));
    defer init.gpa.free(config);
    const parsed = try std.json.parseFromSlice(struct { connection: q.Model.Connection }, init.gpa, config, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const c = parsed.value.connection;
    if (std.mem.eql(u8, args[2], "submit-busy") or std.mem.eql(u8, args[2], "bad-schema")) {
        const caller_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
        const sequence = (try wire.queryGrowing(.{ .realm = 45, .principal = 1234, .kind = .{ .capabilities = {} } }, caller_key)).principal_sequence;
        const schema: q.fuze.model.Schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 };
        const start: q.Request.Start = .{ .schema = if (std.mem.eql(u8, args[2], "bad-schema")) @splat(0) else try schema.fingerprint(), .plan = .{} };
        const receipt = try wire.submitGrowing(try p.Growth.sign(.{ .realm = 45, .principal = 1234, .sequence = sequence + 1, .command = .{ .send = .{ .pid = c.requester, .value = try (s.Frame{ .kind = .cast, .payload = try start.encode() }).encode() } } }, caller_key));
        try std.json.Stringify.value(.{ .submitted = receipt.position }, .{}, &output.interface);
        return output.interface.flush();
    }
    if (std.mem.eql(u8, args[2], "fence")) {
        const process = (try admin.query(.{ .process = c.source })).body.process.process;
        _ = try admin.submit(.{ .own = .{ .pid = c.source, .expected_generation = process.generation, .worker = 65536 } });
    } else if (std.mem.eql(u8, args[2], "revoke")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = c.resource, .subject = 1234, .permissions = 0 } });
    } else if (std.mem.eql(u8, args[2], "restore")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = c.resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    } else return error.UnknownMode;
}
