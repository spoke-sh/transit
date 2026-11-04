//! Lossless scalar adaptation; decoded text/binary borrows input except bytea hex.
const std = @import("std");
const g = @import("root.zig").wire;
const Atom = g.fuze.Types.Values.Atom;
const Format = @import("Frontend.zig").Format;
const Reader = g.Bytes;
pub const Descriptor = struct { oid: u32, size: i16, modifier: i32 = -1 };
pub fn descriptor(kind: g.Type.Kind) Descriptor {
    return switch (kind) {
        .int8, .int16, .uint8 => .{ .oid = 21, .size = 2 },
        .int32, .uint16 => .{ .oid = 23, .size = 4 },
        .uint32 => .{ .oid = 20, .size = 8 },
        .int64 => .{ .oid = 20, .size = 8 },
        .uint64 => .{ .oid = 1700, .size = -1, .modifier = (20 << 16) + 4 },
        .decimal => |d| .{ .oid = 1700, .size = -1, .modifier = (@as(i32, d.precision) << 16) + d.scale + 4 },
        .float32 => .{ .oid = 700, .size = 4 },
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
        .int8, .int16, .int32, .int64 => oid == 20 or oid == 21 or oid == 23,
        .uint8, .uint16, .uint32, .uint64, .decimal => oid == 20 or oid == 21 or oid == 23 or oid == 1700,
        .float32, .float64 => oid == 700 or oid == 701,
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
/// PostgreSQL NUMERIC uses signed base-10000 groups and a display scale.
/// Bound work independently of supplied exponents and preserve exact fractions.
fn decimalDecode(bytes: []const u8, d: g.fuze.Types.Decimal) !i128 {
    var reader: Reader = .{ .bytes = bytes };
    const count = try reader.int(i16, .big);
    const weight = try reader.int(i16, .big);
    const sign = try reader.int(u16, .big);
    const scale = try reader.int(u16, .big);
    if (count < 0 or count > 20 or weight < -10 or weight > 9 or scale > 38 or (sign != 0 and sign != 0x4000)) return error.InvalidWireValue;
    var coefficient: i256 = 0;
    for (0..@intCast(count)) |i| {
        const digit = try reader.int(u16, .big);
        if (digit >= 10000) return error.InvalidWireValue;
        if (digit == 0) continue;
        const exponent: i32 = 4 * (@as(i32, weight) - @as(i32, @intCast(i)));
        // A display scale cannot hide nonzero payload digits.
        if (exponent + scale < 0) {
            if (exponent + scale < -4 or @rem(@as(i256, digit), pow10(@intCast(-(exponent + scale)))) != 0) return error.InvalidWireValue;
        }
        const shifted = exponent + d.scale;
        const part: i256 = if (shifted >= 0) std.math.mul(i256, digit, pow10(@intCast(shifted))) catch return error.WireValueOutOfRange else blk: {
            if (shifted < -4 or @rem(@as(i256, digit), pow10(@intCast(-shifted))) != 0) return error.InexactDecimalRounding;
            break :blk @divTrunc(@as(i256, digit), pow10(@intCast(-shifted)));
        };
        coefficient = std.math.add(i256, coefficient, part) catch return error.WireValueOutOfRange;
    }
    try reader.finish();
    if (coefficient >= pow10(d.precision)) return error.WireValueOutOfRange;
    return @intCast(if (sign == 0x4000) -coefficient else coefficient);
}
fn pow10(exponent: u8) i256 {
    var value: i256 = 1;
    for (0..exponent) |_| value *= 10;
    return value;
}
fn decimalEncode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), coefficient: i128, scale: u8) !void {
    // At most 38 coefficient digits plus three group-alignment zeros.
    var value: u256 = @abs(coefficient);
    const fractional_groups = (@as(usize, scale) + 3) / 4;
    for (0..fractional_groups * 4 - scale) |_| value *= 10;
    var digits: [11]u16 = undefined;
    var count: usize = 0;
    while (value != 0) : (value /= 10000) {
        digits[digits.len - 1 - count] = @intCast(value % 10000);
        count += 1;
    }
    const weight: i16 = if (count == 0) 0 else @intCast(@as(isize, @intCast(count)) - @as(isize, @intCast(fractional_groups)) - 1);
    const start = digits.len - count;
    var end = digits.len;
    while (end > start and digits[end - 1] == 0) end -= 1;
    try Reader.appendInt(out, allocator, u16, @intCast(end - start), .big);
    try Reader.appendInt(out, allocator, i16, weight, .big);
    try Reader.appendInt(out, allocator, u16, if (coefficient < 0) 0x4000 else 0, .big);
    try Reader.appendInt(out, allocator, u16, scale, .big);
    for (digits[start..end]) |digit| try Reader.appendInt(out, allocator, u16, digit, .big);
}
pub fn decode(allocator: std.mem.Allocator, kind: g.Type.Kind, declared_oid: u32, format: Format, bytes: ?[]const u8) !?Atom {
    const oid = try resolve(kind, declared_oid);
    const value = bytes orelse return null;
    if (value.len > g.Limits.max_frame_bytes) return error.WireValueTooLarge;
    var reader: Reader = .{ .bytes = value };
    const result: Atom = switch (kind) {
        .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64 => blk: {
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
            if (kind == .int8 or kind == .int16 or kind == .int32 or kind == .int64) {
                if (number < std.math.minInt(i64) or number > std.math.maxInt(i64)) return error.WireValueOutOfRange;
                break :blk .{ .signed = number };
            }
            if (number < 0 or number > std.math.maxInt(u64)) return error.WireValueOutOfRange;
            break :blk .{ .unsigned = @intCast(number) };
        },
        .decimal => |d| blk: {
            if (format == .text) {
                if (oid != 1700) _ = try decode(allocator, .int64, oid, format, value);
                break :blk try g.Type.decimalParse(value, d);
            }
            if (oid == 1700) break :blk .{ .decimal = try decimalDecode(value, d) };
            const n = (try decode(allocator, .int64, oid, format, value)).?.signed;
            var buffer: [40]u8 = undefined;
            break :blk try g.Type.decimalParse(try std.fmt.bufPrint(&buffer, "{d}", .{n}), d);
        },
        .float32, .float64 => blk: {
            if (format == .text) for (value) |byte| switch (byte) {
                '0'...'9', '.', '+', '-', 'e', 'E' => {},
                else => return error.InvalidWireValue,
            };
            var n: f64 = if (format == .text) std.fmt.parseFloat(f64, value) catch return error.InvalidWireValue else if (oid == 700) @as(f32, @bitCast(try reader.int(u32, .big))) else @as(f64, @bitCast(try reader.int(u64, .big)));
            if (format == .binary) try reader.finish();
            if (format == .text and (oid == 700 or kind == .float32)) n = @as(f32, @floatCast(n));
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
    try g.Type.validate(kind, result);
    return result;
}
/// Appends one non-NULL payload. The row owner writes length/-1 framing.
pub fn encode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), kind: g.Type.Kind, format: Format, value: Atom) !void {
    const start = out.items.len;
    errdefer out.shrinkRetainingCapacity(start);
    try g.Type.validate(kind, value);
    if (kind == .utf8) try textValue(value.bytes);
    if (format == .text) {
        var scratch: [512]u8 = undefined;
        const bytes = switch (kind) {
            .int8, .int16, .int32, .int64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.signed}),
            .uint8, .uint16, .uint32, .uint64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.unsigned}),
            .float32 => try std.fmt.bufPrint(&scratch, "{d}", .{@as(f32, @floatCast(value.float))}),
            .float64 => try std.fmt.bufPrint(&scratch, "{d}", .{value.float}),
            .decimal => |d| try g.Type.decimalText(&scratch, value.decimal, d.scale),
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
        .int8, .int16 => try Reader.appendInt(out, allocator, i16, @intCast(value.signed), .big),
        .int32 => try Reader.appendInt(out, allocator, i32, @intCast(value.signed), .big),
        .int64 => try Reader.appendInt(out, allocator, i64, @intCast(value.signed), .big),
        .uint8 => try Reader.appendInt(out, allocator, i16, @intCast(value.unsigned), .big),
        .uint16 => try Reader.appendInt(out, allocator, i32, @intCast(value.unsigned), .big),
        .uint32 => try Reader.appendInt(out, allocator, i64, @intCast(value.unsigned), .big),
        .uint64 => try numericEncode(allocator, out, @intCast(value.unsigned)),
        .decimal => |d| try decimalEncode(allocator, out, value.decimal, d.scale),
        .float32 => try Reader.appendInt(out, allocator, u32, @bitCast(@as(f32, @floatCast(value.float))), .big),
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

test "decimal binary rejects malformed, special, inexact and overflowing input" {
    const t = std.testing;
    const kind: g.Type.Kind = .{ .decimal = .{ .precision = 10, .scale = 2 } };
    try t.expectEqual(@as(i128, -1200), (try decode(t.allocator, kind, 21, .binary, "\xff\xf4")).?.decimal);
    try t.expectError(error.WireValueOutOfRange, decode(t.allocator, .int8, 23, .binary, "\x00\x00\x00\x80"));
    try t.expectError(error.InvalidWireValue, decode(t.allocator, kind, 1700, .binary, "\x00\x00\x00\x00\xc0\x00\x00\x00"));
    try t.expectError(error.InexactDecimalRounding, decode(t.allocator, kind, 1700, .binary, "\x00\x01\xff\xff\x00\x00\x00\x03\x00\x0a"));
    try t.expectError(error.InvalidWireValue, decode(t.allocator, kind, 1700, .binary, "\x00\x01\x00\x00\x00\x00\x00\x00\x27\x10"));
    try t.expectError(error.InvalidWireValue, decode(t.allocator, kind, 1700, .binary, "\x00\x01\xff\xff\x00\x00\x00\x00\x00\x01"));
    const widest: g.Type.Kind = .{ .decimal = .{ .precision = 38, .scale = 38 } };
    try t.expectError(error.WireValueOutOfRange, decode(t.allocator, widest, 1700, .binary, "\x00\x01\x00\x09\x00\x00\x00\x00\x27\x0f"));
}

test "numeric encoding reuses warmed bounded output without heap allocations" {
    const t = std.testing;
    var memory: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&memory);
    var out: std.ArrayList(u8) = .empty;
    try out.ensureTotalCapacityPrecise(fixed.allocator(), 128);
    const used = fixed.end_index;
    const kind: g.Type.Kind = .{ .decimal = .{ .precision = 38, .scale = 38 } };
    for (0..100) |_| {
        for ([_]Format{ .text, .binary }) |format| {
            out.clearRetainingCapacity();
            try encode(fixed.allocator(), &out, kind, format, .{ .decimal = -12345 });
            try t.expectEqual(@as(i128, -12345), (try decode(fixed.allocator(), kind, 1700, format, out.items)).?.decimal);
        }
    }
    try t.expectEqual(used, fixed.end_index);
}
