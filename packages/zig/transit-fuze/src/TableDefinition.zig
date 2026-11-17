//! Neutral Table definition comparison. No catalog or storage dependency.
const std = @import("std");
const f = @import("root.zig");

/// Full definition under a fixed object/revision. Column and constraint identities
/// remain significant: this is suitable for immutable CREATE plus additive history,
/// not an inference of equivalent identities after arbitrary rewrites.
pub fn fingerprint(schema: f.TableSchema.Schema) ![32]u8 {
    var normalized = schema;
    normalized.object = 1;
    normalized.revision = 1;
    return normalized.fingerprint();
}

/// Canonical SHA-256 fingerprint of a Table's logical and physical column and
/// key shape, independent of catalog object ID, revision or internal ColumnId.
pub fn logicalFingerprint(schema: f.TableSchema.Schema) ![32]u8 {
    if (schema.columns.len == 0 or schema.columns.len > f.TableSchema.max_columns) return error.InvalidColumnCount;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.migration.logical-schema.v1\x00");
    var count_bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &count_bytes, @intCast(schema.columns.len), .little);
    hash.update(&count_bytes);
    var descriptor: [f.Types.max_encoding_bytes]u8 = undefined;
    var default_bytes: [f.TableSchema.max_bytes]u8 = undefined;
    for (schema.columns) |column| {
        hash.update(&.{@intCast(column.name.len)});
        hash.update(column.name);
        const type_bytes = try column.type.encode(&descriptor);
        std.mem.writeInt(u16, &count_bytes, @intCast(type_bytes.len), .little);
        hash.update(&count_bytes);
        hash.update(type_bytes);
        var max_chars: [4]u8 = undefined;
        std.mem.writeInt(u32, &max_chars, column.max_characters orelse 0, .little);
        hash.update(&max_chars);
        hash.update(&.{
            @intFromBool(column.nullable),
            @backingInt(column.encoding),
            @backingInt(column.collation),
            @intFromBool(column.default != null),
        });
        if (column.default) |cell| {
            const encoded = try f.Types.Codec.encode(cell, column.field(), &default_bytes);
            var len_bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &len_bytes, @intCast(encoded.len), .little);
            hash.update(&len_bytes);
            hash.update(encoded);
        }
    }
    std.mem.writeInt(u16, &count_bytes, @intCast(schema.primary_key.len), .little);
    hash.update(&count_bytes);
    for (schema.primary_key) |pk_id| {
        const col_index = try schema.index(pk_id);
        const pk_name = schema.columns[col_index].name;
        hash.update(&.{@intCast(pk_name.len)});
        hash.update(pk_name);
    }
    return hash.finalResult();
}

/// Includes constraint identities, validation state and bound column references.
pub fn integrityFingerprint(schema: f.TableSchema.Schema) ![32]u8 {
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try schema.integrity.write(schema, &writer);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &digest, .{});
    return digest;
}
