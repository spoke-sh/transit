//! Exact prepared values and result scalars for the selected MySQL matrix.
const std = @import("std");
const g = @import("root.zig").gateway;
const Codec = @import("Codec.zig");
const Atom = g.fuze.Types.Values.Atom;
pub const WireType = struct { code: u8, unsigned: bool = false };
pub const Descriptor = struct { code: u8, flags: u16, length: u32, charset: u16, decimals: u8 = 0 };
// utf8mb4_0900_bin is supplied by the session profile, not inferred from a
// client handshake byte. Binary/numeric metadata always uses binary charset 63.
pub fn descriptor(column: g.Type, collation: u16) Descriptor {
    var value: Descriptor = switch (column.kind) {
        .int64 => .{ .code = 8, .flags = 0, .length = 20, .charset = 63 },
        .uint64 => .{ .code = 8, .flags = 32, .length = 20, .charset = 63 },
        .float64 => .{ .code = 5, .flags = 0, .length = 22, .charset = 63, .decimals = 31 },
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
        .int64, .uint64, .boolean => integer(wire.code),
        .float64 => wire.code == 4 or wire.code == 5,
        .utf8, .binary => bytesType(wire.code),
    };
    if (!admitted) return error.WireParameterTypeMismatch;
}
pub fn decode(reader: *Codec.Reader, kind: g.Type.Kind, wire: WireType) !?Atom {
    try compatible(kind, wire);
    if (wire.code == 6) return null;
    return switch (kind) {
        .int64, .uint64, .boolean => blk: {
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
            if (kind == .int64) {
                if (n < std.math.minInt(i64) or n > std.math.maxInt(i64)) return error.WireValueOutOfRange;
                break :blk .{ .signed = n };
            }
            if (n < 0 or n > std.math.maxInt(u64)) return error.WireValueOutOfRange;
            break :blk .{ .unsigned = @intCast(n) };
        },
        .float64 => blk: {
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
}
/// A non-NULL binary-row scalar. NULL bitmap and row header are caller-owned.
pub fn encode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), kind: g.Type.Kind, value: Atom) !void {
    try g.fuze.LogicalPrepared.validate(value, (g.Type{ .kind = kind, .nullable = false }).logical());
    const start = out.items.len;
    errdefer out.shrinkRetainingCapacity(start);
    switch (kind) {
        .int64 => try Codec.Reader.appendInt(out, allocator, i64, @intCast(value.signed), .little),
        .uint64 => try Codec.Reader.appendInt(out, allocator, u64, @intCast(value.unsigned), .little),
        .float64 => try Codec.Reader.appendInt(out, allocator, u64, @bitCast(value.float), .little),
        .boolean => try out.append(allocator, @intFromBool(value.boolean)),
        .utf8, .binary => try Codec.appendString(allocator, out, value.bytes),
    }
}
pub fn text(allocator: std.mem.Allocator, out: *std.ArrayList(u8), kind: g.Type.Kind, value: Atom) !void {
    try g.fuze.LogicalPrepared.validate(value, (g.Type{ .kind = kind, .nullable = false }).logical());
    var scratch: [512]u8 = undefined;
    const bytes = switch (kind) {
        .int64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.signed}),
        .uint64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.unsigned}),
        .float64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.float}),
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
