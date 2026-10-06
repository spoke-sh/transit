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
pub const Definition = struct {
    metadata: Meta.Record,
    head: s.TableHead,
    schema: c.fuze.TableSchema.Owned,
    pub fn deinit(self: *Definition) void {
        self.schema.deinit();
        self.* = undefined;
    }
};
pub const Cursor = struct { scope: m.Scope, resource_revision: u64, after_object: u64 };
pub const Page = struct {
    entries: [p.Growth.page_size]?Definition = @splat(null),
    next: ?Cursor = null,
    resource_revision: u64,
    pub fn deinit(self: *Page) void {
        for (&self.entries) |*slot| if (slot.*) |*entry| entry.deinit();
        self.* = undefined;
    }
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
    if (try principal(turn) != self.configuration.administrator) return error.CatalogDenied;
}
fn check(self: Self, source: anytype) !void {
    try self.configuration.validate();
    if (source.view.resource != self.configuration.scope.resource) return error.CrossResourceTransaction;
    const config = try r.decode(m.Configuration, 'C', (try source.read(self.key('c', 0, 0))) orelse return error.CatalogNotInitialized);
    if (!std.meta.eql(config, self.configuration)) return error.CatalogConfigurationChanged;
}
fn policy(self: Self, source: anytype, who: u64) !?m.Policy {
    if (who > p.max_counter) return error.InvalidCatalogPolicy;
    const rights = try r.decode(m.Policy, 'P', (try source.read(self.key('p', who, 0))) orelse return null);
    try self.scope(rights.scope);
    if (rights.principal != who) return error.InvalidCatalogPolicy;
    return rights;
}
pub fn authorize(self: Self, source: anytype, who: u64, right: m.Right) !m.Policy {
    try self.check(source);
    const rights = (try self.policy(source, who)) orelse return error.CatalogDenied;
    if (!rights.permits(right)) return error.CatalogDenied;
    return rights;
}
pub fn initialize(self: Self, turn: *s.Turn) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.administrator(turn);
    const prefix = r.prefix(self.configuration.scope.catalog, 0);
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        if (std.mem.startsWith(u8, mutation.key.slice(), prefix.data[0..10])) return error.QueryAfterMutation;
    };
    if (try turn.read(self.key('c', 0, 0)) != null) {
        try self.check(turn);
        _ = (try self.policy(turn, self.configuration.administrator)) orelse return error.InvalidCatalogPolicy;
        return;
    }
    var committed = turn.committed();
    const page = try committed.page(prefix);
    try c.Inspection.validatePage(page, prefix, turn.view.revision);
    if (page.entries[0]) |entry| if (std.mem.startsWith(u8, entry.key.slice(), prefix.data[0..10])) return error.CatalogAlreadyPopulated;
    try turn.write(self.key('c', 0, 0), try r.encode('C', self.configuration));
    try turn.write(self.key('p', self.configuration.administrator, 0), try r.encode('P', try m.Policy.administrator(self.configuration.scope, self.configuration.administrator)));
}
pub fn setPolicy(self: Self, turn: *s.Turn, expected_revision: u64, next: m.Policy) !void {
    try self.administrator(turn);
    try self.check(turn);
    try next.validate();
    try self.scope(next.scope);
    if (next.revision != (std.math.add(u64, expected_revision, 1) catch return error.InvalidCatalogPolicy)) return error.InvalidCatalogPolicy;
    const old = try self.policy(turn, next.principal);
    if (old) |previous| if (std.meta.eql(previous, next)) return;
    if ((if (old) |previous| previous.revision else 0) != expected_revision) return error.CatalogPolicyConflict;
    try turn.write(self.key('p', next.principal, 0), try r.encode('P', next));
}
fn object(self: Self, source: anytype, id: u64) !?m.Object {
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
const Bound = struct { object: m.Object, metadata: Meta.Record };
fn binding(self: Self, source: anytype, name: Meta.Name) !?Bound {
    try name.validate();
    const digest = try name.digest();
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
            const actual_digest = try record.name.digest();
            if (!std.mem.eql(u8, actual_digest[0..Meta.name_digest_bytes], digest[0..Meta.name_digest_bytes])) return error.CatalogDefinitionChanged;
            if (record.name.eql(&name)) {
                if (found != null) return error.InvalidCatalogBinding;
                found = .{ .object = current, .metadata = record };
            }
        }
        cursor = page.next orelse return found;
    }
}
fn resolve(self: Self, allocator: std.mem.Allocator, source: anytype, value: m.Object, record: Meta.Record) !Definition {
    try self.scope(value.scope);
    if (value.state != .live or value.object != record.object or value.metadata.id != record.revision) return error.CatalogDefinitionChanged;
    const head = try s.TableHead.load(source, record.object);
    if (head.retired or !std.meta.eql(head.schema, record.schema)) return error.CatalogSourceChanged;
    var schema = try head.readSchema(allocator, source);
    errdefer schema.deinit();
    if (!std.mem.eql(u8, &try schema.schema.fingerprint(), &record.schema_fingerprint)) return error.CatalogDefinitionChanged;
    return .{ .metadata = record, .head = head, .schema = schema };
}
pub fn lookup(self: Self, allocator: std.mem.Allocator, source: anytype, who: u64, name: Meta.Name) !?Definition {
    _ = try self.authorize(source, who, .inspect);
    const current = (try self.binding(source, name)) orelse return null;
    return try self.resolve(allocator, source, current.object, current.metadata);
}
/// Object-ordered pages are bound to one native revision. Tombstoned and pending
/// creation records advance the cursor without being returned as live Tables.
pub fn list(self: Self, allocator: std.mem.Allocator, source: anytype, who: u64, cursor: ?Cursor) !Page {
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
    errdefer result.deinit();
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
        if (current.state == .live) {
            result.entries[count] = try self.resolve(allocator, source, current, try self.metadata(source, current));
            count += 1;
        }
    }
    if (page.next != null and last != 0) result.next = .{ .scope = self.configuration.scope, .resource_revision = source.view.revision, .after_object = last };
    return result;
}
pub fn setDependency(self: Self, turn: *s.Turn, dependency: m.Dependency, present: bool) !void {
    try self.administrator(turn);
    try self.check(turn);
    try dependency.validate();
    try self.scope(dependency.scope);
    const current = (try self.object(turn, dependency.object)) orelse return error.TableNotFound;
    if (present and (current.state != .live or current.pending_operation != 0)) return error.TableBusy;
    const location = self.key('B', dependency.object, dependency.identity);
    const bytes = try r.encode('B', dependency);
    if (try turn.read(location)) |existing| {
        _ = try r.decode(m.Dependency, 'B', existing);
        if (!existing.eql(bytes)) return error.CatalogDependencyConflict;
        if (!present) try turn.write(location, null);
    } else if (present) try turn.write(location, bytes);
}
fn restrict(self: Self, source: anytype, id: u64) !?m.Dependency {
    const full = self.key('B', id, 0);
    const prefix = try p.Value.init(full.data[0..19]);
    var cursor = prefix;
    while (true) {
        const page = try source.page(cursor);
        try c.Inspection.validatePage(page, cursor, source.view.revision);
        for (page.entries) |slot| {
            const entry = slot orelse break;
            if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return null;
            if (entry.key.len != 27) return error.InvalidCatalogDependency;
            const dependency = try r.decode(m.Dependency, 'B', entry.value);
            try self.scope(dependency.scope);
            if (dependency.object != id or dependency.identity != std.mem.readInt(u64, entry.key.data[19..27], .big)) return error.InvalidCatalogDependency;
            if (dependency.restricts()) return dependency;
        }
        cursor = page.next orelse return null;
    }
}
pub fn blockingDependency(self: Self, source: anytype, who: u64, id: u64) !?m.Dependency {
    _ = try self.authorize(source, who, .inspect);
    _ = (try self.object(source, id)) orelse return error.TableNotFound;
    return self.restrict(source, id);
}
