//! Document publication and checkpoint recovery through the public Station host.
const std = @import("std");
const doc = @import("transit_station_document");
const station = @import("transit_station");
const client = station.client;
const p = station.protocol;
const g = p.Growth;
const Server = station.GenServer;
const Turn = station.Turn;
const t = std.testing;
const Realm = 49;
const Principal = 65536;
const Admin = @import("growing_support.zig").Admin(Realm);
const Saved = struct { phase: []const u8, pid: u64, resource: u64, generation: u64 = 2, stale: ?g.SignedRequest = null };
fn service(turn: *Turn) doc.Service {
    return .{ .resource = turn.view.resource, .document = 17 };
}
fn change(replica: u64, epoch: u64, previous: u64, first: u64, ops: []const doc.Operation) doc.Change {
    var out: doc.Change = .{ .document = 17, .epoch = epoch, .replica = replica, .previous = previous, .first = first, .len = @intCast(ops.len) };
    @memcpy(out.operations[0..ops.len], ops);
    return out;
}
fn bootstrap() !doc.Change {
    return change(1, 1, 0, 1, &.{
        .{ .assign = .{ .field = try doc.Model.Name.init("body"), .value = .text } },
        .{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .value = .{ .character = 'a' } } },
        .{ .assign = .{ .field = try doc.Model.Name.init("value"), .value = .null_value } },
    });
}
fn fresh() doc.Change {
    return change(2, 2, 0, 4, &.{.{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .after = .{ .counter = 2, .replica = 1 }, .value = .{ .character = 0x1f642 } } }});
}
const Handler = struct {
    done: bool = false,
    calls: usize = 0,
    lost: usize = 0,
    fn get(raw: ?*anyopaque) *Handler {
        return @ptrCast(@alignCast(raw.?));
    }
    fn initialize(_: ?*anyopaque, turn: *Turn) !void {
        try service(turn).create(turn, 1, .{ .record_bytes = 4096, .staging_bytes = 4096, .staging_records = 1 });
    }
    fn handle(raw: ?*anyopaque, turn: *Turn, frame: station.Frame) !void {
        const self = get(raw);
        self.calls += 1;
        self.done = false;
        const s = service(turn);
        switch (try frame.payload.asInteger()) {
            0 => {},
            1 => {
                _ = try s.prepare(turn, 1, try bootstrap(), 256);
            },
            2 => self.done = try s.upload(turn, 1, try bootstrap()),
            3 => {
                const outcome = try s.advance(turn, 1);
                self.done = outcome != .progress;
                if (outcome == .accepted) {
                    try turn.put(try p.Value.init("acceptances"), p.Value.integer(1));
                    try turn.cast(turn.delivery.pid, p.Value.integer(101));
                }
            },
            4 => {
                const h = try s.head(turn);
                try t.expectEqual(@as(u64, 1), h.state.revision);
                const path = [_]doc.Model.Name{try doc.Model.Name.init("value")};
                try t.expectEqual(.null_value, (try s.readPath(turn, 1, &path)).status());
                const sequence = try s.readSequence(turn, .{ .revision = 1, .object = .{ .counter = 1, .replica = 1 } });
                try t.expectEqual(@as(u8, 1), sequence.len);
                try t.expectEqual(@as(u32, 'a'), sequence.items[0].values.assignments[0].value.character);
                try t.expectEqual(@as(u64, 1), (try s.job(turn, 1)).accepted_revision);
            },
            5 => try s.configureMergeWindow(turn, 1),
            6 => try doc.Checkpoint.begin(s, turn, 2),
            7 => self.done = (try doc.Checkpoint.step(s, turn, 2)) == .complete,
            8 => {
                const h = try s.head(turn);
                try t.expectEqual(@as(u64, 2), h.state.epoch);
                try t.expectEqual(@as(u64, 2), h.floor);
                try t.expectError(error.DocumentHistoryGap, s.open(turn, 1));
                try t.expectError(error.DocumentResyncRequired, s.prepare(turn, 3, try bootstrap(), 256));
                const sync = try s.resynchronize(turn, 1);
                try t.expectEqual(@as(u64, 3), sync.previous_counter);
                const sequence = try s.readSequence(turn, .{ .revision = 2, .object = .{ .counter = 1, .replica = 1 } });
                try t.expectEqual(@as(u8, 1), sequence.len);
            },
            9 => {
                _ = try s.prepare(turn, 3, fresh(), 256);
            },
            10 => self.done = try s.upload(turn, 3, fresh()),
            11 => self.done = (try s.advance(turn, 3)) != .progress,
            12 => {
                const sequence = try s.readSequence(turn, .{ .revision = 3, .object = .{ .counter = 1, .replica = 1 } });
                try t.expectEqual(@as(u8, 2), sequence.len);
                try t.expectEqual(@as(u32, 0x1f642), sequence.items[1].values.assignments[0].value.character);
            },
            13 => try s.retire(turn),
            14 => self.done = try s.collectRetired(turn, 1),
            15 => self.done = try doc.Checkpoint.collectRetired(s, turn, 2),
            16 => self.done = try s.collectRetired(turn, 3),
            17 => {
                try t.expectError(error.DocumentRetired, s.open(turn, 3));
                try t.expectError(error.DocumentRetired, s.resynchronize(turn, 1));
                const pubn = s.publication();
                const budget = try pubn.budget(turn);
                try t.expectEqual(@as(u32, 0), budget.records);
                for ([_]u64{ 1, 3 }) |id| {
                    const j = try s.job(turn, id);
                    try t.expectEqual(j.end_node, j.cleanup);
                    const record = try pubn.inspect(turn, j.request);
                    try t.expectEqual(record.written, record.collected);
                }
                try t.expectEqualStrings("1", (try turn.read(try p.Value.init("acceptances"))).?.slice());
            },
            18 => try t.expectEqual(@as(u8, 1), (try s.readSequence(turn, .{ .revision = 2, .object = .{ .counter = 1, .replica = 1 } })).len),
            19 => try t.expectEqual(@as(u64, 2), (try s.acceptedChange(turn, 3)).replica),
            101 => {},
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
        const before = handler.calls;
        const result = server.step(handler.interface(), now(io) + 30000) catch |err| {
            if (err != error.InvalidAuthorityResponse or server.pending == null) return err;
            try t.expectEqual(before, handler.calls);
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
fn send(io: std.Io, admin: *Admin, server: *Server, handler: *Handler, code: i64, freeze: bool) !void {
    try admin.send(server.session.pid, code);
    try drive(io, server, handler, freeze);
}
fn finish(io: std.Io, admin: *Admin, server: *Server, handler: *Handler, code: i64) !void {
    for (0..10000) |_| {
        try send(io, admin, server, handler, code, false);
        if (handler.done) return;
    }
    return error.DocumentDidNotComplete;
}
fn value(admin: *Admin, resource: u64, key: p.Value) !?p.Value {
    const metadata = (try admin.query(.{ .resource = resource })).body.resource;
    const entry = (try admin.query(.{ .entries = .{ .resource = resource, .revision = metadata.revision, .key = key } })).body.entries.page.entries[0];
    return if (entry) |item| item.value else null;
}
fn head(admin: *Admin, saved: Saved) !doc.Service.Head {
    const s: doc.Service = .{ .resource = saved.resource, .document = 17 };
    return doc.Service.Head.decode((try value(admin, saved.resource, s.key('h', 0))).?);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var output_buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(root_key.public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4) return error.Usage;
    var wire = client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 30000;
    var admin: Admin = .{ .wire = &wire, .key = root_key };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    const worker = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const phase = args[2];
    var saved: Saved = undefined;
    if (std.mem.eql(u8, phase, "stage")) {
        const created = try admin.provision(Principal, worker);
        saved = .{ .phase = phase, .pid = created.pid, .resource = created.resource };
    } else {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.arena.allocator(), .limited(client.max_body));
        saved = (try std.json.parseFromSlice(Saved, init.arena.allocator(), bytes, .{})).value;
        saved.phase = phase;
        _ = try admin.submit(.{ .own = .{ .pid = saved.pid, .expected_generation = saved.generation, .worker = Principal } });
        saved.generation += 1;
        if (saved.stale) |request| {
            try t.expectError(error.Rejected, wire.submit(request));
            try t.expectEqual(.StaleGeneration, wire.last_rejection.?);
            saved.stale = null;
        }
    }
    var server = try Server.init(.{ .client = &wire, .realm = Realm, .principal = Principal, .pid = saved.pid, .generation = saved.generation, .key = worker }, "state");
    var handler: Handler = .{};
    if (std.mem.eql(u8, phase, "stage")) {
        try send(init.io, &admin, &server, &handler, 0, false);
        try send(init.io, &admin, &server, &handler, 1, false);
        try finish(init.io, &admin, &server, &handler, 2);
        for (0..10) |_| try send(init.io, &admin, &server, &handler, 3, false);
        try send(init.io, &admin, &server, &handler, 3, true);
        saved.stale = server.pending.?.signed;
        try t.expectEqual(@as(u64, 0), (try head(&admin, saved)).state.revision);
    } else if (std.mem.eql(u8, phase, "accept")) {
        try drive(init.io, &server, &handler, false);
        try finish(init.io, &admin, &server, &handler, 3);
        try send(init.io, &admin, &server, &handler, 4, false);
        try send(init.io, &admin, &server, &handler, 3, false); // Durable duplicate, no second output.
        try send(init.io, &admin, &server, &handler, 5, false);
        try send(init.io, &admin, &server, &handler, 6, false);
        for (0..10) |_| try send(init.io, &admin, &server, &handler, 7, false);
        try send(init.io, &admin, &server, &handler, 7, true);
        saved.stale = server.pending.?.signed;
        try t.expectEqual(@as(u64, 1), (try head(&admin, saved)).state.revision);
        try t.expectEqual(@as(u64, 0), (try head(&admin, saved)).floor);
    } else if (std.mem.eql(u8, phase, "checkpoint")) {
        try drive(init.io, &server, &handler, false);
        try finish(init.io, &admin, &server, &handler, 7);
        try send(init.io, &admin, &server, &handler, 8, false);
        try send(init.io, &admin, &server, &handler, 9, false);
        try finish(init.io, &admin, &server, &handler, 10);
        try finish(init.io, &admin, &server, &handler, 11);
        try send(init.io, &admin, &server, &handler, 12, false);
        try send(init.io, &admin, &server, &handler, 18, false);
        try send(init.io, &admin, &server, &handler, 19, false);
        _ = try admin.submit(.{ .checkpoint = {} });
    } else if (std.mem.eql(u8, phase, "finish")) {
        // Independent read-only principal: no ownership or execute/publish grant.
        const observer = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
        _ = try admin.submit(.{ .grant = .{ .subject = Principal + 1, .public_key = observer.public_key.toBytes(), .permissions = p.permission(.inspect), .pid = saved.pid } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal + 1, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        const reader_client: doc.Client = .{ .source = .{ .wire = &wire, .realm = Realm, .principal = Principal + 1, .key = observer } };
        const identity: doc.Client.Identity = .{ .resource = saved.resource, .document = 17 };
        const description = try reader_client.describe(identity);
        try t.expectEqual(@as(u64, 3), description.reference.revision);
        const path = [_]doc.Model.Name{try doc.Model.Name.init("value")};
        try t.expectEqual(.null_value, (try reader_client.readPath(description.reference, &path)).value.status());
        const read_cursor: doc.Service.PageCursor = .{ .revision = 3, .object = .{ .counter = 1, .replica = 1 } };
        try t.expectEqual(@as(u8, 2), (try reader_client.readSequence(description.reference, read_cursor)).value.len);
        _ = try reader_client.acceptedChange(description.reference);
        try t.expectEqual(@as(u64, 4), (try reader_client.resynchronize(identity, 2)).previous_counter);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal + 1, .permissions = 0 } });
        try t.expectError(error.AccessDenied, reader_client.readSequence(description.reference, read_cursor));
        try send(init.io, &admin, &server, &handler, 12, false);
        // Revoke after an actual element has been returned from a retained root.
        try admin.send(saved.pid, 12);
        for (0..16) |_| {
            if (server.pending != null) {
                _ = try server.dispatchPending();
                continue;
            }
            if (try server.prepare(now(init.io) + 30000) == .ready) break;
        } else return error.StepBudgetExceeded;
        const s = service(&server.ready.?);
        const snapshot = try s.open(&server.ready.?, 3);
        var reader: station.ImmutableIndex.Reader(*Turn) = .{ .publication = s.publication(), .source = &server.ready.? };
        var cursor: doc.Document.SequenceCursor = .{};
        try t.expect((try snapshot.sequenceStep(&reader, .{ .counter = 1, .replica = 1 }, &cursor)) == .item);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal, .permissions = 0 } });
        try t.expectError(error.AccessDenied, s.readSequence(&server.ready.?, .{ .revision = 3, .object = .{ .counter = 1, .replica = 1 }, .traversal = cursor }));
        try t.expectError(error.AccessDenied, server.finish(null));
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal, .permissions = p.State.all_permissions } });
        try drive(init.io, &server, &handler, false);
        try send(init.io, &admin, &server, &handler, 13, false);
        for ([_]i64{ 14, 15, 16 }) |code| try finish(init.io, &admin, &server, &handler, code);
        try send(init.io, &admin, &server, &handler, 17, false);
        const cut = (try admin.query(.{ .capabilities = {} })).position;
        const outputs = (try admin.query(.{ .outputs = .{ .position = cut } })).body.outputs;
        try t.expect(outputs.entries[0] != null and outputs.entries[1] == null and outputs.next == null);
    } else return error.UnknownPhase;
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, saved, .{});
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = bytes });
    try output.interface.print("Document {s}: passed; generation={d}, exact_retries={d}\n", .{ phase, saved.generation, handler.lost });
    try output.interface.flush();
    if (!std.mem.eql(u8, phase, "finish")) while (true) try init.io.sleep(.fromSeconds(30), .awake);
}
