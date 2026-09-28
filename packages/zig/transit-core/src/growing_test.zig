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
    pub fn tail(self: *Journal) !u64 {
        self.tail_calls += 1;
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
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.all_permissions } });
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

test "growing authority retains wide principals and processes beyond legacy catalogs" {
    var fixture: Fixture = .{};
    defer fixture.deinit();
    try fixture.init();
    for (0..20) |i| _ = try fixture.root(.{ .grant = .{ .subject = 65536 + i, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.all_permissions } });
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
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.all_permissions } });
    const pid = try fixture.root(.{ .spawn = .{} });
    const signed = try fixture.worker(1, .{ .send = .{ .pid = pid, .value = .{} } });
    const prepared = try fixture.engine.prepare(signed);
    try t.expectEqual(@as(u64, 0), (try fixture.engine.process(pid)).admitted);
    _ = try fixture.root(.{ .revoke = 65536 });
    try t.expectError(error.Conflict, fixture.engine.commit(prepared));
    try t.expectError(error.Forbidden, fixture.engine.submit(signed));
    try t.expectEqual(@as(u64, 0), (try fixture.engine.process(pid)).admitted);
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.all_permissions } });
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
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.all_permissions } });
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
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.all_permissions } });
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
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.all_permissions } });
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

    // Current rights apply even though the old root and view are still retained.
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 0 } });
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .entries = .{ .view = reader_view } }));
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    clock.error_ms = 6;
    try t.expectError(error.UntrustedTime, fixture.query(65536, .{ .entries = .{ .view = reader_view } }));
    clock.error_ms = 1;
    clock.now = 199;
    try t.expectError(error.DeadlineUncertain, fixture.query(65536, .{ .entries = .{ .view = reader_view } }));
    clock.now = 200;
    clock.error_ms = 0;
    try t.expectError(error.StateViewExpired, fixture.query(65536, .{ .entries = .{ .view = reader_view } }));
    // A fresh view is fenced by ownership changes even with the same principal.
    const fresh = try fixture.engine.submit(try fixture.worker(4, .{ .open_view = .{ .pid = reader, .generation = 2, .input = reader_input, .expected_revision = 0, .resource = resource, .revision = revision, .deadline_ms = 300 } }));
    _ = try fixture.root(.{ .own = .{ .pid = reader, .expected_generation = 2, .worker = 65536 } });
    try t.expectError(error.InvalidStateView, fixture.query(65536, .{ .entries = .{ .view = fresh } }));

    var forged = try g.signQuery(.{ .realm = 42, .principal = 65536, .kind = .{ .process = writer } }, fixture.worker_key);
    forged.query.kind = .{ .process = reader };
    try t.expectError(error.Unauthorized, fixture.engine.query(forged));
    // Narrowing principal scope invalidates all old resource grants by epoch.
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.all_permissions, .pid = reader } });
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .process = writer }));
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .processes = .{} }));
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
    fixture.engine = try Engine.open(&fixture.journal, &fixture.pages, fixture.genesis);
    fixture.engine.clock = .{ .context = &clock, .read = Clock.read };
    try t.expectEqual(@as(u16, 1), (try work.effect(&fixture.engine, unknown)).observations);
    clock.now = 100;
    const late: g.Command = .{ .observe = .{ .pid = pid, .effect = unknown, .attempt = unknown_attempt, .result = core.Value.integer(4) } };
    try t.expectError(error.DeadlineExpired, fixture.root(late));
    _ = try fixture.root(.{ .close_effect = .{ .pid = pid, .effect = unknown, .attempt = unknown_attempt, .reason = .deadline } });
    try t.expectError(error.ReconciliationClosed, fixture.root(late));
    try t.expectEqual(.closed_unknown, (try work.effect(&fixture.engine, unknown)).phase);
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

    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.all_permissions, .pid = fixture.pid } });
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
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.all_permissions, .pid = fixture.pid } });
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
    _ = try f.root(.{ .grant = .{ .subject = 65536, .public_key = f.worker_key.public_key.toBytes(), .permissions = core.all_permissions } });
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
    _ = try fixture.root(.{ .grant = .{ .subject = 65536, .public_key = fixture.worker_key.public_key.toBytes(), .permissions = core.all_permissions } });
    try t.expectError(error.QueryExpired, fixture.query(65536, .{ .processes = .{ .position = identity.position } }));
    try t.expectEqual(core.all_permissions, (try fixture.query(65536, .{ .identity = {} })).body.identity.permissions);
    _ = try fixture.root(.{ .revoke = 65536 });
    try t.expectError(error.Forbidden, fixture.query(65536, .{ .identity = {} }));
}
