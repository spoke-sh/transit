//! Explicit, single-authority physical host for the exchange fault schedule.
//! Each process invocation reconstructs the worker from accepted native state.
const std = @import("std");
const q = @import("transit_query");
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const x = q.RelationalExchange;
const r = q.RelationalExchangeRecords;
const Producer = q.RelationalExchangeProducer;
const Captured = @import("relational_captured_native.zig");
const Admin = @import("growing_support.zig").Admin(46);
const Worker = struct { process: Admin.Provision, principal: u64, fresh_key: bool };
const Metadata = struct {
    definition: g.Definition,
    id: u64,
    identity: q.RelationalMaintenanceRecords.Identity,
    revision: u64,
    partitions: u64,
    batch: u8,
    workers: []Worker,
};
const Pending = struct { definition: g.Definition, pending: s.client.Session.Pending };
const outstanding = p.Value.init("exchange-outstanding") catch unreachable;
const padding_progress = p.Value.init("proof-checkpoint-growth") catch unreachable;
const workspace_bytes = 4 * 1024 * 1024;
fn rootControl(turn: *s.Turn) !void {
    switch (turn.delivery.input.origin) {
        .external => |origin| if (origin.principal != 0) return error.AccessDenied,
        .process => |origin| if (origin.pid != turn.delivery.pid) return error.AccessDenied,
        .effect => return error.AccessDenied,
    }
}
const Handler = struct {
    bundle: q.RelationalBundle,
    basis: q.RelationalHistory.Vector,
    metadata: Metadata,
    worker: ?usize,
    workspace: []u8,
    captured: Captured.Handler,
    table: q.catalog.TableBehavior,
    fn handle(self: *@This(), turn: *s.Turn, frame: s.Frame) !void {
        var cuts: [2]q.fuze.Relational.Cut = undefined;
        try self.basis.boundCuts(self.bundle, &cuts);
        const bound: q.fuze.Relational.Bound = .{ .plan = self.bundle.plan, .cuts = cuts[0..self.basis.count] };
        const payload = frame.payload.slice();
        if (frame.kind == .cast and std.mem.eql(u8, payload, "x:checkpoint-growth")) {
            try rootControl(turn);
            if (self.worker == null) return error.InvalidProofFrame;
            const previous = if (try turn.read(padding_progress)) |value| try q.UnifiedRecords.readIdentity(value) else 0;
            const next = @min(previous + 3, 257);
            for (previous..next) |index| {
                var key_bytes: [16]u8 = undefined;
                key_bytes[0..8].* = "proofpad".*;
                std.mem.writeInt(u64, key_bytes[8..16], index, .big);
                const value: [256]u8 = @splat(@truncate(index));
                try turn.write(try p.Value.init(&key_bytes), try p.Value.init(&value));
            }
            if (next != previous) try turn.write(padding_progress, q.UnifiedRecords.identityValue(next));
            if (next < 257) try turn.cast(turn.delivery.pid, frame.payload);
            return;
        }
        if (frame.kind == .cast and std.mem.startsWith(u8, payload, "RXP1") and self.worker != null) {
            const notice = try r.Pending.decode(frame.payload);
            try Producer.acknowledge(turn, bound, self.metadata.id, notice);
            if (try turn.read(outstanding)) |previous| {
                if (previous.eql(frame.payload)) try turn.delete(outstanding);
            }
            return;
        }
        if (frame.kind != .cast or (!std.mem.startsWith(u8, payload, "x:") and !std.mem.startsWith(u8, payload, "RXP1"))) {
            if (self.worker != null) return error.InvalidProofFrame;
            if (frame.kind == .reply or frame.kind == .call or std.mem.startsWith(u8, payload, "RMC1") or std.mem.startsWith(u8, payload, "relational-proof-")) return Captured.Handler.handle(&self.captured, turn, frame);
            const handler = self.table.interface();
            return handler.handle(handler.context, turn, frame);
        }
        var fixed: std.heap.FixedBufferAllocator = .init(self.workspace);
        var history = try q.RelationalHistory.open(turn, fixed.allocator(), self.bundle, 1234, self.basis, Producer.scan_rows);
        if (std.mem.startsWith(u8, payload, "x:")) {
            try rootControl(turn);
            if (std.mem.eql(u8, payload, "x:init")) {
                if (self.worker) |worker| {
                    try Producer.create(turn, bound, &history, self.metadata.id, .{ .partitions = self.metadata.partitions, .workers = self.metadata.workers.len, .worker = worker, .batch = self.metadata.batch, .epoch = 1, .quota = 4 * 1024 * 1024 });
                } else {
                    const stored = x.head(turn, self.metadata.id) catch |err| switch (err) {
                        error.QueryNotFound => {
                            _ = try x.create(turn, bound, &history, self.metadata.id, self.metadata.partitions, .{ .retained_bytes = 8 * 1024 * 1024, .credit_bytes = 2 * q.fuze.RelationalExchange.max_bytes, .credit_segments = 1 });
                            try turn.cast(turn.delivery.pid, frame.payload);
                            return;
                        },
                        else => return err,
                    };
                    if (stored.registered != try stored.total()) {
                        const worker = self.metadata.workers[stored.registered % self.metadata.workers.len];
                        try x.register(turn, bound, &history, self.metadata.id, worker.process.pid, worker.process.resource);
                        try turn.cast(turn.delivery.pid, frame.payload);
                    }
                }
                return;
            }
            if (std.mem.eql(u8, payload, "x:attach") and self.worker == null) return q.RelationalMaintenance.attachExchange(turn, self.metadata.identity, self.metadata.id, self.workspace);
            if (!std.mem.eql(u8, payload, "x:tick") or self.worker == null) return error.InvalidProofFrame;
            if (try turn.read(outstanding)) |value| {
                try Producer.retry(turn, bound, &history, self.metadata.id, try r.Pending.decode(value));
            } else if (try Producer.step(turn, bound, &history, self.metadata.id) == .accepted) {
                for (turn.decision.outputs) |slot| if (slot) |output| {
                    const sent = try s.Frame.decode(output.value);
                    if (std.mem.startsWith(u8, sent.payload.slice(), "RXP1")) try turn.write(outstanding, sent.payload);
                };
            }
            return;
        }
        const notice = try r.Pending.decode(frame.payload);
        if (try s.Frame.source(turn.delivery.input) != turn.delivery.pid) {
            if (try x.receive(turn, bound, &history, self.metadata.id, notice) == .progress) try turn.cast(turn.delivery.pid, frame.payload);
            return;
        }
        const stored = try x.head(turn, self.metadata.id);
        if (stored.pending) {
            const pending = (try turn.read(try r.key('s', self.metadata.id, 0, 0, 0))).?;
            if (!pending.eql(frame.payload)) return;
            _ = try x.advance(turn, bound, &history, self.metadata.id);
            try turn.cast(turn.delivery.pid, frame.payload);
        } else {
            const result = try x.consume(turn, bound, &history, self.metadata.id, notice.source, notice.partition);
            if (result == .progress) try turn.cast(turn.delivery.pid, frame.payload);
        }
    }
};
fn addRead(admin: *Admin, pid: u64, principal: u64, resource: u64, name: p.Value) !void {
    _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    _ = try admin.submit(.{ .associate = .{ .pid = pid, .name = name, .resource = resource, .required = false } });
}
pub fn run(comptime Test: type, init: std.process.Init, wire: *s.client.Client, directory: []const u8, config: Test.Config, args: anytype) !void {
    const mode = args[2][9..];
    var admin: Admin = .{ .wire = wire, .key = try Test.key(7) };
    const authority = try admin.query(.capabilities);
    admin.sequence = authority.principal_sequence;
    const request = try Test.load(Captured.Metadata, init, directory, "relational-native.json");
    const bytes = try Test.loadBytes(init, directory, "relational-plan.bin", q.RelationalBundle.max_bytes);
    defer init.gpa.free(bytes);
    var owned = try q.RelationalBundle.decode(init.gpa, bytes);
    defer owned.deinit();
    const bundle = owned.bundle;
    const reader: s.client.ResourceReader = .{ .wire = wire, .realm = 46, .principal = 0, .key = try Test.key(7) };
    if (std.mem.eql(u8, mode, "setup")) {
        const partitions = try std.fmt.parseInt(u64, args[4], 10);
        const count = try std.fmt.parseInt(usize, args[5], 10);
        if (count == 0 or count > 3) return error.InvalidProofLayout;
        var source = try reader.open(config.writer.resource);
        const correlation = try q.UnifiedRecords.readIdentity((try source.read(Captured.correlation_key)).?);
        const identity: q.RelationalMaintenanceRecords.Identity = .{ .peer = config.writer.pid, .correlation = correlation };
        const stored = try q.RelationalMaintenance.head(&source, identity);
        if (stored.phase != .admitted) return error.InvalidProofPhase;
        const basis = try q.RelationalMaintenance.readBasis(&source, bundle, stored);
        var basis_bytes: [q.RelationalHistory.Vector.max_bytes]u8 = undefined;
        try Test.saveBytes(init, directory, "exchange-basis.bin", try basis.encode(bundle, &basis_bytes));
        const workers = try init.arena.allocator().alloc(Worker, count);
        for (workers, 0..) |*worker, index| {
            const principal = 70000 + authority.position + index;
            const pid = try admin.submit(.{ .spawn = .{} });
            _ = try admin.submit(.{ .grant = .{ .subject = principal, .public_key = (try Test.key(8)).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = pid } });
            const resource = try admin.submit(.{ .create_resource = .{ .writer = pid } });
            for ([_]u64{ 0, principal }) |subject| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = subject, .permissions = p.State.all_permissions } });
            _ = try admin.submit(.{ .associate = .{ .pid = pid, .name = try p.Value.init("state"), .resource = resource } });
            for (bundle.sources, 0..) |declared, ordinal| {
                if (ordinal != 0 and declared.scope.resource == bundle.sources[0].scope.resource) continue;
                try addRead(&admin, pid, principal, declared.scope.resource, try p.Value.init(if (ordinal == 0) "left" else "right"));
            }
            const observed = (try admin.query(.{ .process = pid })).body.process.process;
            _ = try admin.submit(.{ .own = .{ .pid = pid, .expected_generation = observed.generation, .worker = principal } });
            worker.* = .{ .principal = principal, .process = .{ .pid = pid, .resource = resource, .generation = observed.generation + 1 }, .fresh_key = false };
        }
        // Optional producer links are established while the receiver is fenced.
        _ = try admin.submit(.{ .@"suspend" = .{ .pid = config.writer.pid, .expected_generation = config.writer.generation, .resume_before_ms = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 60000) } });
        for (workers, 0..) |worker, index| {
            const name = try std.fmt.allocPrint(init.arena.allocator(), "exchange-{d}", .{worker.process.pid});
            try addRead(&admin, config.writer.pid, config.worker, worker.process.resource, try p.Value.init(name));
            _ = index;
        }
        const observed = (try admin.query(.{ .process = config.writer.pid })).body.process.process;
        _ = try admin.submit(.{ .@"resume" = .{ .pid = config.writer.pid, .expected_generation = observed.generation } });
        _ = try admin.submit(.{ .own = .{ .pid = config.writer.pid, .expected_generation = observed.generation + 1, .worker = config.worker } });
        var fresh = config;
        fresh.writer.generation = observed.generation + 2;
        try Test.save(init, directory, "catalog.json", fresh);
        const metadata: Metadata = .{ .definition = g.current_definition, .id = authority.position + 1, .identity = identity, .revision = try stored.successor(), .partitions = partitions, .batch = try std.fmt.parseInt(u8, args[6], 10), .workers = workers };
        try Test.save(init, directory, "exchange-native.json", metadata);
        for (workers) |worker| _ = try admin.submit(.{ .send = .{ .pid = worker.process.pid, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init("x:init") }).encode() } });
        _ = try admin.submit(.{ .send = .{ .pid = config.writer.pid, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init("x:init") }).encode() } });
        return Test.print(init, metadata);
    }
    var metadata = try Test.load(Metadata, init, directory, "exchange-native.json");
    if (metadata.definition != g.current_definition) return error.IncompatibleDefinition;
    const basis_bytes = try Test.loadBytes(init, directory, "exchange-basis.bin", q.RelationalHistory.Vector.max_bytes);
    defer init.gpa.free(basis_bytes);
    const basis = try q.RelationalHistory.Vector.decode(bundle, basis_bytes);
    var cuts: [2]q.fuze.Relational.Cut = undefined;
    try basis.boundCuts(bundle, &cuts);
    const bound: q.fuze.Relational.Bound = .{ .plan = bundle.plan, .cuts = cuts[0..basis.count] };
    if (std.mem.eql(u8, mode, "status")) {
        var source = try reader.open(config.writer.resource);
        const stored = try x.head(&source, metadata.id);
        const Status = struct { cursor: Producer.Cursor, outstanding: bool };
        var status = try init.arena.allocator().alloc(Status, metadata.workers.len);
        for (metadata.workers, 0..) |worker, index| {
            var data = try reader.open(worker.process.resource);
            status[index] = .{ .cursor = try Producer.cursor(&data, bound, metadata.id), .outstanding = try data.read(outstanding) != null };
        }
        return Test.print(init, .{ .head = stored, .workers = status });
    }
    const worker: ?usize = if (args.len <= 4 or std.mem.eql(u8, args[4], "r")) null else try std.fmt.parseInt(usize, args[4], 10);
    if (worker) |index| if (index >= metadata.workers.len) return error.InvalidProofLayout;
    if (std.mem.eql(u8, mode, "handoff")) return @import("worker_handoff_native.zig").run(Test, init, wire, directory, bundle, basis, &metadata, worker orelse return error.InvalidProofLayout, args[5]);
    const process = if (worker) |index| metadata.workers[index].process else config.writer;
    const principal = if (worker) |index| metadata.workers[index].principal else config.worker;
    const worker_key = if (worker != null and metadata.workers[worker.?].fresh_key) try Test.key(11) else try Test.key(8);
    const pending_name = try std.fmt.allocPrint(init.arena.allocator(), "exchange-worker-{d}.json", .{process.pid});
    if (std.mem.eql(u8, mode, "expire-source")) {
        const last = bundle.sources[bundle.sources.len - 1];
        if (last.scope.resource == config.writer.resource) return error.InvalidProofLayout;
        // This source resource has its Table PID as native lifetime owner.
        // Permanent owner termination expires that dependency without deleting
        // its retained bytes or moving query execution authority.
        _ = try admin.submit(.{ .terminate = last.owner });
        return Test.print(init, .{ .state = "source-owner-terminated", .resource = last.scope.resource });
    }
    if (std.mem.eql(u8, mode, "deny") or std.mem.eql(u8, mode, "allow")) {
        _ = try admin.submit(.{ .grant_resource = .{ .resource = bundle.sources[bundle.sources.len - 1].scope.resource, .subject = principal, .permissions = if (std.mem.eql(u8, mode, "deny")) 0 else p.State.permission(.inspect) | p.State.permission(.read) } });
        return Test.print(init, .{ .state = mode });
    }
    if (std.mem.eql(u8, mode, "checkpoint-growth") or std.mem.eql(u8, mode, "tick") or std.mem.eql(u8, mode, "attach")) {
        _ = try admin.submit(.{ .send = .{ .pid = process.pid, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init(if (std.mem.eql(u8, mode, "checkpoint-growth")) "x:checkpoint-growth" else if (std.mem.eql(u8, mode, "attach")) "x:attach" else "x:tick") }).encode() } });
        return Test.print(init, .{ .state = "queued" });
    }
    const pending = Test.load(Pending, init, directory, pending_name) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (pending) |saved| {
        _ = try saved.pending.submit(wire);
        try std.Io.Dir.cwd().deleteFile(init.io, try Test.path(init, directory, pending_name));
    }
    if (std.mem.eql(u8, mode, "rotate")) {
        _ = try admin.submit(.{ .own = .{ .pid = process.pid, .expected_generation = process.generation, .worker = principal } });
        var stale: s.client.Session = .{ .client = wire, .realm = 46, .principal = principal, .pid = process.pid, .generation = process.generation, .key = worker_key };
        try std.testing.expectError(error.StaleActivation, stale.receive());
        if (worker) |index| {
            metadata.workers[index].process.generation += 1;
            try Test.save(init, directory, "exchange-native.json", metadata);
        } else {
            var fresh = config;
            fresh.writer.generation += 1;
            try Test.save(init, directory, "catalog.json", fresh);
        }
        return Test.print(init, .{ .state = "rotated" });
    }
    if (!std.mem.eql(u8, mode, "pump")) return error.InvalidProofCommand;
    const workspace = try init.gpa.alloc(u8, workspace_bytes);
    defer init.gpa.free(workspace);
    var handler: Handler = .{ .bundle = bundle, .basis = basis, .metadata = metadata, .worker = worker, .workspace = workspace, .captured = .{ .bundle = bundle, .bytes = bytes, .reference = request.reference, .workspace = workspace }, .table = .{ .allocator = init.gpa, .configuration = Test.configuration(config) } };
    var server = try s.GenServer.init(.{ .client = wire, .realm = 46, .principal = principal, .pid = process.pid, .generation = process.generation, .key = worker_key }, "state");
    const limit = if (args.len > 5) try std.fmt.parseInt(usize, args[5], 10) else 100;
    var committed: usize = 0;
    while (committed < limit) {
        if (server.pending == null and server.delivery == null and server.ready == null) {
            var resources: [3]u64 = undefined;
            var len: usize = 0;
            for (bundle.sources, 0..) |source, index| {
                if (source.scope.resource == process.resource or (index != 0 and source.scope.resource == bundle.sources[0].scope.resource)) continue;
                resources[len] = source.scope.resource;
                len += 1;
            }
            if (worker == null) {
                var current = try reader.open(process.resource);
                if (try current.read(try r.key('s', metadata.id, 0, 0, 0))) |value| {
                    resources[len] = (try r.Pending.decode(value)).remote.resource;
                    len += 1;
                }
            }
            try server.setReadResources(resources[0..len]);
        }
        const deadline: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000);
        switch (try server.prepare(deadline)) {
            .idle => if (try Test.deliver(init, wire, directory)) continue else return Test.print(init, .{ .state = "idle", .committed = committed }),
            .blocked => return error.BlockedOwner,
            .committed => unreachable,
            .progress => {},
            .ready => {
                try handler.handle(&server.ready.?, try s.Frame.decode(server.ready.?.delivery.input.value));
                try server.finish(null);
            },
        }
        if (server.pending) |proposed| {
            try Test.save(init, directory, pending_name, Pending{ .definition = g.current_definition, .pending = proposed });
            const result = try server.dispatchPending();
            try std.Io.Dir.cwd().deleteFile(init.io, try Test.path(init, directory, pending_name));
            if (result == .committed) committed += 1;
        }
    }
    try Test.print(init, .{ .state = "pumped", .committed = committed });
}
