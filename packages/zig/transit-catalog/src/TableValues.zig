//! Language-neutral general Table values. Native authority and validation stay
//! with their domain owners; every returned string belongs to the caller arena.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const m = c.TableCatalogRecords;
const f = c.fuze;
const Allocator = std.mem.Allocator;
pub const Schema = f.TableSchemaJson.Schema;
pub fn unsigned(text: []const u8) !u64 {
    if (text.len == 0 or text.len > 20 or (text.len > 1 and text[0] == '0')) return error.InvalidCatalogInteger;
    for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidCatalogInteger;
    return std.fmt.parseInt(u64, text, 10) catch error.InvalidCatalogInteger;
}
pub fn decimal(allocator: Allocator, value: u64) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
pub fn hex(allocator: Allocator, bytes: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, try std.math.mul(usize, bytes.len, 2));
    const alphabet = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        result[2 * i] = alphabet[byte >> 4];
        result[2 * i + 1] = alphabet[byte & 15];
    }
    return result;
}
pub fn unhex(allocator: Allocator, text: []const u8, max_bytes: usize) ![]u8 {
    if (text.len % 2 != 0 or text.len / 2 > max_bytes) return error.InvalidTableIntent;
    for (text) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return error.InvalidTableIntent;
    const result = try allocator.alloc(u8, text.len / 2);
    errdefer allocator.free(result);
    _ = std.fmt.hexToBytes(result, text) catch return error.InvalidTableIntent;
    return result;
}
pub fn digest(text: []const u8) ![32]u8 {
    if (text.len != 64) return error.CatalogIdentityConflict;
    for (text) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return error.CatalogIdentityConflict;
    var result: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&result, text) catch return error.CatalogIdentityConflict;
    return result;
}
pub const Scope = struct {
    realm: u64,
    resource: u64,
    catalog: []const u8,
    pub fn native(self: Scope) !m.Scope {
        const value: m.Scope = .{ .realm = self.realm, .resource = self.resource, .catalog = try unsigned(self.catalog) };
        try value.validate();
        return value;
    }
    pub fn foreign(allocator: Allocator, value: m.Scope) !Scope {
        try value.validate();
        return .{ .realm = value.realm, .resource = value.resource, .catalog = try decimal(allocator, value.catalog) };
    }
};
pub const Connection = struct {
    scope: Scope,
    owner: u64,
    principal: u64,
    pub fn native(self: Connection) !c.TableClient.Connection {
        const value: c.TableClient.Connection = .{ .scope = try self.scope.native(), .owner = self.owner, .principal = self.principal };
        try value.validate();
        return value;
    }
};
pub const Configuration = struct {
    scope: Scope,
    owner: u64,
    administrator: u64,
    table_limits: Limits,
    pub const Limits = struct {
        record_bytes: u32,
        staging_bytes: []const u8,
        staging_records: u32,
        pub fn native(self: Limits) !c.station.Publication.Limits {
            const value: c.station.Publication.Limits = .{ .record_bytes = self.record_bytes, .staging_bytes = try unsigned(self.staging_bytes), .staging_records = self.staging_records };
            try value.validate();
            return value;
        }
    };
    pub fn native(self: Configuration) !m.Configuration {
        const value: m.Configuration = .{ .scope = try self.scope.native(), .owner = self.owner, .administrator = self.administrator, .table_limits = try self.table_limits.native() };
        try value.validate();
        return value;
    }
    pub fn foreign(allocator: Allocator, value: m.Configuration) !Configuration {
        try value.validate();
        return .{ .scope = try Scope.foreign(allocator, value.scope), .owner = value.owner, .administrator = value.administrator, .table_limits = .{ .record_bytes = value.table_limits.record_bytes, .staging_bytes = try decimal(allocator, value.table_limits.staging_bytes), .staging_records = value.table_limits.staging_records } };
    }
};
pub const Policy = struct {
    scope: Scope,
    principal: u64,
    revision: []const u8,
    inspect: bool,
    create: bool,
    read: bool,
    insert: bool,
    update: bool,
    delete: bool,
    alter: bool,
    drop: bool,
    pub fn native(self: Policy) !m.Policy {
        const value: m.Policy = .{ .scope = try self.scope.native(), .principal = self.principal, .revision = try unsigned(self.revision), .inspect = self.inspect, .create = self.create, .read = self.read, .insert = self.insert, .update = self.update, .delete = self.delete, .alter = self.alter, .drop = self.drop };
        try value.validate();
        return value;
    }
    pub fn foreign(allocator: Allocator, value: m.Policy) !Policy {
        try value.validate();
        return .{ .scope = try Scope.foreign(allocator, value.scope), .principal = value.principal, .revision = try decimal(allocator, value.revision), .inspect = value.inspect, .create = value.create, .read = value.read, .insert = value.insert, .update = value.update, .delete = value.delete, .alter = value.alter, .drop = value.drop };
    }
};
pub const PolicyChange = struct {
    expected_revision: []const u8,
    policy: Policy,
    pub fn native(self: PolicyChange) !c.TableControl.Policy {
        const value: c.TableControl.Policy = .{ .expected_revision = try unsigned(self.expected_revision), .policy = try self.policy.native() };
        try value.validate();
        return value;
    }
};
pub const DependencyChange = struct {
    scope: Scope,
    object: []const u8,
    identity: []const u8,
    owner: u64,
    kind: @FieldType(m.Dependency, "kind"),
    present: bool,
    pub fn native(self: DependencyChange) !c.TableControl.Dependency {
        const value: c.TableControl.Dependency = .{ .dependency = .{ .scope = try self.scope.native(), .object = try unsigned(self.object), .identity = try unsigned(self.identity), .owner = self.owner, .kind = self.kind }, .present = self.present };
        try value.validate();
        return value;
    }
};
pub const Description = struct { configuration: Configuration, policy: Policy, resource_revision: u64 };
pub const Metadata = struct {
    scope: Scope,
    object: []const u8,
    revision: []const u8,
    name: []const u8,
    schema_fingerprint: []const u8,
    principal: u64,
    operation: []const u8,
    admitted_input: u64,
    /// Commitment to the immutable metadata record, including its physical
    /// schema reference. Foreign query callers must not reconstruct this hash.
    commitment: c.station.Publication.Spec,
    pub fn foreign(allocator: Allocator, value: c.TableMetadata.Record) !Metadata {
        try value.validate();
        return .{ .scope = try Scope.foreign(allocator, value.scope), .object = try decimal(allocator, value.object), .revision = try decimal(allocator, value.revision), .name = try allocator.dupe(u8, value.name.slice()), .schema_fingerprint = try hex(allocator, &value.schema_fingerprint), .principal = value.principal, .operation = try decimal(allocator, value.operation), .admitted_input = value.admitted_input, .commitment = try value.spec() };
    }
};
pub const Head = struct {
    revision: []const u8,
    rows: []const u8,
    pending: []const u8,
    pub fn foreign(allocator: Allocator, value: c.station.TableHead) !Head {
        try value.validate();
        if (value.retired) return error.CatalogSourceChanged;
        return .{ .revision = try decimal(allocator, value.revision), .rows = try decimal(allocator, value.rows), .pending = try decimal(allocator, value.pending) };
    }
};
pub const Definition = struct {
    metadata: Metadata,
    head: Head,
    schema: Schema,
    pub fn foreign(arena: *std.heap.ArenaAllocator, value: c.TableCatalog.Definition) !Definition {
        try entryValid(.{ .metadata = value.metadata, .head = value.head });
        if (value.schema.schema.object != value.metadata.object or !std.mem.eql(u8, &try value.schema.schema.fingerprint(), &value.metadata.schema_fingerprint)) return error.CatalogDefinitionChanged;
        return .{ .metadata = try Metadata.foreign(arena.allocator(), value.metadata), .head = try Head.foreign(arena.allocator(), value.head), .schema = try f.TableSchemaJson.foreign(arena, value.schema.schema) };
    }
};
pub const Entry = struct { metadata: Metadata, head: Head };
pub const HistoricalDefinition = struct {
    metadata: Metadata,
    schema: Schema,
    pub fn foreign(arena: *std.heap.ArenaAllocator, value: c.TableCatalog.HistoricalDefinition) !HistoricalDefinition {
        try value.metadata.validate();
        if (value.schema.schema.object != value.metadata.object or !std.mem.eql(u8, &try value.schema.schema.fingerprint(), &value.metadata.schema_fingerprint)) return error.CatalogDefinitionChanged;
        return .{ .metadata = try Metadata.foreign(arena.allocator(), value.metadata), .schema = try f.TableSchemaJson.foreign(arena, value.schema.schema) };
    }
};
fn entryValid(value: c.TableCatalog.Entry) !void {
    try value.metadata.validate();
    try value.head.validate();
    if (value.metadata.object != value.head.object or value.metadata.scope.resource != value.head.resource or !std.meta.eql(value.metadata.schema, value.head.schema) or value.head.retired) return error.CatalogSourceChanged;
}
pub const Cursor = struct {
    definition: p.Growth.Definition,
    scope: Scope,
    resource_revision: u64,
    after_object: []const u8,
    pub fn native(self: Cursor) !c.TableCatalog.Cursor {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.resource_revision > p.max_counter) return error.InvalidCatalogPage;
        const after = try unsigned(self.after_object);
        if (after == 0) return error.InvalidCatalogPage;
        return .{ .scope = try self.scope.native(), .resource_revision = self.resource_revision, .after_object = after };
    }
    pub fn foreign(allocator: Allocator, value: c.TableCatalog.Cursor) !Cursor {
        const result: Cursor = .{ .definition = p.Growth.current_definition, .scope = try Scope.foreign(allocator, value.scope), .resource_revision = value.resource_revision, .after_object = try decimal(allocator, value.after_object) };
        _ = try result.native();
        return result;
    }
};
pub const Page = struct {
    resource_revision: u64,
    entries: [p.Growth.page_size]?Entry,
    next: ?Cursor,
    pub fn foreign(allocator: Allocator, value: c.TableCatalog.Page) !Page {
        if (value.resource_revision > p.max_counter) return error.InvalidCatalogPage;
        var previous: u64 = 0;
        var scope: ?m.Scope = null;
        var ended = false;
        for (value.entries) |slot| {
            const entry = slot orelse {
                ended = true;
                continue;
            };
            try entryValid(entry);
            if (ended or entry.metadata.object <= previous) return error.InvalidCatalogPage;
            if (scope) |selected| if (!std.meta.eql(selected, entry.metadata.scope)) return error.InvalidCatalogPage;
            previous = entry.metadata.object;
            scope = entry.metadata.scope;
        }
        if (value.next) |cursor| {
            if (cursor.resource_revision != value.resource_revision or cursor.after_object < previous) return error.InvalidCatalogPage;
            if (scope) |selected| if (!std.meta.eql(selected, cursor.scope)) return error.InvalidCatalogPage;
        }
        var result: Page = .{ .resource_revision = value.resource_revision, .entries = @splat(null), .next = if (value.next) |cursor| try Cursor.foreign(allocator, cursor) else null };
        for (value.entries, 0..) |slot, i| if (slot) |entry| {
            result.entries[i] = .{ .metadata = try Metadata.foreign(allocator, entry.metadata), .head = try Head.foreign(allocator, entry.head) };
        };
        return result;
    }
};
pub const Identity = struct {
    operation: []const u8,
    namespace: []const u8,
    pub fn native(self: Identity) !c.TableClient.CompileIdentity {
        const value: c.TableClient.CompileIdentity = .{ .operation = try unsigned(self.operation), .namespace = try unsigned(self.namespace) };
        if (value.operation == 0 or value.namespace == 0) return error.InvalidCatalogIdentity;
        return value;
    }
};
/// Typed plans explicitly bind the schema whose column IDs the caller used.
/// A same-named replacement or rename/default change cannot retarget this work.
pub const Basis = struct {
    object: []const u8,
    revision: []const u8,
    schema_fingerprint: []const u8,
    pub fn check(self: Basis, value: c.TableMetadata.Record) !void {
        if (try unsigned(self.object) != value.object or try unsigned(self.revision) != value.revision or !std.mem.eql(u8, &try digest(self.schema_fingerprint), &value.schema_fingerprint)) return error.CatalogDefinitionChanged;
    }
};
pub const Counts = struct { matched: []const u8, changed: []const u8 };
pub const Outcome = struct {
    kind: @FieldType(c.TableCommand.Header, "kind"),
    operation: []const u8,
    object: []const u8,
    actual_object: ?[]const u8,
    phase: enum { preparing, delegated, building, applied, unchanged, rejected, cancelled },
    terminal: bool,
    counts: ?Counts,
    admitted_input: u64,
    completed_input: ?u64,
    diagnostic: p.Diagnostic,
    pub fn foreign(allocator: Allocator, intent: *const c.TableIntent, value: c.TableClient.Outcome) !Outcome {
        const diagnostic = try c.TableDiagnostic.status(intent, value);
        const table = switch (value) {
            .dml => |entry| entry,
            .ddl => |entry| entry.table,
        };
        const phase: @FieldType(Outcome, "phase") = if (table) |entry| switch (entry.state) {
            .building => .building,
            .applied => .applied,
            .rejected => .rejected,
            .cancelled => .cancelled,
        } else switch (value.ddl.operation.state) {
            .preparing => .preparing,
            .delegated => .delegated,
            .applied => .applied,
            .unchanged => .unchanged,
            .rejected => .rejected,
            .cancelled => .cancelled,
        };
        const completed = if (table) |entry| entry.completed_input else value.ddl.operation.completed_input;
        return .{ .kind = intent.header.kind, .operation = try decimal(allocator, intent.header.operation), .object = try decimal(allocator, intent.header.object), .actual_object = if (value == .ddl) try decimal(allocator, value.ddl.operation.actual_object) else null, .phase = phase, .terminal = value.terminal(), .counts = if (value == .dml and phase == .applied) .{ .matched = try decimal(allocator, value.dml.matched), .changed = try decimal(allocator, value.dml.changed) } else null, .admitted_input = if (table) |entry| entry.admitted_input else value.ddl.operation.admitted_input, .completed_input = if (completed == 0) null else completed, .diagnostic = diagnostic };
    }
};
pub const Upload = struct {
    phase: @FieldType(c.TableUpload.Status, "phase"),
    received: u32,
    total: u32,
    pub fn foreign(value: c.TableUpload.Status) !Upload {
        try value.validate();
        return .{ .phase = value.phase, .received = value.received, .total = value.spec.length };
    }
};
pub const State = struct { outcome: ?Outcome, upload: ?Upload };
pub const Disposition = struct {
    input: u64,
    outcome: @FieldType(c.TableControl.Disposition, "outcome"),
    diagnostic: p.Diagnostic,
    pub fn foreign(value: c.TableControl.Disposition) !Disposition {
        return .{ .input = value.input, .outcome = value.outcome, .diagnostic = try c.TableDiagnostic.input(value) };
    }
};
