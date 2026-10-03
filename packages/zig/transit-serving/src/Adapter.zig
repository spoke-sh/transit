//! Protocol-neutral gateway seam. One instance/client per live request; current
//! service authorization and durable state are public authority/Station reads.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const g = p.Growth;
const m = root.Model;
const Self = @This();
resources: root.station.client.ResourceReader,
service: u64,
ingress: u64,
resource: u64,
pub const Stage = enum { ingress_accepted, not_observed, service_admitted, completed, cancelled, timed_out, failed, rejected };
pub const Receipt = struct { stage: Stage = .ingress_accepted, receipt: p.Receipt };
pub const ReadResult = struct {
    service: u64,
    resource: u64,
    revision: u64,
    policy_revision: u64,
    stage: Stage = .not_observed,
    binding: ?m.Binding = null,
    operation: ?m.Operation = null,
    disposition: ?root.ServingFailure.Disposition = null,
    capabilities: struct { http: bool = true, sse: bool = false, websocket: bool = false, grpc: bool = false, flight: bool = false } = .{},
};
pub fn submit(self: Self, signed: g.SignedRequest, public_key: [32]u8) !Receipt {
    if (signed.request.realm != self.resources.realm or signed.request.principal == 0 or signed.request.command != .send or signed.request.command.send.pid != self.ingress) return error.ServingDenied;
    try p.Ed25519.Signature.fromBytes(signed.signature).verify(&try g.digest(signed.request), try p.Ed25519.PublicKey.fromBytes(public_key));
    const frame = try root.station.Frame.decode(signed.request.command.send.value);
    if (frame.kind != .cast) return error.InvalidServingCommand;
    _ = try m.Command.decode(frame.payload);
    // No native sequence is prepared here; 202 proves this native send only.
    const receipt = self.resources.wire.submit(signed) catch |err| {
        if (err == error.Rejected or err == error.Conflict) switch (self.resources.wire.last_rejection orelse return err) {
            .ConflictingRetry, .SequenceGap, .RetryHorizonExceeded => return error.ServingSequenceConflict,
            .StateResourceExpired, .DeadlineExpired, .RetiredProcess => return error.ResourceUnavailable,
            else => return err,
        };
        return err;
    };
    if (receipt.position == 0 or receipt.position > p.max_counter) return error.InvalidServingReceipt;
    return .{ .receipt = receipt };
}
fn identity(self: Self, signed: m.SignedRead, public_key: [32]u8) !void {
    if (signed.read.realm != self.resources.realm or signed.read.service != self.service or signed.read.ingress != self.ingress) return error.ServingDenied;
    try signed.verify(public_key);
    try self.authorize(signed.identity.native(), public_key);
}
pub fn authorize(self: Self, signed: g.SignedQuery, public_key: [32]u8) !void {
    if (signed.query.realm != self.resources.realm or signed.query.kind != .identity) return error.ServingDenied;
    try p.Ed25519.Signature.fromBytes(signed.signature).verify(&try g.queryDigest(signed.query), try p.Ed25519.PublicKey.fromBytes(public_key));
    const response = try self.resources.wire.call(g.Response, "/v1/query", signed);
    try g.validateResponse(response, signed.query);
    const current = response.body.identity;
    if (current.principal != signed.query.principal or current.pid != self.ingress or current.permissions & p.permission(.inspect) == 0) return error.ServingDenied;
}
pub fn reader(self: Self, principal: u64) !struct { data: root.station.client.ResourceReader.Reader, policy: m.Policy } {
    const response = try self.resources.query(.{ .resource = self.resource });
    const metadata = response.body.resource;
    if (metadata.writer != self.ingress or metadata.id != self.resource or metadata.phase != .active) return error.ResourceUnavailable;
    var data: root.station.client.ResourceReader.Reader = .{ .client = self.resources, .view = .{ .resource = self.resource, .revision = metadata.revision } };
    const config_value = (try data.read(m.key('c', 0, 0))) orelse return error.ServiceUnpublished;
    if ((try root.Codec.decode(m.Configuration, 'g', config_value)).service != self.service) return error.ServingDenied;
    const policy = (try root.Service.policy(&data, principal)) orelse return error.ServingDenied;
    if (!policy.reads) return error.ServingDenied;
    return .{ .data = data, .policy = policy };
}
/// Acquire service configuration/policy and the caller's bounded key set at
/// one native cut. Returned bytes are local evidence for this acquisition only.
pub fn readerFor(self: Self, principal: u64, extra: []const p.Value) !struct { data: root.station.client.ResourceReader.Batch, policy: m.Policy } {
    if (extra.len > g.page_size - 2) return error.InvalidResourceRead;
    var keys: [g.page_size]p.Value = undefined;
    keys[0] = m.key('c', 0, 0);
    keys[1] = m.key('p', principal, 0);
    @memcpy(keys[2..][0..extra.len], extra);
    var data = try self.resources.readBatch(self.resource, null, keys[0 .. 2 + extra.len]);
    if (data.resource.writer != self.ingress) return error.ResourceUnavailable;
    const config = (try data.read(keys[0])) orelse return error.ServiceUnpublished;
    if ((try root.Codec.decode(m.Configuration, 'g', config)).service != self.service) return error.ServingDenied;
    const policy = (try root.Service.policy(&data, principal)) orelse return error.ServingDenied;
    if (!policy.reads) return error.ServingDenied;
    return .{ .data = data, .policy = policy };
}
pub fn read(self: Self, signed: m.SignedRead, public_key: [32]u8) !ReadResult {
    for (0..3) |_| return self.readOnce(signed, public_key) catch |err| {
        if ((err == error.Rejected or err == error.Conflict) and (self.resources.wire.last_rejection == .StaleStateResource or self.resources.wire.last_rejection == .QueryExpired)) continue;
        if ((err == error.Rejected or err == error.Conflict) and self.resources.wire.last_rejection == .StateResourceExpired) return error.ResourceUnavailable;
        return err;
    };
    return error.ServiceReadConflict;
}
fn readOnce(self: Self, signed: m.SignedRead, public_key: [32]u8) !ReadResult {
    try self.identity(signed, public_key);
    const address = switch (signed.read.kind) {
        .discovery => m.key('b', 0, 0),
        .disposition => m.key('e', signed.read.principal, signed.read.operation),
        .status, .result => m.key('o', signed.read.principal, signed.read.operation),
    };
    var scoped = try self.readerFor(signed.read.principal, &.{address});
    var result: ReadResult = .{ .service = self.service, .resource = self.resource, .revision = scoped.data.view.revision, .policy_revision = scoped.policy.revision };
    switch (signed.read.kind) {
        .discovery => result.binding = try root.Service.binding(&scoped.data),
        .disposition => {
            result.disposition = try root.ServingFailure.read(&scoped.data, self.resources.realm, self.resource, self.service, signed.read.principal, signed.read.operation);
            if (result.disposition != null) result.stage = .rejected;
        },
        .status, .result => {
            const operation = (try root.Service.operation(&scoped.data, signed.read.principal, signed.read.operation)) orelse return error.ServingOperationNotFound;
            if (operation.principal != signed.read.principal or operation.operation != signed.read.operation) return error.InvalidServingRecord;
            if (signed.read.kind == .result and operation.phase != .completed) return error.ServingResultPending;
            result.operation = operation;
            result.stage = switch (operation.phase) {
                .admitted => .service_admitted,
                .completed => .completed,
                .cancelled => .cancelled,
                .timed_out => .timed_out,
                .failed => .failed,
            };
        },
    }
    // Protected bytes have been copied but not disclosed. Recheck native identity
    // and current resource/service policy at the final bounded read boundary.
    try self.identity(signed, public_key);
    const latest = try self.readerFor(signed.read.principal, &.{});
    if (latest.policy.revision != scoped.policy.revision) return error.ServiceReadConflict;
    return result;
}
