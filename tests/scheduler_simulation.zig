//! Real shared Session/courier operations with deterministic transport boundaries.
const std = @import("std");
const core = @import("transit_core");
const wire = @import("transit_client");
const p = wire.protocol;
const g = p.Growth;
const Store = @import("simulation_store.zig");
const projection = @import("delivery_simulation.zig");
const Engine = core.Engine(Store, Store);
const Fault = enum { none, before_query, after_query, before_submit, after_submit };
const Transport = struct {
    engine: *Engine,
    fault: Fault = .none,
    fired: bool = false,
    last_rejection: ?p.ErrorCode = null,
    submitted: ?g.SignedRequest = null,
    fn disturb(self: *@This(), fault: Fault) !void {
        if (self.fault == fault) {
            self.fired = true;
            return error.AuthorityUnavailable;
        }
    }
    fn reject(self: *@This(), err: anyerror) anyerror {
        const code = std.meta.stringToEnum(p.ErrorCode, @errorName(err)) orelse .AuthorityUnavailable;
        self.last_rejection = code;
        return switch (code) {
            .Unauthorized, .Forbidden, .WrongProtocolRealm => error.AccessDenied,
            .Conflict, .QueryExpired, .HistoryReclaimed => error.Conflict,
            .AuthorityUnavailable, .ClockRollback, .ClockUnavailable, .DeadlineUncertain, .UntrustedTime, .AdmissionClosed, .ControlCapacity => error.AuthorityUnavailable,
            else => error.Rejected,
        };
    }
    pub fn query(self: *@This(), selector: g.Query, signing_key: p.Ed25519.KeyPair) !g.Response {
        self.last_rejection = null;
        try self.disturb(.before_query);
        const response = self.engine.query(try g.signQuery(selector, signing_key)) catch |err| return self.reject(err);
        try g.validateResponse(response, selector);
        try self.disturb(.after_query);
        return response;
    }
    pub fn submit(self: *@This(), signed: g.SignedRequest) !p.Receipt {
        self.last_rejection = null;
        self.submitted = signed;
        try g.validate(signed.request);
        try self.disturb(.before_submit);
        const at = self.engine.submit(signed) catch |err| return self.reject(err);
        try self.disturb(.after_submit);
        return .{ .position = at };
    }
};
const Session = wire.SessionWithTransport(Transport);
const Worker = struct {
    session: Session,
    pending: ?Session.Pending = null,
    finite: bool = false,
    fn step(self: *@This()) !?u64 {
        if (self.pending) |*pending| {
            const receipt = try pending.submit(self.session.client);
            self.pending = null;
            return receipt.position;
        }
        const delivery = (try self.session.receive()) orelse return null;
        if (delivery.needs_permit) {
            self.pending = try self.session.prepareBegin(delivery);
        } else {
            var decision: Session.Decision = .{};
            if (!self.finite) decision.outputs[0] = .{ .pid = 6, .value = delivery.input.value };
            self.pending = try self.session.prepareCommit(delivery, decision);
        }
        return null;
    }
};
const Action = struct {
    kind: enum { send, worker, courier, crash_worker, crash_courier, own, adopt, policy, restart, clock, maintenance, checkpoint, trim, assert_drained },
    source: u1 = 0,
    principal: u2 = 1,
    permissions: u16 = p.all_permissions,
    value: i64 = 1,
    fault: Fault = .none,
    time: core.Time.Sample = .{ .unix_ms = 10 },
    expected_error: ?[]const u8 = null,
    expected_rejection: ?p.ErrorCode = null,
    require_fault: bool = false,
};
const Trace = struct { version: u32, profile: enum { scheduler }, seed: u64 = 0, finite: bool = false, actions: []const Action };
fn key(principal: u64) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(@as(u8, @intCast(principal)) + 7));
}
fn submit(engine: *Engine, command: g.Command) !u64 {
    return engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = command }, try key(0)));
}
fn clock(context: *anyopaque) !core.Time.Sample {
    return @as(*core.Time.Sample, @ptrCast(@alignCast(context))).*;
}
fn digest(pending: ?Session.Pending) !?[32]u8 {
    return if (pending) |value| try g.digest(value.signed.request) else null;
}
fn act(engine: *Engine, workers: *[2]Worker, courier: *?g.SignedRequest, transport: *Transport, now: *core.Time.Sample, action: Action) !?u64 {
    const pid = @as(u64, action.source) + 4;
    switch (action.kind) {
        .worker => return workers[action.source].step(),
        .courier => {
            _ = try wire.delivery.step(transport, .{ .realm = 42, .principal = 3, .kind = .delivery }, try key(3), courier);
        },
        .send => return try submit(engine, .{ .send = .{ .pid = pid, .value = p.Value.integer(action.value) } }),
        .crash_worker => workers[action.source].pending = null,
        .crash_courier => courier.* = null,
        .own => return try submit(engine, .{ .own = .{ .pid = pid, .expected_generation = (try engine.process(pid)).generation, .worker = @as(u64, action.source) + 1 } }),
        .adopt => {
            workers[action.source].pending = null;
            workers[action.source].session.generation = (try engine.process(pid)).generation;
        },
        .policy => return try submit(engine, .{ .grant = .{ .subject = action.principal, .public_key = (try key(action.principal)).public_key.toBytes(), .permissions = action.permissions } }),
        .restart => {
            engine.* = try Engine.open(engine.journal, engine.page_store, engine.genesis);
            engine.clock = .{ .context = now, .read = clock };
        },
        .clock => now.* = action.time,
        .maintenance => {
            var maintenance: core.growing.Maintenance = .{};
            if (try maintenance.next(engine, now.*)) |command| return try submit(engine, command);
        },
        .checkpoint => return try submit(engine, .{ .checkpoint = {} }),
        .trim => try engine.journal.trim(engine.head.history_floor),
        .assert_drained => {
            for (4..6) |source| {
                const process = try engine.process(source);
                if (process.lifecycle == .running and process.consumed != process.admitted) return error.ProgressStalled;
            }
            const response = try transport.query(.{ .realm = 42, .principal = 3, .kind = .delivery }, try key(3));
            if (response.body.delivery.next != null) return error.ProgressStalled;
        },
    }
    return null;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedTrace;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(1024 * 1024));
    defer init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Trace, init.gpa, bytes, .{});
    defer parsed.deinit();
    const trace = parsed.value;
    if (trace.version != 1 or trace.actions.len == 0 or trace.actions.len > 512) return error.InvalidTrace;
    var store: Store = .{ .allocator = init.gpa };
    defer store.entries.deinit(init.gpa);
    defer store.pages.deinit(init.gpa);
    var now: core.Time.Sample = .{ .unix_ms = 10 };
    const genesis: core.Genesis = .{ .realm = 42, .root_key = (try key(0)).public_key.toBytes(), .max_clock_error_ms = 2, .allow_history_trim = true };
    var engine = try Engine.bootstrap(&store, &store, genesis);
    engine.clock = .{ .context = &now, .read = clock };
    for (1..4) |principal| _ = try submit(&engine, .{ .grant = .{ .subject = principal, .public_key = (try key(principal)).public_key.toBytes(), .permissions = p.all_permissions } });
    for (4..7) |pid| _ = try submit(&engine, .{ .spawn = if (pid == 4 and trace.finite) .{ .work_before_ms = 100, .settle_before_ms = 150 } else .{} });
    var transport: Transport = .{ .engine = &engine };
    var workers: [2]Worker = undefined;
    for (&workers, 0..) |*worker, index| {
        _ = try submit(&engine, .{ .own = .{ .pid = index + 4, .worker = index + 1, .expected_generation = 0 } });
        worker.* = .{ .session = .{ .client = &transport, .realm = 42, .pid = index + 4, .principal = index + 1, .generation = 1, .key = try key(index + 1) }, .finite = trace.finite and index == 0 };
    }
    var courier: ?g.SignedRequest = null;
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (trace.actions, 0..) |action, index| {
        if (action.kind == .policy and action.principal == 0) return error.InvalidTrace;
        transport.fault = action.fault;
        transport.fired = false;
        transport.submitted = null;
        transport.last_rejection = null;
        const before = engine.head.position;
        var failure: ?[]const u8 = null;
        const receipt = act(&engine, &workers, &courier, &transport, &now, action) catch |err| blk: {
            failure = @errorName(err);
            break :blk null;
        };
        transport.fault = .none;
        try engine.refresh();
        const staged = store.staged;
        store.clearCache();
        var recovered = try Engine.open(&store, &store, genesis);
        if (!std.meta.eql(engine.head, recovered.head)) return error.ReplayDivergence;
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        const observed = try projection.observe(&engine, arena.allocator());
        const cold = try projection.observe(&recovered, arena.allocator());
        const live_bytes = try std.json.Stringify.valueAlloc(arena.allocator(), observed, .{});
        const cold_bytes = try std.json.Stringify.valueAlloc(arena.allocator(), cold, .{});
        if (!std.mem.eql(u8, live_bytes, cold_bytes)) return error.ReplayDivergence;
        if (store.staged != staged) return error.RecoveryWrotePages;
        try std.json.Stringify.value(.{
            .index = index,
            .before = before,
            .failure = failure,
            .receipt = receipt,
            .rejection = transport.last_rejection,
            .fault_fired = transport.fired,
            .state = observed,
            .pending = .{ try digest(workers[0].pending), try digest(workers[1].pending), if (courier) |value| try g.digest(value.request) else null },
            .submitted = if (transport.submitted) |value| .{ .principal = value.request.principal, .sequence = value.request.sequence, .digest = try g.digest(value.request), .kind = @tagName(value.request.command) } else null,
        }, .{}, &writer.interface);
        try writer.interface.writeByte('\n');
        try writer.interface.flush();
    }
}
