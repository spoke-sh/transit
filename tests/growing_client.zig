//! Independent Zig application: imports the public client, never core/storage.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const g = p.Growth;
const t = std.testing;
const Expected = struct { pid: u64, resource: u64, receipt: u64, pending: g.SignedRequest };
const Caller = struct {
    client: *wire.Client,
    principal: u64,
    key: p.Ed25519.KeyPair,
    sequence: u64 = 0,
    fn sign(self: *@This(), command: g.Command) !g.SignedRequest {
        return g.sign(.{ .realm = 42, .principal = self.principal, .sequence = self.sequence + 1, .command = command }, self.key);
    }
    fn submit(self: *@This(), command: g.Command) !u64 {
        const receipt = try self.client.submitGrowing(try self.sign(command));
        self.sequence += 1;
        return receipt.position;
    }
    fn query(self: *@This(), kind: @FieldType(g.Query, "kind")) !g.Response {
        return self.client.queryGrowing(.{ .realm = 42, .principal = self.principal, .kind = kind }, self.key);
    }
};
fn key(index: usize) p.Value {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, index, .big);
    return p.Value.init(&bytes) catch unreachable;
}
fn value(index: usize) p.Value {
    var bytes: [256]u8 = @splat(42);
    std.mem.writeInt(u64, bytes[0..8], index, .big);
    return p.Value.init(&bytes) catch unreachable;
}
fn verify(worker: *Caller, expected: Expected) !void {
    const process = (try worker.query(.{ .process = expected.pid })).body.process;
    try t.expectEqual(@as(u64, 65536), process.process.owner.?);
    try t.expectEqual(@as(u64, 16), process.process.consumed);
    try t.expect(process.input == null);
    var after: ?p.Value = null;
    var count: usize = 0;
    while (true) {
        const result = try worker.query(.{ .entries = .{ .resource = expected.resource, .revision = expected.receipt, .after = after } });
        for (result.body.entries.page.entries) |slot| if (slot) |entry| {
            try t.expect(entry.key.eql(key(count)));
            try t.expect(entry.value.eql(value(count)));
            count += 1;
        };
        after = result.body.entries.page.next;
        if (after == null) break;
    }
    try t.expectEqual(@as(usize, 64), count);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var output_buffer: [16 * 1024]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        try std.json.Stringify.value(root_key.public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4) return error.ExpectedUrlPhaseManifest;
    var client = wire.Client.init(init.gpa, init.io, args[1]);
    defer client.deinit();
    client.timeout_ms = 10000;
    var root: Caller = .{ .client = &client, .principal = 0, .key = root_key };
    var worker: Caller = .{ .client = &client, .principal = 65536, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) };
    const writing = std.mem.eql(u8, args[2], "write");
    if (writing) {
        const capabilities = (try root.query(.{ .capabilities = {} })).body.capabilities;
        try t.expect(!capabilities.station and !capabilities.runtime_bindings and !capabilities.history_reclamation);
        try t.expectEqual(.unlimited, capabilities.retained_history);
        _ = try root.submit(.{ .grant = .{ .subject = 65536, .public_key = worker.key.public_key.toBytes(), .permissions = p.all_permissions } });
        const pid = try root.submit(.{ .spawn = .{} });
        const resource = try root.submit(.{ .create_resource = .{ .writer = pid } });
        for (0..5) |_| _ = try root.submit(.{ .create_resource = .{ .writer = pid } });
        for ([_]u64{ 0, 65536 }) |principal| _ = try root.submit(.{ .grant_resource = .{ .resource = resource, .subject = principal, .permissions = p.State.all_permissions } });
        _ = try root.submit(.{ .associate = .{ .pid = pid, .name = try p.Value.init("data"), .resource = resource } });
        _ = try root.submit(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 65536 } });
        var session: wire.GrowingSession = .{ .client = &client, .realm = 42, .principal = 65536, .pid = pid, .generation = 2, .key = worker.key };
        for (0..16) |turn| {
            const input = try root.submit(.{ .send = .{ .pid = pid, .value = .{} } });
            var delivery = (try session.receive()).?;
            try t.expectEqual(input, delivery.input.position);
            const resource_meta = (try worker.query(.{ .resource = resource })).body.resource;
            const opening = try session.prepareView(delivery, resource_meta, @as(u64, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds())) + 30000);
            const view = (try opening.submit(&client)).position;
            // A handler can read just one key at its captured version. It never
            // materializes the entire resource as a prerequisite to execution.
            const captured = try session.readView(view, key(0), null);
            try t.expectEqual(turn == 0, captured.page.entries[0] == null);
            var mutations: [g.turn_mutations]?g.Mutation = @splat(null);
            for (&mutations, 0..) |*slot, i| slot.* = .{ .key = key(turn * 4 + i), .value = value(turn * 4 + i) };
            delivery = (try session.receive()).?; // Opening the view consumed a sequence.
            const pending = try session.prepareCommit(delivery, .{ .views = .{ captured.view.?, null, null, null }, .write_view = view, .mutations = mutations });
            const signed = pending.signed;
            if (turn == 15) {
                // The harness corrupts this accepted reply. Freeze exact retry
                // bytes across caller, node and provider loss; no fresh sequence.
                try t.expectError(error.InvalidAuthorityResponse, pending.submit(&client));
                const expected: Expected = .{ .pid = pid, .resource = resource, .receipt = view + 1, .pending = signed };
                const bytes = try std.json.Stringify.valueAlloc(init.gpa, expected, .{});
                defer init.gpa.free(bytes);
                try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = bytes });
                try verify(&worker, expected);
            } else {
                _ = try pending.submit(&client);
            }
        }
    } else {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(wire.max_body));
        defer init.gpa.free(bytes);
        const parsed = try std.json.parseFromSlice(Expected, init.gpa, bytes, .{});
        defer parsed.deinit();
        const expected = parsed.value;
        if (std.mem.eql(u8, args[2], "invalid-read")) {
            try t.expectError(error.InvalidAuthorityResponse, worker.query(.{ .entries = .{ .resource = expected.resource, .revision = expected.receipt } }));
        } else if (std.mem.eql(u8, args[2], "recover")) {
            const before = (try root.query(.{ .capabilities = {} })).position;
            try t.expectEqual(expected.receipt, (try client.submitGrowing(expected.pending)).position);
            try t.expectEqual(before, (try root.query(.{ .capabilities = {} })).position);
            try verify(&worker, expected);
            root.sequence = (try root.query(.{ .capabilities = {} })).principal_sequence;
            _ = try root.submit(.{ .revoke = 65536 });
            try t.expectError(error.AccessDenied, client.submitGrowing(expected.pending));
            try t.expectError(error.AccessDenied, worker.query(.{ .entries = .{ .resource = expected.resource, .revision = expected.receipt } }));
        } else return error.UnknownPhase;
    }
    try output.interface.print("Growing client {s}: passed\n", .{args[2]});
    try output.interface.flush();
}
