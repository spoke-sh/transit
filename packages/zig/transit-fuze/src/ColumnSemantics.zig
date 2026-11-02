//! Persisted interpretation rules (kappa), independent of the logical type and
//! physical codec. No host locale, timezone lookup, clock or I/O is implicit.
const std = @import("std");
const t = @import("Types.zig");
const numeric = @import("DecimalArithmetic.zig");
const timezones = @import("PinnedTimezone.zig");
const spatial_reference = @import("transit_spatial").Reference;
const metrics = @import("VectorMetric.zig");
const Self = @This();
rounding: ?numeric.RoundingMode = null,
metric: ?metrics.Metric = null,
timezone: ?timezones.Descriptor = null,
/// Reserved interpretation of an opaque BINARY payload. This binds metadata;
/// it does not admit a geometry value or an executable spatial operation.
spatial: ?spatial_reference = null,

pub fn empty(self: Self) bool {
    return self.rounding == null and self.metric == null and self.timezone == null and self.spatial == null;
}
pub fn validate(self: Self, logical: t.Type) !void {
    if (self.rounding != null and logical != .decimal) return error.IncompatibleNumericSemantics;
    if (self.metric) |value| {
        if (logical != .vector) return error.IncompatibleVectorMetric;
        try value.validateForElement(logical.vector.element);
    }
    if (self.timezone) |value| {
        if (logical != .timestamp) return error.IncompatibleTimezoneSemantics;
        try value.validate();
    }
    if (self.spatial) |value| {
        if (logical != .binary) return error.IncompatibleSpatialSemantics;
        try value.validate();
    }
}
pub fn requireSpatialExecution(self: Self) !void {
    _ = self;
    return error.UnsupportedSpatialExecution;
}
/// Framed canonical fields also form the schema interpretation fingerprint.
pub fn write(self: Self, out: *std.Io.Writer) !void {
    const flags: u8 = @as(u8, @intFromBool(self.rounding != null)) |
        (@as(u8, @intFromBool(self.metric != null)) << 1) |
        (@as(u8, @intFromBool(self.timezone != null)) << 2) |
        (@as(u8, @intFromBool(self.spatial != null)) << 3);
    try out.writeByte(flags);
    if (self.rounding) |value| try out.writeByte(@backingInt(value));
    if (self.metric) |value| try out.writeByte(@backingInt(value));
    if (self.timezone) |value| {
        try out.writeByte(@intCast(value.version.version_id.len));
        try out.writeAll(value.version.version_id);
        try out.writeAll(&value.version.digest);
        try out.writeByte(@intCast(value.zone.len));
        try out.writeAll(value.zone);
        try out.writeInt(u32, @intCast(value.tzif.len), .little);
        try out.writeAll(value.tzif);
    }
    if (self.spatial) |value| {
        var bytes: [spatial_reference.encoded_bytes]u8 = undefined;
        try out.writeAll(try value.encode(&bytes));
    }
}
fn readEnum(comptime E: type, reader: *std.Io.Reader) !E {
    return std.enums.fromInt(E, try reader.takeByte()) orelse error.InvalidColumnSemantics;
}
pub fn read(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Self {
    const flags = try reader.takeByte();
    if (flags & 0xf0 != 0) return error.InvalidColumnSemantics;
    var result: Self = .{};
    if (flags & 1 != 0) result.rounding = try readEnum(numeric.RoundingMode, reader);
    if (flags & 2 != 0) result.metric = try readEnum(metrics.Metric, reader);
    if (flags & 4 != 0) {
        const version_id = try allocator.dupe(u8, try reader.take(try reader.takeByte()));
        const digest = (try reader.takeArray(32)).*;
        const zone = try allocator.dupe(u8, try reader.take(try reader.takeByte()));
        const size = try reader.takeInt(u32, .little);
        if (size > @import("Timezone.zig").max_zone_bytes) return error.InvalidTimezoneData;
        result.timezone = .{ .version = .{ .version_id = version_id, .digest = digest }, .zone = zone, .tzif = try allocator.dupe(u8, try reader.take(size)) };
    }
    if (flags & 8 != 0) result.spatial = try spatial_reference.decode(try reader.take(spatial_reference.encoded_bytes));
    return result;
}
pub fn eql(left: Self, right: Self) bool {
    if (left.rounding != right.rounding or left.metric != right.metric or !std.meta.eql(left.spatial, right.spatial)) return false;
    if ((left.timezone != null) != (right.timezone != null)) return false;
    if (left.timezone) |a| {
        const b = right.timezone.?;
        return a.version.eql(b.version) and std.mem.eql(u8, a.zone, b.zone) and std.mem.eql(u8, a.tzif, b.tzif);
    }
    return true;
}
/// Neutral TZif uses hexadecimal, so arbitrary artifact bytes cannot be
/// replaced by a text encoding or truncated at NUL by a foreign runtime.
pub const Neutral = struct {
    rounding: ?numeric.RoundingMode,
    metric: ?metrics.Metric,
    timezone: ?struct { version: @import("Timezone.zig").Version, zone: []const u8, tzif_hex: []const u8 },
    spatial: ?struct {
        definition: @import("transit_protocol").Growth.Definition,
        srid: u32,
        local_frame: [16]u8,
        axes: spatial_reference.Axes,
        manifold: spatial_reference.Manifold,
        linear_unit_nm: []const u8,
        vertical_datum: spatial_reference.VerticalDatum,
        precision: spatial_reference.Precision,
    },
};
pub fn foreign(self: Self, allocator: std.mem.Allocator) !Neutral {
    return .{ .rounding = self.rounding, .metric = self.metric, .spatial = if (self.spatial) |value| .{
        .definition = value.definition,
        .srid = value.srid,
        .local_frame = value.local_frame,
        .axes = value.axes,
        .manifold = value.manifold,
        .linear_unit_nm = try std.fmt.allocPrint(allocator, "{d}", .{value.linear_unit_nm}),
        .vertical_datum = value.vertical_datum,
        .precision = value.precision,
    } else null, .timezone = if (self.timezone) |value| .{
        .version = .{ .version_id = try allocator.dupe(u8, value.version.version_id), .digest = value.version.digest },
        .zone = try allocator.dupe(u8, value.zone),
        .tzif_hex = try hex(allocator, value.tzif),
    } else null };
}
fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, bytes.len * 2);
    const alphabet = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        result[2 * i] = alphabet[byte >> 4];
        result[2 * i + 1] = alphabet[byte & 15];
    }
    return result;
}
pub fn native(value: Neutral, allocator: std.mem.Allocator) !Self {
    return .{ .rounding = value.rounding, .metric = value.metric, .spatial = if (value.spatial) |spatial| blk: {
        const text = spatial.linear_unit_nm;
        if (text.len == 0 or text.len > 20 or (text.len > 1 and text[0] == '0')) return error.InvalidSpatialReference;
        for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidSpatialReference;
        const reference: spatial_reference = .{
            .definition = spatial.definition,
            .srid = spatial.srid,
            .local_frame = spatial.local_frame,
            .axes = spatial.axes,
            .manifold = spatial.manifold,
            .linear_unit_nm = std.fmt.parseInt(u64, text, 10) catch return error.InvalidSpatialReference,
            .vertical_datum = spatial.vertical_datum,
            .precision = spatial.precision,
        };
        try reference.validate();
        break :blk reference;
    } else null, .timezone = if (value.timezone) |rules| blk: {
        if (rules.tzif_hex.len % 2 != 0 or rules.tzif_hex.len / 2 > @import("Timezone.zig").max_zone_bytes) return error.InvalidTimezoneData;
        for (rules.tzif_hex) |byte| if (!std.ascii.isDigit(byte) and (byte < 'a' or byte > 'f')) return error.InvalidTimezoneData;
        const bytes = try allocator.alloc(u8, rules.tzif_hex.len / 2);
        _ = std.fmt.hexToBytes(bytes, rules.tzif_hex) catch return error.InvalidTimezoneData;
        break :blk .{ .version = .{ .version_id = try allocator.dupe(u8, rules.version.version_id), .digest = rules.version.digest }, .zone = try allocator.dupe(u8, rules.zone), .tzif = bytes };
    } else null };
}

test "column semantics retain actual timezone rules and separate shape from metrics and codecs" {
    const e = std.testing;
    const schema_owner = @import("TableSchema.zig");
    const rules = try timezones.Descriptor.init("iana-2025b", "America/New_York", @embedFile("timezone-fixtures/new-york.tzif"));
    const schema: schema_owner.Schema = .{ .object = 1, .revision = 1, .next_column = 5, .columns = &.{
        .{ .id = 1, .name = "amount", .type = .{ .decimal = .{ .precision = 8, .scale = 2 } }, .semantics = .{ .rounding = .half_even } },
        .{ .id = 2, .name = "embedding", .type = .{ .vector = .{ .dimensions = 2, .element = .float16 } }, .semantics = .{ .metric = .cosine } },
        .{ .id = 3, .name = "time", .type = .{ .timestamp = .utc }, .semantics = .{ .timezone = rules } },
        .{ .id = 4, .name = "opaque", .type = .binary, .semantics = .{ .spatial = .{ .definition = @import("transit_protocol").Growth.current_definition, .srid = 0, .local_frame = @splat(7), .axes = .xy, .manifold = .planar, .linear_unit_nm = std.math.maxInt(u64), .vertical_datum = .none, .precision = .exact } } },
    } };
    var owned = try schema.clone(e.allocator);
    defer owned.deinit();
    for (schema.columns, owned.schema.columns) |input, output| try e.expect(input.semantics.eql(output.semantics));
    const bytes = try @import("TableSchemaJson.zig").encode(e.allocator, schema);
    defer e.allocator.free(bytes);
    var decoded = try @import("TableSchemaJson.zig").decode(e.allocator, bytes);
    defer decoded.deinit();
    try e.expectEqual(try schema.fingerprint(), try decoded.schema.fingerprint());
    const loaded = try decoded.schema.columns[2].semantics.timezone.?.load();
    try e.expectError(error.NonexistentLocalTime, loaded.localToUtc(1741487400_000_000, .reject));
    try e.expectError(error.AmbiguousLocalTime, loaded.localToUtc(1762047000_000_000, .reject));
    try e.expectError(error.UnsupportedSpatialExecution, decoded.schema.columns[3].semantics.requireSpatialExecution());
    var columns: [schema_owner.max_columns]schema_owner.Column = undefined;
    const transition = try @import("TableEvolution.zig").apply(schema, .{ .physical = .{ .column = 2, .semantics = .{ .metric = .l2_squared } } }, &columns);
    try e.expectEqual(.rewrite_rows, transition.work);
    try e.expect(!try transition.canProject());
    try e.expect(!std.mem.eql(u8, &try schema.layoutFingerprint(), &try transition.after.layoutFingerprint()));
    try e.expectError(error.IncompatibleVectorMetric, (Self{ .metric = .hamming }).validate(schema.columns[1].type));
    try e.expectError(error.IncompatibleNumericSemantics, (Self{ .rounding = .reject }).validate(.int64));
    var corrupt = rules;
    corrupt.version.digest[0] ^= 1;
    try e.expectError(error.TimezoneDefinitionMismatch, (Self{ .timezone = corrupt }).validate(.{ .timestamp = .utc }));
}

test "column semantics SQL declarations share typed validation and preserve added descriptors" {
    const e = std.testing;
    const ddl = @import("TableDdl.zig");
    var compiled = try ddl.compile(e.allocator, "CREATE TABLE rules (n DECIMAL(8,2) ROUNDING HALF_EVEN, v VECTOR(3,FLOAT32) METRIC COSINE)", null, null);
    defer compiled.deinit();
    const schema = try compiled.statement.create.bind(1);
    try e.expectEqual(numeric.RoundingMode.half_even, schema.columns[0].semantics.rounding.?);
    try e.expectEqual(metrics.Metric.cosine, schema.columns[1].semantics.metric.?);
    try e.expectError(error.IncompatibleVectorMetric, ddl.compile(e.allocator, "CREATE TABLE bad (v VECTOR(3,FLOAT32) METRIC HAMMING)", null, null));
    try e.expectError(error.InvalidColumnSemantics, ddl.compile(e.allocator, "CREATE TABLE bad (ts TIMESTAMPTZ TIMEZONE NULL TZDB 'x' TZIF X'00')", null, null));
    const utc = @embedFile("timezone-fixtures/utc.tzif");
    const encoded = std.fmt.bytesToHex(utc, .lower);
    const sql = try std.fmt.allocPrint(e.allocator, "ALTER TABLE rules ADD ts TIMESTAMPTZ TIMEZONE 'Etc/UTC' TZDB 'iana-2025b' TZIF X'{s}'", .{encoded});
    defer e.allocator.free(sql);
    var altered = try ddl.compile(e.allocator, sql, schema, null);
    defer altered.deinit();
    var columns: [@import("TableSchema.zig").max_columns]@import("TableSchema.zig").Column = undefined;
    const transition = try @import("TableEvolution.zig").apply(schema, altered.statement.alter.action.columns, &columns);
    try e.expect(try transition.canProject());
    try e.expectEqualSlices(u8, utc, transition.after.columns[2].semantics.timezone.?.tzif);
}

test "spatial column metadata uses the canonical reference owner and refuses foreign interpretation" {
    const e = std.testing;
    const reference: spatial_reference = .{ .definition = @import("transit_protocol").Growth.current_definition, .srid = 4326, .local_frame = @splat(0), .axes = .longitude_latitude, .manifold = .wgs84_ellipsoid, .linear_unit_nm = 0, .vertical_datum = .none, .precision = .exact };
    const semantics: Self = .{ .spatial = reference };
    try semantics.validate(.binary);
    try e.expectError(error.IncompatibleSpatialSemantics, semantics.validate(.utf8));
    var bytes: [1 + spatial_reference.encoded_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try semantics.write(&writer);
    var expected: [spatial_reference.encoded_bytes]u8 = undefined;
    try e.expectEqualSlices(u8, try reference.encode(&expected), bytes[1..]);
    try e.expectEqual(@as(u8, 8), bytes[0]);
    var reader: std.Io.Reader = .fixed(&bytes);
    try e.expect(semantics.eql(try read(e.allocator, &reader)));
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    var neutral = try semantics.foreign(arena.allocator());
    try e.expectEqualStrings("0", neutral.spatial.?.linear_unit_nm);
    try e.expect(semantics.eql(try native(neutral, arena.allocator())));
    neutral.spatial.?.linear_unit_nm = "00";
    try e.expectError(error.InvalidSpatialReference, native(neutral, arena.allocator()));
    bytes[5] ^= 1; // The nested SPR1 definition, before any CRS interpretation.
    reader = .fixed(&bytes);
    try e.expectError(error.IncompatibleDefinition, read(e.allocator, &reader));
    try e.expectError(error.UnsupportedSpatialExecution, semantics.requireSpatialExecution());
}
