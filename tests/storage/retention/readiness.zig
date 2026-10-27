//! Persistent reclamation proof. No recycled protocol identities after trim.
const std = @import("std");
const core = @import("transit_core");
const backend = @import("transit_backend_ursula");
const p = core.protocol;
const t = std.testing;
const disk = @import("fixture_native_disk");
const g = disk.g;
const Engine = disk.Engine;
const Clock = struct {
    now: u64 = 1000,
    fn read(context: *anyopaque) !core.Time.Sample {
        const self: *Clock = @ptrCast(@alignCast(context));
        return .{ .unix_ms = self.now };
    }
};
fn send(e: *Engine, key: p.Ed25519.KeyPair, command: p.Command) !u64 {
    return disk.submit(e, key, 0, command);
}
fn process(e: *Engine, key: p.Ed25519.KeyPair) !u64 {
    const pid = try send(e, key, .{ .spawn = .{ .allow_collection = true } });
    return pid;
}
fn collect(e: *Engine, key: p.Ed25519.KeyPair, pid: u64, kind: @FieldType(g.Collection, "kind"), id: u64) !void {
    _ = try send(e, key, .{ .collect = .{ .pid = pid, .kind = kind, .id = id } });
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const genesis: core.Genesis = .{ .realm = 81, .root_key = key.public_key.toBytes(), .allow_history_trim = true, .max_clock_error_ms = 0 };
    var client = try backend.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: backend.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-readiness", .name = "authority" } } };
    var pages = try backend.PackedPageStore.init(init.gpa, store.journal, 8);
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
        const source = try process(e, key);
        const destination = try process(e, key);
        for ([_]u64{ source, destination }) |pid| _ = try send(e, key, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 0 } });
        for (0..65) |_| {
            const input = try send(e, key, .{ .send = .{ .pid = source, .value = .{} } });
            const effect = try send(e, key, .{ .turn = .{ .pid = source, .generation = 1, .input = input, .expected_revision = (try e.process(source)).revision, .effect = .{}, .outputs = .{ .{ .pid = destination, .value = .{} }, null, null, null } } });
            _ = try send(e, key, .{ .deliver = e.head.outputs });
            try collect(e, key, source, .output, e.head.outputs);
            const delivered = (try disk.input(e, destination)).?;
            try t.expectEqual(source, delivered.origin.process.pid);
            _ = try send(e, key, .{ .turn = .{ .pid = destination, .generation = 1, .input = delivered.position, .expected_revision = (try e.process(destination)).revision } });
            const attempt = try send(e, key, .{ .dispatch = .{ .pid = source, .effect = effect } });
            _ = try send(e, key, .{ .close_effect = .{ .pid = source, .effect = effect, .attempt = attempt } });
            try collect(e, key, source, .effect, effect);
        }
        for ([_]u64{ source, destination }) |pid| {
            _ = try send(e, key, .{ .terminate = pid });
            while (true) {
                _ = e.process(pid) catch |err| {
                    if (err == error.RetiredProcess) break;
                    return err;
                };
                try collect(e, key, pid, .process, pid);
            }
        }
        for (0..65) |_| {
            const pid = try process(e, key);
            const resource = try send(e, key, .{ .create_resource = .{ .writer = pid, .history_ms = 0 } });
            _ = try send(e, key, .{ .terminate = pid });
            _ = try send(e, key, .{ .retire_resource = resource });
            _ = try send(e, key, .{ .reclaim_resource = resource });
            // Collection retires authorization before deleting the resource
            // metadata. The intermediate phase must still prevent PID removal.
            try collect(e, key, pid, .resource, resource);
            var policy = try e.authorization();
            try t.expect((try policy.object(.{ .kind = .resource, .id = resource })).?.retired);
            _ = try disk.record(e, g.Resource, .resource, resource);
            try t.expectError(error.StateResourceInUse, collect(e, key, pid, .process, pid));
            try collect(e, key, pid, .resource, resource);
            try t.expectError(error.MissingFixtureRecord, disk.record(e, g.Resource, .resource, resource));
            while (true) {
                _ = e.process(pid) catch |err| {
                    if (err == error.RetiredProcess) break;
                    return err;
                };
                try collect(e, key, pid, .process, pid);
            }
        }
        const managed = try send(e, key, .{ .create = .{ .process = .{ .allow_collection = true }, .required = .{ try p.Value.init("state"), null, null, null } } });
        _ = try send(e, key, .{ .create_resource = .{ .writer = managed, .history_ms = 0 } });
        // Stop between resource allocation and initialization completion.
    } else {
        try t.expectEqual(65, e.head.outputs);
        try t.expectError(error.RetiredProcess, e.process(1));
        var catalog = try e.state();
        try t.expect(try catalog.get(g.Outbox, core.growing.address(.output, 1)) == null);
        const live_processes = try catalog.scan(g.Process, .{ .namespace = .process }, null);
        const managed = live_processes.records[0].?.value;
        try t.expect(live_processes.records[1] == null and live_processes.next == null);
        const live_resources = try catalog.scan(g.Resource, .{ .namespace = .resource }, null);
        const resource = live_resources.records[0].?.value.id;
        try t.expect(live_resources.records[1] == null and live_resources.next == null);
        const managed_pid = managed.pid;
        if (std.mem.eql(u8, args[2], "recover")) {
            try t.expectEqual(.initializing, managed.control.?.phase);
            try t.expectError(error.InvalidLifecycle, send(e, key, .{ .own = .{ .pid = managed_pid, .expected_generation = 0, .worker = 0 } }));
            _ = try send(e, key, .{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = 7 } });
            _ = try send(e, key, .{ .associate = .{ .pid = managed_pid, .resource = resource, .name = try p.Value.init("state") } });
            _ = try send(e, key, .{ .initialize = .{ .pid = managed_pid, .expected_generation = 1 } });
            _ = try send(e, key, .{ .own = .{ .pid = managed_pid, .expected_generation = 2, .worker = 0 } });
            const input = try send(e, key, .{ .send = .{ .pid = managed_pid, .value = .{} } });
            _ = try send(e, key, .{ .turn = .{ .pid = managed_pid, .generation = 3, .input = input, .expected_revision = 0, .failed = true } });
        } else if (std.mem.eql(u8, args[2], "checkpoint")) {
            const failure = managed.failure.?;
            _ = try send(e, key, .{ .retry = .{ .pid = managed_pid, .expected_generation = 4, .failure_input = failure } });
            _ = try send(e, key, .{ .own = .{ .pid = managed_pid, .expected_generation = 5, .worker = 0 } });
            _ = try send(e, key, .{ .turn = .{ .pid = managed_pid, .generation = 6, .input = failure, .expected_revision = 0 } });
            _ = try send(e, key, .{ .@"suspend" = .{ .pid = managed_pid, .expected_generation = 6, .resume_before_ms = 2000 } });
            _ = try send(e, key, .{ .checkpoint = {} });
            try store.maintain(e.head);
        } else if (std.mem.eql(u8, args[2], "trim_recover")) {
            try t.expectEqual(.suspended, managed.control.?.phase);
            clock.now = 2000;
            try t.expectError(error.DeadlineExpired, send(e, key, .{ .@"resume" = .{ .pid = managed_pid, .expected_generation = 7 } }));
            _ = try send(e, key, .{ .expire_suspension = managed_pid });
            try t.expectEqual(.expired, (try e.process(managed_pid)).lifecycle);
            const frontier = e.head.position;
            const pid = try process(e, key);
            try t.expectEqual(frontier, pid);
            try t.expect(pid > 1);
            try t.expectError(error.RetiredProcess, send(e, key, .{ .own = .{ .pid = 1, .expected_generation = 0, .worker = 0 } }));
            try t.expectError(error.UnknownOutput, send(e, key, .{ .deliver = 1 }));
        } else return error.UnknownPhase;
    }
    std.debug.print("readiness {s}: passed\n", .{args[2]});
}
