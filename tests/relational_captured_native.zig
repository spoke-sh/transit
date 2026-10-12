//! Captured relational lifecycle through real public Station/client operations.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const f = q.fuze;
const r = q.RelationalRecords;
const Admin = @import("growing_support.zig").Admin(46);
const Metadata = struct { definition: g.Definition, reference: s.PublicationReference, secondary: ?u64 };
const Pending = struct { definition: g.Definition, pending: s.client.Session.Pending };
const correlation_key = p.Value.init("relational-proof-correlation") catch unreachable;
const workspace_bytes = 4 * 1024 * 1024;
const Handler = struct {
    bundle: q.RelationalBundle,
    bytes: []const u8,
    reference: s.PublicationReference,
    workspace: []u8,
    fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) anyerror!void {
        const self: *@This() = @ptrCast(@alignCast(raw.?));
        switch (frame.kind) {
            .reply => return,
            .call => {
                _ = try q.RelationalCapture.start(turn, try s.PublicationReference.decode(frame.payload), self.workspace);
                return;
            },
            .cast => {},
            else => return error.InvalidProofFrame,
        }
        if (std.mem.eql(u8, frame.payload.slice(), "relational-proof-upload")) {
            const peer = switch (turn.delivery.input.origin) {
                .external => |external| if (external.principal == 0) turn.delivery.pid else return error.AccessDenied,
                .process => |process| if (process.pid == turn.delivery.pid) process.pid else return error.AccessDenied,
                .effect => return error.AccessDenied,
            };
            const fingerprint = try self.bundle.fingerprint();
            if (try q.RelationalCapture.policy(turn, peer)) |old| {
                if (!std.mem.eql(u8, &old.request, &fingerprint)) try q.RelationalCapture.setPolicy(turn, .{ .peer = peer, .requests = turn.view.resource, .principal = 1234, .revision = old.revision + 1, .request = fingerprint, .allow = true });
            } else try q.RelationalCapture.setPolicy(turn, .{ .peer = peer, .requests = turn.view.resource, .principal = 1234, .revision = 1, .request = fingerprint, .allow = true });
            const ready = try s.PublicationUpload.step(turn, .{ .domain = .query_request, .namespace = self.reference.namespace, .identity_key = r.key('u', self.reference.namespace, 0), .identity = try self.reference.encode(), .limits = .{ .record_bytes = q.RelationalBundle.max_bytes, .staging_bytes = q.RelationalBundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = self.reference.spec, .bytes = self.bytes }} });
            if (ready) {
                const correlation = try turn.call(turn.delivery.pid, try self.reference.encode(), null);
                try turn.write(correlation_key, q.UnifiedRecords.identityValue(correlation));
            } else try turn.cast(turn.delivery.pid, frame.payload);
            return;
        }
        if (std.mem.eql(u8, frame.payload.slice(), "relational-proof-retire") or std.mem.eql(u8, frame.payload.slice(), "relational-proof-collect")) {
            const authorized = switch (turn.delivery.input.origin) {
                .external => |external| external.principal == 0,
                .process => |process| process.pid == turn.delivery.pid,
                .effect => false,
            };
            if (!authorized) return error.AccessDenied;
            const correlation = try q.UnifiedRecords.readIdentity((try turn.read(correlation_key)).?);
            const id = try q.UnifiedRecords.readIdentity((try turn.read(r.key('i', turn.delivery.pid, correlation))).?);
            if (std.mem.eql(u8, frame.payload.slice(), "relational-proof-collect")) {
                if (!try q.RelationalCapture.collect(turn, id)) try turn.cast(turn.delivery.pid, frame.payload);
                return;
            }
            return q.RelationalCapture.close(turn, id, .retired, null);
        }
        _ = try q.RelationalCapture.advance(turn, try q.UnifiedRecords.Continuation.decode(frame.payload), self.workspace);
    }
};
fn status(comptime Test: type, init: std.process.Init, wire: *s.client.Client, config: Test.Config) !?r.Job {
    var source = try (s.client.ResourceReader{ .wire = wire, .realm = 46, .principal = 1234, .key = try Test.key(10) }).open(config.writer.resource);
    const correlation_value = (try source.read(correlation_key)) orelse return null;
    const correlation = try q.UnifiedRecords.readIdentity(correlation_value);
    const identity = (try source.read(r.key('i', config.writer.pid, correlation))) orelse return null;
    _ = init;
    return try q.RelationalCapture.job(&source, try q.UnifiedRecords.readIdentity(identity));
}
pub fn run(comptime Test: type, init: std.process.Init, wire: *s.client.Client, directory: []const u8, config: Test.Config, primary: *c.TableClient, args: anytype) !void {
    const mode = args[2];
    var admin: Admin = .{ .wire = wire, .key = try Test.key(7) };
    const authority = try admin.query(.capabilities);
    admin.sequence = authority.principal_sequence;
    if (std.mem.eql(u8, mode, "captured-plan")) {
        var syntax = try f.RelationalSql.parse(init.gpa, args[4], null);
        defer syntax.deinit();
        const secondary_config: ?Test.Config = if (args.len > 5) try Test.load(Test.Config, init, args[5], "catalog.json") else null;
        var secondary: c.TableClient = if (secondary_config) |other| .{ .transport = wire, .connection = .{ .scope = Test.configuration(other).scope, .owner = other.writer.pid, .principal = 1234 }, .key = try Test.key(10) } else primary.*;
        const clients = [_]*c.TableClient{ primary, &secondary };
        var definitions: [2]?c.TableCatalog.Definition = @splat(null);
        defer for (&definitions) |*value| if (value.*) |*owned| owned.deinit();
        var typed: [2]?q.TableSource.Owned = @splat(null);
        defer for (&typed) |*value| if (value.*) |*owned| owned.deinit();
        var declarations: [2]f.Relational.Source = undefined;
        var sources: [2]q.TableSource = undefined;
        for (syntax.targets, 0..) |target, i| {
            const client = clients[i];
            definitions[i] = (try client.lookup(init.gpa, try c.TableMetadata.Name.init(target.name))) orelse return error.TableNotFound;
            const conf: c.TableCatalogRecords.Configuration = if (i == 1 and secondary_config != null) Test.configuration(secondary_config.?) else Test.configuration(config);
            typed[i] = try q.TableSource.from(init.gpa, conf, definitions[i].?);
            sources[i] = typed[i].?.source;
            declarations[i] = .{ .alias = target.alias, .realm = conf.scope.realm, .resource = conf.scope.resource, .catalog = conf.scope.catalog, .owner = conf.owner, .schema = definitions[i].?.schema.schema };
        }
        const plan = try syntax.bind(declarations[0..syntax.targets.len], .captured, .{ .resident_bytes = q.RelationalCapture.resident_base + 8 * 1024 * 1024, .spill_bytes = 64 * 1024 * 1024, .result_bytes = 8 * 1024 * 1024, .output_rows = 10000, .work_steps = 1000000, .source_pins = 2 }, null);
        const bundle: q.RelationalBundle = .{ .plan = plan, .sources = sources[0..syntax.targets.len] };
        var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
        try Test.saveBytes(init, directory, "relational-plan.bin", try bundle.encode(&bytes));
        const metadata: Metadata = .{ .definition = g.current_definition, .reference = try bundle.reference(config.writer.resource, authority.position + 1), .secondary = if (secondary_config) |other| other.writer.resource else null };
        if (metadata.secondary) |resource| {
            _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = config.worker, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
            _ = try admin.submit(.{ .@"suspend" = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .resume_before_ms = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 60000) } });
            _ = try admin.submit(.{ .associate = .{ .pid = config.writer.pid, .name = try p.Value.init("relational-secondary"), .resource = resource, .required = false } });
            const observed = (try admin.query(.{ .process = config.writer.pid })).body.process.process;
            _ = try admin.submit(.{ .@"resume" = .{ .pid = config.writer.pid, .expected_generation = observed.generation } });
            _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = observed.generation + 1, .worker = config.worker } });
            var fresh = config;
            fresh.writer.generation = observed.generation + 2;
            try Test.save(init, directory, "catalog.json", fresh);
        }
        try Test.save(init, directory, "relational-native.json", metadata);
        return Test.print(init, .{ .state = "prepared", .reference = metadata.reference });
    }
    const metadata = try Test.load(Metadata, init, directory, "relational-native.json");
    const bytes = try Test.loadBytes(init, directory, "relational-plan.bin", q.RelationalBundle.max_bytes);
    defer init.gpa.free(bytes);
    var owned = try q.RelationalBundle.decode(init.gpa, bytes);
    defer owned.deinit();
    if (std.mem.eql(u8, mode, "captured-rotate")) {
        _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .worker = config.worker } });
        var old: s.client.Session = .{ .client = wire, .realm = 46, .principal = config.worker, .pid = config.writer.pid, .generation = config.writer.generation, .key = try Test.key(8) };
        try std.testing.expectError(error.StaleActivation, old.receive());
        var fresh = config;
        fresh.writer.generation += 1;
        try Test.save(init, directory, "catalog.json", fresh);
        return Test.print(init, .{ .state = "rotated", .generation = fresh.writer.generation });
    }
    if (std.mem.eql(u8, mode, "captured-worker-deny")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = metadata.secondary.?, .subject = config.worker, .permissions = 0 } });
        return Test.print(init, .{ .state = "denied" });
    }
    if (std.mem.eql(u8, mode, "captured-enqueue") or std.mem.eql(u8, mode, "captured-retire") or std.mem.eql(u8, mode, "captured-collect")) {
        const payload = if (std.mem.eql(u8, mode, "captured-enqueue")) "relational-proof-upload" else if (std.mem.eql(u8, mode, "captured-retire")) "relational-proof-retire" else "relational-proof-collect";
        _ = try admin.submit(.{ .send = .{ .pid = config.writer.pid, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init(payload) }).encode() } });
        return Test.print(init, .{ .state = "queued" });
    }
    if (std.mem.eql(u8, mode, "captured-status")) {
        const current = (try status(Test, init, wire, config)) orelse return Test.print(init, .{ .state = "absent" });
        return Test.print(init, .{ .state = @tagName(current.phase), .job = current.id, .checkpoint = current.checkpoint, .outputs = current.outputs, .state_bytes = current.state_bytes, .released = current.released, .collected = current.cleanup == std.math.maxInt(u64) });
    }
    if (std.mem.eql(u8, mode, "captured-result")) {
        const current = (try status(Test, init, wire, config)) orelse return error.QueryNotFound;
        var nonce: [16]u8 = undefined;
        init.io.random(&nonce);
        var result = try q.RelationalResult.open(.{ .wire = wire, .realm = 46, .principal = 1234, .key = try Test.key(10) }, owned.bundle, .{ .owner = config.writer.pid, .peer = config.writer.pid, .resource = config.writer.resource, .job = current.id, .requests = 10000 }, nonce);
        defer result.close() catch {};
        var fields: [f.Relational.max_outputs]f.Types.Field = undefined;
        const schema = try result.schema(&fields);
        var buffer: [4096]u8 = undefined;
        var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try out.interface.writeAll("{\"rows\":[");
        var rows: usize = 0;
        while (try result.next()) |row| {
            if (rows != 0) try out.interface.writeByte(',');
            try out.interface.writeByte('[');
            for (row.cells[0..row.len], schema.structure, 0..) |cell, field, i| {
                if (i != 0) try out.interface.writeByte(',');
                const json = try f.LogicalJson.encode(init.gpa, cell, field);
                defer init.gpa.free(json);
                try out.interface.writeAll(json);
            }
            try out.interface.writeByte(']');
            rows += 1;
        }
        if (!result.complete) return error.IncompleteResult;
        try out.interface.print("],\"complete\":true,\"requests\":{d}}}\n", .{result.requests});
        try out.interface.flush();
        return;
    }
    const cleanup_only = std.mem.eql(u8, mode, "captured-clean");
    if (!std.mem.eql(u8, mode, "captured-pump") and !cleanup_only) return error.InvalidProofCommand;
    const pending = Test.load(Pending, init, directory, "relational-worker.json") catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (pending) |saved| {
        _ = try saved.pending.submit(wire);
        try std.Io.Dir.cwd().deleteFile(init.io, try Test.path(init, directory, "relational-worker.json"));
    }
    const workspace = try init.gpa.alloc(u8, workspace_bytes);
    defer init.gpa.free(workspace);
    var handler: Handler = .{ .bundle = owned.bundle, .bytes = bytes, .reference = metadata.reference, .workspace = workspace };
    var server = try s.GenServer.init(.{ .client = wire, .realm = 46, .principal = config.worker, .pid = config.writer.pid, .generation = config.writer.generation, .key = try Test.key(8) }, "state");
    if (!cleanup_only) if (metadata.secondary) |resource| try server.setReadResources(&.{resource});
    const limit = if (args.len > 4) try std.fmt.parseInt(usize, args[4], 10) else 10000;
    var committed: usize = 0;
    while (committed < limit) {
        const deadline: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000);
        switch (try server.prepare(deadline)) {
            .idle => if (try Test.deliver(init, wire, directory)) continue else return Test.print(init, .{ .state = "idle", .committed = committed }),
            .blocked => return error.BlockedOwner,
            .committed => unreachable,
            .progress => {},
            .ready => {
                try Handler.handle(&handler, &server.ready.?, try s.Frame.decode(server.ready.?.delivery.input.value));
                try server.finish(null);
            },
        }
        if (server.pending) |proposed| {
            try Test.save(init, directory, "relational-worker.json", Pending{ .definition = g.current_definition, .pending = proposed });
            const result = try server.dispatchPending();
            try std.Io.Dir.cwd().deleteFile(init.io, try Test.path(init, directory, "relational-worker.json"));
            if (result == .committed) committed += 1;
        }
    }
    try Test.print(init, .{ .state = "pumped", .committed = committed });
}
