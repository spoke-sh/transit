//! Lossless scalar adaptation; decoded text/binary borrows input except bytea hex.
const std = @import("std");
const g = @import("root.zig").gateway;
const Atom = g.fuze.Types.Values.Atom;
const Format = @import("Frontend.zig").Format;
const Reader = g.Bytes;
pub const Descriptor = struct { oid: u32, size: i16, modifier: i32 = -1 };
pub fn descriptor(kind: g.Type.Kind) Descriptor {
    return switch (kind) {
        .int64 => .{ .oid = 20, .size = 8 },
        .uint64 => .{ .oid = 1700, .size = -1, .modifier = (20 << 16) + 4 },
        .float64 => .{ .oid = 701, .size = 8 },
        .boolean => .{ .oid = 16, .size = 1 },
        .utf8 => .{ .oid = 25, .size = -1 },
        .binary => .{ .oid = 17, .size = -1 },
    };
}
/// Parse OIDs may use a narrower lossless integer representation. OID zero is
/// inferred; the resolved OID is retained in statement parameter metadata.
pub fn resolve(kind: g.Type.Kind, oid: u32) !u32 {
    if (oid == 0) return descriptor(kind).oid;
    const compatible = switch (kind) {
        .int64 => oid == 20 or oid == 21 or oid == 23,
        .uint64 => oid == 20 or oid == 21 or oid == 23 or oid == 1700,
        .float64 => oid == 700 or oid == 701,
        .boolean => oid == 16,
        .utf8 => oid == 25 or oid == 1043,
        .binary => oid == 17,
    };
    if (!compatible) return error.WireParameterTypeMismatch;
    return oid;
}
fn integerText(bytes: []const u8) !void {
    if (bytes.len == 0) return error.InvalidWireValue;
    const start: usize = if (bytes[0] == '-' or bytes[0] == '+') 1 else 0;
    if (start == bytes.len) return error.InvalidWireValue;
    for (bytes[start..]) |value| if (value < '0' or value > '9') return error.InvalidWireValue;
}
fn textValue(bytes: []const u8) !void {
    if (std.mem.indexOfScalar(u8, bytes, 0) != null or !std.unicode.utf8ValidateSlice(bytes)) return error.InvalidWireText;
}
fn numeric(bytes: []const u8) !u64 {
    var reader: Reader = .{ .bytes = bytes };
    const count = try reader.int(i16, .big);
    const weight = try reader.int(i16, .big);
    const sign = try reader.int(u16, .big);
    const scale = try reader.int(u16, .big);
    if (count < 0 or count > 5 or weight < -1 or weight > 4 or sign != 0 or scale != 0) return error.InvalidWireValue;
    if (count > weight + 1) return error.InvalidWireValue;
    var value: u64 = 0;
    for (0..@intCast(@max(weight + 1, 0))) |i| {
        const digit = if (i < count) try reader.int(u16, .big) else 0;
        if (digit >= 10000) return error.InvalidWireValue;
        value = std.math.add(u64, (std.math.mul(u64, value, 10000) catch return error.WireValueOutOfRange), digit) catch return error.WireValueOutOfRange;
    }
    try reader.finish();
    return value;
}
fn numericEncode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u64) !void {
    var digits: [5]u16 = undefined;
    var n = value;
    var count: usize = 0;
    while (n != 0) : (n /= 10000) {
        digits[4 - count] = @intCast(n % 10000);
        count += 1;
    }
    try Reader.appendInt(out, allocator, u16, @intCast(count), .big);
    try Reader.appendInt(out, allocator, i16, if (count == 0) 0 else @intCast(count - 1), .big);
    try Reader.appendInt(out, allocator, u16, 0, .big);
    try Reader.appendInt(out, allocator, u16, 0, .big);
    for (digits[5 - count ..]) |digit| try Reader.appendInt(out, allocator, u16, digit, .big);
}
pub fn decode(allocator: std.mem.Allocator, kind: g.Type.Kind, declared_oid: u32, format: Format, bytes: ?[]const u8) !?Atom {
    const oid = try resolve(kind, declared_oid);
    const value = bytes orelse return null;
    if (value.len > g.Limits.max_frame_bytes) return error.WireValueTooLarge;
    var reader: Reader = .{ .bytes = value };
    const result: Atom = switch (kind) {
        .int64, .uint64 => blk: {
            if (format == .binary and oid == 1700) break :blk .{ .unsigned = try numeric(value) };
            const number: i128 = if (format == .text) txt: {
                try integerText(value);
                break :txt std.fmt.parseInt(i128, value, 10) catch return error.WireValueOutOfRange;
            } else bin: {
                const n: i128 = switch (oid) {
                    21 => try reader.int(i16, .big),
                    23 => try reader.int(i32, .big),
                    20 => try reader.int(i64, .big),
                    else => unreachable,
                };
                try reader.finish();
                break :bin n;
            };
            // Text parameters obey the declared representation as well as the
            // logical destination; never silently widen an explicitly narrow OID.
            if ((oid == 21 and (number < std.math.minInt(i16) or number > std.math.maxInt(i16))) or
                (oid == 23 and (number < std.math.minInt(i32) or number > std.math.maxInt(i32))) or
                (oid == 20 and (number < std.math.minInt(i64) or number > std.math.maxInt(i64)))) return error.WireValueOutOfRange;
            if (kind == .int64) {
                if (number < std.math.minInt(i64) or number > std.math.maxInt(i64)) return error.WireValueOutOfRange;
                break :blk .{ .signed = number };
            }
            if (number < 0 or number > std.math.maxInt(u64)) return error.WireValueOutOfRange;
            break :blk .{ .unsigned = @intCast(number) };
        },
        .float64 => blk: {
            if (format == .text) for (value) |byte| switch (byte) {
                '0'...'9', '.', '+', '-', 'e', 'E' => {},
                else => return error.InvalidWireValue,
            };
            var n: f64 = if (format == .text) std.fmt.parseFloat(f64, value) catch return error.InvalidWireValue else if (oid == 700) @as(f32, @bitCast(try reader.int(u32, .big))) else @as(f64, @bitCast(try reader.int(u64, .big)));
            if (format == .binary) try reader.finish();
            if (format == .text and oid == 700) n = @as(f32, @floatCast(n));
            if (!std.math.isFinite(n)) return error.InvalidWireValue;
            break :blk .{ .float = n };
        },
        .boolean => blk: {
            if (format == .binary) {
                const n = try reader.byte();
                try reader.finish();
                if (n > 1) return error.InvalidWireValue;
                break :blk .{ .boolean = n == 1 };
            }
            if (std.mem.eql(u8, value, "t") or std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) break :blk .{ .boolean = true };
            if (std.mem.eql(u8, value, "f") or std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0")) break :blk .{ .boolean = false };
            return error.InvalidWireValue;
        },
        .utf8 => blk: {
            try textValue(value);
            break :blk .{ .bytes = value };
        },
        .binary => blk: {
            if (format == .binary) break :blk .{ .bytes = value };
            if (!std.mem.startsWith(u8, value, "\\x") or value.len % 2 != 0) return error.InvalidWireValue;
            const decoded = try allocator.alloc(u8, (value.len - 2) / 2);
            errdefer allocator.free(decoded);
            _ = std.fmt.hexToBytes(decoded, value[2..]) catch return error.InvalidWireValue;
            break :blk .{ .bytes = decoded };
        },
    };
    try g.fuze.LogicalPrepared.validate(result, (g.Type{ .kind = kind, .nullable = true }).logical());
    return result;
}
/// Appends one non-NULL payload. The row owner writes length/-1 framing.
pub fn encode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), kind: g.Type.Kind, format: Format, value: Atom) !void {
    const start = out.items.len;
    errdefer out.shrinkRetainingCapacity(start);
    try g.fuze.LogicalPrepared.validate(value, (g.Type{ .kind = kind, .nullable = false }).logical());
    if (kind == .utf8) try textValue(value.bytes);
    if (format == .text) {
        var scratch: [512]u8 = undefined;
        const bytes = switch (kind) {
            .int64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.signed}),
            .uint64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.unsigned}),
            .float64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.float}),
            .boolean => if (value.boolean) "t" else "f",
            .utf8 => value.bytes,
            .binary => blk: {
                if (value.bytes.len > (g.Limits.max_frame_bytes - 2) / 2) return error.WireValueTooLarge;
                try out.appendSlice(allocator, "\\x");
                for (value.bytes) |byte| try out.appendSlice(allocator, &std.fmt.bytesToHex([_]u8{byte}, .lower));
                break :blk "";
            },
        };
        if (bytes.len > g.Limits.max_frame_bytes) return error.WireValueTooLarge;
        try out.appendSlice(allocator, bytes);
    } else switch (kind) {
        .int64 => try Reader.appendInt(out, allocator, i64, @intCast(value.signed), .big),
        .uint64 => try numericEncode(allocator, out, @intCast(value.unsigned)),
        .float64 => try Reader.appendInt(out, allocator, u64, @bitCast(value.float), .big),
        .boolean => try out.append(allocator, @intFromBool(value.boolean)),
        .utf8, .binary => {
            if (value.bytes.len > g.Limits.max_frame_bytes) return error.WireValueTooLarge;
            try out.appendSlice(allocator, value.bytes);
        },
    }
}
test "PostgreSQL scalar range, exact numeric, UTF8 and NULL boundaries" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const max_numeric = "\x00\x05\x00\x04\x00\x00\x00\x00\x07\x34\x1a\x58\x02\xe1\x03\xbb\x06\x4f";
    try t.expectEqual(@as(u128, std.math.maxInt(u64)), (try decode(a, .uint64, 1700, .binary, max_numeric)).?.unsigned);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(t.allocator);
    try encode(t.allocator, &out, .uint64, .binary, .{ .unsigned = std.math.maxInt(u64) });
    try t.expectEqualSlices(u8, max_numeric, out.items);
    try t.expectEqual(@as(i128, -32768), (try decode(a, .int64, 21, .binary, "\x80\x00")).?.signed);
    try t.expectError(error.WireValueOutOfRange, decode(a, .int64, 21, .text, "32768"));
    try t.expectError(error.WireValueOutOfRange, decode(a, .uint64, 20, .binary, "\xff\xff\xff\xff\xff\xff\xff\xff"));
    try t.expectError(error.InvalidWireValue, decode(a, .uint64, 1700, .text, "1_000"));
    try t.expectError(error.InvalidWireText, decode(a, .utf8, 25, .binary, "a\x00b"));
    try t.expectError(error.InvalidWireValue, decode(a, .float64, 701, .text, "NaN"));
    try t.expectError(error.InvalidWireValue, decode(a, .float64, 701, .text, "1_000"));
    try t.expectError(error.InvalidWireValue, decode(a, .uint64, 1700, .binary, "\x00\x01\x00\x00\x00\x00\x00\x01\x00\x01"));
    try t.expectError(error.WireValueOutOfRange, decode(a, .uint64, 1700, .binary, "\x00\x05\x00\x04\x00\x00\x00\x00\x07\x34\x1a\x58\x02\xe1\x03\xbb\x06\x50"));
    try t.expectError(error.InvalidWireValue, decode(a, .boolean, 16, .binary, "\x02"));
    try t.expectEqualStrings("\x00\xff", (try decode(a, .binary, 17, .text, "\\x00ff")).?.bytes);
    try t.expectEqual(@as(?Atom, null), try decode(a, .int64, 20, .binary, null));
    try t.expectEqual(@as(i128, std.math.minInt(i64)), (try decode(a, .int64, 20, .text, "-9223372036854775808")).?.signed);
}
