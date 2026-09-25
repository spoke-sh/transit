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
        self.root_key = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
        self.worker_key = try core.Ed25519.KeyPair.generateDeterministic(@splat(8));
        self.genesis = .{ .realm = 42, .root_key = self.root_key.public_key.toBytes(), .max_clock_error_ms = 5, .required_dependencies = required, .dependency_vertices = vertices };
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
