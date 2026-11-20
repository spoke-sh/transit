//! Transactional Station message framing and authenticated origin bindings.
//! Payload bytes never establish sender PID or observer principal identity.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const Self = @This();

pub const header_bytes = 13;
pub const max_payload_bytes = 64 * 1024;
pub const magic = "STE1";

pub const Kind = enum(u8) {
    cast = 1,
    call = 2,
    reply = 3,
    cancel = 4,
    timeout = 5,
};

pub const Origin = union(enum) {
    external: u64,
    actor: p.Transaction.Origin,
    observer: u64,

    pub fn validate(self: Origin) !void {
        switch (self) {
            .external, .observer => |principal| if (principal > p.max_counter) return error.InvalidStationOrigin,
            .actor => |origin| try origin.validate(),
        }
    }
};

kind: Kind,
correlation: u64 = 0,
payload: []const u8 = &.{},

pub fn validate(self: Self) !void {
    if (self.payload.len > max_payload_bytes) return error.EnvelopeTooLarge;
    if ((self.kind == .cast) != (self.correlation == 0)) return error.InvalidCorrelation;
}

pub fn encodeAlloc(self: Self, allocator: std.mem.Allocator) ![]u8 {
    try self.validate();
    const out = try allocator.alloc(u8, header_bytes + self.payload.len);
    out[0..4].* = magic.*;
    out[4] = @backingInt(self.kind);
    std.mem.writeInt(u64, out[5..13], self.correlation, .little);
    @memcpy(out[header_bytes..], self.payload);
    return out;
}

pub fn decode(bytes: []const u8) !Self {
    if (bytes.len < header_bytes or !std.mem.eql(u8, bytes[0..4], magic)) return error.InvalidStationEnvelope;
    if (bytes.len - header_bytes > max_payload_bytes) return error.EnvelopeTooLarge;
    const kind = std.enums.fromInt(Kind, bytes[4]) orelse return error.InvalidStationEnvelope;
    const result: Self = .{
        .kind = kind,
        .correlation = std.mem.readInt(u64, bytes[5..13], .little),
        .payload = bytes[header_bytes..],
    };
    try result.validate();
    return result;
}

/// Derive authenticated sender provenance exclusively from Queue row metadata.
/// Actor calls, replies and cancellations require an execution-guarded commit;
/// timeout observations require a non-actor observer principal.
pub fn verifyOrigin(self: Self, operation: d.Operation, execution: ?p.Transaction.Origin) !Origin {
    try self.validate();
    try operation.validate();
    if (execution) |origin| {
        try origin.validate();
        if (!std.meta.eql(origin.transaction.scope, operation.scope) or
            origin.principal != operation.principal or
            std.meta.eql(origin.transaction, operation))
            return error.InvalidStationOrigin;
    }
    return switch (self.kind) {
        .call, .reply, .cancel => .{ .actor = execution orelse return error.UnauthenticatedActorOrigin },
        .timeout => blk: {
            if (execution != null or operation.principal == 0) return error.InvalidObserverOrigin;
            break :blk .{ .observer = operation.principal };
        },
        .cast => if (execution) |origin| .{ .actor = origin } else .{ .external = operation.principal },
    };
}

test "private transactional envelope round-trips and rejects unauthenticated actor or observer origins" {
    const t = std.testing;
    const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const op: d.Operation = .{ .scope = scope, .principal = 9, .operation = 55 };
    const tx_origin: p.Transaction.Origin = .{
        .realm = 1,
        .pid = 42,
        .principal = 9,
        .generation = 2,
        .code = 1,
        .workload = null,
        .transaction = .{ .scope = scope, .principal = 9, .operation = 50 },
    };

    const call_env: Self = .{ .kind = .call, .correlation = 0x10001, .payload = "ping" };
    const encoded = try call_env.encodeAlloc(t.allocator);
    defer t.allocator.free(encoded);
    const decoded = try decode(encoded);
    try t.expectEqual(Kind.call, decoded.kind);
    try t.expectEqual(@as(u64, 0x10001), decoded.correlation);
    try t.expectEqualStrings("ping", decoded.payload);

    // Direct Queue enqueue (execution == null) cannot forge a call, reply or cancel.
    try t.expectError(error.UnauthenticatedActorOrigin, decoded.verifyOrigin(op, null));
    try t.expectError(error.UnauthenticatedActorOrigin, (Self{ .kind = .reply, .correlation = 7, .payload = "ok" }).verifyOrigin(op, null));
    try t.expectError(error.UnauthenticatedActorOrigin, (Self{ .kind = .cancel, .correlation = 7 }).verifyOrigin(op, null));
    try t.expectEqualDeep(Origin{ .actor = tx_origin }, try decoded.verifyOrigin(op, tx_origin));

    // Actor turn (execution != null) cannot forge an observer timeout.
    const timeout_env: Self = .{ .kind = .timeout, .correlation = 7, .payload = "TMO1\x01\x00\x00\x00\x00\x00\x00\x00" };
    try t.expectError(error.InvalidObserverOrigin, timeout_env.verifyOrigin(op, tx_origin));
    try t.expectEqualDeep(Origin{ .observer = 9 }, try timeout_env.verifyOrigin(op, null));

    // Cast admits both external principals and execution-guarded actors.
    const cast_env: Self = .{ .kind = .cast, .correlation = 0, .payload = "event" };
    try t.expectEqualDeep(Origin{ .external = 9 }, try cast_env.verifyOrigin(op, null));
    try t.expectEqualDeep(Origin{ .actor = tx_origin }, try cast_env.verifyOrigin(op, tx_origin));
    try t.expectError(error.InvalidCorrelation, (Self{ .kind = .cast, .correlation = 1 }).validate());
    try t.expectError(error.InvalidCorrelation, (Self{ .kind = .call, .correlation = 0 }).validate());
}
