//! Public native caller for the actual independently scheduled example worker.
const std = @import("std");
const W = @import("work_items");
const s = W.app.station;
const p = W.app.protocol;
const g = p.Growth;
const t = std.testing;
const Realm = 51;
const Operator = 65537;
const Worker = 65536;
const Admin = @import("growing_support.zig").Admin(Realm);
const Saved = struct { pid: u64, resource: u64, generation: u64, activation: u8 = 8 };
fn owner(saved: Saved) W {
    return .{ .configuration = .{ .application = 9, .realm = Realm, .administrator = Operator, .writer = Operator, .resource = saved.resource } };
}
fn write(init: std.process.Init, path: []const u8, value: anytype) !void {
    var atomic = try std.Io.Dir.cwd().createFileAtomic(init.io, path, .{ .replace = true, .permissions = .fromMode(0o600) });
    defer atomic.deinit(init.io);
    var buffer: [4096]u8 = undefined;
    var output = atomic.file.writerStreaming(init.io, &buffer);
    var encoder: std.json.Stringify = .{ .writer = &output.interface };
    try p.Json.write(value, &encoder);
    try output.interface.flush();
    try atomic.file.sync(init.io);
    try atomic.replace(init.io);
}
const Caller = struct {
    wire: *s.client.Client,
    key: p.Ed25519.KeyPair,
    saved: Saved,
    sequence: u64,
    fn resources(self: *@This()) s.client.ResourceReader {
        return .{ .wire = self.wire, .realm = Realm, .principal = Operator, .key = self.key };
    }
    fn read(self: *@This()) !s.client.ResourceReader.Reader {
        return self.resources().open(self.saved.resource);
    }
    fn send(self: *@This(), io: std.Io, command: W.Command, reason: ?[]const u8) !u64 {
        const frozen = try g.sign(.{ .realm = Realm, .principal = Operator, .sequence = self.sequence + 1, .command = .{ .send = .{ .pid = self.saved.pid, .value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, self.key);
        const receipt = self.wire.submitGrowing(frozen) catch |err| value: {
            if (err != error.InvalidAuthorityResponse and !s.client.Client.unavailable(err)) return err;
            break :value try self.wire.submitGrowing(frozen);
        };
        // Retrying accepted bytes cannot admit a second input.
        try t.expectEqual(receipt.position, (try self.wire.submitGrowing(frozen)).position);
        self.sequence += 1;
        const deadline = std.Io.Clock.boot.now(io).toMilliseconds() + 60000;
        while (true) {
            const response = try self.resources().query(.{ .process = self.saved.pid });
            if (response.body.process.input == null or response.body.process.input.?.position > receipt.position) break;
            if (std.Io.Clock.boot.now(io).toMilliseconds() > deadline) return error.WorkerTimeout;
            try io.sleep(.fromMilliseconds(25), .awake);
        }
        var reader = try self.read();
        const error_value = try reader.read(W.dispositionKey(9, Operator, receipt.position));
        if (reason) |expected| try t.expectEqualStrings(expected, (error_value orelse return error.MissingDisposition).slice()) else try t.expect(error_value == null);
        return receipt.position;
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) {
        var buffer: [1024]u8 = undefined;
        var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try std.json.Stringify.value(root_key.public_key.toBytes(), .{}, &output.interface);
        return output.interface.flush();
    }
    if (args.len != 4) return error.Usage;
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var admin: Admin = .{ .wire = &wire, .key = root_key };
    admin.sequence = (try admin.query(.{ .capabilities = {} })).principal_sequence;
    const directory = args[3];
    const saved_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/saved.json", .{directory});
    const config_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/worker.json", .{directory});
    const key_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/worker.seed", .{directory});
    const phase = args[2];
    const operator_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    var saved: Saved = undefined;
    if (std.mem.eql(u8, phase, "setup")) {
        const created = try admin.provision(Worker, try p.Ed25519.KeyPair.generateDeterministic(@splat(8)));
        saved = .{ .pid = created.pid, .resource = created.resource, .generation = created.generation };
        _ = try admin.submit(.{ .grant = .{ .subject = Operator, .public_key = operator_key.public_key.toBytes(), .permissions = p.permission(.send) | p.permission(.inspect), .pid = saved.pid } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Operator, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    } else {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, saved_path, init.arena.allocator(), .limited(4096));
        saved = (try std.json.parseFromSlice(Saved, init.arena.allocator(), bytes, .{})).value;
    }
    if (std.mem.eql(u8, phase, "setup") or std.mem.eql(u8, phase, "fence")) {
        if (std.mem.eql(u8, phase, "fence")) {
            _ = try admin.submit(.{ .own = .{ .pid = saved.pid, .expected_generation = saved.generation, .worker = Worker } });
            saved.generation += 1;
            saved.activation += 1;
            const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(saved.activation));
            _ = try admin.submit(.{ .grant = .{ .subject = Worker, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = saved.pid } });
            _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Worker, .permissions = p.State.all_permissions } });
            _ = try admin.submit(.{ .own = .{ .pid = saved.pid, .expected_generation = saved.generation, .worker = Worker } });
            saved.generation += 1;
        }
        const seed: [32]u8 = @splat(saved.activation);
        const hex = std.fmt.bytesToHex(seed, .lower);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = key_path, .data = &hex });
        try write(init, saved_path, saved);
        return write(init, config_path, .{ .url = args[1], .principal = Worker, .pid = saved.pid, .generation = saved.generation, .seed_file = key_path, .activation_directory = directory, .application = owner(saved).configuration, .request_timeout_ms = @as(u32, 5000) });
    }
    var caller: Caller = .{ .wire = &wire, .key = operator_key, .saved = saved, .sequence = 0 };
    caller.sequence = (try caller.resources().query(.{ .capabilities = {} })).principal_sequence;
    const ledger = try owner(saved).ledger();
    if (std.mem.eql(u8, phase, "seed")) {
        _ = try caller.send(init.io, .initialize, null);
        _ = try caller.send(init.io, .{ .policy = .{ .principal = Operator, .expected = .{}, .next = .{ .revision = .{ .value = 1 }, .migrate = true } } }, null);
        for (0..19) |i| _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 1 }, .id = @as(i64, @intCast(i)) - 10, .state = @intCast(i % 2) } }, null);
        _ = try caller.send(init.io, .{ .begin = try owner(saved).proposal(2) }, null);
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 99, .state = 0 } }, "WorkItemMigrationPaused");
    } else if (std.mem.eql(u8, phase, "deny")) {
        var reader = try caller.read();
        const before = try ledger.progress(&reader, .{ .value = 2 });
        _ = try caller.send(init.io, .{ .policy = .{ .principal = Operator, .expected = .{ .value = 1 }, .next = .{ .revision = .{ .value = 2 }, .migrate = false } } }, null);
        _ = try caller.send(init.io, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = before.next, .operation = 1, .arguments = before.cursor } }, "MigrationDenied");
        reader = try caller.read();
        try t.expectEqualDeep(before, try ledger.progress(&reader, .{ .value = 2 }));
        _ = try caller.send(init.io, .{ .policy = .{ .principal = Operator, .expected = .{ .value = 2 }, .next = .{ .revision = .{ .value = 3 }, .migrate = true } } }, null);
    } else if (std.mem.eql(u8, phase, "step") or std.mem.eql(u8, phase, "finish")) {
        for (0..100) |_| {
            var reader = try caller.read();
            const progress = try ledger.progress(&reader, .{ .value = 2 });
            if (progress.phase == .applied) break;
            const cursor = try W.Cursor.decode(progress.cursor);
            const command: W.Command = .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = progress.next, .operation = if (cursor.phase == .ready) 2 else 1, .arguments = progress.cursor } };
            _ = try caller.send(init.io, command, null);
            if (std.mem.eql(u8, phase, "step")) return;
        }
        var reader = try caller.read();
        const head = try ledger.head(&reader);
        try t.expectEqual(2, head.epoch.value);
        try t.expectEqualSlices(u8, &head.contract, &try (try owner(saved).source(2)).fingerprint());
        for (0..19) |i| {
            const key = @as(i64, @intCast(i)) - 10;
            const table = try s.Table.open(&reader, 2);
            try t.expectEqual(@as(i64, if (i % 2 == 0) 10 else 20), (try table.get(&reader, key)).?.value.int64);
        }
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 99, .state = 1 } }, "WorkItemEpochChanged");
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 2 }, .id = 99, .state = 20 } }, "WorkItemPublicationPaused");
        _ = try caller.send(init.io, .{ .release_writes = .{ .epoch = .{ .value = 2 }, .contract = head.contract } }, null);
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 2 }, .id = 99, .state = 20 } }, null);
        _ = try caller.send(init.io, .{ .abandon = .{ .value = 2 } }, "MigrationAlreadyApplied");
    } else return error.UnknownPhase;
}
