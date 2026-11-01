//! Typed KV operations over the database-owned paged partition. Every call
//! checks current policy; receipts and retained reads confer no authority.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const s = c.storage;
const KV = s.KVPartition;
const w = c.DirectTableProtocol;

pub const Declaration = struct {
    binding: d.Binding,
    namespace: u64,
    name: c.TableAuthority.Name,
    action: union(enum) {
        create: struct { owner: u64, spec: s.KVDeclaration.Spec },
        rename: c.TableAuthority.Name,
        drop,
    },
    /// The returned schema borrows request scratch, never a native writer PID.
    pub fn intent(self: Declaration, scratch: std.mem.Allocator) !c.DirectCatalog.Intent {
        const action: @FieldType(c.DirectCatalog.Intent, "action") = switch (self.action) {
            .create => |value| blk: {
                const columns = try scratch.create([2]c.fuze.TableSchema.Column);
                break :blk .{ .create = .{ .owner = value.owner, .schema = value.spec.schema(self.binding.target.object, columns) } };
            },
            .rename => |value| .{ .rename = value },
            .drop => .drop,
        };
        return .{ .kind = .kv, .namespace = self.namespace, .name = self.name, .action = action };
    }
    pub fn request(self: Declaration, scratch: std.mem.Allocator) !c.DirectCatalog.Request {
        const result: c.DirectCatalog.Request = .{ .binding = self.binding, .intent = try self.intent(scratch) };
        try result.intent.validate(result.binding);
        if (!std.mem.eql(u8, &try result.intent.digest(scratch), &result.binding.intent)) return error.DataIdentityConflict;
        return result;
    }
};

pub const DeclarationRequest = struct {
    declaration: Declaration,
    command: enum { preview, admit, inspect, execute, cancel },
    steps: u16,
    pub fn mutation(self: DeclarationRequest) bool {
        return self.command != .preview and self.command != .inspect;
    }
    pub fn control(self: DeclarationRequest) bool {
        return self.command == .inspect or self.command == .cancel;
    }
    pub fn validate(self: DeclarationRequest, scratch: std.mem.Allocator, connection: w.Connection) !void {
        try connection.binding(self.declaration.binding);
        if (self.steps == 0 or self.steps > 256) return error.InvalidCatalogStepBudget;
        var arena: std.heap.ArenaAllocator = .init(scratch);
        defer arena.deinit();
        _ = try self.declaration.request(arena.allocator());
    }
};
pub const DeclarationResult = union(enum) { preview: c.DirectCatalog.Preview, operation: c.DirectCatalog.Observation };

pub const Definition = struct {
    interpretation: s.TableDeclaration.Stored,
    namespace: u64,
    name: c.TableAuthority.Name,
    authorization: u64,
    spec: s.KVDeclaration.Spec,
    retired: bool,
    position: d.Position,
    changed_lsn: u64,
};
pub const Change = union(enum) {
    put: struct { key: w.Binary, value: w.Binary, expect: @FieldType(@FieldType(KV.Change, "put"), "expect") },
    remove: w.Binary,
};
pub const Mutation = struct {
    pub const json_schema_sequence_bounds = .{ .changes = KV.max_changes };
    binding: d.Binding,
    changes: []const Change,
    pub fn digest(self: Mutation, allocator: std.mem.Allocator) ![32]u8 {
        const bytes = p.Json.valueAllocBounded(allocator, self.changes, w.max_work_bytes) catch |err| switch (err) {
            error.WriteFailed => return error.KVBatchTooLarge,
            else => return err,
        };
        defer allocator.free(bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.kv.mutation.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
    pub fn validate(self: Mutation, allocator: std.mem.Allocator) !void {
        try self.binding.validate();
        if (self.binding.action != .insert or self.binding.expected_definition == null or self.changes.len == 0 or self.changes.len > KV.max_changes) return error.InvalidKVOperation;
        if (!std.mem.eql(u8, &self.binding.intent, &try self.digest(allocator))) return error.DataIdentityConflict;
    }

    pub fn decodeChanges(self: Mutation, scratch: std.mem.Allocator, spec: s.KVDeclaration.Spec) ![]const KV.Change {
        const changes = try scratch.alloc(KV.Change, self.changes.len);
        const field: c.fuze.Types.Field = .{ .name = "value", .type = spec.typeOf(), .nullable = spec.nullable };
        for (self.changes, changes) |change, *lowered| switch (change) {
            .put => |value| {
                const bytes = try value.value.decode(scratch, c.fuze.Types.Codec.max_bytes);
                lowered.* = .{ .put = .{ .key = try keyBytes(scratch, value.key), .value = try c.fuze.Types.Codec.decodeBoundInto(scratch, field, bytes), .expect = value.expect } };
            },
            .remove => |key| lowered.* = .{ .remove = try keyBytes(scratch, key) },
        };
        return changes;
    }
};
pub const Request = union(enum) {
    observe: d.Object,
    mutate: Mutation,
    operation: d.Binding,
    get: struct { object: d.Object, key: w.Binary, source: ?s.TablePartition.SnapshotHandle },
    pin: struct { object: d.Object, owner: d.Operation, expected: d.Position },
    pin_status: struct { object: d.Object, owner: d.Operation },
    release: struct { object: d.Object, source: s.TablePartition.SnapshotHandle },

    pub fn mutation(self: Request) bool {
        return self == .mutate or self == .pin or self == .release;
    }
    pub fn control(self: Request) bool {
        return self == .operation or self == .pin_status or self == .release;
    }
    pub fn target(self: Request) d.Object {
        return switch (self) {
            .observe => |value| value,
            .mutate => |value| value.binding.target,
            .operation => |value| value.target,
            inline else => |value| value.object,
        };
    }
    pub fn identity(self: Request) ?d.Operation {
        return switch (self) {
            .mutate => |value| value.binding.identity,
            .operation => |value| value.identity,
            .get => |value| if (value.source) |source| source.owner else null,
            inline .pin, .pin_status => |value| value.owner,
            .release => |value| value.source.owner,
            .observe => null,
        };
    }
    pub fn access(self: Request) c.KVAuthority.Access {
        return switch (self) {
            .observe, .operation => .inspect,
            .mutate => .write,
            else => .read,
        };
    }
    pub fn validate(self: Request, allocator: std.mem.Allocator, principal: u64, scope: d.Scope) !void {
        try self.target().validate();
        if (!std.meta.eql(self.target().scope, scope)) return error.CatalogDenied;
        if (self.identity()) |original| {
            try original.validate();
            if (original.principal != principal or !std.meta.eql(original.scope, scope)) return error.CatalogDenied;
        }
        switch (self) {
            .mutate => |value| try value.validate(allocator),
            .operation => |value| {
                try value.validate();
                if (value.action != .insert) return error.InvalidKVOperation;
            },
            .pin => |value| try value.expected.validate(),
            else => {},
        }
    }
};
pub const Read = struct {
    interpretation: s.TableDeclaration.Stored,
    position: d.Position,
    changed_lsn: u64,
    spec: s.KVDeclaration.Spec,
    source: ?s.TablePartition.SnapshotHandle,
    workspace: ?p.Transaction.ReadView,
    encoded: ?w.Binary,
};
pub const Result = union(enum) {
    definition: Definition,
    operation: ?s.TablePartition.Evidence,
    value: Read,
    pin: s.TablePartition.SnapshotHandle,
    pin_status: s.TablePartition.PinState,
    released,
    pub fn deinit(self: Result, allocator: std.mem.Allocator) void {
        if (self == .value) if (self.value.encoded) |value| allocator.free(value.base64);
    }
};

fn keyBytes(scratch: std.mem.Allocator, value: w.Binary) ![]const u8 {
    const key = try value.decode(scratch, KV.max_key_bytes);
    if (key.len == 0) return error.InvalidKVKey;
    return key;
}

fn authorize(guard: s.PublicationGuard) !void {
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
}

/// All returned bytes belong to output; decoding and lowering borrow scratch.
/// A missing reply is reconciled with operation using the original binding.
pub fn apply(scratch: std.mem.Allocator, output: std.mem.Allocator, catalog: *c.DirectCatalog, request: Request, policy: c.DirectCatalog.Policy) !Result {
    try request.validate(scratch, policy.subject.principal(), catalog.store.root.configuration.scope);
    var selected = try catalog.kvAccess(scratch, request.target(), request.access(), request.control(), if (request == .mutate) request.mutate.binding.prerequisite else null, policy);
    defer selected.view.deinit();
    var owner: KV = .{ .storage = selected.view.table };
    defer selected.view.table = owner.storage;
    const guard = selected.current;
    const result: Result = switch (request) {
        .observe => .{ .definition = try definition(&owner.storage, selected.view.properties) },
        .operation => |binding| blk: {
            if (try c.OperationBinding.lookup(scratch, catalog.data_objects, binding.identity)) |known| try known.requireSame(binding);
            break :blk .{ .operation = try owner.observe(binding, guard) };
        },
        .mutate => |mutation| blk: {
            const spec = (try s.KVDeclaration.fromPhysical(owner.storage.declaration.definition)).spec;
            const changes = try mutation.decodeChanges(scratch, spec);
            try c.OperationBinding.claim(scratch, catalog.data_objects, mutation.binding);
            if (try owner.observe(mutation.binding, guard) == null) try catalog.kvReady(mutation.binding.target, guard);
            owner.storage.lose_reply = catalog.lose_table_reply;
            _ = owner.apply(mutation.binding, changes, guard) catch |err| switch (err) {
                error.TableBuildBudget => return error.KVBuildBudget,
                else => return err,
            };
            break :blk .{ .operation = try owner.observe(mutation.binding, guard) orelse return error.InvalidKVOutcome };
        },
        .get => |value| blk: {
            const key = try keyBytes(scratch, value.key);
            var basis: Read = .{ .interpretation = owner.storage.root.declared(), .position = .{ .partition = owner.storage.root.partition, .next_lsn = owner.storage.root.next_lsn }, .changed_lsn = owner.storage.root.changed_lsn, .spec = (try s.KVDeclaration.fromPhysical(owner.storage.declaration.definition)).spec, .source = value.source, .workspace = owner.storage.workspace_read, .encoded = null };
            if (basis.workspace) |view| {
                if (value.source != null) return error.UnsupportedTransactionRead;
                basis.position = view.source.source.accepted;
                basis.changed_lsn = view.source.changed_lsn;
            }
            if (value.source) |source| {
                var retained = try owner.storage.inspectSnapshot(scratch, source, guard);
                defer retained.deinit();
                if (retained.root.kind != .kv) return error.CatalogKindMismatch;
                basis.interpretation = retained.root.declared();
                basis.position = retained.position();
                basis.changed_lsn = retained.changedLsn();
                basis.spec = try s.KVDeclaration.validateSchema(retained.schema.schema);
            }
            var row = (if (value.source) |source| try owner.readSnapshot(scratch, source, key, guard) else try owner.get(scratch, key, guard)) orelse break :blk .{ .value = basis };
            defer row.deinit();
            const field: c.fuze.Types.Field = .{ .name = "value", .type = basis.spec.typeOf(), .nullable = basis.spec.nullable };
            const buffer = try scratch.alloc(u8, c.fuze.Types.Codec.max_bytes);
            const bytes = try c.fuze.Types.Codec.encodeBound(row.cell(), field, buffer);
            basis.encoded = try w.Binary.encode(output, bytes);
            break :blk .{ .value = basis };
        },
        .pin => |value| .{ .pin = try owner.pin(value.owner, value.expected, guard) },
        .pin_status => |value| .{ .pin_status = try owner.storage.pinState(value.owner, guard) },
        .release => |value| blk: {
            try owner.releaseSnapshot(value.source, guard);
            break :blk .released;
        },
    };
    errdefer result.deinit(output);
    try authorize(guard);
    return result;
}

pub fn definition(owner: *s.TablePartition, properties: c.DirectCatalog.Properties) !Definition {
    const declared = try s.KVDeclaration.fromPhysical(owner.declaration.definition);
    return .{ .interpretation = owner.root.declared(), .namespace = properties.namespace, .name = properties.name, .authorization = properties.authorization, .spec = declared.spec, .retired = owner.root.retired, .position = .{ .partition = owner.root.partition, .next_lsn = owner.root.next_lsn }, .changed_lsn = owner.root.changed_lsn };
}
