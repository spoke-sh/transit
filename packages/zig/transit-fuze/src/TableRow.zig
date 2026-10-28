//! Schema-bound immutable rows and canonical primary-key equality. Storage,
//! collision buckets, admission and row-ID allocation belong to the Table owner.
const std = @import("std");
const t = @import("Types.zig");
const s = @import("TableSchema.zig");
const Cell = t.Values.Cell;
pub const definition = "transit.table.row.v1.2026-10-05";
pub const header_bytes = 4 + 1 + definition.len + 32 + Identity.encoded_bytes;
pub const max_bytes = header_bytes + t.Codec.max_bytes;
pub const max_key_bytes = t.Codec.max_bytes + s.max_bytes;
pub const Identity = struct {
    /// Owner-defined durable origin and original operation identity. Retrying
    /// accepted work must reuse both; the ordinal is zero-based within the work.
    origin: u64,
    operation: u64,
    ordinal: u32,
    pub const encoded_bytes = 20;
    pub fn validate(self: Identity) !void {
        if (self.origin == 0 or self.operation == 0) return error.InvalidRowIdentity;
    }
    /// Lexicographic ordering is identity ordering, independent of user keys.
    pub fn encode(self: Identity) ![encoded_bytes]u8 {
        try self.validate();
        var bytes: [encoded_bytes]u8 = undefined;
        std.mem.writeInt(u64, bytes[0..8], self.origin, .big);
        std.mem.writeInt(u64, bytes[8..16], self.operation, .big);
        std.mem.writeInt(u32, bytes[16..20], self.ordinal, .big);
        return bytes;
    }
    pub fn decode(bytes: *const [encoded_bytes]u8) !Identity {
        const id: Identity = .{ .origin = std.mem.readInt(u64, bytes[0..8], .big), .operation = std.mem.readInt(u64, bytes[8..16], .big), .ordinal = std.mem.readInt(u32, bytes[16..20], .big) };
        try id.validate();
        return id;
    }
};
pub const Row = struct {
    identity: Identity,
    cells: []const Cell,
    /// A keyless Table preserves every row by its durable owner identity.
    /// Keyed Tables use the declared equality/order semantics instead.
    pub fn storageKey(self: Row, schema: s.Schema, output: []u8) ![]const u8 {
        try self.identity.validate();
        try schema.validateRow(self.cells);
        if (schema.primary_key.len != 0) return @import("Collation.zig").encodePrimaryKeySortKey(schema, self.cells, true, output);
        if (output.len < Identity.encoded_bytes) return error.RowBufferTooSmall;
        output[0..Identity.encoded_bytes].* = try self.identity.encode();
        return output[0..Identity.encoded_bytes];
    }
    pub fn encode(self: Row, schema: s.Schema, output: []u8) ![]const u8 {
        try self.identity.validate();
        try schema.validateRow(self.cells);
        if (output.len < header_bytes) return error.RowBufferTooSmall;
        var writer: std.Io.Writer = .fixed(output[0..header_bytes]);
        try writer.writeAll("FTR1");
        try writer.writeByte(definition.len);
        try writer.writeAll(definition);
        try writer.writeAll(&try schema.layoutFingerprint());
        try writer.writeAll(&try self.identity.encode());
        var fields: [s.max_columns]t.Field = undefined;
        var names: [s.max_columns][16]u8 = undefined;
        const field: t.Field = .{ .name = "row", .type = try schema.storageType(&fields, &names) };
        const bytes = try t.Codec.encode(.{ .value = .{ .structure = self.cells } }, field, output[header_bytes..]);
        return output[0 .. header_bytes + bytes.len];
    }
    /// Exact canonical size for read-page budgets, without materializing another
    /// copy of the row. Validation and the standalone value bound match encode.
    pub fn encodedSize(self: Row, schema: s.Schema) !usize {
        try self.identity.validate();
        try schema.validateRow(self.cells);
        _ = try schema.layoutFingerprint();
        var fields: [s.max_columns]t.Field = undefined;
        var names: [s.max_columns][16]u8 = undefined;
        const field: t.Field = .{ .name = "row", .type = try schema.storageType(&fields, &names) };
        var scratch: [256]u8 = undefined;
        var counter: std.Io.Writer.Discarding = .init(&scratch);
        try t.Codec.write(.{ .value = .{ .structure = self.cells } }, field, &counter.writer);
        const size = counter.fullCount();
        if (size > t.Codec.max_bytes) return error.WriteFailed;
        return header_bytes + @as(usize, @intCast(size));
    }
};
pub const Owned = struct {
    value: t.Codec.Decoded,
    identity: Identity,
    pub fn row(self: *const Owned) Row {
        return .{ .identity = self.identity, .cells = self.value.cell.value.structure };
    }
    pub fn deinit(self: *Owned) void {
        self.value.deinit();
        self.* = undefined;
    }
};
pub fn decode(allocator: std.mem.Allocator, schema: s.Schema, bytes: []const u8) !Owned {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const decoded = try decodeInto(arena.allocator(), schema, bytes);
    return .{ .value = .{ .descriptor = .{ .arena = arena, .type = decoded.value.field.type }, .field = decoded.value.field, .cell = decoded.value.cell }, .identity = decoded.identity };
}
pub const DecodedInto = struct {
    value: t.Codec.DecodedInto,
    identity: Identity,
    pub fn row(self: *const DecodedInto) Row {
        return .{ .identity = self.identity, .cells = self.value.cell.value.structure };
    }
};
/// The supplied arena owns all decoded data and partial-failure allocations.
/// Input may be released immediately; no per-row arena is created here.
pub fn decodeInto(arena: std.mem.Allocator, schema: s.Schema, bytes: []const u8) !DecodedInto {
    if (bytes.len > max_bytes) return error.TableRowTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FTR1")) return error.InvalidTableRowEncoding;
    if (!std.mem.eql(u8, try reader.take(try reader.takeByte()), definition)) return error.UnsupportedTableRowDefinition;
    if (!std.mem.eql(u8, try reader.take(32), &try schema.layoutFingerprint())) return error.TableSchemaChanged;
    const identity = try Identity.decode(try reader.takeArray(Identity.encoded_bytes));
    const value = try t.Codec.decodeInto(arena, try reader.take(reader.bufferedLen()));
    var fields: [s.max_columns]t.Field = undefined;
    var names: [s.max_columns][16]u8 = undefined;
    if (value.field.nullable or value.field.optional or !try value.field.type.eql(try schema.storageType(&fields, &names))) return error.InvalidTableRowEncoding;
    if (value.cell != .value or value.cell.value != .structure) return error.InvalidTableRowEncoding;
    try schema.validateRow(value.cell.value.structure);
    return .{ .value = value, .identity = identity };
}

/// Equality-compatible canonical bytes, not an order-preserving index key.
/// Names, non-key columns and schema revision do not participate. Column IDs,
/// object identity, key order and exact key descriptors do participate.
pub fn encodeKey(schema: s.Schema, cells: []const Cell, output: []u8) ![]const u8 {
    try schema.validateRow(cells);
    var key: [s.max_columns]Cell = undefined;
    for (schema.primary_key, 0..) |id, i| key[i] = cells[try schema.index(id)];
    return encodeKeyValues(schema, key[0..schema.primary_key.len], output);
}
/// Key lookup accepts only key values, with no invented non-key row cells.
pub fn encodeKeyValues(schema: s.Schema, cells: []const Cell, output: []u8) ![]const u8 {
    try schema.validateKey(cells);
    const bounded = output[0..@min(output.len, max_key_bytes)];
    var writer: std.Io.Writer = .fixed(bounded);
    try writer.writeAll("FTK1");
    try writer.writeByte(definition.len);
    try writer.writeAll(definition);
    try writer.writeInt(u64, schema.object, .little);
    try writer.writeInt(u16, @intCast(schema.primary_key.len), .little);
    for (schema.primary_key, cells) |id, value| {
        var cell = value;
        // Structural equality treats signed floating zeros as equal. Exact row
        // bytes still retain the original IEEE sign.
        if (cell.value.atom == .float and cell.value.atom.float == 0) cell.value.atom.float = 0;
        try writer.writeInt(u64, id, .little);
        // FVL1 contains its descriptor and state, with self-delimiting payloads.
        const encoded = try t.Codec.encode(cell, schema.columns[try schema.index(id)].field(), bounded[writer.end..]);
        writer.end += encoded.len;
    }
    return writer.buffered();
}
pub fn keyDigest(schema: s.Schema, cells: []const Cell, output: []u8) ![32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(try encodeKey(schema, cells, output), &digest, .{});
    return digest;
}
/// Hash collisions never establish equality; an index owner compares the actual
/// candidate keys before reporting a uniqueness conflict.
pub fn sameKey(schema: s.Schema, left: []const Cell, right: []const Cell) !bool {
    try schema.validateRow(left);
    try schema.validateRow(right);
    if (schema.primary_key.len == 0) return error.NoPrimaryKey;
    for (schema.primary_key) |id| {
        const i = try schema.index(id);
        if (!try t.Operations.eql(schema.columns[i].field(), left[i], right[i])) return false;
    }
    return true;
}

test {
    _ = @import("table_row_test.zig");
}
