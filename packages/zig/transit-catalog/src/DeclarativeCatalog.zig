//! Named KV, Document and Computation catalog lifecycles over shared catalog
//! authority. Creation uses an explicit two-phase provisioning/publication
//! transition; RESTRICT dependencies block DROP and retired IDs never rebind.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const a = c.TableAuthority;
const r = c.Records;
const m = c.TableCatalogRecords;
const Meta = c.TableMetadata;
const s = c.station;
const Self = @This();
configuration: m.Configuration,
namespace: ?u64 = null,
registration: ?*?p.Authorization.Action = null,

pub const StateKind = enum(u8) { kv = 2, document = 3, computation = 4 };
pub const ComputationSpec = struct {
    source_object: u64,
    source_revision: u64,
    output_object: u64 = 0,
    pub fn validate(self: ComputationSpec) !void {
        if (self.source_object == 0 or self.source_revision == 0) return error.InvalidCatalogDefinition;
        if (self.output_object != 0 and self.output_object == self.source_object) return error.InvalidCatalogDefinition;
    }
};
pub const Spec = union(StateKind) {
    kv: c.fuze.model.Type,
    document: void,
    computation: ComputationSpec,
    pub fn objectKind(self: Spec) m.ObjectKind {
        return switch (self) {
            .kv => .kv,
            .document => .document,
            .computation => .computation,
        };
    }
    pub fn validate(self: Spec) !void {
        switch (self) {
            .kv, .document => {},
            .computation => |comp| try comp.validate(),
        }
    }
    pub fn fingerprint(self: Spec) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.declarative.spec.v1\x00");
        hash.update(&.{@intFromEnum(std.meta.activeTag(self))});
        switch (self) {
            .kv => |vt| hash.update(&.{@intFromEnum(vt)}),
            .document => {},
            .computation => |comp| {
                var buf: [24]u8 = undefined;
                std.mem.writeInt(u64, buf[0..8], comp.source_object, .little);
                std.mem.writeInt(u64, buf[8..16], comp.source_revision, .little);
                std.mem.writeInt(u64, buf[16..24], comp.output_object, .little);
                hash.update(&buf);
            },
        }
        return hash.finalResult();
    }
};

pub const Record = struct {
    scope: m.Scope,
    object: u64,
    namespace: u64,
    authorization: u64,
    resource_id: u64 = 0,
    name: a.Name,
    spec: Spec,
    state: enum(u8) { initializing = 1, live = 2, retired = 3 },
    revision: u64,
    next_revision: u64,
    pending_principal: u64 = 0,
    pending_operation: u64 = 0,
    admitted_input: u64 = 0,
    completed_input: u64 = 0,
    pub fn validate(self: Record) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.namespace);
        try c.Model.nativeId(self.authorization);
        try self.name.validate();
        try self.spec.validate();
        if (self.object == 0 or self.next_revision == 0 or self.pending_principal > p.max_counter) return error.InvalidCatalogObject;
        if (self.state == .initializing) {
            if (self.revision != 0 or self.next_revision != 1 or self.pending_operation == 0 or self.resource_id != 0) return error.InvalidCatalogObject;
        } else if (self.state == .retired and self.revision == 0) {
            if (self.next_revision != 1 or self.pending_operation != 0) return error.InvalidCatalogObject;
        } else {
            if (self.revision == 0 or self.revision >= self.next_revision or self.resource_id == 0) return error.InvalidCatalogObject;
        }
    }
};

pub const Action = union(enum(u8)) {
    create: struct { spec: Spec, resource_id: u64, if_not_exists: bool = false } = 1,
    rename: a.Name = 2,
    drop: struct { if_exists: bool = false } = 3,
    complete_computation: struct { source_revision: u64 } = 4,
};

pub const Request = struct {
    scope: m.Scope,
    principal: u64,
    operation: u64,
    namespace: u64 = 1,
    object: u64,
    expected_revision: u64,
    name: a.Name,
    action: Action,
    pub fn right(self: Request) m.Right {
        return switch (self.action) {
            .create => .create,
            .rename, .complete_computation => .alter,
            .drop => .drop,
        };
    }
    pub fn validate(self: Request) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.operation);
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        if (self.principal > p.max_counter or self.expected_revision > p.max_counter) return error.InvalidCatalogCommand;
        switch (self.action) {
            .create => |value| {
                try value.spec.validate();
                if (self.object == 0 or self.expected_revision != 0 or value.resource_id == 0 or value.resource_id > p.max_counter) return error.InvalidCatalogCommand;
            },
            .rename => |target| {
                try target.validate();
                if (self.object == 0 or self.expected_revision == 0) return error.InvalidCatalogCommand;
            },
            .drop => |value| {
                if ((self.object == 0) != (self.expected_revision == 0) or (self.object == 0 and !value.if_exists)) return error.InvalidCatalogCommand;
            },
            .complete_computation => |value| {
                if (self.object == 0 or self.expected_revision == 0 or value.source_revision == 0) return error.InvalidCatalogCommand;
            },
        }
    }
    pub fn digest(self: Request) ![32]u8 {
        return c.Model.fingerprint(try r.encode('L', self));
    }
    pub fn fromDeclaration(scope_val: m.Scope, principal: u64, operation: u64, namespace: u64, object: u64, resource_id: u64, def: c.fuze.Declaration.Definition) !Request {
        try def.validate();
        const req: Request = .{
            .scope = scope_val,
            .principal = principal,
            .operation = operation,
            .namespace = namespace,
            .object = object,
            .expected_revision = 0,
            .name = try a.Name.init(def.name.slice()),
            .action = .{
                .create = .{
                    .spec = switch (def.body) {
                        .kv => |vt| .{ .kv = vt },
                        .document => .document,
                    },
                    .resource_id = resource_id,
                },
            },
        };
        try req.validate();
        return req;
    }
};

pub const Outcome = struct {
    scope: m.Scope,
    principal: u64,
    operation: u64,
    object: u64,
    actual_object: u64 = 0,
    namespace: u64 = 1,
    kind: m.ObjectKind,
    action: m.Kind,
    state: enum(u8) { provisioning = 1, applied = 2, unchanged = 3, rejected = 4, cancelled = 5 },
    reason: @FieldType(m.Operation, "reason") = .none,
    revision: u64 = 0,
    resource_id: u64 = 0,
    admitted_input: u64,
    completed_input: u64 = 0,
    digest: [32]u8,
    blocker: @FieldType(m.Operation, "blocker") = .none,
    pub fn terminal(self: Outcome) bool {
        return self.state != .provisioning;
    }
    pub fn validate(self: Outcome) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.operation);
        try c.Model.nativeId(self.namespace);
        try c.Model.nativeId(self.admitted_input);
        if (self.principal > p.max_counter or self.completed_input > p.max_counter) return error.InvalidCatalogReceipt;
        if ((self.state == .provisioning) != (self.completed_input == 0)) return error.InvalidCatalogReceipt;
        if ((self.state == .rejected) != (self.reason != .none)) return error.InvalidCatalogReceipt;
        if ((self.reason == .dependency) != (self.blocker == .dependency)) return error.InvalidCatalogReceipt;
    }
};

pub const Cursor = struct { scope: m.Scope, resource_revision: u64, after_object: u64 };
pub const Page = struct {
    entries: [p.Growth.page_size]?Record = @splat(null),
    next: ?Cursor = null,
    resource_revision: u64,
};

fn tables(self: Self) c.TableCatalog {
    return .{ .configuration = self.configuration, .namespace = self.namespace, .registration = self.registration };
}
fn namespaceId(self: Self) u64 {
    return self.namespace orelse self.configuration.authority.initial_schema;
}
fn key(self: Self, tag: u8, id: u64, revision: u64) p.Value {
    return r.key(self.configuration.scope.catalog, tag, id, revision);
}
fn nameKey(self: Self, namespace: u64, name: a.Name, id: u64) !p.Value {
    try c.Model.nativeId(namespace);
    try name.validate();
    const meta_name = try Meta.Name.init(name.slice());
    const digest = try meta_name.digestIn(namespace);
    var bytes: [32]u8 = undefined;
    bytes[0..11].* = r.prefix(self.configuration.scope.catalog, 'm').data[0..11].*;
    @memcpy(bytes[11..24], digest[0..Meta.name_digest_bytes]);
    std.mem.writeInt(u64, bytes[24..32], id, .big);
    return p.Value.init(&bytes);
}

pub fn record(self: Self, source: anytype, id: u64) !?Record {
    if (id == 0) return error.InvalidCatalogIdentity;
    const raw = (try source.read(self.key('K', id, 0))) orelse return null;
    const decoded = try r.decode(Record, 'K', raw);
    if (!std.meta.eql(decoded.scope, self.configuration.scope) or decoded.object != id) return error.InvalidCatalogObject;
    return decoded;
}

pub fn outcome(self: Self, source: anytype, who: u64, id: u64) !?Outcome {
    if (who > p.max_counter or id == 0) return error.InvalidCatalogIdentity;
    const raw = (try source.read(self.key('k', who, id))) orelse return null;
    const decoded = try r.decode(Outcome, 'k', raw);
    if (!std.meta.eql(decoded.scope, self.configuration.scope) or decoded.principal != who or decoded.operation != id) return error.InvalidCatalogReceipt;
    return decoded;
}

pub fn boundMeta(self: Self, source: anytype, namespace: u64, name: Meta.Name) !?Record {
    const auth_name = a.Name.init(name.slice()) catch |err| return if (err == error.InvalidCatalogName) null else err;
    return self.bound(source, namespace, auth_name);
}

pub fn bound(self: Self, source: anytype, namespace: u64, name: a.Name) !?Record {
    const full = try self.nameKey(namespace, name, 1);
    const prefix = try p.Value.init(full.data[0..24]);
    var cursor = prefix;
    var found: ?Record = null;
    while (true) {
        const page = try source.page(cursor);
        try c.Inspection.validatePage(page, cursor, source.view.revision);
        for (page.entries) |slot| {
            const entry = slot orelse break;
            if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return found;
            if (entry.key.len != 32) return error.InvalidCatalogBinding;
            const id = std.mem.readInt(u64, entry.key.data[24..32], .big);
            const binding = try r.decode(m.Binding, 'N', entry.value);
            if (!std.meta.eql(binding.scope, self.configuration.scope) or binding.object != id) return error.InvalidCatalogBinding;
            const current = (try self.record(source, id)) orelse return error.CatalogDefinitionMissing;
            if (current.state != .live or !(try self.nameKey(current.namespace, current.name, id)).eql(entry.key)) return error.CatalogDefinitionChanged;
            if (current.namespace == namespace and std.mem.eql(u8, current.name.slice(), name.slice())) {
                if (found != null) return error.InvalidCatalogBinding;
                found = current;
            }
        }
        cursor = page.next orelse return found;
    }
}

pub fn authorizeObject(self: Self, source: anytype, who: u64, id: u64, right: m.Right) !p.Authorization.Verified {
    const tc = self.tables();
    if (right == .create) return tc.authorize(source, who, .create);
    _ = try tc.authorizeDatabase(source, who);
    if (id == 0) return tc.authorize(source, who, .inspect);
    const current = (try self.record(source, id)) orelse return error.TableNotFound;
    const access: a.Access = switch (right) {
        .inspect => .inspect,
        .read => .read,
        .insert => .insert,
        .update => .update,
        .delete => .delete,
        .alter => .alter,
        .drop => .drop,
        .create => unreachable,
    };
    const ns = try tc.namespaceRecord(source, current.namespace);
    const subject = try a.subjectFor(source, who);
    return a.require(source, try a.guard(subject, self.configuration.authority, ns, .{ .id = id, .schema = current.namespace, .authorization = current.authorization }, access));
}

pub fn lookup(self: Self, source: anytype, who: u64, name: a.Name) !?Record {
    const tc = self.tables();
    _ = try tc.authorize(source, who, .inspect);
    const current = (try self.bound(source, self.namespaceId(), name)) orelse return null;
    _ = self.authorizeObject(source, who, current.object, .inspect) catch |err| return if (err == error.CatalogDenied) null else err;
    return current;
}

pub fn list(self: Self, source: anytype, who: u64, cursor: ?Cursor) !Page {
    const tc = self.tables();
    _ = try tc.authorize(source, who, .inspect);
    if (cursor) |prior| {
        if (!std.meta.eql(prior.scope, self.configuration.scope) or prior.resource_revision != source.view.revision or prior.after_object == 0) return error.CatalogCursorChanged;
    }
    const prefix = r.prefix(self.configuration.scope.catalog, 'K');
    const after = if (cursor) |prior| self.key('K', prior.after_object, 0) else prefix;
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
        const current = try r.decode(Record, 'K', entry.value);
        if (!std.meta.eql(current.scope, self.configuration.scope) or current.object != id or id == 0) return error.InvalidCatalogObject;
        last = id;
        if (current.state == .live and current.namespace == self.namespaceId()) {
            _ = self.authorizeObject(source, who, id, .inspect) catch |err| {
                if (err == error.CatalogDenied) continue;
                return err;
            };
            result.entries[count] = current;
            count += 1;
        }
    }
    if (page.next != null and last != 0) result.next = .{ .scope = self.configuration.scope, .resource_revision = source.view.revision, .after_object = last };
    return result;
}

pub fn status(self: Self, source: anytype, who: u64, id: u64, expected_digest: [32]u8) !?Outcome {
    const tc = self.tables();
    _ = try tc.authorizeDatabase(source, who);
    const found = (try self.outcome(source, who, id)) orelse return null;
    if (!std.mem.eql(u8, &found.digest, &expected_digest)) return error.CatalogIdentityConflict;
    const target = if (found.actual_object != 0) found.actual_object else if (found.object != 0 and try self.record(source, found.object) != null) found.object else 0;
    if (target != 0) {
        if (try self.record(source, target)) |rec| {
            if (rec.authorization != 0) _ = try self.authorizeObject(source, who, target, .inspect) else _ = try tc.authorize(source, who, .create);
        } else {
            _ = try tc.authorizeObject(source, who, target, .inspect);
        }
    } else {
        _ = try tc.authorize(source, who, .inspect);
    }
    return found;
}

pub fn inspectLifecycle(self: Self, source: anytype, who: u64, id: u64) !?m.LifecycleEvidence {
    const tc = self.tables();
    _ = try tc.authorizeDatabase(source, who);
    const current = (try self.record(source, id)) orelse return null;
    _ = try self.authorizeObject(source, who, id, .inspect);
    const state: m.LifecycleState = switch (current.state) {
        .initializing => .pending,
        .retired => .unavailable,
        .live => if (current.pending_operation != 0)
            .pending
        else if (current.spec == .computation and current.completed_input != 0)
            .complete
        else
            .published,
    };
    return .{
        .kind = current.spec.objectKind(),
        .state = state,
        .scope = current.scope,
        .namespace = current.namespace,
        .object = current.object,
        .revision = current.revision,
        .name = try Meta.Name.init(current.name.slice()),
        .definition_digest = try current.spec.fingerprint(),
        .resource_revision = source.view.revision,
        .pending_operation = current.pending_operation,
        .admitted_input = current.admitted_input,
        .completed_input = current.completed_input,
    };
}

pub fn preview(self: Self, source: anytype, who: u64, request: Request) !m.Preview {
    try request.validate();
    var scoped = self;
    scoped.namespace = request.namespace;
    const tc = scoped.tables();
    if (who != request.principal or !std.meta.eql(request.scope, self.configuration.scope)) return error.CatalogDenied;
    _ = try scoped.authorizeObject(source, request.principal, request.object, request.right());
    const meta_name = try Meta.Name.init(request.name.slice());
    switch (request.action) {
        .create => |creation| {
            const fp = try creation.spec.fingerprint();
            const kind = creation.spec.objectKind();
            if (try scoped.bound(source, request.namespace, request.name)) |existing| {
                _ = try scoped.authorizeObject(source, request.principal, existing.object, .inspect);
                const same_kind = existing.spec.objectKind() == kind;
                return .{
                    .kind = kind,
                    .action = .create,
                    .name = meta_name,
                    .object = existing.object,
                    .expected_revision = existing.revision,
                    .disposition = if (creation.if_not_exists and same_kind) .unchanged else .rejected,
                    .reason = if (creation.if_not_exists and same_kind) .none else .name_conflict,
                    .definition_digest = fp,
                    .resource_revision = source.view.revision,
                };
            }
            if (try tc.binding(source, meta_name)) |table_existing| {
                _ = try tc.authorizeObject(source, request.principal, table_existing.object.object, .inspect);
                return .{
                    .kind = kind,
                    .action = .create,
                    .name = meta_name,
                    .object = table_existing.object.object,
                    .expected_revision = table_existing.metadata.revision,
                    .disposition = .rejected,
                    .reason = .name_conflict,
                    .definition_digest = fp,
                    .resource_revision = source.view.revision,
                };
            }
            if ((try scoped.record(source, request.object)) != null or (try source.read(tc.key('O', request.object, 0))) != null) {
                return .{
                    .kind = kind,
                    .action = .create,
                    .name = meta_name,
                    .object = request.object,
                    .expected_revision = 0,
                    .disposition = .rejected,
                    .reason = .object_conflict,
                    .definition_digest = fp,
                    .resource_revision = source.view.revision,
                };
            }
            return .{
                .kind = kind,
                .action = .create,
                .name = meta_name,
                .object = request.object,
                .expected_revision = 1,
                .disposition = .admissible,
                .definition_digest = fp,
                .resource_revision = source.view.revision,
            };
        },
        else => {
            const action_kind: m.Kind = switch (request.action) {
                .create => unreachable,
                .rename => .rename,
                .drop => .drop,
                .complete_computation => .alter,
            };
            const existing = (try scoped.bound(source, request.namespace, request.name)) orelse {
                const absent_ok = request.action == .drop and request.action.drop.if_exists and request.object == 0;
                return .{
                    .kind = .kv,
                    .action = action_kind,
                    .name = meta_name,
                    .object = request.object,
                    .expected_revision = 0,
                    .disposition = if (absent_ok) .unchanged else .rejected,
                    .reason = if (absent_ok) .none else .not_found,
                    .resource_revision = source.view.revision,
                };
            };
            const kind = existing.spec.objectKind();
            const fp = try existing.spec.fingerprint();
            if (request.object != existing.object) {
                return .{
                    .kind = kind,
                    .action = action_kind,
                    .name = meta_name,
                    .object = existing.object,
                    .expected_revision = existing.revision,
                    .disposition = .rejected,
                    .reason = .object_conflict,
                    .definition_digest = fp,
                    .resource_revision = source.view.revision,
                };
            }
            if (request.expected_revision != existing.revision) {
                return .{
                    .kind = kind,
                    .action = action_kind,
                    .name = meta_name,
                    .object = existing.object,
                    .expected_revision = existing.revision,
                    .disposition = .rejected,
                    .reason = .schema_changed,
                    .definition_digest = fp,
                    .resource_revision = source.view.revision,
                };
            }
            if (existing.pending_operation != 0) return error.TableBusy;
            switch (request.action) {
                .create => unreachable,
                .rename => |target| {
                    const target_meta = try Meta.Name.init(target.slice());
                    if (std.mem.eql(u8, target.slice(), request.name.slice())) {
                        return .{
                            .kind = kind,
                            .action = .rename,
                            .name = meta_name,
                            .object = existing.object,
                            .expected_revision = existing.revision,
                            .disposition = .unchanged,
                            .definition_digest = fp,
                            .resource_revision = source.view.revision,
                        };
                    }
                    if (try scoped.bound(source, request.namespace, target)) |occupied| {
                        return .{
                            .kind = kind,
                            .action = .rename,
                            .name = target_meta,
                            .object = occupied.object,
                            .expected_revision = existing.revision,
                            .disposition = .rejected,
                            .reason = .name_conflict,
                            .definition_digest = fp,
                            .resource_revision = source.view.revision,
                        };
                    }
                    if (try tc.binding(source, target_meta)) |table_occupied| {
                        return .{
                            .kind = kind,
                            .action = .rename,
                            .name = target_meta,
                            .object = table_occupied.object.object,
                            .expected_revision = existing.revision,
                            .disposition = .rejected,
                            .reason = .name_conflict,
                            .definition_digest = fp,
                            .resource_revision = source.view.revision,
                        };
                    }
                    return .{
                        .kind = kind,
                        .action = .rename,
                        .name = target_meta,
                        .object = existing.object,
                        .expected_revision = existing.revision + 1,
                        .disposition = .admissible,
                        .definition_digest = fp,
                        .resource_revision = source.view.revision,
                    };
                },
                .drop => {
                    if (try tc.restrict(source, existing.object)) |dep| {
                        return .{
                            .kind = kind,
                            .action = .drop,
                            .name = meta_name,
                            .object = existing.object,
                            .expected_revision = existing.revision,
                            .disposition = .rejected,
                            .reason = .dependency,
                            .definition_digest = fp,
                            .blocker = dep,
                            .resource_revision = source.view.revision,
                        };
                    }
                    return .{
                        .kind = kind,
                        .action = .drop,
                        .name = meta_name,
                        .object = existing.object,
                        .expected_revision = existing.revision + 1,
                        .disposition = .admissible,
                        .definition_digest = fp,
                        .resource_revision = source.view.revision,
                    };
                },
                .complete_computation => {
                    if (existing.spec != .computation) return error.InvalidCatalogCommand;
                    return .{
                        .kind = .computation,
                        .action = .alter,
                        .name = meta_name,
                        .object = existing.object,
                        .expected_revision = existing.revision + 1,
                        .disposition = .admissible,
                        .definition_digest = fp,
                        .resource_revision = source.view.revision,
                    };
                },
            }
        },
    }
}

fn saveRecord(self: Self, turn: *s.Turn, value: Record) !void {
    try turn.write(self.key('K', value.object, 0), try r.encode('K', value));
}
fn saveOutcome(self: Self, turn: *s.Turn, value: Outcome) !Outcome {
    try turn.write(self.key('k', value.principal, value.operation), try r.encode('k', value));
    return value;
}
fn closeOutcome(self: Self, turn: *s.Turn, pending: Outcome, state: @FieldType(Outcome, "state"), reason: @FieldType(Outcome, "reason"), actual: u64, revision: u64, resource_id: u64) !Outcome {
    var final = pending;
    final.state = state;
    final.reason = reason;
    final.actual_object = actual;
    final.revision = revision;
    final.resource_id = resource_id;
    final.completed_input = turn.delivery.input.position;
    return self.saveOutcome(turn, final);
}

pub fn apply(self: Self, turn: *s.Turn, request: Request) !Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    try request.validate();
    var scoped = self;
    scoped.namespace = request.namespace;
    const tc = scoped.tables();
    if (turn.delivery.realm != request.scope.realm or turn.delivery.pid != self.configuration.owner or !std.meta.eql(request.scope, self.configuration.scope)) return error.CatalogOwnerChanged;
    const continuation = turn.delivery.input.origin == .process;
    if (continuation) {
        if (turn.delivery.input.origin.process.pid != self.configuration.owner) return error.CatalogDenied;
    } else if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != request.principal) return error.CatalogDenied;

    const req_digest = try request.digest();
    const existing_outcome = try scoped.outcome(turn, request.principal, request.operation);
    if (existing_outcome) |prior| {
        if (!std.mem.eql(u8, &prior.digest, &req_digest)) return error.CatalogIdentityConflict;
        if (continuation) try turn.bindAuthorizationSubject(.{ .accepted = .{ .pid = self.configuration.owner, .input = prior.admitted_input, .principal = request.principal } });
    } else if (continuation) return error.CatalogOperationNotFound;

    _ = try scoped.authorizeObject(turn, request.principal, request.object, request.right());
    if (existing_outcome) |prior| if (prior.terminal()) return prior;

    switch (request.action) {
        .create => |creation| {
            const kind = creation.spec.objectKind();
            if (existing_outcome) |prior| {
                // Phase 2: bind provisioned resource and publish live catalog record + name index.
                var current = (try scoped.record(turn, request.object)) orelse return error.CatalogDefinitionMissing;
                if (current.state != .initializing or current.pending_principal != request.principal or current.pending_operation != request.operation) return error.CatalogIdentityConflict;
                if (try scoped.bound(turn, request.namespace, request.name)) |occupied| {
                    current.state = .retired;
                    current.pending_principal = 0;
                    current.pending_operation = 0;
                    try scoped.saveRecord(turn, current);
                    const same_kind = occupied.spec.objectKind() == kind;
                    return scoped.closeOutcome(turn, prior, if (creation.if_not_exists and same_kind) .unchanged else .rejected, if (creation.if_not_exists and same_kind) .none else .name_conflict, occupied.object, occupied.revision, occupied.resource_id);
                }
                if (try tc.binding(turn, try Meta.Name.init(request.name.slice()))) |table_occupied| {
                    current.state = .retired;
                    current.pending_principal = 0;
                    current.pending_operation = 0;
                    try scoped.saveRecord(turn, current);
                    return scoped.closeOutcome(turn, prior, .rejected, .name_conflict, table_occupied.object.object, table_occupied.metadata.revision, 0);
                }
                current.state = .live;
                current.revision = 1;
                current.next_revision = 2;
                current.resource_id = creation.resource_id;
                current.pending_principal = 0;
                current.pending_operation = 0;
                if (creation.spec == .computation) {
                    // Register restricting query_source dependency from computation to source_object if in same turn budget or via explicit dependency
                }
                try scoped.saveRecord(turn, current);
                try turn.write(try scoped.nameKey(request.namespace, request.name, request.object), try r.encode('N', m.Binding{ .scope = request.scope, .object = request.object }));
                return scoped.closeOutcome(turn, prior, .applied, .none, request.object, 1, creation.resource_id);
            }
            // Phase 1: reserve catalog operation and initializing object record.
            const pending: Outcome = .{
                .scope = request.scope,
                .principal = request.principal,
                .operation = request.operation,
                .object = request.object,
                .namespace = request.namespace,
                .kind = kind,
                .action = .create,
                .state = .provisioning,
                .admitted_input = turn.originalAuthorizedInput(),
                .digest = req_digest,
            };
            if (try scoped.bound(turn, request.namespace, request.name)) |occupied| {
                _ = try scoped.authorizeObject(turn, request.principal, occupied.object, .inspect);
                const same_kind = occupied.spec.objectKind() == kind;
                return scoped.closeOutcome(turn, pending, if (creation.if_not_exists and same_kind) .unchanged else .rejected, if (creation.if_not_exists and same_kind) .none else .name_conflict, occupied.object, occupied.revision, occupied.resource_id);
            }
            if (try tc.binding(turn, try Meta.Name.init(request.name.slice()))) |table_occupied| {
                _ = try tc.authorizeObject(turn, request.principal, table_occupied.object.object, .inspect);
                return scoped.closeOutcome(turn, pending, .rejected, .name_conflict, table_occupied.object.object, table_occupied.metadata.revision, 0);
            }
            if ((try scoped.record(turn, request.object)) != null or (try turn.read(tc.key('O', request.object, 0))) != null) {
                return scoped.closeOutcome(turn, pending, .rejected, .object_conflict, request.object, 0, 0);
            }
            const ns = try tc.namespaceRecord(turn, request.namespace);
            const identity = try a.binding(request.scope, .table, request.object);
            const profile = self.configuration.authority;
            const native = (try turn.authorizationBinding(profile.table_domain, identity)) orelse {
                const verified = try tc.authorize(turn, request.principal, .create);
                if (self.registration) |slot| slot.* = .{ .register_object = .{ .domain = profile.table_domain, .owner = verified.role, .schema = a.reference(ns.authorization), .binding = identity } };
                return error.CatalogRegistrationRequired;
            };
            try a.validateObject(profile, request.scope, .table, request.object, a.reference(ns.authorization), native);
            const verified = try tc.authorize(turn, request.principal, .create);
            if (native.owner != verified.role) return error.CatalogIdentityConflict;
            try (c.SchemaCatalog{ .configuration = self.configuration }).admitTable(turn, ns.id);
            const initializing: Record = .{
                .scope = request.scope,
                .object = request.object,
                .namespace = ns.id,
                .authorization = native.reference.id,
                .resource_id = 0,
                .name = request.name,
                .spec = creation.spec,
                .state = .initializing,
                .revision = 0,
                .next_revision = 1,
                .pending_principal = request.principal,
                .pending_operation = request.operation,
                .admitted_input = pending.admitted_input,
            };
            try scoped.saveRecord(turn, initializing);
            return scoped.saveOutcome(turn, pending);
        },
        else => {
            const action_kind: m.Kind = switch (request.action) {
                .create => unreachable,
                .rename => .rename,
                .drop => .drop,
                .complete_computation => .alter,
            };
            const pending_base: Outcome = .{
                .scope = request.scope,
                .principal = request.principal,
                .operation = request.operation,
                .object = request.object,
                .namespace = request.namespace,
                .kind = .kv,
                .action = action_kind,
                .state = .provisioning,
                .admitted_input = turn.originalAuthorizedInput(),
                .digest = req_digest,
            };
            var current = (try scoped.bound(turn, request.namespace, request.name)) orelse {
                const absent_ok = request.action == .drop and request.action.drop.if_exists and request.object == 0;
                return scoped.closeOutcome(turn, pending_base, if (absent_ok) .unchanged else .rejected, if (absent_ok) .none else .not_found, 0, 0, 0);
            };
            var pending = pending_base;
            pending.kind = current.spec.objectKind();
            if (request.object != current.object) {
                return scoped.closeOutcome(turn, pending, .rejected, .object_conflict, current.object, current.revision, current.resource_id);
            }
            if (request.expected_revision != current.revision) {
                return scoped.closeOutcome(turn, pending, .rejected, .schema_changed, current.object, current.revision, current.resource_id);
            }
            if (current.pending_operation != 0) return error.TableBusy;
            switch (request.action) {
                .create => unreachable,
                .rename => |target| {
                    if (std.mem.eql(u8, target.slice(), current.name.slice())) {
                        return scoped.closeOutcome(turn, pending, .unchanged, .none, current.object, current.revision, current.resource_id);
                    }
                    if (try scoped.bound(turn, request.namespace, target)) |occupied| {
                        return scoped.closeOutcome(turn, pending, .rejected, .name_conflict, occupied.object, current.revision, current.resource_id);
                    }
                    if (try tc.binding(turn, try Meta.Name.init(target.slice()))) |table_occupied| {
                        return scoped.closeOutcome(turn, pending, .rejected, .name_conflict, table_occupied.object.object, current.revision, current.resource_id);
                    }
                    try turn.write(try scoped.nameKey(request.namespace, current.name, current.object), null);
                    try turn.write(try scoped.nameKey(request.namespace, target, current.object), try r.encode('N', m.Binding{ .scope = request.scope, .object = current.object }));
                    current.name = target;
                    current.revision = std.math.add(u64, current.revision, 1) catch return error.CatalogCapacity;
                    current.next_revision = std.math.add(u64, current.next_revision, 1) catch return error.CatalogCapacity;
                    try scoped.saveRecord(turn, current);
                    return scoped.closeOutcome(turn, pending, .applied, .none, current.object, current.revision, current.resource_id);
                },
                .drop => {
                    if (try tc.restrict(turn, current.object)) |dep| {
                        pending.blocker = .{ .dependency = .{ .identity = dep.identity, .owner = dep.owner, .kind = dep.kind } };
                        return scoped.closeOutcome(turn, pending, .rejected, .dependency, current.object, current.revision, current.resource_id);
                    }
                    try turn.write(try scoped.nameKey(request.namespace, current.name, current.object), null);
                    current.state = .retired;
                    current.revision = std.math.add(u64, current.revision, 1) catch return error.CatalogCapacity;
                    current.next_revision = std.math.add(u64, current.next_revision, 1) catch return error.CatalogCapacity;
                    try scoped.saveRecord(turn, current);
                    return scoped.closeOutcome(turn, pending, .applied, .none, current.object, current.revision, current.resource_id);
                },
                .complete_computation => |comp_update| {
                    if (current.spec != .computation) return error.InvalidCatalogCommand;
                    current.spec.computation.source_revision = comp_update.source_revision;
                    current.completed_input = turn.delivery.input.position;
                    current.revision = std.math.add(u64, current.revision, 1) catch return error.CatalogCapacity;
                    current.next_revision = std.math.add(u64, current.next_revision, 1) catch return error.CatalogCapacity;
                    try scoped.saveRecord(turn, current);
                    return scoped.closeOutcome(turn, pending, .applied, .none, current.object, current.revision, current.resource_id);
                },
            }
        },
    }
}

pub fn cancel(self: Self, turn: *s.Turn, who: u64, id: u64, expected_digest: [32]u8) !Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    const tc = self.tables();
    if (turn.delivery.realm != self.configuration.scope.realm or turn.delivery.pid != self.configuration.owner or turn.view.resource != self.configuration.scope.resource) return error.CatalogOwnerChanged;
    if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != who) return error.CatalogDenied;
    _ = try tc.authorize(turn, who, .inspect);
    const pending = (try self.outcome(turn, who, id)) orelse return error.CatalogOperationNotFound;
    if (!std.mem.eql(u8, &pending.digest, &expected_digest)) return error.CatalogIdentityConflict;
    if (pending.terminal()) return pending;
    var current = (try self.record(turn, pending.object)) orelse return error.CatalogDefinitionMissing;
    if (current.pending_principal != who or current.pending_operation != id) return error.CatalogIdentityConflict;
    if (current.state == .initializing) current.state = .retired;
    current.pending_principal = 0;
    current.pending_operation = 0;
    try self.saveRecord(turn, current);
    return self.closeOutcome(turn, pending, .cancelled, .none, pending.object, current.revision, current.resource_id);
}

/// Collect a never-published initializing reservation after terminal rejection or cancellation.
pub fn cleanup(self: Self, turn: *s.Turn, who: u64, id: u64, expected_digest: [32]u8) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (turn.delivery.realm != self.configuration.scope.realm or turn.delivery.pid != self.configuration.owner or turn.view.resource != self.configuration.scope.resource) return error.CatalogOwnerChanged;
    if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != who) return error.CatalogDenied;
    const found = (try self.status(turn, who, id, expected_digest)) orelse return error.CatalogOperationNotFound;
    if (!found.terminal() or found.state == .applied) return error.CatalogCleanupNotClosed;
    if (found.action == .create) {
        if (try self.record(turn, found.object)) |current| {
            if (current.state == .retired and current.revision == 0) {
                try turn.write(self.key('K', found.object, 0), null);
            }
        }
    }
    return true;
}
