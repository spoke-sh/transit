//! Same-pin count/scan controls through the signed disk-backed Table service.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const f = q.fuze;
const t = std.testing;
const Snapshot = c.DirectTableProtocol.Snapshot;

fn execute(intent: *const c.DirectTableIntent, client: c.DirectTableClient) !void {
    const admitted = try intent.admit(client);
    defer admitted.deinit();
    const applied = try intent.operation(client, .execute, 32);
    defer applied.deinit();
    switch (applied.value.result) {
        .ddl => |result| try t.expect(result == .committed),
        .rows => |result| try t.expect(result == .committed),
        else => return error.UnexpectedCountRangeOutcome,
    }
}
fn insert(client: c.DirectTableClient, operation: u64, sql: []const u8, ingestion: c.storage.TablePartition.Ingestion) !void {
    var prepared = try c.DirectTablePreparedDml.prepare(client.allocator, client, 1, sql, .transit, null);
    defer prepared.deinit();
    var intent = try prepared.bind(client.allocator, client, operation, &.{}, ingestion, null);
    defer intent.deinit();
    try execute(&intent, client);
}
fn pin(client: c.DirectTableClient, operation: u64) !Snapshot {
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "count_rows" } });
    defer lookup.deinit();
    const metadata = lookup.value.result.lookup.?;
    const response = try client.call(.{ .pin = .{
        .object = metadata.interpretation.interpretation.object,
        .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation },
        .expected = metadata.position,
    } });
    defer response.deinit();
    return .{ .object = metadata.interpretation.interpretation.object, .handle = response.value.result.pin };
}
fn open(client: c.DirectTableClient, snapshot: Snapshot, sql: []const u8, requests: u64) !q.direct.DirectTableQuery {
    return q.direct.DirectTableQuery.openRetained(client.allocator, client, snapshot, "count_rows", sql, .{ .requests = requests, .rows = 8, .result_bytes = 8192 }, null, null, .{});
}
fn count(query: *q.direct.DirectTableQuery, snapshot: Snapshot, expected: u64) !void {
    var batch = try query.nextBatch(8);
    defer batch.deinit();
    try t.expect(batch.complete);
    try t.expectEqual(@as(u8, 1), batch.len);
    try t.expectEqual(@as(u128, expected), batch.rows[0].?.cells[0].value.atom.unsigned);
    try t.expectEqualDeep(snapshot, query.source().snapshot);
}

pub fn run(client: c.DirectTableClient, admin: anytype, role: u64) !void {
    var ddl = try c.DirectTablePreparedDdl.prepare(client.allocator, client, 1, "CREATE TABLE count_rows (k BIGINT PRIMARY KEY, v BIGINT)", .transit, null);
    defer ddl.deinit();
    var creation = try ddl.bind(client.allocator, client, 96000, 912);
    defer creation.deinit();
    try execute(&creation.table, client);
    // Identity order differs from key order. SUM over these first three values
    // overflows in source order, while key order would yield a representable 1.
    try insert(client, 96001,
        \\INSERT INTO count_rows VALUES (17, 9223372036854775807), (1, 1), (16, -9223372036854775807),
        \\(2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0), (8, 0),
        \\(9, 0), (10, 0), (11, 0), (12, 0), (13, 0), (14, 0), (15, 0)
    , .bulk);
    const snapshot = try pin(client, 96002);
    defer (client.call(.{ .release = snapshot }) catch unreachable).deinit();
    // Both controls keep the original cut after later segment and WAL writes.
    try insert(client, 96003, "INSERT INTO count_rows VALUES (18, 0)", .bulk);
    try insert(client, 96006, "INSERT INTO count_rows VALUES (19, 0)", .point);
    const Case = struct { predicate: []const u8, expected: u64, requests: u64 = 8 };
    for ([_]Case{
        .{ .predicate = "k >= 16", .expected = 2 },
        .{ .predicate = "k > 16", .expected = 1 },
        .{ .predicate = "k < 1", .expected = 0 },
        .{ .predicate = "k > 17", .expected = 0 },
        .{ .predicate = "k >= 4 AND k < 4", .expected = 0 },
        .{ .predicate = "k >= 7 AND k <= 2", .expected = 0 },
        .{ .predicate = "k >= 4 AND k <= 4", .expected = 1 },
        .{ .predicate = "k >= 9 AND k <= 16", .expected = 8 },
        .{ .predicate = "k >= 8 AND k <= 16", .expected = 9, .requests = 10 },
        .{ .predicate = "k >= 1 AND k <= 17", .expected = 17, .requests = 12 },
        .{ .predicate = "k >= 16 AND k > 16 AND k <= 17", .expected = 1 },
    }) |case| {
        const sql = try std.fmt.allocPrint(client.allocator, "SELECT COUNT(*) FROM count_rows WHERE {s}", .{case.predicate});
        defer client.allocator.free(sql);
        var ranged = try open(client, snapshot, sql, case.requests);
        defer ranged.deinit();
        try count(&ranged, snapshot, case.expected);
        try t.expectEqual(case.requests, ranged.execution.scan.requests);
        const control = try std.fmt.allocPrint(client.allocator, "SELECT COUNT(*) FROM count_rows WHERE ({s}) AND k IS NOT NULL", .{case.predicate});
        defer client.allocator.free(control);
        var scanned = try open(client, snapshot, control, 12);
        defer scanned.deinit();
        try count(&scanned, snapshot, case.expected);
        try t.expectEqual(@as(u64, 12), scanned.execution.scan.requests);
    }
    var exhausted = try open(client, snapshot, "SELECT COUNT(*) FROM count_rows WHERE k >= 1", 8);
    defer exhausted.deinit();
    try t.expectError(error.QueryPageBudget, exhausted.nextBatch(8));
    try t.expectError(error.FailedQuery, exhausted.nextBatch(8));
    // A same-cut full scan cannot finish under the narrow interval's budget.
    var control = try open(client, snapshot, "SELECT COUNT(*) FROM count_rows WHERE k >= 16 AND k IS NOT NULL", 8);
    defer control.deinit();
    try t.expectError(error.QueryPageBudget, control.nextBatch(8));

    var ordered = try open(client, snapshot, "SELECT k FROM count_rows WHERE k >= 1 LIMIT 1", 8);
    defer ordered.deinit();
    var row = try ordered.nextBatch(8);
    defer row.deinit();
    try t.expect(row.complete and row.len == 1);
    try t.expectEqual(@as(i128, 17), row.rows[0].?.cells[0].value.atom.signed);
    var summed = try open(client, snapshot, "SELECT SUM(v) FROM count_rows WHERE k >= 1", 100);
    defer summed.deinit();
    try t.expectError(error.Overflow, summed.nextBatch(8));

    var prepared = try q.direct.DirectTablePrepared.prepare(client.allocator, client, 1, "SELECT COUNT(*) FROM count_rows WHERE k >= $1 AND k < $2", .transit, null);
    defer prepared.deinit();
    for ([_]struct { lower: i64, upper: i64, expected: u64 }{
        .{ .lower = 16, .upper = 18, .expected = 2 }, .{ .lower = 17, .upper = 17, .expected = 0 },
    }) |case| {
        var query = try q.direct.DirectTableQuery.openPreparedRetained(client.allocator, client, snapshot, &prepared, &.{ .{ .signed = case.lower }, .{ .signed = case.upper } }, .{ .requests = 10, .rows = 8, .result_bytes = 8192 }, null, null, .{});
        defer query.deinit();
        try count(&query, snapshot, case.expected);
    }
    var null_bound = try q.direct.DirectTableQuery.openPreparedRetained(client.allocator, client, snapshot, &prepared, &.{ null, .{ .signed = 18 } }, .{ .requests = 14, .rows = 8, .result_bytes = 8192 }, null, null, .{});
    defer null_bound.deinit();
    try count(&null_bound, snapshot, 0);
    const current = try pin(client, 96004);
    defer (client.call(.{ .release = current }) catch unreachable).deinit();
    // Leave one credential/direct exchange pair for repeated terminal disclosure.
    var fresh = try open(client, current, "SELECT COUNT(*) FROM count_rows WHERE k >= 16", 10);
    defer fresh.deinit();
    try count(&fresh, current, 4);

    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "count_rows" } });
    defer lookup.deinit();
    const object = c.TableAuthority.reference(lookup.value.result.lookup.?.authorization);
    errdefer {
        _ = admin.change(.{ .transfer_object = .{ .object = object, .owner = role } }) catch null;
    }
    const Revoke = struct {
        admin: @TypeOf(admin),
        object: @TypeOf(object),
        done: bool = false,
        fn evaluate(context: *anyopaque, batch: *f.Batch, _: ?*const std.atomic.Value(bool)) !void {
            const self: *@This() = @ptrCast(@alignCast(context));
            batch.evaluate();
            if (!self.done) {
                _ = try self.admin.change(.{ .transfer_object = .{ .object = self.object, .owner = 0 } });
                self.done = true;
            }
        }
    };
    // Revoke after local evaluation, for both a buffered hit and an empty range.
    for ([_][]const u8{ "k >= 16", "k > 17" }) |predicate| {
        var revoke: Revoke = .{ .admin = admin, .object = object };
        const sql = try std.fmt.allocPrint(client.allocator, "SELECT COUNT(*) FROM count_rows WHERE {s}", .{predicate});
        defer client.allocator.free(sql);
        var query = try q.direct.DirectTableQuery.openRetained(client.allocator, client, snapshot, "count_rows", sql, .{ .requests = 100, .rows = 8, .result_bytes = 8192 }, null, null, .{ .runner = .{ .context = &revoke, .evaluate = Revoke.evaluate } });
        defer query.deinit();
        try t.expectError(error.AccessDenied, query.nextBatch(8));
        try t.expect(revoke.done);
        _ = try admin.change(.{ .transfer_object = .{ .object = object, .owner = role } });
        try t.expectError(error.FailedQuery, query.nextBatch(8));
    }
    // Even repeated terminal counts recheck authorization instead of disclosing
    // cached completion. Closing a local query never releases its durable pin.
    _ = try admin.change(.{ .transfer_object = .{ .object = object, .owner = 0 } });
    try t.expectError(error.AccessDenied, fresh.nextBatch(8));
    _ = try admin.change(.{ .transfer_object = .{ .object = object, .owner = role } });

    const Cancel = struct {
        fn evaluate(context: *anyopaque, batch: *f.Batch, _: ?*const std.atomic.Value(bool)) !void {
            const flag: *std.atomic.Value(bool) = @ptrCast(@alignCast(context));
            batch.evaluate();
            flag.store(true, .release);
        }
    };
    var cancellation: std.atomic.Value(bool) = .init(false);
    var cancelled = try q.direct.DirectTableQuery.openRetained(client.allocator, client, snapshot, "count_rows", "SELECT COUNT(*) FROM count_rows WHERE k >= 16", .{ .requests = 8, .rows = 8, .result_bytes = 8192 }, &cancellation, null, .{ .runner = .{ .context = &cancellation, .evaluate = Cancel.evaluate } });
    defer cancelled.deinit();
    try t.expectError(error.Cancelled, cancelled.nextBatch(8));
    try t.expectError(error.FailedQuery, cancelled.nextBatch(8));
    const released = try pin(client, 96005);
    var closed = try open(client, released, "SELECT COUNT(*) FROM count_rows WHERE k >= 16", 8);
    defer closed.deinit();
    (try client.call(.{ .release = released })).deinit();
    // The HTTP owner projects released pins to 409/QueryExpired. Keep that
    // native rejection alongside the transport's Conflict classification.
    try t.expectError(error.Conflict, closed.nextBatch(8));
    try t.expectEqual(q.protocol.ErrorCode.QueryExpired, closed.native_rejection.?);
    std.debug.print("Count ranges: same-cut scan controls, 8/9/17-row intervals, prepared bounds, request exhaustion, source order, post-compute denial, cancellation and released pins passed. Narrow count uses 8 exchanges; full scan requires 12.\n", .{});
}
