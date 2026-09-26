const std = @import("std");
const t = std.testing;
const http = @import("root.zig");
const x = http.exchange;
const p = x.p;
const Turn = x.station.GrowingTurn;
const Frame = x.station.Frame;
const Service = http.Service;
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
fn request(buffer: []u8) !http.RequestRecord.Prepared {
    return http.RequestRecord.prepare(8, std.math.maxInt(u64), .{ .method = .POST, .target = &.{.{ .literal = "/write" }}, .body_bytes = 3 }, &.{ 0, 255, 1 }, 7, 9000, 2, buffer);
}
fn reply(turn: Turn) !Frame {
    const output = turn.decision.outputs[0] orelse return error.MissingReply;
    try t.expectEqual(@as(u64, 9), output.pid);
    const frame = try Frame.decode(output.value);
    try t.expectEqual(@as(u64, 99), frame.correlation);
    try t.expectEqual(.reply, frame.kind);
    return frame;
}
test "independent admission fixtures fix binary commitments routes and terminal outcomes" {
    const Fixture = struct { version: u32, request: http.Request, metadata: []const u8, body: p.Value, reference: p.Value, route: p.Value, outcome: p.Value, rejection: p.Value };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("admission-fixtures.json"), .{});
    defer parsed.deinit();
    const f = parsed.value;
    try t.expectEqual(@as(u32, 1), f.version);
    var buffer: [8192]u8 = undefined;
    const prepared = try request(&buffer);
    try t.expectEqualStrings(f.metadata, prepared.metadata);
    try t.expectEqual(try x.Publication.Digest.of(1, f.body.slice()), prepared.reference.bodySpec());
    try t.expect(f.reference.eql(try prepared.reference.encode()));
    inline for (.{ .{ http.RequestRecord.Reference, "reference" }, .{ Service.Route, "route" }, .{ Service.Outcome, "outcome" }, .{ Service.Rejection, "rejection" } }) |item| {
        const wire = @field(f, item[1]);
        const decoded = try x.codec.decode(item[0], wire);
        try t.expect((try x.codec.encode(decoded)).eql(wire));
        var bad = wire;
        bad.data[3] = '9';
        try t.expectError(error.InvalidExchangeRecord, x.codec.decode(item[0], bad));
        bad = wire;
        bad.len -= 1;
        bad.data[bad.len] = 0;
        try t.expectError(error.InvalidExchangeRecord, x.codec.decode(item[0], bad));
    }
    try t.expectEqual(std.math.maxInt(u64), (try Service.Outcome.decode(f.outcome)).exchange);
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
        _ = try ex.beginSegment(&turn, 0, 1, try x.Publication.Digest.of(1, ""));
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
            _ = try ex.finish(&turn, 200);
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
        try t.expectEqual(@as(u16, if (observed) 200 else 0), result.status);
        if (observed) {
            try t.expectEqualDeep(try ex.reference(&turn), try result.reference());
        } else try t.expectError(error.IncompleteExchange, result.reference());
        try store.commit(turn);
        turn = try store.capture(9, 99, wire);
        try t.expect(!try Service.publish(&turn, ex));
    }
}
test "request scope matches the serialized method target and case insensitive header allowlist" {
    const req: http.Request = .{ .method = .GET, .target = &.{ .{ .literal = "/search?q=" }, .{ .variable = .{ .name = "q", .value = "雪 &" } } }, .headers = &.{.{ .name = "X-Tag", .value = &.{.{ .literal = "one" }} }} };
    const scope: Service.Scope = .{ .method = .GET, .target = "/search?q=%E9%9B%AA%20%26", .headers = &.{"x-tag"} };
    var buffer: [8192]u8 = undefined;
    const rendered = try req.render("example.test", 443, &buffer, null, false);
    try Service.validateRequest(scope, req, rendered);
    inline for (.{ "/search", "/search?q=雪 &", "/admin", "/latest/meta-data/" }) |target| {
        var wrong = scope;
        wrong.target = target;
        try t.expectError(error.HttpRequestNotGranted, Service.validateRequest(wrong, req, rendered));
    }
    var wrong = scope;
    wrong.method = .POST;
    try t.expectError(error.HttpRequestNotGranted, Service.validateRequest(wrong, req, rendered));
    wrong = scope;
    wrong.headers = &.{};
    try t.expectError(error.HttpRequestNotGranted, Service.validateRequest(wrong, req, rendered));
}
test "request commitment validates body length and full width namespace without resolving credentials" {
    var buffer: [8192]u8 = undefined;
    const prepared = try request(&buffer);
    const ref = prepared.reference;
    try t.expectEqual(std.math.maxInt(u64), ref.namespace);
    try t.expectEqualDeep(ref, try http.RequestRecord.Reference.decode(try ref.encode()));
    try t.expectEqual(try x.Publication.Digest.of(1, &.{ 0, 255, 1 }), ref.bodySpec());
    const parsed = try std.json.parseFromSlice(http.Request, t.allocator, prepared.metadata, .{});
    defer parsed.deinit();
    try t.expectEqual(@as(u64, 3), parsed.value.body_bytes);
    try t.expectError(error.InvalidHttpBodyLength, http.RequestRecord.prepare(8, 1, .{ .method = .POST, .target = &.{.{ .literal = "/" }}, .body_bytes = 4 }, "cut", 7, 9000, 1, &buffer));
    var malformed = try ref.encode();
    malformed.len -= 1;
    malformed.data[malformed.len] = 0;
    try t.expectError(error.InvalidExchangeRecord, http.RequestRecord.Reference.decode(malformed));
}
