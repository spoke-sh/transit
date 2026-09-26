const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const f = q.fuze;
/// The existing frame budget includes the exact descriptor fingerprint. Larger
/// predicates fail explicitly; do not omit the fence or truncate their bytes.
pub const plan_bytes = q.station.Frame.max_payload - 36;
pub const Start = struct {
    schema: [32]u8,
    plan: f.Stream.Plan,
    pub fn encode(self: Start) !p.Value {
        var bytes: [q.station.Frame.max_payload]u8 = undefined;
        bytes[0..4].* = "PQR1".*;
        bytes[4..36].* = self.schema;
        var plan: [f.Stream.PlanCodec.encoded_bytes]u8 = undefined;
        const encoded = try f.Stream.PlanCodec.encode(self.plan, &plan);
        if (encoded.len > plan_bytes) return error.QueryRequestTooLarge;
        @memcpy(bytes[36..][0..encoded.len], encoded);
        return p.Value.init(bytes[0 .. 36 + encoded.len]);
    }
    pub fn decode(value: p.Value) !Start {
        try value.validate();
        if (value.len < 40 or value.len > q.station.Frame.max_payload or !std.mem.eql(u8, value.data[0..4], "PQR1")) return error.InvalidQueryRequest;
        return .{ .schema = value.data[4..36].*, .plan = try f.Stream.PlanCodec.decode(value.slice()[36..]) };
    }
};
pub fn cancel(correlation: u64) !p.Value {
    if (correlation == 0 or correlation > p.max_counter) return error.InvalidQueryIdentity;
    var bytes: [12]u8 = undefined;
    bytes[0..4].* = "PQC1".*;
    std.mem.writeInt(u64, bytes[4..12], correlation, .little);
    return p.Value.init(&bytes);
}
pub fn cancelled(value: p.Value) !u64 {
    if (value.len != 12 or !std.mem.eql(u8, value.data[0..4], "PQC1")) return error.InvalidQueryRequest;
    const correlation = std.mem.readInt(u64, value.data[4..12], .little);
    if (!(try cancel(correlation)).eql(value)) return error.InvalidQueryRequest;
    return correlation;
}
pub fn principalKey() p.Value {
    return p.Value.init("\x00public-query.principal.v1") catch unreachable;
}
pub fn sourceKey() p.Value {
    return p.Value.init("\x00public-query.source.v1") catch unreachable;
}
pub fn activeKey() p.Value {
    return p.Value.init("\x00public-query.active.v1") catch unreachable;
}
pub fn statusKey(correlation: u64) p.Value {
    var bytes: [12]u8 = undefined;
    bytes[0..4].* = "\x00PQ1".*;
    std.mem.writeInt(u64, bytes[4..12], correlation, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn identity(value: u64) p.Value {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn readIdentity(value: p.Value) !u64 {
    if (value.len != 8) return error.InvalidQueryIdentity;
    const id = std.mem.readInt(u64, value.data[0..8], .little);
    if (id == 0 or id > p.max_counter) return error.InvalidQueryIdentity;
    return id;
}

test "request carries exact schema, canonical plan and bounded lossless predicate" {
    const t = std.testing;
    const schema: f.model.Schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .utf8 };
    const plan = try f.Sql.plan("SELECT value FROM items WHERE id >= -9223372036854775808 LIMIT 2", .{ .name = try .init("items"), .schema = schema });
    const start: Start = .{ .schema = try schema.fingerprint(), .plan = plan };
    try t.expectEqualDeep(start, try Start.decode(try start.encode()));
    var large = start;
    large.plan.predicate = .{ .compare = .{ .column = 1, .op = .eq, .value = .{ .utf8 = try .init(&@as([220]u8, @splat('x'))) } } };
    try t.expectError(error.QueryRequestTooLarge, large.encode());
    try t.expectEqual(@as(u64, 9007199254740991), try cancelled(try cancel(9007199254740991)));
    try t.expectError(error.InvalidQueryIdentity, cancel(0));
}
