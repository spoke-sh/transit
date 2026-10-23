//! Direct catalog control records. Name candidates publish no Table state;
//! visibility is determined by the exact accepted Table declaration.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const a = c.TableAuthority;
const storage = c.storage;
const pages = storage.TreeStore.pages;
pub const max_record_bytes = 16 * 1024;
pub const max_intent_bytes = storage.TransitLog.max_payload_bytes;

pub const Configuration = struct {
    scope: d.Scope,
    branch: u64,
    partition: u64,
    audience: u64,
    authority: a.Profile,
    database_name: a.Name,
    initial_schema_name: a.Name,
    pub fn validate(self: Configuration) !void {
        try self.scope.validate();
        try self.authority.validate();
        try self.database_name.validate();
        try self.initial_schema_name.validate();
        try c.Model.nativeId(self.audience);
        if (self.branch != 1 or self.partition == 0 or self.partition == std.math.maxInt(u64)) return error.InvalidDirectCatalogConfiguration;
    }
};

/// Canonical TableDeclaration.properties. The current native object remains the
/// role/permission authority; this record only names its stable reference.
pub const Properties = struct {
    namespace: u64,
    authorization: u64,
    name: a.Name,
    pub fn validate(self: Properties) !void {
        try c.Model.nativeId(self.namespace);
        try c.Model.nativeId(self.authorization);
        try self.name.validate();
    }
    pub fn encode(self: Properties, output: []u8) ![]const u8 {
        try self.validate();
        var writer: std.Io.Writer = .fixed(output);
        try std.json.Stringify.value(self, .{}, &writer);
        return writer.buffered();
    }
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Properties {
        if (bytes.len > storage.TableDeclaration.max_properties_bytes) return error.InvalidDirectCatalogProperties;
        const parsed = try std.json.parseFromSlice(Properties, allocator, bytes, .{});
        defer parsed.deinit();
        var canonical: [storage.TableDeclaration.max_properties_bytes]u8 = undefined;
        if (!std.mem.eql(u8, bytes, try parsed.value.encode(&canonical))) return error.InvalidDirectCatalogProperties;
        return parsed.value;
    }
    pub fn target(self: Properties, id: u64) a.Table {
        return .{ .id = id, .schema = self.namespace, .authorization = self.authorization };
    }
};

pub const Entry = struct {
    object: u64,
    partition: u64,
    seed: ?storage.TableDeclaration.Stored,
    pub fn validate(self: Entry, config: Configuration) !void {
        if (self.partition <= config.partition or self.object == 0) return error.InvalidDirectCatalogEntry;
        if (self.seed) |seed| {
            try seed.validate();
            const id = seed.interpretation.object;
            if (self.object != id.object or !std.meta.eql(id.scope, config.scope) or id.branch != config.branch or
                seed.interpretation.revision != 1 or seed.retired) return error.InvalidDirectCatalogEntry;
        }
    }
};

pub const Name = struct {
    namespace: u64,
    name: a.Name,
    object: u64,
    reservation: d.Operation,
    pub fn validate(self: Name, config: Configuration) !void {
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        try self.reservation.validate();
        if (self.object == 0 or !std.meta.eql(self.reservation.scope, config.scope)) return error.InvalidDirectCatalogName;
    }
};

pub const Root = struct {
    configuration: Configuration,
    next_lsn: u64,
    next_partition: u64,
    initialized: bool,
    schemas: ?pages.Reference,
    schema_names: ?pages.Reference,
    objects: ?pages.Reference,
    names: ?pages.Reference,
    operations: ?pages.Reference,
    pending: ?pages.Reference,
    pub fn empty(config: Configuration) !Root {
        try config.validate();
        return .{ .configuration = config, .next_lsn = 0, .next_partition = config.partition + 1, .initialized = false, .schemas = null, .schema_names = null, .objects = null, .names = null, .operations = null, .pending = null };
    }
    pub fn validate(self: Root) !void {
        try self.configuration.validate();
        if (self.next_partition <= self.configuration.partition or self.initialized != (self.next_lsn != 0)) return error.InvalidDirectCatalogRoot;
    }
};

pub const Phase = enum { admitted, ready, rejected, cancelled, settled };
pub const Reason = enum { none, name_conflict, object_conflict, stale_definition, stale_data, dependency, constraint };
pub const Operation = struct {
    binding: d.Binding,
    intent: d.Content,
    phase: Phase,
    reason: Reason,
    pub fn pending(self: Operation) bool {
        return self.phase == .admitted or self.phase == .ready;
    }
    pub fn validate(self: Operation, config: Configuration) !void {
        try self.binding.validate();
        try self.intent.validate();
        if (!std.meta.eql(self.binding.identity.scope, config.scope) or self.binding.target.branch != config.branch or self.intent.bytes > max_intent_bytes or
            (self.phase == .rejected) != (self.reason != .none) or (self.phase == .ready and self.binding.action != .create)) return error.InvalidDirectCatalogOperation;
        switch (self.binding.action) {
            .create, .alter, .rename, .drop => {},
            else => return error.InvalidDirectCatalogOperation,
        }
    }
};

pub const Record = struct {
    definition: p.Growth.Definition,
    previous: [32]u8,
    root: Root,
    action: union(enum) { initialize, operation: Operation, assertion: c.NameAssertion.Outcome },
    pub fn validate(self: Record, position: u64) !void {
        try self.root.validate();
        if (self.root.next_lsn != try std.math.add(u64, position, 1) or !self.root.initialized) return error.InvalidDirectCatalogHistory;
        switch (self.action) {
            .initialize => if (position != 0) return error.InvalidDirectCatalogHistory,
            .operation => |value| {
                if (position == 0) return error.InvalidDirectCatalogHistory;
                try value.validate(self.root.configuration);
            },
            .assertion => |value| {
                try value.validate();
                const connection = value.binding.connection;
                if (position == 0 or !connection.matches(self.root.configuration) or value.position.partition != self.root.configuration.partition or value.position.next_lsn != self.root.next_lsn) return error.InvalidDirectCatalogHistory;
            },
        }
    }
};

pub fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}

pub fn idKey(id: u64) !pages.Key {
    if (id == 0) return error.InvalidCatalogIdentity;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, id, .big);
    return pages.Key.init(&bytes);
}

pub fn operationKey(operation: d.Operation) !pages.Key {
    try operation.validate();
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], operation.principal, .big);
    std.mem.writeInt(u64, bytes[8..16], operation.operation, .big);
    return pages.Key.init(&bytes);
}

pub fn nameKey(namespace: u64, name: a.Name) !pages.Key {
    try c.Model.nativeId(namespace);
    try name.validate();
    var bytes: [8 + p.Authorization.max_name_bytes]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], namespace, .big);
    @memcpy(bytes[8..][0..name.len], name.slice());
    return pages.Key.init(&hash(bytes[0 .. 8 + name.len]));
}

pub fn pageValue(input: anytype) !pages.Value {
    var bytes: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try std.json.Stringify.value(input, .{}, &writer);
    return pages.Value.init(writer.buffered());
}

/// Only use for fixed-owning records. Borrowed schemas/intents need their own
/// parsed ownership and must never outlive a temporary JSON arena.
pub fn fromValue(comptime T: type, allocator: std.mem.Allocator, input: pages.Value) !T {
    const parsed = try std.json.parseFromSlice(T, allocator, input.slice(), .{});
    defer parsed.deinit();
    return parsed.value;
}

/// Canonical frozen DDL intent, independent of transport nonce or credentials.
/// CREATE freezes the selected owner role. Its native registration ID is a
/// later accepted provisioning result, never part of caller-chosen intent.
pub const Intent = struct {
    namespace: u64,
    name: a.Name,
    action: union(enum) {
        create: struct { schema: c.fuze.TableSchema.Schema, owner: u64 },
        rename: a.Name,
        alter: c.fuze.TableEvolution.Change,
        drop,
    },
    pub fn validate(self: Intent, binding: d.Binding) !void {
        try binding.validate();
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        const action: d.Action = switch (self.action) {
            .create => .create,
            .rename => .rename,
            .alter => .alter,
            .drop => .drop,
        };
        if (binding.action != action) return error.InvalidDirectCatalogOperation;
        switch (self.action) {
            .create => |value| {
                try value.schema.validate();
                if (value.owner > p.max_counter) return error.InvalidCatalogIdentity;
                if (value.schema.object != binding.target.object or value.schema.revision != 1) return error.InvalidDirectCatalogOperation;
            },
            .rename => |name| try name.validate(),
            .alter, .drop => {},
        }
    }
    pub fn digest(self: Intent, allocator: std.mem.Allocator) ![32]u8 {
        const bytes = try allocator.alloc(u8, max_intent_bytes);
        defer allocator.free(bytes);
        var writer: std.Io.Writer = .fixed(bytes);
        try std.json.Stringify.value(self, .{}, &writer);
        var result = std.crypto.hash.sha2.Sha256.init(.{});
        result.update("transit.catalog.ddl.intent.v1\x00");
        result.update(writer.buffered());
        return result.finalResult();
    }
};

pub const Request = struct {
    binding: d.Binding,
    intent: Intent,
    pub fn validate(self: Request, allocator: std.mem.Allocator, configuration: Configuration) !void {
        try self.intent.validate(self.binding);
        if (!std.meta.eql(self.binding.target.scope, configuration.scope) or self.binding.target.branch != configuration.branch or
            !std.mem.eql(u8, &try self.intent.digest(allocator), &self.binding.intent)) return error.DataIdentityConflict;
    }
};
