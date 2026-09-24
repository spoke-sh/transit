const std = @import("std");
const t = std.testing;
const core = @import("root.zig");
const p = core.protocol;
const s = p.State;
const Memory = struct {
    entries: std.ArrayList(core.Entry) = .empty,
    fail_ack: bool = false,
    pub fn tail(self: *Memory) !u64 {
        return self.entries.items.len;
    }
    pub fn read(self: *Memory, at: u64) !?core.Entry {
        return if (at < self.entries.items.len) self.entries.items[@intCast(at)] else null;
    }
    pub fn append(self: *Memory, at: u64, entry: core.Entry) !bool {
        if (at != self.entries.items.len) return false;
        try self.entries.append(t.allocator, entry);
        if (self.fail_ack) {
            self.fail_ack = false;
            return error.LostAcknowledgement;
        }
        return true;
    }
};
const Engine = core.Engine(Memory);
const Fixture = struct {
    store: Memory = .{},
    engine: Engine,
    now: u64 = 1000,
    root: p.Ed25519.KeyPair,
    worker: p.Ed25519.KeyPair,
    pid: u64 = 0,
    resource: u64 = 0,
    fn init(policy: s.Create) !*Fixture {
        const self = try t.allocator.create(Fixture);
        errdefer t.allocator.destroy(self);
        const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
        self.* = .{ .engine = undefined, .root = root, .worker = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) };
        self.engine = try Engine.bootstrap(&self.store, .{ .realm = 42, .root_key = root.public_key.toBytes(), .retry_policy = .last_per_principal, .max_clock_error_ms = 0 });
        self.engine.clock = .{ .context = self, .read = clock };
        _ = try self.submit(0, .{ .grant = .{ .subject = 1, .public_key = self.worker.public_key.toBytes(), .permissions = p.permission(.execute) | p.permission(.inspect) | p.permission(.publish) | p.permission(.effect) } });
        self.pid = try self.submit(0, .{ .spawn = .{ .allow_trim = true } });
        var create = policy;
        create.writer = self.pid;
        self.resource = try self.submit(0, .{ .state = .{ .create = create } });
        _ = try self.submit(0, .{ .state = .{ .grant = .{ .resource = self.resource, .subject = 0, .permissions = s.all_permissions } } });
        _ = try self.submit(0, .{ .state = .{ .grant = .{ .resource = self.resource, .subject = 1, .permissions = s.all_permissions } } });
        _ = try self.submit(0, .{ .state = .{ .associate = .{ .pid = self.pid, .name = try p.Value.init("data"), .resource = self.resource } } });
        _ = try self.submit(0, .{ .own = .{ .pid = self.pid, .expected_generation = (try self.engine.state.process(self.pid)).generation, .worker = 1 } });
        return self;
    }
    fn deinit(self: *Fixture) void {
        self.store.entries.deinit(t.allocator);
        t.allocator.destroy(self);
    }
    fn clock(context: *anyopaque) !core.Time.Sample {
        const self: *Fixture = @ptrCast(@alignCast(context));
        return .{ .unix_ms = self.now, .error_ms = 0 };
    }
    fn request(self: *Fixture, principal: u8, command: p.Command) !p.SignedRequest {
        return p.sign(.{ .realm = 42, .principal = principal, .sequence = (try self.engine.state.principal(principal)).sequence + 1, .command = command }, if (principal == 0) self.root else self.worker);
    }
    fn submit(self: *Fixture, principal: u8, command: p.Command) !u64 {
        return self.engine.submit(try self.request(principal, command));
    }
    fn open(self: *Fixture) !u64 {
        if (try self.engine.nextInput(self.pid, self.engine.state.position) == null) _ = try self.submit(0, .{ .send = .{ .pid = self.pid, .value = try p.Value.init("input") } });
        const process = try self.engine.state.process(self.pid);
        const resource = try self.engine.state.resources.?.resource(self.resource);
        return self.submit(1, .{ .state = .{ .open = .{ .pid = self.pid, .generation = process.generation, .input = (try self.engine.nextInput(self.pid, self.engine.state.position)).?.position, .expected_revision = process.revision, .resource = self.resource, .revision = resource.meta.revision, .deadline_ms = @min(self.now + 1000, resource.meta.deadline_ms orelse p.max_counter) } } });
    }
    fn proposal(self: *Fixture, view: u64, value: ?p.Value) !p.SignedRequest {
        const process = try self.engine.state.process(self.pid);
        return self.request(1, .{ .state = .{ .turn = .{
            .turn = .{ .pid = self.pid, .generation = process.generation, .input = (try self.engine.nextInput(self.pid, self.engine.state.position)).?.position, .expected_revision = process.revision, .result = process.state },
            .views = .{ view, null, null, null },
            .write_view = view,
            .mutations = .{ .{ .key = try p.Value.init("key"), .value = value }, null, null, null },
        } } });
    }
    fn data(self: *Fixture) !*core.resources.Data {
        return self.engine.state.resources.?.resource(self.resource);
    }
};

test "KV publication and input outputs effects share one durable decision and retry" {
    const f = try Fixture.init(.{ .writer = 0, .history_ms = 0 });
    defer f.deinit();
    const view = try f.open();
    var command = (try f.proposal(view, try p.Value.init("committed"))).request.command;
    command.state.turn.turn.outputs[0] = .{ .pid = f.pid, .value = try p.Value.init("reply") };
    command.state.turn.turn.effect = try p.Value.init("effect");
    const signed = try f.request(1, command);
    const candidate = try f.engine.prepare(signed);
    try t.expect((try f.data()).entries[0] == null);
    try t.expectEqual(0, (try f.engine.state.process(f.pid)).consumed);
    try t.expectEqual(0, f.engine.state.output_count);
    f.store.fail_ack = true;
    try t.expectError(error.LostAcknowledgement, f.engine.commit(candidate));
    const receipt = try f.engine.submit(signed);
    try t.expectEqual(candidate.record.position, receipt);
    try t.expectEqual(receipt, try f.engine.submit(signed));
    try t.expectEqualStrings("committed", (try f.data()).entries[0].?.value.slice());
    try t.expectEqual(receipt, (try f.data()).meta.revision);
    try t.expectEqual(1, (try f.engine.state.process(f.pid)).consumed);
    try t.expectEqual(1, f.engine.state.output_count);
    try t.expectEqual(.pending, (try f.engine.state.effect(receipt)).phase);
    try t.expectError(error.StateViewExpired, f.engine.state.resources.?.view(view));
    const recovered = try Engine.open(&f.store, f.engine.genesis);
    try t.expect(std.meta.eql(f.engine.state, recovered.state));
}

test "rejected state turns publish no partial mutation and stale candidates lose CAS" {
    const f = try Fixture.init(.{ .writer = 0 });
    defer f.deinit();
    const view = try f.open();
    const signed = try f.proposal(view, try p.Value.init("new"));
    var malformed = signed.request;
    malformed.command.state.turn.turn.expected_revision += 1;
    try t.expectError(error.InvalidStateView, f.engine.submit(try p.sign(malformed, f.worker)));
    try t.expect((try f.data()).entries[0] == null);
    const candidate = try f.engine.prepare(signed);
    const before = (try f.engine.state.process(f.pid)).generation;
    _ = try f.submit(0, .{ .own = .{ .pid = f.pid, .expected_generation = before, .worker = 1 } });
    try t.expectError(error.Conflict, f.engine.commit(candidate));
    try t.expect((try f.data()).entries[0] == null);
    try t.expectError(error.StateViewExpired, f.engine.submit(signed));
}

test "resource grants are independent of PID rights and revoke before commit" {
    const f = try Fixture.init(.{ .writer = 0 });
    defer f.deinit();
    const view = try f.open();
    const signed = try f.proposal(view, try p.Value.init("denied"));
    _ = try f.submit(0, .{ .state = .{ .grant = .{ .resource = f.resource, .subject = 1, .permissions = s.permission(.inspect) | s.permission(.read) } } });
    try t.expectError(error.Forbidden, f.engine.submit(signed));
    try t.expect((try f.data()).entries[0] == null);
    _ = try f.submit(0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = p.permission(.execute) | p.permission(.inspect) } });
    try t.expectEqual(0, (try f.data()).grants[1]);
}

test "required state expiry fences activation before maintenance and permanently retires dependents" {
    const f = try Fixture.init(.{ .writer = 0, .deadline_ms = 2000, .history_ms = 0 });
    defer f.deinit();
    const view = try f.open();
    const signed = try f.proposal(view, try p.Value.init("late"));
    f.now = 2000;
    try t.expectError(error.StateResourceExpired, f.submit(0, .{ .own = .{ .pid = f.pid, .expected_generation = (try f.engine.state.process(f.pid)).generation, .worker = 1 } }));
    try t.expectError(error.StateViewExpired, f.engine.submit(signed));
    _ = try f.submit(0, .{ .state = .{ .expire = f.resource } });
    try t.expectEqual(.expired, (try f.engine.state.process(f.pid)).lifecycle);
    try t.expectEqual(1, (try f.engine.state.process(f.pid)).cancelled);
    try t.expectEqual(.retired, (try f.data()).meta.phase);
    _ = try f.submit(0, .{ .state = .{ .reclaim = f.resource } });
    const recovered = try Engine.open(&f.store, f.engine.genesis);
    try t.expect(std.meta.eql(f.engine.state, recovered.state));
}

test "view deadlines bound holding data while outages do not expire the process" {
    const f = try Fixture.init(.{ .writer = 0 });
    defer f.deinit();
    const view = try f.open();
    const signed = try f.proposal(view, try p.Value.init("value"));
    f.engine.clock = null;
    try t.expectError(error.ClockUnavailable, f.engine.submit(signed));
    try t.expectEqual(.running, (try f.engine.state.process(f.pid)).lifecycle);
    f.engine.clock = .{ .context = f, .read = Fixture.clock };
    f.now = 2000;
    try t.expectError(error.StateViewExpired, f.engine.submit(signed));
    _ = try f.submit(0, (try f.engine.state.nextMaintenance(try Fixture.clock(f))).?);
    _ = try f.open();
    try t.expectError(error.StateViewExpired, f.engine.state.resources.?.view(view));
}

test "independent state outlives writer while PID-owned state retires" {
    const f = try Fixture.init(.{ .writer = 0, .owned = false, .history_ms = 0 });
    defer f.deinit();
    const view = try f.open();
    _ = try f.engine.submit(try f.proposal(view, try p.Value.init("durable")));
    _ = try f.submit(0, .{ .terminate = f.pid });
    try t.expectEqual(.active, (try f.data()).meta.phase);
    try t.expectEqualStrings("durable", (try f.data()).entries[0].?.value.slice());
    _ = try f.submit(0, .{ .state = .{ .retire = f.resource } });
    _ = try f.submit(0, .{ .state = .{ .reclaim = f.resource } });
    try t.expect((try f.data()).entries[0] == null);
}

test "history trimming preserves old live values and deleting recreating keys advances revision" {
    const f = try Fixture.init(.{ .writer = 0, .history_ms = 5000 });
    defer f.deinit();
    var view = try f.open();
    const first = try f.engine.submit(try f.proposal(view, try p.Value.init("old")));
    f.now = 5999;
    try t.expectError(error.HistoryPinned, f.submit(0, .{ .checkpoint = {} }));
    f.now = 6000;
    _ = try f.submit(0, .{ .checkpoint = {} });
    const snapshot = try core.Checkpoint.create(t.allocator, f.engine.genesis, &f.engine.state);
    try snapshot.validate(t.allocator, f.engine.genesis);
    try t.expectEqualStrings("old", (try f.data()).entries[0].?.value.slice());
    try t.expectEqual(first, (try f.data()).entries[0].?.revision);
    view = try f.open();
    const removed = try f.engine.submit(try f.proposal(view, null));
    try t.expect((try f.data()).entries[0] == null);
    view = try f.open();
    const replaced = try f.engine.submit(try f.proposal(view, try p.Value.init("new")));
    try t.expect(replaced > removed);
    try t.expectEqual(replaced, (try f.data()).entries[0].?.revision);
}

test "inline-only checkpoint encoding remains byte compatible with omitted resource catalog" {
    const f = try Fixture.init(.{ .writer = 0 });
    defer f.deinit();
    var state = try core.State.init(f.engine.genesis);
    state.history_floor = 1;
    const snapshot = try core.Checkpoint.create(t.allocator, f.engine.genesis, &state);
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, snapshot, .{});
    defer t.allocator.free(bytes);
    try t.expect(std.mem.indexOf(u8, bytes, "\"resources\"") == null);
    var parsed = try std.json.parseFromSlice(core.Checkpoint, t.allocator, bytes, .{});
    defer parsed.deinit();
    try parsed.value.validate(t.allocator, f.engine.genesis);
}
