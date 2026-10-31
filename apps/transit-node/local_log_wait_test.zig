//! Concurrent native-owner schedules. Each caller has an independent engine,
//! request arena and transport; only the real local host/provider are shared.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Engine = backend.DataAuthority.Engine;
const Service = @import("LocalTableService.zig");
const Host = @import("LocalTableHost.zig");
const Waits = @import("LocalLogWaits.zig");
const p = c.protocol;

const Endpoint = struct {
    host: *Host,
    engine: *Engine,
    fn invoke(raw: *anyopaque, invocation: *c.client.LocalEndpoint.Invocation) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        var scratch: std.heap.ArenaAllocator = .init(t.allocator);
        defer scratch.deinit();
        const request = try invocation.request(c.DirectTableProtocol.Request);
        try invocation.respond(try self.host.executeTyped(t.io, self.engine, &scratch, invocation.allocator, request, request.transport().control != null));
    }
    fn call(self: *@This(), action: c.DirectStreamClient.Action) !c.DirectStreamClient.Result {
        return self.callWith(c.DirectStreamClient, action);
    }
    fn queue(self: *@This(), action: c.DirectQueueClient.Action) !c.DirectQueueClient.Result {
        return self.callWith(c.DirectQueueClient, action);
    }
    fn callWith(self: *@This(), comptime Client: type, action: Client.Action) !Client.Result {
        var transport = c.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
        defer transport.deinit();
        transport.local = .{ .context = self, .invoke = invoke };
        const caller: c.DirectTableClient = .{
            .allocator = t.allocator,
            .authority = &transport,
            .service = &transport,
            .connection = .{ .scope = self.host.configuration.scope, .branch = 1, .audience = self.host.configuration.audience, .principal = 101, .role = null },
            .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(29)),
            .credential_epoch = (try self.engine.principal(101)).credential_epoch,
        };
        var output: std.heap.ArenaAllocator = .init(t.allocator);
        defer output.deinit();
        const result = try Client.apply(&output, caller, action);
        // This helper returns only slice-free outcomes, never a borrowed page.
        try t.expect(result != .page);
        return result;
    }
};

fn wait(host: *Host, native: *backend.Backend, genesis: @import("transit_core").growing.Genesis, request: p.StreamRead.Request) !c.DirectStreamClient.Result {
    var pages = try backend.PageStore.init(native, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = native };
    var engine = try Engine.open(&journal, &pages, genesis);
    var endpoint: Endpoint = .{ .host = host, .engine = &engine };
    return endpoint.call(.{ .wait = .{ .consume = request, .milliseconds = 1000 } });
}

/// Bounded test observation of the actual condition waiter, rather than a
/// scheduling sleep that assumes a request has parked. Production does no poll.
fn parked(waits: *Waits) !void {
    const deadline = (std.Io.Timeout{ .duration = .{ .raw = .fromMilliseconds(900), .clock = .awake } }).toDeadline(t.io);
    while (deadline.toDurationFromNow(t.io).?.raw.nanoseconds > 0) {
        waits.notification.mutex.lockUncancelable(t.io);
        var found = false;
        for (waits.notification.slots) |slot| found = found or slot.waiting;
        waits.notification.mutex.unlock(t.io);
        if (found) return;
        try t.io.sleep(.fromMilliseconds(1), .awake);
    }
    return error.StreamWaitDidNotPark;
}

pub fn exercise(service: *Service, declaration: c.DirectLog.Definition, schema: c.fuze.TableSchema.Schema, owner_role: u64, prepare: *const fn (*Engine, u64) anyerror!u64, publish: *const fn (*Engine, u64) anyerror!void, transfer: *const fn (*Engine, u64, u64) anyerror!void) !void {
    const native = service.engine.journal.backend;
    var control: backend.DataStore = .{ .backend = native, .control = true };
    var data: backend.DataStore = .{ .backend = native };
    var catalog = try c.DirectCatalog.init(t.allocator, service.configuration, control.log(), control.objects(), data.log(), data.objects(), service.options);
    defer catalog.deinit();
    try catalog.recover();
    var host: Host = .{ .configuration = service.configuration, .registrar = service.registrar, .options = service.options, .recovery = try catalog.recoveryState(), .log_waits = try Waits.create(t.allocator, t.io) };
    defer host.deinit();
    var endpoint: Endpoint = .{ .host = &host, .engine = service.engine };
    // Partition one is independent of the retained-page schedule in partition zero.
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declaration.stored.declaration.interpretation, .partition = 1 };
    var request: p.StreamRead.Request = .{ .target = target, .operation = .{ .scope = target.interpretation.object.scope, .principal = 101, .operation = 350 }, .group = null, .from = 0, .until = null, .timestamp = null };
    const timeout = try endpoint.call(.{ .wait = .{ .consume = request, .milliseconds = 1 } });
    try t.expectEqual(@as(u64, 0), timeout.timed_out.next);
    try t.expect((try endpoint.call(.{ .operation = .{ .consume = request } })).operation == null);
    {
        var task = try t.io.concurrent(wait, .{ &host, native, service.engine.genesis, request });
        defer _ = task.cancel(t.io) catch undefined;
        try parked(host.log_waits.?);
        const operation: p.DataLifecycle.Operation = .{ .scope = request.operation.scope, .principal = 101, .operation = 354 };
        const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 84 } } }};
        var buffer: [8192]u8 = undefined;
        const payload = try c.storage.LogBatch.encode(schema, operation, .stream, &.{ .{ .cells = &cells }, .{ .cells = &cells } }, &buffer);
        _ = try endpoint.call(.{ .mutate = .{ .work = .{ .append = .{ .target = target, .operation = operation, .kind = .stream, .producer = null, .rows = 2, .payload = c.storage.LogBatch.content(payload) } }, .payload = payload } });
        const accepted = (try task.await(t.io)).operation.?.consume;
        try t.expectEqual(@as(u64, 2), accepted.until);
        try t.expectEqualDeep(accepted, (try endpoint.call(.{ .wait = .{ .consume = request, .milliseconds = 1 } })).operation.?.consume);
    }
    request.operation.operation = 351;
    request.from = 2;
    {
        var task = try t.io.concurrent(wait, .{ &host, native, service.engine.genesis, request });
        defer _ = task.cancel(t.io) catch undefined;
        try parked(host.log_waits.?);
        try t.expectError(error.Canceled, task.cancel(t.io));
        try t.expectEqual(@as(usize, 0), host.log_waits.?.notification.active);
        try t.expect((try endpoint.call(.{ .operation = .{ .consume = request } })).operation == null);
    }
    request.operation.operation = 352;
    {
        // Prepare the paged policy update before starting the bounded wait;
        // only its native publication races the parked reader.
        const revoked = try prepare(service.engine, declaration.properties.authorization);
        var task = try t.io.concurrent(wait, .{ &host, native, service.engine.genesis, request });
        defer _ = task.cancel(t.io) catch undefined;
        try parked(host.log_waits.?);
        try publish(service.engine, revoked);
        host.notifyLogs();
        try t.expectError(error.Forbidden, task.await(t.io));
        try transfer(service.engine, declaration.properties.authorization, owner_role);
        try t.expect((try endpoint.call(.{ .operation = .{ .consume = request } })).operation == null);
    }
    try t.expectEqual(@as(usize, 0), host.log_waits.?.notification.active);
}

fn waitQueue(host: *Host, native: *backend.Backend, genesis: @import("transit_core").growing.Genesis, clock: @FieldType(Engine, "clock"), request: p.StreamQueue.Claim) !c.DirectQueueClient.Result {
    var pages = try backend.PageStore.init(native, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = native };
    var engine = try Engine.open(&journal, &pages, genesis);
    engine.clock = clock;
    var endpoint: Endpoint = .{ .host = host, .engine = &engine };
    return endpoint.queue(.{ .wait = .{ .claim = request, .milliseconds = 1000 } });
}

pub fn exerciseQueue(service: *Service, declaration: c.DirectLog.Definition, schema: c.fuze.TableSchema.Schema, owner_role: u64, prepare: *const fn (*Engine, u64) anyerror!u64, publish: *const fn (*Engine, u64) anyerror!void, transfer: *const fn (*Engine, u64, u64) anyerror!void) !void {
    const Clock = struct {
        now: std.atomic.Value(u64) = .init(100),
        fn read(raw: *anyopaque) !@import("transit_core").Time.Sample {
            return .{ .unix_ms = @as(*@This(), @ptrCast(@alignCast(raw))).now.load(.acquire), .error_ms = 0 };
        }
    };
    var clock: Clock = .{};
    const prior_clock = service.engine.clock;
    defer service.engine.clock = prior_clock;
    service.engine.clock = .{ .context = &clock, .read = Clock.read };
    const native = service.engine.journal.backend;
    var control: backend.DataStore = .{ .backend = native, .control = true };
    var data: backend.DataStore = .{ .backend = native };
    var catalog = try c.DirectCatalog.init(t.allocator, service.configuration, control.log(), control.objects(), data.log(), data.objects(), service.options);
    defer catalog.deinit();
    try catalog.recover();
    var host: Host = .{ .configuration = service.configuration, .registrar = service.registrar, .options = service.options, .recovery = try catalog.recoveryState(), .log_waits = try Waits.create(t.allocator, t.io) };
    defer host.deinit();
    var endpoint: Endpoint = .{ .host = &host, .engine = service.engine };
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declaration.stored.declaration.interpretation, .partition = 0 };
    var claim: p.StreamQueue.Claim = .{ .target = target, .operation = .{ .scope = target.interpretation.object.scope, .principal = 101, .operation = 650 }, .maximum = 1, .lease_ms = 1000 };
    const timeout = try endpoint.queue(.{ .wait = .{ .claim = claim, .milliseconds = 1 } });
    try t.expectEqual(@as(u64, 0), timeout.timed_out.next);
    try t.expect((try endpoint.queue(.{ .operation = .{ .claim = claim } })).operation == null);
    {
        var task = try t.io.concurrent(waitQueue, .{ &host, native, service.engine.genesis, service.engine.clock, claim });
        defer _ = task.cancel(t.io) catch undefined;
        try parked(host.log_waits.?);
        const operation: p.DataLifecycle.Operation = .{ .scope = claim.operation.scope, .principal = 101, .operation = 651 };
        const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 84 } } }};
        var buffer: [8192]u8 = undefined;
        const payload = try c.storage.LogBatch.encode(schema, operation, .queue, &.{.{ .cells = &cells }}, &buffer);
        _ = try endpoint.queue(.{ .mutate = .{ .work = .{ .enqueue = .{ .target = target, .operation = operation, .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) } }, .payload = payload } });
        const accepted = (try task.await(t.io)).operation.?.claim;
        try t.expectEqual(@as(u32, 1), accepted.rows);
        try t.expectEqualDeep(accepted, (try endpoint.queue(.{ .wait = .{ .claim = claim, .milliseconds = 1 } })).operation.?.claim);
    }
    claim.operation.operation = 652;
    {
        // No publication or maintenance notification occurs at visible_at.
        // The accepted schedule must supply the wakeup, followed by a fresh
        // trusted-time eligibility check. An acquired prior item is excluded.
        const operation: p.DataLifecycle.Operation = .{ .scope = claim.operation.scope, .principal = 101, .operation = 653 };
        const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 85 } } }};
        var buffer: [8192]u8 = undefined;
        const payload = try c.storage.LogBatch.encode(schema, operation, .queue, &.{.{ .cells = &cells, .visible_ms = 150 }}, &buffer);
        _ = try endpoint.queue(.{ .mutate = .{ .work = .{ .enqueue = .{ .target = target, .operation = operation, .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) } }, .payload = payload } });
        var task = try t.io.concurrent(waitQueue, .{ &host, native, service.engine.genesis, service.engine.clock, claim });
        defer _ = task.cancel(t.io) catch undefined;
        try parked(host.log_waits.?);
        clock.now.store(150, .release);
        const accepted = (try task.await(t.io)).operation.?.claim;
        try t.expectEqual(@as(u32, 1), accepted.rows);
        try t.expectEqual(@as(u64, 150), accepted.observed_ms);
    }
    claim.operation.operation = 654;
    {
        var task = try t.io.concurrent(waitQueue, .{ &host, native, service.engine.genesis, service.engine.clock, claim });
        defer _ = task.cancel(t.io) catch undefined;
        try parked(host.log_waits.?);
        try t.expectError(error.Canceled, task.cancel(t.io));
        try t.expectEqual(@as(usize, 0), host.log_waits.?.notification.active);
        try t.expect((try endpoint.queue(.{ .operation = .{ .claim = claim } })).operation == null);
    }
    claim.operation.operation = 655;
    {
        const revoked = try prepare(service.engine, declaration.properties.authorization);
        var task = try t.io.concurrent(waitQueue, .{ &host, native, service.engine.genesis, service.engine.clock, claim });
        defer _ = task.cancel(t.io) catch undefined;
        try parked(host.log_waits.?);
        try publish(service.engine, revoked);
        host.notifyLogs();
        try t.expectError(error.Forbidden, task.await(t.io));
        try transfer(service.engine, declaration.properties.authorization, owner_role);
        try t.expect((try endpoint.queue(.{ .operation = .{ .claim = claim } })).operation == null);
    }
    try t.expectEqual(@as(usize, 0), host.log_waits.?.notification.active);
}
