//! Explicit test application over public Station/client APIs and real authority.
const std = @import("std");
const t = std.testing;
const q = @import("transit_query");
const s = @import("transit_station");
const p = s.protocol;
const g = p.Growth;
const r = q.TableMutationRecords;
const admission = q.TableMutationAdmission;
const Admin = @import("growing_support.zig").Admin(46);
const Config = struct { definition: g.Definition, writer: Admin.Provision };
// Test-fixture persistence only. The mandatory definition and canonical equality
// prevent missing/defaulted fields from turning a saved proposal into new work.
const Frozen = struct { definition: g.Definition, signed: g.SignedRequest };
const Handler = struct {
    fn initialize(_: ?*anyopaque, turn: *s.Turn) !void {
        const origin = turn.delivery.input.origin;
        if (origin != .external or origin.external.principal != 0) return error.InvalidInitializer;
        const table = try s.Table.create(turn, 1, .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .utf8 });
        try admission.setPolicy(turn, 0, .{ .principal = 1234, .table = 1, .revision = 1, .declaration = try r.declaration(table), .permissions = 7 });
    }
    fn handle(_: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
        if (turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == 0) {
            const code = try frame.payload.asInteger();
            if (code == -1) return;
            if (code == -2) {
                var grant = (try admission.policy(turn, 1234, 1)).?;
                const expected = grant.revision;
                grant.revision += 1;
                grant.permissions = 0;
                return admission.setPolicy(turn, expected, grant);
            }
            return error.InvalidConfigurationCommand;
        }
        _ = try admission.dispatch(turn);
    }
    const interface: s.GenServer.Handler = .{ .initialize = initialize, .handle = handle };
};
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.real.now(io).toMilliseconds());
}
fn drive(io: std.Io, server: *s.GenServer, freeze: bool) !void {
    for (0..24) |_| {
        if (freeze and server.pending != null and server.pending_kind == .commit) return;
        switch (try server.step(Handler.interface, now(io) + 30000)) {
            .committed => return,
            .blocked => return server.handler_error orelse error.BehaviorBlocked,
            .idle => return error.MissingInput,
            .progress => {},
        }
    }
    return error.StepBudgetExceeded;
}
fn path(init: std.process.Init, directory: []const u8, name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
}
fn save(init: std.process.Init, directory: []const u8, name: []const u8, value: anytype) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try path(init, directory, name), .data = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{}) });
}
fn load(comptime T: type, init: std.process.Init, directory: []const u8, name: []const u8) !T {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, try path(init, directory, name), init.arena.allocator(), .limited(65536));
    const value = try std.json.parseFromSliceLeaky(T, init.arena.allocator(), bytes, .{});
    if (!std.mem.eql(u8, bytes, try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{}))) return error.NoncanonicalFixture;
    return value;
}
fn print(init: std.process.Init, value: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(value, .{}, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
fn makeServer(wire: *s.client.Client, config: Config) !s.GenServer {
    return s.GenServer.init(.{ .client = wire, .realm = 46, .principal = 65536, .pid = config.writer.pid, .generation = config.writer.generation, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) }, "state");
}
fn send(wire: *s.client.Client, config: Config, command: r.Command) !p.Receipt {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
    const sequence = (try wire.query(.{ .realm = 46, .principal = 1234, .kind = .capabilities }, key)).principal_sequence + 1;
    return wire.submit(try g.sign(.{ .realm = 46, .principal = 1234, .sequence = sequence, .command = .{ .send = .{ .pid = config.writer.pid, .value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, key));
}
fn applyCommand(init: std.process.Init, wire: *s.client.Client, config: Config, command: r.Command, freeze: bool) !s.GenServer {
    _ = try send(wire, config, command);
    var worker = try makeServer(wire, config);
    try drive(init.io, &worker, freeze);
    // No pointer into this local worker is used after return. Frozen Pending owns
    // its full native request; later steps create a fresh Session.
    return worker;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const root = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    if (args.len == 2 and std.mem.eql(u8, args[1], "public")) return print(init, root.public_key.toBytes());
    if (args.len < 4) return error.Usage;
    const mode = args[2];
    const directory = args[3];
    var wire = s.client.Client.init(init.gpa, init.io, args[1]);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    errdefer if (wire.last_rejection) |reason| std.debug.print("Authority rejection: {s}\n", .{@tagName(reason)});
    var admin: Admin = .{ .wire = &wire, .key = root };
    admin.sequence = (try admin.query(.capabilities)).principal_sequence;
    if (std.mem.eql(u8, mode, "provision")) {
        const writer = try admin.provision(65536, try p.Ed25519.KeyPair.generateDeterministic(@splat(8)));
        const caller = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
        _ = try admin.submit(.{ .grant = .{ .subject = 1234, .public_key = caller.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) } });
        _ = try admin.submit(.{ .grant_resource = .{ .resource = writer.resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        const config: Config = .{ .definition = g.current_definition, .writer = writer };
        var worker = try makeServer(&wire, config);
        try admin.send(writer.pid, -1);
        try drive(init.io, &worker, false);
        try save(init, directory, "mutation.json", config);
        return print(init, config);
    }
    var config = try load(Config, init, directory, "mutation.json");
    if (std.mem.eql(u8, mode, "stage")) {
        if (args.len != 6) return error.Usage;
        const namespace = try std.fmt.parseInt(u64, args[4], 10);
        var resource = try (s.client.ResourceReader{ .wire = &wire, .realm = 46, .principal = 1234, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) }).open(config.writer.resource);
        const table = try s.Table.open(&resource, 1);
        const grant = (try admission.policy(&resource, 1234, 1)).?;
        const request = try q.TableMutationRequest.fromSql(46, config.writer.pid, table, try .init("items"), args[5]);
        const ref = try request.reference(namespace);
        _ = try applyCommand(init, &wire, config, .{ .begin = .{ .reference = ref, .table = 1, .policy_revision = grant.revision } }, false);
        var buffer: [q.TableMutationRequest.max_bytes]u8 = undefined;
        const bytes = try request.encode(&buffer);
        for (0..ref.spec.chunks()) |ordinal| {
            const offset = ordinal * s.Publication.chunk_bytes;
            const chunk = bytes[offset..][0..try ref.spec.size(@intCast(ordinal))];
            _ = try applyCommand(init, &wire, config, .{ .part = .{ .namespace = namespace, .ordinal = @intCast(ordinal), .second = false, .bytes = chunk[0..@min(chunk.len, r.part_bytes)] } }, false);
            if (chunk.len > r.part_bytes) _ = try applyCommand(init, &wire, config, .{ .part = .{ .namespace = namespace, .ordinal = @intCast(ordinal), .second = true, .bytes = chunk[r.part_bytes..] } }, false);
        }
        _ = try applyCommand(init, &wire, config, .{ .seal = namespace }, false);
        return print(init, .{ .staged = namespace });
    }
    if (std.mem.eql(u8, mode, "prepare")) {
        if (args.len != 5) return error.Usage;
        const namespace = try std.fmt.parseInt(u64, args[4], 10);
        const worker = try applyCommand(init, &wire, config, .{ .apply = namespace }, true);
        try t.expect(worker.pending_kind == .commit);
        const pending = worker.pending.?.signed;
        try save(init, directory, "mutation-commit.json", Frozen{ .definition = g.current_definition, .signed = pending });
        var count: usize = 0;
        for (pending.request.command.turn.mutations) |slot| if (slot != null) {
            count += 1;
        };
        return print(init, .{ .input = pending.request.command.turn.input, .mutations = count });
    }
    if (std.mem.eql(u8, mode, "stale-view")) {
        if (args.len != 6) return error.Usage;
        _ = try send(&wire, config, .{ .apply = try std.fmt.parseInt(u64, args[4], 10) });
        var worker = try makeServer(&wire, config);
        const delivery = (try worker.session.receive()).?;
        var resource = (try admin.query(.{ .resource = config.writer.resource })).body.resource;
        const old = try std.fmt.parseInt(u64, args[5], 10);
        try t.expect(old < resource.revision);
        resource.revision = old;
        const pending = try worker.session.prepareView(delivery, resource, now(init.io) + 30000);
        return print(init, try pending.submit(&wire));
    }
    if (std.mem.eql(u8, mode, "commit") or std.mem.eql(u8, mode, "changed-retry")) {
        var pending = try load(Frozen, init, directory, "mutation-commit.json");
        if (std.mem.eql(u8, mode, "changed-retry")) {
            pending.signed.request.command.turn.mutations[0].?.value = try p.Value.init("changed");
            pending.signed = try g.sign(pending.signed.request, try p.Ed25519.KeyPair.generateDeterministic(@splat(8)));
        }
        return print(init, try wire.submit(pending.signed));
    }
    if (std.mem.eql(u8, mode, "apply") or std.mem.eql(u8, mode, "cancel")) {
        if (args.len != 5) return error.Usage;
        const namespace = try std.fmt.parseInt(u64, args[4], 10);
        _ = try applyCommand(init, &wire, config, if (std.mem.eql(u8, mode, "apply")) .{ .apply = namespace } else .{ .cancel = namespace }, false);
        return print(init, .{ .completed = namespace });
    }
    if (std.mem.eql(u8, mode, "resume")) {
        var worker = try makeServer(&wire, config);
        try drive(init.io, &worker, false);
        return print(init, .{ .resumed = true });
    }
    if (std.mem.eql(u8, mode, "reown")) {
        _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .worker = 65536 } });
        config.writer.generation += 1;
        try save(init, directory, "mutation.json", config);
        return print(init, .{ .generation = config.writer.generation });
    }
    if (std.mem.eql(u8, mode, "revoke-writer") or std.mem.eql(u8, mode, "restore-writer") or std.mem.eql(u8, mode, "revoke-reader")) {
        const revoke_reader = std.mem.eql(u8, mode, "revoke-reader");
        _ = try admin.submit(.{ .grant_resource = .{ .resource = config.writer.resource, .subject = if (revoke_reader) 1234 else 65536, .permissions = if (std.mem.eql(u8, mode, "restore-writer")) p.State.all_permissions else if (revoke_reader) 0 else p.State.permission(.inspect) | p.State.permission(.read) } });
        return print(init, .{ .changed = true });
    }
    if (std.mem.eql(u8, mode, "revoke-policy")) {
        try admin.send(config.writer.pid, -2);
        var worker = try makeServer(&wire, config);
        try drive(init.io, &worker, false);
        return print(init, .{ .revoked = true });
    }
    if (std.mem.eql(u8, mode, "progress")) {
        const current = (try admin.query(.{ .process = config.writer.pid })).body.process;
        return print(init, .{ .admitted = current.process.admitted, .consumed = current.process.consumed, .pending = if (current.input) |value| value.position else @as(?u64, null) });
    }
    if (std.mem.eql(u8, mode, "inspect")) {
        if (args.len != 5) return error.Usage;
        const namespace = try std.fmt.parseInt(u64, args[4], 10);
        var resource = try (s.client.ResourceReader{ .wire = &wire, .realm = 46, .principal = 1234, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) }).open(config.writer.resource);
        const status_entry = (try resource.entry(r.key('u', namespace, 0))) orelse return error.MutationNotFound;
        const current = try r.Status.decode(status_entry.value);
        const table = try s.Table.open(&resource, 1);
        var rows: [3]?struct { value: ?p.Value, revision: u64 } = @splat(null);
        for (&rows, 1..) |*slot, key| if (try resource.entry(s.Table.rowKey(1, @intCast(key)))) |entry| {
            const cell = try table.decodeCell(entry.value);
            slot.* = .{ .value = if (cell == .null) null else try p.Value.init(cell.utf8.slice()), .revision = entry.revision };
        };
        return print(init, .{ .phase = current.phase, .reason = current.reason, .affected_rows = current.affected_rows, .input = current.input, .result_revision = status_entry.revision, .resource_revision = resource.view.revision, .rows = rows, .row_zero = try resource.entry(s.Table.rowKey(1, 0)) });
    }
    return error.InvalidMode;
}
