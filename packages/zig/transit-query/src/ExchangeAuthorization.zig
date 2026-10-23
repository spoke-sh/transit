//! Explicit original-caller authorization for one frozen exchange assignment.
//! Save before activation; replacement retains the same logical PID and proof.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const Self = @This();
assignment: Assignment,
proof: p.Authorization.Proof,

pub const Assignment = struct {
    exchange: u64,
    producer: u64,
    options: q.RelationalExchangeProducer.Options,

    pub fn context(self: Assignment, bundle: q.RelationalBundle, basis: q.RelationalHistory.Vector) ![32]u8 {
        try q.UnifiedRecords.identity(self.exchange);
        try q.UnifiedRecords.identity(self.producer);
        try basis.validate(bundle);
        const options = self.options;
        try options.receiver.validate();
        if (options.receiver.owner != (try original(bundle)).audience) return error.QueryDenied;
        if (options.partitions == 0 or options.workers == 0 or options.worker >= options.workers or options.batch == 0 or options.batch > q.fuze.RelationalExchange.max_rows or options.epoch == 0 or options.quota == 0) return error.InvalidRelationalExchange;
        _ = try std.math.mul(u64, options.partitions, bundle.sources.len);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.query.exchange.assignment.v1\x00");
        var bytes: [q.RelationalHistory.Vector.max_bytes]u8 = undefined;
        hash.update(try basis.encode(bundle, &bytes));
        var number: [8]u8 = undefined;
        inline for (.{ self.exchange, self.producer, options.receiver.owner, options.receiver.resource, options.partitions, options.workers, options.worker, @as(u64, options.batch), options.epoch, options.quota }) |value| {
            std.mem.writeInt(u64, &number, value, .little);
            hash.update(&number);
        }
        return hash.finalResult();
    }
};
fn original(bundle: q.RelationalBundle) !p.Authorization.Claim {
    const authorization = bundle.authorization orelse return error.QueryDenied;
    const bound = try bundle.subject(authorization.proof.claim.audience, authorization.requester, authorization.requests);
    return bound.signed.claim;
}
fn sameCaller(left: p.Authorization.Claim, right: p.Authorization.Claim) bool {
    return left.definition == right.definition and left.realm == right.realm and left.principal == right.principal and left.credential_epoch == right.credential_epoch and left.role == right.role;
}
/// An explicit additional authorization by the accepted query's original caller.
/// A rotated key/epoch or a different active role cannot renew accepted work.
pub fn prepare(client: q.wire.AuthorizationClient, assignment: Assignment, bundle: q.RelationalBundle, basis: q.RelationalHistory.Vector) !Self {
    const claim = try original(bundle);
    if (client.realm != claim.realm or client.principal != claim.principal or client.role != claim.role) return error.QueryDenied;
    const bound = try client.proof(assignment.producer, try assignment.context(bundle, basis));
    if (!sameCaller(claim, bound.signed.claim)) return error.QueryDenied;
    return .{ .assignment = assignment, .proof = bound.signed };
}
pub fn readBinding(self: Self, bundle: q.RelationalBundle, basis: q.RelationalHistory.Vector, ordinal: usize, executor: u64) !q.catalog.DirectReadDelegation.Borrow.Binding {
    _ = try self.subject(self.assignment, bundle, basis);
    if (ordinal >= bundle.sources.len) return error.InvalidRelationalSources;
    const record = basis.entries[ordinal].record;
    return .{ .executor = executor, .target = if (record.point()) |point|
        .{ .history = .{ .object = record.basis.snapshot.object, .point = point } }
    else
        .{ .snapshot = record.basis.snapshot }, .purpose = try self.assignment.context(bundle, basis) };
}
/// The original caller explicitly authorizes this worker credential to read
/// the assignment's exact source cut, without granting pin lifecycle control.
pub fn prepareRead(self: Self, client: q.catalog.DirectTableClient, bundle: q.RelationalBundle, basis: q.RelationalHistory.Vector, ordinal: usize, executor: u64) !q.catalog.DirectReadDelegation.Borrow {
    const binding = try self.readBinding(bundle, basis, ordinal, executor);
    return q.catalog.DirectReadDelegation.Borrow.prepare(client, bundle.retention[ordinal], binding);
}
/// Check the exact query/basis/layout before the native turn authenticates the
/// proof and fences current privileges. This check alone grants no access.
pub fn subject(self: Self, assignment: Assignment, bundle: q.RelationalBundle, basis: q.RelationalHistory.Vector) !p.Authorization.Subject {
    try self.proof.claim.validate();
    if (!std.meta.eql(self.assignment, assignment) or !sameCaller(try original(bundle), self.proof.claim) or self.proof.claim.audience != assignment.producer or !std.mem.eql(u8, &self.proof.claim.context, &try assignment.context(bundle, basis))) return error.QueryDenied;
    return .{ .signed = self.proof };
}
pub fn bind(self: Self, turn: *q.station.Turn, assignment: Assignment, bundle: q.RelationalBundle, basis: q.RelationalHistory.Vector) !void {
    if (turn.delivery.pid != assignment.producer or turn.delivery.realm != self.proof.claim.realm) return error.QueryDenied;
    try turn.bindAuthorizationSubject(try self.subject(assignment, bundle, basis));
}

test "exchange authorization binds original caller, complete basis and exact worker assignment" {
    const t = std.testing;
    var fixture = try @import("direct_query_fixture_test.zig").init(t.allocator, .captured, false);
    defer fixture.deinit();
    const bundle = fixture.bundle;
    const basis = fixture.vector;
    const key = try q.catalog.testing.Authority.key(17);
    var store: q.testing.Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    const assignment: Assignment = .{ .exchange = 99, .producer = 31, .options = .{ .receiver = .{ .owner = bundle.authorization.?.proof.claim.audience, .resource = 900 }, .partitions = 7, .workers = 3, .worker = 1, .batch = 4, .epoch = 1, .quota = 1048576 } };
    var claim = bundle.authorization.?.proof.claim;
    claim.audience = assignment.producer;
    claim.context = try assignment.context(bundle, basis);
    const saved: Self = .{ .assignment = assignment, .proof = try p.Authorization.Proof.sign(claim, key) };
    const bound = try saved.subject(assignment, bundle, basis);
    try bound.signed.verify(key.public_key.toBytes());
    inline for (.{ "exchange", "producer" }) |field| {
        var changed = assignment;
        @field(changed, field) += 1;
        try t.expectError(error.QueryDenied, saved.subject(changed, bundle, basis));
    }
    inline for (.{ "owner", "resource" }) |field| {
        var changed = assignment;
        @field(changed.options.receiver, field) += 1;
        try t.expectError(error.QueryDenied, saved.subject(changed, bundle, basis));
    }
    inline for (.{ "partitions", "workers", "worker", "batch", "epoch", "quota" }) |field| {
        var changed = assignment;
        @field(changed.options, field) += 1;
        try t.expectError(error.QueryDenied, saved.subject(changed, bundle, basis));
    }
    inline for (.{ "principal", "credential_epoch", "role", "realm", "audience" }) |field| {
        var changed = saved;
        if (comptime std.mem.eql(u8, field, "role")) changed.proof.claim.role = 18 else @field(changed.proof.claim, field) += 1;
        changed.proof = try p.Authorization.Proof.sign(changed.proof.claim, key);
        try t.expectError(error.QueryDenied, changed.subject(assignment, bundle, basis));
    }
    var changed_basis = basis;
    for (changed_basis.entries[0..changed_basis.count]) |*entry| entry.record.basis.snapshot.handle.content.sha256[0] ^= 1;
    try t.expectError(error.QueryDenied, saved.subject(assignment, bundle, changed_basis));
    var foreign = bundle;
    foreign.authorization.?.proof.signature[0] ^= 1;
    var foreign_basis = basis;
    foreign_basis.request = try foreign.fingerprint();
    try t.expectError(error.QueryDenied, saved.subject(assignment, foreign, foreign_basis));
    try t.expectError(error.QueryDenied, saved.bind(&turn, assignment, bundle, basis));
    var forged = saved;
    // Keep the signature encoding valid so this checks signer rejection,
    // independent of the contract definition's effect on the curve point.
    forged.proof = try p.Authorization.Proof.sign(claim, try q.catalog.testing.Authority.key(18));
    const unverified = try forged.subject(assignment, bundle, basis);
    try t.expectError(error.SignatureVerificationFailed, unverified.signed.verify(key.public_key.toBytes()));
}
