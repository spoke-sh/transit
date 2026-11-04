//! Exact prepared values and result scalars for the selected MySQL matrix.
const std = @import("std");
const g = @import("root.zig").wire;
const Codec = @import("Codec.zig");
const Atom = g.fuze.Types.Values.Atom;
pub const WireType = struct { code: u8, unsigned: bool = false };
pub const Descriptor = struct { code: u8, flags: u16, length: u32, charset: u16, decimals: u8 = 0 };
// utf8mb4_0900_bin is supplied by the session profile, not inferred from a
// client handshake byte. Binary/numeric metadata always uses binary charset 63.
pub fn descriptor(column: g.Type, collation: u16) Descriptor {
    var value: Descriptor = switch (column.kind) {
        .int8 => .{ .code = 1, .flags = 0, .length = 4, .charset = 63 },
        .int16 => .{ .code = 2, .flags = 0, .length = 6, .charset = 63 },
        .int32 => .{ .code = 3, .flags = 0, .length = 11, .charset = 63 },
        .int64 => .{ .code = 8, .flags = 0, .length = 20, .charset = 63 },
        .uint8 => .{ .code = 1, .flags = 32, .length = 3, .charset = 63 },
        .uint16 => .{ .code = 2, .flags = 32, .length = 5, .charset = 63 },
        .uint32 => .{ .code = 3, .flags = 32, .length = 10, .charset = 63 },
        .uint64 => .{ .code = 8, .flags = 32, .length = 20, .charset = 63 },
        .float32 => .{ .code = 4, .flags = 0, .length = 12, .charset = 63, .decimals = 31 },
        .float64 => .{ .code = 5, .flags = 0, .length = 22, .charset = 63, .decimals = 31 },
        .decimal => |d| .{ .code = 246, .flags = 0, .length = @as(u32, d.precision) + 1 + @as(u32, @intFromBool(d.scale != 0)), .charset = 63, .decimals = d.scale },
        .boolean => .{ .code = 1, .flags = 32, .length = 1, .charset = 63 },
        .utf8 => .{ .code = 253, .flags = 0, .length = g.Limits.max_frame_bytes, .charset = collation },
        .binary => .{ .code = 252, .flags = 128, .length = g.Limits.max_frame_bytes, .charset = 63 },
    };
    if (!column.nullable) value.flags |= 1;
    return value;
}
fn integer(code: u8) bool {
    return code == 1 or code == 2 or code == 3 or code == 8 or code == 9;
}
fn bytesType(code: u8) bool {
    return code == 15 or code == 249 or code == 250 or code == 251 or code == 252 or code == 253 or code == 254;
}
pub fn compatible(kind: g.Type.Kind, wire: WireType) !void {
    if (wire.unsigned and !integer(wire.code)) return error.InvalidWireParameterType;
    if (wire.code == 6) return;
    const admitted = switch (kind) {
        .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .boolean => integer(wire.code),
        .float32, .float64 => wire.code == 4 or wire.code == 5,
        .decimal => wire.code == 0 or wire.code == 246 or integer(wire.code),
        .utf8, .binary => bytesType(wire.code),
    };
    if (!admitted) return error.WireParameterTypeMismatch;
}
pub fn decode(reader: *Codec.Reader, kind: g.Type.Kind, wire: WireType) !?Atom {
    try compatible(kind, wire);
    if (wire.code == 6) return null;
    const result: Atom = switch (kind) {
        .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .boolean => blk: {
            const n: i128 = if (wire.unsigned) switch (wire.code) {
                1 => try reader.byte(),
                2 => try reader.int(u16, .little),
                3, 9 => try reader.int(u32, .little),
                8 => try reader.int(u64, .little),
                else => unreachable,
            } else switch (wire.code) {
                1 => @as(i8, @bitCast(try reader.byte())),
                2 => try reader.int(i16, .little),
                3, 9 => try reader.int(i32, .little),
                8 => try reader.int(i64, .little),
                else => unreachable,
            };
            if (kind == .boolean) {
                if (n < 0 or n > 1) return error.WireValueOutOfRange;
                break :blk .{ .boolean = n == 1 };
            }
            if (kind == .int8 or kind == .int16 or kind == .int32 or kind == .int64) {
                if (n < std.math.minInt(i64) or n > std.math.maxInt(i64)) return error.WireValueOutOfRange;
                break :blk .{ .signed = n };
            }
            if (n < 0 or n > std.math.maxInt(u64)) return error.WireValueOutOfRange;
            break :blk .{ .unsigned = @intCast(n) };
        },
        .decimal => |d| blk: {
            if (!integer(wire.code)) break :blk try g.Type.decimalParse(try Codec.string(reader, 4096), d);
            const atom = (try decode(reader, if (wire.unsigned) .uint64 else .int64, wire)).?;
            var buffer: [40]u8 = undefined;
            const bytes = if (wire.unsigned) try std.fmt.bufPrint(&buffer, "{d}", .{atom.unsigned}) else try std.fmt.bufPrint(&buffer, "{d}", .{atom.signed});
            break :blk try g.Type.decimalParse(bytes, d);
        },
        .float32, .float64 => blk: {
            const n: f64 = if (wire.code == 4) @as(f32, @bitCast(try reader.int(u32, .little))) else @as(f64, @bitCast(try reader.int(u64, .little)));
            if (!std.math.isFinite(n)) return error.InvalidWireValue;
            break :blk .{ .float = n };
        },
        .utf8, .binary => blk: {
            const value = try Codec.string(reader, g.Limits.max_frame_bytes);
            if (kind == .utf8 and !std.unicode.utf8ValidateSlice(value)) return error.InvalidWireText;
            break :blk .{ .bytes = value };
        },
    };
    try g.Type.validate(kind, result);
    return result;
}
/// A non-NULL binary-row scalar. NULL bitmap and row header are caller-owned.
pub fn encode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), kind: g.Type.Kind, value: Atom) !void {
    try g.Type.validate(kind, value);
    const start = out.items.len;
    errdefer out.shrinkRetainingCapacity(start);
    switch (kind) {
        .int8 => try out.append(allocator, @bitCast(@as(i8, @intCast(value.signed)))),
        .int16 => try Codec.Reader.appendInt(out, allocator, i16, @intCast(value.signed), .little),
        .int32 => try Codec.Reader.appendInt(out, allocator, i32, @intCast(value.signed), .little),
        .int64 => try Codec.Reader.appendInt(out, allocator, i64, @intCast(value.signed), .little),
        .uint8 => try out.append(allocator, @intCast(value.unsigned)),
        .uint16 => try Codec.Reader.appendInt(out, allocator, u16, @intCast(value.unsigned), .little),
        .uint32 => try Codec.Reader.appendInt(out, allocator, u32, @intCast(value.unsigned), .little),
        .uint64 => try Codec.Reader.appendInt(out, allocator, u64, @intCast(value.unsigned), .little),
        .float32 => try Codec.Reader.appendInt(out, allocator, u32, @bitCast(@as(f32, @floatCast(value.float))), .little),
        .float64 => try Codec.Reader.appendInt(out, allocator, u64, @bitCast(value.float), .little),
        .decimal => |d| {
            var scratch: [80]u8 = undefined;
            try Codec.appendString(allocator, out, try g.Type.decimalText(&scratch, value.decimal, d.scale));
        },
        .boolean => try out.append(allocator, @intFromBool(value.boolean)),
        .utf8, .binary => try Codec.appendString(allocator, out, value.bytes),
    }
}
pub fn text(allocator: std.mem.Allocator, out: *std.ArrayList(u8), kind: g.Type.Kind, value: Atom) !void {
    try g.Type.validate(kind, value);
    var scratch: [512]u8 = undefined;
    const bytes = switch (kind) {
        .int8, .int16, .int32, .int64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.signed}),
        .uint8, .uint16, .uint32, .uint64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.unsigned}),
        .float32 => try std.fmt.bufPrint(&scratch, "{d}", .{@as(f32, @floatCast(value.float))}),
        .float64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.float}),
        .decimal => |d| try g.Type.decimalText(&scratch, value.decimal, d.scale),
        .boolean => if (value.boolean) "1" else "0",
        .utf8, .binary => value.bytes,
    };
    const start = out.items.len;
    errdefer out.shrinkRetainingCapacity(start);
    try Codec.appendString(allocator, out, bytes);
}
test "MySQL signedness and typed integer Boolean boundaries" {
    const t = std.testing;
    var reader: Codec.Reader = .{ .bytes = "\xff\xff\xff\xff\xff\xff\xff\xff" };
    try t.expectEqual(@as(u128, std.math.maxInt(u64)), (try decode(&reader, .uint64, .{ .code = 8, .unsigned = true })).?.unsigned);
    reader.offset = 0;
    try t.expectError(error.WireValueOutOfRange, decode(&reader, .int64, .{ .code = 8, .unsigned = true }));
    reader.offset = 0;
    try t.expectEqual(@as(i128, -1), (try decode(&reader, .int64, .{ .code = 8 })).?.signed);
    reader.offset = 0;
    try t.expectError(error.WireValueOutOfRange, decode(&reader, .uint64, .{ .code = 8 }));
    reader = .{ .bytes = "\x02" };
    try t.expectError(error.WireValueOutOfRange, decode(&reader, .boolean, .{ .code = 1 }));
    reader = .{ .bytes = "\x03a\x00b" };
    try t.expectEqualStrings("a\x00b", (try decode(&reader, .utf8, .{ .code = 253 })).?.bytes);
    try t.expectEqual(@as(u16, 33), descriptor(.{ .kind = .uint64, .nullable = false }, 309).flags);
}
