//! Schema-bound append payloads. A batch is finite operation work, not a resident
//! durable backlog. Callers provide separate retained output and reusable row
//! scratch. Physical WAL LSNs and logical offsets are not row identities.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const q = p.StreamQueueDeclaration;
pub const header_bytes = 77;
pub const row_header_bytes = 13;
pub const Row = struct { cells: []const f.Types.Values.Cell, visible_ms: u64 = 0, tombstone: bool = false };

fn identity(operation: d.Operation, ordinal: u32) !f.TableRow.Identity {
    try operation.validate();
    // Native principal IDs are bounded below u64's maximum. Adding one leaves
    // root principal zero representable without introducing an invalid origin.
    return .{ .origin = operation.principal + 1, .operation = operation.operation, .ordinal = ordinal };
}

pub fn encode(schema: f.TableSchema.Schema, operation: d.Operation, kind: q.Kind, rows: []const Row, output: []u8) ![]const u8 {
    if (rows.len > std.math.maxInt(u32)) return error.InvalidLogBatch;
    var encoder = try Encoder.init(schema, operation, kind, @intCast(rows.len), output);
    for (rows) |row| try encoder.append(row);
    return encoder.finish();
}

/// Streaming serialization into one fixed caller buffer. Schema and row values
/// borrow their callers; only the resulting encoded prefix is retained.
pub const Encoder = struct {
    schema: f.TableSchema.Schema,
    operation: d.Operation,
    kind: q.Kind,
    count: u32,
    ordinal: u32 = 0,
    output: []u8,
    at: usize = header_bytes,
    pub fn init(schema: f.TableSchema.Schema, operation: d.Operation, kind: q.Kind, count: u32, output: []u8) !Encoder {
        try operation.validate();
        try schema.validate();
        if (count == 0 or output.len < header_bytes) return error.InvalidLogBatch;
        output[0..8].* = "LOGBAT01".*;
        output[8..40].* = p.Growth.definition_bytes;
        output[40..72].* = try schema.layoutFingerprint();
        output[72] = if (kind == .stream) 1 else 2;
        std.mem.writeInt(u32, output[73..77], count, .big);
        return .{ .schema = schema, .operation = operation, .kind = kind, .count = count, .output = output };
    }
    pub fn append(self: *Encoder, row: Row) !void {
        if (self.ordinal >= self.count) return error.InvalidLogBatch;
        if ((self.kind == .stream and row.visible_ms != 0) or (self.kind == .queue and row.tombstone)) return error.InvalidLogRowMetadata;
        if (self.output.len - self.at < row_header_bytes) return error.LogBatchTooLarge;
        const encoded_row: f.TableRow.Row = .{ .identity = try identity(self.operation, self.ordinal), .cells = row.cells };
        const bytes = try encoded_row.encode(self.schema, self.output[self.at + row_header_bytes ..]);
        std.mem.writeInt(u32, self.output[self.at..][0..4], @intCast(bytes.len), .big);
        std.mem.writeInt(u64, self.output[self.at + 4 ..][0..8], row.visible_ms, .big);
        self.output[self.at + 12] = @intFromBool(row.tombstone);
        self.at += row_header_bytes + bytes.len;
        self.ordinal += 1;
    }
    pub fn finish(self: Encoder) ![]const u8 {
        if (self.ordinal != self.count) return error.InvalidLogBatch;
        return self.output[0..self.at];
    }
};

pub fn content(bytes: []const u8) d.Content {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .bytes = bytes.len, .sha256 = digest };
}

pub const EncodedRow = struct {
    ordinal: u32,
    visible_ms: u64,
    tombstone: bool,
    bytes: []const u8,

    /// Retained output must not use an arena that the caller resets before
    /// finishing with these cells. Validation can use reusable row scratch.
    pub fn decode(self: EncodedRow, output: std.mem.Allocator, schema: f.TableSchema.Schema, operation: d.Operation) !Row {
        const decoded = try f.TableRow.decodeInto(output, schema, self.bytes);
        if (!std.meta.eql(decoded.identity, try identity(operation, self.ordinal))) return error.LogRowIdentityConflict;
        return .{ .cells = decoded.row().cells, .visible_ms = self.visible_ms, .tombstone = self.tombstone };
    }
};

pub const Iterator = struct {
    bytes: []const u8,
    kind: q.Kind,
    count: u32,
    ordinal: u32 = 0,
    at: usize = header_bytes,

    pub fn init(bytes: []const u8, schema: f.TableSchema.Schema, kind: q.Kind, expected_rows: u64) !Iterator {
        if (bytes.len < header_bytes or !std.mem.eql(u8, bytes[0..8], "LOGBAT01")) return error.InvalidLogBatch;
        if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        if (!std.mem.eql(u8, bytes[40..72], &try schema.layoutFingerprint())) return error.TableSchemaChanged;
        if (bytes[72] != @as(u8, if (kind == .stream) 1 else 2)) return error.LogBatchKindConflict;
        const count = std.mem.readInt(u32, bytes[73..77], .big);
        if (count == 0 or count != expected_rows or count > (bytes.len - header_bytes) / (row_header_bytes + f.TableRow.header_bytes)) return error.InvalidLogBatch;
        return .{ .bytes = bytes, .kind = kind, .count = count };
    }

    pub fn next(self: *Iterator) !?EncodedRow {
        if (self.ordinal == self.count) {
            if (self.at != self.bytes.len) return error.InvalidLogBatch;
            return null;
        }
        if (self.bytes.len - self.at < row_header_bytes) return error.InvalidLogBatch;
        const bytes = self.bytes[self.at..];
        const length = std.mem.readInt(u32, bytes[0..4], .big);
        const visible = std.mem.readInt(u64, bytes[4..12], .big);
        if (length < f.TableRow.header_bytes or length > bytes.len - row_header_bytes or length > f.TableRow.max_bytes) return error.InvalidLogBatch;
        if (bytes[12] > 1 or (self.kind == .stream and visible != 0) or (self.kind == .queue and bytes[12] != 0)) return error.InvalidLogRowMetadata;
        const result: EncodedRow = .{ .ordinal = self.ordinal, .visible_ms = visible, .tombstone = bytes[12] == 1, .bytes = bytes[row_header_bytes..][0..length] };
        self.at += row_header_bytes + length;
        self.ordinal += 1;
        if (self.ordinal == self.count and self.at != self.bytes.len) return error.InvalidLogBatch;
        return result;
    }
};

/// The caller initializes this arena outside the hot path and retains its
/// capacity between rows/batches. No decoded row survives a scratch reset.
pub fn validate(bytes: []const u8, declaration: *const @import("LogDeclaration.zig").Owned, append: p.StreamQueue.Append, scratch: *std.heap.ArenaAllocator, key_buffer: []u8) !void {
    try append.validate();
    const definition = declaration.definition;
    try definition.validate();
    const stored = try declaration.stored();
    try append.target.requireSame(.{ .definition = p.Growth.current_definition, .interpretation = stored.declaration.interpretation, .partition = append.target.partition });
    defer _ = scratch.reset(.retain_capacity);
    if (!std.meta.eql(append.target.interpretation.object, definition.object) or append.target.interpretation.revision != definition.revision or append.target.partition >= definition.configuration.partitioning.count or append.kind != @as(@FieldType(p.StreamQueue.Append, "kind"), if (definition.configuration.policy == .stream) .stream else .queue)) return error.LogPartitionConflict;
    if (bytes.len > definition.limits.append_bytes or append.rows > definition.limits.append_rows) return error.LogAppendLimitExceeded;
    if (!std.meta.eql(append.payload, content(bytes))) return error.LogPayloadConflict;
    const kind: q.Kind = if (append.kind == .stream) .stream else .queue;
    var iterator = try Iterator.init(bytes, definition.schema, kind, append.rows);
    while (try iterator.next()) |encoded| {
        _ = scratch.reset(.retain_capacity);
        const row = try encoded.decode(scratch.allocator(), definition.schema, append.operation);
        if (row.tombstone and definition.configuration.policy.stream.compact_key_column == null) return error.StreamCompactionNotDeclared;
        if (definition.configuration.partitioning.key_column) |column_id| {
            const index = try definition.schema.index(column_id);
            const column = definition.schema.columns[index];
            const key = try f.Collation.encodeSortKey(row.cells[index], column.type, column.collation, key_buffer);
            if (try definition.configuration.partitioning.select(key) != append.target.partition) return error.LogPartitionKeyMismatch;
        }
    }
    _ = scratch.reset(.retain_capacity);
}
