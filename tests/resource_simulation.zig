//! Test-only schedule runner. Executes the real engine with explicit storage and
//! clock seams; no production authentication or time bypass is introduced.
const std = @import("std");
const core = @import("transit_core");
const p = core.protocol;
const g = p.Growth;
const catalog = core.catalog;
const address = core.growing.address;
const Store = @import("simulation_store.zig");
const Fault = Store.Fault;
const Engine = core.Engine(Store, Store);
const Action = struct {
    kind: enum { send, own, revoke, grant, prepare, commit, retry, restart, clock, terminate, open_view, close_view, resource_grant, checkpoint, trim, evict, assert_drained },
    slot: u2 = 0,
    owner: u8 = 1,
    value: i64 = 1,
    stale_generation: bool = false,
    stale_revision: bool = false,
    fault: Fault = .none,
    fault_at: u16 = 1,
    time: core.Time.Sample = .{ .unix_ms = 10 },
    deadline_ms: u64 = 50,
    resource_permissions: u8 = p.State.all_permissions,
};
const Trace = struct { version: u32, seed: u64 = 0, profile: enum { storage } = .storage, actions: []const Action };
const Saved = struct { signed: core.SignedRequest, prepared: Engine.Prepared };

fn clock(context: *anyopaque) !core.Time.Sample {
    return @as(*core.Time.Sample, @ptrCast(@alignCast(context))).*;
}
fn key(principal: u8) !core.Ed25519.KeyPair {
    return core.Ed25519.KeyPair.generateDeterministic(@splat(principal + 7));
}
fn request(engine: *Engine, principal: u8, command: core.Command) !core.SignedRequest {
    return core.sign(.{ .realm = 42, .principal = principal, .sequence = (try engine.principal(principal)).sequence + 1, .command = command }, try key(principal));
}
fn grant() !core.Command {
    return .{ .grant = .{ .subject = 1, .public_key = (try key(1)).public_key.toBytes(), .permissions = core.all_permissions } };
}
fn nextInput(engine: *Engine) !?g.Input {
    const process = try engine.process(2);
    if (process.consumed + process.cancelled == process.admitted) return null;
    var current = try engine.state();
    return current.get(g.Input, try catalog.key(.mailbox, 2, process.consumed + 1, ""));
}
fn resource(engine: *Engine) !?g.Resource {
    var current = try engine.state();
    return current.get(g.Resource, address(.resource, 3));
}
fn activeView(engine: *Engine) !?g.View {
    const process = try engine.process(2);
    var current = try engine.state();
    var after: ?core.pages.Key = null;
    var latest: ?g.View = null;
    while (true) {
        const batch = try current.scan(core.growing.StoredView, .{ .namespace = .view }, after);
        for (batch.records) |slot| if (slot) |record| {
            const view = record.value.meta;
            if (view.pid == 2 and view.closed_at == null and view.generation == process.generation and view.process_revision == process.revision and process.lifecycle == .running) latest = view;
        };
        after = batch.next;
        if (after == null) return latest;
    }
}
fn act(engine: *Engine, saved: *[4]?Saved, now: *core.Time.Sample, action: Action) !?u64 {
    engine.journal.begin(action.fault, action.fault_at);
    defer engine.journal.fault = .none;
    switch (action.kind) {
        .assert_drained => {
            const process = try engine.process(2);
            if (process.consumed != process.admitted) return error.ProgressStalled;
        },
        .checkpoint => return try engine.submit(try request(engine, 0, .{ .checkpoint = {} })),
        .trim => try engine.journal.trim(engine.head.history_floor),
        .evict => {
            engine.record_cache = .{};
            engine.page_store.clearCache();
        },
        .send => return try engine.submit(try request(engine, 0, .{ .send = .{ .pid = 2, .value = core.Value.integer(action.value) } })),
        .own => return try engine.submit(try request(engine, 0, .{ .own = .{ .pid = 2, .worker = action.owner, .expected_generation = (try engine.process(2)).generation } })),
        .revoke => return try engine.submit(try request(engine, 0, .{ .revoke = 1 })),
        .grant => return try engine.submit(try request(engine, 0, try grant())),
        .resource_grant => return try engine.submit(try request(engine, 0, .{ .grant_resource = .{ .resource = 3, .subject = 1, .permissions = action.resource_permissions } })),
        .open_view => {
            const process = try engine.process(2);
            const input = (try nextInput(engine)) orelse return error.NoInput;
            const data = (try resource(engine)).?;
            return try engine.submit(try request(engine, 1, .{ .open_view = .{
                .pid = 2,
                .generation = process.generation,
                .input = input.position,
                .expected_revision = process.revision,
                .resource = 3,
                .revision = data.revision,
                .deadline_ms = action.deadline_ms,
            } }));
        },
        .close_view => {
            const view = (try activeView(engine)) orelse return error.NoView;
            return try engine.submit(try request(engine, 1, .{ .close_view = .{ .pid = 2, .view = view.id } }));
        },
        .terminate => return try engine.submit(try request(engine, 0, .{ .terminate = 2 })),
        .prepare => {
            // Replace a slot before validation: a failed preparation cannot
            // accidentally leave a previously prepared operation callable.
            saved[action.slot] = null;
            const process = try engine.process(2);
            const input = (try nextInput(engine)) orelse return error.NoInput;
            var turn: p.Turn = .{
                .pid = 2,
                .generation = process.generation + @as(u64, if (action.stale_generation) 1 else 0),
                .expected_revision = process.revision + @as(u64, if (action.stale_revision) 1 else 0),
                .input = input.position,
            };
            const view = (try activeView(engine)) orelse return error.NoView;
            turn.write_view = view.id;
            turn.views[0] = view.id;
            turn.mutations[0] = .{ .key = try core.Value.init("value"), .value = core.Value.integer(action.value) };
            turn.outputs[0] = .{ .pid = 2, .value = core.Value.integer(action.value) };
            const command: core.Command = .{ .turn = turn };
            const signed = try request(engine, 1, command);
            const prepared = try engine.prepare(signed);
            saved[action.slot] = .{ .signed = signed, .prepared = prepared };
            return null;
        },
        .commit => {
            const candidate = &(saved[action.slot] orelse return error.NoPreparation);
            return try engine.commit(candidate.prepared);
        },
        .retry => return try engine.submit((saved[action.slot] orelse return error.NoPreparation).signed),
        .restart => engine.* = try Engine.open(engine.journal, engine.page_store, engine.genesis),
        .clock => now.* = action.time,
    }
    return null;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) return error.ExpectedTracePaths;
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    for (args[1..]) |path| {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1024 * 1024));
        defer init.gpa.free(bytes);
        var trace = try std.json.parseFromSlice(Trace, init.gpa, bytes, .{});
        defer trace.deinit();
        if (trace.value.version != 1 or trace.value.actions.len == 0 or trace.value.actions.len > 512) return error.UnsupportedTrace;
        var store: Store = .{ .allocator = init.gpa };
        defer store.entries.deinit(init.gpa);
        defer store.pages.deinit(init.gpa);
        const genesis: core.Genesis = .{ .realm = 42, .root_key = (try key(0)).public_key.toBytes(), .max_clock_error_ms = 2, .allow_history_trim = true };
        var engine = try Engine.bootstrap(&store, &store, genesis);
        var now: core.Time.Sample = .{ .unix_ms = 10 };
        _ = try engine.submit(try request(&engine, 0, try grant()));
        _ = try engine.submit(try request(&engine, 0, .{ .spawn = .{} }));
        {
            _ = try engine.submit(try request(&engine, 0, .{ .create_resource = .{ .writer = 2, .owned = false } }));
            for ([_]u8{ 0, 1 }) |subject| {
                _ = try engine.submit(try request(&engine, 0, .{ .grant_resource = .{ .resource = 3, .subject = subject, .permissions = p.State.all_permissions } }));
            }
            _ = try engine.submit(try request(&engine, 0, .{ .associate = .{ .pid = 2, .name = try core.Value.init("state"), .resource = 3 } }));
        }
        _ = try engine.submit(try request(&engine, 0, .{ .own = .{ .pid = 2, .worker = 1, .expected_generation = (try engine.process(2)).generation } }));
        // Frozen candidates contain immutable root references. Keeping four
        // independently prepared decisions exercises competing publication.
        const saved = try init.gpa.create([4]?Saved);
        defer init.gpa.destroy(saved);
        saved.* = @splat(null);
        for (trace.value.actions, 0..) |action, index| {
            engine.clock = .{ .context = &now, .read = clock };
            var failure: ?[]const u8 = null;
            const receipt = act(&engine, saved, &now, action) catch |err| blk: {
                failure = @errorName(err);
                break :blk null;
            };
            const io = store.counts;
            const staged = store.staged;
            try engine.refresh();
            store.clearCache();
            var recovered = try Engine.open(&store, &store, genesis);
            if (!std.meta.eql(engine.head, recovered.head)) return error.ReplayDivergence;
            var arena = std.heap.ArenaAllocator.init(init.gpa);
            defer arena.deinit();
            const actual = try observe(&engine, arena.allocator());
            const replay = try observe(&recovered, arena.allocator());
            const actual_bytes = try std.json.Stringify.valueAlloc(arena.allocator(), actual, .{});
            const replay_bytes = try std.json.Stringify.valueAlloc(arena.allocator(), replay, .{});
            if (!std.mem.eql(u8, actual_bytes, replay_bytes)) return error.ReplayDivergence;
            if (staged != store.staged) return error.RecoveryWrotePages;
            try std.json.Stringify.value(.{ .trace = path, .index = index, .failure = failure, .receipt = receipt, .state = actual, .io = io }, .{}, &output.interface);
            try output.interface.writeByte('\n');
            try output.interface.flush();
        }
    }
}

const View = struct { id: u64, resource_revision: u64, closed_at: ?u64, value: ?i64 };
const Output = struct { id: u64, turn: u64, value: i64, source: u64, destination: u64 };
fn observe(engine: *Engine, allocator: std.mem.Allocator) !Observation {
    const process = try engine.process(2);
    var current = try engine.state();
    const data = try resource(engine);
    const entry = try current.get(g.Entry, try catalog.key(.entry, 3, 0, "value"));
    const permission = try current.get(core.growing.ResourceGrant, try catalog.key(.grant, 3, 1, ""));
    const view = try activeView(engine);
    var views: std.ArrayList(View) = .empty;
    var after: ?core.pages.Key = null;
    while (true) {
        const batch = try current.scan(core.growing.StoredView, .{ .namespace = .view }, after);
        for (batch.records) |slot| if (slot) |record| {
            var captured = try catalog.Catalog(Store).open(engine.page_store, record.value.snapshot);
            const item = try captured.get(g.Entry, try catalog.key(.entry, 3, 0, "value"));
            try views.append(allocator, .{ .id = record.value.meta.id, .resource_revision = record.value.meta.revision, .closed_at = record.value.meta.closed_at, .value = if (item) |value| try value.value.asInteger() else null });
        };
        after = batch.next;
        if (after == null) break;
    }
    const outputs = try allocator.alloc(Output, @intCast(engine.head.outputs));
    for (outputs, 1..) |*out, id| {
        const value = (try current.get(g.Outbox, address(.output, id))).?;
        out.* = .{ .id = value.id, .turn = value.turn, .value = try value.value.asInteger(), .source = value.source, .destination = value.destination };
    }
    return .{
        .position = engine.head.position,
        .owner = process.owner,
        .generation = process.generation,
        .revision = process.revision,
        .admitted = process.admitted,
        .consumed = process.consumed,
        .cancelled = process.cancelled,
        .lifecycle = process.lifecycle,
        .value = if (entry) |item| try item.value.asInteger() else 0,
        .permissions = (try engine.principal(1)).grant.permissions,
        .sequence = (try engine.principal(1)).sequence,
        .resource_revision = if (data) |item| item.revision else null,
        .resource_value = if (entry) |item| try item.value.asInteger() else null,
        .resource_permissions = if (permission) |item| (if (item.principal_epoch == (try engine.principal(1)).epoch) item.permissions else @as(u8, 0)) else null,
        .view = if (view) |item| item.id else null,
        .time_floor = engine.head.time_floor_ms,
        .history_floor = engine.head.history_floor,
        .views = try views.toOwnedSlice(allocator),
        .outputs = outputs,
    };
}
const Observation = struct {
    position: u64,
    owner: ?u64,
    generation: u64,
    revision: u64,
    admitted: u64,
    consumed: u64,
    cancelled: u64,
    lifecycle: @FieldType(g.Process, "lifecycle"),
    value: i64,
    permissions: u16,
    sequence: u64,
    resource_revision: ?u64,
    resource_value: ?i64,
    resource_permissions: ?u8,
    view: ?u64,
    time_floor: u64,
    history_floor: u64,
    views: []View,
    outputs: []Output,
};
