//! Catalog-owned schema names and lifecycle. Native authority owns role/grant
//! state. DROP scans one durable page per turn and fences concurrent Table
//! admissions through the namespace revision; it never locks the namespace.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const a = c.TableAuthority;
const r = c.Records;
const m = c.TableCatalogRecords;
const s = c.station;
const Self = @This();
configuration: m.Configuration,
registration: ?*?p.Authorization.Action = null,

pub const Request = struct {
    scope: m.Scope,
    principal: u64,
    operation: u64,
    schema: u64,
    expected_revision: u64,
    action: union(enum(u8)) { create: struct { name: a.Name, owner: u64 } = 1, rename: a.Name = 2, drop: void = 3 },
    pub fn validate(self: Request) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.operation);
        try c.Model.nativeId(self.schema);
        if (self.principal > p.max_counter or self.expected_revision > p.max_counter or (self.action == .create) != (self.expected_revision == 0)) return error.InvalidSchemaCommand;
        switch (self.action) {
            .create => |value| {
                try value.name.validate();
                try p.Authorization.roleId(value.owner);
            },
            .rename => |name| try name.validate(),
            .drop => {},
        }
    }
    pub fn digest(self: Request) ![32]u8 {
        return c.Model.fingerprint(try r.encode('H', self));
    }
};
pub const Outcome = struct {
    scope: m.Scope,
    principal: u64,
    operation: u64,
    schema: u64,
    digest: [32]u8,
    admitted_input: u64,
    completed_input: u64 = 0,
    state: enum(u8) { scanning = 1, applied = 2, rejected = 3 },
    reason: enum(u8) { none = 0, name_conflict = 1, identity_conflict = 2, stale_schema = 3, not_empty = 4 } = .none,
    after_object: u64 = 0,
    pub fn validate(self: Outcome) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.operation);
        try c.Model.nativeId(self.schema);
        try c.Model.nativeId(self.admitted_input);
        if (self.principal > p.max_counter or self.completed_input > p.max_counter or (self.state == .scanning) != (self.completed_input == 0) or (self.state == .rejected) != (self.reason != .none)) return error.InvalidSchemaOutcome;
        if (self.completed_input != 0 and self.completed_input < self.admitted_input) return error.InvalidSchemaOutcome;
    }
};
pub const Cursor = struct { scope: m.Scope, revision: u64, after: u64 };
pub const Page = struct { schemas: [p.Growth.page_size]?a.Schema = @splat(null), next: ?Cursor = null, revision: u64 };

fn key(self: Self, tag: u8, id: u64, revision: u64) p.Value {
    return r.key(self.configuration.scope.catalog, tag, id, revision);
}
fn check(self: Self, source: anytype) !void {
    const stored = try r.decode(m.Configuration, 'C', (try source.read(self.key('c', 0, 0))) orelse return error.CatalogNotInitialized);
    if (!std.meta.eql(stored, self.configuration) or source.view.resource != stored.scope.resource) return error.CatalogConfigurationChanged;
}
pub fn record(self: Self, source: anytype, id: u64) !?a.Schema {
    const value = (try source.read(self.key('S', id, 0))) orelse return null;
    const schema = try r.decode(a.Schema, 'S', value);
    if (schema.id != id or !std.meta.eql(schema.scope, self.configuration.scope)) return error.InvalidCatalogBinding;
    return schema;
}
fn nameKey(self: Self, name: a.Name, id: u64) !p.Value {
    try name.validate();
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(name.slice(), &digest, .{});
    var bytes: [32]u8 = undefined;
    bytes[0..11].* = r.prefix(self.configuration.scope.catalog, 'n').data[0..11].*;
    @memcpy(bytes[11..24], digest[0..13]);
    std.mem.writeInt(u64, bytes[24..32], id, .big);
    return p.Value.init(&bytes);
}
fn bound(self: Self, source: anytype, name: a.Name) !?a.Schema {
    const full = try self.nameKey(name, 1);
    const prefix = try p.Value.init(full.data[0..24]);
    var after = prefix;
    var found: ?a.Schema = null;
    var pages: u16 = 0;
    while (true) {
        if (pages == 4096) return error.AuthorizationBudgetExceeded;
        pages += 1;
        const page = try source.page(after);
        try c.Inspection.validatePage(page, after, source.view.revision);
        var ended = false;
        for (page.entries) |slot| {
            const entry = slot orelse break;
            if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) {
                ended = true;
                break;
            }
            if (entry.key.len != 32) return error.InvalidCatalogBinding;
            const id = std.mem.readInt(u64, entry.key.data[24..32], .big);
            const schema = (try self.record(source, id)) orelse return error.CatalogSchemaMissing;
            if (schema.retired or !(try self.nameKey(schema.name, id)).eql(entry.key)) return error.InvalidCatalogBinding;
            const binding = try r.decode(m.Binding, 'N', entry.value);
            if (binding.object != id or !std.meta.eql(binding.scope, schema.scope)) return error.InvalidCatalogBinding;
            if (std.mem.eql(u8, schema.name.slice(), name.slice())) {
                if (found != null) return error.InvalidCatalogBinding;
                found = schema;
            }
        }
        if (ended or page.next == null) break;
        after = page.next.?;
    }
    // Initialization publishes its explicit public schema with configuration in
    // one bounded turn. It needs no additional name-index write; later renames
    // and name reuse use the same ordinary index as all other schemas.
    if (try self.record(source, self.configuration.authority.initial_schema)) |initial| {
        if (!initial.retired and std.mem.eql(u8, initial.name.slice(), name.slice())) {
            if (found) |other| if (other.id != initial.id) return error.InvalidCatalogBinding;
            return initial;
        }
    }
    return found;
}
fn require(self: Self, source: anytype, who: u64, schema: ?a.Schema, ownership: bool) !p.Authorization.Verified {
    const subject = try a.subjectFor(source, who);
    var guard = try a.guard(subject, self.configuration.authority, null, null, .database);
    if (schema) |value| guard.requirements[1] = .{ .object = a.reference(value.authorization), .privileges = if (ownership) 0 else a.usage | a.create, .access = if (ownership) .ownership else .visible };
    return a.require(source, guard);
}
pub fn lookup(self: Self, source: anytype, who: u64, name: a.Name) !?a.Schema {
    try self.check(source);
    _ = try self.require(source, who, null, false);
    const schema = (try self.bound(source, name)) orelse return null;
    _ = self.require(source, who, schema, false) catch |err| return if (err == error.CatalogDenied) null else err;
    return schema;
}
pub fn list(self: Self, source: anytype, who: u64, cursor: ?Cursor) !Page {
    try self.check(source);
    _ = try self.require(source, who, null, false);
    if (cursor) |value| {
        try c.Model.nativeId(value.after);
        try c.Model.nativeId(value.revision);
        if (!std.meta.eql(value.scope, self.configuration.scope) or value.revision != source.view.revision) return error.CatalogSourceChanged;
    }
    const after = self.key('S', if (cursor) |value| value.after else 0, 0);
    const page = try source.page(after);
    try c.Inspection.validatePage(page, after, source.view.revision);
    const prefix = r.prefix(self.configuration.scope.catalog, 'S');
    var result: Page = .{ .revision = source.view.revision };
    var count: usize = 0;
    var last: u64 = 0;
    var ended = false;
    for (page.entries) |slot| {
        const entry = slot orelse break;
        if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) {
            ended = true;
            break;
        }
        const schema = try r.decode(a.Schema, 'S', entry.value);
        if (!entry.key.eql(self.key('S', schema.id, 0)) or !std.meta.eql(schema.scope, self.configuration.scope)) return error.InvalidCatalogBinding;
        last = schema.id;
        if (schema.retired) continue;
        _ = self.require(source, who, schema, false) catch |err| {
            if (err == error.CatalogDenied) continue;
            return err;
        };
        result.schemas[count] = schema;
        count += 1;
    }
    if (!ended and page.next != null and last != 0) result.next = .{ .scope = self.configuration.scope, .revision = source.view.revision, .after = last };
    return result;
}
fn outcome(self: Self, source: anytype, principal: u64, operation: u64) !?Outcome {
    const value = (try source.read(self.key('h', principal, operation))) orelse return null;
    const result = try r.decode(Outcome, 'h', value);
    if (!std.meta.eql(result.scope, self.configuration.scope) or result.principal != principal or result.operation != operation) return error.InvalidSchemaOutcome;
    return result;
}
pub fn prepare(self: Self, source: anytype, request: Request) !void {
    try request.validate();
    try self.check(source);
    if (!std.meta.eql(request.scope, self.configuration.scope)) return error.CatalogScopeChanged;
    const current = try self.record(source, request.schema);
    if (request.action == .create) {
        var guard = try a.guard(try a.subjectFor(source, request.principal), self.configuration.authority, null, null, .create_schema);
        guard.selectable = request.action.create.owner;
        _ = try a.require(source, guard);
    } else {
        _ = try self.require(source, request.principal, current orelse return error.CatalogSchemaMissing, true);
    }
    if (try self.outcome(source, request.principal, request.operation)) |prior| {
        if (prior.schema != request.schema or !std.mem.eql(u8, &prior.digest, &try request.digest())) return error.CatalogIdentityConflict;
        return;
    }
    switch (request.action) {
        .create => |value| {
            if (current != null) return error.CatalogIdentityConflict;
            if (try self.bound(source, value.name) != null) return error.CatalogSchemaNameExists;
        },
        .rename, .drop => {
            const schema = current.?;
            if (schema.retired or schema.revision != request.expected_revision) return error.CatalogDefinitionChanged;
            if (request.action == .rename) if (try self.bound(source, request.action.rename)) |other| if (other.id != schema.id) return error.CatalogSchemaNameExists;
        },
    }
}
pub fn status(self: Self, source: anytype, who: u64, request: Request) !?Outcome {
    try request.validate();
    try self.check(source);
    if (!std.meta.eql(request.scope, self.configuration.scope)) return error.CatalogDenied;
    const schema = try self.record(source, request.schema);
    if (request.action == .create) {
        _ = try a.require(source, try a.guard(try a.subjectFor(source, who), self.configuration.authority, null, null, .create_schema));
    } else {
        _ = try self.require(source, who, schema orelse return error.CatalogSchemaMissing, true);
    }
    const result = (try self.outcome(source, request.principal, request.operation)) orelse return null;
    if (!std.mem.eql(u8, &result.digest, &try request.digest())) return error.CatalogIdentityConflict;
    return result;
}
fn save(self: Self, turn: *s.Turn, result: Outcome) !Outcome {
    try turn.write(self.key('h', result.principal, result.operation), try r.encode('h', result));
    return result;
}
fn close(self: Self, turn: *s.Turn, before: Outcome, reason: @FieldType(Outcome, "reason")) !Outcome {
    var result = before;
    result.state = if (reason == .none) .applied else .rejected;
    result.reason = reason;
    result.completed_input = turn.delivery.input.position;
    return self.save(turn, result);
}
pub fn apply(self: Self, turn: *s.Turn, request: Request) !Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    try request.validate();
    try self.check(turn);
    if (turn.delivery.realm != request.scope.realm or turn.delivery.pid != self.configuration.owner or !std.meta.eql(request.scope, self.configuration.scope)) return error.CatalogOwnerChanged;
    const continuation = turn.delivery.input.origin == .process;
    if (continuation) {
        if (turn.delivery.input.origin.process.pid != self.configuration.owner) return error.CatalogDenied;
    } else if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != request.principal) return error.CatalogDenied;
    const prior = try self.outcome(turn, request.principal, request.operation);
    if (prior) |value| {
        if (value.schema != request.schema or !std.mem.eql(u8, &value.digest, &try request.digest())) return error.CatalogIdentityConflict;
        try turn.bindAuthorizationSubject(.{ .accepted = .{ .pid = self.configuration.owner, .input = value.admitted_input, .principal = request.principal } });
    } else if (continuation) return error.CatalogOperationNotFound;
    const current = try self.record(turn, request.schema);
    if (request.action == .create) {
        var guard = try a.guard(try a.subjectFor(turn, request.principal), self.configuration.authority, null, null, .create_schema);
        guard.selectable = request.action.create.owner;
        _ = try a.require(turn, guard);
    } else {
        _ = try self.require(turn, request.principal, current orelse return error.CatalogSchemaMissing, true);
    }
    if (prior) |value| if (value.state != .scanning) return value;
    var pending: Outcome = prior orelse .{ .scope = request.scope, .principal = request.principal, .operation = request.operation, .schema = request.schema, .digest = try request.digest(), .admitted_input = turn.originalAuthorizedInput(), .state = .scanning };
    if (request.action == .create) {
        if (current != null) return self.close(turn, pending, .identity_conflict);
        const creation = request.action.create;
        if (try self.bound(turn, creation.name) != null) return self.close(turn, pending, .name_conflict);
        const profile = self.configuration.authority;
        const binding = try a.binding(request.scope, .schema, request.schema);
        const native = (try turn.authorizationBinding(profile.schema_domain, binding)) orelse {
            if (self.registration) |slot| slot.* = .{ .register_object = .{ .domain = profile.schema_domain, .owner = creation.owner, .schema = a.reference(profile.database), .binding = binding } };
            return error.CatalogRegistrationRequired;
        };
        try a.validateObject(profile, request.scope, .schema, request.schema, a.reference(profile.database), native);
        if (native.owner != creation.owner) return error.CatalogIdentityConflict;
        const created: a.Schema = .{ .scope = request.scope, .id = request.schema, .authorization = native.reference.id, .name = creation.name, .revision = 1 };
        try turn.write(self.key('S', created.id, 0), try r.encode('S', created));
        try turn.write(try self.nameKey(created.name, created.id), try r.encode('N', m.Binding{ .scope = created.scope, .object = created.id }));
        return self.close(turn, pending, .none);
    }
    var schema = current.?;
    if (schema.retired or schema.revision != request.expected_revision) return self.close(turn, pending, .stale_schema);
    if (request.action == .rename) {
        const name = request.action.rename;
        if (std.mem.eql(u8, name.slice(), schema.name.slice())) return self.close(turn, pending, .none);
        if (try self.bound(turn, name) != null) return self.close(turn, pending, .name_conflict);
        try turn.write(try self.nameKey(schema.name, schema.id), null);
        schema.name = name;
        schema.revision = std.math.add(u64, schema.revision, 1) catch return error.CatalogCapacity;
        try turn.write(self.key('S', schema.id, 0), try r.encode('S', schema));
        try turn.write(try self.nameKey(name, schema.id), try r.encode('N', m.Binding{ .scope = schema.scope, .object = schema.id }));
        return self.close(turn, pending, .none);
    }
    if (prior == null) return self.save(turn, pending);
    const after = self.key('O', pending.after_object, 0);
    var committed = turn.committed();
    const page = try committed.page(after);
    try c.Inspection.validatePage(page, after, turn.view.revision);
    const prefix = r.prefix(request.scope.catalog, 'O');
    var ended = false;
    for (page.entries) |slot| {
        const entry = slot orelse break;
        if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) {
            ended = true;
            break;
        }
        const object = try r.decode(m.Object, 'O', entry.value);
        if (!std.meta.eql(object.scope, request.scope) or !entry.key.eql(self.key('O', object.object, 0))) return error.InvalidCatalogObject;
        pending.after_object = object.object;
        if (object.namespace == schema.id and object.state != .retired) return self.close(turn, pending, .not_empty);
    }
    if (!ended and page.next != null) return self.save(turn, pending);
    schema.retired = true;
    schema.revision = std.math.add(u64, schema.revision, 1) catch return error.CatalogCapacity;
    try turn.write(self.key('S', schema.id, 0), try r.encode('S', schema));
    try turn.write(try self.nameKey(schema.name, schema.id), null);
    return self.close(turn, pending, .none);
}

/// A CREATE admission changes the namespace revision in the same native turn
/// as its initializing Table record. A concurrent schema DROP must revalidate.
pub fn admitTable(self: Self, turn: *s.Turn, id: u64) !void {
    var schema = (try self.record(turn, id)) orelse return error.CatalogSchemaMissing;
    if (schema.retired) return error.CatalogSchemaMissing;
    schema.revision = std.math.add(u64, schema.revision, 1) catch return error.CatalogCapacity;
    try turn.write(self.key('S', id, 0), try r.encode('S', schema));
}
