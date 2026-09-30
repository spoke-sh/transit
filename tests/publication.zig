//! Public Station API proof. No raw backend access or authoritative local files.
const std = @import("std");
const station = @import("transit_station");
const client = station.client;
const p = station.protocol;
const g = p.Growth;
const Pub = station.Publication;
const Server = station.GenServer;
const Turn = station.Turn;
const t = std.testing;
const Realm = 46;
const Principal = 65536;
const Admin = @import("growing_support.zig").Admin(Realm);
const RecordBytes = 65536;
const Namespace = std.math.maxInt(u64);
const Saved = struct {
    phase: []const u8,
    pid: u64,
    resource: u64,
    generation: u64 = 2,
    pin: ?g.ReadVersionId = null,
    stale: ?g.SignedRequest = null,
};
fn publication(turn: *Turn) Pub {
    return .{ .resource = turn.view.resource, .namespace = Namespace };
}
fn chunk(index: u32) [256]u8 {
    var bytes: [256]u8 = undefined;
    for (&bytes, 0..) |*b, i| b.* = @truncate((@as(usize, index) * 256 + i) * 37 + 11);
    return bytes;
}
fn spec(length: u32) !Pub.Spec {
    var result: Pub.Spec = .{ .format = 7, .length = length, .digest = Pub.Digest.initial(7, length) };
    for (0..result.chunks()) |i| {
        const bytes = chunk(@intCast(i));
        result.digest = try Pub.Digest.next(result.digest, @intCast(i), bytes[0..try result.size(@intCast(i))]);
    }
    return result;
}
fn verify(pubn: Pub, source: anytype, id: u64, length: u32) !void {
    var cursor = try pubn.open(source, id);
    var count: u32 = 0;
    while (true) {
        const result = try pubn.read(source, cursor);
        const expected = chunk(cursor.index);
        try t.expectEqualSlices(u8, expected[0..result.bytes.len], result.bytes.slice());
        count += result.bytes.len;
        cursor = result.next orelse break;
    }
    try t.expectEqual(length, count);
}
const Handler = struct {
    handled: usize = 0,
    lost: usize = 0,
    pin: ?g.ReadVersionId = null,
    fn get(raw: ?*anyopaque) *Handler {
        return @ptrCast(@alignCast(raw.?));
    }
    fn initialize(_: ?*anyopaque, turn: *Turn) !void {
        _ = try Pub.create(turn, Namespace, .{ .record_bytes = RecordBytes, .staging_bytes = RecordBytes + 513, .staging_records = 2 });
    }
    fn handle(raw: ?*anyopaque, turn: *Turn, frame: station.Frame) !void {
        const self = get(raw);
        self.handled += 1;
        const code = try frame.payload.asInteger();
        const pubn = publication(turn);
        switch (code) {
            0 => {},
            1 => {
                _ = try pubn.begin(turn, 1, try spec(RecordBytes));
            },
            2 => {
                if (try pubn.publish(turn, 1) == .changed) {
                    try turn.put(try p.Value.init("head"), try p.Value.init("1"));
                    try turn.put(try p.Value.init("acceptances"), try p.Value.init("1"));
                    try turn.cast(turn.delivery.pid, try p.Value.init("published"));
                }
            },
            3 => {
                const cursor = try pubn.open(turn, 1);
                const first = try pubn.read(turn, cursor);
                try t.expect(first.next != null);
                try t.expectEqualSlices(u8, &chunk(0), first.bytes.slice());
            },
            4 => {
                const id = try turn.retain();
                self.pin = id;
                var saved: [17]u8 = undefined;
                std.mem.writeInt(u64, saved[0..8], id.pid, .little);
                std.mem.writeInt(u64, saved[8..16], id.input, .little);
                saved[16] = id.index;
                try turn.put(try p.Value.init("pin"), try p.Value.init(&saved));
            },
            5 => {
                _ = try pubn.retire(turn, 1);
                try turn.delete(try p.Value.init("head"));
            },
            6 => {
                _ = try pubn.collect(turn, 1);
            },
            7 => {
                _ = try pubn.abandon(turn, 2);
            },
            8 => {
                _ = try pubn.collect(turn, 2);
            },
            9 => {
                const pin = (try turn.read(try p.Value.init("pin"))).?;
                try t.expectEqual(@as(u16, 17), pin.len);
                var source = try turn.openVersion(.{ .pid = std.mem.readInt(u64, pin.data[0..8], .little), .input = std.mem.readInt(u64, pin.data[8..16], .little), .index = pin.data[16] });
                var cursor = try pubn.open(&source, 1);
                const progress_key = try p.Value.init("read-progress");
                if (try turn.read(progress_key)) |progress| {
                    try t.expectEqual(@as(u16, 36), progress.len);
                    cursor.index = std.mem.readInt(u32, progress.data[0..4], .little);
                    cursor.chain = progress.data[4..36].*;
                }
                // Bounded application work, with durable cursor progress in the
                // same turn. The pin, never a worker field, fixes its source.
                for (0..8) |_| {
                    const part = try pubn.read(&source, cursor);
                    const expected = chunk(cursor.index);
                    try t.expectEqualSlices(u8, expected[0..part.bytes.len], part.bytes.slice());
                    if (part.next) |next| {
                        cursor = next;
                    } else {
                        try t.expectEqual(@as(u32, 255), cursor.index);
                        try turn.delete(progress_key);
                        try turn.put(try p.Value.init("verified"), p.Value.integer(RecordBytes));
                        return;
                    }
                }
                var progress: [36]u8 = undefined;
                std.mem.writeInt(u32, progress[0..4], cursor.index, .little);
                progress[4..36].* = cursor.chain;
                try turn.put(progress_key, try p.Value.init(&progress));
            },
            10 => try turn.release(self.pin.?),
            11 => {
                _ = try pubn.begin(turn, 2, try spec(513));
                try t.expectError(error.PublicationQuotaExceeded, pubn.begin(turn, 3, try spec(0)));
                try t.expectError(error.PublicationTooLarge, pubn.begin(turn, 3, try spec(RecordBytes + 1)));
            },
            12 => {
                try t.expectError(error.PublicationClosed, pubn.begin(turn, 1, try spec(RecordBytes)));
                try t.expectError(error.PublicationClosed, pubn.begin(turn, 2, try spec(513)));
                try t.expectError(error.PublicationNotPublished, pubn.open(turn, 1));
                try t.expectError(error.PublicationClosed, pubn.append(turn, 1, 0, &chunk(0)));
                try t.expectError(error.PublicationClosed, pubn.publish(turn, 1));
                try t.expect(try pubn.collect(turn, 1));
                try t.expect(try pubn.collect(turn, 2));
                const budget = try pubn.budget(turn);
                try t.expectEqual(@as(u64, 0), budget.bytes);
                try t.expectEqual(@as(u32, 0), budget.records);
                try verify(pubn, turn, 10, 32);
                try verify(pubn, turn, 50, 32);
            },
            1000...1255 => {
                const first: u32 = @intCast(code - 1000);
                // Three chunks plus one descriptor still fit the existing turn.
                for (first..@min(first + 3, 256)) |i| _ = try pubn.append(turn, 1, @intCast(i), &chunk(@intCast(i)));
            },
            2000...2002 => {
                const index: u32 = @intCast(code - 2000);
                _ = try pubn.append(turn, 2, index, chunk(index)[0..try (try spec(513)).size(index)]);
            },
            3000...3040 => {
                const id: u64 = @intCast(code - 3000 + 10);
                _ = try pubn.begin(turn, id, try spec(32));
                _ = try pubn.append(turn, id, 0, chunk(0)[0..32]);
                _ = try pubn.publish(turn, id);
            },
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
fn send(io: std.Io, admin: *Admin, server: *Server, handler: *Handler, code: i64, freeze: bool) !void {
    try admin.send(server.session.pid, code);
    try drive(io, server, handler, freeze);
}
fn prepare(io: std.Io, server: *Server, deadline: u64) !void {
    _ = io;
    for (0..16) |_| {
        if (server.pending != null) {
            _ = try server.dispatchPending();
            continue;
        }
        switch (try server.prepare(deadline)) {
            .ready => return,
            .progress => {},
            else => return error.UnexpectedHostState,
        }
    }
    return error.StepBudgetExceeded;
}
fn makeServer(wire: *client.Client, saved: Saved, keypair: p.Ed25519.KeyPair) !Server {
    return Server.init(.{ .client = wire, .realm = Realm, .principal = Principal, .pid = saved.pid, .generation = saved.generation, .key = keypair }, "state");
}
fn reown(admin: *Admin, saved: *Saved) !void {
    _ = try admin.submit(.{ .own = .{ .pid = saved.pid, .expected_generation = saved.generation, .worker = Principal } });
    saved.generation += 1;
}
fn value(admin: *Admin, resource: u64, key: p.Value) !?p.Value {
    const metadata = (try admin.query(.{ .resource = resource })).body.resource;
    const entry = (try admin.query(.{ .entries = .{ .resource = resource, .revision = metadata.revision, .key = key } })).body.entries.page.entries[0];
    return if (entry) |item| item.value else null;
}
fn descriptor(admin: *Admin, resource: u64, id: u64) !Pub.Descriptor {
    return Pub.Descriptor.decode((try value(admin, resource, Pub.key(Namespace, 'r', id, 0))).?);
}
fn save(init: std.process.Init, path: []const u8, saved: Saved) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, saved, .{});
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
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
    if (args.len != 5) return error.Usage;
    const max_clock_error_ms = try std.fmt.parseInt(u32, args[4], 10);
    var wire = client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
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
        try reown(&admin, &saved);
        if (saved.stale) |request| {
            try t.expectError(error.Rejected, wire.submit(request));
            try t.expectEqual(.StaleGeneration, wire.last_rejection.?);
            saved.stale = null;
        }
    }
    var server = try makeServer(&wire, saved, worker);
    var handler: Handler = .{ .pin = saved.pin };
    if (std.mem.eql(u8, phase, "stage")) {
        try send(init.io, &admin, &server, &handler, 0, false);
        try send(init.io, &admin, &server, &handler, 1, false);
        try send(init.io, &admin, &server, &handler, 11, false);
        for (0..3) |i| {
            try send(init.io, &admin, &server, &handler, @intCast(2000 + i), false);
        }
        for (0..84) |i| try send(init.io, &admin, &server, &handler, @intCast(1000 + i * 3), false);
        try send(init.io, &admin, &server, &handler, 1252, true);
        saved.stale = server.pending.?.signed;
        try t.expectEqual(@as(u32, 252), (try descriptor(&admin, saved.resource, 1)).written);
        try t.expect((try value(&admin, saved.resource, try p.Value.init("head"))) == null);
        try t.expectEqual(@as(usize, 1), handler.lost);
    } else if (std.mem.eql(u8, phase, "seal")) {
        try drive(init.io, &server, &handler, false); // Same still-pending input, fresh ownership.
        try send(init.io, &admin, &server, &handler, 1255, false);
        try send(init.io, &admin, &server, &handler, 2, true);
        saved.stale = server.pending.?.signed;
        const record = try descriptor(&admin, saved.resource, 1);
        try t.expectEqual(.staging, record.state);
        try t.expectEqual(@as(u32, 256), record.written);
        try t.expect((try value(&admin, saved.resource, try p.Value.init("head"))) == null);
    } else if (std.mem.eql(u8, phase, "publish")) {
        try drive(init.io, &server, &handler, true);
        const pending = server.pending.?.signed;
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal, .permissions = 0 } });
        try t.expectError(error.AccessDenied, server.dispatchPending());
        try t.expect(std.meta.eql(pending, server.pending.?.signed));
        try t.expect((try value(&admin, saved.resource, try p.Value.init("head"))) == null);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal, .permissions = p.State.all_permissions } });
        try drive(init.io, &server, &handler, false);
        try t.expectEqual(@as(usize, 1), handler.lost);
        const accepted = server.confirmation.?.receipt.position;
        const record = try descriptor(&admin, saved.resource, 1);
        try t.expectEqual(.published, record.state);
        try t.expectEqual(saved.pid, record.publisher);
        try t.expectEqualStrings("1", (try value(&admin, saved.resource, try p.Value.init("head"))).?.slice());
        const process = (try admin.query(.{ .process = saved.pid })).body.process;
        try t.expect(process.input == null);
        try send(init.io, &admin, &server, &handler, 2, false); // Duplicate domain command, distinct input.
        const cut = (try admin.query(.{ .capabilities = {} })).position;
        const outputs = (try admin.query(.{ .outputs = .{ .position = cut } })).body.outputs;
        try t.expect(outputs.entries[0] != null and outputs.entries[1] == null and outputs.next == null);
        try t.expectEqual(accepted, outputs.entries[0].?.turn);
        try send(init.io, &admin, &server, &handler, 3, false);
        try send(init.io, &admin, &server, &handler, 4, false);
        saved.pin = handler.pin;
        for (3000..3041) |code| try send(init.io, &admin, &server, &handler, @intCast(code), false);
        try t.expect((try admin.query(.{ .resource = saved.resource })).body.resource.entries > 300);
        _ = try admin.submit(.{ .checkpoint = {} });
    } else if (std.mem.eql(u8, phase, "cleanup")) {
        try send(init.io, &admin, &server, &handler, 3, false);
        // Revoke after an actual prefix. Poisoned reads cannot become success.
        try admin.send(saved.pid, 3);
        try prepare(init.io, &server, now(init.io) + 30000);
        const pubn = publication(&server.ready.?);
        const first = try pubn.read(&server.ready.?, try pubn.open(&server.ready.?, 1));
        try t.expect(first.next != null);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal, .permissions = 0 } });
        try t.expectError(error.AccessDenied, pubn.read(&server.ready.?, first.next.?));
        try t.expectError(error.AccessDenied, server.finish(null));
        try t.expect(server.pending == null);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal, .permissions = p.State.all_permissions } });
        try drive(init.io, &server, &handler, false);
        // A deadline cannot be extended by keeping a cursor or retrying its read.
        try admin.send(saved.pid, 3);
        const deadline = now(init.io) + max_clock_error_ms + 3000;
        try prepare(init.io, &server, deadline);
        const cursor = try pubn.open(&server.ready.?, 1);
        // Use the fixture's admitted clock bound: wall time past the deadline
        // alone may still yield DeadlineUncertain, which poisons this turn.
        // Wait until every admitted sample must have its lower bound expired.
        const definitely_expired = deadline + max_clock_error_ms + 1;
        while (now(init.io) < definitely_expired)
            try init.io.sleep(.fromMilliseconds(@intCast(definitely_expired -| now(init.io))), .awake);
        try t.expectError(error.Rejected, pubn.read(&server.ready.?, cursor));
        try t.expectEqual(.StateViewExpired, wire.last_rejection.?);
        try reown(&admin, &saved);
        server = try makeServer(&wire, saved, worker);
        try drive(init.io, &server, &handler, false);
        try send(init.io, &admin, &server, &handler, 5, false);
        try send(init.io, &admin, &server, &handler, 6, false);
        try send(init.io, &admin, &server, &handler, 7, false);
        try send(init.io, &admin, &server, &handler, 8, false);
        try t.expectEqual(@as(u32, 2), (try descriptor(&admin, saved.resource, 1)).collected);
        try t.expectEqual(@as(u32, 2), (try descriptor(&admin, saved.resource, 2)).collected);
        try send(init.io, &admin, &server, &handler, 9, false);
        _ = try admin.submit(.{ .checkpoint = {} });
    } else if (std.mem.eql(u8, phase, "finish")) {
        const before = try descriptor(&admin, saved.resource, 1);
        try t.expectEqual(@as(u32, 2), before.collected);
        for (0..127) |_| try send(init.io, &admin, &server, &handler, 6, false);
        try send(init.io, &admin, &server, &handler, 8, false);
        try send(init.io, &admin, &server, &handler, 12, false);
        const progress = (try value(&admin, saved.resource, try p.Value.init("read-progress"))).?;
        try t.expectEqual(@as(u32, 8), std.mem.readInt(u32, progress.data[0..4], .little));
        for (0..31) |_| try send(init.io, &admin, &server, &handler, 9, false);
        try t.expectEqualStrings("65536", (try value(&admin, saved.resource, try p.Value.init("verified"))).?.slice());
        const retained = try server.session.version(saved.pin.?);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal, .permissions = 0 } });
        try t.expectError(error.AccessDenied, server.session.readVersion(retained, Pub.key(Namespace, 'c', 1, 0), null));
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Principal, .permissions = p.State.all_permissions } });
        try send(init.io, &admin, &server, &handler, 10, false);
        try t.expectError(error.Rejected, server.session.readVersion(retained, Pub.key(Namespace, 'c', 1, 0), null));
        try t.expectEqual(.ReadVersionReleased, wire.last_rejection.?);
        try t.expect((try value(&admin, saved.resource, try p.Value.init("head"))) == null);
        try t.expectEqualStrings("1", (try value(&admin, saved.resource, try p.Value.init("acceptances"))).?.slice());
        try t.expectEqual(@as(u64, 89), (try admin.query(.{ .resource = saved.resource })).body.resource.entries);
        try output.interface.print("Publication sizes: descriptor={d}, cursor={d}, part={d}, chunk=256; 64 KiB plus 41 retained records verified\n", .{ @sizeOf(Pub.Descriptor), @sizeOf(Pub.Cursor), @sizeOf(Pub.Part) });
    } else return error.UnknownPhase;
    try save(init, args[3], saved);
    try output.interface.print("Publication {s}: passed; generation={d}\n", .{ phase, saved.generation });
    try output.interface.flush();
    // The harness kills this actual worker at the recorded boundary, then kills
    // the authority and restarts its owned disk store. This file is evidence,
    // never a replacement for publication state in Transit.
    if (!std.mem.eql(u8, phase, "finish")) while (true) try init.io.sleep(.fromSeconds(60), .awake);
}
