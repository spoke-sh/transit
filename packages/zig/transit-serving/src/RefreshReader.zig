//! Current scoped authority and finite result evidence for the durable scheduler.
//! The owning host provides its authenticated reader and bounded scratch space.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const q = root.query;
const Self = @This();
resources: root.station.client.ResourceReader,
ingress: u64,
resource: u64,
scratch: []u8,

fn signedQuery(self: Self, principal: u64, kind: @FieldType(p.Growth.Query, "kind"), signature: [64]u8) !p.Growth.Response {
    const request: p.Growth.SignedQuery = .{ .query = .{ .realm = self.resources.realm, .principal = principal, .kind = kind }, .signature = signature };
    // The authority validates each signature against the caller's current key
    // and grant. A retained proof is neither an access token nor a cached grant.
    const response = self.resources.wire.call(p.Growth.Response, "/v3/query", request) catch |err| {
        if (err == error.Rejected or err == error.Conflict) switch (self.resources.wire.last_rejection orelse return err) {
            .AccessDenied, .Forbidden => return error.ServingDenied,
            .StateResourceExpired, .UnknownStateResource, .DeadlineExpired, .RetiredProcess => return error.ResourceUnavailable,
            else => {},
        };
        return err;
    };
    try p.Growth.validateResponse(response, request.query);
    return response;
}
pub fn authorize(self: Self, principal: u64, source: root.ReactiveModel.Source, proof: root.RefreshModel.Proof) !void {
    const identity = (try self.signedQuery(principal, .identity, proof.identity)).body.identity;
    const permissions = p.permission(.inspect) | p.permission(.send);
    if (identity.principal != principal or identity.pid != self.ingress or identity.permissions & permissions != permissions) return error.ServingDenied;
    const source_resource = (try self.signedQuery(principal, .{ .read_access = source.resource }, proof.source)).body.read_access;
    const request_resource = (try self.signedQuery(principal, .{ .read_access = self.resource }, proof.requester)).body.read_access;
    if (source_resource.writer != source.target or source_resource.phase != .active or request_resource.writer != self.ingress or request_resource.phase != .active) return error.ResourceUnavailable;
}
pub fn observe(self: Self, source: root.ReactiveModel.Source) !root.TableWatch.Observation {
    var reader = try self.resources.open(source.resource);
    return root.TableWatch.observe(&reader, source);
}
pub fn result(self: Self, turn: *root.station.GrowingTurn, namespace: u64, source: root.ReactiveModel.Source) !q.fuze.Unified.Basis {
    if (turn.view.resource != self.resource or turn.delivery.pid != self.ingress) return error.ServingDenied;
    const status = (try q.UnifiedUpload.status(turn, namespace)) orelse return error.InvalidRefreshTemplate;
    if (status.phase != .complete or status.manifest == null) return error.InvalidRefreshTemplate;
    var fixed = std.heap.FixedBufferAllocator.init(self.scratch);
    const opened = try q.UnifiedResult.open(status.manifest.?, .{ .resource = source.resource, .source = source.target, .requester = self.ingress, .correlation = status.correlation, .request = status.reference }, self.resources, fixed.allocator());
    return opened.manifest.checkpoint.progress.basis;
}
