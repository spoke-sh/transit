const std = @import("std");
const t = std.testing;
const core = @import("root.zig");

const Memory = struct {
    entries: std.ArrayList(core.Entry) = .empty,
    fail_ack: bool = false,
    tail_calls: usize = 0,
    race_at: ?usize = null,
    reclaimed: bool = false,
    pub fn tail(self: *Memory) !u64 {
        self.tail_calls += 1;
        return self.entries.items.len + @as(u64, if (self.race_at == self.tail_calls) 1 else 0);
    }
    pub fn read(self: *Memory, at: u64) !?core.Entry {
        if (self.reclaimed) return error.HistoryReclaimed;
        return if (at < self.entries.items.len) self.entries.items[@intCast(at)] else null;
    }
    pub fn append(self: *Memory, expected: u64, entry: core.Entry) !bool {
        if (expected != self.entries.items.len) return false;
        try self.entries.append(t.allocator, entry);
        if (self.fail_ack) {
            self.fail_ack = false;
            return error.LostAcknowledgement;
        }
        return true;
    }
    fn deinit(self: *Memory) void {
        self.entries.deinit(t.allocator);
    }
};

const Engine = core.Engine(Memory);
const TestClock = struct {
    now: core.Time.Sample,
    fn read(context: *anyopaque) !core.Time.Sample {
        const self: *TestClock = @ptrCast(@alignCast(context));
        return self.now;
    }
    fn source(self: *TestClock) core.Time.Source {
        return .{ .context = self, .read = read };
    }
};
const Fixture = struct {
    store: Memory = .{},
    root: core.Ed25519.KeyPair,
    worker: core.Ed25519.KeyPair,
    genesis: core.Genesis,

    fn init() !Fixture {
        const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
        return .{ .root = root, .worker = try core.Ed25519.KeyPair.generateDeterministic(@splat(8)), .genesis = .{ .realm = 42, .root_key = root.public_key.toBytes() } };
    }
    fn request(self: *Fixture, engine: anytype, caller: u8, command: core.Command) !core.SignedRequest {
        var current = command;
        if (current == .turn) current.turn.expected_revision = (try engine.state.process(current.turn.pid)).revision;
        return core.sign(.{ .realm = 42, .principal = caller, .sequence = (try engine.state.principal(caller)).sequence + 1, .command = current }, if (caller == 0) self.root else self.worker);
    }
    fn submit(self: *Fixture, engine: anytype, caller: u8, command: core.Command) !u64 {
        var current = command;
        if (current == .turn) current.turn.expected_revision = (try engine.state.process(current.turn.pid)).revision;
        return engine.submit(try self.request(engine, caller, current));
    }
    fn setup(self: *Fixture, engine: anytype) !u64 {
        _ = try self.submit(engine, 0, .{ .grant = .{ .subject = 1, .public_key = self.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.inspect) } });
        const pid = try self.submit(engine, 0, .{ .spawn = .{} });
        _ = try self.submit(engine, 0, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 1 } });
        return pid;
    }
};

test "shared valid and invalid sequence fixture survives recovery after every step" {
    const Trace = struct {
        version: u32,
        realm: u64,
        seed_hex: []const u8,
        steps: []const struct {
            realm: u64 = 42,
            sequence: u64,
            command: core.Command,
            receipt: ?u64 = null,
            @"error": ?[]const u8 = null,
        },
    };
    var trace = try std.json.parseFromSlice(Trace, t.allocator, core.protocol.fixtures.sequences, .{});
    defer trace.deinit();
    try t.expectEqual(@as(u32, 2), trace.value.version);
    var seed: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&seed, trace.value.seed_hex);
    const key = try core.Ed25519.KeyPair.generateDeterministic(seed);
    const genesis: core.Genesis = .{ .realm = trace.value.realm, .root_key = key.public_key.toBytes() };
    const TraceEngine = core.Engine(Memory);
    var store: Memory = .{};
    defer store.deinit();
    var engine = try TraceEngine.bootstrap(&store, genesis);
    for (trace.value.steps) |step| {
        const before = store.entries.items.len;
        const signed = try core.sign(.{ .realm = step.realm, .principal = 0, .sequence = step.sequence, .command = step.command }, key);
        if (engine.submit(signed)) |receipt| {
            try t.expect(step.@"error" == null);
            try t.expectEqual(step.receipt.?, receipt);
        } else |err| {
            try t.expect(step.receipt == null);
            try t.expectEqualStrings(step.@"error" orelse return err, @errorName(err));
            try t.expectEqual(before, store.entries.items.len);
        }
        const recovered = try TraceEngine.open(&store, genesis);
        try t.expect(std.meta.eql(engine.state, recovered.state));
        engine = recovered;
    }
    try t.expectEqual(@as(u64, 16), engine.state.position);
    const first = try engine.state.process(1);
    try t.expectEqual(.terminated, first.lifecycle);
    try t.expectEqual(@as(i64, 9), try first.state.asInteger());
    try t.expectEqual(@as(u64, 1), first.admitted);
    try t.expectEqual(.closed_unknown, (try engine.state.effect(4)).phase);
    const replacement = try engine.state.process(9);
    try t.expectEqual(.terminated, replacement.lifecycle);
    try t.expectEqual(@as(u64, 1), replacement.consumed);
    try t.expectEqual(@as(u64, 1), replacement.cancelled);
    try t.expectEqual(@as(u64, 12), replacement.failure.?.input);
}

test "checkpoint administration requires a current realm-wide grant" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.retry_policy = .last_per_principal;
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .allow_trim = true } });
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.admin), .pid = pid } });
    try t.expectError(error.Forbidden, f.submit(&e, 1, .{ .checkpoint = {} }));
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.admin) } });
    _ = try f.submit(&e, 1, .{ .checkpoint = {} });
    _ = try f.submit(&e, 0, .{ .revoke = 1 });
    try t.expectError(error.Forbidden, f.submit(&e, 1, .{ .checkpoint = {} }));
}

test "capacity backpressure preserves accepted work and bounded control across trim" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.admission_ceiling = 8;
    f.genesis.retry_policy = .last_per_principal;
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .allow_trim = true } });
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute), .pid = pid } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 1 } });
    for (0..4) |_| _ = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } });
    try t.expectError(error.AdmissionClosed, f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(100) } }));
    try t.expectError(error.AdmissionClosed, f.submit(&e, 0, .{ .spawn = .{} }));
    try t.expectEqual(@as(u64, 4), (try e.state.process(pid)).admitted);
    try t.expectEqual(@as(u64, 0), (try e.state.process(pid)).cancelled);
    // Existing work can drain; starting new effects or outputs cannot consume
    // the control reserve or recursively create an unbounded backlog.
    try t.expectError(error.AdmissionClosed, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = 4, .result = core.Value.integer(1), .effect = core.Value.integer(1) } }));
    for (4..8) |input| {
        _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(@intCast(input - 3)) } });
    }
    _ = try f.submit(&e, 0, .{ .revoke = 1 });
    try t.expectError(error.ControlAlreadyRecorded, f.submit(&e, 0, .{ .revoke = 1 }));
    _ = try f.submit(&e, 0, .{ .checkpoint = {} });
    try t.expectEqual(.running, (try e.state.process(pid)).lifecycle);
    try t.expectEqual(@as(i64, 4), try (try e.state.process(pid)).state.asInteger());
    var recovered = try Engine.open(&f.store, f.genesis);
    try t.expectError(error.AdmissionClosed, f.submit(&recovered, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } }));
    try t.expectError(error.ControlAlreadyRecorded, f.submit(&recovered, 0, .{ .checkpoint = {} }));
    // Explicit application/operator termination remains available. Capacity
    // itself never chooses to retire this unlimited-lifetime process.
    _ = try f.submit(&recovered, 0, .{ .terminate = pid });
    try t.expect(recovered.state.position < 8 + core.controlRecordBudget(8));
}

test "payload deletion requires publication, owner retirement, opt-in and current grants" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.submit(&e, 0, .{ .spawn = .{} });
    const retained = try f.submit(&e, 0, .{ .declare_payload = .{ .pid = pid, .sha256 = @splat(1), .bytes = 1 } });
    const removed = try f.submit(&e, 0, .{ .declare_payload = .{ .pid = pid, .sha256 = @splat(2), .bytes = 1, .allow_delete = true } });
    const ref: core.PayloadRef = .{ .pid = pid, .payload = removed };
    try t.expectError(error.PayloadInUse, f.submit(&e, 0, .{ .retire_payload = ref }));
    try t.expectError(error.PayloadPhase, f.submit(&e, 0, .{ .payload_deleted = ref }));
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.admin), .pid = pid } });
    try t.expectError(error.Forbidden, f.submit(&e, 1, .{ .payload_ready = ref }));
    _ = try f.submit(&e, 0, .{ .terminate = pid });
    try t.expectError(error.PayloadPhase, f.submit(&e, 0, .{ .retire_payload = ref }));
    _ = try f.submit(&e, 0, .{ .payload_ready = ref });
    try t.expectError(error.InvalidPayload, f.submit(&e, 0, .{ .retire_payload = .{ .pid = 999, .payload = removed } }));
    try t.expectError(error.RetentionNotEnabled, f.submit(&e, 0, .{ .retire_payload = .{ .pid = pid, .payload = retained } }));
    const pending = try e.prepare(try f.request(&e, 1, .{ .retire_payload = ref }));
    _ = try f.submit(&e, 0, .{ .revoke = 1 });
    try t.expectError(error.Conflict, e.commit(pending));
    try t.expectError(error.Forbidden, f.submit(&e, 1, .{ .retire_payload = ref }));
    _ = try f.submit(&e, 0, .{ .retire_payload = ref });
    _ = try f.submit(&e, 0, .{ .payload_deleted = ref });
    var recovered = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(.deleted, (try recovered.state.payload(ref)).phase);
    try t.expectError(error.PayloadPhase, f.submit(&recovered, 0, .{ .payload_ready = ref }));
    try t.expectError(error.RetiredProcess, f.submit(&recovered, 0, .{ .declare_payload = .{ .pid = pid, .sha256 = @splat(1), .bytes = 1 } }));
}

test "unsupported finite payload lifetimes fail before admission" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 1;
    var e = try Engine.bootstrap(&f.store, f.genesis);
    var clock: TestClock = .{ .now = .{ .unix_ms = 1 } };
    e.clock = clock.source();
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 110 } });
    try t.expectError(error.UnsupportedPayloadLifetime, f.submit(&e, 0, .{ .declare_payload = .{ .pid = pid, .sha256 = @splat(1), .bytes = 1 } }));
    try t.expectEqual(@as(u64, 2), e.state.position);
}

test "an authenticated handler failure blocks recovery without consuming the head" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.retry_policy = .last_per_principal;
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .allow_trim = true } });
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute), .pid = pid } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 1 } });
    const first = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(std.math.maxInt(i64)) } });
    const bad = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } });
    try t.expectError(error.InvalidFailure, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = core.Value.integer(0), .failed = true } }));
    try t.expectError(error.InvalidFailure, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = .{}, .failed = true, .effect = core.Value.integer(1) } }));
    try t.expectError(error.InvalidFailure, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = .{}, .failed = true, .outputs = .{ .{ .pid = pid, .value = core.Value.integer(1) }, null, null, null } } }));
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = core.Value.integer(std.math.maxInt(i64)) } });
    const failure = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = bad, .result = core.Value.integer(std.math.maxInt(i64)), .failed = true } });
    var recovered = try Engine.open(&f.store, f.genesis);
    const p = (try recovered.state.process(pid)).*;
    try t.expectEqual(bad, p.failure.?.input);
    try t.expectEqual(failure, p.failure.?.recorded_at);
    try t.expectEqual(@as(u64, 1), p.consumed);
    try t.expectEqual(@as(u64, 0), p.cancelled);
    try t.expectEqual(@as(?u8, null), p.owner);
    try t.expectError(error.BlockedProcess, f.submit(&recovered, 0, .{ .own = .{ .pid = pid, .expected_generation = p.generation, .worker = 1 } }));
    try t.expectError(error.PendingWork, f.submit(&recovered, 0, .{ .checkpoint = {} }));
    _ = try f.submit(&recovered, 0, .{ .terminate = pid });
    try t.expectEqual(@as(u64, 1), (try recovered.state.process(pid)).cancelled);
    _ = try f.submit(&recovered, 0, .{ .checkpoint = {} });
}

test "lost spawn acknowledgement resolves to the same PID and conflicting retry is rejected" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const spawn = try f.request(&e, 0, .{ .spawn = .{} });
    f.store.fail_ack = true;
    try t.expectError(error.LostAcknowledgement, e.submit(spawn));
    var recovered = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(@as(u64, 1), try recovered.submit(spawn));
    try t.expectEqual(@as(u64, 2), try f.store.tail());
    var changed = spawn.request;
    changed.command.spawn.code = 0;
    try t.expectError(error.ConflictingRetry, recovered.submit(try core.sign(changed, f.root)));
    _ = try f.submit(&recovered, 0, .{ .inspect = 1 });
    try t.expectEqual(@as(u64, 1), try recovered.submit(spawn));
}

test "finite retry policy is explicit and cannot admit a forgotten operation as new" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.retry_policy = .last_per_principal;
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const spawn = try f.request(&e, 0, .{ .spawn = .{} });
    const pid = try e.submit(spawn);
    _ = try f.submit(&e, 0, .{ .inspect = pid });
    try t.expectError(error.RetryHorizonExceeded, e.submit(spawn));
    try t.expectEqual(@as(u64, 3), try f.store.tail());
}

test "two prepared successors cannot both commit and revoked policy fences a prepared turn" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var a = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&a);
    const input = try f.submit(&a, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(4) } });
    var b = try Engine.open(&f.store, f.genesis);
    const turn = try f.request(&a, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(4) } });
    const prepared = try a.prepare(turn);
    _ = try f.submit(&b, 0, .{ .revoke = 1 });
    try t.expectError(error.Conflict, a.commit(prepared));
    try t.expectError(error.Forbidden, a.submit(turn));
    try t.expectEqual(@as(i64, 0), try (try a.state.process(pid)).state.asInteger());
    try t.expectEqual(@as(u64, 0), (try a.state.process(pid)).consumed);
}

test "replacement ownership fences stale worker proposals while preserving the PID" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(5) } });
    const old = try f.request(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(5) } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 1 } });
    try t.expectError(error.StaleGeneration, e.submit(old));
    var new = old.request;
    new.command.turn.generation = 2;
    _ = try e.submit(try core.sign(new, f.worker));
    var restored = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(@as(i64, 5), try (try restored.state.process(pid)).state.asInteger());
    try t.expectEqual(@as(u64, 2), (try restored.state.process(pid)).generation);
}

test "authentication binds the complete request, realm, principal and current key" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const valid = try f.request(&e, 1, .{ .inspect = pid });
    var forged = valid;
    forged.request.command = .{ .terminate = pid };
    try t.expectError(error.SignatureVerificationFailed, e.submit(forged));
    forged = valid;
    forged.request.principal = 0;
    try t.expectError(error.SignatureVerificationFailed, e.submit(forged));
    forged = valid;
    forged.request.realm = 99;
    try t.expectError(error.WrongProtocolRealm, e.submit(forged));
    const forbidden = try f.request(&e, 1, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } });
    try t.expectError(error.Forbidden, e.submit(forbidden));
    const key = try core.Ed25519.KeyPair.generateDeterministic(@splat(9));
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = key.public_key.toBytes(), .permissions = core.permission(.inspect) } });
    try t.expectError(error.SignatureVerificationFailed, e.submit(valid));
    _ = try e.submit(try core.sign(valid.request, key));
}

test "mailbox order rejects skipping and stale state revisions; backlog is not retained in State" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const first = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(3) } });
    const second = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(7) } });
    try t.expectError(error.InvalidInput, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = second, .result = core.Value.integer(7) } }));
    var stale = (try f.request(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = core.Value.integer(900) } })).request;
    stale.command.turn.expected_revision = 99;
    try t.expectError(error.StaleState, e.submit(try core.sign(stale, f.worker)));
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = core.Value.integer(3) } });
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = second, .result = core.Value.integer(10) } });
    for (0..100) |_| {
        _ = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } });
    }
    var recovered = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(@as(i64, 10), try (try recovered.state.process(pid)).state.asInteger());
    try t.expectEqual(@as(u64, 102), (try recovered.state.process(pid)).admitted);
    try t.expectEqual(@as(u64, 2), (try recovered.state.process(pid)).consumed);
}

test "retired PID cannot be reactivated and unsupported finite contracts fail before admission" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    try t.expectError(error.UnsupportedDeadline, f.submit(&e, 0, .{ .spawn = .{ .deadline_ms = 30 } }));
    try t.expectError(error.UnsupportedWorkload, f.submit(&e, 0, .{ .spawn = .{ .code = 0 } }));
    try t.expectEqual(@as(u64, 1), try f.store.tail());
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .terminate = pid });
    try t.expectError(error.RetiredProcess, f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 1 } }));
    try t.expectError(error.RetiredProcess, f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } }));
    try t.expect((try f.submit(&e, 0, .{ .spawn = .{} })) != pid);
}

test "reported failure preserves the pending input" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const a = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(std.math.maxInt(i64)) } });
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = a, .result = core.Value.integer(std.math.maxInt(i64)) } });
    const b = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } });
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = b, .result = core.Value.integer(std.math.maxInt(i64)), .failed = true } });
    try t.expectEqual(@as(u64, 1), (try e.state.process(pid)).consumed);
    _ = try f.submit(&e, 0, .{ .terminate = pid });
    try t.expectEqual(@as(u64, 1), (try e.state.process(pid)).consumed);
    try t.expectEqual(@as(u64, 1), (try e.state.process(pid)).cancelled);
}

test "checkpoint requires explicit retention opt-in and its content is verified" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    try t.expectError(error.HistoryPinned, f.submit(&e, 0, .{ .checkpoint = {} }));
    f.store.deinit();
    f.store = .{};
    f.genesis.retry_policy = .last_per_principal;
    e = try Engine.bootstrap(&f.store, f.genesis);
    _ = try f.submit(&e, 0, .{ .spawn = .{ .allow_trim = true } });
    _ = try f.submit(&e, 0, .{ .checkpoint = {} });
    var checkpoint = try core.Checkpoint.create(t.allocator, f.genesis, &e.state);
    try checkpoint.validate(t.allocator, f.genesis);
    checkpoint.state.processes[0].?.state = core.Value.integer(999);
    try t.expectError(error.InvalidCheckpoint, checkpoint.validate(t.allocator, f.genesis));
}

test "dispatch bounds observations and requires a finite caller reconciliation deadline" {
    const EffectEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 0;
    var clock: TestClock = .{ .now = .{ .unix_ms = 10 } };
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    e.clock = clock.source();
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 110 } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .worker = 0, .expected_generation = 0 } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
    const permit = try f.submit(&e, 0, .{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } });
    const effect = try f.submit(&e, 0, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(9), .effect = core.Value.integer(9), .permit = permit } });
    for ([_]u16{ 0, 17, 65535 }) |budget| {
        try t.expectError(error.InvalidBudget, f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect, .max_observations = budget, .reconcile_before_ms = 120 } }));
    }
    try t.expectError(error.InvalidLifetime, f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } }));
    try t.expectEqual(.pending, (try e.state.effect(effect)).phase);
    _ = try f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect, .reconcile_before_ms = 120 } });
    try t.expectEqual(@as(u16, core.max_effect_observations), (try e.state.effect(effect)).max_observations);
}

test "only a committed intent permits one attempt and late evidence cannot revive its caller" {
    const EffectEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute), .pid = pid } });
    try t.expectError(error.UnknownEffect, f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = 99 } }));
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
    try t.expectError(error.Forbidden, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(9), .effect = core.Value.integer(9) } }));
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.effect), .pid = pid } });
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(9), .effect = core.Value.integer(9) } });
    const attempt = try f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    var recovered = try EffectEngine.open(&f.store, f.genesis);
    try t.expectEqual(.authorized, (try recovered.state.effect(effect)).phase);
    try t.expectError(error.AttemptAlreadyAuthorized, f.submit(&recovered, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } }));
    try t.expectError(error.InvalidAttempt, f.submit(&recovered, 1, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = core.Value.integer(1) } }));
    _ = try f.submit(&recovered, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = null } });
    try t.expectEqual(.unknown, (try recovered.state.effect(effect)).phase);
    _ = try f.submit(&recovered, 0, .{ .terminate = pid });
    _ = try f.submit(&recovered, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = core.Value.integer(3) } });
    try t.expectEqual(.terminated, (try recovered.state.process(pid)).lifecycle);
    try t.expectEqual(@as(u64, 1), (try recovered.state.process(pid)).admitted);
    try t.expectEqual(@as(i64, 9), try (try recovered.state.process(pid)).state.asInteger());
    try t.expectEqual(.observed, (try recovered.state.effect(effect)).phase);
}

test "authenticated effect outcome becomes exactly one ordered mailbox input" {
    const EffectEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.effect) } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(9), .effect = core.Value.integer(9) } });
    const attempt = try f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    const outcome = try f.request(&e, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = core.Value.integer(2) } });
    const position = try e.submit(outcome);
    try t.expectEqual(position, try e.submit(outcome));
    try t.expectEqual(@as(u64, 2), (try e.state.process(pid)).admitted);
    const message = (try e.nextInput(pid, e.state.position)).?;
    try t.expectEqual(position, message.position);
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = position, .result = core.Value.integer(11) } });
    var replay = try EffectEngine.open(&f.store, f.genesis);
    try t.expectEqual(@as(i64, 11), try (try replay.state.process(pid)).state.asInteger());
}

test "revocation fences prepared dispatch; termination cancels only unattempted intents" {
    const EffectEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.effect) } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(9), .effect = core.Value.integer(9) } });
    const request = try f.request(&e, 1, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    const prepared = try e.prepare(request);
    var competing = try EffectEngine.open(&f.store, f.genesis);
    _ = try f.submit(&competing, 0, .{ .revoke = 1 });
    try t.expectError(error.Conflict, e.commit(prepared));
    try t.expectError(error.Forbidden, e.submit(request));
    try t.expectEqual(.pending, (try e.state.effect(effect)).phase);
    _ = try f.submit(&e, 0, .{ .terminate = pid });
    var replay = try EffectEngine.open(&f.store, f.genesis);
    try t.expectEqual(.cancelled, (try replay.state.effect(effect)).phase);
    try t.expectEqual(@as(?u64, null), (try replay.state.effect(effect)).attempt);
}

test "result and unknown closure have one winner despite lost acknowledgements" {
    const EffectEngine = core.Engine(Memory);
    for ([_]bool{ false, true }) |close_wins| {
        var f = try Fixture.init();
        defer f.store.deinit();
        var e = try EffectEngine.bootstrap(&f.store, f.genesis);
        const pid = try f.setup(&e);
        _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.effect), .pid = pid } });
        const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
        const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(9), .effect = core.Value.integer(9) } });
        const attempt = try f.submit(&e, 1, .{ .dispatch = .{ .pid = pid, .effect = effect } });
        const response = try f.request(&e, 1, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = core.Value.integer(2) } });
        const close = try f.request(&e, 0, .{ .close_effect = .{ .pid = pid, .effect = effect, .attempt = attempt } });
        var competing = try EffectEngine.open(&f.store, f.genesis);
        const winner = if (close_wins) close else response;
        const loser = if (close_wins) response else close;
        const a = try e.prepare(winner);
        const b = try competing.prepare(loser);
        f.store.fail_ack = true;
        try t.expectError(error.LostAcknowledgement, e.commit(a));
        try t.expectError(error.Conflict, competing.commit(b));
        var recovered = try EffectEngine.open(&f.store, f.genesis);
        try t.expectEqual(a.record.position, try recovered.submit(winner));
        try t.expectError(error.ReconciliationClosed, recovered.submit(loser));
        const closed = (try recovered.state.effect(effect)).*;
        try t.expectEqual(@as(?u64, a.record.position), closed.closed_at);
        try t.expectEqual(@as(@TypeOf(closed.phase), if (close_wins) .closed_unknown else .observed), closed.phase);
        try t.expectEqual(if (close_wins) @as(?i64, null) else 2, if (closed.result) |v| try v.asInteger() else null);
        try t.expectEqual(if (close_wins) @as(u64, 1) else 2, (try recovered.state.process(pid)).admitted);
        try t.expectError(error.ReconciliationClosed, f.submit(&recovered, 1, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = null } }));
        try t.expectError(error.AttemptAlreadyAuthorized, f.submit(&recovered, 1, .{ .dispatch = .{ .pid = pid, .effect = effect } }));
    }
}

test "closure needs executor or controller authority and cannot overwrite a result" {
    const EffectEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.effect), .pid = pid } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(9), .effect = core.Value.integer(9) } });
    const attempt = try f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    const close: core.Command = .{ .close_effect = .{ .pid = pid, .effect = effect, .attempt = attempt } };
    try t.expectError(error.Forbidden, f.submit(&e, 1, close));
    try t.expectError(error.InvalidAttempt, f.submit(&e, 0, .{ .close_effect = .{ .pid = pid, .effect = effect, .attempt = attempt + 1 } }));
    _ = try f.submit(&e, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = core.Value.integer(2) } });
    try t.expectError(error.ReconciliationClosed, f.submit(&e, 0, close));
    try t.expectEqual(@as(?i64, 2), if ((try e.state.effect(effect)).result) |v| try v.asInteger() else null);
}

test "revoking an executor fences its prepared closure but a controller can finish cleanup" {
    const EffectEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.effect), .pid = pid } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(9), .effect = core.Value.integer(9) } });
    const attempt = try f.submit(&e, 1, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    const command: core.Command = .{ .close_effect = .{ .pid = pid, .effect = effect, .attempt = attempt } };
    const request = try f.request(&e, 1, command);
    const prepared = try e.prepare(request);
    var controller = try EffectEngine.open(&f.store, f.genesis);
    _ = try f.submit(&controller, 0, .{ .revoke = 1 });
    try t.expectError(error.Conflict, e.commit(prepared));
    try t.expectError(error.Forbidden, e.submit(request));
    _ = try f.submit(&controller, 0, .{ .terminate = pid });
    _ = try f.submit(&controller, 0, command);
    try t.expectEqual(.closed_unknown, (try controller.state.effect(effect)).phase);
    try t.expectEqual(.terminated, (try controller.state.process(pid)).lifecycle);
}

test "finite process settles only its recorded turn and expires permanently" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 0;
    var clock: TestClock = .{ .now = .{ .unix_ms = 10 } };
    var e = try Engine.bootstrap(&f.store, f.genesis);
    e.clock = clock.source();
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 200 } });
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute), .pid = pid } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 0 } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(7) } });
    try t.expectError(error.MissingTurnPermit, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(7) } }));
    const permit = try f.submit(&e, 1, .{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } });
    clock.now.unix_ms = 110;
    try t.expectError(error.DeadlineExpired, f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } }));
    try t.expectError(error.DeadlineExpired, f.submit(&e, 1, .{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } }));
    // Recovery transfers ownership, not the original work/settlement lifetime.
    var recovered = try Engine.open(&f.store, f.genesis);
    recovered.clock = clock.source();
    _ = try f.submit(&recovered, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 1 } });
    try t.expectError(error.StaleGeneration, f.submit(&recovered, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(7), .permit = permit } }));
    _ = try f.submit(&recovered, 1, .{ .turn = .{ .pid = pid, .generation = 2, .input = input, .result = core.Value.integer(7), .permit = permit } });
    try t.expectEqual(@as(i64, 7), try (try recovered.state.process(pid)).state.asInteger());
    try t.expectError(error.DeadlineExpired, f.submit(&recovered, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 2 } }));
    try t.expectError(error.DeadlineNotReached, f.submit(&recovered, 0, .{ .expire = pid }));
    clock.now.unix_ms = 200;
    _ = try f.submit(&recovered, 0, (try recovered.state.nextMaintenance(clock.now)).?);
    var replay = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(.expired, (try replay.state.process(pid)).lifecycle);
    try t.expectEqual(@as(?core.Command, null), try replay.state.nextMaintenance(clock.now));
    try t.expectError(error.RetiredProcess, f.submit(&replay, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } }));
}

test "uncertain time, missing clock, and rollback cannot authorize finite work" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 5;
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const spawn: core.Command = .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 200 } };
    try t.expectError(error.ClockUnavailable, f.submit(&e, 0, spawn));
    var clock: TestClock = .{ .now = .{ .unix_ms = 96, .error_ms = 5 } };
    e.clock = clock.source();
    try t.expectError(error.DeadlineUncertain, f.submit(&e, 0, spawn));
    clock.now = .{ .unix_ms = 80, .error_ms = 6 };
    try t.expectError(error.UntrustedTime, f.submit(&e, 0, spawn));
    clock.now.error_ms = 5;
    _ = try f.submit(&e, 0, spawn);
    clock.now.unix_ms = 79;
    var recovered = try Engine.open(&f.store, f.genesis);
    recovered.clock = clock.source();
    try t.expectError(error.ClockRollback, f.submit(&recovered, 0, .{ .send = .{ .pid = 1, .value = core.Value.integer(1) } }));
    // Revocation and reads must remain available during clock failure.
    _ = try f.submit(&recovered, 0, .{ .inspect = 1 });
    clock.now.unix_ms = 90;
    try t.expectError(error.InvalidLifetime, f.submit(&recovered, 0, .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 99 } }));
}

test "reconciliation budgets survive restart and a missed timer cannot accept a late result" {
    const EffectEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 0;
    var clock: TestClock = .{ .now = .{ .unix_ms = 10 } };
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    e.clock = clock.source();
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.effect), .pid = pid } });
    for ([_]bool{ true, false }) |exhaust_budget| {
        const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
        const result = (try (try e.state.process(pid)).state.asInteger()) + 9;
        const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(result), .effect = core.Value.integer(9) } });
        const attempt = try f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect, .reconcile_before_ms = 100, .max_observations = 2 } });
        const observe: core.Command = .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = null } };
        _ = try f.submit(&e, 0, observe);
        e = try EffectEngine.open(&f.store, f.genesis);
        e.clock = clock.source();
        try t.expectEqual(@as(u16, 1), (try e.state.effect(effect)).observations);
        if (exhaust_budget) {
            _ = try f.submit(&e, 0, observe);
        } else {
            clock.now.unix_ms = 100;
            try t.expectError(error.DeadlineExpired, f.submit(&e, 0, observe));
            _ = try f.submit(&e, 0, (try e.state.nextMaintenance(clock.now)).?);
        }
        try t.expectEqual(.closed_unknown, (try e.state.effect(effect)).phase);
        try t.expectError(error.ReconciliationClosed, f.submit(&e, 0, observe));
    }
}

test "acceptance uses trusted validation time while durable closure fences delayed persistence" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 0;
    var clock: TestClock = .{ .now = .{ .unix_ms = 10 } };
    var e = try Engine.bootstrap(&f.store, f.genesis);
    e.clock = clock.source();
    const spawn = try f.request(&e, 0, .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 200 } });
    const prepared = try e.prepare(spawn);
    clock.now.unix_ms = 110;
    // The authority validated this operation before the work cutoff. This is
    // deliberately not a guarantee of physical persistence before that cutoff.
    const pid = try e.commit(prepared);
    try t.expectError(error.DeadlineExpired, f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } }));
    var recovered = try Engine.open(&f.store, f.genesis);
    recovered.clock = clock.source();
    clock.now.unix_ms = 200;
    _ = try f.submit(&recovered, 0, (try recovered.state.nextMaintenance(clock.now)).?);
    try t.expectError(error.Conflict, e.commit(prepared));
}

test "an unfinished permit cannot outlive settlement or skip expired input" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 0;
    var clock: TestClock = .{ .now = .{ .unix_ms = 10 } };
    var e = try Engine.bootstrap(&f.store, f.genesis);
    e.clock = clock.source();
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .deadline_ms = 20, .settle_before_ms = 30 } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .worker = 0, .expected_generation = 0 } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } });
    const permit = try f.submit(&e, 0, .{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } });
    clock.now.unix_ms = 30;
    try t.expectError(error.DeadlineExpired, f.submit(&e, 0, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .permit = permit, .result = core.Value.integer(1) } }));
    _ = try f.submit(&e, 0, (try e.state.nextMaintenance(clock.now)).?);
    var recovered = try Engine.open(&f.store, f.genesis);
    const p = (try recovered.state.process(pid)).*;
    try t.expectEqual(.expired, p.lifecycle);
    try t.expectEqual(@as(u64, 0), p.consumed);
    try t.expectEqual(@as(u64, 1), p.cancelled);
    try t.expectEqual(@as(i64, 0), try p.state.asInteger());
    try t.expect(p.turn_permit == null);
}

const Fanout = struct { state: i64, outputs: [core.max_turn_outputs]?core.Output = @splat(null) };
fn fanout(state: i64, input: i64) !Fanout {
    var decision: Fanout = .{ .state = try std.math.add(i64, state, input) };
    if (input == 99) decision.outputs = .{ .{ .pid = 1, .value = core.Value.integer(1) }, .{ .pid = 1, .value = core.Value.integer(2) }, .{ .pid = 2, .value = core.Value.integer(3) }, null };
    return decision;
}

test "provider observations cannot grant ownership; activation rotates keys atomically" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.inspect), .pid = pid } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(7) } });
    const stale = try f.request(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = core.Value.integer(7) } });
    var intent: core.Runtime.Intent = .{ .pid = pid, .expected_revision = 0, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3) };
    const operation = try f.submit(&e, 0, .{ .runtime_intent = intent });
    try t.expectError(error.StaleGeneration, e.submit(stale));
    try t.expectError(error.RuntimeActivationRequired, f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 2, .worker = 1 } }));
    const replacement = try core.Ed25519.KeyPair.generateDeterministic(@splat(10));
    var activation: core.Runtime.Activate = .{ .pid = pid, .revision = 1, .expected_generation = 2, .worker = 1, .public_key = replacement.public_key.toBytes(), .worker_incarnation = @splat(4) };
    try t.expectError(error.ProviderNotReady, f.submit(&e, 0, .{ .activate = activation }));
    const observation: core.Runtime.Observation = .{ .pid = pid, .revision = 1, .operation = operation, .incarnation = @splat(5), .outcome = .ready };
    _ = try f.submit(&e, 0, .{ .runtime_observe = observation });
    try t.expectEqual(@as(?u8, null), (try e.state.process(pid)).owner);
    // Replaying an already recorded provider outcome does not authorize a worker.
    var recovered = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(@as(?u8, null), (try recovered.state.process(pid)).owner);
    _ = try f.submit(&recovered, 0, .{ .activate = activation });
    try t.expectError(error.SignatureVerificationFailed, recovered.submit(stale));
    f.worker = replacement;
    _ = try f.submit(&recovered, 1, .{ .turn = .{ .pid = pid, .generation = 3, .input = input, .result = core.Value.integer(7) } });
    intent.expected_revision = 1;
    const second_op = try f.submit(&recovered, 0, .{ .runtime_intent = intent });
    try t.expectError(error.StaleBinding, f.submit(&recovered, 0, .{ .runtime_observe = observation }));
    var second_observation = observation;
    second_observation.revision = 2;
    second_observation.operation = second_op;
    second_observation.incarnation = @splat(6);
    try t.expectError(error.ProviderIncarnationMismatch, f.submit(&recovered, 0, .{ .runtime_observe = second_observation }));
    second_observation.incarnation = @splat(5);
    _ = try f.submit(&recovered, 0, .{ .runtime_observe = second_observation });
    activation.revision = 2;
    activation.expected_generation = 4;
    try t.expectError(error.StaleWorkerIncarnation, f.submit(&recovered, 0, .{ .activate = activation }));
    activation.worker_incarnation = @splat(7);
    try t.expectError(error.FreshKeyRequired, f.submit(&recovered, 0, .{ .activate = activation }));
    activation.public_key = (try core.Ed25519.KeyPair.generateDeterministic(@splat(11))).public_key.toBytes();
    const prepared = try recovered.prepare(try f.request(&recovered, 0, .{ .activate = activation }));
    var terminator = try Engine.open(&f.store, f.genesis);
    _ = try f.submit(&terminator, 0, .{ .terminate = pid });
    try t.expectError(error.Conflict, recovered.commit(prepared));
    try t.expectError(error.RetiredProcess, f.submit(&terminator, 0, .{ .activate = activation }));
    const another = try f.submit(&terminator, 0, .{ .spawn = .{} });
    intent.pid = another;
    intent.expected_revision = 0;
    try t.expectError(error.ResourceAlreadyBound, f.submit(&terminator, 0, .{ .runtime_intent = intent }));
}

test "workload upgrade preserves PID and unfinished work while fencing every prior activation" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.inspect) | core.permission(.effect), .pid = pid } });
    const first = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(7) } });
    const committed = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = core.Value.integer(7), .effect = core.Value.integer(11) } });
    const pending = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.inspect), .pid = pid } });
    var intent: core.Runtime.Intent = .{ .pid = pid, .expected_revision = 0, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3) };
    const created = try f.submit(&e, 0, .{ .runtime_intent = intent });
    _ = try f.submit(&e, 0, .{ .runtime_observe = .{ .pid = pid, .revision = 1, .operation = created, .incarnation = @splat(4), .outcome = .ready } });
    f.worker = try core.Ed25519.KeyPair.generateDeterministic(@splat(10));
    _ = try f.submit(&e, 0, .{ .activate = .{ .pid = pid, .revision = 1, .expected_generation = 2, .worker = 1, .public_key = f.worker.public_key.toBytes(), .worker_incarnation = @splat(5) } });
    const permit = try f.submit(&e, 1, .{ .begin_turn = .{ .pid = pid, .generation = 3, .input = pending } });
    const stale_turn = try f.request(&e, 1, .{ .turn = .{ .pid = pid, .generation = 3, .input = pending, .result = core.Value.integer(16), .permit = permit } });
    var upgrade: core.Runtime.Upgrade = .{ .pid = pid, .expected_revision = 1, .expected_workload = @splat(3), .workload = @splat(6), .expected_code = 1, .expected_state_revision = committed };
    try t.expectError(error.Forbidden, f.submit(&e, 1, .{ .runtime_upgrade = upgrade }));
    try t.expectError(error.ProviderNotReady, f.submit(&e, 0, .{ .runtime_upgrade = upgrade }));
    intent.expected_revision = 1;
    intent.desired = .stopped;
    const stopping = try f.submit(&e, 0, .{ .runtime_intent = intent });
    try t.expectError(error.StaleGeneration, e.submit(stale_turn));
    upgrade.expected_revision = 2;
    try t.expectError(error.ProviderNotReady, f.submit(&e, 0, .{ .runtime_upgrade = upgrade }));
    _ = try f.submit(&e, 0, .{ .runtime_observe = .{ .pid = pid, .revision = 2, .operation = stopping, .incarnation = @splat(4), .outcome = .stopped } });
    upgrade.expected_code = 2;
    try t.expectError(error.UnsupportedWorkload, f.submit(&e, 0, .{ .runtime_upgrade = upgrade }));
    upgrade.expected_code = 1;
    upgrade.expected_state_revision = 0;
    try t.expectError(error.StaleState, f.submit(&e, 0, .{ .runtime_upgrade = upgrade }));
    upgrade.expected_state_revision = committed;
    upgrade.expected_workload = @splat(7);
    try t.expectError(error.StaleBinding, f.submit(&e, 0, .{ .runtime_upgrade = upgrade }));
    upgrade.expected_workload = @splat(3);
    const signed = try f.request(&e, 0, .{ .runtime_upgrade = upgrade });
    f.store.fail_ack = true;
    try t.expectError(error.LostAcknowledgement, e.submit(signed));
    var recovered = try Engine.open(&f.store, f.genesis);
    const operation = try recovered.submit(signed);
    const after = (try recovered.state.process(pid)).*;
    try t.expectEqual(committed, after.revision);
    try t.expectEqualSlices(u8, "7", after.state.slice());
    try t.expectEqual(@as(u64, 2), after.admitted);
    try t.expectEqual(@as(u64, 1), after.consumed);
    try t.expectEqual(permit, after.turn_permit.?.id);
    try t.expectEqual(.pending, (try recovered.state.effect(committed)).phase);
    try t.expectEqual(@as(?u8, null), after.owner);
    try t.expectEqual(@as(?[32]u8, @splat(3)), after.binding.?.upgrade_from);
    try t.expectEqual(@as(?[16]u8, @splat(4)), after.binding.?.incarnation);
    intent.expected_revision = 3;
    intent.workload = @splat(6);
    intent.desired = .running;
    try t.expectError(error.PendingProviderOperation, f.submit(&recovered, 0, .{ .runtime_intent = intent }));
    var observed: core.Runtime.Observation = .{ .pid = pid, .revision = 3, .operation = operation, .incarnation = @splat(4), .outcome = .ready };
    try t.expectError(error.InvalidBinding, f.submit(&recovered, 0, .{ .runtime_observe = observed }));
    observed.outcome = .unknown;
    _ = try f.submit(&recovered, 0, .{ .runtime_observe = observed });
    var again = try Engine.open(&f.store, f.genesis);
    observed.outcome = .stopped;
    _ = try f.submit(&again, 0, .{ .runtime_observe = observed });
    const resuming = try f.submit(&again, 0, .{ .runtime_intent = intent });
    observed = .{ .pid = pid, .revision = 4, .operation = resuming, .incarnation = @splat(4), .outcome = .ready };
    _ = try f.submit(&again, 0, .{ .runtime_observe = observed });
    const fresh = try core.Ed25519.KeyPair.generateDeterministic(@splat(11));
    var activate: core.Runtime.Activate = .{ .pid = pid, .revision = 4, .expected_generation = 6, .worker = 1, .public_key = fresh.public_key.toBytes(), .worker_incarnation = @splat(5) };
    try t.expectError(error.StaleWorkerIncarnation, f.submit(&again, 0, .{ .activate = activate }));
    activate.worker_incarnation = @splat(8);
    _ = try f.submit(&again, 0, .{ .activate = activate });
    try t.expectError(error.SignatureVerificationFailed, again.submit(stale_turn));
    f.worker = fresh;
    _ = try f.submit(&again, 1, .{ .turn = .{ .pid = pid, .generation = 7, .input = pending, .result = core.Value.integer(16), .permit = permit } });
    try t.expectEqualSlices(u8, "16", (try again.state.process(pid)).state.slice());
    _ = try f.submit(&again, 0, .{ .terminate = pid });
    try t.expectError(error.RetiredProcess, f.submit(&again, 0, .{ .runtime_upgrade = upgrade }));
}

test "workload upgrade cannot extend finite work or settlement lifetime" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 0;
    var clock: TestClock = .{ .now = .{ .unix_ms = 10 } };
    var e = try Engine.bootstrap(&f.store, f.genesis);
    e.clock = clock.source();
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 200 } });
    const stop = try f.submit(&e, 0, .{ .runtime_intent = .{ .pid = pid, .expected_revision = 0, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3), .desired = .stopped } });
    _ = try f.submit(&e, 0, .{ .runtime_observe = .{ .pid = pid, .revision = 1, .operation = stop, .incarnation = @splat(4), .outcome = .stopped } });
    const upgrade: core.Command = .{ .runtime_upgrade = .{ .pid = pid, .expected_revision = 1, .expected_workload = @splat(3), .workload = @splat(6), .expected_code = 1, .expected_state_revision = 0 } };
    clock.now.unix_ms = 100;
    try t.expectError(error.DeadlineExpired, f.submit(&e, 0, upgrade));
    // Rejection appended no time evidence. Accept before cutoff, then retire
    // while the external template switch remains outstanding.
    clock.now.unix_ms = 99;
    const operation = try f.submit(&e, 0, upgrade);
    clock.now.unix_ms = 200;
    _ = try f.submit(&e, 0, .{ .expire = pid });
    _ = try f.submit(&e, 0, .{ .runtime_observe = .{ .pid = pid, .revision = 2, .operation = operation, .incarnation = @splat(4), .outcome = .stopped } });
    try t.expectError(error.RetiredProcess, f.submit(&e, 0, upgrade));
    try t.expectEqual(.expired, (try e.state.process(pid)).lifecycle);
}

fn seedOutbox(f: *Fixture, e: anytype) !void {
    for (0..3) |_| _ = try f.submit(e, 0, .{ .spawn = .{ .allow_trim = true } });
    _ = try f.submit(e, 0, .{ .own = .{ .pid = 3, .worker = 0, .expected_generation = 0 } });
    const input = try f.submit(e, 0, .{ .send = .{ .pid = 3, .value = core.Value.integer(99) } });
    _ = try f.submit(e, 0, .{ .turn = .{ .pid = 3, .generation = 1, .input = input, .result = core.Value.integer(99), .outputs = (try fanout(0, 99)).outputs } });
    _ = try f.submit(e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.send) } });
}

test "outbox preserves each route's order, partial fanout, and uncertain admission receipts" {
    const OutboxEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try OutboxEngine.bootstrap(&f.store, f.genesis);
    try seedOutbox(&f, &e);
    try t.expectError(error.RouteBlocked, f.submit(&e, 0, .{ .deliver = .{ .pid = 1, .output = 2, .courier = 1 } }));
    _ = try f.submit(&e, 0, .{ .deliver = .{ .pid = 2, .output = 3, .courier = 1 } });
    try t.expectEqual(.pending, (try e.state.output(1)).phase);
    try t.expectEqual(.delivered, (try e.state.output(3)).phase);
    const first = try f.request(&e, 0, .{ .deliver = .{ .pid = 1, .output = 1, .courier = 1 } });
    f.store.fail_ack = true;
    try t.expectError(error.LostAcknowledgement, e.submit(first));
    var replay = try OutboxEngine.open(&f.store, f.genesis);
    const receipt = try replay.submit(first);
    try t.expectEqual(@as(u64, 1), (try replay.state.process(1)).admitted);
    try t.expectEqual(receipt, (try replay.nextInput(1, replay.state.position)).?.position);
    _ = try f.submit(&replay, 0, .{ .deliver = .{ .pid = 1, .output = 2, .courier = 1 } });
    try t.expectEqual(receipt, try replay.submit(first));
    try t.expectEqual(@as(u64, 2), (try replay.state.process(1)).admitted);
}

test "revocation fences delivery; denied records are not mailbox inputs" {
    const OutboxEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try OutboxEngine.bootstrap(&f.store, f.genesis);
    try seedOutbox(&f, &e);
    const delivery = try f.request(&e, 0, .{ .deliver = .{ .pid = 1, .output = 1, .courier = 1 } });
    const pending = try e.prepare(delivery);
    var controller = try OutboxEngine.open(&f.store, f.genesis);
    _ = try f.submit(&controller, 0, .{ .revoke = 1 });
    try t.expectError(error.Conflict, e.commit(pending));
    _ = try f.submit(&controller, 0, .{ .deliver = .{ .pid = 1, .output = 1, .courier = 1 } });
    try t.expectEqual(.denied, (try controller.state.output(1)).phase);
    try t.expectEqual(@as(u64, 0), (try controller.state.process(1)).admitted);
    _ = try f.submit(&controller, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.send) } });
    const accepted = try f.submit(&controller, 0, .{ .deliver = .{ .pid = 1, .output = 2, .courier = 1 } });
    try t.expectEqual(accepted, (try controller.nextInput(1, controller.state.position)).?.position);
    try t.expectError(error.OutputAlreadyResolved, f.submit(&controller, 0, .{ .deliver = .{ .pid = 1, .output = 1, .courier = 1 } }));
    // Source termination cancels only remaining, unaccepted fanout destinations.
    _ = try f.submit(&controller, 0, .{ .terminate = 3 });
    try t.expectEqual(.cancelled, (try controller.state.output(3)).phase);
    try t.expectEqual(.delivered, (try controller.state.output(2)).phase);
    var replay = try OutboxEngine.open(&f.store, f.genesis);
    try t.expectEqual(@as(u64, 1), (try replay.state.process(1)).admitted);
}

test "replay rejects forged mailbox admission metadata" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const at = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } });
    f.store.entries.items[@intCast(at)].operation.admission.?.value = core.Value.integer(999);
    try t.expectError(error.InvalidAdmission, Engine.open(&f.store, f.genesis));
}

test "expired delivery is terminal without waiting for expiry maintenance" {
    const OutboxEngine = core.Engine(Memory);
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 0;
    var clock: TestClock = .{ .now = .{ .unix_ms = 10 } };
    var e = try OutboxEngine.bootstrap(&f.store, f.genesis);
    e.clock = clock.source();
    _ = try f.submit(&e, 0, .{ .spawn = .{ .deadline_ms = 20, .settle_before_ms = 30 } });
    for (0..2) |_| _ = try f.submit(&e, 0, .{ .spawn = .{} });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = 3, .worker = 0, .expected_generation = 0 } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = 3, .value = core.Value.integer(99) } });
    _ = try f.submit(&e, 0, .{ .turn = .{ .pid = 3, .generation = 1, .input = input, .result = core.Value.integer(99), .outputs = (try fanout(0, 99)).outputs } });
    clock.now.unix_ms = 20;
    _ = try f.submit(&e, 0, .{ .deliver = .{ .pid = 1, .output = 1, .courier = 0 } });
    try t.expectEqual(.expired, (try e.state.output(1)).phase);
    try t.expectEqual(@as(u64, 0), (try e.state.process(1)).admitted);
    _ = try f.submit(&e, 0, .{ .deliver = .{ .pid = 2, .output = 3, .courier = 0 } });
    try t.expectEqual(@as(i64, 3), try (try e.nextInput(2, e.state.position)).?.admission.?.value.asInteger());
}

test "application bytes and code identity do not require application execution" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const original = try core.Value.init("arbitrary initial state");
    const next = try core.Value.init(&.{ 0, 255, 42 });
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .code = 99, .initial_state = original } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .worker = 0, .expected_generation = 0 } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = try core.Value.init("application-defined command") } });
    const at = try f.submit(&e, 0, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = next } });
    var replay = try Engine.open(&f.store, f.genesis);
    const process = try replay.state.process(pid);
    try t.expect(next.eql(process.state));
    try t.expectEqual(at, process.revision);
    try t.expectEqual(@as(u64, 1), process.consumed);
    const head = try f.submit(&replay, 0, .{ .send = .{ .pid = pid, .value = original } });
    _ = try f.submit(&replay, 0, .{ .turn = .{ .pid = pid, .generation = 1, .input = head, .result = next, .failed = true } });
    try t.expectEqual(head, (try replay.state.process(pid)).failure.?.input);
}

test "v1 history and requests are never silently reinterpreted" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var old = f.genesis;
    old.version = 1;
    try t.expectError(error.InvalidGenesis, Engine.bootstrap(&f.store, old));
    var e = try Engine.bootstrap(&f.store, f.genesis);
    try t.expectError(error.WrongProtocolRealm, e.submit(try core.sign(.{ .version = 1, .realm = 42, .principal = 0, .sequence = 1, .command = .{ .spawn = .{} } }, f.root)));
}

test "checkpoint parser preserves opaque state and rejects ambiguous or incomplete objects" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.retry_policy = .last_per_principal;
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const value = try core.Value.init(&.{ 0, 255, 34, 10 });
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .allow_trim = true, .initial_state = value } });
    _ = try f.submit(&e, 0, .{ .checkpoint = {} });
    const checkpoint = try core.Checkpoint.create(t.allocator, f.genesis, &e.state);
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, &checkpoint, .{});
    defer t.allocator.free(bytes);
    var parsed = try std.json.parseFromSlice(*core.Checkpoint, t.allocator, bytes, .{});
    var owned = parsed.value.*;
    parsed.deinit();
    try owned.validate(t.allocator, f.genesis);
    try t.expect(value.eql((try owned.state.process(pid)).state));
    try t.expectError(error.DuplicateField, std.json.parseFromSlice(*core.Checkpoint, t.allocator, "{\"version\":2,\"version\":2}", .{}));
    try t.expectError(error.UnknownField, std.json.parseFromSlice(*core.Checkpoint, t.allocator, "{\"unexpected\":0}", .{}));
    try t.expectError(error.MissingField, std.json.parseFromSlice(*core.Checkpoint, t.allocator, "{\"version\":2}", .{}));
    try t.expectError(error.DuplicateField, std.json.parseFromSlice(*core.State, t.allocator, "{\"realm\":42,\"realm\":42}", .{}));
    try t.expectError(error.UnknownField, std.json.parseFromSlice(*core.State, t.allocator, "{\"unexpected\":0}", .{}));
    try t.expectError(error.MissingField, std.json.parseFromSlice(*core.State, t.allocator, "{\"realm\":42}", .{}));
}

fn largestCheckpointFields(comptime T: type) T {
    const state = core.protocol.State;
    if (T == state.Entry) return .{ .key = core.Value.init(&@as([state.max_key_bytes]u8, @splat(255))) catch unreachable, .value = largestCheckpointFields(core.Value), .revision = std.math.maxInt(u64) };
    if (T == state.Association) return .{ .pid = std.math.maxInt(u64), .name = core.Value.init(&@as([state.max_key_bytes]u8, @splat(255))) catch unreachable, .resource = std.math.maxInt(u64), .revision = std.math.maxInt(u64), .required = false };
    if (T == core.Value) return core.Value.init(&(@as([core.Value.max_bytes]u8, @splat(255)))) catch unreachable;
    return switch (@typeInfo(T)) {
        .int => std.math.maxInt(T),
        .bool => false,
        .optional => |info| largestCheckpointFields(info.child),
        .array => |info| @splat(largestCheckpointFields(info.child)),
        .@"struct" => |info| blk: {
            var value: T = undefined;
            inline for (info.field_names, info.field_types) |name, F| @field(value, name) = largestCheckpointFields(F);
            break :blk value;
        },
        .@"enum" => |info| blk: {
            comptime var longest: usize = 0;
            inline for (info.field_names, 0..) |name, index| {
                if (comptime name.len > info.field_names[longest].len) longest = index;
            }
            break :blk @fromBackingInt(@intCast(info.field_values[longest]));
        },
        else => @compileError("Extend the checkpoint bound fixture for this type"),
    };
}

test "all lifetime catalogs with maximum inline values fit the checkpoint bound" {
    // Deliberately wider than legal counters, with every optional field and slot
    // present, with state keys at their enforced 32-byte bound. This protects
    // reserved control capacity from schema growth.
    const value = largestCheckpointFields(core.Checkpoint);
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, &value, .{});
    defer t.allocator.free(bytes);
    try t.expect(bytes.len + 1024 <= core.max_checkpoint_bytes);
    var parsed = try std.json.parseFromSlice(*core.Checkpoint, t.allocator, bytes, .{});
    defer parsed.deinit();
    try t.expectEqual(value.state.position, parsed.value.state.position);
    try t.expect(value.state.effects[core.max_effects - 1].?.payload.eql(parsed.value.state.effects[core.max_effects - 1].?.payload));
}

test "inspection filters discovery, history and links under current permission with bounded scans" {
    const i = core.protocol.Inspection;
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const hidden = try f.submit(&e, 0, .{ .spawn = .{} });
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.inspect), .pid = pid } });
    var q: i.Query = .{ .realm = 42, .principal = 1, .resource = .processes };
    var page = try core.inspection.read(&e, try i.sign(q, f.worker));
    try t.expectEqual(pid, page.processes[0].?.pid);
    try t.expectEqual(null, page.processes[1]);
    q.resource = .history;
    q.pid = hidden;
    try t.expectError(error.Forbidden, core.inspection.read(&e, try i.sign(q, f.worker)));
    q.pid = pid;
    const first_cut = page.cut;
    for (0..140) |_| _ = try f.submit(&e, 0, .{ .send = .{ .pid = hidden, .value = core.Value.integer(123) } });
    page = try core.inspection.read(&e, try i.sign(q, f.worker));
    try t.expectEqual(i.scan_limit, page.scanned);
    try t.expect(!page.complete);
    for (page.events) |slot| if (slot) |event| try t.expectEqual(pid, event.pid);
    q.cut = first_cut;
    try t.expectError(error.QueryExpired, core.inspection.read(&e, try i.sign(q, f.worker)));
    q.cut = page.cut;
    q.after = page.next.?;
    const end = try core.inspection.read(&e, try i.sign(q, f.worker));
    try t.expect(end.complete);
    try t.expectEqual(null, end.events[0]);
    // The final HEAD detects a writer/revocation racing the projection.
    f.store.race_at = f.store.tail_calls + 2;
    try t.expectError(error.Conflict, core.inspection.read(&e, try i.sign(q, f.worker)));
    f.store.race_at = null;
    e.state.history_floor = 10;
    try t.expectError(error.HistoryReclaimed, core.inspection.read(&e, try i.sign(q, f.worker)));
    q.cut = null;
    q.after = 0;
    page = try core.inspection.read(&e, try i.sign(q, f.worker));
    try t.expectEqual(.prefix_reclaimed, page.history);
    f.store.reclaimed = true;
    try t.expectError(error.HistoryReclaimed, core.inspection.read(&e, try i.sign(q, f.worker)));
    f.store.reclaimed = false;
    _ = try f.submit(&e, 0, .{ .revoke = 1 });
    // Old continuations and even nonexistent PIDs do not bypass revocation.
    q.cut = page.cut;
    q.pid = 999;
    try t.expectError(error.Forbidden, core.inspection.read(&e, try i.sign(q, f.worker)));
}

test "inspection links only disclosed endpoints and distinguishes mailbox completion" {
    const i = core.protocol.Inspection;
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const dest = try f.submit(&e, 0, .{ .spawn = .{} });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 0 } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(4) } });
    var outputs: [4]?core.Output = @splat(null);
    outputs[0] = .{ .pid = dest, .value = core.Value.integer(9) };
    const turn = try f.submit(&e, 0, .{ .turn = .{ .pid = pid, .generation = 2, .input = input, .result = core.Value.integer(4), .outputs = outputs } });
    const delivered = try f.submit(&e, 0, .{ .deliver = .{ .pid = dest, .output = 1, .courier = 0 } });
    var q: i.Query = .{ .realm = 42, .principal = 0, .resource = .outbox, .pid = pid };
    const full = try core.inspection.read(&e, try i.sign(q, f.root));
    try t.expectEqual(turn, full.outbox[0].?.turn);
    try t.expectEqual(delivered, full.outbox[0].?.resolved_at);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.inspect), .pid = pid } });
    q.principal = 1;
    const scoped = try core.inspection.read(&e, try i.sign(q, f.worker));
    try t.expectEqual(null, scoped.outbox[0]);
    q.resource = .mailbox;
    const mailbox = try core.inspection.read(&e, try i.sign(q, f.worker));
    try t.expectEqual(.consumed, mailbox.events[0].?.mailbox_status.?);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.inspect), .pid = dest } });
    q.pid = dest;
    const arrivals = try core.inspection.read(&e, try i.sign(q, f.worker));
    try t.expectEqual(.pending, arrivals.events[0].?.mailbox_status.?);
    try t.expectEqual(null, arrivals.events[0].?.output);
    try t.expectEqual(delivered, arrivals.events[0].?.position);
}

test "authenticated input origins survive recovery and cannot be chosen by payloads" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const source = try f.submit(&e, 0, .{ .spawn = .{} });
    const destination = try f.submit(&e, 0, .{ .spawn = .{} });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = source, .expected_generation = 0, .worker = 0 } });
    const forged = try core.Value.init("{\"source\":\"process\",\"pid\":1,\"correlation\":9}");
    _ = try f.submit(&e, 0, .{ .send = .{ .pid = source, .value = forged } });
    const external = (try e.nextInput(source, e.state.position)).?;
    try t.expectEqual(@as(u8, 0), (try e.state.inputOf(external)).origin.source.external.principal);
    const turn = try f.submit(&e, 0, .{ .turn = .{ .pid = source, .generation = 1, .input = external.position, .result = .{}, .effect = forged, .outputs = .{ .{ .pid = destination, .value = forged }, null, null, null } } });
    _ = try f.submit(&e, 0, .{ .deliver = .{ .pid = destination, .output = 1, .courier = 0 } });
    var recovered = try Engine.open(&f.store, f.genesis);
    const delivered = (try recovered.nextInput(destination, recovered.state.position)).?;
    const origin = (try recovered.state.inputOf(delivered)).origin;
    try t.expectEqual(source, origin.source.process.pid);
    try t.expectEqual(turn, origin.source.process.turn);
    try t.expectEqual(@as(u64, 1), origin.source.process.output);
    const attempt = try f.submit(&recovered, 0, .{ .dispatch = .{ .pid = source, .effect = turn } });
    _ = try f.submit(&recovered, 0, .{ .observe = .{ .pid = source, .effect = turn, .attempt = attempt, .result = forged } });
    const effect = (try recovered.nextInput(source, recovered.state.position)).?;
    try t.expectEqual(attempt, (try recovered.state.inputOf(effect)).origin.source.effect.attempt);
    // A corrupted durable origin must not survive replay even if its payload and
    // source/destination are otherwise valid. Application values remain opaque.
    f.store.entries.items[@intCast(delivered.position)].operation.origin.?.source.process.pid = destination;
    try t.expectError(error.InvalidAdmission, Engine.open(&f.store, f.genesis));
}

test "dedicated courier scopes delivery and reconciles lost receipts without admin or inspection" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const source = try f.submit(&e, 0, .{ .spawn = .{} });
    const destination = try f.submit(&e, 0, .{ .spawn = .{} });
    const other = try f.submit(&e, 0, .{ .spawn = .{} });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = source, .expected_generation = 0, .worker = 0 } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = source, .value = .{} } });
    _ = try f.submit(&e, 0, .{ .turn = .{ .pid = source, .generation = 1, .input = input, .result = .{}, .outputs = .{ .{ .pid = other, .value = .{} }, .{ .pid = destination, .value = .{} }, .{ .pid = destination, .value = .{} }, null } } });
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.delivery) | core.permission(.send), .pid = destination } });
    const query: core.protocol.Delivery.Query = .{ .realm = 42, .principal = 1 };
    const before = try core.delivery_read.read(&e, try core.protocol.Delivery.sign(query, f.worker));
    try t.expectEqual(@as(u16, 2), before.pending);
    try t.expectError(error.Forbidden, f.submit(&e, 1, .{ .inspect = destination }));
    try t.expectError(error.Forbidden, f.submit(&e, 1, .{ .terminate = destination }));
    const pending = try f.request(&e, 1, .{ .deliver_next = {} });
    f.store.fail_ack = true;
    try t.expectError(error.LostAcknowledgement, e.submit(pending));
    var recovered = try Engine.open(&f.store, f.genesis);
    _ = try recovered.submit(pending);
    try t.expectEqual(@as(u64, 1), (try recovered.state.process(destination)).admitted);
    try t.expectEqual(.pending, (try recovered.state.output(1)).phase);
    try t.expectEqual(.delivered, (try recovered.state.output(2)).phase);
    // Removing send rights records denial, while removing delivery rights stops
    // the courier entirely. Neither historical acceptance nor a cached read wins.
    _ = try f.submit(&recovered, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = core.permission(.delivery), .pid = destination } });
    _ = try f.submit(&recovered, 1, .{ .deliver_next = {} });
    try t.expectEqual(.denied, (try recovered.state.output(3)).phase);
    _ = try f.submit(&recovered, 0, .{ .revoke = 1 });
    try t.expectError(error.Forbidden, core.delivery_read.read(&recovered, try core.protocol.Delivery.sign(query, f.worker)));
    try t.expectError(error.Forbidden, recovered.submit(pending));
}
