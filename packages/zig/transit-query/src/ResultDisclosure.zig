//! Fresh authority for retained results, independent of immutable execution
//! attribution. The enclosing result reader still verifies every source and
//! rechecks native authorization before releasing each bounded result.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const a = p.Authorization;
const Ref = q.station.PublicationReference;
pub const Selection = union(enum) {
    unified: struct {
        reference: Ref,
        resource: u64,
        source: u64,
        requester: u64,
        correlation: u64,
        request: Ref,
        cursor: ?q.UnifiedResult.Cursor,
    },
    relational: struct {
        request: [32]u8,
        owner: u64,
        peer: u64,
        resource: u64,
        job: u64,
        requests: u64,
    },
    fn audience(self: Selection) u64 {
        return switch (self) {
            .unified => |value| value.source,
            .relational => |value| value.owner,
        };
    }
    fn requester(self: Selection) u64 {
        return switch (self) {
            .unified => |value| value.requester,
            .relational => |value| value.peer,
        };
    }
};
pub fn context(selection: Selection) ![32]u8 {
    var bytes: [8192]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(selection, &encoder);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.result-disclosure.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}
pub fn prepare(client: q.wire.AuthorizationClient, selection: Selection) !a.Subject {
    return client.proof(selection.audience(), try context(selection));
}
/// Signed public reads bind the complete selection. Accepted references are an
/// internal execution profile: a requester continuation uses its original
/// admission, never a replacement credential owned by the worker.
pub fn check(subject: a.Subject, selection: Selection, realm: u64) !a.Subject {
    try subject.validate();
    switch (subject) {
        .signed => |proof| if (proof.claim.realm != realm or proof.claim.audience != selection.audience() or !std.mem.eql(u8, &proof.claim.context, &try context(selection))) return error.QueryDenied,
        .accepted => |input| if (input.pid != selection.requester()) return error.QueryDenied,
    }
    return subject;
}

test "result disclosure binds the complete selection separately from execution identity" {
    const t = std.testing;
    const selection: Selection = .{ .relational = .{ .request = @splat(3), .owner = 7, .peer = 9, .resource = 11, .job = 13, .requests = 100 } };
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(5));
    const subject: a.Subject = .{ .signed = try a.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 1, .principal = 17, .credential_epoch = 2, .role = 19, .audience = 7, .context = try context(selection) }, key) };
    try subject.signed.verify(key.public_key.toBytes());
    try t.expectEqualDeep(subject, try check(subject, selection, 1));
    inline for (.{ "owner", "peer", "resource", "job", "requests" }) |field| {
        var changed = selection;
        @field(changed.relational, field) += 1;
        try t.expectError(error.QueryDenied, check(subject, changed, 1));
    }
    var changed = selection;
    changed.relational.request[0] ^= 1;
    try t.expectError(error.QueryDenied, check(subject, changed, 1));
    try t.expectError(error.QueryDenied, check(subject, selection, 2));
    const accepted: a.Subject = .{ .accepted = .{ .pid = 9, .input = 23, .principal = 17 } };
    try t.expectEqualDeep(accepted, try check(accepted, selection, 1));
    changed = selection;
    changed.relational.peer += 1;
    try t.expectError(error.QueryDenied, check(accepted, changed, 1));
}
