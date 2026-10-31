//! Lossless host declarations over the existing named native resource owner.
//! Allocation, application initialization and name publication stay distinct.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const r = c.DirectResource;
const h = c.DirectTableValues;
const v = c.TableValues;
const w = c.DirectTableProtocol;
const inspection = c.DirectCatalogInspection;
const Allocator = std.mem.Allocator;

pub const Spec = union(r.Kind) {
    document: struct { document: []const u8, type_revision: u32, limits: struct { record_bytes: u32, staging_bytes: []const u8, staging_records: u32 } },
    pub fn native(self: Spec) !r.Spec {
        const result: r.Spec = switch (self) {
            .document => |value| .{ .document = .{ .document = try v.unsigned(value.document), .type_revision = value.type_revision, .limits = .{ .record_bytes = value.limits.record_bytes, .staging_bytes = try v.unsigned(value.limits.staging_bytes), .staging_records = value.limits.staging_records } } },
        };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: r.Spec) !Spec {
        try value.validate();
        return switch (value) {
            .document => |spec| .{ .document = .{ .document = try v.decimal(allocator, spec.document), .type_revision = spec.type_revision, .limits = .{ .record_bytes = spec.limits.record_bytes, .staging_bytes = try v.decimal(allocator, spec.limits.staging_bytes), .staging_records = spec.limits.staging_records } } },
        };
    }
};
pub const Create = struct {
    namespace: u64,
    name: []const u8,
    owner: u64,
    writer: u64,
    owned: bool,
    deadline_ms: ?u64,
    history_ms: ?u64,
    spec: Spec,
    pub fn native(self: Create) !r.Create {
        const result: r.Create = .{ .namespace = self.namespace, .name = try .init(self.name), .owner = self.owner, .writer = self.writer, .owned = self.owned, .deadline_ms = self.deadline_ms, .history_ms = self.history_ms, .spec = try self.spec.native() };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: r.Create) !Create {
        try value.validate();
        return .{ .namespace = value.namespace, .name = try allocator.dupe(u8, value.name.slice()), .owner = value.owner, .writer = value.writer, .owned = value.owned, .deadline_ms = value.deadline_ms, .history_ms = value.history_ms, .spec = try Spec.foreign(allocator, value.spec) };
    }
};
pub const Binding = struct {
    definition: p.Growth.Definition,
    connection: h.Connection,
    operation: []const u8,
    object: h.Object,
    expected: ?h.Interpretation,
    action: union(enum) { create: Create, rename: []const u8, drop },
    pub fn native(self: Binding) !r.Binding {
        const result: r.Binding = .{ .definition = self.definition, .connection = try self.connection.native(), .operation = try v.unsigned(self.operation), .object = try self.object.native(), .expected = if (self.expected) |value| try value.native() else null, .action = switch (self.action) {
            .create => |value| .{ .create = try value.native() },
            .rename => |value| .{ .rename = try .init(value) },
            .drop => .drop,
        } };
        try result.validate();
        return result;
    }
    pub fn check(self: Binding, connection: w.Connection) !r.Binding {
        const result = try self.native();
        if (!std.meta.eql(result.connection, connection)) return error.CatalogIdentityConflict;
        return result;
    }
    pub fn foreign(allocator: Allocator, value: r.Binding) !Binding {
        try value.validate();
        return .{ .definition = value.definition, .connection = try h.Connection.foreign(allocator, value.connection), .operation = try v.decimal(allocator, value.operation), .object = try h.Object.foreign(allocator, value.object), .expected = if (value.expected) |expected| try h.Interpretation.foreign(allocator, expected) else null, .action = switch (value.action) {
            .create => |create| .{ .create = try Create.foreign(allocator, create) },
            .rename => |name| .{ .rename = try allocator.dupe(u8, name.slice()) },
            .drop => .drop,
        } };
    }
};
pub const Definition = struct {
    object: h.Object,
    revision: []const u8,
    namespace: u64,
    name: []const u8,
    authorization: u64,
    resource: u64,
    allocating_principal: u64,
    allocation: r.Allocation,
    creation: Create,
    pub fn native(self: Definition) !r.Definition {
        const result: r.Definition = .{ .object = try self.object.native(), .revision = try v.unsigned(self.revision), .namespace = self.namespace, .name = try .init(self.name), .authorization = self.authorization, .resource = self.resource, .allocating_principal = self.allocating_principal, .allocation = self.allocation, .creation = try self.creation.native() };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: r.Definition) !Definition {
        try value.validate();
        return .{ .object = try h.Object.foreign(allocator, value.object), .revision = try v.decimal(allocator, value.revision), .namespace = value.namespace, .name = try allocator.dupe(u8, value.name.slice()), .authorization = value.authorization, .resource = value.resource, .allocating_principal = value.allocating_principal, .allocation = value.allocation, .creation = try Create.foreign(allocator, value.creation) };
    }
};
pub const Operation = struct {
    binding: Binding,
    position: h.Position,
    phase: @FieldType(r.Operation, "phase"),
    reason: r.Reason,
    resulting: ?Definition,
    allocation: ?r.Allocation,
    retired: bool,
    pub fn native(self: Operation) !r.Operation {
        const result: r.Operation = .{ .binding = try self.binding.native(), .position = try self.position.native(), .phase = self.phase, .reason = self.reason, .resulting = if (self.resulting) |value| try value.native() else null, .allocation = self.allocation, .retired = self.retired };
        try result.validate();
        return result;
    }
    fn foreign(allocator: Allocator, value: r.Operation) !Operation {
        try value.validate();
        return .{ .binding = try Binding.foreign(allocator, value.binding), .position = try h.Position.foreign(allocator, value.position), .phase = value.phase, .reason = value.reason, .resulting = if (value.resulting) |resulting| try Definition.foreign(allocator, resulting) else null, .allocation = value.allocation, .retired = value.retired };
    }
};
pub const View = struct {
    definition: Definition,
    interpretation: h.Interpretation,
    position: h.Position,
    fn foreign(allocator: Allocator, value: c.DirectCatalog.ResourceView) !View {
        return .{ .definition = try Definition.foreign(allocator, value.definition), .interpretation = try h.Interpretation.foreign(allocator, value.interpretation), .position = try h.Position.foreign(allocator, value.position) };
    }
};
pub const Action = union(enum) {
    preview: Binding,
    operation: struct { binding: Binding, command: r.Command, steps: u16 },
    lookup: struct { namespace: u64, name: []const u8 },
    list: struct { namespace: u64, cursor: ?inspection.Cursor },
};
pub const Result = union(enum) {
    preview: struct { binding: Binding, position: h.Position, current: ?Definition, reason: r.Reason },
    observation: union(enum) { not_observed, operation: Operation },
    lookup: ?View,
    list: struct { entries: [8]?View, next: ?inspection.Cursor, position: h.Position },
};
/// Executes one existing owner operation. CREATE execution may inspect its
/// already persisted native allocation sequence before signing that exact work.
pub fn apply(allocator: Allocator, client: c.DirectTableClient, action: Action) !Result {
    const resources: c.DirectResourceClient = .{ .catalog = client };
    switch (action) {
        .preview => |input| {
            const value = try resources.preview(try input.check(client.connection));
            return .{ .preview = .{ .binding = try Binding.foreign(allocator, value.binding), .position = try h.Position.foreign(allocator, value.position), .current = if (value.current) |found| try Definition.foreign(allocator, found) else null, .reason = value.reason } };
        },
        .operation => |input| return .{ .observation = switch (try resources.operation(try input.binding.check(client.connection), input.command, input.steps)) {
            .not_observed => .not_observed,
            .operation => |value| .{ .operation = try Operation.foreign(allocator, value) },
        } },
        .lookup => |input| return .{ .lookup = if (try resources.lookup(input.namespace, input.name)) |value| try View.foreign(allocator, value) else null },
        .list => |input| {
            const selection: inspection.Selection = .{ .resources = input.namespace };
            const page = try resources.list(input.namespace, if (input.cursor) |cursor| try cursor.check(client.connection, selection) else null);
            const next = try inspection.continuation(allocator, client.connection, selection, input.cursor, page.position, page.next);
            var entries: [8]?View = @splat(null);
            for (page.entries, &entries) |slot, *entry| if (slot) |value| {
                entry.* = try View.foreign(allocator, value);
            };
            return .{ .list = .{ .entries = entries, .next = next, .position = try h.Position.foreign(allocator, page.position) } };
        },
    }
}

test "direct resource host bindings preserve document identity and allocation recovery" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const fixture = try p.Json.parseFromSlice(struct { request: w.Request, public_key: [32]u8, resource: r.Definition, digest: [32]u8 }, arena.allocator(), @embedFile("fixtures/direct-resource-v1.json"));
    var original = fixture.value.request.action.resource_operation.binding;
    original.action.create.spec = .{ .document = .{ .document = std.math.maxInt(u64), .type_revision = 1, .limits = .{ .record_bytes = 4096, .staging_bytes = std.math.maxInt(u64), .staging_records = 4 } } };
    const bytes = try p.Json.valueAlloc(arena.allocator(), try Binding.foreign(arena.allocator(), original));
    const restored = try p.Json.parseFromSliceOwned(Binding, t.allocator, bytes);
    defer restored.deinit();
    _ = arena.reset(.free_all);
    try original.requireSame(try restored.value.check(original.connection));
    var other = original.connection;
    other.principal += 1;
    try t.expectError(error.CatalogIdentityConflict, restored.value.check(other));
    const prepared: r.Operation = .{ .binding = original, .position = .{ .partition = std.math.maxInt(u64), .next_lsn = std.math.maxInt(u64) }, .phase = .prepared, .reason = .none, .resulting = null, .allocation = .{ .sequence = p.max_counter }, .retired = false };
    try t.expectEqualDeep(prepared, try (try Operation.foreign(arena.allocator(), prepared)).native());
}
