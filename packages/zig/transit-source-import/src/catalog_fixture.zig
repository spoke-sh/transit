// Component fixture using real Catalog and Stream owners under explicit test policy.
const std = @import("std");
const t = std.testing;
const runtime = @import("fixture_runtime.zig");
const c = @import("root.zig").data.catalog;
const p = c.protocol;
const s = c.storage;
const a = c.TableAuthority;
const D = c.DirectCatalog;
const P = s.TablePartition;
pub const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
const profile: a.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .stream_domain = 31, .queue_domain = 32, .kv_domain = 33, .connection_domain = 34, .source_domain = 35, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };
pub const Access = struct {
    principal: u64 = 1,
    calls: usize = 0,
    deny_at: usize = std.math.maxInt(usize),
    mismatch: bool = false,
    missing_table: bool = false,
    missing_schema: bool = false,
    denied_resource: ?u64 = null,
    denied_metadata: ?u64 = null,
    denied_metadata_error: anyerror = error.CatalogDenied,
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
    pub fn make(context: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !P.Guard {
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
            if (value.access.denied_metadata) |id| if (std.meta.eql(requirement.object, a.reference(id))) return value.access.denied_metadata_error;
            if (value.access.denied_privileges) |denied| if (std.meta.eql(requirement.object, a.reference(denied.id)) and requirement.privileges & denied.mask != 0 and !(value.access.visible_despite_denied_privileges and requirement.access == .visible)) return error.CatalogDenied;
        };
        if (value.requested.subject.principal() != value.access.principal or value.requested.requirements[0].?.object.id != profile.database) return error.CatalogDenied;
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
            .table, .stream, .queue, .kv, .connection, .source => 100 + id,
        };
        return .{ .reference = a.reference(native), .owner = 0, .registrar = 1, .actions = a.actions(kind), .domain = profile.domain(kind), .binding = if (erased(context).mismatch) @splat(9) else try a.binding(scope, kind, id), .parent = switch (kind) {
            .database => null,
            .schema => a.reference(profile.database),
            .table, .stream, .queue, .kv, .connection, .source => a.reference(profile.initial_schema_authority),
        }, .revision = 1 };
    }
    pub fn policy(self: *Access) D.Policy {
        return .{ .context = self, .subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = self.principal } }, .make_guard = make, .registered = registered, .native_resource = .{ .context = self, .prepare = prepareAllocation, .allocation = allocation, .make_guard = nativeGuard } };
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
pub fn owner(wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !D {
    return ownerWith(runtime.allocator(), wal, objects);
}
pub fn ownerWith(allocator: std.mem.Allocator, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !D {
    var result = try D.init(allocator, try configuration(), wal.log(), objects.objectStore(), wal.log(), objects.objectStore(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
    errdefer result.deinit();
    try result.recover();
    return result;
}
const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
fn logCreation(kind: c.DirectLog.Kind, object: u64, operation: u64, name: []const u8, partitions: u32) !c.DirectLog.Request {
    const intent: c.DirectLog.Intent = .{ .kind = kind, .namespace = 1, .name = try .init(name), .action = .{ .create = .{
        .owner = 0,
        .schema = .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{} },
        .configuration = .{ .partitioning = .{ .count = partitions, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = if (kind == .stream) .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } else .{ .queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 100, .maximum_lease_ms = 1000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    return .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = .{ .scope = scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(runtime.allocator()) } };
}
fn connectorCreation(object: u64, operation: u64, name: []const u8, payload: c.SourceDeclaration.Payload) !c.DirectSource.Request {
    const intent: c.DirectSource.Intent = .{ .kind = std.meta.activeTag(payload), .namespace = 1, .name = try .init(name), .action = .{ .create = .{ .owner = 0, .payload = payload } } };
    return .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = operation }, .target = .{ .scope = scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(runtime.allocator()) }, .intent = intent };
}
fn connectorExecute(catalog: *D, access: *Access, request: c.DirectSource.Request) !c.DirectSource.Operation {
    var observed = (try catalog.sourceOperation(request, .reserve, access.policy())).operation;
    for (0..4) |_| {
        if (!observed.pending()) return observed;
        _ = try catalog.sourceRegistration(request, access.policy());
        observed = (try catalog.sourceOperation(request, .execute, access.policy())).operation;
    }
    return error.TestUnexpectedResult;
}
pub fn captureSetup(catalog: *D, access: *Access) !p.Source.Definition {
    return captureSetupRetention(catalog, access, null);
}
fn captureSetupRetention(catalog: *D, access: *Access, max_age_ms: ?u64) !p.Source.Definition {
    var ddl = try c.fuze.LogDdl.compile(runtime.allocator(), "CREATE STREAM captures (capture_id UUID NOT NULL, source_sequence UINT64 NOT NULL, observed_at TIMESTAMPTZ NOT NULL, http_status INTEGER NOT NULL, body_ref BINARY NOT NULL, body_bytes UINT64 NOT NULL, body_sha256 BINARY NOT NULL)", .transit, null);
    defer ddl.deinit();
    var request = try logCreation(.stream, 50, 50, "captures", 1);
    request.intent.action.create.schema = try ddl.statement.action.create.bind(50);
    request.intent.action.create.configuration.retention.max_age_ms = max_age_ms;
    request.binding.intent = try request.intent.digest(runtime.allocator());
    _ = try catalog.admitLog(request, access.policy());
    const log = (try catalog.logOperation(request.binding, .execute, access.policy())).operation.resulting.?;
    const connection = (try connectorExecute(catalog, access, try connectorCreation(77, 100, "upstream", .{ .connection = .{ .endpoint = "http://127.0.0.1:1" } }))).resulting.?;
    const source = try connectorCreation(78, 101, "source", .{ .source = .{ .connection = connection.declaration.interpretation, .destination = log.stored.declaration.interpretation, .executor = 99, .http = .{ .method = .GET, .path = "/feed", .poll_interval_ms = 1000, .request_timeout_ms = 500, .response_max_bytes = 4 * 1024 * 1024 }, .columns = .{ 1, 2, 3, 4, 5, 6, 7 } } });
    const accepted = (try connectorExecute(catalog, access, source)).resulting.?;
    return source.intent.action.create.payload.source.definition(accepted.declaration.interpretation);
}
