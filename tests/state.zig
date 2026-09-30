//! Real Ursula proof: conditional KV visibility, lost receipts and disk recovery.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const p = core.protocol;
const s = p.State;
const t = std.testing;
const disk = @import("native_disk.zig");
const g = disk.g;
const Engine = disk.Engine;
const Clock = struct {
    now: u64 = 1000,
    fn read(context: *anyopaque) !core.Time.Sample {
        const self: *Clock = @ptrCast(@alignCast(context));
        return .{ .unix_ms = self.now };
    }
};
fn signed(e: *Engine, key: p.Ed25519.KeyPair, principal: u8, command: p.Command) !p.SignedRequest {
    return p.sign(.{ .realm = e.genesis.realm, .principal = principal, .sequence = (try e.principal(principal)).sequence + 1, .command = command }, key);
}
fn submit(e: *Engine, key: p.Ed25519.KeyPair, principal: u8, command: p.Command) !u64 {
    return e.submit(try signed(e, key, principal, command));
}
fn resource(e: *Engine) !g.Resource {
    return disk.record(e, g.Resource, .resource, 3);
}
fn count(e: *Engine) !i64 {
    return (try disk.entry(e, 3, "count")).?.value.asInteger();
}
fn open(e: *Engine, root: p.Ed25519.KeyPair, worker: p.Ed25519.KeyPair) !u64 {
    const input = try submit(e, root, 0, .{ .send = .{ .pid = 1, .value = try p.Value.init("update") } });
    const process = try e.process(1);
    return submit(e, worker, 1, .{ .open_view = .{ .pid = 1, .generation = process.generation, .input = input, .expected_revision = process.revision, .resource = 3, .revision = (try resource(e)).revision, .deadline_ms = 2000 } });
}
fn turn(e: *Engine, view_id: u64, value: ?p.Value) !p.Command {
    const view = (try disk.record(e, core.growing.StoredView, .view, view_id)).meta;
    return .{ .turn = .{ .pid = 1, .generation = view.generation, .input = view.input, .expected_revision = view.process_revision, .views = .{ view_id, null, null, null }, .write_view = view_id, .mutations = .{ .{ .key = try p.Value.init("count"), .value = value }, null, null, null } } };
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const genesis: core.Genesis = .{ .realm = 49, .root_key = root.public_key.toBytes(), .allow_history_trim = true, .max_clock_error_ms = 0 };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-state", .name = "authority" } } };
    var pages = try adapter.PackedPageStore.init(init.gpa, store.journal, 8);
    defer pages.deinit();
    const e = try init.gpa.create(Engine);
    defer init.gpa.destroy(e);
    const write = std.mem.eql(u8, args[2], "write");
    if (write) {
        try store.journal.create();
        try pages.create();
    }
    e.* = if (write) try Engine.bootstrap(&store, &pages, genesis) else try Engine.open(&store, &pages, genesis);
    var clock: Clock = .{};
    e.clock = .{ .context = &clock, .read = Clock.read };
    if (write) {
        _ = try submit(e, root, 0, .{ .spawn = .{ .allow_collection = true } });
        _ = try submit(e, root, 0, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute), .pid = 1 } });
        _ = try submit(e, root, 0, .{ .create_resource = .{ .writer = 1, .history_ms = 0, .deadline_ms = 4000 } });
        for (0..2) |principal| _ = try submit(e, root, 0, .{ .grant_resource = .{ .resource = 3, .subject = @intCast(principal), .permissions = s.all_permissions } });
        _ = try submit(e, root, 0, .{ .associate = .{ .pid = 1, .name = try p.Value.init("state"), .resource = 3 } });
        _ = try submit(e, root, 0, .{ .own = .{ .pid = 1, .expected_generation = 1, .worker = 1 } });
        const view = try open(e, root, worker);
        const request = try signed(e, worker, 1, try turn(e, view, p.Value.integer(12)));
        const candidate = try e.prepare(request);
        try t.expect(try disk.entry(e, 3, "count") == null);
        var second_store: adapter.Store = .{ .journal = store.journal };
        const competing = try init.gpa.create(Engine);
        defer init.gpa.destroy(competing);
        competing.* = try Engine.open(&second_store, &pages, genesis);
        competing.clock = e.clock;
        const loser = try competing.prepare(request);
        _ = try e.commit(candidate); // Discard the receipt deliberately.
        try t.expectError(error.Conflict, competing.commit(loser));
        try t.expectEqual(candidate.record.position, try competing.submit(request));
        // Persist a view but abandon a prepared turn. SIGKILL follows this phase.
        const pending = try open(e, root, worker);
        _ = try e.prepare(try signed(e, worker, 1, try turn(e, pending, p.Value.integer(999))));
    } else if (std.mem.eql(u8, args[2], "recover")) {
        try t.expectEqual(12, try count(e));
        try t.expectEqual(1, (try e.process(1)).consumed);
        // The final accepted operation opened a view; the private candidate
        // containing 999 never became an authority root.
        const snapshot = try disk.record(e, core.growing.StoredView, .view, e.head.position - 1);
        var captured = try core.catalog.Catalog(adapter.PackedPageStore).open(&pages, snapshot.snapshot);
        const captured_entry = (try captured.get(g.Entry, try core.catalog.key(.entry, 3, 0, "count"))).?;
        try t.expectEqual(12, try captured_entry.value.asInteger());
        _ = try submit(e, worker, 1, try turn(e, snapshot.meta.id, p.Value.integer(13)));
        _ = try submit(e, root, 0, .{ .checkpoint = {} });
        try disk.publish(&store);
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        try t.expectEqual(13, try count(e));
        // More entries than either the public read page or adapter replay window.
        var last_request: p.SignedRequest = undefined;
        for (0..8) |batch| {
            const view = try open(e, root, worker);
            var command = try turn(e, view, null);
            for (&command.turn.mutations, 0..) |*mutation, offset| {
                var key: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&key, "entry-{d}", .{batch * 4 + offset});
                mutation.* = if (batch == 7 and offset == 3) null else .{ .key = try p.Value.init(text), .value = try p.Value.init(&@as([p.Value.max_bytes]u8, @splat(97))) };
            }
            last_request = try signed(e, worker, 1, command);
            _ = try e.submit(last_request);
        }
        _ = try submit(e, root, 0, .{ .checkpoint = {} });
        try store.maintain(e.head);
        try store.maintain(e.head);
        try t.expectError(error.HistoryReclaimed, store.read(0));
        // The original view-opening record is gone, but receipt permissions
        // survive in the checkpoint. Recovery cannot broaden those permissions.
        const recovered = try init.gpa.create(Engine);
        defer init.gpa.destroy(recovered);
        recovered.* = try Engine.open(&store, &pages, genesis);
        recovered.clock = e.clock;
        const receipt = try recovered.submit(last_request);
        try t.expectEqual(receipt, try recovered.submit(last_request));
        _ = try submit(recovered, root, 0, .{ .grant_resource = .{ .resource = 3, .subject = 1, .permissions = 1 } });
        try t.expectError(error.Forbidden, recovered.submit(last_request));
        _ = try submit(recovered, root, 0, .{ .grant_resource = .{ .resource = 3, .subject = 1, .permissions = 7 } });
        try t.expectEqual(receipt, try recovered.submit(last_request));
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        var current = try e.state();
        var after: ?core.pages.Key = null;
        var entries: usize = 0;
        while (true) {
            const batch = try current.scan(g.Entry, .{ .namespace = .entry, .major = 3 }, after);
            for (batch.records) |slot| if (slot != null) {
                entries += 1;
            };
            after = batch.next;
            if (after == null) break;
        }
        try t.expectEqual(32, entries);
        try t.expectEqual(13, try count(e));
        var view = try open(e, root, worker);
        _ = try submit(e, worker, 1, try turn(e, view, null));
        view = try open(e, root, worker);
        _ = try submit(e, worker, 1, try turn(e, view, p.Value.integer(14)));
        clock.now = 4000;
        try t.expectError(error.StateResourceExpired, submit(e, root, 0, .{ .own = .{ .pid = 1, .expected_generation = (try e.process(1)).generation, .worker = 1 } }));
        _ = try submit(e, root, 0, .{ .expire_resource = 3 });
        _ = try submit(e, root, 0, .{ .expire = 1 });
        var batches: usize = 0;
        while ((try resource(e)).phase != .reclaimed) : (batches += 1) {
            try t.expect(batches < 32);
            _ = try submit(e, root, 0, .{ .reclaim_resource = 3 });
        }
        try t.expect(batches > 1);
        _ = try submit(e, root, 0, .{ .checkpoint = {} });
        try store.maintain(e.head);
        const recovered = try Engine.open(&store, &pages, genesis);
        try t.expect(std.meta.eql(e.head, recovered.head));
        try t.expectEqual(.expired, (try e.process(1)).lifecycle);
    } else return error.UnknownPhase;
    std.debug.print("state {s}: passed\n", .{args[2]});
    if (std.mem.eql(u8, args[2], "checkpoint")) std.debug.print("state bounds: authority={d} bytes, resident pages={d}; 32 live keys, read page=8\n", .{ @sizeOf(Engine), pages.residentBytes() });
}
