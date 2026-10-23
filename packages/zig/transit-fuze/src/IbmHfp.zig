//! Exact binary floating-point / IBM hexadecimal floating-point conversion.
const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");

/// Encode an IEEE-754 `f64` into 8-byte IBM System/360 Hexadecimal Floating-Point (`COMP-2`).
/// Format: `[sign: 1b][characteristic: 7b (excess-64 base-16)][fraction: 56b]`.
pub fn encode64(value: f64) ![8]u8 {
    if (!std.math.isFinite(value)) return error.InvalidIbmHfpValue;
    const bits: u64 = @bitCast(value);
    const sign = bits & (@as(u64, 1) << 63);
    var out: [8]u8 = undefined;
    if (value == 0.0) {
        std.mem.writeInt(u64, &out, sign, .big);
        return out;
    }
    // Every binary64 significand fits exactly in 56 HFP fraction bits.
    // Reject outside the normalized HFP range; never round or underflow to zero.
    const exponent: i32 = @as(i32, @intCast((bits >> 52) & 0x7ff)) - 1023;
    if (exponent < -260) return error.IbmHfpUnderflow;
    if (exponent > 251) return error.IbmHfpOverflow;
    const power = @divFloor(exponent, 4);
    const characteristic: u64 = @intCast(power + 65);
    const shift: u6 = @intCast(exponent - 4 * power);
    const significand = (bits & ((@as(u64, 1) << 52) - 1)) | (@as(u64, 1) << 52);
    std.mem.writeInt(u64, &out, sign | (characteristic << 56) | (significand << shift), .big);
    return out;
}

/// Decode 4-byte (`COMP-1`) or 8-byte (`COMP-2`) IBM Hexadecimal Floating-Point into a 5-state `Values.Cell`.
pub fn decode(bytes: []const u8, expected: Types.Type) Values.Cell {
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
        return floatCellFromF64(if (negative) -0.0 else 0.0, expected);
    }
    const exact: f64 = @floatFromInt(fraction);
    if (@as(u64, @intFromFloat(exact)) != fraction) return err_cell;
    const norm_fraction: f64 = exact / @as(f64, @floatFromInt(@as(u64, 1) << frac_bits));
    const power2: i32 = (characteristic - 64) * 4;
    const magnitude = std.math.ldexp(norm_fraction, power2);
    if (!std.math.isFinite(magnitude)) return err_cell;
    const result = if (negative) -magnitude else magnitude;
    return floatCellFromF64(result, expected);
}

fn floatCellFromF64(val: f64, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    switch (expected) {
        .float32 => {
            const f32_val: f32 = @floatCast(val);
            if (!std.math.isFinite(f32_val) or @as(f64, f32_val) != val) return err_cell;
            return .{ .value = .{ .atom = .{ .float = @floatCast(f32_val) } } };
        },
        .float64 => return .{ .value = .{ .atom = .{ .float = val } } },
        else => return err_cell,
    }
}
