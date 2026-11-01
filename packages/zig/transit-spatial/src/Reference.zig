//! Spatial reference semantics, independent of logical shape and physical codec.
//! New offline descriptor family; no SQL, stored Table or index admission.
const std = @import("std");
const p = @import("transit_protocol");
const Self = @This();

pub const encoded_bytes = 72;
pub const Axes = enum(u8) { xy = 1, xyz = 2, longitude_latitude = 3, longitude_latitude_height = 4 };
pub const Manifold = enum(u8) { planar = 1, wgs84_ellipsoid = 2 };
pub const VerticalDatum = enum(u8) { none = 0, local = 1, wgs84_ellipsoid = 2 };
pub const Precision = union(enum) { exact: void, binary_grid: i16 };

// Every field is explicit. In particular, decoding cannot default a definition,
// CRS, unit, dimension, grid or vertical datum from a newer build.
definition: p.Growth.Definition,
srid: u32,
/// Nonzero stable identity for a local engineering frame; zero for built-in CRS.
/// Caller-owned identity, not a catalog object, permission or transform.
local_frame: [16]u8,
axes: Axes,
manifold: Manifold,
/// Planar axes, or the height axis of 4979. Angular axes are degrees.
/// Zero only for the two-dimensional angular 4326 profile.
linear_unit_nm: u64,
vertical_datum: VerticalDatum,
precision: Precision,

pub fn dimensions(self: Self) u8 {
    return switch (self.axes) {
        .xy, .longitude_latitude => 2,
        .xyz, .longitude_latitude_height => 3,
    };
}

pub fn validate(self: Self) !void {
    if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    switch (self.precision) {
        .exact => {},
        .binary_grid => |exponent| if (exponent < -100 or exponent > 100) return error.InvalidSpatialPrecision,
    }
    const has_local_frame = !std.mem.allEqual(u8, &self.local_frame, 0);
    switch (self.srid) {
        0 => {
            if (!has_local_frame) return error.InvalidSpatialFrame;
            if (self.manifold != .planar or self.linear_unit_nm == 0) return error.InvalidSpatialReference;
            if (self.axes == .xy and self.vertical_datum == .none) return;
            if (self.axes == .xyz and self.vertical_datum == .local) return;
            return error.InvalidSpatialReference;
        },
        3857 => {
            if (self.manifold != .planar or self.axes != .xy or self.linear_unit_nm != 1_000_000_000 or self.vertical_datum != .none) return error.InvalidSpatialReference;
        },
        4326 => {
            if (self.manifold != .wgs84_ellipsoid or self.axes != .longitude_latitude or self.linear_unit_nm != 0 or self.vertical_datum != .none or self.precision != .exact) return error.InvalidSpatialReference;
        },
        4979 => {
            if (self.manifold != .wgs84_ellipsoid or self.axes != .longitude_latitude_height or self.linear_unit_nm != 1_000_000_000 or self.vertical_datum != .wgs84_ellipsoid or self.precision != .exact) return error.InvalidSpatialReference;
        },
        else => return error.UnsupportedSpatialReference,
    }
    if (has_local_frame) return error.InvalidSpatialFrame;
}

/// Binary predicates require identical interpretation. No implicit transform.
pub fn requireSame(self: Self, other: Self) !void {
    try self.validate();
    try other.validate();
    if (!std.meta.eql(self, other)) return error.SpatialReferenceMismatch;
}

pub fn requirePlanar(self: Self, dimension: u8) !void {
    try self.validate();
    if (self.manifold != .planar or self.dimensions() != dimension) return error.UnsupportedSpatialOperation;
}

/// Canonical SPR1 envelope. Validate and size-check before touching output.
pub fn encode(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    if (output.len < encoded_bytes) return error.SpatialOutputTooSmall;
    const bytes = output[0..encoded_bytes];
    @memcpy(bytes[0..4], "SPR1");
    @memcpy(bytes[4..36], &p.Growth.definition_bytes);
    std.mem.writeInt(u32, bytes[36..40], self.srid, .little);
    bytes[40] = @backingInt(self.axes);
    bytes[41] = @backingInt(self.manifold);
    bytes[42] = @backingInt(self.vertical_datum);
    bytes[43] = if (self.precision == .exact) 0 else 1;
    std.mem.writeInt(u64, bytes[44..52], self.linear_unit_nm, .little);
    std.mem.writeInt(i16, bytes[52..54], if (self.precision == .binary_grid) self.precision.binary_grid else 0, .little);
    @memset(bytes[54..56], 0);
    @memcpy(bytes[56..72], &self.local_frame);
    return bytes;
}

pub fn decode(bytes: []const u8) !Self {
    if (bytes.len != encoded_bytes or !std.mem.eql(u8, bytes[0..4], "SPR1")) return error.InvalidSpatialEncoding;
    if (!std.mem.eql(u8, bytes[4..36], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    if (!std.mem.allEqual(u8, bytes[54..56], 0)) return error.InvalidSpatialEncoding;
    const exponent = std.mem.readInt(i16, bytes[52..54], .little);
    const precision: Precision = switch (bytes[43]) {
        0 => if (exponent == 0) .exact else return error.InvalidSpatialEncoding,
        1 => .{ .binary_grid = exponent },
        else => return error.InvalidSpatialEncoding,
    };
    const result: Self = .{
        .definition = p.Growth.current_definition, // explicit byte equality above
        .srid = std.mem.readInt(u32, bytes[36..40], .little),
        .local_frame = bytes[56..72].*,
        .axes = std.enums.fromInt(Axes, bytes[40]) orelse return error.InvalidSpatialEncoding,
        .manifold = std.enums.fromInt(Manifold, bytes[41]) orelse return error.InvalidSpatialEncoding,
        .vertical_datum = std.enums.fromInt(VerticalDatum, bytes[42]) orelse return error.InvalidSpatialEncoding,
        .linear_unit_nm = std.mem.readInt(u64, bytes[44..52], .little),
        .precision = precision,
    };
    try result.validate();
    return result;
}

pub fn fingerprint(self: Self) ![32]u8 {
    var bytes: [encoded_bytes]u8 = undefined;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.spatial.reference.v1\x00");
    hash.update(try self.encode(&bytes));
    return hash.finalResult();
}

test "spatial references preserve explicit local units and reject mismatched descriptors" {
    const local: Self = .{ .definition = p.Growth.current_definition, .srid = 0, .local_frame = @splat(1), .axes = .xy, .manifold = .planar, .linear_unit_nm = 1_000_000_000, .vertical_datum = .none, .precision = .exact };
    var bytes: [encoded_bytes]u8 = undefined;
    try std.testing.expectEqualDeep(local, try decode(try local.encode(&bytes)));
    var changed = local;
    changed.linear_unit_nm = 1_000_000;
    try std.testing.expectError(error.SpatialReferenceMismatch, local.requireSame(changed));
    try std.testing.expect(!std.mem.eql(u8, &try local.fingerprint(), &try changed.fingerprint()));
    changed.linear_unit_nm = 0;
    try std.testing.expectError(error.InvalidSpatialReference, changed.validate());
    changed = local;
    changed.srid = 9999;
    try std.testing.expectError(error.UnsupportedSpatialReference, changed.validate());
    changed = local;
    changed.precision = .{ .binary_grid = -101 };
    try std.testing.expectError(error.InvalidSpatialPrecision, changed.validate());
    changed = local;
    changed.local_frame = @splat(2);
    try std.testing.expectError(error.SpatialReferenceMismatch, local.requireSame(changed));
    try std.testing.expect(!std.mem.eql(u8, &try local.fingerprint(), &try changed.fingerprint()));
    changed.local_frame = @splat(0);
    try std.testing.expectError(error.InvalidSpatialFrame, changed.validate());
}

test "spatial envelopes reject foreign definitions truncation and noncanonical fields" {
    const local: Self = .{ .definition = p.Growth.current_definition, .srid = 0, .local_frame = @splat(1), .axes = .xyz, .manifold = .planar, .linear_unit_nm = 1, .vertical_datum = .local, .precision = .{ .binary_grid = -10 } };
    var bytes: [encoded_bytes]u8 = undefined;
    _ = try local.encode(&bytes);
    for (0..encoded_bytes) |length| try std.testing.expectError(error.InvalidSpatialEncoding, decode(bytes[0..length]));
    var changed = bytes;
    changed[4] ^= 1;
    try std.testing.expectError(error.IncompatibleDefinition, decode(&changed));
    for ([_]usize{ 40, 41, 42, 43, 54 }) |offset| {
        changed = bytes;
        changed[offset] = 255;
        try std.testing.expectError(error.InvalidSpatialEncoding, decode(&changed));
    }
    changed = bytes;
    changed[43] = 0;
    try std.testing.expectError(error.InvalidSpatialEncoding, decode(&changed));
    changed = bytes;
    @memset(changed[56..72], 0);
    try std.testing.expectError(error.InvalidSpatialFrame, decode(&changed));
    var short: [encoded_bytes - 1]u8 = @splat(0xa5);
    try std.testing.expectError(error.SpatialOutputTooSmall, local.encode(&short));
    try std.testing.expect(std.mem.allEqual(u8, &short, 0xa5));
}

test "spatial registry separates ellipsoidal height and planar evaluation" {
    const geographic: Self = .{ .definition = p.Growth.current_definition, .srid = 4979, .local_frame = @splat(0), .axes = .longitude_latitude_height, .manifold = .wgs84_ellipsoid, .linear_unit_nm = 1_000_000_000, .vertical_datum = .wgs84_ellipsoid, .precision = .exact };
    try geographic.validate();
    try std.testing.expectError(error.UnsupportedSpatialOperation, geographic.requirePlanar(3));
    var bad = geographic;
    bad.vertical_datum = .local;
    try std.testing.expectError(error.InvalidSpatialReference, bad.validate());
    bad = geographic;
    bad.precision = .{ .binary_grid = 0 };
    try std.testing.expectError(error.InvalidSpatialReference, bad.validate());
    bad = geographic;
    bad.local_frame = @splat(1);
    try std.testing.expectError(error.InvalidSpatialFrame, bad.validate());
}
