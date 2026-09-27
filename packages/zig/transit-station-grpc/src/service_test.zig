const std = @import("std");
const t = std.testing;
const rpc = @import("root.zig");
const x = rpc.exchange;
const p = x.p;
const Turn = x.station.GrowingTurn;
const Frame = x.station.Frame;
const Service = rpc.Service;
const limits: x.Limits = .{ .segment_bytes = 8192, .capture_bytes = 262144, .segments = 256 };
const policy: Service.Admission = .{ .caller = 9, .resource = 8, .endpoint_revision = 7, .reconcile_before_ms = 10000, .max_attempts = 3 };
const ex: x.Exchange = .{ .resource = 7, .id = 1 };
const Store = struct {
    state: std.AutoHashMapUnmanaged(p.Value, p.Value) = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    fn deinit(self: *Store) void {
        self.state.deinit(t.allocator);
    }
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        return @as(*Store, @ptrCast(@alignCast(raw))).state.get(key);
    }
    fn capture(self: *Store, caller: u64, correlation: u64, value: p.Value) !Turn {
        self.input += 1;
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = try (Frame{ .kind = .call, .correlation = correlation, .payload = value }).encode(), .origin = .{ .process = .{ .pid = caller, .turn = 10, .output = 11 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read });
    }
    fn commit(self: *Store, turn: Turn) !void {
        try turn.validate();
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.state.put(t.allocator, mutation.key, value) else _ = self.state.remove(mutation.key);
        };
        self.revision += 1;
    }
};
fn request(buffer: []u8) !struct { reference: rpc.RequestRecord.Reference } {
    var batch: [64]u8 = undefined;
    const prepared = try rpc.RequestRecord.prepare(8, std.math.maxInt(u64), .{ .method = "/service.Remote/Apply", .shape = .unary, .descriptor_digest = @splat(7) }, &.{"\x12\x02\x00\xff"}, 7, 9000, 2, buffer, &batch);
    return .{ .reference = prepared.reference };
}
fn reply(turn: Turn) !Frame {
    const output = turn.decision.outputs[0] orelse return error.MissingReply;
    try t.expectEqual(@as(u64, 9), output.pid);
    const frame = try Frame.decode(output.value);
    try t.expectEqual(@as(u64, 99), frame.correlation);
    try t.expectEqual(.reply, frame.kind);
    return frame;
}
test "admission commits a fixed caller route within four mutations and refuses conflicting calls" {
    var buffer: [8192]u8 = undefined;
    const ref = (try request(&buffer)).reference;
    const wire = try ref.encode();
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture(9, 99, wire);
    // Framework initialization occupies the remaining mutation slot.
    try turn.write(try p.Value.init("framework"), .{});
    try t.expectEqual(.admitted, try Service.admit(&turn, 1, policy, limits));
    for (turn.decision.mutations) |slot| try t.expect(slot != null);
    try t.expectEqual(null, turn.decision.effect);
    const input = turn.delivery.input.position;
    try store.commit(turn);
    turn = try store.capture(9, 99, wire);
    try t.expectEqual(.duplicate, try Service.admit(&turn, 1, policy, limits));
    try t.expectEqual(input, (try Service.route(ex, &turn)).?.input);
    try t.expectEqual(null, turn.decision.outputs[0]);
    turn = try store.capture(9, 100, wire);
    try t.expectEqual(.rejected, try Service.admit(&turn, 1, policy, limits));
    const busy = try Frame.decode(turn.decision.outputs[0].?.value);
    try t.expectEqual(.busy, (try x.codec.decode(Service.Rejection, busy.payload)).reason);
    turn = try store.capture(9, 99, wire);
    try t.expectError(error.UnsettledExchange, Service.publish(&turn, ex));
    try t.expectEqual(null, turn.decision.outputs[0]);
    _ = try ex.closeUnknown(&turn);
    try store.commit(turn);
    turn = try store.capture(9, 99, wire);
    try t.expect(try Service.publish(&turn, ex));
    const outcome = try Service.Outcome.decode((try reply(turn)).payload);
    try t.expectEqual(.not_dispatched, outcome.phase);
    try t.expectError(error.IncompleteExchange, outcome.reference());
    try store.commit(turn);
    turn = try store.capture(9, 99, wire);
    try t.expect(!try Service.publish(&turn, ex));
    try t.expectEqual(null, turn.decision.outputs[0]);
}
test "admission checks authenticated origin and every policy dimension without creating an exchange" {
    var buffer: [8192]u8 = undefined;
    const ref = (try request(&buffer)).reference;
    var store: Store = .{};
    defer store.deinit();
    inline for (.{ "caller", "resource", "endpoint_revision", "reconcile_before_ms", "max_attempts" }) |field| {
        var denied = policy;
        @field(denied, field) = 1;
        var turn = try store.capture(9, 99, try ref.encode());
        try t.expectEqual(.rejected, try Service.admit(&turn, 1, denied, limits));
        try t.expectEqual(.denied, (try x.codec.decode(Service.Rejection, (try reply(turn)).payload)).reason);
        for (turn.decision.mutations) |slot| try t.expectEqual(null, slot);
    }
    var turn = try store.capture(9, 99, try p.Value.init("bad"));
    try t.expectEqual(.rejected, try Service.admit(&turn, 1, policy, limits));
    try t.expectEqual(.invalid_request, (try x.codec.decode(Service.Rejection, (try reply(turn)).payload)).reason);
    turn = try store.capture(9, 99, try ref.encode());
    turn.delivery.input.origin = .{ .external = .{ .principal = 9, .policy_revision = 1 } };
    try t.expectError(error.ExpectedProcessOrigin, Service.admit(&turn, 1, policy, limits));
    for (turn.decision.mutations) |slot| try t.expectEqual(null, slot);
}
test "outcome publication waits for settlement and atomically records its original reply destination" {
    inline for (.{ false, true }) |observed| {
        var buffer: [8192]u8 = undefined;
        const wire = try (try request(&buffer)).reference.encode();
        var store: Store = .{};
        defer store.deinit();
        var turn = try store.capture(9, 99, wire);
        _ = try Service.admit(&turn, 1, policy, limits);
        try store.commit(turn);
        turn = try store.capture(9, 99, wire);
        _ = try ex.beginSegment(&turn, 0, 1, try x.Publication.Digest.of(2, ""));
        try store.commit(turn);
        turn = try store.capture(9, 99, wire);
        _ = try ex.sealSegment(&turn, 0);
        try store.commit(turn);
        turn = try store.capture(9, 99, wire);
        _ = try ex.commitIntent(&turn);
        var effect: p.Growth.Effect = .{ .id = 19, .pid = 2, .payload = turn.decision.effect.?, .phase = .authorized, .attempt = 20, .executor = 7, .reconcile_before_ms = 9000 };
        try store.commit(turn);
        turn = try store.capture(9, 99, wire);
        if (observed) {
            _ = try ex.bind(&turn, effect);
            _ = try ex.finish(&turn, 1);
            effect.phase = .observed;
            effect.result = try (try ex.reference(&turn)).encode();
        } else {
            _ = try ex.closeUnknown(&turn);
            effect.phase = .closed_unknown;
        }
        try store.commit(turn);
        turn = try store.capture(9, 99, wire);
        try t.expectError(error.UnsettledExchange, Service.publish(&turn, ex));
        _ = try ex.settle(&turn, effect);
        try store.commit(turn);
        turn = try store.capture(9, 99, wire);
        for (0..4) |i| try turn.write(try p.Value.init(&.{ 'k', @intCast(i) }), .{});
        try t.expectError(error.MutationBudgetExceeded, Service.publish(&turn, ex));
        try t.expectEqual(null, turn.decision.outputs[0]);
        turn = try store.capture(99, 999, wire);
        // Later control input and identities do not replace the admitted route.
        try t.expect(try Service.publish(&turn, ex));
        const result = try Service.Outcome.decode((try reply(turn)).payload);
        try t.expectEqual(@as(u64, 19), result.effect);
        try t.expectEqual(@as(u64, 20), result.attempt);
        try t.expectEqual(@as(u32, 0), result.status);
        if (observed) {
            try t.expectEqualDeep(try ex.reference(&turn), try result.reference());
        } else try t.expectError(error.IncompleteExchange, result.reference());
        try store.commit(turn);
        turn = try store.capture(9, 99, wire);
        try t.expect(!try Service.publish(&turn, ex));
        try t.expectError(error.ExchangeHasDependents, ex.retire(&turn));
        _ = try ex.retain(&turn, 123, 999);
        try store.commit(turn);
        const disposal = try (Service.Release{ .resource = ex.resource, .exchange = ex.id }).encode();
        turn = try store.capture(9, 99, disposal);
        // Reply capacity failure must roll back the durable caller release.
        for (0..turn.decision.outputs.len) |_| try turn.send(8, .{ .kind = .cast, .payload = .{} });
        const before = turn.decision;
        try t.expectError(error.OutputBudgetExceeded, Service.release(&turn, ex, policy));
        try t.expectEqualDeep(before, turn.decision);
        turn = try store.capture(9, 99, disposal);
        try Service.release(&turn, ex, policy);
        const released = try Service.Released.decode((try reply(turn)).payload);
        try t.expectEqual(ex.id, released.exchange);
        try t.expectEqual(ex.resource, released.resource);
        try store.commit(turn);
        turn = try store.capture(9, 99, disposal);
        try t.expectEqual(.released, (try ex.control(&turn)).caller);
        try t.expectEqual(@as(u64, 1), (try ex.control(&turn)).dependents);
        try t.expectError(error.ExchangeHasDependents, ex.retire(&turn));
        _ = try ex.release(&turn, 123, 999);
        _ = try ex.retire(&turn);
        try store.commit(turn);
        turn = try store.capture(9, 99, disposal);
        try Service.release(&turn, ex, policy);
        try t.expectEqualDeep(released, try Service.Released.decode((try reply(turn)).payload));
        for (turn.decision.mutations) |slot| try t.expectEqual(null, slot);
    }
}

test "RPC service scope binds exact method descriptor shape and metadata keys" {
    const req: rpc.Request = .{ .method = "/service.Remote/Apply", .shape = .bidi, .descriptor_digest = @splat(7), .metadata = &.{.{ .name = "x-approved", .value = .{ .literal = "value" } }} };
    const scope: Service.Scope = .{ .method = req.method, .shape = req.shape, .descriptor_digest = req.descriptor_digest, .metadata = &.{"x-approved"} };
    try Service.validateRequest(scope, req);
    var changed = scope;
    changed.method = "/service.Remote/Admin";
    try t.expectError(error.GrpcRequestNotGranted, Service.validateRequest(changed, req));
    changed = scope;
    changed.shape = .unary;
    try t.expectError(error.GrpcRequestNotGranted, Service.validateRequest(changed, req));
    changed = scope;
    changed.descriptor_digest[0] ^= 1;
    try t.expectError(error.GrpcRequestNotGranted, Service.validateRequest(changed, req));
    changed = scope;
    changed.metadata = &.{};
    try t.expectError(error.GrpcRequestNotGranted, Service.validateRequest(changed, req));
    try t.expectError(error.InvalidGrpcOutcome, Service.observedStatus(0));
    try t.expectError(error.InvalidGrpcOutcome, Service.observedStatus(18));
    try t.expectEqual(@as(u32, 0), try Service.observedStatus(1));
    try t.expectEqual(@as(u32, 16), try Service.observedStatus(17));
}

test "independent service records preserve OK versus unknown and full-width routing identities" {
    const Fixture = struct { route_hex: []const u8, outcome_ok_hex: []const u8, outcome_unknown_hex: []const u8, rejection_hex: []const u8, release_hex: []const u8, released_hex: []const u8, followup_hex: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/service.json"), .{});
    defer parsed.deinit();
    var buffer: [256]u8 = undefined;
    inline for (.{ .{ Service.Route, "route_hex" }, .{ Service.Outcome, "outcome_ok_hex" }, .{ Service.Outcome, "outcome_unknown_hex" }, .{ Service.Rejection, "rejection_hex" }, .{ Service.Release, "release_hex" }, .{ Service.Released, "released_hex" }, .{ Service.Followup, "followup_hex" } }) |item| {
        const bytes = try std.fmt.hexToBytes(&buffer, @field(parsed.value, item[1]));
        const record = try x.codec.decode(item[0], try p.Value.init(bytes));
        try t.expectEqualSlices(u8, bytes, (try x.codec.encode(record)).slice());
        for (0..bytes.len) |len| try t.expectError(error.InvalidExchangeRecord, x.codec.decode(item[0], try p.Value.init(bytes[0..len])));
    }
    const ok = try Service.Outcome.decode(try p.Value.init(try std.fmt.hexToBytes(&buffer, parsed.value.outcome_ok_hex)));
    try t.expectEqual(@as(u32, 0), ok.status);
    try t.expectEqual(std.math.maxInt(u64), (try ok.reference()).exchange);
    const unknown = try Service.Outcome.decode(try p.Value.init(try std.fmt.hexToBytes(&buffer, parsed.value.outcome_unknown_hex)));
    try t.expectEqual(@as(u32, 0), unknown.status);
    try t.expectError(error.IncompleteExchange, unknown.reference());
    var wrong = try Service.Followup.decode(try p.Value.init(try std.fmt.hexToBytes(&buffer, parsed.value.followup_hex)));
    wrong.reason = .redirect;
    try t.expectError(error.InvalidGrpcFollowup, wrong.validate());
}
