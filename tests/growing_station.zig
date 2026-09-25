//! Two real Station callers. Only public framework/client interfaces are used.
const std = @import("std");
const station = @import("transit_station");
const client = station.client;
const p = client.protocol;
const g = p.Growth;
const Server = station.GrowingGenServer;
const Turn = station.GrowingTurn;
const t = std.testing;
const Realm = 43;
const Count = 40;
const Expected = struct { requester: u64, writer: u64, requests: u64, rows: u64, stale: ?g.SignedRequest = null };

const Admin = struct {
    wire: *client.Client,
    key: p.Ed25519.KeyPair,
    sequence: u64 = 0,
    fn query(self: *Admin, kind: @FieldType(g.Query, "kind")) !g.Response {
        return self.wire.queryGrowing(.{ .realm = Realm, .principal = 0, .kind = kind }, self.key);
    }
    fn submit(self: *Admin, command: g.Command) !u64 {
        const receipt = try self.wire.submitGrowing(try g.sign(.{ .realm = Realm, .principal = 0, .sequence = self.sequence + 1, .command = command }, self.key));
        self.sequence += 1;
        return receipt.position;
    }
    fn send(self: *Admin, pid: u64, index: i64) !void {
        _ = try self.submit(.{ .send = .{ .pid = pid, .value = try (station.Frame{ .kind = .cast, .payload = p.Value.integer(index) }).encode() } });
    }
    fn provision(self: *Admin, principal: u64, key: p.Ed25519.KeyPair) !struct { pid: u64, resource: u64 } {
        const pid = try self.submit(.{ .spawn = .{} });
        _ = try self.submit(.{ .grant = .{ .subject = principal, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = pid } });
        const resource = try self.submit(.{ .create_resource = .{ .writer = pid } });
        for ([_]u64{ 0, principal }) |subject| _ = try self.submit(.{ .grant_resource = .{ .resource = resource, .subject = subject, .permissions = p.State.all_permissions } });
        _ = try self.submit(.{ .associate = .{ .pid = pid, .name = try p.Value.init("state"), .resource = resource } });
        _ = try self.submit(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = principal } });
        return .{ .pid = pid, .resource = resource };
    }
};

const Handler = struct {
    writer: bool,
    peer: u64,
    initialized: usize = 0,
    handled: usize = 0,
    read_failures: usize = 0,
    fn context(raw: ?*anyopaque) *Handler {
        return @ptrCast(@alignCast(raw.?));
    }
    fn initialize(raw: ?*anyopaque, turn: *Turn) anyerror!void {
        const self = context(raw);
        self.initialized += 1;
        if (self.writer) _ = try station.Table.create(turn, 1, .{ .names = .{ try .init("id"), try .init("amount") }, .value_type = .int64 });
    }
    fn handle(raw: ?*anyopaque, turn: *Turn, frame: station.Frame) anyerror!void {
        const self = context(raw);
        self.handled += 1;
        if (self.writer) {
            if (frame.kind != .call) return error.ExpectedCall;
            const table = try station.Table.open(turn, 1);
            const index = try frame.payload.asInteger();
            try table.insert(turn, .{ .key = index, .value = .{ .int64 = index * 2 } });
            try turn.reply(p.Value.integer(index * 2));
        } else switch (frame.kind) {
            .cast => {
                // The proxy corrupts this read once. Swallowing that transport
                // error must still prevent private writes/outputs from committing.
                _ = turn.read(try p.Value.init("read-fault")) catch blk: {
                    self.read_failures += 1;
                    break :blk null;
                };
                try turn.put(try p.Value.init("attempt"), frame.payload);
                if (turn.read_error != null) {
                    try turn.cast(self.peer, frame.payload);
                    return;
                }
                _ = try turn.call(self.peer, frame.payload, null);
            },
            .reply => {
                try t.expectEqual(.replied, (try turn.waiting(frame.correlation)).?.phase);
                try turn.put(try p.Value.init("last"), frame.payload);
            },
            else => return error.UnexpectedFrame,
        }
    }
    fn interface(self: *Handler) Server.Handler {
        return .{ .context = self, .initialize = initialize, .handle = handle };
    }
};

fn deadline(io: std.Io) u64 {
    return @as(u64, @intCast(std.Io.Clock.real.now(io).toMilliseconds())) + 30000;
}
fn drive(io: std.Io, server: *Server, handler: *Handler, prepare_only: bool) !usize {
    var lost: usize = 0;
    for (0..24) |_| {
        if (prepare_only and server.pending != null and server.pending_kind == .commit) return lost;
        const before = handler.handled;
        const result = server.step(handler.interface(), deadline(io)) catch |err| {
            if (err != error.InvalidAuthorityResponse) return err;
            if (server.pending) |pending| {
                try t.expectEqual(.turn, std.meta.activeTag(pending.signed.request.command));
                try t.expectEqual(before, handler.handled);
                lost += 1;
            } else {
                try t.expect(server.ready == null and server.view_id != null);
                try t.expectEqual(@as(usize, 1), handler.read_failures);
            }
            continue;
        };
        switch (result) {
            .committed => return lost,
            .blocked => return error.BehaviorBlocked,
            .idle => return error.MissingInput,
            .progress => {},
        }
    }
    return error.StepBudgetExceeded;
}
fn makeServer(wire: *client.Client, principal: u64, pid: u64, generation: u64, key: p.Ed25519.KeyPair) !Server {
    return Server.init(.{ .client = wire, .realm = Realm, .principal = principal, .pid = pid, .generation = generation, .key = key }, "state");
}
fn verify(admin: *Admin, expected: Expected, count: usize) !void {
    const process = (try admin.query(.{ .process = expected.requester })).body.process;
    try t.expect(process.input == null);
    try t.expectEqual(@as(u64, count * 2), process.process.consumed);
    const requests = (try admin.query(.{ .resource = expected.requests })).body.resource;
    try t.expectEqual(@as(u64, count + 3), requests.entries); // descriptor, attempt, last, waits
    var after: ?p.Value = null;
    var waits: usize = 0;
    while (true) {
        const page = (try admin.query(.{ .entries = .{ .resource = requests.id, .revision = requests.revision, .after = after } })).body.entries.page;
        for (page.entries) |slot| if (slot) |entry| {
            if (entry.key.len == 10 and std.mem.eql(u8, entry.key.data[0..2], "\x00w")) {
                const wait = try Turn.Wait.decode(entry.value);
                try t.expectEqual(.replied, wait.phase);
                try t.expectEqual(expected.writer, wait.target);
                waits += 1;
            }
        };
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(count, waits);
    const rows = (try admin.query(.{ .resource = expected.rows })).body.resource;
    try t.expectEqual(@as(u64, count + 2), rows.entries); // descriptor, schema, rows
    for (0..count) |i| {
        const page = (try admin.query(.{ .entries = .{ .resource = rows.id, .revision = rows.revision, .key = station.Table.rowKey(1, @intCast(i)) } })).body.entries.page;
        const value = page.entries[0].?.value;
        try t.expectEqual(@as(i64, @intCast(i * 2)), std.mem.readInt(i64, value.data[2..10], .little));
    }
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writer(init.io, &output_buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(root_key.public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4) return error.Usage;
    var wire = client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &wire, .key = root_key };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    const requester_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const writer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    if (std.mem.eql(u8, args[2], "write")) {
        const requester = try admin.provision(65536, requester_key);
        const writer = try admin.provision(65537, writer_key);
        var request_server = try makeServer(&wire, 65536, requester.pid, 2, requester_key);
        var write_server = try makeServer(&wire, 65537, writer.pid, 2, writer_key);
        var request_handler: Handler = .{ .writer = false, .peer = writer.pid };
        var write_handler: Handler = .{ .writer = true, .peer = requester.pid };
        var lost: usize = 0;
        for (0..Count) |i| {
            try admin.send(requester.pid, @intCast(i));
            lost += try drive(init.io, &request_server, &request_handler, false);
            _ = try admin.submit(.{ .deliver = i * 2 + 1 });
            lost += try drive(init.io, &write_server, &write_handler, false);
            _ = try admin.submit(.{ .deliver = i * 2 + 2 });
            lost += try drive(init.io, &request_server, &request_handler, false);
        }
        try t.expectEqual(@as(usize, 1), lost);
        try t.expectEqual(@as(usize, 1), request_handler.read_failures);
        try t.expectEqual(@as(usize, 2), request_handler.initialized); // first private attempt failed its read
        try t.expectEqual(@as(usize, 1), write_handler.initialized);
        try t.expectEqual(@as(usize, Count * 2 + 1), request_handler.handled);
        try t.expectEqual(@as(usize, Count), write_handler.handled);
        var expected: Expected = .{ .requester = requester.pid, .writer = writer.pid, .requests = requester.resource, .rows = writer.resource };
        try verify(&admin, expected, Count);
        try admin.send(requester.pid, Count);
        _ = try drive(init.io, &request_server, &request_handler, false);
        _ = try admin.submit(.{ .deliver = Count * 2 + 1 });
        _ = try drive(init.io, &write_server, &write_handler, true);
        expected.stale = write_server.pending.?.signed;
        const bytes = try std.json.Stringify.valueAlloc(init.gpa, expected, .{});
        defer init.gpa.free(bytes);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = bytes });
    } else if (std.mem.eql(u8, args[2], "recover")) {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(client.max_body));
        defer init.gpa.free(bytes);
        const parsed = try std.json.parseFromSlice(Expected, init.gpa, bytes, .{});
        defer parsed.deinit();
        const expected = parsed.value;
        _ = try admin.submit(.{ .own = .{ .pid = expected.requester, .expected_generation = 2, .worker = 65536 } });
        _ = try admin.submit(.{ .own = .{ .pid = expected.writer, .expected_generation = 2, .worker = 65537 } });
        try t.expectError(error.Rejected, wire.submitGrowing(expected.stale.?));
        try t.expectEqual(.StaleGeneration, wire.last_rejection.?);
        var request_server = try makeServer(&wire, 65536, expected.requester, 3, requester_key);
        var write_server = try makeServer(&wire, 65537, expected.writer, 3, writer_key);
        var request_handler: Handler = .{ .writer = false, .peer = expected.writer };
        var write_handler: Handler = .{ .writer = true, .peer = expected.requester };
        _ = try drive(init.io, &write_server, &write_handler, false);
        _ = try admin.submit(.{ .deliver = Count * 2 + 2 });
        _ = try drive(init.io, &request_server, &request_handler, false);
        try t.expectEqual(@as(usize, 0), request_handler.initialized + write_handler.initialized);
        try t.expectEqual(@as(usize, 2), request_handler.handled + write_handler.handled);
        try verify(&admin, expected, Count + 1);
    } else return error.UnknownPhase;
    try output.interface.print("Growing Station {s}: passed\n", .{args[2]});
    try output.interface.flush();
}
