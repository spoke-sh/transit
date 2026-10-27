//! Three explicit producers share seven partitions through exact borrowed cuts.
const std = @import("std");
const t = std.testing;
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const support = @import("fixture_direct_captured_query");
const maintained = @import("fixture_direct_maintained_query");
const exchange = @import("fixture_direct_relational_exchanges");
const x = q.RelationalExchange;
const records = q.RelationalExchangeRecords;
const id = 1800;
const partitions = 7;
const count = 3;

fn reader(client: c.DirectTableClient, resource: u64) !s.client.ResourceReader.Reader {
    const native: s.client.ResourceReader = .{ .wire = client.authority, .realm = 42, .principal = 101, .key = client.key };
    return native.open(resource);
}
fn process(client: c.DirectTableClient, pid: u64) !p.Growth.Process {
    return (try client.authority.query(.{ .realm = 42, .principal = 101, .kind = .{ .process = pid } }, client.key)).body.process.process;
}
pub fn run(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !void {
    const alloc = init.arena.allocator();
    var state = try maintained.prepareWithExchange(init, client, admin, role, true, true);
    const bytes = try state.bundle.decode(alloc, q.RelationalBundle.max_bytes);
    var decoded = try q.RelationalBundle.decode(alloc, bytes);
    defer decoded.deinit();
    const bundle = decoded.bundle;
    const receiver_clients = [_]c.DirectTableClient{ try maintained.executor(client, state), try maintained.executor(client, state) };
    var inner: support.RelationalHost = .{ .bundle = bundle, .bytes = bytes, .reference = try bundle.reference(state.worker.resource, 1), .clients = &receiver_clients, .workspace = try alloc.alloc(u8, 4 * 1024 * 1024), .exchanged = true };
    var receiver = try maintained.host(client, state);
    var vector: q.RelationalHistory.Vector = undefined;
    for (0..500) |_| {
        try exchange.step(init, &receiver, inner.interface(), admin);
        var source = try maintained.source(client, state);
        const head = try q.RelationalMaintenance.head(&source, state.identity);
        if (head.phase == .failed) return error.MaintainedQueryFailed;
        if (head.phase != .running) continue;
        vector = try q.RelationalMaintenance.readBasis(&source, bundle, head);
        try t.expectEqual(@as(u64, 0), head.revision);
        break;
    } else return error.MissingExchangeBasis;

    var workers: [count]support.Provision = undefined;
    for (&workers, 0..) |*worker, index| {
        worker.* = try support.provision(admin, 141 + index, @intCast(113 + index));
        _ = try admin.change(.{ .grant = .{ .object = .{ .kind = .process, .id = worker.pid }, .grantee = role, .privileges = p.permission(.send) | p.permission(.inspect) } });
        worker.generation = (try process(client, worker.pid)).generation;
        _ = try admin.submit(.{ .own = .{ .pid = worker.pid, .expected_generation = worker.generation, .worker = 141 + index } });
        worker.generation += 1;
        _ = try admin.submit(.{ .grant_resource = .{ .resource = worker.resource, .subject = state.principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    }
    _ = try admin.submit(.{ .@"suspend" = .{ .pid = state.worker.pid, .expected_generation = state.worker.generation, .resume_before_ms = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 60000) } });
    for (workers, 0..) |worker, index| {
        var name: [24]u8 = undefined;
        _ = try admin.submit(.{ .associate = .{ .pid = state.worker.pid, .name = try .init(try std.fmt.bufPrint(&name, "producer-{d}", .{index})), .resource = worker.resource, .required = false } });
    }
    const suspended = try process(client, state.worker.pid);
    _ = try admin.submit(.{ .@"resume" = .{ .pid = state.worker.pid, .expected_generation = suspended.generation } });
    _ = try admin.submit(.{ .own = .{ .pid = state.worker.pid, .expected_generation = suspended.generation + 1, .worker = state.principal } });
    state.worker.generation = suspended.generation + 2;
    receiver = try maintained.host(client, state);

    var clients: [count][2]c.DirectTableClient = undefined;
    var borrows: [count][2]c.DirectReadDelegation.Borrow = undefined;
    var handlers: [count]exchange.Handler = undefined;
    var configurations: [count]s.client.Session = undefined;
    var producers: [count]s.GenServer = undefined;
    for (workers, 0..) |worker, index| {
        var selected = client;
        selected.connection.principal = 141 + index;
        selected.key = try support.key(@intCast(113 + index));
        clients[index] = .{ selected, selected };
        const assignment: q.ExchangeAuthorization.Assignment = .{ .exchange = id, .producer = worker.pid, .options = .{ .receiver = .{ .owner = state.worker.pid, .resource = state.worker.resource }, .partitions = partitions, .workers = count, .worker = index, .batch = 4, .epoch = 1, .quota = 4 * 1024 * 1024 } };
        const authorization = try q.ExchangeAuthorization.prepare(.{ .transport = client.authority, .realm = 42, .principal = 101, .key = client.key }, assignment, bundle, vector);
        for (&borrows[index], 0..) |*borrow, source| borrow.* = try authorization.prepareRead(client, bundle, vector, source, selected.connection.principal);
        const borrowed = try q.CapturedTablePin.borrowedClient(selected, bundle.retention[0], borrows[index][0]);
        try t.expectError(error.TableDelegationDenied, borrowed.call(.{ .release = vector.entries[0].record.basis.snapshot }));
        handlers[index] = .{ .inner = &inner, .exchange = id, .partitions = partitions, .vector = vector, .identity = state.identity, .producer = worker, .clients = &clients[index], .authorization = authorization, .borrows = &borrows[index] };
        configurations[index] = .{ .client = client.authority, .realm = 42, .principal = selected.connection.principal, .pid = worker.pid, .generation = worker.generation, .key = selected.key };
        producers[index] = try s.GenServer.init(configurations[index], "state");
        producers[index].failure_policy = .stop;
    }
    var receiver_handler: exchange.Handler = .{ .inner = &inner, .exchange = id, .partitions = partitions, .vector = vector, .identity = state.identity, .producer = workers[0], .producers = &workers, .clients = &receiver_clients };
    try support.send(client, state.worker.pid, try .init("x:init"));
    for (0..200) |_| {
        try exchange.step(init, &receiver, receiver_handler.interface(), admin);
        var source = try maintained.source(client, state);
        const head = x.head(&source, id) catch |err| {
            if (err == error.QueryNotFound) continue;
            return err;
        };
        if (head.registered == try head.total()) break;
    } else return error.ExchangeRegistrationPending;
    try maintained.mutation(init, client, "exchange_input", 1103, 0, false);
    for (workers) |worker| try support.send(client, worker.pid, try .init("x:init"));

    // Keep the receiver stopped until each producer has retried an eligible
    // notice. Duplicate deliveries must not duplicate rows or terminal coverage.
    for (workers, 0..) |worker, index| {
        var original: p.Value = undefined;
        for (0..500) |_| {
            try exchange.step(init, &producers[index], handlers[index].interface(), admin);
            var source = try reader(client, worker.resource);
            original = (try source.read(exchange.outstanding)) orelse continue;
            break;
        } else return error.MissingEligibleExchangeNotice;
        try support.send(client, worker.pid, try .init("x:tick"));
        const target = (try process(client, worker.pid)).admitted;
        for (0..100) |_| {
            try exchange.step(init, &producers[index], handlers[index].interface(), admin);
            if ((try process(client, worker.pid)).consumed < target) continue;
            var source = try reader(client, worker.resource);
            try t.expect((try source.read(exchange.outstanding)).?.eql(original));
            break;
        } else return error.ExchangeRetryPending;
    }

    var attached = false;
    for (0..5000) |iteration| {
        if (iteration != 0 and iteration % 17 == 0) {
            receiver = try maintained.host(client, state);
            for (&producers, configurations) |*producer, configuration| {
                producer.* = try s.GenServer.init(configuration, "state");
                producer.failure_policy = .stop;
            }
        }
        if (iteration % 17 == 0) {
            const receiving = try process(client, state.worker.pid);
            // Drain admitted receiver work before injecting a retry round.
            // Otherwise duplicate notices can outpace this deliberately serial
            // driver even though every individual mailbox is making progress.
            if (receiving.consumed == receiving.admitted) for (workers) |worker| {
                const state_now = try process(client, worker.pid);
                if (state_now.consumed != state_now.admitted) continue;
                var source = try reader(client, worker.resource);
                // Credit refusal keeps the original eligible bytes. Silence
                // cannot acknowledge them or select another source cut.
                if (try source.read(exchange.outstanding) != null) try support.send(client, worker.pid, try .init("x:tick"));
            };
        }
        if (receiver.pending == null and receiver.delivery == null and receiver.ready == null) {
            var source = try maintained.source(client, state);
            if (try source.read(try records.key('s', id, 0, 0, 0))) |pending| {
                const notice = try records.Pending.decode(pending);
                const index = (notice.partition * vector.count + notice.source) % count;
                try receiver.setReadResources(&.{workers[index].resource});
            } else try receiver.setReadResources(&.{});
        }
        try exchange.step(init, &receiver, receiver_handler.interface(), admin);
        for (0..count) |reverse| {
            const index = count - reverse - 1;
            try exchange.step(init, &producers[index], handlers[index].interface(), admin);
        }
        var source = try maintained.source(client, state);
        const head = try x.head(&source, id);
        if (iteration % 100 == 0) std.debug.print("Direct exchange workers: iteration={d} completed={d}/{d} pending={}\n", .{ iteration, head.completed, try head.total(), head.pending });
        if (!attached and head.completed == try head.total() and !head.pending) {
            try support.send(client, state.worker.pid, try .init("x:attach"));
            attached = true;
        }
        const query = try q.RelationalMaintenance.head(&source, state.identity);
        if (query.phase == .failed) return error.MaintainedQueryFailed;
        if (query.phase != .idle or query.revision != 1) continue;
        var done = true;
        for (workers) |worker| {
            var worker_state = try reader(client, worker.resource);
            const terminal = try worker_state.read(exchange.producer_done);
            if (terminal == null or try q.UnifiedRecords.readIdentity(terminal.?) != id or try worker_state.read(exchange.outstanding) != null) done = false;
        }
        if (done) break;
    } else return error.ExchangeQueryPending;
    try t.expect(attached);
    _ = try maintained.readResult(client, bundle, state, 1, 2);
    try support.send(client, state.worker.pid, try .init("close"));
    for (0..500) |_| {
        try exchange.step(init, &receiver, receiver_handler.interface(), admin);
        var source = try maintained.source(client, state);
        if ((try q.RelationalMaintenance.head(&source, state.identity)).cleanup_cursor == bundle.sources.len) break;
    } else return error.ExchangeCleanupPending;
    for (clients, borrows) |worker_clients, worker_borrows| {
        const borrowed = try q.CapturedTablePin.borrowedClient(worker_clients[0], bundle.retention[0], worker_borrows[0]);
        try t.expectError(error.Conflict, borrowed.call(borrowed.borrow.?.binding.target.action()));
        try t.expect(client.service.last_rejection.? == .QueryExpired);
    }
    _ = try maintained.readResult(client, bundle, state, 1, 2);
}
