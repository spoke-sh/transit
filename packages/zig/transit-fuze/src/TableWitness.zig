//! Bounded evidence captured at the rejecting execution, never reconstructed
//! from a later Table. The enclosing durable record supplies format/definition.
const std = @import("std");
const Schema = @import("TableSchema.zig");
const Row = @import("TableRow.zig");
const t = @import("Types.zig");
const display = @import("LogicalDisplay.zig");
const Self = @This();
pub const encoded_bytes = 95;
pub const preview_bytes = 64;
pub const Source = enum(u8) { none = 0, input = 1, stored = 2, withheld = 3 };
source: Source = .none,
row: Row.Identity = .{ .origin = 0, .operation = 0, .ordinal = 0 },
/// Zero identifies the complete primary key or row identity; otherwise the
/// stable column ID identifies the actual failing cell in the bound schema.
column: Schema.ColumnId = 0,
length: u8 = 0,
truncated: bool = false,
preview: [preview_bytes]u8 = @splat(0),
pub fn text(self: *const Self) []const u8 {
    return self.preview[0..self.length];
}
pub fn validate(self: Self) !void {
    if (self.length > preview_bytes or !std.mem.allEqual(u8, self.preview[self.length..], 0) or !std.unicode.utf8ValidateSlice(self.text())) return error.InvalidTableWitness;
    for (self.text()) |byte| if (byte < 32 or byte == 127) return error.InvalidTableWitness;
    if (self.source == .none or self.source == .withheld) {
        if (self.row.origin != 0 or self.row.operation != 0 or self.row.ordinal != 0 or self.length != 0 or self.truncated) return error.InvalidTableWitness;
        if (self.source == .none and self.column != 0) return error.InvalidTableWitness;
    } else try self.row.validate();
}
/// A presentation view can withhold stored-row evidence. Withheld is forbidden
/// in durable encoding, so a projection cannot replace recorded evidence.
pub fn disclose(self: Self, read: bool) !Self {
    try self.validate();
    return if (self.source == .stored and !read) .{ .source = .withheld, .column = self.column } else self;
}
pub fn encode(self: Self) ![encoded_bytes]u8 {
    try self.validate();
    if (self.source == .withheld) return error.InvalidTableWitness;
    var bytes: [encoded_bytes]u8 = @splat(0);
    bytes[0] = @backingInt(self.source);
    if (self.source != .none) bytes[1..21].* = try self.row.encode();
    std.mem.writeInt(u64, bytes[21..29], self.column, .little);
    bytes[29] = self.length;
    bytes[30] = @intFromBool(self.truncated);
    bytes[31..].* = self.preview;
    return bytes;
}
pub fn decode(bytes: []const u8) !Self {
    if (bytes.len != encoded_bytes or bytes[0] > 2 or bytes[30] > 1) return error.InvalidTableWitness;
    const source = std.enums.fromInt(Source, bytes[0]) orelse return error.InvalidTableWitness;
    if (source == .none and !std.mem.allEqual(u8, bytes[1..21], 0)) return error.InvalidTableWitness;
    const result: Self = .{
        .source = source,
        .row = if (source == .none) .{ .origin = 0, .operation = 0, .ordinal = 0 } else try Row.Identity.decode(bytes[1..21]),
        .column = std.mem.readInt(u64, bytes[21..29], .little),
        .length = bytes[29],
        .truncated = bytes[30] == 1,
        .preview = bytes[31..95].*,
    };
    try result.validate();
    return result;
}
fn start(source: Source, row: Row.Identity, column: Schema.ColumnId) !Self {
    if (source != .input and source != .stored) return error.InvalidTableWitness;
    try row.validate();
    return .{ .source = source, .row = row, .column = column };
}
fn finish(self: *Self, out: *std.Io.Writer) void {
    self.length = @intCast(out.buffered().len);
    // Current display is escaped ASCII. Keep a complete UTF-8 prefix even if
    // a future formatter adds printable Unicode under a coordinated cutover.
    while (!std.unicode.utf8ValidateSlice(self.preview[0..self.length])) self.length -= 1;
    @memset(self.preview[self.length..], 0);
}
pub fn identity(source: Source, row: Row.Identity) !Self {
    return start(source, row, 0);
}
pub fn key(source: Source, schema: Schema.Schema, row: Row.Row) !Self {
    try schema.validateRow(row.cells);
    if (schema.primary_key.len == 0) return error.NoPrimaryKey;
    var result = try start(source, row.identity, 0);
    var out: std.Io.Writer = .fixed(&result.preview);
    keyText(&out, schema, row.cells) catch |err| {
        if (err != error.WriteFailed) return err;
        result.truncated = true;
    };
    result.finish(&out);
    try result.validate();
    return result;
}
fn keyText(out: *std.Io.Writer, schema: Schema.Schema, cells: []const t.Values.Cell) !void {
    if (schema.primary_key.len > 1) try out.writeByte('(');
    for (schema.primary_key, 0..) |id, i| {
        if (i != 0) try out.writeAll(", ");
        const column = try schema.index(id);
        try display.cell(out, cells[column], schema.columns[column].type);
    }
    if (schema.primary_key.len > 1) try out.writeByte(')');
}
pub fn cell(source: Source, row: Row.Identity, column: Schema.ColumnId, value: t.Values.Cell, kind: t.Type) !Self {
    if (column == 0) return error.InvalidTableWitness;
    // Constraints can reject NULL/missing; descriptor validity still matters.
    try value.validate(.{ .name = "witness", .type = kind, .nullable = true, .optional = true }, .{});
    var result = try start(source, row, column);
    var out: std.Io.Writer = .fixed(&result.preview);
    display.cell(&out, value, kind) catch |err| {
        if (err != error.WriteFailed) return err;
        result.truncated = true;
    };
    result.finish(&out);
    try result.validate();
    return result;
}

test "execution witness preserves exact keys and explicitly bounds previews" {
    const e = std.testing;
    const columns = [_]Schema.Column{ .{ .id = 1, .name = "id", .type = .int128, .nullable = false }, .{ .id = 2, .name = "region", .type = .utf8, .nullable = false } };
    const schema: Schema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{ 1, 2 } };
    const id: Row.Identity = .{ .origin = 2, .operation = 8, .ordinal = 4 };
    const cells = [_]t.Values.Cell{ .{ .value = .{ .atom = .{ .signed = std.math.minInt(i128) } } }, .{ .value = .{ .atom = .{ .bytes = "east" } } } };
    const evidence = try key(.input, schema, .{ .identity = id, .cells = &cells });
    try e.expectEqualStrings("(-170141183460469231731687303715884105728, \"east\")", evidence.text());
    try e.expect(!evidence.truncated);
    try e.expectEqualDeep(evidence, try decode(&try evidence.encode()));
    const long: [128]u8 = @splat('x');
    const large = try cell(.stored, id, 2, .{ .value = .{ .atom = .{ .bytes = &long } } }, .utf8);
    try e.expect(large.truncated);
    try e.expect(large.length <= preview_bytes);
    try e.expectEqualDeep(large, try decode(&try large.encode()));
    const denied = try large.disclose(false);
    try e.expectEqual(Source.withheld, denied.source);
    try e.expectEqual(@as(u64, 2), denied.column);
    try e.expectEqualStrings("", denied.text());
    try e.expectError(error.InvalidTableWitness, denied.encode());
    try e.expectEqualDeep(evidence, try evidence.disclose(false));
}
test "execution witness rejects malformed tails flags identities and foreign presentation views" {
    const e = std.testing;
    const witness = try cell(.stored, .{ .origin = 3, .operation = 10, .ordinal = 0 }, 8, .null, .utf8);
    const original = try witness.encode();
    try e.expectEqualStrings("NULL", witness.text());
    for (0..encoded_bytes) |size| try e.expectError(error.InvalidTableWitness, decode(original[0..size]));
    for ([_]usize{ 0, 29, 30, 94 }) |index| {
        var changed = original;
        changed[index] = 255;
        try e.expectError(error.InvalidTableWitness, decode(&changed));
    }
    var withheld = original;
    withheld[0] = 3;
    try e.expectError(error.InvalidTableWitness, decode(&withheld));
    var absent: [encoded_bytes]u8 = @splat(0);
    absent[1] = 1;
    try e.expectError(error.InvalidTableWitness, decode(&absent));
}
