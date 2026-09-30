//! Deterministic metadata validation shared by private turns and signed callers.
//! The source supplies one authorized resource cut; this grants no read rights.
const std = @import("std");
const c = @import("root.zig");
const m = c.Model;
const r = c.Records;
const p = c.protocol;
const Self = @This();
configuration: m.Configuration,
principal: u64,

pub const Cursor = struct { scope: m.Scope, resource_revision: u64, after: c.fuze.model.Name };
pub const Page = struct {
    resource_revision: u64,
    entries: [p.Growth.page_size]?m.Definition = @splat(null),
    next: ?Cursor = null,
};
fn scope(self: Self, actual: m.Scope) !void {
    if (!std.meta.eql(self.configuration.scope, actual)) return error.CatalogScopeChanged;
}
fn key(self: Self, tag: u8, id: u64, revision: u64) p.Value {
    return r.key(self.configuration.scope.catalog, tag, id, revision);
}
fn authorize(self: Self, source: anytype) !void {
    try self.configuration.validate();
    if (self.principal > p.max_counter) return error.InvalidCatalogIdentity;
    if (source.view.resource != self.configuration.scope.resource) return error.CatalogScopeChanged;
    const config = (try source.read(self.key('c', 0, 0))) orelse return error.CatalogNotInitialized;
    if (!std.meta.eql(self.configuration, try r.decode(m.Configuration, 'c', config))) return error.CatalogConfigurationChanged;
    const bytes = (try source.read(self.key('p', self.principal, 0))) orelse return error.CatalogDenied;
    const policy = try r.decode(m.Policy, 'p', bytes);
    try self.scope(policy.scope);
    if (policy.principal != self.principal) return error.InvalidCatalogPolicy;
    if (!policy.inspect) return error.CatalogDenied;
}
fn readDefinition(self: Self, source: anytype, object: u64, revision: u64) !?m.Definition {
    const bytes = (try source.read(self.key('d', object, revision))) orelse return null;
    const result = try r.decode(m.Definition, 'd', bytes);
    try self.scope(result.scope);
    if (result.object != object or result.revision != revision) return error.InvalidCatalogDefinition;
    return result;
}
pub fn definition(self: Self, source: anytype, object: u64, revision: u64) !?m.Definition {
    if (object == 0 or revision == 0) return error.InvalidCatalogIdentity;
    try self.authorize(source);
    return self.readDefinition(source, object, revision);
}
/// Validate an already-authorized binding against its definition/live source.
/// Creation conflict checks use their create permission, not inspect permission.
pub fn resolveBinding(self: Self, source: anytype, name: c.fuze.model.Name, binding: m.Binding) !m.Definition {
    try self.scope(binding.scope);
    const result = (try self.readDefinition(source, binding.object, binding.revision)) orelse return error.CatalogDefinitionMissing;
    if (!std.meta.eql(result.name, name) or !std.mem.eql(u8, &binding.digest, &try result.digest())) return error.CatalogDefinitionChanged;
    switch (result.source) {
        .table => |table| if (!std.meta.eql((try c.station.Table.open(source, table.id)).schema, table.schema)) return error.CatalogSourceChanged,
    }
    return result;
}
pub fn lookup(self: Self, source: anytype, name: c.fuze.model.Name) !?m.Definition {
    const address = try r.nameKey(self.configuration.scope.catalog, name);
    try self.authorize(source);
    const value = (try source.read(address)) orelse return null;
    return try self.resolveBinding(source, name, try r.decode(m.Binding, 'n', value));
}
pub fn list(self: Self, source: anytype, cursor: ?Cursor) !Page {
    try self.authorize(source);
    const namespace = r.prefix(self.configuration.scope.catalog, 'n');
    const after = if (cursor) |value| blk: {
        try self.scope(value.scope);
        if (value.resource_revision != source.view.revision) return error.CatalogCursorChanged;
        break :blk try r.nameKey(value.scope.catalog, value.after);
    } else namespace;
    const entries = try source.page(after);
    try validatePage(entries, after, source.view.revision);
    var result: Page = .{ .resource_revision = source.view.revision };
    for (entries.entries, 0..) |slot, index| {
        const entry = slot orelse break;
        if (!std.mem.startsWith(u8, entry.key.slice(), namespace.slice())) {
            result.next = null;
            return result;
        }
        const name = try c.fuze.model.Name.init(entry.key.slice()[namespace.len..]);
        result.entries[index] = try self.resolveBinding(source, name, try r.decode(m.Binding, 'n', entry.value));
        if (entries.next != null) result.next = .{ .scope = self.configuration.scope, .resource_revision = source.view.revision, .after = name };
    }
    return result;
}
pub fn validatePage(entries: c.station.Turn.Page, after: p.Value, revision: u64) !void {
    var previous = after;
    var ended = false;
    for (entries.entries) |slot| {
        if (slot) |entry| {
            if (ended) return error.InvalidCatalogPage;
            try p.Growth.validateKey(entry.key);
            try entry.value.validate();
            if (entry.revision > revision or std.mem.order(u8, previous.slice(), entry.key.slice()) != .lt) return error.InvalidCatalogPage;
            previous = entry.key;
        } else ended = true;
    }
    if (entries.next) |next| if (previous.eql(after) or !previous.eql(next)) return error.InvalidCatalogPage;
}
