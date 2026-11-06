//! Pure HTTP capture-envelope binding. No lookup, publication or permission is
//! implied by validating an explicitly supplied Stream schema/configuration.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const q = c.protocol.StreamQueueDeclaration;
pub const fields = [_]f.Types.Field{
    .{ .name = "capture_id", .type = .uuid, .nullable = false },
    .{ .name = "source_sequence", .type = .uint64, .nullable = false },
    .{ .name = "observed_at", .type = .{ .timestamp = .utc }, .nullable = false },
    .{ .name = "http_status", .type = .int32, .nullable = false },
    .{ .name = "body_ref", .type = .binary, .nullable = false },
    .{ .name = "body_bytes", .type = .uint64, .nullable = false },
    .{ .name = "body_sha256", .type = .binary, .nullable = false },
};

pub fn columns(schema: f.TableSchema.Schema, configuration: q.Configuration) ![fields.len]u64 {
    try schema.validate();
    try configuration.validate();
    if (configuration.policy != .stream or configuration.partitioning.count != 1 or
        configuration.partitioning.key_column != null or configuration.policy.stream.compact_key_column != null)
        return error.UnsupportedSourceDestination;
    if (schema.columns.len != fields.len or schema.primary_key.len != 0 or !schema.integrity.empty()) return error.SourceSchemaMismatch;
    var result: [fields.len]u64 = undefined;
    for (fields, &result) |expected, *id| {
        const index = schema.named(expected.name) catch return error.SourceSchemaMismatch;
        const actual = schema.columns[index];
        if (!try actual.type.eql(expected.type) or actual.nullable or actual.default != null) return error.SourceSchemaMismatch;
        id.* = actual.id;
    }
    if (configuration.policy.stream.timestamp_column) |id| if (id != result[2]) return error.SourceSchemaMismatch;
    return result;
}

const example = "CREATE STREAM captures (capture_id UUID NOT NULL, source_sequence UINT64 NOT NULL, observed_at TIMESTAMPTZ NOT NULL, http_status INTEGER NOT NULL, body_ref BINARY NOT NULL, body_bytes UINT64 NOT NULL, body_sha256 BINARY NOT NULL)";

test "capture envelope binds stable IDs by name independently of column order" {
    const t = std.testing;
    var parsed = try f.LogDdl.compile(t.allocator, example, .transit, null);
    defer parsed.deinit();
    const schema = try parsed.statement.action.create.bind(7);
    const configured = try parsed.statement.configure(null, schema);
    try t.expectEqual([7]u64{ 1, 2, 3, 4, 5, 6, 7 }, try columns(schema, configured.configuration));
    var reordered: [7]f.TableSchema.Column = undefined;
    for (schema.columns, 0..) |column, i| reordered[6 - i] = column;
    var changed = schema;
    changed.columns = &reordered;
    try t.expectEqual([7]u64{ 1, 2, 3, 4, 5, 6, 7 }, try columns(changed, configured.configuration));
    reordered[0].nullable = true;
    try t.expectError(error.SourceSchemaMismatch, columns(changed, configured.configuration));
    reordered[0].nullable = false;
    reordered[0].name = "unrelated";
    try t.expectError(error.SourceSchemaMismatch, columns(changed, configured.configuration));
}

test "capture envelope rejects civil timestamps defaults compaction and partition routing" {
    const t = std.testing;
    var parsed = try f.LogDdl.compile(t.allocator, example, .transit, null);
    defer parsed.deinit();
    var schema = try parsed.statement.action.create.bind(7);
    const configured = try parsed.statement.configure(null, schema);
    var mutable: [7]f.TableSchema.Column = undefined;
    @memcpy(&mutable, schema.columns);
    schema.columns = &mutable;
    mutable[2].type = .{ .timestamp = .civil };
    try t.expectError(error.SourceSchemaMismatch, columns(schema, configured.configuration));
    mutable[2].type = .{ .timestamp = .utc };
    mutable[3].default = .{ .value = .{ .atom = .{ .signed = 200 } } };
    try t.expectError(error.SourceSchemaMismatch, columns(schema, configured.configuration));
    mutable[3].default = null;
    var routing = configured.configuration;
    routing.partitioning.count = 2;
    try t.expectError(error.UnsupportedSourceDestination, columns(schema, routing));
    routing = configured.configuration;
    routing.partitioning.key_column = 1;
    try t.expectError(error.UnsupportedSourceDestination, columns(schema, routing));
    routing = configured.configuration;
    routing.policy.stream.compact_key_column = 1;
    try t.expectError(error.UnsupportedSourceDestination, columns(schema, routing));
    schema.columns = mutable[0..6];
    try t.expectError(error.SourceSchemaMismatch, columns(schema, configured.configuration));
}
