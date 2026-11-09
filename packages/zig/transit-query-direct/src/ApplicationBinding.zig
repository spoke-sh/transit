//! Immutable resource inputs to an ordered program. Each value reconstructs
//! its native definition; neither a schema nor a saved binding grants access.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const p = q.protocol;
const d = p.DataLifecycle;
const a = f.ApplicationProgram;
const w = c.DirectTableProtocol;
const Self = @This();

pub const Table = struct {
    stored: c.storage.TableDeclaration.Stored,
    properties: c.DirectCatalog.Properties,
    schema: w.Binary,
};
pub const KV = struct {
    stored: c.storage.TableDeclaration.Stored,
    properties: c.DirectCatalog.Properties,
    spec: c.storage.KVDeclaration.Spec,
};
value: union(enum) { table: Table, kv: KV, log: c.DirectLogProtocol.Definition },

pub fn table(value: w.Definition) Self {
    return .{ .value = .{ .table = .{ .stored = value.interpretation, .schema = value.schema, .properties = .{
        .namespace = value.namespace,
        .authorization = value.authorization,
        .name = value.name,
        .document = value.document,
        .native_binding = value.native_binding,
    } } } };
}
pub fn kv(value: c.DirectKV.Definition) Self {
    return .{ .value = .{ .kv = .{ .stored = value.interpretation, .spec = value.spec, .properties = .{
        .namespace = value.namespace,
        .authorization = value.authorization,
        .name = value.name,
        .native_binding = value.native_binding,
    } } } };
}
pub fn interpretation(self: Self) d.Definition {
    return switch (self.value) {
        inline .table, .kv => |v| v.stored.interpretation,
        .log => |v| v.declaration.stored.declaration.interpretation,
    };
}
pub fn name(self: Self) c.TableAuthority.Name {
    return switch (self.value) {
        inline .table, .kv => |v| v.properties.name,
        .log => |v| v.declaration.properties.name,
    };
}
pub fn namespace(self: Self) u64 {
    return switch (self.value) {
        inline .table, .kv => |v| v.properties.namespace,
        .log => |v| v.declaration.properties.namespace,
    };
}
pub fn nativeBinding(self: Self) ?f.NativeBinding.Kind {
    return switch (self.value) {
        inline .table, .kv => |v| v.properties.native_binding,
        .log => null,
    };
}
pub fn kind(self: Self) @FieldType(a.Types.Resource, "kind") {
    return switch (self.value) {
        .table => |v| if (v.properties.document != null) .document else .table,
        .kv => .kv,
        .log => |v| if (v.declaration.kind() == .queue) .queue else .stream,
    };
}
pub fn validate(self: Self, allocator: std.mem.Allocator, connection: w.Connection) !void {
    try connection.validate();
    try connection.object(self.interpretation().object);
    switch (self.value) {
        .table => |v| {
            if (v.stored.kind != .table or v.stored.retired) return error.TableDefinitionChanged;
            const bytes = try v.schema.decode(allocator, f.TableSchema.max_bytes);
            defer allocator.free(bytes);
            var decoded = try f.TableSchema.decode(allocator, bytes);
            defer decoded.deinit();
            if (v.properties.native_binding) |native| try c.NativeBindingSchema.validate(native, decoded.schema, false);
            var buffer: [c.storage.TableDeclaration.max_properties_bytes]u8 = undefined;
            var prepared = try c.storage.TableDeclaration.prepare(allocator, .{
                .kind = .table,
                .object = v.stored.interpretation.object,
                .revision = v.stored.interpretation.revision,
                .schema = decoded.schema,
                .properties = try v.properties.encode(&buffer),
            });
            defer prepared.deinit();
            if (!std.meta.eql(v.stored, try prepared.stored())) return error.TableDefinitionChanged;
        },
        .kv => |v| {
            if (v.stored.kind != .kv or v.stored.retired or v.properties.document != null) return error.TableDefinitionChanged;
            if (v.properties.native_binding) |native| {
                var columns: [2]f.TableSchema.Column = undefined;
                try c.NativeBindingSchema.validate(native, v.spec.schema(v.stored.interpretation.object.object, &columns), true);
            }
            var buffer: [c.storage.TableDeclaration.max_properties_bytes]u8 = undefined;
            var prepared = try c.storage.KVDeclaration.prepare(allocator, .{
                .object = v.stored.interpretation.object,
                .revision = v.stored.interpretation.revision,
                .spec = v.spec,
                .properties = try v.properties.encode(&buffer),
            });
            defer prepared.deinit();
            if (!std.meta.eql(v.stored, try prepared.stored())) return error.TableDefinitionChanged;
        },
        .log => |v| {
            if (v.declaration.stored.retired) return error.TableDefinitionChanged;
            try c.DirectLogProtocol.validateMetadata(allocator, connection, v);
        },
    }
}

/// Output owns all names and fields. No row position or lease enters the
/// definition: those are observations of an invocation's actual reads.
pub fn resource(self: Self, output: std.mem.Allocator, connection: w.Connection) !a.Types.Resource {
    try self.validate(output, connection);
    var result: a.Types.Resource = .{ .name = try output.dupe(u8, self.name().slice()), .kind = self.kind(), .fields = undefined };
    if (self.value == .kv) {
        const spec = self.value.kv.spec;
        if (spec.value_type != .row or spec.nullable) return error.ProgramTypeMismatch;
        result.fields = (try q.ApplicationData.bindField(output, .{ .name = "value", .type = spec.typeOf(), .nullable = false })).fields;
        return result;
    }
    const encoded = switch (self.value) {
        .table => |v| v.schema,
        .log => |v| v.schema,
        .kv => unreachable,
    };
    const bytes = try encoded.decode(output, f.TableSchema.max_bytes);
    defer output.free(bytes);
    var decoded = try f.TableSchema.decode(output, bytes);
    defer decoded.deinit();
    const schema = decoded.schema;
    if (schema.columns.len > a.max_arguments) return error.ProgramTooComplex;
    const fields = try output.alloc(a.Types.Field, schema.columns.len);
    for (schema.columns, fields) |column, *field| field.* = .{
        .name = try output.dupe(u8, column.name),
        .value = try q.ApplicationData.bindField(output, .{ .name = column.name, .type = column.type, .nullable = column.nullable }),
    };
    result.fields = fields;
    const keys = try output.alloc([]const u8, schema.primary_key.len);
    for (schema.primary_key, keys) |id, *key| key.* = try output.dupe(u8, schema.columns[try schema.index(id)].name);
    result.key = keys;
    return result;
}

/// Required actions are descriptive inputs to the existing dependency owner.
/// Registering them or retaining a binding never caches a permission grant.
/// The current common transaction owner acquires a read cut for write targets
/// too; readiness must expose those native requirements before execution.
pub fn privileges(self: Self, use: a.Types.Use) !u64 {
    if (use.dispatch or (use.consume and self.kind() != .queue)) return error.ProgramResourceKindMismatch;
    return switch (self.kind()) {
        .table, .document => (if (use.read or use.guard or use.write) @as(u64, c.TableAuthority.select) else 0) |
            (if (use.write) @as(u64, c.TableAuthority.insert) else 0),
        .kv => (if (use.read or use.guard or use.write) c.KVAuthority.read |
            @as(u64, if (self.value.kv.properties.native_binding == .secret_references) c.KVAuthority.use_secret else 0) else 0) |
            (if (use.write) @as(u64, c.KVAuthority.write) else 0),
        .queue, .stream => (if (use.read or use.write) @as(u64, c.LogAuthority.read) else 0) |
            (if (use.write) @as(u64, c.LogAuthority.append) else 0) |
            (if (use.consume) @as(u64, c.LogAuthority.acquire | c.LogAuthority.settle) else 0),
        .sink => unreachable,
    };
}

/// Resolve the same name and compare its immutable definition through signed
/// public owners. The actual read/write still performs its own current check.
pub fn requireCurrent(self: Self, client: c.DirectTableClient) !void {
    try self.validate(client.allocator, client.connection);
    const response = try client.call(switch (self.kind()) {
        .table => .{ .lookup = .{ .namespace = self.namespace(), .name = self.name().slice() } },
        .document => .{ .document_lookup = .{ .namespace = self.namespace(), .name = self.name().slice() } },
        .kv => .{ .kv_lookup = .{ .namespace = self.namespace(), .name = self.name().slice() } },
        .queue, .stream => .{ .log_lookup = .{ .namespace = self.namespace(), .name = self.name().slice() } },
        .sink => unreachable,
    });
    defer response.deinit();
    const current = switch (response.value.result) {
        .lookup => |v| (v orelse return error.TableDefinitionChanged).interpretation.interpretation,
        .document_lookup => |v| (v orelse return error.TableDefinitionChanged).definition.interpretation.interpretation,
        .kv_lookup => |v| (v orelse return error.TableDefinitionChanged).interpretation.interpretation,
        .log_lookup => |v| (v orelse return error.TableDefinitionChanged).declaration.stored.declaration.interpretation,
        else => return error.InvalidTableResponse,
    };
    if (!std.meta.eql(current, self.interpretation())) return error.TableDefinitionChanged;
}

test "application bindings freeze native definitions independently of changing row positions" {
    const t = std.testing;
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const connection: w.Connection = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .branch = 1, .audience = 5, .principal = 17, .role = 3 };
    const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .row, .nullable = false, .fields = &.{.{ .name = "count", .type = .int64, .nullable = false }} };
    const props: c.DirectCatalog.Properties = .{ .namespace = 1, .name = try .init("state"), .authorization = 12 };
    var buffer: [c.storage.TableDeclaration.max_properties_bytes]u8 = undefined;
    var native = try c.storage.KVDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = connection.scope, .branch = connection.branch, .object = 14 },
        .revision = 1,
        .spec = spec,
        .properties = try props.encode(&buffer),
    });
    defer native.deinit();
    var metadata: c.DirectKV.Definition = .{ .interpretation = try native.stored(), .spec = spec, .namespace = 1, .name = props.name, .authorization = 12, .retired = false, .position = .{ .partition = 14, .next_lsn = 2 }, .changed_lsn = 2 };
    const original = kv(metadata);
    metadata.position.next_lsn = 99;
    metadata.changed_lsn = 98;
    try t.expectEqualDeep(original, kv(metadata));
    const bound = try original.resource(output.allocator(), connection);
    try t.expectEqualStrings("state", bound.name);
    try t.expectEqual(.integer, bound.fields[0].value.kind);
    try t.expectEqual(c.KVAuthority.read | c.KVAuthority.write, try original.privileges(.{ .resource = 0, .read = true, .write = true }));
    var forged = original;
    forged.value.kv.properties.name = try .init("other");
    try t.expectError(error.TableDefinitionChanged, forged.validate(t.allocator, connection));
    forged = original;
    forged.value.kv.properties.document = .{ .profile = .versioned };
    try t.expectError(error.TableDefinitionChanged, forged.validate(t.allocator, connection));
}
