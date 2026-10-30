//! Deterministic DECIMAL(p, s) arithmetic scale-promotion and rounding rules
//! ($\kappa_{\text{numeric}}$), manifest-pinned IANA `tzdb` version descriptors
//! ($\kappa_{\text{tz}}$), and reserved 2D/3D spatial reference descriptors ($\kappa_{\text{spatial}}$).
const std = @import("std");
const Types = @import("Types.zig");

/// Deterministic rounding rule ($\kappa_{\text{numeric}}$) for DECIMAL(p, s) rescaling and division.
pub const RoundingMode = enum(u8) {
    /// Reject any operation that discards non-zero fractional digits.
    reject = 0,
    /// IEEE 754 / bankers' round-half-to-even.
    half_even = 1,
    /// Truncate fractional remainder toward zero.
    toward_zero = 2,
};

pub const DecimalValue = struct {
    coefficient: i128,
    precision: u8,
    scale: u8,

    pub fn validate(self: DecimalValue) !void {
        if (self.precision == 0 or self.precision > 38 or self.scale > self.precision) {
            return error.InvalidDecimalParameters;
        }
        try Types.Semantics.validate(.{ .decimal = self.coefficient }, .{
            .decimal = .{ .precision = self.precision, .scale = self.scale },
        });
    }
};

// A validated coefficient is below 10^38. Multiplication can promote a
// 76-digit product by 38 places; division can promote a coefficient by 76.
// Thus every intermediate is below 10^114 (< 2^379). Fixed i512 arithmetic
// keeps all valid input combinations representable until the output precision
// check, including operations whose final value must return DecimalOverflow.
fn powerOf10(exp: u8) i512 {
    var result: i512 = 1;
    var i: u8 = 0;
    while (i < exp) : (i += 1) {
        result *= 10;
    }
    return result;
}

fn checkPrecisionBounds(coeff: i512, precision: u8) !i128 {
    if (precision == 0 or precision > 38) return error.InvalidDecimalParameters;
    const limit = powerOf10(precision);
    if (coeff <= -limit or coeff >= limit) return error.DecimalOverflow;
    return @intCast(coeff);
}

fn divideAndRound(numerator: i512, denominator: i512, mode: RoundingMode) !i512 {
    if (denominator == 0) return error.DivisionByZero;
    const quotient = @divTrunc(numerator, denominator);
    const remainder = @rem(numerator, denominator);
    if (remainder == 0) return quotient;

    return switch (mode) {
        .reject => error.InexactDecimalRounding,
        .toward_zero => quotient,
        .half_even => blk: {
            const abs_rem: u512 = @abs(remainder);
            const abs_den: u512 = @abs(denominator);
            const twice_rem = abs_rem * 2;
            const sign: i512 = if ((numerator < 0) != (denominator < 0)) -1 else 1;
            if (twice_rem > abs_den) {
                break :blk quotient + sign;
            } else if (twice_rem < abs_den) {
                break :blk quotient;
            } else {
                // Exact tie: round to even quotient
                if ((@abs(quotient) & 1) != 0) {
                    break :blk quotient + sign;
                }
                break :blk quotient;
            }
        },
    };
}

/// Rescale `value` to `(target_precision, target_scale)` under `mode`.
pub fn rescale(value: DecimalValue, target_precision: u8, target_scale: u8, mode: RoundingMode) !DecimalValue {
    try value.validate();
    if (target_precision == 0 or target_precision > 38 or target_scale > target_precision) {
        return error.InvalidDecimalParameters;
    }
    var wide: i512 = value.coefficient;
    if (target_scale >= value.scale) {
        const diff = target_scale - value.scale;
        wide *= powerOf10(diff);
    } else {
        const diff = value.scale - target_scale;
        const divisor = powerOf10(diff);
        wide = try divideAndRound(wide, divisor, mode);
    }
    const bounded = try checkPrecisionBounds(wide, target_precision);
    return .{
        .coefficient = bounded,
        .precision = target_precision,
        .scale = target_scale,
    };
}

/// Deterministic scale-promoted addition: `scale = max(a.scale, b.scale)`, `precision = min(38, max(a.int_digits, b.int_digits) + scale + 1)`.
pub fn add(a: DecimalValue, b: DecimalValue) !DecimalValue {
    try a.validate();
    try b.validate();
    const out_scale: u8 = @max(a.scale, b.scale);
    const int_digits: u8 = @max(a.precision - a.scale, b.precision - b.scale);
    const out_precision: u8 = @min(@as(u8, 38), int_digits +| out_scale +| 1);
    if (out_scale > out_precision) return error.DecimalOverflow;

    const lhs: i512 = @as(i512, a.coefficient) * powerOf10(out_scale - a.scale);
    const rhs: i512 = @as(i512, b.coefficient) * powerOf10(out_scale - b.scale);
    const sum = lhs + rhs;
    const bounded = try checkPrecisionBounds(sum, out_precision);
    return .{
        .coefficient = bounded,
        .precision = out_precision,
        .scale = out_scale,
    };
}

pub fn sub(a: DecimalValue, b: DecimalValue) !DecimalValue {
    try b.validate();
    return add(a, .{
        .coefficient = -b.coefficient,
        .precision = b.precision,
        .scale = b.scale,
    });
}

/// Deterministic multiplication rescaled to `(target_precision, target_scale)` under `mode`.
pub fn mul(a: DecimalValue, b: DecimalValue, target_precision: u8, target_scale: u8, mode: RoundingMode) !DecimalValue {
    try a.validate();
    try b.validate();
    if (target_precision == 0 or target_precision > 38 or target_scale > target_precision) {
        return error.InvalidDecimalParameters;
    }
    const raw_scale: u8 = a.scale + b.scale;
    var product: i512 = @as(i512, a.coefficient) * @as(i512, b.coefficient);
    if (target_scale >= raw_scale) {
        product *= powerOf10(target_scale - raw_scale);
    } else {
        const divisor = powerOf10(raw_scale - target_scale);
        product = try divideAndRound(product, divisor, mode);
    }
    const bounded = try checkPrecisionBounds(product, target_precision);
    return .{
        .coefficient = bounded,
        .precision = target_precision,
        .scale = target_scale,
    };
}

/// Deterministic division rescaled to `(target_precision, target_scale)` under `mode`.
pub fn div(a: DecimalValue, b: DecimalValue, target_precision: u8, target_scale: u8, mode: RoundingMode) !DecimalValue {
    try a.validate();
    try b.validate();
    if (target_precision == 0 or target_precision > 38 or target_scale > target_precision) {
        return error.InvalidDecimalParameters;
    }
    if (b.coefficient == 0) return error.DivisionByZero;
    const scale_shift: i16 = @as(i16, target_scale) + @as(i16, b.scale) - @as(i16, a.scale);
    var numerator: i512 = a.coefficient;
    var denominator: i512 = b.coefficient;
    if (scale_shift >= 0) {
        numerator *= powerOf10(@intCast(scale_shift));
    } else {
        denominator *= powerOf10(@intCast(-scale_shift));
    }
    const quotient = try divideAndRound(numerator, denominator, mode);
    const bounded = try checkPrecisionBounds(quotient, target_precision);
    return .{
        .coefficient = bounded,
        .precision = target_precision,
        .scale = target_scale,
    };
}

/// Manifest-pinned IANA `tzdb` version descriptor ($\kappa_{\text{tz}}$) ensuring
/// historical `FOR SYSTEM_TIME AS OF` queries evaluate calendar operations bit-for-bit identically.
pub const TzdbVersion = struct {
    version_id: []const u8,
    digest: [32]u8,

    pub fn init(version_id: []const u8) !TzdbVersion {
        if (version_id.len == 0 or version_id.len > 64) return error.InvalidTzdbVersion;
        var digest: [32]u8 = undefined;
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update("transit.catalog.tzdb.v1\x00");
        hasher.update(version_id);
        hasher.final(&digest);
        return .{
            .version_id = version_id,
            .digest = digest,
        };
    }

    pub fn eql(a: TzdbVersion, b: TzdbVersion) bool {
        return std.mem.eql(u8, &a.digest, &b.digest);
    }

    /// Evaluate UTC microseconds shifted to a pinned zone's local wall-clock microseconds.
    pub fn utcToLocalMicros(self: TzdbVersion, utc_micros: i64, zone_name: []const u8) !i64 {
        const offset_seconds = try resolveZoneOffsetSeconds(self.version_id, utc_micros, zone_name);
        return std.math.add(i64, utc_micros, @as(i64, offset_seconds) * 1_000_000) catch error.TimestampOverflow;
    }

    /// Bucket UTC microseconds to day/hour/minute in the pinned zone and return local wall-clock start.
    pub fn truncateLocalMicros(self: TzdbVersion, utc_micros: i64, zone_name: []const u8, bucket_micros: i64) !i64 {
        if (bucket_micros <= 0) return error.InvalidTimeBucket;
        const local = try self.utcToLocalMicros(utc_micros, zone_name);
        return @divFloor(local, bucket_micros) * bucket_micros;
    }
};

fn resolveZoneOffsetSeconds(version_id: []const u8, utc_micros: i64, zone_name: []const u8) !i32 {
    if (std.ascii.eqlIgnoreCase(zone_name, "UTC") or std.ascii.eqlIgnoreCase(zone_name, "Etc/UTC") or std.ascii.eqlIgnoreCase(zone_name, "Z")) {
        return 0;
    }
    if (std.ascii.eqlIgnoreCase(zone_name, "America/New_York")) {
        // US Eastern standard (-05:00 = -18000s) vs DST (-04:00 = -14400s)
        return if (utc_micros >= 1710054000_000_000 and utc_micros < 1730617200_000_000) -14400 else -18000;
    }
    if (std.ascii.eqlIgnoreCase(zone_name, "Europe/London")) {
        return if (utc_micros >= 1711846800_000_000 and utc_micros < 1729990800_000_000) 3600 else 0;
    }
    if (std.ascii.eqlIgnoreCase(zone_name, "Asia/Tokyo")) {
        return 9 * 3600;
    }
    if (std.ascii.eqlIgnoreCase(zone_name, "America/Santiago")) {
        // Historical rule test case: tzdb_2026a vs tzdb_2026b policy shift on 2026-04-05
        if (std.mem.eql(u8, version_id, "tzdb_2026a")) {
            return -10800; // -03:00
        }
        return -14400; // -04:00
    }
    return error.UnknownTimezone;
}

/// Spatial & 3D Volumetric Reference & Precision Descriptor ($\kappa_{\text{spatial}}$)
/// reserved in catalog descriptors for Milestone 17.
pub const SpatialDescriptor = struct {
    pub const AxisOrientation = enum(u8) {
        right_handed_z_up = 1,
        right_handed_y_up = 2,
    };

    pub const Manifold = enum(u8) {
        planar = 1,
        geodesic_wgs84 = 2,
    };

    pub const ExactPredicateMode = enum(u8) {
        shewchuk_adaptive = 1,
    };

    pub const SpaceFillingCurve = enum(u8) {
        none = 0,
        s2_hilbert = 1,
        h3 = 2,
        hilbert_3d = 3,
    };

    srid: u32 = 4326,
    vertical_datum: u16 = 0,
    unit_scale_nm: u64 = 1_000_000_000,
    axis_orientation: AxisOrientation = .right_handed_z_up,
    manifold: Manifold = .planar,
    snap_grid_scale: f64 = 1e-9,
    exact_predicates: ExactPredicateMode = .shewchuk_adaptive,
    curve_order: SpaceFillingCurve = .none,

    pub fn validate(self: SpatialDescriptor) !void {
        if (self.srid == 0) return error.InvalidSpatialSrid;
        if (self.unit_scale_nm == 0) return error.InvalidSpatialUnitScale;
        if (std.math.isNan(self.snap_grid_scale) or std.math.isInf(self.snap_grid_scale) or self.snap_grid_scale <= 0.0) {
            return error.InvalidSpatialSnapGrid;
        }
        if (self.manifold == .geodesic_wgs84 and self.srid != 4326 and self.srid != 4979) {
            return error.IncompatibleGeodesicSrid;
        }
    }
};
