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
const Staged = struct { definition: g.Definition, reference: s.PublicationReference };
const Frozen = struct { definition: g.Definition, signed: g.SignedRequest };
fn writerConfiguration(config: Config) q.TableMutationWriter.Configuration {
    return .{ .resource = config.writer.resource, .initializer = 0, .principal = 1234, .permissions = 7, .value_type = .utf8 };
}
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.real.now(io).toMilliseconds());
}
fn drive(io: std.Io, server: *s.GenServer, config: Config, freeze: bool) !void {
    var owner: q.TableMutationWriter = .{ .configuration = writerConfiguration(config) };
    server.input_guard = owner.guard();
    defer server.input_guard = null;
    for (0..24) |_| {
        if (freeze and server.pending != null and server.pending_kind == .commit) return;
        switch (try server.step(owner.interface(), now(io) + 30000)) {
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
fn stagedReference(init: std.process.Init, directory: []const u8, namespace: u64) !s.PublicationReference {
    const name = try std.fmt.allocPrint(init.arena.allocator(), "mutation-{d}.json", .{namespace});
    return (try load(Staged, init, directory, name)).reference;
}
fn saveReference(init: std.process.Init, directory: []const u8, ref: s.PublicationReference) !void {
    const name = try std.fmt.allocPrint(init.arena.allocator(), "mutation-{d}.json", .{ref.namespace});
    const existing = load(Staged, init, directory, name) catch |err| return if (err == error.FileNotFound)
        save(init, directory, name, Staged{ .definition = g.current_definition, .reference = ref })
    else
        err;
    if (!std.meta.eql(existing.reference, ref)) return error.MutationIdentityConflict;
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
    var caller = try mutationClient(wire, config);
    return caller.submit(try caller.prepare(command));
}
fn mutationClient(wire: *s.client.Client, config: Config) !q.TableMutationClient {
    return .{ .wire = wire, .connection = .{ .realm = 46, .principal = 1234, .writer = config.writer.pid, .resource = config.writer.resource, .table = 1 }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
}
fn savePrepared(init: std.process.Init, directory: []const u8, prepared: q.TableMutationClient.Prepared) !void {
    const bytes = try prepared.save(init.arena.allocator());
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try path(init, directory, "mutation-send.json"), .data = bytes });
}
fn restorePrepared(init: std.process.Init, directory: []const u8) !q.TableMutationClient.Prepared {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, try path(init, directory, "mutation-send.json"), init.arena.allocator(), .limited(q.TableMutationClient.Prepared.max_saved_bytes));
    return q.TableMutationClient.Prepared.restore(init.arena.allocator(), bytes);
}
fn applyCommand(init: std.process.Init, wire: *s.client.Client, config: Config, command: r.Command, freeze: bool) !s.GenServer {
    _ = try send(wire, config, command);
    var worker = try makeServer(wire, config);
    try drive(init.io, &worker, config, freeze);
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
        _ = try admin.submit(.{ .send = .{ .pid = writer.pid, .value = try (s.Frame{ .kind = .cast, .payload = try writerConfiguration(config).initializeCommand() }).encode() } });
        try drive(init.io, &worker, config, false);
        try save(init, directory, "mutation.json", config);
        return print(init, config);
    }
    var config = try load(Config, init, directory, "mutation.json");
    if (std.mem.eql(u8, mode, "stage") or std.mem.eql(u8, mode, "prepare-upload") or std.mem.eql(u8, mode, "host-step")) {
        if (args.len != 6) return error.Usage;
        const namespace = try std.fmt.parseInt(u64, args[4], 10);
        var caller = try mutationClient(&wire, config);
        const request = try caller.compileSql(try .init("items"), args[5]);
        const ref = try request.reference(namespace);
        try saveReference(init, directory, ref);
        for (0..16) |_| {
            const prepared = (try caller.prepareNext(namespace, request)) orelse {
                if (std.mem.eql(u8, mode, "host-step")) return print(init, .{ .complete = true, .status = (try caller.status(ref)).? });
                return error.UnexpectedTerminalMutation;
            };
            const frame = try s.Frame.decode(prepared.signed.request.command.send.value);
            const command = try r.Command.decode(&frame.payload);
            if (command == .apply and !std.mem.eql(u8, mode, "host-step")) return print(init, .{ .staged = namespace });
            try savePrepared(init, directory, prepared);
            if (std.mem.eql(u8, mode, "prepare-upload")) return print(init, .{ .prepared = namespace });
            const recovered = try restorePrepared(init, directory);
            const receipt = try caller.submit(recovered);
            if (std.mem.eql(u8, mode, "host-step")) return print(init, .{ .complete = false, .input = receipt.position });
            try t.expectEqual(.pending, try caller.observe(recovered, receipt.position));
            var worker = try makeServer(&wire, config);
            try drive(init.io, &worker, config, false);
            try t.expectEqual(.processed, try caller.observe(recovered, receipt.position));
            try t.expectEqual(null, try caller.rejection(recovered, receipt.position));
        }
        return error.StepBudgetExceeded;
    }
    if (std.mem.eql(u8, mode, "submit-upload")) {
        var caller = try mutationClient(&wire, config);
        return print(init, try caller.submit(try restorePrepared(init, directory)));
    }
    if (std.mem.eql(u8, mode, "enqueue-apply")) {
        if (args.len != 5) return error.Usage;
        var caller = try mutationClient(&wire, config);
        const prepared = try caller.prepare(.{ .apply = try stagedReference(init, directory, try std.fmt.parseInt(u64, args[4], 10)) });
        try savePrepared(init, directory, prepared);
        return print(init, try caller.submit(prepared));
    }
    if (std.mem.eql(u8, mode, "rejection")) {
        if (args.len != 5) return error.Usage;
        var caller = try mutationClient(&wire, config);
        const prepared = try restorePrepared(init, directory);
        const input = try std.fmt.parseInt(u64, args[4], 10);
        return print(init, .{ .observation = try caller.observe(prepared, input), .rejection = try caller.rejection(prepared, input) });
    }
    if (std.mem.eql(u8, mode, "prepare")) {
        if (args.len != 5) return error.Usage;
        const namespace = try std.fmt.parseInt(u64, args[4], 10);
        const worker = try applyCommand(init, &wire, config, .{ .apply = try stagedReference(init, directory, namespace) }, true);
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
        _ = try send(&wire, config, .{ .apply = try stagedReference(init, directory, try std.fmt.parseInt(u64, args[4], 10)) });
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
        _ = try applyCommand(init, &wire, config, if (std.mem.eql(u8, mode, "apply")) .{ .apply = try stagedReference(init, directory, namespace) } else .{ .cancel = try stagedReference(init, directory, namespace) }, false);
        return print(init, .{ .completed = namespace });
    }
    if (std.mem.eql(u8, mode, "resume")) {
        var worker = try makeServer(&wire, config);
        try drive(init.io, &worker, config, false);
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
    if (std.mem.eql(u8, mode, "revoke-policy") or std.mem.eql(u8, mode, "restore-policy")) {
        var resource = try (s.client.ResourceReader{ .wire = &wire, .realm = 46, .principal = 0, .key = root }).open(config.writer.resource);
        var policy = (try admission.policy(&resource, 1234, 1)).?;
        const expected = policy.revision;
        policy.revision += 1;
        policy.permissions = if (std.mem.eql(u8, mode, "restore-policy")) 7 else 0;
        _ = try admin.submit(.{ .send = .{ .pid = config.writer.pid, .value = try (s.Frame{ .kind = .cast, .payload = try (q.TableMutationWriter.PolicyChange{ .resource = config.writer.resource, .expected_revision = expected, .policy = policy }).encode() }).encode() } });
        var worker = try makeServer(&wire, config);
        try drive(init.io, &worker, config, false);
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
