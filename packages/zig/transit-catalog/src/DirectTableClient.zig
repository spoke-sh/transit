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
/// When present, key authenticates this delegation's executor. The connection
/// still identifies its original caller and selected role.
delegation: ?c.DirectReadDelegation = null,
/// Current original-caller permission to close a saved delegation. This never
/// renews read authority for the accepted computation.
closure: ?c.DirectReadDelegation.Closure = null,

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
    if (self.delegation) |delegation| {
        try delegation.validate(self.allocator);
        if (!std.meta.eql(delegation.binding.connection, self.connection)) return error.InvalidTableDelegation;
        try delegation.allow(action);
    }
    if (self.closure != null) {
        if (self.delegation == null) return error.InvalidTableDelegation;
        try c.DirectReadDelegation.Closure.allow(action);
    }
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = self.connection, .nonce = nonce, .action = action, .delegation = self.delegation, .closure = self.closure };
    const authority: wire.AuthorizationClient = .{ .transport = self.authority, .realm = self.connection.scope.realm, .principal = if (self.delegation) |delegation| delegation.binding.executor else self.connection.principal, .role = if (self.delegation != null) null else self.connection.role, .key = self.key };
    const proof = (try authority.proof(self.connection.audience, try w.Request.context(input, self.allocator))).signed;
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = input.delegation, .closure = input.closure, .proof = proof };
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

/// Explicitly reconcile closure of one original acquisition, including an
/// uncertain pin/release reply. The caller must durably record its decision to
/// close before entry, retain it on error, and never invoke this for live work.
/// At most three signed exchanges occur; no new cut or pin owner is substituted.
/// A delegated client keeps its original grant and authenticates its executor.
pub fn closeOriginalPin(self: Self, object: p.DataLifecycle.Object, owner: p.DataLifecycle.Operation, expected: p.DataLifecycle.Position, known: ?c.storage.TablePartition.SnapshotHandle) !void {
    return self.closeOriginal(object, owner, expected, known, if (self.delegation) |grant| grant.binding.retention else .snapshot);
}
pub fn closeOriginalHistory(self: Self, object: p.DataLifecycle.Object, owner: p.DataLifecycle.Operation, expected: p.DataLifecycle.Position, known: ?c.storage.TablePartition.SnapshotHandle) !void {
    return self.closeOriginal(object, owner, expected, known, .history);
}
fn closeOriginal(self: Self, object: p.DataLifecycle.Object, owner: p.DataLifecycle.Operation, expected: p.DataLifecycle.Position, known: ?c.storage.TablePartition.SnapshotHandle, retention: c.storage.TablePartition.Retention) !void {
    try self.connection.object(object);
    try self.connection.owner(owner);
    try expected.validate();
    if (expected.next_lsn == 0) return error.InvalidTableResponse;
    if (known) |handle| {
        try handle.content.validate();
        if (!std.meta.eql(handle.owner, owner)) return error.InvalidTableResponse;
    }
    const response = try self.call(.{ .pin_status = .{ .object = object, .owner = owner } });
    defer response.deinit();
    const state = response.value.result.pin_state;
    if (state.position.partition != expected.partition) return error.InvalidTableResponse;
    if (known) |handle| {
        if (state.handle == null or !std.meta.eql(handle, state.handle.?)) return error.InvalidTableResponse;
    }
    if (state.released) return;
    var handle = state.handle;
    if (handle == null or known == null) {
        // A delayed original request can no longer match a retired/later
        // monotone frontier. Otherwise create its tombstone by pinning and
        // releasing that exact frontier, so an in-flight retry cannot reopen it.
        if (handle == null) {
            if (state.retired or state.position.next_lsn > expected.next_lsn) return;
            if (state.position.next_lsn != expected.next_lsn) return error.InvalidTableResponse;
        }
        // An unknown handle must be recovered through the original acquisition
        // to verify its retained frontier. A matching owner alone is not enough.
        const acquisition: w.Acquisition = .{ .object = object, .owner = owner, .expected = expected };
        const pinned = try self.call(if (retention == .history) .{ .retain_history = acquisition } else .{ .pin = acquisition });
        defer pinned.deinit();
        if (handle) |observed| if (!std.meta.eql(observed, pinned.value.result.pin)) return error.InvalidTableResponse;
        handle = pinned.value.result.pin;
    }
    const released = try self.call(.{ .release = .{ .object = object, .handle = handle.? } });
    defer released.deinit();
}
