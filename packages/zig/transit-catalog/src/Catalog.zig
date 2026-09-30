//! Conditional creation in the existing one-resource/four-mutation boundary.
//! Native authority owns commit/fencing; this helper never performs I/O itself.
const std = @import("std");
const c = @import("root.zig");
const m = c.Model;
const r = c.Records;
const p = c.protocol;
const s = c.station;
const Self = @This();
configuration: m.Configuration,

pub const Cursor = struct { scope: m.Scope, resource_revision: u64, after: c.fuze.model.Name };
pub const Page = struct {
    resource_revision: u64,
    entries: [p.Growth.page_size]?m.Definition = @splat(null),
    next: ?Cursor = null,
};

fn key(self: Self, tag: u8, id: u64, revision: u64) p.Value {
    return r.key(self.configuration.scope.catalog, tag, id, revision);
}
fn scope(self: Self, actual: m.Scope) !void {
    if (!std.meta.eql(self.configuration.scope, actual)) return error.CatalogScopeChanged;
}
fn owner(self: Self, turn: *s.Turn) !void {
    try self.configuration.validate();
    if (turn.view.resource != self.configuration.scope.resource or turn.delivery.pid != self.configuration.owner or turn.delivery.realm != self.configuration.scope.realm) return error.CatalogOwnerChanged;
}
fn principal(turn: *s.Turn) !u64 {
    return switch (turn.delivery.input.origin) {
        .external => |origin| origin.principal,
        else => error.CatalogDenied,
    };
}
fn administrator(self: Self, turn: *s.Turn) !void {
    if (try principal(turn) != self.configuration.administrator) return error.CatalogDenied;
}
fn check(self: Self, turn: *s.Turn) !void {
    try self.owner(turn);
    const value = (try turn.read(self.key('c', 0, 0))) orelse return error.CatalogNotInitialized;
    if (!std.meta.eql(self.configuration, try r.decode(m.Configuration, 'c', value))) return error.CatalogConfigurationChanged;
}
fn policy(self: Self, turn: *s.Turn, who: u64) !?m.Policy {
    const value = (try turn.read(self.key('p', who, 0))) orelse return null;
    const result = try r.decode(m.Policy, 'p', value);
    try self.scope(result.scope);
    if (result.principal != who) return error.InvalidCatalogPolicy;
    return result;
}
fn authorize(self: Self, turn: *s.Turn, create: bool) !u64 {
    try self.check(turn);
    const who = try principal(turn);
    const rights = (try self.policy(turn, who)) orelse return error.CatalogDenied;
    if (if (create) !rights.create else !rights.inspect) return error.CatalogDenied;
    return who;
}

/// Explicit administrator initialization. Repeating it cannot reset a policy.
/// Initialize in a separate turn before creation; both operations share bounds.
pub fn initialize(self: Self, turn: *s.Turn) !void {
    try self.owner(turn);
    try self.administrator(turn);
    const config = try r.encode('c', self.configuration);
    if (try turn.read(self.key('c', 0, 0))) |value| {
        _ = try r.decode(m.Configuration, 'c', value);
        if (!value.eql(config)) return error.CatalogConfigurationChanged;
        _ = (try self.policy(turn, self.configuration.administrator)) orelse return error.InvalidCatalogPolicy;
        return;
    }
    // A missing configuration is not permission to adopt orphan catalog state.
    // One ordered page suffices to prove this namespace empty at the captured cut.
    const start = r.prefix(self.configuration.scope.catalog, 0);
    const page = try turn.page(start);
    try validatePage(page, start, turn.view.revision);
    if (page.entries[0]) |entry| {
        if (std.mem.startsWith(u8, entry.key.slice(), start.data[0..10])) return error.CatalogAlreadyPopulated;
    } else if (page.next != null) return error.InvalidCatalogPage;
    const before = turn.decision;
    errdefer turn.decision = before;
    try turn.write(self.key('c', 0, 0), config);
    try turn.write(self.key('p', self.configuration.administrator, 0), try r.encode('p', m.Policy{ .scope = self.configuration.scope, .principal = self.configuration.administrator, .revision = 1, .inspect = true, .create = true }));
}

/// Conditional application policy, independent of current native resource grants.
pub fn setPolicy(self: Self, turn: *s.Turn, expected_revision: u64, next: m.Policy) !void {
    try next.validate();
    try self.scope(next.scope);
    if (next.revision != try std.math.add(u64, expected_revision, 1)) return error.InvalidCatalogPolicy;
    try self.check(turn);
    try self.administrator(turn);
    const old = try self.policy(turn, next.principal);
    if (old) |previous| if (std.meta.eql(previous, next)) return;
    if ((if (old) |previous| previous.revision else 0) != expected_revision) return error.CatalogPolicyConflict;
    try turn.write(self.key('p', next.principal, 0), try r.encode('p', next));
}

fn readReceipt(self: Self, turn: *s.Turn, who: u64, operation: u64) !?m.Receipt {
    const bytes = (try turn.read(self.key('o', who, operation))) orelse return null;
    const result = try r.decode(m.Receipt, 'o', bytes);
    try self.scope(result.request.scope);
    if (result.principal != who or result.request.operation != operation) return error.InvalidCatalogReceipt;
    return result;
}
pub fn receipt(self: Self, turn: *s.Turn, operation: u64) !?m.Receipt {
    if (operation == 0) return error.InvalidCatalogIdentity;
    return self.readReceipt(turn, try self.authorize(turn, false), operation);
}
fn record(self: Self, turn: *s.Turn, value: m.Receipt) !m.Receipt {
    try turn.write(self.key('o', value.principal, value.request.operation), try r.encode('o', value));
    return value;
}

/// All four writes and input acceptance commit together. Conflicts retain a
/// terminal receipt; exact retries never acquire a newly available name/ID.
pub fn createTable(self: Self, turn: *s.Turn, request: m.CreateTable) !m.Receipt {
    try request.validate();
    try self.scope(request.scope);
    const who = try self.authorize(turn, true);
    if (try self.readReceipt(turn, who, request.operation)) |old| {
        if (!std.meta.eql(old.request, request)) return error.CatalogIdentityConflict;
        return old;
    }
    var result: m.Receipt = .{ .request = request, .principal = who, .input = turn.delivery.input.position, .outcome = .applied };
    const name_key = try r.nameKey(request.scope.catalog, request.name);
    // Refuse adoption, including a physical Table with matching schema.
    if (try turn.read(name_key)) |value| {
        const binding = try r.decode(m.Binding, 'n', value);
        _ = try self.resolve(turn, request.name, binding);
        result.outcome = .name_conflict;
    } else if (try turn.read(self.key('d', request.object, 1))) |value| {
        const existing = try r.decode(m.Definition, 'd', value);
        try self.scope(existing.scope);
        if (existing.object != request.object or existing.revision != 1) return error.InvalidCatalogDefinition;
        result.outcome = .object_conflict;
    } else if (try turn.read(s.Table.descriptorKey(request.table))) |value| {
        _ = try s.Table.decodeSchema(value);
        result.outcome = .table_conflict;
    }
    const before = turn.decision;
    errdefer turn.decision = before;
    if (result.outcome != .applied) return self.record(turn, result);
    // An absent descriptor must not make pre-existing row bytes into a new
    // empty Table. Check one ordered page at this same captured commit basis.
    const row = s.Table.rowKey(request.table, std.math.minInt(i64));
    const row_prefix = try p.Value.init(row.slice()[0..6]);
    const rows = try turn.page(row_prefix);
    try validatePage(rows, row_prefix, turn.view.revision);
    if (rows.entries[0]) |entry| {
        if (std.mem.startsWith(u8, entry.key.slice(), row_prefix.slice())) return error.CatalogSourceAlreadyPopulated;
    }
    const created = try m.Definition.created(request, who, result.input);
    const binding: m.Binding = .{ .scope = request.scope, .object = request.object, .revision = created.revision, .digest = try created.digest() };
    _ = try s.Table.create(turn, request.table, request.schema);
    try turn.write(self.key('d', request.object, 1), try r.encode('d', created));
    try turn.write(name_key, try r.encode('n', binding));
    return self.record(turn, result);
}

fn readDefinition(self: Self, turn: *s.Turn, object: u64, revision: u64) !?m.Definition {
    const bytes = (try turn.read(self.key('d', object, revision))) orelse return null;
    const result = try r.decode(m.Definition, 'd', bytes);
    try self.scope(result.scope);
    if (result.object != object or result.revision != revision) return error.InvalidCatalogDefinition;
    return result;
}
pub fn definition(self: Self, turn: *s.Turn, object: u64, revision: u64) !?m.Definition {
    if (object == 0 or revision == 0) return error.InvalidCatalogIdentity;
    _ = try self.authorize(turn, false);
    return self.readDefinition(turn, object, revision);
}
fn resolve(self: Self, turn: *s.Turn, name: c.fuze.model.Name, binding: m.Binding) !m.Definition {
    try self.scope(binding.scope);
    const result = (try self.readDefinition(turn, binding.object, binding.revision)) orelse return error.CatalogDefinitionMissing;
    if (!std.meta.eql(result.name, name) or !std.mem.eql(u8, &binding.digest, &try result.digest())) return error.CatalogDefinitionChanged;
    switch (result.source) {
        .table => |table| if (!std.meta.eql((try s.Table.open(turn, table.id)).schema, table.schema)) return error.CatalogSourceChanged,
    }
    return result;
}
pub fn lookup(self: Self, turn: *s.Turn, name: c.fuze.model.Name) !?m.Definition {
    const name_key = try r.nameKey(self.configuration.scope.catalog, name);
    _ = try self.authorize(turn, false);
    const value = (try turn.read(name_key)) orelse return null;
    return try self.resolve(turn, name, try r.decode(m.Binding, 'n', value));
}

/// One bounded committed metadata page. Recheck current policy on every call;
/// a changed resource revision requires restarting, never mixed-basis results.
pub fn list(self: Self, turn: *s.Turn, cursor: ?Cursor) !Page {
    _ = try self.authorize(turn, false);
    const namespace = r.prefix(self.configuration.scope.catalog, 'n');
    const after = if (cursor) |value| blk: {
        try self.scope(value.scope);
        if (value.resource_revision != turn.view.revision) return error.CatalogCursorChanged;
        break :blk try r.nameKey(value.scope.catalog, value.after);
    } else namespace;
    const entries = try turn.page(after);
    try validatePage(entries, after, turn.view.revision);
    var result: Page = .{ .resource_revision = turn.view.revision };
    for (entries.entries, 0..) |slot, index| {
        const entry = slot orelse break;
        if (!std.mem.startsWith(u8, entry.key.slice(), namespace.slice())) {
            result.next = null;
            return result;
        }
        const name = try c.fuze.model.Name.init(entry.key.slice()[namespace.len..]);
        result.entries[index] = try self.resolve(turn, name, try r.decode(m.Binding, 'n', entry.value));
        if (entries.next != null) result.next = .{ .scope = self.configuration.scope, .resource_revision = turn.view.revision, .after = name };
    }
    return result;
}
fn validatePage(entries: s.Turn.Page, after: p.Value, revision: u64) !void {
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
