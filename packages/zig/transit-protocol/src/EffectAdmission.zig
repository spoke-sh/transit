//! Committed Queue intent identity. Values are commitments, never proof that
//! the referenced row exists or permission to execute an external effect.
const std = @import("std");
const p = @import("root.zig");

pub const Source = struct {
    record: p.StreamQueue.RecordIdentity,
    offset: u64,
    execution: p.Transaction.Origin,
    /// SHA-256 of the complete canonical encoded Queue row. Connector-owned
    /// request, endpoint, policy, deadline and lineage live in those bytes.
    row_sha256: [32]u8,

    pub fn validate(self: Source) !void {
        try self.record.validate();
        try self.execution.validate();
        if (!std.meta.eql(self.record.operation.scope, self.execution.transaction.scope) or
            self.record.operation.principal != self.execution.principal)
            return error.InvalidEffectSource;
    }

    pub fn commitment(self: Source) !Commitment {
        try self.validate();
        // Definition revisions and offsets are checked by the binding digest;
        // changing either cannot create a new identity for the same row.
        return .{
            .key = try hash("transit.effect.row.v1", .{
                .object = self.record.target.interpretation.object,
                .partition = self.record.target.partition,
                .operation = self.record.operation,
                .ordinal = self.record.ordinal,
            }),
            .digest = try hash("transit.effect.binding.v1", self),
        };
    }
};

/// Small enough for the native paged effect record. The accepted command keeps
/// the complete source evidence; this binding remains after effect collection.
pub const Commitment = struct { key: [32]u8, digest: [32]u8 };
pub const Request = struct {
    pub const json_schema_safe_integer_fields = .{ .source = false };
    pid: u64,
    generation: u64,
    source: Source,
    pub fn validate(self: Request) !void {
        try self.source.validate();
        if (self.pid != self.source.execution.pid or self.generation == 0 or self.generation > p.max_counter)
            return error.InvalidEffectSource;
    }
};

fn hash(domain: []const u8, value: anytype) ![32]u8 {
    return p.Json.hashBounded(domain, value, p.max_entry_bytes);
}

test "committed effect source matches independent canonical and signing vectors" {
    const Fixture = struct {
        request: p.Growth.Request,
        commitment: Commitment,
        request_digest: [32]u8,
        signature: [64]u8,
        public_key: [32]u8,
    };
    const parsed = try p.Json.parseFromSlice(Fixture, std.testing.allocator, @embedFile("fixtures/effect-admission-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try p.Growth.validate(fixture.request);
    const source = fixture.request.command.admit_effect.source;
    try std.testing.expectEqualDeep(fixture.commitment, try source.commitment());
    try std.testing.expectEqualDeep(fixture.request_digest, try p.Growth.digest(fixture.request));
    try p.Ed25519.Signature.fromBytes(fixture.signature).verify(&fixture.request_digest, try p.Ed25519.PublicKey.fromBytes(fixture.public_key));
    var altered = source;
    altered.offset += 1;
    const changed = try altered.commitment();
    try std.testing.expectEqualDeep(fixture.commitment.key, changed.key);
    try std.testing.expect(!std.meta.eql(fixture.commitment.digest, changed.digest));
}
