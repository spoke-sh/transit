//! Composable pure-Zig physical codecs (analytical and enterprise/mainframe)
//! with 5-state cell preservation (`value`, `null`, `missing`, `type_error`, `conflict`).
const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const TableSchema = @import("TableSchema.zig");
const Collation = @import("Collation.zig");

pub const Encoding = TableSchema.Encoding;

/// Encode a signed integer/decimal value into COBOL `COMP-3` (Packed Decimal / BCD)
/// with trailing sign nibble `0xC` (positive/zero) or `0xD` (negative).
pub fn encodeComp3(value: i128, byte_len: usize, out: []u8) ![]const u8 {
    if (byte_len == 0 or byte_len > 16 or out.len < byte_len) return error.InvalidComp3Length;
    const negative = value < 0;
    var magnitude: u128 = if (value == std.math.minInt(i128))
        return error.Comp3Overflow
    else
        @intCast(if (negative) -value else value);

    const max_digits = byte_len * 2 - 1;
    var nibbles: [32]u8 = @splat(0);
    var d: usize = 0;
    while (magnitude > 0) : (d += 1) {
        if (d >= max_digits) return error.Comp3Overflow;
        nibbles[d] = @intCast(magnitude % 10);
        magnitude /= 10;
    }

    const sign_nibble: u8 = if (negative) 0x0D else 0x0C;
    for (0..byte_len) |i| {
        const rev_byte = byte_len - 1 - i;
        if (rev_byte == 0) {
            const high_digit = nibbles[0];
            out[i] = (high_digit << 4) | sign_nibble;
        } else {
            const low_idx = rev_byte * 2 - 1;
            const high_idx = rev_byte * 2;
            out[i] = (nibbles[high_idx] << 4) | nibbles[low_idx];
        }
    }
    return out[0..byte_len];
}

/// Decode a COBOL `COMP-3` (Packed Decimal / BCD) byte slice into a 5-state `Values.Cell`.
/// Any non-BCD digit nibble (`> 9`) or invalid sign nibble (`< 0xA`) is captured losslessly
/// as `.{ .type_error = ... }` rather than aborting a scan.
pub fn decodeComp3(bytes: []const u8, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    if (bytes.len == 0 or bytes.len > 16) return err_cell;
    var magnitude: u128 = 0;
    for (bytes, 0..) |b, i| {
        const high = b >> 4;
        const low = b & 0x0F;
        if (high > 9) return err_cell;
        magnitude = std.math.mul(u128, magnitude, 10) catch return err_cell;
        magnitude = std.math.add(u128, magnitude, high) catch return err_cell;
        if (i + 1 < bytes.len) {
            if (low > 9) return err_cell;
            magnitude = std.math.mul(u128, magnitude, 10) catch return err_cell;
            magnitude = std.math.add(u128, magnitude, low) catch return err_cell;
        } else {
            // Trailing sign nibble: 0xC, 0xF, 0xA, 0xE = positive; 0xD, 0xB = negative
            const negative = switch (low) {
                0x0C, 0x0F, 0x0A, 0x0E => false,
                0x0D, 0x0B => true,
                else => return err_cell,
            };
            if (magnitude > @as(u128, @intCast(std.math.maxInt(i128)))) return err_cell;
            const signed_val: i128 = if (negative and magnitude > 0) -@as(i128, @intCast(magnitude)) else @intCast(magnitude);
            return numericCellFromSigned(signed_val, expected);
        }
    }
    return err_cell;
}

/// Encode a signed integer/decimal into EBCDIC Zoned Decimal (`DISPLAY` numeric)
/// with trailing overpunched sign (`0xC0..0xC9` positive, `0xD0..0xD9` negative).
pub fn encodeZoned(value: i128, digit_len: usize, out: []u8) ![]const u8 {
    if (digit_len == 0 or digit_len > 31 or out.len < digit_len) return error.InvalidZonedLength;
    const negative = value < 0;
    var magnitude: u128 = if (value == std.math.minInt(i128))
        return error.ZonedOverflow
    else
        @intCast(if (negative) -value else value);

    var i: usize = digit_len;
    while (i > 0) {
        i -= 1;
        const digit: u8 = @intCast(magnitude % 10);
        magnitude /= 10;
        if (i + 1 == digit_len) {
            out[i] = (if (negative) @as(u8, 0xD0) else @as(u8, 0xC0)) | digit;
        } else {
            out[i] = 0xF0 | digit;
        }
    }
    if (magnitude != 0) return error.ZonedOverflow;
    return out[0..digit_len];
}

/// Decode an EBCDIC or ASCII Zoned Decimal byte slice into a 5-state `Values.Cell`.
pub fn decodeZoned(bytes: []const u8, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    if (bytes.len == 0 or bytes.len > 31) return err_cell;
    var magnitude: u128 = 0;
    var negative = false;
    for (bytes, 0..) |b, i| {
        const is_edge = (i == 0 or i + 1 == bytes.len);
        const zone = b >> 4;
        const low = b & 0x0F;
        var digit: u8 = 0;
        if (zone == 0x0F and low <= 9) {
            digit = low;
        } else if (is_edge and (zone == 0x0C or zone == 0x0A or zone == 0x0E) and low <= 9) {
            digit = low;
        } else if (is_edge and (zone == 0x0D or zone == 0x0B) and low <= 9) {
            digit = low;
            negative = true;
        } else if (b >= '0' and b <= '9') {
            digit = b - '0';
        } else if (is_edge and b == '{') {
            digit = 0;
        } else if (is_edge and b >= 'A' and b <= 'I') {
            digit = (b - 'A') + 1;
        } else if (is_edge and b == '}') {
            digit = 0;
            negative = true;
        } else if (is_edge and b >= 'J' and b <= 'R') {
            digit = (b - 'J') + 1;
            negative = true;
        } else {
            return err_cell;
        }
        magnitude = std.math.mul(u128, magnitude, 10) catch return err_cell;
        magnitude = std.math.add(u128, magnitude, digit) catch return err_cell;
    }
    if (magnitude > @as(u128, @intCast(std.math.maxInt(i128)))) return err_cell;
    const signed_val: i128 = if (negative and magnitude > 0) -@as(i128, @intCast(magnitude)) else @intCast(magnitude);
    return numericCellFromSigned(signed_val, expected);
}

/// Encode a signed integer/decimal into big-endian `COMP` / `COMP-4` (2, 4, or 8 bytes).
pub fn encodeComp4(value: i128, byte_len: usize, out: []u8) ![]const u8 {
    if (out.len < byte_len) return error.BufferTooSmall;
    switch (byte_len) {
        2 => {
            const v = std.math.cast(i16, value) orelse return error.Comp4Overflow;
            std.mem.writeInt(i16, out[0..2], v, .big);
        },
        4 => {
            const v = std.math.cast(i32, value) orelse return error.Comp4Overflow;
            std.mem.writeInt(i32, out[0..4], v, .big);
        },
        8 => {
            const v = std.math.cast(i64, value) orelse return error.Comp4Overflow;
            std.mem.writeInt(i64, out[0..8], v, .big);
        },
        else => return error.InvalidComp4Length,
    }
    return out[0..byte_len];
}

/// Decode a big-endian `COMP` / `COMP-4` (2, 4, or 8 byte) field into a 5-state `Values.Cell`.
pub fn decodeComp4(bytes: []const u8, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    const signed_val: i128 = switch (bytes.len) {
        2 => std.mem.readInt(i16, bytes[0..2], .big),
        4 => std.mem.readInt(i32, bytes[0..4], .big),
        8 => std.mem.readInt(i64, bytes[0..8], .big),
        else => return err_cell,
    };
    return numericCellFromSigned(signed_val, expected);
}

/// Encode an IEEE-754 `f64` into 8-byte IBM System/360 Hexadecimal Floating-Point (`COMP-2`).
/// Format: `[sign: 1b][characteristic: 7b (excess-64 base-16)][fraction: 56b]`.
pub fn encodeIbmHfp64(value: f64) ![8]u8 {
    if (!std.math.isFinite(value)) return error.InvalidIbmHfpValue;
    if (value == 0.0) return @splat(0);
    const negative = value < 0.0;
    var abs_val = @abs(value);
    var exp16: i32 = 0;
    while (abs_val >= 1.0) : (exp16 += 1) {
        abs_val /= 16.0;
        if (exp16 > 63) return error.IbmHfpOverflow;
    }
    while (abs_val > 0.0 and abs_val < (1.0 / 16.0)) : (exp16 -= 1) {
        abs_val *= 16.0;
        if (exp16 < -64) return @splat(0);
    }
    const characteristic: u8 = @intCast(exp16 + 64);
    const scaled = @round(abs_val * @as(f64, @floatFromInt(@as(u64, 1) << 56)));
    var frac: u64 = @intFromFloat(@min(scaled, @as(f64, @floatFromInt((@as(u64, 1) << 56) - 1))));
    const top_byte: u8 = (if (negative) @as(u8, 0x80) else 0x00) | (characteristic & 0x7F);
    frac |= (@as(u64, top_byte) << 56);
    var out: [8]u8 = undefined;
    std.mem.writeInt(u64, &out, frac, .big);
    return out;
}

/// Decode 4-byte (`COMP-1`) or 8-byte (`COMP-2`) IBM Hexadecimal Floating-Point into a 5-state `Values.Cell`.
pub fn decodeIbmHfp(bytes: []const u8, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    if (bytes.len != 4 and bytes.len != 8) return err_cell;
    const negative = (bytes[0] & 0x80) != 0;
    const characteristic: i32 = @intCast(bytes[0] & 0x7F);
    var fraction: u64 = 0;
    const frac_bits: u6 = if (bytes.len == 4) 24 else 56;
    for (bytes[1..]) |b| {
        fraction = (fraction << 8) | b;
    }
    if (fraction == 0) {
        return floatCellFromF64(0.0, expected);
    }
    const norm_fraction: f64 = @as(f64, @floatFromInt(fraction)) / @as(f64, @floatFromInt(@as(u64, 1) << frac_bits));
    const power2: i32 = (characteristic - 64) * 4;
    const magnitude = std.math.ldexp(norm_fraction, power2);
    if (!std.math.isFinite(magnitude)) return err_cell;
    const result = if (negative) -magnitude else magnitude;
    return floatCellFromF64(result, expected);
}

/// Transcode an EBCDIC CP037 slice into UTF-8/ASCII in `out`.
pub fn decodeEbcdic037(bytes: []const u8, out: []u8) ![]const u8 {
    if (out.len < bytes.len) return error.BufferTooSmall;
    for (bytes, 0..) |b, i| {
        out[i] = Collation.ebcdic037_to_latin1[b];
    }
    return out[0..bytes.len];
}

/// Transcode an ASCII/Latin-1 slice into EBCDIC CP037 in `out`.
pub fn encodeEbcdic037(bytes: []const u8, out: []u8) ![]const u8 {
    if (out.len < bytes.len) return error.BufferTooSmall;
    for (bytes, 0..) |b, i| {
        out[i] = Collation.latin1_to_ebcdic037[b];
    }
    return out[0..bytes.len];
}

fn numericCellFromSigned(val: i128, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    switch (expected) {
        .int8 => {
            if (val < std.math.minInt(i8) or val > std.math.maxInt(i8)) return err_cell;
            return .{ .value = .{ .atom = .{ .signed = val } } };
        },
        .int16 => {
            if (val < std.math.minInt(i16) or val > std.math.maxInt(i16)) return err_cell;
            return .{ .value = .{ .atom = .{ .signed = val } } };
        },
        .int32 => {
            if (val < std.math.minInt(i32) or val > std.math.maxInt(i32)) return err_cell;
            return .{ .value = .{ .atom = .{ .signed = val } } };
        },
        .int64 => {
            if (val < std.math.minInt(i64) or val > std.math.maxInt(i64)) return err_cell;
            return .{ .value = .{ .atom = .{ .signed = val } } };
        },
        .int128 => return .{ .value = .{ .atom = .{ .signed = val } } },
        .decimal => |dec| {
            var max_mag: i128 = 1;
            for (0..dec.precision) |_| max_mag *= 10;
            if (val <= -max_mag or val >= max_mag) return err_cell;
            return .{ .value = .{ .atom = .{ .decimal = val } } };
        },
        else => return err_cell,
    }
}

fn floatCellFromF64(val: f64, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    switch (expected) {
        .float32 => {
            const f32_val: f32 = @floatCast(val);
            if (!std.math.isFinite(f32_val)) return err_cell;
            return .{ .value = .{ .atom = .{ .float = @floatCast(f32_val) } } };
        },
        .float64 => return .{ .value = .{ .atom = .{ .float = val } } },
        else => return err_cell,
    }
}

/// Encode a column slice of 5-state `Values.Cell` into a self-contained physical column page
/// using the column's declared `Encoding` ($\epsilon$).
/// Page wire format:
///   - `magic`: `"TCP1"` (4 bytes)
///   - `encoding`: `u8` (`@intFromEnum(encoding)`)
///   - `row_count`: `u32`
///   - `tag_stream`: `row_count` bytes (`0 = value`, `1 = null`, `2 = missing`, `3 = type_error`, `4 = conflict`)
///   - `detail_stream`: for `.type_error` (`u8` kind) and `.conflict` (`u16` count + alternatives)
///   - `value_payload`: physical codec representation for all `.value` lanes (`plain`, `bitpacked`, `rle`, `dictionary`, `fsst`, `comp3`, `zoned`, `comp4`, `ibm_hfp`, `ebcdic`).
pub fn encodeColumnPage(allocator: std.mem.Allocator, column: TableSchema.Column, cells: []const Values.Cell, out: []u8) ![]const u8 {
    try column.validateEncodingAndCollation();
    var writer: std.Io.Writer = .fixed(out);
    try writer.writeAll("TCP1");
    try writer.writeByte(@backingInt(column.encoding));
    try writer.writeInt(u32, @intCast(cells.len), .little);

    // 1. Write 5-state tag stream
    var value_count: u32 = 0;
    for (cells) |cell| {
        const tag_byte: u8 = switch (cell) {
            .value => blk: {
                value_count += 1;
                break :blk 0;
            },
            .null => 1,
            .missing => 2,
            .type_error => 3,
            .conflict => 4,
        };
        try writer.writeByte(tag_byte);
    }

    // 2. Write detail stream for type_error and conflict cells
    for (cells) |cell| switch (cell) {
        .type_error => |kind| try writer.writeByte(@backingInt(kind)),
        .conflict => |alts| {
            try writer.writeInt(u16, @intCast(alts.len), .little);
            for (alts) |alt| {
                try writer.writeInt(u64, alt.counter, .little);
                try writer.writeInt(u64, alt.replica, .little);
                switch (alt.value) {
                    .null => try writer.writeByte(0),
                    .type_error => |kind| {
                        try writer.writeByte(1);
                        try writer.writeByte(@backingInt(kind));
                    },
                    .value => |val| {
                        try writer.writeByte(2);
                        try writeCanonicalValue(&writer, column.type, val);
                    },
                }
            }
        },
        else => {},
    };

    // 3. Collect `.value` cells for codec-specific encoding
    const values = try allocator.alloc(Values.Value, value_count);
    defer allocator.free(values);
    var vi: usize = 0;
    for (cells) |cell| if (cell == .value) {
        values[vi] = cell.value;
        vi += 1;
    };

    switch (column.encoding) {
        .plain => {
            for (values) |val| try writeCanonicalValue(&writer, column.type, val);
        },
        .bitpacked => try encodeBitpackedValues(&writer, column.type, values),
        .rle => try encodeRleValues(&writer, column.type, values),
        .dictionary => try encodeDictionaryValues(allocator, &writer, column.type, values),
        .fsst => try encodeFsstValues(&writer, values),
        .comp_3 => {
            for (values) |val| {
                const num: i128 = switch (val.atom) {
                    .signed => |s| s,
                    .decimal => |d| d,
                    else => return error.IncompatibleColumnEncoding,
                };
                var buf: [16]u8 = undefined;
                const encoded = try encodeComp3(num, 16, &buf);
                try writer.writeAll(encoded);
            }
        },
        .zoned => {
            for (values) |val| {
                const num: i128 = switch (val.atom) {
                    .signed => |s| s,
                    .decimal => |d| d,
                    else => return error.IncompatibleColumnEncoding,
                };
                var buf: [31]u8 = undefined;
                const encoded = try encodeZoned(num, 31, &buf);
                try writer.writeAll(encoded);
            }
        },
        .comp => {
            const width: usize = switch (column.type) {
                .int16 => 2,
                .int32 => 4,
                else => 8,
            };
            for (values) |val| {
                const num: i128 = switch (val.atom) {
                    .signed => |s| s,
                    .decimal => |d| d,
                    else => return error.IncompatibleColumnEncoding,
                };
                var buf: [8]u8 = undefined;
                const encoded = try encodeComp4(num, width, &buf);
                try writer.writeAll(encoded);
            }
        },
        .ibm_hfp => {
            for (values) |val| {
                const hfp = try encodeIbmHfp64(val.atom.float);
                try writer.writeAll(&hfp);
            }
        },
        .ebcdic => {
            for (values) |val| {
                const bytes = val.atom.bytes;
                try writer.writeInt(u32, @intCast(bytes.len), .little);
                for (bytes) |b| try writer.writeByte(Collation.latin1_to_ebcdic037[b]);
            }
        },
    }
    return writer.buffered();
}

/// Decode a physical column page encoded by `encodeColumnPage` back into `Values.Cell` items
/// owned by `arena`.
pub fn decodeColumnPage(arena: std.mem.Allocator, column: TableSchema.Column, bytes: []const u8) ![]Values.Cell {
    if (bytes.len < 9 or !std.mem.eql(u8, bytes[0..4], "TCP1")) return error.InvalidColumnPage;
    var reader: std.Io.Reader = .fixed(bytes[4..]);
    const enc_raw = try reader.takeByte();
    const encoding = std.enums.fromInt(Encoding, enc_raw) orelse return error.InvalidColumnPage;
    if (encoding != column.encoding) return error.ColumnEncodingMismatch;
    const row_count = try reader.takeInt(u32, .little);
    if (row_count > 65536) return error.ColumnPageRowLimitExceeded;

    const tags = try reader.take(row_count);
    const cells = try arena.alloc(Values.Cell, row_count);
    var value_count: u32 = 0;
    for (tags, 0..) |t, i| {
        cells[i] = switch (t) {
            0 => blk: {
                value_count += 1;
                break :blk .null; // placeholder filled below
            },
            1 => .null,
            2 => .missing,
            3 => .{ .type_error = .unknown },
            4 => .{ .conflict = &.{} },
            else => return error.InvalidColumnPage,
        };
    }

    // Read detail stream
    for (tags, 0..) |t, i| {
        if (t == 3) {
            const k_raw = try reader.takeByte();
            cells[i] = .{ .type_error = std.enums.fromInt(Types.Kind, k_raw) orelse return error.InvalidColumnPage };
        } else if (t == 4) {
            const alt_count = try reader.takeInt(u16, .little);
            const alts = try arena.alloc(Values.Alternative, alt_count);
            for (alts) |*alt| {
                const counter = try reader.takeInt(u64, .little);
                const replica = try reader.takeInt(u64, .little);
                const state_tag = try reader.takeByte();
                alt.* = .{
                    .counter = counter,
                    .replica = replica,
                    .value = switch (state_tag) {
                        0 => .null,
                        1 => .{ .type_error = std.enums.fromInt(Types.Kind, try reader.takeByte()) orelse return error.InvalidColumnPage },
                        2 => .{ .value = try readCanonicalValue(arena, &reader, column.type) },
                        else => return error.InvalidColumnPage,
                    },
                };
            }
            cells[i] = .{ .conflict = alts };
        }
    }

    // Decode `.value` stream according to `column.encoding`
    const decoded_values = try arena.alloc(Values.Cell, value_count);
    switch (column.encoding) {
        .plain => {
            for (decoded_values) |*slot| slot.* = .{ .value = try readCanonicalValue(arena, &reader, column.type) };
        },
        .bitpacked => try decodeBitpackedValues(&reader, column.type, decoded_values),
        .rle => try decodeRleValues(arena, &reader, column.type, decoded_values),
        .dictionary => try decodeDictionaryValues(arena, &reader, column.type, decoded_values),
        .fsst => try decodeFsstValues(arena, &reader, decoded_values),
        .comp_3 => {
            for (decoded_values) |*slot| {
                const raw = try reader.take(16);
                slot.* = decodeComp3(raw, column.type);
            }
        },
        .zoned => {
            for (decoded_values) |*slot| {
                const raw = try reader.take(31);
                slot.* = decodeZoned(raw, column.type);
            }
        },
        .comp => {
            const width: usize = switch (column.type) {
                .int16 => 2,
                .int32 => 4,
                else => 8,
            };
            for (decoded_values) |*slot| {
                const raw = try reader.take(width);
                slot.* = decodeComp4(raw, column.type);
            }
        },
        .ibm_hfp => {
            for (decoded_values) |*slot| {
                const raw = try reader.take(8);
                slot.* = decodeIbmHfp(raw, column.type);
            }
        },
        .ebcdic => {
            for (decoded_values) |*slot| {
                const len = try reader.takeInt(u32, .little);
                const raw = try reader.take(len);
                const utf8 = try arena.alloc(u8, len);
                _ = try decodeEbcdic037(raw, utf8);
                slot.* = .{ .value = .{ .atom = .{ .bytes = utf8 } } };
            }
        },
    }

    var vi: usize = 0;
    for (tags, 0..) |t, i| if (t == 0) {
        cells[i] = decoded_values[vi];
        vi += 1;
    };
    return cells;
}

fn scalarToU64(expected: Types.Type, val: Values.Value) u64 {
    return switch (expected) {
        .boolean => @intFromBool(val.atom.boolean),
        .uint8, .uint16, .uint32, .uint64 => @intCast(val.atom.unsigned),
        .int8, .int16, .int32, .int64 => @bitCast(@as(i64, @intCast(val.atom.signed))),
        .date => @intCast(@as(u32, @bitCast(val.atom.date))),
        .time => val.atom.time,
        .timestamp => @bitCast(val.atom.timestamp),
        else => unreachable,
    };
}

fn u64ToScalarCell(expected: Types.Type, word: u64) Values.Cell {
    return .{ .value = .{ .atom = switch (expected) {
        .boolean => .{ .boolean = word != 0 },
        .uint8, .uint16, .uint32, .uint64 => .{ .unsigned = word },
        .int8, .int16, .int32, .int64 => .{ .signed = @as(i64, @bitCast(word)) },
        .date => .{ .date = @bitCast(@as(u32, @intCast(word))) },
        .time => .{ .time = word },
        .timestamp => .{ .timestamp = @bitCast(word) },
        else => unreachable,
    } } };
}

fn encodeBitpackedValues(writer: *std.Io.Writer, expected: Types.Type, values: []const Values.Value) !void {
    if (values.len == 0) return;
    var min_val: u64 = std.math.maxInt(u64);
    var max_val: u64 = 0;
    for (values) |v| {
        const w = scalarToU64(expected, v);
        min_val = @min(min_val, w);
        max_val = @max(max_val, w);
    }
    const delta = max_val - min_val;
    const bit_width: u8 = if (delta == 0) 0 else @intCast(64 - @clz(delta));
    try writer.writeInt(u64, min_val, .little);
    try writer.writeByte(bit_width);
    if (bit_width == 0) return;

    var bit_acc: u128 = 0;
    var acc_bits: u8 = 0;
    const shift_w: u7 = @intCast(bit_width);
    const mask: u64 = if (bit_width == 64) std.math.maxInt(u64) else (@as(u64, 1) << @intCast(bit_width)) - 1;
    for (values) |v| {
        const offset = (scalarToU64(expected, v) - min_val) & mask;
        bit_acc |= (@as(u128, offset) << @intCast(acc_bits));
        acc_bits += @intCast(shift_w);
        while (acc_bits >= 8) {
            try writer.writeByte(@truncate(bit_acc));
            bit_acc >>= 8;
            acc_bits -= 8;
        }
    }
    if (acc_bits > 0) {
        try writer.writeByte(@truncate(bit_acc));
    }
}

fn decodeBitpackedValues(reader: *std.Io.Reader, expected: Types.Type, out: []Values.Cell) !void {
    if (out.len == 0) return;
    const min_val = try reader.takeInt(u64, .little);
    const bit_width = try reader.takeByte();
    if (bit_width > 64) return error.InvalidBitpackedPage;
    if (bit_width == 0) {
        for (out) |*slot| slot.* = u64ToScalarCell(expected, min_val);
        return;
    }
    var bit_acc: u128 = 0;
    var acc_bits: u8 = 0;
    const mask: u64 = if (bit_width == 64) std.math.maxInt(u64) else (@as(u64, 1) << @intCast(bit_width)) - 1;
    for (out) |*slot| {
        while (acc_bits < bit_width) {
            const b = try reader.takeByte();
            bit_acc |= (@as(u128, b) << @intCast(acc_bits));
            acc_bits += 8;
        }
        const offset: u64 = @as(u64, @truncate(bit_acc)) & mask;
        bit_acc >>= @intCast(bit_width);
        acc_bits -= bit_width;
        slot.* = u64ToScalarCell(expected, min_val +% offset);
    }
}

fn encodeRleValues(writer: *std.Io.Writer, expected: Types.Type, values: []const Values.Value) !void {
    if (values.len == 0) {
        try writer.writeInt(u32, 0, .little);
        return;
    }
    var runs: u32 = 1;
    for (1..values.len) |i| {
        if (!valuesEqual(expected, values[i - 1], values[i])) runs += 1;
    }
    try writer.writeInt(u32, runs, .little);
    var run_start: usize = 0;
    for (1..values.len + 1) |i| {
        if (i == values.len or !valuesEqual(expected, values[run_start], values[i])) {
            try writeCanonicalValue(writer, expected, values[run_start]);
            try writer.writeInt(u32, @intCast(i - run_start), .little);
            run_start = i;
        }
    }
}

fn decodeRleValues(arena: std.mem.Allocator, reader: *std.Io.Reader, expected: Types.Type, out: []Values.Cell) !void {
    const runs = try reader.takeInt(u32, .little);
    var pos: usize = 0;
    for (0..runs) |_| {
        const val = try readCanonicalValue(arena, reader, expected);
        const len = try reader.takeInt(u32, .little);
        if (pos + len > out.len) return error.InvalidRlePage;
        for (0..len) |_| {
            out[pos] = .{ .value = val };
            pos += 1;
        }
    }
    if (pos != out.len) return error.InvalidRlePage;
}

fn encodeDictionaryValues(allocator: std.mem.Allocator, writer: *std.Io.Writer, expected: Types.Type, values: []const Values.Value) !void {
    var dict = std.ArrayList(Values.Value).empty;
    defer dict.deinit(allocator);
    const codes = try allocator.alloc(u32, values.len);
    defer allocator.free(codes);

    for (values, 0..) |v, i| {
        var found: ?u32 = null;
        for (dict.items, 0..) |dv, di| {
            if (valuesEqual(expected, dv, v)) {
                found = @intCast(di);
                break;
            }
        }
        if (found) |code| {
            codes[i] = code;
        } else {
            const new_code: u32 = @intCast(dict.items.len);
            try dict.append(allocator, v);
            codes[i] = new_code;
        }
    }
    try writer.writeInt(u32, @intCast(dict.items.len), .little);
    for (dict.items) |dv| try writeCanonicalValue(writer, expected, dv);
    for (codes) |code| try writer.writeInt(u32, code, .little);
}

fn decodeDictionaryValues(arena: std.mem.Allocator, reader: *std.Io.Reader, expected: Types.Type, out: []Values.Cell) !void {
    const dict_len = try reader.takeInt(u32, .little);
    const dict = try arena.alloc(Values.Value, dict_len);
    for (dict) |*dv| dv.* = try readCanonicalValue(arena, reader, expected);
    for (out) |*slot| {
        const code = try reader.takeInt(u32, .little);
        if (code >= dict.len) return error.InvalidDictionaryCode;
        slot.* = .{ .value = dict[code] };
    }
}

/// Fast Static Symbol Table (FSST) string compression: builds a compact symbol table
/// of frequent 2-to-8 byte substrings and encodes strings as symbol codes (`0..symbol_count-1`)
/// with `0xFF` literal escape bytes.
fn encodeFsstValues(writer: *std.Io.Writer, values: []const Values.Value) !void {
    var symbols: [64][]const u8 = undefined;
    var symbol_count: u8 = 0;

    // Harvest up to 64 recurring 4-byte or 2-byte substrings from input values
    for (values) |v| {
        const s = v.atom.bytes;
        var pos: usize = 0;
        while (pos + 4 <= s.len and symbol_count < 64) : (pos += 4) {
            const cand = s[pos .. pos + 4];
            var exists = false;
            for (symbols[0..symbol_count]) |existing| {
                if (std.mem.eql(u8, existing, cand)) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                symbols[symbol_count] = cand;
                symbol_count += 1;
            }
        }
    }

    try writer.writeByte(symbol_count);
    for (symbols[0..symbol_count]) |sym| {
        try writer.writeByte(@intCast(sym.len));
        try writer.writeAll(sym);
    }

    for (values) |v| {
        const s = v.atom.bytes;
        try writer.writeInt(u32, @intCast(s.len), .little);
        // Reserve a small scratch buffer or stream compressed tokens directly
        var token_count: u32 = 0;
        var pos: usize = 0;
        while (pos < s.len) {
            var matched: ?u8 = null;
            for (symbols[0..symbol_count], 0..) |sym, idx| {
                if (pos + sym.len <= s.len and std.mem.eql(u8, s[pos .. pos + sym.len], sym)) {
                    matched = @intCast(idx);
                    pos += sym.len;
                    break;
                }
            }
            if (matched != null) {
                token_count += 1;
            } else {
                token_count += 2; // 0xFF escape + literal byte
                pos += 1;
            }
        }
        try writer.writeInt(u32, token_count, .little);
        pos = 0;
        while (pos < s.len) {
            var matched: ?u8 = null;
            for (symbols[0..symbol_count], 0..) |sym, idx| {
                if (pos + sym.len <= s.len and std.mem.eql(u8, s[pos .. pos + sym.len], sym)) {
                    matched = @intCast(idx);
                    pos += sym.len;
                    break;
                }
            }
            if (matched) |code| {
                try writer.writeByte(code);
            } else {
                try writer.writeByte(0xFF);
                try writer.writeByte(s[pos]);
                pos += 1;
            }
        }
    }
}

fn decodeFsstValues(arena: std.mem.Allocator, reader: *std.Io.Reader, out: []Values.Cell) !void {
    const symbol_count = try reader.takeByte();
    if (symbol_count > 254) return error.InvalidFsstTable;
    var symbols: [254][]const u8 = undefined;
    for (0..symbol_count) |i| {
        const sym_len = try reader.takeByte();
        if (sym_len == 0 or sym_len > 8) return error.InvalidFsstTable;
        symbols[i] = try reader.take(sym_len);
    }
    for (out) |*slot| {
        const decoded_len = try reader.takeInt(u32, .little);
        const token_len = try reader.takeInt(u32, .little);
        const tokens = try reader.take(token_len);
        const buf = try arena.alloc(u8, decoded_len);
        var ti: usize = 0;
        var bi: usize = 0;
        while (ti < tokens.len) {
            const tok = tokens[ti];
            ti += 1;
            if (tok == 0xFF) {
                if (ti >= tokens.len or bi >= buf.len) return error.InvalidFsstStream;
                buf[bi] = tokens[ti];
                ti += 1;
                bi += 1;
            } else {
                if (tok >= symbol_count) return error.InvalidFsstStream;
                const sym = symbols[tok];
                if (bi + sym.len > buf.len) return error.InvalidFsstStream;
                @memcpy(buf[bi .. bi + sym.len], sym);
                bi += sym.len;
            }
        }
        if (bi != decoded_len) return error.InvalidFsstStream;
        slot.* = .{ .value = .{ .atom = .{ .bytes = buf } } };
    }
}

fn valuesEqual(expected: Types.Type, a: Values.Value, b: Values.Value) bool {
    return switch (a) {
        .atom => |la| (Values.atomOrder(la, b.atom, expected) catch return false) == .eq,
        .json => |lj| std.mem.eql(u8, lj, b.json),
        else => false,
    };
}

fn writeCanonicalValue(writer: *std.Io.Writer, expected: Types.Type, val: Values.Value) !void {
    const field: Types.Field = .{ .name = "v", .type = expected, .nullable = true };
    const cell: Values.Cell = .{ .value = val };
    // Column encoders use a fixed segment budget. Encode into that remaining
    // buffer, without imposing a separate 4 KiB limit on each logical value.
    const start = writer.end;
    try writer.writeInt(u32, 0, .little);
    const encoded = try Types.Codec.encodeBound(cell, field, writer.buffer[writer.end..]);
    std.mem.writeInt(u32, writer.buffer[start..][0..4], @intCast(encoded.len), .little);
    writer.end += encoded.len;
}

fn readCanonicalValue(arena: std.mem.Allocator, reader: *std.Io.Reader, expected: Types.Type) !Values.Value {
    const field: Types.Field = .{ .name = "v", .type = expected, .nullable = true };
    const len = try reader.takeInt(u32, .little);
    const slice = try reader.take(len);
    const decoded = try Types.Codec.decodeBoundInto(arena, field, slice);
    if (decoded != .value) return error.InvalidColumnPage;
    return decoded.value;
}
