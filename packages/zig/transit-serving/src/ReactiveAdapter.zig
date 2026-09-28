//! Current authorization and watch acquisition through public clients only.
const std = @import("std");
const root = @import("root.zig");
const r = root.ReactiveModel;
const p = root.protocol;
const Self = @This();
base: root.Adapter,
/// Returns a conservative upper bound on wall clock milliseconds. The host owns
/// clock qualification; it must fail if its configured bound is unavailable.
clock: struct { context: ?*anyopaque, upper: *const fn (?*anyopaque) anyerror!u64 },
pub const Outcome = struct { operation: u64, phase: root.Model.Phase, resolution_input: u64 };
pub const Event = struct {
    source_changed: bool,
    resource: u64,
    data_revision: u64,
    outcome: ?Outcome = null,
};
pub const Response = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u8 = 1,
    session: r.Session,
    source: ?r.Source = null,
    snapshot: ?root.TableWatch.Snapshot = null,
    event: ?Event = null,
    cursor: ?r.Cursor = null,
};
const Context = struct { session: r.Session, source: ?r.Source, policy_revision: u64 };
fn context(self: Self, signed: r.SignedRead, public_key: [32]u8) !Context {
    const scope = signed.read.scope;
    if (scope.realm != self.base.resources.realm or scope.service != self.base.service or scope.ingress != self.base.ingress) return error.ServingDenied;
    try signed.verify(public_key);
    try self.base.authorize(signed.identity.native(), public_key);
    var scoped = try self.base.readerFor(scope.principal, &.{
        root.Model.key('S', scope.principal, scope.session), root.Model.key('W', 0, 0), root.Model.key('b', 0, 0),
    });
    const value = (try root.ReactiveService.session(&scoped.data, scope.principal, scope.session)) orelse return error.ReactiveSessionNotFound;
    if (value.principal != scope.principal or value.session != scope.session or value.generation != scope.generation) return error.ReactiveGenerationConflict;
    const source = try root.ReactiveService.source(&scoped.data);
    if (signed.read.kind != .session) {
        if (value.phase != .open or value.lease_before_ms <= try self.clock.upper(self.clock.context)) return error.ReactiveSessionExpired;
        if (value.attachment != signed.read.attachment or !std.mem.eql(u8, &value.nonce, &signed.read.nonce)) return error.ReactiveAttachmentConflict;
        if (value.subscription != scope.subscription or value.subscription_generation != scope.subscription_generation) return error.ReactiveSubscriptionConflict;
        const watch = source orelse return error.ReactiveResetRequired;
        if (!watch.published or watch.revision != value.source_revision) return error.ReactiveResetRequired;
        const binding = (try root.Service.binding(&scoped.data)) orelse return error.ServiceUnpublished;
        if (!binding.published or binding.target != watch.target) return error.ServiceUnpublished;
    }
    return .{ .session = value, .source = source, .policy_revision = scoped.policy.revision };
}
fn sourceReader(self: Self, source: r.Source) !root.station.client.ResourceReader.Reader {
    const response = try self.base.resources.query(.{ .resource = source.resource });
    const metadata = response.body.resource;
    if (metadata.id != source.resource or metadata.writer != source.target or metadata.phase != .active) return error.ResourceUnavailable;
    return .{ .client = self.base.resources, .view = .{ .resource = source.resource, .revision = metadata.revision } };
}
const Acquisition = struct { response: Response, observation: ?root.TableWatch.Observation = null };
pub fn read(self: Self, signed: r.SignedRead, public_key: [32]u8) !Response {
    return (try self.acquire(signed, public_key)).response;
}
fn acquire(self: Self, signed: r.SignedRead, public_key: [32]u8) !Acquisition {
    for (0..3) |_| return self.readOnce(signed, public_key) catch |err| {
        if (err == error.Rejected or err == error.Conflict) switch (self.base.resources.wire.last_rejection orelse return err) {
            .StaleStateResource, .QueryExpired => continue,
            .StateResourceExpired, .DeadlineExpired, .RetiredProcess => return error.ResourceUnavailable,
            else => {},
        };
        return err;
    };
    return error.ServiceReadConflict;
}
fn readOnce(self: Self, signed: r.SignedRead, public_key: [32]u8) !Acquisition {
    const before = try self.context(signed, public_key);
    var result: Response = .{ .session = before.session, .source = before.source };
    var acquired: ?root.TableWatch.Observation = null;
    if (signed.read.kind != .session) {
        const source = before.source.?;
        var reader = try self.sourceReader(source);
        const observation = if (signed.read.kind == .snapshot) blk: {
            result.snapshot = try root.TableWatch.snapshot(&reader, source);
            break :blk result.snapshot.?.observation;
        } else try root.TableWatch.observe(&reader, source);
        acquired = observation;
        var outcome: ?Outcome = null;
        if (before.session.operation != 0) {
            var scoped = try self.base.reader(signed.read.scope.principal);
            if (try root.Service.operation(&scoped.data, signed.read.scope.principal, before.session.operation)) |operation| {
                if (operation.phase != .admitted) outcome = .{ .operation = operation.operation, .phase = operation.phase, .resolution_input = operation.resolution_input };
            }
        }
        const position: r.Position = .{ .scope = signed.read.scope, .watch_revision = source.revision, .resource = source.resource, .schema = source.schema, .data_revision = observation.data_revision, .outcome_position = if (outcome) |v| v.resolution_input else 0 };
        var changed = true;
        var outcome_changed = outcome != null;
        if (signed.read.cursor) |cursor| {
            try cursor.verify(self.base.resources.key.public_key.toBytes());
            try root.TableWatch.validateResume(cursor.position, signed.read.scope, source, observation, position.outcome_position);
            changed = cursor.position.data_revision < position.data_revision;
            outcome_changed = cursor.position.outcome_position < position.outcome_position;
        }
        if (signed.read.kind == .events and (changed or outcome_changed)) result.event = .{ .source_changed = changed, .resource = source.resource, .data_revision = position.data_revision, .outcome = if (outcome_changed) outcome else null };
        result.cursor = try r.Cursor.sign(position, self.base.resources.key);
        // Current source authority/lifecycle/schema after copying bounded bytes.
        // Newer data is safely reported by the next poll; a changed declaration
        // cannot disclose a page from the previous schema.
        var latest = try self.sourceReader(source);
        const current = try root.TableWatch.observe(&latest, source);
        if (current.data_revision < observation.data_revision) return error.ReactiveResetRequired;
    }
    const after = try self.context(signed, public_key);
    if (!std.meta.eql(before, after)) return error.ServiceReadConflict;
    return .{ .response = result, .observation = acquired };
}

/// Verify the new socket's proof before forwarding the caller's exact attach
/// bytes. The host must first consume its own single-use challenge. Native
/// acceptance is returned separately from observing the attachment commit.
pub fn attach(self: Self, bootstrap: root.ReactiveWire.Bootstrap, public_key: [32]u8) !root.Adapter.Receipt {
    if (bootstrap.version != 1 or bootstrap.read.read.kind != .events) return error.InvalidReactiveScope;
    try bootstrap.read.verify(public_key);
    const request = bootstrap.read.read;
    const native = bootstrap.attach.native();
    if (native.request.realm != request.scope.realm or native.request.principal != request.scope.principal or native.request.command.send.pid != request.scope.ingress) return error.ServingDenied;
    const frame = try root.station.Frame.decode(native.request.command.send.value);
    if (frame.kind != .cast) return error.InvalidServingCommand;
    const command = try root.Model.Command.decode(frame.payload);
    if (command != .reactive or command.reactive != .attach) return error.InvalidServingCommand;
    const attachment = command.reactive.attach;
    if (attachment.identity.session != request.scope.session or attachment.identity.generation != request.scope.generation or
        request.attachment == 0 or attachment.expected != request.attachment - 1 or !std.mem.eql(u8, &attachment.nonce, &request.nonce)) return error.InvalidReactiveScope;
    if (request.scope.realm != self.base.resources.realm or request.scope.service != self.base.service or request.scope.ingress != self.base.ingress) return error.ServingDenied;
    try self.base.authorize(bootstrap.read.identity.native(), public_key);
    var scoped = try self.base.readerFor(request.scope.principal, &.{root.Model.key('S', request.scope.principal, request.scope.session)});
    const value = (try root.ReactiveService.session(&scoped.data, request.scope.principal, request.scope.session)) orelse return error.ReactiveSessionNotFound;
    if (value.generation != request.scope.generation) return error.ReactiveGenerationConflict;
    if (value.phase != .open or value.lease_before_ms <= try self.clock.upper(self.clock.context)) return error.ReactiveSessionExpired;
    return self.base.submit(native, public_key);
}

/// Revalidate an attachment immediately before a bounded transport release.
pub fn check(self: Self, signed: r.SignedRead, public_key: [32]u8) !void {
    for (0..3) |_| return self.checkOnce(signed, public_key) catch |err| {
        if (err == error.Rejected or err == error.Conflict) switch (self.base.resources.wire.last_rejection orelse return err) {
            .StaleStateResource, .QueryExpired => continue,
            .StateResourceExpired, .DeadlineExpired, .RetiredProcess => return error.ResourceUnavailable,
            else => {},
        };
        return err;
    };
    return error.ServiceReadConflict;
}
fn checkOnce(self: Self, signed: r.SignedRead, public_key: [32]u8) !void {
    const current = try self.context(signed, public_key);
    if (signed.read.kind == .session) return error.InvalidReactiveScope;
    var data = try self.sourceReader(current.source.?);
    _ = try root.TableWatch.observe(&data, current.source.?);
}

pub fn discovery(self: Self, signed: root.Model.SignedRead, public_key: [32]u8, allocator: std.mem.Allocator) !root.Api.Discovery {
    if (signed.read.kind != .discovery) return error.InvalidServingRead;
    const base = try self.base.read(signed, public_key);
    const binding = base.binding orelse return error.ServiceUnpublished;
    var scoped = try self.base.readerFor(signed.read.principal, &.{root.Model.key('W', 0, 0)});
    const source = (try root.ReactiveService.source(&scoped.data)) orelse return error.ServiceUnpublished;
    if (!source.published or !binding.published or source.target != binding.target) return error.ServiceUnpublished;
    var data = try self.sourceReader(source);
    _ = try root.TableWatch.observe(&data, source);
    const result: root.Api.Discovery = .{ .service = self.base.service, .ingress = self.base.ingress, .resource = self.base.resource, .binding_revision = binding.revision, .watch_revision = source.revision, .openapi_sha256 = try root.Api.digest(.openapi, allocator), .asyncapi_sha256 = try root.Api.digest(.asyncapi, allocator) };
    const latest = try self.base.read(signed, public_key);
    if (latest.policy_revision != base.policy_revision or !std.meta.eql(latest.binding, base.binding)) return error.ServiceReadConflict;
    scoped = try self.base.readerFor(signed.read.principal, &.{root.Model.key('W', 0, 0)});
    if (!std.meta.eql(source, (try root.ReactiveService.source(&scoped.data)) orelse return error.ServiceUnpublished)) return error.ServiceReadConflict;
    return result;
}

/// Metadata-only projection of the same authorized acquisition as snapshot/events.
/// Reuse its exact observation and final authority check; a second independent
/// observation both adds I/O and needlessly widens the concurrent-write window.
pub fn inspect(self: Self, signed: r.SignedRead, public_key: [32]u8) !root.ReactiveClient.Response {
    if (signed.read.kind != .events) return error.InvalidReactiveScope;
    const result = try self.acquire(signed, public_key);
    return .{ .inspection = .{ .response = result.response, .observation = result.observation.? } };
}
