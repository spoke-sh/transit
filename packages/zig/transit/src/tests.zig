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
