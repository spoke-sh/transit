//! Explicit exchange workers borrow exact direct cuts, independently of storage.
const std = @import("std");
const t = std.testing;
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const x = q.RelationalExchange;
const r = q.RelationalExchangeRecords;
const Producer = q.RelationalExchangeProducer;
const support = @import("direct_captured_query.zig");
const maintained = @import("direct_maintained_query.zig");
const outstanding = p.Value.init("exchange-outstanding") catch unreachable;
const producer_done = p.Value.init("exchange-complete") catch unreachable;
const first_exchange = 1700;
const pending_checked = p.Value.init("exchange-pending-checked") catch unreachable;
const stale_checked = p.Value.init("exchange-stale-checked") catch unreachable;
const Handler = struct {
    inner: *support.RelationalHost,
    exchange: u64,
    partitions: u64,
    vector: q.RelationalHistory.Vector,
    identity: q.RelationalMaintenanceRecords.Identity,
    producer: support.Provision,
    clients: []const c.DirectTableClient,
    authorization: ?q.ExchangeAuthorization = null,
    borrows: []const c.DirectReadDelegation.Borrow = &.{},
    fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) anyerror!void {
        const self: *@This() = @ptrCast(@alignCast(raw.?));
        const worker = self.authorization != null;
        const payload = frame.payload.slice();
        if (frame.kind != .cast or (!std.mem.startsWith(u8, payload, "x:") and !std.mem.startsWith(u8, payload, "RXP1"))) {
            if (worker) return error.InvalidProofFrame;
            const delegate = self.inner.interface();
            return delegate.handle(delegate.context, turn, frame);
        }
        var cuts: [q.fuze.Relational.max_sources]q.fuze.Relational.Cut = undefined;
        try self.vector.boundCuts(self.inner.bundle, &cuts);
        const bound: q.fuze.Relational.Bound = .{ .plan = self.inner.bundle.plan, .cuts = cuts[0..self.vector.count] };
        if (worker and std.mem.startsWith(u8, payload, "RXP1")) {
            const notice = try r.Pending.decode(frame.payload);
            try Producer.acknowledge(turn, bound, self.exchange, notice);
            if (try turn.read(outstanding)) |previous| {
                if (previous.eql(frame.payload)) {
                    try turn.delete(outstanding);
                    try turn.cast(turn.delivery.pid, try .init("x:tick"));
                }
            }
            return;
        }
        var fixed: std.heap.FixedBufferAllocator = .init(self.inner.workspace);
        if (!worker) {
            const original = self.inner.bundle.authorization.?;
            try self.inner.bundle.bindSubject(turn, original.requester, original.requests, original.proof.claim.principal);
        }
        var history = if (self.authorization) |authorization|
            try q.RelationalHistory.openExchange(turn, fixed.allocator(), self.inner.bundle, self.vector, self.clients, authorization, self.borrows, Producer.scan_rows)
        else
            try q.RelationalHistory.open(turn, fixed.allocator(), self.inner.bundle, self.vector, self.clients, Producer.scan_rows);
        if (std.mem.startsWith(u8, payload, "x:")) {
            switch (turn.delivery.input.origin) {
                .external => |origin| if (origin.principal != 101) return error.AccessDenied,
                .process => |origin| if (origin.pid != turn.delivery.pid) return error.AccessDenied,
                .effect => return error.AccessDenied,
            }
            if (!worker and std.mem.eql(u8, payload, "x:retire-request")) {
                _ = try self.inner.reference.publication().retire(turn, self.inner.reference.record);
                return;
            }
            if (std.mem.eql(u8, payload, "x:init")) {
                if (self.authorization) |authorization| {
                    try Producer.create(turn, bound, &history, self.exchange, authorization.assignment.options);
                    try turn.cast(turn.delivery.pid, try .init("x:tick"));
                } else {
                    const head = x.head(turn, self.exchange) catch |err| switch (err) {
                        error.QueryNotFound => {
                            _ = try x.create(turn, bound, &history, self.exchange, self.partitions, .{ .retained_bytes = 8 * 1024 * 1024, .credit_bytes = 2 * q.fuze.RelationalExchange.max_bytes, .credit_segments = 1 });
                            try turn.cast(turn.delivery.pid, frame.payload);
                            return;
                        },
                        else => return err,
                    };
                    if (head.registered < try head.total()) {
                        try x.register(turn, bound, &history, self.exchange, self.producer.pid, self.producer.resource);
                        try turn.cast(turn.delivery.pid, frame.payload);
                    }
                }
                return;
            }
            if (!worker and (std.mem.eql(u8, payload, "x:pending") or std.mem.eql(u8, payload, "x:stale"))) {
                const stale = std.mem.eql(u8, payload, "x:stale");
                const before = turn.decision;
                try t.expectError(if (stale) error.RelationalSourceChanged else error.RelationalExchangePending, q.RelationalMaintenance.attachExchange(turn, self.identity, if (stale) first_exchange else self.exchange, self.clients, self.inner.workspace));
                try t.expectEqualDeep(before, turn.decision);
                try turn.write(if (stale) stale_checked else pending_checked, q.UnifiedRecords.identityValue(self.exchange));
                return;
            }
            if (!worker and std.mem.eql(u8, payload, "x:attach")) return q.RelationalMaintenance.attachExchange(turn, self.identity, self.exchange, self.clients, self.inner.workspace);
            if (!worker or !std.mem.eql(u8, payload, "x:tick")) return error.InvalidProofFrame;
            if (try turn.read(outstanding)) |value| return Producer.retry(turn, bound, &history, self.exchange, try r.Pending.decode(value));
            switch (try Producer.step(turn, bound, &history, self.exchange)) {
                .accepted => for (turn.decision.outputs) |slot| {
                    if (slot) |output| {
                        const sent = try s.Frame.decode(output.value);
                        if (std.mem.startsWith(u8, sent.payload.slice(), "RXP1")) try turn.write(outstanding, sent.payload);
                    }
                },
                .complete => try turn.write(producer_done, q.UnifiedRecords.identityValue(self.exchange)),
                else => try turn.cast(turn.delivery.pid, frame.payload),
            }
            return;
        }
        const notice = try r.Pending.decode(frame.payload);
        if (try s.Frame.source(turn.delivery.input) != turn.delivery.pid) {
            if (try x.receive(turn, bound, &history, self.exchange, notice) == .progress) try turn.cast(turn.delivery.pid, frame.payload);
            return;
        }
        const head = try x.head(turn, self.exchange);
        if (head.pending) {
            const saved = (try turn.read(try r.key('s', self.exchange, 0, 0, 0))).?;
            if (!saved.eql(frame.payload)) return;
            _ = try x.advance(turn, bound, &history, self.exchange);
            try turn.cast(turn.delivery.pid, frame.payload);
        } else if (try x.consume(turn, bound, &history, self.exchange, notice.source, notice.partition) == .progress) try turn.cast(turn.delivery.pid, frame.payload);
    }
    fn interface(self: *@This()) s.GenServer.Handler {
        return .{ .context = self, .handle = handle };
    }
};
fn step(init: std.process.Init, server: *s.GenServer, handler: s.GenServer.Handler, admin: anytype) !void {
    if (try server.step(handler, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30000)) == .blocked) return server.handler_error orelse error.Blocked;
    const pending = try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .delivery }, try support.key(17));
    if (pending.body.delivery.next) |next| _ = try admin.submit(.{ .deliver = next });
}
pub fn run(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !void {
    const alloc = init.arena.allocator();
    var state = try maintained.prepareWithExchange(init, client, admin, role, false, true);
    const bytes = try state.bundle.decode(alloc, q.RelationalBundle.max_bytes);
    var decoded = try q.RelationalBundle.decode(alloc, bytes);
    defer decoded.deinit();
    const bundle = decoded.bundle;
    const receiver_clients = [_]c.DirectTableClient{ try maintained.executor(client, state), try maintained.executor(client, state) };
    var inner: support.RelationalHost = .{ .bundle = bundle, .bytes = bytes, .reference = try bundle.reference(state.worker.resource, 1), .clients = &receiver_clients, .workspace = try alloc.alloc(u8, 4 * 1024 * 1024), .exchanged = true };
    var receiver = try maintained.host(client, state);
    var vector: q.RelationalHistory.Vector = undefined;
    for (0..500) |_| {
        try step(init, &receiver, inner.interface(), admin);
        var read = try maintained.source(client, state);
        const head = try q.RelationalMaintenance.head(&read, state.identity);
        if (head.phase == .failed) return error.MaintainedQueryFailed;
        if (head.phase == .running) {
            vector = try q.RelationalMaintenance.readBasis(&read, bundle, head);
            try t.expectEqual(@as(u64, 0), head.revision);
            try t.expect(try q.RelationalMaintenance.exchangeSelected(&read, state.identity, inner.reference));
            break;
        }
    } else return error.MissingExchangeBasis;
    var worker = try support.provision(admin, 141, 113);
    _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = worker.pid }, .grantee = role, .privileges = p.permission(.send) | p.permission(.inspect) } });
    worker.generation = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = worker.pid } }, try support.key(17))).body.process.process.generation;
    _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = 141 } });
    worker.generation += 1;
    _ = try admin.submit(.{ .grant_resource = .{ .resource = worker.resource, .subject = state.principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    // Adding an optional resource link requires a fenced receiver. Preserve
    // the accepted query and replace only its physical ownership generation.
    _ = try admin.submit(.{ .@"suspend" = .{ .pid = state.worker.pid, .expected_generation = state.worker.generation, .resume_before_ms = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 60000) } });
    _ = try admin.submit(.{ .associate = .{ .pid = state.worker.pid, .name = try .init("producer"), .resource = worker.resource, .required = false } });
    const suspended = (try admin.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .process = state.worker.pid } }, try support.key(17))).body.process.process;
    _ = try admin.submit(.{ .@"resume" = .{ .pid = state.worker.pid, .expected_generation = suspended.generation } });
    _ = try admin.submit(.{ .own = .{ .pid = state.worker.pid, .expected_generation = suspended.generation + 1, .worker = state.principal } });
    state.worker.generation = suspended.generation + 2;
    receiver = try maintained.host(client, state);
    var worker_client = client;
    worker_client.connection.principal = 141;
    worker_client.key = try support.key(113);
    const worker_clients = [_]c.DirectTableClient{ worker_client, worker_client };
    var receiver_handler: Handler = .{ .inner = &inner, .exchange = first_exchange, .partitions = 1, .vector = vector, .identity = state.identity, .producer = worker, .clients = &receiver_clients };
    var worker_handler: Handler = .{ .inner = &inner, .exchange = first_exchange, .partitions = 1, .vector = vector, .identity = state.identity, .producer = worker, .clients = &worker_clients };
    const worker_configuration: s.client.Session = .{ .client = client.authority, .realm = 42, .principal = 141, .pid = worker.pid, .generation = worker.generation, .key = worker_client.key };
    var producer = try s.GenServer.init(worker_configuration, "state");
    producer.failure_policy = .stop;
    receiver.failure_policy = .stop;
    // Accepted activation owns a retained request version. Retirement of the
    // live publication cannot replace it or stop either selected revision.
    try support.send(client, state.worker.pid, try .init("x:retire-request"));
    for (0..200) |_| {
        try step(init, &receiver, receiver_handler.interface(), admin);
        var read = try maintained.source(client, state);
        if ((try inner.reference.publication().inspect(&read, inner.reference.record)).state == .retired) break;
    } else return error.RequestRetirementPending;
    var borrowed: [2]c.DirectTableClient = undefined;
    for ([_]u64{ 1, 7 }, 0..) |partitions, index| {
        const revision: u64 = index + 1;
        const exchange_id: u64 = first_exchange + index;
        if (index != 0) {
            try support.send(client, state.worker.pid, try .init("wake"));
            for (0..500) |_| {
                try step(init, &receiver, receiver_handler.interface(), admin);
                var read = try maintained.source(client, state);
                const head = try q.RelationalMaintenance.head(&read, state.identity);
                try t.expectEqual(@as(u64, 1), head.revision);
                if (head.phase == .failed) return error.MaintainedQueryFailed;
                if (head.phase != .running) continue;
                const next = try q.RelationalMaintenance.readBasis(&read, bundle, head);
                try t.expect(next.entries[0].position > vector.entries[0].position);
                vector = next;
                break;
            } else return error.MissingExchangeSuccessor;
        }
        const assignment: q.ExchangeAuthorization.Assignment = .{ .exchange = exchange_id, .producer = worker.pid, .options = .{ .receiver = .{ .owner = state.worker.pid, .resource = state.worker.resource }, .partitions = partitions, .workers = 1, .worker = 0, .batch = 4, .epoch = revision, .quota = 4 * 1024 * 1024 } };
        const authorization = try q.ExchangeAuthorization.prepare(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, assignment, bundle, vector);
        var borrows: [2]c.DirectReadDelegation.Borrow = undefined;
        for (&borrows, 0..) |*borrow, i| borrow.* = try authorization.prepareRead(client, bundle, vector, i, 141);
        if (index != 0) try t.expectError(error.TableDelegationDenied, borrowed[0].call(borrows[0].binding.target.action()));
        borrowed[index] = try q.CapturedTablePin.borrowedClient(worker_client, bundle.retention[0], borrows[0]);
        try t.expectError(error.TableDelegationDenied, borrowed[index].call(.{ .release = vector.entries[0].record.basis.snapshot }));
        receiver_handler.exchange = exchange_id;
        receiver_handler.partitions = partitions;
        receiver_handler.vector = vector;
        worker_handler.exchange = exchange_id;
        worker_handler.partitions = partitions;
        worker_handler.vector = vector;
        worker_handler.authorization = authorization;
        worker_handler.borrows = &borrows;
        try support.send(client, state.worker.pid, try .init("x:init"));
        // A complete registration is not complete row/terminal coverage.
        for (0..200) |_| {
            try step(init, &receiver, receiver_handler.interface(), admin);
            var read = try maintained.source(client, state);
            const exchange = x.head(&read, exchange_id) catch |err| {
                if (err == error.QueryNotFound) continue;
                return err;
            };
            if (exchange.registered == try exchange.total()) break;
        } else return error.ExchangeRegistrationPending;
        const commands: []const []const u8 = if (index == 0) &.{"x:pending"} else &.{ "x:pending", "x:stale" };
        for (commands) |command| {
            try support.send(client, state.worker.pid, try .init(command));
            for (0..200) |_| {
                try step(init, &receiver, receiver_handler.interface(), admin);
                var read = try maintained.source(client, state);
                const value = (try read.read(if (std.mem.eql(u8, command, "x:stale")) stale_checked else pending_checked)) orelse continue;
                if (try q.UnifiedRecords.readIdentity(value) != exchange_id) continue;
                const head = try q.RelationalMaintenance.head(&read, state.identity);
                try t.expectEqual(revision - 1, head.revision);
                try t.expectEqual(.running, head.phase);
                break;
            } else return error.ExchangeRejectionPending;
        }
        // The first producer must still read its two-row cut after a live delete.
        if (index == 0) try maintained.mutation(init, client, "exchange_input", 1103, 0, false);
        try support.send(client, worker.pid, try .init("x:init"));
        var attached = false;
        for (0..5000) |iteration| {
            if (iteration != 0 and iteration % 19 == 0) {
                receiver = try maintained.host(client, state);
                producer = try s.GenServer.init(worker_configuration, "state");
                producer.failure_policy = .stop;
            }
            if (receiver.pending == null and receiver.delivery == null and receiver.ready == null) {
                var read = try maintained.source(client, state);
                const pending = try read.read(try r.key('s', exchange_id, 0, 0, 0));
                try receiver.setReadResources(if (pending != null) &.{worker.resource} else &.{});
            }
            try step(init, &receiver, receiver_handler.interface(), admin);
            try step(init, &producer, worker_handler.interface(), admin);
            var read = try maintained.source(client, state);
            const exchange = try x.head(&read, exchange_id);
            if (!attached and exchange.completed == try exchange.total() and !exchange.pending) {
                try support.send(client, state.worker.pid, try .init("x:attach"));
                attached = true;
            }
            const head = try q.RelationalMaintenance.head(&read, state.identity);
            if (head.phase == .failed) return error.MaintainedQueryFailed;
            if (head.phase != .idle or head.revision != revision) continue;
            // Drain the last producer acknowledgement before switching cuts.
            const resources: s.client.ResourceReader = .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key };
            var worker_read = try resources.open(worker.resource);
            const done = (try worker_read.read(producer_done)) orelse continue;
            if (try q.UnifiedRecords.readIdentity(done) != exchange_id) continue;
            try t.expect(try worker_read.read(outstanding) == null);
            break;
        } else return error.ExchangeQueryPending;
        try t.expect(attached);
        _ = try maintained.readResult(client, bundle, state, revision, if (index == 0) 2 else 1);
    }
    try support.send(client, state.worker.pid, try .init("close"));
    for (0..500) |_| {
        try step(init, &receiver, receiver_handler.interface(), admin);
        var read = try maintained.source(client, state);
        if ((try q.RelationalMaintenance.head(&read, state.identity)).cleanup_cursor == bundle.sources.len) break;
    } else return error.ExchangeCleanupPending;
    for (borrowed) |old| {
        try t.expectError(error.Conflict, old.call(old.borrow.?.binding.target.action()));
        try t.expect(client.service.last_rejection.? == .QueryExpired);
    }
    _ = try maintained.readResult(client, bundle, state, 1, 2);
    _ = try maintained.readResult(client, bundle, state, 2, 1);
    try support.send(client, state.worker.pid, try .init("retire"));
    for (0..200) |_| {
        try step(init, &receiver, receiver_handler.interface(), admin);
        var read = try maintained.source(client, state);
        const head = try q.RelationalMaintenance.head(&read, state.identity);
        if (head.phase != .retired) continue;
        try t.expect(head.released);
        break;
    } else return error.ExchangeRetirementPending;
    try t.expectError(error.MaintainedResetRequired, maintained.readResult(client, bundle, state, 2, 1));
}
