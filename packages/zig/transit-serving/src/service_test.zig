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
