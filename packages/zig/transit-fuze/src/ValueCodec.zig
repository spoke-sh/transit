//! One canonical value envelope with explicit descriptor and five-state cells.
//! Decoding owns all data in one allocator-backed arena; no borrowed input remains.
const std = @import("std");
const types = @import("Types.zig");
const v = types.Values;
const sem = types.Semantics;
pub const max_bytes = 2 * 1024 * 1024;
pub fn encode(cell: v.Cell, field: types.Field, output: []u8) ![]const u8 {
    try cell.validate(field, .{});
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("FVL1");
    var descriptor: [types.max_encoding_bytes]u8 = undefined;
    const encoded_type = try field.type.encode(&descriptor);
    try writer.writeInt(u16, @intCast(encoded_type.len), .little);
    try writer.writeAll(encoded_type);
    try writer.writeByte(@intFromBool(field.nullable) | (@as(u8, @intFromBool(field.optional)) << 1));
    try writeCell(cell, field.type, &writer);
    return writer.buffered();
}
fn writeCell(cell: v.Cell, expected: types.Type, writer: *std.Io.Writer) anyerror!void {
    try writer.writeByte(@backingInt(std.meta.activeTag(cell)));
    switch (cell) {
        .missing, .null => {},
        .type_error => |actual| try writer.writeByte(@backingInt(actual)),
        .value => |value| try writeValue(value, expected, writer),
        .conflict => |alternatives| {
            try writer.writeByte(@intCast(alternatives.len));
            for (alternatives) |alternative| {
                try writer.writeInt(u64, alternative.counter, .little);
                try writer.writeInt(u64, alternative.replica, .little);
                switch (alternative.value) {
                    .null => try writer.writeByte(1),
                    .type_error => |actual| try writer.writeAll(&.{ 2, @backingInt(actual) }),
                    .value => |value| {
                        try writer.writeByte(3);
                        try writeValue(value, expected, writer);
                    },
                }
            }
        },
    }
}
fn writeValue(value: v.Value, expected: types.Type, writer: *std.Io.Writer) anyerror!void {
    switch (value) {
        .atom => |atom| try writeAtom(atom, expected, writer),
        .structure => |cells| for (cells, expected.structure) |cell, field| try writeCell(cell, field.type, writer),
        .list, .array => |cells| {
            try writer.writeInt(u32, @intCast(cells.len), .little);
            const child = if (expected == .list) expected.list.type else expected.array.element.type;
            for (cells) |cell| try writeCell(cell, child.*, writer);
        },
        .map => |entries| {
            try writer.writeInt(u32, @intCast(entries.len), .little);
            for (entries) |entry| {
                try writeAtom(entry.key, expected.map.key.*, writer);
                try writeCell(entry.value, expected.map.value.type.*, writer);
            }
        },
        .tagged_union => |tagged| {
            try writer.writeByte(tagged.index);
            try writeCell(tagged.value.*, expected.tagged_union[tagged.index].type, writer);
        },
        .json => |bytes| try writeBytes(bytes, writer),
    }
}
fn writeBytes(bytes: []const u8, writer: *std.Io.Writer) !void {
    try writer.writeInt(u32, @intCast(bytes.len), .little);
    try writer.writeAll(bytes);
}
fn writeAtom(atom: sem.Atom, expected: types.Type, writer: *std.Io.Writer) !void {
    switch (atom) {
        .signed => |number| switch (expected) {
            .int8 => try writer.writeInt(i8, @intCast(number), .little),
            .int16 => try writer.writeInt(i16, @intCast(number), .little),
            .int32 => try writer.writeInt(i32, @intCast(number), .little),
            .int64 => try writer.writeInt(i64, @intCast(number), .little),
            .int128 => try writer.writeInt(i128, number, .little),
            else => unreachable,
        },
        .unsigned => |number| switch (expected) {
            .uint8 => try writer.writeInt(u8, @intCast(number), .little),
            .uint16 => try writer.writeInt(u16, @intCast(number), .little),
            .uint32 => try writer.writeInt(u32, @intCast(number), .little),
            .uint64 => try writer.writeInt(u64, @intCast(number), .little),
            .uint128 => try writer.writeInt(u128, number, .little),
            else => unreachable,
        },
        .float => |number| if (expected == .float32) try writer.writeInt(u32, @bitCast(@as(f32, @floatCast(number))), .little) else try writer.writeInt(u64, @bitCast(number), .little),
        .decimal => |number| try writer.writeInt(i128, number, .little),
        .boolean => |boolean| try writer.writeByte(@intFromBool(boolean)),
        .bytes => |bytes| try writeBytes(bytes, writer),
        .date => |number| try writer.writeInt(i32, number, .little),
        .time => |number| try writer.writeInt(u64, number, .little),
        .timestamp => |number| try writer.writeInt(i64, number, .little),
        .interval => |interval| {
            try writer.writeInt(i32, interval.months, .little);
            try writer.writeInt(i32, interval.days, .little);
            try writer.writeInt(i64, interval.nanos, .little);
        },
        .uuid => |bytes| try writer.writeAll(&bytes),
    }
}
pub const Decoded = struct {
    descriptor: types.Decoded,
    field: types.Field,
    cell: v.Cell,
    pub fn deinit(self: *Decoded) void {
        self.descriptor.deinit();
        self.* = undefined;
    }
};
const Reader = struct {
    reader: std.Io.Reader,
    allocator: std.mem.Allocator,
    children: usize = 0,
    bytes: usize = 0,
    fn child(self: *Reader, depth: usize) !void {
        const limits: types.Limits = .{};
        if (depth >= limits.depth or self.children >= limits.children) return error.ValueBudgetExceeded;
        self.children += 1;
    }
    fn data(self: *Reader) ![]const u8 {
        const size = try self.reader.takeInt(u32, .little);
        const limits: types.Limits = .{};
        if (size > limits.value_bytes -| self.bytes) return error.ValueBudgetExceeded;
        self.bytes += size;
        return self.allocator.dupe(u8, try self.reader.take(size));
    }
    fn readCount(self: *Reader) !usize {
        const count = try self.reader.takeInt(u32, .little);
        const limits: types.Limits = .{};
        if (count > limits.children -| self.children or count > self.reader.bufferedLen()) return error.ValueBudgetExceeded;
        return count;
    }
};
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Decoded {
    if (bytes.len > max_bytes) return error.ValueBudgetExceeded;
    var reader: Reader = .{ .reader = .fixed(bytes), .allocator = undefined };
    if (!std.mem.eql(u8, try reader.reader.take(4), "FVL1")) return error.InvalidValueEncoding;
    var descriptor = try types.decode(allocator, try reader.reader.take(try reader.reader.takeInt(u16, .little)));
    errdefer descriptor.deinit();
    reader.allocator = descriptor.arena.allocator();
    const flags = try reader.reader.takeByte();
    if (flags > 3) return error.InvalidValueEncoding;
    const field: types.Field = .{ .name = "value", .type = descriptor.type, .nullable = flags & 1 != 0, .optional = flags & 2 != 0 };
    const cell = try readCell(&reader, field.type, 0);
    if (reader.reader.bufferedLen() != 0) return error.InvalidValueEncoding;
    try cell.validate(field, .{});
    return .{ .descriptor = descriptor, .field = field, .cell = cell };
}
fn readCell(reader: *Reader, expected: types.Type, depth: usize) anyerror!v.Cell {
    try reader.child(depth);
    return switch (try reader.reader.takeByte()) {
        0 => .missing,
        1 => .null,
        2 => .{ .type_error = std.enums.fromInt(types.Tag, try reader.reader.takeByte()) orelse return error.InvalidValueEncoding },
        3 => .{ .value = try readValue(reader, expected, depth) },
        4 => blk: {
            const count = try reader.reader.takeByte();
            if (count < 2 or count > types.Query.max_conflicts) return error.InvalidConflict;
            const alternatives = try reader.allocator.alloc(v.Alternative, count);
            for (alternatives) |*alternative| {
                try reader.child(depth);
                alternative.counter = try reader.reader.takeInt(u64, .little);
                alternative.replica = try reader.reader.takeInt(u64, .little);
                alternative.value = switch (try reader.reader.takeByte()) {
                    1 => .null,
                    2 => .{ .type_error = std.enums.fromInt(types.Tag, try reader.reader.takeByte()) orelse return error.InvalidValueEncoding },
                    3 => .{ .value = try readValue(reader, expected, depth) },
                    else => return error.InvalidConflict,
                };
            }
            break :blk .{ .conflict = alternatives };
        },
        else => error.InvalidValueEncoding,
    };
}
fn readValue(reader: *Reader, expected: types.Type, depth: usize) anyerror!v.Value {
    return switch (expected) {
        .structure => |fields| blk: {
            const cells = try reader.allocator.alloc(v.Cell, fields.len);
            for (cells, fields) |*cell, field| cell.* = try readCell(reader, field.type, depth + 1);
            break :blk .{ .structure = cells };
        },
        .list, .array => blk: {
            const count = try reader.readCount();
            if (expected == .array and count != expected.array.length) return error.InvalidArrayLength;
            const cells = try reader.allocator.alloc(v.Cell, count);
            const child = if (expected == .list) expected.list.type else expected.array.element.type;
            for (cells) |*cell| cell.* = try readCell(reader, child.*, depth + 1);
            break :blk if (expected == .list) .{ .list = cells } else .{ .array = cells };
        },
        .map => |map| blk: {
            const count = try reader.readCount();
            const entries = try reader.allocator.alloc(v.Entry, count);
            for (entries) |*entry| {
                try reader.child(depth + 1);
                entry.key = try readAtom(reader, map.key.*);
                entry.value = try readCell(reader, map.value.type.*, depth + 1);
            }
            break :blk .{ .map = entries };
        },
        .tagged_union => |fields| blk: {
            const index = try reader.reader.takeByte();
            if (index >= fields.len) return error.InvalidUnion;
            const cell = try reader.allocator.create(v.Cell);
            cell.* = try readCell(reader, fields[index].type, depth + 1);
            break :blk .{ .tagged_union = .{ .index = index, .value = cell } };
        },
        .json => .{ .json = try reader.data() },
        else => .{ .atom = try readAtom(reader, expected) },
    };
}
fn readAtom(reader: *Reader, expected: types.Type) !sem.Atom {
    const r = &reader.reader;
    return switch (expected) {
        .int8 => .{ .signed = try r.takeInt(i8, .little) },
        .int16 => .{ .signed = try r.takeInt(i16, .little) },
        .int32 => .{ .signed = try r.takeInt(i32, .little) },
        .int64 => .{ .signed = try r.takeInt(i64, .little) },
        .int128 => .{ .signed = try r.takeInt(i128, .little) },
        .uint8 => .{ .unsigned = try r.takeInt(u8, .little) },
        .uint16 => .{ .unsigned = try r.takeInt(u16, .little) },
        .uint32 => .{ .unsigned = try r.takeInt(u32, .little) },
        .uint64 => .{ .unsigned = try r.takeInt(u64, .little) },
        .uint128 => .{ .unsigned = try r.takeInt(u128, .little) },
        .float32 => .{ .float = @as(f32, @bitCast(try r.takeInt(u32, .little))) },
        .float64 => .{ .float = @bitCast(try r.takeInt(u64, .little)) },
        .decimal => .{ .decimal = try r.takeInt(i128, .little) },
        .boolean => .{ .boolean = switch (try r.takeByte()) {
            0 => false,
            1 => true,
            else => return error.InvalidValueEncoding,
        } },
        .utf8, .binary => .{ .bytes = try reader.data() },
        .date => .{ .date = try r.takeInt(i32, .little) },
        .time => .{ .time = try r.takeInt(u64, .little) },
        .timestamp => .{ .timestamp = try r.takeInt(i64, .little) },
        .interval => .{ .interval = .{ .months = try r.takeInt(i32, .little), .days = try r.takeInt(i32, .little), .nanos = try r.takeInt(i64, .little) } },
        .uuid => .{ .uuid = (try r.take(16))[0..16].* },
        else => error.UnsupportedAtomType,
    };
}
test "neutral recursive cells preserve states and owned bytes through allocation failure" {
    const t = std.testing;
    const field: types.Field = .{ .name = "row", .nullable = true, .optional = true, .type = .{ .list = .{ .type = &.utf8, .nullable = true } } };
    const cell: v.Cell = .{ .value = .{ .list = &.{ .null, .{ .type_error = .int128 }, .{ .value = .{ .atom = .{ .bytes = "hello🙂" } } } } } };
    var output: [4096]u8 = undefined;
    const encoded = try encode(cell, field, &output);
    try t.checkAllAllocationFailures(t.allocator, struct {
        fn run(allocator: std.mem.Allocator, bytes: []const u8) !void {
            var decoded = try decode(allocator, bytes);
            defer decoded.deinit();
            try t.expectEqualStrings("hello🙂", decoded.cell.value.list[2].value.atom.bytes);
            var again: [4096]u8 = undefined;
            try t.expectEqualSlices(u8, bytes, try encode(decoded.cell, decoded.field, &again));
        }
    }.run, .{encoded});
    for (0..encoded.len) |length| {
        if (decode(t.allocator, encoded[0..length])) |result| {
            var owned = result;
            owned.deinit();
            return error.AcceptedTruncation;
        } else |_| {}
    }
}
