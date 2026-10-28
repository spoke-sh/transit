//! Retain the same prepared objects across fresh reads, policy and DDL changes.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const f = q.fuze;
const t = std.testing;
const name = "prepared_rows";
const create = "CREATE TABLE prepared_rows (k BIGINT PRIMARY KEY, v UTF8, n UINT64 DEFAULT 7)";
const Self = @This();
allocator: std.mem.Allocator,
client: c.DirectTableClient,
pin_operation: u64 = 93000,

fn execute(self: *Self, intent: *const c.DirectTableIntent) !void {
    const admitted = try intent.admit(self.client);
    defer admitted.deinit();
    const applied = try intent.operation(self.client, .execute, 32);
    defer applied.deinit();
    switch (applied.value.result) {
        .ddl => |value| try t.expect(value == .committed),
        .rows => |value| try t.expect(value == .committed),
        else => return error.UnexpectedPreparedOutcome,
    }
}
fn ddl(self: *Self, sql: []const u8, operation: u64, object: ?u64) !void {
    var prepared = try c.DirectTablePreparedDdl.prepare(self.allocator, self.client, 1, sql, .transit, null);
    defer prepared.deinit();
    var work = try prepared.bind(self.allocator, self.client, operation, object);
    defer work.deinit();
    try self.execute(&work.table);
}
fn bind(self: *Self, prepared: *const c.DirectTablePreparedDml, operation: u64, values: []const ?f.Types.Values.Atom) !c.DirectTableIntent {
    const before = try self.client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer before.deinit();
    var work = try prepared.bind(self.allocator, self.client, operation, values, .point, null);
    errdefer work.deinit();
    const after = try self.client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer after.deinit();
    try t.expectEqualDeep(before.value.result.lookup.?.position, after.value.result.lookup.?.position);
    const status = try work.operation(self.client, .inspect, 1);
    defer status.deinit();
    try t.expect(status.value.result.rows == .not_observed);
    return work;
}
fn read(self: *Self, prepared: *const q.direct.DirectTablePrepared, value: ?f.Types.Values.Atom, expected: ?[]const u8, rows: u8) !void {
    const response = try self.client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer response.deinit();
    const metadata = response.value.result.lookup.?;
    // A fresh execution cannot relabel an old template with a new definition.
    try prepared.binding.check(self.client.connection, metadata);
    self.pin_operation += 1;
    const pinned = try self.client.call(.{ .pin = .{ .object = metadata.interpretation.interpretation.object, .owner = .{ .scope = self.client.connection.scope, .principal = self.client.connection.principal, .operation = self.pin_operation }, .expected = metadata.position } });
    defer pinned.deinit();
    const snapshot: c.DirectTableProtocol.Snapshot = .{ .object = metadata.interpretation.interpretation.object, .handle = pinned.value.result.pin };
    defer (self.client.call(.{ .release = snapshot }) catch unreachable).deinit();
    // Seventeen rows require three scan pages. A complete key equality instead
    // fits one point call plus preparation/opening and final disclosure checks.
    var query = try q.direct.DirectTableQuery.openPreparedRetained(self.allocator, self.client, snapshot, prepared, &.{value}, .{ .requests = if (value != null) 10 else 100, .rows = 8, .result_bytes = 8192 }, null, null, .{});
    defer query.deinit();
    var batch = try query.nextBatch(8);
    defer batch.deinit();
    try t.expect(batch.complete);
    try t.expectEqual(rows, batch.len);
    if (rows == 0) return;
    const cells = batch.rows[0].?.cells;
    try t.expectEqual(@as(i128, 1), cells[0].value.atom.signed);
    if (expected) |text| try t.expectEqualStrings(text, cells[1].value.atom.bytes) else try t.expect(cells[1] == .null);
    try t.expectEqual(@as(u128, std.math.maxInt(u64)), cells[2].value.atom.unsigned);
}
fn finiteReads(self: *Self) !void {
    const response = try self.client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer response.deinit();
    const metadata = response.value.result.lookup.?;
    self.pin_operation += 1;
    const pinned = try self.client.call(.{ .pin = .{ .object = metadata.interpretation.interpretation.object, .owner = .{ .scope = self.client.connection.scope, .principal = self.client.connection.principal, .operation = self.pin_operation }, .expected = metadata.position } });
    defer pinned.deinit();
    const snapshot: c.DirectTableProtocol.Snapshot = .{ .object = metadata.interpretation.interpretation.object, .handle = pinned.value.result.pin };
    defer (self.client.call(.{ .release = snapshot }) catch unreachable).deinit();
    const Case = struct { sql: []const u8, requests: u64, expected: ?f.Types.Values.Cell };
    // Each tight-budget equality must finish before even two source-page calls
    // are possible. General predicates use the same retained source as controls.
    for ([_]Case{
        .{ .sql = "SELECT k FROM prepared_rows WHERE k = 17", .requests = 8, .expected = .{ .value = .{ .atom = .{ .signed = 17 } } } },
        .{ .sql = "SELECT COUNT(*) FROM prepared_rows WHERE k = 1000", .requests = 8, .expected = .{ .value = .{ .atom = .{ .unsigned = 0 } } } },
        .{ .sql = "SELECT SUM(k) FROM prepared_rows WHERE k = 1000", .requests = 8, .expected = .null },
        .{ .sql = "SELECT k FROM prepared_rows WHERE k = 17 LIMIT 0", .requests = 6, .expected = null },
        .{ .sql = "SELECT k FROM prepared_rows WHERE k >= 17", .requests = 100, .expected = .{ .value = .{ .atom = .{ .signed = 17 } } } },
        .{ .sql = "SELECT COUNT(*) FROM prepared_rows WHERE k = 1 OR k = 17", .requests = 100, .expected = .{ .value = .{ .atom = .{ .unsigned = 2 } } } },
        .{ .sql = "SELECT COUNT(*) FROM prepared_rows", .requests = 100, .expected = .{ .value = .{ .atom = .{ .unsigned = 17 } } } },
    }) |case| {
        var query = try q.direct.DirectTableQuery.openRetained(self.allocator, self.client, snapshot, name, case.sql, .{ .requests = case.requests, .rows = 8, .result_bytes = 8192 }, null, null, .{});
        defer query.deinit();
        var batch = try query.nextBatch(8);
        defer batch.deinit();
        try t.expect(batch.complete);
        try t.expectEqual(@as(u8, if (case.expected != null) 1 else 0), batch.len);
        if (case.expected) |expected| try t.expectEqualDeep(expected, batch.rows[0].?.cells[0]);
        try t.expectEqualDeep(snapshot, query.source().snapshot);
    }
    var scan = try q.direct.DirectTableQuery.openRetained(self.allocator, self.client, snapshot, name, "SELECT k FROM prepared_rows WHERE k = 17 AND n = 7", .{ .requests = 8, .rows = 8, .result_bytes = 8192 }, null, null, .{});
    defer scan.deinit();
    try t.expectError(error.QueryPageBudget, scan.nextBatch(8));
    try t.expectError(error.FailedQuery, scan.nextBatch(8));
}
fn compositeReads(self: *Self) !void {
    try self.ddl("CREATE TABLE prepared_keys (tag VARCHAR(8), longtag UTF8, k BIGINT, PRIMARY KEY(tag, longtag, k))", 92020, 9902);
    var insert = try c.DirectTablePreparedDml.prepare(self.allocator, self.client, 1, "INSERT INTO prepared_keys VALUES ('東京', 'x', -3)", .transit, null);
    defer insert.deinit();
    var work = try insert.bind(self.allocator, self.client, 92021, &.{}, .point, null);
    defer work.deinit();
    try self.execute(&work);
    var select = try q.direct.DirectTablePrepared.prepare(self.allocator, self.client, 1, "SELECT k FROM prepared_keys WHERE k = $1 AND longtag = $2 AND tag = $3", .transit, null);
    defer select.deinit();
    const response = try self.client.call(.{ .lookup = .{ .namespace = 1, .name = "prepared_keys" } });
    defer response.deinit();
    const metadata = response.value.result.lookup.?;
    self.pin_operation += 1;
    const pinned = try self.client.call(.{ .pin = .{ .object = metadata.interpretation.interpretation.object, .owner = .{ .scope = self.client.connection.scope, .principal = self.client.connection.principal, .operation = self.pin_operation }, .expected = metadata.position } });
    defer pinned.deinit();
    const snapshot: c.DirectTableProtocol.Snapshot = .{ .object = metadata.interpretation.interpretation.object, .handle = pinned.value.result.pin };
    defer (self.client.call(.{ .release = snapshot }) catch unreachable).deinit();
    const wide: [4096]u8 = @splat('x');
    const Case = struct { tag: []const u8, longtag: []const u8, count: u8 };
    for ([_]Case{
        .{ .tag = "東京", .longtag = "x", .count = 1 },
        .{ .tag = "absent", .longtag = "x", .count = 0 },
        // Comparisons may use values which cannot be stored as this key. Both
        // remain valid empty queries, not character-limit or key-encoding errors.
        .{ .tag = "123456789", .longtag = "x", .count = 0 },
        .{ .tag = "東京", .longtag = &wide, .count = 0 },
    }) |case| {
        var query = try q.direct.DirectTableQuery.openPreparedRetained(self.allocator, self.client, snapshot, &select, &.{ .{ .signed = -3 }, .{ .bytes = case.longtag }, .{ .bytes = case.tag } }, .{ .requests = 10, .rows = 8, .result_bytes = 8192 }, null, null, .{});
        defer query.deinit();
        var batch = try query.nextBatch(8);
        defer batch.deinit();
        try t.expect(batch.complete);
        try t.expectEqual(case.count, batch.len);
        if (case.count == 1) try t.expectEqual(@as(i128, -3), batch.rows[0].?.cells[0].value.atom.signed);
    }
}
pub fn run(allocator: std.mem.Allocator, client: c.DirectTableClient, admin: anytype, role: u64) !void {
    var self: Self = .{ .allocator = allocator, .client = client };
    try self.ddl(create, 92000, 902);
    const before = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer before.deinit();
    var select = try q.direct.DirectTablePrepared.prepare(allocator, client, 1, "SELECT k, v, n FROM prepared_rows WHERE k = $1", .transit, null);
    defer select.deinit();
    var insert = try c.DirectTablePreparedDml.prepare(allocator, client, 1, "INSERT INTO prepared_rows (k, v, n) VALUES ($1, $2, $3)", .transit, null);
    defer insert.deinit();
    var update = try c.DirectTablePreparedDml.prepare(allocator, client, 1, "UPDATE `prepared_rows` SET v = ? WHERE k = ?", .mysql, null);
    defer update.deinit();
    const after = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer after.deinit();
    try t.expectEqualDeep(before.value.result.lookup.?.position, after.value.result.lookup.?.position);
    const text = "東京'; DELETE FROM prepared_rows; ? $1";
    var inserted = try self.bind(&insert, 92001, &.{ .{ .signed = 1 }, .{ .bytes = text }, .{ .unsigned = std.math.maxInt(u64) } });
    defer inserted.deinit();
    const token_key: c.DirectClientToken.Key = .{ .definition = c.protocol.Growth.current_definition, .connection = client.connection, .account = @splat(27), .token = @splat(91) };
    try t.expect(try c.DirectClientToken.lookup(client, token_key) == null);
    const token_binding: c.DirectClientToken.Binding = .{ .key = token_key, .fingerprint = @splat(37), .intent = try inserted.stage(client, 1) };
    const token_receipt = try c.DirectClientToken.bind(client, token_binding);
    var conflicting = token_binding;
    conflicting.fingerprint[0] ^= 1;
    try t.expectError(error.Conflict, c.DirectClientToken.bind(client, conflicting));
    const recovered = (try c.DirectClientToken.lookup(client, token_key)).?;
    try t.expectEqualDeep(token_receipt, recovered);
    // Use the recovered original reference, including on a repeated execution.
    // A lookup never admits data and rebinding never resets its terminal state.
    const reference = recovered.binding.intent;
    const missing = try reference.operation(client, .inspect, 1);
    defer missing.deinit();
    try t.expect(missing.value.result.rows == .not_observed);
    (try reference.admit(client)).deinit();
    const accepted = try reference.operation(client, .execute, 1);
    defer accepted.deinit();
    try t.expectEqual(@as(u64, 1), accepted.value.result.rows.committed.outcome.affected);
    try t.expectEqualDeep(token_receipt, try c.DirectClientToken.bind(client, token_binding));
    const repeated = try reference.operation(client, .execute, 1);
    defer repeated.deinit();
    try t.expectEqualDeep(accepted.value.result.rows.committed, repeated.value.result.rows.committed);
    var filler = try c.DirectTablePreparedDml.prepare(allocator, client, 1,
        \\INSERT INTO prepared_rows (k, v, n) VALUES
        \\(2, 'other', 7), (3, 'other', 7), (4, 'other', 7), (5, 'other', 7),
        \\(6, 'other', 7), (7, 'other', 7), (8, 'other', 7), (9, 'other', 7),
        \\(10, 'other', 7), (11, 'other', 7), (12, 'other', 7), (13, 'other', 7),
        \\(14, 'other', 7), (15, 'other', 7), (16, 'other', 7), (17, 'other', 7)
    , .transit, null);
    defer filler.deinit();
    var filled = try self.bind(&filler, 92010, &.{});
    defer filled.deinit();
    try self.execute(&filled);
    try self.finiteReads();
    try self.read(&select, .{ .signed = 1 }, text, 1);
    try self.read(&select, .{ .signed = 1000 }, null, 0);
    try self.read(&select, null, null, 0);
    try t.expectError(error.NullNotAllowed, self.bind(&insert, 92002, &.{ null, null, null }));
    try t.expectError(error.ParameterCountMismatch, self.bind(&insert, 92002, &.{}));
    var nulled = try self.bind(&update, 92003, &.{ null, .{ .signed = 1 } });
    defer nulled.deinit();
    try self.execute(&nulled);
    try self.read(&select, .{ .signed = 1 }, null, 1);
    var changed = try self.bind(&update, 92004, &.{ .{ .bytes = "fresh" }, .{ .signed = 1 } });
    defer changed.deinit();
    try self.execute(&changed);
    try self.read(&select, .{ .signed = 1 }, "fresh", 1);
    const object = c.TableAuthority.reference(before.value.result.lookup.?.authorization);
    _ = try admin.change(.{ .transfer_object = .{ .object = object, .owner = 0 } });
    try t.expectError(error.AccessDenied, c.DirectClientToken.lookup(client, token_key));
    try t.expectError(error.AccessDenied, self.read(&select, .{ .signed = 1 }, "fresh", 1));
    _ = try admin.change(.{ .transfer_object = .{ .object = object, .owner = role } });
    try self.read(&select, .{ .signed = 1 }, "fresh", 1);
    try self.ddl("ALTER TABLE prepared_rows ADD COLUMN extra BIGINT", 92005, null);
    try t.expectError(error.TableDefinitionChanged, self.read(&select, .{ .signed = 1 }, "fresh", 1));
    try t.expectError(error.TableDefinitionChanged, self.bind(&update, 92006, &.{ null, .{ .signed = 1 } }));
    try self.ddl("DROP TABLE prepared_rows", 92007, null);
    try self.ddl(create, 92008, 903);
    try t.expectError(error.TableDefinitionChanged, self.read(&select, .{ .signed = 1 }, null, 0));
    try t.expectError(error.TableDefinitionChanged, self.bind(&insert, 92009, &.{ .{ .signed = 2 }, null, null }));
    try self.compositeReads();
}
