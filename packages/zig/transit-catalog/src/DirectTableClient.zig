//! Typed signed direct Table caller. Each explicit call owns its response;
//! operation identities survive retries independently of request credentials.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const wire = c.client;
const w = c.DirectTableProtocol;
const Self = @This();

allocator: std.mem.Allocator,
authority: *wire.Client,
service: *wire.Client,
connection: w.Connection,
key: p.Ed25519.KeyPair,
/// An already observed signing epoch, never a cached authorization decision.
/// The owner still authenticates the claim and checks current policy on every
/// request. Rotation rejects this epoch; no refresh or replay is implicit.
credential_epoch: ?u64 = null,
/// When present, key authenticates this delegation's executor. The connection
/// still identifies its original caller and selected role.
delegation: ?c.DirectReadDelegation = null,
lease: ?c.DirectClientToken.Lease = null,
transaction: ?c.DirectTransactionRead.Context = null,
/// Current original-caller permission to close a saved delegation. This never
/// renews read authority for the accepted computation.
closure: ?c.DirectReadDelegation.Closure = null,
/// Saved read-only permission for a distinct executor and one exact cut.
borrow: ?c.DirectReadDelegation.Borrow = null,
/// Per-invocation evidence for an embedding caller. Clear it explicitly before
/// starting a new host action; nested reads must not erase a mutation attempt.
attempt: ?*Attempt = null,

pub const Attempt = struct {
    mutation: ?Mutation = null,
    pub const Mutation = struct { action: std.meta.Tag(w.Action), identity: ?p.DataLifecycle.Operation };
    fn begin(self: *Attempt, request: w.Request) void {
        if (!request.transport().mutation) return;
        self.mutation = .{
            .action = std.meta.activeTag(request.action),
            .identity = switch (request.action) {
                .stream => |value| value.identity(),
                .queue => |value| value.identity(),
                .kv => |value| value.identity(),
                .kv_declaration => |value| value.declaration.binding.identity,
                // A raced token may select a different original operation. Never
                // label the proposed operation as the accepted recovery identity.
                .client_token => null,
                .stage => |value| value.intent.work.binding().identity,
                inline .admit_saved, .commit_saved => |value| value.binding.identity,
                inline .admit_ddl, .admit_rows, .admit_statement, .operation, .log_admit, .log_operation => |value| value.binding.identity,
                inline .name_assertion, .namespace_operation, .dependency_operation, .resource_operation => |value| value.binding.identity(),
                inline .pin, .retain_history => |value| value.owner,
                .release => |value| value.handle.owner,
                else => null,
            },
        };
    }
    /// A service denial, conflict, malformed response or output allocation
    /// failure can follow acceptance. Only a validated owner outcome settles
    /// domain work; an error code cannot turn this attempt into rejection.
    pub fn failure(self: Attempt, cause: anyerror, native: ?p.ErrorCode) !?p.Diagnostic {
        const mutation = self.mutation orelse return null;
        var result = try p.Diagnostic.init("catalog.direct_outcome_unknown", .unavailable, .submit, .unknown, if (mutation.identity != null) .saved_intent else .none, if (mutation.identity != null) "The direct operation outcome is unknown. Preserve its original saved binding and inspect that operation under current rights before deciding how to continue." else if (mutation.action == .historical_catalog) "The historical catalog operation outcome is unknown. Preserve the original selection, account and token. Inspect and resume that original acquisition or release; do not choose a newer cut." else if (mutation.action == .branch) "The branch operation outcome is unknown. Preserve the original account, token and complete request. Inspect that token under current source rights, then resume or cancel the original branch preparation." else if (mutation.action == .transaction) "The transaction control outcome is unknown. Preserve the original account, token, statement and commit operation identities. Inspect that transaction under current rights before resuming its original work." else if (mutation.action == .client_token) "The client-token binding outcome is unknown. Preserve the original account, token and request fingerprint. Look up that token under current rights and use only its accepted intent reference." else if (mutation.action == .flush) "The physical flush outcome is unknown. Preserve the original object and exclusive acceptance cut. Inspect current storage coverage or repeat that same target under current rights." else "The catalog initialization outcome is unknown. Inspect the catalog under the original connection and current rights before deciding how to continue.");
        result.cause = try p.Diagnostic.Code.init(@errorName(cause));
        if (mutation.identity) |identity| result.identity = .{ .domain = .catalog, .id = .init(identity.operation), .realm = .init(identity.scope.realm), .resource = .init(identity.scope.resource) };
        try result.text(.operation, .caller, @tagName(mutation.action));
        if (native) |value| try result.text(.native_cause, .authority, @tagName(value));
        try result.action(.inspect_status);
        if (cause == error.AccessDenied or cause == error.CatalogDenied) try result.action(.inspect_scope);
        try result.validate();
        return result;
    }
};

test "Stream wait cancellation retains its original consume identity as unknown work" {
    const t = std.testing;
    const fixture = try p.Json.parseFromSlice(struct { request: w.Request, public_key: [32]u8, intent_digest: [32]u8 }, t.allocator, @embedFile("fixtures/direct-stream-wait-v1.json"));
    defer fixture.deinit();
    var attempt: Attempt = .{};
    attempt.begin(fixture.value.request);
    const identity = fixture.value.request.action.stream.wait.consume.operation;
    try t.expectEqualDeep(identity, attempt.mutation.?.identity.?);
    const diagnostic = (try attempt.failure(error.Canceled, null)).?;
    try t.expectEqual(.unknown, diagnostic.outcome);
    try t.expectEqual(.saved_intent, diagnostic.evidence);
    try t.expectEqual(identity.operation, try diagnostic.identity.?.id.value());
}

test "direct caller attempt evidence survives reads and service rejection" {
    const t = std.testing;
    const fixture = try p.Json.parseFromSlice(struct { request: w.Request, public_key: [32]u8, edge_digest: [32]u8 }, t.allocator, @embedFile("fixtures/direct-dependency-v1.json"));
    defer fixture.deinit();
    var attempt: Attempt = .{};
    try t.expect(try attempt.failure(error.ConnectionRefused, null) == null);
    attempt.begin(fixture.value.request);
    var read = fixture.value.request;
    read.action.dependency_operation.command = .inspect;
    attempt.begin(read);
    for ([_]anyerror{ error.AccessDenied, error.Conflict, error.InvalidTableResponse, error.AuthorityTimeout, error.OutOfMemory }) |cause| {
        const diagnostic = (try attempt.failure(cause, null)).?;
        try t.expectEqual(.unknown, diagnostic.outcome);
        try t.expectEqual(.saved_intent, diagnostic.evidence);
        try t.expectEqual(std.math.maxInt(u64), try diagnostic.identity.?.id.value());
        try t.expectEqual(.inspect_status, diagnostic.actions[0].?.kind);
        for (diagnostic.actions) |slot| if (slot) |action| try t.expect(action.kind == .inspect_status or action.kind == .inspect_scope);
    }
    attempt = .{};
    attempt.begin(read);
    try t.expect(try attempt.failure(error.AccessDenied, null) == null);
    var wire_client = wire.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire_client.deinit();
    wire_client.timeout_ms = 100;
    const caller: Self = .{ .allocator = t.allocator, .authority = &wire_client, .service = &wire_client, .connection = fixture.value.request.connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(1)), .attempt = &attempt };
    if (caller.call(fixture.value.request.action)) |response| {
        response.deinit();
        return error.UnexpectedConnection;
    } else |_| {}
    // Credential inspection failed before entering the direct mutation route.
    try t.expect(attempt.mutation == null);
}

test "Queue wait cancellation retains its original claim identity as unknown work" {
    const t = std.testing;
    const fixture = try p.Json.parseFromSlice(struct { request: w.Request, public_key: [32]u8, intent_digest: [32]u8 }, t.allocator, @embedFile("fixtures/direct-queue-wait-v1.json"));
    defer fixture.deinit();
    var attempt: Attempt = .{};
    attempt.begin(fixture.value.request);
    const identity = fixture.value.request.action.queue.wait.claim.operation;
    try t.expectEqualDeep(identity, attempt.mutation.?.identity.?);
    const diagnostic = (try attempt.failure(error.Canceled, null)).?;
    try t.expectEqual(.unknown, diagnostic.outcome);
    try t.expectEqual(.saved_intent, diagnostic.evidence);
    try t.expectEqual(identity.operation, try diagnostic.identity.?.id.value());
}

pub const validateResponse = @import("DirectTableResponse.zig").validate;

test "observed signing epoch needs no identity round trip and binds the complete request" {
    const t = std.testing;
    const fixture = try p.Json.parseFromSlice(struct { request: w.Request, public_key: [32]u8, edge_digest: [32]u8 }, t.allocator, @embedFile("fixtures/direct-dependency-v1.json"));
    defer fixture.deinit();
    // No server: preparing the claim must not perform an identity request.
    var transport = wire.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer transport.deinit();
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(1));
    var caller: Self = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = fixture.value.request.connection, .key = key, .credential_epoch = 7 };
    const first = try caller.signed(.describe, @splat(5));
    try first.proof.verify(key.public_key.toBytes());
    try t.expectEqual(7, first.proof.claim.credential_epoch);
    try t.expectEqual(caller.connection.principal, first.proof.claim.principal);
    try t.expectEqual(caller.connection.role, first.proof.claim.role);
    caller.credential_epoch = 8;
    const rotated = try caller.signed(.describe, @splat(5));
    try t.expect(!std.meta.eql(first.proof, rotated.proof));
    var changed = first;
    changed.nonce[0] ^= 1;
    if (changed.validate(t.allocator)) |_| return error.UnboundRequest else |_| {}
}
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
    if (self.borrow) |borrow| {
        if (self.delegation == null or self.closure != null) return error.InvalidTableDelegation;
        _ = try borrow.proof(self.delegation.?, self.allocator);
        try borrow.allow(action);
    }
    if (self.closure != null) {
        if (self.delegation == null) return error.InvalidTableDelegation;
        try c.DirectReadDelegation.Closure.allow(action);
    }
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = self.connection, .nonce = nonce, .action = action, .delegation = self.delegation, .closure = self.closure, .borrow = self.borrow, .lease = self.lease, .transaction = self.transaction };
    const authority: wire.AuthorizationClient = .{ .transport = self.authority, .realm = self.connection.scope.realm, .principal = if (self.borrow) |borrow| borrow.binding.executor else if (self.delegation) |delegation| delegation.binding.executor else self.connection.principal, .role = if (self.delegation != null) null else self.connection.role, .key = self.key };
    const context = try w.Request.context(input, self.allocator);
    const proof = if (self.credential_epoch) |epoch|
        try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = authority.realm, .principal = authority.principal, .credential_epoch = epoch, .role = authority.role, .audience = self.connection.audience, .context = context }, self.key)
    else
        (try authority.proof(self.connection.audience, context)).signed;
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = input.delegation, .closure = input.closure, .borrow = input.borrow, .lease = input.lease, .transaction = input.transaction, .proof = proof };
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
    // Local signing and request validation have succeeded. Entering the
    // mutating transport is conservative evidence of possible acceptance,
    // including failure before a response can prove what actually happened.
    if (self.attempt) |attempt| attempt.begin(request);
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
    const selection = if (self.delegation) |grant| grant.binding.selection else .exact;
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
            if (state.retired) return;
            if (selection == .exact and state.position.next_lsn > expected.next_lsn) return;
            if (state.position.next_lsn < expected.next_lsn) return error.InvalidTableResponse;
            if (self.delegation) |grant| {
                const original = grant.binding.interpretation;
                // Definitions advance monotonically. With no accepted pin,
                // a later definition permanently excludes this acquisition,
                // even when its selection allowed a later data frontier.
                if (state.interpretation.revision > original.revision) return;
                if (!std.meta.eql(state.interpretation, original)) return error.InvalidTableResponse;
            }
        }
        // An unknown handle must be recovered through the original acquisition
        // to verify its retained frontier. A matching owner alone is not enough.
        const acquisition: w.Acquisition = .{ .object = object, .owner = owner, .expected = expected, .selection = selection };
        const pinned = try self.call(if (retention == .history) .{ .retain_history = acquisition } else .{ .pin = acquisition });
        defer pinned.deinit();
        if (handle) |observed| if (!std.meta.eql(observed, pinned.value.result.pin)) return error.InvalidTableResponse;
        handle = pinned.value.result.pin;
    }
    const released = try self.call(.{ .release = .{ .object = object, .handle = handle.? } });
    defer released.deinit();
}
