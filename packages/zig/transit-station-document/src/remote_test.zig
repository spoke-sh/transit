const std = @import("std");
const t = std.testing;
const lib = @import("root.zig");
const s = lib.station;
const p = s.protocol;
const Turn = s.GrowingTurn;
const Store = @import("test_store.zig");
const Request = lib.Request;
const Remote = lib.Remote;
const service: lib.Service = .{ .resource = 7, .document = 17 };
const policy: Remote.Policy = .{ .caller = 3, .resource = 8, .replica = 1, .revision = 5 };
const Source = struct {
    store: *Store,
    opens: usize = 0,
    deny_at: ?usize = null,
    pub fn open(self: *@This(), resource: u64) !Turn {
        self.opens += 1;
        if (self.deny_at) |at| if (self.opens >= at) return error.AccessDenied;
        if (resource != self.store.resource) return error.ResourceUnavailable;
        return self.store.capture();
    }
};
fn change() !lib.Change {
    var out: lib.Change = .{ .document = 17, .epoch = 1, .replica = 1, .first = 1, .len = 2 };
    out.operations[0] = .{ .assign = .{ .field = try lib.Model.Name.init("body"), .value = .text } };
    out.operations[1] = .{ .insert = .{ .object = out.id(0), .value = .{ .character = 0x1f642 } } };
    return out;
}
fn setup(store: *Store) !void {
    var turn = try store.capture();
    try service.create(&turn, 1, .{ .record_bytes = 4096, .staging_bytes = 4096, .staging_records = 1 });
    try store.commit(turn);
}
fn publish(store: *Store, namespace: u64, value: lib.Change) !Request.Reference {
    const reference = try Request.prepare(store.resource, namespace, 5, value);
    for (0..32) |_| {
        var turn = try store.capture();
        const done = try Request.stage(&turn, reference, value);
        try store.commit(turn);
        if (done) return reference;
    }
    return error.UploadDidNotComplete;
}
fn call(store: *Store, caller: u64, correlation: u64, payload: p.Value) !Turn {
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .process = .{ .pid = caller, .turn = 10, .output = 11 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .call, .correlation = correlation, .payload = payload }).encode();
    return turn;
}
fn response(turn: Turn, caller: u64, correlation: u64) !Remote.Reply {
    const output = turn.decision.outputs[0].?;
    try t.expectEqual(caller, output.pid);
    const frame = try s.Frame.decode(output.value);
    try t.expectEqual(.reply, frame.kind);
    try t.expectEqual(correlation, frame.correlation);
    for (turn.decision.outputs[1..]) |extra| try t.expectEqual(null, extra);
    return Remote.Reply.decode(frame.payload);
}
fn clean(turn: Turn) !void {
    for (turn.decision.mutations) |mutation| try t.expectEqual(null, mutation);
    for (turn.decision.outputs) |output| try t.expectEqual(null, output);
}
fn finish(store: *Store, source: *Source) !Remote.Reply {
    for (0..1000) |_| {
        var turn = try store.capture();
        const result = try Remote.advance(service, &turn, policy, source);
        if (result == .idle) return error.MissingDocumentJob;
        if (result != .progress) {
            const reply = try response(turn, 3, 41);
            try store.commit(turn);
            return reply;
        }
        try store.commit(turn);
    }
    return error.DocumentDidNotComplete;
}
test "independent remote codecs fit frames and preserve full width identities" {
    const Fixture = struct { change_hex: []const u8, request_hex: []const u8, reply_hex: []const u8, route_hex: []const u8, call_hex: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/remote.json"), .{});
    defer fixture.deinit();
    var bytes: [4096]u8 = undefined;
    const value = try lib.codec.decode(try std.fmt.hexToBytes(&bytes, fixture.value.change_hex));
    const expected = try p.Value.init(try std.fmt.hexToBytes(&bytes, fixture.value.request_hex));
    const request = try Request.prepare(p.max_counter, std.math.maxInt(u64), std.math.maxInt(u64), value);
    try t.expect(expected.eql(try request.encode()));
    try t.expectEqualDeep(request, try Request.Reference.decode(expected));
    try t.expectEqual(@as(u16, 109), (try (s.Frame{ .kind = .call, .correlation = 1, .payload = expected }).encode()).len);
    const reply_bytes = try p.Value.init(try std.fmt.hexToBytes(&bytes, fixture.value.reply_hex));
    const reply = try Remote.Reply.decode(reply_bytes);
    try t.expectEqual(@as(u64, 42), reply.basis.?.revision);
    try t.expect(reply_bytes.eql(try reply.encode()));
    const route_bytes = try p.Value.init(try std.fmt.hexToBytes(&bytes, fixture.value.route_hex));
    const route = try Remote.Route.decode(route_bytes);
    try t.expectEqual(std.math.maxInt(u64), route.correlation);
    try t.expectEqual(try Remote.jobId(route.input), reply.job);
    try t.expect(route_bytes.eql(try route.encode()));
    const call_bytes = try p.Value.init(try std.fmt.hexToBytes(&bytes, fixture.value.call_hex));
    const saved = try lib.Caller.Call.decode(call_bytes);
    try t.expectEqual(std.math.maxInt(u64), saved.correlation);
    try t.expect(call_bytes.eql(try saved.encode()));
    inline for (.{ Request.Reference, Remote.Reply, Remote.Route, lib.Caller.Call }, .{ expected, reply_bytes, route_bytes, call_bytes }) |Type, encoded| {
        for (0..encoded.len) |i| if (Type.decode(try p.Value.init(encoded.slice()[0..i]))) |_| return error.TruncatedRemoteAccepted else |_| {};
        var extra = encoded;
        extra.data[extra.len] = 0;
        extra.len += 1;
        try t.expectError(error.InvalidDocumentEncoding, Type.decode(extra));
    }
    var bad = reply_bytes;
    bad.data[4] = 255;
    try t.expectError(error.InvalidDocumentReply, Remote.Reply.decode(bad));
    try t.expectError(error.InvalidDocumentReply, (Remote.Reply{ .status = .accepted, .job = 1, .basis = null }).encode());
}
test "remote policy binds authenticated caller, replica and request resource without leaking denied metadata" {
    var caller: Store = .{ .resource = 8 };
    defer caller.deinit();
    const request = try publish(&caller, 100, try change());
    var source: Source = .{ .store = &caller };
    var writer: Store = .{};
    defer writer.deinit();
    try setup(&writer);
    var turn = try call(&writer, 4, 41, try request.encode());
    try t.expectEqual(.rejected, try Remote.admit(service, &turn, policy, &source, 256));
    const denied = try response(turn, 4, 41);
    try t.expectEqual(.denied, denied.reason);
    try t.expectEqual(null, denied.basis);
    try t.expectEqual(@as(usize, 0), source.opens);
    var impersonation = request;
    impersonation.replica = 2;
    turn = try call(&writer, 3, 41, try impersonation.encode());
    try t.expectEqual(.rejected, try Remote.admit(service, &turn, policy, &source, 256));
    try t.expectEqual(.denied, (try response(turn, 3, 41)).reason);
    turn = try call(&writer, 3, 41, try request.encode());
    turn.delivery.input.origin = .{ .external = .{ .principal = 3, .policy_revision = 5 } };
    try t.expectError(error.ExpectedProcessOrigin, Remote.admit(service, &turn, policy, &source, 256));
    try clean(turn);
    var forged = request;
    forged.document = 18;
    // Matching policy cannot make the published change acquire a different identity.
    try t.expectError(error.InvalidDocumentRequest, Request.read(&source, forged));
    var corrupt = request;
    corrupt.spec.digest[0] ^= 1;
    try t.expectError(error.InvalidDocumentRequest, Request.read(&source, corrupt));
}
test "every remote step recovers from private loss and final success uses original route within four mutations" {
    var caller: Store = .{ .resource = 8 };
    defer caller.deinit();
    const request = try publish(&caller, 100, try change());
    var source: Source = .{ .store = &caller };
    var writer: Store = .{};
    defer writer.deinit();
    try setup(&writer);
    var admission = try call(&writer, 3, 41, try request.encode());
    const id = try Remote.jobId(admission.delivery.input.position);
    try t.expectEqual(.admitted, try Remote.admit(service, &admission, policy, &source, 256));
    try admission.write(try p.Value.init("framework"), try p.Value.init("admitted"));
    try writer.commit(admission);
    var blocked = try call(&writer, 3, 42, try request.encode());
    try t.expectEqual(.rejected, try Remote.admit(service, &blocked, policy, &source, 256));
    try t.expectEqual(.busy, (try response(blocked, 3, 42)).reason);
    for (0..1000) |_| {
        var lost = try writer.capture();
        const first = try Remote.advance(service, &lost, policy, &source);
        var turn = try writer.capture();
        try t.expectEqual(@as(u64, 0), (try service.head(&turn)).state.revision);
        const second = try Remote.advance(service, &turn, policy, &source);
        try t.expectEqual(first, second);
        try t.expectEqualDeep(lost.decision, turn.decision);
        try turn.write(try p.Value.init("framework"), try p.Value.init("progress"));
        if (second == .accepted) {
            var saturated = try writer.capture();
            for (0..4) |_| try saturated.cast(9, try p.Value.init("occupied"));
            const before = saturated.decision;
            try t.expectError(error.OutputBudgetExceeded, Remote.advance(service, &saturated, policy, &source));
            try t.expectEqualDeep(before, saturated.decision);
            const accepted = try response(turn, 3, 41);
            try t.expectEqual(id, accepted.job);
            try t.expectEqual(@as(u64, 1), accepted.basis.?.revision);
            try writer.commit(turn);
            break;
        }
        try t.expectEqual(.progress, second);
        try writer.commit(turn);
    } else return error.DocumentDidNotComplete;
    try t.expectEqual(@as(usize, 1), writer.accepted_outputs);
    var done = try writer.capture();
    try t.expectEqual(.idle, try Remote.advance(service, &done, policy, &source));
    try clean(done);
    // A new call with the same change has its own route and returns the original revision.
    admission = try call(&writer, 3, 41, try request.encode());
    try t.expectEqual(.admitted, try Remote.admit(service, &admission, policy, &source, 256));
    try writer.commit(admission);
    const duplicate = try finish(&writer, &source);
    try t.expectEqual(.duplicate, duplicate.status);
    try t.expectEqual(@as(u64, 1), duplicate.basis.?.revision);
}
test "revocation, changed service policy and PID replacement leave the pending job recoverable" {
    var caller: Store = .{ .resource = 8 };
    defer caller.deinit();
    const request = try publish(&caller, 100, try change());
    var source: Source = .{ .store = &caller };
    var writer: Store = .{};
    defer writer.deinit();
    try setup(&writer);
    var turn = try call(&writer, 3, 41, try request.encode());
    _ = try Remote.admit(service, &turn, policy, &source, 256);
    try writer.commit(turn);
    for (0..32) |_| {
        turn = try writer.capture();
        const head = try service.head(&turn);
        if ((try service.job(&turn, head.active_job)).phase == .building) break;
        _ = try Remote.advance(service, &turn, policy, &source);
        try writer.commit(turn);
    } else return error.UploadDidNotComplete;
    source.deny_at = source.opens + 1;
    turn = try writer.capture();
    try t.expectError(error.AccessDenied, Remote.advance(service, &turn, policy, &source));
    try clean(turn);
    source.deny_at = null;
    var replacement_policy = policy;
    replacement_policy.revision += 1;
    try t.expectError(error.AccessDenied, Remote.advance(service, &turn, replacement_policy, &source));
    try clean(turn);
    turn.delivery.pid = 9;
    try t.expectError(error.InvalidDocumentRoute, Remote.advance(service, &turn, policy, &source));
    try clean(turn);
    try t.expectEqual(.accepted, (try finish(&writer, &source)).status);
}
test "request upload freezes identity and each verified chunk rechecks current access" {
    var caller: Store = .{ .resource = 8 };
    defer caller.deinit();
    var value = try change();
    value.len = 4;
    value.operations[2] = .{ .assign = .{ .field = try lib.Model.Name.init("a"), .value = .{ .binary = try lib.Model.Bytes.init(&@as([96]u8, @splat(1))) } } };
    value.operations[3] = .{ .assign = .{ .field = try lib.Model.Name.init("b"), .value = .{ .binary = try lib.Model.Bytes.init(&@as([96]u8, @splat(2))) } } };
    const request = try publish(&caller, 100, value);
    try t.expect(request.spec.length > 256);
    var source: Source = .{ .store = &caller, .deny_at = 2 };
    try t.expectError(error.AccessDenied, Request.read(&source, request));
    try t.expectEqual(@as(usize, 2), source.opens);
    source.deny_at = null;
    _ = try Request.read(&source, request);
    var turn = try caller.capture();
    var changed = request;
    changed.policy_revision += 1;
    try t.expectError(error.PublicationUploadIdentityConflict, Request.stage(&turn, changed, value));
    try clean(turn);
    _ = try request.publication().retire(&turn, Request.record);
    try caller.commit(turn);
    try t.expectError(error.PublicationNotPublished, Request.check(&source, request));
}
test "dependency rejection closes its candidate atomically and delayed calls cannot revive retirement" {
    var caller: Store = .{ .resource = 8 };
    defer caller.deinit();
    var value = try change();
    value.previous = 3;
    value.first = 4;
    value.len = 1;
    const request = try publish(&caller, 100, value);
    var source: Source = .{ .store = &caller };
    var writer: Store = .{};
    defer writer.deinit();
    try setup(&writer);
    var turn = try call(&writer, 3, 41, try request.encode());
    _ = try Remote.admit(service, &turn, policy, &source, 256);
    try writer.commit(turn);
    const rejected = try finish(&writer, &source);
    try t.expectEqual(.dependency, rejected.reason);
    try t.expectEqual(@as(u64, 0), rejected.basis.?.revision);
    turn = try writer.capture();
    try t.expectEqual(.rejected, (try service.job(&turn, rejected.job)).phase);
    try t.expectEqual(@as(u64, 0), (try service.head(&turn)).active_job);
    try Remote.reject(service, &turn, rejected.job, .dependency);
    try clean(turn);
    try service.retire(&turn);
    try writer.commit(turn);
    turn = try call(&writer, 3, 41, try request.encode());
    try t.expectEqual(.rejected, try Remote.admit(service, &turn, policy, &source, 256));
    try t.expectEqual(.retired, (try response(turn, 3, 41)).reason);
}

test "caller freezes peer and correlation, rejects spoofed replies and preserves the original outcome" {
    const Caller = lib.Caller;
    var caller: Store = .{ .resource = 8 };
    defer caller.deinit();
    const value = try change();
    const request = try Request.prepare(8, 100, 5, value);
    const target: Caller.Target = .{ .pid = 2, .resource = 7 };
    var correlation: u64 = 0;
    for (0..32) |_| {
        var turn = try caller.capture();
        const result = try Caller.stage(&turn, target, request, value);
        if (result == .sent) {
            const frame = try s.Frame.decode(turn.decision.outputs[0].?.value);
            correlation = frame.correlation;
            try t.expectEqual(.call, frame.kind);
            try t.expect(frame.payload.eql(try request.encode()));
            // Wait, call binding and framework state share one decision.
            try turn.write(try p.Value.init("framework"), try p.Value.init("called"));
            try caller.commit(turn);
            break;
        }
        try caller.commit(turn);
    } else return error.CallerDidNotSubmit;
    var turn = try caller.capture();
    try t.expectEqual(.waiting, try Caller.stage(&turn, target, request, value));
    try clean(turn);
    try t.expectError(error.DocumentCallIdentityConflict, Caller.stage(&turn, .{ .pid = 9, .resource = 7 }, request, value));
    try clean(turn);
    const reply: Remote.Reply = .{ .status = .accepted, .job = try Remote.jobId(3), .basis = .{ .resource = 7, .document = 17, .epoch = 1, .type_revision = 1, .revision = 1 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .reply, .correlation = correlation, .payload = try reply.encode() }).encode();
    turn.delivery.input.origin = .{ .process = .{ .pid = 9, .turn = 10, .output = 11 } };
    try t.expectError(error.UnexpectedDocumentReply, Caller.accept(&turn, 100));
    try clean(turn);
    turn.delivery.input.origin.process.pid = 2;
    var wrong = reply;
    wrong.basis.?.resource = 9;
    turn.delivery.input.value = try (s.Frame{ .kind = .reply, .correlation = correlation, .payload = try wrong.encode() }).encode();
    try t.expectError(error.UnexpectedDocumentReply, Caller.accept(&turn, 100));
    try clean(turn);
    turn.delivery.input.value = try (s.Frame{ .kind = .reply, .correlation = correlation, .payload = try reply.encode() }).encode();
    _ = try turn.acceptReply(); // GenServer settles the durable wait before dispatch.
    try t.expectEqualDeep(reply, try Caller.accept(&turn, 100));
    try turn.write(try p.Value.init("framework"), try p.Value.init("received"));
    try caller.commit(turn);
    var next = try caller.capture();
    try t.expectEqual(.complete, try Caller.stage(&next, target, request, value));
    try t.expectEqualDeep(reply, (try Caller.outcome(&next, 100)).?);
    next.delivery.input = turn.delivery.input;
    try t.expectEqualDeep(reply, try Caller.accept(&next, 100));
    try clean(next);
    wrong = reply;
    wrong.basis.?.revision = 2;
    next.delivery.input.value = try (s.Frame{ .kind = .reply, .correlation = correlation, .payload = try wrong.encode() }).encode();
    try t.expectError(error.DocumentReplyIdentityConflict, Caller.accept(&next, 100));
    try clean(next);
}
