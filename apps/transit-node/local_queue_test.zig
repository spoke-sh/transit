//! Signed native Queue calls, original recovery and caller-owned pages. The
//! enclosing policy schedule supplies a published Queue and native credentials.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const p = c.protocol;
const Service = @import("LocalTableService.zig");

pub fn exercise(service: *Service, declaration: c.DirectLog.Definition, schema: c.fuze.TableSchema.Schema, key: p.Ed25519.KeyPair) !c.DirectQueue.Request {
    const Clock = struct {
        now: u64 = 100,
        fn read(raw: *anyopaque) !@import("transit_core").Time.Sample {
            return .{ .unix_ms = @as(*@This(), @ptrCast(@alignCast(raw))).now, .error_ms = 5 };
        }
    };
    var clock: Clock = .{};
    const previous_clock = service.engine.clock;
    defer service.engine.clock = previous_clock;
    service.engine.clock = .{ .context = &clock, .read = Clock.read };
    const Endpoint = struct {
        service: *Service,
        lose: bool = false,
        fn run(raw: *anyopaque, invocation: *c.client.LocalEndpoint.Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            try t.expectEqualStrings("/table/v1", invocation.path);
            var scratch: std.heap.ArenaAllocator = .init(t.allocator);
            defer scratch.deinit();
            const response = try self.service.executeResult(.typed, &scratch, invocation.allocator, try invocation.request(c.DirectTableProtocol.Request));
            if (self.lose) {
                self.lose = false;
                return error.LostAcknowledgement;
            }
            try invocation.respond(response);
        }
    };
    var endpoint: Endpoint = .{ .service = service };
    var transport = c.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer transport.deinit();
    transport.local = .{ .context = &endpoint, .invoke = Endpoint.run };
    const connection: c.DirectTableProtocol.Connection = .{ .scope = service.configuration.scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null };
    var attempt: c.DirectTableClient.Attempt = .{};
    const caller: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = connection, .key = key, .credential_epoch = (try service.engine.principal(101)).credential_epoch, .attempt = &attempt };
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declaration.stored.declaration.interpretation, .partition = 0 };
    const identity: p.DataLifecycle.Operation = .{ .scope = connection.scope, .principal = 101, .operation = 501 };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    var buffer: [8192]u8 = undefined;
    const payload = try c.storage.LogBatch.encode(schema, identity, .queue, &.{ .{ .cells = &cells }, .{ .cells = &cells } }, &buffer);
    const enqueue: c.DirectQueueMutation.Request = .{ .enqueue = .{ .target = target, .operation = identity, .kind = .queue, .producer = .{ .id = @splat(12), .epoch = 1, .sequence = 1 }, .rows = 2, .payload = c.storage.LogBatch.content(payload) } };
    const saved = try c.DirectQueueClient.save(t.allocator, connection, .{ .work = enqueue, .payload = payload });
    defer t.allocator.free(saved);
    const original = try c.DirectQueueClient.load(t.allocator, saved);
    defer original.deinit();
    endpoint.lose = true;
    try t.expectError(error.LostAcknowledgement, c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = enqueue, .payload = payload } }));
    try t.expectEqualDeep(identity, attempt.mutation.?.identity.?);
    try t.expectEqual(.queue, attempt.mutation.?.action);
    try t.expectEqual(.unknown, (try attempt.failure(error.LostAcknowledgement, null)).?.outcome);
    const accepted = (try caller.call(.{ .queue = .{ .mutate = original.value.work } }));
    defer accepted.deinit();
    try t.expectEqual(@as(u64, 2), accepted.value.result.queue.operation.?.enqueue.next);
    const claim: c.DirectQueueMutation.Request = .{ .claim = .{ .target = target, .operation = .{ .scope = connection.scope, .principal = 101, .operation = 502 }, .maximum = 2, .lease_ms = 100 } };
    endpoint.lose = true;
    try t.expectError(error.LostAcknowledgement, c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = claim } }));
    try t.expectEqualDeep(claim.identity(), attempt.mutation.?.identity.?);
    service.engine.clock = null;
    const claimed = (try c.DirectQueueClient.apply(&output, caller, .{ .operation = claim })).operation.?.claim;
    try t.expectEqual(@as(u64, 105), claimed.observed_ms);
    try t.expectEqual(@as(u64, 205), claimed.expires_ms);
    try t.expectEqualDeep(claimed, (try c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = claim } })).operation.?.claim);
    const page_request: c.DirectQueue.Request = .{ .page = .{ .cursor = .{ .receipt = claimed, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } };
    attempt = .{};
    const unavailable = (try c.DirectQueueClient.apply(&output, caller, .{ .page = page_request.page })).page;
    try t.expectEqual(.unavailable, unavailable.rows[0].lease.liveness);
    try t.expect(attempt.mutation == null);
    service.engine.clock = .{ .context = &clock, .read = Clock.read };
    const first = (try c.DirectQueueClient.apply(&output, caller, .{ .page = page_request.page })).page;
    try t.expectEqual(.live, first.rows[0].lease.liveness);
    try t.expect(!first.cursor.complete());
    const second = (try c.DirectQueueClient.apply(&output, caller, .{ .page = .{ .cursor = first.cursor, .limits = page_request.page.limits } })).page;
    try t.expect(second.cursor.complete());
    try t.expectEqual(@as(u64, 1), second.rows[0].lease.original.offset);
    const terminal = (try c.DirectQueueClient.apply(&output, caller, .{ .page = .{ .cursor = second.cursor, .limits = page_request.page.limits } })).page;
    try t.expect(terminal.cursor.complete() and terminal.rows.len == 0);
    try t.expectEqual(@as(i64, 42), first.rows[0].value.cells[0].value.atom.signed);
    try t.expectEqualStrings("id", first.source.schema.columns[0].name);
    var settlement: c.DirectQueueMutation.Request = .{ .settle = .{ .operation = .{ .scope = connection.scope, .principal = 101, .operation = 503 }, .lease = first.rows[0].lease.original, .action = .{ .extend = .{ .expires_ms = 305 } } } };
    const renewed = (try c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = settlement } })).operation.?.settle;
    try t.expectEqualDeep(settlement.settle, renewed.settlement);
    settlement.settle.operation.operation = 504;
    settlement.settle.action = .ack;
    try t.expectError(error.QueueLeaseFenced, c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = settlement } }));
    // A refused attempt may already reserve its identity. Corrected work gets
    // a new identity; it never rewrites the original settlement intent.
    settlement.settle.operation.operation = 505;
    settlement.settle.lease.expires_ms = 305;
    endpoint.lose = true;
    try t.expectError(error.LostAcknowledgement, c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = settlement } }));
    const ack = (try c.DirectQueueClient.apply(&output, caller, .{ .operation = settlement })).operation.?.settle;
    try t.expectEqualDeep(settlement.settle, ack.settlement);
    var nack = settlement;
    nack.settle.operation.operation = 506;
    nack.settle.lease = second.rows[0].lease.original;
    nack.settle.action = .{ .nack = .{ .visible_ms = 300 } };
    _ = try c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = nack } });
    const settled_page = (try c.DirectQueueClient.apply(&output, caller, .{ .page = page_request.page })).page;
    try t.expectEqual(.acked, settled_page.rows[0].lease.state);
    try t.expectEqual(.fenced, settled_page.rows[0].lease.liveness);
    var later = claim;
    later.claim.operation.operation = 507;
    const empty = (try c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = later } })).operation.?.claim;
    try t.expectEqual(@as(u32, 0), empty.rows);
    clock.now = 1000;
    try t.expectEqualDeep(empty, (try c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = later } })).operation.?.claim);
    later.claim.operation.operation = 508;
    const reassigned = (try c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = later } })).operation.?.claim;
    try t.expectEqual(@as(u32, 1), reassigned.rows);
    clock.now = 2000;
    const expired = (try c.DirectQueueClient.apply(&output, caller, .{ .page = .{ .cursor = .{ .receipt = reassigned, .next = 0 }, .limits = page_request.page.limits } })).page;
    try t.expectEqual(.expired, expired.rows[0].lease.liveness);
    try t.expectEqual(.acquired, expired.rows[0].lease.state);
    try t.expectEqual(@as(u64, 2), expired.rows[0].lease.epoch);
    try t.expectEqualDeep(ack, (try c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = settlement } })).operation.?.settle);
    return .{ .page = .{ .cursor = terminal.cursor, .limits = page_request.page.limits } };
}
