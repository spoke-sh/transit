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
const Admin = @import("fixture_growing_support").Admin(Realm);
const c = W.query.catalog;
const authorization = @import("fixture_table_authorization_support");
pub const Saved = struct { data: ?W.Data.Binding = null, authority: ?c.TableAuthority.Profile = null, pid: u64, resource: u64, generation: u64, worker_key: [32]u8, activation: u8 = 8, denied_input: u64 = 0, cursor_input: u64 = 0, ordinal_input: u64 = 0 };
pub fn owner(allocator: std.mem.Allocator, saved: Saved) W {
    return .{ .allocator = allocator, .configuration = .{ .owner = saved.pid, .application = 9, .realm = Realm, .administrator = Operator, .writer = Operator, .resource = saved.resource } };
}
pub fn write(init: std.process.Init, path: []const u8, value: anytype) !void {
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
pub const Caller = struct {
    wire: *s.client.Client,
    key: p.Ed25519.KeyPair,
    saved: Saved,
    sequence: u64,
    pub fn resources(self: *@This()) s.client.ResourceReader {
        return .{ .wire = self.wire, .realm = Realm, .principal = Operator, .key = self.key };
    }
    pub fn read(self: *@This()) !s.client.ResourceReader.Reader {
        const start = std.Io.Clock.awake.now(self.wire.http.io);
        while (true) return self.resources().open(self.saved.resource) catch |err| {
            if (!s.client.Client.unavailable(err) or start.durationTo(std.Io.Clock.awake.now(self.wire.http.io)).toMilliseconds() >= 10000) return err;
            try self.wire.http.io.sleep(.fromMilliseconds(25), .awake);
            continue;
        };
    }
    pub fn http(self: *@This()) W.Data.Http {
        return .{ .allocator = self.wire.http.allocator, .resources = self.resources() };
    }
    pub fn authorized(self: *@This(), source: *s.client.ResourceReader.Reader) !c.TableAuthority.Source(*s.client.ResourceReader.Reader) {
        var data = self.http();
        return (try data.authorization(self.saved.data orelse return error.MissingProofDataBinding)).wrap(source);
    }
    pub fn row(self: *@This(), table: u32, key: i64) !?W.Table.Row {
        var data = self.http();
        const binding = self.saved.data orelse return error.MissingProofDataBinding;
        const client = try data.transport().bind(binding);
        var metadata = try W.Table.definition(client, binding, table);
        defer metadata.deinit();
        return W.Table.get(self.wire.http.allocator, client, metadata.value, metadata.value.position, key);
    }
    pub fn query(self: *@This(), kind: @FieldType(g.Query, "kind")) !g.Response {
        const start = std.Io.Clock.awake.now(self.wire.http.io);
        while (true) return self.resources().query(kind) catch |err| {
            if (!s.client.Client.unavailable(err) or start.durationTo(std.Io.Clock.awake.now(self.wire.http.io)).toMilliseconds() >= 10000) return err;
            try self.wire.http.io.sleep(.fromMilliseconds(25), .awake);
            continue;
        };
    }
    fn submit(self: *@This(), frozen: g.SignedRequest) !p.Receipt {
        const start = std.Io.Clock.awake.now(self.wire.http.io);
        while (true) return self.wire.submit(frozen) catch |err| {
            if ((!s.client.Client.unavailable(err) and err != error.InvalidAuthorityResponse) or start.durationTo(std.Io.Clock.awake.now(self.wire.http.io)).toMilliseconds() >= 10000) return err;
            try self.wire.http.io.sleep(.fromMilliseconds(25), .awake);
            continue;
        };
    }
    fn observationChanged(self: *@This(), err: anyerror) bool {
        return s.client.Client.unavailable(err) or ((err == error.Rejected or err == error.Conflict) and
            (self.wire.last_rejection == .StaleStateResource or self.wire.last_rejection == .QueryExpired));
    }
    fn failure(self: *@This(), io: std.Io, input: u64) !?W.Failure.Disposition {
        const started = std.Io.Clock.awake.now(io);
        while (true) {
            var reader = try self.read();
            return W.Failure.read(owner(self.wire.http.allocator, self.saved).configuration, &reader, Operator, input) catch |err| {
                if (!self.observationChanged(err) or started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() >= 10000) return err;
                try io.sleep(.fromMilliseconds(25), .awake);
                continue;
            };
        }
    }
    fn completed(self: *@This(), command: W.Command, input: u64) !bool {
        var source = try self.read();
        var reader = try self.authorized(&source);
        var data = self.http();
        var application = owner(self.wire.http.allocator, self.saved);
        application.transport = data.transport();
        return application.completed(&reader, command, input);
    }
    pub fn progress(self: *@This(), plan: W.app.Model.Wide) !W.app.Migration.Progress {
        const start = std.Io.Clock.awake.now(self.wire.http.io);
        const ledger = try owner(self.wire.http.allocator, self.saved).ledger();
        while (true) {
            var reader = try self.read();
            return ledger.progress(&reader, plan) catch |err| {
                if (!self.observationChanged(err) or start.durationTo(std.Io.Clock.awake.now(self.wire.http.io)).toMilliseconds() >= 10000) return err;
                try self.wire.http.io.sleep(.fromMilliseconds(25), .awake);
                continue;
            };
        }
    }
    pub fn send(self: *@This(), io: std.Io, command: W.Command, reason: ?[]const u8) !u64 {
        const input = try self.sendPayload(io, try command.encode(), reason);
        if (reason == null) {
            const started = std.Io.Clock.awake.now(io);
            while (true) {
                const done = self.completed(command, input) catch |err| value: {
                    if (!self.observationChanged(err)) return err;
                    break :value false;
                };
                if (done) break;
                const process = (try self.query(.{ .process = self.saved.pid })).body.process;
                if (process.process.failure != null or process.process.lifecycle != .running) return error.WorkerUnavailable;
                if (started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() >= 60000) return error.WorkerTimeout;
                try io.sleep(.fromMilliseconds(25), .awake);
            }
        }
        return input;
    }
    pub fn sendPayload(self: *@This(), io: std.Io, payload: p.Value, reason: ?[]const u8) !u64 {
        const frozen = try g.sign(.{ .realm = Realm, .principal = Operator, .sequence = self.sequence + 1, .command = .{ .send = .{ .pid = self.saved.pid, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, self.key);
        const receipt = try self.submit(frozen);
        // Retrying accepted bytes cannot admit a second input.
        try t.expectEqual(receipt.position, (try self.submit(frozen)).position);
        self.sequence += 1;
        const deadline = std.Io.Clock.boot.now(io).toMilliseconds() + 60000;
        while (true) {
            const response = try self.query(.{ .process = self.saved.pid });
            if (response.body.process.input == null or response.body.process.input.?.position > receipt.position) break;
            if (std.Io.Clock.boot.now(io).toMilliseconds() > deadline) return error.WorkerTimeout;
            try io.sleep(.fromMilliseconds(25), .awake);
        }
        const disposition = try self.failure(io, receipt.position);
        if (reason) |expected| {
            const value = disposition orelse return error.MissingDisposition;
            try t.expectEqualStrings(expected, value.record.cause.slice());
            try t.expectEqual(p.Diagnostic.Outcome.input_rejected, value.diagnostic.outcome);
            const frame = try (s.Frame{ .kind = .cast, .payload = payload }).encode();
            var digest = std.crypto.hash.sha2.Sha256.init(.{});
            digest.update("transit.application.migration.input.v1\x00");
            digest.update(frame.slice());
            try t.expectEqualSlices(u8, &digest.finalResult(), &value.record.payload);
            for (value.diagnostic.actions) |slot| if (slot) |action| try t.expect(action.kind == .inspect_status or action.kind == .inspect_scope);
        } else try t.expect(disposition == null);
        return receipt.position;
    }
};
pub fn provisionData(init: std.process.Init, admin: *Admin, saved: *Saved, owner_role: u64, directory: []const u8) !void {
    const resource = try admin.submit(.{ .create_resource = .{ .writer = saved.pid } });
    const scope: p.DataLifecycle.Scope = .{ .realm = Realm, .resource = resource, .catalog = 1 };
    const profile = try authorization.profile(c, admin, scope, 0, owner_role);
    _ = try admin.authorization(.{ .grant = .{ .object = .{ .kind = .process, .id = saved.pid }, .grantee = owner_role, .privileges = p.permission(.send) } });
    const worker_role = try authorization.loginRole(c, admin.wire, Realm, Worker, try p.Ed25519.KeyPair.generateDeterministic(@splat(saved.activation)));
    _ = try admin.authorization(.{ .membership = .{ .member = worker_role, .role = owner_role, .inherit = false, .set = true } });
    saved.authority = profile;
    saved.data = .{ .definition = p.Growth.definition_bytes, .scope = scope, .branch = 1, .audience = saved.pid, .namespace = 1, .first_object = 1000, .owner_role = owner_role };
    const config: c.DirectCatalog.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = saved.pid, .authority = profile, .database_name = try .init("work_items"), .initial_schema_name = try .init("public") };
    const seed: [32]u8 = @splat(7);
    const seed_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/registrar.seed", .{directory});
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = seed_path, .data = &std.fmt.bytesToHex(seed, .lower) });
    try write(init, try std.fmt.allocPrint(init.arena.allocator(), "{s}/data-catalog.json", .{directory}), .{ .catalog = config, .registrar = .{ .principal = @as(u64, 0), .seed_file = seed_path } });
}
pub fn initializeData(allocator: std.mem.Allocator, wire: *s.client.Client, saved: Saved) !void {
    const binding = saved.data orelse return error.MissingProofDataBinding;
    const client: c.DirectTableClient = .{ .allocator = allocator, .authority = wire, .service = wire, .connection = try binding.connection(Operator, null), .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9)) };
    const response = try client.call(.initialize);
    defer response.deinit();
    try t.expect(response.value.result == .initialized);
}
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
        saved = .{ .pid = created.pid, .resource = created.resource, .generation = created.generation, .worker_key = (try p.Ed25519.KeyPair.generateDeterministic(@splat(8))).public_key.toBytes() };
        const owner_role = try authorization.login(c, &admin, "work-items-owner", Operator, operator_key, saved.pid);
        try provisionData(init, &admin, &saved, owner_role, directory);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Operator, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        const courier_seed: [32]u8 = @splat(10);
        const courier_key = try p.Ed25519.KeyPair.generateDeterministic(courier_seed);
        _ = try admin.submit(.{ .grant = .{ .subject = 65538, .public_key = courier_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery) } });
        const courier_path = try std.fmt.allocPrint(init.arena.allocator(), "{s}/courier.seed", .{directory});
        const courier_hex = std.fmt.bytesToHex(courier_seed, .lower);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = courier_path, .data = &courier_hex });
        try write(init, try std.fmt.allocPrint(init.arena.allocator(), "{s}/courier.json", .{directory}), .{ .url = args[1], .realm = Realm, .principal = @as(u64, 65538), .seed_file = courier_path, .role = .{ .courier = .{ .destinations = [1]u64{saved.pid} } } });
    } else {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, saved_path, init.arena.allocator(), .limited(4096));
        saved = (try std.json.parseFromSlice(Saved, init.arena.allocator(), bytes, .{})).value;
    }
    if (std.mem.eql(u8, phase, "setup") or std.mem.eql(u8, phase, "fence")) {
        if (std.mem.eql(u8, phase, "fence")) {
            saved.activation += 1;
            const next = try p.Ed25519.KeyPair.generateDeterministic(@splat(saved.activation));
            _ = try admin.submit(.{ .rotate_worker = .{ .pid = saved.pid, .worker = Worker, .expected_generation = saved.generation, .expected_public_key = saved.worker_key, .expected_permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .public_key = next.public_key.toBytes() } });
            saved.generation += 1;
            saved.worker_key = next.public_key.toBytes();
        }
        const seed: [32]u8 = @splat(saved.activation);
        const hex = std.fmt.bytesToHex(seed, .lower);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = key_path, .data = &hex });
        try write(init, saved_path, saved);
        return write(init, config_path, .{ .url = args[1], .principal = Worker, .pid = saved.pid, .generation = saved.generation, .seed_file = key_path, .activation_directory = directory, .application = owner(init.gpa, saved).configuration, .request_timeout_ms = @as(u32, 5000) });
    }
    if (std.mem.eql(u8, phase, "initialize-data")) return initializeData(init.gpa, &wire, saved);
    var caller: Caller = .{ .wire = &wire, .key = operator_key, .saved = saved, .sequence = 0 };
    caller.sequence = (try caller.query(.{ .capabilities = {} })).principal_sequence;
    const ledger = try owner(init.gpa, saved).ledger();
    if (std.mem.eql(u8, phase, "seed")) {
        _ = try caller.send(init.io, .initialize, null);
        _ = try caller.send(init.io, .{ .catalog_initialize = saved.data orelse return error.MissingProofDataBinding }, null);
        for ([_]u32{ 1, 2 }) |table| _ = try caller.send(init.io, .{ .prepare_table = table }, null);
        _ = try caller.send(init.io, .{ .policy = .{ .principal = Operator, .expected = .{}, .next = .{ .revision = .{ .value = 1 }, .migrate = true } } }, null);
        for (0..19) |i| _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 1 }, .id = @as(i64, @intCast(i)) - 10, .state = @intCast(i % 2) } }, null);
        _ = try caller.send(init.io, .{ .begin = try owner(init.gpa, saved).proposal(2) }, null);
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 99, .state = 0 } }, "WorkItemMigrationPaused");
    } else if (std.mem.eql(u8, phase, "deny")) {
        var reader = try caller.read();
        const before = try ledger.progress(&reader, .{ .value = 2 });
        _ = try caller.send(init.io, .{ .policy = .{ .principal = Operator, .expected = .{ .value = 1 }, .next = .{ .revision = .{ .value = 2 }, .migrate = false } } }, null);
        saved.denied_input = try caller.send(init.io, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = before.next, .operation = 1, .arguments = before.cursor } }, "MigrationDenied");
        reader = try caller.read();
        try t.expectEqualDeep(before, try ledger.progress(&reader, .{ .value = 2 }));
        _ = try caller.send(init.io, .{ .policy = .{ .principal = Operator, .expected = .{ .value = 2 }, .next = .{ .revision = .{ .value = 3 }, .migrate = true } } }, null);
        saved.cursor_input = try caller.send(init.io, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = before.next, .operation = 1, .arguments = try p.Value.init("wrong cursor") } }, "WorkItemCursorChanged");
        saved.ordinal_input = try caller.send(init.io, .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = .{ .value = before.next.value + 2 }, .operation = 1, .arguments = before.cursor } }, "MigrationStepConflict");
        try write(init, saved_path, saved);
    } else if (std.mem.eql(u8, phase, "step") or std.mem.eql(u8, phase, "finish")) {
        for (0..100) |_| {
            var reader = try caller.read();
            const progress = try ledger.progress(&reader, .{ .value = 2 });
            const plan = (try ledger.plan(&reader, .{ .value = 2 })).?;
            const detail = try W.app.MigrationDiagnostic.progress(9, Realm, saved.resource, plan, progress);
            try t.expectEqual(if (progress.phase == .applied) p.Diagnostic.Outcome.applied else .pending, detail.outcome);
            try t.expectEqualStrings(if (progress.phase == .applied) "migration.applied" else "migration.active", detail.code.slice());
            try t.expectEqual(@as(u64, 2), try detail.identity.?.id.value());
            try t.expectEqualDeep(detail.identity, detail.actions[0].?.target);
            try t.expectEqual(null, detail.actions[1]);
            if (progress.phase == .applied) break;
            const cursor = try W.Cursor.decode(progress.cursor);
            const command: W.Command = .{ .step = .{ .plan = .{ .value = 2 }, .ordinal = progress.next, .operation = if (cursor.phase == .ready) 2 else 1, .arguments = progress.cursor } };
            _ = try caller.send(init.io, command, null);
            if (std.mem.eql(u8, phase, "step")) return;
        }
        var reader = try caller.read();
        const head = try ledger.head(&reader);
        try t.expectEqual(2, head.epoch.value);
        try t.expectEqualSlices(u8, &head.contract, &try owner(init.gpa, saved).contract(2));
        for (0..19) |i| {
            const key = @as(i64, @intCast(i)) - 10;
            try t.expectEqual(@as(i64, if (i % 2 == 0) 10 else 20), (try caller.row(2, key)).?.state);
        }
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 1 }, .id = 99, .state = 1 } }, "WorkItemEpochChanged");
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 2 }, .id = 99, .state = 20 } }, "WorkItemPublicationPaused");
        _ = try caller.send(init.io, .{ .release_writes = .{ .epoch = .{ .value = 2 }, .contract = head.contract } }, null);
        _ = try caller.send(init.io, .{ .put = .{ .epoch = .{ .value = 2 }, .id = 99, .state = 20 } }, null);
        _ = try caller.send(init.io, .{ .abandon = .{ .value = 2 } }, "MigrationAlreadyApplied");
        reader = try caller.read();
        const denial = (try W.Failure.read(owner(init.gpa, saved).configuration, &reader, Operator, saved.denied_input)).?;
        try t.expectEqual(@as(u64, 2), denial.witness.ledger.policy.actual.value);
        try t.expect(!denial.witness.ledger.policy.migrate);
        const cursor_failure = (try W.Failure.read(owner(init.gpa, saved).configuration, &reader, Operator, saved.cursor_input)).?;
        try t.expectEqualStrings("work_items.cursor_changed", cursor_failure.diagnostic.code.slice());
        try t.expect(!std.mem.eql(u8, &cursor_failure.witness.cursor.expected, &cursor_failure.witness.cursor.actual));
        const ordinal_failure = (try W.Failure.read(owner(init.gpa, saved).configuration, &reader, Operator, saved.ordinal_input)).?;
        try t.expectEqual(ordinal_failure.witness.ledger.progress.next.value + 2, ordinal_failure.witness.ledger.progress.supplied.value);
        try t.expectEqual(W.app.Migration.Phase.active, ordinal_failure.witness.ledger.progress.phase);
        // Historical rejection is unchanged after activation and later policy restoration.
        try t.expectEqual(W.app.Migration.Phase.applied, (try ledger.progress(&reader, .{ .value = 2 })).phase);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = saved.resource, .subject = Operator, .permissions = p.State.permission(.inspect) } });
        var denied_reader = try caller.read();
        try t.expectError(error.AccessDenied, W.Failure.read(owner(init.gpa, saved).configuration, &denied_reader, Operator, saved.denied_input));
    } else return error.UnknownPhase;
}
