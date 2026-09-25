const std = @import("std");
const t = std.testing;
const core = @import("root.zig");
const g = core.protocol.Growth;
const growing = @import("growing.zig");
const PageStore = @import("pages_test.zig").Store;
const Journal = struct {
    entries: std.ArrayList(growing.Entry) = .empty,
    fail: enum { none, before, after } = .none,
    pub fn tail(self: *Journal) !u64 {
        return self.entries.items.len;
    }
    pub fn read(self: *Journal, at: u64) !?growing.Entry {
        return if (at < self.entries.items.len) self.entries.items[@intCast(at)] else null;
    }
    pub fn append(self: *Journal, at: u64, entry: growing.Entry) !bool {
        if (at != self.entries.items.len) return false;
        if (self.fail == .before) return error.StorageUnavailable;
        try self.entries.append(t.allocator, entry);
        if (self.fail == .after) return error.LostAcknowledgement;
        return true;
    }
};
const Engine = growing.Engine(Journal, PageStore);
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
    _ = try fixture.root(.{ .own = .{ .pid = first, .expected_generation = 0, .worker = 65536 } });
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
        previous = revision;
        sequence += 1;
        try t.expectEqual(@as(u64, i + 1), (try fixture.engine.process(pid)).consumed);
        current = try fixture.engine.state();
        try t.expectEqual(@as(u64, i + 1), (try current.get(g.Resource, growing.address(.resource, resource))).?.entries);
        try t.expect((try current.get(g.Entry, key)) != null);
    }
    var snapshot = try core.catalog.Catalog(PageStore).open(&fixture.pages, first_snapshot.?);
    try t.expectEqual(@as(?g.Entry, null), try snapshot.get(g.Entry, try core.catalog.key(.entry, resource, 0, core.Value.integer(1).slice())));
    const recovered = try Engine.open(&fixture.journal, &fixture.pages, fixture.genesis);
    try t.expect(std.meta.eql(fixture.engine.head, recovered.head));
    try t.expectEqual(revision, try fixture.engine.submit(last));
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = 0 } });
    try t.expectError(error.Forbidden, fixture.engine.submit(last));
    _ = try fixture.root(.{ .grant_resource = .{ .resource = resource, .subject = 65536, .permissions = core.protocol.State.all_permissions } });
    try t.expectEqual(revision, try fixture.engine.submit(last));
    try t.expectError(error.StateResourceInUse, fixture.root(.{ .retire_resource = resource }));
    clock.now = 300;
    _ = try fixture.root(.{ .expire_resource = resource });
    try t.expectError(error.StateResourceExpired, fixture.root(.{ .send = .{ .pid = pid, .value = .{} } }));
    try t.expectError(error.StateResourceExpired, fixture.root(.{ .associate = .{ .pid = dependent, .name = try core.Value.init("dependency"), .expected_revision = association, .resource = null } }));
    try t.expectError(error.StateResourceExpired, fixture.root(.{ .own = .{ .pid = indirect, .expected_generation = 1, .worker = 65536 } }));
}
