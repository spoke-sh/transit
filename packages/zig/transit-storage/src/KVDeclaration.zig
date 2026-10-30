//! A KV definition selects typed values and byte-exact keys. The shared row
//! engine's two physical columns are an implementation detail, not a Table API.
const std = @import("std");
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const Declaration = @import("TableDeclaration.zig");

pub const Spec = struct {
    value_type: enum { int64, boolean, utf8, binary },
    nullable: bool,

    pub fn typeOf(self: Spec) f.Types.Type {
        return switch (self.value_type) {
            .int64 => .int64,
            .boolean => .boolean,
            .utf8 => .utf8,
            .binary => .binary,
        };
    }
    pub fn schema(self: Spec, object: u64, columns: *[2]f.TableSchema.Column) f.TableSchema.Schema {
        columns.* = .{
            .{ .id = 1, .name = "key", .type = .binary, .nullable = false },
            .{ .id = 2, .name = "value", .type = self.typeOf(), .nullable = self.nullable },
        };
        return .{ .object = object, .revision = 1, .next_column = 3, .columns = columns, .primary_key = &.{1} };
    }
};

pub const Definition = struct {
    object: p.DataLifecycle.Object,
    revision: u64,
    spec: Spec,
    properties: []const u8,
    retired: bool = false,

    /// The result borrows columns and properties until prepare/init returns.
    pub fn physical(self: Definition, columns: *[2]f.TableSchema.Column) Declaration.Definition {
        return .{
            .kind = .kv,
            .object = self.object,
            .revision = self.revision,
            .schema = self.spec.schema(self.object.object, columns),
            .properties = self.properties,
            .retired = self.retired,
        };
    }
};

/// Validate the whole layout, including the persisted kind. Similar column
/// names or compatible field types alone never establish a KV interpretation.
pub fn fromPhysical(value: Declaration.Definition) !Definition {
    try value.validate();
    if (value.kind != .kv) return error.DataKindMismatch;
    return .{ .object = value.object, .revision = value.revision, .spec = try validateSchema(value.schema), .properties = value.properties, .retired = value.retired };
}

pub fn validateSchema(schema: f.TableSchema.Schema) !Spec {
    if (schema.columns.len != 2) return error.InvalidKVDeclaration;
    const column = schema.columns[1];
    const spec: Spec = .{ .value_type = switch (column.type) {
        .int64 => .int64,
        .boolean => .boolean,
        .utf8 => .utf8,
        .binary => .binary,
        else => return error.InvalidKVDeclaration,
    }, .nullable = column.nullable };
    var columns: [2]f.TableSchema.Column = undefined;
    const expected = spec.schema(schema.object, &columns);
    if (!std.mem.eql(u8, &try expected.fingerprint(), &try schema.fingerprint())) return error.InvalidKVDeclaration;
    return spec;
}

pub fn prepare(allocator: std.mem.Allocator, definition: Definition) !Declaration.Owned {
    var columns: [2]f.TableSchema.Column = undefined;
    return Declaration.prepare(allocator, definition.physical(&columns));
}
