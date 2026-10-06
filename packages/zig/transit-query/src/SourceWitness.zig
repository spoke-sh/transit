//! Expected and observed metadata copied at the failing owner check. No reads,
//! row payloads or diagnostic allocation; fits the existing 104-byte evidence slot.
const std = @import("std");
const q = @import("root.zig");
const d = q.protocol.Diagnostic;
const Self = @This();
pub const Reason = enum(u8) { policy_missing = 1, policy_disabled, policy_revision, request_resource, resource, declaration, table_schema, contract, policy_budget, table_metadata };
reason: Reason,
resource: u64,
object: ?u64 = null,
expected: ?u64 = null,
actual: ?u64 = null,
expected_hash: ?[32]u8 = null,
actual_hash: ?[32]u8 = null,
dimension: q.QueryFailure.Dimension = .none,
pub const encoded_bytes = 104;

pub fn validate(self: Self) !void {
    if (self.resource == 0 or self.resource > q.protocol.max_counter) return error.InvalidSourceWitness;
    if ((self.reason == .table_metadata) != (self.object != null)) return error.InvalidSourceWitness;
    switch (self.reason) {
        .table_metadata => {
            if (self.object.? == 0 or self.expected == null or self.actual == null or self.expected_hash == null or self.actual_hash == null) return error.InvalidSourceWitness;
            if (self.expected == self.actual and std.meta.eql(self.expected_hash, self.actual_hash)) return error.InvalidSourceWitness;
        },
        .declaration, .table_schema, .contract => {
            if (self.expected_hash == null or self.actual_hash == null or self.expected != null or self.actual != null or std.meta.eql(self.expected_hash, self.actual_hash)) return error.InvalidSourceWitness;
        },
        .policy_missing => {
            if (self.actual != null or self.expected_hash != null or self.actual_hash != null) return error.InvalidSourceWitness;
        },
        .policy_disabled => {
            if (self.actual == null or self.expected_hash != null or self.actual_hash != null) return error.InvalidSourceWitness;
        },
        .policy_revision, .request_resource, .resource, .policy_budget => {
            if (self.expected == null or self.actual == null or self.expected == self.actual or self.expected_hash != null or self.actual_hash != null) return error.InvalidSourceWitness;
        },
    }
    if (self.reason == .policy_budget) {
        if (self.dimension == .none or self.actual.? <= self.expected.?) return error.InvalidSourceWitness;
    } else if (self.dimension != .none) return error.InvalidSourceWitness;
}
pub fn encode(self: Self) ![encoded_bytes]u8 {
    try self.validate();
    var bytes: [encoded_bytes]u8 = @splat(0);
    bytes[0] = @backingInt(self.reason);
    bytes[1] = @intFromBool(self.expected != null) | (@as(u8, @intFromBool(self.actual != null)) << 1) |
        (@as(u8, @intFromBool(self.expected_hash != null)) << 2) | (@as(u8, @intFromBool(self.actual_hash != null)) << 3);
    bytes[2] = @backingInt(self.dimension);
    bytes[3] = @intFromBool(self.object != null);
    std.mem.writeInt(u64, bytes[4..12], self.resource, .little);
    std.mem.writeInt(u64, bytes[12..20], self.expected orelse 0, .little);
    std.mem.writeInt(u64, bytes[20..28], self.actual orelse 0, .little);
    bytes[28..60].* = self.expected_hash orelse @splat(0);
    bytes[60..92].* = self.actual_hash orelse @splat(0);
    std.mem.writeInt(u64, bytes[92..100], self.object orelse 0, .little);
    return bytes;
}
pub fn decode(bytes: []const u8) !Self {
    if (bytes.len != encoded_bytes) return error.InvalidSourceWitness;
    const result: Self = .{
        .reason = std.enums.fromInt(Reason, bytes[0]) orelse return error.InvalidSourceWitness,
        .dimension = std.enums.fromInt(q.QueryFailure.Dimension, bytes[2]) orelse return error.InvalidSourceWitness,
        .resource = std.mem.readInt(u64, bytes[4..12], .little),
        .object = if (bytes[3] == 1) std.mem.readInt(u64, bytes[92..100], .little) else null,
        .expected = if (bytes[1] & 1 != 0) std.mem.readInt(u64, bytes[12..20], .little) else null,
        .actual = if (bytes[1] & 2 != 0) std.mem.readInt(u64, bytes[20..28], .little) else null,
        .expected_hash = if (bytes[1] & 4 != 0) bytes[28..60].* else null,
        .actual_hash = if (bytes[1] & 8 != 0) bytes[60..92].* else null,
    };
    if (!std.mem.eql(u8, &try result.encode(), bytes)) return error.InvalidSourceWitness;
    return result;
}
pub fn message(self: Self) []const u8 {
    return switch (self.reason) {
        .policy_missing => "The source has no query policy for this requester.",
        .policy_disabled => "The current source policy disables queries for this requester.",
        .policy_revision => "The query policy revision changed from the admitted policy.",
        .request_resource => "The request publication resource differs from the resource allowed by policy.",
        .resource => "The query source resource differs from the executing resource.",
        .declaration => "The query source declaration differs from the declaration allowed by policy.",
        .table_schema => "The current Table schema differs from the submitted schema.",
        .table_metadata => "The current Table metadata differs from the submitted immutable definition.",
        .contract => "The source contract differs from the frozen query basis.",
        .policy_budget => "The requested query budget exceeds the current policy allowance.",
    };
}
pub fn enrich(self: Self, result: *d) !void {
    try self.validate();
    try result.fact(.object, .execution, .{ .unsigned = .init(self.object orelse self.resource) });
    try result.text(.native_cause, .owner, @tagName(self.reason));
    const fields: [2]d.Field = switch (self.reason) {
        .policy_missing, .policy_disabled, .policy_revision => .{ .expected_policy, .actual_policy },
        .request_resource, .resource => .{ .expected_resource, .actual_resource },
        .table_schema => .{ .expected_schema, .actual_schema },
        .declaration, .contract, .table_metadata => .{ .expected_source, .actual_source },
        .policy_budget => .{ .limit, .required },
    };
    const expected_origin: d.Origin = switch (self.reason) {
        .policy_budget, .declaration => .authority,
        .request_resource, .resource => if (result.stage == .admission) .authority else .execution,
        .table_schema, .table_metadata => .caller,
        else => .execution,
    };
    const actual_origin: d.Origin = switch (self.reason) {
        .policy_budget, .declaration => .caller,
        .request_resource, .resource => if (result.stage == .admission) .caller else .authority,
        .table_schema, .table_metadata => .schema,
        else => .authority,
    };
    if (self.expected_hash) |value| try result.fact(fields[0], expected_origin, .{ .digest = value }) else if (self.expected) |value| try result.fact(fields[0], expected_origin, .{ .unsigned = .init(value) }) else try result.absent(fields[0], expected_origin, .inapplicable);
    if (self.actual_hash) |value| try result.fact(fields[1], actual_origin, .{ .digest = value }) else if (self.actual) |value| try result.fact(fields[1], actual_origin, .{ .unsigned = .init(value) }) else try result.absent(fields[1], actual_origin, .unavailable);
    if (self.dimension != .none) try result.text(.budget, .owner, @tagName(self.dimension));
    if (self.reason == .table_metadata) {
        try result.fact(.expected_revision, .caller, .{ .unsigned = .init(self.expected.?) });
        try result.fact(.actual_revision, .schema, .{ .unsigned = .init(self.actual.?) });
        try result.fact(.actual_resource, .authority, .{ .unsigned = .init(self.resource) });
    }
}

test "source witnesses retain full counters and hashes and reject noncanonical padding" {
    for ([_]Self{
        .{ .reason = .policy_missing, .resource = 7, .expected = 1 },
        .{ .reason = .policy_disabled, .resource = 7, .expected = 1, .actual = 2 },
        .{ .reason = .policy_revision, .resource = 7, .expected = 1, .actual = q.protocol.max_counter },
        .{ .reason = .request_resource, .resource = 7, .expected = 8, .actual = 9 },
        .{ .reason = .resource, .resource = 7, .expected = 7, .actual = 9 },
        .{ .reason = .table_schema, .resource = 7, .expected_hash = @splat(1), .actual_hash = @splat(2) },
        .{ .reason = .declaration, .resource = 7, .expected_hash = @splat(1), .actual_hash = @splat(2) },
        .{ .reason = .contract, .resource = 7, .expected_hash = @splat(1), .actual_hash = @splat(2) },
        .{ .reason = .policy_budget, .resource = 7, .dimension = .result_bytes, .expected = std.math.maxInt(u64) - 1, .actual = std.math.maxInt(u64) },
    }) |witness| {
        var bytes = try witness.encode();
        try std.testing.expectEqualDeep(witness, try decode(&bytes));
        var result = try d.init("query.source_changed", .conflict, .execute, .not_applicable, .none, witness.message());
        try witness.enrich(&result);
        try result.validate();
        bytes[103] = 1;
        try std.testing.expectError(error.InvalidSourceWitness, decode(&bytes));
    }
}
