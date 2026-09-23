const std = @import("std");
const t = std.testing;
const transit = @import("root.zig");

const Memory = struct {
    entries: std.ArrayList(transit.Entry) = .empty,
    fail_ack: bool = false,
    pub fn tail(self: *Memory) !u64 {
        return self.entries.items.len;
    }
    pub fn read(self: *Memory, at: u64) !?transit.Entry {
        return if (at < self.entries.items.len) self.entries.items[@intCast(at)] else null;
    }
    pub fn append(self: *Memory, expected: u64, entry: transit.Entry) !bool {
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
fn counter(state: i64, input: i64) !transit.Decision {
    return .{ .state = try std.math.add(i64, state, input) };
}
const Engine = transit.Engine(Memory, counter);
const TestClock = struct {
    now: transit.Time.Sample,
    fn read(context: *anyopaque) !transit.Time.Sample {
        const self: *TestClock = @ptrCast(@alignCast(context));
        return self.now;
    }
    fn source(self: *TestClock) transit.Time.Source {
        return .{ .context = self, .read = read };
    }
};
const Fixture = struct {
    store: Memory = .{},
    root: transit.Ed25519.KeyPair,
    worker: transit.Ed25519.KeyPair,
    genesis: transit.Genesis,

    fn init() !Fixture {
        const root = try transit.Ed25519.KeyPair.generateDeterministic(@splat(7));
        return .{ .root = root, .worker = try transit.Ed25519.KeyPair.generateDeterministic(@splat(8)), .genesis = .{ .realm = 42, .root_key = root.public_key.toBytes() } };
    }
    fn request(self: *Fixture, engine: anytype, caller: u8, command: transit.Command) !transit.SignedRequest {
        return transit.sign(.{ .realm = 42, .principal = caller, .sequence = (try engine.state.principal(caller)).sequence + 1, .command = command }, if (caller == 0) self.root else self.worker);
    }
    fn submit(self: *Fixture, engine: anytype, caller: u8, command: transit.Command) !u64 {
        return engine.submit(try self.request(engine, caller, command));
    }
    fn setup(self: *Fixture, engine: anytype) !u64 {
        _ = try self.submit(engine, 0, .{ .grant = .{ .subject = 1, .public_key = self.worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.inspect) } });
        const pid = try self.submit(engine, 0, .{ .spawn = .{} });
        _ = try self.submit(engine, 0, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 1 } });
        return pid;
    }
};

test "canonical cross-language request fixture and strict schema" {
    const wire = "{\"version\":1,\"realm\":42,\"principal\":0,\"sequence\":1,\"command\":{\"send\":{\"pid\":3,\"value\":7}}}";
    var parsed = try std.json.parseFromSlice(transit.Request, t.allocator, wire, .{});
    defer parsed.deinit();
    const canonical = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
    defer t.allocator.free(canonical);
    try t.expectEqualStrings(wire, canonical);
    try t.expectError(error.UnknownField, std.json.parseFromSlice(transit.Request, t.allocator, "{\"realm\":42,\"principal\":0,\"sequence\":1,\"command\":{\"spawn\":{}},\"admin\":true}", .{}));
}

test "shared JSON request vectors preserve canonical bytes, digests and signatures" {
    const Vectors = struct {
        version: u32,
        seed_hex: []const u8,
        public_key: [32]u8,
        cases: []const struct { canonical: []const u8, sha256: []const u8, signature: [64]u8 },
    };
    var vectors = try std.json.parseFromSlice(Vectors, t.allocator, @embedFile("fixtures/requests-v1.json"), .{});
    defer vectors.deinit();
    try t.expectEqual(@as(u32, 1), vectors.value.version);
    var seed: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&seed, vectors.value.seed_hex);
    const key = try transit.Ed25519.KeyPair.generateDeterministic(seed);
    try t.expectEqualSlices(u8, &vectors.value.public_key, &key.public_key.toBytes());
    for (vectors.value.cases) |vector| {
        var parsed = try std.json.parseFromSlice(transit.Request, t.allocator, vector.canonical, .{});
        defer parsed.deinit();
        const canonical = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
        defer t.allocator.free(canonical);
        try t.expectEqualStrings(vector.canonical, canonical);
        var expected: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected, vector.sha256);
        try t.expectEqualSlices(u8, &expected, &transit.digest(parsed.value));
        try t.expectEqualSlices(u8, &vector.signature, &(try transit.sign(parsed.value, key)).signature);
        try transit.Ed25519.Signature.fromBytes(vector.signature).verify(&expected, key.public_key);
    }
}

test "shared valid and invalid sequence fixture survives recovery after every step" {
    const Trace = struct {
        version: u32,
        realm: u64,
        seed_hex: []const u8,
        steps: []const struct {
            realm: u64 = 42,
            sequence: u64,
            command: transit.Command,
            receipt: ?u64 = null,
            @"error": ?[]const u8 = null,
        },
    };
    var trace = try std.json.parseFromSlice(Trace, t.allocator, @embedFile("fixtures/sequences-v1.json"), .{});
    defer trace.deinit();
    try t.expectEqual(@as(u32, 1), trace.value.version);
    var seed: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&seed, trace.value.seed_hex);
    const key = try transit.Ed25519.KeyPair.generateDeterministic(seed);
    const genesis: transit.Genesis = .{ .realm = trace.value.realm, .root_key = key.public_key.toBytes() };
    const Workload = struct {
        fn reduce(state: i64, input: i64) !transit.Decision {
            return .{ .state = try std.math.add(i64, state, input), .effect = if (input == 9) 9 else null };
        }
    };
    const TraceEngine = transit.Engine(Memory, Workload.reduce);
    var store: Memory = .{};
    defer store.deinit();
    var engine = try TraceEngine.bootstrap(&store, genesis);
    for (trace.value.steps) |step| {
        const before = store.entries.items.len;
        const signed = try transit.sign(.{ .realm = step.realm, .principal = 0, .sequence = step.sequence, .command = step.command }, key);
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
    try t.expectEqual(@as(i64, 9), first.state);
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
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.admin), .pid = pid } });
    try t.expectError(error.Forbidden, f.submit(&e, 1, .{ .checkpoint = {} }));
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.admin) } });
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
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute), .pid = pid } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 1 } });
    for (0..4) |_| _ = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 1 } });
    try t.expectError(error.AdmissionClosed, f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 100 } }));
    try t.expectError(error.AdmissionClosed, f.submit(&e, 0, .{ .spawn = .{} }));
    try t.expectEqual(@as(u64, 4), (try e.state.process(pid)).admitted);
    try t.expectEqual(@as(u64, 0), (try e.state.process(pid)).cancelled);
    // Existing work can drain; starting new effects or outputs cannot consume
    // the control reserve or recursively create an unbounded backlog.
    try t.expectError(error.AdmissionClosed, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = 4, .result = 1, .effect = 1 } }));
    for (4..8) |input| {
        _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = @intCast(input - 3) } });
    }
    _ = try f.submit(&e, 0, .{ .revoke = 1 });
    try t.expectError(error.ControlAlreadyRecorded, f.submit(&e, 0, .{ .revoke = 1 }));
    _ = try f.submit(&e, 0, .{ .checkpoint = {} });
    try t.expectEqual(.running, (try e.state.process(pid)).lifecycle);
    try t.expectEqual(@as(i64, 4), (try e.state.process(pid)).state);
    var recovered = try Engine.open(&f.store, f.genesis);
    try t.expectError(error.AdmissionClosed, f.submit(&recovered, 0, .{ .send = .{ .pid = pid, .value = 1 } }));
    try t.expectError(error.ControlAlreadyRecorded, f.submit(&recovered, 0, .{ .checkpoint = {} }));
    // Explicit application/operator termination remains available. Capacity
    // itself never chooses to retire this unlimited-lifetime process.
    _ = try f.submit(&recovered, 0, .{ .terminate = pid });
    try t.expect(recovered.state.position < 8 + transit.controlRecordBudget(8));
}

test "payload deletion requires publication, owner retirement, opt-in and current grants" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.submit(&e, 0, .{ .spawn = .{} });
    const retained = try f.submit(&e, 0, .{ .declare_payload = .{ .pid = pid, .sha256 = @splat(1), .bytes = 1 } });
    const removed = try f.submit(&e, 0, .{ .declare_payload = .{ .pid = pid, .sha256 = @splat(2), .bytes = 1, .allow_delete = true } });
    const ref: transit.PayloadRef = .{ .pid = pid, .payload = removed };
    try t.expectError(error.PayloadInUse, f.submit(&e, 0, .{ .retire_payload = ref }));
    try t.expectError(error.PayloadPhase, f.submit(&e, 0, .{ .payload_deleted = ref }));
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.admin), .pid = pid } });
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

test "a verified handler failure blocks recovery without consuming the head" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.retry_policy = .last_per_principal;
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.submit(&e, 0, .{ .spawn = .{ .allow_trim = true } });
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute), .pid = pid } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 1 } });
    const first = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = std.math.maxInt(i64) } });
    const bad = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 1 } });
    try t.expectError(error.InvalidFailure, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = 0, .failed = true } }));
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = std.math.maxInt(i64) } });
    const failure = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = bad, .result = std.math.maxInt(i64), .failed = true } });
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
    changed.command.spawn.code = 2;
    try t.expectError(error.ConflictingRetry, recovered.submit(try transit.sign(changed, f.root)));
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
    const input = try f.submit(&a, 0, .{ .send = .{ .pid = pid, .value = 4 } });
    var b = try Engine.open(&f.store, f.genesis);
    const turn = try f.request(&a, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 4 } });
    const prepared = try a.prepare(turn);
    _ = try f.submit(&b, 0, .{ .revoke = 1 });
    try t.expectError(error.Conflict, a.commit(prepared));
    try t.expectError(error.Forbidden, a.submit(turn));
    try t.expectEqual(@as(i64, 0), (try a.state.process(pid)).state);
    try t.expectEqual(@as(u64, 0), (try a.state.process(pid)).consumed);
}

test "replacement ownership fences stale worker proposals while preserving the PID" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 5 } });
    const old = try f.request(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 5 } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 1 } });
    try t.expectError(error.StaleGeneration, e.submit(old));
    var new = old.request;
    new.command.turn.generation = 2;
    _ = try e.submit(try transit.sign(new, f.worker));
    var restored = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(@as(i64, 5), (try restored.state.process(pid)).state);
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
    const forbidden = try f.request(&e, 1, .{ .send = .{ .pid = pid, .value = 1 } });
    try t.expectError(error.Forbidden, e.submit(forbidden));
    const key = try transit.Ed25519.KeyPair.generateDeterministic(@splat(9));
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = key.public_key.toBytes(), .permissions = transit.permission(.inspect) } });
    try t.expectError(error.SignatureVerificationFailed, e.submit(valid));
    _ = try e.submit(try transit.sign(valid.request, key));
}

test "mailbox order rejects skipping and forged results; backlog is not retained in State" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const first = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 3 } });
    const second = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 7 } });
    try t.expectError(error.InvalidInput, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = second, .result = 7 } }));
    try t.expectError(error.InvalidResult, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = 900 } }));
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first, .result = 3 } });
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = second, .result = 10 } });
    for (0..100) |_| {
        _ = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 1 } });
    }
    var recovered = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(@as(i64, 10), (try recovered.state.process(pid)).state);
    try t.expectEqual(@as(u64, 102), (try recovered.state.process(pid)).admitted);
    try t.expectEqual(@as(u64, 2), (try recovered.state.process(pid)).consumed);
}

test "retired PID cannot be reactivated and unsupported finite contracts fail before admission" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    try t.expectError(error.UnsupportedDeadline, f.submit(&e, 0, .{ .spawn = .{ .deadline_ms = 30 } }));
    try t.expectError(error.UnsupportedWorkload, f.submit(&e, 0, .{ .spawn = .{ .code = 2 } }));
    try t.expectEqual(@as(u64, 1), try f.store.tail());
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .terminate = pid });
    try t.expectError(error.RetiredProcess, f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 1 } }));
    try t.expectError(error.RetiredProcess, f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 1 } }));
    try t.expect((try f.submit(&e, 0, .{ .spawn = .{} })) != pid);
}

test "poison input remains pending and cannot be skipped after arithmetic failure" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    const a = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = std.math.maxInt(i64) } });
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = a, .result = std.math.maxInt(i64) } });
    const b = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 1 } });
    try t.expectError(error.Overflow, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = b, .result = 0 } }));
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
    var checkpoint = try transit.Checkpoint.create(t.allocator, f.genesis, e.state);
    try checkpoint.validate(t.allocator, f.genesis);
    checkpoint.state.processes[0].?.state = 999;
    try t.expectError(error.InvalidCheckpoint, checkpoint.validate(t.allocator, f.genesis));
}

fn effectCounter(state: i64, input: i64) !transit.Decision {
    return .{ .state = try std.math.add(i64, state, input), .effect = if (input == 9) 9 else null };
}

test "only a committed intent permits one attempt and late evidence cannot revive its caller" {
    const EffectEngine = transit.Engine(Memory, effectCounter);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.effect), .pid = pid } });
    try t.expectError(error.UnknownEffect, f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = 99 } }));
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 9 } });
    try t.expectError(error.InvalidEffectIntent, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 9 } }));
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 9, .effect = 9 } });
    const attempt = try f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    var recovered = try EffectEngine.open(&f.store, f.genesis);
    try t.expectEqual(.authorized, (try recovered.state.effect(effect)).phase);
    try t.expectError(error.AttemptAlreadyAuthorized, f.submit(&recovered, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } }));
    try t.expectError(error.InvalidAttempt, f.submit(&recovered, 1, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = 1 } }));
    _ = try f.submit(&recovered, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = null } });
    try t.expectEqual(.unknown, (try recovered.state.effect(effect)).phase);
    _ = try f.submit(&recovered, 0, .{ .terminate = pid });
    _ = try f.submit(&recovered, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = 3 } });
    try t.expectEqual(.terminated, (try recovered.state.process(pid)).lifecycle);
    try t.expectEqual(@as(u64, 1), (try recovered.state.process(pid)).admitted);
    try t.expectEqual(@as(i64, 9), (try recovered.state.process(pid)).state);
    try t.expectEqual(.observed, (try recovered.state.effect(effect)).phase);
}

test "authenticated effect outcome becomes exactly one ordered mailbox input" {
    const EffectEngine = transit.Engine(Memory, effectCounter);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.effect) } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 9 } });
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 9, .effect = 9 } });
    const attempt = try f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    const outcome = try f.request(&e, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = 2 } });
    const position = try e.submit(outcome);
    try t.expectEqual(position, try e.submit(outcome));
    try t.expectEqual(@as(u64, 2), (try e.state.process(pid)).admitted);
    const message = (try e.nextInput(pid, e.state.position)).?;
    try t.expectEqual(position, message.position);
    _ = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = position, .result = 11 } });
    var replay = try EffectEngine.open(&f.store, f.genesis);
    try t.expectEqual(@as(i64, 11), (try replay.state.process(pid)).state);
}

test "revocation fences prepared dispatch; termination cancels only unattempted intents" {
    const EffectEngine = transit.Engine(Memory, effectCounter);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.effect) } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 9 } });
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 9, .effect = 9 } });
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
    const EffectEngine = transit.Engine(Memory, effectCounter);
    for ([_]bool{ false, true }) |close_wins| {
        var f = try Fixture.init();
        defer f.store.deinit();
        var e = try EffectEngine.bootstrap(&f.store, f.genesis);
        const pid = try f.setup(&e);
        _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.effect), .pid = pid } });
        const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 9 } });
        const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 9, .effect = 9 } });
        const attempt = try f.submit(&e, 1, .{ .dispatch = .{ .pid = pid, .effect = effect } });
        const response = try f.request(&e, 1, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = 2 } });
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
        try t.expectEqual(if (close_wins) @as(?i64, null) else 2, closed.result);
        try t.expectEqual(if (close_wins) @as(u64, 1) else 2, (try recovered.state.process(pid)).admitted);
        try t.expectError(error.ReconciliationClosed, f.submit(&recovered, 1, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = null } }));
        try t.expectError(error.AttemptAlreadyAuthorized, f.submit(&recovered, 1, .{ .dispatch = .{ .pid = pid, .effect = effect } }));
    }
}

test "closure needs executor or controller authority and cannot overwrite a result" {
    const EffectEngine = transit.Engine(Memory, effectCounter);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.effect), .pid = pid } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 9 } });
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 9, .effect = 9 } });
    const attempt = try f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    const close: transit.Command = .{ .close_effect = .{ .pid = pid, .effect = effect, .attempt = attempt } };
    try t.expectError(error.Forbidden, f.submit(&e, 1, close));
    try t.expectError(error.InvalidAttempt, f.submit(&e, 0, .{ .close_effect = .{ .pid = pid, .effect = effect, .attempt = attempt + 1 } }));
    _ = try f.submit(&e, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = 2 } });
    try t.expectError(error.ReconciliationClosed, f.submit(&e, 0, close));
    try t.expectEqual(@as(?i64, 2), (try e.state.effect(effect)).result);
}

test "revoking an executor fences its prepared closure but a controller can finish cleanup" {
    const EffectEngine = transit.Engine(Memory, effectCounter);
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.effect), .pid = pid } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 9 } });
    const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 9, .effect = 9 } });
    const attempt = try f.submit(&e, 1, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    const command: transit.Command = .{ .close_effect = .{ .pid = pid, .effect = effect, .attempt = attempt } };
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
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute), .pid = pid } });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 0 } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 7 } });
    try t.expectError(error.MissingTurnPermit, f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 7 } }));
    const permit = try f.submit(&e, 1, .{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } });
    clock.now.unix_ms = 110;
    try t.expectError(error.DeadlineExpired, f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 9 } }));
    try t.expectError(error.DeadlineExpired, f.submit(&e, 1, .{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } }));
    // Recovery transfers ownership, not the original work/settlement lifetime.
    var recovered = try Engine.open(&f.store, f.genesis);
    recovered.clock = clock.source();
    _ = try f.submit(&recovered, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 1 } });
    try t.expectError(error.StaleGeneration, f.submit(&recovered, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 7, .permit = permit } }));
    _ = try f.submit(&recovered, 1, .{ .turn = .{ .pid = pid, .generation = 2, .input = input, .result = 7, .permit = permit } });
    try t.expectEqual(@as(i64, 7), (try recovered.state.process(pid)).state);
    try t.expectError(error.DeadlineExpired, f.submit(&recovered, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 2 } }));
    try t.expectError(error.DeadlineNotReached, f.submit(&recovered, 0, .{ .expire = pid }));
    clock.now.unix_ms = 200;
    _ = try f.submit(&recovered, 0, (try recovered.state.nextMaintenance(clock.now)).?);
    var replay = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(.expired, (try replay.state.process(pid)).lifecycle);
    try t.expectEqual(@as(?transit.Command, null), try replay.state.nextMaintenance(clock.now));
    try t.expectError(error.RetiredProcess, f.submit(&replay, 0, .{ .send = .{ .pid = pid, .value = 1 } }));
}

test "uncertain time, missing clock, and rollback cannot authorize finite work" {
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 5;
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const spawn: transit.Command = .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 200 } };
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
    try t.expectError(error.ClockRollback, f.submit(&recovered, 0, .{ .send = .{ .pid = 1, .value = 1 } }));
    // Revocation and reads must remain available during clock failure.
    _ = try f.submit(&recovered, 0, .{ .inspect = 1 });
    clock.now.unix_ms = 90;
    try t.expectError(error.InvalidLifetime, f.submit(&recovered, 0, .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 99 } }));
}

test "reconciliation budgets survive restart and a missed timer cannot accept a late result" {
    const EffectEngine = transit.Engine(Memory, effectCounter);
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 0;
    var clock: TestClock = .{ .now = .{ .unix_ms = 10 } };
    var e = try EffectEngine.bootstrap(&f.store, f.genesis);
    e.clock = clock.source();
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.effect), .pid = pid } });
    for ([_]bool{ true, false }) |exhaust_budget| {
        const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 9 } });
        const result = (try e.state.process(pid)).state + 9;
        const effect = try f.submit(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = result, .effect = 9 } });
        const attempt = try f.submit(&e, 0, .{ .dispatch = .{ .pid = pid, .effect = effect, .reconcile_before_ms = 100, .max_observations = 2 } });
        const observe: transit.Command = .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = null } };
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
    try t.expectError(error.DeadlineExpired, f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 1 } }));
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
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 1 } });
    const permit = try f.submit(&e, 0, .{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } });
    clock.now.unix_ms = 30;
    try t.expectError(error.DeadlineExpired, f.submit(&e, 0, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .permit = permit, .result = 1 } }));
    _ = try f.submit(&e, 0, (try e.state.nextMaintenance(clock.now)).?);
    var recovered = try Engine.open(&f.store, f.genesis);
    const p = (try recovered.state.process(pid)).*;
    try t.expectEqual(.expired, p.lifecycle);
    try t.expectEqual(@as(u64, 0), p.consumed);
    try t.expectEqual(@as(u64, 1), p.cancelled);
    try t.expectEqual(@as(i64, 0), p.state);
    try t.expect(p.turn_permit == null);
}

fn fanout(state: i64, input: i64) !transit.Decision {
    var decision: transit.Decision = .{ .state = try std.math.add(i64, state, input) };
    if (input == 99) decision.outputs = .{ .{ .pid = 1, .value = 1 }, .{ .pid = 1, .value = 2 }, .{ .pid = 2, .value = 3 }, null };
    return decision;
}

test "provider observations cannot grant ownership; activation rotates keys atomically" {
    var f = try Fixture.init();
    defer f.store.deinit();
    var e = try Engine.bootstrap(&f.store, f.genesis);
    const pid = try f.setup(&e);
    _ = try f.submit(&e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.inspect), .pid = pid } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 7 } });
    const stale = try f.request(&e, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 7 } });
    var intent: transit.Runtime.Intent = .{ .pid = pid, .expected_revision = 0, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3) };
    const operation = try f.submit(&e, 0, .{ .runtime_intent = intent });
    try t.expectError(error.StaleGeneration, e.submit(stale));
    try t.expectError(error.RuntimeActivationRequired, f.submit(&e, 0, .{ .own = .{ .pid = pid, .expected_generation = 2, .worker = 1 } }));
    const replacement = try transit.Ed25519.KeyPair.generateDeterministic(@splat(10));
    var activation: transit.Runtime.Activate = .{ .pid = pid, .revision = 1, .expected_generation = 2, .worker = 1, .public_key = replacement.public_key.toBytes(), .worker_incarnation = @splat(4) };
    try t.expectError(error.ProviderNotReady, f.submit(&e, 0, .{ .activate = activation }));
    const observation: transit.Runtime.Observation = .{ .pid = pid, .revision = 1, .operation = operation, .incarnation = @splat(5), .outcome = .ready };
    _ = try f.submit(&e, 0, .{ .runtime_observe = observation });
    try t.expectEqual(@as(?u8, null), (try e.state.process(pid)).owner);
    // Replaying an already recorded provider outcome does not authorize a worker.
    var recovered = try Engine.open(&f.store, f.genesis);
    try t.expectEqual(@as(?u8, null), (try recovered.state.process(pid)).owner);
    _ = try f.submit(&recovered, 0, .{ .activate = activation });
    try t.expectError(error.SignatureVerificationFailed, recovered.submit(stale));
    f.worker = replacement;
    _ = try f.submit(&recovered, 1, .{ .turn = .{ .pid = pid, .generation = 3, .input = input, .result = 7 } });
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
    activation.public_key = (try transit.Ed25519.KeyPair.generateDeterministic(@splat(11))).public_key.toBytes();
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

fn seedOutbox(f: *Fixture, e: anytype) !void {
    for (0..3) |_| _ = try f.submit(e, 0, .{ .spawn = .{ .allow_trim = true } });
    _ = try f.submit(e, 0, .{ .own = .{ .pid = 3, .worker = 0, .expected_generation = 0 } });
    const input = try f.submit(e, 0, .{ .send = .{ .pid = 3, .value = 99 } });
    _ = try f.submit(e, 0, .{ .turn = .{ .pid = 3, .generation = 1, .input = input, .result = 99, .outputs = (try fanout(0, 99)).outputs } });
    _ = try f.submit(e, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.send) } });
}

test "outbox preserves each route's order, partial fanout, and uncertain admission receipts" {
    const OutboxEngine = transit.Engine(Memory, fanout);
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
    const OutboxEngine = transit.Engine(Memory, fanout);
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
    _ = try f.submit(&controller, 0, .{ .grant = .{ .subject = 1, .public_key = f.worker.public_key.toBytes(), .permissions = transit.permission(.send) } });
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
    const at = try f.submit(&e, 0, .{ .send = .{ .pid = pid, .value = 1 } });
    f.store.entries.items[@intCast(at)].operation.admission.?.value = 999;
    try t.expectError(error.InvalidAdmission, Engine.open(&f.store, f.genesis));
}

test "expired delivery is terminal without waiting for expiry maintenance" {
    const OutboxEngine = transit.Engine(Memory, fanout);
    var f = try Fixture.init();
    defer f.store.deinit();
    f.genesis.max_clock_error_ms = 0;
    var clock: TestClock = .{ .now = .{ .unix_ms = 10 } };
    var e = try OutboxEngine.bootstrap(&f.store, f.genesis);
    e.clock = clock.source();
    _ = try f.submit(&e, 0, .{ .spawn = .{ .deadline_ms = 20, .settle_before_ms = 30 } });
    for (0..2) |_| _ = try f.submit(&e, 0, .{ .spawn = .{} });
    _ = try f.submit(&e, 0, .{ .own = .{ .pid = 3, .worker = 0, .expected_generation = 0 } });
    const input = try f.submit(&e, 0, .{ .send = .{ .pid = 3, .value = 99 } });
    _ = try f.submit(&e, 0, .{ .turn = .{ .pid = 3, .generation = 1, .input = input, .result = 99, .outputs = (try fanout(0, 99)).outputs } });
    clock.now.unix_ms = 20;
    _ = try f.submit(&e, 0, .{ .deliver = .{ .pid = 1, .output = 1, .courier = 0 } });
    try t.expectEqual(.expired, (try e.state.output(1)).phase);
    try t.expectEqual(@as(u64, 0), (try e.state.process(1)).admitted);
    _ = try f.submit(&e, 0, .{ .deliver = .{ .pid = 2, .output = 3, .courier = 0 } });
    try t.expectEqual(@as(i64, 3), (try e.nextInput(2, e.state.position)).?.admission.?.value);
}
