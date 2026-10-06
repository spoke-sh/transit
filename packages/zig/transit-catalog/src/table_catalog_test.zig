const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const Cat = c.TableCatalog;
const m = c.TableCatalogRecords;
const Meta = c.TableMetadata;
const Records = c.TableMetadataStore;
const TestStore = @import("TestStore.zig");
const r = c.Records;
const p = c.protocol;
const s = c.station;
const owner: Cat = .{ .configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .administrator = 17, .table_limits = .{ .record_bytes = c.fuze.TableRow.max_bytes, .staging_bytes = c.fuze.TableRow.max_bytes * 2, .staging_records = 2 } } };
fn ready(store: *TestStore) !void {
    var turn = try store.capture(17);
    try owner.initialize(&turn);
    try store.commit(turn);
}
// Construct committed object fixtures explicitly. This is not CREATE admission
// evidence; the namespace reader must validate these independently staged parts.
fn install(store: *TestStore, object: u64, name: Meta.Name) !void {
    const schema: c.fuze.TableSchema.Schema = .{ .object = object, .revision = 1, .next_column = 3, .columns = &.{
        .{ .id = 1, .name = "id", .type = .int32 },
        .{ .id = 2, .name = "name", .type = .utf8 },
    }, .primary_key = &.{} };
    var turn = try store.capture(17);
    const pages = try s.TablePages.create(&turn, object, owner.configuration.table_limits);
    try store.commit(turn);
    var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    const encoded = try schema.encode(&bytes);
    const schema_ref: s.TablePages.Reference = .{ .id = 1, .spec = try s.Publication.Digest.of(s.TablePages.schema_format, encoded) };
    for (0..100) |_| {
        turn = try store.capture(17);
        const result = try pages.stage(&turn, schema_ref, encoded);
        try store.commit(turn);
        if (result == .ready) break;
    }
    const records: Records = .{ .scope = owner.configuration.scope, .object = object };
    turn = try store.capture(17);
    try records.create(&turn);
    try store.commit(turn);
    const metadata: Meta.Record = .{ .scope = owner.configuration.scope, .object = object, .revision = 1, .name = name, .schema = schema_ref, .schema_fingerprint = try schema.fingerprint(), .principal = 17, .operation = object, .admitted_input = 1 };
    for (0..100) |_| {
        turn = try store.capture(17);
        const result = try records.stage(&turn, metadata);
        try store.commit(turn);
        if (result == .ready) break;
    }
    turn = try store.capture(17);
    const head: s.TableHead = .{ .resource = owner.configuration.scope.resource, .object = object, .revision = 1, .schema = schema_ref, .next_record = 2 };
    try head.create(t.allocator, &turn);
    const current: m.Object = .{ .scope = owner.configuration.scope, .object = object, .state = .live, .metadata = .{ .id = 1, .spec = try metadata.spec() }, .next_revision = 2 };
    try turn.write(owner.key('O', object, 0), try r.encode('O', current));
    try turn.write(try Meta.nameKey(owner.configuration.scope.catalog, try name.digest(), object), try r.encode('N', m.Binding{ .scope = owner.configuration.scope, .object = object }));
    try store.commit(turn);
}
test "general namespace policy separates metadata data and schema rights and preserves restoration" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    var turn = try store.capture(17);
    try owner.initialize(&turn);
    var rights = try m.Policy.administrator(owner.configuration.scope, 18);
    rights.create = false;
    rights.read = false;
    rights.insert = false;
    rights.update = false;
    rights.delete = false;
    rights.alter = false;
    rights.drop = false;
    try owner.setPolicy(&turn, 0, rights);
    try store.commit(turn);
    turn = try store.capture(18);
    _ = try owner.authorize(&turn, 18, .inspect);
    inline for (.{ .create, .read, .insert, .update, .delete, .alter, .drop }) |right| try t.expectError(error.CatalogDenied, owner.authorize(&turn, 18, right));
    try t.expectError(error.CatalogDenied, owner.setPolicy(&turn, 1, rights));
    turn = try store.capture(17);
    var administrator = try m.Policy.administrator(owner.configuration.scope, 17);
    administrator.revision = 2;
    administrator.inspect = false;
    administrator.alter = false;
    try owner.setPolicy(&turn, 1, administrator);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.list(t.allocator, &turn, 17, .{ .scope = owner.configuration.scope, .resource_revision = 0, .after_object = 0 }));
    administrator.revision = 3;
    administrator.inspect = true;
    try owner.setPolicy(&turn, 2, administrator);
    try store.commit(turn);
    turn = try store.capture(17);
    _ = try owner.authorize(&turn, 17, .inspect);
    try t.expectError(error.CatalogDenied, owner.authorize(&turn, 17, .alter));
    try owner.initialize(&turn);
    try t.expectError(error.CatalogDenied, owner.authorize(&turn, 17, .alter));
}
test "general namespace resolves full names and pages stable objects beyond one resident page" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    for (1..21) |id| {
        var name: [64]u8 = undefined;
        try install(&store, id, try Meta.Name.init(try std.fmt.bufPrint(&name, "people-{d}", .{id})));
    }
    var turn = try store.capture(17);
    var found = (try owner.lookup(t.allocator, &turn, 17, try Meta.Name.init("people-12"))).?;
    defer found.deinit();
    try t.expectEqual(@as(u64, 12), found.metadata.object);
    try t.expectEqual(@as(usize, 2), found.schema.schema.columns.len);
    try t.expect(found.schema.schema.columns[0].nullable);
    try t.expectEqual(null, try owner.lookup(t.allocator, &turn, 17, try Meta.Name.init("People-12")));
    var cursor: ?Cat.Cursor = null;
    var count: u64 = 0;
    while (true) {
        var page = try owner.list(t.allocator, &turn, 17, cursor);
        defer page.deinit();
        for (page.entries) |slot| if (slot) |entry| {
            count += 1;
            try t.expectEqual(count, entry.metadata.object);
        };
        cursor = page.next orelse break;
    }
    try t.expectEqual(@as(u64, 20), count);
    var first = try owner.list(t.allocator, &turn, 17, null);
    defer first.deinit();
    try install(&store, 30, try Meta.Name.init("later"));
    turn = try store.capture(17);
    try t.expectError(error.CatalogCursorChanged, owner.list(t.allocator, &turn, 17, first.next));
}
test "general namespace refuses stale heads wrong bindings orphan state and corrupt pages" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const name = try Meta.Name.init("people");
    try install(&store, 1, name);
    try install(&store, 2, try Meta.Name.init("other"));
    const binding = try Meta.nameKey(owner.configuration.scope.catalog, try name.digest(), 1);
    const saved = store.state.get(binding).?;
    try store.state.put(t.allocator, binding, try r.encode('N', m.Binding{ .scope = owner.configuration.scope, .object = 2 }));
    var turn = try store.capture(17);
    try t.expectError(error.InvalidCatalogBinding, owner.lookup(t.allocator, &turn, 17, name));
    try store.state.put(t.allocator, binding, saved);
    turn = try store.capture(17);
    const before = try s.TableHead.load(&turn, 1);
    var retired = before;
    retired.revision += 1;
    retired.retired = true;
    try before.replace(&turn, retired);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogSourceChanged, owner.lookup(t.allocator, &turn, 17, name));
    inline for (.{ .gap, .next, .revision, .order }) |failure| {
        store.bad_page = failure;
        try t.expectError(error.InvalidCatalogPage, owner.list(t.allocator, &turn, 17, null));
    }
    store.bad_page = .none;
    store.fail_at = store.reads + 1;
    try t.expectError(error.Unavailable, owner.lookup(t.allocator, &turn, 17, name));
    try t.expectError(error.Unavailable, turn.validate());
    store.fail_at = null;
    _ = store.state.remove(owner.key('c', 0, 0));
    turn = try store.capture(17);
    try t.expectError(error.CatalogAlreadyPopulated, owner.initialize(&turn));
}
test "durable dependencies block RESTRICT while history references remain distinct" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    try install(&store, 1, try Meta.Name.init("people"));
    for (1..12) |id| {
        var turn = try store.capture(17);
        try owner.setDependency(&turn, .{ .scope = owner.configuration.scope, .object = 1, .identity = id, .owner = 4, .kind = if (id == 11) .query_source else .history }, true);
        try store.commit(turn);
    }
    var turn = try store.capture(17);
    const dependent = (try owner.blockingDependency(&turn, 17, 1)).?;
    try t.expectEqual(@as(u64, 11), dependent.identity);
    try t.expectEqual(.query_source, dependent.kind);
    var changed = dependent;
    changed.owner = 5;
    try t.expectError(error.CatalogDependencyConflict, owner.setDependency(&turn, changed, false));
    try owner.setDependency(&turn, dependent, false);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectEqual(null, try owner.blockingDependency(&turn, 17, 1));
    try t.expect(store.state.get(owner.key('B', 1, 1)) != null);
}
