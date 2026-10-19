//! Test-only schedule runner. Executes the real engine with explicit storage and
//! clock seams; no production authentication or time bypass is introduced.
const std = @import("std");
const core = @import("transit_core");
const p = core.protocol;
const g = p.Growth;
const catalog = core.catalog;
const address = core.growing.address;
const Fault = enum { none, before_append, after_append };
const Store = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(core.Entry) = .empty,
    fault: Fault = .none,
    pages: std.AutoHashMapUnmanaged(core.pages.Reference, core.pages.Page) = .empty,
    blocks: @import("simulation_blocks.zig") = .{},

    pub fn stage(self: *Store, reference: core.pages.Reference, page: *const core.pages.Page) !core.pages.Reference {
        try self.pages.put(self.allocator, reference, page.*);
        return reference;
    }
    pub fn load(self: *Store, reference: core.pages.Reference) !core.pages.Page {
        return self.pages.get(reference) orelse error.PageUnavailable;
    }
    pub fn stageBlock(self: *Store, spec: p.Blocks.Spec, bytes: []const u8) !core.blocks.Reference {
        return self.blocks.stage(self.allocator, spec, bytes);
    }
    pub fn loadBlock(self: *Store, reference: core.blocks.Reference, output: []u8) ![]const u8 {
        return self.blocks.load(reference, output);
    }

    pub fn tail(self: *Store) !u64 {
        return self.entries.items.len;
    }
    pub fn read(self: *Store, at: u64) !?core.Entry {
        return if (at < self.entries.items.len) self.entries.items[@intCast(at)] else null;
    }
    pub fn append(self: *Store, expected: u64, entry: core.Entry) !bool {
        const fault = self.fault;
        self.fault = .none;
        if (fault == .before_append) return error.StorageUnavailable;
        if (expected != self.entries.items.len) return false;
        try self.entries.append(self.allocator, entry);
        if (fault == .after_append) return error.LostAcknowledgement;
        return true;
    }
};
const Engine = core.Engine(Store, Store);
const Action = struct {
    kind: enum { send, own, revoke, grant, prepare, commit, retry, restart, clock, terminate, open_view, close_view, resource_grant },
    slot: u2 = 0,
    owner: u8 = 1,
    value: i64 = 1,
    stale_generation: bool = false,
    stale_revision: bool = false,
    fault: Fault = .none,
    time: core.Time.Sample = .{ .unix_ms = 10 },
    deadline_ms: u64 = 50,
    resource_permissions: u8 = p.State.all_permissions,
};
const Trace = struct { version: u32, seed: u64 = 0, profile: enum { effects, resource } = .effects, actions: []const Action };
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
    switch (action.kind) {
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
            if (try resource(engine) != null) {
                const view = (try activeView(engine)) orelse return error.NoView;
                turn.write_view = view.id;
                turn.views[0] = view.id;
                turn.mutations[0] = .{ .key = try core.Value.init("value"), .value = core.Value.integer(action.value) };
            } else {
                // The control schedule records its value as an effect intent;
                // execution/replay never dispatches that intent.
                turn.effect = core.Value.integer(action.value);
            }
            const command: core.Command = .{ .turn = turn };
            const signed = try request(engine, 1, command);
            const prepared = try engine.prepare(signed);
            saved[action.slot] = .{ .signed = signed, .prepared = prepared };
            return null;
        },
        .commit => {
            const candidate = &(saved[action.slot] orelse return error.NoPreparation);
            engine.journal.fault = action.fault;
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
        if (trace.value.version != 1 or trace.value.actions.len > 4096) return error.UnsupportedTrace;
        if (trace.value.profile == .effects) for (trace.value.actions) |action| {
            switch (action.kind) {
                .open_view, .close_view, .resource_grant => return error.UnsupportedTrace,
                else => {},
            }
        };
        var store: Store = .{ .allocator = init.gpa };
        defer store.entries.deinit(init.gpa);
        defer store.pages.deinit(init.gpa);
        defer store.blocks.deinit(init.gpa);
        const genesis: core.Genesis = .{ .realm = 42, .root_key = (try key(0)).public_key.toBytes(), .max_clock_error_ms = 2 };
        var engine = try Engine.bootstrap(&store, &store, genesis);
        var now: core.Time.Sample = .{ .unix_ms = 10 };
        _ = try engine.submit(try request(&engine, 0, try grant()));
        _ = try engine.submit(try request(&engine, 0, .{ .spawn = .{} }));
        if (trace.value.profile == .resource) {
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
            // Recover from committed bytes after every boundary, including a
            // lost acknowledgement. Comparison is of logical state, not WAL
            // bytes, and replay never invokes a handler.
            const recovered = try Engine.open(&store, &store, genesis);
            try engine.refresh();
            if (!std.meta.eql(engine.head, recovered.head)) return error.ReplayDivergence;
            engine = recovered;
            const process = try engine.process(2);
            var current = try engine.state();
            const data = try resource(&engine);
            const entry = try current.get(g.Entry, try catalog.key(.entry, 3, 0, "value"));
            const effect = try current.get(g.Effect, address(.effect, process.revision));
            const identity = try engine.principal(1);
            var policy = try engine.authorization();
            var evaluator = try core.authorization.Evaluator(@TypeOf(policy)).init(&policy, policy.revision, engine.genesis.authorization_limits);
            const resource_permissions: ?u8 = if (data == null) null else if (!identity.enabled) 0 else @intCast((try evaluator.evaluate(identity.role, .{ .kind = .resource, .id = 3 }, p.State.all_permissions)).allowed);
            const view = try activeView(&engine);
            try std.json.Stringify.value(.{
                .trace = path,
                .index = index,
                .failure = failure,
                .receipt = receipt,
                .position = engine.head.position,
                .owner = process.owner,
                .generation = process.generation,
                .revision = process.revision,
                .admitted = process.admitted,
                .consumed = process.consumed,
                .cancelled = process.cancelled,
                .lifecycle = process.lifecycle,
                .value = if (data != null) (if (entry) |item| try item.value.asInteger() else 0) else (if (effect) |item| try item.payload.asInteger() else 0),
                .permissions = (try engine.principal(1)).grant.permissions,
                .sequence = (try engine.principal(1)).sequence,
                .resource_revision = if (data) |item| item.revision else null,
                .resource_value = if (entry) |item| try item.value.asInteger() else null,
                .resource_permissions = resource_permissions,
                .view = if (view) |item| item.id else null,
                .time_floor = engine.head.time_floor_ms,
            }, .{}, &output.interface);
            try output.interface.writeByte('\n');
        }
        try output.interface.flush();
    }
}
