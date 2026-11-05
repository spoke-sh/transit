//! Relational scalar views and explicit ownership of variable-width payloads.
//! Collation affects comparison/hash identity; retained bytes preserve spelling.
const std = @import("std");
const table = @import("TableSchema.zig");
const types = @import("Types.zig");
const collation = @import("Collation.zig");
pub const Literal = union(enum(u8)) {
    integer: i64 = 1,
    text: []const u8 = 2,
    unsigned: u64 = 3,
    float: f64 = 4,
    decimal: i128 = 5,
    boolean: bool = 6,
    date: i32 = 7,
    time: u64 = 8,
    timestamp: i64 = 9,
    uuid: [16]u8 = 10,
    binary: []const u8 = 11,
};
/// Largest fixed scalar encoding (tag plus decimal/UUID payload).
pub const fixed_bytes = 17;
pub fn supported(kind: types.Type) bool {
    return switch (kind) {
        .boolean, .int64, .uint64, .float64, .decimal, .date, .time, .timestamp, .uuid, .utf8, .binary => true,
        else => false,
    };
}
pub fn variable(kind: types.Type) bool {
    return kind == .utf8 or kind == .binary;
}
fn payload(value: Literal) ?[]const u8 {
    return switch (value) {
        .text, .binary => |bytes| bytes,
        else => null,
    };
}
fn setPayload(value: *Literal, bytes: []const u8) void {
    switch (value.*) {
        .text => value.text = bytes,
        .binary => value.binary = bytes,
        else => unreachable,
    }
}
pub fn encodedLength(value: Value) usize {
    const present = value orelse return 1;
    return 1 + switch (present) {
        .text, .binary => |bytes| 4 + bytes.len,
        .decimal, .uuid => @as(usize, 16),
        .boolean => @as(usize, 1),
        .date => @as(usize, 4),
        else => @as(usize, 8),
    };
}
pub fn cellBytes(value: types.Values.Cell) !usize {
    if (value == .null) return 5;
    if (value != .value or value.value != .atom) return error.InvalidRelationalOutput;
    return 5 + @as(usize, switch (value.value.atom) {
        .signed, .unsigned, .float, .time, .timestamp => 8,
        .decimal, .uuid => 16,
        .boolean => 1,
        .date => 4,
        .bytes => |bytes| bytes.len,
        else => return error.InvalidRelationalOutput,
    });
}
pub const Value = ?Literal;
pub const max_text_bytes = (types.Limits{}).value_bytes;

pub fn payloadLength(values: []const Value) !usize {
    var length: usize = 0;
    for (values) |value| if (value) |present| if (payload(present)) |bytes| {
        if (bytes.len > max_text_bytes - length) return error.RelationalResidentBudget;
        length += bytes.len;
    };
    return length;
}

pub fn cell(value: Value) types.Values.Cell {
    const atom = value orelse return .null;
    return .{ .value = .{ .atom = switch (atom) {
        .integer => |v| .{ .signed = v },
        .text, .binary => |v| .{ .bytes = v },
        inline else => |v, tag| @unionInit(types.Values.Atom, @tagName(tag), v),
    } } };
}
pub fn fromCell(value: types.Values.Cell, column: table.Column) !Value {
    const result: Value = if (value == .null) null else blk: {
        if (value != .value or value.value != .atom) return error.InvalidRelationalSourceRow;
        const atom = value.value.atom;
        try types.Semantics.validate(atom, column.type);
        break :blk switch (column.type) {
            .int64 => .{ .integer = @intCast(atom.signed) },
            .uint64 => .{ .unsigned = @intCast(atom.unsigned) },
            .utf8 => .{ .text = atom.bytes },
            .binary => .{ .binary = atom.bytes },
            .float64 => .{ .float = atom.float },
            .decimal => .{ .decimal = atom.decimal },
            .boolean => .{ .boolean = atom.boolean },
            .date => .{ .date = atom.date },
            .time => .{ .time = atom.time },
            .timestamp => .{ .timestamp = atom.timestamp },
            .uuid => .{ .uuid = atom.uuid },
            else => return error.UnsupportedRelationalType,
        };
    };
    try validate(result, column);
    return result;
}
pub fn validate(value: Value, column: table.Column) !void {
    if (!supported(column.type)) return error.UnsupportedRelationalType;
    const present = value orelse {
        if (!column.nullable) return error.InvalidRelationalSourceRow;
        return;
    };
    if ((present == .text and column.type != .utf8) or (present == .binary and column.type != .binary)) return error.InvalidRelationalSourceRow;
    types.Semantics.validate(cell(value).value.atom, column.type) catch return error.InvalidRelationalSourceRow;
    if (payload(present)) |bytes| {
        if (bytes.len > max_text_bytes) return error.InvalidRelationalSourceRow;
        if (present == .text) try collation.validateBytes(bytes, column.collation);
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
            for (values) |*value| if (value.*) |*present| if (payload(present.*) != null) {
                setPayload(present, "");
            };
            return .{};
        }
        const bytes = try allocator.alloc(u8, length);
        var offset: usize = 0;
        for (values) |*value| if (value.*) |*present| if (payload(present.*)) |source| {
            const destination = bytes[offset..][0..source.len];
            @memcpy(destination, source);
            offset += destination.len;
            setPayload(present, destination);
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
                .signed, .unsigned, .float, .decimal, .boolean, .date, .time, .timestamp, .uuid => {},
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
    try writer.writeByte(@backingInt(std.meta.activeTag(present)));
    switch (present) {
        .text, .binary => |bytes| {
            if (bytes.len > max_text_bytes) return error.InvalidRelationalSourceRow;
            try writer.writeInt(u32, @intCast(bytes.len), .little);
            try writer.writeAll(bytes);
        },
        .float => |number| try writer.writeInt(u64, @bitCast(number), .little),
        .boolean => |flag| try writer.writeByte(@intFromBool(flag)),
        .uuid => |bytes| try writer.writeAll(&bytes),
        inline else => |number| try writer.writeInt(@TypeOf(number), number, .little),
    }
}
/// Returned bytes borrow the record until the caller copies its vector.
pub fn read(reader: *std.Io.Reader) !Value {
    const tag = try reader.takeByte();
    if (tag == 0) return null;
    const kind = std.enums.fromInt(std.meta.Tag(Literal), tag) orelse return error.InvalidRelationalSourceRow;
    return switch (kind) {
        .text, .binary => blk: {
            const length = try reader.takeInt(u32, .little);
            if (length > max_text_bytes) return error.InvalidRelationalSourceRow;
            const bytes = try reader.take(length);
            break :blk if (kind == .text) .{ .text = bytes } else .{ .binary = bytes };
        },
        .float => .{ .float = @bitCast(try reader.takeInt(u64, .little)) },
        .boolean => .{ .boolean = switch (try reader.takeByte()) {
            0 => false,
            1 => true,
            else => return error.InvalidRelationalSourceRow,
        } },
        .uuid => .{ .uuid = (try reader.takeArray(16)).* },
        inline else => |field| @unionInit(Literal, @tagName(field), try reader.takeInt(@FieldType(Literal, @tagName(field)), .little)),
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
    const variants = [_]table.Collation{ .utf8_binary, .ascii_ci, .ebcdic_cp037, .ebcdic_037_pad, .ebcdic_1047_nopad };
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
        const ebcdic = variant == .ebcdic_cp037 or variant == .ebcdic_037_pad or variant == .ebcdic_1047_nopad;
        try t.expectEqual(if (variant == .ascii_ci) std.math.Order.eq else if (ebcdic) std.math.Order.gt else std.math.Order.lt, try order(.{ .text = "A" }, .{ .text = "a" }, column));
        try t.expectEqual(if (variant == .ebcdic_037_pad) std.math.Order.eq else std.math.Order.lt, try order(.{ .text = "a" }, .{ .text = "a " }, column));
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

test "relational scalar keys retain exact types through ordering encoding and owned rows" {
    const t = std.testing;
    const Case = struct { kind: types.Type, low: Literal, high: Literal };
    const cases = [_]Case{
        .{ .kind = .boolean, .low = .{ .boolean = false }, .high = .{ .boolean = true } },
        .{ .kind = .uint64, .low = .{ .unsigned = 9223372036854775808 }, .high = .{ .unsigned = std.math.maxInt(u64) } },
        .{ .kind = .float64, .low = .{ .float = -1.25 }, .high = .{ .float = 2.5 } },
        .{ .kind = .{ .decimal = .{ .precision = 38, .scale = 2 } }, .low = .{ .decimal = -9223372036854775809 }, .high = .{ .decimal = 9223372036854775809 } },
        .{ .kind = .date, .low = .{ .date = -1 }, .high = .{ .date = 1 } },
        .{ .kind = .time, .low = .{ .time = 1 }, .high = .{ .time = 86399999999999 } },
        .{ .kind = .{ .timestamp = .utc }, .low = .{ .timestamp = -1 }, .high = .{ .timestamp = 1 } },
        .{ .kind = .uuid, .low = .{ .uuid = @splat(0) }, .high = .{ .uuid = @splat(255) } },
        .{ .kind = .binary, .low = .{ .binary = "\x00\xff" }, .high = .{ .binary = "\xff\x00" } },
    };
    for (cases) |case| {
        const column: table.Column = .{ .id = 1, .name = "k", .type = case.kind, .nullable = true };
        try t.expectEqual(std.math.Order.lt, try order(case.low, case.high, column));
        try t.expectEqual(std.math.Order.lt, try order(null, case.low, column));
        var bytes: [128]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try write(&writer, case.high);
        var reader: std.Io.Reader = .fixed(writer.buffered());
        const decoded = try read(&reader);
        try t.expectEqual(std.math.Order.eq, try order(case.high, decoded, column));
        try t.expectEqual(std.math.Order.eq, try order(case.high, try fromCell(cell(decoded), column), column));
        var first: std.crypto.hash.sha2.Sha256 = .init(.{});
        var second = first;
        try hashInto(&first, case.high, column);
        try hashInto(&second, decoded, column);
        try t.expectEqual(first.finalResult(), second.finalResult());
        var owned_values = [_]Value{decoded};
        var owned = try Buffer.copy(t.allocator, &owned_values);
        defer owned.deinit();
        @memset(&bytes, 0);
        try t.expectEqual(std.math.Order.eq, try order(case.high, owned_values[0], column));
    }
    try t.expectError(error.InvalidRelationalSourceRow, validate(.{ .float = std.math.nan(f64) }, .{ .id = 1, .name = "x", .type = .float64 }));
    try t.expectError(error.InvalidRelationalSourceRow, validate(.{ .decimal = 1000 }, .{ .id = 1, .name = "x", .type = .{ .decimal = .{ .precision = 3, .scale = 1 } } }));
}
