//! Neutral general Table schemas. All identities use canonical decimal strings;
//! descriptors and defaults share the logical JSON contract. No catalog access.
const std = @import("std");
const p = @import("transit_protocol");
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const j = @import("LogicalJson.zig");
pub const max_input_bytes = 2 * 1024 * 1024;
pub const Column = struct {
    id: []const u8,
    name: []const u8,
    type: t.Type,
    nullable: bool,
    default: ?j.Cell,
    max_characters: ?u32,
    encoding: s.Encoding,
    collation: s.Collation,
    semantics: s.Semantics.Neutral,
};
pub const Schema = struct {
    pub const json_schema_sequence_bounds = .{ .columns = s.max_columns, .primary_key = s.max_columns };
    // Mandatory even for callers persisting a schema outside a saved intent.
    definition: p.Growth.Definition,
    object: []const u8,
    revision: []const u8,
    next_column: []const u8,
    columns: []const Column,
    primary_key: []const []const u8,
    integrity: @import("TableIntegrityJson.zig").Integrity = .{},
};
fn unsigned(text: []const u8) !u64 {
    if (text.len == 0 or text.len > 20 or (text.len > 1 and text[0] == '0')) return error.InvalidIntegerEncoding;
    for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidIntegerEncoding;
    return std.fmt.parseInt(u64, text, 10) catch error.InvalidIntegerEncoding;
}
fn decimal(allocator: std.mem.Allocator, value: u64) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
/// The enclosing arena owns every result byte, including borrowed-looking
/// descriptor/default children. Destroying the native input is safe on return.
pub fn foreign(arena: *std.heap.ArenaAllocator, source: s.Schema) !Schema {
    return foreignInto(arena.allocator(), source);
}
/// The supplied allocation scope owns the complete projection, including the
/// copied schema's child arena. Release that scope after consuming the result.
pub fn foreignInto(allocator: std.mem.Allocator, source: s.Schema) !Schema {
    // Child owners allocate exclusively through the enclosing arena, which
    // releases their complete storage together with the neutral projection.
    const copied = try source.clone(allocator);
    const value = copied.schema;
    const columns = try allocator.alloc(Column, value.columns.len);
    for (value.columns, columns) |column, *output| output.* = .{
        .id = try decimal(allocator, column.id),
        .name = column.name,
        .type = column.type,
        .nullable = column.nullable,
        .default = if (column.default) |cell| try j.foreignCell(allocator, cell, column.type) else null,
        .max_characters = column.max_characters,
        .encoding = column.encoding,
        .collation = column.collation,
        .semantics = try column.semantics.foreign(allocator),
    };
    const primary_key = try allocator.alloc([]const u8, value.primary_key.len);
    for (value.primary_key, primary_key) |id, *output| output.* = try decimal(allocator, id);
    return .{ .definition = p.Growth.current_definition, .object = try decimal(allocator, value.object), .revision = try decimal(allocator, value.revision), .next_column = try decimal(allocator, value.next_column), .columns = columns, .primary_key = primary_key, .integrity = try @import("TableIntegrityJson.zig").foreign(allocator, value) };
}
/// Convert through the shared schema validator, then copy into the enclosing
/// arena. No caller-owned strings, descriptor pointers or defaults survive.
pub fn native(arena: *std.heap.ArenaAllocator, value: Schema) !s.Schema {
    if (value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    if (value.columns.len == 0 or value.columns.len > s.max_columns) return error.InvalidColumnCount;
    if (value.primary_key.len > value.columns.len) return error.InvalidPrimaryKey;
    const allocator = arena.allocator();
    const columns = try allocator.alloc(s.Column, value.columns.len);
    var default_bytes: u64 = 0;
    for (value.columns, columns) |column, *output| {
        output.* = .{ .id = try unsigned(column.id), .name = column.name, .type = column.type, .nullable = column.nullable, .max_characters = column.max_characters, .encoding = column.encoding, .collation = column.collation, .semantics = try s.Semantics.native(column.semantics, allocator) };
        if (column.default) |cell| {
            output.default = try j.fromForeign(allocator, cell, output.field());
            // Canonical payloads are a lower bound on the complete FTS1 record.
            // Check before converting another default; schema.clone still
            // validates descriptor/framing bytes and every schema constraint.
            var scratch: [256]u8 = undefined;
            var count: std.Io.Writer.Discarding = .init(&scratch);
            try t.Codec.writeBound(output.default.?, output.field(), &count.writer);
            if (count.fullCount() > s.max_bytes - default_bytes) return error.TableSchemaTooLarge;
            default_bytes += count.fullCount();
        }
    }
    const primary_key = try allocator.alloc(s.ColumnId, value.primary_key.len);
    for (value.primary_key, primary_key) |id, *output| output.* = try unsigned(id);
    var schema: s.Schema = .{ .object = try unsigned(value.object), .revision = try unsigned(value.revision), .next_column = try unsigned(value.next_column), .columns = columns, .primary_key = primary_key };
    schema.integrity = try @import("TableIntegrityJson.zig").native(allocator, value.integrity, schema);
    return (try schema.clone(allocator)).schema;
}
pub fn encode(allocator: std.mem.Allocator, schema: s.Schema) ![]u8 {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const wire = try foreign(&arena, schema);
    // This fixed neutral schema has no custom serializers or I/O. Its
    // allocating writer can fail only when it cannot grow the output buffer.
    const bytes = p.Json.valueAlloc(allocator, wire) catch |err| return if (err == error.WriteFailed) error.OutOfMemory else err;
    errdefer allocator.free(bytes);
    if (bytes.len > max_input_bytes) return error.JsonByteBudgetExceeded;
    return bytes;
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !s.Owned {
    try t.Json.preflight(bytes, .{ .bytes = max_input_bytes, .depth = 96, .tokens = 1024 * 1024, .fields = 256 });
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const parsed = try p.Json.parseFromSlice(Schema, arena.allocator(), bytes);
    const schema = try native(&arena, parsed.value);
    return .{ .arena = arena, .schema = schema };
}

test {
    _ = @import("table_schema_json_test.zig");
}
