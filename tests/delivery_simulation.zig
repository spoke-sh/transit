//! Test-only event runner for two producers, their workers and one destination.
//! Prepared decisions are delayed explicitly; real signatures, authority and
//! delivery transitions run unchanged. The store assumes atomic conditional append.
const std = @import("std");
const core = @import("transit_core");
const p = core.protocol;
const g = p.Growth;
const c = core.catalog;
const address = core.growing.address;
const Fault = enum { none, before_append, after_append };
const Store = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(core.Entry) = .empty,
    pages: std.AutoHashMapUnmanaged(core.pages.Reference, core.pages.Page) = .empty,
    fault: Fault = .none,
    stages: usize = 0,

    pub fn stage(self: *Store, reference: core.pages.Reference, page: *const core.pages.Page) !core.pages.Reference {
        try self.pages.put(self.allocator, reference, page.*);
        self.stages += 1;
        return reference;
    }
    pub fn load(self: *Store, reference: core.pages.Reference) !core.pages.Page {
        return self.pages.get(reference) orelse error.PageUnavailable;
    }
    pub fn tail(self: *Store) !u64 {
        return self.entries.items.len;
    }
    pub fn read(self: *Store, at: u64) !?core.Entry {
        return if (at < self.entries.items.len) self.entries.items[@intCast(at)] else null;
    }
    pub fn append(self: *Store, expected: u64, entry: core.Entry) !bool {
        if (self.fault == .before_append) return error.StorageUnavailable;
        if (expected != self.entries.items.len) return false;
        try self.entries.append(self.allocator, entry);
        if (self.fault == .after_append) return error.LostAcknowledgement;
        return true;
    }
};
const Engine = core.Engine(Store, Store);
const Action = struct {
    kind: enum { send, prepare_turn, prepare_delivery, commit, retry, own, policy, terminate, restart, progress, assert_drained },
    source: u1 = 0,
    slot: u3 = 0,
    principal: u2 = 1,
    value: i64 = 1,
    output: u64 = 1,
    policy: enum { allow, revoke, delivery_only } = .allow,
    fault: Fault = .none,
};
const Trace = struct { version: u32, profile: enum { delivery }, seed: u64 = 0, generator: ?[]const u8 = null, actions: []const Action };
const Saved = struct { signed: core.SignedRequest, prepared: Engine.Prepared };
const Process = struct { pid: u64, owner: ?u64, generation: u64, revision: u64, admitted: u64, consumed: u64, cancelled: u64, lifecycle: @FieldType(g.Process, "lifecycle") };
const Output = struct { id: u64, source: u64, destination: u64, turn: u64, value: i64, phase: @FieldType(g.Outbox, "phase"), resolved_at: ?u64 };
const Input = struct { position: u64, ordinal: u64, value: i64, source: u64, turn: u64, output: u64 };
const Observation = struct { position: u64, processes: [3]Process, sequences: [4]u64, permissions: [4]u16, outputs: []Output, received: []Input };

fn key(principal: u64) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(@as(u8, @intCast(principal)) + 7));
}
fn request(engine: *Engine, principal: u64, command: core.Command) !core.SignedRequest {
    return core.sign(.{ .realm = 42, .principal = principal, .sequence = (try engine.principal(principal)).sequence + 1, .command = command }, try key(principal));
}
fn grant(principal: u64, permissions: u16) !core.Command {
    return .{ .grant = .{ .subject = principal, .public_key = (try key(principal)).public_key.toBytes(), .permissions = permissions } };
}
fn drained(engine: *Engine) !bool {
    for (4..6) |pid| {
        const process = try engine.process(pid);
        if (process.lifecycle == .running and process.consumed != process.admitted) return false;
    }
    var current = try engine.state();
    const pending = try current.scan(u64, .{ .namespace = .pending_output }, null);
    return pending.records[0] == null;
}
fn act(engine: *Engine, saved: *[8]?Saved, action: Action) !?u64 {
    // A fault belongs to one event, even if validation or deduplication avoids
    // append. It must not leak into the next unrelated administrative command.
    engine.journal.fault = action.fault;
    defer engine.journal.fault = .none;
    const pid = @as(u64, action.source) + 4;
    switch (action.kind) {
        .send => return try engine.submit(try request(engine, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(action.value) } })),
        .own => return try engine.submit(try request(engine, 0, .{ .own = .{ .pid = pid, .expected_generation = (try engine.process(pid)).generation, .worker = action.principal } })),
        .policy => return try engine.submit(try request(engine, 0, switch (action.policy) {
            .allow => try grant(action.principal, core.all_permissions),
            .revoke => .{ .revoke = action.principal },
            .delivery_only => try grant(action.principal, p.permission(.delivery)),
        })),
        .terminate => return try engine.submit(try request(engine, 0, .{ .terminate = pid })),
        .prepare_turn => {
            saved[action.slot] = null;
            const process = try engine.process(pid);
            if (process.consumed + process.cancelled == process.admitted) return error.NoInput;
            var current = try engine.state();
            const input = (try current.get(g.Input, try c.key(.mailbox, pid, process.consumed + 1, ""))) orelse return error.InvalidHistory;
            var turn: g.Turn = .{ .pid = pid, .generation = process.generation, .input = input.position, .expected_revision = process.revision };
            turn.outputs[0] = .{ .pid = 6, .value = input.value };
            const signed = try request(engine, process.owner orelse return error.NoOwner, .{ .turn = turn });
            const prepared = try engine.prepare(signed);
            saved[action.slot] = .{ .signed = signed, .prepared = prepared };
        },
        .prepare_delivery => {
            saved[action.slot] = null;
            const signed = try request(engine, 3, .{ .deliver = action.output });
            const prepared = try engine.prepare(signed);
            saved[action.slot] = .{ .signed = signed, .prepared = prepared };
        },
        .commit => return try engine.commit((saved[action.slot] orelse return error.NoPreparation).prepared),
        .retry => return try engine.submit((saved[action.slot] orelse return error.NoPreparation).signed),
        .restart => engine.* = try Engine.open(engine.journal, engine.page_store, engine.genesis),
        .progress => {},
        .assert_drained => if (!try drained(engine)) return error.ProgressStalled,
    }
    return null;
}
fn observe(engine: *Engine, allocator: std.mem.Allocator) !Observation {
    var result: Observation = undefined;
    result.position = engine.head.position;
    for (&result.processes, 4..) |*target, pid| {
        const process = try engine.process(pid);
        target.* = .{ .pid = process.pid, .owner = process.owner, .generation = process.generation, .revision = process.revision, .admitted = process.admitted, .consumed = process.consumed, .cancelled = process.cancelled, .lifecycle = process.lifecycle };
    }
    for (0..4) |principal| {
        const value = try engine.principal(principal);
        result.sequences[principal] = value.sequence;
        result.permissions[principal] = value.grant.permissions;
    }
    var current = try engine.state();
    result.outputs = try allocator.alloc(Output, @intCast(engine.head.outputs));
    for (result.outputs, 1..) |*target, id| {
        const out = (try current.get(g.Outbox, address(.output, id))) orelse return error.InvalidHistory;
        target.* = .{ .id = out.id, .source = out.source, .destination = out.destination, .turn = out.turn, .value = try out.value.asInteger(), .phase = out.phase, .resolved_at = out.resolved_at };
    }
    result.received = try allocator.alloc(Input, @intCast(result.processes[2].admitted));
    for (result.received, 1..) |*target, ordinal| {
        const input = (try current.get(g.Input, try c.key(.mailbox, 6, ordinal, ""))) orelse return error.InvalidHistory;
        if (input.origin != .process) return error.InvalidOrigin;
        const origin = input.origin.process;
        target.* = .{ .position = input.position, .ordinal = input.ordinal, .value = try input.value.asInteger(), .source = origin.pid, .turn = origin.turn, .output = origin.output };
    }
    return result;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) return error.ExpectedTracePaths;
    var output_buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    for (args[1..]) |path| {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1024 * 1024));
        defer init.gpa.free(bytes);
        var trace = try std.json.parseFromSlice(Trace, init.gpa, bytes, .{});
        defer trace.deinit();
        if (trace.value.version != 1 or trace.value.actions.len == 0 or trace.value.actions.len > 4096) return error.UnsupportedTrace;
        var store: Store = .{ .allocator = init.gpa };
        defer store.entries.deinit(init.gpa);
        defer store.pages.deinit(init.gpa);
        const genesis: core.Genesis = .{ .realm = 42, .root_key = (try key(0)).public_key.toBytes() };
        var engine = try Engine.bootstrap(&store, &store, genesis);
        for (1..4) |principal| _ = try engine.submit(try request(&engine, 0, try grant(principal, core.all_permissions)));
        for (4..7) |_| _ = try engine.submit(try request(&engine, 0, .{ .spawn = .{} }));
        for (4..6) |pid| _ = try engine.submit(try request(&engine, 0, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = pid - 3 } }));
        const saved = try init.gpa.create([8]?Saved);
        defer init.gpa.destroy(saved);
        saved.* = @splat(null);
        for (trace.value.actions, 0..) |action, index| {
            if ((action.kind == .policy or action.kind == .own) and action.principal == 0) return error.InvalidScenario;
            if (action.fault != .none and action.kind != .commit and action.kind != .retry) return error.InvalidScenario;
            var failure: ?[]const u8 = null;
            const receipt = act(&engine, saved, action) catch |err| blk: {
                failure = @errorName(err);
                break :blk null;
            };
            const stages = store.stages;
            try engine.refresh();
            var recovered = try Engine.open(&store, &store, genesis);
            if (!std.meta.eql(engine.head, recovered.head)) return error.ReplayDivergence;
            // Compare the full selected projection with a cold engine, but keep
            // the live engine (and its record cache) until an explicit restart.
            var arena = std.heap.ArenaAllocator.init(init.gpa);
            defer arena.deinit();
            const actual = try observe(&engine, arena.allocator());
            const replay = try observe(&recovered, arena.allocator());
            const live_bytes = try std.json.Stringify.valueAlloc(arena.allocator(), actual, .{});
            const replay_bytes = try std.json.Stringify.valueAlloc(arena.allocator(), replay, .{});
            if (!std.mem.eql(u8, live_bytes, replay_bytes)) return error.ReplayDivergence;
            if (store.stages != stages) return error.RecoveryWrotePages;
            try std.json.Stringify.value(.{ .trace = path, .index = index, .failure = failure, .receipt = receipt, .state = actual }, .{}, &writer.interface);
            try writer.interface.writeByte('\n');
            try writer.interface.flush();
        }
    }
}
