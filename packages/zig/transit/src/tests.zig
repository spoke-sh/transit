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
fn counter(state: i64, input: i64) !i64 {
    return std.math.add(i64, state, input);
}
const Engine = transit.Engine(Memory, counter);
const Fixture = struct {
    store: Memory = .{},
    root: transit.Ed25519.KeyPair,
    worker: transit.Ed25519.KeyPair,
    genesis: transit.Genesis,

    fn init() !Fixture {
        const root = try transit.Ed25519.KeyPair.generateDeterministic(@splat(7));
        return .{ .root = root, .worker = try transit.Ed25519.KeyPair.generateDeterministic(@splat(8)), .genesis = .{ .realm = 42, .root_key = root.public_key.toBytes() } };
    }
    fn request(self: *Fixture, engine: *Engine, caller: u8, command: transit.Command) !transit.SignedRequest {
        return transit.sign(.{ .realm = 42, .principal = caller, .sequence = (try engine.state.principal(caller)).sequence + 1, .command = command }, if (caller == 0) self.root else self.worker);
    }
    fn submit(self: *Fixture, engine: *Engine, caller: u8, command: transit.Command) !u64 {
        return engine.submit(try self.request(engine, caller, command));
    }
    fn setup(self: *Fixture, engine: *Engine) !u64 {
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
}
