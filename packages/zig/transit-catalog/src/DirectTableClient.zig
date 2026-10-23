//! Typed signed direct Table caller. Each explicit call owns its response;
//! operation identities survive retries independently of request credentials.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const wire = c.station.client;
const w = c.DirectTableProtocol;
const Self = @This();

allocator: std.mem.Allocator,
authority: *wire.Client,
service: *wire.Client,
connection: w.Connection,
key: p.Ed25519.KeyPair,

pub const validateResponse = @import("DirectTableResponse.zig").validate;
/// Current rights and exact interpretation only. This prepares no mutation or
/// snapshot, and the returned subject does not authorize a later operation.
pub fn require(self: Self, requested: c.DirectCatalog.AccessRequest) !p.Authorization.Verified {
    const response = try self.call(.{ .check = requested });
    defer response.deinit();
    return response.value.subject;
}
pub fn signed(self: Self, action: w.Action, nonce: [16]u8) !w.Request {
    try self.connection.validate();
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = self.connection, .nonce = nonce, .action = action };
    const authority: wire.AuthorizationClient = .{ .transport = self.authority, .realm = self.connection.scope.realm, .principal = self.connection.principal, .role = self.connection.role, .key = self.key };
    const proof = (try authority.proof(self.connection.audience, try w.Request.context(input, self.allocator))).signed;
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .proof = proof };
    try request.validate(self.allocator);
    return request;
}
/// No retry, resubmission, pin renewal or settlement is implicit. A timeout can
/// leave accepted work; inspect or resume its original binding explicitly.
pub fn call(self: Self, action: w.Action) !std.json.Parsed(w.Response) {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var temporary = self;
    temporary.allocator = arena.allocator();
    var nonce: [16]u8 = undefined;
    try self.authority.http.io.randomSecure(&nonce);
    const request = try temporary.signed(action, nonce);
    const response = try self.service.callOwned(w.Response, "/table/v1", request, .{ .request_bytes = w.max_request_bytes, .response_bytes = w.max_response_bytes });
    errdefer response.deinit();
    try validateResponse(arena.allocator(), request, response.value);
    return response;
}
