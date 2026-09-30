//! One public-protocol courier step. Caller owns scheduling and exact pending bytes.
const std = @import("std");
const wire = @import("root.zig");
const p = wire.protocol;
const g = p.Growth;

pub fn step(client: anytype, query: g.Query, key: p.Ed25519.KeyPair, pending: *?g.SignedRequest) !bool {
    if (query.kind != .delivery) return error.InvalidRequest;
    if (pending.* == null) {
        const status = try client.query(query, key);
        if (status.version != 1 or status.realm != query.realm) return error.InvalidAuthorityResponse;
        const output = status.body.delivery.next orelse return false;
        pending.* = try g.sign(.{ .realm = query.realm, .principal = query.principal, .sequence = try std.math.add(u64, status.principal_sequence, 1), .command = .{ .deliver = output } }, key);
    }
    _ = client.submit(pending.*.?) catch |err| {
        if (client.last_rejection == .OutputAlreadyResolved) {
            // Another identical courier may already have drained/advanced this
            // dedicated principal. No request-specific application data is lost.
            pending.* = null;
            return false;
        }
        return err;
    };
    pending.* = null;
    return true;
}
