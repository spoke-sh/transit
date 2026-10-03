//! Compact owned runtime evidence. A failed job plus this witness remains one
//! native value; no extra mutation or later source lookup is required.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const m = q.fuze.Unified;
const d = p.Diagnostic;
const Self = @This();
pub const encoded_bytes = 104;
pub const Operation = enum(u8) { validate = 1, predicate = 2, count = 3, sum = 4 };
pub const KeyKind = enum(u8) { none = 0, kv = 1, table = 2, element = 3 };
pub const Decoding = enum(u8) { none = 0, invalid_utf8 = 1, invalid_length = 2, invalid_boolean = 3, nonfinite_float = 4 };
resource: u64,
revision: u64,
binding: [32]u8,
row: u64,
kind: m.SourceKind,
operation: Operation,
column: u8,
instruction: ?u8,
expected: m.Type,
key_kind: KeyKind,
key_length: u16,
decoding: Decoding,
actual_bytes: u16,
column_length: u8,
column_truncated: bool,
/// At most 23 ASCII column bytes, then the key prefix. Remaining bytes are zero.
detail: [39]u8,

pub fn capture(bound: m.Plan.Bound, page: *const q.UnifiedSource.Batch, failed: m.Stream.Failure) !Self {
    if (failed.page_row >= page.count or failed.column >= page.column_count or failed.row == 0 or !std.meta.eql(page.basis, bound.basis)) return error.InvalidRuntimeWitness;
    const column = try bound.schema.column(failed.column);
    const name = column.name.slice();
    var value: Self = .{
        .resource = bound.basis.resource,
        .revision = bound.basis.revision,
        .binding = bound.fingerprint,
        .row = failed.row,
        .kind = bound.basis.kind,
        .column = failed.column,
        .instruction = failed.instruction,
        .operation = switch (failed.operation) {
            .validate => .validate,
            .predicate => .predicate,
            .count => .count,
            .sum => .sum,
        },
        .expected = column.type,
        .key_kind = .none,
        .key_length = 0,
        .decoding = .none,
        .actual_bytes = 0,
        .column_length = @intCast(@min(name.len, 23)),
        .column_truncated = name.len > 23,
        .detail = @splat(0),
    };
    @memcpy(value.detail[0..value.column_length], name[0..value.column_length]);
    if (page.keys[failed.page_row]) |key| switch (key) {
        .kv => |bytes| {
            value.key_kind = .kv;
            value.key_length = bytes.len;
            @memcpy(value.keyPrefixMut(), bytes.slice()[0..value.keyPrefix().len]);
        },
        .table => |number| {
            value.key_kind = .table;
            value.key_length = 8;
            std.mem.writeInt(i64, value.keyPrefixMut()[0..8], number, .little);
        },
        .element => |id| {
            value.key_kind = .element;
            value.key_length = 16;
            std.mem.writeInt(u64, value.keyPrefixMut()[0..8], id.counter, .little);
            std.mem.writeInt(u64, value.keyPrefixMut()[8..16], id.replica, .little);
        },
    };
    if (page.decoding[failed.page_row][failed.column]) |decoder| {
        value.decoding = switch (decoder.reason) {
            .invalid_utf8 => .invalid_utf8,
            .invalid_length => .invalid_length,
            .invalid_boolean => .invalid_boolean,
            .nonfinite_float => .nonfinite_float,
        };
        value.actual_bytes = decoder.actual_bytes;
    }
    try value.validate();
    return value;
}
pub fn columnName(self: *const Self) []const u8 {
    return self.detail[0..self.column_length];
}
fn keyPrefix(self: *const Self) []const u8 {
    return self.detail[self.column_length..][0..@min(self.key_length, self.detail.len - self.column_length)];
}
fn keyPrefixMut(self: *Self) []u8 {
    return self.detail[self.column_length..][0..@min(self.key_length, self.detail.len - self.column_length)];
}
pub fn validate(self: Self) !void {
    if (self.resource == 0 or self.resource > p.max_counter or self.revision > p.max_counter or self.row == 0 or self.column >= m.max_columns or self.column_length == 0 or self.column_length > 23) return error.InvalidRuntimeWitness;
    _ = try m.Name.init(self.columnName());
    if (self.column_truncated and self.column_length != 23) return error.InvalidRuntimeWitness;
    if ((self.operation == .predicate) != (self.instruction != null)) return error.InvalidRuntimeWitness;
    if (self.instruction) |index| if (index >= m.PredicateProgram.max_instructions) return error.InvalidRuntimeWitness;
    switch (self.key_kind) {
        .none => if (self.key_length != 0 or self.kind != .document) return error.InvalidRuntimeWitness,
        .kv => if (self.kind != .kv or self.key_length > p.Value.max_bytes) return error.InvalidRuntimeWitness,
        .table => if (self.kind != .table or self.key_length != 8) return error.InvalidRuntimeWitness,
        .element => if (self.kind != .document or self.key_length != 16) return error.InvalidRuntimeWitness,
    }
    if (!std.mem.allEqual(u8, self.detail[self.column_length + self.keyPrefix().len ..], 0)) return error.InvalidRuntimeWitness;
    if (self.actual_bytes > p.Value.max_bytes or (self.decoding == .none and self.actual_bytes != 0) or (self.decoding != .none and self.kind != .kv)) return error.InvalidRuntimeWitness;
    switch (self.decoding) {
        .none => {},
        .invalid_utf8 => if (self.expected != .utf8) return error.InvalidRuntimeWitness,
        .invalid_boolean => if (self.expected != .boolean or self.actual_bytes != 1) return error.InvalidRuntimeWitness,
        .nonfinite_float => if (self.expected != .float64 or self.actual_bytes != 8) return error.InvalidRuntimeWitness,
        .invalid_length => if (self.expected == .utf8 or self.expected == .binary or self.actual_bytes == self.expectedBytes().?) return error.InvalidRuntimeWitness,
    }
}
fn expectedBytes(self: Self) ?u16 {
    return switch (self.expected) {
        .boolean => 1,
        .int64, .uint64, .float64 => 8,
        .utf8, .binary => null,
    };
}
pub fn encode(self: Self) ![encoded_bytes]u8 {
    try self.validate();
    var bytes: [encoded_bytes]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try out.writeInt(u56, @intCast(self.resource), .little);
    try out.writeInt(u56, @intCast(self.revision), .little);
    try out.writeAll(&self.binding);
    try out.writeInt(u64, self.row, .little);
    try out.writeAll(&.{ @backingInt(self.kind), @backingInt(self.operation), self.column, self.instruction orelse 255, @backingInt(self.key_kind) | (@backingInt(self.decoding) << 2), @backingInt(self.expected), self.column_length | (if (self.column_truncated) @as(u8, 128) else 0) });
    try out.writeInt(u16, self.key_length, .little);
    try out.writeInt(u16, self.actual_bytes, .little);
    try out.writeAll(&self.detail);
    std.debug.assert(out.end == encoded_bytes);
    return bytes;
}
pub fn decode(bytes: []const u8) !Self {
    if (bytes.len != encoded_bytes) return error.InvalidRuntimeWitness;
    var in: std.Io.Reader = .fixed(bytes);
    var value: Self = .{ .resource = try in.takeInt(u56, .little), .revision = try in.takeInt(u56, .little), .binding = (try in.takeArray(32)).*, .row = try in.takeInt(u64, .little), .kind = std.enums.fromInt(m.SourceKind, try in.takeByte()) orelse return error.InvalidRuntimeWitness, .operation = std.enums.fromInt(Operation, try in.takeByte()) orelse return error.InvalidRuntimeWitness, .column = try in.takeByte(), .instruction = null, .key_kind = .none, .expected = undefined, .decoding = .none, .key_length = 0, .actual_bytes = 0, .column_length = 0, .column_truncated = false, .detail = undefined };
    const instruction = try in.takeByte();
    value.instruction = if (instruction == 255) null else instruction;
    const flags = try in.takeByte();
    if (flags & 0xe0 != 0) return error.InvalidRuntimeWitness;
    value.key_kind = std.enums.fromInt(KeyKind, flags & 3).?;
    value.decoding = std.enums.fromInt(Decoding, (flags >> 2) & 7) orelse return error.InvalidRuntimeWitness;
    value.expected = std.enums.fromInt(m.Type, try in.takeByte()) orelse return error.InvalidRuntimeWitness;
    const length = try in.takeByte();
    value.column_length = length & 127;
    value.column_truncated = length & 128 != 0;
    value.key_length = try in.takeInt(u16, .little);
    value.actual_bytes = try in.takeInt(u16, .little);
    value.detail = (try in.takeArray(39)).*;
    try value.validate();
    return value;
}

pub fn enrich(self: Self, value: *d) !void {
    try self.validate();
    try value.text(.operation, .execution, @tagName(self.operation));
    try value.fact(.source_row, .execution, .{ .unsigned = .init(self.row) });
    try value.add(.{ .field = .column, .origin = .schema, .availability = if (self.column_truncated) .truncated else .provided, .value = .{ .text = try d.Text.init(self.columnName()) } });
    try value.text(.expected_type, .schema, @tagName(self.expected));
    try value.text(.source_kind, .execution, @tagName(self.kind));
    try value.fact(.object, .execution, .{ .unsigned = .init(self.resource) });
    try value.fact(.expected_revision, .execution, .{ .unsigned = .init(self.revision) });
    try value.fact(.source_basis, .execution, .{ .digest = self.binding });
    if (self.instruction) |instruction| try value.fact(.expression, .execution, .{ .unsigned = .init(instruction) });
    const key = self.keyPrefix();
    var buffer: [128]u8 = undefined;
    switch (self.key_kind) {
        .none => try value.absent(.source_key, .execution, .inapplicable),
        .table => try value.fact(.source_key, .execution, .{ .signed = .init(std.mem.readInt(i64, key[0..8], .little)) }),
        .element => try value.text(.source_key, .execution, try std.fmt.bufPrint(&buffer, "{d}:{d}", .{ std.mem.readInt(u64, key[0..8], .little), std.mem.readInt(u64, key[8..16], .little) })),
        .kv => try value.add(.{ .field = .source_key, .origin = .execution, .availability = if (key.len < self.key_length) .truncated else .provided, .value = .{ .text = try d.Text.init(try std.fmt.bufPrint(&buffer, "{x}", .{key})) } }),
    }
    if (self.decoding != .none) {
        try value.text(.native_cause, .execution, @tagName(self.decoding));
        if (self.expectedBytes()) |expected| try value.fact(.expected_count, .execution, .{ .unsigned = .init(expected) });
        try value.fact(.actual_count, .execution, .{ .unsigned = .init(self.actual_bytes) });
    }
}

test "compact runtime witness preserves extreme keys and marks bounded details" {
    const t = std.testing;
    const name = &@as([32]u8, @splat('a'));
    const schema: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init(name), .type = .int64 }} };
    const basis: m.Basis = .{ .kind = .table, .resource = p.max_counter, .revision = p.max_counter, .contract = @splat(7), .schema = try schema.fingerprint() };
    const bound = try (m.Plan{ .projection = &.{0}, .aggregate = .sum }).bind(basis, schema);
    var page: q.UnifiedSource.Batch = .{ .basis = basis, .count = 1, .column_count = 1 };
    page.keys[0] = .{ .table = std.math.minInt(i64) };
    const failed: m.Stream.Failure = .{ .operation = .sum, .row = std.math.maxInt(u64), .page_row = 0, .column = 0 };
    var witness = try capture(bound, &page, failed);
    const bytes = try witness.encode();
    try t.expectEqual(@as(usize, 104), bytes.len);
    try t.expectEqualDeep(witness, try decode(&bytes));
    try t.expect(witness.column_truncated);
    var diagnostic = try d.init("query.arithmetic_overflow", .limit, .execute, .rejected, .domain_status, "Overflow.");
    try witness.enrich(&diagnostic);
    try t.expectEqual(d.Availability.truncated, diagnostic.facts[2].?.availability);
    try t.expectEqual(std.math.minInt(i64), try diagnostic.facts[8].?.value.?.signed.value());
    try diagnostic.validate();
    var malformed = bytes;
    malformed[58] |= 0x80;
    try t.expectError(error.InvalidRuntimeWitness, decode(&malformed));
    malformed = bytes;
    malformed[103] = 1;
    try t.expectError(error.InvalidRuntimeWitness, decode(&malformed));
    witness.kind = .kv;
    witness.key_kind = .kv;
    witness.key_length = 256;
    @memset(witness.keyPrefixMut(), 255);
    try t.expectEqualDeep(witness, try decode(&try witness.encode()));
    diagnostic = try d.init("query.cell_type_error", .binding, .execute, .rejected, .domain_status, "Invalid cell.");
    try witness.enrich(&diagnostic);
    try t.expectEqual(d.Availability.truncated, diagnostic.facts[8].?.availability);
}
