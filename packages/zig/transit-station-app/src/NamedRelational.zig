//! Immutable names and explicit activation above the existing query owners.
//! Namespace metadata grants no native or Table access. Explicit activation
//! delegates to the query owner with its original direct source grants.
const std = @import("std");
const root = @import("root.zig");
const q = root.query;
const s = root.station;
const p = root.protocol;
const r = root.NamedRelationalRecords;
const Self = @This();
configuration: r.Configuration,
pub const Proposal = r.Proposal;
pub const Started = union(enum) { captured: q.RelationalRecords.Job, maintained: q.RelationalMaintenanceRecords.Head };
/// Administrative wire ingress. Infrastructure errors leave the input unresolved;
/// applications may record their own bounded rejected-control dispositions.
pub fn control(self: Self, turn: *s.Turn, workspace: []u8) !void {
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast) return error.InvalidNamedQuery;
    switch (try r.Control.decode(frame.payload)) {
        .initialize => try self.initialize(turn),
        .publish => |proposal| {
            _ = try self.publish(turn, proposal, workspace);
        },
        .authorize => |permission| {
            _ = try self.authorize(turn, permission.reference, permission.expected, permission.principal, permission.allow);
        },
    }
}

fn scoped(self: Self, turn: *s.Turn) !void {
    try self.configuration.validate();
    const scope = self.configuration.scope;
    if (turn.delivery.realm != scope.realm or turn.delivery.pid != scope.owner or turn.view.resource != scope.resource) return error.InvalidNamedQuery;
}
fn administrator(self: Self, turn: *s.Turn) !void {
    try self.scoped(turn);
    const principal = switch (turn.delivery.input.origin) {
        .external => |origin| origin.principal,
        else => return error.NamedQueryDenied,
    };
    if (principal != self.configuration.administrator) return error.NamedQueryDenied;
}
fn configured(self: Self, source: anytype) !void {
    try self.configuration.validate();
    if (source.view.resource != self.configuration.scope.resource) return error.InvalidNamedQuery;
    const stored = try r.decodeRecord(r.Configuration, "NRC1", (try source.read(r.key('c', self.configuration.scope.namespace, null, null))) orelse return error.NamedQueryUninitialized);
    try stored.validate();
    if (!std.meta.eql(stored, self.configuration)) return error.NamedQueryConfigurationChanged;
}
fn fresh(turn: *s.Turn) !void {
    for (turn.decision.mutations) |slot| if (slot != null) return error.QueryAfterMutation;
}
pub fn initialize(self: Self, turn: *s.Turn) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.administrator(turn);
    const key = r.key('c', self.configuration.scope.namespace, null, null);
    if (try turn.read(key) != null) return self.configured(turn);
    try fresh(turn);
    const budget_key = r.key('b', self.configuration.scope.namespace, null, null);
    if (try turn.read(budget_key) != null) return error.InvalidNamedQuery;
    try turn.write(key, try r.encodeRecord("NRC1", self.configuration));
    try turn.write(budget_key, try r.encodeRecord("NRB1", r.Budget{ .records = 2, .bytes = 144 }));
}
pub fn budget(self: Self, source: anytype) !r.Budget {
    try self.configured(source);
    const value = try r.decodeRecord(r.Budget, "NRB1", (try source.read(r.key('b', self.configuration.scope.namespace, null, null))) orelse return error.InvalidNamedQuery);
    if (value.records < 2 or value.records > self.configuration.records or value.bytes < 144 or value.bytes > self.configuration.bytes) return error.InvalidNamedQuery;
    return value;
}
fn reserve(self: Self, turn: *s.Turn, records: u64, bytes: u64) !void {
    const old = try self.budget(turn);
    if (records > self.configuration.records - old.records or bytes > self.configuration.bytes - old.bytes) return error.NamedQueryQuota;
    try turn.write(r.key('b', self.configuration.scope.namespace, null, null), try r.encodeRecord("NRB1", r.Budget{ .records = old.records + records, .bytes = old.bytes + bytes }));
}
pub fn lookup(self: Self, source: anytype, name: r.Name) !?r.Reference {
    try self.configured(source);
    const value = (try source.read(try r.nameKey(self.configuration.scope.namespace, name))) orelse return null;
    const reference = try r.Reference.decode(value);
    if (!std.meta.eql(reference.identity.scope, self.configuration.scope) or !std.meta.eql(reference.identity.name, name)) return error.InvalidNamedQuery;
    _ = try self.definition(source, reference);
    return reference;
}
pub fn definition(self: Self, source: anytype, reference: r.Reference) !r.Definition {
    try reference.validate();
    try self.configured(source);
    if (!std.meta.eql(reference.identity.scope, self.configuration.scope)) return error.InvalidNamedQuery;
    const stored = try r.decodeRecord(r.Definition, "NRD1", (try source.read(r.definitionKey(reference.identity))) orelse return error.NamedQueryNotFound);
    if (!std.meta.eql(try stored.reference(), reference)) return error.NamedQueryChanged;
    return stored;
}
fn requestBytes(view: anytype, reference: s.PublicationReference, bytes: []u8) ![]const u8 {
    var cursor = try reference.publication().open(view, reference.record);
    if (!std.meta.eql(cursor.spec, reference.spec) or reference.spec.length > bytes.len) return error.PublicationReferenceChanged;
    var offset: usize = 0;
    while (true) {
        const part = try reference.publication().read(view, cursor);
        if (part.bytes.len > reference.spec.length - offset) return error.InvalidQueryBundle;
        @memcpy(bytes[offset..][0..part.bytes.len], part.bytes.slice());
        offset += part.bytes.len;
        cursor = part.next orelse break;
    }
    if (offset != reference.spec.length) return error.InvalidQueryBundle;
    return bytes[0..offset];
}
/// Publish only metadata: no source data capture, query start, or policy update.
/// Exact retries read their original revision before considering the live head.
pub fn publish(self: Self, turn: *s.Turn, proposal: Proposal, workspace: []u8) !r.Reference {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.administrator(turn);
    try self.configured(turn);
    try fresh(turn);
    try q.RelationalBundle.checkReference(proposal.request);
    const identity: r.Identity = .{ .scope = self.configuration.scope, .name = proposal.name, .object = proposal.object, .revision = std.math.add(u64, proposal.expected, 1) catch return error.InvalidNamedQuery };
    try identity.validate();
    if (proposal.peer == 0) return error.InvalidNamedQuery;
    if (try turn.read(r.definitionKey(identity))) |value| {
        const existing = try r.decodeRecord(r.Definition, "NRD1", value);
        if (!std.meta.eql(existing.identity, identity) or existing.peer != proposal.peer or !std.meta.eql(existing.request, proposal.request)) return error.NamedQueryConflict;
        return existing.reference();
    }
    const old = try self.lookup(turn, proposal.name);
    if (old) |head| {
        if (head.identity.object != proposal.object or head.identity.revision != proposal.expected) return error.NamedQueryConflict;
    } else {
        if (proposal.expected != 0) return error.NamedQueryConflict;
        var first = identity;
        first.revision = 1;
        if (try turn.read(r.definitionKey(first)) != null) return error.NamedQueryConflict;
    }
    var view = try turn.captured(proposal.request.resource);
    const descriptor = try proposal.request.publication().inspect(&view, proposal.request.record);
    if (descriptor.publisher != proposal.peer or descriptor.state != .published or !std.meta.eql(descriptor.spec, proposal.request.spec)) return error.UnexpectedQueryPublisher;
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace);
    const bundle = try q.RelationalBundle.decodeInto(fixed.allocator(), try requestBytes(&view, proposal.request, &bytes));
    for (bundle.sources) |source| if (source.scope.realm != identity.scope.realm) return error.RelationalSourceChanged;
    try view.requireCurrent();
    const definition_value: r.Definition = .{ .identity = identity, .peer = proposal.peer, .request = proposal.request, .version = try view.retain(), .fingerprint = try bundle.fingerprint(), .lifetime = bundle.plan.lifetime };
    const encoded = try r.encodeRecord("NRD1", definition_value);
    const reference = try definition_value.reference();
    const head_value = try reference.encode();
    const retained_bytes = std.math.add(u64, encoded.len, proposal.request.spec.length) catch return error.NamedQueryQuota;
    try self.reserve(turn, if (old == null) 2 else 1, std.math.add(u64, retained_bytes, if (old == null) head_value.len else 0) catch return error.NamedQueryQuota);
    try turn.write(r.definitionKey(identity), encoded);
    try turn.write(try r.nameKey(identity.scope.namespace, identity.name), head_value);
    try turn.validate();
    return reference;
}
/// Bind one exact named revision to the next query policy revision. Archive and
/// current policy share the same commit; the immutable archive grants no rights.
pub fn authorize(self: Self, turn: *s.Turn, reference: r.Reference, expected: u64, principal: u64, allow: bool) !r.Activation {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.administrator(turn);
    try fresh(turn);
    const definition_value = try self.definition(turn, reference);
    const next = std.math.add(u64, expected, 1) catch return error.InvalidNamedQuery;
    const policy: q.RelationalRecords.Policy = .{ .peer = definition_value.peer, .requests = definition_value.request.resource, .principal = principal, .revision = next, .request = definition_value.fingerprint, .allow = allow };
    _ = try policy.encode();
    const archive: r.Authorization = .{ .identity = reference.identity, .digest = reference.digest, .policy = policy };
    const encoded = try r.encodeRecord("NRP1", archive);
    const key = r.authorizationKey(policy.peer, next);
    if (try turn.read(key)) |existing| {
        if (!existing.eql(encoded)) return error.NamedQueryConflict;
        return .{ .reference = reference, .policy_revision = next };
    }
    const current = try q.RelationalCapture.policy(turn, policy.peer);
    if ((if (current) |value| value.revision else 0) != expected) return error.NamedQueryConflict;
    try self.reserve(turn, 1, encoded.len);
    try q.RelationalCapture.setPolicy(turn, policy);
    try turn.write(key, encoded);
    try turn.validate();
    return .{ .reference = reference, .policy_revision = next };
}
/// Permanent attribution for a query root's original peer and policy revision.
/// Metadata read only: the caller still uses the query reader for result rights.
pub fn attribution(self: Self, source: anytype, peer: u64, policy_revision: u64) !r.Reference {
    const archive = try r.decodeRecord(r.Authorization, "NRP1", (try source.read(r.authorizationKey(peer, policy_revision))) orelse return error.NamedQueryNotFound);
    _ = try archive.policy.encode();
    if (archive.policy.peer != peer or archive.policy.revision != policy_revision) return error.InvalidNamedQuery;
    const reference: r.Reference = .{ .definition = p.Growth.current_definition, .identity = archive.identity, .digest = archive.digest };
    const definition_value = try self.definition(source, reference);
    if (definition_value.peer != peer or definition_value.request.resource != archive.policy.requests or !std.mem.eql(u8, &definition_value.fingerprint, &archive.policy.request)) return error.InvalidNamedQuery;
    return reference;
}
/// Resolve the definition of an actual captured result at its retained native
/// cut. Later name publication cannot relabel it. This consumes only the reader's
/// metadata budget; output coverage still requires its checked terminal next().
pub fn capturedDefinition(self: Self, result: *q.RelationalResult) !r.Definition {
    try self.configuration.validate();
    try result.check();
    const scope = self.configuration.scope;
    if (scope.realm != result.source.client.realm or scope.owner != result.stored.request_version.pid or scope.resource != result.source.view.resource) return error.NamedQueryChanged;
    var metadata: ResultMetadata = .{ .result = result, .view = result.source.view };
    const reference = try self.attribution(&metadata, result.stored.destination, result.stored.policy_revision);
    const found = try self.definition(&metadata, reference);
    if (found.lifetime != .captured or !std.meta.eql(found.request, result.stored.request) or
        !std.mem.eql(u8, &found.fingerprint, &try result.bundle.fingerprint())) return error.NamedQueryChanged;
    try result.check();
    return found;
}
const ResultMetadata = struct {
    result: *q.RelationalResult,
    view: @FieldType(s.client.SnapshotReader, "view"),
    pub fn read(self: *ResultMetadata, key: p.Value) !?p.Value {
        if (self.result.requests >= self.result.request_limit) return error.QueryPageBudget;
        self.result.requests += 1;
        var request: p.Growth.SnapshotRead.Query = .{ .snapshot = .{ .existing = self.result.source.snapshot.id } };
        request.points[0] = key;
        const response = try self.result.source.batch(request);
        try p.Growth.SnapshotRead.validateResult(response, request);
        return if (response.points[0]) |entry| entry.value else null;
    }
};
/// Resolve the original named definition of this retained maintained revision.
/// A later definition or successor revision cannot relabel its attribution.
/// Inspection does not consume rows/deltas, complete delivery or wake execution.
pub fn maintainedDefinition(self: Self, revision: *q.RelationalRevision) !r.Definition {
    try self.configuration.validate();
    try revision.check();
    const scope = self.configuration.scope;
    if (scope.realm != revision.source.client.realm or scope.owner != revision.stored.request_version.pid or scope.resource != revision.source.view.resource) return error.NamedQueryChanged;
    var metadata: RevisionMetadata = .{ .revision = revision, .view = revision.source.view };
    const reference = try self.attribution(&metadata, revision.stored.peer, revision.stored.policy_revision);
    const found = try self.definition(&metadata, reference);
    if (found.lifetime != .maintained or !std.meta.eql(found.request, revision.stored.request) or
        !std.mem.eql(u8, &found.fingerprint, &try revision.bundle.fingerprint())) return error.NamedQueryChanged;
    try revision.check();
    return found;
}
const RevisionMetadata = struct {
    revision: *q.RelationalRevision,
    view: @FieldType(s.client.SnapshotReader, "view"),
    pub fn read(self: *RevisionMetadata, key: p.Value) !?p.Value {
        if (self.revision.options.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
        if (self.revision.requests >= self.revision.options.requests) return error.QueryPageBudget;
        self.revision.requests += 1;
        var request: p.Growth.SnapshotRead.Query = .{ .snapshot = .{ .existing = self.revision.source.snapshot.id } };
        request.points[0] = key;
        const response = try self.revision.source.batch(request);
        try p.Growth.SnapshotRead.validateResult(response, request);
        return if (response.points[0]) |entry| entry.value else null;
    }
};
pub fn activate(self: Self, turn: *s.Turn, activation: r.Activation, clients: []const q.catalog.DirectTableClient, workspace: []u8) !Started {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.scoped(turn);
    try fresh(turn);
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .call or !frame.payload.eql(try activation.encode())) return error.ExpectedCall;
    const peer = try s.Frame.source(turn.delivery.input);
    const definition_value = try self.definition(turn, activation.reference);
    if (peer != definition_value.peer) return error.NamedQueryDenied;
    if (!std.meta.eql(activation.reference, try self.attribution(turn, peer, activation.policy_revision))) return error.NamedQueryChanged;
    const current = (try q.RelationalCapture.policy(turn, peer)) orelse return error.QueryDenied;
    const archive = try r.decodeRecord(r.Authorization, "NRP1", (try turn.read(r.authorizationKey(peer, activation.policy_revision))).?);
    if (!current.allow or !std.meta.eql(current, archive.policy)) return error.QueryDenied;
    return switch (definition_value.lifetime) {
        .captured => .{ .captured = try q.RelationalCapture.start(turn, definition_value.request, clients, workspace) },
        .maintained => .{ .maintained = try q.RelationalMaintenance.start(turn, definition_value.request, clients, workspace) },
        .interactive => error.InvalidNamedQuery,
    };
}
