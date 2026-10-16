//! Original caller proof for one immutable query and its intended recipient.
//! Decoding/checking these bytes never substitutes for current native authority.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const a = p.Authorization;
const Self = @This();
pub const encoded_bytes = 185;
requester: u64,
requests: u64,
proof: a.Proof,

pub fn validate(self: Self) !void {
    q.UnifiedRecords.identity(self.requester) catch return error.InvalidQueryAuthorization;
    q.UnifiedRecords.identity(self.requests) catch return error.InvalidQueryAuthorization;
    self.proof.claim.validate() catch |err| return if (err == error.IncompatibleDefinition) err else error.InvalidQueryAuthorization;
}
/// A saved query cannot switch its execution role when a caller restores it.
/// Current disclosure/recovery under another role is a separate operation.
pub fn caller(self: Self, principal: u64, role: ?u64) !void {
    try self.validate();
    if (self.proof.claim.principal != principal or self.proof.claim.role != role) return error.QueryDenied;
}
pub fn context(requester: u64, requests: u64, body: []const u8) ![32]u8 {
    try q.UnifiedRecords.identity(requester);
    try q.UnifiedRecords.identity(requests);
    var identities: [16]u8 = undefined;
    std.mem.writeInt(u64, identities[0..8], requester, .little);
    std.mem.writeInt(u64, identities[8..16], requests, .little);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.original-subject.v1\x00");
    hash.update(&identities);
    hash.update(body);
    return hash.finalResult();
}
/// Prepare once before saving/uploading. Rotation must not silently replace the
/// epoch/signature of an accepted query or change its immutable publication.
pub fn prepare(client: q.wire.AuthorizationClient, audience: u64, requester: u64, requests: u64, body: []const u8) !Self {
    const original = try client.proof(audience, try context(requester, requests, body));
    return .{ .requester = requester, .requests = requests, .proof = original.signed };
}
/// Bind the proof to actual native routing and canonical unsigned query bytes.
/// The enclosing reader/turn must still check this subject through native guards.
pub fn subject(self: Self, audience: u64, requester: u64, requests: u64, body: []const u8) !a.Subject {
    try self.validate();
    if (self.requester != requester or self.requests != requests or self.proof.claim.audience != audience or !std.mem.eql(u8, &self.proof.claim.context, &try context(requester, requests, body))) return error.QueryDenied;
    return .{ .signed = self.proof };
}
pub fn readerContext(resources: q.wire.ResourceReader, original: a.Subject, observed: ?*?a.Guard) q.catalog.TableAuthority.Context {
    return .{ .client = .{ .transport = resources.wire, .realm = resources.realm, .principal = resources.principal, .key = resources.key }, .subject = original, .observed = observed };
}
pub fn checkTable(table: q.TableSource, reader: anytype, original: a.Subject, expected: u64) !void {
    if (original.principal() != expected) return error.QueryDenied;
    const Reader = @typeInfo(@TypeOf(reader)).pointer.child;
    if (Reader == q.wire.ResourceReader.Reader) {
        var current = readerContext(reader.client, original, null).wrap(reader);
        _ = try table.checkCurrent(&current, expected);
        try current.finish();
    } else if (@hasDecl(Reader, "bindAuthorizationSubject")) {
        try reader.bindAuthorizationSubject(original);
        _ = try table.checkCurrent(reader, expected);
    } else return error.UnsupportedAuthorization;
}
pub fn write(value: ?Self, writer: *std.Io.Writer) !void {
    try writer.writeByte(@intFromBool(value != null));
    const self = value orelse return;
    try self.validate();
    try writer.writeInt(u64, self.requester, .little);
    try writer.writeInt(u64, self.requests, .little);
    try writer.writeAll(&q.catalog.TableMetadata.definition());
    const claim = self.proof.claim;
    inline for (.{ "realm", "principal", "credential_epoch" }) |field| try writer.writeInt(u64, @field(claim, field), .little);
    try writer.writeByte(@intFromBool(claim.role != null));
    try writer.writeInt(u64, claim.role orelse 0, .little);
    try writer.writeInt(u64, claim.audience, .little);
    try writer.writeAll(&claim.context);
    try writer.writeAll(&self.proof.signature);
}
pub fn read(reader: *std.Io.Reader) !?Self {
    switch (try reader.takeByte()) {
        0 => return null,
        1 => {},
        else => return error.InvalidQueryAuthorization,
    }
    const requester = try reader.takeInt(u64, .little);
    const requests = try reader.takeInt(u64, .little);
    if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
    var claim: a.Claim = .{
        .definition = p.Growth.current_definition,
        .realm = try reader.takeInt(u64, .little),
        .principal = try reader.takeInt(u64, .little),
        .credential_epoch = try reader.takeInt(u64, .little),
        .role = null,
        .audience = undefined,
        .context = undefined,
    };
    const has_role = try reader.takeByte();
    const role = try reader.takeInt(u64, .little);
    if (has_role > 1 or (has_role == 0 and role != 0)) return error.InvalidQueryAuthorization;
    if (has_role == 1) claim.role = role;
    claim.audience = try reader.takeInt(u64, .little);
    claim.context = (try reader.takeArray(32)).*;
    const result: Self = .{ .requester = requester, .requests = requests, .proof = .{ .claim = claim, .signature = (try reader.takeArray(64)).* } };
    try result.validate();
    return result;
}

test "query proof binds recipient, request resource, owner and immutable body" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const original: Self = .{ .requester = 11, .requests = 12, .proof = try a.Proof.sign(.{
        .definition = p.Growth.current_definition,
        .realm = 1,
        .principal = 17,
        .credential_epoch = 3,
        .role = 19,
        .audience = 13,
        .context = try context(11, 12, "immutable query"),
    }, key) };
    const bound = try original.subject(13, 11, 12, "immutable query");
    try original.caller(17, 19);
    try t.expectError(error.QueryDenied, original.caller(18, 19));
    try t.expectError(error.QueryDenied, original.caller(17, null));
    try t.expectError(error.QueryDenied, original.caller(17, 20));
    try bound.signed.verify(key.public_key.toBytes());
    try t.expectError(error.QueryDenied, original.subject(14, 11, 12, "immutable query"));
    try t.expectError(error.QueryDenied, original.subject(13, 14, 12, "immutable query"));
    try t.expectError(error.QueryDenied, original.subject(13, 11, 14, "immutable query"));
    try t.expectError(error.QueryDenied, original.subject(13, 11, 12, "different query"));
    var bytes: [1 + encoded_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try write(original, &writer);
    try t.expectEqual(bytes.len, writer.buffered().len);
    var reader: std.Io.Reader = .fixed(writer.buffered());
    try t.expectEqualDeep(original, (try read(&reader)).?);
    try t.expectEqual(@as(usize, 0), reader.bufferedLen());
    bytes[17] ^= 1;
    reader = .fixed(&bytes);
    try t.expectError(error.IncompatibleDefinition, read(&reader));
}
