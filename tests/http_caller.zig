//! Distinct application caller used by the real HTTP worker proof.
const std = @import("std");
const t = std.testing;
const http = @import("transit_station_http");
const s = @import("transit_station");
const p = s.protocol;
const Pub = s.Publication;
const Admin = @import("growing_support.zig").Admin(47);
pub const Saved = struct { pid: u64, resource: u64, correlation: u64, deadline: u64, replacement: ?u64 = null, output_after: u64 };
const Action = union(enum) {
    create,
    begin: struct { id: u64, spec: Pub.Spec },
    append: struct { id: u64, index: u32, bytes: []const u8 },
    publish: u64,
    call: struct { pid: u64, reference: http.RequestRecord.Reference },
    receive,
};
const Caller = struct {
    action: Action = .create,
    correlation: u64 = 0,
    outcome: ?http.Service.Outcome = null,
    fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) !void {
        const self: *Caller = @ptrCast(@alignCast(raw.?));
        const publication: Pub = .{ .resource = turn.view.resource, .namespace = std.math.maxInt(u64) };
        switch (self.action) {
            .create => {
                _ = try Pub.create(turn, publication.namespace, .{ .record_bytes = 65536, .staging_bytes = 73728, .staging_records = 2 });
            },
            .begin => |a| {
                _ = try publication.begin(turn, a.id, a.spec);
            },
            .append => |a| {
                _ = try publication.append(turn, a.id, a.index, a.bytes);
            },
            .publish => |id| {
                _ = try publication.publish(turn, id);
            },
            .call => |call| self.correlation = try turn.call(call.pid, try call.reference.encode(), null),
            .receive => {
                try t.expectEqual(.reply, frame.kind);
                self.outcome = try http.Service.Outcome.decode(frame.payload);
                try turn.put(try p.Value.init("http-outcome"), frame.payload);
            },
        }
    }
};
fn drive(init: std.process.Init, server: *s.GrowingGenServer, caller: *Caller) !void {
    for (0..32) |_| switch (try server.step(.{ .context = caller, .handle = Caller.handle }, @as(u64, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds())) + 30000)) {
        .committed => return,
        .blocked => return server.handler_error orelse error.CallerBlocked,
        .idle => return error.MissingInput,
        .progress => {},
    };
    return error.StepBudgetExceeded;
}
fn apply(init: std.process.Init, admin: *Admin, server: *s.GrowingGenServer, caller: *Caller, action: Action) !void {
    caller.action = action;
    try admin.send(server.session.pid, 0);
    try drive(init, server, caller);
}
fn stage(init: std.process.Init, admin: *Admin, server: *s.GrowingGenServer, caller: *Caller, id: u64, bytes: []const u8, spec: Pub.Spec) !void {
    try apply(init, admin, server, caller, .{ .begin = .{ .id = id, .spec = spec } });
    for (0..spec.chunks()) |i| try apply(init, admin, server, caller, .{ .append = .{ .id = id, .index = @intCast(i), .bytes = bytes[i * 256 ..][0..try spec.size(@intCast(i))] } });
    try apply(init, admin, server, caller, .{ .publish = id });
}
fn output(admin: *Admin, after: u64) !p.Growth.Outbox {
    const position = (try admin.query(.{ .capabilities = {} })).position;
    return (try admin.query(.{ .outputs = .{ .after = after, .position = position } })).body.outputs.entries[0] orelse error.MissingOutput;
}
fn lastOutput(admin: *Admin) !u64 {
    const position = (try admin.query(.{ .capabilities = {} })).position;
    var after: ?u64 = null;
    var last: u64 = 0;
    while (true) {
        const page = (try admin.query(.{ .outputs = .{ .after = after, .position = position } })).body.outputs;
        for (page.entries) |entry| if (entry) |item| {
            last = item.id;
        };
        after = page.next;
        if (after == null) return last;
    }
}
pub fn publish(init: std.process.Init, admin: *Admin, worker: u64, capture: u64, config_path: []const u8) !Saved {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, config_path, init.arena.allocator(), .limited(65536));
    const config = (try std.json.parseFromSlice(struct { request: http.Request, endpoint_revision: u64, reconcile_before_ms: u64, max_attempts: u32 }, init.arena.allocator(), bytes, .{ .ignore_unknown_fields = true })).value;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(73));
    const pid = try admin.submit(.{ .spawn = .{} });
    const resource = try admin.submit(.{ .create_resource = .{ .writer = pid } });
    const process = .{ .pid = pid, .resource = resource };
    _ = try admin.submit(.{ .grant = .{ .subject = 65537, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = pid } });
    for ([_]u64{ 0, 65537 }) |subject| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = subject, .permissions = p.State.all_permissions } });
    _ = try admin.submit(.{ .associate = .{ .pid = pid, .name = try p.Value.init("state"), .resource = resource } });
    _ = try admin.submit(.{ .grant_resource = .{ .resource = process.resource, .subject = 65536, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    _ = try admin.submit(.{ .grant_resource = .{ .resource = capture, .subject = 65537, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    // PID-scoped readers need both an association and a current resource grant.
    // Optional links do not make connector execution depend on caller lifetime.
    _ = try admin.submit(.{ .associate = .{ .pid = worker, .name = try p.Value.init("request"), .resource = process.resource, .required = false } });
    _ = try admin.submit(.{ .associate = .{ .pid = process.pid, .name = try p.Value.init("capture"), .resource = capture, .required = false } });
    _ = try admin.submit(.{ .own = .{ .pid = worker, .expected_generation = 2, .worker = 65536 } });
    _ = try admin.submit(.{ .own = .{ .pid = process.pid, .expected_generation = 2, .worker = 65537 } });
    var server = try s.GrowingGenServer.init(.{ .client = admin.wire, .realm = 47, .principal = 65537, .pid = process.pid, .generation = 3, .key = key }, "state");
    var caller: Caller = .{};
    var buffer: [8192]u8 = undefined;
    const prepared = try http.RequestRecord.prepare(process.resource, std.math.maxInt(u64), config.request, "body", config.endpoint_revision, config.reconcile_before_ms, config.max_attempts, &buffer);
    try apply(init, admin, &server, &caller, .create);
    try stage(init, admin, &server, &caller, http.RequestRecord.metadata_id, prepared.metadata, prepared.reference.metadataSpec());
    try stage(init, admin, &server, &caller, http.RequestRecord.body_id, "body", prepared.reference.bodySpec());
    // Outbox IDs are independent counters, not journal positions.
    const before = try lastOutput(admin);
    try apply(init, admin, &server, &caller, .{ .call = .{ .pid = worker, .reference = prepared.reference } });
    const outgoing = try output(admin, before);
    try t.expectEqual(process.pid, outgoing.source);
    try t.expectEqual(worker, outgoing.destination);
    _ = try admin.submit(.{ .deliver = outgoing.id });
    return .{ .pid = process.pid, .resource = process.resource, .correlation = caller.correlation, .deadline = prepared.reference.reconcile_before_ms, .output_after = outgoing.id };
}
pub fn receive(init: std.process.Init, admin: *Admin, saved: Saved, worker: u64) !http.Service.Outcome {
    const outgoing = try output(admin, saved.output_after);
    try t.expectEqual(worker, outgoing.source);
    try t.expectEqual(saved.pid, outgoing.destination);
    const frame = try s.Frame.decode(outgoing.value);
    try t.expectEqual(saved.correlation, frame.correlation);
    const outcome = try http.Service.Outcome.decode(frame.payload);
    _ = try admin.submit(.{ .deliver = outgoing.id });
    if (saved.replacement) |replacement| {
        const resolved = try output(admin, saved.output_after);
        try t.expectEqual(.retired, resolved.phase);
        try t.expectEqual(@as(u64, 0), (try admin.query(.{ .process = replacement })).body.process.process.admitted);
    } else {
        var server = try s.GrowingGenServer.init(.{ .client = admin.wire, .realm = 47, .principal = 65537, .pid = saved.pid, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(73)) }, "state");
        var caller: Caller = .{ .action = .receive };
        try drive(init, &server, &caller);
        try t.expectEqualDeep(outcome, caller.outcome.?);
    }
    return outcome;
}
