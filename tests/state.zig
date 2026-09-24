//! Real Ursula proof: conditional KV visibility, lost receipts and disk recovery.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const p = core.protocol;
const s = p.State;
const t = std.testing;
const Engine = core.Engine(adapter.Store);
const Clock = struct {
    now: u64 = 1000,
    fn read(context: *anyopaque) !core.Time.Sample {
        const self: *Clock = @ptrCast(@alignCast(context));
        return .{ .unix_ms = self.now };
    }
};
fn signed(e: *Engine, key: p.Ed25519.KeyPair, principal: u8, command: p.Command) !p.SignedRequest {
    return p.sign(.{ .realm = e.state.realm, .principal = principal, .sequence = (try e.state.principal(principal)).sequence + 1, .command = command }, key);
}
fn submit(e: *Engine, key: p.Ed25519.KeyPair, principal: u8, command: p.Command) !u64 {
    return e.submit(try signed(e, key, principal, command));
}
fn open(e: *Engine, root: p.Ed25519.KeyPair, worker: p.Ed25519.KeyPair) !u64 {
    const input = try submit(e, root, 0, .{ .send = .{ .pid = 1, .value = try p.Value.init("update") } });
    const process = try e.state.process(1);
    return submit(e, worker, 1, .{ .state = .{ .open = .{ .pid = 1, .generation = process.generation, .input = input, .expected_revision = process.revision, .resource = 3, .revision = (try e.state.resources.?.resource(3)).meta.revision, .deadline_ms = 2000 } } });
}
fn turn(e: *Engine, view_id: u64, value: ?p.Value) !p.Command {
    const view = (try e.state.resources.?.view(view_id)).meta;
    return .{ .state = .{ .turn = .{ .turn = .{ .pid = 1, .generation = view.generation, .input = view.input, .expected_revision = view.process_revision, .result = .{} }, .views = .{ view_id, null, null, null }, .write_view = view_id, .mutations = .{ .{ .key = try p.Value.init("count"), .value = value }, null, null, null } } } };
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const genesis: core.Genesis = .{ .realm = 49, .root_key = root.public_key.toBytes(), .retry_policy = .last_per_principal, .max_clock_error_ms = 0 };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-state", .name = "authority" } } };
    const e = try init.gpa.create(Engine);
    defer init.gpa.destroy(e);
    const write = std.mem.eql(u8, args[2], "write");
    if (write) try store.journal.create();
    e.* = if (write) try Engine.bootstrap(&store, genesis) else try Engine.open(&store, genesis);
    var clock: Clock = .{};
    e.clock = .{ .context = &clock, .read = Clock.read };
    if (write) {
        _ = try submit(e, root, 0, .{ .spawn = .{ .allow_trim = true } });
        _ = try submit(e, root, 0, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute), .pid = 1 } });
        _ = try submit(e, root, 0, .{ .state = .{ .create = .{ .writer = 1, .history_ms = 0, .deadline_ms = 4000 } } });
        for (0..2) |principal| _ = try submit(e, root, 0, .{ .state = .{ .grant = .{ .resource = 3, .subject = @intCast(principal), .permissions = s.all_permissions } } });
        _ = try submit(e, root, 0, .{ .state = .{ .associate = .{ .pid = 1, .name = try p.Value.init("state"), .resource = 3 } } });
        _ = try submit(e, root, 0, .{ .own = .{ .pid = 1, .expected_generation = 1, .worker = 1 } });
        const view = try open(e, root, worker);
        const request = try signed(e, worker, 1, try turn(e, view, p.Value.integer(12)));
        const candidate = try e.prepare(request);
        try t.expect((try e.state.resources.?.resource(3)).entries[0] == null);
        var second_store: adapter.Store = .{ .journal = store.journal };
        const competing = try init.gpa.create(Engine);
        defer init.gpa.destroy(competing);
        competing.* = try Engine.open(&second_store, genesis);
        competing.clock = e.clock;
        const loser = try competing.prepare(request);
        _ = try e.commit(candidate); // Discard the receipt deliberately.
        try t.expectError(error.Conflict, competing.commit(loser));
        try t.expectEqual(candidate.record.position, try competing.submit(request));
        // Persist a view but abandon a prepared turn. SIGKILL follows this phase.
        const pending = try open(e, root, worker);
        _ = try e.prepare(try signed(e, worker, 1, try turn(e, pending, p.Value.integer(999))));
    } else if (std.mem.eql(u8, args[2], "recover")) {
        try t.expectEqual(12, try (try e.state.resources.?.resource(3)).entries[0].?.value.asInteger());
        try t.expectEqual(1, (try e.state.process(1)).consumed);
        const snapshot = e.state.resources.?.views[0].?;
        try t.expectEqual(12, try snapshot.entries[0].?.value.asInteger());
        _ = try submit(e, worker, 1, try turn(e, snapshot.meta.id, p.Value.integer(13)));
        _ = try submit(e, root, 0, .{ .checkpoint = {} });
        try store.publishCheckpoint(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        try t.expectEqual(13, try (try e.state.resources.?.resource(3)).entries[0].?.value.asInteger());
        // More entries than either the public read page or adapter replay window.
        var last_request: p.SignedRequest = undefined;
        for (0..8) |batch| {
            const view = try open(e, root, worker);
            var command = try turn(e, view, null);
            for (&command.state.turn.mutations, 0..) |*mutation, offset| {
                var key: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&key, "entry-{d}", .{batch * 4 + offset});
                mutation.* = if (batch == 7 and offset == 3) null else .{ .key = try p.Value.init(text), .value = try p.Value.init(&@as([p.Value.max_bytes]u8, @splat(97))) };
            }
            last_request = try signed(e, worker, 1, command);
            _ = try e.submit(last_request);
        }
        _ = try submit(e, root, 0, .{ .checkpoint = {} });
        const checkpoint = try core.Checkpoint.create(init.gpa, genesis, &e.state);
        try store.maintain(&checkpoint);
        try store.maintain(&checkpoint);
        try t.expectError(error.HistoryReclaimed, store.read(0));
        // The original view-opening record is gone, but receipt permissions
        // survive in the checkpoint. Recovery cannot broaden those permissions.
        const recovered = try init.gpa.create(Engine);
        defer init.gpa.destroy(recovered);
        recovered.* = try Engine.open(&store, genesis);
        recovered.clock = e.clock;
        const receipt = (try recovered.state.principal(1)).receipt;
        try t.expectEqual(receipt, try recovered.submit(last_request));
        _ = try submit(recovered, root, 0, .{ .state = .{ .grant = .{ .resource = 3, .subject = 1, .permissions = 1 } } });
        try t.expectError(error.Forbidden, recovered.submit(last_request));
        _ = try submit(recovered, root, 0, .{ .state = .{ .grant = .{ .resource = 3, .subject = 1, .permissions = 7 } } });
        try t.expectEqual(receipt, try recovered.submit(last_request));
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        const data = try e.state.resources.?.resource(3);
        var count: usize = 0;
        for (data.entries) |entry| if (entry != null) {
            count += 1;
        };
        try t.expectEqual(32, count);
        try t.expectEqual(13, try data.entries[0].?.value.asInteger());
        var view = try open(e, root, worker);
        _ = try submit(e, worker, 1, try turn(e, view, null));
        view = try open(e, root, worker);
        _ = try submit(e, worker, 1, try turn(e, view, p.Value.integer(14)));
        clock.now = 4000;
        try t.expectError(error.StateResourceExpired, submit(e, root, 0, .{ .own = .{ .pid = 1, .expected_generation = (try e.state.process(1)).generation, .worker = 1 } }));
        _ = try submit(e, root, 0, .{ .state = .{ .expire = 3 } });
        _ = try submit(e, root, 0, .{ .state = .{ .reclaim = 3 } });
        _ = try submit(e, root, 0, .{ .checkpoint = {} });
        try store.maintain(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
        const recovered = try Engine.open(&store, genesis);
        try t.expect(std.meta.eql(e.state, recovered.state));
        try t.expectEqual(.expired, (try e.state.process(1)).lifecycle);
    } else return error.UnknownPhase;
    std.debug.print("state {s}: passed\n", .{args[2]});
    if (std.mem.eql(u8, args[2], "checkpoint")) std.debug.print("state bounds: catalog={d} core={d} view={d} page={d} store={d} bytes; 32 live keys, page=8, replay window=16\n", .{ @sizeOf(core.resources.Catalog), @sizeOf(core.State), @sizeOf(core.resources.Snapshot), @sizeOf(s.Page), @sizeOf(adapter.Store) });
}
