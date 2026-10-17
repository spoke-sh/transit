//! Configuration requests retain their operation identity across uncertain replies.
const std = @import("std");
const q = @import("root.zig");
const C = q.settings.Contract;
const Self = @This();
allocator: std.mem.Allocator,
transport: *q.wire.Client,
binding: C.Binding,
principal: u64,
key: q.protocol.Ed25519.KeyPair,
role: ?u64 = null,

pub fn prepare(self: Self, action: C.Action, operation: [16]u8) !C.Signed {
    const authority: q.wire.AuthorizationClient = .{ .transport = self.transport, .realm = self.binding.realm, .principal = self.principal, .key = self.key, .role = self.role };
    const identity = (try authority.read(.identity)).body.authorization.body.identity;
    return C.Signed.sign(.{ .definition = q.protocol.Growth.current_definition, .binding = self.binding, .operation = operation, .action = action }, self.allocator, self.principal, identity.credential_epoch, self.role, self.key);
}
pub fn submit(self: Self, signed: C.Signed) !std.json.Parsed(C.Response) {
    _ = try signed.validate(self.allocator, self.binding);
    if (signed.authority.query.principal != self.principal or signed.authority.query.kind.authorization.role != self.role) return error.ConfigurationDenied;
    const response = self.transport.callOwned(C.Response, C.route, signed, .{ .request_bytes = C.max_bytes, .response_bytes = C.max_bytes }) catch |err| {
        return switch (self.transport.last_rejection orelse return err) {
            .UnknownSetting => error.UnknownSetting,
            .ConfigurationSnapshotChanged => error.ConfigurationSnapshotChanged,
            .ConfigurationOperationConflict => error.ConfigurationOperationConflict,
            .ConfigurationUnavailable => error.ConfigurationUnavailable,
            else => err,
        };
    };
    errdefer response.deinit();
    try response.value.validate(signed.configuration);
    return response;
}
pub fn read(self: Self, action: C.Action) !std.json.Parsed(C.Response) {
    if (action == .reload) return error.ConfigurationOperationRequired;
    var operation: [16]u8 = undefined;
    try self.transport.http.io.randomSecure(&operation);
    return self.submit(try self.prepare(action, operation));
}

pub fn canSeeOrigins(self: Self) !bool {
    var operation: [16]u8 = undefined;
    try self.transport.http.io.randomSecure(&operation);
    const signed = try self.prepare(.{ .settings = .{ .name = "version", .origins = true } }, operation);
    _ = self.transport.call(q.protocol.Growth.Response, "/v1/query", signed.authority) catch |err| {
        if (err == error.AccessDenied) return false;
        return err;
    };
    return true;
}
