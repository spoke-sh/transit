//! Canonical opaque transport for an exact Queue lease. This is a fenced
//! descriptor, not a bearer credential, signature or current liveness proof.
const std = @import("std");
const p = @import("root.zig");
const q = p.StreamQueue;

pub const encoded_bytes = 168;
pub const magic = "QLH1";

/// Fixed size and caller-owned storage make projection allocation-free. The
/// target scope is also the original claim scope, as required by Lease.validate.
pub fn encode(lease: q.Lease, output: *[encoded_bytes]u8) !void {
    try lease.validate();
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll(magic);
    try writer.writeAll(&p.Growth.definition_bytes);
    const object = lease.target.interpretation.object;
    inline for (.{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, lease.target.interpretation.revision }) |value| try writer.writeInt(u64, value, .little);
    try writer.writeAll(&lease.target.interpretation.digest);
    try writer.writeInt(u32, lease.target.partition, .little);
    inline for (.{ lease.claim.principal, lease.claim.operation, lease.offset, lease.epoch, lease.attempt, lease.expires_ms }) |value| try writer.writeInt(u64, value, .little);
    std.debug.assert(writer.buffered().len == encoded_bytes);
}

/// Decode no defaulted compatibility field: the exact definition is required
/// and checked before constructing a native descriptor. Authority and accepted
/// identity remain with the Queue owner on every subsequent operation.
pub fn decode(bytes: []const u8) !q.Lease {
    if (bytes.len != encoded_bytes or !std.mem.eql(u8, bytes[0..4], magic)) return error.InvalidQueueLeaseHandle;
    if (!std.mem.eql(u8, bytes[4..36], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var reader: std.Io.Reader = .fixed(bytes[36..]);
    const scope: p.DataLifecycle.Scope = .{
        .realm = try reader.takeInt(u64, .little),
        .resource = try reader.takeInt(u64, .little),
        .catalog = try reader.takeInt(u64, .little),
    };
    const object: p.DataLifecycle.Object = .{ .scope = scope, .branch = try reader.takeInt(u64, .little), .object = try reader.takeInt(u64, .little) };
    const revision = try reader.takeInt(u64, .little);
    const digest = (try reader.takeArray(32)).*;
    const partition = try reader.takeInt(u32, .little);
    const result: q.Lease = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = object, .revision = revision, .digest = digest }, .partition = partition },
        .claim = .{ .scope = scope, .principal = try reader.takeInt(u64, .little), .operation = try reader.takeInt(u64, .little) },
        .offset = try reader.takeInt(u64, .little),
        .epoch = try reader.takeInt(u64, .little),
        .attempt = try reader.takeInt(u64, .little),
        .expires_ms = try reader.takeInt(u64, .little),
    };
    try result.validate();
    return result;
}

test "Queue lease handles match independent fixed bytes and reject incompatible inputs" {
    const t = std.testing;
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const lease: q.Lease = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 5 }, .revision = 6, .digest = @splat(0x7a) }, .partition = 7 },
        .claim = .{ .scope = scope, .principal = 8, .operation = 9 },
        .offset = 10,
        .epoch = 11,
        .attempt = 12,
        .expires_ms = 13,
    };
    var bytes: [encoded_bytes]u8 = undefined;
    try encode(lease, &bytes);
    // Explicit positions are an independent layout oracle, not a second codec.
    var expected: [encoded_bytes]u8 = @splat(0);
    @memcpy(expected[0..4], "QLH1");
    @memcpy(expected[4..36], &p.Growth.definition_bytes);
    for ([_]usize{ 36, 44, 52, 60, 68, 76 }, [_]u8{ 1, 2, 3, 1, 5, 6 }) |at, value| expected[at] = value;
    @memset(expected[84..116], 0x7a);
    expected[116] = 7;
    for ([_]usize{ 120, 128, 136, 144, 152, 160 }, 8..) |at, value| expected[at] = @intCast(value);
    try t.expectEqualSlices(u8, &expected, &bytes);
    try t.expectEqualDeep(lease, try decode(&expected));
    for (0..encoded_bytes) |length| try t.expectError(error.InvalidQueueLeaseHandle, decode(bytes[0..length]));
    var extended: [encoded_bytes + 1]u8 = @splat(0);
    @memcpy(extended[0..encoded_bytes], &bytes);
    try t.expectError(error.InvalidQueueLeaseHandle, decode(&extended));
    bytes[0] ^= 1;
    try t.expectError(error.InvalidQueueLeaseHandle, decode(&bytes));
    bytes = expected;
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, decode(&bytes));
    bytes = expected;
    @memset(bytes[144..152], 0);
    try t.expectError(error.InvalidQueueLease, decode(&bytes));
    bytes = expected;
    bytes[60] = 4;
    try t.expectError(error.UnsupportedTransactionDomain, decode(&bytes));
    // Successful decoding says nothing about acceptance or lease freshness.
    try t.expectError(error.QueueLeaseExpired, (try decode(&expected)).requireLive(lease, 13));
    var changed = lease;
    changed.expires_ms += 1;
    try t.expectError(error.QueueLeaseFenced, (try decode(&expected)).requireLive(changed, 1));
    changed = lease;
    changed.target.interpretation.object.scope.catalog = std.math.maxInt(u64);
    changed.claim.scope = changed.target.interpretation.object.scope;
    changed.target.interpretation.object.object = std.math.maxInt(u64);
    changed.offset = std.math.maxInt(u64) - 1;
    changed.epoch = std.math.maxInt(u64);
    changed.attempt = std.math.maxInt(u64);
    changed.expires_ms = std.math.maxInt(u64);
    try encode(changed, &bytes);
    try t.expectEqualDeep(changed, try decode(&bytes));
}
