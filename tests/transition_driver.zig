//! Test-only schedule runner. Executes the real engine with explicit storage and
//! clock seams; no production authentication or time bypass is introduced.
const std = @import("std");
const core = @import("transit_core");
const p = core.protocol;
const Fault = enum { none, before_append, after_append };
const Store = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(core.Entry) = .empty,
    fault: Fault = .none,

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
const Engine = core.Engine(Store);
const Action = struct {
    kind: enum { send, own, revoke, grant, prepare, commit, retry, restart, clock },
    slot: u2 = 0,
    owner: u8 = 1,
    value: i64 = 1,
    stale_generation: bool = false,
    stale_revision: bool = false,
    fault: Fault = .none,
    time: core.Time.Sample = .{ .unix_ms = 10 },
};
const Trace = struct { version: u32, seed: u64 = 0, actions: []const Action };
const Saved = struct { signed: core.SignedRequest, prepared: Engine.Prepared };

fn clock(context: *anyopaque) !core.Time.Sample {
    return @as(*core.Time.Sample, @ptrCast(@alignCast(context))).*;
}
fn key(principal: u8) !core.Ed25519.KeyPair {
    return core.Ed25519.KeyPair.generateDeterministic(@splat(principal + 7));
}
fn request(engine: *Engine, principal: u8, command: core.Command) !core.SignedRequest {
    return core.sign(.{ .realm = 42, .principal = principal, .sequence = (try engine.state.principal(principal)).sequence + 1, .command = command }, try key(principal));
}
fn grant() !core.Command {
    return .{ .grant = .{ .subject = 1, .public_key = (try key(1)).public_key.toBytes(), .permissions = core.all_permissions } };
}
fn act(engine: *Engine, saved: *[4]?Saved, now: *core.Time.Sample, action: Action) !?u64 {
    switch (action.kind) {
        .send => return try engine.submit(try request(engine, 0, .{ .send = .{ .pid = 2, .value = core.Value.integer(action.value) } })),
        .own => return try engine.submit(try request(engine, 0, .{ .own = .{ .pid = 2, .worker = action.owner, .expected_generation = (try engine.state.process(2)).generation } })),
        .revoke => return try engine.submit(try request(engine, 0, .{ .revoke = 1 })),
        .grant => return try engine.submit(try request(engine, 0, try grant())),
        .prepare => {
            // Replace a slot before validation: a failed preparation cannot
            // accidentally leave a previously prepared operation callable.
            saved[action.slot] = null;
            const process = try engine.state.process(2);
            const input = (try engine.nextInput(2, engine.state.position)) orelse return error.NoInput;
            const signed = try request(engine, 1, .{ .turn = .{
                .pid = 2,
                .generation = process.generation + @as(u64, if (action.stale_generation) 1 else 0),
                .expected_revision = process.revision + @as(u64, if (action.stale_revision) 1 else 0),
                .input = input.position,
                .result = core.Value.integer(action.value),
            } });
            const prepared = try engine.prepare(signed);
            saved[action.slot] = .{ .signed = signed, .prepared = prepared };
            return null;
        },
        .commit => {
            const candidate = &(saved[action.slot] orelse return error.NoPreparation);
            engine.store.fault = action.fault;
            return try engine.commit(candidate.prepared);
        },
        .retry => return try engine.submit((saved[action.slot] orelse return error.NoPreparation).signed),
        .restart => engine.* = try Engine.open(engine.store, engine.genesis),
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
        var store: Store = .{ .allocator = init.gpa };
        defer store.entries.deinit(init.gpa);
        const genesis: core.Genesis = .{ .realm = 42, .root_key = (try key(0)).public_key.toBytes(), .max_clock_error_ms = 2 };
        var engine = try Engine.bootstrap(&store, genesis);
        var now: core.Time.Sample = .{ .unix_ms = 10 };
        _ = try engine.submit(try request(&engine, 0, try grant()));
        _ = try engine.submit(try request(&engine, 0, .{ .spawn = .{} }));
        _ = try engine.submit(try request(&engine, 0, .{ .own = .{ .pid = 2, .worker = 1, .expected_generation = 0 } }));
        // Candidate copies are part of the legacy profile; allocate this
        // test scheduler's four slots explicitly instead of exhausting stack.
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
            const recovered = try Engine.open(&store, genesis);
            try engine.refresh();
            if (!std.meta.eql(engine.state, recovered.state)) return error.ReplayDivergence;
            engine = recovered;
            const process = try engine.state.process(2);
            try std.json.Stringify.value(.{
                .trace = path,
                .index = index,
                .failure = failure,
                .receipt = receipt,
                .position = engine.state.position,
                .owner = process.owner,
                .generation = process.generation,
                .revision = process.revision,
                .admitted = process.admitted,
                .consumed = process.consumed,
                .value = try process.state.asInteger(),
                .permissions = (try engine.state.principal(1)).grant.permissions,
                .sequence = (try engine.state.principal(1)).sequence,
            }, .{}, &output.interface);
            try output.interface.writeByte('\n');
        }
        try output.interface.flush();
    }
}
