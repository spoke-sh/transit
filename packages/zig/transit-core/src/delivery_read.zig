const core = @import("root.zig");
const p = core.protocol;
pub fn read(engine: anytype, signed: p.Delivery.SignedQuery) !p.Delivery.Status {
    try engine.refresh();
    const q = signed.query;
    if (q.realm != engine.state.realm) return error.Unauthorized;
    const principal = engine.state.principal(q.principal) catch return error.Unauthorized;
    const key = p.Ed25519.PublicKey.fromBytes(principal.grant.public_key) catch return error.Unauthorized;
    p.Ed25519.Signature.fromBytes(signed.signature).verify(&p.Delivery.digest(q), key) catch return error.Unauthorized;
    if (principal.grant.permissions & p.permission(.delivery) == 0) return error.Forbidden;
    if (q.version != 1) return error.InvalidRead;
    var status: p.Delivery.Status = .{ .realm = q.realm, .position = engine.state.position, .principal_sequence = principal.sequence, .pending = 0 };
    for (engine.state.outputs) |slot| if (slot) |out| {
        if (out.phase == .pending and (principal.grant.pid == null or principal.grant.pid == out.destination)) status.pending += 1;
    };
    if (try engine.store.tail() != status.position) return error.Conflict;
    return status;
}
