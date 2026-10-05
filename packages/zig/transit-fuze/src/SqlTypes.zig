//! Selected SQL scalar spellings and parameters. Resolving a name does not
//! extend the execution/storage admission of a SQL surface.
const std = @import("std");
const t = @import("Types.zig");
pub const Zone = enum { unspecified, without, with };
pub const Resolved = struct { type: t.Type, max_characters: ?u32 = null };
pub const Alias = struct { name: []const u8, type: t.Type };
pub const aliases = [_]Alias{
    .{ .name = "INT8", .type = .int8 },
    .{ .name = "TINYINT", .type = .int8 },
    .{ .name = "INT16", .type = .int16 },
    .{ .name = "SMALLINT", .type = .int16 },
    .{ .name = "INT32", .type = .int32 },
    .{ .name = "INT", .type = .int32 },
    .{ .name = "INTEGER", .type = .int32 },
    .{ .name = "INT64", .type = .int64 },
    .{ .name = "BIGINT", .type = .int64 },
    .{ .name = "INT128", .type = .int128 },
    .{ .name = "UINT8", .type = .uint8 },
    .{ .name = "UINT16", .type = .uint16 },
    .{ .name = "UINT32", .type = .uint32 },
    .{ .name = "UINT64", .type = .uint64 },
    .{ .name = "UINT128", .type = .uint128 },
    .{ .name = "FLOAT32", .type = .float32 },
    .{ .name = "REAL", .type = .float32 },
    .{ .name = "FLOAT64", .type = .float64 },
    .{ .name = "DOUBLE", .type = .float64 },
    .{ .name = "DOUBLE PRECISION", .type = .float64 },
    .{ .name = "FLOAT", .type = .float64 },
    .{ .name = "BOOLEAN", .type = .boolean },
    .{ .name = "BOOL", .type = .boolean },
    .{ .name = "UTF8", .type = .utf8 },
    .{ .name = "TEXT", .type = .utf8 },
    .{ .name = "VARCHAR", .type = .utf8 },
    .{ .name = "CHARACTER VARYING", .type = .utf8 },
    .{ .name = "BINARY", .type = .binary },
    .{ .name = "BLOB", .type = .binary },
    .{ .name = "BYTEA", .type = .binary },
    .{ .name = "DATE", .type = .date },
    .{ .name = "TIME", .type = .time },
    .{ .name = "TIMESTAMP", .type = .{ .timestamp = .civil } },
    .{ .name = "TIMESTAMPTZ", .type = .{ .timestamp = .utc } },
    .{ .name = "INTERVAL", .type = .interval },
    .{ .name = "UUID", .type = .uuid },
    .{ .name = "JSON", .type = .json },
};
fn is(name: []const u8, expected: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, expected);
}
pub fn resolve(name: []const u8, parameters: []const u32, zone: Zone) !Resolved {
    if (is(name, "DECIMAL") or is(name, "NUMERIC")) {
        if (zone != .unspecified) return error.UnsupportedTimeZoneType;
        if (parameters.len > 2) return error.InvalidTypeParameters;
        const precision = if (parameters.len == 0) 38 else parameters[0];
        const scale = if (parameters.len < 2) 0 else parameters[1];
        if (precision == 0 or precision > 38 or scale > precision) return error.InvalidDecimal;
        return .{ .type = .{ .decimal = .{ .precision = @intCast(precision), .scale = @intCast(scale) } } };
    }
    if (is(name, "CHAR") or is(name, "CHARACTER")) return error.UnsupportedCharacterPadding;
    if (is(name, "VARBINARY")) return error.UnsupportedBinaryLength;
    for (aliases) |alias| if (is(name, alias.name)) {
        var result: Resolved = .{ .type = alias.type };
        if (is(name, "VARCHAR") or is(name, "CHARACTER VARYING")) {
            if (parameters.len > 1) return error.InvalidTypeParameters;
            if (parameters.len == 1) {
                if (parameters[0] == 0) return error.InvalidCharacterLimit;
                result.max_characters = parameters[0];
            }
        } else if (result.type == .time or result.type == .timestamp) {
            if (parameters.len > 1) return error.InvalidTypeParameters;
            if (parameters.len == 1 and parameters[0] != @as(u32, if (result.type == .time) 9 else 6)) return error.UnsupportedTemporalPrecision;
        } else if (parameters.len != 0) {
            if (result.type == .binary) return error.UnsupportedBinaryLength;
            if (is(name, "FLOAT")) return error.UnsupportedFloatPrecision;
            return error.InvalidTypeParameters;
        }
        if (zone != .unspecified) {
            if (result.type == .timestamp) {
                if (is(name, "TIMESTAMPTZ") and zone == .without) return error.ConflictingTimeZone;
                result.type = .{ .timestamp = if (zone == .with) .utc else .civil };
            } else if (result.type != .time or zone == .with) return error.UnsupportedTimeZoneType;
        }
        return result;
    };
    return error.UnknownSqlType;
}

test "SQL aliases normalize descriptors and preserve Transit bit-width names" {
    const e = std.testing;
    for (aliases) |alias| {
        const result = try resolve(alias.name, &.{}, .unspecified);
        try e.expect(try result.type.eql(alias.type));
        var lower: [32]u8 = undefined;
        for (alias.name, 0..) |byte, i| lower[i] = std.ascii.toLower(byte);
        try e.expect(try (try resolve(lower[0..alias.name.len], &.{}, .unspecified)).type.eql(alias.type));
    }
    try e.expectEqual(t.Tag.int8, (try resolve("int8", &.{}, .unspecified)).type.tag());
    try e.expectEqual(t.Tag.int32, (try resolve("INTEGER", &.{}, .unspecified)).type.tag());
    try e.expectEqual(t.Tag.int64, (try resolve("BIGINT", &.{}, .unspecified)).type.tag());
    try e.expect(try (try resolve("DOUBLE PRECISION", &.{}, .unspecified)).type.eql((try resolve("FLOAT64", &.{}, .unspecified)).type));
}
test "SQL type parameters are meaningful and unsupported dialect semantics reject" {
    const e = std.testing;
    try e.expectEqual(@as(?u32, 200), (try resolve("VARCHAR", &.{200}, .unspecified)).max_characters);
    try e.expectEqual(@as(?u32, null), (try resolve("VARCHAR", &.{}, .unspecified)).max_characters);
    try e.expectEqualDeep((t.Type{ .decimal = .{ .precision = 38, .scale = 0 } }), (try resolve("DECIMAL", &.{}, .unspecified)).type);
    try e.expectEqualDeep((t.Type{ .decimal = .{ .precision = 18, .scale = 2 } }), (try resolve("NUMERIC", &.{ 18, 2 }, .unspecified)).type);
    try e.expectEqualDeep((t.Type{ .timestamp = .utc }), (try resolve("TIMESTAMP", &.{6}, .with)).type);
    try e.expectEqualDeep(t.Type.time, (try resolve("TIME", &.{9}, .without)).type);
    try e.expectError(error.InvalidCharacterLimit, resolve("VARCHAR", &.{0}, .unspecified));
    try e.expectError(error.InvalidTypeParameters, resolve("INTEGER", &.{8}, .unspecified));
    try e.expectError(error.InvalidDecimal, resolve("DECIMAL", &.{ 38, 39 }, .unspecified));
    try e.expectError(error.UnsupportedTemporalPrecision, resolve("TIME", &.{6}, .unspecified));
    try e.expectError(error.UnsupportedTemporalPrecision, resolve("TIMESTAMP", &.{9}, .unspecified));
    try e.expectError(error.UnsupportedTimeZoneType, resolve("TIME", &.{}, .with));
    try e.expectError(error.ConflictingTimeZone, resolve("TIMESTAMPTZ", &.{}, .without));
    try e.expectError(error.UnsupportedFloatPrecision, resolve("FLOAT", &.{24}, .unspecified));
    try e.expectError(error.UnsupportedBinaryLength, resolve("BINARY", &.{16}, .unspecified));
    try e.expectError(error.UnsupportedCharacterPadding, resolve("CHAR", &.{10}, .unspecified));
    try e.expectError(error.UnknownSqlType, resolve("GEOMETRY", &.{}, .unspecified));
}
