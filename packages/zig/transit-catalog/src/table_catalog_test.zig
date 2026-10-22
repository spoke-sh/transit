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
const owner: Cat = .{ .configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .administrator = 17, .database_name = c.TableAuthority.Name.init("test") catch unreachable, .authority = @import("TestStore.zig").profile, .table_limits = .{ .record_bytes = c.fuze.TableRow.max_bytes, .staging_bytes = c.fuze.TableRow.max_bytes * 2, .staging_records = 2 } } };
fn ready(store: *TestStore) !void {
    var turn = try store.capture(17);
    try owner.initialize(&turn);
    try store.commit(turn);
}
test "root can be an explicit Table administrator but has no implicit catalog rights" {
    var ordinary: TestStore = .{};
    defer ordinary.deinit();
    try ready(&ordinary);
    var turn = try ordinary.capture(0);
    try t.expectError(error.CatalogDenied, owner.authorize(&turn, 0, .inspect));

    var root = owner;
    root.configuration.administrator = 0;
    try root.configuration.validate();
    var invalid = root.configuration;
    invalid.owner = 0;
    try t.expectError(error.InvalidCatalogIdentity, invalid.validate());
    invalid = root.configuration;
    invalid.administrator = p.max_counter + 1;
    try t.expectError(error.InvalidCatalogIdentity, invalid.validate());
    var store: TestStore = .{};
    defer store.deinit();
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, root.initialize(&turn));
    turn = try store.capture(0);
    try root.initialize(&turn);
    try store.commit(turn);
    var request = try createRequest(10, 1, "root_table");
    request.principal = 0;
    var applied = false;
    for (0..100) |_| {
        turn = try store.capture(0);
        const result = try root.step(t.allocator, &turn, request);
        try store.commit(turn);
        if (result.terminal()) {
            try t.expectEqual(.applied, result.operation.state);
            applied = true;
            break;
        }
    }
    try t.expect(applied);
    turn = try store.capture(0);
    var found = (try root.lookup(t.allocator, &turn, 0, request.name)).?;
    defer found.deinit();
    try t.expectEqual(@as(u64, 0), found.metadata.principal);
    var revoked = try @import("TestStore.zig").Rights.administrator(root.configuration.scope, 0);
    revoked.revision = 2;
    revoked.read = false;
    try store.setRights(revoked);
    try store.commit(turn);
    turn = try store.capture(0);
    try root.initialize(&turn);
    try t.expectEqual(@as(usize, 0), countWrites(turn));
    try t.expectError(error.CatalogDenied, root.authorizeObject(&turn, 0, request.object, .read));
}
test "read-definition mismatch evidence is copied only after current inspect and read authorization" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    try install(&store, 10, try Meta.Name.init("people"));
    var turn = try store.capture(17);
    var found = (try owner.lookup(t.allocator, &turn, 17, try Meta.Name.init("people"))).?;
    defer found.deinit();
    const actual: s.TablePages.Reference = .{ .id = found.metadata.revision, .spec = try found.metadata.spec() };
    var expected = actual;
    expected.id += 1;
    expected.spec.digest[0] ^= 1;
    var evidence: ?Cat.DefinitionMismatch = null;
    try t.expectError(error.CatalogDefinitionChanged, owner.readDefinitionDiagnostic(t.allocator, &turn, 17, 10, expected, &evidence));
    try t.expectEqualDeep(Cat.DefinitionMismatch{ .expected = expected, .actual = actual }, evidence.?);
    var current = try owner.readDefinitionDiagnostic(t.allocator, &turn, 17, 10, actual, &evidence);
    defer current.deinit();
    try t.expect(evidence == null);
    var revoked = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
    revoked.revision = 2;
    revoked.read = false;
    try store.setRights(revoked);
    try store.commit(turn);
    turn = try store.capture(17);
    evidence = .{ .expected = expected, .actual = actual };
    try t.expectError(error.CatalogDenied, owner.readDefinitionDiagnostic(t.allocator, &turn, 17, 10, expected, &evidence));
    try t.expect(evidence == null);
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
    const current: m.Object = .{ .scope = owner.configuration.scope, .object = object, .namespace = 1, .authorization = 100, .state = .live, .metadata = .{ .id = 1, .spec = try metadata.spec() }, .next_revision = 2 };
    try turn.write(owner.key('O', object, 0), try r.encode('O', current));
    try turn.write(try Meta.nameKey(owner.configuration.scope.catalog, try name.digest(), object), try r.encode('N', m.Binding{ .scope = owner.configuration.scope, .object = object }));
    try store.commit(turn);
}
test "namespace usage does not grant Table data or ownership rights" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    _ = try ddl(&store, try createRequest(10, 1, "rights"));
    var turn = try store.capture(17);
    try owner.initialize(&turn);
    var rights = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 18);
    rights.create = false;
    rights.read = false;
    rights.insert = false;
    rights.update = false;
    rights.delete = false;
    rights.alter = false;
    rights.drop = false;
    try store.setRights(rights);
    try store.commit(turn);
    turn = try store.capture(18);
    _ = try owner.authorize(&turn, 18, .inspect);
    try t.expectError(error.CatalogDenied, owner.authorize(&turn, 18, .create));
    inline for (.{ .read, .insert, .update, .delete, .alter, .drop }) |right| try t.expectError(error.CatalogDenied, owner.authorizeObject(&turn, 18, 10, right));
    turn = try store.capture(17);
    var administrator = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
    administrator.revision = 2;
    administrator.inspect = false;
    administrator.alter = false;
    try store.setRights(administrator);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.list(&turn, 17, .{ .scope = owner.configuration.scope, .resource_revision = 0, .after_object = 0 }));
    administrator.revision = 3;
    administrator.inspect = true;
    try store.setRights(administrator);
    try store.commit(turn);
    turn = try store.capture(17);
    _ = try owner.authorize(&turn, 17, .inspect);
    try t.expectError(error.CatalogDenied, owner.authorizeObject(&turn, 17, 10, .alter));
    try owner.initialize(&turn);
    try t.expectError(error.CatalogDenied, owner.authorizeObject(&turn, 17, 10, .alter));
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
        const page = try owner.list(&turn, 17, cursor);
        for (page.entries) |slot| if (slot) |entry| {
            count += 1;
            try t.expectEqual(count, entry.metadata.object);
        };
        cursor = page.next orelse break;
    }
    try t.expectEqual(@as(u64, 20), count);
    const first = try owner.list(&turn, 17, null);
    try install(&store, 30, try Meta.Name.init("later"));
    turn = try store.capture(17);
    try t.expectError(error.CatalogCursorChanged, owner.list(&turn, 17, first.next));
}
test "listing validates live identity without acquiring schema or row bytes" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    try install(&store, 1, try Meta.Name.init("people"));
    var turn = try store.capture(17);
    const head = try s.TableHead.load(&turn, 1);
    const Source = struct {
        turn: *s.Turn,
        view: p.Growth.View,
        blocked: p.Value,
        pub fn authorizationSubject(self: *@This(), who: u64) !p.Authorization.Subject {
            return self.turn.authorizationSubject(who);
        }
        pub fn requireAuthorization(self: *@This(), guard: p.Authorization.Guard) !p.Authorization.Verified {
            return self.turn.requireAuthorization(guard);
        }
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            if (key.eql(self.blocked)) return error.Unavailable;
            return self.turn.read(key);
        }
        pub fn readBlock(self: *@This(), key: p.Value, output: []u8) !?[]const u8 {
            if (key.eql(self.blocked)) return error.Unavailable;
            return self.turn.readBlock(key, output);
        }
        pub fn page(self: *@This(), after: p.Value) !s.Turn.Page {
            return self.turn.page(after);
        }
    };
    var source: Source = .{ .turn = &turn, .view = turn.view, .blocked = s.TablePages.key(1, 'c', head.schema.id) };
    const listed = try owner.list(&source, 17, null);
    try t.expectEqualStrings("people", listed.entries[0].?.metadata.name.slice());
    try t.expectEqualDeep(head, listed.entries[0].?.head);
    try t.expectEqual(null, listed.next);
    try t.expectError(error.Unavailable, owner.lookup(t.allocator, &source, 17, try Meta.Name.init("people")));
    // Metadata still cannot describe a retired or mismatched live head.
    var retired = head;
    retired.retired = true;
    retired.revision += 1;
    try head.replace(&turn, retired);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogSourceChanged, owner.list(&turn, 17, null));
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
        try t.expectError(error.InvalidCatalogPage, owner.list(&turn, 17, null));
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

test "DROP retains the exact blocking dependency after removal replacement and name reuse" {
    inline for (.{ .query_source, .writer, .watch, .maintained_relation }) |kind| {
        var store: TestStore = .{};
        defer store.deinit();
        try ready(&store);
        const creation = try createRequest(10, 1, "people");
        _ = try ddl(&store, creation);
        const request: c.TableDdlRequest = .{ .principal = 17, .operation = 2, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .drop = .{} } };
        var turn = try store.capture(17);
        const dependency: m.Dependency = .{ .scope = owner.configuration.scope, .object = 10, .identity = std.math.maxInt(u64), .owner = 4, .kind = kind };
        try owner.setDependency(&turn, dependency, true);
        try store.commit(turn);
        const rejected = try ddl(&store, request);
        try t.expectEqual(.rejected, rejected.operation.state);
        try t.expectEqual(.dependency, rejected.operation.reason);
        const blocker = rejected.operation.blocker.dependency;
        try t.expectEqual(dependency.identity, blocker.identity);
        try t.expectEqual(dependency.owner, blocker.owner);
        try t.expectEqual(dependency.kind, blocker.kind);
        const encoded = try r.encode('R', rejected.operation);
        try t.expectEqual(@as(usize, 250), encoded.len);
        try t.expectEqualDeep(rejected.operation, try r.decode(m.Operation, 'R', encoded));
        var invalid = rejected.operation;
        invalid.blocker = .none;
        try t.expectError(error.InvalidCatalogReceipt, invalid.validate());
        invalid = rejected.operation;
        invalid.blocker.dependency.kind = .history;
        try t.expectError(error.InvalidCatalogReceipt, invalid.validate());
        invalid = rejected.operation;
        invalid.reason = .schema_changed;
        try t.expectError(error.InvalidCatalogReceipt, invalid.validate());
        turn = try store.capture(17);
        var resolved = (try owner.lookup(t.allocator, &turn, 17, request.name)).?;
        defer resolved.deinit();
        var intent = try c.TableIntent.create(t.allocator, try c.TableCommand.fromDdl(owner.configuration.scope, owner.configuration.owner, request, resolved.metadata), 1000);
        defer intent.deinit();
        const detail = try c.TableDiagnostic.status(&intent, .{ .ddl = rejected });
        try t.expectEqual(dependency.identity, try (try diagnosticFact(detail, .dependency)).value.?.unsigned.value());
        try t.expectEqualStrings(@tagName(kind), (try diagnosticFact(detail, .dependency_kind)).value.?.text.slice());
        try t.expectEqual(dependency.owner, try (try diagnosticFact(detail, .dependency_owner)).value.?.unsigned.value());
        turn = try store.capture(17);
        try owner.setDependency(&turn, dependency, false);
        try store.commit(turn);
        var replacement = dependency;
        replacement.owner = 5;
        replacement.kind = .watch;
        turn = try store.capture(17);
        try owner.setDependency(&turn, replacement, true);
        try store.commit(turn);
        turn = try store.capture(17);
        try t.expectEqualDeep(rejected, (try owner.status(&turn, 17, 2, rejected.operation.digest)).?);
        try owner.setDependency(&turn, replacement, false);
        try store.commit(turn);
        var next = request;
        next.operation = 3;
        try t.expectEqual(.applied, (try ddl(&store, next)).operation.state);
        _ = try ddl(&store, try createRequest(11, 4, "people"));
        turn = try store.capture(17);
        const retained = (try owner.status(&turn, 17, 2, rejected.operation.digest)).?;
        try t.expectEqualDeep(rejected, retained);
        try t.expectEqualDeep(detail, try c.TableDiagnostic.status(&intent, .{ .ddl = retained }));
        try t.expectEqualDeep(rejected, try owner.step(t.allocator, &turn, request));
        try t.expectEqual(@as(usize, 0), countWrites(turn));
        var rights = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
        rights.inspect = false;
        rights.revision = 2;
        try store.setRights(rights);
        try store.commit(turn);
        turn = try store.capture(17);
        try t.expectError(error.CatalogDenied, owner.status(&turn, 17, 2, rejected.operation.digest));
        rights.inspect = true;
        rights.revision = 3;
        try store.setRights(rights);
        try store.commit(turn);
        turn = try store.capture(17);
        try t.expectEqualDeep(rejected, (try owner.status(&turn, 17, 2, rejected.operation.digest)).?);
    }
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
        try t.expectEqual(null, try owner.definition(t.allocator, &turn, 17, 10, 2));
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
    // Every surviving committed phase was independently cancelled and cleaned.
    try t.expect(stages > 0 and stages <= 6);
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
    // Six existing preparation cuts plus the immutable predecessor staging cut.
    // Every one is independently cancelled, cleaned and followed by new DDL.
    try t.expectEqual(@as(usize, 6), phases);
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
    var rights = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
    rights.revision = 2;
    rights.inspect = false;
    try store.setRights(rights);
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
    try store.setRights(rights);
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
    try t.expectEqual(null, try owner.definition(t.allocator, &turn, 17, 10, rejected.operation.metadata.id));
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
fn diagnosticFact(value: p.Diagnostic, field: p.Diagnostic.Field) !p.Diagnostic.Fact {
    for (value.facts) |slot| if (slot) |fact| {
        if (fact.field == field) return fact;
    };
    return error.TestUnexpectedResult;
}
test "durable constraint witnesses preserve original intent and enforce current disclosure" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try keyedCreate();
    const created = try ddl(&store, creation);
    var turn = try store.capture(17);
    var basis = (try owner.lookup(t.allocator, &turn, 17, creation.name)).?;
    defer basis.deinit();
    var insert = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO people VALUES (1, 'Ada'), (2, NULL)", "people", creation.action.create.schema, null);
    defer insert.deinit();
    const initial: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = created.operation.metadata, .plan = insert.plan };
    _ = try dml(&store, initial);
    var update = try c.fuze.TableDml.compile(t.allocator, "UPDATE people SET id = 9", "people", creation.action.create.schema, null);
    defer update.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 3, .metadata = created.operation.metadata, .plan = update.plan };
    const rejected = try dml(&store, request);
    try t.expectEqual(.rejected, rejected.state);
    try t.expectEqual(.stored, rejected.witness.source);
    try t.expectEqualStrings("9", rejected.witness.text());
    try t.expectEqual(@as(u32, 1), rejected.witness.row.ordinal);
    var original = try c.TableIntent.create(t.allocator, try c.TableCommand.fromDml(owner.configuration.scope, 3, request, basis.metadata), 1000);
    defer original.deinit();
    const detail = try c.TableDiagnostic.status(&original, .{ .dml = rejected });
    try t.expectEqualStrings("id", (try diagnosticFact(detail, .column)).value.?.text.slice());
    try t.expectEqualStrings("9", (try diagnosticFact(detail, .key)).value.?.text.slice());
    const stored = store.state.get(rejected.reference.key()).?;

    const duplicate = try dml(&store, .{ .principal = 17, .operation = 4, .metadata = created.operation.metadata, .plan = insert.plan });
    try t.expectEqual(.input, duplicate.witness.source);
    var incoming = try c.TableIntent.create(t.allocator, try c.TableCommand.fromDml(owner.configuration.scope, 3, .{ .principal = 17, .operation = 4, .metadata = created.operation.metadata, .plan = insert.plan }, basis.metadata), 1001);
    defer incoming.deinit();
    const input_detail = try c.TableDiagnostic.status(&incoming, .{ .dml = duplicate });
    try t.expectEqualStrings("1", (try diagnosticFact(input_detail, .input_row)).value.?.unsigned.text.slice());
    var corrupt = duplicate;
    corrupt.witness.preview[0] = '8';
    try t.expectError(error.InvalidCatalogReceipt, c.TableDiagnostic.status(&incoming, .{ .dml = corrupt }));
    corrupt = duplicate;
    corrupt.witness.row.ordinal = 2;
    try t.expectError(error.InvalidCatalogReceipt, c.TableDiagnostic.status(&incoming, .{ .dml = corrupt }));

    const alter: c.TableDdlRequest = .{ .principal = 17, .operation = 5, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .alter = .{ .schema = creation.action.create.schema, .change = .{ .nullable = .{ .column = 2, .value = false } } } } };
    const failed = try ddl(&store, alter);
    try t.expectEqual(.null_not_allowed, failed.table.?.rejection);
    try t.expectEqual(@as(u64, 2), failed.table.?.witness.column);
    try t.expectEqualStrings("NULL", failed.table.?.witness.text());
    var evolution = try c.TableIntent.create(t.allocator, try c.TableCommand.fromDdl(owner.configuration.scope, 3, alter, basis.metadata), 1002);
    defer evolution.deinit();
    const alter_detail = try c.TableDiagnostic.status(&evolution, .{ .ddl = failed });
    try t.expectEqualStrings("name", (try diagnosticFact(alter_detail, .column)).value.?.text.slice());
    try t.expectEqualStrings("utf8", (try diagnosticFact(alter_detail, .expected_type)).value.?.text.slice());

    var rights = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
    rights.revision = 2;
    rights.read = false;
    turn = try store.capture(17);
    try store.setRights(rights);
    try store.commit(turn);
    turn = try store.capture(17);
    const hidden = (try owner.mutationReceipt(&turn, 17, rejected.reference)).?;
    try t.expectEqual(.withheld, hidden.witness.source);
    try t.expectEqualDeep(hidden, (try owner.mutationStatus(t.allocator, &turn, 17, request)).?);
    const hidden_detail = try c.TableDiagnostic.status(&original, .{ .dml = hidden });
    try t.expectEqual(.withheld, (try diagnosticFact(hidden_detail, .key)).availability);
    try t.expectEqual(.withheld, (try diagnosticFact(hidden_detail, .source_row)).availability);
    try t.expectEqualDeep(duplicate, (try owner.mutationReceipt(&turn, 17, duplicate.reference)).?);
    const hidden_alter = (try owner.status(&turn, 17, 5, failed.operation.digest)).?;
    try t.expectEqual(.withheld, hidden_alter.table.?.witness.source);
    try t.expectEqual(.withheld, (try diagnosticFact(try c.TableDiagnostic.status(&evolution, .{ .ddl = hidden_alter }), .supplied_value)).availability);
    try t.expectEqualDeep(stored, store.state.get(rejected.reference.key()).?);
    try t.expectError(error.InvalidTableWitness, hidden.encode());
    rights.revision = 3;
    rights.inspect = false;
    try store.setRights(rights);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.mutationReceipt(&turn, 17, duplicate.reference));
    rights.revision = 4;
    rights.inspect = true;
    rights.read = true;
    try store.setRights(rights);
    try store.commit(turn);
    _ = try ddl(&store, .{ .principal = 17, .operation = 6, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .drop = .{} } });
    _ = try ddl(&store, try createRequest(11, 7, "people"));
    turn = try store.capture(17);
    try t.expectEqualDeep(rejected, (try owner.mutationReceipt(&turn, 17, rejected.reference)).?);
    try t.expectEqualDeep(detail, try c.TableDiagnostic.status(&original, .{ .dml = (try owner.mutationReceipt(&turn, 17, rejected.reference)).? }));
    try t.expectEqualDeep(failed, (try owner.status(&turn, 17, 5, failed.operation.digest)).?);
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
    const accepted = try dml(&store, request);
    try t.expectEqual(.applied, accepted.state);
    try t.expectEqual(@as(u64, 1), accepted.matched);
    try t.expectEqual(@as(u64, 1), accepted.changed);
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
    var rights = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
    rights.revision = 2;
    rights.insert = false;
    rights.read = false;
    turn = try store.capture(17);
    try store.setRights(rights);
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
    try store.setRights(rights);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.mutationStatus(t.allocator, &turn, 17, request));
    try t.expectError(error.CatalogDenied, owner.cancelMutation(t.allocator, &turn, request));
    try t.expectError(error.CatalogDenied, owner.cleanupMutation(t.allocator, &turn, request));
    try t.expectEqual(@as(usize, 0), countWrites(turn));
    var other = owner;
    other.configuration.scope.catalog = 2;
    try store.setRights(try TestStore.Rights.administrator(other.configuration.scope, 17));
    try other.initialize(&turn);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.TableNotFound, other.mutationStatus(t.allocator, &turn, 17, request));
    turn = try store.capture(18);
    try t.expectError(error.CatalogDenied, owner.mutate(t.allocator, &turn, request));
}

fn selfTurn(store: *TestStore, pid: u64) !s.Turn {
    var turn = try store.capture(17);
    turn.delivery.input.origin = .{ .process = .{ .pid = pid, .turn = 1, .output = 1 } };
    return turn;
}
test "owner continuation cannot admit work or impersonate its original principal" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try keyedCreate();
    var turn = try selfTurn(&store, 3);
    try t.expectError(error.CatalogOperationNotFound, owner.continueDdl(t.allocator, &turn, creation));
    try t.expectError(error.CatalogDenied, owner.step(t.allocator, &turn, creation));
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.continueDdl(t.allocator, &turn, creation));
    _ = try owner.step(t.allocator, &turn, creation);
    try store.commit(turn);
    turn = try selfTurn(&store, 4);
    try t.expectError(error.CatalogDenied, owner.continueDdl(t.allocator, &turn, creation));
    var changed = creation;
    changed.principal = 18;
    turn = try selfTurn(&store, 3);
    try t.expectError(error.CatalogOperationNotFound, owner.continueDdl(t.allocator, &turn, changed));
    changed = creation;
    changed.name = try Meta.Name.init("other");
    try t.expectError(error.CatalogIdentityConflict, owner.continueDdl(t.allocator, &turn, changed));
    var completed: ?Cat.Outcome = null;
    for (0..100) |_| {
        turn = try selfTurn(&store, 3);
        const result = try owner.continueDdl(t.allocator, &turn, creation);
        try store.commit(turn);
        if (result.terminal()) {
            completed = result;
            break;
        }
    }
    try t.expect(completed != null);
    var plan = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO people VALUES (1, 'A'), (2, 'B')", "people", creation.action.create.schema, null);
    defer plan.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = completed.?.operation.metadata, .plan = plan.plan };
    turn = try selfTurn(&store, 3);
    try t.expectError(error.TableWriteNotFound, owner.continueMutation(t.allocator, &turn, request));
    try t.expectError(error.CatalogDenied, owner.mutate(t.allocator, &turn, request));
    turn = try store.capture(17);
    _ = try owner.mutate(t.allocator, &turn, request);
    try store.commit(turn);
    turn = try selfTurn(&store, 4);
    try t.expectError(error.CatalogDenied, owner.continueMutation(t.allocator, &turn, request));
    turn = try store.capture(17);
    var rights = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
    rights.revision = 2;
    rights.insert = false;
    try store.setRights(rights);
    try store.commit(turn);
    turn = try selfTurn(&store, 3);
    try t.expectError(error.CatalogDenied, owner.continueMutation(t.allocator, &turn, request));
    try t.expectEqual(@as(usize, 0), countWrites(turn));
    turn = try store.capture(17);
    try t.expectEqual(.building, (try owner.mutationStatus(t.allocator, &turn, 17, request)).?.state);
    rights.revision = 3;
    rights.insert = true;
    try store.setRights(rights);
    try store.commit(turn);
    for (0..100) |_| {
        turn = try selfTurn(&store, 3);
        const result = try owner.continueMutation(t.allocator, &turn, request);
        try store.commit(turn);
        if (result.state == .applied) {
            try t.expectEqual(@as(u64, 2), result.changed);
            return;
        }
    }
    return error.TestUnexpectedResult;
}

test "saved DML references retain their route and cannot cancel catalog ALTER" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try keyedCreate();
    const created = try ddl(&store, creation);
    var plan = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO people VALUES (1, 'A'), (2, 'B')", "people", creation.action.create.schema, null);
    defer plan.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = created.operation.metadata, .plan = plan.plan };
    var turn = try store.capture(17);
    const admitted = try owner.mutate(t.allocator, &turn, request);
    try t.expectEqual(.statement, admitted.route);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectEqualDeep(admitted, (try owner.mutationReceipt(&turn, 17, admitted.reference)).?);
    try t.expectError(error.InvalidTableWriteStatus, s.TableWrite.cancel(&turn, admitted.reference));
    try t.expectEqual(.cancelled, (try owner.cancelMutationReference(&turn, admitted.reference)).state);
    try store.commit(turn);
    for (0..100) |_| {
        turn = try store.capture(17);
        const complete = try owner.cleanupMutationReference(&turn, admitted.reference);
        try store.commit(turn);
        if (complete) break;
    }
    const alter: c.TableDdlRequest = .{ .principal = 17, .operation = 3, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .alter = .{ .schema = creation.action.create.schema, .change = .{ .rename = .{ .column = 2, .name = "full_name" } } } } };
    const alter_ref = try (try alter.tableAlter(owner.configuration.scope)).reference();
    for (0..100) |_| {
        turn = try store.capture(17);
        const result = try owner.step(t.allocator, &turn, alter);
        try store.commit(turn);
        if (result.operation.state == .delegated) break;
    }
    turn = try store.capture(17);
    try t.expectEqual(.alter, (try s.TableWrite.status(&turn, alter_ref)).?.route);
    try t.expectError(error.CatalogIdentityConflict, owner.mutationReceipt(&turn, 17, alter_ref));
    try t.expectError(error.CatalogIdentityConflict, owner.cancelMutationReference(&turn, alter_ref));
    try t.expectError(error.CatalogIdentityConflict, owner.cleanupMutationReference(&turn, alter_ref));
    try t.expectError(error.InvalidTableWriteStatus, s.TableStatement.cancel(&turn, alter_ref));
    try t.expectEqual(@as(usize, 0), countWrites(turn));
    const pending = try owner.cancel(&turn, 17, 3, try alter.digest(owner.configuration.scope));
    try t.expect(!pending.terminal());
    try t.expectEqual(@as(usize, 0), countWrites(turn));
    try t.expect(turn.decision.blocks.mutations[0] != null);
    try store.commit(turn);
    turn = try store.capture(17);
    const cancelled = try owner.cancel(&turn, 17, 3, try alter.digest(owner.configuration.scope));
    try t.expectEqual(.cancelled, cancelled.table.?.state);
    try t.expectEqual(@as(usize, 4), countWrites(turn));
    try store.commit(turn);
    var other = admitted.reference;
    other.resource += 1;
    turn = try store.capture(17);
    try t.expectError(error.CatalogScopeChanged, owner.mutationReceipt(&turn, 17, other));
    try t.expectError(error.CatalogDenied, owner.mutationReceipt(&turn, 18, admitted.reference));
}

test "command basis resolves accepted historical schema after DROP with current rights" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try keyedCreate();
    _ = try ddl(&store, creation);
    var turn = try store.capture(17);
    var definition = (try owner.lookup(t.allocator, &turn, 17, creation.name)).?;
    defer definition.deinit();
    var plan = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO people VALUES (1, 'A')", "people", definition.schema.schema, null);
    defer plan.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = .{ .id = definition.metadata.revision, .spec = try definition.metadata.spec() }, .plan = plan.plan };
    const body = try c.TableCommand.fromDml(owner.configuration.scope, owner.configuration.owner, request, definition.metadata);
    var bytes: [512]u8 = undefined;
    const encoded = try c.TableCommand.encode(t.allocator, body, &bytes);
    _ = try dml(&store, request);
    _ = try ddl(&store, .{ .principal = 17, .operation = 3, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .drop = .{} } });
    _ = try ddl(&store, try createRequest(11, 4, "people"));
    turn = try store.capture(17);
    const Batched = struct {
        store: *TestStore,
        view: struct { id: u64 = 0, resource: u64 = 7, revision: u64 },
        keys: [16]?p.Value = @splat(null),
        count: usize = 0,
        batches: usize = 0,
        fail_batch: ?usize = null,
        pub fn authorizationSubject(self: *@This(), who: u64) !p.Authorization.Subject {
            return self.store.authorizationSubject(who);
        }
        pub fn requireAuthorization(self: *@This(), guard: p.Authorization.Guard) !p.Authorization.Verified {
            return self.store.requireAuthorization(guard);
        }
        pub fn prefetch(self: *@This(), keys: []const p.Value) !void {
            try t.expect(keys.len <= p.Growth.page_size);
            const before = self.count;
            outer: for (keys) |key| {
                for (self.keys[0..self.count]) |existing| if (existing.?.eql(key)) continue :outer;
                try t.expect(self.count < self.keys.len);
                self.keys[self.count] = key;
                self.count += 1;
            }
            if (self.count != before) {
                self.batches += 1;
                if (self.fail_batch == self.batches) return error.Unavailable;
            }
        }
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            for (self.keys[0..self.count]) |existing| if (existing.?.eql(key)) return self.store.state.get(key);
            return error.UnbatchedMetadataRead;
        }
        pub fn readBlock(self: *@This(), key: p.Value, output: []u8) !?[]const u8 {
            const value = self.store.blocks.records.get(key) orelse return null;
            if (value.bytes.len > output.len) return error.BlockBufferTooSmall;
            @memcpy(output[0..value.bytes.len], value.bytes);
            return output[0..value.bytes.len];
        }
    };
    var batched: Batched = .{ .store = &store, .view = .{ .revision = store.revision } };
    var original = (try owner.commandBasis(t.allocator, &batched, 17, body.header, .execute)).?;
    defer original.deinit();
    try t.expectEqual(@as(usize, 4), batched.batches);
    for (1..5) |failed| {
        var unavailable: Batched = .{ .store = &store, .view = batched.view, .fail_batch = failed };
        try t.expectError(error.Unavailable, owner.commandBasis(t.allocator, &unavailable, 17, body.header, .execute));
    }
    try t.expectEqual(@as(u64, 10), original.record.object);
    var decoded = try c.TableCommand.decode(t.allocator, encoded, original.borrow());
    defer decoded.deinit();
    try t.expectEqual(.applied, (try owner.mutate(t.allocator, &turn, decoded.body.request.dml)).state);
    var changed = body.header;
    changed.owner += 1;
    try t.expectError(error.CatalogOwnerChanged, owner.commandBasis(t.allocator, &turn, 17, changed, .inspect));
    try t.expectError(error.CatalogDenied, owner.commandBasis(t.allocator, &turn, 18, body.header, .inspect));
    var rights = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
    rights.revision = 2;
    rights.insert = false;
    try store.setRights(rights);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.commandBasis(t.allocator, &turn, 17, body.header, .execute));
    var disclosed = (try owner.commandBasis(t.allocator, &turn, 17, body.header, .inspect)).?;
    defer disclosed.deinit();
    rights.revision = 3;
    rights.inspect = false;
    try store.setRights(rights);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.CatalogDenied, owner.commandBasis(t.allocator, &turn, 17, body.header, .inspect));
}

test "exact general definitions survive evolution retirement and name reuse with current inspection rights" {
    inline for (.{ "people", "people_with_a_name_long_enough_to_require_chunked_immutable_metadata_storage" }) |name| {
        var store: TestStore = .{};
        defer store.deinit();
        try ready(&store);
        const creation = try createRequest(10, 1, name);
        _ = try ddl(&store, creation);
        const alteration: c.TableDdlRequest = .{ .principal = 17, .operation = 2, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .alter = .{ .schema = creation.action.create.schema, .change = .{ .rename = .{ .column = 2, .name = "full_name" } } } } };
        _ = try ddl(&store, alteration);
        _ = try ddl(&store, .{ .principal = 17, .operation = 3, .object = 10, .expected_revision = 2, .name = creation.name, .action = .{ .drop = .{} } });
        _ = try ddl(&store, try createRequest(11, 4, name));
        var turn = try store.capture(17);
        var current = (try owner.lookup(t.allocator, &turn, 17, creation.name)).?;
        defer current.deinit();
        try t.expectEqual(@as(u64, 11), current.metadata.object);
        for (1..4) |revision| {
            var old = (try owner.definition(t.allocator, &turn, 17, 10, revision)).?;
            defer old.deinit();
            try t.expectEqual(@as(u64, 10), old.metadata.object);
            try t.expectEqual(revision, old.metadata.revision);
            try t.expectEqualStrings(name, old.metadata.name.slice());
            try t.expectEqualStrings(if (revision == 1) "name" else "full_name", old.schema.schema.columns[1].name);
            try t.expectEqual(@as(usize, 0), countWrites(turn));
        }
        try t.expectEqual(null, try owner.definition(t.allocator, &turn, 17, 10, 99));
        try t.expectEqual(null, try owner.definition(t.allocator, &turn, 17, 99, 1));
        try t.expectError(error.InvalidCatalogIdentity, owner.definition(t.allocator, &turn, 17, 10, 0));
        var rights = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
        rights.revision = 2;
        rights.inspect = false;
        try store.setRights(rights);
        try store.commit(turn);
        turn = try store.capture(17);
        try t.expectError(error.CatalogDenied, owner.definition(t.allocator, &turn, 17, 10, 1));
        try t.expectError(error.CatalogDenied, owner.definition(t.allocator, &turn, 17, 99, 1));
        rights.revision = 3;
        rights.inspect = true;
        rights.read = false;
        try store.setRights(rights);
        try store.commit(turn);
        turn = try store.capture(17);
        var restored = (try owner.definition(t.allocator, &turn, 17, 10, 1)).?;
        defer restored.deinit();
        try t.expectEqualStrings("name", restored.schema.schema.columns[1].name);
        // Losing a retained acceptance record is an error, not an absent revision.
        const receipt_key = owner.key('o', 17, 1);
        const receipt = store.state.get(receipt_key).?;
        try t.expect(store.state.remove(receipt_key));
        try t.expectError(error.CatalogDefinitionMissing, owner.definition(t.allocator, &turn, 17, 10, 1));
        try store.state.put(t.allocator, receipt_key, receipt);
        const block_key = Records.key(10, 'c', 1);
        const bytes = try t.allocator.dupe(u8, store.blocks.records.get(block_key).?.bytes);
        defer t.allocator.free(bytes);
        store.blocks.records.get(block_key).?.bytes[44 + 4] ^= 1;
        try t.expectError(error.CatalogDefinitionChanged, owner.definition(t.allocator, &turn, 17, 10, 1));
        try store.blocks.put(t.allocator, block_key, bytes[0..10], store.revision);
        try t.expectError(error.InvalidPublicationChunk, owner.definition(t.allocator, &turn, 17, 10, 1));
        try store.blocks.put(t.allocator, block_key, bytes, store.revision);
    }
}

fn retainedDefinitionAllocation(allocator: std.mem.Allocator, store: *TestStore) !void {
    var turn = try store.capture(17);
    var old = (try owner.definition(allocator, &turn, 17, 10, 1)).?;
    defer old.deinit();
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const value = try c.TableValues.HistoricalDefinition.foreign(&arena, old);
    try t.expectEqualStrings("10", value.metadata.object);
    try t.expectEqualStrings("id", value.schema.columns[0].name);
}
test "retained definition allocation failures free owned schema and neutral results" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    _ = try ddl(&store, try createRequest(10, 1, "people"));
    for (0..128) |index| {
        var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = index, .resize_fail_index = 0 });
        retainedDefinitionAllocation(failing.allocator(), &store) catch |err| {
            if (err != error.OutOfMemory) return err;
            try t.expect(failing.has_induced_failure);
            continue;
        };
        return;
    }
    return error.TestUnexpectedResult;
}

test "current object checks filter two Tables sharing one resource" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const first = try createRequest(10, 1, "visible");
    const second = try createRequest(20, 2, "hidden");
    _ = try ddl(&store, first);
    _ = try ddl(&store, second);
    var turn = try store.capture(17);
    var visible = (try owner.lookup(t.allocator, &turn, 17, first.name)).?;
    defer visible.deinit();
    turn = try store.capture(17);
    var hidden = (try owner.lookup(t.allocator, &turn, 17, second.name)).?;
    defer hidden.deinit();
    try t.expect(visible.authority.authorization != hidden.authority.authorization);
    try store.setRights(.{ .principal = 18, .create = false, .read = false, .insert = false, .update = false, .delete = false, .alter = false, .drop = false });
    try store.grantObject(18, visible.authority.authorization, c.TableAuthority.select);
    turn = try store.capture(18);
    const page = try owner.list(&turn, 18, null);
    try t.expectEqual(@as(u64, 10), page.entries[0].?.metadata.object);
    try t.expectEqual(null, page.entries[1]);
    try t.expectEqual(null, try owner.lookup(t.allocator, &turn, 18, second.name));
    try t.expectError(error.CatalogDenied, owner.definition(t.allocator, &turn, 18, 20, 1));
    _ = try owner.authorizeObject(&turn, 18, 10, .read);
    try t.expectError(error.CatalogDenied, owner.authorizeObject(&turn, 18, 20, .read));
    try t.expectError(error.CatalogDenied, owner.authorizeObject(&turn, 18, 10, .insert));
    try store.grantObject(18, visible.authority.authorization, 0);
    turn = try store.capture(18);
    try t.expectEqual(null, (try owner.list(&turn, 18, null)).entries[0]);
    try t.expectError(error.CatalogDenied, owner.authorizeObject(&turn, 18, 10, .read));
}

test "lifecycle inspection and non-mutating DDL preview distinguish pending published and unavailable states" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try createRequest(10, 1, "people");

    var turn = try store.capture(17);
    const create_preview = try owner.previewDdl(&turn, 17, creation);
    try t.expectEqual(null, turn.decision.mutations[0]);
    try t.expectEqual(m.ObjectKind.table, create_preview.kind);
    try t.expectEqual(m.Kind.create, create_preview.action);
    try t.expectEqual(.admissible, create_preview.disposition);
    try t.expectEqual(@as(u64, 1), create_preview.expected_revision);
    try t.expectEqual(null, try owner.inspectLifecycle(&turn, 17, 10));

    // Admit creation (step 1: initializing -> pending)
    const admitted = try owner.step(t.allocator, &turn, creation);
    try t.expect(!admitted.terminal());
    try store.commit(turn);

    turn = try store.capture(17);
    const pending_ev = (try owner.inspectLifecycle(&turn, 17, 10)).?;
    try t.expectEqual(m.LifecycleState.pending, pending_ev.state);
    try t.expectEqual(@as(u64, 1), pending_ev.pending_operation);

    // Finish creation -> published
    _ = try ddl(&store, creation);
    turn = try store.capture(17);
    const published_ev = (try owner.inspectLifecycle(&turn, 17, 10)).?;
    try t.expectEqual(m.LifecycleState.published, published_ev.state);
    try t.expectEqual(@as(u64, 1), published_ev.revision);
    try t.expectEqualStrings("people", published_ev.name.slice());

    // Preview duplicate CREATE and IF NOT EXISTS without mutating state
    const conflict_preview = try owner.previewDdl(&turn, 17, try createRequest(11, 2, "people"));
    try t.expectEqual(.rejected, conflict_preview.disposition);
    try t.expectEqual(.name_conflict, conflict_preview.reason);
    var if_not_exists = try createRequest(11, 2, "people");
    if_not_exists.action.create.if_not_exists = true;
    const unchanged_preview = try owner.previewDdl(&turn, 17, if_not_exists);
    try t.expectEqual(.unchanged, unchanged_preview.disposition);

    // Preview ALTER and DROP with dependency check
    var resolved = (try owner.lookup(t.allocator, &turn, 17, creation.name)).?;
    defer resolved.deinit();
    const alter_req: c.TableDdlRequest = .{
        .principal = 17,
        .operation = 3,
        .object = 10,
        .expected_revision = 1,
        .name = creation.name,
        .action = .{ .alter = .{ .schema = resolved.schema.schema, .change = .{ .rename = .{ .column = 2, .name = "full_name" } } } },
    };
    const alter_preview = try owner.previewDdl(&turn, 17, alter_req);
    try t.expectEqual(.admissible, alter_preview.disposition);
    try t.expectEqual(c.fuze.TableEvolution.Work.metadata, alter_preview.work);

    const dep: m.Dependency = .{ .scope = owner.configuration.scope, .object = 10, .identity = 77, .owner = 4, .kind = .query_source };
    try owner.setDependency(&turn, dep, true);
    try store.commit(turn);

    turn = try store.capture(17);
    const drop_req: c.TableDdlRequest = .{ .principal = 17, .operation = 4, .object = 10, .expected_revision = 1, .name = creation.name, .action = .{ .drop = .{} } };
    const blocked_drop = try owner.previewDdl(&turn, 17, drop_req);
    try t.expectEqual(.rejected, blocked_drop.disposition);
    try t.expectEqual(.dependency, blocked_drop.reason);
    try t.expectEqual(@as(u64, 77), blocked_drop.blocker.?.identity);

    try owner.setDependency(&turn, dep, false);
    try store.commit(turn);
    _ = try ddl(&store, drop_req);

    turn = try store.capture(17);
    const retired_ev = (try owner.inspectLifecycle(&turn, 17, 10)).?;
    try t.expectEqual(m.LifecycleState.unavailable, retired_ev.state);
}

test "declarative catalog manages KV and Document lifecycles with two-phase provisioning RESTRICT drop and retirement" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const decl: c.DeclarativeCatalog = .{ .configuration = owner.configuration };

    // Parse SQL CREATE KV and CREATE DOCUMENT via Fuze Declaration
    const kv_def = try c.fuze.Declaration.compile("CREATE KV session_tokens (UTF8)");
    const doc_def = try c.fuze.Declaration.compile("CREATE DOCUMENT customer_profile");

    const kv_req = try c.DeclarativeCatalog.Request.fromDeclaration(owner.configuration.scope, 17, 101, 1, 50, 9001, kv_def);
    var turn = try store.capture(17);
    const kv_preview = try decl.preview(&turn, 17, kv_req);
    try t.expectEqual(m.ObjectKind.kv, kv_preview.kind);
    try t.expectEqual(.admissible, kv_preview.disposition);

    // Phase 1: reserve initializing record
    turn = try store.capture(17);
    const phase1 = try decl.apply(&turn, kv_req);
    try t.expectEqual(.provisioning, phase1.state);
    try store.commit(turn);

    turn = try store.capture(17);
    const pending_ev = (try owner.inspectLifecycle(&turn, 17, 50)).?;
    try t.expectEqual(m.ObjectKind.kv, pending_ev.kind);
    try t.expectEqual(m.LifecycleState.pending, pending_ev.state);
    try t.expectEqual(null, try decl.lookup(&turn, 17, kv_req.name));

    // Phase 2: bind resource and publish
    const phase2 = try decl.apply(&turn, kv_req);
    try t.expectEqual(.applied, phase2.state);
    try t.expectEqual(@as(u64, 9001), phase2.resource_id);
    try store.commit(turn);

    turn = try store.capture(17);
    const published_ev = (try owner.inspectLifecycle(&turn, 17, 50)).?;
    try t.expectEqual(m.ObjectKind.kv, published_ev.kind);
    try t.expectEqual(m.LifecycleState.published, published_ev.state);
    const looked_up = (try decl.lookup(&turn, 17, kv_req.name)).?;
    try t.expectEqual(@as(u64, 50), looked_up.object);
    try t.expectEqual(@as(u64, 9001), looked_up.resource_id);

    // Interrupted provisioning on Document (cancel + cleanup)
    const doc_req_cancelled = try c.DeclarativeCatalog.Request.fromDeclaration(owner.configuration.scope, 17, 102, 1, 60, 9002, doc_def);
    turn = try store.capture(17);
    const doc_p1 = try decl.apply(&turn, doc_req_cancelled);
    try t.expectEqual(.provisioning, doc_p1.state);
    try store.commit(turn);

    turn = try store.capture(17);
    const cancelled_doc = try decl.cancel(&turn, 17, 102, try doc_req_cancelled.digest());
    try t.expectEqual(.cancelled, cancelled_doc.state);
    try store.commit(turn);

    turn = try store.capture(17);
    try t.expect(try decl.cleanup(&turn, 17, 102, try doc_req_cancelled.digest()));
    try store.commit(turn);

    // Publish Document with fresh object ID 61
    const doc_req = try c.DeclarativeCatalog.Request.fromDeclaration(owner.configuration.scope, 17, 103, 1, 61, 9003, doc_def);
    turn = try store.capture(17);
    _ = try decl.apply(&turn, doc_req);
    try store.commit(turn);
    turn = try store.capture(17);
    const doc_p2 = try decl.apply(&turn, doc_req);
    try t.expectEqual(.applied, doc_p2.state);
    try store.commit(turn);

    turn = try store.capture(17);
    const page = try decl.list(&turn, 17, null);
    try t.expectEqual(@as(u64, 50), page.entries[0].?.object);
    try t.expectEqual(@as(u64, 61), page.entries[1].?.object);

    // Table with same name as KV is rejected with name_conflict
    const table_conflict = try ddl(&store, try createRequest(70, 104, "session_tokens"));
    try t.expectEqual(.rejected, table_conflict.operation.state);
    try t.expectEqual(.name_conflict, table_conflict.operation.reason);

    // Rename KV and test RESTRICT drop
    const rename_req: c.DeclarativeCatalog.Request = .{
        .scope = owner.configuration.scope,
        .principal = 17,
        .operation = 105,
        .namespace = 1,
        .object = 50,
        .expected_revision = 1,
        .name = kv_req.name,
        .action = .{ .rename = try c.TableAuthority.Name.init("active_tokens") },
    };
    turn = try store.capture(17);
    const renamed = try decl.apply(&turn, rename_req);
    try t.expectEqual(.applied, renamed.state);
    try t.expectEqual(@as(u64, 2), renamed.revision);
    try store.commit(turn);

    // Add restricting dependency on KV object 50
    turn = try store.capture(17);
    const dep: m.Dependency = .{ .scope = owner.configuration.scope, .object = 50, .identity = 88, .owner = 4, .kind = .query_source };
    try owner.setDependency(&turn, dep, true);
    try store.commit(turn);

    const drop_req: c.DeclarativeCatalog.Request = .{
        .scope = owner.configuration.scope,
        .principal = 17,
        .operation = 106,
        .namespace = 1,
        .object = 50,
        .expected_revision = 2,
        .name = try c.TableAuthority.Name.init("active_tokens"),
        .action = .{ .drop = .{} },
    };
    turn = try store.capture(17);
    const blocked = try decl.apply(&turn, drop_req);
    try t.expectEqual(.rejected, blocked.state);
    try t.expectEqual(.dependency, blocked.reason);
    try t.expectEqual(@as(u64, 88), blocked.blocker.dependency.identity);
    try store.commit(turn);

    // Remove dependency and drop KV object 50
    turn = try store.capture(17);
    try owner.setDependency(&turn, dep, false);
    try store.commit(turn);

    var drop_req2 = drop_req;
    drop_req2.operation = 107;
    turn = try store.capture(17);
    const dropped = try decl.apply(&turn, drop_req2);
    try t.expectEqual(.applied, dropped.state);
    try store.commit(turn);

    turn = try store.capture(17);
    const retired_kv = (try owner.inspectLifecycle(&turn, 17, 50)).?;
    try t.expectEqual(m.LifecycleState.unavailable, retired_kv.state);

    // Reusing retired object ID 50 is rejected with object_conflict; fresh ID 51 succeeds
    var reuse_id_req = try c.DeclarativeCatalog.Request.fromDeclaration(owner.configuration.scope, 17, 108, 1, 50, 9004, try c.fuze.Declaration.compile("CREATE KV active_tokens (UTF8)"));
    turn = try store.capture(17);
    const reused = try decl.apply(&turn, reuse_id_req);
    try t.expectEqual(.rejected, reused.state);
    try t.expectEqual(.object_conflict, reused.reason);
    try store.commit(turn);

    reuse_id_req.operation = 109;
    reuse_id_req.object = 51;
    turn = try store.capture(17);
    _ = try decl.apply(&turn, reuse_id_req);
    try store.commit(turn);
    turn = try store.capture(17);
    const replaced = try decl.apply(&turn, reuse_id_req);
    try t.expectEqual(.applied, replaced.state);
    try store.commit(turn);
}

test "dependency graph and policy reference inspection enforce current rights and redact details without read access" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    _ = try ddl(&store, try createRequest(10, 1, "people"));
    _ = try ddl(&store, try createRequest(20, 2, "secret_audit"));

    const decl: c.DeclarativeCatalog = .{ .configuration = owner.configuration };
    const kv_req = try c.DeclarativeCatalog.Request.fromDeclaration(owner.configuration.scope, 17, 3, 1, 30, 9100, try c.fuze.Declaration.compile("CREATE KV user_cache (UTF8)"));
    var turn = try store.capture(17);
    _ = try decl.apply(&turn, kv_req);
    try store.commit(turn);
    turn = try store.capture(17);
    _ = try decl.apply(&turn, kv_req);
    try store.commit(turn);

    // Register dependencies: identity 30 (user_cache) depends on 10 (people) and 20 (secret_audit)
    turn = try store.capture(17);
    try owner.setDependency(&turn, .{ .scope = owner.configuration.scope, .object = 10, .identity = 30, .owner = 3, .kind = .query_source }, true);
    try store.commit(turn);
    turn = try store.capture(17);
    try owner.setDependency(&turn, .{ .scope = owner.configuration.scope, .object = 20, .identity = 30, .owner = 3, .kind = .history }, true);
    try store.commit(turn);

    turn = try store.capture(17);
    const deps_of_10 = try owner.dependents(&turn, 17, 10, null);
    try t.expectEqual(@as(u64, 30), deps_of_10.entries[0].?.identity);
    try t.expectEqual(null, deps_of_10.entries[1]);

    const targets_of_30 = try owner.dependencies(&turn, 17, 30, null);
    try t.expectEqual(@as(u64, 10), targets_of_30.entries[0].?.object);
    try t.expectEqual(@as(u64, 20), targets_of_30.entries[1].?.object);

    // Full policy references with read access
    const full_policy = (try owner.policyReferences(&turn, 17, 10)).?;
    try t.expectEqual(m.ObjectKind.table, full_policy.kind);
    try t.expect(full_policy.can_read);
    try t.expect(!full_policy.redacted);
    try t.expect(full_policy.authorization_object != 0);
    try t.expect(full_policy.schema_authorization != 0);

    const kv_policy = (try owner.policyReferences(&turn, 17, 30)).?;
    try t.expectEqual(m.ObjectKind.kv, kv_policy.kind);
    try t.expect(kv_policy.can_read);
    try t.expect(!kv_policy.redacted);

    // Revoke read access for principal 17 (keep inspect via insert/update/delete or visible grant)
    var rights = try @import("TestStore.zig").Rights.administrator(owner.configuration.scope, 17);
    rights.revision = 2;
    rights.read = false;
    try store.setRights(rights);
    try store.commit(turn);

    turn = try store.capture(17);
    const redacted_policy = (try owner.policyReferences(&turn, 17, 10)).?;
    try t.expect(!redacted_policy.can_read);
    try t.expect(redacted_policy.redacted);
    try t.expectEqual(@as(u64, 0), redacted_policy.authorization_object);
    try t.expectEqual(@as(u64, 0), redacted_policy.schema_authorization);
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const foreign_redacted = try c.TableValues.PolicyReferences.foreign(arena.allocator(), redacted_policy);
    try t.expect(foreign_redacted.redacted);
    try t.expectEqual(null, foreign_redacted.authorization_object);
    try t.expectEqual(null, foreign_redacted.schema_authorization);

    // Principal 18 granted only SELECT on table 10 and KV 30, not on table 20
    var def10 = (try owner.lookup(t.allocator, &turn, 17, try Meta.Name.init("people"))).?;
    defer def10.deinit();
    const rec30 = (try decl.record(&turn, 30)).?;
    try store.setRights(.{ .principal = 18, .create = false, .read = false, .insert = false, .update = false, .delete = false, .alter = false, .drop = false });
    try store.grantObject(18, def10.authority.authorization, c.TableAuthority.select);
    try store.grantObject(18, rec30.authorization, c.TableAuthority.select);

    turn = try store.capture(18);
    // Principal 18 inspecting dependencies of 30 sees 10, while unauthorized 20 is filtered out
    const filtered_targets = try owner.dependencies(&turn, 18, 30, null);
    try t.expectEqual(@as(u64, 10), filtered_targets.entries[0].?.object);
    try t.expectEqual(null, filtered_targets.entries[1]);
    try t.expectError(error.CatalogDenied, owner.dependents(&turn, 18, 20, null));
    try t.expectError(error.CatalogDenied, owner.policyReferences(&turn, 18, 20));
}

test "computation catalog lifecycle tracks upstream source revision freshness and availability" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    const creation = try createRequest(10, 1, "people");
    _ = try ddl(&store, creation);

    const decl: c.DeclarativeCatalog = .{ .configuration = owner.configuration };
    const comp_req: c.DeclarativeCatalog.Request = .{
        .scope = owner.configuration.scope,
        .principal = 17,
        .operation = 2,
        .namespace = 1,
        .object = 80,
        .expected_revision = 0,
        .name = try c.TableAuthority.Name.init("people_summary"),
        .action = .{
            .create = .{
                .spec = .{ .computation = .{ .source_object = 10, .source_revision = 1, .output_object = 0 } },
                .resource_id = 9800,
            },
        },
    };

    // Phase 1: initializing -> pending
    var turn = try store.capture(17);
    const p1 = try decl.apply(&turn, comp_req);
    try t.expectEqual(.provisioning, p1.state);
    try store.commit(turn);

    turn = try store.capture(17);
    try t.expectEqual(m.LifecycleState.pending, (try owner.inspectComputation(&turn, 17, 80)).?.state);

    // Phase 2: live -> published (not yet evaluated)
    const p2 = try decl.apply(&turn, comp_req);
    try t.expectEqual(.applied, p2.state);
    try store.commit(turn);

    // Bind restricting query_source dependency from computation 80 to source table 10
    turn = try store.capture(17);
    try decl.bindComputationDependency(&turn, 80, true);
    try store.commit(turn);

    turn = try store.capture(17);
    const comp_published = (try owner.inspectComputation(&turn, 17, 80)).?;
    try t.expectEqual(m.LifecycleState.published, comp_published.state);
    try t.expect(comp_published.source_available);
    try t.expect(!comp_published.fresh);
    try t.expectEqual(@as(u64, 1), comp_published.source_revision);
    try t.expectEqual(@as(u64, 1), comp_published.current_source_revision);
    try t.expectEqual(@as(u64, 80), (try owner.dependents(&turn, 17, 10, null)).entries[0].?.identity);
    try t.expectEqual(@as(u64, 10), (try owner.dependencies(&turn, 17, 80, null)).entries[0].?.object);

    // Complete computation evaluation against source_revision 1 -> complete & fresh
    const eval1: c.DeclarativeCatalog.Request = .{
        .scope = owner.configuration.scope,
        .principal = 17,
        .operation = 3,
        .namespace = 1,
        .object = 80,
        .expected_revision = 1,
        .name = comp_req.name,
        .action = .{ .complete_computation = .{ .source_revision = 1 } },
    };
    const eval1_out = try decl.apply(&turn, eval1);
    try t.expectEqual(.applied, eval1_out.state);
    try store.commit(turn);

    turn = try store.capture(17);
    const comp_complete = (try owner.inspectComputation(&turn, 17, 80)).?;
    try t.expectEqual(m.LifecycleState.complete, comp_complete.state);
    try t.expect(comp_complete.fresh);
    try t.expectEqual(m.LifecycleState.complete, (try owner.inspectLifecycle(&turn, 17, 80)).?.state);

    // Evolve upstream table 10 to revision 2 -> computation becomes stale (pending, fresh = false)
    const alter: c.TableDdlRequest = .{
        .principal = 17,
        .operation = 4,
        .object = 10,
        .expected_revision = 1,
        .name = creation.name,
        .action = .{ .alter = .{ .schema = creation.action.create.schema, .change = .{ .rename = .{ .column = 2, .name = "full_name" } } } },
    };
    _ = try ddl(&store, alter);

    turn = try store.capture(17);
    const comp_stale = (try owner.inspectComputation(&turn, 17, 80)).?;
    try t.expectEqual(m.LifecycleState.pending, comp_stale.state);
    try t.expect(!comp_stale.fresh);
    try t.expectEqual(@as(u64, 1), comp_stale.source_revision);
    try t.expectEqual(@as(u64, 2), comp_stale.current_source_revision);
    try t.expectEqual(m.LifecycleState.pending, (try owner.inspectLifecycle(&turn, 17, 80)).?.state);

    // Re-evaluate computation against source_revision 2 -> complete & fresh again
    const eval2: c.DeclarativeCatalog.Request = .{
        .scope = owner.configuration.scope,
        .principal = 17,
        .operation = 5,
        .namespace = 1,
        .object = 80,
        .expected_revision = 2,
        .name = comp_req.name,
        .action = .{ .complete_computation = .{ .source_revision = 2 } },
    };
    _ = try decl.apply(&turn, eval2);
    try store.commit(turn);

    turn = try store.capture(17);
    const comp_re_evaluated = (try owner.inspectComputation(&turn, 17, 80)).?;
    try t.expectEqual(m.LifecycleState.complete, comp_re_evaluated.state);
    try t.expect(comp_re_evaluated.fresh);

    // Unbind dependency and drop upstream table 10 -> computation reports unavailable
    try decl.bindComputationDependency(&turn, 80, false);
    try store.commit(turn);
    _ = try ddl(&store, .{ .principal = 17, .operation = 6, .object = 10, .expected_revision = 2, .name = creation.name, .action = .{ .drop = .{} } });

    turn = try store.capture(17);
    const comp_unavail = (try owner.inspectComputation(&turn, 17, 80)).?;
    try t.expectEqual(m.LifecycleState.unavailable, comp_unavail.state);
    try t.expect(!comp_unavail.source_available);
    try t.expect(!comp_unavail.fresh);
    try t.expectEqual(m.LifecycleState.unavailable, (try owner.inspectLifecycle(&turn, 17, 80)).?.state);
}
