const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const p = root.protocol;
const s = root.station;
const m = root.Model;
const c = root.Codec;
const Service = root.Service;
const Turn = s.GrowingTurn;
test "independent OpenSSL/Python fixtures pin command layouts and scoped signatures" {
    const Fixture = struct {
        version: u8,
        commands: []const struct { command: m.Command, hex: p.Value },
        public_key: [32]u8,
        read: m.SignedRead,
    };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/serving-v1.json"), .{});
    defer fixture.deinit();
    try t.expectEqual(@as(u8, 1), fixture.value.version);
    for (fixture.value.commands) |case| {
        try t.expect(case.hex.eql(try case.command.encode()));
        try t.expect(std.meta.eql(case.command, try m.Command.decode(case.hex)));
    }
    try fixture.value.read.verify(fixture.value.public_key);
}
const Store = struct {
    entries: std.AutoHashMap(p.Value, p.Value) = .init(t.allocator),
    position: u64 = 10,
    fail: bool = false,
    reads: usize = 0,
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) anyerror!?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.reads += 1;
        if (self.fail) return error.Unavailable;
        return self.entries.get(key);
    }
    fn turn(self: *Store, principal: u64, frame: s.Frame) !Turn {
        self.position += 1;
        return Turn.init(.{ .realm = 1, .principal = 77, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = self.position, .ordinal = 1, .value = try frame.encode(), .origin = .{ .external = .{ .principal = principal, .policy_revision = 1 } } }, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 77, .generation = 3, .input = self.position, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100000 }, .{ .context = self, .read = read });
    }
    fn commit(self: *Store, candidate: *Turn) !void {
        try candidate.validate();
        for (candidate.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.entries.put(mutation.key, value) else _ = self.entries.remove(mutation.key);
        };
    }
    fn command(self: *Store, owner: *Service, principal: u64, request: m.Command) !Turn {
        var out = try self.turn(principal, .{ .kind = .cast, .payload = try request.encode() });
        try owner.apply(&out, request, principal);
        return out;
    }
    fn setup(self: *Store, owner: *Service) !void {
        var boot = try self.turn(33, .{ .kind = .cast, .payload = try m.Command.encode(.initialize) });
        const handler = owner.interface();
        try handler.initialize.?(handler.context, &boot);
        try self.commit(&boot);
        var publish = try self.command(owner, 33, .{ .publish = .{ .expected = 0, .binding = binding(1, true) } });
        try self.commit(&publish);
        for ([_]u64{ 65536, 65537 }) |principal| {
            var rights = try self.command(owner, 33, .{ .policy = .{ .principal = principal, .expected = 0, .policy = .{ .revision = 1, .commands = true, .reads = true, .active_limit = 1 } } });
            try self.commit(&rights);
        }
    }
};
fn binding(revision: u64, published: bool) m.Binding {
    return .{ .revision = revision, .target = 88, .codec = 1, .active_limit = 2, .wait_before_ms = 10000, .published = published };
}
fn command(id: u64) m.Command {
    return .{ .submit = .{ .operation = id, .binding = 1, .codec = 1, .deadline_ms = 9999, .payload = p.Value.init("change") catch unreachable } };
}
fn service() Service {
    return .{ .configuration = .{ .service = 9, .administrator = 33, .observer = 34 } };
}

test "publication is conditional; duplicate identity freezes route and conflicts cannot retarget" {
    var store: Store = .{};
    defer store.entries.deinit();
    var owner = service();
    try store.setup(&owner);
    var first = try store.command(&owner, 65536, command(1));
    const input = first.delivery.input.position;
    try t.expectEqual(@as(u64, 88), first.decision.outputs[0].?.pid);
    try t.expect(first.decision.mutations[3] == null);
    const invocation = try c.decode(m.Invocation, 'i', (try s.Frame.decode(first.decision.outputs[0].?.value)).payload);
    try t.expectEqual(@as(u64, 65536), invocation.principal);
    try t.expectEqual(@as(u64, 9), invocation.service);
    try store.commit(&first);
    var update = binding(2, false);
    update.target = 89;
    var publication = try store.command(&owner, 33, .{ .publish = .{ .expected = 1, .binding = update } });
    try store.commit(&publication);
    try t.expectError(error.ServiceRevisionConflict, store.command(&owner, 33, .{ .publish = .{ .expected = 1, .binding = update } }));
    try t.expectError(error.ServingDenied, store.command(&owner, 65536, .{ .publish = .{ .expected = 2, .binding = binding(3, true) } }));
    var duplicate = try store.command(&owner, 65536, command(1));
    for (duplicate.decision.outputs) |output| try t.expect(output == null);
    const original = (try Service.operation(&duplicate, 65536, 1)).?;
    try t.expectEqual(@as(u64, 1), original.binding);
    try t.expectEqual(@as(u64, 88), original.target);
    try t.expectEqual(input, original.correlation);
    var changed = command(1);
    changed.submit.payload = try p.Value.init("different");
    try t.expectError(error.ServingIdentityConflict, store.command(&owner, 65536, changed));
    try t.expectError(error.ServiceUnpublished, store.command(&owner, 65536, command(2)));
}

test "quota survives gateway replacement; reply/cancel/timeout close slots without deleting history" {
    var store: Store = .{};
    defer store.entries.deinit();
    var owner = service();
    try store.setup(&owner);
    var first = try store.command(&owner, 65536, command(1));
    const correlation = first.delivery.input.position;
    try store.commit(&first);
    owner = service(); // no in-memory admission state survives or is needed
    try t.expectError(error.ServingCapacity, store.command(&owner, 65536, command(2)));
    var second = try store.command(&owner, 65537, command(1));
    const second_correlation = second.delivery.input.position;
    try store.commit(&second);
    var third_policy = try store.command(&owner, 33, .{ .policy = .{ .principal = 65538, .expected = 0, .policy = .{ .revision = 1, .commands = true, .reads = true, .active_limit = 1 } } });
    try store.commit(&third_policy);
    try t.expectError(error.ServingCapacity, store.command(&owner, 65538, command(1)));
    var reply = try store.turn(0, .{ .kind = .reply, .correlation = correlation, .payload = try p.Value.init("exact result") });
    reply.delivery.input.origin = .{ .process = .{ .pid = 88, .turn = 100, .output = 101 } };
    const guard = owner.guard();
    const handler = owner.interface();
    try t.expect(!try guard.reject(guard.context, &reply));
    _ = try reply.acceptReply();
    try handler.handle(handler.context, &reply, try s.Frame.decode(reply.delivery.input.value));
    try store.commit(&reply);
    try t.expectEqual(m.Phase.completed, (try Service.operation(&reply, 65536, 1)).?.phase);
    var third = try store.command(&owner, 65536, command(2));
    try store.commit(&third);
    var cancel = try store.command(&owner, 65536, .{ .cancel = 2 });
    try store.commit(&cancel);
    try t.expectEqual(m.Phase.cancelled, (try Service.operation(&cancel, 65536, 2)).?.phase);
    const observation = try s.Waiting.observation(second_correlation, 9999);
    var timeout = try store.turn(34, observation);
    try t.expect(!try guard.reject(guard.context, &timeout));
    try t.expect(!try s.Waiting.dispatch(&timeout, observation));
    try handler.handle(handler.context, &timeout, observation);
    try store.commit(&timeout);
    try t.expectEqual(m.Phase.timed_out, (try Service.operation(&timeout, 65537, 1)).?.phase);
    var late = try store.turn(34, observation);
    try t.expect(try s.Waiting.dispatch(&late, observation));
    try t.expect((try Service.operation(&late, 65536, 1)).?.result.eql(try p.Value.init("exact result")));
    for ((try Service.active(&late)).slots) |slot| try t.expectEqual(@as(u64, 0), slot.correlation);
    var dup = try store.command(&owner, 65536, command(1));
    try t.expect(dup.decision.outputs[0] == null);
    try t.expectEqual(correlation, (try Service.operation(&dup, 65536, 1)).?.correlation);
}

test "current policy, finite lifetime, malformed provenance and read outages fail distinctly" {
    var store: Store = .{};
    defer store.entries.deinit();
    var owner = service();
    try store.setup(&owner);
    var input = try store.turn(65536, .{ .kind = .cast, .payload = try command(1).encode() });
    input.delivery.work_before_ms = 100;
    try t.expectError(error.InvalidWaitLifetime, owner.apply(&input, command(1), 65536));
    try t.expect(input.decision.outputs[0] == null and input.decision.mutations[0] == null);
    input.delivery.work_before_ms = null;
    try t.expectError(error.ServingDenied, owner.apply(&input, command(1), 65537));
    const guard = owner.guard();
    input.delivery.input.value = try p.Value.init("bad frame");
    try t.expect(try guard.reject(guard.context, &input));
    var forged = try store.turn(65536, .{ .kind = .reply, .correlation = 100, .payload = .{} });
    try t.expect(try guard.reject(guard.context, &forged));
    var denied = try store.command(&owner, 33, .{ .policy = .{ .principal = 65536, .expected = 1, .policy = .{ .revision = 2, .commands = false, .reads = false, .active_limit = 1 } } });
    try store.commit(&denied);
    try t.expectError(error.ServingDenied, store.command(&owner, 65536, command(1)));
    store.fail = true;
    var failure = try store.turn(65537, .{ .kind = .cast, .payload = try command(1).encode() });
    try t.expectError(error.Unavailable, owner.apply(&failure, command(1), 65537));
    try t.expectError(error.Unavailable, failure.validate());
    try t.expect(failure.decision.mutations[0] == null);
}

test "retained operations grow while admission performs bounded point reads" {
    var store: Store = .{};
    defer store.entries.deinit();
    var owner = service();
    try store.setup(&owner);
    for (1..129) |index| {
        store.reads = 0;
        var admission = try store.command(&owner, 65536, command(index));
        try t.expect(store.reads <= 6);
        try store.commit(&admission);
        var cancellation = try store.command(&owner, 65536, .{ .cancel = index });
        try store.commit(&cancellation);
    }
    try t.expect(store.entries.count() > 256);
    var read = try store.turn(65536, .{ .kind = .cast, .payload = .{} });
    try t.expectEqual(m.Phase.cancelled, (try Service.operation(&read, 65536, 1)).?.phase);
}

test "scope signatures cannot reuse identity proof for another service or principal" {
    const pair = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const read: m.Read = .{ .realm = 1, .principal = 65536, .service = 9, .ingress = 2, .kind = .status, .operation = 1 };
    const signed = try m.SignedRead.sign(read, pair);
    try signed.verify(pair.public_key.toBytes());
    var forged = signed;
    forged.read.operation = 2;
    try t.expectError(error.SignatureVerificationFailed, forged.verify(pair.public_key.toBytes()));
    forged = signed;
    forged.identity.query.principal = 65537;
    try t.expectError(error.ServingDenied, forged.verify(pair.public_key.toBytes()));
    const other = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    try t.expectError(error.SignatureVerificationFailed, signed.verify(other.public_key.toBytes()));
}

test "canonical serving codecs enforce payload and trailing bytes at full-width identities" {
    var request = command(p.max_counter);
    request.submit.payload = try p.Value.init(&@as([64]u8, @splat(255)));
    const encoded = try request.encode();
    try t.expect(std.meta.eql(request, try m.Command.decode(encoded)));
    var trailing = encoded;
    trailing.len += 1;
    try t.expectError(error.InvalidServingRecord, m.Command.decode(trailing));
    request.submit.payload = try p.Value.init(&@as([65]u8, @splat(255)));
    try t.expectError(error.ServingPayloadTooLarge, request.encode());
    try t.expectEqual(@as(u16, 196), (try c.encode('a', m.Active{})).len);
    var op: m.Operation = .{ .principal = p.max_counter, .operation = p.max_counter, .binding = 1, .codec = 1, .deadline_ms = 100, .digest = @splat(255), .target = 88, .correlation = p.max_counter, .policy_revision = 1 };
    op.result = try p.Value.init(&@as([64]u8, @splat(255)));
    try t.expect(std.meta.eql(op, try c.decode(m.Operation, 'o', try c.encode('o', op))));
}

const reactive = root.ReactiveModel;
const Reactive = root.ReactiveService;
fn reactiveSetup(store: *Store, owner: *Service) !void {
    try store.setup(owner);
    var publication = try store.command(owner, 33, .{ .reactive = .{ .publish = .{ .expected = 0, .source = .{ .revision = 1, .target = 88, .resource = 8, .table = 1, .progress_key = try p.Value.init("data-progress"), .schema = @splat(5) } } } });
    try store.commit(&publication);
    var clock = try store.command(owner, 34, .{ .reactive = .{ .observe_clock = 1000 } });
    try store.commit(&clock);
}
fn openSession(store: *Store, owner: *Service, principal: u64, id: u64) !reactive.SessionIdentity {
    var candidate = try store.command(owner, principal, .{ .reactive = .{ .open = .{ .session = id, .source_revision = 1, .lease_before_ms = 5000 } } });
    const value = (try Reactive.session(&candidate, principal, id)).?;
    try store.commit(&candidate);
    return .{ .session = id, .generation = value.generation };
}
test "reactive aggregate quota survives reconstruction and closed history grows independently" {
    var store: Store = .{};
    defer store.entries.deinit();
    var owner = service();
    try reactiveSetup(&store, &owner);
    const first = try openSession(&store, &owner, 65536, 1);
    _ = try openSession(&store, &owner, 65536, 2);
    owner = service();
    try t.expectError(error.ReactiveCapacity, openSession(&store, &owner, 65536, 3));
    _ = try openSession(&store, &owner, 65537, 1);
    _ = try openSession(&store, &owner, 65537, 2);
    var other = try store.command(&owner, 33, .{ .policy = .{ .principal = 65538, .expected = 0, .policy = .{ .revision = 1, .commands = true, .reads = true, .active_limit = 1 } } });
    try store.commit(&other);
    try t.expectError(error.ReactiveCapacity, openSession(&store, &owner, 65538, 1));
    var close = try store.command(&owner, 65536, .{ .reactive = .{ .close = first } });
    try store.commit(&close);
    const original = try openSession(&store, &owner, 65536, 1);
    try t.expectEqual(first.generation, original.generation);
    try t.expectEqual(reactive.Phase.closed, (try Reactive.session(&close, 65536, 1)).?.phase);
    for (3..131) |id| {
        store.reads = 0;
        const next = try openSession(&store, &owner, 65536, id);
        try t.expect(store.reads <= 8);
        var done = try store.command(&owner, 65536, .{ .reactive = .{ .close = next } });
        try store.commit(&done);
    }
    try t.expect(store.entries.count() > 128);
    const old = (try Reactive.session(&close, 65536, 1)).?;
    try t.expectEqual(reactive.Phase.closed, old.phase);
    _ = try openSession(&store, &owner, 65538, 1);
}
test "conditional attachments and subscription generations fence delayed controls" {
    var store: Store = .{};
    defer store.entries.deinit();
    var owner = service();
    try reactiveSetup(&store, &owner);
    const identity = try openSession(&store, &owner, 65536, 1);
    try t.expectError(error.ReactiveSessionNotFound, store.command(&owner, 65537, .{ .reactive = .{ .close = identity } }));
    var request: m.Command = .{ .reactive = .{ .attach = .{ .identity = identity, .expected = 0, .nonce = @splat(8) } } };
    var attached = try store.command(&owner, 65536, request);
    try store.commit(&attached);
    try t.expectError(error.ReactiveAttachmentConflict, store.command(&owner, 65536, request));
    request.reactive.attach.expected = 1;
    request.reactive.attach.nonce = @splat(9);
    var replacement = try store.command(&owner, 65536, request);
    try store.commit(&replacement);
    const observed = (try Reactive.session(&replacement, 65536, 1)).?;
    try t.expectEqual(@as(u64, 2), observed.attachment);
    try t.expectEqual(@as([16]u8, @splat(9)), observed.nonce);
    request.reactive.attach.identity.generation += 1;
    try t.expectError(error.ReactiveGenerationConflict, store.command(&owner, 65536, request));
    var sub = try store.command(&owner, 65536, .{ .reactive = .{ .subscribe = .{ .identity = identity, .expected = 0, .subscription = 7, .operation = 11 } } });
    const generation = sub.delivery.input.position;
    try store.commit(&sub);
    const unsubscribe: m.Command = .{ .reactive = .{ .unsubscribe = .{ .identity = identity, .subscription = 7, .generation = generation } } };
    var removed = try store.command(&owner, 65536, unsubscribe);
    try store.commit(&removed);
    var resub = try store.command(&owner, 65536, .{ .reactive = .{ .subscribe = .{ .identity = identity, .expected = generation, .subscription = 7 } } });
    try store.commit(&resub);
    try t.expectError(error.ReactiveSubscriptionConflict, store.command(&owner, 65536, unsubscribe));
    // Session shutdown never cancels the separate application wait.
    var operation = try store.command(&owner, 65536, command(11));
    try store.commit(&operation);
    var done = try store.command(&owner, 65536, .{ .reactive = .{ .close = identity } });
    try store.commit(&done);
    try t.expectEqual(m.Phase.admitted, (try Service.operation(&done, 65536, 11)).?.phase);
}
test "authenticated monotonic observations, finite lease bounds, stale expiry and poisoned reads" {
    var store: Store = .{};
    defer store.entries.deinit();
    var owner = service();
    try reactiveSetup(&store, &owner);
    try t.expectError(error.ServingDenied, store.command(&owner, 65536, .{ .reactive = .{ .observe_clock = 5000 } }));
    const identity = try openSession(&store, &owner, 65536, 1);
    var request: m.Command = .{ .reactive = .{ .renew = .{ .identity = identity, .expected = 5000, .lease_before_ms = 6000 } } };
    var turn = try store.turn(65536, .{ .kind = .cast, .payload = try request.encode() });
    turn.resource_deadline_ms = 5999;
    try t.expectError(error.InvalidReactiveLease, owner.apply(&turn, request, 65536));
    try t.expect(turn.decision.mutations[0] == null);
    turn.resource_deadline_ms = null;
    turn.delivery.work_before_ms = 5999;
    try t.expectError(error.InvalidReactiveLease, owner.apply(&turn, request, 65536));
    var renewed = try store.command(&owner, 65536, request);
    try store.commit(&renewed);
    try t.expectError(error.ReactiveLeaseConflict, store.command(&owner, 65536, request));
    const expiry: m.Command = .{ .reactive = .{ .expire = .{ .principal = 65536, .identity = identity, .observed_ms = 5000 } } };
    try t.expectError(error.InvalidReactiveLease, store.command(&owner, 34, expiry));
    var advanced = try store.command(&owner, 34, .{ .reactive = .{ .observe_clock = 6000 } });
    try store.commit(&advanced);
    var backward = try store.command(&owner, 34, .{ .reactive = .{ .observe_clock = 1000 } });
    try store.commit(&backward);
    try t.expectEqual(@as(u64, 6000), try Reactive.clock(&backward));
    request.reactive.renew.expected = 6000;
    request.reactive.renew.lease_before_ms = 7000;
    try t.expectError(error.ReactiveSessionExpired, store.command(&owner, 65536, request));
    var expired = expiry;
    expired.reactive.expire.observed_ms = 6000;
    var terminal = try store.command(&owner, 34, expired);
    try store.commit(&terminal);
    var duplicate = try store.command(&owner, 34, expired);
    try t.expect(duplicate.decision.mutations[0] == null);
    try t.expectEqual(reactive.Phase.expired, (try Reactive.session(&duplicate, 65536, 1)).?.phase);
    store.fail = true;
    var failed = try store.turn(65536, .{ .kind = .cast, .payload = try request.encode() });
    const handler = owner.interface();
    try t.expectError(error.Unavailable, handler.handle(handler.context, &failed, try s.Frame.decode(failed.delivery.input.value)));
    try t.expectError(error.Unavailable, failed.validate());
    try t.expect(failed.decision.mutations[0] == null);
}

test "independent reactive lifecycle bytes, wide cursor and scoped read signatures" {
    const Fixture = struct {
        version: u8,
        commands: []const struct { command: m.Command, hex: p.Value },
        public_key: [32]u8,
        cursor: reactive.Cursor,
        cursor_hex: p.Value,
        read: reactive.SignedRead,
    };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/reactive-v1.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    try t.expectEqual(@as(u8, 1), fixture.version);
    for (fixture.commands) |case| {
        try t.expect(case.hex.eql(try case.command.encode()));
        try t.expect(std.meta.eql(case.command, try m.Command.decode(case.hex)));
        _ = try (s.Frame{ .kind = .cast, .payload = case.hex }).encode();
    }
    try t.expect(fixture.cursor_hex.eql(try fixture.cursor.encode()));
    try fixture.cursor.verify(fixture.public_key);
    try fixture.read.verify(fixture.public_key);
}
