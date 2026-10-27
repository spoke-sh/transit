//! Relational scalar views and explicit ownership of variable-width payloads.
//! Collation affects comparison/hash identity; retained bytes preserve spelling.
const std = @import("std");
const table = @import("TableSchema.zig");
const types = @import("Types.zig");
const collation = @import("Collation.zig");
pub const Literal = union(enum) { integer: i64, text: []const u8 };
pub const Value = ?Literal;
pub const max_text_bytes = (types.Limits{}).value_bytes;

pub fn payloadLength(values: []const Value) !usize {
    var length: usize = 0;
    for (values) |value| if (value) |present| if (present == .text) {
        if (present.text.len > max_text_bytes - length) return error.RelationalResidentBudget;
        length += present.text.len;
    };
    return length;
}

pub fn cell(value: Value) types.Values.Cell {
    const atom = value orelse return .null;
    return .{ .value = .{ .atom = switch (atom) {
        .integer => |v| .{ .signed = v },
        .text => |v| .{ .bytes = v },
    } } };
}
pub fn fromCell(value: types.Values.Cell, column: table.Column) !Value {
    const result: Value = if (value == .null) null else blk: {
        if (value != .value or value.value != .atom) return error.InvalidRelationalSourceRow;
        const atom = value.value.atom;
        break :blk switch (column.type) {
            .int64 => if (atom == .signed) .{ .integer = std.math.cast(i64, atom.signed) orelse return error.InvalidRelationalSourceRow } else return error.InvalidRelationalSourceRow,
            .utf8 => if (atom == .bytes) .{ .text = atom.bytes } else return error.InvalidRelationalSourceRow,
            else => return error.UnsupportedRelationalType,
        };
    };
    try validate(result, column);
    return result;
}
pub fn validate(value: Value, column: table.Column) !void {
    if (column.type != .int64 and column.type != .utf8) return error.UnsupportedRelationalType;
    const present = value orelse {
        if (!column.nullable) return error.InvalidRelationalSourceRow;
        return;
    };
    switch (present) {
        .integer => if (column.type != .int64) return error.InvalidRelationalSourceRow,
        .text => |bytes| {
            if (column.type != .utf8 or bytes.len > max_text_bytes) return error.InvalidRelationalSourceRow;
            try types.Semantics.validate(.{ .bytes = bytes }, .utf8);
            try collation.validateBytes(bytes, column.collation);
        },
    }
}
/// NULL sorts first for group identity; it never establishes a join match.
pub fn order(left: Value, right: Value, column: table.Column) !std.math.Order {
    var nullable = column;
    nullable.nullable = true;
    try validate(left, nullable);
    try validate(right, nullable);
    if (left == null) return if (right == null) .eq else .lt;
    if (right == null) return .gt;
    return collation.compareCell(cell(left), cell(right), column.type, column.collation);
}
/// Hash exactly the same canonical bytes used by declared-collation ordering.
/// A fixed hashing buffer avoids materializing an expanded variable-width key.
pub fn hashInto(hash: *std.crypto.hash.sha2.Sha256, value: Value, column: table.Column) !void {
    var nullable = column;
    nullable.nullable = true;
    try validate(value, nullable);
    var scratch: [256]u8 = undefined;
    var writer: std.Io.Writer.Hashing(std.crypto.hash.sha2.Sha256) = .initHasher(hash.*, &scratch);
    try collation.appendSortKey(&writer.writer, cell(value), column.type, column.collation);
    try writer.writer.flush();
    hash.* = writer.hasher;
}

/// The owning vector is moved, never copied and independently released twice.
/// Views can copy the scalar directory while borrowing this buffer's lifetime.
pub const Buffer = struct {
    allocator: ?std.mem.Allocator = null,
    bytes: []u8 = &.{},

    /// Copy all text into one allocation and retarget the supplied directory.
    /// Failure leaves every input view unchanged. Integers need no allocation.
    pub fn copy(allocator: std.mem.Allocator, values: []Value) !Buffer {
        const length = try payloadLength(values);
        if (length == 0) {
            for (values) |*value| if (value.*) |*present| if (present.* == .text) {
                present.text = "";
            };
            return .{};
        }
        const bytes = try allocator.alloc(u8, length);
        var offset: usize = 0;
        for (values) |*value| if (value.*) |*present| if (present.* == .text) {
            const destination = bytes[offset..][0..present.text.len];
            @memcpy(destination, present.text);
            offset += destination.len;
            present.text = destination;
        };
        return .{ .allocator = allocator, .bytes = bytes };
    }
    pub fn deinit(self: *Buffer) void {
        if (self.allocator) |allocator| allocator.free(self.bytes);
        self.* = .{};
    }

    pub fn copyCells(allocator: std.mem.Allocator, cells: []types.Values.Cell) !Buffer {
        var length: usize = 0;
        for (cells) |value| {
            if (value == .null) continue;
            if (value != .value or value.value != .atom) return error.InvalidRelationalOutput;
            switch (value.value.atom) {
                .signed, .unsigned => {},
                .bytes => |bytes| {
                    if (bytes.len > max_text_bytes - length) return error.RelationalResidentBudget;
                    length += bytes.len;
                },
                else => return error.InvalidRelationalOutput,
            }
        }
        if (length == 0) {
            for (cells) |*value| if (value.* == .value and value.value.atom == .bytes) {
                value.value.atom.bytes = "";
            };
            return .{};
        }
        const bytes = try allocator.alloc(u8, length);
        var offset: usize = 0;
        for (cells) |*value| if (value.* == .value and value.value.atom == .bytes) {
            const destination = bytes[offset..][0..value.value.atom.bytes.len];
            @memcpy(destination, value.value.atom.bytes);
            offset += destination.len;
            value.value.atom.bytes = destination;
        };
        return .{ .allocator = allocator, .bytes = bytes };
    }
};

pub fn write(writer: *std.Io.Writer, value: Value) !void {
    const present = value orelse return writer.writeByte(0);
    switch (present) {
        .integer => |integer| {
            try writer.writeByte(1);
            try writer.writeInt(i64, integer, .little);
        },
        .text => |bytes| {
            if (bytes.len > max_text_bytes) return error.InvalidRelationalSourceRow;
            try writer.writeByte(2);
            try writer.writeInt(u32, @intCast(bytes.len), .little);
            try writer.writeAll(bytes);
        },
    }
}
/// Returned text borrows the encoded record until the caller copies its vector.
pub fn read(reader: *std.Io.Reader) !Value {
    return switch (try reader.takeByte()) {
        0 => null,
        1 => .{ .integer = try reader.takeInt(i64, .little) },
        2 => blk: {
            const length = try reader.takeInt(u32, .little);
            if (length > max_text_bytes) return error.InvalidRelationalSourceRow;
            break :blk .{ .text = try reader.take(length) };
        },
        else => error.InvalidRelationalSourceRow,
    };
}

/// Allocate exactly the encoded length through the query's bounded allocator.
pub fn encodeOwned(allocator: std.mem.Allocator, value: anytype, bound: anytype, maximum: usize) ![]u8 {
    var scratch: [256]u8 = undefined;
    var size: std.Io.Writer.Discarding = .init(&scratch);
    try value.writeTo(bound, &size.writer);
    const length = size.fullCount();
    if (length > maximum) return error.RelationalResidentBudget;
    const bytes = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);
    try value.writeTo(bound, &writer);
    if (writer.end != length) return error.InvalidRelationalEncoding;
    return bytes;
}

/// Verify canonical re-encoding without retaining a second copy of text.
pub fn checkEncoding(bytes: []const u8, value: anytype, bound: anytype) !void {
    var compare: Comparing = .{ .bytes = bytes };
    try value.writeTo(bound, &compare.writer);
    if (compare.offset != bytes.len) return error.InvalidRelationalEncoding;
}
const Comparing = struct {
    bytes: []const u8,
    offset: usize = 0,
    writer: std.Io.Writer = .{ .buffer = &.{}, .vtable = &.{ .drain = drain } },
    fn consume(self: *Comparing, bytes: []const u8) std.Io.Writer.Error!void {
        if (bytes.len > self.bytes.len - self.offset or !std.mem.eql(u8, bytes, self.bytes[self.offset..][0..bytes.len])) return error.WriteFailed;
        self.offset += bytes.len;
    }
    fn drain(writer: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *Comparing = @alignCast(@fieldParentPtr("writer", writer));
        var consumed: usize = 0;
        for (data[0 .. data.len - 1]) |bytes| {
            try self.consume(bytes);
            consumed += bytes.len;
        }
        for (0..splat) |_| {
            const bytes = data[data.len - 1];
            try self.consume(bytes);
            consumed += bytes.len;
        }
        return consumed;
    }
};

test "relational text comparison and streaming hash share declared collation identity" {
    const t = std.testing;
    const variants = [_]table.Collation{ .utf8_binary, .ascii_ci, .ebcdic_cp037 };
    const values = [_]Value{ null, .{ .text = "" }, .{ .text = "A" }, .{ .text = "a" }, .{ .text = "a " }, .{ .text = "0" }, .{ .text = "\x00" }, .{ .text = "é" } };
    for (variants) |variant| {
        const column: table.Column = .{ .id = 1, .name = "k", .type = .utf8, .nullable = true, .collation = variant };
        for (values) |left| for (values) |right| {
            if (try order(left, right, column) != .eq) continue;
            var a: std.crypto.hash.sha2.Sha256 = .init(.{});
            var b = a;
            try hashInto(&a, left, column);
            try hashInto(&b, right, column);
            try t.expectEqual(a.finalResult(), b.finalResult());
        };
        try t.expectEqual(if (variant == .ascii_ci) std.math.Order.eq else if (variant == .ebcdic_cp037) std.math.Order.gt else std.math.Order.lt, try order(.{ .text = "A" }, .{ .text = "a" }, column));
        try t.expectEqual(std.math.Order.lt, try order(.{ .text = "a" }, .{ .text = "a " }, column));
    }
    // The complete canonical key exceeds the index-key materialization bound.
    const large = try t.allocator.alloc(u8, 32 * 1024);
    defer t.allocator.free(large);
    @memset(large, 'A');
    const column: table.Column = .{ .id = 1, .name = "k", .type = .utf8, .collation = .ascii_ci };
    var upper: std.crypto.hash.sha2.Sha256 = .init(.{});
    try hashInto(&upper, .{ .text = large }, column);
    @memset(large, 'a');
    var lower: std.crypto.hash.sha2.Sha256 = .init(.{});
    try hashInto(&lower, .{ .text = large }, column);
    try t.expectEqual(upper.finalResult(), lower.finalResult());
    try t.expectError(error.InvalidRelationalSourceRow, validate(.{ .integer = 1 }, column));
    var unsupported = column;
    unsupported.collation = .icu_root;
    try t.expectError(error.UnsupportedColumnCollation, validate(.{ .text = "a" }, unsupported));
}

test "relational text ownership survives scratch reuse and allocation failure" {
    const t = std.testing;
    var scratch = [_]u8{ 'A', 'b', 'C' };
    var values = [_]Value{ null, .{ .integer = 19 }, .{ .text = &scratch }, .{ .text = "" } };
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    try t.expectError(error.OutOfMemory, Buffer.copy(failing.allocator(), &values));
    try t.expectEqual(scratch[0..].ptr, values[2].?.text.ptr);
    var owned = try Buffer.copy(t.allocator, &values);
    defer owned.deinit();
    @memset(&scratch, 'x');
    try t.expectEqualStrings("AbC", values[2].?.text);
    try t.expectEqual(@as(usize, 3), owned.bytes.len);
    var bytes: [64]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    for (values) |value| try write(&writer, value);
    var reader: std.Io.Reader = .fixed(writer.buffered());
    try t.expect(try read(&reader) == null);
    try t.expectEqual(@as(i64, 19), (try read(&reader)).?.integer);
    try t.expectEqualStrings("AbC", (try read(&reader)).?.text);
    try t.expectEqualStrings("", (try read(&reader)).?.text);
    try t.expectEqual(@as(usize, 0), reader.bufferedLen());
}
