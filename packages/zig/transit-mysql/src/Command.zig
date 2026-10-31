//! Bounded classic command bodies, without query attributes or cursor flags.
const std = @import("std");
const g = @import("root.zig").wire;
const Codec = @import("Codec.zig");
const Scalar = @import("Scalar.zig");
const maximum = g.Limits.max_parameters;
pub const Message = union(enum) { query: []const u8, prepare: []const u8, execute: []const u8, close: u32, reset: u32, database: []const u8, ping, quit, reset_connection };
pub fn decode(payload: []const u8) !Message {
    if (payload.len > g.Limits.max_frame_bytes) return error.FrameTooLarge;
    var reader: Codec.Reader = .{ .bytes = payload };
    const tag = try reader.byte();
    const result: Message = switch (tag) {
        0x03, 0x16 => blk: {
            const sql = try reader.take(payload.len - reader.offset);
            if (sql.len > g.Limits.statement_bytes) return error.WireValueTooLarge;
            if (std.mem.indexOfScalar(u8, sql, 0) != null or !std.unicode.utf8ValidateSlice(sql)) return error.InvalidWireText;
            break :blk if (tag == 0x03) .{ .query = sql } else .{ .prepare = sql };
        },
        0x17 => .{ .execute = try reader.take(payload.len - reader.offset) },
        0x19 => .{ .close = try reader.int(u32, .little) },
        0x1a => .{ .reset = try reader.int(u32, .little) },
        0x02 => blk: {
            const database = try reader.take(payload.len - reader.offset);
            if (database.len == 0 or database.len > g.Limits.max_name_bytes) return error.WireValueTooLarge;
            if (std.mem.indexOfScalar(u8, database, 0) != null or !std.unicode.utf8ValidateSlice(database)) return error.InvalidWireText;
            break :blk .{ .database = database };
        },
        0x0e => .ping,
        0x01 => .quit,
        0x1f => .reset_connection,
        else => return error.UnsupportedWireCommand,
    };
    try reader.finish();
    return result;
}
pub fn statementId(payload: []const u8) !u32 {
    var reader: Codec.Reader = .{ .bytes = payload };
    return reader.int(u32, .little);
}
/// Types persist across valid executions. Rejected messages never alter them.
/// The session owns this state with its prepared statement, not its socket input.
pub const Parameters = struct {
    types: [maximum]Scalar.WireType = undefined,
    count: u16 = 0,
    initialized: bool = false,
    pub const Bound = struct { values: [maximum]?g.fuze.Types.Values.Atom = undefined, count: u16 };
    pub fn execute(self: *Parameters, payload: []const u8, id: u32, expected: []const g.Type.Kind) !Bound {
        if (expected.len > maximum) return error.TooManyWireParameters;
        if (payload.len > g.Limits.max_frame_bytes) return error.FrameTooLarge;
        var reader: Codec.Reader = .{ .bytes = payload };
        if (try reader.int(u32, .little) != id) return error.UnknownPreparedStatement;
        if (try reader.byte() != 0 or try reader.int(u32, .little) != 1) return error.UnsupportedWireExecute;
        var bound: Bound = .{ .count = @intCast(expected.len) };
        if (expected.len == 0) {
            try reader.finish();
            return bound;
        }
        const bitmap = try reader.take((expected.len + 7) / 8);
        const new_types = try reader.byte();
        if (new_types > 1) return error.InvalidWireMessage;
        var candidate = self.*;
        if (new_types == 1) {
            candidate.count = @intCast(expected.len);
            for (candidate.types[0..expected.len]) |*kind| {
                kind.code = try reader.byte();
                const flag = try reader.byte();
                if (flag != 0 and flag != 0x80) return error.InvalidWireParameterType;
                kind.unsigned = flag == 0x80;
            }
            candidate.initialized = true;
        } else if (!candidate.initialized or candidate.count != expected.len) return error.MissingWireParameterTypes;
        for (expected, candidate.types[0..expected.len], bound.values[0..expected.len], 0..) |kind, wire, *value, i| {
            try Scalar.compatible(kind, wire);
            value.* = if (bitmap[i / 8] & (@as(u8, 1) << @intCast(i % 8)) != 0) null else try Scalar.decode(&reader, kind, wire);
        }
        try reader.finish();
        self.* = candidate;
        return bound;
    }
};
test "prepared execution remembers types only after a complete valid body" {
    const t = std.testing;
    const prefix = "\x07\x00\x00\x00\x00\x01\x00\x00\x00";
    const body = prefix ++ "\x02\x01\x08\x80\xfd\x00\xff\xff\xff\xff\xff\xff\xff\xff";
    var parameters: Parameters = .{};
    const kinds: []const g.Type.Kind = &.{ .uint64, .utf8 };
    for (0..body.len) |end| {
        _ = parameters.execute(body[0..end], 7, kinds) catch {};
        try t.expect(!parameters.initialized);
    }
    const bound = try parameters.execute(body, 7, kinds);
    try t.expectEqual(@as(u128, std.math.maxInt(u64)), bound.values[0].?.unsigned);
    try t.expectEqual(@as(?g.fuze.Types.Values.Atom, null), bound.values[1]);
    const next = try parameters.execute(prefix ++ "\x01\x00\x03a\x00b", 7, kinds);
    try t.expectEqual(@as(?g.fuze.Types.Values.Atom, null), next.values[0]);
    try t.expectEqualStrings("a\x00b", next.values[1].?.bytes);
    try t.expectError(error.InvalidWireMessage, parameters.execute(body ++ "x", 7, kinds));
    try t.expectError(error.UnsupportedWireExecute, parameters.execute("\x07\x00\x00\x00\x01\x01\x00\x00\x00", 7, kinds));
    try t.expectError(error.InvalidWireMessage, decode("\x0ex"));
    try t.expectError(error.UnsupportedWireCommand, decode("\x18"));
}
