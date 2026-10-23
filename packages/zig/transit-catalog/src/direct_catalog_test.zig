const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const p = c.protocol;
const s = c.storage;
const a = c.TableAuthority;
const D = c.DirectCatalog;
const P = s.TablePartition;
const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
const profile: a.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };

// Injected policy exercises required scopes and fence placement. Native signed
// proofs, registration and service enforcement need separate composition tests.
const Access = struct {
    calls: usize = 0,
    deny_at: usize = std.math.maxInt(usize),
    mismatch: bool = false,
    missing_table: bool = false,
    const Context = struct { access: *Access, requested: p.Authorization.Guard };
    fn erased(context: *anyopaque) *Access {
        return @ptrCast(@alignCast(context));
    }
    fn make(context: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard) !P.Guard {
        try requested.validate();
        const result = try allocator.create(Context);
        result.* = .{ .access = erased(context), .requested = requested };
        return .{ .context = result, .acquire = acquire, .release = release };
    }
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const value: *Context = @ptrCast(@alignCast(context));
        value.access.calls += 1;
        if (value.access.calls >= value.access.deny_at) return error.CatalogDenied;
        if (value.requested.subject.principal() != 1 or value.requested.requirements[0].?.object.id != profile.database) return error.CatalogDenied;
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn registered(context: *anyopaque, kind: a.Kind, id: u64) !?p.Authorization.Object {
        if (kind == .table and erased(context).missing_table) return null;
        const native: u64 = switch (kind) {
            .database => profile.database,
            .schema => profile.initial_schema_authority,
            .table => 100 + id,
        };
        return .{ .reference = a.reference(native), .owner = 0, .registrar = 1, .actions = a.actions(kind), .domain = profile.domain(kind), .binding = if (erased(context).mismatch) @splat(9) else try a.binding(scope, kind, id), .parent = switch (kind) {
            .database => null,
            .schema => a.reference(profile.database),
            .table => a.reference(profile.initial_schema_authority),
        }, .revision = 1 };
    }
    fn policy(self: *Access) D.Policy {
        return .{ .context = self, .subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 1 } }, .make_guard = make, .registered = registered };
    }
    fn dataGuard(self: *Access, allocator: std.mem.Allocator, properties: D.Properties, object: u64) !P.Guard {
        const namespace: a.Schema = .{ .scope = scope, .id = 1, .authorization = profile.initial_schema_authority, .name = try a.Name.init("public"), .revision = 1 };
        return make(self, allocator, try a.guard(self.policy().subject, profile, namespace, properties.target(object), .insert));
    }
};
fn configuration() !D.Configuration {
    return .{ .scope = scope, .branch = 1, .partition = 1, .audience = 3, .authority = profile, .database_name = try a.Name.init("main"), .initial_schema_name = try a.Name.init("public") };
}
fn owner(wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !D {
    var result = try D.init(t.allocator, try configuration(), wal.log(), objects.objectStore(), wal.log(), objects.objectStore(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
    errdefer result.deinit();
    try result.recover();
    return result;
}
const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};

test "direct preview checks current expectations and schema work without claims or durable writes" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const create = try creation(7, 1, "events");
    const root = catalog.store.root;
    const puts = objects.puts;
    const proposed = try catalog.preview(create, access.policy());
    try t.expectEqual(.none, proposed.reason);
    try t.expect(proposed.work.? == .metadata and proposed.current == null);
    try t.expectEqualDeep(proposed, try catalog.preview(create, access.policy()));
    try t.expectEqualDeep(root, catalog.store.root);
    try t.expectEqual(puts, objects.puts);
    try t.expect(try c.OperationBinding.lookup(t.allocator, objects.objectStore(), create.binding.identity) == null);
    try t.expect((try catalog.status(create.binding, access.policy())) == .not_observed);
    access.deny_at = access.calls + 2;
    try t.expectError(error.CatalogDenied, catalog.preview(create, access.policy()));
    try t.expectEqual(puts, objects.puts);
    access.deny_at = std.math.maxInt(usize);
    _ = try catalog.admit(create, access.policy());
    _ = try catalog.perform(create.binding, access.policy());
    var view = (try resolve(&catalog, &access, "events")).?;
    defer view.deinit();
    var altered = try edit(&view, 2, .{ .alter = .{ .add = .{ .name = "extra", .type = .int64 } } });
    const before_table = try wal.log().tail(view.table.root.partition);
    const before_catalog = catalog.store.root;
    const before_objects = objects.puts;
    try t.expectEqual(@as(u64, 1), (try catalog.inspectNamespace(1, access.policy())).?.id);
    try t.expect(try catalog.inspectNamespace(2, access.policy()) == null);
    const requested: D.AccessRequest = .{ .namespace = 1, .target = view.table.root.interpretation, .access = .read };
    try catalog.checkAccess(requested, access.policy());
    var stale_access = requested;
    stale_access.target.?.revision += 1;
    try t.expectError(error.TableDefinitionChanged, catalog.checkAccess(stale_access, access.policy()));
    access.deny_at = access.calls + 3;
    try t.expectError(error.CatalogDenied, catalog.checkAccess(requested, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    try t.expectError(error.InvalidTableAccessRequest, catalog.checkAccess(.{ .namespace = 1, .target = null, .access = .read }, access.policy()));
    const previewed = try catalog.preview(altered, access.policy());
    try t.expectEqual(.none, previewed.reason);
    try t.expectEqual(c.fuze.TableEvolution.Work.rewrite_rows, previewed.work.?);
    try t.expectEqualDeep(view.table.root.declared(), previewed.current.?.interpretation);
    altered.binding.expected_data = .{ .partition = view.table.root.partition, .next_lsn = 0 };
    try t.expectEqual(.stale_data, (try catalog.preview(altered, access.policy())).reason);
    altered.binding.expected_data = null;
    altered.binding.expected_definition.?.revision += 1;
    try t.expectEqual(.stale_definition, (try catalog.preview(altered, access.policy())).reason);
    const conflict = try creation(8, 3, "events");
    try t.expectEqual(.name_conflict, (try catalog.preview(conflict, access.policy())).reason);
    var reused = try creation(9, 1, "replacement");
    reused.binding.identity = create.binding.identity;
    try t.expectError(error.DataIdentityConflict, catalog.preview(reused, access.policy()));
    try t.expectEqual(before_table, try wal.log().tail(view.table.root.partition));
    try t.expectEqualDeep(before_catalog, catalog.store.root);
    try t.expectEqual(before_objects, objects.puts);
}

test "direct catalog serializes row admission against DDL without a catalog write or inspection side effect" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const create = try creation(7, 1, "events");
    _ = try catalog.admit(create, access.policy());
    _ = try catalog.perform(create.binding, access.policy());
    _ = try catalog.settle(create.binding, access.policy());
    var view = (try resolve(&catalog, &access, "events")).?;
    defer view.deinit();
    const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 2 }, .target = create.binding.target, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, .intent = @splat(3) };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    const request: s.TableDmlIntent.Request = .{ .binding = binding, .interpretation = view.table.root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 2, .operation = 2, .ordinal = 0 }, .cells = &cells }, .expect = .absent } }}, .ingestion = .bulk };
    var forged_row = request.changes[0];
    forged_row.put.row.identity.origin = 7;
    var malformed = request;
    malformed.changes = &.{forged_row};
    const before_bad_identity = objects.puts;
    try t.expectError(error.InvalidInsertRowIdentity, catalog.admitRows(malformed, access.policy()));
    try t.expectEqual(before_bad_identity, objects.puts);
    try t.expect(try c.OperationBinding.lookup(t.allocator, objects.objectStore(), binding.identity) == null);
    const before = catalog.store.root;
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.admitRows(request, access.policy()));
    catalog.lose_table_reply = false;
    try catalog.recover();
    try t.expect((try catalog.rowStatus(binding, access.policy())) == .admitted);
    try t.expectEqualDeep(before, catalog.store.root);
    try view.table.recover();
    try t.expectEqual(@as(u64, 0), view.table.root.live_rows);
    const conflict = try edit(&view, 3, .{ .rename = try a.Name.init("other") });
    try t.expectEqual(.object_conflict, (try catalog.admit(conflict, access.policy())).reason);
    const after_ddl = catalog.store.root;
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, catalog.performRows(binding, access.policy()));
    try t.expectError(error.CatalogDenied, catalog.rowStatus(binding, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.performRows(binding, access.policy()));
    catalog.lose_table_reply = false;
    const committed = (try catalog.rowStatus(binding, access.policy())).committed;
    try t.expectEqual(@as(u64, 1), committed.outcome.affected);
    try t.expectEqualDeep(committed, (try catalog.cancelRows(binding, access.policy())).committed);
    try t.expectEqualDeep(after_ddl, catalog.store.root);
    try view.table.recover();
    const rename = try edit(&view, 4, .{ .rename = try a.Name.init("other") });
    _ = try catalog.admit(rename, access.policy());
    _ = try catalog.perform(rename.binding, access.policy());
    try t.expectEqualDeep(committed, (try catalog.applyRows(request, access.policy())).committed);
}

fn creation(object: u64, operation: u64, name: []const u8) !D.Request {
    const schema: c.fuze.TableSchema.Schema = .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const intent: D.Intent = .{ .namespace = 1, .name = try a.Name.init(name), .action = .{ .create = .{ .schema = schema, .owner = 0 } } };
    return .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = .{ .scope = scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) }, .intent = intent };
}
fn edit(view: *D.View, operation: u64, action: @FieldType(D.Intent, "action")) !D.Request {
    const intent: D.Intent = .{ .namespace = view.properties.namespace, .name = view.properties.name, .action = action };
    return .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = view.table.root.interpretation.object, .action = switch (action) {
        .rename => .rename,
        .alter => .alter,
        .drop => .drop,
        .create => unreachable,
    }, .expected_definition = view.table.root.interpretation, .expected_data = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, .intent = try intent.digest(t.allocator) }, .intent = intent };
}
fn resolve(catalog: *D, access: *Access, name: []const u8) !?D.View {
    return catalog.resolve(t.allocator, 1, try a.Name.init(name), access.policy());
}

test "direct catalog reservations publish names only through Table acceptance and survive restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    const create = try creation(7, 1, "events");
    var rename: D.Request = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        catalog.store.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.admit(create, access.policy()));
        catalog.store.lose_reply = false;
        try t.expect((try catalog.status(create.binding, access.policy())) == .admitted);
        try t.expect((try resolve(&catalog, &access, "events")) == null);
        const admitted_at = catalog.store.root.next_lsn;
        _ = try catalog.admit(create, access.policy());
        try t.expectEqual(admitted_at, catalog.store.root.next_lsn);
        catalog.lose_table_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.perform(create.binding, access.policy()));
        catalog.lose_table_reply = false;
        try t.expect((try catalog.status(create.binding, access.policy())) == .committed);
        const published_at = catalog.store.root.next_lsn;
        var view = (try resolve(&catalog, &access, "events")).?;
        defer view.deinit();
        const row = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
        const data_binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 10 }, .target = create.binding.target, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = @splat(8) };
        _ = try catalog.applyRows(.{ .binding = data_binding, .interpretation = view.table.root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 2, .operation = 10, .ordinal = 0 }, .cells = &row }, .expect = .absent } }}, .ingestion = .point }, access.policy());
        try view.table.recover();
        try t.expectEqual(published_at, catalog.store.root.next_lsn);
        rename = try edit(&view, 2, .{ .rename = try a.Name.init("renamed") });
        _ = try catalog.admit(rename, access.policy());
        try t.expect((try resolve(&catalog, &access, "renamed")) == null);
        var old = (try resolve(&catalog, &access, "events")).?;
        old.deinit();
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    try t.expect((try catalog.status(rename.binding, access.policy())) == .admitted);
    const renamed = try catalog.perform(rename.binding, access.policy());
    try t.expectEqual(@as(u64, 2), renamed.committed.resulting.interpretation.revision);
    try t.expect((try resolve(&catalog, &access, "events")) == null);
    var view = (try resolve(&catalog, &access, "renamed")).?;
    defer view.deinit();
    try t.expectEqual(@as(u64, 1), view.table.root.live_rows);
    const dropped = try edit(&view, 3, .drop);
    _ = try catalog.admit(dropped, access.policy());
    try t.expect((try catalog.perform(dropped.binding, access.policy())) == .committed);
    try t.expect((try resolve(&catalog, &access, "renamed")) == null);
    const replacement = try creation(8, 4, "renamed");
    _ = try catalog.admit(replacement, access.policy());
    _ = try catalog.perform(replacement.binding, access.policy());
    var later = (try resolve(&catalog, &access, "renamed")).?;
    defer later.deinit();
    try t.expectEqual(@as(u64, 8), later.table.root.interpretation.object.object);
    try t.expect((try catalog.cancel(rename.binding, access.policy())) == .committed);
    const exact = try catalog.settle(rename.binding, access.policy());
    try t.expectEqual(@as(u64, 2), exact.committed.resulting.interpretation.revision);
    try t.expectEqual(@as(u64, 7), exact.committed.resulting.interpretation.object.object);
    const original = try catalog.perform(create.binding, access.policy());
    try t.expectEqual(@as(u64, 1), original.committed.resulting.interpretation.revision);
    try t.expect(!original.committed.resulting.retired);
    var retargeted = replacement;
    retargeted.binding.identity = create.binding.identity;
    try t.expectError(error.DataIdentityConflict, catalog.admit(retargeted, access.policy()));
}

test "direct catalog cancelled reservations release names without reusing object identities" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const first = try creation(7, 1, "reserved");
    _ = try catalog.admit(first, access.policy());
    const contender = try creation(8, 2, "reserved");
    try t.expectEqual(.rejected, (try catalog.admit(contender, access.policy())).phase);
    try t.expect((try catalog.cancel(first.binding, access.policy())) == .cancelled);
    try catalog.recover();
    try t.expect((try catalog.perform(first.binding, access.policy())) == .cancelled);
    try t.expect((try resolve(&catalog, &access, "reserved")) == null);
    const reused_object = try creation(7, 3, "reserved");
    try t.expectEqual(.rejected, (try catalog.admit(reused_object, access.policy())).phase);
    const replacement = try creation(9, 4, "reserved");
    _ = try catalog.admit(replacement, access.policy());
    try t.expect((try catalog.perform(replacement.binding, access.policy())) == .committed);
    const before = catalog.store.root.next_lsn;
    _ = try catalog.status(first.binding, access.policy());
    try t.expectEqual(before, catalog.store.root.next_lsn);
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, catalog.status(replacement.binding, access.policy()));
    try t.expectError(error.CatalogDenied, resolve(&catalog, &access, "reserved"));
    access.deny_at = std.math.maxInt(usize);
    access.mismatch = true;
    try t.expectError(error.InvalidCatalogConfiguration, resolve(&catalog, &access, "reserved"));
}

test "direct catalog ALTER admission blocks conflicting data and final denial preserves resumable work" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const create = try creation(7, 1, "events");
    _ = try catalog.admit(create, access.policy());
    _ = try catalog.perform(create.binding, access.policy());
    _ = try catalog.settle(create.binding, access.policy());
    var view = (try resolve(&catalog, &access, "events")).?;
    defer view.deinit();
    const alteration = try edit(&view, 2, .{ .alter = .{ .add = .{ .name = "value", .type = .int64, .nullable = false, .default = .{ .value = .{ .atom = .{ .signed = 5 } } } } } });
    const before = catalog.store.root.next_lsn;
    access.deny_at = access.calls + 2;
    try t.expectError(error.CatalogDenied, catalog.admit(alteration, access.policy()));
    try t.expectEqual(before, catalog.store.root.next_lsn);
    access.deny_at = std.math.maxInt(usize);
    try t.expect((try catalog.status(alteration.binding, access.policy())) == .not_observed);
    _ = try catalog.admit(alteration, access.policy());
    const data_binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 20 }, .target = create.binding.target, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = @splat(8) };
    const rows: s.TableDmlIntent.Request = .{ .binding = data_binding, .interpretation = view.table.root.declared(), .changes = &.{}, .ingestion = .point };
    try t.expectError(error.CatalogObjectBusy, catalog.admitRows(rows, access.policy()));
    try catalog.recover();
    try t.expect((try catalog.status(alteration.binding, access.policy())) == .admitted);
    const before_table = try wal.log().tail(view.table.root.partition);
    access.deny_at = access.calls + 4;
    try t.expectError(error.CatalogDenied, catalog.perform(alteration.binding, access.policy()));
    try t.expectEqual(before_table, try wal.log().tail(view.table.root.partition));
    access.deny_at = std.math.maxInt(usize);
    try t.expect((try catalog.status(alteration.binding, access.policy())) == .admitted);
    try t.expect((try catalog.perform(alteration.binding, access.policy())) == .committed);
    const again = try catalog.perform(alteration.binding, access.policy());
    try t.expectEqual(@as(u64, 2), again.committed.resulting.interpretation.revision);
    try t.expectEqual(.definition_changed, (try catalog.admitRows(rows, access.policy())).rejected.reason);
}

test "direct catalog directories and operations grow past one resident page with independent listing cuts" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        for (1..130) |id| {
            var buffer: [32]u8 = undefined;
            const request = try creation(id, id, try std.fmt.bufPrint(&buffer, "table-{d}", .{id}));
            _ = try catalog.admit(request, access.policy());
            _ = try catalog.perform(request.binding, access.policy());
            _ = try catalog.settle(request.binding, access.policy());
        }
        try t.expectEqual(@as(usize, 1), catalog.store.index.cache.len);
        try t.expect(catalog.store.root.pending == null);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var cursor: ?s.TreeStore.pages.Key = null;
    var count: usize = 0;
    const before = catalog.store.root.next_lsn;
    while (true) {
        const page = try catalog.list(1, cursor, access.policy());
        try t.expectEqual(.independent, page.consistency);
        try t.expectEqual(before, page.directory_position.next_lsn);
        for (page.entries) |slot| if (slot) |item| {
            count += 1;
            try t.expectEqual(@as(u64, @intCast(count)), item.interpretation.object.object);
            try t.expectEqual(@as(u64, 1), item.position.next_lsn);
        };
        cursor = page.next orelse break;
    }
    try t.expectEqual(@as(usize, 129), count);
    try t.expectEqual(before, catalog.store.root.next_lsn);
}

test "direct catalog rejected ALTER preserves the accepted rows and cannot be resumed" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const create = try creation(7, 1, "events");
    _ = try catalog.admit(create, access.policy());
    _ = try catalog.perform(create.binding, access.policy());
    var before = (try resolve(&catalog, &access, "events")).?;
    defer before.deinit();
    const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 2 }, .target = create.binding.target, .action = .insert, .expected_definition = before.table.root.interpretation, .expected_data = null, .intent = @splat(1) };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    _ = try catalog.applyRows(.{ .binding = binding, .interpretation = before.table.root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 2, .operation = 2, .ordinal = 0 }, .cells = &cells }, .expect = .absent } }}, .ingestion = .point }, access.policy());
    try before.table.recover();
    const alteration = try edit(&before, 3, .{ .alter = .{ .add = .{ .name = "required", .type = .int64, .nullable = false } } });
    _ = try catalog.admit(alteration, access.policy());
    const result = try catalog.perform(alteration.binding, access.policy());
    try t.expectEqual(.constraint, result.rejected.reason);
    try catalog.recover();
    const at = catalog.store.root.next_lsn;
    try t.expect((try catalog.perform(alteration.binding, access.policy())) == .rejected);
    try t.expect((try catalog.cancel(alteration.binding, access.policy())) == .rejected);
    try t.expectEqual(at, catalog.store.root.next_lsn);
    var after = (try resolve(&catalog, &access, "events")).?;
    defer after.deinit();
    try t.expectEqualDeep(before.table.root, after.table.root);
    try t.expectEqual(@as(u64, 1), after.table.root.live_rows);
    try t.expect(catalog.store.root.pending == null);
}

test "direct catalog missing admitted intent fails closed and a listing rechecks final rights" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const first = try creation(7, 1, "events");
    _ = try catalog.admit(first, access.policy());
    _ = try catalog.perform(first.binding, access.policy());
    access.deny_at = access.calls + 3;
    try t.expectError(error.CatalogDenied, catalog.list(1, null, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    const second = try creation(8, 2, "pending");
    const admitted = try catalog.admit(second, access.policy());
    var key: [96]u8 = undefined;
    try objects.deleteObject(try std.fmt.bufPrint(&key, "catalog-intents/{x}.data", .{&admitted.intent.sha256}));
    const at = catalog.store.root.next_lsn;
    try catalog.recover();
    try t.expectError(error.CatalogIntentMissing, catalog.status(second.binding, access.policy()));
    try t.expectError(error.CatalogIntentMissing, catalog.perform(second.binding, access.policy()));
    try t.expectError(error.CatalogIntentMissing, catalog.cancel(second.binding, access.policy()));
    try t.expectEqual(at, catalog.store.root.next_lsn);
    try t.expect((try resolve(&catalog, &access, "pending")) == null);
    var view = (try resolve(&catalog, &access, "events")).?;
    view.deinit();
}

test "direct catalog recovery rejects a terminal operation reopened in accepted history" {
    const r = @import("DirectCatalogRecords.zig");
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const create = try creation(7, 1, "events");
    const admitted = try catalog.admit(create, access.policy());
    _ = try catalog.cancel(create.binding, access.policy());
    var next = catalog.store.root;
    next.next_lsn += 1;
    const record: r.Record = .{ .definition = p.Growth.current_definition, .previous = catalog.store.chain, .root = next, .action = .{ .operation = admitted } };
    var encoded: [r.max_record_bytes]u8 = undefined;
    encoded[0..8].* = "TCATLOG1".*;
    encoded[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(encoded[40..]);
    try std.json.Stringify.value(record, .{}, &writer);
    _ = try wal.log().append(next.configuration.partition, catalog.store.root.next_lsn, 1, 1, .catalog_ddl, encoded[0 .. 40 + writer.end]);
    try t.expectError(error.InvalidDirectCatalogTransition, catalog.recover());
    try t.expectError(error.CatalogRecoveryRequired, catalog.status(create.binding, access.policy()));
    try t.expectEqual(next.next_lsn, try wal.log().tail(next.configuration.partition));
}

test "direct catalog CREATE can restart and cancel before native registration exists" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{ .missing_table = true };
    const cancelled = try creation(7, 1, "events");
    const pending = try creation(8, 2, "events");
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        _ = try catalog.admit(cancelled, access.policy());
        try t.expect((try catalog.registration(cancelled.binding, access.policy())) != null);
        try t.expect((try catalog.cancel(cancelled.binding, access.policy())) == .cancelled);
        try t.expect((try catalog.registration(cancelled.binding, access.policy())) == null);
        _ = try catalog.admit(pending, access.policy());
        const at = catalog.store.root.next_lsn;
        const required = (try catalog.registration(pending.binding, access.policy())).?;
        try t.expectEqual(@as(u64, 0), required.action.owner);
        try t.expectEqual(@as(u64, 0), required.authorization_revision);
        try t.expect((try catalog.status(pending.binding, access.policy())) == .admitted);
        try t.expect((try resolve(&catalog, &access, "events")) == null);
        try t.expectError(error.CatalogRegistrationRequired, catalog.perform(pending.binding, access.policy()));
        try t.expectEqual(at, catalog.store.root.next_lsn);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    access.missing_table = false;
    try t.expect((try catalog.perform(cancelled.binding, access.policy())) == .cancelled);
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.attachRegistration(pending.binding, access.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    try t.expectEqual(.ready, (try catalog.status(pending.binding, access.policy())).admitted.phase);
    try t.expect((try resolve(&catalog, &access, "events")) == null);
    try t.expect((try catalog.perform(pending.binding, access.policy())) == .committed);
    var view = (try resolve(&catalog, &access, "events")).?;
    defer view.deinit();
    try t.expectEqual(@as(u64, 8), view.table.root.interpretation.object.object);
    try t.expectEqual(@as(u64, 3), view.table.root.partition);
}
