const std = @import("std");
const t = std.testing;
const core = @import("root.zig");
const g = core.protocol.Growth;
const growing = @import("growing.zig");
const PageStore = @import("pages_test.zig").Store;
const Journal = struct {
    entries: std.ArrayList(growing.Entry) = .empty,
    fail: enum { none, before, after } = .none,
    competing_append: ?growing.Entry = null,
    tail_calls: usize = 0,
    race_at: ?usize = null,
    publish_at: ?usize = null,
    publish: ?growing.Entry = null,
    pub fn tail(self: *Journal) !u64 {
        self.tail_calls += 1;
        if (self.publish_at == self.tail_calls) {
            try self.entries.append(t.allocator, self.publish.?);
            self.publish = null;
        }
        return self.entries.items.len + @as(u64, if (self.race_at == self.tail_calls) 1 else 0);
    }
    pub fn read(self: *Journal, at: u64) !?growing.Entry {
        return if (at < self.entries.items.len) self.entries.items[@intCast(at)] else null;
    }
    pub fn append(self: *Journal, at: u64, entry: growing.Entry) !bool {
        if (self.competing_append) |other| {
            self.competing_append = null;
            try self.entries.append(t.allocator, other);
        }
        if (at != self.entries.items.len) return false;
        if (self.fail == .before) return error.StorageUnavailable;
        try self.entries.append(t.allocator, entry);
        if (self.fail == .after) return error.LostAcknowledgement;
        return true;
    }
};
const Engine = growing.Engine(Journal, PageStore);

test "incompatible v1 signatures and persisted heads cannot alter accepted history" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    // Independent old canonical bytes: the public v1 label is unchanged, but
    // these bytes do not bind the current contract definition.
    const old = "{\"version\":1,\"realm\":42,\"principal\":0,\"sequence\":1,\"command\":{\"spawn\":{\"allow_collection\":false,\"code\":1,\"work_before_ms\":null,\"settle_before_ms\":null}}}";
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(g.request_domain);
    hash.update(old);
    const signed: g.SignedRequest = .{
        .request = .{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .spawn = .{} } },
        .signature = (try f.root_key.sign(&hash.finalResult(), null)).toBytes(),
    };
    const before = f.engine.head;
    const writes = f.pages.writes;
    try t.expectError(error.SignatureVerificationFailed, f.engine.submit(signed));
    try t.expect(std.meta.eql(before, f.engine.head));
    try t.expectEqual(writes, f.pages.writes);
    try t.expectEqual(@as(u64, 1), try f.journal.tail());
    try t.expectEqual(@as(u64, 0), (try f.engine.principal(0)).sequence);

    const encoded = try std.json.Stringify.valueAlloc(t.allocator, before, .{});
    defer t.allocator.free(encoded);
    const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, encoded, .{});
    defer parsed.deinit();
    var head = parsed.value;
    head.object.getPtr("definition").?.* = .{ .string = "previous-v1-definition" };
    const foreign = try std.json.Stringify.valueAlloc(t.allocator, head, .{});
    defer t.allocator.free(foreign);
    try t.expectError(error.InvalidEnumTag, std.json.parseFromSlice(growing.Head, t.allocator, foreign, .{}));
    _ = head.object.swapRemove("definition");
    const missing = try std.json.Stringify.valueAlloc(t.allocator, head, .{});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, std.json.parseFromSlice(growing.Head, t.allocator, missing, .{}));
    const recovered = try Engine.open(&f.journal, &f.pages, f.genesis);
    try t.expect(std.meta.eql(before, recovered.head));
    try t.expectEqual(writes, f.pages.writes);
}

test "paged managed readiness and suspension preserve backlog and required recovery state" {
    const Clock = struct {
        now: core.Time.Sample = .{ .unix_ms = 10 },
        fn read(context: *anyopaque) anyerror!core.Time.Sample {
            return @as(*@This(), @ptrCast(@alignCast(context))).now;
        }
    };
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    var clock: Clock = .{};
    f.engine.clock = .{ .context = &clock, .read = Clock.read };
    const name = try core.Value.init("state");
    const pid = try f.root(.{ .create = .{ .required = .{ name, null, null, null } } });
    const input = try f.root(.{ .send = .{ .pid = pid, .value = .{} } });
    try t.expectEqual(@as(?g.Input, null), (try f.query(0, .{ .process = pid })).body.process.input);
    try t.expectError(error.InvalidLifecycle, f.root(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 0 } }));
    try t.expectError(error.MissingRequiredAssociation, f.root(.{ .initialize = .{ .pid = pid, .expected_generation = 0 } }));
    const resource = try f.root(.{ .create_resource = .{ .writer = pid, .deadline_ms = 100 } });
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    _ = try f.root(.{ .associate = .{ .pid = pid, .name = name, .resource = resource } });
    _ = try f.root(.{ .initialize = .{ .pid = pid, .expected_generation = 1 } });
    _ = try f.root(.{ .own = .{ .pid = pid, .expected_generation = 2, .worker = 0 } });
    try t.expectError(error.StateResourceExpired, f.root(.{ .@"suspend" = .{ .pid = pid, .expected_generation = 3, .resume_before_ms = 101 } }));
    _ = try f.root(.{ .@"suspend" = .{ .pid = pid, .expected_generation = 3, .resume_before_ms = 90 } });
    try t.expectEqual(@as(?g.Input, null), (try f.query(0, .{ .process = pid })).body.process.input);
    try t.expectEqual(@as(u64, 0), (try f.engine.process(pid)).consumed);
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    f.engine.clock = .{ .context = &clock, .read = Clock.read };
    try t.expectError(error.StaleGeneration, f.root(.{ .@"resume" = .{ .pid = pid, .expected_generation = 3 } }));
    _ = try f.root(.{ .@"resume" = .{ .pid = pid, .expected_generation = 4 } });
    try t.expectEqual(input, (try f.query(0, .{ .process = pid })).body.process.input.?.position);
    _ = try f.root(.{ .@"suspend" = .{ .pid = pid, .expected_generation = 5, .resume_before_ms = 90 } });
    clock.now = .{ .unix_ms = 90 };
    try t.expectError(error.DeadlineExpired, f.root(.{ .@"resume" = .{ .pid = pid, .expected_generation = 6 } }));
    _ = try f.root(.{ .expire_suspension = pid });
    try t.expectEqual(.expired, (try f.engine.process(pid)).lifecycle);
    try t.expectEqual(@as(u64, 1), (try f.engine.process(pid)).cancelled);
}

test "paged runtime binding fences owners, retains resource reservations and recovers activation" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const pid = try f.root(.{ .spawn = .{} });
    const other = try f.root(.{ .spawn = .{} });
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.inspect), .pid = pid } });
    const resource = try f.root(.{ .create_resource = .{ .writer = pid } });
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 1 } });
    const epoch = (try f.engine.principal(65536)).epoch;
    const intent: core.protocol.Runtime.Intent = .{ .pid = pid, .expected_revision = 0, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3) };
    const operation = try f.root(.{ .runtime_intent = intent });
    try t.expectEqual(@as(u64, 1), (try f.engine.process(pid)).generation);
    try t.expectError(error.RuntimeActivationRequired, f.root(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 65536 } }));
    var duplicate = intent;
    duplicate.pid = other;
    try t.expectError(error.ResourceAlreadyBound, f.root(.{ .runtime_intent = duplicate }));
    const fresh = try core.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const activate: g.Command = .{ .activate = .{ .pid = pid, .revision = 1, .expected_generation = 1, .worker = 65536, .public_key = fresh.public_key.toBytes(), .worker_incarnation = @splat(5) } };
    try t.expectError(error.ProviderNotReady, f.root(activate));
    _ = try f.root(.{ .runtime_observe = .{ .pid = pid, .revision = 1, .operation = operation, .incarnation = @splat(4), .outcome = .ready } });
    const signed = try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = activate }, f.root_key);
    f.journal.fail = .after;
    try t.expectError(error.LostAcknowledgement, f.engine.submit(signed));
    f.journal.fail = .none;
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    _ = try f.engine.submit(signed);
    f.root_sequence += 1;
    const active = try f.engine.process(pid);
    try t.expectEqual(@as(?u64, 65536), active.owner);
    try t.expectEqual(@as(u64, 2), active.generation);
    try t.expectEqual(epoch, (try f.engine.principal(65536)).epoch);
    try t.expectEqual(@as(u64, 0), (try f.engine.principal(65536)).sequence);
    try t.expectError(error.AlreadyActivated, f.root(activate));
    const stopped = try f.root(.{ .runtime_intent = .{ .pid = pid, .expected_revision = 1, .instance = intent.instance, .resource = intent.resource, .workload = intent.workload, .desired = .stopped } });
    try t.expectEqual(@as(?u64, null), (try f.engine.process(pid)).owner);
    _ = try f.root(.{ .runtime_observe = .{ .pid = pid, .revision = 2, .operation = stopped, .incarnation = @splat(4), .outcome = .stopped } });
    const upgrade = try f.root(.{ .runtime_upgrade = .{ .pid = pid, .expected_revision = 2, .expected_workload = intent.workload, .workload = @splat(6), .expected_code = 1, .expected_state_revision = 0 } });
    try t.expectError(error.InvalidBinding, f.root(.{ .runtime_observe = .{ .pid = pid, .revision = 3, .operation = upgrade, .incarnation = @splat(4), .outcome = .ready } }));
    _ = try f.root(.{ .runtime_observe = .{ .pid = pid, .revision = 3, .operation = upgrade, .incarnation = @splat(4), .outcome = .stopped } });
    _ = try f.root(.{ .terminate = pid });
    try t.expectError(error.ResourceAlreadyBound, f.root(.{ .runtime_intent = duplicate }));
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    try t.expectEqual(.terminated, (try f.engine.process(pid)).lifecycle);
    try t.expectError(error.RetiredProcess, f.root(activate));
}

test "growing maintenance bounds each pass and preserves terminal work during clock failure" {
    const work = @import("growing_work.zig");
    const state = @import("growing_state.zig");
    const Clock = struct {
        now: core.Time.Sample = .{ .unix_ms = 10 },
        failed: bool = false,
        fn read(context: *anyopaque) anyerror!core.Time.Sample {
            const self: *@This() = @ptrCast(@alignCast(context));
            if (self.failed) return error.ClockUnavailable;
            return self.now;
        }
    };
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    var clock: Clock = .{};
    f.engine.clock = .{ .context = &clock, .read = Clock.read };
    const finite = try f.root(.{ .spawn = .{ .work_before_ms = 90, .settle_before_ms = 100 } });
    const source = try f.root(.{ .spawn = .{} });
    const destination = try f.root(.{ .spawn = .{} });
    const owned = try f.root(.{ .create_resource = .{ .writer = source } });
    const independent = try f.root(.{ .create_resource = .{ .writer = source, .owned = false } });
    _ = try f.root(.{ .own = .{ .pid = source, .expected_generation = 0, .worker = 0 } });
    const active = try f.emit(source, @splat(null), .{});
    _ = try f.root(.{ .dispatch = .{ .pid = source, .effect = active, .reconcile_before_ms = 100 } });
    const pending = try f.emit(source, .{ .{ .pid = destination, .value = .{} }, .{ .pid = destination, .value = .{} }, null, null }, .{});
    _ = try f.root(.{ .terminate = source });
    clock.failed = true;
    var scan: growing.Maintenance = .{};
    var errors: usize = 0;
    for (0..64) |_| {
        const before = f.engine.head.position;
        const writes = f.pages.writes;
        const command = scan.next(&f.engine, error.ClockUnavailable) catch |err| {
            try t.expectEqual(error.ClockUnavailable, err);
            errors += 1;
            continue;
        };
        try t.expectEqual(before, f.engine.head.position);
        try t.expectEqual(writes, f.pages.writes); // A scan never publishes/stages.
        if (command) |value| _ = try f.root(value);
    }
    try t.expect(errors > 0);
    try t.expectEqual(.running, (try f.engine.process(finite)).lifecycle);
    try t.expectEqual(.authorized, (try work.effect(&f.engine, active)).phase);
    try t.expectEqual(.cancelled, (try work.effect(&f.engine, pending)).phase);
    try t.expectEqual(.cancelled, (try work.output(&f.engine, 1)).phase);
    try t.expectEqual(.cancelled, (try work.output(&f.engine, 2)).phase);
    try t.expectEqual(@as(u64, 0), (try f.engine.process(destination)).admitted);
    try t.expectEqual(.retired, (try state.resource(&f.engine, owned)).phase);
    try t.expectEqual(.active, (try state.resource(&f.engine, independent)).phase);
    try t.expectEqual(@as(u64, 0), f.engine.head.history_floor);

    // An uncertainty interval crossing the deadline never authorizes closure.
    clock.failed = false;
    clock.now = .{ .unix_ms = 100, .error_ms = 5 };
    for (0..32) |_| try t.expectEqual(@as(?g.Command, null), try scan.next(&f.engine, clock.now));
    clock.now = .{ .unix_ms = 105, .error_ms = 5 };
    for (0..32) |_| {
        if (try scan.next(&f.engine, clock.now)) |command| _ = try f.root(command);
    }
    try t.expectEqual(.expired, (try f.engine.process(finite)).lifecycle);
    try t.expectEqual(.closed_unknown, (try work.effect(&f.engine, active)).phase);
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    // Restarted cursors rediscover durable state, not already completed work.
    scan = .{};
    const after = f.engine.head.position;
    for (0..32) |_| try t.expectEqual(@as(?g.Command, null), try scan.next(&f.engine, clock.now));
    try t.expectEqual(after, f.engine.head.position);
}

test "growing maintenance revisits skipped expiry despite continuing admission" {
    const Clock = struct {
        fn read(_: *anyopaque) anyerror!core.Time.Sample {
            return .{ .unix_ms = 10 };
        }
    };
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    var context: u8 = 0;
    f.engine.clock = .{ .context = &context, .read = Clock.read };
    const finite = try f.root(.{ .spawn = .{ .work_before_ms = 90, .settle_before_ms = 100 } });
    for (0..3) |_| _ = try f.root(.{ .spawn = .{} });
    var scan: growing.Maintenance = .{};
    try t.expectError(error.ClockUnavailable, scan.next(&f.engine, error.ClockUnavailable));
    var found = false;
    for (0..32) |_| {
        _ = try f.root(.{ .spawn = .{} });
        if (try scan.next(&f.engine, .{ .unix_ms = 101 })) |command| {
            try t.expectEqual(finite, command.expire);
            found = true;
            break;
        }
    }
    try t.expect(found);
    // A suggestion made at another sample is not authority: submit revalidates.
    try t.expectError(error.DeadlineNotReached, f.root(.{ .expire = finite }));
}

test "growing maintenance authenticates current realm control without publishing" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const pid = try f.root(.{ .spawn = .{} });
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.admin), .pid = pid } });
    const signed = try f.worker(1, .{ .checkpoint = {} });
    try t.expectError(error.Forbidden, f.engine.authorizeMaintenance(signed));
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.admin) } });
    const before = f.engine.head;
    try f.engine.authorizeMaintenance(signed);
    try t.expect(std.meta.eql(before, f.engine.head));
    _ = try f.root(.{ .revoke = 65536 });
    try t.expectError(error.Forbidden, f.engine.authorizeMaintenance(signed));
    try t.expectError(error.Forbidden, f.engine.authorizeMaintenance(try f.worker(1, .{ .terminate = pid })));
}

test "growing submit fences revocation at the publication boundary" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions } });
    const pid = try f.root(.{ .spawn = .{} });
    const signed = try f.worker(1, .{ .send = .{ .pid = pid, .value = .{} } });
    const revoke = try f.engine.prepare(try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = .{ .revoke = 65536 } }, f.root_key));
    f.journal.competing_append = .{ .operation = revoke.record };
    try t.expectError(error.Conflict, f.engine.submit(signed));
    try t.expectError(error.Forbidden, f.engine.submit(signed));
    try t.expectEqual(@as(u64, 0), (try f.engine.process(pid)).admitted);
    try t.expectEqual(@as(u64, 0), (try f.engine.principal(65536)).sequence);
    const recovered = try Engine.open(&f.journal, &f.pages, f.genesis);
    try t.expect(std.meta.eql(f.engine.head, recovered.head));
}
const Fixture = struct {
    journal: Journal = .{},
    pages: PageStore = .{},
    engine: Engine = undefined,
    root_key: core.Ed25519.KeyPair = undefined,
    worker_key: core.Ed25519.KeyPair = undefined,
    genesis: growing.Genesis = undefined,
    root_sequence: u64 = 1,
    fn init(self: *Fixture) !void {
        try self.initLimits(16, 64);
    }
    fn initLimits(self: *Fixture, required: u16, vertices: u16) !void {
        try self.initProfile(required, vertices, false);
    }
    fn initProfile(self: *Fixture, required: u16, vertices: u16, trim: bool) !void {
        self.root_key = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
        self.worker_key = try core.Ed25519.KeyPair.generateDeterministic(@splat(8));
        self.genesis = .{ .realm = 42, .root_key = self.root_key.public_key.toBytes(), .max_clock_error_ms = 5, .required_dependencies = required, .dependency_vertices = vertices, .allow_history_trim = trim };
        self.engine = try Engine.bootstrap(&self.journal, &self.pages, self.genesis);
    }
    fn initCapacity(self: *Fixture, ceiling: u64, reserve: u64) !void {
        self.root_key = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
        self.worker_key = try core.Ed25519.KeyPair.generateDeterministic(@splat(8));
        self.genesis = .{ .realm = 42, .root_key = self.root_key.public_key.toBytes(), .max_clock_error_ms = 5, .allow_history_trim = true, .admission_ceiling = ceiling, .control_reserve = reserve };
        self.engine = try Engine.bootstrap(&self.journal, &self.pages, self.genesis);
    }
    fn deinit(self: *Fixture) void {
        self.pages.deinit();
        self.journal.entries.deinit(t.allocator);
    }
    fn root(self: *Fixture, command: g.Command) !u64 {
        const result = try self.engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = self.root_sequence, .command = command }, self.root_key));
        self.root_sequence += 1;
        return result;
    }
    fn worker(self: *Fixture, sequence: u64, command: g.Command) !g.SignedRequest {
        return g.sign(.{ .realm = 42, .principal = 65536, .sequence = sequence, .command = command }, self.worker_key);
    }
    fn query(self: *Fixture, principal: u64, kind: @FieldType(g.Query, "kind")) !g.Response {
        const request: g.Query = .{ .realm = 42, .principal = principal, .kind = kind };
        const response = try self.engine.query(try g.signQuery(request, if (principal == 0) self.root_key else self.worker_key));
        try g.validateResponse(response, request);
        return response;
    }
    fn emit(self: *Fixture, pid: u64, outputs: [g.turn_outputs]?g.Output, payload: ?core.Value) !u64 {
        const input = try self.root(.{ .send = .{ .pid = pid, .value = .{} } });
        const process = try self.engine.process(pid);
        return self.root(.{ .turn = .{ .pid = pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .outputs = outputs, .effect = payload } });
    }
};

test "simulation: provider schedules fence old activations and retain accepted backlog" {
    var random = std.Random.DefaultPrng.init(t.random_seed);
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const pid = try f.root(.{ .spawn = .{} });
    _ = try f.root(.{ .send = .{ .pid = pid, .value = core.Value.integer(73) } });
    const rights = core.permission(.execute) | core.permission(.inspect);
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = rights, .pid = pid } });
    const epoch = (try f.engine.principal(65536)).epoch;
    for (0..8) |round| {
        const revision = round + 1;
        const generation = round * 2 + 1;
        const operation = try f.root(.{ .runtime_intent = .{ .pid = pid, .expected_revision = round, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3) } });
        const fresh = try core.Ed25519.KeyPair.generateDeterministic(@splat(@as(u8, @intCast(round + 40))));
        const activation: g.Command = .{ .activate = .{ .pid = pid, .revision = revision, .expected_generation = generation, .worker = 65536, .public_key = fresh.public_key.toBytes(), .worker_incarnation = @splat(@as(u8, @intCast(revision))) } };
        try t.expectEqual(@as(?u64, null), (try f.engine.process(pid)).owner);
        try t.expectError(error.ProviderNotReady, f.root(activation));
        const unknowns = random.random().uintLessThan(u8, 4);
        for (0..unknowns) |_| {
            _ = try f.root(.{ .runtime_observe = .{ .pid = pid, .revision = revision, .operation = operation, .incarnation = null, .outcome = .unknown } });
            f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
            try t.expectEqual(@as(?u64, null), (try f.engine.process(pid)).owner);
        }
        try t.expectError(error.StaleBinding, f.root(.{ .runtime_observe = .{ .pid = pid, .revision = revision, .operation = operation - 1, .incarnation = @splat(4), .outcome = .ready } }));
        _ = try f.root(.{ .runtime_observe = .{ .pid = pid, .revision = revision, .operation = operation, .incarnation = @splat(4), .outcome = .ready } });
        try t.expectEqual(@as(?u64, null), (try f.engine.process(pid)).owner);
        const signed = try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = activation }, f.root_key);
        const lost = random.random().boolean();
        if (lost) {
            f.journal.fail = .after;
            try t.expectError(error.LostAcknowledgement, f.engine.submit(signed));
            f.journal.fail = .none;
            f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
        }
        _ = try f.engine.submit(signed);
        f.root_sequence += 1;
        const process = try f.engine.process(pid);
        try t.expectEqual(generation + 1, process.generation);
        try t.expectEqual(@as(?u64, 65536), process.owner);
        try t.expectEqual(@as(u64, 1), process.admitted);
        try t.expectEqual(@as(u64, 0), process.consumed);
        try t.expectEqual(epoch, (try f.engine.principal(65536)).epoch);
        try t.expectError(error.AlreadyActivated, f.root(activation));
        if (t.environ.containsConstant("TRANSIT_SIMULATION_TRACE")) std.debug.print("SIMULATION {{\"domain\":\"runtime\",\"round\":{d},\"unknowns\":{d},\"lost_reply\":{},\"generation\":{d}}}\n", .{ round, unknowns, lost, process.generation });
    }
    _ = try f.root(.{ .terminate = pid });
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    try t.expectEqual(.terminated, (try f.engine.process(pid)).lifecycle);
    try t.expectEqual(@as(u64, 1), (try f.engine.process(pid)).cancelled);
    try t.expectError(error.RetiredProcess, f.root(.{ .runtime_intent = .{ .pid = pid, .expected_revision = 8, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3) } }));
}

test "growing authority retains wide principals and processes beyond legacy catalogs" {
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    for (0..20) |i| _ = try fixture.root(.{ .grant = .{ .subject = 65536 + i, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions } });
    var first: u64 = 0;
    for (0..70) |i| {
        const pid = try fixture.root(.{ .spawn = .{} });
        if (i == 0) first = pid;
    }
    const cut = fixture.engine.head.position;
    var after: ?u64 = null;
    var listed: usize = 0;
    while (true) {
        const response = try fixture.query(65536, .{ .processes = .{ .after = after, .position = cut } });
        for (response.body.processes.entries) |slot| if (slot) |process| {
            try t.expect(process.pid > (after orelse 0));
            listed += 1;
        };
        after = response.body.processes.next;
        if (after == null) break;
    }
    try t.expectEqual(@as(usize, 70), listed);
    _ = try fixture.root(.{ .own = .{ .pid = first, .expected_generation = 0, .worker = 65536 } });
    try t.expectError(error.QueryExpired, fixture.query(65536, .{ .processes = .{ .position = cut } }));
    const request = try fixture.worker(1, .{ .send = .{ .pid = first, .value = try core.Value.init("retained") } });
    const accepted = try fixture.engine.submit(request);
    _ = try fixture.engine.submit(try fixture.worker(2, .{ .send = .{ .pid = first, .value = .{} } }));
    const count = try fixture.journal.tail();
    try t.expectEqual(accepted, try fixture.engine.submit(request));
    try t.expectEqual(count, try fixture.journal.tail());
    const writes = fixture.pages.writes;
    var recovered = try Engine.open(&fixture.journal, &fixture.pages, fixture.genesis);
    try t.expectEqual(writes, fixture.pages.writes);
    try t.expectEqual(@as(?u64, 65536), (try recovered.process(first)).owner);
    try t.expectEqual(@as(u64, 2), (try recovered.process(first)).admitted);
    try t.expectEqual(@as(u64, 2), (try recovered.principal(65536)).sequence);
    var catalog = try recovered.state();
    const input = (try catalog.get(g.Input, try core.catalog.key(.mailbox, first, 1, ""))).?;
    try t.expectEqualStrings("retained", input.value.slice());
    try t.expectEqual(@as(u64, 65536), input.origin.external.principal);
    try t.expectEqual(accepted, try recovered.submit(request));
}

test "dependency admission cannot exceed its operational budget or strand existing borrowers" {
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.initLimits(1, 2);
    const base = try fixture.root(.{ .spawn = .{} });
    const middle = try fixture.root(.{ .spawn = .{} });
    const top = try fixture.root(.{ .spawn = .{} });
    const base_resource = try fixture.root(.{ .create_resource = .{ .writer = base } });
    const middle_resource = try fixture.root(.{ .create_resource = .{ .writer = middle } });
    for ([_]u64{ base_resource, middle_resource }) |id| _ = try fixture.root(.{ .grant_resource = .{ .resource = id, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    const name = try core.Value.init("required");
    _ = try fixture.root(.{ .associate = .{ .pid = top, .name = name, .resource = middle_resource } });
    const before = fixture.engine.head;
    try t.expectError(error.DependencyInUse, fixture.root(.{ .associate = .{ .pid = middle, .name = name, .resource = base_resource } }));
    try t.expect(std.meta.eql(before, fixture.engine.head));
    _ = try fixture.root(.{ .terminate = top });
    _ = try fixture.root(.{ .associate = .{ .pid = middle, .name = name, .resource = base_resource } });
    const other = try fixture.root(.{ .spawn = .{} });
    try t.expectError(error.DependencyBudgetExceeded, fixture.root(.{ .associate = .{ .pid = other, .name = name, .resource = middle_resource } }));
    _ = try fixture.root(.{ .associate = .{ .pid = other, .name = name, .resource = base_resource } });
    try t.expectError(error.DependencyBudgetExceeded, fixture.root(.{ .associate = .{ .pid = other, .name = try core.Value.init("second"), .resource = base_resource } }));
}

test "growing publication fences competing candidates and preserves uncertain receipts" {
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions } });
    const pid = try fixture.root(.{ .spawn = .{} });
    const signed = try fixture.worker(1, .{ .send = .{ .pid = pid, .value = .{} } });
    const prepared = try fixture.engine.prepare(signed);
    try t.expectEqual(@as(u64, 0), (try fixture.engine.process(pid)).admitted);
    _ = try fixture.root(.{ .revoke = 65536 });
    try t.expectError(error.Conflict, fixture.engine.commit(prepared));
    try t.expectError(error.Forbidden, fixture.engine.submit(signed));
    try t.expectEqual(@as(u64, 0), (try fixture.engine.process(pid)).admitted);
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions } });
    fixture.journal.fail = .before;
    try t.expectError(error.StorageUnavailable, fixture.engine.submit(signed));
    fixture.journal.fail = .none;
    try t.expectEqual(@as(u64, 0), (try fixture.engine.process(pid)).admitted);
    fixture.journal.fail = .after;
    try t.expectError(error.LostAcknowledgement, fixture.engine.submit(signed));
    fixture.journal.fail = .none;
    const tail = try fixture.journal.tail();
    try t.expectEqual(tail - 1, try fixture.engine.submit(signed));
    try t.expectEqual(tail, try fixture.journal.tail());
    try t.expectEqual(@as(u64, 1), (try fixture.engine.process(pid)).admitted);
    _ = try fixture.root(.{ .terminate = pid });
    try t.expectEqual(@as(u64, 1), (try fixture.engine.process(pid)).cancelled);
    try t.expectError(error.RetiredProcess, fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 65536 } }));
    _ = try fixture.root(.{ .revoke = 65536 });
    try t.expectError(error.Forbidden, fixture.engine.submit(signed));
}

test "growing recovery rejects a published position with an older materialization root" {
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    const old = fixture.engine.head.catalog;
    _ = try fixture.root(.{ .spawn = .{} });
    fixture.journal.entries.items[1].operation.next.catalog = old;
    try t.expectError(error.MissingReceipt, Engine.open(&fixture.journal, &fixture.pages, fixture.genesis));
    var legacy = fixture.genesis;
    legacy.version = 2;
    try t.expectError(error.InvalidGenesis, Engine.open(&fixture.journal, &fixture.pages, legacy));
}

test "growing finite work fails closed on clock uncertainty without disabling control" {
    const Clock = struct {
        sample: core.Time.Sample = .{ .unix_ms = 99, .error_ms = 2 },
        unavailable: bool = false,
        fn read(context: *anyopaque) anyerror!core.Time.Sample {
            const self: *@This() = @ptrCast(@alignCast(context));
            if (self.unavailable) return error.ClockUnavailable;
            return self.sample;
        }
    };
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    var clock: Clock = .{};
    fixture.engine.clock = .{ .context = &clock, .read = Clock.read };
    const finite: g.Command = .{ .spawn = .{ .work_before_ms = 100, .settle_before_ms = 200 } };
    try t.expectError(error.DeadlineUncertain, fixture.root(finite));
    try t.expectEqual(@as(u64, 1), try fixture.journal.tail());
    clock.sample = .{ .unix_ms = 90, .error_ms = 1 };
    const pid = try fixture.root(finite);
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions } });
    clock.sample = .{ .unix_ms = 89, .error_ms = 1 };
    try t.expectError(error.ClockRollback, fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 65536 } }));
    clock.sample = .{ .unix_ms = 100, .error_ms = 0 };
    try t.expectError(error.DeadlineExpired, fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 65536 } }));
    clock.unavailable = true;
    _ = try fixture.root(.{ .revoke = 65536 });
    _ = try fixture.root(.{ .terminate = pid });
    try t.expectEqual(.terminated, (try fixture.engine.process(pid)).lifecycle);
}

test "growing scoped retry preserves the failed input and fences revocation retirement and repeated failure" {
    const Clock = struct {
        now: u64 = 100,
        fn read(raw: *anyopaque) anyerror!core.Time.Sample {
            return .{ .unix_ms = @as(*@This(), @ptrCast(@alignCast(raw))).now };
        }
    };
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    var clock: Clock = .{};
    f.engine.clock = .{ .context = &clock, .read = Clock.read };
    const pid = try f.root(.{ .spawn = .{ .work_before_ms = 150, .settle_before_ms = 200 } });
    const other = try f.root(.{ .spawn = .{} });
    const resource = try f.root(.{ .create_resource = .{ .writer = pid, .deadline_ms = 140 } });
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    _ = try f.root(.{ .associate = .{ .pid = pid, .name = try core.Value.init("state"), .resource = resource } });
    _ = try f.root(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 0 } });
    const input = try f.root(.{ .send = .{ .pid = pid, .value = try core.Value.init("retained") } });
    const permit = try f.root(.{ .begin_turn = .{ .pid = pid, .generation = 2, .input = input } });
    _ = try f.root(.{ .turn = .{ .pid = pid, .generation = 2, .input = input, .expected_revision = 0, .permit = permit, .failed = true } });
    _ = try f.root(.{ .send = .{ .pid = pid, .value = try core.Value.init("queued behind failure") } });
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect) | core.permission(.admin), .pid = other } });
    const retry: g.Command = .{ .retry = .{ .pid = pid, .expected_generation = 3, .failure_input = input } };
    try t.expectError(error.Forbidden, f.engine.submit(try f.worker(1, retry)));
    var grant: g.Grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect), .pid = pid };
    _ = try f.root(.{ .grant = grant });
    const blocked = (try f.query(65536, .{ .process = pid })).body.process;
    try t.expectEqual(@as(?u64, input), blocked.process.failure);
    try t.expect(blocked.input == null and blocked.process.owner == null);
    try t.expectError(error.Forbidden, f.engine.submit(try f.worker(1, retry)));
    grant.permissions |= core.permission(.admin);
    _ = try f.root(.{ .grant = grant });
    try t.expect((try f.query(65536, .{ .capabilities = {} })).body.capabilities.scoped_retry);
    try t.expectError(error.InvalidFailure, f.engine.submit(try f.worker(1, .{ .retry = .{ .pid = pid, .expected_generation = 3, .failure_input = input + 1 } })));
    const signed = try f.worker(1, retry);
    const prepared = try f.engine.prepare(signed);
    _ = try f.root(.{ .revoke = 65536 });
    try t.expectError(error.Conflict, f.engine.commit(prepared));
    try t.expectError(error.Forbidden, f.engine.submit(signed));
    try t.expectEqual(@as(?u64, input), (try f.engine.process(pid)).failure);
    _ = try f.root(.{ .grant = grant });
    f.journal.fail = .after;
    try t.expectError(error.LostAcknowledgement, f.engine.submit(signed));
    f.journal.fail = .none;
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    f.engine.clock = .{ .context = &clock, .read = Clock.read };
    const receipt = try f.engine.submit(signed);
    try t.expectEqual(receipt, try f.engine.submit(signed));
    const ready = (try f.query(65536, .{ .process = pid })).body.process;
    try t.expectEqual(@as(u64, 4), ready.process.generation);
    try t.expectEqual(@as(u64, 0), ready.process.consumed);
    try t.expectEqual(@as(u64, 2), ready.process.admitted);
    try t.expectEqual(@as(u64, 0), ready.process.revision);
    try t.expect(ready.process.owner == null and ready.process.failure == null and ready.process.turn_permit == null);
    try t.expectEqual(input, ready.input.?.position);
    _ = try f.root(.{ .own = .{ .pid = pid, .expected_generation = 4, .worker = 0 } });
    const next_permit = try f.root(.{ .begin_turn = .{ .pid = pid, .generation = 5, .input = input } });
    _ = try f.root(.{ .turn = .{ .pid = pid, .generation = 5, .input = input, .expected_revision = 0, .permit = next_permit, .failed = true } });
    try t.expectError(error.StaleGeneration, f.engine.submit(try f.worker(2, retry)));
    const next_retry = try f.worker(2, .{ .retry = .{ .pid = pid, .expected_generation = 6, .failure_input = input } });
    clock.now = 145;
    try t.expectError(error.StateResourceExpired, f.engine.submit(next_retry));
    clock.now = 151;
    try t.expectError(error.DeadlineExpired, f.engine.submit(next_retry));
    clock.now = 100;
    _ = try f.root(.{ .terminate = pid });
    try t.expectError(error.RetiredProcess, f.engine.submit(next_retry));
    try t.expectEqual(@as(u64, 0), (try f.engine.process(pid)).consumed);
}

test "growing row count encoding overflow cannot publish partial rows progress or view closure" {
    const state = @import("growing_state.zig");
    const Clock = struct {
        fn read(_: *anyopaque) anyerror!core.Time.Sample {
            return .{ .unix_ms = 100 };
        }
    };
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    var context: u8 = 0;
    f.engine.clock = .{ .context = &context, .read = Clock.read };
    const pid = try f.root(.{ .spawn = .{} });
    const resource = try f.root(.{ .create_resource = .{ .writer = pid } });
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    _ = try f.root(.{ .associate = .{ .pid = pid, .name = try core.Value.init("state"), .resource = resource } });
    _ = try f.root(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 0 } });
    // Synthetic counter boundary, not a claim to have stored 2^53 rows. Install
    // metadata in the injected journal/page store before exercising real turns.
    var current = try f.engine.state();
    var data = try state.resource(&f.engine, resource);
    data.entries = core.protocol.max_counter - 1;
    try current.put(growing.address(.resource, resource), data);
    f.engine.head.catalog = current.snapshot;
    f.journal.entries.items[f.journal.entries.items.len - 1].operation.next.catalog = current.snapshot;
    const first = try core.Value.init("first");
    const second = try core.Value.init("second");
    for (0..2) |i| {
        const process = try f.engine.process(pid);
        const input = try f.root(.{ .send = .{ .pid = pid, .value = .{} } });
        const view = try f.root(.{ .open_view = .{ .pid = pid, .generation = 2, .input = input, .expected_revision = process.revision, .resource = resource, .revision = (try state.resource(&f.engine, resource)).revision, .deadline_ms = 200 } });
        var turn: g.Turn = .{ .pid = pid, .generation = 2, .input = input, .expected_revision = process.revision, .views = .{ view, null, null, null }, .write_view = view, .mutations = .{ .{ .key = if (i == 0) first else second, .value = .{} }, .{ .key = try core.Value.init("extra"), .value = .{} }, null, null } };
        const before = f.engine.head;
        try t.expectError(error.Overflow, f.root(.{ .turn = turn }));
        try t.expect(std.meta.eql(before, f.engine.head));
        try t.expectEqual(process.consumed, (try f.engine.process(pid)).consumed);
        try t.expectEqual(@as(?u64, null), (try state.view(&f.engine, view)).meta.closed_at);
        current = try f.engine.state();
        try t.expectEqual(@as(?g.Entry, null), try current.get(g.Entry, try core.catalog.key(.entry, resource, 0, second.slice())));
        // At the ceiling, an insertion followed by a deletion is one legal
        // replacement. The private intermediate count does not leak publicly.
        turn.mutations[1] = if (i == 0) null else .{ .key = first, .value = null };
        _ = try f.root(.{ .turn = turn });
        try t.expectEqual(core.protocol.max_counter, (try state.resource(&f.engine, resource)).entries);
    }
}

test "growing turns publish rows, progress, outputs and retained views as one root" {
    const Clock = struct {
        now: u64 = 100,
        fn read(context: *anyopaque) anyerror!core.Time.Sample {
            const self: *@This() = @ptrCast(@alignCast(context));
            return .{ .unix_ms = self.now, .error_ms = 1 };
        }
    };
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    var clock: Clock = .{};
    fixture.engine.clock = .{ .context = &clock, .read = Clock.read };
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions } });
    const pid = try fixture.root(.{ .spawn = .{} });
    const resource = try fixture.root(.{ .create_resource = .{ .writer = pid, .deadline_ms = 250 } });
    // Resource count grows independently of the handler's per-turn batch size.
    for (0..5) |_| _ = try fixture.root(.{ .create_resource = .{ .writer = pid } });
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    _ = try fixture.root(.{ .associate = .{ .pid = pid, .name = try core.Value.init("state"), .resource = resource } });
    const dependent = try fixture.root(.{ .spawn = .{} });
    const association = try fixture.root(.{ .associate = .{ .pid = dependent, .name = try core.Value.init("dependency"), .resource = resource } });
    const indirect_resource = try fixture.root(.{ .create_resource = .{ .writer = dependent } });
    _ = try fixture.root(.{ .grant_resource = .{ .resource = indirect_resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    const indirect = try fixture.root(.{ .spawn = .{} });
    _ = try fixture.root(.{ .associate = .{ .pid = indirect, .name = try core.Value.init("indirect"), .resource = indirect_resource } });
    _ = try fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 65536 } });
    var sequence: u64 = 1;
    var revision: u64 = 0;
    var previous = resource;
    var last: g.SignedRequest = undefined;
    var first_snapshot: ?core.catalog.Snapshot = null;
    for (0..36) |i| {
        const input = try fixture.root(.{ .send = .{ .pid = pid, .value = .{} } });
        const opened = try fixture.engine.submit(try fixture.worker(sequence, .{ .open_view = .{ .pid = pid, .generation = 2, .input = input, .expected_revision = revision, .resource = resource, .revision = previous, .deadline_ms = 200 } }));
        sequence += 1;
        const captured = try fixture.query(65536, .{ .entries = .{ .view = opened } });
        try t.expectEqual(previous, captured.body.entries.resource.revision);
        try t.expectEqual(@as(u64, i), captured.body.entries.resource.entries);
        var current = try fixture.engine.state();
        if (i == 0) first_snapshot = (try current.get(growing.StoredView, growing.address(.view, opened))).?.snapshot;
        var command: g.Turn = .{ .pid = pid, .generation = 2, .input = input, .expected_revision = revision, .views = .{ opened, null, null, null }, .write_view = opened, .mutations = .{ .{ .key = core.Value.integer(@intCast(i + 1)), .value = core.Value.integer(@intCast(i + 100)) }, null, null, null }, .outputs = .{ .{ .pid = pid, .value = core.Value.integer(@intCast(i)) }, null, null, null } };
        if (i == 35) {
            const before = fixture.engine.head;
            command.outputs[0].?.pid = 999999;
            try t.expectError(error.UnknownProcess, fixture.engine.prepare(try fixture.worker(sequence, .{ .turn = command })));
            try t.expect(std.meta.eql(before, fixture.engine.head));
            command.outputs[0].?.pid = pid;
        }
        last = try fixture.worker(sequence, .{ .turn = command });
        const prepared = try fixture.engine.prepare(last);
        try t.expectEqual(@as(u64, i), (try fixture.engine.process(pid)).consumed);
        current = try fixture.engine.state();
        const key = try core.catalog.key(.entry, resource, 0, core.Value.integer(@intCast(i + 1)).slice());
        try t.expectEqual(@as(?g.Entry, null), try current.get(g.Entry, key));
        revision = try fixture.engine.commit(prepared);
        try t.expectError(error.StateViewExpired, fixture.query(65536, .{ .entries = .{ .view = opened } }));
        previous = revision;
        sequence += 1;
        try t.expectEqual(@as(u64, i + 1), (try fixture.engine.process(pid)).consumed);
        current = try fixture.engine.state();
        try t.expectEqual(@as(u64, i + 1), (try current.get(g.Resource, growing.address(.resource, resource))).?.entries);
        try t.expect((try current.get(g.Entry, key)) != null);
    }
    var after: ?core.Value = null;
    var count: usize = 0;
    while (true) {
        const response = try fixture.query(65536, .{ .entries = .{ .resource = resource, .revision = revision, .after = after } });
        for (response.body.entries.page.entries) |slot| if (slot != null) {
            count += 1;
        };
        after = response.body.entries.page.next;
        if (after == null) break;
    }
    try t.expectEqual(@as(usize, 36), count);
    const direct = try fixture.query(65536, .{ .entries = .{ .resource = resource, .revision = revision, .key = core.Value.integer(36) } });
    try t.expectEqual(@as(i64, 135), try direct.body.entries.page.entries[0].?.value.asInteger());
    try t.expectError(error.StaleStateResource, fixture.query(65536, .{ .entries = .{ .resource = resource, .revision = resource } }));
    var batch_keys: [g.page_size]?core.Value = @splat(null);
    batch_keys[0] = core.Value.integer(36);
    batch_keys[1] = core.Value.integer(999);
    batch_keys[2] = core.Value.integer(1);
    const batch_query: g.Query = .{ .realm = 42, .principal = 65536, .kind = .{ .read_entries = .{ .resource = resource, .keys = batch_keys } } };
    const batched = try fixture.query(65536, batch_query.kind);
    try g.validateResponse(batched, batch_query);
    try t.expectEqual(revision, batched.body.read_entries.resource.revision);
    try t.expectEqualDeep(direct.body.entries.page.entries[0], batched.body.read_entries.entries[0]);
    try t.expect(batched.body.read_entries.entries[1] == null);
    try t.expect(batched.body.read_entries.entries[2].?.key.eql(core.Value.integer(1)));
    try t.expectError(error.StaleStateResource, fixture.query(65536, .{ .read_entries = .{ .resource = resource, .revision = resource, .keys = batch_keys } }));

    var snapshot = try core.catalog.Catalog(PageStore).open(&fixture.pages, first_snapshot.?);
    try t.expectEqual(@as(?g.Entry, null), try snapshot.get(g.Entry, try core.catalog.key(.entry, resource, 0, core.Value.integer(1).slice())));
    const recovered = try Engine.open(&fixture.journal, &fixture.pages, fixture.genesis);
    try t.expect(std.meta.eql(fixture.engine.head, recovered.head));
    try t.expectEqual(revision, try fixture.engine.submit(last));
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 0 } });
    try t.expectError(error.Forbidden, fixture.engine.submit(last));
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .entries = .{ .resource = resource, .revision = revision } }));
    const hidden = try fixture.query(65536, .{ .associations = .{ .pid = pid } });
    try t.expectEqual(@as(?g.Association, null), hidden.body.associations.entries[0]);
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    try t.expectEqual(revision, try fixture.engine.submit(last));
    try t.expectError(error.StateResourceInUse, fixture.root(.{ .retire_resource = resource }));
    clock.now = 300;
    try t.expectError(error.StateResourceExpired, fixture.query(65536, batch_query.kind));
    _ = try fixture.root(.{ .expire_resource = resource });
    try t.expectError(error.StateResourceExpired, fixture.root(.{ .send = .{ .pid = pid, .value = .{} } }));
    try t.expectError(error.StateResourceExpired, fixture.root(.{ .associate = .{ .pid = dependent, .name = try core.Value.init("dependency"), .expected_revision = association, .resource = null } }));
    try t.expectError(error.StateResourceExpired, fixture.root(.{ .own = .{ .pid = indirect, .expected_generation = 1, .worker = 65536 } }));
}

test "growing captured reads retain a version but never retain permission or ownership" {
    const Clock = struct {
        now: u64 = 100,
        error_ms: u32 = 0,
        fn read(context: *anyopaque) anyerror!core.Time.Sample {
            const self: *@This() = @ptrCast(@alignCast(context));
            return .{ .unix_ms = self.now, .error_ms = self.error_ms };
        }
    };
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    var clock: Clock = .{};
    fixture.engine.clock = .{ .context = &clock, .read = Clock.read };
    const writer = try fixture.root(.{ .spawn = .{} });
    const reader = try fixture.root(.{ .spawn = .{} });
    const resource = try fixture.root(.{ .create_resource = .{ .writer = writer } });
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions } });
    for ([_]u64{ 0, 65536 }) |principal| _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = principal, .permissions = core.protocol.State.all_permissions } });
    for ([_]u64{ writer, reader }) |pid| {
        _ = try fixture.root(.{ .associate = .{ .pid = pid, .name = try core.Value.init("table"), .resource = resource } });
        _ = try fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 65536 } });
    }
    const reader_input = try fixture.root(.{ .send = .{ .pid = reader, .value = .{} } });
    const reader_view = try fixture.engine.submit(try fixture.worker(1, .{ .open_view = .{ .pid = reader, .generation = 2, .input = reader_input, .expected_revision = 0, .resource = resource, .revision = resource, .deadline_ms = 200 } }));
    const writer_input = try fixture.root(.{ .send = .{ .pid = writer, .value = .{} } });
    const writer_view = try fixture.engine.submit(try fixture.worker(2, .{ .open_view = .{ .pid = writer, .generation = 2, .input = writer_input, .expected_revision = 0, .resource = resource, .revision = resource, .deadline_ms = 200 } }));
    const key = try core.Value.init("row");
    const revision = try fixture.engine.submit(try fixture.worker(3, .{ .turn = .{ .pid = writer, .generation = 2, .input = writer_input, .expected_revision = 0, .views = .{ writer_view, null, null, null }, .write_view = writer_view, .mutations = .{ .{ .key = key, .value = core.Value.integer(7) }, null, null, null } } }));
    const old = try fixture.query(65536, .{ .entries = .{ .view = reader_view, .key = key } });
    try t.expectEqual(resource, old.body.entries.resource.revision);
    try t.expectEqual(@as(?g.Entry, null), old.body.entries.page.entries[0]);
    const current = try fixture.query(65536, .{ .entries = .{ .resource = resource, .revision = revision, .key = key } });
    try t.expectEqual(@as(i64, 7), try current.body.entries.page.entries[0].?.value.asInteger());

    const many: @FieldType(g.Query, "kind") = .{ .read_entries = .{ .resource = resource, .revision = resource, .view = reader_view, .keys = .{ key, null, null, null, null, null, null, null } } };
    const old_many = try fixture.query(65536, many);
    try t.expectEqualDeep(old.body.entries.view, old_many.body.read_entries.view);
    try t.expectEqual(@as(?g.Entry, null), old_many.body.read_entries.entries[0]);
    var wrong = many;
    wrong.read_entries.resource += 1;
    try t.expectError(error.InvalidStateView, fixture.query(65536, wrong));
    // Current rights apply even though the old root and view are still retained.
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 0 } });
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .entries = .{ .view = reader_view } }));
    try t.expectError(error.Forbidden, fixture.query(65536, many));
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    clock.error_ms = 6;
    try t.expectError(error.UntrustedTime, fixture.query(65536, .{ .entries = .{ .view = reader_view } }));
    try t.expectError(error.UntrustedTime, fixture.query(65536, many));
    clock.error_ms = 1;
    clock.now = 199;
    try t.expectError(error.DeadlineUncertain, fixture.query(65536, .{ .entries = .{ .view = reader_view } }));
    try t.expectError(error.DeadlineUncertain, fixture.query(65536, many));
    clock.now = 200;
    clock.error_ms = 0;
    try t.expectError(error.StateViewExpired, fixture.query(65536, .{ .entries = .{ .view = reader_view } }));
    try t.expectError(error.StateViewExpired, fixture.query(65536, many));
    // A fresh view is fenced by ownership changes even with the same principal.
    const fresh = try fixture.engine.submit(try fixture.worker(4, .{ .open_view = .{ .pid = reader, .generation = 2, .input = reader_input, .expected_revision = 0, .resource = resource, .revision = revision, .deadline_ms = 300 } }));
    _ = try fixture.root(.{ .own = .{ .pid = reader, .expected_generation = 2, .worker = 65536 } });
    try t.expectError(error.InvalidStateView, fixture.query(65536, .{ .entries = .{ .view = fresh } }));
    var fenced = many;
    fenced.read_entries.view = fresh;
    fenced.read_entries.revision = revision;
    try t.expectError(error.InvalidStateView, fixture.query(65536, fenced));

    var forged = try g.signQuery(.{ .realm = 42, .principal = 65536, .kind = .{ .process = writer } }, fixture.worker_key);
    forged.query.kind = .{ .process = reader };
    try t.expectError(error.Unauthorized, fixture.engine.query(forged));
    // Narrowing principal scope invalidates all old resource grants by epoch.
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions, .pid = reader } });
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .process = writer }));
    const scoped = try fixture.query(65536, .{ .processes = .{} });
    try t.expectEqual(reader, scoped.body.processes.entries[0].?.pid);
    try t.expectEqual(@as(?g.Process, null), scoped.body.processes.entries[1]);
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .entries = .{ .resource = resource, .revision = revision } }));
    fixture.pages.missing = true;
    try t.expectError(error.PageUnavailable, fixture.query(0, .{ .process = reader }));
    fixture.pages.missing = false;
}

test "growing filtered discovery advances bounded pages without exposing hidden names" {
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    const pid = try fixture.root(.{ .spawn = .{} });
    const hidden = try fixture.root(.{ .create_resource = .{ .writer = pid } });
    const visible = try fixture.root(.{ .create_resource = .{ .writer = pid } });
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect) } });
    for ([_]u64{ hidden, visible }) |id| _ = try fixture.root(.{ .grant_resource = .{ .resource = id, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    _ = try fixture.root(.{ .grant_resource = .{ .resource = visible, .subject = 65536, .permissions = core.protocol.State.permission(.inspect) } });
    for (0..8) |i| _ = try fixture.root(.{ .associate = .{ .pid = pid, .name = core.Value.integer(@intCast(i)), .resource = hidden, .required = false } });
    const name = try core.Value.init("visible");
    const association = try fixture.root(.{ .associate = .{ .pid = pid, .name = name, .resource = visible, .required = false } });
    const first = try fixture.query(65536, .{ .associations = .{ .pid = pid } });
    for (first.body.associations.entries) |entry| try t.expectEqual(@as(?g.Association, null), entry);
    const after = first.body.associations.next.?;
    const second = try fixture.query(65536, .{ .associations = .{ .pid = pid, .after = after, .position = first.position } });
    try t.expectEqualStrings("visible", second.body.associations.entries[0].?.name.slice());
    try t.expectEqual(@as(?u64, null), second.body.associations.next);
    try t.expectError(error.InvalidRead, fixture.query(65536, .{ .associations = .{ .pid = pid, .after = after } }));
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .resource = hidden }));
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .entries = .{ .resource = visible, .revision = visible } }));
    const resources = try fixture.query(65536, .{ .resources = .{} });
    try t.expectEqual(visible, resources.body.resources.entries[0].?.id);
    try t.expectEqual(@as(?g.Resource, null), resources.body.resources.entries[1]);
    try t.expect((try fixture.query(65536, .{ .capabilities = {} })).body.capabilities.association_lookup);
    const point: @FieldType(g.Query, "kind") = .{ .association = .{ .pid = pid, .name = name } };
    try t.expectEqual(visible, (try fixture.query(65536, point)).body.association.?.resource);
    try t.expectEqual(@as(?g.Association, null), (try fixture.query(65536, .{ .association = .{ .pid = pid, .name = core.Value.integer(0) } })).body.association);
    try t.expectEqual(@as(?g.Association, null), (try fixture.query(65536, .{ .association = .{ .pid = pid, .name = try core.Value.init("absent") } })).body.association);
    try t.expectError(error.InvalidStateKey, fixture.query(65536, .{ .association = .{ .pid = pid, .name = .{} } }));
    _ = try fixture.root(.{ .send = .{ .pid = pid, .value = .{} } });
    try t.expectEqual(association, (try fixture.query(65536, point)).body.association.?.revision);
    fixture.journal.race_at = fixture.journal.tail_calls + 2;
    try t.expectError(error.Conflict, fixture.query(65536, point));
    fixture.journal.race_at = null;
    _ = try fixture.root(.{ .grant_resource = .{ .resource = visible, .subject = 65536, .permissions = 0 } });
    try t.expectEqual(@as(?g.Association, null), (try fixture.query(65536, point)).body.association);
    _ = try fixture.root(.{ .grant_resource = .{ .resource = visible, .subject = 65536, .permissions = core.protocol.State.permission(.inspect) } });
    try t.expectEqual(visible, (try fixture.query(65536, point)).body.association.?.resource);
    _ = try fixture.root(.{ .associate = .{ .pid = pid, .name = name, .expected_revision = association, .resource = null, .required = false } });
    try t.expectError(error.QueryExpired, fixture.query(65536, .{ .associations = .{ .pid = pid, .after = after, .position = first.position } }));
    const removed = try fixture.query(65536, .{ .associations = .{ .pid = pid } });
    for (removed.body.associations.entries) |entry| try t.expectEqual(@as(?g.Association, null), entry);
    try t.expectEqual(@as(?u64, null), removed.body.associations.next);
    try t.expectEqual(@as(?g.Association, null), (try fixture.query(65536, point)).body.association);
    const other = try fixture.root(.{ .spawn = .{} });
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect), .pid = other } });
    try t.expectError(error.Forbidden, fixture.query(65536, point));
}

test "resource read-access proof checks current read grant scope and lifetime without disclosing entries" {
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    const pid = try fixture.root(.{ .spawn = .{} });
    const resource = try fixture.root(.{ .create_resource = .{ .writer = pid } });
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect), .pid = pid } });
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 3 } });
    const signed = try g.signQuery(.{ .realm = 42, .principal = 65536, .kind = .{ .read_access = resource } }, fixture.worker_key);
    // Resource grants cannot broaden a PID's associated-resource scope.
    try t.expectError(error.Forbidden, fixture.engine.query(signed));
    _ = try fixture.root(.{ .associate = .{ .pid = pid, .name = try core.Value.init("data"), .resource = resource, .required = false } });
    const response = try fixture.engine.query(signed);
    try g.validateResponse(response, signed.query);
    try t.expectEqual(resource, response.body.read_access.id);
    try t.expect((try fixture.query(65536, .capabilities)).body.capabilities.resource_read_access);
    var foreign = signed;
    foreign.query.kind.read_access += 1;
    try t.expectError(error.Unauthorized, fixture.engine.query(foreign));
    // Metadata remains readable after revoking only entry-read permission.
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 1 } });
    _ = try fixture.query(65536, .{ .resource = resource });
    try t.expectError(error.Forbidden, fixture.engine.query(signed));
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 3 } });
    _ = try fixture.engine.query(signed);
    // Final authority-tail validation still prevents caching a raced grant.
    fixture.journal.race_at = fixture.journal.tail_calls + 2;
    try t.expectError(error.Conflict, fixture.engine.query(signed));
    fixture.journal.race_at = null;
    _ = try fixture.root(.{ .terminate = pid });
    try t.expectError(error.StateResourceExpired, fixture.engine.query(signed));
}

test "bounded multi-key reads preserve current grant scope lifetime and authority tail" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const pid = try f.root(.{ .spawn = .{} });
    const resource = try f.root(.{ .create_resource = .{ .writer = pid } });
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = 7 } });
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect), .pid = pid } });
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 3 } });
    var keys: [g.page_size]?core.Value = @splat(null);
    keys[0] = try core.Value.init("absent");
    const kind: @FieldType(g.Query, "kind") = .{ .read_entries = .{ .resource = resource, .keys = keys } };
    try t.expectError(error.Forbidden, f.query(65536, kind));
    _ = try f.root(.{ .associate = .{ .pid = pid, .name = try core.Value.init("state"), .resource = resource, .required = false } });
    const signed = try g.signQuery(.{ .realm = 42, .principal = 65536, .kind = kind }, f.worker_key);
    const first = try f.engine.query(signed);
    try g.validateResponse(first, signed.query);
    try t.expectEqual(resource, first.body.read_entries.resource.id);
    for (first.body.read_entries.entries) |entry| try t.expect(entry == null);
    try t.expect((try f.query(65536, .capabilities)).body.capabilities.resource_read_batch);
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 1 } });
    _ = try f.query(65536, .{ .resource = resource });
    try t.expectError(error.Forbidden, f.engine.query(signed));
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 3 } });
    f.journal.race_at = f.journal.tail_calls + 2;
    try t.expectError(error.Conflict, f.engine.query(signed));
    f.journal.race_at = null;
    var foreign = signed;
    foreign.query.kind.read_entries.keys[0] = try core.Value.init("tampered");
    try t.expectError(error.Unauthorized, f.engine.query(foreign));
    _ = try f.root(.{ .terminate = pid });
    try t.expectError(error.StateResourceExpired, f.engine.query(signed));
}

test "growing outboxes preserve routes, permission ordering and lost delivery receipts" {
    const work = @import("growing_work.zig");
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    const source = try fixture.root(.{ .spawn = .{} });
    const a = try fixture.root(.{ .spawn = .{} });
    const b = try fixture.root(.{ .spawn = .{} });
    _ = try fixture.root(.{ .own = .{ .pid = source, .expected_generation = 0, .worker = 0 } });
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.permission(.delivery) | core.permission(.send), .pid = a } });
    _ = try fixture.emit(source, .{ .{ .pid = a, .value = core.Value.integer(1) }, .{ .pid = a, .value = core.Value.integer(2) }, .{ .pid = b, .value = core.Value.integer(3) }, null }, null);
    try t.expectError(error.RouteBlocked, fixture.engine.submit(try fixture.worker(1, .{ .deliver = 2 })));
    try t.expectError(error.Forbidden, fixture.engine.submit(try fixture.worker(1, .{ .deliver = 3 })));
    _ = try fixture.root(.{ .deliver = 3 }); // Independent route makes progress.
    const signed = try fixture.worker(1, .{ .deliver = 1 });
    fixture.journal.fail = .after;
    try t.expectError(error.LostAcknowledgement, fixture.engine.submit(signed));
    fixture.journal.fail = .none;
    const count = try fixture.journal.tail();
    try t.expectEqual(count - 1, try fixture.engine.submit(signed));
    try t.expectEqual(count, try fixture.journal.tail());
    try t.expectEqual(@as(u64, 1), (try fixture.engine.process(a)).admitted);
    var state = try fixture.engine.state();
    const input = (try state.get(g.Input, try core.catalog.key(.mailbox, a, 1, ""))).?;
    try t.expectEqual(@as(u64, 1), input.origin.process.output);
    try t.expectEqual(source, input.origin.process.pid);

    const prepared = try fixture.engine.prepare(try fixture.worker(2, .{ .deliver = 2 }));
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.permission(.delivery), .pid = a } });
    try t.expectError(error.Conflict, fixture.engine.commit(prepared));
    _ = try fixture.engine.submit(try fixture.worker(2, .{ .deliver = 2 }));
    try t.expectEqual(.denied, (try work.output(&fixture.engine, 2)).phase);
    try t.expectEqual(@as(u64, 1), (try fixture.engine.process(a)).admitted);
    _ = try fixture.emit(source, .{ .{ .pid = a, .value = .{} }, null, null, null }, null);
    _ = try fixture.root(.{ .terminate = source });
    _ = try fixture.root(.{ .deliver = 4 });
    try t.expectEqual(.cancelled, (try work.output(&fixture.engine, 4)).phase);
    state = try fixture.engine.state();
    const pending = try state.scan(u64, .{ .namespace = .pending_output }, null);
    try t.expect(pending.records[0] == null);
    const recovered = try Engine.open(&fixture.journal, &fixture.pages, fixture.genesis);
    try t.expect(std.meta.eql(fixture.engine.head, recovered.head));
}

test "delivery staging failures preserve admission provenance and every pending index" {
    const work = @import("growing_work.zig");
    const c = core.catalog;
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const source = try f.root(.{ .spawn = .{} });
    const destination = try f.root(.{ .spawn = .{} });
    _ = try f.root(.{ .own = .{ .pid = source, .expected_generation = 0, .worker = 0 } });
    const turn = try f.emit(source, .{ .{ .pid = destination, .value = core.Value.integer(42) }, null, null, null }, null);
    const signed = try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = .{ .deliver = 1 } }, f.root_key);
    const before = f.engine.head;
    const writes = f.pages.writes;
    _ = try f.engine.prepare(signed);
    const stages = f.pages.writes - writes;
    try t.expect(stages > 0);
    std.debug.print("Delivery preparation: {d} page stages; {d} staging/acknowledgement fault cases.\n", .{ stages, stages * 2 });
    const pending = [_]core.pages.Key{
        growing.address(.pending_output, 1),
        try c.key(.pending_destination, destination, 1, ""),
        work.routeKey(source, destination, 1),
    };
    const pending_values = [_]u64{ destination, 1, 1 };
    const mailbox = try c.key(.mailbox, destination, 1, "");
    // Enumerate every staging boundary, including persisted pages whose
    // acknowledgements were lost. Unpublished candidates cannot resolve work.
    for (0..stages) |offset| {
        for ([_]bool{ false, true }) |lost| {
            if (lost) {
                f.pages.lose_at = f.pages.writes + offset;
                try t.expectError(error.StagingAcknowledgementLost, f.engine.prepare(signed));
                f.pages.lose_at = null;
            } else {
                f.pages.fail_at = f.pages.writes + offset;
                try t.expectError(error.StagingFailed, f.engine.prepare(signed));
                f.pages.fail_at = null;
            }
            try t.expectEqualDeep(before, f.engine.head);
            const after_fault_writes = f.pages.writes;
            var recovered = try Engine.open(&f.journal, &f.pages, f.genesis);
            try t.expectEqual(after_fault_writes, f.pages.writes);
            try t.expectEqualDeep(before, recovered.head);
            try t.expectEqual(@as(u64, 0), (try recovered.process(destination)).admitted);
            try t.expectEqual(.pending, (try work.output(&recovered, 1)).phase);
            var catalog = try recovered.state();
            try t.expectEqual(@as(?g.Input, null), try catalog.get(g.Input, mailbox));
            for (pending, pending_values) |key, value| try t.expectEqual(@as(?u64, value), try catalog.get(u64, key));
        }
    }
    const receipt = try f.engine.submit(signed);
    try t.expectEqual(before.position, receipt);
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    try t.expectEqual(receipt, try f.engine.submit(signed));
    try t.expectEqual(@as(u64, 1), (try f.engine.process(destination)).admitted);
    const output = try work.output(&f.engine, 1);
    try t.expectEqual(.delivered, output.phase);
    try t.expectEqual(@as(?u64, receipt), output.resolved_at);
    var catalog = try f.engine.state();
    const input = (try catalog.get(g.Input, mailbox)).?;
    try t.expectEqual(receipt, input.position);
    try t.expectEqual(@as(i64, 42), try input.value.asInteger());
    try t.expectEqualDeep(g.Origin{ .process = .{ .pid = source, .turn = turn, .output = 1 } }, input.origin);
    for (pending) |key| try t.expectEqual(@as(?u64, null), try catalog.get(u64, key));
}

test "growing effects retain bounded settlement across retirement and reject late results" {
    const work = @import("growing_work.zig");
    const Clock = struct {
        now: u64 = 10,
        fn read(context: *anyopaque) anyerror!core.Time.Sample {
            const self: *@This() = @ptrCast(@alignCast(context));
            return .{ .unix_ms = self.now };
        }
    };
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    var clock: Clock = .{};
    fixture.engine.clock = .{ .context = &clock, .read = Clock.read };
    const pid = try fixture.root(.{ .spawn = .{} });
    _ = try fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 0 } });
    const observed = try fixture.emit(pid, @splat(null), core.Value.integer(1));
    const unknown = try fixture.emit(pid, @splat(null), core.Value.integer(2));
    const pending = try fixture.emit(pid, @splat(null), core.Value.integer(3));
    const observed_attempt = try fixture.root(.{ .dispatch = .{ .pid = pid, .effect = observed, .reconcile_before_ms = 100, .max_observations = 2 } });
    const unknown_attempt = try fixture.root(.{ .dispatch = .{ .pid = pid, .effect = unknown, .reconcile_before_ms = 100, .max_observations = 2 } });
    _ = try fixture.root(.{ .observe = .{ .pid = pid, .effect = unknown, .attempt = unknown_attempt, .result = null } });
    const prepared = try fixture.engine.prepare(try g.sign(.{ .realm = 42, .principal = 0, .sequence = fixture.root_sequence, .command = .{ .dispatch = .{ .pid = pid, .effect = pending, .reconcile_before_ms = 100 } } }, fixture.root_key));
    _ = try fixture.root(.{ .terminate = pid });
    try t.expectError(error.Conflict, fixture.engine.commit(prepared));
    try t.expectError(error.RetiredProcess, fixture.root(.{ .dispatch = .{ .pid = pid, .effect = pending, .reconcile_before_ms = 100 } }));
    _ = try fixture.root(.{ .cancel_effect = .{ .pid = pid, .effect = pending } });
    try t.expectEqual(.cancelled, (try work.effect(&fixture.engine, pending)).phase);
    try t.expectEqual(.unattempted_cancel, (try work.effect(&fixture.engine, pending)).closure.?.reason);
    // An authorized external request may still return after caller retirement.
    const result = try g.sign(.{ .realm = 42, .principal = 0, .sequence = fixture.root_sequence, .command = .{ .observe = .{ .pid = pid, .effect = observed, .attempt = observed_attempt, .result = core.Value.integer(9) } } }, fixture.root_key);
    fixture.journal.fail = .after;
    try t.expectError(error.LostAcknowledgement, fixture.engine.submit(result));
    fixture.journal.fail = .none;
    const tail = try fixture.journal.tail();
    try t.expectEqual(tail - 1, try fixture.engine.submit(result));
    fixture.root_sequence += 1;
    try t.expectEqual(@as(u64, 3), (try fixture.engine.process(pid)).admitted);
    try t.expectEqual(.observed, (try work.effect(&fixture.engine, observed)).phase);
    const original_observation = try work.effect(&fixture.engine, observed);
    try t.expectEqual(.observed, original_observation.closure.?.reason);
    try t.expectEqual(original_observation.closed_at.?, original_observation.last_observation.?.input);
    try t.expectEqual(@as(u64, 0), original_observation.authorization_policy.?);
    fixture.engine = try Engine.open(&fixture.journal, &fixture.pages, fixture.genesis);
    fixture.engine.clock = .{ .context = &clock, .read = Clock.read };
    try t.expectEqual(@as(u16, 1), (try work.effect(&fixture.engine, unknown)).observations);
    clock.now = 100;
    const late: g.Command = .{ .observe = .{ .pid = pid, .effect = unknown, .attempt = unknown_attempt, .result = core.Value.integer(4) } };
    try t.expectError(error.DeadlineExpired, fixture.root(late));
    _ = try fixture.root(.{ .close_effect = .{ .pid = pid, .effect = unknown, .attempt = unknown_attempt, .reason = .deadline } });
    try t.expectError(error.ReconciliationClosed, fixture.root(late));
    try t.expectEqual(.closed_unknown, (try work.effect(&fixture.engine, unknown)).phase);
    const original_closure = try work.effect(&fixture.engine, unknown);
    try t.expectEqual(.deadline, original_closure.closure.?.reason);
    try t.expectEqual(@as(?u64, 100), original_closure.closure.?.clock_lower_ms);
    fixture.engine = try Engine.open(&fixture.journal, &fixture.pages, fixture.genesis);
    try t.expect(std.meta.eql(original_closure, try work.effect(&fixture.engine, unknown)));
    try t.expect(std.meta.eql(original_observation, try work.effect(&fixture.engine, observed)));
    const effects = try fixture.query(0, .{ .effects = .{ .pid = pid } });
    try t.expectEqual(observed, effects.body.effects.entries[0].?.id);
    try t.expectEqual(.observed, effects.body.effects.entries[0].?.phase);
    try t.expectEqual(.closed_unknown, effects.body.effects.entries[1].?.phase);
    try t.expectEqual(.cancelled, effects.body.effects.entries[2].?.phase);
    try t.expectEqual(tail - 1, try fixture.engine.submit(result));
}

test "growing finite settlement preserves its permit and closes permanently without a timer" {
    const Clock = struct {
        now: u64 = 10,
        fn read(context: *anyopaque) anyerror!core.Time.Sample {
            const self: *@This() = @ptrCast(@alignCast(context));
            return .{ .unix_ms = self.now };
        }
    };
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    var clock: Clock = .{};
    fixture.engine.clock = .{ .context = &clock, .read = Clock.read };
    const pid = try fixture.root(.{ .spawn = .{ .work_before_ms = 100, .settle_before_ms = 200 } });
    _ = try fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 0 } });
    const input = try fixture.root(.{ .send = .{ .pid = pid, .value = .{} } });
    const permit = try fixture.root(.{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } });
    clock.now = 110;
    try t.expectError(error.DeadlineExpired, fixture.root(.{ .send = .{ .pid = pid, .value = .{} } }));
    _ = try fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 0 } });
    const command: g.Turn = .{ .pid = pid, .generation = 2, .input = input, .expected_revision = 0, .permit = permit };
    var invalid = command;
    invalid.generation = 1;
    try t.expectError(error.StaleGeneration, fixture.root(.{ .turn = invalid }));
    invalid = command;
    invalid.effect = .{};
    try t.expectError(error.DeadlineExpired, fixture.root(.{ .turn = invalid }));
    const settled = try fixture.root(.{ .turn = command });
    try t.expectError(error.DeadlineNotReached, fixture.root(.{ .expire = pid }));
    clock.now = 200;
    _ = try fixture.root(.{ .expire = pid });
    const state = try fixture.engine.process(pid);
    try t.expectEqual(.expired, state.lifecycle);
    try t.expectEqual(settled, state.revision);
    try t.expectEqual(@as(u64, 1), state.consumed);
    try t.expect(state.owner == null and state.turn_permit == null);
    try t.expectError(error.RetiredProcess, fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 2, .worker = 0 } }));
}

test "growing root compaction requires explicit retention opt-in and keeps retry evidence" {
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    try t.expectError(error.RetentionNotEnabled, fixture.root(.{ .checkpoint = {} }));
    try t.expectEqual(@as(u64, 0), fixture.engine.head.history_floor);
    const capabilities = (try fixture.query(0, .{ .capabilities = {} })).body.capabilities;
    try t.expectEqual(.unlimited, capabilities.retained_history);
    var pages: PageStore = .{};
    defer pages.deinit();
    var journal: Journal = .{};
    defer journal.entries.deinit(t.allocator);
    var genesis = fixture.genesis;
    genesis.allow_history_trim = true;
    var engine = try Engine.bootstrap(&journal, &pages, genesis);
    const spawn = try g.sign(.{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .spawn = .{} } }, fixture.root_key);
    const pid = try engine.submit(spawn);
    const checkpoint = try g.sign(.{ .realm = 42, .principal = 0, .sequence = 2, .command = .{ .checkpoint = {} } }, fixture.root_key);
    const prepared = try engine.prepare(checkpoint);
    try t.expectEqual(@as(u64, 0), engine.head.history_floor);
    _ = try engine.commit(prepared);
    try t.expectEqual(engine.head.position - 1, engine.head.history_floor);
    var reopened = try Engine.open(&journal, &pages, genesis);
    try t.expectEqual(pid, try reopened.submit(spawn));
    try t.expectEqual(@as(u64, 3), try journal.tail());
    journal.entries.items[2].operation.next.history_floor = 3;
    try t.expectError(error.InvalidHistory, Engine.open(&journal, &pages, genesis));
}

const VersionFixture = struct {
    f: Fixture = .{},
    now: u64 = 100,
    pid: u64 = undefined,
    resource: u64 = undefined,
    fn clock(context: *anyopaque) anyerror!core.Time.Sample {
        const self: *@This() = @ptrCast(@alignCast(context));
        return .{ .unix_ms = self.now };
    }
    fn init(self: *@This(), finite: bool) !void {
        try self.f.initProfile(16, 64, true);
        self.f.engine.clock = .{ .context = self, .read = clock };
        self.pid = try self.f.root(.{ .spawn = .{} });
        self.resource = try self.f.root(.{ .create_resource = .{ .writer = self.pid, .owned = false, .deadline_ms = if (finite) 500 else null } });
        _ = try self.f.root(.{ .grant_resource = .{ .resource = self.resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
        _ = try self.f.root(.{ .associate = .{ .pid = self.pid, .name = try core.Value.init("data"), .resource = self.resource, .required = false } });
        _ = try self.f.root(.{ .own = .{ .pid = self.pid, .expected_generation = 1, .worker = 0 } });
    }
    fn proposal(self: *@This(), value: i64) !g.TurnWithVersions {
        const input = try self.f.root(.{ .send = .{ .pid = self.pid, .value = .{} } });
        const process = try self.f.engine.process(self.pid);
        const resource = try @import("growing_state.zig").resource(&self.f.engine, self.resource);
        const view = try self.f.root(.{ .open_view = .{ .pid = self.pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .resource = self.resource, .revision = resource.revision, .deadline_ms = self.now + 50 } });
        return .{ .turn = .{ .pid = self.pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .views = .{ view, null, null, null }, .write_view = view, .mutations = .{ .{ .key = try core.Value.init("row"), .value = core.Value.integer(value) }, null, null, null } }, .retain = .{ view, null, null, null } };
    }
    fn id(command: g.TurnWithVersions) g.ReadVersionId {
        return .{ .pid = command.turn.pid, .input = command.turn.input, .index = 0 };
    }
    fn query(self: *@This(), name: g.ReadVersionId, principal: u64, generation: u64) !g.Response {
        return self.f.query(principal, .{ .version_entries = .{ .id = name, .generation = generation, .key = try core.Value.init("row") } });
    }
};

test "leased snapshots retain one cut without durable updates and cannot survive restart" {
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(false);
    const f = &fixture.f;
    f.engine.snapshot_epoch = @splat(1);
    _ = try f.root(.{ .turn_with_versions = try fixture.proposal(10) });
    const before = f.engine.head.position;
    const query: @FieldType(g.Query, "kind") = .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(7) } };
    const snapshot = (try f.query(0, query)).body.open_snapshot;
    try t.expect(std.meta.eql(snapshot, (try f.query(0, query)).body.open_snapshot));
    try t.expectEqual(before, f.engine.head.position);
    _ = try f.root(.{ .turn_with_versions = try fixture.proposal(20) });
    const read: @FieldType(g.Query, "kind") = .{ .snapshot_entries = .{ .id = snapshot.id, .key = try core.Value.init("row") } };
    const result = (try f.query(0, read)).body.snapshot_entries;
    try t.expectEqual(@as(i64, 10), try result.page.entries[0].?.value.asInteger());
    const fresh = (try f.query(0, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(8) } })).body.open_snapshot;
    try t.expect(fresh.resource.revision > snapshot.resource.revision);
    try t.expectEqual(@as(i64, 20), try (try f.query(0, .{ .snapshot_entries = .{ .id = fresh.id, .key = try core.Value.init("row") } })).body.snapshot_entries.page.entries[0].?.value.asInteger());
    _ = try f.query(0, .{ .close_snapshot = snapshot.id });
    _ = try f.query(0, .{ .close_snapshot = snapshot.id });
    try t.expectError(error.QueryExpired, f.query(0, read));
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    f.engine.clock = .{ .context = &fixture, .read = VersionFixture.clock };
    f.engine.snapshot_epoch = @splat(2);
    try t.expectError(error.QueryExpired, f.query(0, .{ .snapshot_entries = .{ .id = fresh.id } }));
}

test "leased snapshots enforce current grants, principal epochs and source retirement" {
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(false);
    const f = &fixture.f;
    f.engine.snapshot_epoch = @splat(1);
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect) } });
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = core.protocol.State.permission(.inspect) | core.protocol.State.permission(.read) } });
    const snapshot = (try f.query(65536, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(7) } })).body.open_snapshot;
    const read: @FieldType(g.Query, "kind") = .{ .snapshot_entries = .{ .id = snapshot.id } };
    _ = try f.query(65536, read);
    try t.expectError(error.Forbidden, f.query(0, read));
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = 0 } });
    try t.expectError(error.Forbidden, f.query(65536, read));
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    _ = try f.query(65536, read);
    _ = try f.root(.{ .revoke = 65536 });
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect) } });
    try t.expectError(error.Forbidden, f.query(65536, read));
    const own = (try f.query(0, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(7) } })).body.open_snapshot;
    _ = try f.root(.{ .retire_resource = fixture.resource });
    try t.expectError(error.StateResourceExpired, f.query(0, .{ .snapshot_entries = .{ .id = own.id } }));
}

test "leased snapshot admission, renewal and hard expiry remain bounded" {
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(false);
    const f = &fixture.f;
    f.engine.snapshot_epoch = @splat(1);
    var first: g.Snapshot = undefined;
    for (0..g.snapshots_per_principal) |i| {
        const opened = (try f.query(0, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(@intCast(i)) } })).body.open_snapshot;
        if (i == 0) first = opened;
    }
    try t.expectError(error.StateViewCapacity, f.query(0, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(99) } }));
    fixture.now += 30_000;
    const renewed = (try f.query(0, .{ .snapshot_entries = .{ .id = first.id } })).body.snapshot_entries.snapshot;
    try t.expect(renewed.deadline_ms > first.deadline_ms);
    fixture.now = first.deadline_ms;
    _ = try f.query(0, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(99) } });
    while (fixture.now < first.hard_deadline_ms) : (fixture.now += 30_000) {
        const result = (try f.query(0, .{ .snapshot_entries = .{ .id = first.id } })).body.snapshot_entries;
        try t.expect(result.snapshot.deadline_ms <= first.hard_deadline_ms);
    }
    try t.expectError(error.QueryExpired, f.query(0, .{ .snapshot_entries = .{ .id = first.id } }));
    f.engine.clock = null;
    try t.expectError(error.ClockUnavailable, f.query(0, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(4) } }));
}

test "leased snapshot global admission refuses without evicting another principal" {
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(false);
    const f = &fixture.f;
    f.engine.snapshot_epoch = @splat(1);
    const owners = g.snapshot_capacity / g.snapshots_per_principal;
    for (0..owners + 1) |owner| {
        const subject = 65536 + owner;
        _ = try f.root(.{ .grant = .{ .subject = subject, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect) } });
        _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = subject, .permissions = core.protocol.State.permission(.inspect) | core.protocol.State.permission(.read) } });
    }
    const position = f.engine.head.position;
    var first: g.Snapshot = undefined;
    for (0..owners) |owner| for (0..g.snapshots_per_principal) |nonce| {
        const opened = (try f.query(65536 + owner, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(@intCast(nonce)) } })).body.open_snapshot;
        if (owner == 0 and nonce == 0) first = opened;
    };
    try t.expectError(error.StateViewCapacity, f.query(65536 + owners, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(0) } }));
    try t.expectError(error.Forbidden, f.query(65536 + owners, .{ .close_snapshot = first.id }));
    _ = try f.query(65536, .{ .snapshot_entries = .{ .id = first.id } });
    _ = try f.query(65536, .{ .close_snapshot = first.id });
    _ = try f.query(65536 + owners, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(0) } });
    try t.expectEqual(position, f.engine.head.position);
}

test "leased reads fail on rollback uncertainty and expiry during materialization" {
    const Clock = struct {
        sample: core.Time.Sample,
        advance: u64 = 0,
        fn read(raw: *anyopaque) anyerror!core.Time.Sample {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const now = self.sample;
            self.sample.unix_ms += self.advance;
            return now;
        }
    };
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(false);
    const f = &fixture.f;
    f.engine.snapshot_epoch = @splat(1);
    const snapshot = (try f.query(0, .{ .open_snapshot = .{ .resource = fixture.resource, .nonce = @splat(0) } })).body.open_snapshot;
    const position = f.engine.head.position;
    const read: @FieldType(g.Query, "kind") = .{ .snapshot_entries = .{ .id = snapshot.id } };
    var clock: Clock = .{ .sample = .{ .unix_ms = fixture.now - 1 } };
    f.engine.clock = .{ .context = &clock, .read = Clock.read };
    try t.expectError(error.ClockRollback, f.query(0, read));
    clock.sample = .{ .unix_ms = snapshot.deadline_ms - 5, .error_ms = 5 };
    try t.expectError(error.DeadlineUncertain, f.query(0, read));
    // The first clock check passes; materialization crosses the deadline.
    clock.sample = .{ .unix_ms = snapshot.deadline_ms - 4 };
    clock.advance = 10;
    try t.expectError(error.DeadlineExpired, f.query(0, read));
    clock.advance = 0;
    try t.expectError(error.QueryExpired, f.query(0, read));
    try t.expectEqual(position, f.engine.head.position);
}

test "growing retained versions atomically publish old roots and survive replacement and checkpoint recovery" {
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(false);
    const f = &fixture.f;
    const state = @import("growing_state.zig");
    var first: g.ReadVersionId = undefined;
    var last: g.ReadVersionId = undefined;
    for (0..10) |i| {
        const command = try fixture.proposal(@intCast(i));
        const id = VersionFixture.id(command);
        if (i == 0) first = id;
        last = id;
        const signed = try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = .{ .turn_with_versions = command } }, f.root_key);
        const before = f.engine.head;
        const prepared = try f.engine.prepare(signed);
        try t.expect(std.meta.eql(before, f.engine.head));
        try t.expectError(error.UnknownReadVersion, fixture.query(id, 0, 2));
        if (i == 0) {
            var invalid = command;
            invalid.release[0] = .{ .pid = fixture.pid, .input = 1, .index = 0 };
            try t.expectError(error.UnknownReadVersion, f.root(.{ .turn_with_versions = invalid }));
            try t.expect(std.meta.eql(before, f.engine.head));
            try t.expectEqual(@as(?u64, null), (try state.view(&f.engine, command.retain[0].?)).meta.closed_at);
            f.pages.fail_at = f.pages.writes;
            try t.expectError(error.StagingFailed, f.engine.prepare(signed));
            f.pages.fail_at = null;
            try t.expect(std.meta.eql(before, f.engine.head));
        }
        if (i == 9) {
            f.journal.fail = .after;
            try t.expectError(error.LostAcknowledgement, f.engine.commit(prepared));
            f.journal.fail = .none;
            f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
            f.engine.clock = .{ .context = &fixture, .read = VersionFixture.clock };
            try t.expectEqual(before.position, try f.engine.submit(signed));
        } else _ = try f.engine.commit(prepared);
        f.root_sequence += 1;
        const result = (try fixture.query(id, 0, 2)).body.version_entries;
        try t.expectEqual(before.position, result.version.created_at);
        if (i == 0) try t.expectEqual(@as(?g.Entry, null), result.page.entries[0]) else try t.expectEqual(@as(i64, @intCast(i - 1)), try result.page.entries[0].?.value.asInteger());
        try t.expectError(error.StateViewExpired, f.query(0, .{ .entries = .{ .view = command.retain[0] } }));
    }
    fixture.now = 300; // Source view deadlines have elapsed; version is independent.
    _ = try fixture.query(first, 0, 2);
    const checkpoint = try f.root(.{ .checkpoint = {} });
    // Trim the test journal prefix without touching its absolute coordinates.
    // Root-only recovery must not consult the removed operations.
    const old_entry = f.journal.entries.items[0];
    for (f.journal.entries.items[0..checkpoint]) |*entry| entry.* = old_entry;
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    f.engine.clock = .{ .context = &fixture, .read = VersionFixture.clock };
    try t.expectEqual(@as(i64, 8), try (try fixture.query(last, 0, 2)).body.version_entries.page.entries[0].?.value.asInteger());
    const first_page = try f.query(0, .{ .read_versions = .{ .pid = fixture.pid } });
    try t.expect(first_page.body.read_versions.next != null);
    const second = try f.query(0, .{ .read_versions = .{ .pid = fixture.pid, .after = first_page.body.read_versions.next, .position = first_page.position } });
    try t.expect(second.body.read_versions.entries[1] != null);
    try t.expectEqual(@as(?g.ReadVersionId, null), second.body.read_versions.next);

    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions, .pid = fixture.pid } });
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    _ = try f.root(.{ .own = .{ .pid = fixture.pid, .expected_generation = 2, .worker = 65536 } });
    try t.expectError(error.StaleGeneration, fixture.query(last, 0, 2));
    try t.expectError(error.StaleGeneration, fixture.query(last, 65536, 2));
    _ = try fixture.query(last, 65536, 3);
    try t.expectError(error.QueryExpired, f.query(0, .{ .read_versions = .{ .pid = fixture.pid, .after = first_page.body.read_versions.next, .position = first_page.position } }));
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = 0 } });
    try t.expectError(error.Forbidden, fixture.query(last, 65536, 3));
    const hidden = (try f.query(65536, .{ .read_versions = .{ .pid = fixture.pid } })).body.read_versions;
    try t.expectEqual(@as(?g.ReadVersion, null), hidden.entries[0]);
    try t.expect(hidden.next != null); // Filtered discovery still advances.
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    f.journal.race_at = f.journal.tail_calls + 2;
    try t.expectError(error.Conflict, fixture.query(last, 65536, 3));
    f.journal.race_at = null;
    const retained = try state.readVersion(&f.engine, last);
    const missing = f.pages.pages.fetchRemove(retained.snapshot.root.?).?;
    _ = try f.query(65536, .{ .read_version = last });
    try t.expectError(error.PageUnavailable, fixture.query(last, 65536, 3));
    try f.pages.pages.put(t.allocator, missing.key, missing.value);
    _ = try fixture.query(last, 65536, 3);
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect), .pid = fixture.pid } });
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    _ = try f.query(65536, .{ .read_version = last });
    try t.expectError(error.Forbidden, fixture.query(last, 65536, 3));
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions, .pid = fixture.pid } });
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    _ = try f.root(.{ .terminate = fixture.pid });
    try t.expectError(error.StaleGeneration, fixture.query(last, 65536, 3));
    // Metadata can explain retained evidence without promising executable reads.
    _ = try f.query(65536, .{ .read_version = last });
}

test "growing retained version release is terminal and cannot extend source lifetime" {
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(true);
    const f = &fixture.f;
    const one = try fixture.proposal(1);
    _ = try f.root(.{ .turn_with_versions = one });
    const first = VersionFixture.id(one);
    var two = try fixture.proposal(2);
    two.release[0] = first;
    const published = try f.root(.{ .turn_with_versions = two });
    try t.expectEqual(@as(?u64, published), (try f.query(0, .{ .read_version = first })).body.read_version.released_at);
    try t.expectError(error.ReadVersionReleased, fixture.query(first, 0, 2));
    const second = VersionFixture.id(two);
    _ = try fixture.query(second, 0, 2);
    var three = try fixture.proposal(3);
    three.release[0] = first;
    const before = f.engine.head;
    try t.expectError(error.ReadVersionReleased, f.root(.{ .turn_with_versions = three }));
    try t.expect(std.meta.eql(before, f.engine.head));
    try t.expectError(error.UnknownReadVersion, fixture.query(VersionFixture.id(three), 0, 2));
    fixture.now = 500;
    try t.expectError(error.StateResourceExpired, fixture.query(second, 0, 2));
    _ = try f.root(.{ .expire_resource = fixture.resource });
    try t.expectError(error.StateResourceExpired, fixture.query(second, 0, 2));
    _ = try f.query(0, .{ .read_version = second });
}

test "growing retained read dependencies fence later proposals and historical receipt access" {
    const state = @import("growing_state.zig");
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(true);
    const f = &fixture.f;
    const start = try fixture.proposal(1);
    _ = try f.root(.{ .turn_with_versions = start });
    const id = VersionFixture.id(start);
    const input = try f.root(.{ .send = .{ .pid = fixture.pid, .value = .{} } });
    var command: g.TurnWithVersions = .{ .turn = .{ .pid = fixture.pid, .generation = 2, .input = input, .expected_revision = (try f.engine.process(fixture.pid)).revision }, .reads = .{ id, null, null, null } };
    const signed = try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = .{ .turn_with_versions = command } }, f.root_key);
    const prepared = try f.engine.prepare(signed);
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 0, .permissions = 0 } });
    try t.expectError(error.Conflict, f.engine.commit(prepared));
    const before = f.engine.head;
    try t.expectError(error.Forbidden, f.root(.{ .turn_with_versions = command }));
    try t.expect(std.meta.eql(before, f.engine.head));
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    fixture.now = 500;
    try t.expectError(error.StateResourceExpired, f.root(.{ .turn_with_versions = command }));
    // Expired optional sources can still be released by their live owner. This
    // does not assert a read or require source privileges to dispose of a pin.
    command.reads = @splat(null);
    command.release[0] = id;
    _ = try f.root(.{ .turn_with_versions = command });
    try t.expect((try state.readVersion(&f.engine, id)).meta.released_at != null);

    // Another retained version demonstrates current receipt authorization after
    // declared reads have committed, separately from the expiry case above.
    var other: VersionFixture = .{};
    defer other.f.deinit();
    try other.init(false);
    const proposal = try other.proposal(1);
    _ = try other.f.root(.{ .turn_with_versions = proposal });
    const other_id = VersionFixture.id(proposal);
    const next_input = try other.f.root(.{ .send = .{ .pid = other.pid, .value = .{} } });
    const read_commit = try g.sign(.{ .realm = 42, .principal = 0, .sequence = other.f.root_sequence, .command = .{ .turn_with_versions = .{
        .turn = .{ .pid = other.pid, .generation = 2, .input = next_input, .expected_revision = (try other.f.engine.process(other.pid)).revision },
        .reads = .{ other_id, null, null, null },
        .release = .{ other_id, null, null, null },
    } } }, other.f.root_key);
    const receipt = try other.f.engine.submit(read_commit);
    other.f.root_sequence += 1;
    try t.expectEqual(receipt, try other.f.engine.submit(read_commit));
    _ = try other.f.root(.{ .grant_resource = .{ .resource = other.resource, .subject = 0, .permissions = 0 } });
    try t.expectError(error.Forbidden, other.f.engine.submit(read_commit));
    _ = try other.f.root(.{ .grant_resource = .{ .resource = other.resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    try t.expectEqual(receipt, try other.f.engine.submit(read_commit));
}

test "growing capacity backpressure blocks new admission but drains and closes existing work through an explicit reserve" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.initCapacity(20, 10);
    // The configured ceiling and reserve are observable from the start, not
    // only discoverable by hitting AdmissionClosed/ControlCapacity blind.
    {
        const observed = try f.query(0, .{ .capabilities = {} });
        try t.expectEqual(@as(?u64, 20), observed.body.capabilities.admission_ceiling);
        try t.expectEqual(@as(u64, 10), observed.body.capabilities.control_reserve);
    }
    const pid = try f.root(.{ .spawn = .{} });
    const doomed = try f.root(.{ .spawn = .{} });
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions } });
    _ = try f.root(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 0 } });
    // `Turn.input` names the mailbox entry's journal position, not its
    // per-process ordinal; capture what each send actually returns.
    var inputs: std.ArrayList(u64) = .empty;
    defer inputs.deinit(t.allocator);
    while (f.engine.head.position < 20) try inputs.append(t.allocator, try f.root(.{ .send = .{ .pid = pid, .value = core.Value.integer(1) } }));
    try t.expectEqual(@as(u64, 20), f.engine.head.position);
    // A caller reading capabilities plus the response's own position can
    // compute remaining ordinary (0) and control-reserve (10) headroom
    // without provoking AdmissionClosed/ControlCapacity to discover it.
    {
        const observed = try f.query(0, .{ .capabilities = {} });
        try t.expectEqual(@as(u64, 20), observed.position);
        try t.expectEqual(@as(u64, 0), observed.body.capabilities.admission_ceiling.? - observed.position);
        try t.expectEqual(@as(u64, 10), observed.body.capabilities.admission_ceiling.? + observed.body.capabilities.control_reserve - observed.position);
    }
    // New growth is refused before it is even acknowledged, not accepted and
    // silently truncated.
    try t.expectError(error.AdmissionClosed, f.root(.{ .send = .{ .pid = pid, .value = core.Value.integer(1) } }));
    try t.expectError(error.AdmissionClosed, f.root(.{ .spawn = .{} }));
    try t.expectError(error.AdmissionClosed, f.root(.{ .associate = .{ .pid = pid, .name = try core.Value.init("x"), .resource = null, .required = false } }));
    const process_before = try f.engine.process(pid);
    var next_input = process_before.consumed;
    // Existing backlog can still drain and close: a turn producing no new
    // output/effect is admissible, one that would create either is not.
    try t.expectError(error.AdmissionClosed, f.root(.{ .turn = .{ .pid = pid, .generation = process_before.generation, .input = inputs.items[next_input], .expected_revision = process_before.revision, .effect = core.Value.integer(1) } }));
    _ = try f.root(.{ .turn = .{ .pid = pid, .generation = process_before.generation, .input = inputs.items[next_input], .expected_revision = process_before.revision } });
    next_input += 1;
    // Ordinary control/wind-down work remains admissible past the ceiling:
    // reassigning ownership (of the doomed process, so pid's own owner and
    // later turns are unaffected), revocation, a failed turn plus its retry,
    // termination and an opted-in checkpoint. Extending a grant is new
    // capability, not wind-down, so revoking stays one-way here.
    _ = try f.root(.{ .own = .{ .pid = doomed, .expected_generation = 0, .worker = 65536 } });
    _ = try f.root(.{ .revoke = 65536 });
    const owned = try f.engine.process(pid);
    const failing_input = inputs.items[next_input];
    _ = try f.root(.{ .turn = .{ .pid = pid, .generation = owned.generation, .input = failing_input, .expected_revision = owned.revision, .failed = true } });
    _ = try f.root(.{ .retry = .{ .pid = pid, .expected_generation = owned.generation + 1, .failure_input = failing_input } });
    _ = try f.root(.{ .terminate = doomed });
    _ = try f.root(.{ .checkpoint = {} });
    try t.expectEqual(.terminated, (try f.engine.process(doomed)).lifecycle);
    try t.expect(f.engine.head.position < 20 + 10);
    // The reserve is finite too: pad it with more admissible control work
    // (an idempotent revoke costs one position without granting anything new)
    // until even that is refused.
    while (f.engine.head.position < 20 + 10) _ = try f.root(.{ .revoke = 65536 });
    try t.expectError(error.ControlCapacity, f.root(.{ .revoke = 65536 }));
    try t.expectError(error.ControlCapacity, f.root(.{ .checkpoint = {} }));
    // Reads remain available even once every write is refused; the exhausted
    // reserve is itself observable, not just inferable from a stream of errors.
    {
        const observed = try f.query(0, .{ .capabilities = {} });
        try t.expectEqual(@as(u64, 20 + 10), observed.position);
        try t.expectEqual(observed.body.capabilities.admission_ceiling.? + observed.body.capabilities.control_reserve, observed.position);
    }
    // A restarted engine recovers the same ceiling and reserve exhaustion; the
    // limit is durable protocol state, not a process-local counter.
    var recovered = try Engine.open(&f.journal, &f.pages, f.genesis);
    try t.expectError(error.ControlCapacity, recovered.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = .{ .revoke = 65536 } }, f.root_key)));
}

test "growing identity observes current grants and expires a prior inspection cut" {
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect) } });
    const identity = try fixture.query(65536, .{ .identity = {} });
    try t.expectEqual(core.permission(.inspect), identity.body.identity.permissions);
    _ = try fixture.query(65536, .{ .processes = .{ .position = identity.position } });
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.protocol.all_permissions } });
    try t.expectError(error.QueryExpired, fixture.query(65536, .{ .processes = .{ .position = identity.position } }));
    try t.expectEqual(core.protocol.all_permissions, (try fixture.query(65536, .{ .identity = {} })).body.identity.permissions);
    _ = try fixture.root(.{ .revoke = 65536 });
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .identity = {} }));
}

test "worker rotation preserves current policy and accepted work while fencing old keys" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const pid = try f.root(.{ .spawn = .{} });
    const resource = try f.root(.{ .create_resource = .{ .writer = pid } });
    const permissions = core.permission(.inspect) | core.permission(.execute);
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = permissions, .pid = pid } });
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = 7 } });
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 7 } });
    _ = try f.root(.{ .associate = .{ .pid = pid, .name = try core.Value.init("state"), .resource = resource } });
    _ = try f.root(.{ .own = .{ .pid = pid, .worker = 65536, .expected_generation = (try f.engine.process(pid)).generation } });
    const generation = (try f.engine.process(pid)).generation;
    const accepted = try f.root(.{ .send = .{ .pid = pid, .value = try core.Value.init("retained") } });
    const old = try g.signQuery(.{ .realm = 42, .principal = 65536, .kind = .{ .read_access = resource } }, f.worker_key);
    const next = try core.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const rotation: g.Command = .{ .rotate_worker = .{ .pid = pid, .worker = 65536, .expected_generation = generation, .expected_public_key = f.worker_key.public_key.toBytes(), .expected_permissions = permissions, .public_key = next.public_key.toBytes() } };
    const pending = try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = rotation }, f.root_key);
    const epoch = (try f.engine.principal(65536)).epoch;
    const receipt = try f.root(rotation);
    // A lost activation reply is recovered verbatim, even after reopening.
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    try t.expectEqual(receipt, try f.engine.submit(pending));
    try t.expectEqual(epoch, (try f.engine.principal(65536)).epoch);
    try t.expectEqual(generation + 1, (try f.engine.process(pid)).generation);
    try t.expectEqual(accepted, (try f.query(0, .{ .process = pid })).body.process.input.?.position);
    try t.expectError(error.Unauthorized, f.engine.query(old));
    f.worker_key = next;
    _ = try f.query(65536, .{ .read_access = resource });
    try t.expectError(error.StaleGeneration, f.root(rotation));

    // Revoking resource read permission survives a later compatible rotation.
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 1 } });
    const last = try core.Ed25519.KeyPair.generateDeterministic(@splat(10));
    var next_rotation = rotation;
    next_rotation.rotate_worker.expected_generation = generation + 1;
    next_rotation.rotate_worker.expected_public_key = next.public_key.toBytes();
    next_rotation.rotate_worker.public_key = last.public_key.toBytes();
    _ = try f.root(next_rotation);
    f.worker_key = last;
    try t.expectError(error.Forbidden, f.query(65536, .{ .read_access = resource }));
    // Revocation racing a prepared rotation wins the journal CAS; re-preparing
    // cannot silently restore the worker's execute permission.
    next_rotation.rotate_worker.expected_generation = generation + 2;
    next_rotation.rotate_worker.expected_public_key = last.public_key.toBytes();
    next_rotation.rotate_worker.public_key = next.public_key.toBytes();
    const prepared = try f.engine.prepare(try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = next_rotation }, f.root_key));
    _ = try f.root(.{ .revoke = 65536 });
    try t.expectError(error.Conflict, f.engine.commit(prepared));
    try t.expectError(error.Forbidden, f.root(next_rotation));
    try t.expectEqual(generation + 2, (try f.engine.process(pid)).generation);
}

test "principal creation recovers exact receipts without replacing existing grants" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const grant: g.Command = .{ .create_principal = .{ .subject = 99, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect) } };
    const pending = try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = grant }, f.root_key);
    const receipt = try f.root(grant);
    try t.expectEqual(receipt, try f.engine.submit(pending));
    var broaden = grant;
    broaden.create_principal.permissions |= core.permission(.admin);
    try t.expectError(error.InvalidGrant, f.root(broaden));
    _ = try f.root(.{ .revoke = 99 });
    try t.expectError(error.InvalidGrant, f.root(grant));
    try t.expectEqual(@as(u16, 0), (try f.engine.principal(99)).grant.permissions);
}

test "combined snapshot reads separate retained data from current metadata and release only after validation" {
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(false);
    const f = &fixture.f;
    f.engine.snapshot_epoch = @splat(1);
    _ = try f.root(.{ .turn_with_versions = try fixture.proposal(10) });
    const key = try core.Value.init("row");
    var keys: g.SnapshotRead.Keys = @splat(null);
    keys[0] = key;
    const current: [2]?g.SnapshotRead.Current = .{ .{ .resource = fixture.resource, .keys = keys }, null };
    const before = f.engine.head.position;
    const opened = (try f.query(0, .{ .snapshot_read = .{ .snapshot = .{ .open = .{ .resource = fixture.resource, .nonce = @splat(7) } }, .current = current, .points = keys, .range = .{} } })).body.snapshot_read;
    try t.expectEqual(before, f.engine.head.position);
    try t.expectEqual(@as(i64, 10), try opened.points[0].?.value.asInteger());
    try t.expectEqual(@as(i64, 10), try opened.entries[0].?.value.asInteger());
    try t.expect(opened.next == null);
    _ = try f.root(.{ .turn_with_versions = try fixture.proposal(20) });
    const next = (try f.query(0, .{ .snapshot_read = .{ .snapshot = .{ .existing = opened.snapshot.id }, .current = current, .points = keys } })).body.snapshot_read;
    try t.expectEqual(@as(i64, 10), try next.points[0].?.value.asInteger());
    try t.expectEqual(@as(i64, 20), try next.current[0].?.entries[0].?.value.asInteger());
    const finished = (try f.query(0, .{ .snapshot_read = .{ .snapshot = .{ .existing = opened.snapshot.id }, .current = current, .finish = true } })).body.snapshot_read;
    try t.expect(finished.finished);
    try t.expectError(error.QueryExpired, f.query(0, .{ .snapshot_read = .{ .snapshot = .{ .existing = opened.snapshot.id } } }));
    _ = try f.query(0, .{ .close_snapshot = opened.snapshot.id });
}

test "snapshot read final barrier accepts unrelated publication and observes current revocation" {
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(false);
    const f = &fixture.f;
    f.engine.snapshot_epoch = @splat(1);
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect) } });
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    const opened = (try f.query(65536, .{ .snapshot_read = .{ .snapshot = .{ .open = .{ .resource = fixture.resource, .nonce = @splat(7) } } } })).body.snapshot_read;
    const before = f.engine.head;
    _ = try f.root(.{ .spawn = .{} });
    f.journal.publish = f.journal.entries.pop().?;
    f.engine.head = before;
    f.journal.publish_at = f.journal.tail_calls + 2; // During final refresh, after data acquisition.
    const response = try f.query(65536, .{ .snapshot_read = .{ .snapshot = .{ .existing = opened.snapshot.id }, .range = .{} } });
    try t.expectEqual(before.position + 1, response.position);
    const current = f.engine.head;
    _ = try f.root(.{ .grant_resource = .{ .resource = fixture.resource, .subject = 65536, .permissions = 0 } });
    f.journal.publish = f.journal.entries.pop().?;
    f.engine.head = current;
    f.journal.publish_at = f.journal.tail_calls + 2;
    try t.expectError(error.Forbidden, f.query(65536, .{ .snapshot_read = .{ .snapshot = .{ .existing = opened.snapshot.id }, .finish = true } }));
    try t.expect(f.engine.snapshots[0] != null); // Denial did not perform a success-shaped release.
    _ = try f.query(65536, .{ .close_snapshot = opened.snapshot.id });
}

test "snapshot ranges obey byte budgets and preserve exact continuation" {
    var fixture: VersionFixture = .{};
    defer fixture.f.deinit();
    try fixture.init(false);
    const f = &fixture.f;
    f.engine.snapshot_epoch = @splat(1);
    for (0..17) |i| {
        var proposal = try fixture.proposal(0);
        var bytes: [8]u8 = undefined;
        proposal.turn.mutations[0].?.key = try core.Value.init(try std.fmt.bufPrint(&bytes, "r{d:0>3}", .{i}));
        proposal.turn.mutations[0].?.value = try core.Value.init(&@as([256]u8, @splat(@intCast(i))));
        _ = try f.root(.{ .turn_with_versions = proposal });
    }
    const range: g.SnapshotRead.Range = .{ .prefix = try core.Value.init("r"), .bytes = 512 };
    var result = (try f.query(0, .{ .snapshot_read = .{ .snapshot = .{ .open = .{ .resource = fixture.resource, .nonce = @splat(7) } }, .range = range } })).body.snapshot_read;
    var count: usize = 0;
    while (true) {
        try t.expect(result.entries[0] != null and result.entries[1] == null);
        try t.expectEqual(@as(u8, @intCast(count)), result.entries[0].?.value.data[0]);
        count += 1;
        const next = result.next orelse break;
        result = (try f.query(0, .{ .snapshot_read = .{ .snapshot = .{ .existing = result.snapshot.id }, .range = .{ .prefix = range.prefix, .after = next, .bytes = 512 } } })).body.snapshot_read;
    }
    try t.expectEqual(@as(usize, 17), count);
    fixture.now = result.snapshot.deadline_ms;
    try t.expectError(error.QueryExpired, f.query(0, .{ .snapshot_read = .{ .snapshot = .{ .existing = result.snapshot.id }, .finish = true } }));
}

test "native inspection pages preserve scoped history, backlog and current authorization" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.initProfile(16, 64, true);
    const pid = try f.root(.{ .spawn = .{} });
    const hidden = try f.root(.{ .spawn = .{} });
    for (0..g.page_size + 3) |n| _ = try f.root(.{ .send = .{ .pid = pid, .value = core.Value.integer(@intCast(n)) } });
    _ = try f.root(.{ .send = .{ .pid = hidden, .value = try core.Value.init("secret") } });
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.inspect), .pid = pid } });
    const first = (try f.query(65536, .{ .inspection = .{ .resource = .mailbox, .pid = pid } })).body.inspection;
    try t.expectEqual(@as(u16, g.page_size), first.scanned);
    try t.expect(!first.complete and first.next != null);
    const second = (try f.query(65536, .{ .inspection = .{ .resource = .mailbox, .pid = pid, .after = first.next.?, .cut = first.cut } })).body.inspection;
    try t.expect(second.complete);
    try t.expectEqual(@as(u16, 3), second.scanned);
    const catalog = (try f.query(65536, .{ .processes = .{} })).body.processes;
    try t.expectEqual(pid, catalog.entries[0].?.pid);
    try t.expectEqual(null, catalog.entries[1]);
    try t.expectError(error.Forbidden, f.query(65536, .{ .inspection = .{ .resource = .history, .pid = hidden } }));
    const history = (try f.query(65536, .{ .inspection = .{ .resource = .history, .pid = pid } })).body.inspection;
    try t.expectEqual(.spawn, history.events[0].?.kind);
    try t.expect(history.events[1].?.admitted);
    _ = try f.root(.{ .checkpoint = {} });
    try t.expectError(error.HistoryReclaimed, f.query(65536, .{ .inspection = .{ .resource = .history, .pid = pid, .cut = history.cut } }));
    const backlog = (try f.query(65536, .{ .inspection = .{ .resource = .mailbox, .pid = pid } })).body.inspection;
    try t.expect(backlog.events[0].?.admitted);
    try t.expectEqual(.pending, backlog.events[0].?.mailbox_status.?);
    try t.expectEqual(.prefix_reclaimed, backlog.history);
    f.journal.race_at = f.journal.tail_calls + 2;
    try t.expectError(error.Conflict, f.query(65536, .{ .inspection = .{ .resource = .process, .pid = pid } }));
    f.journal.race_at = null;
    _ = try f.root(.{ .revoke = 65536 });
    try t.expectError(error.Forbidden, f.query(65536, .{ .inspection = .{ .resource = .process, .pid = pid } }));
}

test "native standalone payloads require creation identity, retirement opt-in and deletion evidence" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const pid = try f.root(.{ .spawn = .{} });
    const payload = try f.root(.{ .declare_payload = .{ .pid = pid, .sha256 = @splat(9), .bytes = 32, .allow_delete = true } });
    const ref: core.protocol.PayloadRef = .{ .pid = pid, .payload = payload };
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.permission(.admin) | core.permission(.inspect), .pid = pid } });
    try t.expectError(error.Forbidden, f.engine.submit(try f.worker(1, .{ .payload_ready = ref })));
    _ = try f.root(.{ .payload_ready = ref });
    try t.expectError(error.PayloadInUse, f.root(.{ .retire_payload = ref }));
    try t.expectError(error.PayloadPhase, f.root(.{ .payload_deleted = ref }));
    const kept = try f.root(.{ .declare_payload = .{ .pid = pid, .sha256 = @splat(8), .bytes = 8 } });
    _ = try f.root(.{ .payload_ready = .{ .pid = pid, .payload = kept } });
    _ = try f.root(.{ .terminate = pid });
    try t.expectError(error.RetentionNotEnabled, f.root(.{ .retire_payload = .{ .pid = pid, .payload = kept } }));
    _ = try f.root(.{ .retire_payload = ref });
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    const retiring = (try f.query(65536, .{ .inspection = .{ .resource = .payloads, .pid = pid } })).body.inspection;
    try t.expectEqual(.retiring, retiring.payloads[0].?.phase);
    try t.expectEqual(null, retiring.payloads[0].?.deleted_at);
    _ = try f.root(.{ .payload_deleted = ref });
    const deleted = (try f.query(65536, .{ .inspection = .{ .resource = .payloads, .pid = pid } })).body.inspection;
    try t.expectEqual(.deleted, deleted.payloads[0].?.phase);
    try t.expect(deleted.payloads[0].?.deleted_at != null);
}

test "opted-in catalog collection preserves pending admissions, permanent identity and exact receipts" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const ordinary = try f.root(.{ .spawn = .{} });
    _ = try f.root(.{ .terminate = ordinary });
    try t.expectError(error.RetentionNotEnabled, f.root(.{ .collect = .{ .pid = ordinary, .id = ordinary, .kind = .process } }));
    const source = try f.root(.{ .spawn = .{ .allow_collection = true } });
    const destination = try f.root(.{ .spawn = .{} });
    _ = try f.root(.{ .own = .{ .pid = source, .worker = 0, .expected_generation = 0 } });
    const turn = try f.emit(source, .{ .{ .pid = destination, .value = try core.Value.init("accepted") }, null, null, null }, null);
    const output = (try f.query(0, .{ .outputs = .{} })).body.outputs.entries[0].?;
    try t.expectError(error.PendingWork, f.root(.{ .collect = .{ .pid = source, .id = output.id, .kind = .output } }));
    const delivered = try f.root(.{ .deliver = output.id });
    const signed = try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = .{ .collect = .{ .pid = source, .id = output.id, .kind = .output } } }, f.root_key);
    const receipt = try f.engine.submit(signed);
    f.root_sequence += 1;
    _ = try f.root(.{ .terminate = source });
    while (true) {
        _ = try f.root(.{ .collect = .{ .pid = source, .id = source, .kind = .process } });
        _ = f.engine.process(source) catch |err| {
            try t.expectEqual(error.RetiredProcess, err);
            break;
        };
    }
    try t.expectEqual(receipt, try f.engine.submit(signed));
    const input = (try f.query(0, .{ .process = destination })).body.process.input.?;
    try t.expectEqual(delivered, input.position);
    try t.expectEqualDeep(g.Origin{ .process = .{ .pid = source, .turn = turn, .output = output.id } }, input.origin);
    try t.expectEqualStrings("accepted", input.value.slice());
    try t.expectError(error.RetiredProcess, f.root(.{ .send = .{ .pid = source, .value = .{} } }));
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    try t.expectError(error.RetiredProcess, f.engine.process(source));
    try t.expectEqual(receipt, try f.engine.submit(signed));
}

test "resource collection is paged and cannot erase a live consumer association" {
    const Clock = struct {
        fn read(_: *anyopaque) anyerror!core.Time.Sample {
            return .{ .unix_ms = 10 };
        }
    };
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    var clock: u8 = 0;
    f.engine.clock = .{ .context = &clock, .read = Clock.read };
    const owner = try f.root(.{ .spawn = .{ .allow_collection = true } });
    const reader = try f.root(.{ .spawn = .{} });
    const resource = try f.root(.{ .create_resource = .{ .writer = owner, .owned = false, .history_ms = 0 } });
    _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = 7 } });
    _ = try f.root(.{ .associate = .{ .pid = reader, .name = try core.Value.init("optional"), .resource = resource, .required = false } });
    _ = try f.root(.{ .associate = .{ .pid = owner, .name = try core.Value.init("state"), .resource = resource } });
    _ = try f.root(.{ .own = .{ .pid = owner, .worker = 0, .expected_generation = 1 } });
    for (0..3) |batch| {
        const input = try f.root(.{ .send = .{ .pid = owner, .value = .{} } });
        const process = try f.engine.process(owner);
        const metadata = (try f.query(0, .{ .resource = resource })).body.resource;
        const view = try f.root(.{ .open_view = .{ .pid = owner, .generation = 2, .input = input, .expected_revision = process.revision, .resource = resource, .revision = metadata.revision, .deadline_ms = 100 } });
        var turn: g.Turn = .{ .pid = owner, .generation = 2, .input = input, .expected_revision = process.revision, .views = .{ view, null, null, null }, .write_view = view };
        for (&turn.mutations, 0..) |*mutation, index| mutation.* = .{ .key = try core.Value.init(&.{@intCast(batch * 4 + index)}), .value = core.Value.integer(@intCast(index)) };
        _ = try f.root(.{ .turn = turn });
    }
    _ = try f.root(.{ .terminate = owner });
    _ = try f.root(.{ .retire_resource = resource });
    const request: g.Collection = .{ .pid = owner, .id = resource, .kind = .resource };
    try t.expectError(error.PendingWork, f.root(.{ .collect = request }));
    _ = try f.root(.{ .reclaim_resource = resource }); // At most eight entries.
    try t.expectEqual(@as(u64, 4), (try f.query(0, .{ .resource = resource })).body.resource.entries);
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    _ = try f.root(.{ .reclaim_resource = resource }); // Four remaining entries.
    try t.expectEqual(@as(u64, 0), (try f.query(0, .{ .resource = resource })).body.resource.entries);
    try t.expectError(error.StateResourceInUse, f.root(.{ .collect = request }));
    _ = try f.root(.{ .terminate = reader });
    _ = try f.root(.{ .collect = request }); // Detach retired associations.
    try t.expectEqual(@as(?g.Association, null), (try f.query(0, .{ .association = .{ .pid = reader, .name = try core.Value.init("optional") } })).body.association);
    _ = try f.root(.{ .collect = request }); // Current grants.
    _ = try f.root(.{ .collect = request }); // Resource metadata and indexes.
    try t.expectError(error.Forbidden, f.query(0, .{ .resource = resource }));
    // Restarted maintenance rotates six families and resumes one bounded page
    // per family at a time; the schedule must still finish in finite work.
    var scan: growing.Maintenance = .{};
    for (0..256) |_| {
        if (try scan.next(&f.engine, null)) |command| _ = try f.root(command);
        _ = f.engine.process(owner) catch |err| {
            try t.expectEqual(error.RetiredProcess, err);
            break;
        };
    }
    try t.expectError(error.RetiredProcess, f.engine.process(owner));
}

test "resource history is unlimited by default and minimum age uses trusted uncertainty bounds" {
    const Clock = struct {
        now: core.Time.Sample = .{ .unix_ms = 100, .error_ms = 5 },
        fn read(raw: *anyopaque) anyerror!core.Time.Sample {
            return @as(*@This(), @ptrCast(@alignCast(raw))).now;
        }
    };
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const pid = try f.root(.{ .spawn = .{} });
    const unlimited = try f.root(.{ .create_resource = .{ .writer = pid } });
    try t.expectError(error.ClockUnavailable, f.root(.{ .create_resource = .{ .writer = pid, .history_ms = 20 } }));
    var clock: Clock = .{};
    f.engine.clock = .{ .context = &clock, .read = Clock.read };
    const finite = try f.root(.{ .create_resource = .{ .writer = pid, .history_ms = 20 } });
    _ = try f.root(.{ .retire_resource = unlimited });
    _ = try f.root(.{ .retire_resource = finite });
    try t.expectError(error.HistoryPinned, f.root(.{ .reclaim_resource = unlimited }));
    clock.now.unix_ms = 129; // lower=124, creation upper+age=125.
    try t.expectError(error.HistoryPinned, f.root(.{ .reclaim_resource = finite }));
    clock.now.unix_ms = 130;
    const signed = try g.sign(.{ .realm = 42, .principal = 0, .sequence = f.root_sequence, .command = .{ .reclaim_resource = finite } }, f.root_key);
    const receipt = try f.engine.submit(signed);
    f.engine = try Engine.open(&f.journal, &f.pages, f.genesis);
    // Recovered exact receipt requires neither a clock nor re-execution.
    try t.expectEqual(receipt, try f.engine.submit(signed));
    try t.expectEqual(.reclaimed, (try @import("growing_state.zig").resource(&f.engine, finite)).phase);
    try t.expectEqual(.retired, (try @import("growing_state.zig").resource(&f.engine, unlimited)).phase);
}

test "owned resource reads and required borrowers obey owner deadlines before maintenance" {
    for ([_]bool{ false, true }) |suspension| {
        var f: Fixture = .{};
        defer f.deinit();
        try f.init();
        var now: u64 = 100;
        const Clock = struct {
            fn read(context: *anyopaque) !core.Time.Sample {
                return .{ .unix_ms = @as(*u64, @ptrCast(@alignCast(context))).* };
            }
        };
        f.engine.clock = .{ .context = &now, .read = Clock.read };
        const owner = try f.root(.{ .spawn = if (suspension) .{} else .{ .work_before_ms = 200, .settle_before_ms = 300 } });
        const resource = try f.root(.{ .create_resource = .{ .writer = owner } });
        _ = try f.root(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = 7 } });
        const borrower = try f.root(.{ .spawn = .{} });
        _ = try f.root(.{ .associate = .{ .pid = borrower, .resource = resource, .name = try core.Value.init("required") } });
        if (suspension) _ = try f.root(.{ .@"suspend" = .{ .pid = owner, .expected_generation = 0, .resume_before_ms = 300 } });
        now = 250;
        _ = try f.query(0, .{ .read_access = resource });
        const before = f.engine.head.position;
        now = 300;
        try t.expectError(error.StateResourceExpired, f.query(0, .{ .read_access = resource }));
        try t.expectError(error.StateResourceExpired, f.root(.{ .send = .{ .pid = borrower, .value = .{} } }));
        try t.expectEqual(before, f.engine.head.position);
        try t.expectEqual(.running, (try f.engine.process(owner)).lifecycle);
        try t.expectEqual(.running, (try f.engine.process(borrower)).lifecycle);
        _ = try f.root(.{ .expire = borrower });
        try t.expectEqual(.expired, (try f.engine.process(borrower)).lifecycle);
    }
}

test "native effect observation budget closure keeps its original decision across retry and grant changes" {
    const work = @import("growing_work.zig");
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    const pid = try fixture.root(.{ .spawn = .{} });
    _ = try fixture.root(.{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 0 } });
    const id = try fixture.emit(pid, @splat(null), core.Value.integer(1));
    const grant = try fixture.root(.{ .grant = .{ .subject = 1, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.permission(.effect), .pid = pid } });
    const attempt = try fixture.engine.submit(try g.sign(.{ .realm = 42, .principal = 1, .sequence = 1, .command = .{ .dispatch = .{ .pid = pid, .effect = id, .max_observations = 1 } } }, fixture.worker_key));
    const request = try g.sign(.{ .realm = 42, .principal = 1, .sequence = 2, .command = .{ .observe = .{ .pid = pid, .effect = id, .attempt = attempt, .result = null } } }, fixture.worker_key);
    fixture.journal.fail = .after;
    try t.expectError(error.LostAcknowledgement, fixture.engine.submit(request));
    fixture.journal.fail = .none;
    const input = try fixture.engine.submit(request);
    const original = try work.effect(&fixture.engine, id);
    try t.expectEqual(.observation_budget, original.closure.?.reason);
    try t.expectEqual(input, original.closed_at.?);
    try t.expectEqual(@as(u16, 1), original.observations);
    try t.expectEqual(grant, original.authorization_policy.?);
    try t.expectEqual(grant, original.closure.?.policy_revision);
    _ = try fixture.root(.{ .revoke = 1 });
    try t.expectError(error.Forbidden, fixture.engine.submit(request));
    _ = try fixture.root(.{ .grant = .{ .subject = 1, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.permission(.effect), .pid = pid } });
    try t.expectEqual(input, try fixture.engine.submit(request));
    try t.expect(std.meta.eql(original, try work.effect(&fixture.engine, id)));
    fixture.engine = try Engine.open(&fixture.journal, &fixture.pages, fixture.genesis);
    try t.expect(std.meta.eql(original, try work.effect(&fixture.engine, id)));
    try t.expectError(error.ReconciliationClosed, fixture.root(.{ .close_effect = .{ .pid = pid, .effect = id, .attempt = attempt } }));
    try t.expectError(error.AttemptAlreadyAuthorized, fixture.root(.{ .dispatch = .{ .pid = pid, .effect = id } }));
    const diagnostic = try core.protocol.EffectDiagnostic.from(42, fixture.engine.head.position, original);
    try t.expectEqualStrings("effect.observation_limit", diagnostic.code.slice());
}

test "effect evidence and maximum opaque payloads fit the unchanged catalog record bound" {
    const maximum = core.protocol.max_counter;
    const bytes: [256]u8 = @splat(255);
    const effect: g.Effect = .{ .id = 2, .pid = 1, .payload = try core.Value.init(&bytes), .result = try core.Value.init(&bytes), .phase = .observed, .attempt = 3, .executor = maximum, .authorization_policy = 2, .closed_at = maximum - 1, .last_observation = .{ .input = maximum - 1, .policy_revision = maximum - 2 }, .closure = .{ .reason = .observed, .principal = maximum, .policy_revision = maximum - 2 }, .reconcile_before_ms = maximum, .max_observations = core.protocol.max_effect_observations, .observations = core.protocol.max_effect_observations };
    try g.validateEffect(effect, maximum);
    const catalog = @import("catalog.zig");
    _ = try catalog.putMutation(try catalog.key(.effect, effect.id, 0, ""), effect);
}
