//! Literal binding, explicit casts, domain promotion and observation inference
//! are deliberately separate. Exact numbers never pass through binary floats.
const std = @import("std");
const types = @import("Types.zig");
const Type = types.Type;
pub const Rounding = enum { reject, toward_zero, nearest_even };
pub const Interval = struct { months: i32, days: i32, nanos: i64 };
pub const Atom = union(enum) {
    signed: i128,
    unsigned: u128,
    float: f64,
    decimal: i128,
    boolean: bool,
    bytes: []const u8,
    date: i32,
    time: u64,
    timestamp: i64,
    interval: Interval,
    uuid: [16]u8,
};
pub const Integer = struct { signed: bool, bits: u8 };
pub fn integer(value: Type) ?Integer {
    return switch (value) {
        .int8 => .{ .signed = true, .bits = 8 },
        .int16 => .{ .signed = true, .bits = 16 },
        .int32 => .{ .signed = true, .bits = 32 },
        .int64 => .{ .signed = true, .bits = 64 },
        .int128 => .{ .signed = true, .bits = 128 },
        .uint8 => .{ .signed = false, .bits = 8 },
        .uint16 => .{ .signed = false, .bits = 16 },
        .uint32 => .{ .signed = false, .bits = 32 },
        .uint64 => .{ .signed = false, .bits = 64 },
        .uint128 => .{ .signed = false, .bits = 128 },
        else => null,
    };
}
fn integerType(signed: bool, bits: u8) Type {
    return if (signed) switch (bits) {
        8 => .int8,
        16 => .int16,
        32 => .int32,
        64 => .int64,
        else => .int128,
    } else switch (bits) {
        8 => .uint8,
        16 => .uint16,
        32 => .uint32,
        64 => .uint64,
        else => .uint128,
    };
}
fn checkInteger(value: i256, target: Integer) !Atom {
    const upper: i256 = @as(i256, 1) << @intCast(if (target.signed) target.bits - 1 else target.bits);
    const lower: i256 = if (target.signed) -upper else 0;
    if (value < lower or value >= upper) return error.Overflow;
    return if (target.signed) .{ .signed = @intCast(value) } else .{ .unsigned = @intCast(value) };
}
fn pow10(exponent: u8) i256 {
    var result: i256 = 1;
    for (0..exponent) |_| result *= 10;
    return result;
}
// The pinned x86_64 Debug backend can load this i256 stack argument with
// vmovdqa despite only 16-byte alignment at the call site. Keep the coefficient
// in the caller to avoid that load while retaining checked arithmetic.
pub inline fn rescale(value: i256, from: u8, to: u8, rounding: Rounding) !i256 {
    if (from > 76 or to > 76) return error.Overflow;
    if (to >= from) {
        const result = @mulWithOverflow(value, pow10(to - from));
        if (result[1] != 0) return error.Overflow;
        return result[0];
    }
    const divisor = pow10(from - to);
    var quotient = @divTrunc(value, divisor);
    const remainder = @rem(value, divisor);
    if (remainder == 0) return quotient;
    switch (rounding) {
        .reject => return error.Inexact,
        .toward_zero => return quotient,
        .nearest_even => {
            const distance = @abs(remainder);
            const half: u256 = @intCast(@divTrunc(divisor, 2));
            if (distance > half or (distance == half and @rem(quotient, 2) != 0)) quotient += if (value < 0) @as(i256, -1) else 1;
            return quotient;
        },
    }
}
pub fn validate(value: Atom, expected: Type) !void {
    if (integer(expected)) |target| {
        const number: i256 = switch (value) {
            .signed => |v| v,
            .unsigned => |v| v,
            else => return error.TypeMismatch,
        };
        if (target.signed != (value == .signed)) return error.TypeMismatch;
        _ = try checkInteger(number, target);
        return;
    }
    switch (expected) {
        .float32, .float64 => {
            if (value != .float) return error.TypeMismatch;
            if (!std.math.isFinite(value.float)) return error.NonFiniteValue;
            if (expected == .float32) {
                const narrowed: f32 = @floatCast(value.float);
                if (!std.math.isFinite(narrowed) or @as(f64, narrowed) != value.float) return error.Inexact;
            }
        },
        .decimal => |d| {
            if (d.precision == 0 or d.precision > 38 or d.scale > d.precision) return error.InvalidDecimal;
            if (value != .decimal) return error.TypeMismatch;
            if (@as(i256, value.decimal) <= -pow10(d.precision) or @as(i256, value.decimal) >= pow10(d.precision)) return error.Overflow;
        },
        .boolean => if (value != .boolean) return error.TypeMismatch,
        .utf8, .binary, .json => {
            if (value != .bytes) return error.TypeMismatch;
            if (expected != .binary and !std.unicode.utf8ValidateSlice(value.bytes)) return error.InvalidUtf8;
            if (expected == .json) return error.UnsupportedAtomType;
        },
        .date => if (value != .date) return error.TypeMismatch,
        .time => {
            if (value != .time) return error.TypeMismatch;
            if (value.time >= 86400_000_000_000) return error.InvalidTime;
        },
        .timestamp => if (value != .timestamp) return error.TypeMismatch,
        .interval => if (value != .interval) return error.TypeMismatch,
        .uuid => if (value != .uuid) return error.TypeMismatch,
        else => return error.UnsupportedAtomType,
    }
}
fn numberGrammar(text: []const u8, fraction: bool) !void {
    if (text.len == 0 or text.len > 4096) return error.InvalidLiteral;
    var i: usize = if (text[0] == '-' or text[0] == '+') 1 else 0;
    const start = i;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    if (i == start) return error.InvalidLiteral;
    if (fraction and i < text.len and text[i] == '.') {
        i += 1;
        const begin = i;
        while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
        if (i == begin) return error.InvalidLiteral;
    }
    if (fraction and i < text.len and (text[i] == 'e' or text[i] == 'E')) {
        i += 1;
        if (i < text.len and (text[i] == '-' or text[i] == '+')) i += 1;
        const begin = i;
        while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
        if (i == begin) return error.InvalidLiteral;
    }
    if (i != text.len) return error.InvalidLiteral;
}
pub const Exact = struct { coefficient: i256, scale: u8 };
pub fn exact(text: []const u8) !Exact {
    try numberGrammar(text, true);
    var i: usize = if (text[0] == '-' or text[0] == '+') 1 else 0;
    var coefficient: i256 = 0;
    var fractional: i32 = 0;
    var after_dot = false;
    while (i < text.len and text[i] != 'e' and text[i] != 'E') : (i += 1) {
        if (text[i] == '.') {
            after_dot = true;
            continue;
        }
        const multiplied = @mulWithOverflow(coefficient, @as(i256, 10));
        const added = @addWithOverflow(multiplied[0], @as(i256, text[i] - '0'));
        if (multiplied[1] != 0 or added[1] != 0) return error.Overflow;
        coefficient = added[0];
        if (after_dot) fractional += 1;
    }
    if (i < text.len) fractional -= std.fmt.parseInt(i16, text[i + 1 ..], 10) catch return error.Overflow;
    if (text[0] == '-') coefficient = -coefficient;
    if (fractional < 0) {
        if (fractional < -76) return error.Overflow;
        coefficient = try rescale(coefficient, 0, @intCast(-fractional), .reject);
        fractional = 0;
    }
    while (fractional > 0 and @rem(coefficient, 10) == 0) {
        coefficient = @divTrunc(coefficient, 10);
        fractional -= 1;
    }
    if (fractional > 76) return error.Overflow;
    return .{ .coefficient = coefficient, .scale = @intCast(fractional) };
}
pub fn bind(text: []const u8, target: Type) !Atom {
    try target.validate(.{});
    if (integer(target)) |info| {
        try numberGrammar(text, false);
        const number = std.fmt.parseInt(i256, text, 10) catch return error.Overflow;
        return checkInteger(number, info);
    }
    const result: Atom = switch (target) {
        .float32, .float64 => blk: {
            try numberGrammar(text, true);
            const number = std.fmt.parseFloat(f64, text) catch return error.InvalidLiteral;
            const rounded: f64 = if (target == .float32) (std.fmt.parseFloat(f32, text) catch return error.InvalidLiteral) else number;
            if (!std.math.isFinite(rounded)) return error.NonFiniteValue;
            break :blk .{ .float = rounded };
        },
        .decimal => |d| blk: {
            const number = try exact(text);
            const coefficient = try rescale(number.coefficient, number.scale, d.scale, .reject);
            if (coefficient <= -pow10(d.precision) or coefficient >= pow10(d.precision)) return error.Overflow;
            break :blk .{ .decimal = @intCast(coefficient) };
        },
        .boolean => if (std.mem.eql(u8, text, "true")) .{ .boolean = true } else if (std.mem.eql(u8, text, "false")) .{ .boolean = false } else return error.InvalidLiteral,
        .utf8, .binary => .{ .bytes = text },
        .date => .{ .date = try parseDate(text) },
        .time => .{ .time = try parseTime(text) },
        .timestamp => |zone| blk: {
            const suffix: usize = if (zone == .utc) 1 else 0;
            if (text.len < 19 + suffix or text[10] != 'T' or (zone == .utc and text[text.len - 1] != 'Z')) return error.InvalidTimestamp;
            const day = try parseDate(text[0..10]);
            const nanos = try parseTime(text[11 .. text.len - suffix]);
            if (nanos % 1000 != 0) return error.Inexact;
            break :blk .{ .timestamp = @as(i64, day) * 86400_000_000 + @as(i64, @intCast(nanos / 1000)) };
        },
        .uuid => blk: {
            if (text.len != 36) return error.InvalidUuid;
            var bytes: [16]u8 = undefined;
            var index: usize = 0;
            var pos: usize = 0;
            while (pos < text.len) {
                if (pos == 8 or pos == 13 or pos == 18 or pos == 23) {
                    if (text[pos] != '-') return error.InvalidUuid;
                    pos += 1;
                    continue;
                }
                const high = std.fmt.charToDigit(text[pos], 16) catch return error.InvalidUuid;
                const low = std.fmt.charToDigit(text[pos + 1], 16) catch return error.InvalidUuid;
                bytes[index] = (high << 4) | low;
                index += 1;
                pos += 2;
            }
            break :blk .{ .uuid = bytes };
        },
        else => return error.UnsupportedLiteralType,
    };
    try validate(result, target);
    return result;
}
fn digits(text: []const u8) !u32 {
    for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidLiteral;
    return std.fmt.parseInt(u32, text, 10) catch error.InvalidLiteral;
}
fn parseDate(text: []const u8) !i32 {
    if (text.len != 10 or text[4] != '-' or text[7] != '-') return error.InvalidDate;
    const year = try digits(text[0..4]);
    const month = try digits(text[5..7]);
    const day = try digits(text[8..10]);
    if (year == 0 or month == 0 or month > 12) return error.InvalidDate;
    const lengths = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    const leap = year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
    const max_day: u32 = lengths[month - 1] + @as(u32, if (month == 2 and leap) 1 else 0);
    if (day == 0 or day > max_day) return error.InvalidDate;
    const y: i32 = @as(i32, @intCast(year)) - @as(i32, if (month <= 2) 1 else 0);
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const m: i32 = @as(i32, @intCast(month)) + @as(i32, if (month > 2) -3 else 9);
    const doy = @divTrunc(153 * m + 2, 5) + @as(i32, @intCast(day)) - 1;
    const doe = yoe * 365 + @divTrunc(yoe, 4) - @divTrunc(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}
fn parseTime(text: []const u8) !u64 {
    if (text.len < 8 or text[2] != ':' or text[5] != ':') return error.InvalidTime;
    const hour = try digits(text[0..2]);
    const minute = try digits(text[3..5]);
    const second = try digits(text[6..8]);
    if (hour >= 24 or minute >= 60 or second >= 60) return error.InvalidTime;
    var fraction: u64 = 0;
    if (text.len > 8) {
        if (text[8] != '.' or text.len < 10 or text.len > 18) return error.InvalidTime;
        fraction = try digits(text[9..]);
        for (text.len - 9..9) |_| fraction *= 10;
    }
    return (@as(u64, hour) * 3600 + @as(u64, minute) * 60 + second) * 1000_000_000 + fraction;
}
pub fn cast(value: Atom, from: Type, to: Type, rounding: Rounding) !Atom {
    try from.validate(.{});
    try to.validate(.{});
    try validate(value, from);
    if (try from.eql(to)) return value;
    if (integer(to)) |info| {
        const number: i256 = switch (value) {
            .signed => |v| v,
            .unsigned => |v| v,
            .decimal => |v| try rescale(v, from.decimal.scale, 0, rounding),
            else => return error.UnsupportedCast,
        };
        return checkInteger(number, info);
    }
    if (to == .decimal) {
        const number: i256 = switch (value) {
            .signed => |v| try rescale(v, 0, to.decimal.scale, rounding),
            .unsigned => |v| try rescale(v, 0, to.decimal.scale, rounding),
            .decimal => |v| try rescale(v, from.decimal.scale, to.decimal.scale, rounding),
            else => return error.UnsupportedCast,
        };
        if (number <= -pow10(to.decimal.precision) or number >= pow10(to.decimal.precision)) return error.Overflow;
        return .{ .decimal = @intCast(number) };
    }
    if (to == .float32 or to == .float64) {
        const initial: f64 = switch (value) {
            .signed => |v| @floatFromInt(v),
            .unsigned => |v| @floatFromInt(v),
            .float => |v| v,
            else => return error.UnsupportedCast,
        };
        if (rounding == .toward_zero) return error.UnsupportedCast;
        const result: f64 = if (to == .float32) switch (value) {
            .signed => |number| @as(f32, @floatFromInt(number)),
            .unsigned => |number| @as(f32, @floatFromInt(number)),
            else => @as(f32, @floatCast(initial)),
        } else initial;
        if (!std.math.isFinite(result)) return error.Overflow;
        if (rounding == .reject) switch (value) {
            // Rounding can reach the first value outside the original integer
            // domain. Check that boundary before converting back at its actual
            // width; LLVM cannot lower float-to-i256 on AArch64.
            .signed => |v| if (result < -0x1p127 or result >= 0x1p127 or @as(i128, @intFromFloat(result)) != v) return error.Inexact,
            .unsigned => |v| if (result < 0 or result >= 0x1p128 or @as(u128, @intFromFloat(result)) != v) return error.Inexact,
            .float => |v| if (result != v) return error.Inexact,
            else => unreachable,
        };
        return .{ .float = result };
    }
    return error.UnsupportedCast;
}
pub fn promote(left: Type, right: Type) !Type {
    try left.validate(.{});
    try right.validate(.{});
    if (try left.eql(right)) return left;
    if (integer(left)) |l| if (integer(right)) |r| {
        if (l.signed == r.signed) return integerType(l.signed, @max(l.bits, r.bits));
        const signed = if (l.signed) l else r;
        const unsigned = if (l.signed) r else l;
        for ([_]u8{ 8, 16, 32, 64, 128 }) |bits| if (bits >= signed.bits and bits > unsigned.bits) return integerType(true, bits);
        return error.NoLosslessPromotion;
    };
    if ((left == .float32 or left == .float64) and (right == .float32 or right == .float64)) return .float64;
    if (left == .decimal and right == .decimal) {
        const scale = @max(left.decimal.scale, right.decimal.scale);
        const whole = @max(left.decimal.precision - left.decimal.scale, right.decimal.precision - right.decimal.scale);
        if (@as(u16, whole) + scale > 38) return error.NoLosslessPromotion;
        return .{ .decimal = .{ .precision = whole + scale, .scale = scale } };
    }
    return error.NoLosslessPromotion;
}
/// CSV inference is conservative about identities and never infers a float.
pub fn inferText(text: []const u8) Type {
    if (text.len == 0) return .utf8;
    if (std.mem.eql(u8, text, "true") or std.mem.eql(u8, text, "false")) return .boolean;
    const offset: usize = if (text[0] == '-') 1 else 0;
    if (offset == text.len or text[0] == '+') return .utf8;
    const body = text[offset..];
    if (!std.ascii.isDigit(body[0]) or (body.len > 1 and body[0] == '0' and body[1] != '.') or std.mem.eql(u8, text, "-0")) return .utf8;
    if (numberGrammar(text, false)) |_| {
        if (bind(text, .int64)) |_| return .int64 else |_| {}
        if (bind(text, .uint64)) |_| return .uint64 else |_| {}
        if (bind(text, .int128)) |_| return .int128 else |_| {}
        if (bind(text, .uint128)) |_| return .uint128 else |_| {}
        return .utf8;
    } else |_| {}
    // An exponent/scale is part of a textual identifier unless an override
    // explicitly requests numeric conversion. JSON has its own typed grammar.
    return .utf8;
}
pub fn unifyText(left: Type, right: Type) Type {
    return promote(left, right) catch .utf8;
}
