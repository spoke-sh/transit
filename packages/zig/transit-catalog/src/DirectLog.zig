//! Stream/Queue declarations share the catalog's names, operation identities and
//! native policy graph. Private partition initialization is not publication.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const q = p.StreamQueueDeclaration;
const r = @import("DirectCatalogRecords.zig");
const s = c.storage;
pub const Kind = q.Kind;
pub const IntentStore = @import("CatalogIntentCodec.zig").Codec(Request, "catalog-log-intents", "LCATREQ1");
pub const Intent = struct {
    kind: Kind,
    namespace: u64,
    name: c.TableAuthority.Name,
    action: union(enum) {
        create: struct { owner: u64, schema: c.fuze.TableSchema.Schema, configuration: q.Configuration, limits: q.Limits },
        /// The first ALTER profile changes policy and operation budgets only.
        /// Schema, routing, key and ordering changes reject before admission.
        alter: struct { configuration: q.Configuration, limits: q.Limits },
        rename: c.TableAuthority.Name,
        drop,
    },

    pub fn validate(self: Intent, binding: d.Binding) !void {
        try binding.validate();
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        if (binding.expected_data != null) return error.InvalidLogCatalogIntent;
        const action: d.Action = switch (self.action) {
            .create => .create,
            .alter => .alter,
            .rename => .rename,
            .drop => .drop,
        };
        if (binding.action != action) return error.InvalidLogCatalogIntent;
        switch (self.action) {
            .create => |value| {
                try p.Authorization.roleId(value.owner);
                if (value.schema.revision != 1) return error.InvalidLogCatalogIntent;
                try (s.LogDeclaration.Definition{ .object = binding.target, .revision = 1, .schema = value.schema, .configuration = value.configuration, .limits = value.limits, .properties = "" }).validate();
                if (std.meta.activeTag(value.configuration.policy) != self.kind) return error.CatalogKindMismatch;
            },
            .alter => |value| {
                try value.configuration.validate();
                try value.limits.validate();
                if (std.meta.activeTag(value.configuration.policy) != self.kind) return error.CatalogKindMismatch;
            },
            .rename => |name| try name.validate(),
            .drop => {},
        }
    }

    pub fn digest(self: Intent, allocator: std.mem.Allocator) ![32]u8 {
        const bytes = try p.Json.valueAlloc(allocator, self);
        defer allocator.free(bytes);
        if (bytes.len > r.max_intent_bytes) return error.CatalogRecordTooLarge;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.log.intent.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
};

pub const Request = struct {
    binding: d.Binding,
    intent: Intent,
    pub fn validate(self: Request, allocator: std.mem.Allocator, configuration: r.Configuration) !void {
        try self.intent.validate(self.binding);
        if (!std.meta.eql(self.binding.target.scope, configuration.scope) or self.binding.target.branch != configuration.branch or
            !std.mem.eql(u8, &try self.intent.digest(allocator), &self.binding.intent)) return error.DataIdentityConflict;
    }
};

/// Contiguous allocation is an identity range, never a resident partition array.
/// The original genesis survives rename/ALTER and remains a recovery dependency.
pub const Definition = struct {
    stored: s.LogDeclaration.Stored,
    properties: r.Properties,
    seed: s.LogDeclaration.Stored,
    initialization: d.Operation,
    first_partition: u64,

    pub fn validate(self: Definition) !void {
        try self.stored.validate();
        try self.seed.validate();
        try self.properties.validate();
        try self.initialization.validate();
        const initial = self.seed.declaration;
        const current = self.stored.declaration;
        if (self.first_partition == 0 or initial.interpretation.revision != 1 or self.seed.retired or
            !std.meta.eql(current.interpretation.object, initial.interpretation.object) or
            !std.meta.eql(self.initialization.scope, initial.interpretation.object.scope) or
            !std.meta.eql(current.schema, initial.schema) or
            (current.interpretation.revision == 1 and !std.meta.eql(self.stored, self.seed))) return error.InvalidLogCatalogDefinition;
        try initial.configuration.requireEvolution(current.configuration);
        _ = try self.partition(self.count() - 1);
    }
    pub fn count(self: Definition) u32 {
        return self.seed.declaration.configuration.partitioning.count;
    }
    pub fn partition(self: Definition, ordinal: u32) !u64 {
        if (ordinal >= self.count()) return error.InvalidLogPartitioning;
        return std.math.add(u64, self.first_partition, ordinal) catch error.LogPartitionAllocationOverflow;
    }
    pub fn genesis(self: Definition, ordinal: u32) !s.LogInitialization.Request {
        try self.validate();
        return .{ .definition = p.Growth.current_definition, .declared = self.seed, .operation = self.initialization, .ordinal = ordinal, .partition = try self.partition(ordinal) };
    }
    pub fn kind(self: Definition) Kind {
        return std.meta.activeTag(self.stored.declaration.configuration.policy);
    }
    pub fn deadLetterEdge(self: Definition) !?c.DirectDependency.Edge {
        try self.validate();
        if (self.kind() != .queue or self.stored.retired) return null;
        const destination = self.stored.declaration.configuration.policy.queue.dead_letter orelse return null;
        const edge: c.DirectDependency.Edge = .{ .source = destination, .dependent = .{ .kind = .queue, .interpretation = self.stored.declaration.interpretation }, .privileges = c.LogAuthority.append };
        try edge.validate();
        return edge;
    }
};

pub const Reason = enum { none, name_conflict, object_conflict, stale_definition, dependency };
pub const Phase = enum { admitted, initializing, complete, rejected, cancelled };
pub const Command = enum { inspect, admit, execute, cancel };
pub const Operation = struct {
    binding: d.Binding,
    intent: d.Content,
    kind: Kind,
    namespace: u64,
    name: c.TableAuthority.Name,
    owner: ?u64,
    position: d.Position,
    phase: Phase,
    reason: Reason,
    first_partition: u64,
    partition_count: u32,
    initialized: u32,
    resulting: ?Definition,

    pub fn pending(self: Operation) bool {
        return self.phase == .admitted or self.phase == .initializing;
    }
    pub fn validate(self: Operation) !void {
        try self.binding.validate();
        try self.intent.validate();
        try self.position.validate();
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        if (self.position.next_lsn == 0 or self.intent.bytes > r.max_intent_bytes or
            self.binding.expected_data != null or
            (self.reason != .none) != (self.phase == .rejected) or
            (self.owner != null) != (self.binding.action == .create) or
            self.initialized > self.partition_count) return error.InvalidLogCatalogOperation;
        if (self.owner) |owner| try p.Authorization.roleId(owner);
        switch (self.binding.action) {
            .create, .alter, .rename, .drop => {},
            else => return error.InvalidLogCatalogOperation,
        }
        if (self.partition_count == 0) {
            if (self.first_partition != 0 or self.resulting != null or self.phase != .rejected) return error.InvalidLogCatalogOperation;
        } else {
            if (self.first_partition == 0) return error.InvalidLogCatalogOperation;
            _ = std.math.add(u64, self.first_partition, self.partition_count) catch return error.LogPartitionAllocationOverflow;
        }
        if (self.phase == .initializing and (self.binding.action != .create or self.resulting == null or self.initialized == self.partition_count)) return error.InvalidLogCatalogOperation;
        if (self.phase == .complete and (self.resulting == null or (self.binding.action == .create and self.initialized != self.partition_count))) return error.InvalidLogCatalogOperation;
        if (self.binding.action != .create and self.initialized != 0) return error.InvalidLogCatalogOperation;
        if (self.phase == .admitted and (self.initialized != 0 or self.resulting != null)) return error.InvalidLogCatalogOperation;
        if (self.resulting) |value| {
            try value.validate();
            if (value.kind() != self.kind or value.properties.namespace != self.namespace or
                !std.meta.eql(value.stored.declaration.interpretation.object, self.binding.target) or
                value.first_partition != self.first_partition or value.count() != self.partition_count) return error.InvalidLogCatalogOperation;
            const revision = if (self.binding.expected_definition) |previous| std.math.add(u64, previous.revision, 1) catch return error.InvalidLogCatalogOperation else 1;
            if (value.stored.declaration.interpretation.revision != revision or !std.meta.eql(value.properties.name, self.name)) return error.InvalidLogCatalogOperation;
            if (self.binding.action == .create and (!std.meta.eql(value.initialization, self.binding.identity) or self.initialized == 0)) return error.InvalidLogCatalogOperation;
            if (self.phase == .complete and value.stored.retired != (self.binding.action == .drop)) return error.InvalidLogCatalogOperation;
        }
    }
};
pub const Observation = union(enum) { not_observed, operation: Operation };
pub const Preview = struct { binding: d.Binding, position: d.Position, current: ?Definition, reason: Reason };
pub const Page = struct { entries: [s.TreeStore.pages.page_entries]?Definition = @splat(null), next: ?s.TreeStore.pages.Key, position: d.Position };
pub const PendingPage = struct { entries: [s.TreeStore.pages.page_entries]?Operation = @splat(null), next: ?s.TreeStore.pages.Key, position: d.Position };

pub fn authorityKind(kind: Kind) c.TableAuthority.Kind {
    return switch (kind) {
        .stream => .stream,
        .queue => .queue,
    };
}
