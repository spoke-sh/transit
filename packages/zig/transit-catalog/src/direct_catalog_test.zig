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
    missing_schema: bool = false,
    denied_resource: ?u64 = null,
    denied_metadata: ?u64 = null,
    deny_create: bool = false,
    allocation_binding: ?c.DirectResource.Binding = null,
    allocation_id: ?u64 = null,
    initialization: ?p.DataLifecycle.ResourceInitialization = null,
    native_checks: usize = 0,
    native_deny_at: usize = std.math.maxInt(usize),
    native_retired: bool = false,
    const Context = struct { access: *Access, requested: p.Authorization.Guard };
    fn erased(context: *anyopaque) *Access {
        return @ptrCast(@alignCast(context));
    }
    fn make(context: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !P.Guard {
        if (prerequisite != null) return error.CatalogDenied;
        try requested.validate();
        const result = try allocator.create(Context);
        result.* = .{ .access = erased(context), .requested = requested };
        return .{ .context = result, .acquire = acquire, .release = release };
    }
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const value: *Context = @ptrCast(@alignCast(context));
        value.access.calls += 1;
        if (value.access.calls >= value.access.deny_at) return error.CatalogDenied;
        for (value.requested.requirements) |slot| if (slot) |requirement| {
            if (value.access.deny_create and std.meta.eql(requirement.object, a.reference(profile.initial_schema_authority)) and requirement.privileges & a.create != 0) return error.CatalogDenied;
            if (requirement.object.kind == .resource and requirement.object.id == value.access.denied_resource) return error.CatalogDenied;
            if (value.access.denied_metadata) |id| if (std.meta.eql(requirement.object, a.reference(id))) return error.CatalogDenied;
        };
        if (value.requested.subject.principal() != 1 or value.requested.requirements[0].?.object.id != profile.database) return error.CatalogDenied;
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn registered(context: *anyopaque, kind: a.Kind, id: u64) !?p.Authorization.Object {
        if (kind == .table and erased(context).missing_table) return null;
        if (kind == .schema and id != 1 and erased(context).missing_schema) return null;
        const native: u64 = switch (kind) {
            .database => profile.database,
            .schema => if (id == 1) profile.initial_schema_authority else 20000 + id,
            .table => 100 + id,
        };
        return .{ .reference = a.reference(native), .owner = 0, .registrar = 1, .actions = a.actions(kind), .domain = profile.domain(kind), .binding = if (erased(context).mismatch) @splat(9) else try a.binding(scope, kind, id), .parent = switch (kind) {
            .database => null,
            .schema => a.reference(profile.database),
            .table => a.reference(profile.initial_schema_authority),
        }, .revision = 1 };
    }
    fn policy(self: *Access) D.Policy {
        return .{ .context = self, .subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 1 } }, .make_guard = make, .registered = registered, .native_resource = .{ .context = self, .prepare = prepareAllocation, .allocation = allocation, .make_guard = nativeGuard } };
    }
    fn prepareAllocation(_: *anyopaque, binding_value: c.DirectResource.Binding) !c.DirectResource.Allocation {
        return .{ .sequence = binding_value.operation + 50 };
    }
    fn allocation(context: *anyopaque, binding_value: c.DirectResource.Binding, _: c.DirectResource.Allocation) !?u64 {
        const self = erased(context);
        if (self.allocation_binding) |expected| try expected.requireSame(binding_value);
        return self.allocation_id;
    }
    const NativeContext = struct { access: *Access, underlying: P.Guard, condition: c.DirectResource.Condition };
    fn nativeGuard(context: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard, condition: c.DirectResource.Condition) !P.Guard {
        const value = try allocator.create(NativeContext);
        value.* = .{ .access = erased(context), .underlying = try make(context, allocator, requested, null), .condition = condition };
        return .{ .context = value, .acquire = nativeAcquire, .release = release };
    }
    fn nativeAcquire(context: *anyopaque) !P.Guard.Fence {
        const value: *NativeContext = @ptrCast(@alignCast(context));
        const fence = try value.underlying.acquire(value.underlying.context);
        const self = value.access;
        self.native_checks += 1;
        if (self.native_checks >= self.native_deny_at) return error.CatalogDenied;
        if (value.condition.resource == null) return fence;
        if (try allocation(self, value.condition.binding, value.condition.allocation) != value.condition.resource) return error.NamedResourceAllocationMismatch;
        if (value.condition.initialization) |expected| {
            if (self.native_retired) return error.RetiredResource;
            if (self.initialization == null) return error.NamedResourceNotInitialized;
            if (!std.meta.eql(expected, self.initialization.?)) return error.NamedResourceIdentityConflict;
        }
        return fence;
    }
    fn dataGuard(self: *Access, allocator: std.mem.Allocator, properties: D.Properties, object: u64) !P.Guard {
        const namespace: a.Schema = .{ .scope = scope, .id = 1, .authorization = profile.initial_schema_authority, .name = try a.Name.init("public"), .revision = 1 };
        return make(self, allocator, try a.guard(self.policy().subject, profile, namespace, properties.target(object), .insert), null);
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

test "direct Table recovery hints evict safely and cannot replace current metadata or authority" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    var hint: ?P.RecoveryState = null;
    catalog.options.table_recovery = &hint;
    try catalog.initialize(access.policy());
    for ([_]D.Request{ try creation(7, 1, "events"), try creation(71, 2, "other") }) |create| {
        _ = try catalog.admit(create, access.policy());
        _ = try catalog.perform(create.binding, access.policy());
    }
    for ([_][]const u8{ "events", "events", "other", "events" }, 0..) |name, index| {
        var view = (try resolve(&catalog, &access, name)).?;
        try t.expectEqualStrings(name, view.properties.name.slice());
        try t.expectEqual(@as(u64, if (index == 1) 0 else 1), view.table.recovery_work.replayed_frames);
        view.deinit();
        try t.expect(hint != null);
    }
    var view = (try resolve(&catalog, &access, "events")).?;
    const renamed = try edit(&view, 3, .{ .rename = try a.Name.init("renamed") });
    view.deinit();
    _ = try catalog.admit(renamed, access.policy());
    _ = try catalog.perform(renamed.binding, access.policy());
    try t.expect(try resolve(&catalog, &access, "events") == null);
    var updated = (try resolve(&catalog, &access, "renamed")).?;
    try t.expectEqualStrings("renamed", updated.properties.name.slice());
    updated.deinit();
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, resolve(&catalog, &access, "renamed"));
    access.deny_at = std.math.maxInt(usize);
    hint.?.chain[0] ^= 1;
    try t.expectError(error.InvalidTableHistory, resolve(&catalog, &access, "renamed"));
    try t.expect(hint == null);
    var recovered = (try resolve(&catalog, &access, "renamed")).?;
    defer recovered.deinit();
    try t.expectEqual(recovered.table.root.next_lsn, recovered.table.recovery_work.replayed_frames);
}

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
    {
        var observed = try catalog.observe(t.allocator, 1, view.table.root.interpretation, .{}, access.policy());
        defer observed.deinit();
        try t.expectEqualDeep(view.table.root, observed.view.table.root);
        try t.expectEqual(@as(u8, 0), observed.page.?.count);
        try t.expect(!observed.page.?.more);
        try t.expectEqual(profile.database, observed.authority.database);
        try t.expectEqual(profile.initial_schema_authority, observed.authority.schema);
        try t.expectEqual(@as(u64, 107), observed.authority.table);
        try t.expectEqualDeep(observed.authority, try catalog.currentReadAuthority(view.table.root.interpretation.object, access.policy()));
        var metadata_only = try catalog.observe(t.allocator, 1, view.table.root.interpretation, null, access.policy());
        defer metadata_only.deinit();
        try t.expect(metadata_only.page == null);
        try t.expectEqualDeep(observed.view.table.root, metadata_only.view.table.root);
        const read: c.DirectTableProtocol.CurrentRead = .{ .namespace = 1, .interpretation = view.table.root.interpretation, .expected = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, .selection = .{ .rows = .{ .after = null, .limits = .{} } } };
        var empty = try catalog.readCurrent(t.allocator, read, access.policy());
        defer empty.deinit();
        try t.expectEqualDeep(view.table.root, empty.current.view.table.root);
        try t.expectEqual(@as(u8, 0), empty.selection.rows.count);
        var changed = read;
        changed.interpretation.revision += 1;
        try t.expectError(error.TableDefinitionChanged, catalog.readCurrent(t.allocator, changed, access.policy()));
        changed = read;
        changed.expected.next_lsn += 1;
        try t.expectError(error.TableDataChanged, catalog.readCurrent(t.allocator, changed, access.policy()));
    }
    var stale_access = requested;
    stale_access.target.?.revision += 1;
    try t.expectError(error.TableDefinitionChanged, catalog.checkAccess(stale_access, access.policy()));
    try t.expectError(error.TableDefinitionChanged, catalog.observe(t.allocator, 1, stale_access.target.?, null, access.policy()));
    access.deny_at = access.calls + 5;
    try t.expectError(error.CatalogDenied, catalog.observe(t.allocator, 1, view.table.root.interpretation, .{}, access.policy()));
    access.deny_at = std.math.maxInt(usize);
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
    const table_tail = try wal.log().tail(view.table.root.partition);
    const preview_puts = objects.puts;
    const preview = try catalog.previewRows(request, access.policy());
    try t.expectEqual(.none, preview.reason);
    try t.expectEqualDeep(preview, try catalog.previewRows(request, access.policy()));
    try t.expectEqual(@as(u64, 0), preview.current.row_count);
    try t.expect((try catalog.rowStatus(binding, access.policy())) == .not_observed);
    try t.expect(try c.OperationBinding.lookup(t.allocator, objects.objectStore(), binding.identity) == null);
    access.deny_at = access.calls + 3;
    try t.expectError(error.CatalogDenied, catalog.previewRows(request, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    var stale_rows = request;
    stale_rows.binding.expected_data.?.next_lsn = 0;
    try t.expectEqual(.stale_data, (try catalog.previewRows(stale_rows, access.policy())).reason);
    try t.expectEqualDeep(before, catalog.store.root);
    try t.expectEqual(table_tail, try wal.log().tail(view.table.root.partition));
    try t.expectEqual(preview_puts, objects.puts);
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

fn tokenBinding(objects: s.TransitObjectStore.ObjectStore, operation: u64, token: u8) !c.DirectClientToken.Binding {
    const request = try creation(7, operation, "events");
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var buffer: [4096]u8 = undefined;
    const wire_schema = try c.DirectTableProtocol.Binary.encode(arena.allocator(), try request.intent.action.create.schema.encode(&buffer));
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    var intent = try c.DirectTableIntent.create(t.allocator, connection, .{ .ddl = .{ .binding = request.binding, .namespace = 1, .name = "events", .action = .{ .create = .{ .owner = 0, .schema = wire_schema } } } });
    defer intent.deinit();
    return .{ .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(9), .token = @splat(token) }, .fingerprint = @splat(17), .intent = .{ .table = try c.DirectTableIntentStore.stage(objects, &intent, 1) } };
}

test "direct client token lost reply recovers the original intent on disk without data admission" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var binding: c.DirectClientToken.Binding = undefined;
    var access: Access = .{};
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        binding = try tokenBinding(objects.objectStore(), 55, 1);
        try t.expect(try catalog.clientToken(.{ .lookup = binding.key }, access.policy()) == null);
        catalog.store.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.clientToken(.{ .bind = binding }, access.policy()));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    const receipt = (try catalog.clientToken(.{ .lookup = binding.key }, access.policy())).?;
    try t.expectEqualDeep(binding, receipt.binding);
    try t.expectEqualDeep(p.DataLifecycle.Position{ .partition = 1, .next_lsn = 2 }, receipt.position);
    try t.expectEqual(@as(u64, 1), catalog.store.root.client_token_count);
    try t.expectEqual(.not_observed, try catalog.status(binding.intent.table.binding, access.policy()));
    try t.expect(try catalog.resolve(t.allocator, 1, try .init("events"), access.policy()) == null);
    const root_before = catalog.store.root;
    var competing = binding;
    competing.intent.table.binding.identity.operation = 56;
    competing.intent.table.content.sha256 = @splat(88); // Never staged: retry returns the winner before loading a losing proposal.
    try t.expectEqualDeep(receipt, (try catalog.clientToken(.{ .bind = competing }, access.policy())).?);
    competing.fingerprint[0] ^= 1;
    try t.expectError(error.ClientTokenConflict, catalog.clientToken(.{ .bind = competing }, access.policy()));
    competing = binding;
    competing.key.connection.role = 2;
    competing.intent.table.connection.role = 2;
    try t.expectError(error.DataIdentityConflict, catalog.clientToken(.{ .bind = competing }, access.policy()));
    try t.expectEqualDeep(root_before, catalog.store.root);
    // The recovered binding owns a usable immutable body; no name lookup or
    // replacement operation is needed to admit and finish the original work.
    var original = try c.DirectTableIntentStore.load(t.allocator, objects.objectStore(), receipt.binding.intent.table);
    defer original.deinit();
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    const native = try original.parsed.value.work.ddl.native(scratch.allocator(), try configuration());
    _ = try catalog.admit(native, access.policy());
    try t.expect((try catalog.perform(native.binding, access.policy())) == .committed);
    try t.expectEqualDeep(receipt, (try catalog.clientToken(.{ .bind = binding }, access.policy())).?);
    access.deny_create = true;
    try t.expectError(error.CatalogDenied, catalog.clientToken(.{ .lookup = binding.key }, access.policy()));
}

test "direct client token reserves DDL identity in its control store" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var control = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer control.deinit();
    var data = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer data.deinit();
    var catalog = try D.init(t.allocator, try configuration(), wal.log(), control.objectStore(), wal.log(), data.objectStore(), .{ .resident_pages = 1 });
    defer catalog.deinit();
    try catalog.recover();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try tokenBinding(data.objectStore(), 55, 1);
    _ = try catalog.clientToken(.{ .bind = binding }, access.policy());
    try t.expectEqualDeep(binding.intent.table.binding, (try c.OperationBinding.lookup(t.allocator, control.objectStore(), binding.intent.table.binding.identity)).?);
    try t.expect(try c.OperationBinding.lookup(t.allocator, data.objectStore(), binding.intent.table.binding.identity) == null);
    try t.expectError(error.DataIdentityConflict, catalog.admit(try creation(8, 55, "other"), access.policy()));
    try t.expectEqual(.not_observed, try catalog.status(binding.intent.table.binding, access.policy()));
}

test "direct client token roots reject omitted durable directories and counters" {
    const Records = @import("DirectCatalogRecords.zig");
    const empty = try Records.Root.empty(try configuration());
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, empty, .{});
    defer t.allocator.free(bytes);
    for ([_][]const u8{ "client_tokens", "client_token_count" }) |field| {
        const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, bytes, .{});
        defer parsed.deinit();
        var object = parsed.value;
        try t.expect(object.object.swapRemove(field));
        const missing = try std.json.Stringify.valueAlloc(t.allocator, object, .{});
        defer t.allocator.free(missing);
        try t.expectError(error.MissingField, std.json.parseFromSlice(Records.Root, t.allocator, missing, .{}));
    }
}

test "direct client token quota bounds admission independently of resident pages and never expires identities" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    catalog.options.client_token_quota = 80;
    var access: Access = .{};
    try catalog.initialize(access.policy());
    var binding = try tokenBinding(objects.objectStore(), 55, 0);
    for (0..80) |i| {
        binding.key.token = @splat(@intCast(i));
        _ = try catalog.clientToken(.{ .bind = binding }, access.policy());
    }
    try t.expectEqual(@as(u64, 80), catalog.store.root.client_token_count);
    binding.key.token = @splat(80);
    try t.expectError(error.ClientTokenCapacity, catalog.clientToken(.{ .bind = binding }, access.policy()));
    try catalog.recover();
    for (0..80) |i| {
        binding.key.token = @splat(@intCast(i));
        const found = (try catalog.clientToken(.{ .lookup = binding.key }, access.policy())).?;
        try t.expectEqualDeep(binding, found.binding);
        try t.expectEqual(@as(u64, i + 2), found.position.next_lsn);
        try t.expectEqualDeep(found, (try catalog.clientToken(.{ .bind = binding }, access.policy())).?);
    }
    try t.expectEqual(@as(u64, 81), try wal.log().tail(1));
}

test "direct client token missing content and current denial cannot manufacture a binding" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try tokenBinding(objects.objectStore(), 55, 0);
    var missing = binding;
    missing.intent.table.content.sha256 = @splat(99);
    try t.expectError(error.TableIntentMissing, catalog.clientToken(.{ .bind = missing }, access.policy()));
    try t.expectEqual(@as(u64, 1), try wal.log().tail(1));
    access.deny_create = true;
    try t.expectError(error.CatalogDenied, catalog.clientToken(.{ .bind = binding }, access.policy()));
    try t.expectEqual(@as(u64, 0), catalog.store.root.client_token_count);
    access.deny_create = false;
    // An absent-token observation still requires CONNECT, including its final check.
    access.deny_at = access.calls + 2;
    try t.expectError(error.CatalogDenied, catalog.clientToken(.{ .lookup = binding.key }, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    try t.expect(try catalog.clientToken(.{ .lookup = binding.key }, access.policy()) == null);
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

test "direct storage observations and original flush cuts survive later writes and lost publication replies" {
    const Fixture = struct {
        fn insert(catalog: *D, access: *Access, operation: u64, value: i64) !P.Evidence {
            var view = (try resolve(catalog, access, "events")).?;
            defer view.deinit();
            const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = view.table.root.interpretation.object, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = @splat(3) };
            const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = value } } }};
            const request: s.TableDmlIntent.Request = .{ .binding = binding, .interpretation = view.table.root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(binding.identity, 0), .cells = &cells }, .expect = .absent } }}, .ingestion = .point };
            return (try catalog.applyRows(request, access.policy())).committed;
        }
    };
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
    const first = try Fixture.insert(&catalog, &access, 2, 42);
    const target: D.FlushTarget = .{ .object = create.binding.target, .through = first.outcome.position };
    const pin = try catalog.pinRows(target.object, .{ .scope = scope, .principal = 1, .operation = 100 }, target.through, access.policy());
    const later = try Fixture.insert(&catalog, &access, 3, 43);
    const before = try catalog.inspectStorage(target.object, 2, access.policy());
    try t.expectEqual(@as(u64, 2), before.pending.rows);
    try t.expect(before.pending.complete);
    const puts = objects.puts;
    const partial = try catalog.inspectStorage(target.object, 1, access.policy());
    try t.expectEqual(@as(u64, 1), partial.pending.rows);
    try t.expect(!partial.pending.complete);
    try t.expectEqual(before.position, partial.position);
    try t.expectEqual(puts, objects.puts);
    access.denied_metadata = 107;
    try t.expectError(error.CatalogDenied, catalog.inspectStorage(target.object, 1, access.policy()));
    try t.expectError(error.CatalogDenied, catalog.flushStorage(target, access.policy()));
    access.denied_metadata = null;
    access.deny_at = access.calls + 3; // Revoke after initial scope checks.
    try t.expectError(error.CatalogDenied, catalog.flushStorage(target, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    try t.expectEqualDeep(before, try catalog.inspectStorage(target.object, 2, access.policy()));
    var wrong = target;
    wrong.through.partition += 1;
    try t.expectError(error.InvalidTableBasis, catalog.flushStorage(wrong, access.policy()));
    wrong = target;
    wrong.through.next_lsn = before.position.next_lsn + 1;
    try t.expectError(error.InvalidTableBasis, catalog.flushStorage(wrong, access.policy()));
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.flushStorage(target, access.policy()));
    catalog.lose_table_reply = false;
    // A fresh catalog reconstructs current Table acceptance. The saved cut
    // remains complete even though the later row is still WAL-backed.
    var recovered = try owner(&wal, &objects);
    defer recovered.deinit();
    const moved = try recovered.inspectStorage(target.object, 2, access.policy());
    try t.expectEqual(@as(u64, 1), moved.pending.rows);
    try t.expect(moved.pending.complete and moved.pending.oldest_lsn.? >= target.through.next_lsn);
    try t.expectEqual(before.changed_lsn, moved.changed_lsn);
    try t.expectEqual(before.live_rows, moved.live_rows);
    const after_puts = objects.puts;
    const repeated = try recovered.flushStorage(target, access.policy());
    try t.expect(repeated.complete);
    try t.expectEqualDeep(moved, repeated.observed);
    try t.expectEqual(after_puts, objects.puts);
    try t.expectEqualDeep(first, (try recovered.rowStatus(first.binding, access.policy())).committed);
    try t.expectEqualDeep(later, (try recovered.rowStatus(later.binding, access.policy())).committed);
    var original = try recovered.scanRows(t.allocator, target.object, pin, null, .{}, access.policy());
    defer original.deinit();
    try t.expectEqual(@as(u8, 1), original.count);
    try t.expectEqual(@as(i128, 42), original.rows[0].?.row().cells[0].value.atom.signed);
}

test "maintenance discovery bounds a growing catalog pass and rechecks current authority" {
    const Physical = struct {
        calls: usize = 0,
        deny_at: ?usize = null,
        held: bool = false,
        fn acquire(raw: *anyopaque) !P.Guard.Fence {
            const self: *@This() = @ptrCast(@alignCast(raw));
            try t.expect(!self.held);
            self.calls += 1;
            if (self.calls == self.deny_at) return error.Forbidden;
            self.held = true;
            return .{ .writer_epoch = 1, .policy_epoch = 1 };
        }
        fn release(raw: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            std.debug.assert(self.held);
            self.held = false;
        }
        fn guard(self: *@This()) P.Guard {
            return .{ .context = self, .acquire = acquire, .release = release };
        }
        fn create(catalog: *D, access: *Access, object: u64) !void {
            var buffer: [32]u8 = undefined;
            const request = try creation(object, object, try std.fmt.bufPrint(&buffer, "table_{d}", .{object}));
            _ = try catalog.admit(request, access.policy());
            _ = try catalog.perform(request.binding, access.policy());
        }
    };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    var physical: Physical = .{};
    var cursor: D.MaintenanceCursor = .{};
    try t.expectEqualDeep(D.MaintenanceSelection{ .object = null, .pass_complete = true }, try catalog.maintenanceNext(&cursor, physical.guard()));
    try catalog.initialize(access.policy());
    for (100..119) |object| try Physical.create(&catalog, &access, object);
    try t.expect(@sizeOf(D.MaintenanceCursor) <= 32);
    for (100..119) |object| {
        const before = catalog.store.root;
        const puts = objects.puts;
        const selection = try catalog.maintenanceNext(&cursor, physical.guard());
        try t.expectEqual(@as(?u64, object), selection.object);
        try t.expectEqual(object == 118, selection.pass_complete);
        var view = (try catalog.maintenanceOpen(t.allocator, object, physical.guard())).?;
        defer view.deinit();
        try t.expectEqual(object, view.table.root.interpretation.object.object);
        try t.expectEqualDeep(before, catalog.store.root);
        try t.expectEqual(puts, objects.puts);
        // New high IDs never extend this pass. A low ID waits for the next
        // pass rather than requiring an ever-growing resident pending queue.
        try Physical.create(&catalog, &access, object + 1000);
        if (object == 100) try Physical.create(&catalog, &access, 10);
    }
    try t.expectEqualDeep(D.MaintenanceCursor{}, cursor);
    for ([_]usize{ 1, 2 }) |offset| {
        physical.deny_at = physical.calls + offset;
        try t.expectError(error.Forbidden, catalog.maintenanceNext(&cursor, physical.guard()));
        try t.expectEqualDeep(D.MaintenanceCursor{}, cursor);
    }
    physical.deny_at = null;
    try t.expectEqual(@as(?u64, 10), (try catalog.maintenanceNext(&cursor, physical.guard())).object);
    try t.expectEqual(@as(?u64, 1118), cursor.through);
    // Reconstruct from the accepted log, with no retained owner or cursor.
    var restarted = try owner(&wal, &objects);
    defer restarted.deinit();
    var fresh: D.MaintenanceCursor = .{};
    try t.expectEqual(@as(?u64, 10), (try restarted.maintenanceNext(&fresh, physical.guard())).object);
    physical.deny_at = physical.calls + 2;
    try t.expectError(error.Forbidden, restarted.maintenanceOpen(t.allocator, 10, physical.guard()));
    physical.deny_at = null;
    cursor = .{ .after = 10 };
    try t.expectError(error.InvalidMaintenanceCursor, catalog.maintenanceNext(&cursor, physical.guard()));
    try t.expect(!physical.held);
}

// This seeded schedule uses volatile log/object adapters. It exercises the real
// catalog state machine and reconstruction, not disk or provider durability.
test "simulation: direct catalog admission, publication and original receipts under current policy" {
    var random = std.Random.DefaultPrng.init(t.random_seed);
    const rng = random.random();
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const Accepted = struct { request: D.Request, outcome: D.Observation };
    var accepted: std.ArrayList(Accepted) = .empty;
    defer accepted.deinit(t.allocator);
    for (0..40) |round| {
        var name_buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buffer, "item-{d}", .{round});
        const prior = if (round % 4 == 0) null else accepted.items[4 * rng.uintLessThan(usize, (round + 3) / 4)].request;
        const request = try creation(if (round % 4 == 2) prior.?.binding.target.object else 100 + round, 1000 + round, if (round % 4 == 1) prior.?.intent.name.slice() else name);
        const before = catalog.store.root;
        const appends = wal.appends;
        const puts = objects.puts;
        access.deny_create = true;
        try t.expectError(error.CatalogDenied, catalog.admit(request, access.policy()));
        try t.expectEqualDeep(before, catalog.store.root);
        try t.expectEqual(appends, wal.appends);
        try t.expectEqual(puts, objects.puts);
        access.deny_create = false;

        const lost_admission = rng.boolean();
        catalog.store.lose_reply = lost_admission;
        if (lost_admission) try t.expectError(error.LostAcknowledgement, catalog.admit(request, access.policy())) else _ = try catalog.admit(request, access.policy());
        catalog.store.lose_reply = false;
        const replace = rng.boolean();
        if (replace) {
            catalog.deinit();
            catalog = try owner(&wal, &objects);
        }
        var outcome = try catalog.status(request.binding, access.policy());
        const lost_publication = rng.boolean();
        if (round % 4 == 0 or round % 4 == 3) {
            try t.expect(outcome == .admitted);
            try t.expect(try resolve(&catalog, &access, name) == null);
            const admitted_at = catalog.store.root.next_lsn;
            _ = try catalog.admit(request, access.policy());
            try t.expectEqual(admitted_at, catalog.store.root.next_lsn);
            access.deny_create = true;
            try t.expectError(error.CatalogDenied, catalog.perform(request.binding, access.policy()));
            try t.expectEqual(admitted_at, catalog.store.root.next_lsn);
            access.deny_create = false;
            if (round % 4 == 3) {
                outcome = try catalog.cancel(request.binding, access.policy());
                try t.expect(outcome == .cancelled);
                try t.expect(try resolve(&catalog, &access, name) == null);
            } else {
                catalog.lose_table_reply = lost_publication;
                if (lost_publication) try t.expectError(error.LostAcknowledgement, catalog.perform(request.binding, access.policy())) else _ = try catalog.perform(request.binding, access.policy());
                catalog.lose_table_reply = false;
                outcome = try catalog.status(request.binding, access.policy());
                try t.expect(outcome == .committed);
                try t.expectEqual(@as(u64, 1), outcome.committed.outcome.position.next_lsn);
                try t.expectEqual(@as(u64, 1), outcome.committed.resulting.interpretation.revision);
                try t.expectEqualDeep(outcome, try catalog.settle(request.binding, access.policy()));
                access.denied_metadata = 100 + request.binding.target.object;
                try t.expectError(error.CatalogDenied, resolve(&catalog, &access, name));
                access.denied_metadata = null;
            }
        } else {
            try t.expect(outcome == .rejected);
            const reason: @TypeOf(outcome.rejected.reason) = if (round % 4 == 1) .name_conflict else .object_conflict;
            try t.expectEqual(reason, outcome.rejected.reason);
        }
        try accepted.append(t.allocator, .{ .request = request, .outcome = outcome });
        const replay = accepted.items[rng.uintLessThan(usize, accepted.items.len)];
        access.deny_create = true;
        try t.expectError(error.CatalogDenied, catalog.status(replay.request.binding, access.policy()));
        access.deny_create = false;
        catalog.deinit();
        catalog = try owner(&wal, &objects);
        const replay_at = catalog.store.root.next_lsn;
        try t.expectEqualDeep(replay.outcome, try catalog.status(replay.request.binding, access.policy()));
        try t.expectEqualDeep(replay.outcome, try catalog.perform(replay.request.binding, access.policy()));
        try t.expectEqual(replay_at, catalog.store.root.next_lsn);
        var altered = replay.request;
        altered.intent.name = try a.Name.init("changed");
        altered.binding.intent = try altered.intent.digest(t.allocator);
        try t.expectError(error.DataIdentityConflict, catalog.admit(altered, access.policy()));
        var after: ?s.TreeStore.pages.Key = null;
        var count: usize = 0;
        while (true) {
            const page = try catalog.list(1, after, access.policy());
            try t.expectEqual(.independent, page.consistency);
            try t.expectEqual(replay_at, page.directory_position.next_lsn);
            for (page.entries) |slot| if (slot) |item| {
                const expected = accepted.items[count * 4].request;
                try t.expectEqual(expected.binding.target.object, item.interpretation.object.object);
                try t.expectEqualStrings(expected.intent.name.slice(), item.name.slice());
                count += 1;
            };
            after = page.next orelse break;
        }
        try t.expectEqual((round / 4) + 1, count);
        if (t.environ.containsConstant("TRANSIT_SIMULATION_TRACE")) std.debug.print("SIMULATION {{\"domain\":\"catalog\",\"round\":{d},\"outcome\":\"{s}\",\"lost_admission\":{},\"lost_publication\":{},\"replacement\":{},\"visible\":{d},\"directory_lsn\":{d}}}\n", .{ round, @tagName(outcome), lost_admission, lost_publication, replace, count, replay_at });
    }
    // A real continuation cannot combine pages across catalog publication.
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const inspection = c.DirectCatalogInspection;
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    const first = try catalog.list(1, null, access.policy());
    const key = first.next orelse return error.TestUnexpectedResult;
    const cursor = (try inspection.continuation(arena.allocator(), connection, .{ .tables = 1 }, null, first.directory_position, std.mem.readInt(u64, key.data[0..8], .big))).?;
    const more = try creation(999, 9999, "additional");
    _ = try catalog.admit(more, access.policy());
    const next = try catalog.list(1, key, access.policy());
    try t.expectError(error.CatalogObservationChanged, inspection.continuation(arena.allocator(), connection, .{ .tables = 1 }, cursor, next.directory_position, null));
}

fn dependencyBinding(source: p.DataLifecycle.Definition, operation: u64, dependent: u64) c.DirectDependency.Binding {
    return .{
        .definition = p.Growth.current_definition,
        .connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null },
        .operation = operation,
        .edge = .{
            .source = source,
            .dependent = .{ .kind = .captured, .interpretation = .{
                .object = .{ .scope = .{ .realm = 1, .resource = 11, .catalog = 8 }, .branch = 1, .object = dependent },
                .revision = 1,
                .digest = @splat(2),
            } },
            .privileges = a.select,
        },
        .action = .register,
        .authority = .dependent,
    };
}

test "direct dependency lost replies retain exact DROP protection across restart and name replacement" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var binding: c.DirectDependency.Binding = undefined;
    var access: Access = .{};
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        const create = try creation(7, 1, "events");
        _ = try catalog.admit(create, access.policy());
        _ = try catalog.perform(create.binding, access.policy());
        _ = try catalog.settle(create.binding, access.policy());
        var view = (try resolve(&catalog, &access, "events")).?;
        defer view.deinit();
        binding = dependencyBinding(view.table.root.interpretation, 2, 99);
        catalog.store.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.dependencyOperation(binding, .accept, access.policy()));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    const accepted = (try catalog.dependencyOperation(binding, .inspect, access.policy())).outcome;
    try t.expect(accepted.phase == .applied and accepted.changed);
    const membership_root = catalog.store.root;
    const membership = try catalog.dependencyState(binding.edge, access.policy());
    try t.expect(membership.present);
    try t.expectEqualDeep(binding.edge, membership.edge);
    try t.expectEqualDeep(membership_root, catalog.store.root);
    access.denied_resource = binding.edge.dependent.interpretation.object.scope.resource;
    try t.expectError(error.CatalogDenied, catalog.dependencyState(binding.edge, access.policy()));
    access.denied_resource = null;
    try t.expectEqualDeep(accepted, (try catalog.dependencyOperation(binding, .accept, access.policy())).outcome);
    var changed = binding;
    changed.edge.dependent.interpretation.revision += 1;
    try t.expectError(error.DataIdentityConflict, catalog.dependencyOperation(changed, .accept, access.policy()));
    try t.expectError(error.DataIdentityConflict, catalog.preview(try creation(8, 2, "replacement"), access.policy()));
    var view = (try resolve(&catalog, &access, "events")).?;
    defer view.deinit();
    const blocked = try edit(&view, 3, .drop);
    try t.expectEqual(.dependency, (try catalog.preview(blocked, access.policy())).reason);
    try t.expectEqual(.dependency, (try catalog.admit(blocked, access.policy())).reason);
    try t.expect((try catalog.perform(blocked.binding, access.policy())) == .rejected);
    const rename = try edit(&view, 4, .{ .rename = try a.Name.init("renamed") });
    _ = try catalog.admit(rename, access.policy());
    _ = try catalog.perform(rename.binding, access.policy());
    _ = try catalog.settle(rename.binding, access.policy());
    changed = binding;
    changed.operation = 5;
    try t.expectEqual(.stale_definition, (try catalog.dependencyOperation(changed, .accept, access.policy())).outcome.reason);
    const graph = try catalog.dependencyPage(.{ .dependents = binding.edge.source.object }, null, .dependent, access.policy());
    try t.expectEqualDeep(binding.edge, graph.entries[0].?);
    try t.expect(graph.entries[1] == null and graph.next == null);
    var removal = binding;
    removal.operation = 6;
    removal.action = .remove;
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.dependencyOperation(removal, .accept, access.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    try t.expect((try catalog.dependencyOperation(removal, .inspect, access.policy())).outcome.changed);
    try t.expectEqualDeep(accepted, (try catalog.dependencyOperation(binding, .accept, access.policy())).outcome);
    try t.expect((try catalog.dependencyPage(.{ .dependents = binding.edge.source.object }, null, .dependent, access.policy())).entries[0] == null);
    const removed = try catalog.dependencyState(binding.edge, access.policy());
    try t.expect(!removed.present and removed.position.next_lsn > membership.position.next_lsn);
    var renamed = (try resolve(&catalog, &access, "renamed")).?;
    defer renamed.deinit();
    const drop = try edit(&renamed, 7, .drop);
    _ = try catalog.admit(drop, access.policy());
    try t.expect((try catalog.perform(drop.binding, access.policy())) == .committed);
    const replacement = try creation(8, 8, "renamed");
    _ = try catalog.admit(replacement, access.policy());
    try t.expect((try catalog.perform(replacement.binding, access.policy())) == .committed);
    try t.expect((try catalog.dependencyPage(.{ .dependencies = binding.edge.dependent.interpretation.object }, null, .dependent, access.policy())).entries[0] == null);
    try t.expectEqualDeep(accepted, (try catalog.dependencyOperation(binding, .inspect, access.policy())).outcome);
}

test "direct dependency cancellation and publication fence preserve original registration intent" {
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
    var binding = dependencyBinding(view.table.root.interpretation, 2, 99);
    const cancelled = (try catalog.dependencyOperation(binding, .cancel, access.policy())).outcome;
    try t.expect(cancelled.phase == .cancelled and !cancelled.changed);
    try t.expectEqualDeep(cancelled, (try catalog.dependencyOperation(binding, .accept, access.policy())).outcome);
    binding.operation = 3;
    const root = catalog.store.root;
    access.deny_at = access.calls + 3;
    try t.expectError(error.CatalogDenied, catalog.dependencyOperation(binding, .accept, access.policy()));
    try t.expectEqualDeep(root, catalog.store.root);
    access.deny_at = std.math.maxInt(usize);
    try t.expect((try catalog.dependencyOperation(binding, .inspect, access.policy())) == .not_observed);
    try t.expect((try catalog.dependencyOperation(binding, .accept, access.policy())).outcome.changed);
    binding.operation = 4;
    try t.expect(!(try catalog.dependencyOperation(binding, .accept, access.policy())).outcome.changed);
    access.denied_resource = 11;
    try t.expectError(error.CatalogDenied, catalog.dependencyOperation(binding, .inspect, access.policy()));
    const hidden = try catalog.dependencyPage(.{ .dependents = binding.edge.source.object }, null, .dependent, access.policy());
    try t.expect(hidden.entries[0] == null);
    // Redaction never makes the source unprotected.
    const drop = try edit(&view, 5, .drop);
    try t.expectEqual(.dependency, (try catalog.preview(drop, access.policy())).reason);
    access.denied_resource = null;
    var removal = binding;
    removal.operation = 6;
    removal.action = .remove;
    _ = try catalog.dependencyOperation(removal, .accept, access.policy());
    const admitted_drop = try edit(&view, 7, .drop);
    _ = try catalog.admit(admitted_drop, access.policy());
    binding.operation = 8;
    try t.expectEqual(.source_busy, (try catalog.dependencyOperation(binding, .accept, access.policy())).outcome.reason);
    try t.expect((try catalog.perform(admitted_drop.binding, access.policy())) == .committed);
}

test "direct dependency pages grow beyond cache with redaction and exact continuation basis" {
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
    for (0..41) |i| {
        var binding = dependencyBinding(view.table.root.interpretation, 2 + i, 99 + i);
        if (i % 2 == 0) binding.edge.dependent.interpretation.object.scope.resource = 12;
        _ = try catalog.dependencyOperation(binding, .accept, access.policy());
    }
    try catalog.recover();
    access.denied_resource = 11;
    const puts = objects.puts;
    const root = catalog.store.root;
    var cursor: ?c.DirectDependency.Cursor = null;
    var count: usize = 0;
    var rounds: usize = 0;
    while (true) {
        const page = try catalog.dependencyPage(.{ .dependents = view.table.root.interpretation.object }, cursor, .dependent, access.policy());
        rounds += 1;
        try t.expect(rounds <= 12);
        for (page.entries) |slot| if (slot) |edge| {
            try t.expectEqual(@as(u64, 12), edge.dependent.interpretation.object.scope.resource);
            count += 1;
        };
        cursor = page.next;
        if (cursor == null) break;
    }
    try t.expectEqual(@as(usize, 21), count);
    try t.expect(rounds > 8);
    try t.expectEqualDeep(root, catalog.store.root);
    try t.expectEqual(puts, objects.puts);
    const first = try catalog.dependencyPage(.{ .dependents = view.table.root.interpretation.object }, null, .dependent, access.policy());
    access.denied_resource = null;
    _ = try catalog.dependencyOperation(dependencyBinding(view.table.root.interpretation, 50, 150), .accept, access.policy());
    try t.expectError(error.CatalogObservationChanged, catalog.dependencyPage(.{ .dependents = view.table.root.interpretation.object }, first.next, .dependent, access.policy()));
}

test "current Table capture freezes once across lost replies, mutation, restart and definition changes" {
    const Fixture = struct {
        fn insert(catalog: *D, access: *Access, operation: u64, key: i64) !void {
            var view = (try resolve(catalog, access, "events")).?;
            defer view.deinit();
            const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = view.table.root.interpretation.object, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, .intent = @splat(3) };
            const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = key } } }};
            const request: s.TableDmlIntent.Request = .{ .binding = binding, .interpretation = view.table.root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = .{ .origin = view.table.root.partition, .operation = operation, .ordinal = 0 }, .cells = &cells }, .expect = .absent } }}, .ingestion = .point };
            _ = try catalog.admitRows(request, access.policy());
            try t.expect((try catalog.performRows(binding, access.policy())) == .committed);
        }
    };
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var interpretation: p.DataLifecycle.Definition = undefined;
    var minimum: p.DataLifecycle.Position = undefined;
    var retained: P.SnapshotHandle = undefined;
    const capture: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 100 };
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        const create = try creation(7, 1, "events");
        _ = try catalog.admit(create, access.policy());
        _ = try catalog.perform(create.binding, access.policy());
        _ = try catalog.settle(create.binding, access.policy());
        var view = (try resolve(&catalog, &access, "events")).?;
        defer view.deinit();
        interpretation = view.table.root.interpretation;
        minimum = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn };
        try Fixture.insert(&catalog, &access, 2, 42);
        access.deny_at = access.calls + 1;
        try t.expectError(error.CatalogDenied, catalog.captureRowsDefined(interpretation, capture, minimum, access.policy()));
        access.deny_at = std.math.maxInt(usize);
        try t.expect((try catalog.pinState(interpretation.object, capture, access.policy())).handle == null);
        catalog.lose_table_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.captureRowsDefined(interpretation, capture, minimum, access.policy()));
        catalog.lose_table_reply = false;
        retained = (try catalog.pinState(interpretation.object, capture, access.policy())).handle.?;
        try Fixture.insert(&catalog, &access, 3, 43);
    }
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try t.expectEqualDeep(retained, try catalog.captureRowsDefined(interpretation, capture, minimum, access.policy()));
        var snapshot = try catalog.snapshotDefinition(t.allocator, interpretation.object, retained, access.policy());
        defer snapshot.deinit();
        try t.expectEqual(@as(u64, 1), snapshot.root.live_rows);
        try t.expect(snapshot.root.next_lsn > minimum.next_lsn);
        const before_retry = try wal.log().tail(minimum.partition);
        try t.expectEqualDeep(retained, try catalog.captureRowsDefined(interpretation, capture, minimum, access.policy()));
        try t.expectEqual(before_retry, try wal.log().tail(minimum.partition));
        var view = (try resolve(&catalog, &access, "events")).?;
        defer view.deinit();
        try t.expectEqual(@as(u64, 2), view.table.root.live_rows);
        const changed = try edit(&view, 4, .{ .alter = .{ .add = .{ .name = "extra", .type = .int64 } } });
        _ = try catalog.admit(changed, access.policy());
        _ = try catalog.perform(changed.binding, access.policy());
        _ = try catalog.settle(changed.binding, access.policy());
        try t.expectEqualDeep(retained, try catalog.captureRowsDefined(interpretation, capture, minimum, access.policy()));
        var other = capture;
        other.operation += 1;
        try t.expectError(error.TableDefinitionChanged, catalog.captureRowsDefined(interpretation, other, minimum, access.policy()));
        try catalog.releaseRows(interpretation.object, retained, access.policy());
        try t.expectError(error.TableSnapshotReleased, catalog.captureRowsDefined(interpretation, capture, minimum, access.policy()));
        try catalog.recover();
        try t.expectError(error.TableSnapshotReleased, catalog.captureRowsDefined(interpretation, capture, minimum, access.policy()));
    }
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

const ObservedCatalogLog = struct {
    inner: s.TransitLog.Log,
    reads: usize = 0,
    lose_append: bool = false,
    fn get(raw: *anyopaque) *@This() {
        return @ptrCast(@alignCast(raw));
    }
    fn log(self: *@This()) s.TransitLog.Log {
        return .{ .context = self, .vtable = &.{ .append = append, .read = read, .tail = tail, .trim = trim, .fence = fence } };
    }
    fn append(raw: *anyopaque, id: u64, expected: ?u64, writer: u64, policy: u64, kind: s.TransitLog.FrameKind, payload: []const u8) !s.TransitLog.AppendReceipt {
        const self = get(raw);
        const receipt = try self.inner.append(id, expected, writer, policy, kind, payload);
        if (self.lose_append) return error.LostAcknowledgement;
        return receipt;
    }
    fn read(raw: *anyopaque, allocator: std.mem.Allocator, id: u64, from: u64, count: usize) !s.TransitLog.Log.OwnedBatch {
        const self = get(raw);
        self.reads += 1;
        return self.inner.read(allocator, id, from, count);
    }
    fn tail(raw: *anyopaque, id: u64) !u64 {
        return get(raw).inner.tail(id);
    }
    fn trim(raw: *anyopaque, id: u64, before: u64) !void {
        try get(raw).inner.trim(id, before);
    }
    fn fence(raw: *anyopaque, id: u64, writer: u64, policy: u64) !void {
        try get(raw).inner.fence(id, writer, policy);
    }
};

test "catalog retained roots visit complete control history at a fixed cut" {
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
    const request = try creation(7, 1, "retained");
    _ = try catalog.admit(request, access.policy());
    _ = try catalog.perform(request.binding, access.policy());
    for (10..20) |id| {
        const pending = try creation(id, id, "cancelled");
        _ = try catalog.admit(pending, access.policy());
        _ = try catalog.cancel(pending.binding, access.policy());
    }
    const cut = try catalog.recoveryState();
    var roots = try c.DirectCatalogRoots.init(cut);
    var observed: ObservedCatalogLog = .{ .inner = wal.log() };
    var records: u64 = 0;
    var earlier_objects: bool = false;
    while (try roots.next(t.allocator, observed.log())) |record| {
        records += 1;
        try t.expectEqual(records, record.root.next_lsn);
        if (record.root.objects) |reference| {
            _ = try catalog.store.index.load(reference);
            if (!std.meta.eql(record.root.objects, cut.root.objects)) earlier_objects = true;
        }
        if (records == 2) {
            // The cursor owns its chain/root, survives serialization, and does
            // not absorb a later accepted control transition into its old cut.
            const bytes = try std.json.Stringify.valueAlloc(t.allocator, roots, .{});
            defer t.allocator.free(bytes);
            const parsed = try std.json.parseFromSlice(c.DirectCatalogRoots, t.allocator, bytes, .{});
            defer parsed.deinit();
            roots = parsed.value;
            _ = try catalog.admit(try creation(30, 30, "later"), access.policy());
        }
    }
    try t.expectEqual(cut.root.next_lsn, records);
    try t.expectEqual(records, observed.reads);
    try t.expect(earlier_objects);
    try t.expect(catalog.store.root.next_lsn > roots.next_lsn);
    try t.expect(try roots.next(t.allocator, observed.log()) == null);
}

test "catalog retained roots reject changed cuts and missing history without cursor progress" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const cut = try catalog.recoveryState();
    for (0..3) |scenario| {
        var changed = cut;
        switch (scenario) {
            0 => changed.chain[0] ^= 1,
            1 => changed.root.next_partition += 1,
            else => changed.root.configuration.scope.catalog += 1,
        }
        var roots = try c.DirectCatalogRoots.init(changed);
        const before = roots;
        try t.expectError(error.InvalidDirectCatalogHistory, roots.next(t.allocator, wal.log()));
        try t.expectEqualDeep(before, roots);
    }
    var absent = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer absent.deinit();
    var roots = try c.DirectCatalogRoots.init(cut);
    const before = roots;
    try t.expectError(error.CatalogHistoryMissing, roots.next(t.allocator, absent.log()));
    try t.expectEqualDeep(before, roots);
    try wal.log().trim(cut.root.configuration.partition, 1);
    try t.expectError(error.WalHistoryTrimmed, roots.next(t.allocator, wal.log()));
    try t.expectEqualDeep(before, roots);
}

test "catalog directory walk retains seed declarations across bounded page paths" {
    const r = @import("DirectCatalogRecords.zig");
    const ObservedIndex = struct {
        index: *s.TreeStore,
        loads: usize = 0,
        pub fn load(self: *@This(), reference: s.TreeStore.pages.Reference) !s.TreeStore.pages.Page {
            self.loads += 1;
            return self.index.load(reference);
        }
    };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const request = try creation(7, 1, "seed");
    _ = try catalog.admit(request, access.policy());
    _ = try catalog.perform(request.binding, access.policy());
    var basis = catalog.store.root;
    var reference = basis.objects.?;
    try catalog.store.index.begin(64 * 1024 * 1024);
    defer catalog.store.index.end();
    for (100..173) |id| {
        const entry: r.Entry = .{ .object = id, .partition = id, .seed = null, .resource = null };
        reference = try catalog.store.tree().put(reference, try r.idKey(id), try r.pageValue(entry));
    }
    basis.next_partition = 173;
    var index: ObservedIndex = .{ .index = &catalog.store.index };
    var walk = try c.DirectCatalogWalk.init(basis, .{ .reference = reference, .kind = .objects });
    try t.expect(@sizeOf(c.DirectCatalogWalk) < 8 * 1024);
    var seeds: usize = 0;
    var page_count: usize = 0;
    while (true) {
        const before = index.loads;
        const edge = try walk.next(t.allocator, &index);
        try t.expect(index.loads - before <= c.DirectCatalogWalk.max_depth + 1);
        switch (edge orelse break) {
            .page => page_count += 1,
            .declaration => |seed| {
                var declaration = try s.TableDeclaration.load(t.allocator, objects.objectStore(), seed);
                defer declaration.deinit();
                try t.expectEqual(@as(u64, 7), seed.interpretation.object.object);
                seeds += 1;
            },
        }
    }
    try t.expectEqual(@as(usize, 1), seeds);
    try t.expect(page_count > 8);
    var skip = try c.DirectCatalogWalk.init(basis, .{ .reference = reference, .kind = .objects });
    try t.expectError(error.InvalidDirectCatalogHistory, skip.skip());
    try t.expect((try skip.next(t.allocator, &index)).? == .page);
    try skip.skip();
    try t.expect(try skip.next(t.allocator, &index) == null);

    // A typed object directory must not reinterpret a mismatched object key.
    const foreign: r.Entry = .{ .object = 99, .partition = 99, .seed = null, .resource = null };
    const invalid = try catalog.store.tree().put(null, try r.idKey(98), try r.pageValue(foreign));
    var corrupt = try c.DirectCatalogWalk.init(basis, .{ .reference = invalid, .kind = .objects });
    try t.expect((try corrupt.next(t.allocator, &index)).? == .page);
    const before = corrupt;
    try t.expectError(error.InvalidDirectCatalogEntry, corrupt.next(t.allocator, &index));
    try t.expectEqualDeep(before, corrupt);
}

test "direct catalog recovery reuses a validated prefix and recovers an uncertain successor" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var observed: ObservedCatalogLog = .{ .inner = wal.log() };
    var access: Access = .{};
    const known = blk: {
        // Destroy the original request owner and allocator before reuse.
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        var catalog = try D.init(arena.allocator(), try configuration(), observed.log(), objects.objectStore(), wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
        defer catalog.deinit();
        try catalog.recover();
        try catalog.initialize(access.policy());
        for (1..10) |id| {
            const request = try creation(id, id, "released");
            _ = try catalog.admit(request, access.policy());
            _ = try catalog.cancel(request.binding, access.policy());
        }
        break :blk try catalog.recoveryState();
    };
    try t.expectEqual(@as(u64, 19), known.root.next_lsn);
    var catalog = try D.init(t.allocator, try configuration(), observed.log(), objects.objectStore(), wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer catalog.deinit();
    observed.reads = 0;
    try catalog.recover();
    const full_reads = observed.reads;
    // Transition validation may also read an earlier referenced operation.
    try t.expect(full_reads >= known.root.next_lsn);
    observed.reads = 0;
    try catalog.recoverSince(known);
    try t.expectEqual(@as(usize, 1), observed.reads);
    try t.expectEqualDeep(known, try catalog.recoveryState());
    const request = try creation(20, 20, "uncertain");
    observed.lose_append = true;
    try t.expectError(error.LostAcknowledgement, catalog.admit(request, access.policy()));
    try t.expectError(error.CatalogRecoveryRequired, catalog.recoveryState());
    observed.lose_append = false;
    observed.reads = 0;
    try catalog.recoverSince(known);
    try t.expectEqual(@as(usize, 2), observed.reads);
    std.debug.print("Catalog recovery: {d} full log reads, one cached-boundary read, two reads after an uncertain append.\n", .{full_reads});
    try t.expectEqual(@as(u64, 20), catalog.store.root.next_lsn);
    try t.expect((try catalog.status(request.binding, access.policy())) == .admitted);
    const appends = wal.appends;
    _ = try catalog.admit(request, access.policy());
    try t.expectEqual(appends, wal.appends);
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, catalog.status(request.binding, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    // A replacement owner still validates the whole history from its beginning.
    var replacement = try owner(&wal, &objects);
    defer replacement.deinit();
    try t.expectEqualDeep(try catalog.recoveryState(), try replacement.recoveryState());
    try t.expect((try replacement.status(request.binding, access.policy())) == .admitted);
}

test "direct catalog recovery rejects substituted cached boundaries and missing current roots" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const known = try catalog.recoveryState();
    var changed = known;
    changed.chain[0] ^= 1;
    try t.expectError(error.InvalidDirectCatalogHistory, catalog.recoverSince(changed));
    try t.expectError(error.CatalogRecoveryRequired, catalog.recoveryState());
    changed = known;
    changed.root.next_partition += 1;
    try t.expectError(error.InvalidDirectCatalogHistory, catalog.recoverSince(changed));
    changed = known;
    changed.root.configuration.scope.catalog += 1;
    try t.expectError(error.InvalidDirectCatalogHistory, catalog.recoverSince(changed));
    var absent = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer absent.deinit();
    var shortened = try owner(&absent, &objects);
    defer shortened.deinit();
    try t.expectError(error.CatalogHistoryMissing, shortened.recoverSince(known));
    try catalog.recoverSince(known);
    const reference = known.root.schemas.?;
    for (objects.objects.items) |item| if (std.mem.eql(u8, &item.sha256, &reference.location)) {
        const key_copy = try t.allocator.dupe(u8, item.key);
        defer t.allocator.free(key_copy);
        try objects.deleteObject(key_copy);
        break;
    };
    try t.expectError(error.MissingDataIndexObject, catalog.recoverSince(known));
    try t.expectError(error.CatalogRecoveryRequired, catalog.recoveryState());
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
    const known = try catalog.recoveryState();
    var next = catalog.store.root;
    next.next_lsn += 1;
    const record: r.Record = .{ .definition = p.Growth.current_definition, .previous = catalog.store.chain, .root = next, .action = .{ .operation = admitted } };
    var encoded: [r.max_record_bytes]u8 = undefined;
    encoded[0..8].* = "TCATLOG1".*;
    encoded[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(encoded[40..]);
    try std.json.Stringify.value(record, .{}, &writer);
    _ = try wal.log().append(next.configuration.partition, catalog.store.root.next_lsn, 1, 1, .catalog_ddl, encoded[0 .. 40 + writer.end]);
    try t.expectError(error.InvalidDirectCatalogTransition, catalog.recoverSince(known));
    try t.expectError(error.CatalogRecoveryRequired, catalog.recoveryState());
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

fn nameAssertion(operation: u64, name: []const u8, expected: ?p.DataLifecycle.Definition) !c.NameAssertion.Binding {
    return .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null }, .operation = operation, .namespace = 1, .name = try .init(name), .action = if (expected != null) .create_if_not_exists else .drop_if_exists, .expected = expected, .intent = @splat(19) };
}

test "conditional catalog outcomes survive lost replies and never retarget a reused name" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var saved: c.NameAssertion.Binding = undefined;
    var absent: c.NameAssertion.Binding = undefined;
    var accepted: c.NameAssertion.Outcome = undefined;
    var access: Access = .{};
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        const create = try creation(7, 1, "events");
        _ = try catalog.admit(create, access.policy());
        _ = try catalog.perform(create.binding, access.policy());
        var view = (try resolve(&catalog, &access, "events")).?;
        defer view.deinit();
        saved = try nameAssertion(90, "events", view.table.root.interpretation);
        const before = catalog.store.root;
        const puts = objects.puts;
        const proposal = try catalog.previewName(saved, access.policy());
        try t.expect(proposal.matches);
        try t.expectEqualDeep(saved.expected, proposal.current);
        try t.expectEqualDeep(proposal, try catalog.previewName(saved, access.policy()));
        try t.expect(try c.OperationBinding.lookupAssertion(t.allocator, objects.objectStore(), saved.identity()) == null);
        access.deny_at = access.calls + 3;
        try t.expectError(error.CatalogDenied, catalog.previewName(saved, access.policy()));
        access.deny_at = std.math.maxInt(usize);
        try t.expect((try catalog.assertName(saved, .inspect, access.policy())) == .not_observed);
        try t.expectEqualDeep(before, catalog.store.root);
        try t.expectEqual(puts, objects.puts);
        const table_tail = try wal.log().tail(view.table.root.partition);
        catalog.store.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.assertName(saved, .accept, access.policy()));
        catalog.store.lose_reply = false;
        accepted = (try catalog.assertName(saved, .inspect, access.policy())).outcome;
        try t.expectEqual(.unchanged, accepted.state);
        try t.expectEqualDeep(accepted, (try catalog.assertName(saved, .cancel, access.policy())).outcome);
        try t.expectEqual(table_tail, try wal.log().tail(view.table.root.partition));
        try t.expectEqualDeep(before.names, catalog.store.root.names);
        try t.expectEqualDeep(before.objects, catalog.store.root.objects);
        const rename = try edit(&view, 2, .{ .rename = try .init("moved") });
        _ = try catalog.admit(rename, access.policy());
        _ = try catalog.perform(rename.binding, access.policy());
        const replacement = try creation(8, 3, "events");
        _ = try catalog.admit(replacement, access.policy());
        _ = try catalog.perform(replacement.binding, access.policy());
        var stale = saved;
        stale.operation = 91;
        try t.expectEqual(.rejected, (try catalog.assertName(stale, .accept, access.policy())).outcome.state);
        absent = try nameAssertion(92, "missing", null);
        try t.expectEqual(.unchanged, (try catalog.assertName(absent, .accept, access.policy())).outcome.state);
        const later = try creation(9, 4, "missing");
        _ = try catalog.admit(later, access.policy());
        _ = try catalog.perform(later.binding, access.policy());
        var conflict = create.binding;
        conflict.identity = saved.identity();
        try t.expectError(error.DataIdentityConflict, c.OperationBinding.claim(t.allocator, objects.objectStore(), conflict));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    const before = catalog.store.root;
    try t.expectEqualDeep(accepted, (try catalog.assertName(saved, .accept, access.policy())).outcome);
    try t.expectEqual(.unchanged, (try catalog.assertName(absent, .accept, access.policy())).outcome.state);
    try t.expectEqualDeep(before, catalog.store.root);
    var replacement = (try resolve(&catalog, &access, "events")).?;
    defer replacement.deinit();
    try t.expectEqual(@as(u64, 8), replacement.table.root.interpretation.object.object);
    var later = (try resolve(&catalog, &access, "missing")).?;
    defer later.deinit();
    try t.expectEqual(@as(u64, 9), later.table.root.interpretation.object.object);
    var changed = saved;
    changed.intent[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, catalog.assertName(changed, .accept, access.policy()));
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, catalog.assertName(saved, .inspect, access.policy()));
}

test "conditional catalog cancellation and late denial retain bounded exact recovery" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const blocked = try nameAssertion(1, "missing", null);
    const before = catalog.store.root;
    access.deny_at = access.calls + 5;
    try t.expectError(error.CatalogDenied, catalog.assertName(blocked, .accept, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    access.deny_at = std.math.maxInt(usize);
    try t.expect((try catalog.assertName(blocked, .inspect, access.policy())) == .not_observed);
    const closed = (try catalog.assertName(blocked, .cancel, access.policy())).outcome;
    try t.expectEqual(.cancelled, closed.state);
    try t.expectEqualDeep(closed, (try catalog.assertName(blocked, .accept, access.policy())).outcome);
    for (2..130) |id| {
        const binding = try nameAssertion(id, "missing", null);
        try t.expectEqual(.unchanged, (try catalog.assertName(binding, .accept, access.policy())).outcome.state);
    }
    try catalog.recover();
    try t.expectEqual(@as(usize, 1), catalog.store.index.cache.len);
    try t.expectEqualDeep(closed, (try catalog.assertName(blocked, .inspect, access.policy())).outcome);
}

fn namespaceCreate(id: u64, operation: u64, name: []const u8) !c.DirectNamespace.Binding {
    return .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null }, .operation = operation, .namespace = id, .expected = null, .action = .{ .create = .{ .name = try .init(name), .owner = 0 } } };
}
fn namespaceChange(current: a.Schema, operation: u64, action: @FieldType(c.DirectNamespace.Binding, "action")) c.DirectNamespace.Binding {
    return .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null }, .operation = operation, .namespace = current.id, .expected = current, .action = action };
}
test "direct namespaces recover exact publication and reject identity reuse after rename retirement and cancellation" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{ .missing_schema = true };
    const create = try namespaceCreate(2, 1000, "application");
    var published: c.DirectNamespace.Operation = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        const before = catalog.store.root;
        const puts = objects.puts;
        try t.expectEqual(.none, (try catalog.previewNamespace(create, access.policy())).reason);
        try t.expect((try catalog.namespaceOperation(create, .inspect, access.policy())) == .not_observed);
        try t.expectEqualDeep(before, catalog.store.root);
        try t.expectEqual(puts, objects.puts);
        catalog.store.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.namespaceOperation(create, .admit, access.policy()));
        catalog.store.lose_reply = false;
        try catalog.recover();
        try t.expectEqual(.admitted, (try catalog.namespaceOperation(create, .inspect, access.policy())).operation.phase);
        try t.expect(try catalog.inspectNamespace(2, access.policy()) == null);
        const registration = (try catalog.namespaceRegistration(create, access.policy())).?;
        try t.expectEqual(profile.schema_domain, registration.action.domain);
        try t.expectEqualDeep(a.reference(profile.database), registration.action.schema.?);
        try t.expectError(error.CatalogRegistrationRequired, catalog.namespaceOperation(create, .execute, access.policy()));
        access.missing_schema = false;
        catalog.store.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.namespaceOperation(create, .execute, access.policy()));
        catalog.store.lose_reply = false;
        published = (try catalog.namespaceOperation(create, .inspect, access.policy())).operation;
        try t.expectEqual(.applied, published.phase);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    try t.expectEqualDeep(published, (try catalog.namespaceOperation(create, .execute, access.policy())).operation);
    const rename = namespaceChange(published.resulting.?, 1001, .{ .rename = try .init("renamed") });
    _ = try catalog.namespaceOperation(rename, .admit, access.policy());
    const renamed = (try catalog.namespaceOperation(rename, .execute, access.policy())).operation.resulting.?;
    try t.expectEqual(@as(u64, 2), renamed.revision);
    try t.expectEqualDeep(published, (try catalog.namespaceOperation(create, .inspect, access.policy())).operation);
    var changed = create;
    changed.action.create.name = try .init("different");
    try t.expectError(error.DataIdentityConflict, catalog.namespaceOperation(changed, .admit, access.policy()));
    const stale = namespaceChange(published.resulting.?, 1002, .drop);
    try t.expectEqual(.stale_definition, (try catalog.namespaceOperation(stale, .admit, access.policy())).operation.reason);
    const drop = namespaceChange(renamed, 1003, .drop);
    _ = try catalog.namespaceOperation(drop, .admit, access.policy());
    const retired = (try catalog.namespaceOperation(drop, .execute, access.policy())).operation;
    try t.expect(retired.resulting.?.retired);
    try t.expect(try catalog.inspectNamespace(2, access.policy()) == null);
    const recreate = try namespaceCreate(3, 1004, "renamed");
    _ = try catalog.namespaceOperation(recreate, .admit, access.policy());
    try t.expectEqual(.applied, (try catalog.namespaceOperation(recreate, .execute, access.policy())).operation.phase);
    try t.expectEqualDeep(retired, (try catalog.namespaceOperation(drop, .execute, access.policy())).operation);
    const reused = try namespaceCreate(2, 1005, "replacement");
    try t.expectEqual(.object_conflict, (try catalog.namespaceOperation(reused, .admit, access.policy())).operation.reason);
    const cancelled = try namespaceCreate(4, 1006, "cancelled");
    _ = try catalog.namespaceOperation(cancelled, .admit, access.policy());
    try t.expectEqual(.cancelled, (try catalog.namespaceOperation(cancelled, .cancel, access.policy())).operation.phase);
    try t.expectEqual(.cancelled, (try catalog.namespaceOperation(cancelled, .admit, access.policy())).operation.phase);
    try t.expectEqual(.object_conflict, (try catalog.namespaceOperation(try namespaceCreate(4, 1007, "other"), .admit, access.policy())).operation.reason);
    try t.expectError(error.DataIdentityConflict, c.OperationBinding.claim(t.allocator, objects.objectStore(), (try creation(40, 1006, "conflict")).binding));
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, catalog.namespaceOperation(create, .inspect, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    try catalog.recover();
    try t.expectEqualDeep(retired, (try catalog.namespaceOperation(drop, .inspect, access.policy())).operation);
}

test "namespace RESTRICT fences new Table DDL and preserves retained reads after logical retirement" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const initial = (try catalog.inspectNamespace(1, access.policy())).?;
    const pending = try creation(7, 1, "events");
    _ = try catalog.admit(pending, access.policy());
    const first_drop = namespaceChange(initial, 1000, .drop);
    _ = try catalog.namespaceOperation(first_drop, .admit, access.policy());
    try t.expectEqual(.object_conflict, (try catalog.admit(try creation(8, 2, "blocked"), access.policy())).reason);
    try t.expectEqual(.dependency, (try catalog.namespaceOperation(first_drop, .execute, access.policy())).operation.reason);
    _ = try catalog.perform(pending.binding, access.policy());
    var view = (try resolve(&catalog, &access, "events")).?;
    defer view.deinit();
    const interpretation = view.table.root.interpretation;
    const position: p.DataLifecycle.Position = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn };
    const pin_owner: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 6000 };
    const retained = try catalog.pinRowsDefined(interpretation, pin_owner, position, access.policy());
    const live_drop = namespaceChange(initial, 1001, .drop);
    _ = try catalog.namespaceOperation(live_drop, .admit, access.policy());
    try t.expectEqual(.dependency, (try catalog.namespaceOperation(live_drop, .execute, access.policy())).operation.reason);
    const drop_table = try edit(&view, 3, .drop);
    _ = try catalog.admit(drop_table, access.policy());
    _ = try catalog.perform(drop_table.binding, access.policy());
    // The Table's committed DROP still has an unsettled catalog entry. That
    // receipt is terminal evidence, not a live namespace dependency.
    const empty_drop = namespaceChange(initial, 1002, .drop);
    _ = try catalog.namespaceOperation(empty_drop, .admit, access.policy());
    try t.expectEqual(.applied, (try catalog.namespaceOperation(empty_drop, .execute, access.policy())).operation.phase);
    try catalog.recover();
    var retained_definition = try catalog.snapshotDefinition(t.allocator, interpretation.object, retained, access.policy());
    defer retained_definition.deinit();
    try t.expectEqualDeep(interpretation, retained_definition.root.interpretation);
    try t.expect((try catalog.status(drop_table.binding, access.policy())) == .committed);
    _ = try catalog.currentReadAuthority(interpretation.object, access.policy());
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, catalog.snapshotDefinition(t.allocator, interpretation.object, retained, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    try catalog.releaseRows(interpretation.object, retained, access.policy());
}

test "namespace dependency progress is paged recoverable and independent of resident cache" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    for (10..35) |id| {
        var name: [30]u8 = undefined;
        const create = try creation(id, id, try std.fmt.bufPrint(&name, "table_{d}", .{id}));
        _ = try catalog.admit(create, access.policy());
        _ = try catalog.perform(create.binding, access.policy());
    }
    const create = try namespaceCreate(2, 1000, "empty");
    _ = try catalog.namespaceOperation(create, .admit, access.policy());
    const current = (try catalog.namespaceOperation(create, .execute, access.policy())).operation.resulting.?;
    const drop = namespaceChange(current, 1001, .drop);
    _ = try catalog.namespaceOperation(drop, .admit, access.policy());
    var pages_scanned: usize = 0;
    while (true) {
        const result = (try catalog.namespaceOperation(drop, .execute, access.policy())).operation;
        pages_scanned += 1;
        try catalog.recover();
        try t.expectEqualDeep(result, (try catalog.namespaceOperation(drop, .inspect, access.policy())).operation);
        if (result.phase == .applied) break;
        try t.expect(result.phase == .admitted and result.after != null);
        try t.expect(pages_scanned < 10);
    }
    try t.expect(pages_scanned > 1);
}

fn namedCreation(object: u64, operation: u64, name: []const u8) !c.DirectResource.Binding {
    return .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null }, .object = .{ .scope = scope, .branch = 1, .object = object }, .operation = operation, .expected = null, .action = .{ .create = .{
        .namespace = 1,
        .name = try a.Name.init(name),
        .owner = 0,
        .writer = 3,
        .owned = false,
        .deadline_ms = null,
        .history_ms = null,
        .spec = .{ .kv = .{ .value_type = .int64, .nullable = false, .key_encoding = .native_bytes, .value_encoding = .fvl1 } },
    } } };
}

fn namedAllocation(catalog: *D, access: *Access, binding: c.DirectResource.Binding, resource: u64) !c.DirectResource.Definition {
    _ = try catalog.prepareResourceAllocation(binding, access.policy());
    access.allocation_binding = binding;
    access.allocation_id = resource;
    return (try catalog.attachResource(binding, resource, access.policy())).operation.resulting.?;
}

test "named dependencies bind actual kinds and metadata authority before publication and preserve RESTRICT after rename" {
    for ([_]bool{ false, true }) |document_source| {
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        var access: Access = .{};
        try catalog.initialize(access.policy());
        var source = try namedCreation(150, 1500, "source");
        var consumer = try namedCreation(151, 1501, "consumer");
        const document: c.DirectResource.Spec = .{ .document = .{ .document = 91, .type_revision = 1, .limits = .{ .record_bytes = 4096, .staging_bytes = 16384, .staging_records = 4 } } };
        if (document_source) source.action.create.spec = document else consumer.action.create.spec = document;
        _ = try catalog.resourceOperation(source, .admit, access.policy());
        const source_value = try namedAllocation(&catalog, &access, source, 750);
        access.initialization = try source_value.initialization(t.allocator);
        _ = try catalog.resourceOperation(source, .execute, access.policy());
        _ = try catalog.resourceOperation(consumer, .admit, access.policy());
        const consumer_value = try namedAllocation(&catalog, &access, consumer, 751);
        var registration = dependencyBinding(try source_value.interpretation(t.allocator), 1502, 151);
        registration.edge.dependent = try consumer_value.dependent(t.allocator);
        var invalid = registration;
        invalid.operation = 1503;
        invalid.edge.dependent.kind = if (document_source) .document else .kv;
        try t.expectEqual(.stale_definition, (try catalog.dependencyOperation(invalid, .accept, access.policy())).outcome.reason);
        invalid.operation = 1504;
        invalid.edge.dependent.kind = .captured;
        try t.expectEqual(.stale_definition, (try catalog.dependencyOperation(invalid, .accept, access.policy())).outcome.reason);
        invalid = registration;
        invalid.operation = 1505;
        invalid.edge.privileges = a.update;
        try t.expectError(error.InvalidCatalogDependency, catalog.dependencyOperation(invalid, .accept, access.policy()));
        access.denied_resource = source_value.resource;
        try t.expectError(error.CatalogDenied, catalog.dependencyOperation(registration, .accept, access.policy()));
        // Source data is read-authorized at registration. The consumer instead
        // requires its metadata ownership, even while data access is revoked.
        access.denied_resource = consumer_value.resource;
        catalog.store.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.dependencyOperation(registration, .accept, access.policy()));
        catalog.store.lose_reply = false;
        try catalog.recover();
        const receipt = (try catalog.dependencyOperation(registration, .inspect, access.policy())).outcome;
        try t.expect(receipt.changed and receipt.phase == .applied);
        try t.expectEqual(null, try catalog.resolveResource(1, consumer.action.create.name, access.policy()));
        try t.expectEqualDeep(registration.edge, (try catalog.dependencyPage(.{ .dependencies = consumer.object }, null, .dependent, access.policy())).entries[0].?);
        access.denied_metadata = consumer_value.authorization;
        try t.expectError(error.CatalogDenied, catalog.dependencyOperation(registration, .inspect, access.policy()));
        try t.expectEqual(null, (try catalog.dependencyPage(.{ .dependents = source.object }, null, .dependent, access.policy())).entries[0]);
        var drop = source;
        drop.operation = 1506;
        drop.expected = registration.edge.source;
        drop.action = .drop;
        try t.expectEqual(.dependency, (try catalog.resourceOperation(drop, .admit, access.policy())).operation.reason);
        access.denied_metadata = null;
        access.denied_resource = null;
        access.initialization = try consumer_value.initialization(t.allocator);
        _ = try catalog.resourceOperation(consumer, .execute, access.policy());
        var rename = source;
        rename.operation = 1507;
        rename.expected = registration.edge.source;
        rename.action = .{ .rename = try a.Name.init("renamed_source") };
        _ = try catalog.resourceOperation(rename, .admit, access.policy());
        const renamed = (try catalog.resourceOperation(rename, .execute, access.policy())).operation.resulting.?;
        invalid = registration;
        invalid.operation = 1508;
        try t.expectEqual(.stale_definition, (try catalog.dependencyOperation(invalid, .accept, access.policy())).outcome.reason);
        drop.operation = 1509;
        drop.expected = try renamed.interpretation(t.allocator);
        try t.expectEqual(.dependency, (try catalog.resourceOperation(drop, .admit, access.policy())).operation.reason);
        // Explicit retirement of the consumer does not silently discard the
        // separately registered edge. Cleanup remains authorized and recoverable.
        var retire = consumer;
        retire.operation = 1510;
        retire.expected = registration.edge.dependent.interpretation;
        retire.action = .drop;
        _ = try catalog.resourceOperation(retire, .admit, access.policy());
        try t.expect((try catalog.resourceOperation(retire, .execute, access.policy())).operation.retired);
        access.denied_resource = source_value.resource;
        var removal = registration;
        removal.operation = 1511;
        removal.action = .remove;
        try t.expect((try catalog.dependencyOperation(removal, .accept, access.policy())).outcome.changed);
        try t.expectEqualDeep(receipt, (try catalog.dependencyOperation(registration, .accept, access.policy())).outcome);
        drop.operation = 1512;
        _ = try catalog.resourceOperation(drop, .admit, access.policy());
        try t.expect((try catalog.resourceOperation(drop, .execute, access.policy())).operation.retired);
        try t.expectEqual(null, (try catalog.dependencyPage(.{ .dependencies = consumer.object }, null, .dependent, access.policy())).entries[0]);
    }
}

test "named resource catalog reserves shared names and requires actual initialization before visibility" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const create = try namedCreation(101, 201, "objects");
    const before = catalog.store.root;
    const puts = objects.puts;
    const preview = try catalog.previewResource(create, access.policy());
    try t.expectEqual(.none, preview.reason);
    try t.expectEqual(null, preview.current);
    try t.expectEqual(.not_observed, try catalog.resourceOperation(create, .inspect, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    try t.expectEqual(puts, objects.puts);
    try t.expectEqual(@as(usize, 0), access.native_checks);
    try t.expectEqual(.admitted, (try catalog.resourceOperation(create, .admit, access.policy())).operation.phase);
    try t.expectEqual(null, try catalog.resolveResource(1, create.action.create.name, access.policy()));
    // The Table path shares the exact same name and permanent identity claims.
    const table = try creation(102, 202, "objects");
    try t.expectEqual(.name_conflict, (try catalog.admit(table, access.policy())).reason);
    const same_object = try creation(101, 203, "other");
    try t.expectEqual(.object_conflict, (try catalog.admit(same_object, access.policy())).reason);
    const absent = try nameAssertion(204, "objects", null);
    try t.expectEqual(.rejected, (try catalog.assertName(absent, .accept, access.policy())).outcome.state);
    const prepared_allocation = (try catalog.prepareResourceAllocation(create, access.policy())).operation.allocation.?;
    try t.expectEqualDeep(try create.allocation(prepared_allocation), (try catalog.resourceAllocation(create, access.policy())).?);
    try t.expectError(error.NamedResourceAllocationMismatch, catalog.attachResource(create, 700, access.policy()));
    const value = try namedAllocation(&catalog, &access, create, 700);
    try t.expectEqual(.allocated, (try catalog.resourceOperation(create, .inspect, access.policy())).operation.phase);
    try t.expectEqual(null, try catalog.resolveResource(1, create.action.create.name, access.policy()));
    try t.expectError(error.NamedResourceNotInitialized, catalog.resourceOperation(create, .execute, access.policy()));
    access.initialization = try value.initialization(t.allocator);
    access.initialization.?.interpretation.object.object += 1;
    try t.expectError(error.NamedResourceIdentityConflict, catalog.resourceOperation(create, .execute, access.policy()));
    access.initialization = try value.initialization(t.allocator);
    access.native_deny_at = access.native_checks + 2;
    try t.expectError(error.CatalogDenied, catalog.resourceOperation(create, .execute, access.policy()));
    access.native_deny_at = std.math.maxInt(usize);
    try t.expectEqual(.allocated, (try catalog.resourceOperation(create, .inspect, access.policy())).operation.phase);
    const complete = (try catalog.resourceOperation(create, .execute, access.policy())).operation;
    try t.expectEqual(.complete, complete.phase);
    try t.expectEqualDeep(value, (try catalog.resolveResource(1, create.action.create.name, access.policy())).?.definition);
    try t.expectEqual(null, try catalog.resolve(t.allocator, 1, create.action.create.name, access.policy()));
    var renamed = create;
    renamed.operation = 205;
    renamed.expected = try value.interpretation(t.allocator);
    renamed.action = .{ .rename = try a.Name.init("renamed") };
    _ = try catalog.resourceOperation(renamed, .admit, access.policy());
    const new_value = (try catalog.resourceOperation(renamed, .execute, access.policy())).operation.resulting.?;
    try t.expectEqual(@as(u64, 2), new_value.revision);
    try t.expectEqual(value.resource, new_value.resource);
    try t.expectEqual(null, try catalog.resolveResource(1, create.action.create.name, access.policy()));
    try t.expectEqualDeep(complete, (try catalog.resourceOperation(create, .execute, access.policy())).operation);
    var drop = renamed;
    drop.operation = 206;
    drop.expected = try new_value.interpretation(t.allocator);
    drop.action = .drop;
    _ = try catalog.resourceOperation(drop, .admit, access.policy());
    try t.expect((try catalog.resourceOperation(drop, .execute, access.policy())).operation.retired);
    try t.expectEqual(null, try catalog.resolveResource(1, renamed.action.rename, access.policy()));
    try t.expect(!access.native_retired); // Logical retirement never deletes data.
    const replacement = try creation(103, 207, "renamed");
    _ = try catalog.admit(replacement, access.policy());
    try t.expect((try catalog.perform(replacement.binding, access.policy())) == .committed);
    var stale = create;
    stale.operation = 208;
    try t.expectEqual(.object_conflict, (try catalog.resourceOperation(stale, .admit, access.policy())).operation.reason);
    var changed = create;
    changed.action.create.history_ms = 0;
    try t.expectError(error.DataIdentityConflict, catalog.resourceOperation(changed, .inspect, access.policy()));
}

test "named resource catalog disk recovery preserves allocation after every lost stage reply" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    const create = try namedCreation(111, 211, "durable");
    var value: c.DirectResource.Definition = undefined;
    for (0..4) |phase| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        if (phase == 2) {
            try t.expectEqual(.prepared, (try catalog.resourceOperation(create, .inspect, access.policy())).operation.phase);
            access.allocation_binding = create;
            access.allocation_id = 701;
        }
        if (phase == 3) {
            const recovered = (try catalog.resourceOperation(create, .inspect, access.policy())).operation;
            try t.expectEqual(.allocated, recovered.phase);
            value = recovered.resulting.?;
            access.initialization = try value.initialization(t.allocator);
        }
        catalog.store.lose_reply = true;
        if (phase == 0) try t.expectError(error.LostAcknowledgement, catalog.resourceOperation(create, .admit, access.policy())) else if (phase == 1) try t.expectError(error.LostAcknowledgement, catalog.prepareResourceAllocation(create, access.policy())) else if (phase == 2) try t.expectError(error.LostAcknowledgement, catalog.attachResource(create, 701, access.policy())) else try t.expectError(error.LostAcknowledgement, catalog.resourceOperation(create, .execute, access.policy()));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    try t.expectEqualDeep(value, (try catalog.resolveResource(1, create.action.create.name, access.policy())).?.definition);
    try t.expectEqual(.complete, (try catalog.resourceOperation(create, .execute, access.policy())).operation.phase);
    try t.expectEqual(@as(u64, 5), catalog.store.root.next_lsn);
}

test "named resource cancellation retains physical cleanup evidence and blocks unreconciled allocation" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const create = try namedCreation(112, 212, "partial");
    _ = try catalog.resourceOperation(create, .admit, access.policy());
    access.allocation_binding = create;
    access.allocation_id = 702;
    _ = try catalog.prepareResourceAllocation(create, access.policy());
    try t.expectError(error.NamedResourceAllocationUnreconciled, catalog.resourceOperation(create, .cancel, access.policy()));
    access.native_retired = true;
    const allocated = try namedAllocation(&catalog, &access, create, 702);
    access.initialization = try allocated.initialization(t.allocator);
    try t.expectError(error.RetiredResource, catalog.resourceOperation(create, .execute, access.policy()));
    const closed = (try catalog.resourceOperation(create, .cancel, access.policy())).operation;
    try t.expectEqual(.cancelled, closed.phase);
    try t.expectEqual(@as(u64, 702), closed.resulting.?.resource);
    try t.expectEqualDeep(closed, (try catalog.resourceOperation(create, .admit, access.policy())).operation);
    try t.expectEqual(null, try catalog.resolveResource(1, create.action.create.name, access.policy()));
    const table = try creation(113, 213, "partial");
    try t.expectEqual(.admitted, (try catalog.admit(table, access.policy())).phase);
}

test "named resource pages grow beyond the resident cache and namespace retirement respects pending data" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const namespace = (try catalog.inspectNamespace(1, access.policy())).?;
    const pending = try namedCreation(100, 1000, "pending");
    _ = try catalog.resourceOperation(pending, .admit, access.policy());
    const drop = namespaceChange(namespace, 2000, .drop);
    _ = try catalog.namespaceOperation(drop, .admit, access.policy());
    const blocked = try namedCreation(101, 1001, "blocked");
    try t.expectEqual(.object_conflict, (try catalog.resourceOperation(blocked, .admit, access.policy())).operation.reason);
    try t.expectEqual(.dependency, (try catalog.namespaceOperation(drop, .execute, access.policy())).operation.reason);
    _ = try catalog.resourceOperation(pending, .cancel, access.policy());
    // Cancelled definitions occupy permanent IDs, so the first listing page
    // can contain no visible entries and still have a required continuation.
    for (101..111) |id| {
        var buffer: [30]u8 = undefined;
        const create = try namedCreation(id, 3000 + id, try std.fmt.bufPrint(&buffer, "cancelled_{d}", .{id}));
        _ = try catalog.resourceOperation(create, .admit, access.policy());
        _ = try catalog.resourceOperation(create, .cancel, access.policy());
    }
    for (111..136) |id| {
        var buffer: [30]u8 = undefined;
        const create = try namedCreation(id, 3000 + id, try std.fmt.bufPrint(&buffer, "value_{d}", .{id}));
        _ = try catalog.resourceOperation(create, .admit, access.policy());
        const value = try namedAllocation(&catalog, &access, create, 5000 + id);
        access.initialization = try value.initialization(t.allocator);
        _ = try catalog.resourceOperation(create, .execute, access.policy());
    }
    try catalog.recover();
    const first = try catalog.listResources(1, null, access.policy());
    try t.expect(first.next != null);
    for (first.entries) |entry| try t.expectEqual(null, entry);
    access.denied_metadata = 100 + 120;
    var after = first.next;
    var count: usize = 0;
    var page_count: usize = 1;
    var previous: u64 = 0;
    while (after != null) {
        const page = try catalog.listResources(1, after, access.policy());
        for (page.entries) |entry| if (entry) |value| {
            const id = value.definition.object.object;
            try t.expect(id > previous and id >= 111 and id < 136 and id != 120);
            try t.expectEqualDeep(try value.definition.interpretation(t.allocator), value.interpretation);
            previous = id;
            count += 1;
        };
        if (page.next) |next| try t.expect(!std.meta.eql(after.?, next));
        after = page.next;
        page_count += 1;
        try t.expect(page_count < 12);
    }
    try t.expectEqual(@as(usize, 24), count);
    try t.expect(page_count > 3);
    access.denied_metadata = null;
    const live_drop = namespaceChange(namespace, 2001, .drop);
    _ = try catalog.namespaceOperation(live_drop, .admit, access.policy());
    while (true) {
        const status = (try catalog.namespaceOperation(live_drop, .execute, access.policy())).operation;
        if (status.phase != .admitted) {
            try t.expectEqual(.dependency, status.reason);
            break;
        }
    }
}

test "named resource allocation reservations survive recovery and release only on reconciliation or cancellation" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const first = try namedCreation(100, 1000, "first");
    const second = try namedCreation(101, 1001, "second");
    const third = try namedCreation(102, 1002, "third");
    for ([_]c.DirectResource.Binding{ first, second, third }) |binding| _ = try catalog.resourceOperation(binding, .admit, access.policy());
    const prepared = (try catalog.prepareResourceAllocation(first, access.policy())).operation;
    try catalog.recover();
    const before = catalog.store.root;
    try t.expectError(error.NativeAllocationBusy, catalog.prepareResourceAllocation(second, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    try t.expectEqualDeep(prepared, (try catalog.prepareResourceAllocation(first, access.policy())).operation);
    _ = try catalog.resourceOperation(first, .cancel, access.policy());
    try catalog.recover();
    try t.expectEqual(.prepared, (try catalog.prepareResourceAllocation(second, access.policy())).operation.phase);
    access.allocation_binding = second;
    access.allocation_id = 777;
    try t.expectError(error.NativeAllocationBusy, catalog.prepareResourceAllocation(third, access.policy()));
    _ = try catalog.attachResource(second, 777, access.policy());
    try catalog.recover();
    // Initialization can continue independently once the exact native receipt
    // has been reconciled. It does not hold the caller's next sequence hostage.
    try t.expectEqual(.prepared, (try catalog.prepareResourceAllocation(third, access.policy())).operation.phase);
    try t.expectEqual(.allocated, (try catalog.resourceOperation(second, .inspect, access.policy())).operation.phase);
}

fn retainedMetadataAllocations(allocator: std.mem.Allocator, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore, object: p.DataLifecycle.Object, lease: P.SnapshotHandle, point: P.HistoryPoint) !void {
    var access: Access = .{};
    var catalog = try D.init(allocator, try configuration(), wal.log(), objects.objectStore(), wal.log(), objects.objectStore(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
    defer catalog.deinit();
    try catalog.recover();
    var snapshot = try catalog.snapshotRead(allocator, object, lease, access.policy());
    defer snapshot.deinit();
    var history = try catalog.historyRead(allocator, object, lease, point, access.policy());
    defer history.deinit();
    try t.expectEqualDeep(snapshot.authority, history.authority);
    // Snapshot manifests omit control directories; the historical WAL record
    // retains them. Their logical data basis still agrees exactly.
    try t.expectEqualDeep(snapshot.definition.root.declared(), history.definition.root.declared());
    try t.expectEqual(snapshot.definition.root.changed_lsn, history.definition.root.changed_lsn);
    try t.expectEqual(snapshot.definition.root.live_rows, history.definition.root.live_rows);
    try t.expectEqual(snapshot.definition.root.next_lsn, history.definition.root.next_lsn);
}

test "retained metadata shares one recovered owner while preserving source and final authority" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var access: Access = .{};
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    try catalog.initialize(access.policy());
    const create = try creation(7, 1, "events");
    _ = try catalog.admit(create, access.policy());
    _ = try catalog.perform(create.binding, access.policy());
    _ = try catalog.settle(create.binding, access.policy());
    var view = (try resolve(&catalog, &access, "events")).?;
    defer view.deinit();
    const object = view.table.root.interpretation.object;
    const expected: p.DataLifecycle.Position = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn };
    const lease = try catalog.retainHistory(object, .{ .scope = scope, .principal = 1, .operation = 100 }, expected, view.table.root.interpretation, access.policy());
    var latest = (try resolve(&catalog, &access, "events")).?;
    defer latest.deinit();
    const renamed = try edit(&latest, 2, .{ .rename = try a.Name.init("renamed") });
    _ = try catalog.admit(renamed, access.policy());
    _ = try catalog.perform(renamed.binding, access.policy());
    try t.expect((try catalog.settle(renamed.binding, access.policy())) == .committed);
    var changed = (try resolve(&catalog, &access, "renamed")).?;
    defer changed.deinit();
    try t.expect(changed.table.root.interpretation.revision > view.table.root.interpretation.revision);
    const puts = objects.puts;
    const root = catalog.store.root;
    var initial = try catalog.historyDefinition(t.allocator, object, lease, null, access.policy());
    defer initial.deinit();
    const authority = try catalog.readAuthority(object, lease.owner, access.policy(), false);
    var separate_reads: u64 = 0;
    {
        var fresh = try owner(&wal, &objects);
        defer fresh.deinit();
        const begin = objects.range_reads;
        var snapshot = try fresh.snapshotDefinition(t.allocator, object, lease, access.policy());
        defer snapshot.deinit();
        try t.expectEqualDeep(authority, try fresh.readAuthority(object, lease.owner, access.policy(), false));
        try t.expectEqualDeep(view.table.root.interpretation, snapshot.root.interpretation);
        separate_reads = objects.range_reads - begin;
    }
    {
        var fresh = try owner(&wal, &objects);
        defer fresh.deinit();
        const begin = objects.range_reads;
        var combined = try fresh.snapshotRead(t.allocator, object, lease, access.policy());
        defer combined.deinit();
        const combined_reads = objects.range_reads - begin;
        try t.expect(combined_reads > 0 and combined_reads < separate_reads);
        std.debug.print("Retained metadata: separate/combined object ranges {d}/{d} with identical retained source and authority.\n", .{ separate_reads, combined_reads });
        try t.expectEqualDeep(authority, combined.authority);
        try t.expectEqualDeep(view.table.root.interpretation, combined.definition.root.interpretation);
    }
    var historical = try catalog.historyRead(t.allocator, object, lease, initial.point, access.policy());
    defer historical.deinit();
    try t.expectEqualDeep(initial.root, historical.definition.root);
    try t.expectEqualDeep(initial.point, historical.definition.point);
    try t.expectEqualDeep(authority, historical.authority);
    // Every guard can deny, including the final check after constructing the
    // retained outputs. Nothing is published by either successful or failed reads.
    for ([_]bool{ false, true }) |history| {
        const begin = access.calls;
        if (history) {
            var read = try catalog.historyRead(t.allocator, object, lease, initial.point, access.policy());
            read.deinit();
        } else {
            var read = try catalog.snapshotRead(t.allocator, object, lease, access.policy());
            read.deinit();
        }
        const guards = access.calls - begin;
        try t.expect(guards >= 3);
        for (1..guards + 1) |at| {
            access.deny_at = access.calls + at;
            if (history) try t.expectError(error.CatalogDenied, catalog.historyRead(t.allocator, object, lease, initial.point, access.policy())) else try t.expectError(error.CatalogDenied, catalog.snapshotRead(t.allocator, object, lease, access.policy()));
            access.deny_at = std.math.maxInt(usize);
        }
    }
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), retainedMetadataAllocations, .{ &wal, &objects, object, lease, initial.point });
    try t.expectEqual(puts, objects.puts);
    try t.expectEqualDeep(root, catalog.store.root);
    var wrong = initial.point;
    wrong.commitment[0] ^= 1;
    try t.expectError(error.TableHistoryConflict, catalog.historyRead(t.allocator, object, lease, wrong, access.policy()));
    wrong = initial.point;
    wrong.lease.content.sha256[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, catalog.historyRead(t.allocator, object, lease, wrong, access.policy()));
    try catalog.releaseRows(object, lease, access.policy());
    try t.expectError(error.TableSnapshotReleased, catalog.snapshotRead(t.allocator, object, lease, access.policy()));
    try t.expectError(error.TableSnapshotReleased, catalog.historyRead(t.allocator, object, lease, initial.point, access.policy()));
}

test "direct client recovery pages persist cancellation and exact CAS retries across restart" {
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
    const binding = try tokenBinding(objects.objectStore(), 55, 1);
    for (0..19) |i| {
        var next = binding;
        next.key.token = @splat(@intCast(i));
        _ = try catalog.clientToken(.{ .bind = next }, access.policy());
    }
    const initial = (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?;
    var change: c.DirectClientToken.Update = .{ .key = binding.key, .expected = initial.revision, .pending = true, .cancel = true, .record = null };
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.clientProgress(.{ .update = change }, access.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    const cancelled = (try catalog.clientProgress(.{ .update = change }, access.policy())).state.?;
    try t.expectEqualDeep(initial.receipt, cancelled.receipt);
    try t.expect(cancelled.cancel and cancelled.revision.next_lsn > initial.revision.next_lsn);
    const root_before = catalog.store.root;
    try t.expectEqualDeep(cancelled, (try catalog.clientProgress(.{ .update = change }, access.policy())).state.?);
    try t.expectEqualDeep(root_before, catalog.store.root);
    change.pending = false;
    try t.expectError(error.ClientOperationConflict, catalog.clientProgress(.{ .update = change }, access.policy()));
    change.expected = cancelled.revision;
    try t.expectError(error.ClientOperationPending, catalog.clientProgress(.{ .update = change }, access.policy()));
    change.pending = true;
    change.cancel = false;
    try t.expectError(error.ClientOperationConflict, catalog.clientProgress(.{ .update = change }, access.policy()));
    var original = try c.DirectTableIntentStore.load(t.allocator, objects.objectStore(), binding.intent.table);
    defer original.deinit();
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const native = try original.parsed.value.work.ddl.native(arena.allocator(), try configuration());
    _ = try catalog.admit(native, access.policy());
    _ = try catalog.perform(native.binding, access.policy());
    change.pending = false;
    change.cancel = true;
    const settled = (try catalog.clientProgress(.{ .update = change }, access.policy())).state.?;
    try catalog.recover();
    try t.expectEqualDeep(settled, (try catalog.clientProgress(.{ .operation = .{ .scope = binding.key.scope(), .id = initial.id() } }, access.policy())).state.?);
    for ([_]bool{ false, true }) |pending| {
        var count: usize = 0;
        var after: ?u64 = null;
        while (true) {
            const page = (try catalog.clientProgress(.{ .list = .{ .scope = binding.key.scope(), .after = after, .pending = pending } }, access.policy())).page;
            for (page.entries) |slot| if (slot) |state| {
                if (pending) try t.expect(state.id() != settled.id());
                count += 1;
            };
            after = page.next;
            if (after == null) break;
        }
        try t.expectEqual(@as(usize, if (pending) 18 else 19), count);
    }
    access.deny_create = true;
    try t.expectError(error.CatalogDenied, catalog.clientProgress(.{ .list = .{ .scope = binding.key.scope(), .after = null, .pending = true } }, access.policy()));
}

test "direct records retain complete bodies and scope recovery progress without actor turns" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    const record_scope: c.DirectRecord.Scope = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(9) };
    const bytes: [65536]u8 = @splat(37);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const staged = try catalog.directRecord(arena.allocator(), .{ .stage = .{ .scope = record_scope, .format = 7, .bytes = try c.DirectTableProtocol.Binary.encode(arena.allocator(), &bytes) } }, access.policy());
    const binding: c.DirectClientToken.Binding = .{ .key = .{ .definition = record_scope.definition, .connection = connection, .account = record_scope.account, .token = @splat(17) }, .fingerprint = @splat(11), .intent = .{ .external = .{ .connection = connection, .namespace = 1, .operation = 71, .record = staged.reference } } };
    const receipt = (try catalog.clientToken(.{ .bind = binding }, access.policy())).?;
    const read = try catalog.directRecord(arena.allocator(), .{ .read = staged.reference }, access.policy());
    try t.expectEqualSlices(u8, &bytes, try read.bytes.?.decode(arena.allocator(), c.DirectRecord.max_bytes));
    const changed = (try catalog.clientProgress(.{ .update = .{ .key = binding.key, .expected = receipt.position, .pending = true, .cancel = false, .record = staged.reference } }, access.policy())).state.?;
    try catalog.recover();
    try t.expectEqualDeep(changed, (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?);
    var foreign = staged.reference;
    foreign.scope.account[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, catalog.clientProgress(.{ .update = .{ .key = binding.key, .expected = changed.revision, .pending = true, .cancel = false, .record = foreign } }, access.policy()));
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, catalog.directRecord(arena.allocator(), .{ .read = staged.reference }, access.policy()));
}

test "client account budgets and request fences persist with exact admission" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    var binding = try tokenBinding(objects.objectStore(), 55, 1);
    binding.budget = .{ .limits = .{ .operations = 2, .pending = 1, .bytes = 9216 }, .bytes = 4608 };
    const receipt = (try catalog.clientToken(.{ .bind = binding }, access.policy())).?;
    const lease: c.DirectClientToken.Lease = .{ .key = binding.key, .revision = receipt.position };
    try catalog.requireClientLease(lease, access.policy());
    var other = binding;
    other.key.token = @splat(2);
    const before = catalog.store.root;
    try t.expectError(error.ClientTokenCapacity, catalog.clientToken(.{ .bind = other }, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    try t.expectEqualDeep(receipt, (try catalog.clientToken(.{ .bind = binding }, access.policy())).?);
    var original = try c.DirectTableIntentStore.load(t.allocator, objects.objectStore(), binding.intent.table);
    defer original.deinit();
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    const native = try original.parsed.value.work.ddl.native(scratch.allocator(), try configuration());
    _ = try catalog.admit(native, access.policy());
    _ = try catalog.perform(native.binding, access.policy());
    _ = try catalog.clientProgress(.{ .update = .{ .key = binding.key, .expected = receipt.position, .pending = false, .cancel = false, .record = null } }, access.policy());
    try catalog.recover();
    try t.expectError(error.StaleClientLease, catalog.requireClientLease(lease, access.policy()));
    other.budget.limits.operations = 3;
    try t.expectError(error.ClientBudgetConflict, catalog.clientToken(.{ .bind = other }, access.policy()));
    other.budget = binding.budget;
    const second = (try catalog.clientToken(.{ .bind = other }, access.policy())).?;
    _ = try catalog.clientProgress(.{ .update = .{ .key = other.key, .expected = second.position, .pending = false, .cancel = false, .record = null } }, access.policy());
    other.key.token = @splat(3);
    try t.expectError(error.ClientTokenCapacity, catalog.clientToken(.{ .bind = other }, access.policy()));
    const usage = (try catalog.store.clientUsage(catalog.store.root, binding.key)).?;
    try t.expectEqual(@as(u64, 2), usage.operations);
    try t.expectEqual(@as(u64, 9216), usage.bytes);
    try t.expectEqual(@as(u64, 0), usage.pending);
}
