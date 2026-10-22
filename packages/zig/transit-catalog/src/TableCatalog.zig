//! General Table namespace over an already authorized resource owner. Native
//! authority still owns grants, captured cuts, input acceptance and fencing.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const r = c.Records;
const m = c.TableCatalogRecords;
const Meta = c.TableMetadata;
const Store = c.TableMetadataStore;
const s = c.station;
const Self = @This();
configuration: m.Configuration,
namespace: ?u64 = null,
registration: ?*?p.Authorization.Action = null,
pub const Definition = struct {
    metadata: Meta.Record,
    authority: c.TableAuthority.Table,
    namespace: c.TableAuthority.Schema,
    head: s.TableHead,
    schema: c.fuze.TableSchema.Owned,
    pub fn deinit(self: *Definition) void {
        self.schema.deinit();
        self.* = undefined;
    }
};
pub const Entry = struct { metadata: Meta.Record, head: s.TableHead };
/// An accepted immutable definition, with no claim about today's Table head.
pub const HistoricalDefinition = struct {
    metadata: Meta.Record,
    schema: c.fuze.TableSchema.Owned,
    pub fn deinit(self: *HistoricalDefinition) void {
        self.schema.deinit();
        self.* = undefined;
    }
};
pub const Cursor = struct { scope: m.Scope, resource_revision: u64, after_object: u64 };
pub const Page = struct {
    entries: [p.Growth.page_size]?Entry = @splat(null),
    next: ?Cursor = null,
    resource_revision: u64,
};
pub fn key(self: Self, tag: u8, id: u64, revision: u64) p.Value {
    return r.key(self.configuration.scope.catalog, tag, id, revision);
}
fn scope(self: Self, actual: m.Scope) !void {
    if (!std.meta.eql(actual, self.configuration.scope)) return error.CatalogScopeChanged;
}
fn owner(self: Self, turn: *s.Turn) !void {
    try self.configuration.validate();
    if (turn.delivery.realm != self.configuration.scope.realm or turn.delivery.pid != self.configuration.owner or turn.view.resource != self.configuration.scope.resource) return error.CatalogOwnerChanged;
}
fn principal(turn: *s.Turn) !u64 {
    return switch (turn.delivery.input.origin) {
        .external => |origin| origin.principal,
        else => error.CatalogDenied,
    };
}
fn administrator(self: Self, turn: *s.Turn) !void {
    try self.owner(turn);
    const who = try principal(turn);
    _ = try self.require(turn, who, null, null, .create_schema);
}
fn namespaceId(self: Self) u64 {
    return self.namespace orelse self.configuration.authority.initial_schema;
}
pub fn namespaceRecord(self: Self, source: anytype, id: u64) !c.TableAuthority.Schema {
    const Source = @typeInfo(@TypeOf(source)).pointer.child;
    if (comptime @hasDecl(Source, "prefetch")) try source.prefetch(&.{self.key('S', id, 0)});
    const value = try r.decode(c.TableAuthority.Schema, 'S', (try source.read(self.key('S', id, 0))) orelse return error.CatalogSchemaMissing);
    try self.scope(value.scope);
    if (value.id != id or value.retired) return error.CatalogSchemaMissing;
    return value;
}
fn require(self: Self, source: anytype, who: u64, namespace: ?c.TableAuthority.Schema, table: ?c.TableAuthority.Table, access: c.TableAuthority.Access) !p.Authorization.Verified {
    return c.TableAuthority.require(source, try c.TableAuthority.guard(try c.TableAuthority.subjectFor(source, who), self.configuration.authority, namespace, table, access));
}
/// Namespace access never implies rights on every Table stored below it.
pub fn authorize(self: Self, source: anytype, who: u64, right: m.Right) !p.Authorization.Verified {
    try self.check(source);
    const access: c.TableAuthority.Access = switch (right) {
        .inspect => .schema,
        .create => .create_table,
        else => return error.InvalidCatalogIdentity,
    };
    return self.require(source, who, try self.namespaceRecord(source, self.namespaceId()), null, access);
}
pub fn authorizeDatabase(self: Self, source: anytype, who: u64) !p.Authorization.Verified {
    try self.check(source);
    return self.require(source, who, null, null, .database);
}
pub fn authorizeObject(self: Self, source: anytype, who: u64, id: u64, right: m.Right) !p.Authorization.Verified {
    if (right == .create) return self.authorize(source, who, .create);
    _ = try self.authorizeDatabase(source, who);
    if (id == 0) return self.authorize(source, who, .inspect);
    const value = (try self.object(source, id)) orelse return error.TableNotFound;
    const access: c.TableAuthority.Access = switch (right) {
        .inspect => .inspect,
        .read => .read,
        .insert => .insert,
        .update => .update,
        .delete => .delete,
        .alter => .alter,
        .drop => .drop,
        .create => unreachable,
    };
    return self.require(source, who, try self.namespaceRecord(source, value.namespace), .{ .id = id, .schema = value.namespace, .authorization = value.authorization }, access);
}
pub fn authorizeCreationInspection(self: Self, source: anytype, who: u64, id: u64) !p.Authorization.Verified {
    _ = try self.authorizeDatabase(source, who);
    const value = try self.object(source, id);
    if (value == null or value.?.authorization == 0) return self.authorize(source, who, .create);
    return self.authorizeObject(source, who, id, .inspect);
}
fn canRead(self: Self, source: anytype, who: u64, id: u64) !bool {
    _ = self.authorizeObject(source, who, id, .read) catch |err| return if (err == error.CatalogDenied) false else err;
    return true;
}
fn check(self: Self, source: anytype) !void {
    try self.configuration.validate();
    if (source.view.resource != self.configuration.scope.resource) return error.CrossResourceTransaction;
    const Source = @typeInfo(@TypeOf(source)).pointer.child;
    if (comptime @hasDecl(Source, "prefetch")) try source.prefetch(&.{self.key('c', 0, 0)});
    const config = try r.decode(m.Configuration, 'C', (try source.read(self.key('c', 0, 0))) orelse return error.CatalogNotInitialized);
    if (!std.meta.eql(config, self.configuration)) return error.CatalogConfigurationChanged;
}
pub fn initialize(self: Self, turn: *s.Turn) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.owner(turn);
    const prefix = r.prefix(self.configuration.scope.catalog, 0);
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        if (std.mem.startsWith(u8, mutation.key.slice(), prefix.data[0..10])) return error.QueryAfterMutation;
    };
    if (try turn.read(self.key('c', 0, 0)) != null) {
        try self.check(turn);
        _ = try self.authorizeDatabase(turn, try principal(turn));
        return;
    }
    if (try principal(turn) != self.configuration.administrator) return error.CatalogDenied;
    try self.administrator(turn);
    var committed = turn.committed();
    const page = try committed.page(prefix);
    try c.Inspection.validatePage(page, prefix, turn.view.revision);
    if (page.entries[0]) |entry| if (std.mem.startsWith(u8, entry.key.slice(), prefix.data[0..10])) return error.CatalogAlreadyPopulated;
    try turn.write(self.key('c', 0, 0), try r.encode('C', self.configuration));
    const profile = self.configuration.authority;
    const database = (try turn.authorizationBinding(profile.database_domain, try c.TableAuthority.binding(self.configuration.scope, .database, 0))) orelse return error.CatalogRegistrationRequired;
    try c.TableAuthority.validateObject(profile, self.configuration.scope, .database, 0, null, database);
    if (database.reference.id != profile.database) return error.InvalidCatalogConfiguration;
    const initial = (try turn.authorizationBinding(profile.schema_domain, try c.TableAuthority.binding(self.configuration.scope, .schema, profile.initial_schema))) orelse return error.CatalogRegistrationRequired;
    try c.TableAuthority.validateObject(profile, self.configuration.scope, .schema, profile.initial_schema, c.TableAuthority.reference(profile.database), initial);
    if (initial.reference.id != profile.initial_schema_authority) return error.InvalidCatalogConfiguration;
    const namespace: c.TableAuthority.Schema = .{ .scope = self.configuration.scope, .id = profile.initial_schema, .authorization = profile.initial_schema_authority, .name = try .init("public"), .revision = 1 };
    try turn.write(self.key('S', namespace.id, 0), try r.encode('S', namespace));
}
pub fn object(self: Self, source: anytype, id: u64) !?m.Object {
    const Source = @typeInfo(@TypeOf(source)).pointer.child;
    if (comptime @hasDecl(Source, "prefetch")) try source.prefetch(&.{self.key('O', id, 0)});
    if (id == 0) return error.InvalidCatalogIdentity;
    const value = try r.decode(m.Object, 'O', (try source.read(self.key('O', id, 0))) orelse return null);
    try self.scope(value.scope);
    if (value.object != id) return error.InvalidCatalogObject;
    return value;
}
fn metadata(self: Self, source: anytype, value: m.Object) !Meta.Record {
    try self.scope(value.scope);
    if (value.state == .initializing) return error.CatalogDefinitionMissing;
    return (Store{ .scope = value.scope, .object = value.object }).read(source, value.metadata);
}
pub const Bound = struct { object: m.Object, metadata: Meta.Record };
pub fn binding(self: Self, source: anytype, name: Meta.Name) !?Bound {
    try name.validate();
    const digest = try name.digestIn(self.namespaceId());
    const full = try Meta.nameKey(self.configuration.scope.catalog, digest, 1);
    const prefix = try p.Value.init(full.data[0..24]);
    var cursor = prefix;
    var found: ?Bound = null;
    while (true) {
        const page = try source.page(cursor);
        try c.Inspection.validatePage(page, cursor, source.view.revision);
        for (page.entries) |slot| {
            const entry = slot orelse break;
            if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return found;
            if (entry.key.len != 32) return error.InvalidCatalogBinding;
            const id = std.mem.readInt(u64, entry.key.data[24..32], .big);
            const link = try r.decode(m.Binding, 'N', entry.value);
            try self.scope(link.scope);
            if (link.object != id) return error.InvalidCatalogBinding;
            const current = (try self.object(source, id)) orelse return error.CatalogDefinitionMissing;
            if (current.state != .live) return error.CatalogDefinitionChanged;
            const record = try self.metadata(source, current);
            const actual_digest = try record.name.digestIn(record.namespace);
            if (!std.mem.eql(u8, actual_digest[0..Meta.name_digest_bytes], digest[0..Meta.name_digest_bytes])) return error.CatalogDefinitionChanged;
            if (record.namespace == self.namespaceId() and record.name.eql(&name)) {
                if (found != null) return error.InvalidCatalogBinding;
                found = .{ .object = current, .metadata = record };
            }
        }
        cursor = page.next orelse return found;
    }
}
fn resolveHead(self: Self, source: anytype, value: m.Object, record: Meta.Record) !s.TableHead {
    try self.scope(value.scope);
    if (value.state != .live or value.object != record.object or value.metadata.id != record.revision) return error.CatalogDefinitionChanged;
    const head = try s.TableHead.load(source, record.object);
    if (head.retired or !std.meta.eql(head.schema, record.schema)) return error.CatalogSourceChanged;
    return head;
}
fn resolve(self: Self, allocator: std.mem.Allocator, source: anytype, value: m.Object, record: Meta.Record) !Definition {
    const head = try self.resolveHead(source, value, record);
    var schema = try head.readSchema(allocator, source);
    errdefer schema.deinit();
    if (!std.mem.eql(u8, &try schema.schema.fingerprint(), &record.schema_fingerprint)) return error.CatalogDefinitionChanged;
    return .{ .metadata = record, .authority = .{ .id = value.object, .schema = value.namespace, .authorization = value.authorization }, .namespace = try self.namespaceRecord(source, value.namespace), .head = head, .schema = schema };
}
pub fn lookup(self: Self, allocator: std.mem.Allocator, source: anytype, who: u64, name: Meta.Name) !?Definition {
    _ = try self.authorize(source, who, .inspect);
    const current = (try self.binding(source, name)) orelse return null;
    _ = self.authorizeObject(source, who, current.object.object, .inspect) catch |err| return if (err == error.CatalogDenied) null else err;
    return try self.resolve(allocator, source, current.object, current.metadata);
}
/// Object-ordered pages are bound to one native revision. Tombstoned and pending
/// creation records advance the cursor without being returned as live Tables.
/// Listing validates metadata/head identity without fetching schema or row pages.
/// Entries are bounded inline values; lookup separately owns a complete schema.
pub fn list(self: Self, source: anytype, who: u64, cursor: ?Cursor) !Page {
    _ = try self.authorize(source, who, .inspect);
    if (cursor) |prior| {
        try self.scope(prior.scope);
        if (prior.resource_revision != source.view.revision or prior.after_object == 0) return error.CatalogCursorChanged;
    }
    const prefix = r.prefix(self.configuration.scope.catalog, 'O');
    const after = if (cursor) |prior| self.key('O', prior.after_object, 0) else prefix;
    const page = try source.page(after);
    try c.Inspection.validatePage(page, after, source.view.revision);
    var result: Page = .{ .resource_revision = source.view.revision };
    var count: usize = 0;
    var last: u64 = 0;
    for (page.entries) |slot| {
        const entry = slot orelse break;
        if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return result;
        if (entry.key.len != 27 or std.mem.readInt(u64, entry.key.data[19..27], .big) != 0) return error.InvalidCatalogObject;
        const id = std.mem.readInt(u64, entry.key.data[11..19], .big);
        const current = try r.decode(m.Object, 'O', entry.value);
        try self.scope(current.scope);
        if (current.object != id or id == 0) return error.InvalidCatalogObject;
        last = id;
        if (current.state == .live and current.namespace == self.namespaceId()) {
            _ = self.authorizeObject(source, who, id, .inspect) catch |err| {
                if (err == error.CatalogDenied) continue;
                return err;
            };
            const record = try self.metadata(source, current);
            result.entries[count] = .{ .metadata = record, .head = try self.resolveHead(source, current, record) };
            count += 1;
        }
    }
    if (page.next != null and last != 0) result.next = .{ .scope = self.configuration.scope, .resource_revision = source.view.revision, .after_object = last };
    return result;
}
pub fn setDependency(self: Self, turn: *s.Turn, dependency: m.Dependency, present: bool) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.administrator(turn);
    try self.check(turn);
    try dependency.validate();
    try self.scope(dependency.scope);
    const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
    if (try self.object(turn, dependency.object)) |current| {
        if (present and (current.state != .live or current.pending_operation != 0)) return error.TableBusy;
    } else if (try decl.record(turn, dependency.object)) |current_decl| {
        if (present and (current_decl.state != .live or current_decl.pending_operation != 0)) return error.TableBusy;
    } else return error.TableNotFound;
    const location = self.key('B', dependency.object, dependency.identity);
    const index_key = self.key('J', dependency.object, dependency.identity);
    const reverse_key = self.key('b', dependency.identity, dependency.object);
    const bytes = try r.encode('B', dependency);
    const indexed = try turn.read(index_key);
    if (try turn.read(location)) |existing| {
        _ = try r.decode(m.Dependency, 'B', existing);
        if (!existing.eql(bytes)) return error.CatalogDependencyConflict;
        if (dependency.restricts()) {
            if (indexed == null or !indexed.?.eql(bytes)) return error.InvalidCatalogDependency;
            if (!present) try turn.write(index_key, null);
        } else if (indexed != null) return error.InvalidCatalogDependency;
        if (!present) {
            try turn.write(location, null);
            try turn.write(reverse_key, null);
        }
    } else {
        if (indexed != null) return error.InvalidCatalogDependency;
        if (present) {
            try turn.write(location, bytes);
            if (dependency.restricts()) try turn.write(index_key, bytes);
            try turn.write(reverse_key, bytes);
        }
    }
}
pub fn restrict(self: Self, source: anytype, id: u64) !?m.Dependency {
    const full = self.key('J', id, 0);
    const prefix = try p.Value.init(full.data[0..19]);
    const page = try source.page(prefix);
    try c.Inspection.validatePage(page, prefix, source.view.revision);
    const entry = page.entries[0] orelse return null;
    if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return null;
    if (entry.key.len != 27) return error.InvalidCatalogDependency;
    const dependency = try r.decode(m.Dependency, 'B', entry.value);
    try self.scope(dependency.scope);
    if (!dependency.restricts() or dependency.object != id or dependency.identity != std.mem.readInt(u64, entry.key.data[19..27], .big)) return error.InvalidCatalogDependency;
    const original = (try source.read(self.key('B', id, dependency.identity))) orelse return error.InvalidCatalogDependency;
    if (!original.eql(entry.value)) return error.InvalidCatalogDependency;
    return dependency;
}
pub fn blockingDependency(self: Self, source: anytype, who: u64, id: u64) !?m.Dependency {
    const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
    if (try self.object(source, id) != null) {
        _ = try self.authorizeObject(source, who, id, .inspect);
    } else if (try decl.record(source, id) != null) {
        _ = try decl.authorizeObject(source, who, id, .inspect);
    } else return error.TableNotFound;
    return self.restrict(source, id);
}
pub fn dependents(self: Self, source: anytype, who: u64, object_id: u64, cursor: ?m.DependencyCursor) !m.DependencyPage {
    const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
    if (try self.object(source, object_id) != null) {
        _ = try self.authorizeObject(source, who, object_id, .inspect);
    } else if (try decl.record(source, object_id) != null) {
        _ = try decl.authorizeObject(source, who, object_id, .inspect);
    } else return error.TableNotFound;
    if (cursor) |prior| {
        try self.scope(prior.scope);
        if (prior.resource_revision != source.view.revision or prior.subject != object_id or prior.after == 0) return error.CatalogCursorChanged;
    }
    const full = self.key('B', object_id, 0);
    const prefix = try p.Value.init(full.data[0..19]);
    const after = if (cursor) |prior| self.key('B', object_id, prior.after) else prefix;
    const page = try source.page(after);
    try c.Inspection.validatePage(page, after, source.view.revision);
    var result: m.DependencyPage = .{ .resource_revision = source.view.revision };
    var count: usize = 0;
    var last: u64 = 0;
    for (page.entries) |slot| {
        const entry = slot orelse break;
        if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return result;
        if (entry.key.len != 27) return error.InvalidCatalogDependency;
        const identity = std.mem.readInt(u64, entry.key.data[19..27], .big);
        const dep = try r.decode(m.Dependency, 'B', entry.value);
        try self.scope(dep.scope);
        if (dep.object != object_id or dep.identity != identity) return error.InvalidCatalogDependency;
        last = identity;
        result.entries[count] = dep;
        count += 1;
    }
    if (page.next != null and last != 0) result.next = .{ .scope = self.configuration.scope, .resource_revision = source.view.revision, .subject = object_id, .after = last };
    return result;
}
pub fn dependencies(self: Self, source: anytype, who: u64, identity: u64, cursor: ?m.DependencyCursor) !m.DependencyPage {
    if (identity == 0) return error.InvalidCatalogIdentity;
    const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
    if (try self.object(source, identity) != null) {
        _ = try self.authorizeObject(source, who, identity, .inspect);
    } else if (try decl.record(source, identity) != null) {
        _ = try decl.authorizeObject(source, who, identity, .inspect);
    } else {
        _ = try self.authorize(source, who, .inspect);
    }
    if (cursor) |prior| {
        try self.scope(prior.scope);
        if (prior.resource_revision != source.view.revision or prior.subject != identity or prior.after == 0) return error.CatalogCursorChanged;
    }
    const full = self.key('b', identity, 0);
    const prefix = try p.Value.init(full.data[0..19]);
    const after = if (cursor) |prior| self.key('b', identity, prior.after) else prefix;
    const page = try source.page(after);
    try c.Inspection.validatePage(page, after, source.view.revision);
    var result: m.DependencyPage = .{ .resource_revision = source.view.revision };
    var count: usize = 0;
    var last: u64 = 0;
    for (page.entries) |slot| {
        const entry = slot orelse break;
        if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return result;
        if (entry.key.len != 27) return error.InvalidCatalogDependency;
        const target = std.mem.readInt(u64, entry.key.data[19..27], .big);
        const dep = try r.decode(m.Dependency, 'B', entry.value);
        try self.scope(dep.scope);
        if (dep.identity != identity or dep.object != target) return error.InvalidCatalogDependency;
        const forward = (try source.read(self.key('B', target, identity))) orelse return error.InvalidCatalogDependency;
        if (!forward.eql(entry.value)) return error.InvalidCatalogDependency;
        last = target;
        if (try self.object(source, target) != null) {
            _ = self.authorizeObject(source, who, target, .inspect) catch |err| {
                if (err == error.CatalogDenied) continue;
                return err;
            };
        } else if (try decl.record(source, target) != null) {
            _ = decl.authorizeObject(source, who, target, .inspect) catch |err| {
                if (err == error.CatalogDenied) continue;
                return err;
            };
        } else continue;
        result.entries[count] = dep;
        count += 1;
    }
    if (page.next != null and last != 0) result.next = .{ .scope = self.configuration.scope, .resource_revision = source.view.revision, .subject = identity, .after = last };
    return result;
}
pub fn policyReferences(self: Self, source: anytype, who: u64, id: u64) !?m.PolicyReferences {
    _ = try self.authorizeDatabase(source, who);
    const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
    if (try self.object(source, id)) |current| {
        _ = try self.authorizeObject(source, who, id, .inspect);
        const ns = try self.namespaceRecord(source, current.namespace);
        const readable = try self.canRead(source, who, id);
        return .{
            .kind = .table,
            .scope = current.scope,
            .namespace = current.namespace,
            .object = current.object,
            .authorization_domain = self.configuration.authority.table_domain,
            .authorization_object = if (readable) current.authorization else 0,
            .schema_authorization = if (readable) ns.authorization else 0,
            .owner_pid = self.configuration.owner,
            .retention_unlimited = true,
            .record_bytes = self.configuration.table_limits.record_bytes,
            .staging_bytes = self.configuration.table_limits.staging_bytes,
            .staging_records = self.configuration.table_limits.staging_records,
            .can_read = readable,
            .redacted = !readable,
            .resource_revision = source.view.revision,
        };
    }
    if (try decl.record(source, id)) |current_decl| {
        _ = try decl.authorizeObject(source, who, id, .inspect);
        const ns = try self.namespaceRecord(source, current_decl.namespace);
        const readable = blk: {
            _ = decl.authorizeObject(source, who, id, .read) catch |err| {
                if (err == error.CatalogDenied) break :blk false;
                return err;
            };
            break :blk true;
        };
        return .{
            .kind = current_decl.spec.objectKind(),
            .scope = current_decl.scope,
            .namespace = current_decl.namespace,
            .object = current_decl.object,
            .authorization_domain = self.configuration.authority.table_domain,
            .authorization_object = if (readable) current_decl.authorization else 0,
            .schema_authorization = if (readable) ns.authorization else 0,
            .owner_pid = self.configuration.owner,
            .retention_unlimited = true,
            .record_bytes = p.Value.max_bytes,
            .staging_bytes = 0,
            .staging_records = 0,
            .can_read = readable,
            .redacted = !readable,
            .resource_revision = source.view.revision,
        };
    }
    return null;
}
pub fn inspectComputation(self: Self, source: anytype, who: u64, id: u64) !?m.ComputationEvidence {
    const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
    return decl.inspectComputation(source, who, id);
}
pub fn inspectLifecycle(self: Self, source: anytype, who: u64, id: u64) !?m.LifecycleEvidence {
    _ = try self.authorizeDatabase(source, who);
    const current = (try self.object(source, id)) orelse {
        return (c.DeclarativeCatalog{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration }).inspectLifecycle(source, who, id);
    };
    _ = try self.authorizeObject(source, who, id, .inspect);
    if (current.state == .initializing) {
        const pending = if (current.pending_operation != 0) try self.operation(source, current.pending_principal, current.pending_operation) else null;
        return .{
            .kind = .table,
            .state = .pending,
            .scope = current.scope,
            .namespace = current.namespace,
            .object = current.object,
            .revision = 0,
            .name = try Meta.Name.init("_initializing"),
            .definition_digest = current.pending_digest,
            .resource_revision = source.view.revision,
            .pending_operation = current.pending_operation,
            .admitted_input = if (pending) |op| op.admitted_input else 0,
        };
    }
    if (current.state == .retired and current.metadata.id == 0) {
        return .{
            .kind = .table,
            .state = .unavailable,
            .scope = current.scope,
            .namespace = current.namespace,
            .object = current.object,
            .revision = 0,
            .name = try Meta.Name.init("_retired"),
            .definition_digest = @splat(0),
            .resource_revision = source.view.revision,
        };
    }
    const record = try self.metadata(source, current);
    if (current.state == .retired) {
        return .{
            .kind = .table,
            .state = .unavailable,
            .scope = current.scope,
            .namespace = current.namespace,
            .object = current.object,
            .revision = record.revision,
            .name = record.name,
            .definition_digest = record.schema_fingerprint,
            .resource_revision = source.view.revision,
            .admitted_input = record.admitted_input,
        };
    }
    const head = try self.resolveHead(source, current, record);
    const active_op = if (current.pending_operation != 0) current.pending_operation else head.pending;
    return .{
        .kind = .table,
        .state = if (active_op != 0) .pending else .published,
        .scope = current.scope,
        .namespace = current.namespace,
        .object = current.object,
        .revision = record.revision,
        .name = record.name,
        .definition_digest = record.schema_fingerprint,
        .resource_revision = source.view.revision,
        .pending_operation = active_op,
        .admitted_input = record.admitted_input,
    };
}
pub fn previewDdl(self: Self, source: anytype, who: u64, request: DdlRequest) !m.Preview {
    var scoped = self;
    scoped.namespace = request.namespace;
    if (who != request.principal) return error.CatalogDenied;
    _ = try scoped.authorizeObject(source, request.principal, request.object, request.right());
    _ = try request.digest(self.configuration.scope);
    const bound = try scoped.binding(source, request.name);
    switch (request.action) {
        .create => |creation| {
            const decl: c.DeclarativeCatalog = .{ .configuration = scoped.configuration, .namespace = scoped.namespace, .registration = scoped.registration };
            const fp = try creation.schema.fingerprint();
            if (bound) |existing| {
                _ = try scoped.authorizeObject(source, request.principal, existing.object.object, .inspect);
                return .{
                    .kind = .table,
                    .action = .create,
                    .name = request.name,
                    .object = existing.object.object,
                    .expected_revision = existing.metadata.revision,
                    .disposition = if (creation.if_not_exists) .unchanged else .rejected,
                    .reason = if (creation.if_not_exists) .none else .name_conflict,
                    .definition_digest = fp,
                    .resource_revision = source.view.revision,
                };
            }
            if (try decl.boundMeta(source, scoped.namespaceId(), request.name)) |decl_existing| {
                _ = try decl.authorizeObject(source, request.principal, decl_existing.object, .inspect);
                return .{
                    .kind = .table,
                    .action = .create,
                    .name = request.name,
                    .object = decl_existing.object,
                    .expected_revision = decl_existing.revision,
                    .disposition = .rejected,
                    .reason = .name_conflict,
                    .definition_digest = fp,
                    .resource_revision = source.view.revision,
                };
            }
            if (try scoped.object(source, request.object) != null or try decl.record(source, request.object) != null) {
                return .{
                    .kind = .table,
                    .action = .create,
                    .name = request.name,
                    .object = request.object,
                    .expected_revision = 0,
                    .disposition = .rejected,
                    .reason = .object_conflict,
                    .definition_digest = fp,
                    .resource_revision = source.view.revision,
                };
            }
            return .{
                .kind = .table,
                .action = .create,
                .name = request.name,
                .object = request.object,
                .expected_revision = 1,
                .disposition = .admissible,
                .definition_digest = fp,
                .resource_revision = source.view.revision,
            };
        },
        else => {
            const action_tag: m.Kind = request.action;
            const existing = bound orelse {
                const absent_ok = request.action == .drop and request.action.drop.if_exists and request.object == 0;
                return .{
                    .kind = .table,
                    .action = action_tag,
                    .name = request.name,
                    .object = request.object,
                    .expected_revision = 0,
                    .disposition = if (absent_ok) .unchanged else .rejected,
                    .reason = if (absent_ok) .none else .not_found,
                    .resource_revision = source.view.revision,
                };
            };
            if (request.object != existing.object.object) {
                return .{
                    .kind = .table,
                    .action = action_tag,
                    .name = request.name,
                    .object = existing.object.object,
                    .expected_revision = existing.metadata.revision,
                    .disposition = .rejected,
                    .reason = .object_conflict,
                    .definition_digest = existing.metadata.schema_fingerprint,
                    .resource_revision = source.view.revision,
                };
            }
            if (request.expected_revision != existing.metadata.revision) {
                return .{
                    .kind = .table,
                    .action = action_tag,
                    .name = request.name,
                    .object = existing.object.object,
                    .expected_revision = existing.metadata.revision,
                    .disposition = .rejected,
                    .reason = .schema_changed,
                    .definition_digest = existing.metadata.schema_fingerprint,
                    .resource_revision = source.view.revision,
                };
            }
            const head = try s.TableHead.load(source, request.object);
            if (head.retired or !std.meta.eql(head.schema, existing.metadata.schema)) return error.CatalogSourceChanged;
            if (existing.object.pending_operation != 0 or head.pending != 0) return error.TableBusy;
            switch (request.action) {
                .create => unreachable,
                .alter => |alter| {
                    if (!std.mem.eql(u8, &try alter.schema.fingerprint(), &existing.metadata.schema_fingerprint)) {
                        return .{
                            .kind = .table,
                            .action = .alter,
                            .name = request.name,
                            .object = request.object,
                            .expected_revision = existing.metadata.revision,
                            .disposition = .rejected,
                            .reason = .schema_changed,
                            .definition_digest = existing.metadata.schema_fingerprint,
                            .resource_revision = source.view.revision,
                        };
                    }
                    var columns: [c.fuze.TableSchema.max_columns]c.fuze.TableSchema.Column = undefined;
                    const transition = try c.fuze.TableEvolution.apply(alter.schema, alter.change, &columns);
                    return .{
                        .kind = .table,
                        .action = .alter,
                        .name = request.name,
                        .object = request.object,
                        .expected_revision = try add(existing.metadata.revision, 1),
                        .disposition = .admissible,
                        .work = transition.work,
                        .rebuild_key = transition.rebuild_key,
                        .definition_digest = try transition.after.fingerprint(),
                        .resource_revision = source.view.revision,
                    };
                },
                .rename => |target_name| {
                    if (target_name.eql(&request.name)) {
                        return .{
                            .kind = .table,
                            .action = .rename,
                            .name = request.name,
                            .object = request.object,
                            .expected_revision = existing.metadata.revision,
                            .disposition = .unchanged,
                            .definition_digest = existing.metadata.schema_fingerprint,
                            .resource_revision = source.view.revision,
                        };
                    }
                    if (try scoped.binding(source, target_name)) |occupied| {
                        return .{
                            .kind = .table,
                            .action = .rename,
                            .name = target_name,
                            .object = occupied.object.object,
                            .expected_revision = existing.metadata.revision,
                            .disposition = .rejected,
                            .reason = .name_conflict,
                            .definition_digest = existing.metadata.schema_fingerprint,
                            .resource_revision = source.view.revision,
                        };
                    }
                    const decl: c.DeclarativeCatalog = .{ .configuration = scoped.configuration, .namespace = scoped.namespace, .registration = scoped.registration };
                    if (try decl.boundMeta(source, scoped.namespaceId(), target_name)) |decl_occupied| {
                        return .{
                            .kind = .table,
                            .action = .rename,
                            .name = target_name,
                            .object = decl_occupied.object,
                            .expected_revision = existing.metadata.revision,
                            .disposition = .rejected,
                            .reason = .name_conflict,
                            .definition_digest = existing.metadata.schema_fingerprint,
                            .resource_revision = source.view.revision,
                        };
                    }
                    return .{
                        .kind = .table,
                        .action = .rename,
                        .name = target_name,
                        .object = request.object,
                        .expected_revision = try add(existing.metadata.revision, 1),
                        .disposition = .admissible,
                        .definition_digest = existing.metadata.schema_fingerprint,
                        .resource_revision = source.view.revision,
                    };
                },
                .drop => {
                    if (try scoped.restrict(source, request.object)) |dependency| {
                        return .{
                            .kind = .table,
                            .action = .drop,
                            .name = request.name,
                            .object = request.object,
                            .expected_revision = existing.metadata.revision,
                            .disposition = .rejected,
                            .reason = .dependency,
                            .definition_digest = existing.metadata.schema_fingerprint,
                            .blocker = dependency,
                            .resource_revision = source.view.revision,
                        };
                    }
                    return .{
                        .kind = .table,
                        .action = .drop,
                        .name = request.name,
                        .object = request.object,
                        .expected_revision = try add(existing.metadata.revision, 1),
                        .disposition = .admissible,
                        .definition_digest = existing.metadata.schema_fingerprint,
                        .resource_revision = source.view.revision,
                    };
                },
            }
        },
    }
}

pub const DdlRequest = c.TableDdlRequest;
pub const Outcome = struct {
    operation: m.Operation,
    table: ?s.TableWrite.Status = null,
    pub fn terminal(self: Outcome) bool {
        return switch (self.operation.state) {
            .preparing => false,
            .delegated => if (self.table) |value| value.state != .building else false,
            else => true,
        };
    }
};
fn operation(self: Self, source: anytype, who: u64, id: u64) !?m.Operation {
    if (who > p.max_counter or id == 0) return error.InvalidCatalogIdentity;
    const found = try r.decode(m.Operation, 'R', (try source.read(self.key('o', who, id))) orelse return null);
    try self.scope(found.scope);
    if (found.principal != who or found.operation != id) return error.InvalidCatalogReceipt;
    return found;
}
fn outcome(source: anytype, value: m.Operation) !Outcome {
    const table = if (value.state == .delegated) (try s.TableWrite.status(source, try value.tableReference())) orelse return error.InvalidCatalogReceipt else null;
    if (table) |result| if (result.route != .alter) return error.InvalidCatalogReceipt;
    return .{ .operation = value, .table = table };
}
pub fn status(self: Self, source: anytype, who: u64, id: u64, digest: [32]u8) !?Outcome {
    _ = try self.authorizeDatabase(source, who);
    const found = (try self.operation(source, who, id)) orelse return null;
    if (!std.mem.eql(u8, &found.digest, &digest)) return error.CatalogIdentityConflict;
    const target = if (found.actual_object != 0) found.actual_object else if (found.object != 0 and try self.object(source, found.object) != null) found.object else 0;
    if (target != 0) _ = try self.authorizeObject(source, who, target, .inspect) else _ = try self.require(source, who, try self.namespaceRecord(source, found.namespace), null, .schema);
    var result = try outcome(source, found);
    if (result.table) |*table| table.* = try table.disclose(try self.canRead(source, who, found.object));
    return result;
}
/// Published bytes alone do not establish an accepted definition. Retained
/// metadata must be named by its original applied catalog/Table decision.
fn acceptedDefinition(self: Self, source: anytype, id: u64, ref: s.TablePages.Reference, record: Meta.Record) !bool {
    const accepted = (try self.operation(source, record.principal, record.operation)) orelse return error.CatalogDefinitionMissing;
    if (accepted.object != id or accepted.admitted_input != record.admitted_input or !std.meta.eql(accepted.metadata, ref)) return error.CatalogDefinitionChanged;
    return switch (accepted.state) {
        .applied => true,
        .delegated => (try outcome(source, accepted)).table.?.state == .applied,
        else => false,
    };
}
pub fn historical(self: Self, source: anytype, who: u64, id: u64, ref: s.TablePages.Reference) !Meta.Record {
    _ = try self.authorizeObject(source, who, id, .inspect);
    const record = try (Store{ .scope = self.configuration.scope, .object = id }).read(source, ref);
    if (!try self.acceptedDefinition(source, id, ref, record)) return error.CatalogDefinitionMissing;
    return record;
}
/// Exact metadata/schema inspection survives rename and DROP. Missing or never
/// accepted revisions return null; incompatible/corrupt retained evidence fails.
pub fn definition(self: Self, allocator: std.mem.Allocator, source: anytype, who: u64, id: u64, revision: u64) !?HistoricalDefinition {
    _ = try self.authorizeDatabase(source, who);
    if (revision == 0) return error.InvalidCatalogIdentity;
    const current = (try self.object(source, id)) orelse return null;
    _ = try self.authorizeObject(source, who, id, .inspect);
    if (current.metadata.id == 0) return null;
    const ref = (try (Store{ .scope = self.configuration.scope, .object = id }).referenceAt(source, revision)) orelse return null;
    const record = try (Store{ .scope = self.configuration.scope, .object = id }).read(source, ref);
    if (!try self.acceptedDefinition(source, id, ref, record)) return null;
    return .{ .metadata = record, .schema = try record.readSchema(allocator, source) };
}
fn saveOperation(self: Self, turn: *s.Turn, value: m.Operation) !void {
    try turn.write(self.key('o', value.principal, value.operation), try r.encode('R', value));
}
fn saveObject(self: Self, turn: *s.Turn, value: m.Object) !void {
    try turn.write(self.key('O', value.object, 0), try r.encode('O', value));
}
fn add(left: u64, right: u64) !u64 {
    return std.math.add(u64, left, right) catch return error.CatalogCapacity;
}
fn writes(turn: *s.Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
fn matchingPending(value: m.Object, pending: m.Operation) !void {
    if (value.object != pending.object or value.pending_principal != pending.principal or value.pending_operation != pending.operation or !std.mem.eql(u8, &value.pending_digest, &pending.digest)) return error.CatalogIdentityConflict;
}
fn close(self: Self, turn: *s.Turn, pending: m.Operation, current: ?m.Object, state: @FieldType(m.Operation, "state"), reason: @FieldType(m.Operation, "reason"), actual: u64) !Outcome {
    var final = pending;
    final.state = state;
    final.reason = reason;
    final.actual_object = actual;
    final.completed_input = turn.delivery.input.position;
    if (current) |old| {
        try matchingPending(old, pending);
        var next = old;
        if (next.state == .initializing) next.state = .retired;
        next.clearPending();
        try self.saveObject(turn, next);
    }
    try self.saveOperation(turn, final);
    return .{ .operation = final };
}
fn closeRestricted(self: Self, turn: *s.Turn, pending: m.Operation, current: ?m.Object, dependency: m.Dependency) !Outcome {
    try dependency.validate();
    if (!std.meta.eql(dependency.scope, pending.scope) or dependency.object != pending.object or !dependency.restricts()) return error.InvalidCatalogDependency;
    var rejected = pending;
    rejected.blocker = .{ .dependency = .{ .identity = dependency.identity, .owner = dependency.owner, .kind = dependency.kind } };
    return self.close(turn, rejected, current, .rejected, .dependency, pending.object);
}
fn emptyObjectNamespace(turn: *s.Turn, id: u64) !void {
    inline for (.{ s.Publication.Domain.table, s.Publication.Domain.catalog }) |domain| {
        const full = s.Publication.key(domain, id, 0, 0, 0);
        const prefix = try p.Value.init(full.data[0..14]);
        var committed = turn.committed();
        const page = try committed.page(prefix);
        try c.Inspection.validatePage(page, prefix, turn.view.revision);
        if (page.entries[0]) |entry| if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.CatalogAlreadyPopulated;
    }
}
fn admit(self: Self, turn: *s.Turn, request: DdlRequest, digest: [32]u8) !Outcome {
    var pending: m.Operation = .{ .scope = self.configuration.scope, .principal = request.principal, .operation = request.operation, .object = request.object, .namespace = request.namespace, .digest = digest, .kind = request.action, .state = .preparing, .admitted_input = turn.originalAuthorizedInput() };
    const bound = try self.binding(turn, request.name);
    switch (request.action) {
        .create => |creation| {
            const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
            if (bound) |existing| {
                _ = try self.authorizeObject(turn, request.principal, existing.object.object, .inspect);
                return self.close(turn, pending, null, if (creation.if_not_exists) .unchanged else .rejected, if (creation.if_not_exists) .none else .name_conflict, existing.object.object);
            }
            if (try decl.boundMeta(turn, self.namespaceId(), request.name)) |decl_existing| {
                _ = try decl.authorizeObject(turn, request.principal, decl_existing.object, .inspect);
                return self.close(turn, pending, null, .rejected, .name_conflict, decl_existing.object);
            }
            if (try self.object(turn, request.object) != null or try decl.record(turn, request.object) != null) return self.close(turn, pending, null, .rejected, .object_conflict, request.object);
            try emptyObjectNamespace(turn, request.object);
            const namespace = try self.namespaceRecord(turn, self.namespaceId());
            const identity = try c.TableAuthority.binding(pending.scope, .table, request.object);
            const profile = self.configuration.authority;
            const native = (try turn.authorizationBinding(profile.table_domain, identity)) orelse {
                const verified = try self.authorize(turn, request.principal, .create);
                if (self.registration) |slot| slot.* = .{ .register_object = .{ .domain = profile.table_domain, .owner = verified.role, .schema = c.TableAuthority.reference(namespace.authorization), .binding = identity } };
                return error.CatalogRegistrationRequired;
            };
            try c.TableAuthority.validateObject(profile, pending.scope, .table, request.object, c.TableAuthority.reference(namespace.authorization), native);
            const verified = try self.authorize(turn, request.principal, .create);
            if (native.owner != verified.role) return error.CatalogIdentityConflict;
            try (c.SchemaCatalog{ .configuration = self.configuration }).admitTable(turn, namespace.id);
            const fresh: m.Object = .{ .scope = pending.scope, .object = request.object, .namespace = namespace.id, .authorization = native.reference.id, .state = .initializing, .next_revision = 2, .pending_principal = pending.principal, .pending_operation = pending.operation, .pending_revision = 1, .pending_digest = digest };
            try self.saveObject(turn, fresh);
            var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
            const schema_ref: s.TablePages.Reference = .{ .id = 1, .spec = try s.Publication.Digest.of(s.TablePages.schema_format, try creation.schema.encode(&bytes)) };
            const record = self.candidate(pending, fresh, request.name, schema_ref, try creation.schema.fingerprint());
            pending.metadata = .{ .id = 1, .spec = try record.spec() };
        },
        else => {
            const existing = bound orelse {
                const absent_ok = request.action == .drop and request.action.drop.if_exists and request.object == 0;
                return self.close(turn, pending, null, if (absent_ok) .unchanged else .rejected, if (absent_ok) .none else .not_found, 0);
            };
            // A saved absent DROP is not allowed to bind a subsequently created Table.
            if (request.object != existing.object.object) return self.close(turn, pending, null, .rejected, .object_conflict, existing.object.object);
            if (request.expected_revision != existing.metadata.revision) return self.close(turn, pending, null, .rejected, .schema_changed, existing.object.object);
            const head = try s.TableHead.load(turn, request.object);
            if (head.retired or !std.meta.eql(head.schema, existing.metadata.schema)) return error.CatalogSourceChanged;
            if (existing.object.pending_operation != 0 or head.pending != 0) return error.TableBusy;
            if (request.action == .alter and !std.mem.eql(u8, &try request.action.alter.schema.fingerprint(), &existing.metadata.schema_fingerprint)) return self.close(turn, pending, null, .rejected, .schema_changed, request.object);
            if (request.action == .rename) {
                if (request.action.rename.eql(&request.name)) return self.close(turn, pending, null, .unchanged, .none, request.object);
                if (try self.binding(turn, request.action.rename)) |occupied| return self.close(turn, pending, null, .rejected, .name_conflict, occupied.object.object);
                const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
                if (try decl.boundMeta(turn, self.namespaceId(), request.action.rename)) |decl_occupied| return self.close(turn, pending, null, .rejected, .name_conflict, decl_occupied.object);
            }
            if (request.action == .drop) if (try self.restrict(turn, request.object)) |dependency| return self.closeRestricted(turn, pending, null, dependency);
            var next = existing.object;
            next.pending_principal = request.principal;
            next.pending_operation = request.operation;
            next.pending_revision = next.next_revision;
            next.next_revision = try add(next.next_revision, 1);
            next.pending_digest = digest;
            try self.saveObject(turn, next);
        },
    }
    if (request.action == .alter) pending.table_digest = (try (try request.tableAlter(pending.scope)).reference()).digest;
    try self.saveOperation(turn, pending);
    return .{ .operation = pending };
}
fn candidate(self: Self, pending: m.Operation, current: m.Object, name: Meta.Name, schema: s.TablePages.Reference, fingerprint: [32]u8) Meta.Record {
    return .{ .scope = self.configuration.scope, .object = current.object, .namespace = current.namespace, .revision = current.pending_revision, .name = name, .schema = schema, .schema_fingerprint = fingerprint, .principal = pending.principal, .operation = pending.operation, .admitted_input = pending.admitted_input };
}
fn stagedMetadata(self: Self, turn: *s.Turn, record: Meta.Record) !bool {
    const store: Store = .{ .scope = self.configuration.scope, .object = record.object };
    const before = writes(turn);
    const ready = try store.stage(turn, record);
    return ready == .ready and writes(turn) == before;
}
fn recordCandidate(self: Self, turn: *s.Turn, pending: m.Operation, record: Meta.Record) !bool {
    const ref: s.TablePages.Reference = .{ .id = record.revision, .spec = try record.spec() };
    if (pending.metadata.id != 0) {
        if (!std.meta.eql(pending.metadata, ref)) return error.CatalogIdentityConflict;
        return true;
    }
    var next = pending;
    next.metadata = ref;
    try self.saveOperation(turn, next);
    return false;
}
fn publishObject(self: Self, turn: *s.Turn, old: m.Object, record: Meta.Record, pending: m.Operation, retired: bool) !Outcome {
    var next = old;
    next.state = if (retired) .retired else .live;
    next.metadata = .{ .id = record.revision, .spec = try record.spec() };
    next.clearPending();
    try self.saveObject(turn, next);
    var final = pending;
    final.state = .applied;
    final.actual_object = old.object;
    final.metadata = next.metadata;
    final.completed_input = turn.delivery.input.position;
    try self.saveOperation(turn, final);
    return .{ .operation = final };
}
fn createStep(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DdlRequest, pending: m.Operation, current: m.Object) !Outcome {
    if (try self.binding(turn, request.name)) |existing| return self.close(turn, pending, current, if (request.action.create.if_not_exists) .unchanged else .rejected, if (request.action.create.if_not_exists) .none else .name_conflict, existing.object.object);
    const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
    if (try decl.boundMeta(turn, self.namespaceId(), request.name)) |decl_existing| return self.close(turn, pending, current, .rejected, .name_conflict, decl_existing.object);
    if (current.state != .initializing or try turn.read(s.TableHead.key(current.object)) != null) return error.CatalogDefinitionChanged;
    const before = writes(turn);
    const pages = try s.TablePages.create(turn, request.object, self.configuration.table_limits);
    if (writes(turn) != before) return .{ .operation = pending };
    const store: Store = .{ .scope = self.configuration.scope, .object = request.object };
    try store.create(turn);
    if (writes(turn) != before) return .{ .operation = pending };
    const schema = request.action.create.schema;
    var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    const encoded = try schema.encode(&bytes);
    const schema_ref: s.TablePages.Reference = .{ .id = 1, .spec = try s.Publication.Digest.of(s.TablePages.schema_format, encoded) };
    if (try pages.stage(turn, schema_ref, encoded) == .progress or writes(turn) != before) return .{ .operation = pending };
    const record = self.candidate(pending, current, request.name, schema_ref, try schema.fingerprint());
    if (!try self.recordCandidate(turn, pending, record)) return .{ .operation = (try self.operation(turn, pending.principal, pending.operation)).? };
    if (!try self.stagedMetadata(turn, record)) return .{ .operation = pending };
    const head: s.TableHead = .{ .resource = self.configuration.scope.resource, .object = request.object, .revision = 1, .schema = schema_ref, .next_record = 2 };
    try head.create(allocator, turn);
    try turn.write(try Meta.nameKey(self.configuration.scope.catalog, try request.name.digestIn(request.namespace), request.object), try r.encode('N', m.Binding{ .scope = self.configuration.scope, .object = request.object }));
    return self.publishObject(turn, current, record, pending, false);
}
fn boundStep(self: Self, turn: *s.Turn, request: DdlRequest, pending: m.Operation, current: m.Object) !Outcome {
    const original = try self.metadata(turn, current);
    if (!original.name.eql(&request.name) or original.revision != request.expected_revision) return error.CatalogDefinitionChanged;
    const head = try s.TableHead.load(turn, request.object);
    if (head.retired or !std.meta.eql(head.schema, original.schema)) return error.CatalogSourceChanged;
    if (head.pending != 0) return error.TableBusy;
    if (request.action == .rename) {
        if (try self.binding(turn, request.action.rename)) |occupied| return self.close(turn, pending, current, .rejected, .name_conflict, occupied.object.object);
        const decl: c.DeclarativeCatalog = .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
        if (try decl.boundMeta(turn, self.namespaceId(), request.action.rename)) |decl_occupied| return self.close(turn, pending, current, .rejected, .name_conflict, decl_occupied.object);
    } else if (try self.restrict(turn, request.object)) |dependency| return self.closeRestricted(turn, pending, current, dependency);
    const record = self.candidate(pending, current, if (request.action == .rename) request.action.rename else request.name, head.schema, original.schema_fingerprint);
    if (!try self.recordCandidate(turn, pending, record)) return .{ .operation = (try self.operation(turn, pending.principal, pending.operation)).? };
    if (!try self.stagedMetadata(turn, record)) return .{ .operation = pending };
    // DROP's name, object, head and outcome still publish together in four
    // writes. An earlier immutable predecessor stage does not retire anything.
    if (request.action == .drop and try s.TableHistory.stage(head, turn) == .progress) return .{ .operation = pending };
    try turn.write(try Meta.nameKey(self.configuration.scope.catalog, try request.name.digestIn(request.namespace), request.object), null);
    if (request.action == .rename) {
        try turn.write(try Meta.nameKey(self.configuration.scope.catalog, try request.action.rename.digestIn(request.namespace), request.object), try r.encode('N', m.Binding{ .scope = self.configuration.scope, .object = request.object }));
    } else {
        var retired = head;
        retired.revision = try add(head.revision, 1);
        retired.retired = true;
        try head.replace(turn, retired);
    }
    return self.publishObject(turn, current, record, pending, request.action == .drop);
}
fn alterStep(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DdlRequest, pending: m.Operation, current: m.Object) !Outcome {
    const original = try self.metadata(turn, current);
    if (!original.name.eql(&request.name) or original.revision != request.expected_revision or !std.mem.eql(u8, &original.schema_fingerprint, &try request.action.alter.schema.fingerprint())) return error.CatalogDefinitionChanged;
    const table_request = try request.tableAlter(self.configuration.scope);
    if (pending.state == .delegated) {
        const head = try s.TableHead.load(turn, request.object);
        if (head.pending != 0 and try s.TableHistory.stage(head, turn) == .progress) return .{ .operation = pending };
        const result = try s.TableAlter.step(allocator, turn, table_request);
        if (result.state != .building) {
            var next = current;
            if (result.state == .applied) next.metadata = pending.metadata;
            next.clearPending();
            try self.saveObject(turn, next);
        }
        return .{ .operation = pending, .table = result };
    }
    const table_ref = try table_request.reference();
    const prior = (try s.TableWrite.status(turn, table_ref)) orelse {
        _ = try s.TableAlter.step(allocator, turn, table_request);
        return .{ .operation = pending };
    };
    if (prior.state == .cancelled) return self.close(turn, pending, current, .cancelled, .none, pending.object);
    if (prior.state != .building) return error.InvalidCatalogReceipt;
    var columns: [c.fuze.TableSchema.max_columns]c.fuze.TableSchema.Column = undefined;
    const transition = try c.fuze.TableEvolution.apply(table_request.schema, table_request.change, &columns);
    var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    const encoded = try transition.after.encode(&bytes);
    const schema_ref: s.TablePages.Reference = .{ .id = prior.first_record, .spec = try s.Publication.Digest.of(s.TablePages.schema_format, encoded) };
    const record = self.candidate(pending, current, request.name, schema_ref, try transition.after.fingerprint());
    if (!try self.recordCandidate(turn, pending, record)) return .{ .operation = (try self.operation(turn, pending.principal, pending.operation)).? };
    if (!try self.stagedMetadata(turn, record)) return .{ .operation = pending };
    var delegated = pending;
    delegated.state = .delegated;
    delegated.actual_object = request.object;
    delegated.metadata = .{ .id = record.revision, .spec = try record.spec() };
    try self.saveOperation(turn, delegated);
    return .{ .operation = delegated, .table = prior };
}
/// One bounded private proposal. The native owner commits its writes with input
/// progress, and supplies the exact same request on each continuation.
pub fn step(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DdlRequest) !Outcome {
    var scoped = self;
    scoped.namespace = request.namespace;
    return scoped.advanceDdl(allocator, turn, request, .external);
}
/// A native self-message can continue only an already admitted exact operation.
/// Origin is never rewritten to impersonate the recorded external principal.
pub fn continueDdl(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DdlRequest) !Outcome {
    var scoped = self;
    scoped.namespace = request.namespace;
    return scoped.advanceDdl(allocator, turn, request, .continuation);
}
fn actor(self: Self, turn: *s.Turn, who: u64, continuation: bool) !void {
    try self.owner(turn);
    if (continuation) {
        if (turn.delivery.input.origin != .process or turn.delivery.input.origin.process.pid != self.configuration.owner) return error.CatalogDenied;
    } else if (try principal(turn) != who) return error.CatalogDenied;
}
pub fn bindCommand(self: Self, turn: *s.Turn, header: c.TableCommand.Header) !void {
    if (turn.delivery.input.origin != .process) return;
    if (turn.delivery.input.origin.process.pid != self.configuration.owner) return error.CatalogDenied;
    const input = switch (header.kind) {
        .create, .alter, .rename, .drop => ((try self.operation(turn, header.principal, header.operation)) orelse return error.CatalogOperationNotFound).admitted_input,
        .insert, .update, .delete => blk: {
            const ref: s.TableWrite.Reference = .{ .resource = header.scope.resource, .object = header.object, .principal = header.principal, .operation = header.operation, .digest = @splat(0) };
            const record = try s.TableWrite.Status.decode((try turn.read(ref.key())) orelse return error.TableWriteNotFound);
            if (record.reference.resource != ref.resource or record.reference.object != ref.object or record.reference.principal != ref.principal or record.reference.operation != ref.operation) return error.CatalogIdentityConflict;
            break :blk record.admitted_input;
        },
    };
    try turn.bindAuthorizationSubject(.{ .accepted = .{ .pid = self.configuration.owner, .input = input, .principal = header.principal } });
}
const Admission = enum { external, continuation, uploaded };
fn advanceDdl(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DdlRequest, admission: Admission) !Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, request.principal, admission != .external);
    const existing = try self.operation(turn, request.principal, request.operation);
    if (existing == null and admission == .continuation) return error.CatalogOperationNotFound;
    if (admission != .external) if (existing) |value| try turn.bindAuthorizationSubject(.{ .accepted = .{ .pid = self.configuration.owner, .input = value.admitted_input, .principal = request.principal } });
    _ = try self.authorizeObject(turn, request.principal, request.object, request.right());
    const digest = try request.digest(self.configuration.scope);
    const pending = existing orelse {
        if (admission == .continuation) return error.CatalogOperationNotFound;
        return self.admit(turn, request, digest);
    };
    if (!std.mem.eql(u8, &pending.digest, &digest)) return error.CatalogIdentityConflict;
    const result = try outcome(turn, pending);
    if (result.terminal()) return result;
    const current = (try self.object(turn, request.object)) orelse return error.CatalogDefinitionMissing;
    try matchingPending(current, pending);
    return switch (request.action) {
        .create => self.createStep(allocator, turn, request, pending, current),
        .alter => self.alterStep(allocator, turn, request, pending, current),
        .rename, .drop => self.boundStep(turn, request, pending, current),
    };
}

pub fn cancel(self: Self, turn: *s.Turn, who: u64, id: u64, digest: [32]u8) !Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.owner(turn);
    if (try principal(turn) != who) return error.CatalogDenied;
    _ = try self.authorize(turn, who, .inspect);
    const pending = (try self.operation(turn, who, id)) orelse return error.CatalogOperationNotFound;
    if (!std.mem.eql(u8, &pending.digest, &digest)) return error.CatalogIdentityConflict;
    const result = try outcome(turn, pending);
    if (result.terminal()) return result;
    const current = (try self.object(turn, pending.object)) orelse return error.CatalogDefinitionMissing;
    try matchingPending(current, pending);
    if (pending.kind == .alter) {
        const ref = try pending.tableReference();
        if (try s.TableWrite.status(turn, ref)) |table| {
            if (table.state == .cancelled and pending.state == .preparing) return self.close(turn, pending, current, .cancelled, .none, pending.object);
            if (table.state != .building) return error.InvalidCatalogReceipt;
            // Delegated cancellation also clears the catalog reservation. Keep
            // that publication atomic with the Table receipt within four writes.
            // A caller repeats the exact pending cancellation after staging.
            if (pending.state == .delegated and try s.TableHistory.stage(try s.TableHead.load(turn, pending.object), turn) == .progress) return .{ .operation = pending };
            const cancelled = try s.TableAlter.cancel(turn, ref);
            if (pending.state == .delegated) {
                var next = current;
                next.clearPending();
                try self.saveObject(turn, next);
                return .{ .operation = pending, .table = cancelled };
            }
            // Preparing work has no delegated catalog result yet. Cancel the
            // Table first; the next turn closes the catalog's pending record.
            // Keep its object reservation until that second bounded decision.
            return .{ .operation = pending };
        }
    }
    return self.close(turn, pending, current, .cancelled, .none, pending.object);
}

/// Cleanup only candidates whose exact terminal receipt proves they never
/// became live. Accepted historical revisions and DROP data are not collected.
pub fn cleanup(self: Self, turn: *s.Turn, who: u64, id: u64, digest: [32]u8) !bool {
    const before = turn.decision;
    const before_count = writes(turn);
    errdefer turn.decision = before;
    try self.owner(turn);
    if (try principal(turn) != who) return error.CatalogDenied;
    const result = (try self.status(turn, who, id, digest)) orelse return error.CatalogOperationNotFound;
    if (!result.terminal() or result.operation.state == .applied or (result.table != null and result.table.?.state == .applied)) return error.CatalogCleanupNotClosed;
    const pending = result.operation;
    if (pending.metadata.id != 0) {
        const current = (try self.object(turn, pending.object)) orelse return error.CatalogDefinitionMissing;
        if (current.next_revision <= pending.metadata.id or current.metadata.id == pending.metadata.id or current.pending_revision == pending.metadata.id) return error.CatalogDefinitionChanged;
        if (try (Store{ .scope = pending.scope, .object = pending.object }).collect(turn, pending.metadata) == .progress) return false;
        if (writes(turn) != before_count) return false;
    }
    if (pending.kind == .alter) {
        const ref = try pending.tableReference();
        if (try s.TableWrite.status(turn, ref) != null) return s.TableCleanup.step(turn, ref);
    } else if (pending.kind == .create and pending.metadata.id != 0) {
        const current = (try self.object(turn, pending.object)) orelse return true;
        // A name/object conflict can refer to a different admitted owner; never
        // collect it. Only this cancelled/rejected initial reservation qualifies.
        if (current.state != .retired or current.metadata.id != 0) return true;
        if (try turn.read(s.TableHead.key(pending.object)) != null) return error.CatalogDefinitionChanged;
        if (try turn.read(s.TablePages.key(pending.object, 'd', 0)) == null) return true;
        const pages: s.TablePages = .{ .resource = pending.scope.resource, .object = pending.object };
        if (try turn.read(s.TablePages.key(pending.object, 'r', 1)) != null) return try pages.collect(turn, 1, true) == .ready;
        if (try turn.read(s.TablePages.key(pending.object, 'i', 1)) != null) return try pages.collect(turn, 1, false) == .ready;
    }
    return true;
}

pub const DmlRequest = c.TableDmlRequest;
fn dataBinding(self: Self, source: anytype, request: DmlRequest) !void {
    const current = (try self.object(source, request.plan.schema.object)) orelse return error.TableNotFound;
    if (current.state != .live) return error.TableRetired;
    if (!std.meta.eql(current.metadata, request.metadata)) return error.CatalogDefinitionChanged;
    if (current.pending_operation != 0) return error.TableBusy;
    const record = try self.metadata(source, current);
    if (!std.mem.eql(u8, record.name.slice(), request.plan.name) or !std.mem.eql(u8, &record.schema_fingerprint, &try request.plan.schema.fingerprint())) return error.CatalogDefinitionChanged;
    const head = try s.TableHead.load(source, current.object);
    if (head.retired or !std.meta.eql(head.schema, record.schema)) return error.CatalogSourceChanged;
}
/// Inspect and action policy are current. A terminal exact receipt is returned
/// before consulting the live name/schema, including after DROP or RENAME.
pub fn mutate(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DmlRequest) !s.TableWrite.Status {
    return self.advanceMutation(allocator, turn, request, .external);
}
pub fn continueMutation(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DmlRequest) !s.TableWrite.Status {
    return self.advanceMutation(allocator, turn, request, .continuation);
}
fn advanceMutation(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DmlRequest, admission: Admission) !s.TableWrite.Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, request.principal, admission != .external);
    var scratch: [c.fuze.TableSchema.max_columns]c.fuze.Types.Values.Cell = undefined;
    const route = try request.route(allocator, self.configuration.scope, &scratch);
    const ref = try route.reference(allocator);
    const existing = try s.TableWrite.status(turn, ref);
    if (existing == null and admission == .continuation) return error.TableWriteNotFound;
    if (admission != .external) if (existing) |value| try turn.bindAuthorizationSubject(.{ .accepted = .{ .pid = self.configuration.owner, .input = value.admitted_input, .principal = request.principal } });
    _ = try self.authorizeObject(turn, request.principal, ref.object, request.right());
    if (existing) |previous| {
        if (previous.route != route.receiptRoute()) return error.InvalidTableWriteStatus;
        if (previous.state != .building) return previous;
    } else if (admission == .continuation) return error.TableWriteNotFound;
    try self.dataBinding(turn, request);
    return route.step(allocator, turn);
}

/// An owner self-message can admit an uploaded command only through the exact
/// committed transport record created by its original external principal.
/// Check terminal receipts before reading a body that may have been collected.
pub fn executeUploaded(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, namespace: u64) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    const uploads: c.TableUpload = .{ .catalog = self };
    const upload = try uploads.executionStatus(turn, namespace);
    if (upload.phase == .cancelled) return true;
    if (upload.phase != .ready) return error.TableUploadNotReady;
    if (try uploads.application(turn, upload) == .terminal) return true;
    var command = try uploads.resolve(allocator, turn, namespace);
    defer command.deinit();
    const admission: Admission = if (turn.delivery.input.origin == .external) .external else .uploaded;
    var scoped = self;
    scoped.namespace = upload.header.namespace;
    return switch (command.body.request) {
        .ddl => |request| (try scoped.advanceDdl(allocator, turn, request, admission)).terminal(),
        .dml => |request| (try scoped.advanceMutation(allocator, turn, request, admission)).state != .building,
    };
}
pub fn mutationStatus(self: Self, allocator: std.mem.Allocator, source: anytype, who: u64, request: DmlRequest) !?s.TableWrite.Status {
    _ = try self.authorizeDatabase(source, who);
    if (who != request.principal) return error.CatalogDenied;
    var scratch: [c.fuze.TableSchema.max_columns]c.fuze.Types.Values.Cell = undefined;
    const route = try request.route(allocator, self.configuration.scope, &scratch);
    const ref = try route.reference(allocator);
    _ = try self.authorizeObject(source, who, ref.object, .inspect);
    const result = try s.TableWrite.status(source, ref);
    if (result) |value| if (value.route != route.receiptRoute()) return error.InvalidTableWriteStatus;
    return if (result) |value| try value.disclose(try self.canRead(source, who, ref.object)) else null;
}

/// A saved exact reference can inspect/cancel DML without retransmitting its
/// original typed rows. Catalog ownership and current disclosure still apply.
pub fn mutationReceipt(self: Self, source: anytype, who: u64, ref: s.TableWrite.Reference) !?s.TableWrite.Status {
    _ = try self.authorizeDatabase(source, who);
    if (who != ref.principal) return error.CatalogDenied;
    if (ref.resource != self.configuration.scope.resource) return error.CatalogScopeChanged;
    _ = try self.authorizeObject(source, who, ref.object, .inspect);
    const result = (try s.TableWrite.status(source, ref)) orelse return null;
    if (result.route == .alter) return error.CatalogIdentityConflict;
    return try result.disclose(try self.canRead(source, who, ref.object));
}
pub fn cancelMutationReference(self: Self, turn: *s.Turn, ref: s.TableWrite.Reference) !s.TableWrite.Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, ref.principal, false);
    const result = (try self.mutationReceipt(turn, ref.principal, ref)) orelse return error.TableWriteNotFound;
    return switch (result.route) {
        .point => s.TableWrite.cancel(turn, ref),
        .statement => s.TableStatement.cancel(turn, ref),
        .alter => unreachable,
    };
}
pub fn cleanupMutationReference(self: Self, turn: *s.Turn, ref: s.TableWrite.Reference) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, ref.principal, false);
    _ = (try self.mutationReceipt(turn, ref.principal, ref)) orelse return error.TableWriteNotFound;
    return s.TableCleanup.step(turn, ref);
}
pub fn cancelMutation(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DmlRequest) !s.TableWrite.Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.owner(turn);
    if (try principal(turn) != request.principal) return error.CatalogDenied;
    _ = (try self.mutationStatus(allocator, turn, request.principal, request)) orelse return error.TableWriteNotFound;
    var scratch: [c.fuze.TableSchema.max_columns]c.fuze.Types.Values.Cell = undefined;
    return (try request.route(allocator, self.configuration.scope, &scratch)).cancel(allocator, turn);
}
pub fn cleanupMutation(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, request: DmlRequest) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.owner(turn);
    if (try principal(turn) != request.principal) return error.CatalogDenied;
    const result = (try self.mutationStatus(allocator, turn, request.principal, request)) orelse return error.TableWriteNotFound;
    return s.TableCleanup.step(turn, result.reference);
}
/// Capture a schema-bound data source under independent current read permission.
/// A caller must retain the native source cut for subsequent row reads.
pub fn readDefinition(self: Self, allocator: std.mem.Allocator, source: anytype, who: u64, id: u64, expected: s.TablePages.Reference) !Definition {
    return self.readDefinitionDiagnostic(allocator, source, who, id, expected, null);
}
pub const DefinitionMismatch = struct { expected: s.TablePages.Reference, actual: s.TablePages.Reference };
/// Copy exact mismatch evidence at the authorized owner check. No later read is
/// needed to explain a stale declaration, and no current row data is disclosed.
pub fn readDefinitionDiagnostic(self: Self, allocator: std.mem.Allocator, source: anytype, who: u64, id: u64, expected: s.TablePages.Reference, diagnostic: ?*?DefinitionMismatch) !Definition {
    if (diagnostic) |detail| detail.* = null;
    _ = try self.authorize(source, who, .inspect);
    _ = try self.authorizeObject(source, who, id, .read);
    // These exact identities are already known from the authorized declaration.
    // Acquiring them together does not replace any lifecycle/commitment check.
    const Source = @typeInfo(@TypeOf(source)).pointer.child;
    if (comptime @hasDecl(Source, "prefetch")) try source.prefetch(&.{
        self.key('O', id, 0),
        Store.key(id, 'd', 0),
        Store.key(id, if (expected.spec.length <= p.Value.max_bytes) 'i' else 'r', expected.id),
        s.TableHead.key(id),
    });
    const current = (try self.object(source, id)) orelse return error.TableNotFound;
    if (current.state != .live) return error.TableRetired;
    if (!std.meta.eql(current.metadata, expected)) {
        if (diagnostic) |detail| detail.* = .{ .expected = expected, .actual = current.metadata };
        return error.CatalogDefinitionChanged;
    }
    return self.resolve(allocator, source, current, try self.metadata(source, current));
}

/// Resolve the command's accepted immutable metadata under current policy.
/// The enclosing native caller supplies authenticated `who`; this read helper
/// does not grant execution merely because a header names an allowed principal.
pub fn commandBasis(self: Self, allocator: std.mem.Allocator, source: anytype, who: u64, header: c.TableCommand.Header, purpose: enum { inspect, execute }) !?c.TableCommand.ResolvedBasis {
    var scoped = self;
    scoped.namespace = header.namespace;
    const Source = @typeInfo(@TypeOf(source)).pointer.child;
    if (comptime @hasDecl(Source, "prefetch")) try source.prefetch(&.{ self.key('c', 0, 0), self.key('O', header.object, 0), self.key('S', header.namespace, 0) });
    _ = try self.authorizeDatabase(source, who);
    if (who != header.principal) return error.CatalogDenied;
    try header.validate();
    try self.scope(header.scope);
    if (header.owner != self.configuration.owner) return error.CatalogOwnerChanged;
    if (purpose == .execute) _ = try scoped.authorizeObject(source, who, header.object, header.right()) else if (header.kind != .create) _ = try self.authorizeObject(source, who, header.object, .inspect);
    if (header.metadata.id == 0) return null;
    if (comptime @hasDecl(Source, "prefetch")) {
        // All addresses follow the authenticated header. Acquire bounded
        // metadata together; every identity/lifecycle check below still runs.
        const keys = [_]p.Value{
            Store.key(header.object, 'd', 0),
            Store.key(header.object, if (header.metadata.spec.length <= p.Value.max_bytes) 'i' else 'r', header.metadata.id),
            self.key('O', header.object, 0),
            s.TableHead.key(header.object),
        };
        try source.prefetch(keys[0..if (purpose == .execute) keys.len else 2]);
    }
    const record = try (Store{ .scope = self.configuration.scope, .object = header.object }).read(source, header.metadata);
    const needs_schema = header.kind == .alter or header.kind == .insert or header.kind == .update or header.kind == .delete;
    if (comptime @hasDecl(Source, "prefetch")) {
        // The accepted-definition receipt and original schema are independent
        // reads at this exact cut. Neither the prefetch nor its cache is policy.
        const keys = [_]p.Value{
            self.key('o', record.principal, record.operation),
            s.TablePages.key(record.object, 'd', 0),
            s.TablePages.key(record.object, 'b', 0),
        };
        try source.prefetch(keys[0..if (needs_schema) keys.len else 1]);
    }
    if (!try self.acceptedDefinition(source, header.object, header.metadata, record)) return error.CatalogDefinitionMissing;
    return .{ .record = record, .schema = if (needs_schema) try record.readSchema(allocator, source) else null };
}
