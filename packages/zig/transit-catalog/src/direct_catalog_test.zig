const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const p = c.protocol;
const s = c.storage;
const a = c.TableAuthority;
const D = c.DirectCatalog;
const P = s.TablePartition;
const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
const profile: a.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .stream_domain = 31, .queue_domain = 32, .kv_domain = 33, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };

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
    denied_privileges: ?struct { id: u64, mask: u64 } = null,
    visible_despite_denied_privileges: bool = false,
    deny_create: bool = false,
    epoch_change_at: usize = std.math.maxInt(usize),
    exclusive: bool = false,
    held: bool = false,
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
        if (value.access.exclusive and value.access.held) return error.NestedPolicyGuard;
        value.access.calls += 1;
        if (value.access.calls >= value.access.deny_at) return error.CatalogDenied;
        for (value.requested.requirements) |slot| if (slot) |requirement| {
            if (value.access.deny_create and std.meta.eql(requirement.object, a.reference(profile.initial_schema_authority)) and requirement.privileges & a.create != 0) return error.CatalogDenied;
            if (requirement.object.kind == .resource and requirement.object.id == value.access.denied_resource) return error.CatalogDenied;
            if (value.access.denied_metadata) |id| if (std.meta.eql(requirement.object, a.reference(id))) return error.CatalogDenied;
            if (value.access.denied_privileges) |denied| if (std.meta.eql(requirement.object, a.reference(denied.id)) and requirement.privileges & denied.mask != 0 and !(value.access.visible_despite_denied_privileges and requirement.access == .visible)) return error.CatalogDenied;
        };
        if (value.requested.subject.principal() != 1 or value.requested.requirements[0].?.object.id != profile.database) return error.CatalogDenied;
        if (value.access.exclusive) value.access.held = true;
        return .{ .writer_epoch = 1, .policy_epoch = if (value.access.calls >= value.access.epoch_change_at) 2 else 1 };
    }
    fn release(context: *anyopaque) void {
        const value: *Context = @ptrCast(@alignCast(context));
        if (value.access.exclusive) {
            std.debug.assert(value.access.held);
            value.access.held = false;
        }
    }
    fn registered(context: *anyopaque, kind: a.Kind, id: u64) !?p.Authorization.Object {
        if ((kind == .table or kind == .stream or kind == .queue or kind == .kv) and erased(context).missing_table) return null;
        if (kind == .schema and id != 1 and erased(context).missing_schema) return null;
        const native: u64 = switch (kind) {
            .database => profile.database,
            .schema => if (id == 1) profile.initial_schema_authority else 20000 + id,
            .table, .stream, .queue, .kv => 100 + id,
        };
        return .{ .reference = a.reference(native), .owner = 0, .registrar = 1, .actions = a.actions(kind), .domain = profile.domain(kind), .binding = if (erased(context).mismatch) @splat(9) else try a.binding(scope, kind, id), .parent = switch (kind) {
            .database => null,
            .schema => a.reference(profile.database),
            .table, .stream, .queue, .kv => a.reference(profile.initial_schema_authority),
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
    try t.expectEqual(c.fuze.TableEvolution.Work.metadata, previewed.work.?);
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
    const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try a.Name.init(name), .action = .{ .create = .{ .schema = schema, .owner = 0 } } };
    return .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = .{ .scope = scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) }, .intent = intent };
}

test "companion Table defaults and semantic descriptors recover admitted DDL from disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var binding: p.DataLifecycle.Binding = undefined;
    var fingerprint: [32]u8 = undefined;
    for (0..3) |restart| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        if (restart == 0) {
            try catalog.initialize(access.policy());
            var compiled = try c.fuze.TableDdl.compile(t.allocator, "CREATE TABLE companions (id BIGINT PRIMARY KEY, span RANGE<BIGINT> DEFAULT '[1,3]', runs MULTIRANGE<DECIMAL(5,2)> DEFAULT '{[1.00,2.00),[2.00,3.00]}', embedding VECTOR(3,FLOAT32) METRIC COSINE DEFAULT '[-0.0,1.25,-2.5]', amount DECIMAL(8,2) ROUNDING HALF_EVEN)", null, null);
            defer compiled.deinit();
            var request = try creation(7, 1, "companions");
            request.intent.action.create.schema = try compiled.statement.create.bind(7);
            request.binding.intent = try request.intent.digest(t.allocator);
            binding = request.binding;
            fingerprint = try request.intent.action.create.schema.fingerprint();
            catalog.store.lose_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.admit(request, access.policy()));
            continue;
        }
        try t.expect(try catalog.perform(binding, access.policy()) == .committed);
        var view = (try resolve(&catalog, &access, "companions")).?;
        defer view.deinit();
        const schema = view.table.declaration.schema.schema;
        try t.expectEqual(fingerprint, try schema.fingerprint());
        try t.expectEqual(.cosine, schema.columns[3].semantics.metric.?);
        try t.expectEqual(.half_even, schema.columns[4].semantics.rounding.?);
        const vector = schema.columns[3].default.?.value.vector;
        try t.expect(@intFromPtr(vector.ptr) % 64 == 0);
        try t.expectEqualSlices(u8, &.{ 0, 0, 0, 128, 0, 0, 160, 63, 0, 0, 32, 192 }, vector);
        try t.expectEqual(@as(i128, 4), schema.columns[1].default.?.value.range.upper.?.value.signed);
        try t.expectEqual(@as(usize, 1), schema.columns[2].default.?.value.multirange.len);
        if (restart == 1) {
            var dml = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO companions(id) VALUES (1)", "companions", schema, null);
            defer dml.deinit();
            const change: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 2 }, .target = binding.target, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = try dml.plan.fingerprint(t.allocator) };
            const inserted = (try catalog.applyRows(.{ .binding = change, .interpretation = view.table.root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(change.identity, 0), .cells = dml.plan.action.insert[0] }, .expect = .absent } }}, .ingestion = .point }, access.policy())).committed;
            var finished = false;
            for (0..16) |_| {
                if ((try catalog.flushStorage(.{ .object = binding.target, .through = inserted.outcome.position }, access.policy())).complete) {
                    finished = true;
                    break;
                }
            }
            try t.expect(finished);
        } else {
            try t.expect(view.table.root.next_segment > 0);
            var read = try catalog.readCurrent(t.allocator, .{ .namespace = 1, .interpretation = view.table.root.interpretation, .expected = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, .selection = .{ .rows = .{ .after = null, .limits = .{} } } }, access.policy());
            defer read.deinit();
            try t.expectEqual(@as(u8, 1), read.selection.rows.count);
            const cells = read.selection.rows.rows[0].?.row().cells;
            try t.expectEqualSlices(u8, vector, cells[3].value.vector);
            try t.expect(@intFromPtr(cells[3].value.vector.ptr) % 64 == 0);
            try t.expectEqual(@as(i128, 4), cells[1].value.range.upper.?.value.signed);
            try t.expectEqual(@as(usize, 1), cells[2].value.multirange.len);
        }
    }
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

test "direct client log token recovers its complete original declaration before admission" {
    for ([_]c.DirectLog.Kind{ .stream, .queue }) |kind| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var access: Access = .{ .exclusive = true };
        var binding: c.DirectClientToken.Binding = undefined;
        for (0..3) |restart| {
            var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
            defer wal.deinit();
            var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
            defer objects.deinit();
            var catalog = try owner(&wal, &objects);
            defer catalog.deinit();
            if (restart == 0) {
                try catalog.initialize(access.policy());
                const request = try logCreation(kind, 7, 55, "events", 2);
                var arena = std.heap.ArenaAllocator.init(t.allocator);
                defer arena.deinit();
                const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
                var intent = try c.DirectLogIntent.create(t.allocator, connection, try c.DirectLogProtocol.Ddl.encode(arena.allocator(), request));
                defer intent.deinit();
                const reference = try intent.reference(@splat(9));
                binding = .{ .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(9), .token = @splat(1) }, .fingerprint = @splat(17), .intent = .{ .log = reference } };
                try t.expectError(error.DirectRecordMissing, catalog.clientToken(.{ .bind = binding }, access.policy()));
                try reference.record.requireSame(try c.DirectRecord.store(objects.objectStore(), reference.record.scope, c.DirectLogIntent.format, intent.bytes));
                var forged = binding;
                forged.intent.log.namespace = 2;
                try t.expectError(error.DataIdentityConflict, catalog.clientToken(.{ .bind = forged }, access.policy()));
                forged = binding;
                forged.key.account = @splat(10);
                try t.expectError(error.InvalidClientToken, catalog.clientToken(.{ .bind = forged }, access.policy()));
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.clientToken(.{ .bind = binding }, access.policy()));
                continue;
            }
            access.deny_create = true;
            try t.expectError(error.CatalogDenied, catalog.clientToken(.{ .lookup = binding.key }, access.policy()));
            access.deny_create = false;
            const receipt = (try catalog.clientToken(.{ .lookup = binding.key }, access.policy())).?;
            try t.expectEqualDeep(binding, receipt.binding);
            const progress = (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?;
            if (restart == 1) {
                try t.expectEqual(.not_observed, try catalog.logOperation(binding.intent.log.binding, .inspect, access.policy()));
                try t.expectError(error.ClientOperationPending, catalog.clientProgress(.{ .update = .{ .key = binding.key, .expected = progress.revision, .pending = false, .cancel = false, .record = null } }, access.policy()));
                var losing = binding;
                losing.intent.log.binding.identity.operation = 56;
                losing.intent.log.record.content.sha256 = @splat(88);
                try t.expectEqualDeep(receipt, (try catalog.clientToken(.{ .bind = losing }, access.policy())).?);
                try t.expectError(error.DataIdentityConflict, catalog.admit(try creation(8, 55, "other"), access.policy()));
                var original = try c.DirectLogIntent.load(t.allocator, objects.objectStore(), receipt.binding.intent.log);
                defer original.deinit();
                var scratch = std.heap.ArenaAllocator.init(t.allocator);
                defer scratch.deinit();
                const request = try original.parsed.value.work.request(scratch.allocator());
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.admitLog(request, access.policy()));
                continue;
            }
            try t.expect((try catalog.logOperation(binding.intent.log.binding, .inspect, access.policy())).operation.pending());
            for (0..2) |_| _ = try catalog.logOperation(binding.intent.log.binding, .execute, access.policy());
            const complete = (try catalog.logOperation(binding.intent.log.binding, .inspect, access.policy())).operation;
            try t.expectEqual(.complete, complete.phase);
            try t.expectEqual(@as(u32, 2), complete.initialized);
            const settled = (try catalog.clientProgress(.{ .update = .{ .key = binding.key, .expected = progress.revision, .pending = false, .cancel = false, .record = null } }, access.policy())).state.?;
            try t.expect(!settled.pending);
            try t.expectEqualDeep(receipt, settled.receipt);
            try t.expectEqual(kind, (try catalog.resolveLog(1, try .init("events"), access.policy())).?.kind());
        }
    }
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
    for ([_][]const u8{ "client_tokens", "client_token_count", "client_operations", "client_pending", "client_accounts" }) |field| {
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
    const intent: D.Intent = .{ .kind = .table, .namespace = view.properties.namespace, .name = view.properties.name, .action = action };
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

test "direct dispatch retains encoded output independently of temporary read owners" {
    const Fixture = struct {
        fn ddl(_: *anyopaque, _: *D, _: p.DataLifecycle.Binding, _: D.Policy, _: u16) !D.Observation {
            return error.UnexpectedDispatchExecution;
        }
        fn namespace(_: *anyopaque, _: *D, _: c.DirectNamespace.Binding, _: D.Policy, _: u16) !c.DirectNamespace.Observation {
            return error.UnexpectedDispatchExecution;
        }
    };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var output_probe: c.fuze.memory.AllocationProbe = .{ .parent = t.allocator };
    var output = std.heap.ArenaAllocator.init(output_probe.allocator());
    defer output.deinit();
    const result = blk: {
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
        const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 2 }, .target = create.binding.target, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = @splat(3) };
        const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
        const inserted = (try catalog.applyRows(.{ .binding = binding, .interpretation = view.table.root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(binding.identity, 0), .cells = &cells }, .expect = .absent } }}, .ingestion = .point }, access.policy())).committed;
        const pin = try catalog.pinRows(create.binding.target, .{ .scope = scope, .principal = 1, .operation = 100 }, inserted.outcome.position, access.policy());
        const execution: c.DirectTableDispatch.Execution = .{ .context = &catalog, .ddl = Fixture.ddl, .namespace = Fixture.namespace };
        const scanned = try c.DirectTableDispatch.apply(output.allocator(), &catalog, access.policy(), .{ .scan = .{ .snapshot = .{ .object = create.binding.target, .handle = pin }, .after = null, .limits = .{} } }, null, execution);
        try t.expectEqual(1, scanned.page.rows.len);
        // A one-cell result must not keep megabytes of owner caches, WAL
        // decoding or row encoding scratch in its caller's output arena.
        std.debug.print("Direct dispatch retained output: {d} backing bytes for {d} encoded row bytes.\n", .{ output_probe.live_bytes, scanned.page.rows[0].base64.len });
        try t.expect(output_probe.live_bytes < 64 * 1024);
        var other_output = std.heap.ArenaAllocator.init(t.allocator);
        defer other_output.deinit();
        const lookup = try c.DirectTableDispatch.apply(other_output.allocator(), &catalog, access.policy(), .{ .lookup = .{ .namespace = 1, .name = "events" } }, null, execution);
        try t.expectEqualDeep(scanned.page.interpretation, lookup.lookup.?.interpretation);
        break :blk scanned;
    };
    // Neither another dispatch nor destruction of the catalog/read owners can
    // invalidate returned bytes. Decode against the independently known schema.
    const encoded = try result.page.rows[0].decode(t.allocator, c.fuze.TableRow.max_bytes);
    defer t.allocator.free(encoded);
    var decoded = try c.fuze.TableRow.decode(t.allocator, .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} }, encoded);
    defer decoded.deinit();
    try t.expectEqual(@as(i64, 42), decoded.row().cells[0].value.atom.signed);
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

    // Stream traversal visits every logical partition, skips the existing
    // Tables plus Queue/private declarations, and freezes the same pass bound.
    const queue = try logCreation(.queue, 2000, 2000, "queue", 1);
    _ = try catalog.admitLog(queue, access.policy());
    _ = try catalog.logOperation(queue.binding, .execute, access.policy());
    const private = try logCreation(.stream, 2001, 2001, "private", 2);
    _ = try catalog.admitLog(private, access.policy());
    _ = try catalog.logOperation(private.binding, .execute, access.policy());
    for (2002..2011) |object| {
        var name: [32]u8 = undefined;
        const request = try logCreation(.stream, object, object, try std.fmt.bufPrint(&name, "stream_{d}", .{object}), 2);
        _ = try catalog.admitLog(request, access.policy());
        while ((try catalog.logOperation(request.binding, .execute, access.policy())).operation.phase != .complete) {}
    }
    var streams: D.LogMaintenanceCursor = .{};
    var count: usize = 0;
    var examined: usize = 0;
    while (true) : (examined += 1) {
        try t.expect(examined < 128);
        const before = catalog.store.root;
        const puts = objects.puts;
        const found = try catalog.logMaintenanceNext(.stream, &streams, physical.guard());
        if (found.target) |target| {
            try t.expectEqual(2002 + count / 2, target.object);
            try t.expectEqual(count % 2, target.ordinal);
            const definition = (try catalog.logMaintenanceDefinition(.stream, target, physical.guard())).?;
            try t.expectEqual(target.object, definition.stored.declaration.interpretation.object.object);
            try t.expectEqualDeep(before, catalog.store.root);
            try t.expectEqual(puts, objects.puts);
            count += 1;
            if (count == 1) {
                const later = try logCreation(.stream, 3000, 3000, "later", 1);
                _ = try catalog.admitLog(later, access.policy());
                _ = try catalog.logOperation(later.binding, .execute, access.policy());
            }
        }
        if (found.pass_complete) break;
    }
    try t.expectEqual(@as(usize, 18), count);
    try t.expectEqualDeep(D.LogMaintenanceCursor{}, streams);
    try t.expect(try catalog.logMaintenanceDefinition(.stream, .{ .object = 2000, .ordinal = 0 }, physical.guard()) == null);
    try t.expect(try catalog.logMaintenanceDefinition(.stream, .{ .object = 2001, .ordinal = 0 }, physical.guard()) == null);
    var queues: D.LogMaintenanceCursor = .{};
    var queue_count: usize = 0;
    for (0..128) |_| {
        const found = try catalog.logMaintenanceNext(.queue, &queues, physical.guard());
        if (found.target) |target| {
            try t.expectEqual(@as(u64, 2000), target.object);
            try t.expectEqual(@as(u32, 0), target.ordinal);
            try t.expectEqual(.queue, (try catalog.logMaintenanceDefinition(.queue, target, physical.guard())).?.kind());
            queue_count += 1;
        }
        if (found.pass_complete) break;
    } else return error.FixtureBudget;
    try t.expectEqual(@as(usize, 1), queue_count);
    try t.expectEqualDeep(D.LogMaintenanceCursor{}, queues);
    try t.expect(try catalog.logMaintenanceDefinition(.queue, .{ .object = 2002, .ordinal = 0 }, physical.guard()) == null);
    for ([_]usize{ 1, 2 }) |offset| {
        physical.deny_at = physical.calls + offset;
        try t.expectError(error.Forbidden, catalog.logMaintenanceNext(.stream, &streams, physical.guard()));
        try t.expectEqualDeep(D.LogMaintenanceCursor{}, streams);
    }
    physical.deny_at = physical.calls + 2;
    try t.expectError(error.Forbidden, catalog.logMaintenanceDefinition(.stream, .{ .object = 2002, .ordinal = 0 }, physical.guard()));
    physical.deny_at = null;
    streams = .{ .pending = .{ .object = 2002, .ordinal = 1 } };
    try t.expectError(error.InvalidMaintenanceCursor, catalog.logMaintenanceNext(.stream, &streams, physical.guard()));
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
        const entry: r.Entry = .{ .object = id, .partition = id, .seed = null, .resource = null, .log = null, .descriptor = null };
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
            .value => return error.UnexpectedDirectoryValue,
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
    const foreign: r.Entry = .{ .object = 99, .partition = 99, .seed = null, .resource = null, .log = null, .descriptor = null };
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
        .spec = .{ .document = .{ .document = 91, .type_revision = 1, .limits = .{ .record_bytes = 4096, .staging_bytes = 16384, .staging_records = 4 } } },
    } } };
}

fn namedAllocation(catalog: *D, access: *Access, binding: c.DirectResource.Binding, resource: u64) !c.DirectResource.Definition {
    _ = try catalog.prepareResourceAllocation(binding, access.policy());
    access.allocation_binding = binding;
    access.allocation_id = resource;
    return (try catalog.attachResource(binding, resource, access.policy())).operation.resulting.?;
}

test "named dependencies bind actual kinds and metadata authority before publication and preserve RESTRICT after rename" {
    {
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        var access: Access = .{};
        try catalog.initialize(access.policy());
        const source = try namedCreation(150, 1500, "source");
        const consumer = try namedCreation(151, 1501, "consumer");
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
        invalid.edge.dependent.kind = .kv;
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

fn transactionToken(catalog: *D, operation: u64, token: u8, count: u64) !c.DirectClientToken.Binding {
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    const identity: p.Transaction.Identity = .{ .begin = .{ .scope = scope, .principal = 1, .operation = operation }, .branch = 1 };
    var directory = try s.TransactionDirectory.init(t.allocator, catalog.data_objects, identity, .participants, 100, 1, 1024 * 1024);
    defer directory.deinit();
    for (0..count) |i| try directory.put(.{ .participant = .{ .state = .{
        .kind = .table,
        .guard = .{ .source = .{ .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = i + 1000 }, .revision = 1, .digest = @splat(1) }, .accepted = .{ .partition = i + 1000, .next_lsn = 1 } }, .changed_lsn = 1 },
        .access = .read,
    } } });
    const reference: c.DirectTransaction.Reference = .{ .connection = connection, .namespace = 1, .begin = .{
        .definition = p.Growth.current_definition,
        .identity = identity,
        .mode = .serializable,
        .selection = .explicit_objects,
        .objects = try directory.seal(),
        .catalog = .{ .partition = 1, .next_lsn = catalog.store.root.next_lsn },
        .limits = .{ .resident_bytes = 65536, .workspace_bytes = 1048576, .participants = 100, .statements = 1000, .savepoints = 32 },
    } };
    return .{ .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(9), .token = @splat(token) }, .fingerprint = @splat(token + 1), .intent = .{ .transaction = reference } };
}

test "transaction admission recovers original token and exclusive partition after lost disk reply" {
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
        binding = try transactionToken(&catalog, 55, 1, 17);
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
    try t.expectEqual(@as(?u64, 2), receipt.coordination);
    try t.expectEqual(@as(u64, 2), receipt.position.next_lsn);
    try t.expectEqual(@as(u64, 0), try wal.log().tail(receipt.coordination.?));
    const before = catalog.store.root;
    var racing = binding;
    racing.intent.transaction.begin.identity.begin.operation += 1;
    racing.intent.transaction.begin.objects.content.sha256 = @splat(99);
    try t.expectEqualDeep(receipt, (try catalog.clientToken(.{ .bind = racing }, access.policy())).?);
    try t.expectEqualDeep(before, catalog.store.root);
    // Another token cannot reserve a second coordinator for this begin identity.
    racing = binding;
    racing.key.token = @splat(2);
    racing.intent.transaction.begin.catalog.next_lsn = before.next_lsn;
    try t.expectError(error.DataIdentityConflict, catalog.clientToken(.{ .bind = racing }, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    const create = try creation(7, 70, "events");
    _ = try catalog.admit(create, access.policy());
    _ = try catalog.perform(create.binding, access.policy());
    var table = (try resolve(&catalog, &access, "events")).?;
    defer table.deinit();
    try t.expectEqual(@as(u64, 3), table.table.root.partition);
    try t.expectEqualDeep(receipt, (try catalog.clientToken(.{ .bind = binding }, access.policy())).?);
    const progress = (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?;
    const record = try c.DirectRecord.store(objects.objectStore(), binding.key.scope(), 1, "not transaction state");
    const protected = catalog.store.root;
    for ([_]bool{ false, true }) |pending| for ([_]bool{ false, true }) |cancel| for ([_]?c.DirectRecord.Reference{ null, record }) |replacement| {
        try t.expectError(error.TransactionOperationRequired, catalog.clientProgress(.{ .update = .{ .key = binding.key, .expected = progress.revision, .pending = pending, .cancel = cancel, .record = replacement } }, access.policy()));
        try t.expectEqualDeep(protected, catalog.store.root);
    };
    try catalog.recover();
    try t.expectEqualDeep(progress, (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?);
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, catalog.clientToken(.{ .lookup = binding.key }, access.policy()));
}

test "transaction admission refusals do not allocate partitions or consume token quota" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try transactionToken(&catalog, 55, 1, 9);
    const before = catalog.store.root;
    var changed = binding;
    changed.intent.transaction.begin.selection = .authorized_catalog_tables;
    try t.expectError(error.InvalidTransactionBegin, catalog.clientToken(.{ .bind = changed }, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    changed = binding;
    changed.intent.transaction.begin.limits.workspace_bytes = catalog.options.transaction_limits.workspace_bytes + 1;
    try t.expectError(error.TransactionCapacity, catalog.clientToken(.{ .bind = changed }, access.policy()));
    changed = binding;
    changed.intent.transaction.begin.objects.content.sha256 = @splat(99);
    try t.expectError(error.MissingTransactionDirectory, catalog.clientToken(.{ .bind = changed }, access.policy()));
    changed = binding;
    changed.intent.transaction.begin.catalog.next_lsn += 1;
    try t.expectError(error.TransactionCatalogChanged, catalog.clientToken(.{ .bind = changed }, access.policy()));
    var malformed = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), binding.intent.transaction.begin.identity, .participants, 100, 1, 1024 * 1024);
    defer malformed.deinit();
    try malformed.restore(binding.intent.transaction.begin.objects);
    malformed.root.count += 1;
    changed = binding;
    changed.intent.transaction.begin.objects = try malformed.seal();
    try t.expectError(error.InvalidTransactionDirectory, catalog.clientToken(.{ .bind = changed }, access.policy()));
    catalog.options.client_token_quota = 0;
    try t.expectError(error.ClientTokenCapacity, catalog.clientToken(.{ .bind = binding }, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(1));
    catalog.options.client_token_quota = 1;
    const receipt = (try catalog.clientToken(.{ .bind = binding }, access.policy())).?;
    var invalid = receipt;
    invalid.coordination = null;
    try t.expectError(error.InvalidClientToken, invalid.validate());
    invalid = receipt;
    invalid.coordination = 1;
    try t.expectError(error.InvalidClientToken, invalid.validate());
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, receipt, .{});
    defer t.allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, bytes, .{});
    defer parsed.deinit();
    var value = parsed.value;
    try t.expect(value.object.swapRemove("coordination"));
    const missing = try std.json.Stringify.valueAlloc(t.allocator, value, .{});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, std.json.parseFromSlice(c.DirectClientToken.Receipt, t.allocator, missing, .{}));
}

test "transaction admission retains selected directory pages through the catalog graph" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try transactionToken(&catalog, 55, 1, 73);
    _ = try catalog.clientToken(.{ .bind = binding }, access.policy());
    var workspace: @import("direct_storage_graph_test.zig").Workspace = .{};
    defer workspace.deinit();
    try workspace.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
    var at: usize = 0;
    var steps: usize = 0;
    while (at < workspace.jobs.items.len) : (at += 1) {
        var work = workspace.jobs.items[at];
        while (!try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &workspace)) {
            steps += 1;
            if (steps > 10000) return error.FixtureBudget;
        }
    }
    var selected = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), binding.intent.transaction.begin.identity, .participants, 100, 0, 1);
    defer selected.deinit();
    try selected.restore(binding.intent.transaction.begin.objects);
    const node = selected.root.entries.?;
    var walker = try c.DirectCatalogWalk.init(catalog.store.root, .{ .reference = node, .kind = .pages_only });
    var pages: usize = 0;
    while (try walker.next(t.allocator, &selected.index)) |edge| switch (edge) {
        .page => |page| {
            var name: [96]u8 = undefined;
            try t.expect(workspace.marks.contains(try s.TreeStore.key(page.reference.location, &name)));
            pages += 1;
        },
        .declaration, .value => return error.UnexpectedDeclaration,
    };
    try t.expect(pages > 1);
}

fn selectedTransaction(catalog: *D, access: *Access, count: usize) !c.DirectClientToken.Binding {
    return selectedTransactionIntegrity(catalog, access, count, false);
}
fn selectedTransactionIntegrity(catalog: *D, access: *Access, count: usize, integrity: bool) !c.DirectClientToken.Binding {
    var binding = try transactionToken(catalog, 9000, 1, 0);
    binding.intent.transaction.begin.limits.resident_bytes = 16 * 1024 * 1024;
    const identity = binding.intent.transaction.begin.identity;
    var selected = try s.TransactionDirectory.init(t.allocator, catalog.data_objects, identity, .participants, 100, 1, 1024 * 1024);
    defer selected.deinit();
    for (0..count) |i| {
        var buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "selected_{d}", .{i});
        var create = try creation(i + 10, i + 100, name);
        const constraint: c.fuze.TableConstraints.CheckConstraint = .{ .id = 1, .name = "bounded_id", .validated = false, .atoms = &.{.{ .compare_literal = .{ .column = 1, .op = .lt, .literal = .{ .signed = 600 } } }} };
        if (integrity) {
            create.intent.action.create.schema.integrity = .{ .next_id = 2, .checks = (&constraint)[0..1] };
            create.binding.intent = try create.intent.digest(t.allocator);
        }
        _ = try catalog.admit(create, access.policy());
        _ = try catalog.perform(create.binding, access.policy());
        var view = (try resolve(catalog, access, name)).?;
        defer view.deinit();
        const root = view.table.root;
        try selected.put(.{ .participant = .{ .state = .{ .kind = .table, .access = .read, .guard = .{ .source = .{ .interpretation = root.interpretation, .accepted = .{ .partition = root.partition, .next_lsn = root.next_lsn } }, .changed_lsn = root.changed_lsn } } } });
    }
    binding.intent.transaction.begin.objects = try selected.seal();
    binding.intent.transaction.begin.catalog.next_lsn = catalog.store.root.next_lsn;
    _ = try catalog.clientToken(.{ .bind = binding }, access.policy());
    return binding;
}

test "transaction common cut resumes lost pins and original publication on disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var binding: c.DirectClientToken.Binding = undefined;
    var published: c.DirectTransaction.Acquired = undefined;
    var access: Access = .{};
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        binding = try selectedTransaction(&catalog, &access, 11);
        const admitted = catalog.store.root;
        catalog.lose_table_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.acquireTransaction(binding.key, access.policy()));
        try t.expectEqualDeep(admitted, catalog.store.root);
    }
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        catalog.store.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.acquireTransaction(binding.key, access.policy()));
        catalog.store.lose_reply = false;
        try catalog.recover();
        published = try catalog.acquireTransaction(binding.key, access.policy());
        try t.expectEqual(@as(u64, 11), published.cut.sources.count);
        var sources = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), binding.intent.transaction.begin.identity, .sources, 100, 1, 1024 * 1024);
        defer sources.deinit();
        try sources.restore(published.cut.sources);
        var after: ?s.TransactionDirectory.Cursor = null;
        var count: usize = 0;
        while (true) {
            const page = try sources.page(after);
            for (page.entries) |slot| if (slot) |entry| {
                // Every empty Table was created at 1 and pinned exactly once.
                try t.expectEqual(@as(u64, 1), entry.source.guard.state.basis.source.accepted.next_lsn);
                try t.expectEqual(@as(u64, 2), try wal.log().tail(entry.source.guard.state.basis.source.accepted.partition));
                count += 1;
            };
            after = page.next orelse break;
        }
        try t.expectEqual(@as(usize, 11), count);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    const before = catalog.store.root;
    try t.expectEqualDeep(published, try catalog.acquireTransaction(binding.key, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    const progress = (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?;
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    try t.expectError(error.TransactionOperationRequired, catalog.directRecord(output.allocator(), .{ .stage = .{ .scope = binding.key.scope(), .format = c.DirectTransaction.Acquired.format, .bytes = .{ .base64 = "" } } }, access.policy()));
    access.denied_metadata = 110;
    try t.expectError(error.CatalogDenied, catalog.acquireTransaction(binding.key, access.policy()));
    try t.expectError(error.TransactionOperationRequired, catalog.directRecord(output.allocator(), .{ .read = progress.record.? }, access.policy()));
}

test "transaction acquisition refuses a changed recovered pin and preserves its original cut" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 2);
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.acquireTransaction(binding.key, access.policy()));
    catalog.lose_table_reply = false;
    var view = (try resolve(&catalog, &access, "selected_0")).?;
    defer view.deinit();
    const before_pin = try catalog.pinState(view.table.root.interpretation.object, binding.intent.transaction.begin.identity.begin, access.policy());
    const rename = try edit(&view, 999, .{ .rename = try a.Name.init("renamed") });
    _ = try catalog.admit(rename, access.policy());
    _ = try catalog.perform(rename.binding, access.policy());
    try t.expectError(error.TransactionConflict, catalog.acquireTransaction(binding.key, access.policy()));
    const after_pin = try catalog.pinState(view.table.root.interpretation.object, binding.intent.transaction.begin.identity.begin, access.policy());
    try t.expectEqualDeep(before_pin.handle, after_pin.handle);
    try t.expect((try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?.record == null);
}

test "transaction acquisition refuses mixed policy epochs before cut publication" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 2);
    const before = catalog.store.root;
    access.epoch_change_at = access.calls + 5;
    try t.expectError(error.TransactionAuthorityChanged, catalog.acquireTransaction(binding.key, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    const acquired = try catalog.acquireTransaction(binding.key, access.policy());
    try t.expectEqual(@as(u64, 2), acquired.cut.sources.count);
}

fn insertSelected(catalog: *D, access: *Access, operation: u64) !P.Evidence {
    return insertSelectedTable(catalog, access, "selected_0", operation);
}

fn insertSelectedTable(catalog: *D, access: *Access, name: []const u8, operation: u64) !P.Evidence {
    var view = (try resolve(catalog, access, name)).?;
    defer view.deinit();
    const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = view.table.root.interpretation.object, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = @splat(3) };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = @intCast(operation) } } }};
    return (try catalog.applyRows(.{ .binding = binding, .interpretation = view.table.root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(binding.identity, 0), .cells = &cells }, .expect = .absent } }}, .ingestion = .point }, access.policy())).committed;
}

test "transaction common cut preserves WAL rows across disk recovery flush and compaction" {
    for ([_]bool{ false, true }) |change| {
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
        const binding = try selectedTransaction(&catalog, &access, 2);
        const inserted = try insertSelected(&catalog, &access, 500);
        catalog.lose_table_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.acquireTransaction(binding.key, access.policy()));
        catalog.lose_table_reply = false;
        _ = try catalog.flushStorage(.{ .object = inserted.binding.target, .through = inserted.outcome.position }, access.policy());
        {
            var view = (try resolve(&catalog, &access, "selected_0")).?;
            defer view.deinit();
            var guards = std.heap.ArenaAllocator.init(t.allocator);
            defer guards.deinit();
            const guard = try access.dataGuard(guards.allocator(), view.properties, 10);
            const changed = view.table.root.changed_lsn;
            try t.expect((try view.table.compact(view.table.root.next_segment, .{}, guard)).complete);
            try t.expectEqual(changed, view.table.root.changed_lsn);
        }
        catalog.deinit();
        catalog = try owner(&wal, &objects);
        if (change) {
            _ = try insertSelected(&catalog, &access, 501);
            // A's original pin contains only 500. B acquires 502 strictly
            // after A changes, so old-A/new-B never existed as one common cut.
            // This is the finite model's interrupted-acquisition obligation
            // exercised against the real catalog and Table pin owners.
            _ = try insertSelectedTable(&catalog, &access, "selected_1", 502);
            try t.expectError(error.TransactionConflict, catalog.acquireTransaction(binding.key, access.policy()));
            try t.expect((try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?.record == null);
            continue;
        }
        const acquired = try catalog.acquireTransaction(binding.key, access.policy());
        var sources = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), binding.intent.transaction.begin.identity, .sources, 100, 0, 1);
        defer sources.deinit();
        try sources.restore(acquired.cut.sources);
        const source = (try sources.getTable(10)).?.source;
        try t.expectEqual(inserted.outcome.position.next_lsn, source.guard.state.basis.changed_lsn);
        _ = try insertSelected(&catalog, &access, 501);
        // Reobserving an acquired cut neither follows later data nor re-pins it.
        try t.expectEqualDeep(acquired, try catalog.acquireTransaction(binding.key, access.policy()));
        var rows = try catalog.scanRows(t.allocator, inserted.binding.target, source.pin, null, .{}, access.policy());
        defer rows.deinit();
        try t.expectEqual(@as(u8, 1), rows.count);
        try t.expectEqual(@as(i64, 500), rows.rows[0].?.row().cells[0].value.atom.signed);
    }
}

test "transaction common cut source pages remain reachable through catalog history" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 17);
    const acquired = try catalog.acquireTransaction(binding.key, access.policy());
    var workspace: @import("direct_storage_graph_test.zig").Workspace = .{};
    defer workspace.deinit();
    try workspace.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
    var at: usize = 0;
    var steps: usize = 0;
    while (at < workspace.jobs.items.len) : (at += 1) {
        var work = workspace.jobs.items[at];
        while (!try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &workspace)) {
            steps += 1;
            if (steps > 10000) return error.FixtureBudget;
        }
    }
    var sources = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), binding.intent.transaction.begin.identity, .sources, 100, 0, 1);
    defer sources.deinit();
    try sources.restore(acquired.cut.sources);
    var walker = try c.DirectCatalogWalk.init(catalog.store.root, .{ .reference = sources.root.entries.?, .kind = .pages_only });
    var count: usize = 0;
    while (try walker.next(t.allocator, &sources.index)) |edge| switch (edge) {
        .page => |page| {
            var name: [96]u8 = undefined;
            try t.expect(workspace.marks.contains(try s.TreeStore.key(page.reference.location, &name)));
            count += 1;
        },
        .declaration, .value => return error.UnexpectedDeclaration,
    };
    try t.expect(count > 1);
    var metadata = try c.DirectHistoryDirectory.init(t.allocator, objects.objectStore(), binding.intent.transaction.begin.identity.begin, 1, .retained, 100, 0, 1);
    defer metadata.deinit();
    const retained = acquired.catalog.?;
    try metadata.restore(retained);
    try t.expectEqual(@as(u64, 17), retained.count);
    var object_key: [96]u8 = undefined;
    try t.expect(workspace.marks.contains(try c.DirectHistoryDirectory.objectKey(retained.content, &object_key)));
    const first = (try metadata.get(10)).?;
    try t.expectEqualStrings("selected_0", first.properties.name.slice());
    try t.expectEqualDeep((try sources.getTable(10)).?.source.pin, first.pin.?);
    try first.verify(t.allocator, objects.objectStore());
    for ([_]?s.TreeStore.pages.Reference{ metadata.root.objects, metadata.root.names, metadata.root.namespaces, metadata.root.namespace_names }) |reference| {
        var pages = try c.DirectCatalogWalk.init(catalog.store.root, .{ .reference = reference.?, .kind = .pages_only });
        while (try pages.next(t.allocator, &metadata.index)) |edge| switch (edge) {
            .page => |page| try t.expect(workspace.marks.contains(try s.TreeStore.key(page.reference.location, &object_key))),
            else => return error.UnexpectedDeclaration,
        };
    }
}

test "transaction acquisition meters temporary memory and authorizes before revealing a budget refusal" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    var binding = try transactionToken(&catalog, 800, 1, 0);
    binding.intent.transaction.begin.limits.resident_bytes = 1024;
    _ = try catalog.clientToken(.{ .bind = binding }, access.policy());
    const before = catalog.store.root;
    try t.expectError(error.TransactionMemoryLimit, catalog.acquireTransaction(binding.key, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    access.deny_at = access.calls + 1;
    try t.expectError(error.CatalogDenied, catalog.acquireTransaction(binding.key, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
}

fn workspaceRequest(catalog: *D, access: *Access, key: c.DirectClientToken.Key, object_id: u64, sequence: u64, operation: u64) !c.DirectTransactionWorkspace.Request {
    const object: p.DataLifecycle.Object = .{ .scope = scope, .branch = 1, .object = object_id };
    const state = try catalog.transactionTableState(key, object, access.policy());
    const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = object, .action = .insert, .expected_definition = state.root.interpretation, .expected_data = null, .intent = @splat(3) };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = @intCast(operation) } } }};
    const request: s.TableDmlIntent.Request = .{ .binding = binding, .interpretation = state.root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(binding.identity, 0), .cells = &cells }, .expect = .absent } }}, .ingestion = .bulk };
    return .{ .basis = (try catalog.inspectTransaction(key, access.policy())).revision, .statement = .{ .transaction = state.begin.identity, .sequence = sequence, .intent = binding.intent }, .binding = binding, .intent = try s.TableDmlIntent.stage(t.allocator, catalog.data_objects, request) };
}

test "transaction temporary budgets do not borrow or retain ordinary Table owners" {
    for ([_]bool{ false, true }) |warm| {
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        var access: Access = .{};
        try catalog.initialize(access.policy());
        const binding = try selectedTransaction(&catalog, &access, 1);
        var retained: ?D.CachedTable = null;
        defer if (retained) |*cached| cached.table.deinit();
        catalog.options.table_owner = &retained;
        if (warm) {
            var view = (try resolve(&catalog, &access, "selected_0")).?;
            view.deinit();
        }
        const before = if (retained) |cached| cached.table.root else null;
        _ = try catalog.acquireTransaction(binding.key, access.policy());
        const request = try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500);
        try t.expect(try catalog.admitTransactionStatement(binding.key, request, access.policy()) == null);
        const outcome = try catalog.executeTransactionStatement(binding.key, request, access.policy());
        try t.expectEqual(@as(u64, 1), outcome.provisional.affected);
        try t.expectEqualDeep(outcome, try catalog.executeTransactionStatement(binding.key, request, access.policy()));
        const state = try catalog.transactionTableState(binding.key, request.binding.target, access.policy());
        try t.expectEqual(@as(u64, 1), state.root.live_rows);
        // The cold slot stays empty; a warm slot keeps its independently owned
        // allocator/root. Transaction opens are charged to their own budget.
        try t.expectEqualDeep(before, if (retained) |cached| cached.table.root else null);
        try t.expect(catalog.options.table_owner.? == &retained);
        var public = (try resolve(&catalog, &access, "selected_0")).?;
        defer public.deinit();
        try t.expectEqual(@as(u64, 0), public.table.root.live_rows);
    }
}

test "transaction durable workspace recovers lost admission and outcome replies without public writes" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var binding: c.DirectClientToken.Binding = undefined;
    var request: c.DirectTransactionWorkspace.Request = undefined;
    var expected: s.TableWorkspace.Outcome = undefined;
    for (0..3) |restart| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        if (restart == 0) {
            try catalog.initialize(access.policy());
            binding = try selectedTransaction(&catalog, &access, 2);
            _ = try catalog.acquireTransaction(binding.key, access.policy());
            request = try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500);
            catalog.store.lose_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.admitTransactionStatement(binding.key, request, access.policy()));
        } else if (restart == 1) {
            try t.expect(try catalog.admitTransactionStatement(binding.key, request, access.policy()) == null);
            var loaded = try s.TableDmlIntent.load(t.allocator, objects.objectStore(), request.intent);
            defer loaded.deinit();
            try t.expectError(error.DataIdentityConflict, catalog.applyRows(loaded.request, access.policy()));
            catalog.store.lose_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.executeTransactionStatement(binding.key, request, access.policy()));
        } else {
            const before = catalog.store.root;
            expected = try catalog.executeTransactionStatement(binding.key, request, access.policy());
            try t.expect(expected == .provisional);
            try t.expectEqual(@as(u64, 1), expected.provisional.affected);
            try t.expectEqualDeep(before, catalog.store.root);
            const state = try catalog.transactionTableState(binding.key, request.binding.target, access.policy());
            try t.expectEqual(@as(u64, 1), state.root.live_rows);
            const acquired = try catalog.acquireTransaction(binding.key, access.policy());
            try t.expectEqual(@as(u64, 2), acquired.cut.sources.count);
            var view = (try resolve(&catalog, &access, "selected_0")).?;
            defer view.deinit();
            try t.expectEqual(@as(u64, 0), view.table.root.live_rows);
            try t.expectEqual(@as(u64, 2), try wal.log().tail(view.table.root.partition));
            var guard_arena = std.heap.ArenaAllocator.init(t.allocator);
            defer guard_arena.deinit();
            const guard_value = try access.dataGuard(guard_arena.allocator(), view.properties, 10);
            var evaluator = try s.TableWorkspace.init(t.allocator, &view.table, state.begin, state.source, state, guard_value);
            defer evaluator.deinit();
            var key_buffer: [4096]u8 = undefined;
            const row_key = try c.fuze.Collation.encodePrimaryKeySortKey(view.table.declaration.schema.schema, &.{.{ .value = .{ .atom = .{ .signed = 500 } } }}, false, &key_buffer);
            var own_row = (try evaluator.get(t.allocator, row_key, guard_value)).?;
            defer own_row.deinit();
            try t.expectEqual(@as(i128, 500), own_row.row().cells[0].value.atom.signed);
            try t.expect(try view.table.get(t.allocator, row_key, guard_value) == null);
            var conflict = request;
            conflict.binding.identity.operation += 1;
            try t.expectError(error.TransactionStatementConflict, catalog.executeTransactionStatement(binding.key, conflict, access.policy()));
            access.denied_metadata = 110;
            try t.expectError(error.CatalogDenied, catalog.executeTransactionStatement(binding.key, request, access.policy()));
            try t.expectError(error.CatalogDenied, catalog.transactionTableState(binding.key, request.binding.target, access.policy()));
            access.denied_metadata = null;
            try t.expectEqualDeep(expected, try catalog.executeTransactionStatement(binding.key, request, access.policy()));
        }
    }
}

test "transaction durable workspace pages and private data remain reachable beyond one cache page" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 9);
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    for (0..9) |i| {
        const request = try workspaceRequest(&catalog, &access, binding.key, i + 10, i + 1, i + 500);
        _ = try catalog.executeTransactionStatement(binding.key, request, access.policy());
    }
    // A separately admitted statement must retain its frozen bytes even before
    // any private Table state or result exists for that sequence.
    const pending = try workspaceRequest(&catalog, &access, binding.key, 10, 10, 600);
    try t.expect(try catalog.admitTransactionStatement(binding.key, pending, access.policy()) == null);
    var graph: @import("direct_storage_graph_test.zig").Workspace = .{};
    defer graph.deinit();
    try graph.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
    var at: usize = 0;
    while (at < graph.jobs.items.len) : (at += 1) {
        var work = graph.jobs.items[at];
        while (true) {
            const before = graph.jobs.items.len;
            const done = try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &graph);
            try t.expect(graph.jobs.items.len - before <= 3);
            if (done) break;
        }
    }
    var name: [96]u8 = undefined;
    try t.expect(graph.marks.contains(try s.TableDmlIntent.key(pending.intent, &name)));
    var segments: usize = 0;
    for (objects.objects.items) |stored| {
        if (std.mem.startsWith(u8, stored.key, "table-segments/")) {
            try t.expect(graph.marks.contains(stored.key));
            segments += 1;
        }
    }
    try t.expectEqual(@as(usize, 9), segments);
    const progress = (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?;
    const head = try c.DirectTransactionWorkspace.recover(t.allocator, catalog.data_objects, progress);
    try t.expectEqual(@as(u64, 10), head.last_statement);
    try t.expect((try catalog.store.index.load(head.tables.?)).height > 0);
    try t.expect((try catalog.store.index.load(head.statements.?)).height > 0);
    for (0..9) |i| {
        const state = try catalog.transactionTableState(binding.key, .{ .scope = scope, .branch = 1, .object = i + 10 }, access.policy());
        try t.expectEqual(@as(u64, 1), state.root.live_rows);
    }
    _ = try catalog.executeTransactionStatement(binding.key, pending, access.policy());
    try t.expectEqual(@as(u64, 2), (try catalog.transactionTableState(binding.key, pending.binding.target, access.policy())).root.live_rows);
}

test "transaction durable workspace rejects out of order and concurrent statements without consuming them" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 1);
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    const first = try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500);
    const second = try workspaceRequest(&catalog, &access, binding.key, 10, 2, 501);
    var before = catalog.store.root;
    try t.expectError(error.TransactionStatementConflict, catalog.admitTransactionStatement(binding.key, second, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    _ = try catalog.admitTransactionStatement(binding.key, first, access.policy());
    before = catalog.store.root;
    try t.expectError(error.TransactionStatementPending, catalog.executeTransactionStatement(binding.key, second, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    _ = try catalog.executeTransactionStatement(binding.key, first, access.policy());
    try t.expectError(error.TransactionReadChanged, catalog.executeTransactionStatement(binding.key, second, access.policy()));
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 2, 501), access.policy());
    try t.expectEqual(@as(u64, 2), (try catalog.transactionTableState(binding.key, first.binding.target, access.policy())).root.live_rows);
}

test "transaction durable workspace quota refusal preserves pending work and original private root" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const first_binding = try selectedTransaction(&catalog, &access, 1);
    var binding = first_binding;
    binding.key.token = @splat(2);
    binding.intent.transaction.begin.identity.begin.operation += 1;
    binding.intent.transaction.begin.limits.workspace_bytes = 40 * 1024;
    // Rebind the paged selection to this distinct original begin.
    var old = try s.TransactionDirectory.init(t.allocator, catalog.data_objects, first_binding.intent.transaction.begin.identity, .participants, 100, 1, 1024 * 1024);
    defer old.deinit();
    try old.restore(first_binding.intent.transaction.begin.objects);
    var selected = try s.TransactionDirectory.init(t.allocator, catalog.data_objects, binding.intent.transaction.begin.identity, .participants, 100, 1, 1024 * 1024);
    defer selected.deinit();
    try selected.put((try old.getTable(10)).?);
    binding.intent.transaction.begin.objects = try selected.seal();
    binding.intent.transaction.begin.catalog.next_lsn = catalog.store.root.next_lsn;
    _ = try catalog.clientToken(.{ .bind = binding }, access.policy());
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    const request = try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500);
    _ = try catalog.admitTransactionStatement(binding.key, request, access.policy());
    const before = catalog.store.root;
    try t.expectError(error.TransactionWorkspaceLimit, catalog.executeTransactionStatement(binding.key, request, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    const state = try catalog.transactionTableState(binding.key, request.binding.target, access.policy());
    try t.expectEqual(@as(u64, 0), state.root.live_rows);
    const progress = (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?;
    const head = try c.DirectTransactionWorkspace.recover(t.allocator, catalog.data_objects, progress);
    try t.expectEqualDeep(request, head.pending.?.state);
    try t.expect(head.charged_bytes <= binding.intent.transaction.begin.limits.workspace_bytes);
    access.denied_metadata = 110;
    try t.expectError(error.CatalogDenied, catalog.executeTransactionStatement(binding.key, request, access.policy()));
    access.denied_metadata = null;
    const closed = try catalog.settleTransaction(binding.key, .{ .scope = scope, .principal = 1, .operation = 900 }, .abort, 8, access.policy());
    try t.expect(closed.cleanup_complete);
    try t.expect(closed.observation.decided.outcome == .aborted);
    try t.expectEqual(@as(u64, 1), (try catalog.store.clientUsage(catalog.store.root, binding.key)).?.transactions.count);
    // Only the deliberately unacquired first transaction retains a reservation.
    var public = (try resolve(&catalog, &access, "selected_0")).?;
    defer public.deinit();
    try t.expectEqual(@as(u64, 0), public.table.root.live_rows);
}

test "transaction account reservations survive reopen and cannot be bypassed by a different role" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var first: c.DirectClientToken.Binding = undefined;
    var second: c.DirectClientToken.Binding = undefined;
    for (0..2) |restart| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        catalog.options.transaction_account_limits.count = 1;
        if (restart == 0) {
            try catalog.initialize(access.policy());
            first = try transactionToken(&catalog, 55, 1, 0);
            catalog.store.lose_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.clientToken(.{ .bind = first }, access.policy()));
        } else {
            const before = catalog.store.root;
            _ = try catalog.clientToken(.{ .bind = first }, access.policy());
            try t.expectEqualDeep(before, catalog.store.root);
            const usage = (try catalog.store.clientUsage(before, first.key)).?;
            try t.expectEqual(@as(u64, 1), usage.transactions.count);
            try t.expectEqual(first.intent.transaction.begin.limits.workspace_bytes, usage.transactions.workspace_bytes);
            second = try transactionToken(&catalog, 56, 2, 0);
            second.key.connection.role = 7;
            second.intent.transaction.connection.role = 7;
            try t.expectError(error.TransactionAccountCapacity, catalog.clientToken(.{ .bind = second }, access.policy()));
            try t.expectEqualDeep(before, catalog.store.root);
            // Lowering admission ceilings must not hide the original accepted
            // receipt or release its reservation after an uncertain response.
            catalog.options.transaction_account_limits.resident_bytes = 0;
            _ = try catalog.clientToken(.{ .bind = first }, access.policy());
            try t.expectEqualDeep(usage, (try catalog.store.clientUsage(before, first.key)).?);
        }
    }
}

test "transaction account capacity sums every configured dimension before reserving a partition" {
    inline for (@typeInfo(c.DirectClientToken.TransactionReservations).@"struct".field_names) |name| {
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        var access: Access = .{};
        try catalog.initialize(access.policy());
        const first = try transactionToken(&catalog, 55, 1, 0);
        const limit = if (comptime std.mem.eql(u8, name, "count")) 1 else @field(first.intent.transaction.begin.limits, name);
        @field(catalog.options.transaction_account_limits, name) = limit;
        _ = try catalog.clientToken(.{ .bind = first }, access.policy());
        const second = try transactionToken(&catalog, 56, 2, 0);
        const before = catalog.store.root;
        try t.expectError(error.TransactionAccountCapacity, catalog.clientToken(.{ .bind = second }, access.policy()));
        try t.expectEqualDeep(before, catalog.store.root);
    }
    // Persisted records without explicit reservation counters must reject.
    const old = "{\"limits\":{\"operations\":100,\"bytes\":65536,\"pending\":10},\"operations\":1,\"bytes\":4608,\"pending\":1}";
    try t.expectError(error.MissingField, std.json.parseFromSlice(c.DirectClientToken.Usage, t.allocator, old, .{}));
}

test "transaction durable workspace preserves rejected statement outcome and consumed sequence" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var binding: c.DirectClientToken.Binding = undefined;
    var duplicate: c.DirectTransactionWorkspace.Request = undefined;
    var expected: s.TableWorkspace.Outcome = undefined;
    for (0..2) |restart| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        if (restart == 0) {
            try catalog.initialize(access.policy());
            binding = try selectedTransaction(&catalog, &access, 1);
            _ = try catalog.acquireTransaction(binding.key, access.policy());
            const first = try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500);
            _ = try catalog.executeTransactionStatement(binding.key, first, access.policy());
            var intent = try s.TableDmlIntent.load(t.allocator, catalog.data_objects, first.intent);
            defer intent.deinit();
            var request = intent.request;
            request.binding.identity.operation = 501;
            var row = request.changes[0].put.row;
            row.identity = try s.TableDmlIntent.insertIdentity(request.binding.identity, 0);
            request.changes = &.{.{ .put = .{ .row = row, .expect = .absent } }};
            duplicate = .{ .basis = (try catalog.inspectTransaction(binding.key, access.policy())).revision, .statement = .{ .transaction = first.statement.transaction, .sequence = 2, .intent = request.binding.intent }, .binding = request.binding, .intent = try s.TableDmlIntent.stage(t.allocator, catalog.data_objects, request) };
            expected = try catalog.executeTransactionStatement(binding.key, duplicate, access.policy());
            try t.expect(expected == .rejected);
            try t.expectEqual(.duplicate_key, expected.rejected.reason);
        } else {
            const before = catalog.store.root;
            try t.expectEqualDeep(expected, try catalog.executeTransactionStatement(binding.key, duplicate, access.policy()));
            try t.expectEqualDeep(before, catalog.store.root);
            const state = try catalog.transactionTableState(binding.key, duplicate.binding.target, access.policy());
            try t.expectEqual(@as(u64, 1), state.root.live_rows);
            try t.expectEqual(@as(u64, 2), state.last_statement);
            const replacement = try workspaceRequest(&catalog, &access, binding.key, 10, 2, 502);
            try t.expectError(error.TransactionStatementConflict, catalog.executeTransactionStatement(binding.key, replacement, access.policy()));
            var third = replacement;
            third.statement.sequence = 3;
            _ = try catalog.executeTransactionStatement(binding.key, third, access.policy());
            try t.expectEqual(@as(u64, 2), (try catalog.transactionTableState(binding.key, duplicate.binding.target, access.policy())).root.live_rows);
        }
    }
}

test "transaction coordinator recovers original multi Table decision through every lost reply boundary" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var binding: c.DirectClientToken.Binding = undefined;
    var request: c.DirectTransactionWorkspace.Request = undefined;
    const commit: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 700 };
    var original: ?p.Transaction.Decision = null;
    for (0..6) |restart| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        switch (restart) {
            0 => {
                try catalog.initialize(access.policy());
                binding = try selectedTransaction(&catalog, &access, 2);
                _ = try catalog.acquireTransaction(binding.key, access.policy());
                request = try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500);
                _ = try catalog.executeTransactionStatement(binding.key, request, access.policy());
                _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 11, 2, 501), access.policy());
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.settleTransaction(binding.key, commit, .commit, 1, access.policy()));
            },
            1 => {
                const status = try catalog.settleTransaction(binding.key, commit, .commit, 1, access.policy());
                try t.expect(status.observation == .preparing);
                try t.expect(!status.cleanup_complete);
                try t.expectError(error.TransactionPrepared, resolve(&catalog, &access, "selected_0"));
                var untouched = (try resolve(&catalog, &access, "selected_1")).?;
                defer untouched.deinit();
                try t.expectEqual(@as(u64, 0), untouched.table.root.live_rows);
                try t.expectError(error.TransactionFrozen, catalog.executeTransactionStatement(binding.key, request, access.policy()));
                var other = commit;
                other.operation += 1;
                try t.expectError(error.TransactionIdentityConflict, catalog.settleTransaction(binding.key, other, .commit, 1, access.policy()));
            },
            2 => {
                catalog.lose_table_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.settleTransaction(binding.key, commit, .commit, 1, access.policy()));
                try t.expect((try catalog.inspectTransaction(binding.key, access.policy())).observation == .preparing);
                try t.expectError(error.TransactionPrepared, resolve(&catalog, &access, "selected_1"));
            },
            3 => {
                catalog.lose_transaction_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.settleTransaction(binding.key, commit, .commit, 3, access.policy()));
                original = (try catalog.inspectTransaction(binding.key, access.policy())).observation.decided;
                try t.expect(original.?.outcome == .committed);
                try t.expectError(error.TransactionPrepared, resolve(&catalog, &access, "selected_0"));
                try t.expectError(error.TransactionPrepared, resolve(&catalog, &access, "selected_1"));
            },
            4 => {
                catalog.lose_table_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.settleTransaction(binding.key, commit, .abort, 2, access.policy()));
                var published = (try resolve(&catalog, &access, "selected_0")).?;
                defer published.deinit();
                try t.expectEqual(@as(u64, 1), published.table.root.live_rows);
                try t.expectError(error.TransactionPrepared, resolve(&catalog, &access, "selected_1"));
            },
            5 => {
                const status = try catalog.settleTransaction(binding.key, commit, .commit, 4, access.policy());
                try t.expect(status.cleanup_complete);
                try t.expectEqualDeep(original.?, status.observation.decided);
                try t.expectEqualDeep(status, try catalog.settleTransaction(binding.key, commit, .abort, 1, access.policy()));
                try t.expectEqual(@as(u64, 0), (try catalog.store.clientUsage(catalog.store.root, binding.key)).?.transactions.count);
                for ([_][]const u8{ "selected_0", "selected_1" }, 0..) |name, i| {
                    var view = (try resolve(&catalog, &access, name)).?;
                    defer view.deinit();
                    var guards = std.heap.ArenaAllocator.init(t.allocator);
                    defer guards.deinit();
                    const current = try access.dataGuard(guards.allocator(), view.properties, 10 + i);
                    const pinned = try view.table.pinState(binding.intent.transaction.begin.identity.begin, current);
                    try t.expect(pinned.released);
                    var key_buffer: [4096]u8 = undefined;
                    const row_key = try c.fuze.Collation.encodePrimaryKeySortKey(view.table.declaration.schema.schema, &.{.{ .value = .{ .atom = .{ .signed = @intCast(500 + i) } } }}, false, &key_buffer);
                    var row = (try view.table.get(t.allocator, row_key, current)).?;
                    defer row.deinit();
                    try t.expectEqual(@as(i128, @intCast(500 + i)), row.row().cells[0].value.atom.signed);
                    try t.expectEqual(@as(u64, 1), view.table.root.live_rows);
                }
            },
            else => unreachable,
        }
    }
}

test "transaction coordinator abort clears prepared prefix and incomplete acquisition without new work" {
    for ([_]bool{ false, true }) |prepared| {
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        var access: Access = .{};
        try catalog.initialize(access.policy());
        const binding = try selectedTransaction(&catalog, &access, 2);
        const commit: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 700 };
        if (prepared) {
            _ = try catalog.acquireTransaction(binding.key, access.policy());
            _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500), access.policy());
            _ = try catalog.settleTransaction(binding.key, commit, .commit, 1, access.policy());
        } else {
            catalog.lose_table_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.acquireTransaction(binding.key, access.policy()));
            catalog.lose_table_reply = false;
        }
        const status = try catalog.settleTransaction(binding.key, commit, .abort, 4, access.policy());
        try t.expect(status.cleanup_complete);
        try t.expect(status.observation.decided.outcome == .aborted);
        try t.expectEqualDeep(status, try catalog.settleTransaction(binding.key, commit, .commit, 1, access.policy()));
        try t.expectEqual(@as(u64, 0), (try catalog.store.clientUsage(catalog.store.root, binding.key)).?.transactions.count);
        for ([_][]const u8{ "selected_0", "selected_1" }, 0..) |name, i| {
            var view = (try resolve(&catalog, &access, name)).?;
            defer view.deinit();
            try t.expectEqual(@as(u64, 0), view.table.root.live_rows);
            var guards = std.heap.ArenaAllocator.init(t.allocator);
            defer guards.deinit();
            const state = try view.table.pinState(binding.intent.transaction.begin.identity.begin, try access.dataGuard(guards.allocator(), view.properties, 10 + i));
            try t.expect(state.handle == null or state.released);
        }
    }
}

test "transaction coordinator validates read dependencies and current policy before the decision" {
    for ([_]enum { conflict, denied, epoch }{ .conflict, .denied, .epoch }) |failure| {
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        var access: Access = .{};
        try catalog.initialize(access.policy());
        const binding = try selectedTransaction(&catalog, &access, 2);
        _ = try catalog.acquireTransaction(binding.key, access.policy());
        _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500), access.policy());
        const commit: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 700 };
        _ = try catalog.settleTransaction(binding.key, commit, .commit, 1, access.policy());
        switch (failure) {
            .conflict => {
                _ = try insertSelectedTable(&catalog, &access, "selected_1", 800);
                try t.expectError(error.TransactionConflict, catalog.settleTransaction(binding.key, commit, .commit, 4, access.policy()));
            },
            .denied => {
                access.denied_metadata = 110;
                try t.expectError(error.CatalogDenied, catalog.settleTransaction(binding.key, commit, .commit, 4, access.policy()));
                access.denied_metadata = null;
            },
            .epoch => {
                access.epoch_change_at = access.calls + 5;
                try t.expectError(error.TransactionAuthorityChanged, catalog.settleTransaction(binding.key, commit, .commit, 4, access.policy()));
                access.epoch_change_at = std.math.maxInt(usize);
            },
        }
        try t.expect((try catalog.inspectTransaction(binding.key, access.policy())).observation == .preparing);
        const terminal = try catalog.settleTransaction(binding.key, commit, .abort, 4, access.policy());
        try t.expect(terminal.cleanup_complete);
        try t.expect(terminal.observation.decided.outcome == .aborted);
        var first = (try resolve(&catalog, &access, "selected_0")).?;
        defer first.deinit();
        try t.expectEqual(@as(u64, 0), first.table.root.live_rows);
    }
}

test "transaction coordinator refuses unavailable prepared data and abort can reclaim its private graph" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 2);
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500), access.policy());
    const commit: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 700 };
    var name: [96]u8 = undefined;
    var lost: ?[]u8 = null;
    defer if (lost) |value| t.allocator.free(value);
    for (objects.objects.items) |stored| {
        if (std.mem.startsWith(u8, stored.key, "table-segments/")) {
            lost = try t.allocator.dupe(u8, stored.key);
            break;
        }
    }
    try objects.objectStore().delete(lost.?);
    try t.expectError(error.TableSegmentMissing, catalog.settleTransaction(binding.key, commit, .commit, 4, access.policy()));
    try t.expect((try catalog.inspectTransaction(binding.key, access.policy())).observation == .preparing);
    const terminal = try catalog.settleTransaction(binding.key, commit, .abort, 4, access.policy());
    try t.expect(terminal.cleanup_complete);
    var graph: @import("direct_storage_graph_test.zig").Workspace = .{};
    defer graph.deinit();
    try graph.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
    for ([_][]const u8{ "selected_0", "selected_1" }) |table_name| {
        var view = (try resolve(&catalog, &access, table_name)).?;
        defer view.deinit();
        const cut = try view.table.recoveryState();
        try graph.enqueue(.{ .table_history = try .init(.{ .root = cut.root, .chain = cut.chain }) });
    }
    var at: usize = 0;
    while (at < graph.jobs.items.len) : (at += 1) {
        var work = graph.jobs.items[at];
        while (true) {
            const before = graph.jobs.items.len;
            const done = try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &graph);
            try t.expect(graph.jobs.items.len - before <= 3);
            if (done) break;
        }
    }
    try t.expect(!graph.marks.contains(lost.?));
    const progress = (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?;
    const control = try c.DirectTransactionControl.load(t.allocator, catalog.data_objects, progress);
    var preparations = try s.TransactionDirectory.init(t.allocator, catalog.data_objects, control.binding.begin.identity, .preparations, 10, 1, 1024 * 1024);
    defer preparations.deinit();
    try preparations.restore(control.preparations.?);
    const prepared = (try preparations.getTable(10)).?.prepared;
    try t.expect(graph.marks.contains(try s.TableTransaction.key(.{ .content = prepared.successor }, &name)));
    // The persisted decision can still be reopened after the unreachable
    // private candidate disappeared. Replay must not dereference aborted data.
    var reopened = try owner(&wal, &objects);
    defer reopened.deinit();
    try t.expectEqualDeep(terminal, try reopened.inspectTransaction(binding.key, access.policy()));
}

test "transaction server selection freezes authorized catalog and preserves original token" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var retained: ?D.CachedTable = null;
    defer if (retained) |*cached| cached.table.deinit();
    catalog.options.table_owner = &retained;
    var access: Access = .{};
    try catalog.initialize(access.policy());
    _ = try selectedTransaction(&catalog, &access, 12);
    const template = try transactionToken(&catalog, 9500, 2, 0);
    var request: c.DirectTransactionRequest.Begin = .{
        .key = template.key,
        .fingerprint = template.fingerprint,
        .operation = template.intent.transaction.begin.identity.begin,
        .namespace = 1,
        .mode = .read_only,
        .selection = .authorized_catalog_tables,
        .limits = c.DirectTransaction.default_limits,
        .budget = template.budget,
    };
    access.denied_metadata = 111;
    const receipt = try catalog.beginTransaction(request, access.policy());
    try t.expectEqual(@as(u64, 11), receipt.binding.intent.transaction.begin.objects.count);
    try t.expectEqual(.authorized_catalog_tables, receipt.binding.intent.transaction.begin.selection);
    const cut = try catalog.acquireTransaction(request.key, access.policy());
    try t.expectEqual(@as(u64, 11), cut.cut.sources.count);
    // Later catalog growth and a racing proposed identity cannot change the
    // already accepted original begin or select an additional participant.
    const create = try creation(70, 9800, "later");
    _ = try catalog.admit(create, access.policy());
    _ = try catalog.perform(create.binding, access.policy());
    request.operation.operation += 1;
    try t.expectEqualDeep(receipt, try catalog.beginTransaction(request, access.policy()));
    const operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9600 };
    const status = try catalog.settleTransaction(request.key, operation, .commit, 32, access.policy());
    try t.expect(status.cleanup_complete);
    try t.expect(status.observation.decided.outcome == .committed);
    try c.DirectTransactionRequest.validateResult(.{ .settle = .{ .key = request.key, .operation = operation, .command = .commit, .steps = 32 } }, .{ .status = status });
    request.fingerprint[0] ^= 1;
    try t.expectError(error.ClientTokenConflict, catalog.beginTransaction(request, access.policy()));
    request.key.token = @splat(3);
    request.selection = .{ .explicit_objects = &.{.{ .object = .{ .scope = scope, .branch = 1, .object = 10 }, .kind = .queue, .partition = 0 }} };
    const before_refusal = catalog.store.root;
    try t.expectError(error.CatalogDenied, catalog.beginTransaction(request, access.policy()));
    try t.expectEqualDeep(before_refusal, catalog.store.root);
    request.selection = .{ .explicit_objects = &.{.{ .object = .{ .scope = scope, .branch = 1, .object = 11 }, .kind = .table, .partition = null }} };
    try t.expectError(error.CatalogDenied, catalog.beginTransaction(request, access.policy()));
    access.denied_metadata = null;
    access.epoch_change_at = access.calls + 4;
    try t.expectError(error.TransactionAuthorityChanged, catalog.beginTransaction(request, access.policy()));
}

test "transaction native staging binds private work without accepting or exposing rows" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var retained: ?D.CachedTable = null;
    defer if (retained) |*cached| cached.table.deinit();
    catalog.options.table_owner = &retained;
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 1);
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    var view = (try resolve(&catalog, &access, "selected_0")).?;
    defer view.deinit();
    const w = c.DirectTableProtocol;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const schema = view.table.declaration.schema.schema;
    const identity: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 500 };
    const row: c.fuze.TableRow.Row = .{ .identity = try w.Rows.insertIdentity(identity, 0), .cells = &.{.{ .value = .{ .atom = .{ .signed = 7 } } }} };
    var buffer: [65536]u8 = undefined;
    var work: w.Rows = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = identity, .target = view.table.root.interpretation.object, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = @splat(1) },
        .interpretation = view.table.root.declared(),
        .schema = try w.Binary.encode(allocator, try schema.encode(&buffer)),
        .changes = &.{.{ .insert = try w.Binary.encode(allocator, try row.encode(schema, &buffer)) }},
        .ingestion = .bulk,
    };
    work.binding.intent = try work.digest(allocator);
    const before = try catalog.inspectTransaction(binding.key, access.policy());
    const request = try catalog.stageTransactionStatement(binding.key, before.revision, 1, .{ .rows = work }, access.policy());
    try t.expectEqualDeep(before, try catalog.inspectTransaction(binding.key, access.policy()));
    try t.expectEqualDeep(request, try catalog.stageTransactionStatement(binding.key, before.revision, 1, .{ .rows = work }, access.policy()));
    try c.DirectTransactionRequest.validateResult(.{ .stage = .{ .key = binding.key, .basis = before.revision, .sequence = 1, .work = .{ .rows = work } } }, .{ .staged = request });
    try t.expect(try catalog.admitTransactionStatement(binding.key, request, access.policy()) == null);
    const resumed = try catalog.resumeTransaction(binding.key, 1, access.policy());
    try t.expect(!resumed.pending_statement and resumed.attempt == null);
    try t.expectEqualDeep(resumed, try catalog.resumeTransaction(binding.key, 1, access.policy()));
    const outcome = try catalog.executeTransactionStatement(binding.key, request, access.policy());
    try t.expectEqual(@as(u64, 1), outcome.provisional.affected);
    try t.expectEqualDeep(outcome, try catalog.executeTransactionStatement(binding.key, request, access.policy()));
    try t.expectError(error.TransactionStatementConflict, catalog.stageTransactionStatement(binding.key, before.revision, 1, .{ .rows = work }, access.policy()));
    var visible = (try resolve(&catalog, &access, "selected_0")).?;
    defer visible.deinit();
    try t.expectEqual(@as(u64, 0), visible.table.root.live_rows);
    const terminal = try catalog.settleTransaction(binding.key, .{ .scope = scope, .principal = 1, .operation = 501 }, .abort, 2, access.policy());
    try t.expect(terminal.cleanup_complete);
    try t.expectEqualDeep(terminal, try catalog.resumeTransaction(binding.key, 1, access.policy()));
}

test "transaction private reads retain the common cut and invalidate earlier workspace revisions" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 1);
    const acquired = try catalog.acquireTransaction(binding.key, access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500), access.policy());
    const context: c.DirectTransactionRead.Context = .{ .key = binding.key, .revision = (try catalog.inspectTransaction(binding.key, access.policy())).revision };
    catalog.transaction_read = context;
    var private = (try resolve(&catalog, &access, "selected_0")).?;
    const object = private.table.root.interpretation.object;
    const observed = private.table.workspace_read.?;
    try t.expectEqualDeep(acquired.cut, observed.cut);
    try t.expectEqual(@as(u64, 1), private.table.root.live_rows);
    try t.expect(private.table.root.next_lsn > observed.source.source.accepted.next_lsn);
    const handle: P.SnapshotHandle = .{ .owner = binding.intent.transaction.begin.identity.begin, .content = observed.private };
    private.deinit();
    {
        var read = try catalog.snapshotRead(t.allocator, object, handle, access.policy());
        defer read.deinit();
        try t.expectEqualDeep(observed, read.definition.transaction.?);
        try t.expectEqualDeep(observed.source.source.accepted, read.definition.position());
        var page = try catalog.scanRows(t.allocator, object, handle, null, .{}, access.policy());
        defer page.deinit();
        try t.expectEqual(@as(usize, 1), page.count);
        try t.expectEqualDeep(read.definition.position(), page.accepted);
        try t.expectEqual(@as(i128, 500), page.rows[0].?.row().cells[0].value.atom.signed);
    }
    // A public rename does not change the original catalog/definition cut.
    catalog.transaction_read = null;
    var public = (try resolve(&catalog, &access, "selected_0")).?;
    const rename = try edit(&public, 800, .{ .rename = try a.Name.init("renamed") });
    public.deinit();
    _ = try catalog.admit(rename, access.policy());
    _ = try catalog.perform(rename.binding, access.policy());
    catalog.transaction_read = context;
    var historical = (try resolve(&catalog, &access, "selected_0")).?;
    try t.expectEqualStrings("selected_0", historical.properties.name.slice());
    try t.expectEqualDeep(observed, historical.table.workspace_read.?);
    historical.deinit();
    try t.expect(try resolve(&catalog, &access, "renamed") == null);
    catalog.transaction_read = null;
    // An explicit abort invalidates cursors even before its cleanup finishes.
    _ = try catalog.settleTransaction(binding.key, .{ .scope = scope, .principal = 1, .operation = 900 }, .abort, 1, access.policy());
    catalog.transaction_read = context;
    try t.expectError(error.TransactionReadChanged, catalog.snapshotRead(t.allocator, object, handle, access.policy()));
    catalog.transaction_read = null;
}

test "transaction private scans preserve bounded source evidence and reject stale cursors" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 1);
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    for (0..3) |i| _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, i + 1, 500 + i), access.policy());
    const context: c.DirectTransactionRead.Context = .{ .key = binding.key, .revision = (try catalog.inspectTransaction(binding.key, access.policy())).revision };
    catalog.transaction_read = context;
    var view = (try resolve(&catalog, &access, "selected_0")).?;
    defer view.deinit();
    const evidence = view.table.workspace_read.?;
    const object = view.table.root.interpretation.object;
    const handle: P.SnapshotHandle = .{ .owner = evidence.cut.begin.identity.begin, .content = evidence.private };
    var page = try catalog.scanRows(t.allocator, object, handle, null, .{ .rows = 1 }, access.policy());
    defer page.deinit();
    try t.expectEqual(@as(u8, 1), page.count);
    try t.expect(page.next != null);
    try t.expectEqualDeep(evidence.source.source.accepted, page.accepted);
    var second = try catalog.scanRows(t.allocator, object, handle, page.next, .{ .rows = 1 }, access.policy());
    defer second.deinit();
    try t.expectEqual(@as(u8, 1), second.count);
    try t.expect(!std.meta.eql(page.rows[0].?.row().identity, second.rows[0].?.row().identity));
    var columns_page = try catalog.scanColumns(t.allocator, object, handle, &.{0}, null, .{ .rows = 1 }, access.policy());
    defer columns_page.deinit();
    try t.expectEqualDeep(page.accepted, columns_page.accepted);
    try t.expectEqual(page.changed_lsn, columns_page.changed_lsn);
    var range_page = try catalog.rangeRows(t.allocator, object, handle, .{}, null, .{ .rows = 1 }, access.policy());
    defer range_page.deinit();
    try t.expectEqualDeep(page.accepted, range_page.accepted);
    var fields: [c.fuze.TableSchema.max_columns]c.fuze.Types.Field = undefined;
    const schema = view.table.declaration.schema.schema;
    const plan: c.fuze.LogicalQuery.Plan = .{ .schema = try schema.rowType(&fields), .source_basis = @splat(1), .projection = &.{0}, .collations = .fromTable(schema), .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = 501 } } } };
    var filtered = try catalog.scanFiltered(t.allocator, object, handle, plan, null, .{}, access.policy());
    defer filtered.deinit();
    try t.expectEqualDeep(page.accepted, filtered.page.accepted);
    try t.expectEqual(@as(u8, 1), filtered.page.count);
    try t.expectEqual(@as(i128, 501), filtered.page.rows[0].?.row().cells[0].value.atom.signed);
    // Closing a private cursor does not release the transaction's original pin.
    try catalog.releaseRows(object, handle, access.policy());
    var alive = try catalog.snapshotRead(t.allocator, object, handle, access.policy());
    alive.deinit();
    access.denied_metadata = 110;
    try t.expectError(error.CatalogDenied, catalog.scanRows(t.allocator, object, handle, page.next, .{}, access.policy()));
    access.denied_metadata = null;
    catalog.transaction_read = null;
    try t.expectError(error.DataIdentityConflict, catalog.snapshotRead(t.allocator, object, handle, access.policy()));
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 4, 503), access.policy());
    catalog.transaction_read = context;
    try t.expectError(error.TransactionReadChanged, catalog.scanRows(t.allocator, object, handle, page.next, .{}, access.policy()));
    catalog.transaction_read = null;
}

fn savepointRequest(catalog: *D, access: *Access, key: c.DirectClientToken.Key, operation: u64, action: @FieldType(c.DirectTransactionSavepoint.Request, "action")) !c.DirectTransactionSavepoint.Request {
    const status = try catalog.inspectTransaction(key, access.policy());
    return .{ .transaction = status.begin.identity, .operation = .{ .scope = scope, .principal = 1, .operation = operation }, .sequence = status.last_control + 1, .basis = status.revision, .action = action };
}

test "transaction savepoints recover paged rollback and preserve consumed identities after disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var binding: c.DirectClientToken.Binding = undefined;
    var saved: c.DirectTransactionSavepoint.Request = undefined;
    var rollback: c.DirectTransactionSavepoint.Request = undefined;
    var rolled_back: c.DirectTransactionWorkspace.Request = undefined;
    var expected: s.TableWorkspace.Outcome = undefined;
    var stale: c.DirectTransactionRead.Context = undefined;
    for (0..6) |restart| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        switch (restart) {
            0 => {
                try catalog.initialize(access.policy());
                binding = try selectedTransaction(&catalog, &access, 3);
                _ = try catalog.acquireTransaction(binding.key, access.policy());
                _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500), access.policy());
                saved = try savepointRequest(&catalog, &access, binding.key, 800, .{ .create = try a.Name.init("before_more") });
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.transactionSavepoint(binding.key, saved, 1, access.policy()));
            },
            1 => {
                const before = catalog.store.root;
                try t.expect((try catalog.transactionSavepoint(binding.key, saved, 1, access.policy())).completed != null);
                try t.expectEqualDeep(before, catalog.store.root);
                rolled_back = try workspaceRequest(&catalog, &access, binding.key, 10, 2, 501);
                expected = try catalog.executeTransactionStatement(binding.key, rolled_back, access.policy());
                _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 11, 3, 502), access.policy());
                _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 12, 4, 503), access.policy());
                stale = .{ .key = binding.key, .revision = (try catalog.inspectTransaction(binding.key, access.policy())).revision };
                rollback = try savepointRequest(&catalog, &access, binding.key, 801, .{ .rollback = try a.Name.init("before_more") });
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.transactionSavepoint(binding.key, rollback, 1, access.policy()));
            },
            2, 3 => {
                try t.expect((try catalog.inspectTransaction(binding.key, access.policy())).pending_control);
                try t.expectError(error.TransactionReadChanged, catalog.transactionReadHead(stale, access.policy()));
                try t.expectError(error.TransactionControlPending, catalog.settleTransaction(binding.key, .{ .scope = scope, .principal = 1, .operation = 900 }, .commit, 1, access.policy()));
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.transactionSavepoint(binding.key, rollback, 1, access.policy()));
                try t.expect((try catalog.inspectTransaction(binding.key, access.policy())).pending_control);
                // No page of a rollback publishes public data or changes the
                // active private roots while the restoration remains pending.
                try t.expectEqual(@as(u64, 2), (try catalog.transactionTableState(binding.key, rolled_back.binding.target, access.policy())).root.live_rows);
            },
            4 => {
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.transactionSavepoint(binding.key, rollback, 1, access.policy()));
                try t.expect(!(try catalog.inspectTransaction(binding.key, access.policy())).pending_control);
            },
            5 => {
                const before = catalog.store.root;
                const result = try catalog.transactionSavepoint(binding.key, rollback, 1, access.policy());
                try t.expect(result.completed != null);
                try t.expectEqualDeep(before, catalog.store.root);
                try t.expectEqualDeep(expected, try catalog.executeTransactionStatement(binding.key, rolled_back, access.policy()));
                for (0..3) |i| {
                    const state = try catalog.transactionTableState(binding.key, .{ .scope = scope, .branch = 1, .object = 10 + i }, access.policy());
                    try t.expectEqual(@as(u64, if (i == 0) 1 else 0), state.root.live_rows);
                }
                // New statement numbers and immutable segment numbers continue
                // beyond the rolled-back work; original operations stay bound.
                _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 11, 5, 504), access.policy());
                const terminal = try catalog.settleTransaction(binding.key, .{ .scope = scope, .principal = 1, .operation = 900 }, .commit, 8, access.policy());
                try t.expect(terminal.cleanup_complete and terminal.observation.decided.outcome == .committed);
                try t.expectEqualDeep(expected, (try catalog.transactionStatementOutcome(binding.key, rolled_back, access.policy())).?);
                try t.expectEqualDeep(result, (try catalog.transactionSavepointOutcome(binding.key, rollback, access.policy())).?);
                access.denied_metadata = 110;
                try t.expectError(error.CatalogDenied, catalog.transactionStatementOutcome(binding.key, rolled_back, access.policy()));
                access.denied_metadata = null;
                for ([_][]const u8{ "selected_0", "selected_1", "selected_2" }, 0..) |name, i| {
                    var public = (try resolve(&catalog, &access, name)).?;
                    defer public.deinit();
                    try t.expectEqual(@as(u64, if (i == 2) 0 else 1), public.table.root.live_rows);
                }
            },
            else => unreachable,
        }
    }
}

test "transaction savepoint shadowing release and limits retain explicit scope" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 1);
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    const name = try a.Name.init("s");
    const first = try savepointRequest(&catalog, &access, binding.key, 800, .{ .create = name });
    _ = try catalog.transactionSavepoint(binding.key, first, 1, access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500), access.policy());
    _ = try catalog.transactionSavepoint(binding.key, try savepointRequest(&catalog, &access, binding.key, 801, .{ .create = name }), 1, access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 2, 501), access.policy());
    const latest = try savepointRequest(&catalog, &access, binding.key, 802, .{ .rollback = name });
    try t.expect((try catalog.transactionSavepoint(binding.key, latest, 1, access.policy())).completed == null);
    const resumed = try catalog.resumeTransaction(binding.key, 1, access.policy());
    try t.expect(!resumed.pending_control and resumed.savepoints == 2 and resumed.last_statement == 2);
    const object: p.DataLifecycle.Object = .{ .scope = scope, .branch = 1, .object = 10 };
    try t.expectEqual(@as(u64, 1), (try catalog.transactionTableState(binding.key, object, access.policy())).root.live_rows);
    _ = try catalog.transactionSavepoint(binding.key, try savepointRequest(&catalog, &access, binding.key, 803, .{ .release = name }), 1, access.policy());
    try t.expectEqual(@as(u64, 1), (try catalog.inspectTransaction(binding.key, access.policy())).savepoints);
    const original = try savepointRequest(&catalog, &access, binding.key, 804, .{ .rollback = name });
    _ = try catalog.transactionSavepoint(binding.key, original, 1, access.policy());
    _ = try catalog.resumeTransaction(binding.key, 1, access.policy());
    try t.expectEqual(@as(u64, 0), (try catalog.transactionTableState(binding.key, object, access.policy())).root.live_rows);
    var conflict = first;
    conflict.action = .{ .release = name };
    try t.expectError(error.TransactionControlConflict, catalog.transactionSavepoint(binding.key, conflict, 1, access.policy()));
    const before = catalog.store.root;
    try t.expectError(error.TransactionSavepointMissing, catalog.transactionSavepoint(binding.key, try savepointRequest(&catalog, &access, binding.key, 805, .{ .release = try a.Name.init("missing") }), 1, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    _ = try catalog.settleTransaction(binding.key, .{ .scope = scope, .principal = 1, .operation = 900 }, .abort, 4, access.policy());
}

test "transaction savepoint graph retains saved and partial rollback roots with bounded jobs" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 2);
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500), access.policy());
    const saved_progress = (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?;
    const saved_root = (try c.DirectTransactionWorkspace.recover(t.allocator, catalog.data_objects, saved_progress)).tables.?;
    _ = try catalog.transactionSavepoint(binding.key, try savepointRequest(&catalog, &access, binding.key, 800, .{ .create = try a.Name.init("s") }), 1, access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 2, 501), access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 11, 3, 502), access.policy());
    const rollback = try savepointRequest(&catalog, &access, binding.key, 801, .{ .rollback = try a.Name.init("s") });
    _ = try catalog.transactionSavepoint(binding.key, rollback, 1, access.policy());
    _ = try catalog.resumeTransaction(binding.key, 1, access.policy());
    var key_buffer: [96]u8 = undefined;
    for (0..2) |phase| {
        const progress = (try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?;
        const head = try c.DirectTransactionWorkspace.recover(t.allocator, catalog.data_objects, progress);
        var graph: @import("direct_storage_graph_test.zig").Workspace = .{};
        defer graph.deinit();
        try graph.enqueue(.{ .transaction = .{ .root = catalog.store.root, .progress = progress } });
        var at: usize = 0;
        while (at < graph.jobs.items.len) : (at += 1) {
            var work = graph.jobs.items[at];
            while (true) {
                const before = graph.jobs.items.len;
                const done = try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &graph);
                try t.expect(graph.jobs.items.len - before <= 3);
                if (done) break;
            }
        }
        try t.expectEqual(phase == 0, graph.marks.contains(try s.TreeStore.key(saved_root.location, &key_buffer)));
        if (phase == 0) {
            try t.expect(graph.marks.contains(try s.TreeStore.key(head.pending_control.?.tables.?.location, &key_buffer)));
            _ = try catalog.resumeTransaction(binding.key, 1, access.policy());
            _ = try catalog.transactionSavepoint(binding.key, try savepointRequest(&catalog, &access, binding.key, 802, .{ .release = try a.Name.init("s") }), 1, access.policy());
        }
    }
}

test "transaction savepoint quota refuses unaccepted work and abort closes a stalled rollback" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    var binding = try transactionToken(&catalog, 9000, 1, 0);
    binding.intent.transaction.begin.limits.savepoints = 1;
    binding.intent.transaction.begin.limits.resident_bytes = 16 * 1024 * 1024;
    _ = try catalog.clientToken(.{ .bind = binding }, access.policy());
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    _ = try catalog.transactionSavepoint(binding.key, try savepointRequest(&catalog, &access, binding.key, 800, .{ .create = try a.Name.init("only") }), 1, access.policy());
    const before = catalog.store.root;
    try t.expectError(error.TransactionSavepointLimit, catalog.transactionSavepoint(binding.key, try savepointRequest(&catalog, &access, binding.key, 801, .{ .create = try a.Name.init("second") }), 1, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    const rollback = try savepointRequest(&catalog, &access, binding.key, 802, .{ .rollback = try a.Name.init("only") });
    _ = try catalog.transactionSavepoint(binding.key, rollback, 1, access.policy());
    try t.expect((try catalog.inspectTransaction(binding.key, access.policy())).pending_control);
    const terminal = try catalog.settleTransaction(binding.key, .{ .scope = scope, .principal = 1, .operation = 900 }, .abort, 1, access.policy());
    try t.expect(terminal.cleanup_complete and terminal.observation.decided.outcome == .aborted);
    try t.expectEqual(@as(u64, 0), (try catalog.store.clientUsage(catalog.store.root, binding.key)).?.transactions.count);
}

test "transaction caller tokens retain exact work before owner admission and cannot manufacture completion" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const parent = try selectedTransaction(&catalog, &access, 1);
    _ = try catalog.acquireTransaction(parent.key, access.policy());
    const request = try workspaceRequest(&catalog, &access, parent.key, 10, 1, 500);
    const before = catalog.store.root;
    try t.expect(try catalog.transactionStatementOutcome(parent.key, request, access.policy()) == null);
    try t.expectEqualDeep(before, catalog.store.root);
    var key = parent.key;
    key.token = @splat(2);
    const call: c.DirectTransactionCall = .{ .connection = key.connection, .namespace = 1, .operation = 800, .work = .{ .statement = .{ .key = parent.key, .request = request } } };
    const binding: c.DirectClientToken.Binding = .{ .key = key, .fingerprint = @splat(3), .budget = .{ .bytes = c.DirectTransactionCall.reservation_bytes }, .intent = .{ .transaction_call = call } };
    const receipt = (try catalog.clientToken(.{ .bind = binding }, access.policy())).?;
    var encoded: [c.DirectIntent.max_bytes]u8 = undefined;
    try t.expectEqualDeep(binding.intent, try c.DirectIntent.decode(t.allocator, try c.DirectIntent.encode(binding.intent, &encoded)));
    var progress = (try catalog.clientProgress(.{ .inspect = key }, access.policy())).state.?;
    try t.expectError(error.TransactionOperationRequired, catalog.clientProgress(.{ .update = .{ .key = key, .expected = progress.revision, .pending = false, .cancel = false, .record = null } }, access.policy()));
    var graph: @import("direct_storage_graph_test.zig").Workspace = .{};
    defer graph.deinit();
    try graph.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
    var at: usize = 0;
    while (at < graph.jobs.items.len) : (at += 1) {
        var work = graph.jobs.items[at];
        while (!try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &graph)) {}
    }
    var name: [96]u8 = undefined;
    try t.expect(graph.marks.contains(try s.TableDmlIntent.key(request.intent, &name)));
    const outcome = (try catalog.transactionCall(key, 1, false, false, access.policy())).?.statement;
    try t.expectEqualDeep(outcome, (try catalog.transactionStatementOutcome(parent.key, request, access.policy())).?);
    progress = (try catalog.clientProgress(.{ .inspect = key }, access.policy())).state.?;
    try t.expect(!progress.pending);
    try t.expectEqualDeep(outcome, (try catalog.transactionCallOutcome(key, access.policy())).?.statement);
    try t.expectEqualDeep(receipt, (try catalog.clientToken(.{ .bind = binding }, access.policy())).?);
    var old = request;
    old.binding.identity.operation = 501;
    try t.expectError(error.TransactionStatementConflict, catalog.transactionStatementOutcome(parent.key, old, access.policy()));
}

test "transaction caller commands recover original results and durable refusals across disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var parent: c.DirectClientToken.Binding = undefined;
    var binding: c.DirectClientToken.Binding = undefined;
    var stale: c.DirectClientToken.Binding = undefined;
    var settlement: c.DirectClientToken.Binding = undefined;
    var decision: ?p.Transaction.Decision = null;
    for (0..7) |restart| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        switch (restart) {
            0 => {
                try catalog.initialize(access.policy());
                parent = try selectedTransaction(&catalog, &access, 2);
                _ = try catalog.acquireTransaction(parent.key, access.policy());
                var key = parent.key;
                key.token = @splat(2);
                binding = .{ .key = key, .fingerprint = @splat(3), .budget = .{ .bytes = c.DirectTransactionCall.reservation_bytes }, .intent = .{ .transaction_call = .{
                    .connection = key.connection,
                    .namespace = 1,
                    .operation = 800,
                    .work = .{ .statement = .{ .key = parent.key, .request = try workspaceRequest(&catalog, &access, parent.key, 10, 1, 500) } },
                } } };
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.clientToken(.{ .bind = binding }, access.policy()));
            },
            1, 2, 3 => {
                const before = catalog.store.root;
                try t.expectError(error.InvalidTransactionWork, catalog.transactionCall(binding.key, 1, true, false, access.policy()));
                try t.expectEqualDeep(before, catalog.store.root);
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.transactionCall(binding.key, 1, false, false, access.policy()));
            },
            4 => {
                const result = (try catalog.transactionCallOutcome(binding.key, access.policy())).?;
                try t.expectEqual(@as(u64, 1), result.statement.provisional.affected);
                try t.expect(!(try catalog.clientProgress(.{ .inspect = binding.key }, access.policy())).state.?.pending);
                try t.expectEqualDeep(result, (try catalog.transactionCall(binding.key, 1, false, true, access.policy())).?);
                var key = binding.key;
                key.token = @splat(4);
                const request = try workspaceRequest(&catalog, &access, parent.key, 11, 2, 501);
                _ = try catalog.transactionSavepoint(parent.key, try savepointRequest(&catalog, &access, parent.key, 900, .{ .create = try a.Name.init("later") }), 1, access.policy());
                stale = .{ .key = key, .fingerprint = @splat(5), .budget = .{ .bytes = c.DirectTransactionCall.reservation_bytes }, .intent = .{ .transaction_call = .{
                    .connection = key.connection,
                    .namespace = 1,
                    .operation = 801,
                    .work = .{ .statement = .{ .key = parent.key, .request = request } },
                } } };
                _ = try catalog.clientToken(.{ .bind = stale }, access.policy());
                catalog.store.lose_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.transactionCall(stale.key, 1, false, false, access.policy()));
            },
            5 => {
                try t.expectEqual(c.DirectTransactionCall.Refusal.stale_workspace, (try catalog.transactionCallOutcome(stale.key, access.policy())).?.rejected);
                try t.expectEqual(@as(u64, 1), (try catalog.inspectTransaction(parent.key, access.policy())).last_statement);
                var key = binding.key;
                key.token = @splat(6);
                settlement = .{ .key = key, .fingerprint = @splat(7), .budget = .{ .bytes = c.DirectTransactionCall.reservation_bytes }, .intent = .{ .transaction_call = .{
                    .connection = key.connection,
                    .namespace = 1,
                    .operation = 802,
                    .work = .{ .settle = .{ .key = parent.key, .operation = .{ .scope = scope, .principal = 1, .operation = 901 }, .command = .commit } },
                } } };
                _ = try catalog.clientToken(.{ .bind = settlement }, access.policy());
                catalog.lose_transaction_reply = true;
                try t.expectError(error.LostAcknowledgement, catalog.transactionCall(key, 8, true, true, access.policy()));
                try t.expect(try catalog.transactionCallOutcome(key, access.policy()) == null);
                try t.expectError(error.LostAcknowledgement, catalog.transactionCall(key, 8, true, true, access.policy()));
                // Stop-wait cancellation is not rollback, including before the
                // decision. Only the original owner's actual decision is evidence.
                decision = (try catalog.transactionCallOutcome(key, access.policy())).?.settled.observation.decided;
                try t.expect(decision.?.outcome == .committed);
                const progress = (try catalog.clientProgress(.{ .inspect = key }, access.policy())).state.?;
                try t.expect(progress.pending and progress.cancel);
            },
            6 => {
                var finished = false;
                for (0..8) |_| {
                    const result = try catalog.transactionCall(settlement.key, 1, true, false, access.policy()) orelse continue;
                    try t.expectEqualDeep(decision.?, result.settled.observation.decided);
                    if (result.settled.cleanup_complete) {
                        finished = true;
                        break;
                    }
                }
                try t.expect(finished);
                try t.expect(!(try catalog.clientProgress(.{ .inspect = settlement.key }, access.policy())).state.?.pending);
                const before = catalog.store.root;
                _ = try catalog.transactionCall(binding.key, 1, false, false, access.policy());
                _ = try catalog.transactionCall(stale.key, 1, false, false, access.policy());
                try t.expectEqualDeep(before, catalog.store.root);
                try t.expectEqual(@as(u64, 0), (try catalog.store.clientUsage(catalog.store.root, parent.key)).?.transactions.count);
            },
            else => unreachable,
        }
    }
}

test "transaction predicate writes bind virtual private frontiers through rollback" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransaction(&catalog, &access, 1);
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500), access.policy());
    _ = try catalog.transactionSavepoint(binding.key, try savepointRequest(&catalog, &access, binding.key, 600, .{ .create = try a.Name.init("original") }), 1, access.policy());
    for ([_][]const u8{ "UPDATE selected_0 SET id=501 WHERE id=500", "DELETE FROM selected_0 WHERE id=500" }, 0..) |sql, i| {
        const current = try catalog.inspectTransaction(binding.key, access.policy());
        catalog.transaction_read = .{ .key = binding.key, .revision = current.revision };
        var private = (try resolve(&catalog, &access, "selected_0")).?;
        defer private.deinit();
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const schema = private.table.declaration.schema.schema;
        const view = private.table.workspace_read.?;
        try t.expect(view.private_position.next_lsn > view.source.source.accepted.next_lsn);
        try t.expectEqual(private.table.root.next_lsn, view.private_position.next_lsn);
        var buffer: [65536]u8 = undefined;
        const metadata: c.DirectTableProtocol.Definition = .{
            .interpretation = private.table.root.declared(),
            .namespace = private.properties.namespace,
            .authorization = private.properties.authorization,
            .name = private.properties.name,
            .position = view.source.source.accepted,
            .changed_lsn = view.source.changed_lsn,
            .workspace = view,
            .row_count = private.table.root.live_rows,
            .schema = try c.DirectTableProtocol.Binary.encode(allocator, try schema.encode(&buffer)),
        };
        var compiled = try c.fuze.TableDml.compile(allocator, sql, "selected_0", schema, null);
        defer compiled.deinit();
        var intent = try c.DirectTableIntent.fromDml(allocator, binding.key.connection, metadata, 700 + i, compiled.plan, .bulk);
        defer intent.deinit();
        try t.expectEqualDeep(@as(?p.DataLifecycle.Position, view.private_position), intent.binding().expected_data);
        catalog.transaction_read = null;
        const request = try catalog.stageTransactionStatement(binding.key, current.revision, current.last_statement + 1, intent.parsed.value.work, access.policy());
        const result = try catalog.executeTransactionStatement(binding.key, request, access.policy());
        try t.expectEqual(@as(u64, 1), result.provisional.matched);
        try t.expectEqual(@as(u64, 1), result.provisional.affected);
        if (i == 0) {
            const rollback = try savepointRequest(&catalog, &access, binding.key, 601, .{ .rollback = try a.Name.init("original") });
            var completed = false;
            for (0..8) |_| {
                if ((try catalog.transactionSavepoint(binding.key, rollback, 8, access.policy())).completed != null) {
                    completed = true;
                    break;
                }
            }
            try t.expect(completed);
        }
    }
    const state = try catalog.transactionTableState(binding.key, .{ .scope = scope, .branch = 1, .object = 10 }, access.policy());
    try t.expectEqual(@as(u64, 0), state.root.live_rows);
    const result = try catalog.settleTransaction(binding.key, .{ .scope = scope, .principal = 1, .operation = 800 }, .commit, 8, access.policy());
    try t.expect(result.cleanup_complete and result.observation.decided.outcome == .committed);
}

fn logCreation(kind: c.DirectLog.Kind, object: u64, operation: u64, name: []const u8, partitions: u32) !c.DirectLog.Request {
    const intent: c.DirectLog.Intent = .{ .kind = kind, .namespace = 1, .name = try .init(name), .action = .{ .create = .{
        .owner = 0,
        .schema = .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{} },
        .configuration = .{ .partitioning = .{ .count = partitions, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = if (kind == .stream) .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } else .{ .queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 100, .maximum_lease_ms = 1000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    return .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = .{ .scope = scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) } };
}
fn logEdit(value: c.DirectLog.Definition, operation: u64, action: @FieldType(c.DirectLog.Intent, "action")) !c.DirectLog.Request {
    const intent: c.DirectLog.Intent = .{ .kind = value.kind(), .namespace = value.properties.namespace, .name = value.properties.name, .action = action };
    return .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = value.stored.declaration.interpretation.object, .action = switch (action) {
        .create => unreachable,
        .alter => .alter,
        .rename => .rename,
        .drop => .drop,
    }, .expected_definition = value.stored.declaration.interpretation, .expected_data = null, .intent = try intent.digest(t.allocator) } };
}

const TransactionLogFault = struct {
    underlying: s.TransitLog.Log,
    lose_reply: bool = false,
    fn log(self: *@This()) s.TransitLog.Log {
        return .{ .context = self, .vtable = &.{ .append = append, .read = read, .tail = tail, .trim = trim, .fence = fence } };
    }
    fn cast(raw: *anyopaque) *@This() {
        return @ptrCast(@alignCast(raw));
    }
    fn append(raw: *anyopaque, partition: u64, expected: ?u64, writer: u64, policy: u64, kind: s.TransitLog.FrameKind, bytes: []const u8) !s.TransitLog.AppendReceipt {
        const self = cast(raw);
        const result = try self.underlying.append(partition, expected, writer, policy, kind, bytes);
        if (self.lose_reply) {
            self.lose_reply = false;
            return error.InjectedReplyLoss;
        }
        return result;
    }
    fn read(raw: *anyopaque, allocator: std.mem.Allocator, partition: u64, from: u64, count: usize) !s.TransitLog.Log.OwnedBatch {
        return cast(raw).underlying.read(allocator, partition, from, count);
    }
    fn tail(raw: *anyopaque, partition: u64) !u64 {
        return cast(raw).underlying.tail(partition);
    }
    fn trim(raw: *anyopaque, partition: u64, until: u64) !void {
        return cast(raw).underlying.trim(partition, until);
    }
    fn fence(raw: *anyopaque, partition: u64, writer: u64, policy: u64) !void {
        return cast(raw).underlying.fence(partition, writer, policy);
    }
};

fn selectTransactionLogs(catalog: *D, access: *Access, mode: p.Transaction.Mode) !c.DirectClientToken.Receipt {
    return selectTransactionLogsWithQueue(catalog, access, mode, false);
}
fn selectTransactionLogsWithQueue(catalog: *D, access: *Access, mode: p.Transaction.Mode, fifo: bool) !c.DirectClientToken.Receipt {
    const table = try creation(10, 1, "rows");
    _ = try catalog.admit(table, access.policy());
    _ = try catalog.perform(table.binding, access.policy());
    var queue = try logCreation(.queue, 12, 3, "work", 1);
    if (fifo) {
        queue.intent.action.create.configuration.policy.queue.ordering = .key_fifo;
        queue.intent.action.create.configuration.policy.queue.key_column = 1;
        queue.binding.intent = try queue.intent.digest(t.allocator);
    }
    for ([_]c.DirectLog.Request{ try logCreation(.stream, 11, 2, "events", 2), queue }) |request| {
        _ = try catalog.admitLog(request, access.policy());
        for (0..request.intent.action.create.configuration.partitioning.count) |_| _ = try catalog.logOperation(request.binding, .execute, access.policy());
    }
    const template = try transactionToken(catalog, 9000, 1, 0);
    const targets = [_]p.Transaction.Target{
        .{ .object = table.binding.target, .kind = .table, .partition = null },
        .{ .object = .{ .scope = scope, .branch = 1, .object = 11 }, .kind = .stream, .partition = 0 },
        .{ .object = .{ .scope = scope, .branch = 1, .object = 11 }, .kind = .stream, .partition = 1 },
        .{ .object = .{ .scope = scope, .branch = 1, .object = 12 }, .kind = .queue, .partition = 0 },
    };
    return catalog.beginTransaction(.{
        .key = template.key,
        .fingerprint = template.fingerprint,
        .operation = template.intent.transaction.begin.identity.begin,
        .namespace = 1,
        .mode = mode,
        .selection = .{ .explicit_objects = &targets },
        .limits = c.DirectTransaction.default_limits,
        .budget = template.budget,
    }, access.policy());
}

test "transaction log statements share sequences and restore private actions through savepoints" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{ .exclusive = true };
    try catalog.initialize(access.policy());
    const receipt = try selectTransactionLogs(&catalog, &access, .serializable);
    const key = receipt.binding.key;
    _ = try catalog.acquireTransaction(key, access.policy());
    const definition = (try catalog.resolveLog(1, try .init("events"), access.policy())).?;
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = definition.stored.declaration.interpretation, .partition = 1 };
    const schema = (try logCreation(.stream, 11, 2, "events", 2)).intent.action.create.schema;
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    var bytes: [8192]u8 = undefined;
    var requests: [3]c.DirectTransactionLogWork.Request = undefined;
    var saved: c.DirectTransactionSavepoint.Request = undefined;
    var saved_logs: p.Transaction.Directory = undefined;
    for (0..3) |i| {
        const operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 600 + i };
        const payload = try s.LogBatch.encode(schema, operation, .stream, &.{.{ .cells = &cells }}, &bytes);
        const status = try catalog.inspectTransaction(key, access.policy());
        const request = try catalog.stageTransactionLog(key, status.revision, status.last_statement + 1, .{ .append = .{ .target = target, .operation = operation, .kind = .stream, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) } }, payload, access.policy());
        requests[i] = request;
        try t.expect(try catalog.admitTransactionLog(key, request, access.policy()) == null);
        // Private identity reservations exclude standalone publication even
        // before any log preparation or transaction decision exists.
        try t.expectError(error.DataIdentityConflict, c.OperationBinding.lookupStream(t.allocator, catalog.data_objects, operation));
        const outcome = try catalog.executeTransactionLog(key, request, access.policy());
        try t.expect(outcome == .provisional);
        const root = catalog.store.root;
        try t.expectEqualDeep(outcome, try catalog.executeTransactionLog(key, request, access.policy()));
        try t.expectEqualDeep(root, catalog.store.root);
        if (i == 0) {
            _ = try catalog.executeTransactionStatement(key, try workspaceRequest(&catalog, &access, key, 10, 2, 500), access.policy());
            saved = try savepointRequest(&catalog, &access, key, 800, .{ .create = try a.Name.init("keep_first") });
            _ = try catalog.transactionSavepoint(key, saved, 8, access.policy());
            const progress = (try catalog.clientProgress(.{ .inspect = key }, access.policy())).state.?;
            saved_logs = (try c.DirectTransactionWorkspace.recover(t.allocator, catalog.data_objects, progress)).logs.?;
        }
    }
    const rollback = try savepointRequest(&catalog, &access, key, 801, .{ .rollback = try a.Name.init("keep_first") });
    try t.expect((try catalog.transactionSavepoint(key, rollback, 8, access.policy())).completed == null);
    try t.expect((try catalog.transactionSavepoint(key, rollback, 8, access.policy())).completed != null);
    const progress = (try catalog.clientProgress(.{ .inspect = key }, access.policy())).state.?;
    const head = try c.DirectTransactionWorkspace.recover(t.allocator, catalog.data_objects, progress);
    try t.expectEqualDeep(saved_logs, head.logs.?);
    try t.expectEqual(@as(u64, 4), head.last_statement);
    try t.expect((try catalog.executeTransactionLog(key, requests[2], access.policy())) == .provisional);
    var cached: ?c.DirectStream.Cached = null;
    defer if (cached) |*value| value.deinit();
    try t.expectEqual(@as(u64, 0), (try streamCall(&catalog, &access, &cached, .{ .observe = target }, 256)).cut.next);
    try t.expect((try streamCall(&catalog, &access, &cached, .{ .operation = .{ .append = requests[0].work.append } }, 256)).operation == null);
    const commit: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9001 };
    try t.expect((try catalog.settleTransaction(key, commit, .commit, 3, access.policy())).observation == .preparing);
    const prepared_progress = (try catalog.clientProgress(.{ .inspect = key }, access.policy())).state.?;
    const control = try c.DirectTransactionControl.load(t.allocator, catalog.data_objects, prepared_progress);
    var preparations = try s.TransactionDirectory.init(t.allocator, catalog.data_objects, control.binding.begin.identity, .preparations, control.binding.begin.limits.participants, 1, 1024 * 1024);
    defer preparations.deinit();
    try preparations.restore(control.preparations.?);
    const prepared = (try preparations.get((p.Transaction.Guard{ .log = requests[0].guard }).target())).?.prepared;
    const preparation = try s.LogTransaction.loadPreparation(catalog.data_objects, .{ .content = prepared.successor });
    var index = try s.TreeStore.init(t.allocator, catalog.data_objects, 1);
    defer index.deinit();
    var tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &index };
    const segment_page = try tree.scan(preparation.successor.segments, null);
    const descriptor = try s.LogSegment.Descriptor.decode(segment_page.entries[0].?.value);
    const segment = descriptor.segment.?;
    const saved_bytes = try t.allocator.alloc(u8, @intCast(segment.bytes));
    defer t.allocator.free(saved_bytes);
    var segment_key: [96]u8 = undefined;
    const path = try s.LogSegment.segmentKey(segment, &segment_key);
    _ = try catalog.data_objects.getRange(path, 0, @intCast(saved_bytes.len), saved_bytes);
    try catalog.data_objects.delete(path);
    try t.expectError(error.LogSegmentMissing, catalog.settleTransaction(key, commit, .commit, 16, access.policy()));
    try t.expect((try catalog.inspectTransaction(key, access.policy())).observation == .preparing);
    _ = try catalog.data_objects.putImmutable(path, saved_bytes, segment.sha256);
    access.denied_privileges = .{ .id = definition.properties.authorization, .mask = c.LogAuthority.append };
    try t.expectError(error.CatalogDenied, catalog.settleTransaction(key, commit, .commit, 16, access.policy()));
    access.denied_privileges = null;
    const terminal = try catalog.settleTransaction(key, commit, .commit, 16, access.policy());
    try t.expect(terminal.cleanup_complete and terminal.observation.decided.outcome == .committed);
    try t.expectEqual(@as(u64, 1), (try streamCall(&catalog, &access, &cached, .{ .observe = target }, 256)).cut.next);
    const original = (try streamCall(&catalog, &access, &cached, .{ .operation = .{ .append = requests[0].work.append } }, 256)).operation.?.append;
    try t.expectEqual(@as(u64, 0), original.first);
    try t.expectEqual(@as(u64, 1), original.next);
    try t.expect((try streamCall(&catalog, &access, &cached, .{ .operation = .{ .append = requests[2].work.append } }, 256)).operation == null);
    var rows = (try resolve(&catalog, &access, "rows")).?;
    defer rows.deinit();
    try t.expectEqual(@as(u64, 1), rows.table.root.live_rows);
}

test "transaction log statements atomically enqueue and ACK with lost decision recovery and final lease fencing" {
    const FinalClock = struct {
        now: s.LogTime.Sample = .exact(100),
        reads: usize = 0,
        expire_at: ?usize = null,
        fn read(raw: *anyopaque) !?s.LogTime.Sample {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.reads += 1;
            if (self.expire_at) |at| {
                if (self.reads >= at) self.now = .exact(200);
            }
            return self.now;
        }
        fn source(self: *@This()) s.LogTime.Source {
            return .{ .context = self, .read = read };
        }
    };
    for ([_]bool{ false, true }) |fifo| for ([_]bool{ false, true }) |expire| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var access: Access = .{ .exclusive = true };
        var receipt: c.DirectClientToken.Receipt = undefined;
        var claim: p.StreamQueue.ClaimReceipt = undefined;
        var target: p.StreamQueue.Partition = undefined;
        var ack: c.DirectTransactionLogWork.Request = undefined;
        const commit: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9001 };
        for (0..2) |restart| {
            var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
            defer wal.deinit();
            var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
            defer objects.deinit();
            var catalog = try owner(&wal, &objects);
            defer catalog.deinit();
            catalog.options.resident_pages = (D.Options{}).resident_pages;
            var clock: QueueClock = .{};
            var cached: ?c.DirectQueue.Cached = null;
            defer if (cached) |*value| value.deinit();
            if (restart == 0) {
                try catalog.initialize(access.policy());
                receipt = try selectTransactionLogsWithQueue(&catalog, &access, .serializable, fifo);
                const declaration = (try catalog.resolveLog(1, try .init("work"), access.policy())).?;
                target = .{ .definition = p.Growth.current_definition, .interpretation = declaration.stored.declaration.interpretation, .partition = 0 };
                const operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 600 };
                const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
                const schema = (try logCreation(.queue, 12, 3, "work", 1)).intent.action.create.schema;
                var bytes: [8192]u8 = undefined;
                const payload = try s.LogBatch.encode(schema, operation, .queue, &.{.{ .cells = &cells }}, &bytes);
                const encoded = try c.DirectTableProtocol.Binary.encode(t.allocator, payload);
                defer t.allocator.free(encoded.base64);
                _ = try queueCall(&catalog, &access, &cached, &clock, .{ .mutate = .{ .work = .{ .enqueue = .{ .target = target, .operation = operation, .kind = .queue, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) } }, .payload = encoded } }, 256);
                claim = (try queueCall(&catalog, &access, &cached, &clock, .{ .mutate = .{ .work = .{ .claim = .{ .target = target, .operation = .{ .scope = scope, .principal = 1, .operation = 601 }, .maximum = 1, .lease_ms = 100 } }, .payload = null } }, 256)).operation.?.claim;
                const page = try queueCall(&catalog, &access, &cached, &clock, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } }, 256);
                defer page.deinit(t.allocator);
                const key = receipt.binding.key;
                _ = try catalog.acquireTransaction(key, access.policy());
                var trusted: FinalClock = .{};
                const environment: c.DirectTransactionLog.Environment = .{ .clock = trusted.source() };
                catalog.log_environment = &environment;
                defer catalog.log_environment = null;
                const status = try catalog.inspectTransaction(key, access.policy());
                ack = try catalog.stageTransactionLog(key, status.revision, 1, .{ .queue_ack = .{ .operation = .{ .scope = scope, .principal = 1, .operation = 602 }, .lease = page.page.rows[0].lease.original, .action = .ack } }, null, access.policy());
                try t.expect((try catalog.executeTransactionLog(key, ack, access.policy())) == .provisional);
                _ = try catalog.executeTransactionStatement(key, try workspaceRequest(&catalog, &access, key, 10, 2, 500), access.policy());
                const enqueued: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 603 };
                const next_payload = try s.LogBatch.encode(schema, enqueued, .queue, &.{.{ .cells = &cells }}, &bytes);
                const next = try catalog.inspectTransaction(key, access.policy());
                const append = try catalog.stageTransactionLog(key, next.revision, 3, .{ .append = .{ .target = target, .operation = enqueued, .kind = .queue, .producer = null, .rows = 1, .payload = s.LogBatch.content(next_payload) } }, next_payload, access.policy());
                try t.expect((try catalog.executeTransactionLog(key, append, access.policy())) == .provisional);
                // Freeze and prepare the Table, leaving log verification for
                // the following call. No public queue state has changed yet.
                _ = try catalog.settleTransaction(key, commit, .commit, 1, access.policy());
                trusted.reads = 0;
                if (expire) {
                    // Preparation and prepared-owner checks see a live lease;
                    // only the final clock check observes its deadline.
                    trusted.expire_at = 3;
                    try t.expectError(error.QueueLeaseExpired, catalog.settleTransaction(key, commit, .commit, 16, access.policy()));
                    try t.expectEqual(@as(usize, 3), trusted.reads);
                    try t.expect((try catalog.inspectTransaction(key, access.policy())).observation == .preparing);
                } else {
                    catalog.lose_transaction_reply = true;
                    try t.expectError(error.LostAcknowledgement, catalog.settleTransaction(key, commit, .commit, 16, access.policy()));
                }
            } else {
                // Resolution uses the recorded decision without any clock or
                // old input rights, even though the input lease has now expired.
                const terminal = try catalog.settleTransaction(receipt.binding.key, commit, .abort, 16, access.policy());
                try t.expect(terminal.cleanup_complete);
                try t.expectEqual(@as(@FieldType(p.Transaction.Decision, "outcome"), if (expire) .aborted else .committed), terminal.observation.decided.outcome);
                clock.now = .exact(1000);
                const page = try queueCall(&catalog, &access, &cached, &clock, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } }, 256);
                defer page.deinit(t.allocator);
                try t.expectEqual(@as(p.QueueRead.State, if (expire) .acquired else .acked), page.page.rows[0].lease.state);
                try t.expectEqual(@as(u64, if (expire) 1 else 2), (try queueCall(&catalog, &access, &cached, &clock, .{ .observe = target }, 256)).cut.next);
                try t.expect((try catalog.transactionLogOutcome(receipt.binding.key, ack, access.policy())).? == .provisional);
                const original = (try queueCall(&catalog, &access, &cached, &clock, .{ .operation = .{ .settle = ack.work.queue_ack } }, 256)).operation;
                try t.expectEqual(!expire, original != null);
                if (original) |value| try t.expectEqualDeep(ack.work.queue_ack, value.settle.settlement);
                var rows = (try resolve(&catalog, &access, "rows")).?;
                defer rows.deinit();
                try t.expectEqual(@as(u64, if (expire) 0 else 1), rows.table.root.live_rows);
            }
        }
    };
}

test "transaction log terminal transfers preserve both owners through denial rollback expiry and disk replacement" {
    return terminalTransferCases() catch |err| {
        std.debug.print("terminal transfer error: {s}\n", .{@errorName(err)});
        return err;
    };
}
fn terminalTransferCases() !void {
    const Case = enum { commit, exhausted, expire, rollback };
    for ([_]Case{ .commit, .exhausted, .expire, .rollback }) |case| {
        var phase: []const u8 = "initialization";
        errdefer std.debug.print("terminal transfer {s} during {s}\n", .{ @tagName(case), phase });
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var access: Access = .{ .exclusive = true };
        var receipt: c.DirectClientToken.Receipt = undefined;
        var claim: p.StreamQueue.ClaimReceipt = undefined;
        var request: c.DirectTransactionLogWork.Request = undefined;
        var source_target: p.StreamQueue.Partition = undefined;
        var destination_target: p.StreamQueue.Partition = undefined;
        const commit: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9001 };
        for (0..2) |restart| {
            var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
            defer wal.deinit();
            var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
            defer objects.deinit();
            var catalog = try owner(&wal, &objects);
            defer catalog.deinit();
            catalog.options.resident_pages = (D.Options{}).resident_pages;
            var clock: QueueClock = .{};
            var cached: ?c.DirectQueue.Cached = null;
            defer if (cached) |*value| value.deinit();
            if (restart == 0) {
                try catalog.initialize(access.policy());
                var destination = try logCreation(.queue, 12, 2, "dead_letters", 1);
                destination.intent.action.create.configuration.policy.queue.ordering = .key_fifo;
                destination.intent.action.create.configuration.policy.queue.key_column = 1;
                destination.binding.intent = try destination.intent.digest(t.allocator);
                _ = try catalog.admitLog(destination, access.policy());
                _ = try catalog.logOperation(destination.binding, .execute, access.policy());
                const destination_definition = (try catalog.resolveLog(1, try .init("dead_letters"), access.policy())).?;
                destination_target = .{ .definition = p.Growth.current_definition, .interpretation = destination_definition.stored.declaration.interpretation, .partition = 0 };
                var source = try logCreation(.queue, 11, 1, "inbox", 1);
                source.intent.action.create.configuration.policy.queue.ordering = .key_fifo;
                source.intent.action.create.configuration.policy.queue.key_column = 1;
                source.intent.action.create.configuration.policy.queue.dead_letter = destination_target.interpretation;
                if (case == .exhausted) source.intent.action.create.configuration.policy.queue.maximum_attempts = 1;
                source.binding.intent = try source.intent.digest(t.allocator);
                _ = try catalog.admitLog(source, access.policy());
                _ = try catalog.logOperation(source.binding, .execute, access.policy());
                const source_definition = (try catalog.resolveLog(1, try .init("inbox"), access.policy())).?;
                source_target = .{ .definition = p.Growth.current_definition, .interpretation = source_definition.stored.declaration.interpretation, .partition = 0 };
                const operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 600 };
                const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
                var bytes: [8192]u8 = undefined;
                const original_payload = try s.LogBatch.encode(source.intent.action.create.schema, operation, .queue, &.{ .{ .cells = &cells, .visible_ms = 75 }, .{ .cells = &cells, .visible_ms = 75 } }, &bytes);
                const encoded = try c.DirectTableProtocol.Binary.encode(t.allocator, original_payload);
                defer t.allocator.free(encoded.base64);
                _ = try queueCall(&catalog, &access, &cached, &clock, .{ .mutate = .{ .work = .{ .enqueue = .{ .target = source_target, .operation = operation, .kind = .queue, .producer = null, .rows = 2, .payload = s.LogBatch.content(original_payload) } }, .payload = encoded } }, 256);
                claim = (try queueCall(&catalog, &access, &cached, &clock, .{ .mutate = .{ .work = .{ .claim = .{ .target = source_target, .operation = .{ .scope = scope, .principal = 1, .operation = 601 }, .maximum = 1, .lease_ms = 100 } }, .payload = null } }, 256)).operation.?.claim;
                const page = try queueCall(&catalog, &access, &cached, &clock, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } }, 256);
                defer page.deinit(t.allocator);
                var transfer_source: @FieldType(p.Transaction.TerminalTransfer, "source") = .{ .nack = page.page.rows[0].lease.original };
                if (case == .exhausted) {
                    _ = try queueCall(&catalog, &access, &cached, &clock, .{ .mutate = .{ .work = .{ .settle = .{ .operation = .{ .scope = scope, .principal = 1, .operation = 604 }, .lease = page.page.rows[0].lease.original, .action = .{ .nack = .{ .visible_ms = 0 } } } }, .payload = null } }, 256);
                    var changed_configuration = source.intent.action.create.configuration;
                    changed_configuration.policy.queue.dead_letter = null;
                    const policy_edit = try logEdit(source_definition, 605, .{ .alter = .{ .configuration = changed_configuration, .limits = source.intent.action.create.limits } });
                    _ = try catalog.admitLog(policy_edit, access.policy());
                    _ = try catalog.logOperation(policy_edit.binding, .execute, access.policy());
                    source_target.interpretation = (try catalog.resolveLog(1, try .init("inbox"), access.policy())).?.stored.declaration.interpretation;
                    const blocked = try queueCall(&catalog, &access, &cached, &clock, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } }, 256);
                    defer blocked.deinit(t.allocator);
                    const observed = blocked.page.rows[0].lease;
                    try t.expectEqualDeep(destination_target.interpretation, observed.blocked.dead_letter);
                    transfer_source = .{ .exhausted = .{ .target = source_target, .offset = observed.original.offset, .lease_epoch = observed.epoch, .attempt = observed.attempt, .not_before_ms = observed.blocked_after_ms.? } };
                }
                const template = try transactionToken(&catalog, 9000, 1, 0);
                const targets = [_]p.Transaction.Target{
                    .{ .object = source_target.interpretation.object, .kind = .queue, .partition = 0 },
                    .{ .object = destination_target.interpretation.object, .kind = .queue, .partition = 0 },
                };
                receipt = try catalog.beginTransaction(.{ .key = template.key, .fingerprint = template.fingerprint, .operation = template.intent.transaction.begin.identity.begin, .namespace = 1, .mode = .serializable, .selection = .{ .explicit_objects = &targets }, .limits = c.DirectTransaction.default_limits, .budget = template.budget }, access.policy());
                const key = receipt.binding.key;
                phase = "common cut";
                _ = try catalog.acquireTransaction(key, access.policy());
                const environment: c.DirectTransactionLog.Environment = .{ .clock = clock.source() };
                catalog.log_environment = &environment;
                defer catalog.log_environment = null;
                if (case == .rollback) _ = try catalog.transactionSavepoint(key, try savepointRequest(&catalog, &access, key, 800, .{ .create = try a.Name.init("before_transfer") }), 8, access.policy());
                const enqueued: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 603 };
                const payload = try s.LogBatch.encode(destination.intent.action.create.schema, enqueued, .queue, &.{.{ .cells = &cells, .visible_ms = 75 }}, &bytes);
                const work: c.DirectTransactionLogWork.Work = .{ .queue_transfer = .{ .operation = .{ .scope = scope, .principal = 1, .operation = 602 }, .source = transfer_source, .destination = .{ .target = destination_target, .operation = enqueued, .kind = .queue, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) } } };
                const status = try catalog.inspectTransaction(key, access.policy());
                access.denied_privileges = .{ .id = destination_definition.properties.authorization, .mask = c.LogAuthority.append };
                try t.expectError(error.CatalogDenied, catalog.stageTransactionLog(key, status.revision, 1, work, payload, access.policy()));
                access.denied_privileges = null;
                // A valid encoding of another value cannot substitute for the
                // source's data, including its original visibility timestamp.
                var wrong_bytes: [8192]u8 = undefined;
                const wrong_payload = try s.LogBatch.encode(destination.intent.action.create.schema, enqueued, .queue, &.{.{ .cells = &cells, .visible_ms = 76 }}, &wrong_bytes);
                var wrong = work;
                wrong.queue_transfer.destination.payload = s.LogBatch.content(wrong_payload);
                try t.expectError(error.LogPayloadConflict, catalog.stageTransactionLog(key, status.revision, 1, wrong, wrong_payload, access.policy()));
                request = try catalog.stageTransactionLog(key, status.revision, 1, work, payload, access.policy());
                phase = "statement evaluation";
                if (case == .commit) {
                    const checks_before = access.calls;
                    try t.expect(try catalog.transactionLogOutcome(key, request, access.policy()) == null);
                    const disclosure_checks = access.calls - checks_before;
                    try t.expect(disclosure_checks != 0);
                    access.deny_at = access.calls + disclosure_checks;
                    try t.expectError(error.CatalogDenied, catalog.transactionLogOutcome(key, request, access.policy()));
                    access.deny_at = std.math.maxInt(usize);
                }
                try t.expect(try catalog.admitTransactionLog(key, request, access.policy()) == null);
                if (case == .commit) {
                    var graph: @import("direct_storage_graph_test.zig").Workspace = .{};
                    defer graph.deinit();
                    try graph.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
                    var at: usize = 0;
                    while (at < graph.jobs.items.len) : (at += 1) {
                        var graph_work = graph.jobs.items[at];
                        while (true) {
                            const before = graph.jobs.items.len;
                            const done = try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &graph_work, &graph);
                            try t.expect(graph.jobs.items.len - before <= 3);
                            if (done) break;
                        }
                    }
                    var payload_key: [96]u8 = undefined;
                    try t.expect(graph.marks.contains(try s.LogTransactionActions.payloadKey(work.queue_transfer.destination.payload, &payload_key)));
                }
                try t.expect((try catalog.executeTransactionLog(key, request, access.policy())) == .provisional);
                try t.expectError(error.DataIdentityConflict, c.OperationBinding.lookupQueue(t.allocator, catalog.data_objects, work.operation()));
                try t.expectError(error.DataIdentityConflict, c.OperationBinding.lookupQueue(t.allocator, catalog.data_objects, enqueued));
                try t.expect((try queueCall(&catalog, &access, &cached, &clock, .{ .operation = .{ .enqueue = work.queue_transfer.destination } }, 256)).operation == null);
                if (case == .rollback) {
                    const rollback = try savepointRequest(&catalog, &access, key, 801, .{ .rollback = try a.Name.init("before_transfer") });
                    _ = try catalog.transactionSavepoint(key, rollback, 8, access.policy());
                    try t.expect((try catalog.transactionSavepoint(key, rollback, 8, access.policy())).completed != null);
                }
                access.denied_privileges = .{ .id = destination_definition.properties.authorization, .mask = c.LogAuthority.append };
                phase = "commit decision";
                try t.expectError(error.CatalogDenied, catalog.settleTransaction(key, commit, .commit, 16, access.policy()));
                access.denied_privileges = null;
                if (case == .expire) {
                    clock.now = .exact(200);
                    try t.expectError(error.QueueLeaseExpired, catalog.settleTransaction(key, commit, .commit, 16, access.policy()));
                } else {
                    catalog.lose_transaction_reply = true;
                    try t.expectError(error.LostAcknowledgement, catalog.settleTransaction(key, commit, .commit, 16, access.policy()));
                }
            } else {
                phase = "disk resolution";
                // Reopening resolves only the accepted decision, without a
                // trusted clock. An abort cannot replace an accepted commit.
                const terminal = try catalog.settleTransaction(receipt.binding.key, commit, .abort, 16, access.policy());
                try t.expect(terminal.cleanup_complete);
                try t.expectEqual(@as(@FieldType(p.Transaction.Decision, "outcome"), if (case == .expire) .aborted else .committed), terminal.observation.decided.outcome);
                clock.now = .exact(1000);
                const page = try queueCall(&catalog, &access, &cached, &clock, .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } }, 256);
                defer page.deinit(t.allocator);
                const transferred = case == .commit or case == .exhausted;
                try t.expectEqual(@as(p.QueueRead.State, if (transferred) .archived else .acquired), page.page.rows[0].lease.state);
                try t.expectEqual(@as(u64, if (transferred) 1 else 0), (try queueCall(&catalog, &access, &cached, &clock, .{ .observe = destination_target }, 256)).cut.next);
                const original = (try queueCall(&catalog, &access, &cached, &clock, .{ .operation = .{ .enqueue = request.work.queue_transfer.destination } }, 256)).operation;
                try t.expectEqual(transferred, original != null);
                if (original) |value| try t.expectEqualDeep(request.work.queue_transfer.destination, value.enqueue.append);
                try t.expect((try catalog.transactionLogOutcome(receipt.binding.key, request, access.policy())).? == .provisional);
            }
        }
    }
}

test "transaction log statements retain exact offset cursors through lost admission and key rotation after preparation" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    // Match the installed service cache profile within the unchanged transaction budget.
    catalog.options.resident_pages = (D.Options{}).resident_pages;
    var access: Access = .{ .exclusive = true };
    try catalog.initialize(access.policy());
    const receipt = try selectTransactionLogs(&catalog, &access, .serializable);
    const key = receipt.binding.key;
    const declaration = (try catalog.resolveLog(1, try .init("events"), access.policy())).?;
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declaration.stored.declaration.interpretation, .partition = 1 };
    var cached: ?c.DirectStream.Cached = null;
    defer if (cached) |*value| value.deinit();
    const operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 600 };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    const schema = (try logCreation(.stream, 11, 2, "events", 2)).intent.action.create.schema;
    var bytes: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(schema, operation, .stream, &.{.{ .cells = &cells }}, &bytes);
    const encoded = try c.DirectTableProtocol.Binary.encode(t.allocator, payload);
    defer t.allocator.free(encoded.base64);
    _ = try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .append = .{ .target = target, .operation = operation, .kind = .stream, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) } }, .payload = encoded } }, 256);
    const group: p.StreamQueue.Group = .{ .id = 7, .generation = 1, .principal = 1 };
    const cut = (try streamCall(&catalog, &access, &cached, .{ .observe = target }, 256)).cut;
    _ = try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .assign = .{ .operation = .{ .scope = scope, .principal = 1, .operation = 601 }, .cut = cut, .expected = null, .group = group, .next = 0 } }, .payload = null } }, 256);
    const consumed = (try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .consume = .{ .target = target, .operation = .{ .scope = scope, .principal = 1, .operation = 602 }, .group = group, .from = 0, .until = null, .timestamp = null } }, .payload = null } }, 256)).operation.?.consume;
    const cursor = (try streamCall(&catalog, &access, &cached, .{ .cursor = .{ .target = target, .read = consumed.handle() } }, 256)).cursor;
    const page = try streamCall(&catalog, &access, &cached, .{ .page = .{ .cursor = cursor, .limits = .{ .rows = 1, .encoded_bytes = 8192, .scanned_rows = 1 } } }, 256);
    defer page.deinit(t.allocator);
    _ = try catalog.acquireTransaction(key, access.policy());
    var environment: c.DirectTransactionLog.Environment = .{ .authority = try s.LogRead.Authority.init(@splat(4)) };
    catalog.log_environment = &environment;
    defer catalog.log_environment = null;
    const work: c.DirectTransactionLogWork.Work = .{ .stream_offset = .{ .commit = .{ .operation = .{ .scope = scope, .principal = 1, .operation = 603 }, .group = group, .coverage = page.page.cursor.coverage, .expected_next = 0, .next = 1 }, .cursor = page.page.cursor } };
    const status = try catalog.inspectTransaction(key, access.policy());
    var forged = work;
    forged.stream_offset.cursor.authentication[0] ^= 1;
    try t.expectError(error.StreamCursorUnauthenticated, catalog.stageTransactionLog(key, status.revision, 1, forged, null, access.policy()));
    const request = try catalog.stageTransactionLog(key, status.revision, 1, work, null, access.policy());
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.admitTransactionLog(key, request, access.policy()));
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    catalog.log_environment = &environment;
    try t.expect((try catalog.resumeTransaction(key, 8, access.policy())).last_statement == 1);
    try t.expect((try catalog.transactionLogOutcome(key, request, access.policy())).? == .provisional);
    try t.expectEqual(@as(u64, 0), (try streamCall(&catalog, &access, &cached, .{ .group = .{ .target = target, .id = group.id } }, 256)).group.?.next);
    const commit: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9001 };
    const preparing = try catalog.settleTransaction(key, commit, .commit, 3, access.policy());
    try t.expect(preparing.observation == .preparing);
    environment.authority = try s.LogRead.Authority.init(@splat(5));
    const terminal = try catalog.settleTransaction(key, commit, .commit, 8, access.policy());
    try t.expect(terminal.cleanup_complete and terminal.observation.decided.outcome == .committed);
    try t.expectEqual(@as(u64, 1), (try streamCall(&catalog, &access, &cached, .{ .group = .{ .target = target, .id = group.id } }, 256)).group.?.next);
    const original = (try streamCall(&catalog, &access, &cached, .{ .operation = .{ .offset = work.stream_offset } }, 256)).operation.?.offset;
    try t.expectEqualDeep(work.stream_offset.commit, original.commit);
}

test "transaction log source cuts recover original pins and common decisions through lost disk replies" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{ .exclusive = true };
    var receipt: c.DirectClientToken.Receipt = undefined;
    var acquired: c.DirectTransaction.Acquired = undefined;
    const operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9001 };
    for (0..7) |restart| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var fault: TransactionLogFault = .{ .underlying = wal.log() };
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        catalog.data_log = fault.log();
        if (restart == 0) {
            try catalog.initialize(access.policy());
            receipt = try selectTransactionLogs(&catalog, &access, .serializable);
            try t.expectEqual(@as(u64, 4), receipt.binding.intent.transaction.begin.objects.count);
            catalog.lose_table_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.acquireTransaction(receipt.binding.key, access.policy()));
        } else if (restart < 4) {
            fault.lose_reply = true;
            try t.expectError(error.LogAppendUncertain, catalog.acquireTransaction(receipt.binding.key, access.policy()));
            try t.expect(!fault.lose_reply);
            try t.expect((try catalog.clientProgress(.{ .inspect = receipt.binding.key }, access.policy())).state.?.record == null);
        } else if (restart == 4) {
            catalog.store.lose_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.acquireTransaction(receipt.binding.key, access.policy()));
        } else if (restart == 5) {
            acquired = try catalog.acquireTransaction(receipt.binding.key, access.policy());
            try t.expectEqual(@as(u64, 4), acquired.cut.sources.count);
            var sources = try s.TransactionDirectory.init(t.allocator, objects.objectStore(), acquired.cut.begin.identity, .sources, 100, 1, 1024 * 1024);
            defer sources.deinit();
            try sources.restore(acquired.cut.sources);
            var graph: @import("direct_storage_graph_test.zig").Workspace = .{};
            defer graph.deinit();
            try graph.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
            var job: usize = 0;
            var graph_steps: usize = 0;
            while (job < graph.jobs.items.len) : (job += 1) {
                var work = graph.jobs.items[job];
                while (true) {
                    const jobs_before = graph.jobs.items.len;
                    const complete = try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &graph);
                    try t.expect(graph.jobs.items.len <= jobs_before + 3);
                    graph_steps += 1;
                    if (graph_steps > 10000) return error.FixtureBudget;
                    if (complete) break;
                }
            }
            var cursor: ?s.TransactionDirectory.Cursor = null;
            var count: u64 = 0;
            while (true) {
                const page = try sources.page(cursor);
                for (page.entries) |slot| if (slot) |entry| {
                    try t.expectEqual(@as(u64, 1), entry.source.guard.accepted().next_lsn);
                    try t.expectEqual(@as(u64, 2), try wal.log().tail(entry.source.guard.accepted().partition));
                    if (entry.source.guard == .log) {
                        var name: [96]u8 = undefined;
                        try t.expect(graph.marks.contains(try s.LogTransaction.sourceKey(entry.source.pin.content, &name)));
                    }
                    count += 1;
                };
                cursor = page.next orelse break;
            }
            try t.expectEqual(@as(u64, 4), count);
            access.denied_privileges = .{ .id = 112, .mask = c.LogAuthority.read };
            try t.expectError(error.CatalogDenied, catalog.acquireTransaction(receipt.binding.key, access.policy()));
            try t.expectError(error.CatalogDenied, catalog.settleTransaction(receipt.binding.key, operation, .commit, 16, access.policy()));
            access.denied_privileges = null;
            catalog.lose_transaction_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.settleTransaction(receipt.binding.key, operation, .commit, 16, access.policy()));
        } else {
            try t.expectEqualDeep(acquired.cut, (try catalog.inspectTransaction(receipt.binding.key, access.policy())).cut.?);
            // A committed decision still cleans up its pins after data-read
            // revocation. Closure uses current control rights, not data access.
            access.denied_privileges = .{ .id = 112, .mask = c.LogAuthority.read };
            const settled = try catalog.settleTransaction(receipt.binding.key, operation, .commit, 16, access.policy());
            try t.expect(settled.cleanup_complete and settled.observation.decided.outcome == .committed);
            const before = catalog.store.root;
            try t.expectEqualDeep(settled, try catalog.settleTransaction(receipt.binding.key, operation, .abort, 16, access.policy()));
            try t.expectEqualDeep(before, catalog.store.root);
            access.denied_privileges = null;
        }
    }
}

test "transaction log source cuts preserve accepted snapshots and fence changed serializable dependencies" {
    for ([_]p.Transaction.Mode{ .read_only, .serializable }) |mode| {
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        var access: Access = .{ .exclusive = true };
        try catalog.initialize(access.policy());
        const receipt = try selectTransactionLogs(&catalog, &access, mode);
        const key = receipt.binding.key;
        const acquired = try catalog.acquireTransaction(key, access.policy());
        const commit: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9001 };
        if (mode == .serializable) {
            _ = try catalog.executeTransactionStatement(key, try workspaceRequest(&catalog, &access, key, 10, 1, 500), access.policy());
            // Prepare Table output before advancing a later read dependency.
            _ = try catalog.settleTransaction(key, commit, .commit, 1, access.policy());
        }
        const declared = (try catalog.resolveLog(1, try .init("events"), access.policy())).?;
        const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declared.stored.declaration.interpretation, .partition = 1 };
        const operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 600 };
        const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
        var bytes: [8192]u8 = undefined;
        const schema = (try logCreation(.stream, 11, 2, "events", 2)).intent.action.create.schema;
        const payload = try s.LogBatch.encode(schema, operation, .stream, &.{.{ .cells = &cells }}, &bytes);
        const encoded = try c.DirectTableProtocol.Binary.encode(t.allocator, payload);
        defer t.allocator.free(encoded.base64);
        var cached: ?c.DirectStream.Cached = null;
        defer if (cached) |*value| value.deinit();
        _ = try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .append = .{ .target = target, .operation = operation, .kind = .stream, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) } }, .payload = encoded } }, 256);
        if (mode == .read_only) {
            try t.expectEqualDeep(acquired, try catalog.acquireTransaction(key, access.policy()));
            const result = try catalog.settleTransaction(key, commit, .commit, 16, access.policy());
            try t.expect(result.cleanup_complete and result.observation.decided.outcome == .committed);
        } else {
            try t.expectError(error.TransactionConflict, catalog.settleTransaction(key, commit, .commit, 16, access.policy()));
            try t.expect((try catalog.inspectTransaction(key, access.policy())).observation == .preparing);
            const result = try catalog.settleTransaction(key, commit, .abort, 16, access.policy());
            try t.expect(result.cleanup_complete and result.observation.decided.outcome == .aborted);
            var view = (try resolve(&catalog, &access, "rows")).?;
            defer view.deinit();
            try t.expectEqual(@as(u64, 0), view.table.root.live_rows);
        }
        try t.expectEqual(@as(u64, 1), (try streamCall(&catalog, &access, &cached, .{ .observe = target }, 256)).cut.next);
    }
}

test "catalog log publication resumes private partitions and retains identity across policy rename and drop" {
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
    const request = try logCreation(.stream, 17, 100, "events", 3);
    const original_root = catalog.store.root;
    const puts = objects.puts;
    try t.expectEqual(.none, (try catalog.previewLog(request, access.policy())).reason);
    try t.expectEqualDeep(original_root, catalog.store.root);
    try t.expectEqual(puts, objects.puts);
    const admitted = try catalog.admitLog(request, access.policy());
    try t.expectEqual(original_root.next_partition, admitted.first_partition);
    try t.expectEqual(original_root.next_partition + 3, catalog.store.root.next_partition);
    try t.expect(try catalog.resolveLog(1, request.intent.name, access.policy()) == null);
    // The shared name directory excludes both Tables and another log kind.
    try t.expectEqual(.name_conflict, (try catalog.preview(try creation(18, 101, "events"), access.policy())).reason);
    try t.expectEqual(.name_conflict, (try catalog.previewLog(try logCreation(.queue, 19, 102, "events", 1), access.policy())).reason);
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.logOperation(request.binding, .execute, access.policy()));
    catalog.deinit();
    wal.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    catalog = try owner(&wal, &objects);
    const resumed = (try catalog.logOperation(request.binding, .inspect, access.policy())).operation;
    try t.expectEqual(.initializing, resumed.phase);
    try t.expectEqual(@as(u32, 1), resumed.initialized);
    const pending_page = try catalog.pendingLogs(1, null, access.policy());
    try t.expectEqualDeep(resumed, pending_page.entries[0].?);
    try t.expect(pending_page.next == null);
    try t.expectEqualDeep(resumed, try catalog.admitLog(request, access.policy()));
    // Admission retries report the current original operation, never allocate.
    const reserved = catalog.store.root.next_partition;
    try t.expectEqual(.initializing, (try catalog.logOperation(request.binding, .execute, access.policy())).operation.phase);
    const completed = (try catalog.logOperation(request.binding, .execute, access.policy())).operation;
    try t.expectEqual(.complete, completed.phase);
    try t.expect((try catalog.pendingLogs(1, null, access.policy())).entries[0] == null);
    try t.expectEqual(reserved, catalog.store.root.next_partition);
    var value = (try catalog.resolveLog(1, request.intent.name, access.policy())).?;
    try t.expectEqualDeep(completed.resulting.?, value);
    for (0..value.count()) |i| try t.expectEqual(@as(u64, 1), try wal.log().tail(try value.partition(@intCast(i))));
    const initial = value.seed;
    const renamed = try logEdit(value, 103, .{ .rename = try .init("renamed") });
    _ = try catalog.admitLog(renamed, access.policy());
    _ = try catalog.logOperation(renamed.binding, .execute, access.policy());
    try t.expect(try catalog.resolveLog(1, request.intent.name, access.policy()) == null);
    value = (try catalog.resolveLog(1, try .init("renamed"), access.policy())).?;
    try t.expectEqualDeep(initial, value.seed);
    try t.expectEqualDeep(request.binding.identity, value.initialization);
    var configuration_value = value.stored.declaration.configuration;
    configuration_value.partitioning.count += 1;
    const unsupported = try logEdit(value, 104, .{ .alter = .{ .configuration = configuration_value, .limits = value.stored.declaration.limits } });
    const before_unsupported = catalog.store.root;
    try t.expectError(error.UnsupportedLogRepartition, catalog.admitLog(unsupported, access.policy()));
    try t.expectEqualDeep(before_unsupported, catalog.store.root);
    try t.expect(try c.OperationBinding.lookup(t.allocator, objects.objectStore(), unsupported.binding.identity) == null);
    configuration_value = value.stored.declaration.configuration;
    configuration_value.retention.max_age_ms = 1000;
    const alter = try logEdit(value, 105, .{ .alter = .{ .configuration = configuration_value, .limits = value.stored.declaration.limits } });
    _ = try catalog.admitLog(alter, access.policy());
    _ = try catalog.logOperation(alter.binding, .execute, access.policy());
    value = (try catalog.resolveLog(1, try .init("renamed"), access.policy())).?;
    try t.expectEqual(@as(?u64, 1000), value.stored.declaration.configuration.retention.max_age_ms);
    const drop = try logEdit(value, 106, .drop);
    _ = try catalog.admitLog(drop, access.policy());
    _ = try catalog.logOperation(drop.binding, .execute, access.policy());
    try t.expect(try catalog.resolveLog(1, try .init("renamed"), access.policy()) == null);
    try t.expectEqualDeep(completed, (try catalog.logOperation(request.binding, .inspect, access.policy())).operation);
    // Dropped identity stays reserved while the name may be reused.
    try t.expectEqual(.object_conflict, (try catalog.previewLog(try logCreation(.stream, 17, 107, "new", 1), access.policy())).reason);
    try t.expectEqual(.none, (try catalog.previewLog(try logCreation(.queue, 18, 108, "renamed", 1), access.policy())).reason);
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    try t.expectEqualDeep(completed, (try catalog.logOperation(request.binding, .inspect, access.policy())).operation);
    access.denied_metadata = 117;
    try t.expectError(error.CatalogDenied, catalog.logOperation(request.binding, .inspect, access.policy()));
}

test "catalog log pagination exceeds cache and filters revoked metadata without losing continuation" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    var name_buffer: [32]u8 = undefined;
    for (0..19) |i| {
        const create = try logCreation(if (i % 2 == 0) .stream else .queue, 100 + i, 200 + i, try std.fmt.bufPrint(&name_buffer, "log-{d}", .{i}), 1);
        _ = try catalog.admitLog(create, access.policy());
        _ = try catalog.logOperation(create.binding, .execute, access.policy());
    }
    access.denied_metadata = 200;
    var after: ?s.TreeStore.pages.Key = null;
    var count: usize = 0;
    while (true) {
        const page = try catalog.listLogs(1, after, access.policy());
        for (page.entries) |slot| if (slot) |value| {
            try t.expect(value.properties.authorization != access.denied_metadata.?);
            count += 1;
        };
        after = page.next orelse break;
    }
    try t.expectEqual(@as(usize, 18), count);
    try t.expectError(error.CatalogDenied, catalog.resolveLog(1, try .init("log-0"), access.policy()));
    access.denied_metadata = null;
    const private = try logCreation(.queue, 300, 400, "private", 2);
    _ = try catalog.admitLog(private, access.policy());
    _ = try catalog.logOperation(private.binding, .execute, access.policy());
    access.denied_metadata = 400;
    try t.expect((try catalog.pendingLogs(1, null, access.policy())).entries[0] == null);
    access.denied_metadata = null;
    const cancelled = (try catalog.logOperation(private.binding, .cancel, access.policy())).operation;
    try t.expectEqual(.cancelled, cancelled.phase);
    try t.expectEqual(@as(u32, 1), cancelled.initialized);
    try t.expect((try catalog.pendingLogs(1, null, access.policy())).entries[0] == null);
    try t.expect(try catalog.resolveLog(1, try .init("private"), access.policy()) == null);
    try t.expectEqual(.none, (try catalog.previewLog(try logCreation(.stream, 301, 401, "private", 1), access.policy())).reason);
}

test "catalog log DLQ definitions guard publication and retain dependency and storage roots" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const destination = try logCreation(.queue, 70, 1, "dead_letters", 1);
    access.missing_table = true;
    _ = try catalog.admitLog(destination, access.policy());
    const registration = (try catalog.logRegistration(destination.binding, access.policy())).?;
    try t.expectEqual(profile.queue_domain, registration.action.domain);
    try t.expectError(error.CatalogRegistrationRequired, catalog.logOperation(destination.binding, .execute, access.policy()));
    access.missing_table = false;
    _ = try catalog.logOperation(destination.binding, .execute, access.policy());
    var target = (try catalog.resolveLog(1, destination.intent.name, access.policy())).?;
    var source = try logCreation(.queue, 71, 2, "jobs", 2);
    source.intent.action.create.configuration.policy.queue.dead_letter = target.stored.declaration.interpretation;
    source.binding.intent = try source.intent.digest(t.allocator);
    access.denied_metadata = target.properties.authorization;
    try t.expectError(error.CatalogDenied, catalog.admitLog(source, access.policy()));
    try t.expect(try c.OperationBinding.lookup(t.allocator, objects.objectStore(), source.binding.identity) == null);
    access.denied_metadata = null;
    _ = try catalog.admitLog(source, access.policy());
    const rename = try logEdit(target, 3, .{ .rename = try .init("renamed_dlq") });
    _ = try catalog.admitLog(rename, access.policy());
    _ = try catalog.logOperation(rename.binding, .execute, access.policy());
    try t.expectError(error.QueueDestinationChanged, catalog.logOperation(source.binding, .execute, access.policy()));
    const cancelled = (try catalog.logOperation(source.binding, .cancel, access.policy())).operation;
    try t.expectEqual(.cancelled, cancelled.phase);
    target = (try catalog.resolveLog(1, try .init("renamed_dlq"), access.policy())).?;
    source = try logCreation(.queue, 72, 4, "jobs", 2);
    source.intent.action.create.configuration.policy.queue.dead_letter = target.stored.declaration.interpretation;
    source.binding.intent = try source.intent.digest(t.allocator);
    _ = try catalog.admitLog(source, access.policy());
    _ = try catalog.logOperation(source.binding, .execute, access.policy());
    const published = (try catalog.logOperation(source.binding, .execute, access.policy())).operation;
    const edge = (try published.resulting.?.deadLetterEdge()).?;
    try t.expect((try catalog.dependencyState(edge, access.policy())).present);
    const drop = try logEdit(target, 5, .drop);
    try t.expectEqual(.dependency, (try catalog.previewLog(drop, access.policy())).reason);
    // Revocation after buffering rejects the complete disclosure as well.
    access.deny_at = access.calls + 3;
    try t.expectError(error.CatalogDenied, catalog.resolveLog(1, try .init("jobs"), access.policy()));
    access.deny_at = std.math.maxInt(usize);
    const retired = try logEdit(published.resulting.?, 6, .drop);
    _ = try catalog.admitLog(retired, access.policy());
    _ = try catalog.logOperation(retired.binding, .execute, access.policy());
    try t.expect((try catalog.dependencyState(edge, access.policy())).present);
    // Catalog history owns declarations and initialization even after DROP.
    var graph: @import("direct_storage_graph_test.zig").Workspace = .{};
    defer graph.deinit();
    try graph.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
    var at: usize = 0;
    var steps: usize = 0;
    while (at < graph.jobs.items.len) : (at += 1) {
        var work = graph.jobs.items[at];
        while (!try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &graph)) {
            steps += 1;
            if (steps > 20000) return error.FixtureBudget;
        }
    }
    var key_buffer: [96]u8 = undefined;
    for ([_]s.LogDeclaration.Stored{ target.seed, target.stored, published.resulting.?.stored }) |stored| {
        try t.expect(graph.marks.contains(try s.LogDeclaration.key(stored.content, &key_buffer)));
    }
    try t.expect(graph.marks.contains(try c.DirectLog.IntentStore.key(published.intent, &key_buffer)));
    var frame = try wal.log().read(t.allocator, target.first_partition, 0, 1);
    defer frame.deinit();
    try t.expect((try c.DirectStorageGraph.fromFrame(t.allocator, frame.frames[0])) == .log_initialization);
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    try t.expect((try catalog.dependencyState(edge, access.policy())).present);
}

const QueueClock = struct {
    now: ?s.LogTime.Sample = .exact(100),
    fn read(raw: *anyopaque) !?s.LogTime.Sample {
        return @as(*QueueClock, @ptrCast(@alignCast(raw))).now;
    }
    fn source(self: *QueueClock) s.LogTime.Source {
        return .{ .context = self, .read = read };
    }
};
fn queueCall(catalog: *D, access: *Access, cached: *?c.DirectQueue.Cached, clock: *QueueClock, request: c.DirectQueue.Request, steps: u16) !c.DirectQueue.Result {
    return queueCallWaiting(catalog, access, cached, clock, request, steps, null);
}
fn queueCallWaiting(catalog: *D, access: *Access, cached: *?c.DirectQueue.Cached, clock: *QueueClock, request: c.DirectQueue.Request, steps: u16, waiting: ?c.DirectLog.Waiting) !c.DirectQueue.Result {
    var scratch: std.heap.ArenaAllocator = .init(t.allocator);
    defer scratch.deinit();
    return c.DirectQueue.apply(scratch.allocator(), t.allocator, catalog, cached, .{
        .resident_pages = 1,
        .batch_bytes = 8192,
        .key_bytes = 256,
        .tail = .{ .slots = 1, .borrow_slots = 2, .slot_bytes = 8192, .resident_bytes = 16384 },
    }, .{ .clock = clock.source(), .recovery_steps = steps, .waiting = waiting }, request, access.policy());
}

test "direct Queue waits preserve timeout absence delayed eligibility and original empty claims through restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    var clock: QueueClock = .{};
    var cached: ?c.DirectQueue.Cached = null;
    defer if (cached) |*value| value.deinit();
    try catalog.initialize(access.policy());
    const create = try logCreation(.queue, 10, 1, "waiting", 1);
    _ = try catalog.admitLog(create, access.policy());
    _ = try catalog.logOperation(create.binding, .execute, access.policy());
    const declared = (try catalog.logOperation(create.binding, .execute, access.policy())).operation.resulting.?;
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declared.stored.declaration.interpretation, .partition = 0 };
    const claim: p.StreamQueue.Claim = .{ .target = target, .operation = .{ .scope = scope, .principal = 1, .operation = 100 }, .maximum = 1, .lease_ms = 100 };
    var request: c.DirectQueue.Request = .{ .wait = .{ .claim = claim, .milliseconds = 1000 } };
    var wake_after_ms: ?u64 = null;
    const active: c.DirectLog.Waiting = .{ .expired = false, .registrations = 1, .wake_after_ms = &wake_after_ms };
    const expired: c.DirectLog.Waiting = .{ .expired = true, .registrations = 1 };
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .principal = 1, .audience = 3, .role = null };
    try t.expectError(error.QueueWaitUnavailable, queueCall(&catalog, &access, &cached, &clock, request, 256));
    try t.expectError(error.QueueWaitPending, queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, active));
    try t.expect(wake_after_ms == null);
    try t.expect((try c.OperationBinding.lookupQueue(t.allocator, objects.objectStore(), claim.operation)) == null);
    const timeout = try queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, expired);
    try c.DirectQueueResponse.validate(t.allocator, connection, request, timeout);
    try t.expectEqual(@as(u64, 0), timeout.timed_out.next);
    try t.expect((try queueCall(&catalog, &access, &cached, &clock, .{ .operation = .{ .claim = claim } }, 256)).operation == null);
    try t.expectError(error.QueueWaitCapacity, queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, .{ .expired = false, .registrations = declared.stored.declaration.limits.waiters + 1 }));
    access.denied_privileges = .{ .id = declared.properties.authorization, .mask = c.LogAuthority.acquire };
    try t.expectError(error.CatalogDenied, queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, expired));
    access.denied_privileges = null;
    clock.now = null;
    try t.expectError(error.QueueTimeUnavailable, queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, expired));
    clock.now = .exact(100);
    var empty_claim = claim;
    empty_claim.operation.operation = 101;
    const empty = (try queueCall(&catalog, &access, &cached, &clock, .{ .mutate = .{ .work = .{ .claim = empty_claim }, .payload = null } }, 256)).operation.?.claim;
    try t.expectEqual(@as(u32, 0), empty.rows);
    const append_operation: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 102 };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    var bytes: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(create.intent.action.create.schema, append_operation, .queue, &.{.{ .cells = &cells, .visible_ms = 1200 }}, &bytes);
    const encoded = try c.DirectTableProtocol.Binary.encode(t.allocator, payload);
    defer t.allocator.free(encoded.base64);
    _ = try queueCall(&catalog, &access, &cached, &clock, .{ .mutate = .{ .work = .{ .enqueue = .{ .target = target, .operation = append_operation, .kind = .queue, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) } }, .payload = encoded } }, 256);
    try t.expectError(error.QueueWaitPending, queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, active));
    try t.expectEqual(@as(?u64, 1100), wake_after_ms);
    const delayed_timeout = try queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, expired);
    try c.DirectQueueResponse.validate(t.allocator, connection, request, delayed_timeout);
    try t.expectEqual(@as(u64, 1), delayed_timeout.timed_out.next);
    try t.expect((try c.OperationBinding.lookupQueue(t.allocator, objects.objectStore(), claim.operation)) == null);
    // Offset availability is not eligibility: the trusted lower bound must
    // reach visible_at. A local wakeup cannot establish that fact.
    clock.now = .{ .earliest_ms = 1199, .latest_ms = 1201 };
    try t.expectError(error.QueueWaitPending, queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, active));
    try t.expectEqual(@as(?u64, 1), wake_after_ms);
    clock.now = .exact(1201);
    const accepted = try queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, expired);
    try c.DirectQueueResponse.validate(t.allocator, connection, request, accepted);
    try t.expectEqual(@as(u32, 1), accepted.operation.?.claim.rows);
    request.wait.milliseconds = 1;
    clock.now = null;
    try t.expectEqualDeep(accepted, try queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, active));
    request.wait.claim = empty_claim;
    try t.expectEqualDeep(empty, (try queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, active)).operation.?.claim);
    request.wait.claim = claim;
    request.wait.claim.maximum = 2;
    try t.expectError(error.DataIdentityConflict, queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, active));
    request.wait.claim = claim;
    cached.?.deinit();
    cached = null;
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    try t.expectEqualDeep(accepted, try queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, active));
    access.denied_privileges = .{ .id = declared.properties.authorization, .mask = c.LogAuthority.read };
    try t.expectError(error.CatalogDenied, queueCallWaiting(&catalog, &access, &cached, &clock, request, 256, expired));
    try t.expectError(error.InvalidQueueResponse, c.DirectQueueResponse.validate(t.allocator, connection, .{ .observe = target }, timeout));
    var invalid = timeout;
    invalid.timed_out.target.partition = 1;
    try t.expectError(error.LogPartitionConflict, c.DirectQueueResponse.validate(t.allocator, connection, request, invalid));
}

test "direct Queue composition preserves original claims current rights and settlements across edits and reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    var clock: QueueClock = .{};
    var cached: ?c.DirectQueue.Cached = null;
    defer if (cached) |*value| value.deinit();
    try catalog.initialize(access.policy());
    const creation_request = try logCreation(.queue, 10, 1, "work", 2);
    _ = try catalog.admitLog(creation_request, access.policy());
    _ = try catalog.logOperation(creation_request.binding, .execute, access.policy());
    const declaration = (try catalog.logOperation(creation_request.binding, .execute, access.policy())).operation.resulting.?;
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declaration.stored.declaration.interpretation, .partition = 0 };
    const identity: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 100 };
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    var bytes: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(creation_request.intent.action.create.schema, identity, .queue, &.{ .{ .cells = &cells }, .{ .cells = &cells } }, &bytes);
    const encoded = try c.DirectTableProtocol.Binary.encode(t.allocator, payload);
    defer t.allocator.free(encoded.base64);
    const append: c.DirectQueueMutation.Request = .{ .enqueue = .{ .target = target, .operation = identity, .kind = .queue, .producer = null, .rows = 2, .payload = s.LogBatch.content(payload) } };
    const enqueue: c.DirectQueue.Request = .{ .mutate = .{ .work = append, .payload = encoded } };
    access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = c.LogAuthority.append };
    try t.expectError(error.CatalogDenied, queueCall(&catalog, &access, &cached, &clock, enqueue, 256));
    try t.expect(cached == null);
    try t.expect((try c.OperationBinding.lookupQueue(t.allocator, objects.objectStore(), identity)) == null);
    access.denied_privileges = null;
    const accepted = try queueCall(&catalog, &access, &cached, &clock, enqueue, 256);
    try c.DirectQueueResponse.validate(t.allocator, connection, enqueue, accepted);
    try t.expectEqual(@as(u64, 2), accepted.operation.?.enqueue.next);
    try t.expect(cached.?.owner.owner.options.clock == null);
    var changed = enqueue;
    changed.mutate.work.enqueue.target.partition = 1;
    try t.expectError(error.DataIdentityConflict, queueCall(&catalog, &access, &cached, &clock, changed, 256));
    // Table and Stream operations share the same namespace, even if a Queue
    // request names another partition or has not reached WAL publication yet.
    try t.expectError(error.DataIdentityConflict, c.OperationBinding.lookup(t.allocator, objects.objectStore(), identity));
    try t.expectError(error.DataIdentityConflict, c.OperationBinding.lookupStream(t.allocator, objects.objectStore(), identity));
    var stream_cache: ?c.DirectStream.Cached = null;
    defer if (stream_cache) |*value| value.deinit();
    try t.expectError(error.CatalogKindMismatch, streamCall(&catalog, &access, &stream_cache, .{ .observe = target }, 256));
    const claim: c.DirectQueueMutation.Request = .{ .claim = .{ .target = target, .operation = .{ .scope = scope, .principal = 1, .operation = 101 }, .maximum = 2, .lease_ms = 100 } };
    const claim_request: c.DirectQueue.Request = .{ .mutate = .{ .work = claim, .payload = null } };
    for ([_]u64{ c.LogAuthority.read, c.LogAuthority.acquire }) |mask| {
        access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = mask };
        try t.expectError(error.CatalogDenied, queueCall(&catalog, &access, &cached, &clock, claim_request, 256));
    }
    access.denied_privileges = null;
    const claimed = try queueCall(&catalog, &access, &cached, &clock, claim_request, 256);
    try c.DirectQueueResponse.validate(t.allocator, connection, claim_request, claimed);
    const receipt = claimed.operation.?.claim;
    try t.expectEqual(@as(u32, 2), receipt.rows);
    const page_request: c.DirectQueue.Request = .{ .page = .{ .cursor = .{ .receipt = receipt, .next = 0 }, .limits = .{ .rows = 2, .encoded_bytes = 8192 } } };
    access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = c.LogAuthority.acquire };
    try t.expectError(error.CatalogDenied, queueCall(&catalog, &access, &cached, &clock, page_request, 256));
    access.denied_privileges = null;
    const before = access.calls;
    const page = try queueCall(&catalog, &access, &cached, &clock, page_request, 256);
    defer page.deinit(t.allocator);
    const disclosure_checks = access.calls - before;
    try c.DirectQueueResponse.validate(t.allocator, connection, page_request, page);
    try t.expect(page.page.cursor.complete());
    try t.expectEqual(.live, page.page.rows[0].lease.liveness);
    var invalid = page;
    invalid.page.rows = invalid.page.rows[0..1];
    try t.expectError(error.InvalidQueueResponse, c.DirectQueueResponse.validate(t.allocator, connection, page_request, invalid));
    invalid = page;
    invalid.page.encoded_bytes += 1;
    try t.expectError(error.InvalidQueueResponse, c.DirectQueueResponse.validate(t.allocator, connection, page_request, invalid));
    access.deny_at = access.calls + disclosure_checks;
    try t.expectError(error.CatalogDenied, queueCall(&catalog, &access, &cached, &clock, page_request, 256));
    try t.expectEqual(access.deny_at, access.calls);
    access.deny_at = std.math.maxInt(usize);
    const settlement: c.DirectQueueMutation.Request = .{ .settle = .{ .operation = .{ .scope = scope, .principal = 1, .operation = 102 }, .lease = page.page.rows[0].lease.original, .action = .ack } };
    const settle_request: c.DirectQueue.Request = .{ .mutate = .{ .work = settlement, .payload = null } };
    access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = c.LogAuthority.settle };
    try t.expectError(error.CatalogDenied, queueCall(&catalog, &access, &cached, &clock, settle_request, 256));
    access.denied_privileges = null;
    const settled = try queueCall(&catalog, &access, &cached, &clock, settle_request, 256);
    try c.DirectQueueResponse.validate(t.allocator, connection, settle_request, settled);
    var smaller = creation_request.intent.action.create.limits;
    smaller.append_bytes = 1;
    const alter = try logEdit(declaration, 150, .{ .alter = .{ .configuration = declaration.stored.declaration.configuration, .limits = smaller } });
    _ = try catalog.admitLog(alter, access.policy());
    const revised = (try catalog.logOperation(alter.binding, .execute, access.policy())).operation.resulting.?;
    try t.expectEqualDeep(accepted, try queueCall(&catalog, &access, &cached, &clock, enqueue, 256));
    const drop = try logEdit(revised, 151, .drop);
    _ = try catalog.admitLog(drop, access.policy());
    _ = try catalog.logOperation(drop.binding, .execute, access.policy());
    const after_drop = try queueCall(&catalog, &access, &cached, &clock, page_request, 256);
    defer after_drop.deinit(t.allocator);
    try c.DirectQueueResponse.validate(t.allocator, connection, page_request, after_drop);
    try t.expectEqual(.fenced, after_drop.page.rows[0].lease.liveness);
    try t.expectEqual(.acked, after_drop.page.rows[0].lease.state);
    try t.expectEqual(.live, after_drop.page.rows[1].lease.liveness);
    var close = settlement;
    close.settle.operation.operation = 103;
    close.settle.lease = page.page.rows[1].lease.original;
    _ = try queueCall(&catalog, &access, &cached, &clock, .{ .mutate = .{ .work = close, .payload = null } }, 256);
    var fresh = claim_request;
    fresh.mutate.work.claim.operation.operation = 104;
    try t.expectError(error.LogDeclarationConflict, queueCall(&catalog, &access, &cached, &clock, fresh, 256));
    cached.?.deinit();
    cached = null;
    catalog.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    catalog = try owner(&wal, &objects);
    clock.now = null;
    var incomplete: usize = 0;
    for (0..16) |_| {
        const result = try queueCall(&catalog, &access, &cached, &clock, .{ .operation = claim }, 1);
        if (result == .recovering) {
            try c.DirectQueueResponse.validate(t.allocator, connection, .{ .operation = claim }, result);
            incomplete += 1;
        } else {
            try t.expectEqualDeep(claimed, result);
            break;
        }
    } else return error.FixtureBudget;
    try t.expect(incomplete > 0);
    try t.expectEqualDeep(settled, try queueCall(&catalog, &access, &cached, &clock, settle_request, 256));
    const recovered = try queueCall(&catalog, &access, &cached, &clock, page_request, 256);
    defer recovered.deinit(t.allocator);
    try c.DirectQueueResponse.validate(t.allocator, connection, page_request, recovered);
    try t.expectEqualStrings(page.page.rows[0].encoded.base64, recovered.page.rows[0].encoded.base64);
    try t.expectEqual(.acked, recovered.page.rows[1].lease.state);
    access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = c.LogAuthority.acquire };
    try t.expectError(error.CatalogDenied, queueCall(&catalog, &access, &cached, &clock, .{ .operation = claim }, 256));
    const release: c.DirectQueueMutation.Request = .{ .release = .{ .operation = .{ .scope = scope, .principal = 1, .operation = 105 }, .claim = receipt } };
    const release_request: c.DirectQueue.Request = .{ .mutate = .{ .work = release, .payload = null } };
    for ([_]u64{ c.LogAuthority.read, c.LogAuthority.acquire }) |mask| {
        access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = mask };
        try t.expectError(error.CatalogDenied, queueCall(&catalog, &access, &cached, &clock, release_request, 256));
        try t.expect((try c.OperationBinding.lookupQueue(t.allocator, objects.objectStore(), release.identity())) == null);
    }
    access.denied_privileges = null;
    const saved_release = try c.DirectQueueClient.save(t.allocator, connection, .{ .work = release });
    defer t.allocator.free(saved_release);
    const loaded_release = try c.DirectQueueClient.load(t.allocator, saved_release);
    defer loaded_release.deinit();
    try t.expectEqualDeep(release, loaded_release.value.work.work);
    const released = try queueCall(&catalog, &access, &cached, &clock, release_request, 256);
    try c.DirectQueueResponse.validate(t.allocator, connection, release_request, released);
    try t.expectError(error.QueueReadReleased, queueCall(&catalog, &access, &cached, &clock, page_request, 256));
    try t.expectEqualDeep(claimed, try queueCall(&catalog, &access, &cached, &clock, .{ .operation = claim }, 256));
    changed = release_request;
    changed.mutate.work.release.claim.leases.?.sha256[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, queueCall(&catalog, &access, &cached, &clock, changed, 256));
    cached.?.deinit();
    cached = null;
    try t.expectEqualDeep(released, try queueCall(&catalog, &access, &cached, &clock, release_request, 256));
    access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = c.LogAuthority.acquire };
    try t.expectError(error.CatalogDenied, queueCall(&catalog, &access, &cached, &clock, .{ .operation = release }, 256));
}

fn streamCall(catalog: *D, access: *Access, cached: *?c.DirectStream.Cached, request: c.DirectStream.Request, steps: u16) !c.DirectStream.Result {
    return streamCallWaiting(catalog, access, cached, request, steps, null);
}
fn streamCallWaiting(catalog: *D, access: *Access, cached: *?c.DirectStream.Cached, request: c.DirectStream.Request, steps: u16, waiting: @FieldType(c.DirectStream.Environment, "waiting")) !c.DirectStream.Result {
    var scratch: std.heap.ArenaAllocator = .init(t.allocator);
    defer scratch.deinit();
    return c.DirectStream.apply(scratch.allocator(), t.allocator, catalog, cached, .{
        .resident_pages = 1,
        .batch_bytes = 8192,
        .key_bytes = 256,
        .tail = .{ .slots = 1, .borrow_slots = 2, .slot_bytes = 8192, .resident_bytes = 16384 },
    }, .{ .authority = try s.LogRead.Authority.init(@splat(4)), .clock = null, .recovery_steps = steps, .waiting = waiting }, request, access.policy());
}

test "direct Stream waits select one cut without accepting a timeout or extending an original read" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    var cached: ?c.DirectStream.Cached = null;
    defer if (cached) |*value| value.deinit();
    try catalog.initialize(access.policy());
    const create = try logCreation(.stream, 10, 1, "waiting", 1);
    _ = try catalog.admitLog(create, access.policy());
    _ = try catalog.logOperation(create.binding, .execute, access.policy());
    const declared = (try catalog.logOperation(create.binding, .execute, access.policy())).operation.resulting.?;
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declared.stored.declaration.interpretation, .partition = 0 };
    const input: p.StreamRead.Request = .{ .target = target, .operation = .{ .scope = scope, .principal = 1, .operation = 100 }, .group = null, .from = 0, .until = null, .timestamp = null };
    var request: c.DirectStream.Request = .{ .wait = .{ .consume = input, .milliseconds = 1000 } };
    const active: @FieldType(c.DirectStream.Environment, "waiting") = .{ .expired = false, .registrations = 1 };
    const expired: @FieldType(c.DirectStream.Environment, "waiting") = .{ .expired = true, .registrations = 1 };
    try t.expectError(error.StreamWaitPending, streamCallWaiting(&catalog, &access, &cached, request, 256, active));
    try t.expect((try c.OperationBinding.lookupStream(t.allocator, objects.objectStore(), input.operation)) == null);
    try t.expect((try streamCall(&catalog, &access, &cached, .{ .operation = .{ .consume = input } }, 256)).operation == null);
    try t.expectError(error.StreamWaitCapacity, streamCallWaiting(&catalog, &access, &cached, request, 256, .{ .expired = false, .registrations = declared.stored.declaration.limits.waiters + 1 }));
    const timeout = try streamCallWaiting(&catalog, &access, &cached, request, 256, expired);
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .principal = 1, .audience = 3, .role = null };
    try c.DirectStreamResponse.validate(t.allocator, connection, request, timeout);
    try t.expectEqual(@as(u64, 0), timeout.timed_out.next);
    try t.expect((try c.OperationBinding.lookupStream(t.allocator, objects.objectStore(), input.operation)) == null);
    access.denied_privileges = .{ .id = declared.properties.authorization, .mask = c.LogAuthority.read };
    try t.expectError(error.CatalogDenied, streamCallWaiting(&catalog, &access, &cached, request, 256, expired));
    access.denied_privileges = null;
    var empty_input = input;
    empty_input.operation.operation = 101;
    const empty = (try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .consume = empty_input }, .payload = null } }, 256)).operation.?.consume;
    const identity: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 102 };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    var bytes: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(create.intent.action.create.schema, identity, .stream, &.{ .{ .cells = &cells }, .{ .cells = &cells } }, &bytes);
    const encoded = try c.DirectTableProtocol.Binary.encode(t.allocator, payload);
    defer t.allocator.free(encoded.base64);
    _ = try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .append = .{ .target = target, .operation = identity, .kind = .stream, .producer = null, .rows = 2, .payload = s.LogBatch.content(payload) } }, .payload = encoded } }, 256);
    // Readiness wins the final deadline recheck. This is a newly accepted finite
    // read; it does not turn the earlier timeout into acceptance evidence.
    const accepted = try streamCallWaiting(&catalog, &access, &cached, request, 256, expired);
    try c.DirectStreamResponse.validate(t.allocator, connection, request, accepted);
    try t.expectEqual(@as(u64, 2), accepted.operation.?.consume.until);
    request.wait.milliseconds = 1;
    try t.expectEqualDeep(accepted, try streamCallWaiting(&catalog, &access, &cached, request, 256, active));
    request.wait.consume = empty_input;
    try t.expectEqualDeep(empty, (try streamCallWaiting(&catalog, &access, &cached, request, 256, active)).operation.?.consume);
    try t.expectEqual(@as(u64, 0), empty.until);
    request.wait.consume = input;
    request.wait.consume.operation.operation = 103;
    request.wait.consume.until = 3;
    try t.expectError(error.StreamWaitPending, streamCallWaiting(&catalog, &access, &cached, request, 256, active));
    try c.DirectStreamResponse.validate(t.allocator, connection, request, try streamCallWaiting(&catalog, &access, &cached, request, 256, expired));
    request.wait.consume.group = .{ .id = 1, .generation = 1, .principal = 1 };
    try t.expectError(error.LogGroupRequired, streamCallWaiting(&catalog, &access, &cached, request, 256, expired));
    const cut = accepted.operation.?.consume.cut;
    _ = try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .assign = .{ .cut = cut, .operation = .{ .scope = scope, .principal = 1, .operation = 104 }, .expected = null, .group = request.wait.consume.group.?, .next = 2 } }, .payload = null } }, 256);
    try t.expectError(error.LogOffsetConflict, streamCallWaiting(&catalog, &access, &cached, request, 256, expired));
    request.wait.consume.from = 2;
    request.wait.consume.group.?.generation = 2;
    try t.expectError(error.LogGroupFenced, streamCallWaiting(&catalog, &access, &cached, request, 256, expired));
    request.wait.consume.group.?.generation = 1;
    try t.expectError(error.StreamWaitPending, streamCallWaiting(&catalog, &access, &cached, request, 256, active));
}

test "direct Stream composition preserves original work pins and group rights across catalog edits and reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    var cached: ?c.DirectStream.Cached = null;
    defer if (cached) |*value| value.deinit();
    try catalog.initialize(access.policy());
    const creation_request = try logCreation(.stream, 10, 1, "composed", 2);
    _ = try catalog.admitLog(creation_request, access.policy());
    _ = try catalog.logOperation(creation_request.binding, .execute, access.policy());
    const declaration = (try catalog.logOperation(creation_request.binding, .execute, access.policy())).operation.resulting.?;
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declaration.stored.declaration.interpretation, .partition = 0 };
    const identity: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 100 };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    var bytes: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(creation_request.intent.action.create.schema, identity, .stream, &.{ .{ .cells = &cells }, .{ .cells = &cells } }, &bytes);
    const encoded = try c.DirectTableProtocol.Binary.encode(t.allocator, payload);
    defer t.allocator.free(encoded.base64);
    const append: c.DirectStreamMutation.Request = .{ .append = .{ .target = target, .operation = identity, .kind = .stream, .producer = null, .rows = 2, .payload = s.LogBatch.content(payload) } };
    const produce: c.DirectStream.Request = .{ .mutate = .{ .work = append, .payload = encoded } };
    access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = c.LogAuthority.append };
    try t.expectError(error.CatalogDenied, streamCall(&catalog, &access, &cached, produce, 256));
    try t.expect(cached == null);
    try t.expect((try c.OperationBinding.lookupStream(t.allocator, objects.objectStore(), identity)) == null);
    access.denied_privileges = null;
    const accepted = (try streamCall(&catalog, &access, &cached, produce, 256)).operation.?.append;
    try t.expectEqual(@as(u64, 2), accepted.next);
    var changed = produce;
    changed.mutate.work.append.target.partition = 1;
    try t.expectError(error.DataIdentityConflict, streamCall(&catalog, &access, &cached, changed, 256));
    const read_request: p.StreamRead.Request = .{ .target = target, .operation = .{ .scope = scope, .principal = 1, .operation = 101 }, .group = null, .from = 0, .until = null, .timestamp = null };
    const pinned = (try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .consume = read_request }, .payload = null } }, 256)).operation.?.consume;
    const positional = (try streamCall(&catalog, &access, &cached, .{ .cursor = .{ .target = target, .read = pinned.handle() } }, 256)).cursor;
    const cut = (try streamCall(&catalog, &access, &cached, .{ .observe = target }, 256)).cut;
    const group: p.StreamQueue.Group = .{ .id = 7, .generation = 1, .principal = 1 };
    const assigned: c.DirectStreamMutation.Request = .{ .assign = .{ .operation = .{ .scope = scope, .principal = 1, .operation = 102 }, .cut = cut, .expected = null, .group = group, .next = 0 } };
    _ = try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = assigned, .payload = null } }, 256);
    var group_request = read_request;
    group_request.operation.operation = 103;
    group_request.group = group;
    const group_read = (try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .consume = group_request }, .payload = null } }, 256)).operation.?.consume;
    const group_cursor = (try streamCall(&catalog, &access, &cached, .{ .cursor = .{ .target = target, .read = group_read.handle() } }, 256)).cursor;
    const page_request: c.DirectStream.Request = .{ .page = .{ .cursor = group_cursor, .limits = .{ .rows = 2, .encoded_bytes = 8192, .scanned_rows = 2 } } };
    access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = c.LogAuthority.acquire };
    try t.expectError(error.CatalogDenied, streamCall(&catalog, &access, &cached, page_request, 256));
    // Positional reads never need group acquire rights; their owned row bytes
    // survive the request scratch arena destroyed by streamCall.
    const page = try streamCall(&catalog, &access, &cached, .{ .page = .{ .cursor = positional, .limits = .{ .rows = 2, .encoded_bytes = 8192, .scanned_rows = 2 } } }, 256);
    defer page.deinit(t.allocator);
    try t.expectEqual(@as(usize, 2), page.page.rows.len);
    const row_bytes = try page.page.rows[0].encoded.decode(t.allocator, 8192);
    defer t.allocator.free(row_bytes);
    var decoded = try c.fuze.TableRow.decode(t.allocator, creation_request.intent.action.create.schema, row_bytes);
    defer decoded.deinit();
    try t.expectEqual(@as(i128, 42), decoded.row().cells[0].value.atom.signed);
    access.denied_privileges = null;
    const before_disclosure = access.calls;
    const consumed = try streamCall(&catalog, &access, &cached, page_request, 256);
    defer consumed.deinit(t.allocator);
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    try c.DirectStreamResponse.validate(t.allocator, connection, page_request, consumed);
    var changed_page = consumed;
    changed_page.page.rows = changed_page.page.rows[0..1];
    try t.expectError(error.InvalidStreamResponse, c.DirectStreamResponse.validate(t.allocator, connection, page_request, changed_page));
    changed_page = consumed;
    changed_page.page.examined += 1;
    try t.expectError(error.InvalidStreamResponse, c.DirectStreamResponse.validate(t.allocator, connection, page_request, changed_page));
    const disclosure_checks = access.calls - before_disclosure;
    access.deny_at = access.calls + disclosure_checks;
    // Revoke on the same final check after output rows have been copied. The
    // error path must free owned output as well as the transient read page.
    try t.expectError(error.CatalogDenied, streamCall(&catalog, &access, &cached, page_request, 256));
    try t.expectEqual(access.deny_at, access.calls);
    access.deny_at = std.math.maxInt(usize);
    // Policy revisions cannot reinterpret an accepted read or invalidate the
    // original append's larger payload. Fresh appends use the new limits.
    var smaller = creation_request.intent.action.create.limits;
    smaller.append_bytes = 1;
    const alter = try logEdit(declaration, 150, .{ .alter = .{ .configuration = declaration.stored.declaration.configuration, .limits = smaller } });
    _ = try catalog.admitLog(alter, access.policy());
    const revised = (try catalog.logOperation(alter.binding, .execute, access.policy())).operation.resulting.?;
    try t.expectEqualDeep(accepted, (try streamCall(&catalog, &access, &cached, produce, 256)).operation.?.append);
    const offset: c.DirectStreamMutation.Request = .{ .offset = .{
        .commit = .{ .operation = .{ .scope = scope, .principal = 1, .operation = 104 }, .group = group, .coverage = consumed.page.cursor.coverage, .expected_next = 0, .next = 2 },
        .cursor = consumed.page.cursor,
    } };
    _ = try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = offset, .payload = null } }, 256);
    try t.expectEqual(@as(u64, 2), (try streamCall(&catalog, &access, &cached, .{ .group = .{ .target = target, .id = group.id } }, 256)).group.?.next);
    const dropped = try logEdit(revised, 105, .drop);
    _ = try catalog.admitLog(dropped, access.policy());
    _ = try catalog.logOperation(dropped.binding, .execute, access.policy());
    try t.expectEqualDeep(accepted, (try streamCall(&catalog, &access, &cached, produce, 256)).operation.?.append);
    const after_drop = try streamCall(&catalog, &access, &cached, .{ .page = .{ .cursor = positional, .limits = .{ .rows = 2, .encoded_bytes = 8192, .scanned_rows = 2 } } }, 256);
    defer after_drop.deinit(t.allocator);
    try t.expect(after_drop.page.cursor.coverage.complete);
    try c.DirectStreamResponse.validate(t.allocator, connection, .{ .page = .{ .cursor = positional, .limits = .{ .rows = 2, .encoded_bytes = 8192, .scanned_rows = 2 } } }, after_drop);
    const release: c.DirectStreamMutation.Request = .{ .release = .{ .target = target, .operation = .{ .scope = scope, .principal = 1, .operation = 106 }, .read = group_read.handle() } };
    const released = (try streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = release, .payload = null } }, 256)).operation.?.release;
    try t.expect(cached.?.owner.root.declared.retired);
    try t.expectError(error.StreamReadReleased, streamCall(&catalog, &access, &cached, page_request, 256));
    // A closed declaration admits only settlement/closure of accepted work.
    var fresh = read_request;
    fresh.operation.operation = 107;
    try t.expectError(error.LogDeclarationConflict, streamCall(&catalog, &access, &cached, .{ .mutate = .{ .work = .{ .consume = fresh }, .payload = null } }, 256));
    cached.?.deinit();
    cached = null;
    catalog.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    catalog = try owner(&wal, &objects);
    var incomplete: usize = 0;
    for (0..16) |_| {
        const result = try streamCall(&catalog, &access, &cached, .{ .operation = append }, 1);
        if (result == .recovering) {
            try t.expect(!result.recovering.complete and result.recovering.examined <= 1);
            incomplete += 1;
        } else {
            try t.expectEqualDeep(accepted, result.operation.?.append);
            break;
        }
    } else return error.FixtureBudget;
    try t.expect(incomplete > 0);
    try t.expectEqualDeep(released, (try streamCall(&catalog, &access, &cached, .{ .operation = release }, 256)).operation.?.release);
    access.denied_privileges = .{ .id = declaration.properties.authorization, .mask = c.LogAuthority.read };
    try t.expectError(error.CatalogDenied, streamCall(&catalog, &access, &cached, .{ .cursor = .{ .target = target, .read = pinned.handle() } }, 256));
}

fn branchRequest(catalog: *D, access: *Access, operation: u64, token: u8, name: []const u8, mode: p.Branch.Mode) !@FieldType(c.DirectBranch.Request, "create") {
    var view = (try resolve(catalog, access, "events")).?;
    defer view.deinit();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    return .{ .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(19), .token = @splat(token) }, .intent = .{ .connection = connection, .namespace = 1, .operation = operation, .name = try a.Name.init(name), .source = .{ .interpretation = view.table.root.interpretation, .manifest = null, .checkpoint_lsn = 0, .accepted = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn } }, .mode = mode } };
}
fn dispatchBranch(output: std.mem.Allocator, catalog: *D, access: *Access, request: c.DirectBranch.Request) !c.DirectBranch.Result {
    const Execution = struct {
        fn ddl(_: *anyopaque, _: *D, _: p.DataLifecycle.Binding, _: D.Policy, _: u16) !D.Observation {
            return error.UnexpectedExecution;
        }
        fn namespace(_: *anyopaque, _: *D, _: c.DirectNamespace.Binding, _: D.Policy, _: u16) !c.DirectNamespace.Observation {
            return error.UnexpectedExecution;
        }
    };
    return (try c.DirectTableDispatch.apply(output, catalog, access.policy(), .{ .branch = request }, null, .{ .context = catalog, .ddl = Execution.ddl, .namespace = Execution.namespace })).branch;
}

test "direct branch unflushed data survives lost pin reply parent changes and disk reopen" {
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
    for (100..113) |value| _ = try insertSelectedTable(&catalog, &access, "events", value);
    const request = try branchRequest(&catalog, &access, 200, 1, "frozen", .full_data);
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.createBranch(request, access.policy()));
    catalog.lose_table_reply = false;
    try t.expectEqual(c.DirectBranch.Phase.admitted, (try catalog.inspectBranch(request.key, access.policy())).?.state.phase);
    try t.expect(try catalog.lookupBranch(1, request.intent.name, access.policy()) == null);
    _ = try insertSelectedTable(&catalog, &access, "events", 999);
    catalog.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    catalog = try owner(&wal, &objects);
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.advanceBranch(request.key, false, access.policy()));
    catalog.store.lose_reply = false;
    const published = try catalog.advanceBranch(request.key, false, access.policy());
    try t.expectEqual(c.DirectBranch.Phase.published, published.state.phase);
    try t.expectEqualDeep(published, try catalog.createBranch(request, access.policy()));
    var changed = request;
    changed.intent.mode = .schema_only;
    try t.expectError(error.ClientTokenConflict, catalog.createBranch(changed, access.policy()));
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const source = (try dispatchBranch(output.allocator(), &catalog, &access, .{ .source = published.state.head.? })).source;
    try t.expectEqual(13, source.rows);
    var wrong_kind = source;
    wrong_kind.interpretation.kind = .kv;
    try t.expectError(error.InvalidBranchResponse, c.DirectBranch.validateResult(t.allocator, request.key.connection, .{ .source = published.state.head.? }, .{ .source = wrong_kind }));
    var schema_value = try c.fuze.TableSchema.decode(t.allocator, try source.schema.decode(output.allocator(), c.fuze.TableSchema.max_bytes));
    defer schema_value.deinit();
    var cursor: ?P.SnapshotCursor = null;
    var seen: usize = 0;
    while (true) {
        const page = (try dispatchBranch(output.allocator(), &catalog, &access, .{ .scan = .{ .head = published.state.head.?, .after = cursor, .limits = .{ .rows = 3 } } })).page;
        try t.expectEqual(13, page.total_rows);
        for (page.rows) |row| {
            var decoded = try c.fuze.TableRow.decode(t.allocator, schema_value.schema, try row.decode(output.allocator(), c.fuze.TableRow.max_bytes));
            defer decoded.deinit();
            // Independent materialized-copy oracle: parent has 999, frozen copy 100..112.
            try t.expectEqual(@as(i64, @intCast(100 + seen)), decoded.row().cells[0].value.atom.signed);
            seen += 1;
        }
        cursor = page.next orelse break;
    }
    try t.expectEqual(13, seen);
    var selected = try catalog.openBranch(output.allocator(), published.state.head.?, access.policy());
    const retained_pin = selected.entry.pin;
    selected.deinit();
    try t.expectError(error.BranchRetentionOwned, catalog.releaseRows(create.binding.target, retained_pin, access.policy()));
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    try t.expectError(error.CatalogDenied, catalog.inspectBranch(request.key, access.policy()));
    try t.expectError(error.CatalogDenied, dispatchBranch(output.allocator(), &catalog, &access, .{ .scan = .{ .head = published.state.head.?, .after = null, .limits = .{} } }));
}

test "direct branch cancellation recovers pin cleanup and preserves nonreused identity" {
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
    _ = try insertSelectedTable(&catalog, &access, "events", 100);
    const other = try creation(8, 2, "other");
    _ = try catalog.admit(other, access.policy());
    _ = try catalog.perform(other.binding, access.policy());
    const request = try branchRequest(&catalog, &access, 200, 1, "trial", .full_data);
    var view = (try resolve(&catalog, &access, "other")).?;
    const other_position: p.DataLifecycle.Position = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn };
    view.deinit();
    const unrelated = try catalog.pinRows(other.binding.target, request.intent.identity(), other_position, access.policy());
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.createBranch(request, access.policy()));
    const original = (try catalog.inspectBranch(request.key, access.policy())).?;
    const conflict = try branchRequest(&catalog, &access, 201, 2, "trial", .full_data);
    try t.expectError(error.BranchNameConflict, catalog.createBranch(conflict, access.policy()));
    try t.expectError(error.LostAcknowledgement, catalog.advanceBranch(request.key, true, access.policy()));
    catalog.lose_table_reply = false;
    // The branch owns only its selected source. Another retained source with
    // the same reader operation must still be independently releasable.
    try catalog.releaseRows(other.binding.target, unrelated, access.policy());
    try t.expect((try catalog.pinState(other.binding.target, request.intent.identity(), access.policy())).released);
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    const cancelled = try catalog.advanceBranch(request.key, false, access.policy());
    try t.expectEqual(c.DirectBranch.Phase.cancelled, cancelled.state.phase);
    try t.expect((try catalog.pinState(request.intent.source.interpretation.object, request.intent.identity(), access.policy())).released);
    const replacement = try branchRequest(&catalog, &access, 201, 2, "trial", .schema_only);
    const published = try catalog.createBranch(replacement, access.policy());
    try t.expect(published.state.branch.branch > original.state.branch.branch);
    try t.expectEqualDeep(cancelled, try catalog.createBranch(request, access.policy()));
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const result = try dispatchBranch(output.allocator(), &catalog, &access, .{ .scan = .{ .head = published.state.head.?, .after = null, .limits = .{} } });
    try t.expectEqual(0, result.page.total_rows);
    try t.expect(result.page.next == null and result.page.rows.len == 0);
    try t.expectEqualDeep(published, try catalog.advanceBranch(replacement.key, true, access.policy()));
}

test "direct branch admission never retargets a stale unpinned source" {
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
    const request = try branchRequest(&catalog, &access, 200, 1, "stale", .full_data);
    access.deny_create = true;
    try t.expectError(error.CatalogDenied, catalog.createBranch(request, access.policy()));
    try t.expect(try catalog.inspectBranch(request.key, access.policy()) == null);
    access.deny_create = false;
    // Crash boundary after durable name/token admission, before Table pinning.
    _ = try catalog.clientToken(.{ .bind = .{ .key = request.key, .fingerprint = try request.intent.digest(), .intent = .{ .branch = request.intent }, .budget = request.budget } }, access.policy());
    try t.expectError(error.BranchRetentionOwned, catalog.captureRowsDefined(request.intent.source.interpretation, request.intent.identity(), request.intent.source.accepted, access.policy()));
    _ = try insertSelectedTable(&catalog, &access, "events", 999);
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    try t.expectError(error.TableDataChanged, catalog.advanceBranch(request.key, false, access.policy()));
    try t.expectEqual(c.DirectBranch.Phase.admitted, (try catalog.inspectBranch(request.key, access.policy())).?.state.phase);
    try t.expect((try catalog.pinState(create.binding.target, request.intent.identity(), access.policy())).handle == null);
    try t.expectEqual(c.DirectBranch.Phase.cancelled, (try catalog.advanceBranch(request.key, true, access.policy())).state.phase);
    const next = try branchRequest(&catalog, &access, 201, 2, "stale", .full_data);
    const published = try catalog.createBranch(next, access.policy());
    var key_buffer: [96]u8 = undefined;
    try objects.objectStore().delete(try s.BranchSnapshot.objectKey(published.state.head.?.reference.content, &key_buffer));
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    try t.expectError(error.BranchArtifactMissing, catalog.openBranch(scratch.allocator(), published.state.head.?, access.policy()));
    // The accepted publication remains inspectable; missing storage never
    // converts it into a new operation or a scan of the live parent.
    try t.expectEqualDeep(published, (try catalog.inspectBranch(next.key, access.policy())).?);
}

test "direct branch directories exceed the old branch model bound with one resident page" {
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
    const create = try creation(7, 1, "events");
    _ = try catalog.admit(create, access.policy());
    _ = try catalog.perform(create.binding, access.policy());
    var first: ?c.DirectBranch.Status = null;
    for (0..137) |i| {
        var name: [32]u8 = undefined;
        const request = try branchRequest(&catalog, &access, 1000 + i, @intCast(i + 1), try std.fmt.bufPrint(&name, "branch_{d}", .{i}), .full_data);
        const published = try catalog.createBranch(request, access.policy());
        if (i == 0) first = published;
        try t.expectEqual(c.DirectBranch.Phase.published, published.state.phase);
    }
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    try t.expectEqualDeep(first.?, (try catalog.lookupBranch(1, try a.Name.init("branch_0"), access.policy())).?);
    try t.expect((try catalog.lookupBranch(1, try a.Name.init("branch_136"), access.policy())).?.state.branch.branch > first.?.state.branch.branch);
}

test "mixed Table KV transaction preserves private reads rights and one decision across disk replacement" {
    const w = c.DirectTableProtocol;
    const K = c.DirectKV;
    const ReadOnly = struct {
        fn ddl(_: *anyopaque, _: *D, _: p.DataLifecycle.Binding, _: D.Policy, _: u16) !D.Observation {
            return error.UnexpectedMutation;
        }
        fn namespace(_: *anyopaque, _: *D, _: c.DirectNamespace.Binding, _: D.Policy, _: u16) !c.DirectNamespace.Observation {
            return error.UnexpectedMutation;
        }
    };
    for ([_]bool{ false, true }) |commit| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        var access: Access = .{};
        var token: c.DirectClientToken.Key = undefined;
        var kv_object: p.DataLifecycle.Object = undefined;
        var original: c.DirectTransactionWorkspace.Request = undefined;
        const settlement: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9001 };
        const payload: [1024]u8 = @splat(0x93);
        for (0..2) |restart| {
            var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
            defer wal.deinit();
            var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
            defer objects.deinit();
            var catalog = try owner(&wal, &objects);
            defer catalog.deinit();
            if (restart == 0) {
                try catalog.initialize(access.policy());
                const table = try creation(10, 1, "rows");
                _ = try catalog.admit(table, access.policy());
                _ = try catalog.perform(table.binding, access.policy());
                var kv_columns: [2]c.fuze.TableSchema.Column = undefined;
                const spec: s.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = false };
                var create = try creation(7, 2, "state");
                create.intent.kind = .kv;
                create.intent.action.create.schema = spec.schema(7, &kv_columns);
                create.binding.intent = try create.intent.digest(t.allocator);
                _ = try catalog.admit(create, access.policy());
                _ = try catalog.perform(create.binding, access.policy());
                kv_object = create.binding.target;
                const metadata = (try K.apply(arena.allocator(), arena.allocator(), &catalog, .{ .observe = kv_object }, access.policy())).definition;
                const template = try transactionToken(&catalog, 9000, 1, 0);
                token = template.key;
                const selection = [_]p.Transaction.Target{
                    .{ .object = kv_object, .kind = .kv, .partition = null },
                    .{ .object = table.binding.target, .kind = .table, .partition = null },
                };
                const begin: c.DirectTransactionRequest.Begin = .{ .key = token, .fingerprint = template.fingerprint, .operation = template.intent.transaction.begin.identity.begin, .namespace = 1, .mode = .serializable, .selection = .{ .explicit_objects = &selection }, .limits = c.DirectTransaction.default_limits, .budget = template.budget };
                _ = try catalog.beginTransaction(begin, access.policy());
                _ = try catalog.acquireTransaction(token, access.policy());
                // Ordinary SQL selection remains Table-only even when a KV
                // object is declared in the same authorized namespace.
                var tables_only = begin;
                tables_only.key.token = @splat(2);
                tables_only.operation.operation = 9100;
                tables_only.selection = .authorized_catalog_tables;
                try t.expectEqual(@as(u64, 1), (try catalog.beginTransaction(tables_only, access.policy())).binding.intent.transaction.begin.objects.count);
                _ = try catalog.settleTransaction(tables_only.key, .{ .scope = scope, .principal = 1, .operation = 9101 }, .abort, 8, access.policy());
                const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 500 }, .target = kv_object, .action = .insert, .expected_definition = metadata.interpretation.interpretation, .expected_data = null, .intent = undefined };
                var changes: [6]s.KVPartition.Change = undefined;
                const keys = [_][]const u8{ "one", "two", "three", "four", "five", "six" };
                for (&changes, keys) |*change, key| change.* = .{ .put = .{ .key = key, .value = .{ .value = .{ .atom = .{ .bytes = &payload } } } } };
                const mutation = try c.DirectKVClient.prepareMutation(&arena, binding, spec, &changes);
                const revision = (try catalog.inspectTransaction(token, access.policy())).revision;
                original = try catalog.stageTransactionKV(token, revision, 1, mutation, access.policy());
                try t.expectEqual(@as(u64, 6), (try catalog.executeTransactionStatement(token, original, access.policy())).provisional.affected);
                const row = try workspaceRequest(&catalog, &access, token, 10, 2, 501);
                _ = try catalog.executeTransactionStatement(token, row, access.policy());
                const get: K.Request = .{ .get = .{ .object = kv_object, .key = try w.Binary.encode(arena.allocator(), "six"), .source = null } };
                try t.expect((try K.apply(arena.allocator(), arena.allocator(), &catalog, get, access.policy())).value.encoded == null);
                const context: c.DirectTransactionRead.Context = .{ .key = token, .revision = (try catalog.inspectTransaction(token, access.policy())).revision };
                const execution: c.DirectTableDispatch.Execution = .{ .context = &catalog, .ddl = ReadOnly.ddl, .namespace = ReadOnly.namespace };
                const private = (try c.DirectTransactionRead.apply(arena.allocator(), &catalog, access.policy(), context, .{ .kv = get }, execution)).kv;
                try c.DirectKVResponse.validate(t.allocator, get, private);
                try t.expect(private.value.workspace != null);
                const encoded = try private.value.encoded.?.decode(arena.allocator(), c.fuze.Types.Codec.max_bytes);
                const decoded = try c.fuze.Types.Codec.decodeBoundInto(arena.allocator(), .{ .name = "value", .type = .binary, .nullable = false }, encoded);
                try t.expectEqualSlices(u8, &payload, decoded.value.atom.bytes);
                access.denied_privileges = .{ .id = metadata.authorization, .mask = c.KVAuthority.read };
                try t.expectError(error.CatalogDenied, c.DirectTransactionRead.apply(arena.allocator(), &catalog, access.policy(), context, .{ .kv = get }, execution));
                access.denied_privileges = null;
                var stale = context;
                stale.revision.next_lsn -= 1;
                try t.expectError(error.TransactionReadChanged, c.DirectTransactionRead.apply(arena.allocator(), &catalog, access.policy(), stale, .{ .kv = get }, execution));
                // A consumed private operation cannot escape as autocommit.
                try t.expectError(error.DataIdentityConflict, K.apply(arena.allocator(), arena.allocator(), &catalog, .{ .mutate = mutation }, access.policy()));
                if (commit) {
                    catalog.lose_transaction_reply = true;
                    try t.expectError(error.LostAcknowledgement, catalog.settleTransaction(token, settlement, .commit, 8, access.policy()));
                } else {
                    access.denied_privileges = .{ .id = metadata.authorization, .mask = c.KVAuthority.write };
                    try t.expectError(error.CatalogDenied, catalog.settleTransaction(token, settlement, .commit, 8, access.policy()));
                    _ = try catalog.settleTransaction(token, settlement, .abort, 8, access.policy());
                    access.denied_privileges = null;
                }
            } else {
                const settled = try catalog.settleTransaction(token, settlement, if (commit) .commit else .abort, 8, access.policy());
                try t.expect(settled.cleanup_complete);
                try t.expectEqual(commit, settled.observation.decided.outcome == .committed);
                const got = try K.apply(arena.allocator(), arena.allocator(), &catalog, .{ .get = .{ .object = kv_object, .key = try w.Binary.encode(arena.allocator(), "six"), .source = null } }, access.policy());
                try t.expectEqual(commit, got.value.encoded != null);
                var table = (try resolve(&catalog, &access, "rows")).?;
                defer table.deinit();
                try t.expectEqual(@as(u64, @intFromBool(commit)), table.table.root.live_rows);
                try t.expectEqual(@as(u64, 6), (try catalog.transactionStatementOutcome(token, original, access.policy())).?.provisional.affected);
                var graph: @import("direct_storage_graph_test.zig").Workspace = .{};
                defer graph.deinit();
                try graph.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
                var at: usize = 0;
                var steps: usize = 0;
                while (at < graph.jobs.items.len) : (at += 1) {
                    var work = graph.jobs.items[at];
                    while (!try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &graph)) {
                        steps += 1;
                        if (steps > 10000) return error.FixtureBudget;
                    }
                }
            }
        }
    }
}

test "direct KV lifecycle survives disk replacement with large atomic batches and separate rights" {
    const K = c.DirectKV;
    const Binary = c.DirectTableProtocol.Binary;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var scratch: std.heap.ArenaAllocator = .init(t.allocator);
    defer scratch.deinit();
    const alloc = scratch.allocator();
    var access: Access = .{};
    var kv_columns: [2]c.fuze.TableSchema.Column = undefined;
    const spec: s.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = false };
    var create = try creation(7, 1, "state");
    create.intent.kind = .kv;
    create.intent.action.create.schema = spec.schema(7, &kv_columns);
    create.binding.intent = try create.intent.digest(alloc);
    var work: K.Mutation = undefined;
    var pin: P.SnapshotHandle = undefined;
    var original: P.Evidence = undefined;
    const payload: [1024]u8 = @splat(0xa5);
    var encoded_value: [1100]u8 = undefined;
    const encoded = try c.fuze.Types.Codec.encodeBound(.{ .value = .{ .atom = .{ .bytes = &payload } } }, .{ .name = "value", .type = .binary, .nullable = false }, &encoded_value);
    var changes: [8]K.Change = undefined;
    for (&changes, 0..) |*change, index| {
        const key = [_]u8{@intCast(index + 1)};
        change.* = .{ .put = .{ .key = try Binary.encode(alloc, &key), .value = try Binary.encode(alloc, encoded), .expect = .absent } };
    }
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        _ = try catalog.admit(create, access.policy());
        try t.expect(try catalog.perform(create.binding, access.policy()) == .committed);
        try t.expect(try catalog.resolve(alloc, 1, create.intent.name, access.policy()) == null);
        const first = (try K.apply(alloc, alloc, &catalog, .{ .observe = create.binding.target }, access.policy())).definition;
        work = .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 2 }, .target = create.binding.target, .action = .insert, .expected_definition = first.interpretation.interpretation, .expected_data = first.position, .intent = undefined }, .changes = &changes };
        work.binding.intent = try work.digest(alloc);
        catalog.lose_table_reply = true;
        try t.expectError(error.LostAcknowledgement, K.apply(alloc, alloc, &catalog, .{ .mutate = work }, access.policy()));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    original = (try K.apply(alloc, alloc, &catalog, .{ .operation = work.binding }, access.policy())).operation.?;
    try t.expectEqual(@as(u64, 8), original.outcome.affected);
    const before = try wal.log().tail(original.outcome.position.partition);
    try t.expectEqualDeep(original, (try K.apply(alloc, alloc, &catalog, .{ .mutate = work }, access.policy())).operation.?);
    try t.expectEqual(before, try wal.log().tail(original.outcome.position.partition));
    const current = (try K.apply(alloc, alloc, &catalog, .{ .observe = create.binding.target }, access.policy())).definition;
    pin = (try K.apply(alloc, alloc, &catalog, .{ .pin = .{ .object = create.binding.target, .owner = .{ .scope = scope, .principal = 1, .operation = 3 }, .expected = current.position } }, access.policy())).pin;
    for (changes) |change| {
        const result = try K.apply(alloc, alloc, &catalog, .{ .get = .{ .object = create.binding.target, .key = change.put.key, .source = pin } }, access.policy());
        const bytes = try result.value.encoded.?.decode(alloc, c.fuze.Types.Codec.max_bytes);
        const value = try c.fuze.Types.Codec.decodeBoundInto(alloc, .{ .name = "value", .type = .binary, .nullable = false }, bytes);
        try t.expectEqualSlices(u8, &payload, value.value.atom.bytes);
    }
    access.denied_privileges = .{ .id = 107, .mask = c.KVAuthority.read };
    try t.expectError(error.CatalogDenied, K.apply(alloc, alloc, &catalog, .{ .get = .{ .object = create.binding.target, .key = changes[0].put.key, .source = pin } }, access.policy()));
    // Inspect is independent of read; a receipt never restores data authority.
    try t.expect((try K.apply(alloc, alloc, &catalog, .{ .operation = work.binding }, access.policy())).operation != null);
    access.denied_privileges = null;
    _ = try K.apply(alloc, alloc, &catalog, .{ .release = .{ .object = create.binding.target, .source = pin } }, access.policy());
    try t.expectError(error.CatalogKindMismatch, catalog.readAuthority(create.binding.target, pin.owner, access.policy(), false));
}

test "direct KV signed dispatch validates typed metadata saved mutations and absent key conflicts" {
    const K = c.DirectKV;
    const Client = c.DirectKVClient;
    const w = c.DirectTableProtocol;
    const Fixture = SignedDispatch;
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const spec: s.KVDeclaration.Spec = .{ .value_type = .int64, .nullable = false };
    const base = try creation(7, 1, "state");
    var declared = try Client.prepareDeclaration(t.allocator, .{ .binding = base.binding, .namespace = 1, .name = base.intent.name, .action = .{ .create = .{ .owner = 0, .spec = spec } } });
    for ([_]@FieldType(K.DeclarationRequest, "command"){ .preview, .admit, .execute }) |command| _ = try Fixture.call(&arena, &catalog, &access, .{ .kv_declaration = .{ .declaration = declared, .command = command, .steps = 1 } });
    const metadata = (try Fixture.call(&arena, &catalog, &access, .{ .kv_lookup = .{ .namespace = 1, .name = "state" } })).kv_lookup.?;
    try t.expect((try Fixture.call(&arena, &catalog, &access, .{ .kv_list = .{ .namespace = 1, .after = null } })).kv_list.entries[0] != null);
    const absent = (try Fixture.call(&arena, &catalog, &access, try (Client.Action{ .get = .{ .object = base.binding.target, .key = "absent" } }).encode(arena.allocator()))).kv.value;
    try t.expect(absent.encoded == null);
    var binding = base.binding;
    binding.identity.operation = 2;
    binding.action = .insert;
    binding.expected_definition = metadata.interpretation.interpretation;
    binding.expected_data = absent.position;
    const mutation = try Client.prepareMutation(&arena, binding, spec, &.{.{ .put = .{ .key = "absent", .value = .{ .value = .{ .atom = .{ .signed = 42 } } }, .expect = .absent } }});
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    const saved = try Client.save(arena.allocator(), connection, mutation);
    var loaded = try Client.load(t.allocator, saved);
    defer loaded.deinit();
    _ = try Fixture.call(&arena, &catalog, &access, .{ .kv = .{ .mutate = loaded.value.mutation } });
    _ = try Fixture.call(&arena, &catalog, &access, .{ .kv = .{ .operation = mutation.binding } });
    binding.identity.operation = 3;
    const stale = try Client.prepareMutation(&arena, binding, spec, &.{.{ .remove = "absent" }});
    try t.expectError(error.TableDataChanged, Fixture.call(&arena, &catalog, &access, .{ .kv = .{ .mutate = stale } }));
    const read = (try Fixture.call(&arena, &catalog, &access, try (Client.Action{ .get = .{ .object = base.binding.target, .key = "absent" } }).encode(arena.allocator()))).kv.value;
    const decoded = try c.fuze.Types.Codec.decodeBoundInto(arena.allocator(), .{ .name = "value", .type = .int64 }, try read.encoded.?.decode(arena.allocator(), 100));
    try t.expectEqual(@as(i64, 42), decoded.value.atom.signed);
    binding.identity.operation = 4;
    binding.expected_data = read.position;
    const conflict = try Client.prepareMutation(&arena, binding, spec, &.{ .{ .put = .{ .key = "new", .value = decoded, .expect = .absent } }, .{ .put = .{ .key = "absent", .value = decoded, .expect = .absent } } });
    try t.expectError(error.DuplicatePrimaryKey, Fixture.call(&arena, &catalog, &access, .{ .kv = .{ .mutate = conflict } }));
    try t.expect((try Fixture.call(&arena, &catalog, &access, try (Client.Action{ .get = .{ .object = base.binding.target, .key = "new" } }).encode(arena.allocator()))).kv.value.encoded == null);
    declared.binding.identity.operation = 5;
    declared.binding.action = .rename;
    declared.binding.expected_definition = metadata.interpretation.interpretation;
    declared.action = .{ .rename = try a.Name.init("renamed") };
    declared = try Client.prepareDeclaration(t.allocator, declared);
    for ([_]@FieldType(K.DeclarationRequest, "command"){ .preview, .admit, .execute }) |command| _ = try Fixture.call(&arena, &catalog, &access, .{ .kv_declaration = .{ .declaration = declared, .command = command, .steps = 1 } });
    try t.expect((try Fixture.call(&arena, &catalog, &access, .{ .kv_lookup = .{ .namespace = 1, .name = "state" } })).kv_lookup == null);
    const renamed = (try Fixture.call(&arena, &catalog, &access, .{ .kv_lookup = .{ .namespace = 1, .name = "renamed" } })).kv_lookup.?;
    declared.binding.identity.operation = 6;
    declared.binding.action = .drop;
    declared.binding.expected_definition = renamed.interpretation.interpretation;
    declared.name = renamed.name;
    declared.action = .drop;
    declared = try Client.prepareDeclaration(t.allocator, declared);
    for ([_]@FieldType(K.DeclarationRequest, "command"){ .preview, .admit, .execute }) |command| _ = try Fixture.call(&arena, &catalog, &access, .{ .kv_declaration = .{ .declaration = declared, .command = command, .steps = 1 } });
    try t.expect((try Fixture.call(&arena, &catalog, &access, .{ .kv_lookup = .{ .namespace = 1, .name = "renamed" } })).kv_lookup == null);
    _ = try Fixture.call(&arena, &catalog, &access, .{ .kv = .{ .mutate = loaded.value.mutation } });
    try t.expectError(error.TableRetired, Fixture.call(&arena, &catalog, &access, try (Client.Action{ .get = .{ .object = base.binding.target, .key = "absent" } }).encode(arena.allocator())));
}

test "direct KV and Document dependencies preserve kind rights recovery and DROP restrictions" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var kv_columns: [2]c.fuze.TableSchema.Column = undefined;
    const spec: s.KVDeclaration.Spec = .{ .value_type = .int64, .nullable = false };
    var kv = try creation(7, 1, "state");
    kv.intent.kind = .kv;
    kv.intent.action.create.schema = spec.schema(7, &kv_columns);
    kv.binding.intent = try kv.intent.digest(alloc);
    _ = try catalog.admit(kv, access.policy());
    _ = try catalog.perform(kv.binding, access.policy());
    const metadata = (try c.DirectKV.apply(alloc, alloc, &catalog, .{ .observe = kv.binding.target }, access.policy())).definition;
    const document = try namedCreation(8, 2, "document");
    _ = try catalog.resourceOperation(document, .admit, access.policy());
    const native = try namedAllocation(&catalog, &access, document, 750);
    var forward = dependencyBinding(metadata.interpretation.interpretation, 3, 8);
    forward.edge.dependent = try native.dependent(alloc);
    forward.edge.privileges = c.KVAuthority.read;
    access.denied_privileges = .{ .id = metadata.authorization, .mask = c.KVAuthority.read };
    try t.expectError(error.CatalogDenied, catalog.dependencyOperation(forward, .accept, access.policy()));
    access.denied_privileges = null;
    // The unpublished Document owns its metadata independently of data rights.
    access.denied_resource = native.resource;
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.dependencyOperation(forward, .accept, access.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    const first = (try catalog.dependencyOperation(forward, .inspect, access.policy())).outcome;
    try t.expect(first.changed and first.phase == .applied);
    try t.expectEqualDeep(first, (try catalog.dependencyOperation(forward, .accept, access.policy())).outcome);
    access.denied_resource = null;
    access.initialization = try native.initialization(alloc);
    _ = try catalog.resourceOperation(document, .execute, access.policy());
    var reverse = dependencyBinding(try native.interpretation(alloc), 4, 7);
    reverse.edge.dependent = .{ .kind = .kv, .interpretation = metadata.interpretation.interpretation };
    reverse.edge.privileges = a.select;
    access.denied_resource = native.resource;
    try t.expectError(error.CatalogDenied, catalog.dependencyOperation(reverse, .accept, access.policy()));
    access.denied_resource = null;
    access.denied_metadata = metadata.authorization;
    try t.expectError(error.CatalogDenied, catalog.dependencyOperation(reverse, .accept, access.policy()));
    access.denied_metadata = null;
    var wrong = reverse;
    wrong.operation = 5;
    wrong.edge.dependent.kind = .document;
    try t.expectEqual(.stale_definition, (try catalog.dependencyOperation(wrong, .accept, access.policy())).outcome.reason);
    const second = (try catalog.dependencyOperation(reverse, .accept, access.policy())).outcome;
    try t.expect(second.changed and second.phase == .applied);
    try t.expectEqualDeep(reverse.edge, (try catalog.dependencyPage(.{ .dependencies = kv.binding.target }, null, .dependent, access.policy())).entries[0].?);
    var kv_drop = kv;
    kv_drop.intent.action = .drop;
    kv_drop.binding.action = .drop;
    kv_drop.binding.identity.operation = 6;
    kv_drop.binding.expected_definition = metadata.interpretation.interpretation;
    kv_drop.binding.intent = try kv_drop.intent.digest(alloc);
    try t.expectEqual(.dependency, (try catalog.admit(kv_drop, access.policy())).reason);
    var document_drop = document;
    document_drop.operation = 7;
    document_drop.expected = try native.interpretation(alloc);
    document_drop.action = .drop;
    try t.expectEqual(.dependency, (try catalog.resourceOperation(document_drop, .admit, access.policy())).operation.reason);
    // Closing known edges needs dependent ownership, even after source reads
    // are revoked. Original registration receipts remain independently visible.
    access.denied_privileges = .{ .id = metadata.authorization, .mask = c.KVAuthority.read };
    var close = forward;
    close.operation = 8;
    close.action = .remove;
    try t.expect((try catalog.dependencyOperation(close, .accept, access.policy())).outcome.changed);
    access.denied_privileges = null;
    access.denied_resource = native.resource;
    close = reverse;
    close.operation = 9;
    close.action = .remove;
    try t.expect((try catalog.dependencyOperation(close, .accept, access.policy())).outcome.changed);
    access.denied_resource = null;
    try t.expectEqualDeep(first, (try catalog.dependencyOperation(forward, .accept, access.policy())).outcome);
    try t.expectEqualDeep(second, (try catalog.dependencyOperation(reverse, .accept, access.policy())).outcome);
    kv_drop.binding.identity.operation = 10;
    _ = try catalog.admit(kv_drop, access.policy());
    try t.expect((try catalog.perform(kv_drop.binding, access.policy())) == .committed);
    document_drop.operation = 11;
    _ = try catalog.resourceOperation(document_drop, .admit, access.policy());
    try t.expect((try catalog.resourceOperation(document_drop, .execute, access.policy())).operation.retired);
}

fn finishTableDdl(catalog: *D, access: *Access, binding: p.DataLifecycle.Binding) !void {
    for (0..128) |_| {
        const observed = try catalog.perform(binding, access.policy());
        if (observed == .committed or observed == .finalizing) break;
        try t.expect(observed == .admitted);
    } else return error.TestUnexpectedResult;
    for (0..128) |_| {
        _ = try catalog.settle(binding, access.policy());
        if ((try catalog.store.operation(binding)).?.phase == .settled) return;
    }
    return error.TestUnexpectedResult;
}

test "staged Table foreign keys recover protection before publication and bounded cleanup on disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var child_binding: p.DataLifecycle.Binding = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        try catalog.initialize(access.policy());
        const parent = try creation(7, 1, "parent");
        _ = try catalog.admit(parent, access.policy());
        try finishTableDdl(&catalog, &access, parent.binding);
        var view = (try resolve(&catalog, &access, "parent")).?;
        defer view.deinit();
        var child = try creation(8, 2, "child");
        const fk: c.fuze.TableConstraints.ForeignKeyConstraint = .{ .id = 1, .name = "parent_id", .local_columns = &.{1}, .target_object = 7, .target_revision = 1, .target_definition = view.table.root.interpretation, .target_columns = &.{1} };
        child.intent.action.create.schema.integrity = .{ .next_id = 2, .foreign_keys = (&fk)[0..1] };
        child.binding.intent = try child.intent.digest(t.allocator);
        child_binding = child.binding;
        _ = try catalog.admit(child, access.policy());
        _ = try catalog.attachRegistration(child.binding, access.policy());
        catalog.store.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.perform(child.binding, access.policy()));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    try t.expect(try resolve(&catalog, &access, "child") == null);
    const progress = (try catalog.status(child_binding, access.policy())).admitted;
    try t.expectEqual(@as(u16, 1), progress.protected_columns);
    {
        // A replay record cannot invent another protected column without the
        // corresponding two graph entries, even with a valid operation index.
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        const guard = try Access.make(&access, arena.allocator(), try a.guard(access.policy().subject, profile, null, null, .database), null);
        var batch: s.TreeStore.Batch = .{};
        try catalog.store.index.beginBatch(catalog.options.index_work_bytes, &batch);
        defer catalog.store.index.end();
        var proposed = catalog.store.root;
        proposed.next_lsn += 1;
        try catalog.store.receipt(&proposed, child_binding);
        var forged = progress;
        forged.dependency_steps += 1;
        forged.protected_columns += 1;
        forged.dependency_change = null;
        const before = catalog.store.root;
        try t.expectError(error.InvalidDirectCatalogTransition, catalog.store.publish(proposed, .{ .operation = forged }, guard));
        try t.expectEqualDeep(before, catalog.store.root);
    }
    var parent = (try resolve(&catalog, &access, "parent")).?;
    defer parent.deinit();
    const drop = try edit(&parent, 3, .drop);
    try t.expectEqual(.dependency, (try catalog.admit(drop, access.policy())).reason);
    const incompatible = try edit(&parent, 4, .{ .alter = .{ .type = .{ .column = 1, .type = .int32, .max_characters = null } } });
    try t.expectEqual(.dependency, (try catalog.preview(incompatible, access.policy())).reason);
    try t.expectEqual(.dependency, (try catalog.admit(incompatible, access.policy())).reason);
    const rename = try edit(&parent, 5, .{ .rename = try a.Name.init("renamed") });
    _ = try catalog.admit(rename, access.policy());
    try finishTableDdl(&catalog, &access, rename.binding);
    access.denied_metadata = 107;
    try t.expectError(error.CatalogDenied, catalog.perform(child_binding, access.policy()));
    access.denied_metadata = null;
    try finishTableDdl(&catalog, &access, child_binding);
    var child = (try resolve(&catalog, &access, "child")).?;
    defer child.deinit();
    try t.expectEqual(parent.table.root.interpretation, child.table.declaration.schema.schema.integrity.foreign_keys[0].target_definition.?);
    const graph = try catalog.dependencyPage(.{ .dependencies = child_binding.target }, null, .dependent, access.policy());
    try t.expectEqual(@as(u32, 1), graph.entries[0].?.foreign_key.?.constraint);
    var erase = graph.entries[0].?;
    erase.privileges = 0;
    try t.expectError(error.TableDependencyOwned, catalog.dependencyOperation(.{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 1, .principal = 1, .role = null }, .operation = 90, .edge = erase, .action = .remove, .authority = .dependent }, .accept, access.policy()));
    var replacement = child.table.declaration.schema.schema;
    replacement.integrity = .{ .next_id = 2 };
    const remove = try edit(&child, 6, .{ .alter = .{ .integrity = replacement } });
    _ = try catalog.admit(remove, access.policy());
    // Publication precedes graph cleanup; a crash here leaves protection.
    try t.expect((try catalog.perform(remove.binding, access.policy())) == .finalizing);
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.settle(remove.binding, access.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    try finishTableDdl(&catalog, &access, remove.binding);
    try t.expect((try catalog.dependencyPage(.{ .dependencies = child_binding.target }, null, .dependent, access.policy())).entries[0] == null);
    var renamed = (try resolve(&catalog, &access, "renamed")).?;
    defer renamed.deinit();
    const retire = try edit(&renamed, 7, .drop);
    try t.expectEqual(.none, (try catalog.admit(retire, access.policy())).reason);
    try finishTableDdl(&catalog, &access, retire.binding);
    try catalog.recover();
    try t.expect((try catalog.status(child_binding, access.policy())) == .committed);
}

test "staged Table foreign key cancellation resumes original cleanup after source revocation" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const parent = try creation(7, 1, "parent");
    _ = try catalog.admit(parent, access.policy());
    try finishTableDdl(&catalog, &access, parent.binding);
    var view = (try resolve(&catalog, &access, "parent")).?;
    defer view.deinit();
    var child = try creation(8, 2, "child");
    const fk: c.fuze.TableConstraints.ForeignKeyConstraint = .{ .id = 1, .name = "parent_id", .local_columns = &.{1}, .target_object = 7, .target_revision = 1, .target_definition = view.table.root.interpretation, .target_columns = &.{1} };
    child.intent.action.create.schema.integrity = .{ .next_id = 2, .foreign_keys = (&fk)[0..1] };
    child.binding.intent = try child.intent.digest(t.allocator);
    _ = try catalog.admit(child, access.policy());
    try t.expect((try catalog.perform(child.binding, access.policy())) == .admitted);
    access.denied_metadata = 107;
    try t.expectError(error.CatalogDenied, catalog.perform(child.binding, access.policy()));
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.cancel(child.binding, access.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    const closing = (try catalog.status(child.binding, access.policy())).admitted;
    try t.expectEqual(.cancelled, closing.closing.?.phase);
    // Completing cancellation needs the child's current authority. Parent
    // revocation cannot leak a registration or authorize a new publication.
    for (0..8) |_| {
        const outcome = try catalog.cancel(child.binding, access.policy());
        if (outcome == .cancelled) break;
        try t.expect(outcome == .admitted);
    } else return error.TestUnexpectedResult;
    try t.expect(try resolve(&catalog, &access, "child") == null);
    access.denied_metadata = null;
    try t.expect((try catalog.dependencyPage(.{ .dependents = parent.binding.target }, null, .dependent, access.policy())).entries[0] == null);
    const drop = try edit(&view, 3, .drop);
    _ = try catalog.admit(drop, access.policy());
    try finishTableDdl(&catalog, &access, drop.binding);
    try t.expect((try catalog.perform(child.binding, access.policy())) == .cancelled);
}

test "CHECK constraints fence transaction candidates and preserve savepoint recovery" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var catalog = try owner(&wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    const binding = try selectedTransactionIntegrity(&catalog, &access, 1, true);
    _ = try catalog.acquireTransaction(binding.key, access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, 1, 500), access.policy());
    _ = try catalog.transactionSavepoint(binding.key, try savepointRequest(&catalog, &access, binding.key, 800, .{ .create = try a.Name.init("valid") }), 8, access.policy());
    // Binary ingress cannot stage an invalid candidate under this exact schema.
    try t.expectError(error.CheckConstraintViolation, workspaceRequest(&catalog, &access, binding.key, 10, 2, 700));
    const current = try catalog.inspectTransaction(binding.key, access.policy());
    catalog.transaction_read = .{ .key = binding.key, .revision = current.revision };
    var private = (try resolve(&catalog, &access, "selected_0")).?;
    defer private.deinit();
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const schema = private.table.declaration.schema.schema;
    const workspace = private.table.workspace_read.?;
    var buffer: [65536]u8 = undefined;
    const metadata: c.DirectTableProtocol.Definition = .{
        .interpretation = private.table.root.declared(),
        .namespace = private.properties.namespace,
        .authorization = private.properties.authorization,
        .name = private.properties.name,
        .position = workspace.source.source.accepted,
        .changed_lsn = workspace.source.changed_lsn,
        .workspace = workspace,
        .row_count = private.table.root.live_rows,
        .schema = try c.DirectTableProtocol.Binary.encode(allocator, try schema.encode(&buffer)),
    };
    var compiled = try c.fuze.TableDml.compile(allocator, "UPDATE selected_0 SET id=700 WHERE id=500", "selected_0", schema, null);
    defer compiled.deinit();
    var intent = try c.DirectTableIntent.fromDml(allocator, binding.key.connection, metadata, 701, compiled.plan, .bulk);
    defer intent.deinit();
    catalog.transaction_read = null;
    const request = try catalog.stageTransactionStatement(binding.key, current.revision, current.last_statement + 1, intent.parsed.value.work, access.policy());
    const before = try catalog.transactionTableState(binding.key, request.binding.target, access.policy());
    const outcome = try catalog.executeTransactionStatement(binding.key, request, access.policy());
    try t.expectEqual(.check_violation, outcome.rejected.reason);
    try t.expectEqualDeep(before.root.rows, (try catalog.transactionTableState(binding.key, request.binding.target, access.policy())).root.rows);
    try catalog.recover();
    try t.expectEqualDeep(outcome, try catalog.executeTransactionStatement(binding.key, request, access.policy()));
    const rollback = try savepointRequest(&catalog, &access, binding.key, 801, .{ .rollback = try a.Name.init("valid") });
    var complete = false;
    for (0..8) |_| if ((try catalog.transactionSavepoint(binding.key, rollback, 8, access.policy())).completed != null) {
        complete = true;
        break;
    };
    try t.expect(complete);
    const after = try catalog.inspectTransaction(binding.key, access.policy());
    _ = try catalog.executeTransactionStatement(binding.key, try workspaceRequest(&catalog, &access, binding.key, 10, after.last_statement + 1, 501), access.policy());
    const result = try catalog.settleTransaction(binding.key, .{ .scope = scope, .principal = 1, .operation = 900 }, .commit, 8, access.policy());
    try t.expect(result.cleanup_complete and result.observation.decided.outcome == .committed);
    var published = (try resolve(&catalog, &access, "selected_0")).?;
    defer published.deinit();
    try t.expectEqual(@as(u64, 2), published.table.root.live_rows);
    try t.expect(!published.table.declaration.schema.schema.integrity.checks[0].validated);
}

const SignedDispatch = struct {
    fn ddl(_: *anyopaque, catalog: *D, binding: p.DataLifecycle.Binding, policy: D.Policy, _: u16) !D.Observation {
        return catalog.perform(binding, policy);
    }
    fn namespace(_: *anyopaque, _: *D, _: c.DirectNamespace.Binding, _: D.Policy, _: u16) !c.DirectNamespace.Observation {
        return error.UnexpectedDispatchExecution;
    }
    fn call(arena: *std.heap.ArenaAllocator, catalog: *D, access: *Access, action: c.DirectTableProtocol.Action) !c.DirectTableProtocol.Result {
        const w = c.DirectTableProtocol;
        const alloc = arena.allocator();
        const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
        const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = connection, .nonce = @splat(9), .action = action, .delegation = null };
        const context = try w.Request.context(input, alloc);
        const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 1, .principal = 1, .role = null, .audience = 3, .credential_epoch = 1, .context = context }, try p.Ed25519.KeyPair.generateDeterministic(@splat(7)));
        const request: w.Request = .{ .definition = input.definition, .connection = connection, .nonce = input.nonce, .action = action, .delegation = null, .proof = proof };
        try request.validate(alloc);
        const result = try c.DirectTableDispatch.apply(alloc, catalog, access.policy(), action, null, .{ .context = access, .ddl = ddl, .namespace = namespace });
        const response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .subject = .{ .principal = 1, .login_role = 1, .role = 1, .credential_epoch = 1, .audience = 3, .context = context }, .result = result };
        try c.DirectTableClient.validateResponse(alloc, request, response);
        return result;
    }
};

test "retained projection inspection separates metadata rights from row placement and rejects spliced coverage" {
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
    var last: P.Evidence = undefined;
    for (10..20) |operation| last = try insertSelectedTable(&catalog, &access, "events", operation);
    const pin = try catalog.pinRows(create.binding.target, .{ .scope = scope, .principal = 1, .operation = 100 }, last.outcome.position, access.policy());
    const snapshot: c.DirectTableProtocol.Snapshot = .{ .object = create.binding.target, .handle = pin };
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const before = catalog.store.root;
    const puts = objects.puts;
    const first = (try SignedDispatch.call(&output, &catalog, &access, .{ .projection_locations = .{ .snapshot = snapshot, .after = null } })).projection_locations;
    try t.expectEqual(@as(u8, 8), first.count);
    try t.expect(first.next != null);
    const definitions = (try SignedDispatch.call(&output, &catalog, &access, .{ .projection_definitions = .{ .snapshot = snapshot, .after = null } })).projection_definitions;
    try t.expectEqual(@as(u64, 10), definitions.entry.?.rows);
    try t.expectEqual(@as(u64, 1), definitions.entry.?.columns[0].?.source.physical);
    try t.expectEqual(null, definitions.next);
    const final = (try SignedDispatch.call(&output, &catalog, &access, .{ .projection_locations = .{ .snapshot = snapshot, .after = first.next } })).projection_locations;
    try t.expectEqual(@as(u8, 2), final.count);
    try t.expectEqual(null, final.next);
    try t.expectEqual(puts, objects.puts);
    try t.expectEqualDeep(before, catalog.store.root);
    access.visible_despite_denied_privileges = true;
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    _ = try SignedDispatch.call(&output, &catalog, &access, .{ .projection_definitions = .{ .snapshot = snapshot, .after = null } });
    try t.expectError(error.CatalogDenied, SignedDispatch.call(&output, &catalog, &access, .{ .projection_locations = .{ .snapshot = snapshot, .after = first.next } }));
    access.denied_privileges = null;
    access.deny_at = access.calls + 4;
    try t.expectError(error.CatalogDenied, catalog.projectionDefinitions(snapshot.object, pin, null, access.policy()));
    access.deny_at = std.math.maxInt(usize);
    var changed = first.next.?;
    changed.source.sha256[0] ^= 1;
    try t.expectError(error.InvalidTableCursor, SignedDispatch.call(&output, &catalog, &access, .{ .projection_locations = .{ .snapshot = snapshot, .after = changed } }));
    var view = (try resolve(&catalog, &access, "events")).?;
    const drop = try edit(&view, 101, .drop);
    view.deinit();
    _ = try catalog.admit(drop, access.policy());
    _ = try catalog.perform(drop.binding, access.policy());
    _ = try catalog.settle(drop.binding, access.policy());
    const replacement = try creation(8, 102, "events");
    _ = try catalog.admit(replacement, access.policy());
    _ = try catalog.perform(replacement.binding, access.policy());
    const retained = try catalog.projectionDefinitions(snapshot.object, pin, null, access.policy());
    try t.expectEqualDeep(definitions.logical, retained.logical);
    try t.expectEqual(definitions.total_rows, retained.total_rows);
    try catalog.releaseRows(snapshot.object, pin, access.policy());
    try t.expectError(error.TableSnapshotReleased, catalog.projectionDefinitions(snapshot.object, pin, null, access.policy()));
}

fn historyRequest(catalog: *D, access: *Access, operation: u64, token: u8, names: []const []const u8) !@FieldType(c.DirectHistory.Request, "acquire") {
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    var selection: c.DirectHistory.Selection = .{ .owner = .{ .scope = scope, .principal = 1, .operation = operation }, .branch = 1, .directory = null };
    for (names) |name| selection = try catalog.selectHistory(.{ .selection = selection, .namespace = 1, .name = try a.Name.init(name) }, access.policy());
    return .{ .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(20), .token = @splat(token) }, .intent = .{ .connection = connection, .namespace = 1, .operation = operation, .selection = selection.directory.?, .common = null } };
}

test "historical acquisition preserves selected WAL cuts through lost replies rename name reuse and release" {
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
    for ([_][]const u8{ "events", "other" }, 7..) |name, id| {
        const create = try creation(id, id, name);
        _ = try catalog.admit(create, access.policy());
        _ = try catalog.perform(create.binding, access.policy());
        _ = try catalog.settle(create.binding, access.policy());
        _ = try insertSelectedTable(&catalog, &access, name, id + 100);
    }
    const request = try historyRequest(&catalog, &access, 200, 1, &.{ "events", "other" });
    const admitted = try catalog.acquireHistory(request, access.policy());
    try t.expectEqual(@as(?u64, 7), admitted.state.inflight);
    try t.expect(admitted.state.snapshot == null);
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.advanceHistory(request.key, .advance, access.policy()));
    catalog.lose_table_reply = false;
    const pin = (try catalog.pinState(.{ .scope = scope, .branch = 1, .object = 7 }, request.intent.identity(), access.policy())).handle.?;
    try t.expectError(error.HistoricalRetentionOwned, catalog.releaseRows(.{ .scope = scope, .branch = 1, .object = 7 }, pin, access.policy()));
    _ = try insertSelectedTable(&catalog, &access, "events", 999);
    catalog.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    catalog = try owner(&wal, &objects);
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.advanceHistory(request.key, .advance, access.policy()));
    catalog.store.lose_reply = false;
    var published: c.DirectHistory.Status = undefined;
    for (0..16) |_| {
        published = try catalog.advanceHistory(request.key, .advance, access.policy());
        if (published.state.phase == .published) break;
    } else return error.FixtureBudget;
    const snapshot = published.state.snapshot.?;
    try t.expectEqual(@as(u64, 2), snapshot.source_count);
    try t.expectEqual(p.DataLifecycle.Consistency.independent, snapshot.consistency);
    try t.expectEqualDeep(published, try catalog.acquireHistory(request, access.policy()));
    try t.expectEqualDeep(published, try catalog.advanceHistory(request.key, .abandon, access.policy()));
    var changed = request;
    changed.intent.selection.count += 1;
    try t.expectError(error.ClientTokenConflict, catalog.acquireHistory(changed, access.policy()));
    try t.expectError(error.HistoricalOperationRequired, catalog.clientProgress(.{ .update = .{ .key = request.key, .expected = published.revision, .pending = false, .cancel = false, .record = null } }, access.policy()));
    var view = (try resolve(&catalog, &access, "events")).?;
    const rename = try edit(&view, 201, .{ .rename = try a.Name.init("archived") });
    view.deinit();
    _ = try catalog.admit(rename, access.policy());
    _ = try catalog.perform(rename.binding, access.policy());
    _ = try catalog.settle(rename.binding, access.policy());
    const replacement = try creation(9, 202, "events");
    _ = try catalog.admit(replacement, access.policy());
    _ = try catalog.perform(replacement.binding, access.policy());
    try t.expectEqual(@as(?u64, 7), try catalog.lookupHistory(snapshot, 1, try .init("events"), access.policy()));
    try t.expect(try catalog.lookupHistory(snapshot, 1, try .init("archived"), access.policy()) == null);
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    {
        var selected = try catalog.openHistory(output.allocator(), snapshot, 7, true, access.policy());
        defer selected.deinit();
        var page = try selected.access.view.table.scanSnapshot(t.allocator, selected.binding.pin.?, null, .{}, selected.access.current);
        defer page.deinit();
        try t.expectEqual(@as(u64, 1), page.total_rows);
        try t.expectEqual(@as(i128, 107), page.rows[0].?.row().cells[0].value.atom.signed);
    }
    access.visible_despite_denied_privileges = true;
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    var metadata = try catalog.openHistory(output.allocator(), snapshot, 7, false, access.policy());
    metadata.deinit();
    try t.expectError(error.CatalogDenied, catalog.openHistory(output.allocator(), snapshot, 7, true, access.policy()));
    access.denied_privileges = null;
    const closing = try catalog.advanceHistory(request.key, .release, access.policy());
    try t.expectEqual(c.DirectHistory.Phase.releasing, closing.state.phase);
    try t.expectEqualDeep(snapshot, closing.state.snapshot.?);
    try t.expectError(error.HistoricalSnapshotReleased, catalog.openHistory(output.allocator(), snapshot, 7, true, access.policy()));
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.advanceHistory(request.key, .advance, access.policy()));
    catalog.lose_table_reply = false;
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    var released: c.DirectHistory.Status = undefined;
    for (0..8) |_| {
        released = try catalog.advanceHistory(request.key, .advance, access.policy());
        if (released.state.phase == .released) break;
    } else return error.FixtureBudget;
    try t.expectEqualDeep(snapshot, released.state.snapshot.?);
    try t.expectEqualDeep(released, try catalog.advanceHistory(request.key, .release, access.policy()));
    for ([_]u64{ 7, 8 }) |id| try t.expect((try catalog.pinState(.{ .scope = scope, .branch = 1, .object = id }, request.intent.identity(), access.policy())).released);
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    try t.expectError(error.CatalogDenied, catalog.openHistory(output.allocator(), snapshot, 7, true, access.policy()));
    access.denied_privileges = null;
    access.denied_metadata = 107;
    try t.expectError(error.CatalogDenied, catalog.openHistory(output.allocator(), snapshot, 7, false, access.policy()));
    try t.expectError(error.CatalogDenied, catalog.lookupHistory(snapshot, 1, try .init("events"), access.policy()));
    access.denied_metadata = null;
    try t.expectError(error.HistoricalSnapshotReleased, catalog.lookupHistory(snapshot, 1, try .init("events"), access.policy()));
    var foreign = snapshot;
    foreign.catalog_root.sha256[0] ^= 1;
    try t.expectError(error.HistoricalIdentityConflict, catalog.openHistory(output.allocator(), foreign, 7, true, access.policy()));
}

test "historical acquisition refuses stale input and abandons only recorded pins" {
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
    _ = try insertSelectedTable(&catalog, &access, "events", 100);
    const stale = try historyRequest(&catalog, &access, 200, 1, &.{"events"});
    _ = try catalog.acquireHistory(stale, access.policy());
    _ = try insertSelectedTable(&catalog, &access, "events", 101);
    try t.expectError(error.TableDataChanged, catalog.advanceHistory(stale.key, .advance, access.policy()));
    _ = try catalog.advanceHistory(stale.key, .abandon, access.policy());
    for (0..8) |_| {
        const value = try catalog.advanceHistory(stale.key, .advance, access.policy());
        if (value.state.phase == .cancelled) break;
    } else return error.FixtureBudget;
    try t.expect((try catalog.pinState(create.binding.target, stale.intent.identity(), access.policy())).handle == null);
    const request = try historyRequest(&catalog, &access, 201, 2, &.{"events"});
    _ = try catalog.acquireHistory(request, access.policy());
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.advanceHistory(request.key, .advance, access.policy()));
    catalog.lose_table_reply = false;
    const abandoned = try catalog.advanceHistory(request.key, .abandon, access.policy());
    try t.expect(abandoned.state.inflight != null);
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    try t.expectError(error.CatalogDenied, catalog.advanceHistory(request.key, .advance, access.policy()));
    access.denied_privileges = null;
    for (0..8) |_| {
        const value = try catalog.advanceHistory(request.key, .advance, access.policy());
        if (value.state.phase == .cancelled) break;
    } else return error.FixtureBudget;
    try t.expect((try catalog.pinState(create.binding.target, request.intent.identity(), access.policy())).released);
}

/// Metadata inspection must not hide a data read or immutable write in an
/// otherwise read-only signed action. Real backing objects remain available.
const MetadataObjects = struct {
    const O = s.TransitObjectStore;
    inner: O.ObjectStore,
    reads: usize = 0,
    fn from(raw: *anyopaque) *MetadataObjects {
        return @ptrCast(@alignCast(raw));
    }
    fn allowed(key: []const u8) !void {
        if (std.mem.endsWith(u8, key, ".tseg") or std.mem.endsWith(u8, key, ".tdel")) return error.UnexpectedMetadataDataRead;
    }
    fn get(raw: *anyopaque, key: []const u8, offset: u64, length: u32, output: []u8) ![]const u8 {
        try allowed(key);
        const self = from(raw);
        self.reads += 1;
        return self.inner.getRange(key, offset, length, output);
    }
    fn head(raw: *anyopaque, key: []const u8) !?O.ObjectMeta {
        try allowed(key);
        return from(raw).inner.head(key);
    }
    fn put(_: *anyopaque, _: []const u8, _: []const u8, _: [32]u8) !O.ObjectMeta {
        return error.UnexpectedMetadataWrite;
    }
    fn conditional(_: *anyopaque, _: []const u8, _: O.Condition, _: []const u8) !bool {
        return error.UnexpectedMetadataWrite;
    }
    fn delete(_: *anyopaque, _: []const u8) !void {
        return error.UnexpectedMetadataWrite;
    }
    fn store(self: *MetadataObjects) O.ObjectStore {
        return .{ .context = self, .vtable = &.{ .putImmutable = put, .putConditional = conditional, .getRange = get, .head = head, .delete = delete } };
    }
};

test "historical acquisition signed disclosure and collectible directory closure" {
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
    for (10..20) |operation| _ = try insertSelectedTable(&catalog, &access, "events", operation);
    const flush_target: D.FlushTarget = .{ .object = create.binding.target, .through = (try catalog.inspectStorage(create.binding.target, 1, access.policy())).position };
    for (0..8) |_| {
        if ((try catalog.flushStorage(flush_target, access.policy())).complete) break;
    } else return error.TestUnexpectedResult;
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    const selection = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .select = .{ .selection = .{ .owner = .{ .scope = scope, .principal = 1, .operation = 100 }, .branch = 1, .directory = null }, .namespace = 1, .name = try a.Name.init("events") } } })).historical_catalog.selection;
    const request: @FieldType(c.DirectHistory.Request, "acquire") = .{ .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(20), .token = @splat(21) }, .intent = .{ .connection = connection, .namespace = 1, .operation = 100, .selection = selection.directory.?, .common = null } };
    var status = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .acquire = request } })).historical_catalog.status.?;
    for (0..12) |_| {
        if (status.state.phase == .published) break;
        _ = output.reset(.retain_capacity);
        status = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .advance = request.key } })).historical_catalog.status.?;
    } else return error.TestUnexpectedResult;
    const snapshot = status.state.snapshot.?;
    const before_puts = objects.puts;
    const before_control = try wal.log().tail(catalog.store.root.configuration.partition);
    const before_data = try wal.log().tail(flush_target.through.partition);
    var metadata_objects: MetadataObjects = .{ .inner = catalog.data_objects };
    catalog.data_objects = metadata_objects.store();
    defer catalog.data_objects = metadata_objects.inner;
    const namespace = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .namespace = .{ .snapshot = snapshot, .name = try a.Name.init("public") } } })).historical_catalog.namespace.?;
    try t.expectEqual(@as(u64, 1), namespace.id);
    const selected_id = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .lookup = .{ .snapshot = snapshot, .namespace = 1, .name = try a.Name.init("events") } } })).historical_catalog.object.?;
    try t.expectEqual(@as(u64, 7), selected_id);
    const source = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .source = .{ .snapshot = snapshot, .object = 7 } } })).historical_catalog.source;
    var reader = try c.DirectTableReader.initCatalog(t.allocator, connection, source);
    defer reader.deinit();
    try t.expectEqualDeep(snapshot, reader.basis.catalog.?);
    try t.expectEqual(@as(u64, 10), reader.basis.row_count);
    const listing = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .list = .{ .snapshot = snapshot, .namespace = 1, .after = null } } })).historical_catalog.listing;
    try t.expectEqual(@as(usize, 1), listing.entries.len);
    try t.expect(listing.next == null);
    try t.expectEqualStrings("events", listing.entries[0].properties.name.slice());
    const definitions_request: c.DirectHistory.Request = .{ .definitions = .{ .snapshot = snapshot, .object = 7, .after = null } };
    const locations_request: c.DirectHistory.Request = .{ .locations = .{ .snapshot = snapshot, .object = 7, .after = null } };
    access.visible_despite_denied_privileges = true;
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    const coverage = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = definitions_request })).historical_catalog.definitions;
    try t.expectEqualDeep(source.binding.declaration, coverage.evidence.logical);
    try t.expectEqual(@as(u64, 10), coverage.evidence.entry.?.rows);
    try t.expect(coverage.evidence.next == null);
    try t.expectError(error.CatalogDenied, SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = locations_request }));
    access.denied_privileges = null;
    const locations = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = locations_request })).historical_catalog.locations;
    try t.expectEqual(@as(u8, 8), locations.evidence.count);
    const locations_tail: c.DirectHistory.Request = .{ .locations = .{ .snapshot = snapshot, .object = 7, .after = locations.evidence.next } };
    const tail = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = locations_tail })).historical_catalog.locations;
    try t.expectEqual(@as(u8, 2), tail.evidence.count);
    try t.expect(tail.evidence.next == null);
    var forged_coverage = coverage;
    forged_coverage.source.accepted.next_lsn += 1;
    try t.expectError(error.InvalidHistoricalResponse, c.DirectHistory.validateResult(t.allocator, connection, definitions_request, .{ .definitions = forged_coverage }));
    var forged_locations = locations;
    forged_locations.evidence.next.?.source.sha256[0] ^= 1;
    try t.expectError(error.InvalidTableResponse, c.DirectHistory.validateResult(t.allocator, connection, locations_request, .{ .locations = forged_locations }));
    try t.expect(metadata_objects.reads > 0);
    try t.expectEqual(before_puts, objects.puts);
    try t.expectEqual(before_control, try wal.log().tail(catalog.store.root.configuration.partition));
    try t.expectEqual(before_data, try wal.log().tail(flush_target.through.partition));
    catalog.data_objects = metadata_objects.inner;
    const read: c.DirectHistory.Read = .{ .snapshot = snapshot, .object = 7, .after = null, .limits = .{ .rows = 8, .encoded_bytes = 65536 } };
    const first = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .scan = read } })).historical_catalog.page;
    try t.expectEqual(@as(usize, 8), first.rows.len);
    const cursor = first.next.?;
    var next = read;
    next.after = cursor;
    var tampered = first;
    tampered.snapshot.catalog_root.sha256[0] ^= 1;
    try t.expectError(error.InvalidHistoricalResponse, c.DirectHistory.validateResult(t.allocator, connection, .{ .scan = read }, .{ .page = tampered }));
    access.visible_despite_denied_privileges = true;
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    _ = try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .source = .{ .snapshot = snapshot, .object = 7 } } });
    try t.expectError(error.CatalogDenied, SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .scan = next } }));
    access.denied_privileges = null;
    const last = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .scan = next } })).historical_catalog.page;
    try t.expectEqual(@as(usize, 2), last.rows.len);
    try t.expect(last.next == null);
    // Unaccepted staging may be collected; accepted selected/retained directory
    // pages and entry contents remain reachable through retained catalog WAL.
    const orphan = try historyRequest(&catalog, &access, 101, 22, &.{"events"});
    var workspace: @import("direct_storage_graph_test.zig").Workspace = .{};
    defer workspace.deinit();
    try workspace.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
    {
        var view = (try resolve(&catalog, &access, "events")).?;
        defer view.deinit();
        const cut = try view.table.recoveryState();
        try workspace.enqueue(.{ .table_history = try .init(.{ .root = cut.root, .chain = cut.chain }) });
    }
    var at: usize = 0;
    var steps: usize = 0;
    while (at < workspace.jobs.items.len) : (at += 1) {
        var work = workspace.jobs.items[at];
        while (true) {
            const jobs = workspace.jobs.items.len;
            const done = try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &workspace);
            try t.expect(workspace.jobs.items.len - jobs <= 3);
            steps += 1;
            if (steps > 100000) return error.FixtureBudget;
            if (done) break;
        }
    }
    var key: [96]u8 = undefined;
    try t.expect(workspace.marks.contains(try c.DirectHistoryDirectory.objectKey(snapshot.catalog_root, &key)));
    try t.expect(workspace.marks.contains(try c.DirectHistoryDirectory.objectKey(snapshot.sources_root, &key)));
    try t.expect(!workspace.marks.contains(try c.DirectHistoryDirectory.objectKey(orphan.intent.selection.content, &key)));
    at = 0;
    while (at < objects.objects.items.len) {
        const item = objects.objects.items[at];
        if (c.DirectStorageGraph.collectible(item.key) and !workspace.marks.contains(item.key)) try objects.objectStore().delete(item.key) else at += 1;
    }
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    try catalog.recover();
    _ = try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .source = .{ .snapshot = snapshot, .object = 7 } } });
    _ = try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .scan = next } });
    _ = try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .release = request.key } });
    try t.expectError(error.HistoricalSnapshotReleased, SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .scan = next } }));
    try t.expectError(error.HistoricalSnapshotReleased, SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = definitions_request }));
    try t.expectError(error.HistoricalSnapshotReleased, SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = locations_tail }));
    for (0..4) |_| {
        status = (try SignedDispatch.call(&output, &catalog, &access, .{ .historical_catalog = .{ .advance = request.key } })).historical_catalog.status.?;
        if (status.state.phase == .released) break;
    } else return error.TestUnexpectedResult;
    try t.expectEqualDeep(snapshot, status.state.snapshot.?);
    try t.expect((try catalog.pinState(create.binding.target, source.binding.pin.?.owner, access.policy())).released);
}

test "historical common transaction cut transfers retention through cleanup lost replies and rename" {
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
    _ = try selectedTransaction(&catalog, &access, 9);
    _ = try insertSelectedTable(&catalog, &access, "selected_0", 600);
    const template = try transactionToken(&catalog, 9500, 2, 0);
    const receipt = try catalog.beginTransaction(.{
        .key = template.key,
        .fingerprint = template.fingerprint,
        .operation = template.intent.transaction.identity(),
        .namespace = 1,
        .mode = .read_only,
        .selection = .authorized_catalog_tables,
        .limits = c.DirectTransaction.default_limits,
        .budget = template.budget,
    }, access.policy());
    const acquired = try catalog.acquireTransaction(receipt.binding.key, access.policy());
    const request: @FieldType(c.DirectHistory.Request, "acquire") = .{
        .key = .{ .definition = p.Growth.current_definition, .connection = template.key.connection, .account = @splat(20), .token = @splat(31) },
        .intent = .{ .connection = template.key.connection, .namespace = 1, .operation = 9600, .selection = acquired.catalog.?, .common = .{ .key = template.key, .cut = acquired.commonCut() } },
    };
    var forged = request;
    forged.intent.common.?.cut.acquired.next_lsn += 1;
    const before = catalog.store.root;
    try t.expectError(error.HistoricalIdentityConflict, catalog.acquireHistory(forged, access.policy()));
    try t.expectEqualDeep(before, catalog.store.root);
    // Current changes precede the first copied pin. The original acquired
    // schema, namespace and unflushed row still define the historical binding.
    _ = try insertSelectedTable(&catalog, &access, "selected_0", 601);
    var view = (try resolve(&catalog, &access, "selected_0")).?;
    const rename = try edit(&view, 602, .{ .rename = try a.Name.init("renamed") });
    view.deinit();
    _ = try catalog.admit(rename, access.policy());
    _ = try catalog.perform(rename.binding, access.policy());
    _ = try catalog.settle(rename.binding, access.policy());
    const old_namespace = (try catalog.inspectNamespace(1, access.policy())).?;
    const ns_rename = namespaceChange(old_namespace, 603, .{ .rename = try .init("renamed_namespace") });
    _ = try catalog.namespaceOperation(ns_rename, .admit, access.policy());
    _ = try catalog.namespaceOperation(ns_rename, .execute, access.policy());
    const admitted = try catalog.acquireHistory(request, access.policy());
    try t.expectEqual(@as(?u64, 10), admitted.state.inflight);
    try t.expect(try catalog.store.historyTransferPending(acquired.commonCut().transaction));
    var duplicate = request;
    duplicate.key.token = @splat(32);
    duplicate.intent.operation += 1;
    try t.expectError(error.HistoricalRetentionPending, catalog.acquireHistory(duplicate, access.policy()));
    const original_pin = (try catalog.pinState(.{ .scope = scope, .branch = 1, .object = 10 }, acquired.commonCut().transaction, access.policy())).handle.?;
    try t.expectError(error.HistoricalRetentionPending, catalog.releaseRows(.{ .scope = scope, .branch = 1, .object = 10 }, original_pin, access.policy()));
    const settlement: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9700 };
    const decided = try catalog.settleTransaction(template.key, settlement, .commit, 32, access.policy());
    try t.expect(decided.observation.decided.outcome == .committed);
    try t.expect(!decided.cleanup_complete);
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.advanceHistory(request.key, .advance, access.policy()));
    catalog.lose_table_reply = false;
    catalog.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    catalog = try owner(&wal, &objects);
    try t.expect(try catalog.store.historyTransferPending(acquired.commonCut().transaction));
    try t.expect(!(try catalog.resumeTransaction(template.key, 32, access.policy())).cleanup_complete);
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.advanceHistory(request.key, .advance, access.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    var published: c.DirectHistory.Status = undefined;
    for (0..48) |_| {
        published = try catalog.advanceHistory(request.key, .advance, access.policy());
        if (published.state.phase == .published) break;
    } else return error.FixtureBudget;
    const snapshot = published.state.snapshot.?;
    try t.expectEqualDeep(acquired.commonCut(), snapshot.consistency.common_transaction);
    try t.expect(!try catalog.store.historyTransferPending(acquired.commonCut().transaction));
    const settled = try catalog.resumeTransaction(template.key, 32, access.policy());
    try t.expect(settled.cleanup_complete and settled.observation.decided.outcome == .committed);
    try t.expect((try catalog.pinState(.{ .scope = scope, .branch = 1, .object = 10 }, acquired.commonCut().transaction, access.policy())).released);
    try t.expectEqualDeep(published, try catalog.acquireHistory(request, access.policy()));
    try t.expectEqual(@as(?u64, 10), try catalog.lookupHistory(snapshot, 1, try .init("selected_0"), access.policy()));
    try t.expectEqualDeep(old_namespace, (try catalog.namespaceHistory(snapshot, old_namespace.name, access.policy())).?);
    try t.expectEqual(null, try catalog.namespaceHistory(snapshot, try .init("renamed_namespace"), access.policy()));
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    {
        var selected = try catalog.openHistory(output.allocator(), snapshot, 10, true, access.policy());
        defer selected.deinit();
        var page = try selected.access.view.table.scanSnapshot(t.allocator, selected.binding.pin.?, null, .{}, selected.access.current);
        defer page.deinit();
        try t.expectEqual(@as(u64, 1), page.total_rows);
        try t.expectEqual(@as(i128, 600), page.rows[0].?.row().cells[0].value.atom.signed);
        var frozen = try selected.access.view.table.inspectSnapshot(t.allocator, selected.binding.pin.?, selected.access.current);
        defer frozen.deinit();
        try t.expectEqualDeep(original_pin, frozen.copied_from.?);
    }
    var selector: [c.DirectHistory.Selector.text_bytes]u8 = undefined;
    const encoded = try c.DirectHistory.Selector.encode(snapshot, &selector);
    try t.expectEqualDeep(snapshot, try c.DirectHistory.Selector.decode(encoded));
    selector[450] = if (selector[450] == '0') '1' else '0';
    const wrong = try c.DirectHistory.Selector.decode(&selector);
    try t.expectError(error.HistoricalIdentityConflict, catalog.lookupHistory(wrong, 1, try .init("selected_0"), access.policy()));
    access.denied_privileges = .{ .id = 110, .mask = a.select };
    try t.expectError(error.CatalogDenied, catalog.openHistory(output.allocator(), snapshot, 10, true, access.policy()));
    access.denied_privileges = null;
    _ = try catalog.advanceHistory(request.key, .release, access.policy());
    for (0..16) |_| {
        if ((try catalog.advanceHistory(request.key, .advance, access.policy())).state.phase == .released) break;
    } else return error.FixtureBudget;
    try t.expectError(error.HistoricalSnapshotReleased, catalog.lookupHistory(snapshot, 1, try .init("selected_0"), access.policy()));
}

fn collectHistoricalFixture(catalog: *D, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore, access: *Access, names: []const []const u8) !void {
    var workspace: @import("direct_storage_graph_test.zig").Workspace = .{};
    defer workspace.deinit();
    try workspace.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
    for (names) |name| {
        var view = (try resolve(catalog, access, name)).?;
        defer view.deinit();
        const cut = try view.table.recoveryState();
        try workspace.enqueue(.{ .table_history = try .init(.{ .root = cut.root, .chain = cut.chain }) });
    }
    var at: usize = 0;
    var steps: usize = 0;
    while (at < workspace.jobs.items.len) : (at += 1) {
        var work = workspace.jobs.items[at];
        while (true) {
            const queued = workspace.jobs.items.len;
            const complete = try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &workspace);
            try t.expect(workspace.jobs.items.len - queued <= 3);
            steps += 1;
            if (steps > 100000) return error.FixtureBudget;
            if (complete) break;
        }
    }
    at = 0;
    while (at < objects.objects.items.len) {
        const item = objects.objects.items[at];
        if (c.DirectStorageGraph.collectible(item.key) and !workspace.marks.contains(item.key)) try objects.objectStore().delete(item.key) else at += 1;
    }
}

test "historical common transaction collection and abandonment preserve independent pin ownership" {
    for ([_]bool{ false, true }) |abandon| {
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var catalog = try owner(&wal, &objects);
        defer catalog.deinit();
        var access: Access = .{};
        try catalog.initialize(access.policy());
        _ = try selectedTransaction(&catalog, &access, 2);
        _ = try insertSelectedTable(&catalog, &access, "selected_0", 600);
        const template = try transactionToken(&catalog, 9500, 2, 0);
        _ = try catalog.beginTransaction(.{ .key = template.key, .fingerprint = template.fingerprint, .operation = template.intent.transaction.identity(), .namespace = 1, .mode = .serializable, .selection = .authorized_catalog_tables, .limits = c.DirectTransaction.default_limits, .budget = template.budget }, access.policy());
        const acquired = try catalog.acquireTransaction(template.key, access.policy());
        for ([_]u64{ 10, 11 }, 1..) |object, sequence| {
            const statement = try workspaceRequest(&catalog, &access, template.key, object, sequence, 700 + sequence);
            _ = try catalog.executeTransactionStatement(template.key, statement, access.policy());
        }
        const request: @FieldType(c.DirectHistory.Request, "acquire") = .{
            .key = .{ .definition = p.Growth.current_definition, .connection = template.key.connection, .account = @splat(20), .token = @splat(31) },
            .intent = .{ .connection = template.key.connection, .namespace = 1, .operation = 9600, .selection = acquired.catalog.?, .common = .{ .key = template.key, .cut = acquired.commonCut() } },
        };
        _ = try catalog.acquireHistory(request, access.policy());
        catalog.lose_table_reply = true;
        try t.expectError(error.LostAcknowledgement, catalog.advanceHistory(request.key, .advance, access.policy()));
        catalog.lose_table_reply = false;
        const source_object: p.DataLifecycle.Object = .{ .scope = scope, .branch = 1, .object = 10 };
        const original = (try catalog.pinState(source_object, acquired.commonCut().transaction, access.policy())).handle.?;
        const copied = (try catalog.pinState(source_object, request.intent.identity(), access.policy())).handle.?;
        try collectHistoricalFixture(&catalog, &wal, &objects, &access, &.{ "selected_0", "selected_1" });
        catalog.deinit();
        catalog = try owner(&wal, &objects);
        const settlement: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 9700 };
        const waiting = try catalog.settleTransaction(template.key, settlement, if (abandon) .abort else .commit, 8, access.policy());
        try t.expect((waiting.observation.decided.outcome == .aborted) == abandon and !waiting.cleanup_complete);
        if (abandon) {
            _ = try catalog.advanceHistory(request.key, .abandon, access.policy());
            access.denied_privileges = .{ .id = 110, .mask = a.select };
            try t.expectError(error.CatalogDenied, catalog.advanceHistory(request.key, .advance, access.policy()));
            access.denied_privileges = null;
            catalog.lose_table_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.advanceHistory(request.key, .advance, access.policy()));
            catalog.lose_table_reply = false;
            catalog.deinit();
            catalog = try owner(&wal, &objects);
        }
        var status: c.DirectHistory.Status = undefined;
        for (0..16) |_| {
            status = try catalog.advanceHistory(request.key, .advance, access.policy());
            if (status.state.phase == .published or status.state.phase == .cancelled) break;
        } else return error.FixtureBudget;
        try t.expectEqual(abandon, status.state.phase == .cancelled);
        try t.expect(!try catalog.store.historyTransferPending(acquired.commonCut().transaction));
        try t.expect(!(try catalog.pinState(source_object, original.owner, access.policy())).released);
        try t.expectEqual(abandon, (try catalog.pinState(source_object, copied.owner, access.policy())).released);
        try t.expect((try catalog.resumeTransaction(template.key, 8, access.policy())).cleanup_complete);
        try t.expect((try catalog.pinState(source_object, original.owner, access.policy())).released);
        try collectHistoricalFixture(&catalog, &wal, &objects, &access, &.{ "selected_0", "selected_1" });
        catalog.deinit();
        catalog = try owner(&wal, &objects);
        try t.expectEqualDeep(status, (try catalog.inspectHistory(request.key, access.policy())).?);
        if (!abandon) {
            var output = std.heap.ArenaAllocator.init(t.allocator);
            defer output.deinit();
            var selected = try catalog.openHistory(output.allocator(), status.state.snapshot.?, 10, true, access.policy());
            defer selected.deinit();
            var page = try selected.access.view.table.scanSnapshot(t.allocator, copied, null, .{}, selected.access.current);
            defer page.deinit();
            try t.expectEqual(@as(u64, 1), page.total_rows);
            try t.expectEqual(@as(i128, 600), page.rows[0].?.row().cells[0].value.atom.signed);
        }
    }
}

test "signed schema projection freezes CURRENT without data pins and preserves historical cuts after DROP" {
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
    var last: P.Evidence = undefined;
    for (10..20) |operation| last = try insertSelectedTable(&catalog, &access, "events", operation);
    const pin = try catalog.pinRows(create.binding.target, .{ .scope = scope, .principal = 1, .operation = 100 }, last.outcome.position, access.policy());
    const snapshot: c.DirectTableProtocol.Snapshot = .{ .object = create.binding.target, .handle = pin };
    var original = try catalog.snapshotDefinition(t.allocator, snapshot.object, pin, access.policy());
    defer original.deinit();
    const acquisition = try historyRequest(&catalog, &access, 200, 1, &.{"events"});
    var history = try catalog.acquireHistory(acquisition, access.policy());
    for (0..8) |_| {
        if (history.state.phase == .published) break;
        history = try catalog.advanceHistory(acquisition.key, .advance, access.policy());
    } else return error.FixtureBudget;
    const historical = history.state.snapshot.?;
    var view = (try resolve(&catalog, &access, "events")).?;
    const add = try edit(&view, 201, .{ .alter = .{ .add = .{ .name = "score", .type = .int64, .nullable = false, .default = .{ .value = .{ .atom = .{ .signed = 7 } } } } } });
    view.deinit();
    _ = try catalog.admit(add, access.policy());
    _ = try catalog.perform(add.binding, access.policy());
    _ = try catalog.settle(add.binding, access.policy());
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const source = original.root.declared();
    const before = catalog.store.root;
    const puts = objects.puts;
    access.visible_despite_denied_privileges = true;
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    const prepared = (try SignedDispatch.call(&output, &catalog, &access, .{ .schema_projection = .{ .prepare = .{ .source = source, .target = null } } })).schema_projection.prepared;
    try t.expectEqual(puts, objects.puts);
    try t.expectEqualDeep(before, catalog.store.root);
    const read: c.DirectSchemaProjection.Request = .{ .scan = .{ .source = .{ .snapshot = snapshot }, .target = prepared.target.declaration, .after = null, .limits = .{} } };
    try t.expectError(error.CatalogDenied, SignedDispatch.call(&output, &catalog, &access, .{ .schema_projection = read }));
    access.denied_privileges = null;
    const first = (try SignedDispatch.call(&output, &catalog, &access, .{ .schema_projection = read })).schema_projection.page;
    try t.expectEqualDeep(source, first.source.interpretation);
    try t.expectEqualDeep(prepared.target, first.target);
    try t.expectEqual(@as(usize, 8), first.source.rows.len);
    var target_schema = try c.fuze.TableSchema.decode(t.allocator, try prepared.schema.decode(output.allocator(), c.fuze.TableSchema.max_bytes));
    defer target_schema.deinit();
    var row = try c.fuze.TableRow.decode(t.allocator, target_schema.schema, try first.source.rows[0].decode(output.allocator(), c.fuze.TableRow.max_bytes));
    defer row.deinit();
    try t.expectEqual(@as(i128, 7), row.row().cells[1].value.atom.signed);
    var tail = read;
    tail.scan.after = first.source.next;
    // Later defaults and DROP do not replace the frozen target or old data.
    view = (try resolve(&catalog, &access, "events")).?;
    const change_default = try edit(&view, 202, .{ .alter = .{ .default = .{ .column = 2, .value = .{ .value = .{ .atom = .{ .signed = 9 } } } } } });
    view.deinit();
    _ = try catalog.admit(change_default, access.policy());
    _ = try catalog.perform(change_default.binding, access.policy());
    _ = try catalog.settle(change_default.binding, access.policy());
    view = (try resolve(&catalog, &access, "events")).?;
    const drop = try edit(&view, 203, .drop);
    view.deinit();
    _ = try catalog.admit(drop, access.policy());
    _ = try catalog.perform(drop.binding, access.policy());
    _ = try catalog.settle(drop.binding, access.policy());
    try catalog.recover();
    const final = (try SignedDispatch.call(&output, &catalog, &access, .{ .schema_projection = tail })).schema_projection.page;
    try t.expectEqual(@as(usize, 2), final.source.rows.len);
    try t.expectEqual(null, final.source.next);
    var spliced = tail;
    spliced.scan.target = source;
    try t.expectError(error.InvalidTableSnapshotCursor, SignedDispatch.call(&output, &catalog, &access, .{ .schema_projection = spliced }));
    const retained: c.DirectSchemaProjection.Request = .{ .scan = .{ .source = .{ .historical = .{ .snapshot = historical, .object = 7 } }, .target = prepared.target.declaration, .after = null, .limits = .{} } };
    const historical_first = (try SignedDispatch.call(&output, &catalog, &access, .{ .schema_projection = retained })).schema_projection.page;
    try t.expectEqualDeep(historical, historical_first.catalog.?);
    try t.expectEqualDeep(historical.consistency.single_partition, historical_first.historical_source.?.accepted);
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    try t.expectError(error.CatalogDenied, SignedDispatch.call(&output, &catalog, &access, .{ .schema_projection = tail }));
    access.denied_privileges = null;
    _ = try catalog.advanceHistory(acquisition.key, .release, access.policy());
    try t.expectError(error.HistoricalSnapshotReleased, SignedDispatch.call(&output, &catalog, &access, .{ .schema_projection = retained }));
    // Releasing the historical catalog does not release the independent pin.
    _ = try SignedDispatch.call(&output, &catalog, &access, .{ .schema_projection = tail });
}

test "captured historical copy keeps exact interpretation through lost reply release DDL and recovery" {
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
    _ = try insertSelectedTable(&catalog, &access, "events", 10);
    const request = try historyRequest(&catalog, &access, 100, 1, &.{"events"});
    var status = try catalog.acquireHistory(request, access.policy());
    for (0..12) |_| {
        if (status.state.phase == .published) break;
        status = try catalog.advanceHistory(request.key, .advance, access.policy());
    } else return error.FixtureBudget;
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    var retained = try catalog.openHistory(scratch.allocator(), status.state.snapshot.?, 7, true, access.policy());
    const cut = retained.binding.source;
    const original = retained.binding.pin.?;
    retained.deinit();
    const copy_owner: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 1, .operation = 200 };
    // Acceptance is durable even when its reply disappears.
    catalog.lose_table_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.copyRowsDefined(cut.interpretation, copy_owner, cut.accepted, original, access.policy()));
    catalog.lose_table_reply = false;
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    const copied = try catalog.copyRowsDefined(cut.interpretation, copy_owner, cut.accepted, original, access.policy());
    _ = try catalog.advanceHistory(request.key, .release, access.policy());
    for (0..12) |_| {
        status = try catalog.advanceHistory(request.key, .advance, access.policy());
        if (status.state.phase == .released) break;
    } else return error.FixtureBudget;
    try t.expectEqualDeep(copied, try catalog.copyRowsDefined(cut.interpretation, copy_owner, cut.accepted, original, access.policy()));
    var later = copy_owner;
    later.operation += 1;
    try t.expectError(error.TableSnapshotReleased, catalog.copyRowsDefined(cut.interpretation, later, cut.accepted, original, access.policy()));
    var view = (try resolve(&catalog, &access, "events")).?;
    const drop = try edit(&view, 300, .drop);
    view.deinit();
    _ = try catalog.admit(drop, access.policy());
    _ = try catalog.perform(drop.binding, access.policy());
    _ = try catalog.settle(drop.binding, access.policy());
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    try t.expectEqualDeep(copied, try catalog.copyRowsDefined(cut.interpretation, copy_owner, cut.accepted, original, access.policy()));
    var frozen = try catalog.snapshotDefinition(t.allocator, create.binding.target, copied, access.policy());
    defer frozen.deinit();
    try t.expectEqualDeep(cut.interpretation, frozen.root.interpretation);
    try t.expectEqualDeep(original, frozen.copied_from.?);
    try t.expectEqual(@as(u64, 1), frozen.root.live_rows);
    var wrong = cut.accepted;
    wrong.next_lsn += 1;
    try t.expectError(error.TableDataChanged, catalog.copyRowsDefined(cut.interpretation, copy_owner, wrong, original, access.policy()));
    var substituted = original;
    substituted.content.sha256[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, catalog.copyRowsDefined(cut.interpretation, copy_owner, cut.accepted, substituted, access.policy()));
    access.denied_privileges = .{ .id = 107, .mask = a.select };
    try t.expectError(error.CatalogDenied, catalog.copyRowsDefined(cut.interpretation, copy_owner, cut.accepted, original, access.policy()));
    access.denied_privileges = null;
    try catalog.releaseRows(create.binding.target, copied, access.policy());
    try t.expectError(error.TableSnapshotReleased, catalog.copyRowsDefined(cut.interpretation, copy_owner, cut.accepted, original, access.policy()));
}

fn descriptorView(allocator: std.mem.Allocator, view: *D.View, object: u64, operation: u64, name: []const u8) !c.DirectDefinition.Request {
    const f = c.fuze;
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    const source: c.CatalogDefinition.Source = .{ .properties = view.properties, .declaration = view.table.root.declared(), .schema = try c.DirectTableProtocol.Binary.encode(allocator, try view.table.declaration.schema.schema.encode(&bytes)) };
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const plan: f.LogicalQuery.Plan = .{ .schema = try view.table.declaration.schema.schema.rowType(&fields), .source_basis = source.declaration.interpretation.digest, .projection = &.{0}, .output_names = &.{"original_id"} };
    var plan_bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    const sources = try allocator.alloc(c.CatalogDefinition.Source, 1);
    sources[0] = source;
    const schema: f.TableSchema.Schema = .{ .object = object, .revision = 1, .next_column = 12, .columns = &.{.{ .id = 11, .name = "original_id", .type = .int64, .nullable = false }} };
    const intent: c.DirectDefinition.Intent = .{ .kind = .view, .namespace = 1, .name = try .init(name), .action = .{ .create = .{ .owner = 0, .payload = .{ .schema = try c.DirectTableProtocol.Binary.encode(allocator, try schema.encode(&bytes)), .sources = sources, .body = .{ .view = .{ .plan = try c.DirectTableProtocol.Binary.encode(allocator, try f.LogicalPlanCodec.encode(plan, &plan_bytes)), .source_text = "SELECT id AS original_id FROM events" } } } } } };
    return .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = .{ .scope = scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(allocator) }, .intent = intent };
}
fn descriptorEdit(stored: c.CatalogDefinition.Stored, operation: u64, action: @FieldType(c.DirectDefinition.Intent, "action")) !c.DirectDefinition.Request {
    const intent: c.DirectDefinition.Intent = .{ .kind = stored.kind, .namespace = stored.properties.namespace, .name = stored.properties.name, .action = action };
    return .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = stored.interpretation.object, .action = switch (action) {
        .create => .create,
        .replace => .alter,
        .rename => .rename,
        .drop => .drop,
    }, .expected_definition = stored.interpretation, .expected_data = null, .intent = try intent.digest(t.allocator) }, .intent = intent };
}
test "catalog descriptor atomic publication recovery dependencies and historical identity" {
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
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const request = try descriptorView(arena.allocator(), &view, 77, 100, "selected");
    const before = catalog.store.root;
    const puts = objects.puts;
    try t.expectEqual(.none, (try catalog.previewDefinition(request, access.policy())).reason);
    try t.expectEqualDeep(before, catalog.store.root);
    try t.expectEqual(puts, objects.puts);
    try t.expectEqual(.not_observed, try catalog.definitionOperation(request, .inspect, access.policy()));
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.definitionOperation(request, .accept, access.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    const accepted = (try catalog.definitionOperation(request, .accept, access.policy())).operation;
    try t.expectEqual(.applied, accepted.phase);
    try t.expectEqual(before.next_lsn + 1, accepted.position.next_lsn);
    const original = accepted.resulting.?;
    _ = try insertSelectedTable(&catalog, &access, "events", 110);
    const acquisition = try historyRequest(&catalog, &access, 111, 21, &.{"selected"});
    try t.expectEqual(@as(u64, 1), acquisition.intent.selection.count);
    try t.expectEqual(@as(u64, 1), acquisition.intent.selection.descriptors);
    var history = try catalog.acquireHistory(acquisition, access.policy());
    for (0..20) |_| {
        if (history.state.phase == .published) break;
        history = try catalog.advanceHistory(acquisition.key, .advance, access.policy());
    } else return error.FixtureBudget;
    const retained_catalog = history.state.snapshot.?;
    const historical = (try catalog.historicalDefinition(arena.allocator(), retained_catalog, 1, try .init("selected"), true, access.policy())).?;
    try t.expectEqualDeep(original, historical.binding.declaration);
    try t.expectEqual(@as(u64, 1), retained_catalog.source_count);
    try t.expectEqual(@as(u64, 11), original.next_column - 1);
    var selected = (try catalog.resolveDefinition(t.allocator, 1, try .init("selected"), access.policy())).?;
    selected.deinit();
    const blocked_table = try creation(88, 101, "selected");
    try t.expectEqual(.name_conflict, (try catalog.preview(blocked_table, access.policy())).reason);
    var current_table = (try resolve(&catalog, &access, "events")).?;
    const drop_table = try edit(&current_table, 102, .drop);
    current_table.deinit();
    try t.expectEqual(.dependency, (try catalog.preview(drop_table, access.policy())).reason);
    const rename = try descriptorEdit(original, 103, .{ .rename = try .init("old_view") });
    const renamed = (try catalog.definitionOperation(rename, .accept, access.policy())).operation.resulting.?;
    try t.expect(try catalog.resolveDefinition(t.allocator, 1, try .init("selected"), access.policy()) == null);
    var prior = try catalog.inspectDefinition(t.allocator, original.interpretation, access.policy());
    defer prior.deinit();
    try t.expectEqualStrings("selected", prior.value.properties.name.slice());
    try t.expectEqual(@as(u64, 1), prior.value.revision);
    const stale = try descriptorEdit(original, 104, .drop);
    try t.expectEqual(.stale_definition, (try catalog.definitionOperation(stale, .accept, access.policy())).operation.reason);
    const drop = try descriptorEdit(renamed, 105, .drop);
    try t.expectEqual(.applied, (try catalog.definitionOperation(drop, .accept, access.policy())).operation.phase);
    try t.expectEqual(.none, (try catalog.preview(drop_table, access.policy())).reason);
    _ = try catalog.admit(drop_table, access.policy());
    _ = try catalog.perform(drop_table.binding, access.policy());
    _ = try catalog.settle(drop_table.binding, access.policy());
    try catalog.recover();
    var old = try catalog.inspectDefinition(t.allocator, original.interpretation, access.policy());
    defer old.deinit();
    try t.expectEqualDeep(create.binding.target, old.value.sources[0].declaration.interpretation.object);
    const selected_old = (try catalog.historicalDefinition(arena.allocator(), retained_catalog, 1, try .init("selected"), true, access.policy())).?;
    try t.expectEqualDeep(original, selected_old.binding.declaration);
    try t.expect(try catalog.historicalDefinition(arena.allocator(), retained_catalog, 1, try .init("old_view"), true, access.policy()) == null);
    access.denied_privileges = .{ .id = original.properties.authorization, .mask = a.select };
    access.visible_despite_denied_privileges = true;
    _ = try catalog.historicalDefinition(arena.allocator(), retained_catalog, 1, try .init("selected"), false, access.policy());
    try t.expectError(error.CatalogDenied, catalog.historicalDefinition(arena.allocator(), retained_catalog, 1, try .init("selected"), true, access.policy()));
    access.denied_privileges = null;
    access.denied_metadata = original.properties.authorization;
    try t.expectError(error.CatalogDenied, catalog.inspectDefinition(t.allocator, original.interpretation, access.policy()));
    access.denied_metadata = null;
    _ = try catalog.advanceHistory(acquisition.key, .release, access.policy());
    for (0..20) |_| {
        history = try catalog.advanceHistory(acquisition.key, .advance, access.policy());
        if (history.state.phase == .released) break;
    } else return error.FixtureBudget;
    try t.expectError(error.HistoricalSnapshotReleased, catalog.historicalDefinition(arena.allocator(), retained_catalog, 1, try .init("selected"), true, access.policy()));
    var substituted = original.interpretation;
    substituted.digest[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, catalog.inspectDefinition(t.allocator, substituted, access.policy()));
}

test "catalog descriptor historical graph replacement preserves mappings and transfers dependency protection" {
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
    for ([_]D.Request{ try creation(7, 1, "first"), try creation(8, 2, "second") }) |create| {
        _ = try catalog.admit(create, access.policy());
        _ = try catalog.perform(create.binding, access.policy());
        _ = try catalog.settle(create.binding, access.policy());
    }
    var first = (try resolve(&catalog, &access, "first")).?;
    defer first.deinit();
    var second = (try resolve(&catalog, &access, "second")).?;
    defer second.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var request = try descriptorView(allocator, &first, 77, 100, "network");
    request.intent.kind = .property_graph;
    request.intent.action.create.payload.body = .{ .property_graph = .{
        .next_mapping = 3,
        .vertices = &.{.{ .id = 1, .label = try .init("Person"), .key = .{ .source = 0, .column = 1 }, .properties = &.{.{ .id = 11, .name = try .init("original_id"), .value = .{ .source = 0, .column = 1 } }} }},
        .edges = &.{.{ .id = 2, .label = try .init("Knows"), .key = .{ .source = 0, .column = 1 }, .source_vertex = 1, .source_key = .{ .source = 0, .column = 1 }, .target_vertex = 1, .target_key = .{ .source = 0, .column = 1 }, .properties = &.{} }},
    } };
    request.binding.intent = try request.intent.digest(allocator);
    const original = (try catalog.definitionOperation(request, .accept, access.policy())).operation.resulting.?;
    const acquisition = try historyRequest(&catalog, &access, 101, 21, &.{"network"});
    var history = try catalog.acquireHistory(acquisition, access.policy());
    for (0..20) |_| {
        if (history.state.phase == .published) break;
        history = try catalog.advanceHistory(acquisition.key, .advance, access.policy());
    } else return error.FixtureBudget;
    const snapshot = history.state.snapshot.?;
    const next_source = try descriptorView(allocator, &second, 77, 102, "network");
    var replacement = request.intent.action.create.payload;
    replacement.sources = next_source.intent.action.create.payload.sources;
    var schema = try c.CatalogDefinition.decodeSchema(allocator, replacement.schema);
    defer schema.deinit();
    schema.schema.revision = 2;
    var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    replacement.schema = try c.DirectTableProtocol.Binary.encode(allocator, try schema.schema.encode(&bytes));
    var vertex = replacement.body.property_graph.vertices[0];
    vertex.label = try .init("Member");
    replacement.body.property_graph.vertices = &.{vertex};
    const replace = try descriptorEdit(original, 102, .{ .replace = replacement });
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.definitionOperation(replace, .accept, access.policy()));
    catalog.store.lose_reply = false;
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    const updated = (try catalog.definitionOperation(replace, .accept, access.policy())).operation.resulting.?;
    try t.expectEqual(@as(u64, 2), updated.interpretation.revision);
    const drop_first = try edit(&first, 103, .drop);
    const drop_second = try edit(&second, 104, .drop);
    try t.expectEqual(.none, (try catalog.preview(drop_first, access.policy())).reason);
    try t.expectEqual(.dependency, (try catalog.preview(drop_second, access.policy())).reason);
    const old = (try catalog.historicalDefinition(allocator, snapshot, 1, try .init("network"), false, access.policy())).?;
    try t.expectEqualStrings("Person", old.value.body.property_graph.vertices[0].label.slice());
    try t.expectEqual(@as(u64, 7), old.value.sources[0].declaration.interpretation.object.object);
    try t.expectEqual(@as(u64, 1), old.value.body.property_graph.edges[0].target_vertex);
    var current = (try catalog.resolveDefinition(t.allocator, 1, try .init("network"), access.policy())).?;
    defer current.deinit();
    try t.expectEqualStrings("Member", current.value.body.property_graph.vertices[0].label.slice());
    try t.expectEqual(@as(u64, 8), current.value.sources[0].declaration.interpretation.object.object);
    const page = try catalog.historicalDefinitions(snapshot, 1, null, access.policy());
    try t.expectEqualDeep(original, page.entries[0].?.declaration);
    try t.expect(page.next == null);
    // Removing a mapping does not make its ID available to a later definition.
    replacement.body.property_graph.edges = &.{};
    schema.schema.revision = 3;
    replacement.schema = try c.DirectTableProtocol.Binary.encode(allocator, try schema.schema.encode(&bytes));
    const removed = (try catalog.definitionOperation(try descriptorEdit(updated, 105, .{ .replace = replacement }), .accept, access.policy())).operation.resulting.?;
    schema.schema.revision = 4;
    replacement.schema = try c.DirectTableProtocol.Binary.encode(allocator, try schema.schema.encode(&bytes));
    replacement.body.property_graph.edges = request.intent.action.create.payload.body.property_graph.edges;
    try t.expectError(error.InvalidCatalogDescriptor, catalog.definitionOperation(try descriptorEdit(removed, 106, .{ .replace = replacement }), .accept, access.policy()));
}

test "historical metadata-only foreign catalog retains decoder and captured bytes without inventing a Table source" {
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
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const input = try catalog.stageDefinitionInput(1, &.{ 0x12, 0x3d }, access.policy());
    const f = c.fuze;
    const schema: f.TableSchema.Schema = .{ .object = 81, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "amount", .type = .int64, .nullable = false }} };
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    const intent: c.DirectDefinition.Intent = .{ .kind = .foreign, .namespace = 1, .name = try .init("mainframe"), .action = .{ .create = .{ .owner = 0, .payload = .{ .schema = try c.DirectTableProtocol.Binary.encode(allocator, try schema.encode(&bytes)), .sources = &.{}, .body = .{ .foreign = .{ .record_bytes = 2, .fields = &.{.{ .column = 1, .offset = 0, .bytes = 2, .encoding = .comp_3 }}, .malformed = .type_error, .input = .{ .content = input, .availability = .retained, .provenance = "file:///mutable/input" } } } } } } };
    const request: c.DirectDefinition.Request = .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 100 }, .target = .{ .scope = scope, .branch = 1, .object = 81 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(allocator) }, .intent = intent };
    const original = (try catalog.definitionOperation(request, .accept, access.policy())).operation.resulting.?;
    const acquisition = try historyRequest(&catalog, &access, 111, 21, &.{"mainframe"});
    try t.expectEqual(@as(u64, 0), acquisition.intent.selection.count);
    try t.expectEqual(@as(u64, 1), acquisition.intent.selection.descriptors);
    var history = try catalog.acquireHistory(acquisition, access.policy());
    for (0..20) |_| {
        if (history.state.phase == .published) break;
        history = try catalog.advanceHistory(acquisition.key, .advance, access.policy());
    } else return error.FixtureBudget;
    const snapshot = history.state.snapshot.?;
    try t.expectEqual(@as(u64, 0), snapshot.source_count);
    try t.expectEqual(.independent, snapshot.consistency);
    var selector: [c.DirectHistory.Selector.text_bytes]u8 = undefined;
    try t.expectEqualDeep(snapshot, try c.DirectHistory.Selector.decode(try c.DirectHistory.Selector.encode(snapshot, &selector)));
    _ = try c.DirectCatalogHistory.Snapshot.foreign(allocator, snapshot);
    // Replacement names a different byte interpretation, while the selected
    // catalog still owns the first decoder and its exact captured content.
    var replacement = intent.action.create.payload;
    var updated = schema;
    updated.revision = 2;
    replacement.schema = try c.DirectTableProtocol.Binary.encode(allocator, try updated.encode(&bytes));
    replacement.body.foreign.fields = &.{.{ .column = 1, .offset = 0, .bytes = 2, .encoding = .comp }};
    const replace = try descriptorEdit(original, 112, .{ .replace = replacement });
    _ = try catalog.definitionOperation(replace, .accept, access.policy());
    const orphan = try catalog.stageDefinitionInput(1, &.{ 0x99, 0x9c }, access.policy());
    var workspace: @import("direct_storage_graph_test.zig").Workspace = .{};
    defer workspace.deinit();
    // Accepted revisions are reachable from the revision directory itself,
    // independent of the additional retained control-WAL recovery obligations.
    try workspace.enqueue(.{ .catalog_root = .{ .root = catalog.store.root } });
    var at: usize = 0;
    var steps: usize = 0;
    while (at < workspace.jobs.items.len) : (at += 1) {
        var work = workspace.jobs.items[at];
        while (true) {
            const jobs = workspace.jobs.items.len;
            const done = try c.DirectStorageGraph.step(t.allocator, &catalog.store.index, wal.log(), &work, &workspace);
            try t.expect(workspace.jobs.items.len - jobs <= 3);
            steps += 1;
            if (steps > 100000) return error.FixtureBudget;
            if (done) break;
        }
    }
    var key: [96]u8 = undefined;
    try t.expect(workspace.marks.contains(try c.CatalogDefinition.key(original.content, &key)));
    try t.expect(workspace.marks.contains(try c.CatalogDefinition.inputKey(input, &key)));
    try t.expect(!workspace.marks.contains(try c.CatalogDefinition.inputKey(orphan, &key)));
    try objects.objectStore().delete(try c.CatalogDefinition.inputKey(orphan, &key));
    catalog.deinit();
    catalog = try owner(&wal, &objects);
    const old = (try catalog.historicalDefinition(allocator, snapshot, 1, try .init("mainframe"), false, access.policy())).?;
    try t.expectEqualDeep(original, old.binding.declaration);
    try t.expectEqual(.comp_3, old.value.body.foreign.fields[0].encoding);
    const captured = try c.CatalogDefinition.loadInput(allocator, objects.objectStore(), old.value.body.foreign.input);
    var utf8: [16]u8 = undefined;
    try t.expectEqual(@as(i128, -123), (try c.CatalogDefinition.decodeField(schema.columns[0], old.value.body.foreign.fields[0], .reject, captured, &utf8)).value.atom.signed);
    _ = try catalog.advanceHistory(acquisition.key, .release, access.policy());
    for (0..20) |_| {
        history = try catalog.advanceHistory(acquisition.key, .advance, access.policy());
        if (history.state.phase == .released) break;
    } else return error.FixtureBudget;
    try t.expectError(error.HistoricalSnapshotReleased, catalog.historicalDefinition(allocator, snapshot, 1, try .init("mainframe"), false, access.policy()));
}
