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
    const pages_before = store.pages;
    const dependent = (try owner.blockingDependency(&turn, 17, 1)).?;
    try t.expectEqual(pages_before + 1, store.pages);
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

fn ddl(store: *TestStore, request: c.TableDdlRequest) !Cat.Outcome {
    for (0..2000) |_| {
        var turn = try store.capture(request.principal);
        const result = try owner.step(t.allocator, &turn, request);
        var lost = try store.capture(request.principal);
        const repeat = try owner.step(t.allocator, &lost, request);
        try t.expectEqualDeep(result, repeat);
        try t.expectEqualDeep(turn.decision, lost.decision);
        try store.commit(turn);
        if (result.terminal()) return result;
    }
    return error.TestUnexpectedResult;
}
fn createRequest(object: u64, operation: u64, name: []const u8) !c.TableDdlRequest {
    return .{ .principal = 17, .operation = operation, .object = object, .expected_revision = 0, .name = try Meta.Name.init(name), .action = .{ .create = .{ .schema = .{ .object = object, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int32 }, .{ .id = 2, .name = "name", .type = .utf8 } }, .primary_key = &.{} } } } };
}
fn countWrites(turn: s.Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
test "general DDL creates atomic names and schemas and retains exact outcomes" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const request = try createRequest(100, 1, "people");
    const applied = try ddl(&store, request);
    try t.expectEqual(.applied, applied.operation.state);
    var turn = try store.capture(17);
    var found = (try owner.lookup(t.allocator, &turn, 17, request.name)).?;
    defer found.deinit();
    try t.expectEqual(@as(u64, 100), found.schema.schema.object);
    try t.expectEqual(@as(u64, 0), found.head.rows);
    try t.expectEqual(@as(usize, 2), found.schema.schema.columns.len);
    try t.expectEqualDeep(found.metadata, try owner.historical(&turn, 17, 100, applied.operation.metadata));
    try t.expectEqualDeep(applied, try owner.step(t.allocator, &turn, request));
    try t.expectEqual(@as(usize, 0), countWrites(turn));
    var changed = request;
    changed.name = try Meta.Name.init("changed");
    try t.expectError(error.CatalogIdentityConflict, owner.step(t.allocator, &turn, changed));
    const duplicate = try ddl(&store, try createRequest(101, 2, "people"));
    try t.expectEqual(.name_conflict, duplicate.operation.reason);
    try t.expectEqual(@as(u64, 100), duplicate.operation.actual_object);
    var optional = try createRequest(102, 3, "people");
    optional.action.create.if_not_exists = true;
    try t.expectEqual(.unchanged, (try ddl(&store, optional)).operation.state);
    turn = try store.capture(17);
    try t.expectEqual(null, try turn.read(s.TableHead.key(101)));
    try t.expectEqual(null, try turn.read(s.TableHead.key(102)));
}
test "general DDL rename drop name reuse and history keep object identity" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try createRequest(10, 1, "people");
    const first = try ddl(&store, creation);
    const rename: c.TableDdlRequest = .{ .principal = 17, .operation = 2, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .rename = try Meta.Name.init("persons") } };
    const renamed = try ddl(&store, rename);
    try t.expectEqual(.applied, renamed.operation.state);
    try t.expectEqual(@as(u64, 2), renamed.operation.metadata.id);
    var turn = try store.capture(17);
    try t.expectEqual(null, try owner.lookup(t.allocator, &turn, 17, creation.name));
    var pinned = (try owner.lookup(t.allocator, &turn, 17, rename.action.rename)).?;
    defer pinned.deinit();
    const dependency: m.Dependency = .{ .scope = owner.configuration.scope, .object = 10, .identity = 1, .owner = 4, .kind = .writer };
    try owner.setDependency(&turn, dependency, true);
    try store.commit(turn);
    var drop: c.TableDdlRequest = .{ .principal = 17, .operation = 3, .object = 10, .expected_revision = 2, .name = rename.action.rename, .action = .{ .drop = .{} } };
    try t.expectEqual(.dependency, (try ddl(&store, drop)).operation.reason);
    turn = try store.capture(17);
    try owner.setDependency(&turn, dependency, false);
    try store.commit(turn);
    drop.operation = 4;
    const dropped = try ddl(&store, drop);
    try t.expectEqual(.applied, dropped.operation.state);
    turn = try store.capture(17);
    try t.expectEqual(null, try owner.lookup(t.allocator, &turn, 17, drop.name));
    try t.expect((try s.TableHead.load(&turn, 10)).retired);
    try t.expectEqualDeep(first, try owner.step(t.allocator, &turn, creation));
    const old = try owner.historical(&turn, 17, 10, first.operation.metadata);
    try t.expect(old.name.eql(&creation.name));
    const reused = try ddl(&store, try createRequest(11, 5, "persons"));
    try t.expectEqual(.applied, reused.operation.state);
    const stolen = try ddl(&store, try createRequest(10, 6, "another"));
    try t.expectEqual(.object_conflict, stolen.operation.reason);
    turn = try store.capture(17);
    var old_schema = try pinned.head.readSchema(t.allocator, &turn);
    defer old_schema.deinit();
    try t.expectEqual(@as(u64, 10), old_schema.schema.object);
    try t.expectEqualDeep(dropped, try owner.step(t.allocator, &turn, drop));
}
test "general catalog ALTER publishes its schema and metadata in the same decision" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try createRequest(10, 1, "people");
    const initial = try ddl(&store, creation);
    const request: c.TableDdlRequest = .{ .principal = 17, .operation = 2, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .alter = .{ .schema = creation.action.create.schema, .change = .{ .rename = .{ .column = 2, .name = "full_name" } } } } };
    var terminal: ?Cat.Outcome = null;
    for (0..100) |_| {
        var turn = try store.capture(17);
        var before = (try owner.lookup(t.allocator, &turn, 17, creation.name)).?;
        defer before.deinit();
        try t.expectEqual(@as(u64, 1), before.metadata.revision);
        try t.expectEqualStrings("name", before.schema.schema.columns[1].name);
        const result = try owner.step(t.allocator, &turn, request);
        if (result.terminal()) {
            try t.expectEqual(@as(usize, 4), countWrites(turn));
            terminal = result;
        }
        try store.commit(turn);
        if (terminal != null) break;
    }
    try t.expect(terminal != null);
    try t.expectEqual(.delegated, terminal.?.operation.state);
    try t.expectEqual(.applied, terminal.?.table.?.state);
    var turn = try store.capture(17);
    var after = (try owner.lookup(t.allocator, &turn, 17, creation.name)).?;
    defer after.deinit();
    try t.expectEqual(@as(u64, 2), after.metadata.revision);
    try t.expectEqualStrings("full_name", after.schema.schema.columns[1].name);
    try t.expectEqualDeep(terminal.?, try owner.step(t.allocator, &turn, request));
    try t.expectEqualDeep(after.metadata, try owner.historical(&turn, 17, 10, terminal.?.operation.metadata));
    _ = try owner.historical(&turn, 17, 10, initial.operation.metadata);
}

fn cancelAndClean(store: *TestStore, request: c.TableDdlRequest) !void {
    const digest = try request.digest(owner.configuration.scope);
    var closed: ?Cat.Outcome = null;
    for (0..10) |_| {
        var turn = try store.capture(request.principal);
        const result = try owner.cancel(&turn, request.principal, request.operation, digest);
        try store.commit(turn);
        if (result.terminal()) {
            closed = result;
            break;
        }
    }
    try t.expect(closed != null);
    try t.expect(if (closed.?.table) |value| value.state == .cancelled else closed.?.operation.state == .cancelled);
    for (0..100) |_| {
        var turn = try store.capture(request.principal);
        const finished = try owner.cleanup(&turn, request.principal, request.operation, digest);
        var lost = try store.capture(request.principal);
        try t.expectEqual(finished, try owner.cleanup(&lost, request.principal, request.operation, digest));
        try t.expectEqualDeep(turn.decision, lost.decision);
        try store.commit(turn);
        if (finished) {
            turn = try store.capture(request.principal);
            try t.expectEqualDeep(closed, try owner.status(&turn, request.principal, request.operation, digest));
            try t.expect(try owner.cleanup(&turn, request.principal, request.operation, digest));
            return;
        }
    }
    return error.TestUnexpectedResult;
}
test "cancel every CREATE phase reclaims only its candidate and never reuses an object" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const request = try createRequest(100, 1, "people_with_a_name_that_requires_chunked_metadata_even_without_a_large_schema");
    var stages: usize = 0;
    for (0..100) |_| {
        var turn = try store.capture(17);
        const result = try owner.step(t.allocator, &turn, request);
        try store.commit(turn);
        if (result.terminal()) break;
        stages += 1;
        var cancelled = try store.clone();
        defer cancelled.deinit();
        try cancelAndClean(&cancelled, request);
        var checked = try cancelled.capture(17);
        try t.expectEqual(null, try owner.lookup(t.allocator, &checked, 17, request.name));
        const replacement = try ddl(&cancelled, try createRequest(101, 2, request.name.slice()));
        try t.expectEqual(.applied, replacement.operation.state);
        const reused = try ddl(&cancelled, try createRequest(100, 3, "another"));
        try t.expectEqual(.object_conflict, reused.operation.reason);
    }
    try t.expect(stages > 6);
}
test "cancel every ALTER phase preserves its old schema and permits later evolution" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try createRequest(10, 1, "people_with_a_name_that_requires_chunked_metadata_even_without_a_large_schema");
    _ = try ddl(&store, creation);
    const request: c.TableDdlRequest = .{ .principal = 17, .operation = 2, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .alter = .{ .schema = creation.action.create.schema, .change = .{ .rename = .{ .column = 2, .name = "full_name" } } } } };
    var phases: usize = 0;
    for (0..100) |_| {
        var turn = try store.capture(17);
        const result = try owner.step(t.allocator, &turn, request);
        try store.commit(turn);
        if (result.terminal()) break;
        phases += 1;
        var cancelled = try store.clone();
        defer cancelled.deinit();
        try cancelAndClean(&cancelled, request);
        var checked = try cancelled.capture(17);
        var original = (try owner.lookup(t.allocator, &checked, 17, creation.name)).?;
        defer original.deinit();
        try t.expectEqualStrings("name", original.schema.schema.columns[1].name);
        var next = request;
        next.operation = 3;
        const applied = try ddl(&cancelled, next);
        try t.expectEqual(.applied, applied.table.?.state);
        try t.expectEqual(@as(u64, 3), applied.operation.metadata.id);
    }
    try t.expect(phases > 6);
}
test "DDL conflicts bind original names schemas and absent DROP without retargeting" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const absent: c.TableDdlRequest = .{ .principal = 17, .operation = 1, .object = 0, .expected_revision = 0, .name = try Meta.Name.init("later"), .action = .{ .drop = .{ .if_exists = true } } };
    const no_op = try ddl(&store, absent);
    try t.expectEqual(.unchanged, no_op.operation.state);
    _ = try ddl(&store, try createRequest(10, 2, "later"));
    var turn = try store.capture(17);
    try t.expectEqualDeep(no_op, try owner.step(t.allocator, &turn, absent));
    var late = absent;
    late.operation = 3;
    try t.expectEqual(.object_conflict, (try ddl(&store, late)).operation.reason);
    const stale: c.TableDdlRequest = .{ .principal = 17, .operation = 4, .object = 10, .expected_revision = 9, .name = absent.name, .action = .{ .drop = .{} } };
    try t.expectEqual(.schema_changed, (try ddl(&store, stale)).operation.reason);
    const request = try createRequest(11, 5, "competing");
    turn = try store.capture(17);
    _ = try owner.step(t.allocator, &turn, request);
    try store.commit(turn);
    _ = try ddl(&store, try createRequest(12, 6, "competing"));
    const lost = try ddl(&store, request);
    try t.expectEqual(.name_conflict, lost.operation.reason);
    turn = try store.capture(17);
    try t.expect(try owner.cleanup(&turn, 17, 5, try request.digest(owner.configuration.scope)));
    try store.commit(turn);
    turn = try store.capture(17);
    var winner = (try owner.lookup(t.allocator, &turn, 17, request.name)).?;
    defer winner.deinit();
    try t.expectEqual(@as(u64, 12), winner.head.object);
}

test "DDL rechecks current policy and preserves reservation when disclosure is revoked" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const request = try createRequest(100, 1, "people");
    var turn = try store.capture(17);
    _ = try owner.step(t.allocator, &turn, request);
    try store.commit(turn);
    turn = try store.capture(17);
    var rights = try m.Policy.administrator(owner.configuration.scope, 17);
    rights.revision = 2;
    rights.inspect = false;
    try owner.setPolicy(&turn, 1, rights);
    try store.commit(turn);
    turn = try store.capture(17);
    const digest = try request.digest(owner.configuration.scope);
    try t.expectError(error.CatalogDenied, owner.step(t.allocator, &turn, request));
    try t.expectError(error.CatalogDenied, owner.status(&turn, 17, 1, digest));
    try t.expectError(error.CatalogDenied, owner.cancel(&turn, 17, 1, digest));
    try t.expectError(error.CatalogDenied, owner.cleanup(&turn, 17, 1, digest));
    try t.expectEqual(@as(usize, 0), countWrites(turn));
    rights.inspect = true;
    rights.create = false;
    rights.revision = 3;
    try owner.setPolicy(&turn, 2, rights);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.step(t.allocator, &turn, request));
    try t.expect(!(try owner.status(&turn, 17, 1, digest)).?.terminal());
    // Inspect permits closing one's original work even after execution revocation.
    try cancelAndClean(&store, request);
    turn = try store.capture(18);
    try t.expectError(error.CatalogDenied, owner.cancel(&turn, 17, 1, digest));
}
test "ALTER validates populated rows atomically and keeps rejected metadata private" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try createRequest(10, 1, "people");
    _ = try ddl(&store, creation);
    var turn = try store.capture(17);
    const insert: s.TableWrite.Request = .{ .resource = 7, .principal = 17, .operation = 2, .schema = creation.action.create.schema, .change = .{ .insert = .{ .identity = .{ .origin = 18, .operation = 2, .ordinal = 0 }, .cells = &.{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .null } } } };
    for (0..100) |_| {
        turn = try store.capture(17);
        const result = try s.TableWrite.step(t.allocator, &turn, insert);
        try store.commit(turn);
        if (result.state != .building) break;
    }
    const request: c.TableDdlRequest = .{ .principal = 17, .operation = 3, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .alter = .{ .schema = creation.action.create.schema, .change = .{ .nullable = .{ .column = 2, .value = false } } } } };
    const rejected = try ddl(&store, request);
    try t.expectEqual(.rejected, rejected.table.?.state);
    try t.expectEqual(.null_not_allowed, rejected.table.?.rejection);
    turn = try store.capture(17);
    var old = (try owner.lookup(t.allocator, &turn, 17, creation.name)).?;
    defer old.deinit();
    try t.expectEqual(@as(u64, 1), old.head.rows);
    try t.expectEqual(@as(u64, 1), old.metadata.revision);
    try t.expectError(error.CatalogDefinitionMissing, owner.historical(&turn, 17, 10, rejected.operation.metadata));
    for (0..100) |_| {
        turn = try store.capture(17);
        const complete = try owner.cleanup(&turn, 17, 3, rejected.operation.digest);
        try store.commit(turn);
        if (complete) break;
    }
    var next = request;
    next.operation = 4;
    next.action.alter.change = .{ .add = .{ .name = "active", .type = .boolean, .nullable = false, .default = .{ .value = .{ .atom = .{ .boolean = true } } } } };
    const applied = try ddl(&store, next);
    try t.expectEqual(.applied, applied.table.?.state);
    turn = try store.capture(17);
    var found = (try owner.lookup(t.allocator, &turn, 17, creation.name)).?;
    defer found.deinit();
    const pages: s.TablePages = .{ .resource = 7, .object = 10 };
    var reader: s.TablePages.Reader(*s.Turn) = .{ .pages = pages, .source = &turn };
    const data: s.TableData = .{ .schema = found.schema.schema, .index = found.head.index };
    var row = (try data.next(t.allocator, &reader, null)).?;
    defer row.deinit();
    try t.expect(row.row().cells[2].value.atom.boolean);
    try t.expectEqualDeep(insert.change.insert.identity, row.identity);
}

fn dml(store: *TestStore, request: c.TableDmlRequest) !s.TableWrite.Status {
    for (0..2000) |_| {
        var turn = try store.capture(request.principal);
        const result = try owner.mutate(t.allocator, &turn, request);
        var lost = try store.capture(request.principal);
        try t.expectEqualDeep(result, try owner.mutate(t.allocator, &lost, request));
        try t.expectEqualDeep(turn.decision, lost.decision);
        try store.commit(turn);
        if (result.state != .building) return result;
    }
    return error.TestUnexpectedResult;
}
fn keyedCreate() !c.TableDdlRequest {
    var request = try createRequest(10, 1, "people");
    request.action.create.schema.columns = &.{ .{ .id = 1, .name = "id", .type = .int32, .nullable = false }, .{ .id = 2, .name = "name", .type = .utf8 } };
    request.action.create.schema.primary_key = &.{1};
    return request;
}
test "catalog routes point and finite DML with exact counts and original post-drop receipts" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try keyedCreate();
    const created = try ddl(&store, creation);
    var insert = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO people VALUES (1, 'Ada')", "people", creation.action.create.schema, null);
    defer insert.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = created.operation.metadata, .plan = insert.plan };
    var scratch: [c.fuze.TableSchema.max_columns]c.fuze.Types.Values.Cell = undefined;
    try t.expectEqual(.point, std.meta.activeTag(try request.route(t.allocator, owner.configuration.scope, &scratch)));
    var turn = try store.capture(17);
    const accepted = try owner.mutate(t.allocator, &turn, request);
    try t.expectEqual(.applied, accepted.state);
    try t.expectEqual(@as(usize, 4), countWrites(turn));
    try t.expectEqual(@as(u64, 1), accepted.matched);
    try t.expectEqual(@as(u64, 1), accepted.changed);
    try store.commit(turn);
    var update = try c.fuze.TableDml.compile(t.allocator, "UPDATE people SET name = 'Ada' WHERE id = 1", "people", creation.action.create.schema, null);
    defer update.deinit();
    const patch: c.TableDmlRequest = .{ .principal = 17, .operation = 3, .metadata = created.operation.metadata, .plan = update.plan };
    try t.expectEqual(.point, std.meta.activeTag(try patch.route(t.allocator, owner.configuration.scope, &scratch)));
    const unchanged = try dml(&store, patch);
    try t.expectEqual(@as(u64, 1), unchanged.matched);
    try t.expectEqual(@as(u64, 0), unchanged.changed);
    var many = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO people VALUES (2, 'B'), (3, 'C')", "people", creation.action.create.schema, null);
    defer many.deinit();
    const batch: c.TableDmlRequest = .{ .principal = 17, .operation = 4, .metadata = created.operation.metadata, .plan = many.plan };
    try t.expectEqual(.finite, std.meta.activeTag(try batch.route(t.allocator, owner.configuration.scope, &scratch)));
    const inserted = try dml(&store, batch);
    try t.expectEqual(@as(u64, 2), inserted.changed);
    var filtered = try c.fuze.TableDml.compile(t.allocator, "DELETE FROM people WHERE id = 2 AND name = 'different'", "people", creation.action.create.schema, null);
    defer filtered.deinit();
    const remove: c.TableDmlRequest = .{ .principal = 17, .operation = 5, .metadata = created.operation.metadata, .plan = filtered.plan };
    try t.expectEqual(.finite, std.meta.activeTag(try remove.route(t.allocator, owner.configuration.scope, &scratch)));
    try t.expectEqual(@as(u64, 0), (try dml(&store, remove)).matched);
    _ = try ddl(&store, .{ .principal = 17, .operation = 6, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .drop = .{} } });
    _ = try ddl(&store, try createRequest(11, 7, "people"));
    turn = try store.capture(17);
    try t.expectEqualDeep(accepted, try owner.mutate(t.allocator, &turn, request));
    try t.expectEqualDeep(accepted, (try owner.mutationStatus(t.allocator, &turn, 17, request)).?);
    var fresh = request;
    fresh.operation = 8;
    try t.expectError(error.TableRetired, owner.mutate(t.allocator, &turn, fresh));
    var changed = request;
    changed.metadata.id += 1;
    try t.expectError(error.TableWriteIdentityConflict, owner.mutate(t.allocator, &turn, changed));
}
test "catalog fences new DML during DDL and DDL during finite DML" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try keyedCreate();
    const created = try ddl(&store, creation);
    var plan = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO people VALUES (1, 'A'), (2, 'B')", "people", creation.action.create.schema, null);
    defer plan.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = created.operation.metadata, .plan = plan.plan };
    var turn = try store.capture(17);
    try t.expectEqual(.building, (try owner.mutate(t.allocator, &turn, request)).state);
    try store.commit(turn);
    const rename: c.TableDdlRequest = .{ .principal = 17, .operation = 3, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .rename = try Meta.Name.init("persons") } };
    turn = try store.capture(17);
    try t.expectError(error.TableBusy, owner.step(t.allocator, &turn, rename));
    _ = try owner.cancelMutation(t.allocator, &turn, request);
    try store.commit(turn);
    turn = try store.capture(17);
    _ = try owner.step(t.allocator, &turn, rename);
    try store.commit(turn);
    var later = request;
    later.operation = 4;
    turn = try store.capture(17);
    try t.expectError(error.TableBusy, owner.mutate(t.allocator, &turn, later));
    var observed = try owner.readDefinition(t.allocator, &turn, 17, 10, created.operation.metadata);
    defer observed.deinit();
    try t.expectEqual(@as(u64, 0), observed.head.rows);
    _ = try ddl(&store, rename);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDefinitionChanged, owner.mutate(t.allocator, &turn, later));
    try t.expectEqual(.cancelled, (try owner.mutationStatus(t.allocator, &turn, 17, request)).?.state);
    for (0..100) |_| {
        turn = try store.capture(17);
        const done = try owner.cleanupMutation(t.allocator, &turn, request);
        try store.commit(turn);
        if (done) return;
    }
    return error.TestUnexpectedResult;
}

test "catalog data policy separates inspection execution and receipt cancellation" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try keyedCreate();
    const created = try ddl(&store, creation);
    var plan = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO people VALUES (1, 'A'), (2, 'B')", "people", creation.action.create.schema, null);
    defer plan.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = created.operation.metadata, .plan = plan.plan };
    var turn = try store.capture(17);
    _ = try owner.mutate(t.allocator, &turn, request);
    try store.commit(turn);
    var rights = try m.Policy.administrator(owner.configuration.scope, 17);
    rights.revision = 2;
    rights.insert = false;
    rights.read = false;
    turn = try store.capture(17);
    try owner.setPolicy(&turn, 1, rights);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.mutate(t.allocator, &turn, request));
    try t.expectError(error.CatalogDenied, owner.readDefinition(t.allocator, &turn, 17, 10, request.metadata));
    try t.expectEqual(.building, (try owner.mutationStatus(t.allocator, &turn, 17, request)).?.state);
    try t.expectEqual(.cancelled, (try owner.cancelMutation(t.allocator, &turn, request)).state);
    try store.commit(turn);
    turn = try store.capture(17);
    rights.revision = 3;
    rights.inspect = false;
    try owner.setPolicy(&turn, 2, rights);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.mutationStatus(t.allocator, &turn, 17, request));
    try t.expectError(error.CatalogDenied, owner.cancelMutation(t.allocator, &turn, request));
    try t.expectError(error.CatalogDenied, owner.cleanupMutation(t.allocator, &turn, request));
    try t.expectEqual(@as(usize, 0), countWrites(turn));
    var other = owner;
    other.configuration.scope.catalog = 2;
    try other.initialize(&turn);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.TableNotFound, other.mutationStatus(t.allocator, &turn, 17, request));
    turn = try store.capture(18);
    try t.expectError(error.CatalogDenied, owner.mutate(t.allocator, &turn, request));
}
