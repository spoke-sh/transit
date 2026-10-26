//! Additional Station cuts through the real native authority and retained store.
const std = @import("std");
const s = @import("transit_station");
const p = s.client.protocol;
const g = p.Growth;
const t = std.testing;
const Admin = @import("fixture_growing_support").Admin(43);
const Saved = struct { definition: g.Definition, source: Admin.Provision, reader: Admin.Provision, input: u64 };
fn key(comptime byte: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(byte));
}
fn address(text: []const u8) !p.Value {
    return p.Value.init(text);
}
const Handler = struct {
    source: ?u64 = null,
    fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) anyerror!void {
        const self: *@This() = @ptrCast(@alignCast(raw.?));
        const command = try frame.payload.asInteger();
        if (self.source == null) return turn.put(try address("value"), p.Value.integer(command));
        var source = try turn.captured(self.source.?);
        const current = try (try source.read(try address("value"))).?.asInteger();
        switch (command) {
            0 => {
                try t.expectEqual(10, current);
                const first = try source.retain();
                const repeated = try source.retain();
                try t.expect(std.meta.eql(first, repeated));
                try t.expectEqual(0, first.index);
                try t.expectEqual(1, (try turn.retain()).index);
                try turn.put(try address("pins"), p.Value.integer(@intCast(first.input)));
                try turn.put(try address("captured"), p.Value.integer(current));
            },
            1 => {
                const input: u64 = @intCast(try (try turn.read(try address("pins"))).?.asInteger());
                var foreign = try turn.openVersion(.{ .pid = turn.delivery.pid, .input = input, .index = 0 });
                var own = try turn.openVersion(.{ .pid = turn.delivery.pid, .input = input, .index = 1 });
                try t.expectEqual(10, try (try foreign.read(try address("value"))).?.asInteger());
                try t.expectEqual(30, current);
                try t.expectEqual(null, try own.read(try address("captured")));
                try turn.put(try address("restored"), p.Value.integer(current));
                try turn.release(foreign.view.id);
                try turn.release(own.view.id);
            },
            2 => {
                try source.requireCurrent();
                try turn.put(try address("conditional"), p.Value.integer(current));
            },
            else => return error.InvalidProofCommand,
        }
    }
    fn interface(self: *@This()) s.GenServer.Handler {
        return .{ .context = self, .handle = handle };
    }
};
fn server(wire: *s.client.Client, provision: Admin.Provision, reader: bool) !s.GenServer {
    return s.GenServer.init(.{ .client = wire, .realm = 43, .principal = if (reader) 65541 else 65540, .pid = provision.pid, .generation = provision.generation, .key = if (reader) try key(19) else try key(18) }, "state");
}
fn drive(io: std.Io, host: *s.GenServer, handler: *Handler, prepare_only: bool) !void {
    host.failure_policy = .stop;
    for (0..32) |_| {
        if (prepare_only and host.pending != null and host.pending_kind == .commit) return;
        const frozen = host.pending;
        const result = host.step(handler.interface(), @intCast(std.Io.Clock.real.now(io).toMilliseconds() + 30000)) catch |err| {
            if (err != error.InvalidAuthorityResponse or frozen == null) return err;
            try t.expect(host.pending != null and std.meta.eql(frozen.?.signed, host.pending.?.signed));
            continue;
        };
        if (result == .committed) return;
        if (result == .blocked or result == .idle) return error.MissingProofProgress;
    }
    return error.ProofStepBudget;
}
fn read(admin: *Admin, resource: u64, name: []const u8) !?p.Value {
    const current = (try admin.query(.{ .resource = resource })).body.resource;
    const page = (try admin.query(.{ .entries = .{ .resource = resource, .revision = current.revision, .key = try address(name) } })).body.entries.page;
    return if (page.entries[0]) |entry| entry.value else null;
}
pub fn run(init: std.process.Init, wire: *s.client.Client, mode: []const u8, path: []const u8) !void {
    var admin: Admin = .{ .wire = wire, .key = try key(7) };
    admin.sequence = (try admin.query(.capabilities)).principal_sequence;
    if (std.mem.eql(u8, mode, "views")) {
        const source = try admin.provision(65540, try key(18));
        const reader = try admin.provisionReader(65541, try key(19), source.resource);
        var source_host = try server(wire, source, false);
        var reader_host = try server(wire, reader, true);
        var source_handler: Handler = .{};
        var reader_handler: Handler = .{ .source = source.resource };
        // Naming the writable resource again reuses its original cut.
        try reader_host.setReadResources(&.{ reader.resource, source.resource });
        try admin.send(source.pid, 10);
        try drive(init.io, &source_host, &source_handler, false);
        try admin.send(reader.pid, 0);
        try drive(init.io, &reader_host, &reader_handler, false);
        const input: u64 = @intCast(try (try read(&admin, reader.resource, "pins")).?.asInteger());
        try t.expectEqual(10, try (try read(&admin, reader.resource, "captured")).?.asInteger());
        try admin.send(source.pid, 20);
        try drive(init.io, &source_host, &source_handler, false);
        try admin.send(reader.pid, 2);
        try drive(init.io, &reader_host, &reader_handler, true);
        const pending = reader_host.pending.?;
        try admin.send(source.pid, 30);
        try drive(init.io, &source_host, &source_handler, false);
        try t.expectError(error.Rejected, pending.submit(wire));
        try t.expectEqual(.StaleStateResource, wire.last_rejection.?);
        try t.expectEqual(null, try read(&admin, reader.resource, "conditional"));
        // The native rejection settles this rejected computation. Reopen the
        // same unconsumed input; no accepted turn or signed retry is replaced.
        reader_host = try server(wire, reader, true);
        try reader_host.setReadResources(&.{source.resource});
        try drive(init.io, &reader_host, &reader_handler, false);
        try t.expectEqual(30, try (try read(&admin, reader.resource, "conditional")).?.asInteger());
        _ = try admin.submit(.{ .grant_resource = .{ .resource = source.resource, .subject = 65541, .permissions = p.State.permission(.inspect) } });
        try t.expectError(error.AccessDenied, wire.query(.{ .realm = 43, .principal = 65541, .kind = .{ .version_entries = .{ .id = .{ .pid = reader.pid, .input = input, .index = 0 }, .generation = reader.generation, .key = try address("value") } } }, try key(19)));
        try t.expectEqual(.AccessDenied, wire.last_rejection.?);
        _ = try admin.submit(.{ .grant_resource = .{ .resource = source.resource, .subject = 65541, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        const bytes = try std.json.Stringify.valueAlloc(init.gpa, Saved{ .definition = g.current_definition, .source = source, .reader = reader, .input = input }, .{});
        defer init.gpa.free(bytes);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
    } else if (std.mem.eql(u8, mode, "views-recover")) {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(4096));
        defer init.gpa.free(bytes);
        const parsed = try std.json.parseFromSlice(Saved, init.gpa, bytes, .{});
        defer parsed.deinit();
        var saved = parsed.value;
        _ = try admin.submit(.{ .own = .{ .pid = saved.reader.pid, .expected_generation = saved.reader.generation, .worker = 65541 } });
        saved.reader.generation += 1;
        var host = try server(wire, saved.reader, true);
        var handler: Handler = .{ .source = saved.source.resource };
        try host.setReadResources(&.{saved.source.resource});
        try admin.send(saved.reader.pid, 1);
        try drive(init.io, &host, &handler, false);
        try t.expectEqual(30, try (try read(&admin, saved.reader.resource, "restored")).?.asInteger());
        for (0..2) |index| {
            const version = try host.session.version(.{ .pid = saved.reader.pid, .input = saved.input, .index = @intCast(index) });
            try t.expect(version.released_at != null);
        }
    } else return error.InvalidProofCommand;
}
