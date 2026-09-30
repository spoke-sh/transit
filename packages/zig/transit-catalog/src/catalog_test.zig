const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const s = c.station;
const p = c.protocol;
const m = c.Model;
const r = c.Records;
const Store = @import("TestStore.zig");
const owner: c.Catalog = .{ .configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .administrator = 17 } };
fn request() !m.CreateTable {
    return m.CreateTable.compile(owner.configuration.scope, std.math.maxInt(u64), std.math.maxInt(u64), 9, "CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)");
}
fn ready(store: *Store) !void {
    var turn = try store.capture(17);
    try owner.initialize(&turn);
    try t.expectEqual(2, count(&turn));
    try store.commit(turn);
}
fn count(turn: *const s.Turn) usize {
    var total: usize = 0;
    for (turn.decision.mutations) |entry| if (entry != null) {
        total += 1;
    };
    return total;
}
test "catalog records agree with independent layouts and reject incompatible bytes" {
    const Fixture = struct { version: u8, native_definition: []const u8, digest: []const u8, records: struct { configuration: []const u8, policy: []const u8, request: []const u8, definition: []const u8, binding: []const u8, receipt_1: []const u8, receipt_2: []const u8, receipt_3: []const u8, receipt_4: []const u8 }, keys: struct { configuration: []const u8, policy: []const u8, definition: []const u8, binding: []const u8, receipt: []const u8 } };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/catalog-v1.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    try t.expectEqualStrings(@tagName(p.Growth.current_definition), fixture.native_definition);
    const req = try request();
    const created = try m.Definition.created(req, 17, 2);
    const values = .{ owner.configuration, m.Policy{ .scope = req.scope, .principal = 17, .revision = 1, .inspect = true, .create = true }, req, created, m.Binding{ .scope = req.scope, .object = req.object, .revision = 1, .digest = try created.digest() } };
    var buffer: [256]u8 = undefined;
    inline for (.{ "configuration", "policy", "request", "definition", "binding" }, .{ 'c', 'p', 'q', 'd', 'n' }, values) |name, tag, value| {
        const bytes = try p.Value.init(try std.fmt.hexToBytes(&buffer, @field(fixture.records, name)));
        try t.expect(bytes.eql(try r.encode(tag, value)));
        try t.expect(std.meta.eql(value, try r.decode(@TypeOf(value), tag, bytes)));
        for (0..bytes.len) |length| {
            if (r.decode(@TypeOf(value), tag, try p.Value.init(bytes.slice()[0..length]))) |_| return error.AcceptedTruncation else |_| {}
        }
        var corrupt = bytes;
        corrupt.len += 1;
        try t.expectError(error.InvalidCatalogRecord, r.decode(@TypeOf(value), tag, corrupt));
        corrupt = bytes;
        corrupt.data[5] ^= 1;
        try t.expectError(error.IncompatibleDefinition, r.decode(@TypeOf(value), tag, corrupt));
        corrupt = bytes;
        corrupt.data[4] = '!';
        try t.expectError(error.InvalidCatalogRecord, r.decode(@TypeOf(value), tag, corrupt));
    }
    inline for (.{ "receipt_1", "receipt_2", "receipt_3", "receipt_4" }, .{ m.Outcome.applied, .name_conflict, .object_conflict, .table_conflict }) |name, outcome| {
        const receipt: m.Receipt = .{ .request = req, .principal = 17, .input = 2, .outcome = outcome };
        const bytes = try p.Value.init(try std.fmt.hexToBytes(&buffer, @field(fixture.records, name)));
        try t.expect(bytes.eql(try r.encode('o', receipt)));
        try t.expect(std.meta.eql(receipt, try r.decode(m.Receipt, 'o', bytes)));
    }
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&buffer, fixture.digest), &try created.digest());
    const keys = .{ r.key(req.scope.catalog, 'c', 0, 0), r.key(req.scope.catalog, 'p', 17, 0), r.key(req.scope.catalog, 'd', req.object, 1), try r.nameKey(req.scope.catalog, req.name), r.key(req.scope.catalog, 'o', 17, req.operation) };
    inline for (.{ "configuration", "policy", "definition", "binding", "receipt" }, keys) |name, key| try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&buffer, @field(fixture.keys, name)), key.slice());
}
test "catalog initialization binds its owner, administrator and current definition" {
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture(18);
    try t.expectError(error.CatalogDenied, owner.initialize(&turn));
    try t.expectEqual(0, count(&turn));
    try ready(&store);
    turn = try store.capture(17);
    const old: m.Policy = .{ .scope = owner.configuration.scope, .principal = 17, .revision = 2, .inspect = false, .create = false };
    try owner.setPolicy(&turn, 1, old);
    try store.commit(turn);
    turn = try store.capture(17);
    try owner.initialize(&turn);
    try t.expectEqual(0, count(&turn));
    try t.expectError(error.CatalogDenied, owner.createTable(&turn, try request()));
    var changed = owner;
    changed.configuration.administrator = 18;
    turn = try store.capture(18);
    try t.expectError(error.CatalogConfigurationChanged, changed.initialize(&turn));
    turn = try store.capture(17);
    turn.delivery.pid = 4;
    try t.expectError(error.CatalogOwnerChanged, owner.initialize(&turn));
    turn = try store.capture(17);
    turn.delivery.input.origin = .{ .process = .{ .pid = 17, .turn = 1, .output = 0 } };
    try t.expectError(error.CatalogDenied, owner.initialize(&turn));
    const key = r.key(owner.configuration.scope.catalog, 'c', 0, 0);
    var foreign = store.state.get(key).?;
    foreign.data[5] ^= 1;
    try store.state.put(t.allocator, key, foreign);
    turn = try store.capture(17);
    try t.expectError(error.IncompatibleDefinition, owner.initialize(&turn));
    try t.expectEqual(0, count(&turn));
}
test "initialization refuses orphan records without changing their authority" {
    var store: Store = .{};
    defer store.deinit();
    const req = try request();
    const created = try m.Definition.created(req, 17, 1);
    try store.state.put(t.allocator, r.key(req.scope.catalog, 'd', req.object, 1), try r.encode('d', created));
    var turn = try store.capture(17);
    try t.expectError(error.CatalogAlreadyPopulated, owner.initialize(&turn));
    try t.expectEqual(0, count(&turn));
    try t.expectEqual(1, store.pages);
    try t.expectEqual(1, store.state.count());
}
test "catalog integrity checks reject changed definitions, scopes, sources and malformed pages" {
    var store: Store = .{};
    defer store.deinit();
    try ready(&store);
    var req = try request();
    var turn = try store.capture(17);
    _ = try owner.createTable(&turn, req);
    try store.commit(turn);
    const name_key = try r.nameKey(req.scope.catalog, req.name);
    const original = store.state.get(name_key).?;
    var binding = try r.decode(m.Binding, 'n', original);
    binding.digest[0] ^= 1;
    try store.state.put(t.allocator, name_key, try r.encode('n', binding));
    turn = try store.capture(17);
    try t.expectError(error.CatalogDefinitionChanged, owner.lookup(&turn, req.name));
    req.operation = 1;
    try t.expectError(error.CatalogDefinitionChanged, owner.createTable(&turn, req));
    try t.expectEqual(0, count(&turn));
    binding = try r.decode(m.Binding, 'n', original);
    binding.scope.realm += 1;
    try store.state.put(t.allocator, name_key, try r.encode('n', binding));
    try t.expectError(error.CatalogScopeChanged, owner.lookup(&turn, req.name));
    try store.state.put(t.allocator, name_key, original);
    var schema = req.schema;
    schema.value_type = .binary;
    try store.state.put(t.allocator, s.Table.descriptorKey(req.table), try s.Table.encodeSchema(schema));
    try t.expectError(error.CatalogSourceChanged, owner.lookup(&turn, req.name));
    try store.state.put(t.allocator, s.Table.descriptorKey(req.table), try s.Table.encodeSchema(req.schema));
    inline for (.{ .gap, .next, .revision, .order }) |failure| {
        store.bad_page = failure;
        try t.expectError(error.InvalidCatalogPage, owner.list(&turn, null));
    }
}
test "maximum-width catalog names and schemas fit the native value and command bounds" {
    var req = try request();
    req.name = try c.fuze.model.Name.init("abcdefghijklmnop");
    req.schema.names = .{ req.name, try c.fuze.model.Name.init("ABCDEFGHIJKLMNOP") };
    try t.expectEqual(138, (try r.encode('q', req)).len);
    try t.expectEqual(163, (try r.encode('d', try m.Definition.created(req, p.max_counter, p.max_counter))).len);
    const receipt: m.Receipt = .{ .request = req, .principal = p.max_counter, .input = p.max_counter, .outcome = .applied };
    try t.expectEqual(155, (try r.encode('o', receipt)).len);
    _ = try (s.Frame{ .kind = .cast, .payload = try r.encode('q', req) }).encode();
}
test "Table descriptor, immutable definition, name and exact receipt share four writes" {
    var store: Store = .{};
    defer store.deinit();
    try ready(&store);
    var turn = try store.capture(17);
    const req = try request();
    const receipt = try owner.createTable(&turn, req);
    try t.expectEqual(.applied, receipt.outcome);
    try t.expectEqual(4, count(&turn));
    try t.expect(store.state.get(s.Table.descriptorKey(req.table)) == null);
    const created = (try owner.lookup(&turn, req.name)).?;
    try t.expectEqual(1, created.revision);
    try t.expectEqual(req.object, created.object);
    try t.expect(std.meta.eql(req.schema, (try s.Table.open(&turn, req.table)).schema));
    try t.expectEqual(null, try (try s.Table.open(&turn, req.table)).get(&turn, 1));
    try store.commit(turn);
    var replacement = try store.clone();
    defer replacement.deinit();
    turn = try replacement.capture(17);
    try t.expect(std.meta.eql(receipt, try owner.createTable(&turn, req)));
    try t.expectEqual(0, count(&turn));
    try t.expect(std.meta.eql(receipt, (try owner.receipt(&turn, req.operation)).?));
    try t.expect(std.meta.eql(created, (try owner.definition(&turn, req.object, 1)).?));
    var altered = req;
    altered.schema.value_type = .binary;
    try t.expectError(error.CatalogIdentityConflict, owner.createTable(&turn, altered));
    altered = req;
    altered.scope.resource = 8;
    try t.expectError(error.CatalogScopeChanged, owner.createTable(&turn, altered));
    try t.expectEqual(0, count(&turn));
}
test "conditional conflicts retain their original outcome and never adopt Tables" {
    var store: Store = .{};
    defer store.deinit();
    try ready(&store);
    const first = try request();
    var turn = try store.capture(17);
    _ = try owner.createTable(&turn, first);
    try store.commit(turn);
    for ([_]m.Outcome{ .name_conflict, .object_conflict, .table_conflict }, 0..) |outcome, index| {
        var req = first;
        req.operation = index + 1;
        if (outcome != .name_conflict) req.name = try c.fuze.model.Name.init("other");
        if (outcome == .table_conflict) req.object = 1;
        turn = try store.capture(17);
        const receipt = try owner.createTable(&turn, req);
        try t.expectEqual(outcome, receipt.outcome);
        try t.expectEqual(1, count(&turn));
        try store.commit(turn);
        turn = try store.capture(17);
        try t.expect(std.meta.eql(receipt, try owner.createTable(&turn, req)));
        try t.expectEqual(0, count(&turn));
    }
    // Even an unrelated Table with exactly the requested schema is not adopted.
    turn = try store.capture(17);
    _ = try s.Table.create(&turn, 10, first.schema);
    try store.commit(turn);
    var req = first;
    req.operation = 99;
    req.object = 99;
    req.table = 10;
    req.name = try c.fuze.model.Name.init("other");
    turn = try store.capture(17);
    try t.expectEqual(.table_conflict, (try owner.createTable(&turn, req)).outcome);
}
test "creation refuses orphan Table rows and preserves incoming proposals and read poison" {
    var store: Store = .{};
    defer store.deinit();
    try ready(&store);
    var turn = try store.capture(17);
    try turn.put(try p.Value.init("existing"), try p.Value.init("kept"));
    const before = turn.decision;
    try t.expectError(error.QueryAfterMutation, owner.createTable(&turn, try request()));
    try t.expect(std.meta.eql(before, turn.decision));
    // Fail every point read, including the Table helper's recheck after admission.
    turn = try store.capture(17);
    store.reads = 0;
    _ = try owner.createTable(&turn, try request());
    const reads = store.reads;
    try t.expectEqual(7, reads);
    for (1..reads + 1) |fail_at| {
        turn = try store.capture(17);
        store.reads = 0;
        store.fail_at = fail_at;
        try t.expectError(error.Unavailable, owner.createTable(&turn, try request()));
        try t.expectEqual(0, count(&turn));
        try t.expectEqual(error.Unavailable, turn.read_error.?);
        try t.expectError(error.Unavailable, turn.validate());
    }
    store.fail_at = null;
    turn = try store.capture(17);
    store.fail_page = true;
    try t.expectError(error.Unavailable, owner.createTable(&turn, try request()));
    try t.expectEqual(0, count(&turn));
    try t.expectError(error.Unavailable, turn.validate());
    store.fail_page = false;
    const req = try request();
    const table: s.Table = .{ .resource = req.scope.resource, .id = req.table, .schema = req.schema };
    try store.state.put(t.allocator, s.Table.rowKey(req.table, std.math.minInt(i64)), try table.encodeCell(.null));
    turn = try store.capture(17);
    try t.expectError(error.CatalogSourceAlreadyPopulated, owner.createTable(&turn, req));
    try t.expectEqual(0, count(&turn));
    try t.expect(store.state.get(s.Table.descriptorKey(req.table)) == null);
    try t.expect(store.state.get(r.key(req.scope.catalog, 'o', 17, req.operation)) == null);
}
test "current catalog create and inspect policies are separate and conditional" {
    var store: Store = .{};
    defer store.deinit();
    try ready(&store);
    var turn = try store.capture(18);
    try t.expectError(error.CatalogDenied, owner.createTable(&turn, try request()));
    try t.expectError(error.CatalogDenied, owner.list(&turn, null));
    turn = try store.capture(17);
    var policy: m.Policy = .{ .scope = owner.configuration.scope, .principal = 18, .revision = 1, .inspect = false, .create = true };
    try owner.setPolicy(&turn, 0, policy);
    try store.commit(turn);
    turn = try store.capture(18);
    _ = try owner.createTable(&turn, try request());
    try t.expectError(error.CatalogDenied, owner.lookup(&turn, (try request()).name));
    try store.commit(turn);
    turn = try store.capture(17);
    try owner.setPolicy(&turn, 0, policy);
    try t.expectEqual(0, count(&turn));
    policy.revision = 2;
    policy.inspect = true;
    policy.create = false;
    try t.expectError(error.InvalidCatalogPolicy, owner.setPolicy(&turn, 0, policy));
    try owner.setPolicy(&turn, 1, policy);
    try store.commit(turn);
    turn = try store.capture(18);
    try t.expect((try owner.lookup(&turn, (try request()).name)) != null);
    try t.expect((try owner.receipt(&turn, (try request()).operation)) != null);
    try t.expectError(error.CatalogDenied, owner.createTable(&turn, try request()));
    try t.expectError(error.CatalogDenied, owner.setPolicy(&turn, 1, policy));
}
test "catalog pages grow independently of resident bounds and bind their source revision" {
    var store: Store = .{};
    defer store.deinit();
    try ready(&store);
    for (0..257) |index| {
        var text: [16]u8 = undefined;
        var req = try request();
        req.operation = index + 1;
        req.object = index + 1;
        req.table = @intCast(index + 1);
        req.name = try c.fuze.model.Name.init(try std.fmt.bufPrint(&text, "item_{d:0>3}", .{index}));
        var turn = try store.capture(17);
        _ = try owner.createTable(&turn, req);
        try store.commit(turn);
    }
    var total: usize = 0;
    store.pages = 0;
    var cursor: ?c.Catalog.Cursor = null;
    while (true) {
        var turn = try store.capture(17);
        const page = try owner.list(&turn, cursor);
        try t.expectEqual(store.revision, page.resource_revision);
        for (page.entries) |slot| if (slot) |entry| {
            total += 1;
            try t.expectEqual(total, entry.object);
        };
        cursor = page.next;
        if (cursor == null) break;
    }
    try t.expectEqual(257, total);
    try t.expectEqual(33, store.pages);
    var turn = try store.capture(17);
    const first = try owner.list(&turn, null);
    var stale = first.next.?;
    stale.resource_revision -= 1;
    try t.expectError(error.CatalogCursorChanged, owner.list(&turn, stale));
    try turn.put(try p.Value.init("private"), try p.Value.init("value"));
    try t.expectError(error.QueryAfterMutation, owner.list(&turn, first.next));
    turn = try store.capture(17);
    try owner.setPolicy(&turn, 1, .{ .scope = owner.configuration.scope, .principal = 17, .revision = 2, .inspect = false, .create = true });
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.list(&turn, first.next));
}
