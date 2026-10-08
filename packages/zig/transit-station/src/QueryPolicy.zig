//! Current peer policy and shared framework keys.
const std = @import("std");
const p = @import("transit_client").protocol;
pub const Policy = struct { table: u64, revision: u64, allow: bool };
pub fn key(tag: u8, identity: u64, ordinal: u8) p.Value {
    var bytes: [11]u8 = undefined;
    bytes[0] = 0;
    bytes[1] = tag;
    std.mem.writeInt(u64, bytes[2..10], identity, .little);
    bytes[10] = ordinal;
    return p.Value.init(&bytes) catch unreachable;
}
pub fn policy(turn: anytype, peer: u64) !?Policy {
    const value = (try turn.read(key('a', peer, 0))) orelse return null;
    if (value.len != 18 or value.data[0] != 1 or value.data[17] > 1) return error.InvalidQueryPolicy;
    return .{ .table = std.mem.readInt(u64, value.data[1..9], .little), .revision = std.mem.readInt(u64, value.data[9..17], .little), .allow = value.data[17] == 1 };
}
/// This is a trusted handler operation. A remote policy API must separately
/// authorize its administrator from authenticated origin before invoking it.
pub fn setPolicy(turn: anytype, peer: u64, table: u64, expected_revision: u64, allow: bool) !void {
    if (peer == 0 or peer > p.max_counter or table == 0) return error.InvalidQueryPolicy;
    const old = try policy(turn, peer);
    if ((if (old) |value| value.revision else 0) != expected_revision) return error.QueryPolicyConflict;
    var bytes: [18]u8 = undefined;
    bytes[0] = 1;
    std.mem.writeInt(u64, bytes[1..9], table, .little);
    std.mem.writeInt(u64, bytes[9..17], try std.math.add(u64, expected_revision, 1), .little);
    bytes[17] = @intFromBool(allow);
    try turn.write(key('a', peer, 0), try p.Value.init(&bytes));
}
