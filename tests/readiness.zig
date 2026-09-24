//! Persistent reclamation proof. No recycled protocol identities after trim.
const std = @import("std");
const core = @import("transit_core");
const backend = @import("transit_backend_ursula");
const p = core.protocol;
const t = std.testing;
const Engine = core.Engine(backend.Store);
const Clock = struct {
    now: u64 = 1000,
    fn read(context: *anyopaque) !core.Time.Sample {
        const self: *Clock = @ptrCast(@alignCast(context));
        return .{ .unix_ms = self.now };
    }
};
fn send(e: *Engine, key: p.Ed25519.KeyPair, command: p.Command) !u64 {
    return e.submit(try p.sign(.{ .realm = e.state.realm, .principal = 0, .sequence = (try e.state.principal(0)).sequence + 1, .command = command }, key));
}
fn process(e: *Engine, key: p.Ed25519.KeyPair) !u64 {
    const pid = try send(e, key, .{ .spawn = .{ .allow_trim = true } });
    _ = try send(e, key, .{ .catalog_retention = .{ .pid = pid } });
    return pid;
}
fn collect(e: *Engine, key: p.Ed25519.KeyPair, pid: u64, kind: @FieldType(p.Collection, "kind"), id: u64) !void {
    _ = try send(e, key, .{ .collect = .{ .pid = pid, .kind = kind, .id = id } });
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const genesis: core.Genesis = .{ .realm = 81, .root_key = key.public_key.toBytes(), .retry_policy = .last_per_principal, .max_clock_error_ms = 0 };
    var client = try backend.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: backend.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-readiness", .name = "authority" } } };
    const e = try init.gpa.create(Engine);
    defer init.gpa.destroy(e);
    const write = std.mem.eql(u8, args[2], "write");
    if (write) try store.journal.create();
    e.* = if (write) try Engine.bootstrap(&store, genesis) else try Engine.open(&store, genesis);
    var clock: Clock = .{};
    e.clock = .{ .context = &clock, .read = Clock.read };
    if (write) {
        const source = try process(e, key);
        const destination = try process(e, key);
        for ([_]u64{ source, destination }) |pid| _ = try send(e, key, .{ .own = .{ .pid = pid, .expected_generation = 0, .worker = 0 } });
        for (0..p.max_outputs + 1) |_| {
            const input = try send(e, key, .{ .send = .{ .pid = source, .value = .{} } });
            const effect = try send(e, key, .{ .turn = .{ .pid = source, .generation = 1, .input = input, .expected_revision = (try e.state.process(source)).revision, .result = .{}, .effect = .{}, .outputs = .{ .{ .pid = destination, .value = .{} }, null, null, null } } });
            _ = try send(e, key, .{ .deliver_next = {} });
            try collect(e, key, source, .output, e.state.output_count);
            const delivered = (try e.nextInput(destination, e.state.position)).?;
            try t.expectEqual(source, (try e.state.inputOf(delivered)).origin.source.process.pid);
            _ = try send(e, key, .{ .turn = .{ .pid = destination, .generation = 1, .input = delivered.position, .expected_revision = (try e.state.process(destination)).revision, .result = .{} } });
            const attempt = try send(e, key, .{ .dispatch = .{ .pid = source, .effect = effect } });
            _ = try send(e, key, .{ .close_effect = .{ .pid = source, .effect = effect, .attempt = attempt } });
            try collect(e, key, source, .effect, effect);
        }
        for ([_]u64{ source, destination }) |pid| {
            _ = try send(e, key, .{ .terminate = pid });
            try collect(e, key, pid, .process, pid);
        }
        for (0..p.max_processes + 1) |_| {
            const pid = try process(e, key);
            const resource = try send(e, key, .{ .state = .{ .create = .{ .writer = pid, .history_ms = 0 } } });
            _ = try send(e, key, .{ .terminate = pid });
            _ = try send(e, key, .{ .state = .{ .reclaim = resource } });
            try collect(e, key, pid, .resource, resource);
            try collect(e, key, pid, .process, pid);
        }
        const managed = try send(e, key, .{ .lifecycle = .{ .create = .{ .allow_trim = true, .collect_catalog = true, .required = .{ try p.Value.init("state"), null, null, null } } } });
        _ = try send(e, key, .{ .state = .{ .create = .{ .writer = managed, .history_ms = 0 } } });
        // Stop between resource allocation and initialization completion.
    } else {
        try t.expectEqual(p.max_outputs + 1, e.state.output_count);
        try t.expectError(error.UnknownProcess, e.state.process(1));
        try t.expectError(error.UnknownOutput, e.state.output(1));
        const managed = &e.state.processes[0].?;
        const managed_pid = managed.pid;
        const resource = e.state.resources.?.resources[0].?.meta.id;
        for (e.state.processes[1..]) |slot| try t.expect(slot == null);
        for (e.state.resources.?.resources[1..]) |slot| try t.expect(slot == null);
        if (std.mem.eql(u8, args[2], "recover")) {
            try t.expectEqual(.initializing, managed.control.?.phase);
            try t.expectError(error.NotInitialized, send(e, key, .{ .own = .{ .pid = managed_pid, .expected_generation = 0, .worker = 0 } }));
            _ = try send(e, key, .{ .state = .{ .grant = .{ .resource = resource, .subject = 0, .permissions = 7 } } });
            _ = try send(e, key, .{ .state = .{ .associate = .{ .pid = managed_pid, .resource = resource, .name = try p.Value.init("state") } } });
            _ = try send(e, key, .{ .lifecycle = .{ .initialize = .{ .pid = managed_pid, .expected_generation = 1 } } });
            _ = try send(e, key, .{ .own = .{ .pid = managed_pid, .expected_generation = 2, .worker = 0 } });
            const input = try send(e, key, .{ .send = .{ .pid = managed_pid, .value = .{} } });
            _ = try send(e, key, .{ .turn = .{ .pid = managed_pid, .generation = 3, .input = input, .result = .{}, .failed = true } });
        } else if (std.mem.eql(u8, args[2], "checkpoint")) {
            const failure = managed.failure.?;
            _ = try send(e, key, .{ .lifecycle = .{ .retry = .{ .pid = managed_pid, .expected_generation = 4, .failure = failure.recorded_at } } });
            _ = try send(e, key, .{ .own = .{ .pid = managed_pid, .expected_generation = 5, .worker = 0 } });
            _ = try send(e, key, .{ .turn = .{ .pid = managed_pid, .generation = 6, .input = failure.input, .result = .{} } });
            _ = try send(e, key, .{ .lifecycle = .{ .@"suspend" = .{ .pid = managed_pid, .expected_generation = 6, .resume_before_ms = 2000 } } });
            _ = try send(e, key, .{ .checkpoint = {} });
            try store.maintain(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
        } else if (std.mem.eql(u8, args[2], "trim_recover")) {
            try t.expectEqual(.suspended, managed.control.?.phase);
            clock.now = 2000;
            try t.expectError(error.StateResourceExpired, send(e, key, .{ .lifecycle = .{ .@"resume" = .{ .pid = managed_pid, .expected_generation = 7 } } }));
            _ = try send(e, key, .{ .lifecycle = .{ .expire_suspension = managed_pid } });
            try t.expectEqual(.expired, (try e.state.process(managed_pid)).lifecycle);
            const frontier = e.state.position;
            const pid = try process(e, key);
            try t.expectEqual(frontier, pid);
            try t.expect(pid > 1);
            try t.expectError(error.UnknownProcess, send(e, key, .{ .own = .{ .pid = 1, .expected_generation = 0, .worker = 0 } }));
            try t.expectError(error.UnknownOutput, send(e, key, .{ .deliver = .{ .pid = pid, .output = 1, .courier = 0 } }));
        } else return error.UnknownPhase;
    }
    std.debug.print("readiness {s}: passed\n", .{args[2]});
}
