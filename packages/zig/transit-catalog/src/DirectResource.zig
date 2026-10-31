//! Named native resource declarations. Allocation, initialization and catalog
//! publication are distinct decisions; a resource ID alone proves none of them.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;

pub const Kind = @FieldType(d.ResourceInitialization, "kind");
pub const Spec = union(Kind) {
    document: struct {
        document: u64,
        type_revision: u32,
        limits: c.protocol.DataLifecycle.PublicationLimits,
    },

    pub fn validate(self: Spec) !void {
        switch (self) {
            .document => |value| {
                if (value.document == 0 or value.type_revision == 0 or value.limits.record_bytes < p.DataLifecycle.document_index_node_bytes)
                    return error.InvalidNamedResource;
                try value.limits.validate();
            },
        }
    }
};

pub const Create = struct {
    namespace: u64,
    name: c.TableAuthority.Name,
    owner: u64,
    /// The application supplies the existing writer; creating a declaration does
    /// not select behavior code or create an execution authority implicitly.
    writer: u64,
    owned: bool,
    deadline_ms: ?u64,
    history_ms: ?u64,
    spec: Spec,

    pub fn validate(self: Create) !void {
        try c.Model.nativeId(self.namespace);
        try p.Authorization.roleId(self.owner);
        try c.Model.nativeId(self.writer);
        try self.name.validate();
        try self.spec.validate();
        if ((self.deadline_ms orelse 0) > p.max_counter or (self.history_ms orelse 0) > p.max_counter) return error.InvalidNamedResource;
    }

    pub fn allocation(self: Create) @FieldType(p.Growth.Command, "create_resource") {
        return .{ .writer = self.writer, .owned = self.owned, .deadline_ms = self.deadline_ms, .history_ms = self.history_ms };
    }
};

pub const Binding = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    operation: u64,
    object: d.Object,
    expected: ?d.Definition,
    action: union(enum) {
        create: Create,
        rename: c.TableAuthority.Name,
        drop,
    },

    pub fn identity(self: Binding) d.Operation {
        return .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = self.operation };
    }

    pub fn validate(self: Binding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.connection.object(self.object);
        try self.identity().validate();
        if ((self.action == .create) != (self.expected == null)) return error.InvalidNamedResource;
        if (self.expected) |value| {
            try value.validate();
            if (!std.meta.eql(value.object, self.object)) return error.DataIdentityConflict;
        }
        switch (self.action) {
            .create => |value| try value.validate(),
            .rename => |value| try value.validate(),
            .drop => {},
        }
    }

    pub fn requireSame(self: Binding, other: Binding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }

    pub fn allocation(self: Binding, prepared: Allocation) !p.Growth.Request {
        try self.validate();
        try prepared.validate();
        if (self.action != .create) return error.InvalidNamedResource;
        return .{ .definition = self.definition, .realm = self.connection.scope.realm, .principal = self.connection.principal, .sequence = prepared.sequence, .command = .{ .create_resource = self.action.create.allocation() } };
    }
};

/// An immutable interpretation of a provisioned native resource. The initial
/// interpretation remains its initialization identity after a later rename.
pub const Definition = struct {
    object: d.Object,
    revision: u64,
    namespace: u64,
    name: c.TableAuthority.Name,
    authorization: u64,
    resource: u64,
    allocating_principal: u64,
    allocation: Allocation,
    creation: Create,

    pub fn validate(self: Definition) !void {
        try self.object.validate();
        try c.Model.nativeId(self.namespace);
        try c.Model.nativeId(self.authorization);
        try c.Model.nativeId(self.resource);
        try self.name.validate();
        try self.creation.validate();
        try self.allocation.validate();
        if (self.object.branch != 1 or self.revision == 0 or self.namespace != self.creation.namespace or self.allocating_principal > p.max_counter)
            return error.InvalidNamedResource;
        if (self.revision == 1 and !std.meta.eql(self.name, self.creation.name)) return error.InvalidNamedResource;
    }

    pub fn interpretation(self: Definition, allocator: std.mem.Allocator) !d.Definition {
        try self.validate();
        const bytes = try p.Json.valueAlloc(allocator, self);
        defer allocator.free(bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.native-resource.v1\x00");
        hash.update(bytes);
        return .{ .object = self.object, .revision = self.revision, .digest = hash.finalResult() };
    }

    pub fn initialization(self: Definition, allocator: std.mem.Allocator) !d.ResourceInitialization {
        if (self.revision != 1) return error.InvalidNamedResource;
        return .{ .definition = p.Growth.current_definition, .interpretation = try self.interpretation(allocator), .kind = std.meta.activeTag(self.creation.spec), .resource = self.resource };
    }

    pub fn dependent(self: Definition, allocator: std.mem.Allocator) !c.DirectDependency.Dependent {
        return .{ .kind = .document, .interpretation = try self.interpretation(allocator) };
    }

    pub fn initial(self: Definition) !Definition {
        try self.validate();
        var result = self;
        result.revision = 1;
        result.name = self.creation.name;
        return result;
    }
};

pub const Command = enum { inspect, admit, execute, cancel };
/// Persisted after permission registration and before native dispatch. This
/// avoids consuming the caller's frozen sequence when it is also the registrar.
pub const Allocation = struct {
    sequence: u64,
    pub fn validate(self: Allocation) !void {
        try c.Model.nativeId(self.sequence);
    }
};
pub const SignedAllocation = struct { allocation: Allocation, signature: [64]u8 };
pub const Reason = enum { none, name_conflict, object_conflict, stale_definition, dependency };
pub const Operation = struct {
    binding: Binding,
    position: d.Position,
    phase: enum { admitted, prepared, allocated, complete, rejected, cancelled },
    reason: Reason,
    resulting: ?Definition,
    allocation: ?Allocation,
    retired: bool,

    pub fn pending(self: Operation) bool {
        return self.phase == .admitted or self.phase == .prepared or self.phase == .allocated;
    }

    pub fn validate(self: Operation) !void {
        try self.binding.validate();
        try self.position.validate();
        if (self.position.next_lsn == 0 or (self.phase == .rejected) != (self.reason != .none) or
            ((self.phase == .allocated or self.phase == .prepared) and self.binding.action != .create) or
            ((self.phase == .allocated or self.phase == .complete) and self.resulting == null) or
            (self.phase == .admitted and self.allocation != null) or
            (self.phase == .prepared and (self.allocation == null or self.resulting != null)) or
            (self.binding.action != .create and self.allocation != null) or
            (self.binding.action == .create and (self.phase == .admitted or self.phase == .rejected) and self.resulting != null) or
            self.retired != (self.phase == .complete and self.binding.action == .drop)) return error.InvalidNamedResourceOperation;
        if (self.allocation) |value| try value.validate();
        if (self.resulting) |value| {
            try value.validate();
            if (!std.meta.eql(value.object, self.binding.object)) return error.InvalidNamedResourceOperation;
            if (self.binding.action == .create) {
                if (!std.meta.eql(value.creation, self.binding.action.create) or value.revision != 1 or value.allocating_principal != self.binding.connection.principal or !std.meta.eql(@as(?Allocation, value.allocation), self.allocation)) return error.InvalidNamedResourceOperation;
            } else if (self.phase == .complete) {
                if (value.revision != try std.math.add(u64, self.binding.expected.?.revision, 1)) return error.InvalidNamedResourceOperation;
                if (self.binding.action == .rename and !std.meta.eql(value.name, self.binding.action.rename)) return error.InvalidNamedResourceOperation;
            }
        }
    }
};
pub const Observation = union(enum) { not_observed, operation: Operation };
pub const Preview = struct { binding: Binding, position: d.Position, current: ?Definition, reason: Reason };

/// Trusted service adapter condition. A supplied resource ID or marker from a
/// network caller is never evidence: the provider checks the exact allocation
/// receipt and current native state while holding the publication fence.
pub const Condition = struct {
    binding: Binding,
    allocation: Allocation,
    /// Null freezes the next unused native sequence before dispatch. Non-null
    /// verifies the original accepted native allocation, including retired data.
    resource: ?u64,
    initialization: ?d.ResourceInitialization,
};
pub const Native = struct {
    context: *anyopaque,
    prepare: *const fn (*anyopaque, Binding) anyerror!Allocation,
    allocation: *const fn (*anyopaque, Binding, Allocation) anyerror!?u64,
    make_guard: *const fn (*anyopaque, std.mem.Allocator, p.Authorization.Guard, Condition) anyerror!c.storage.TablePartition.Guard,
};
