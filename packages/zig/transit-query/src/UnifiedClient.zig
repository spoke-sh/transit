//! Signed v2 caller operations. A Prepared command is frozen across uncertainty;
//! only an observed, committed upload step permits preparing its successor.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const r = q.UnifiedRecords;
const Self = @This();
wire: *q.wire.Client,
connection: Connection,
key: p.Ed25519.KeyPair,
pub const Connection = struct { realm: u64, principal: u64, source: u64, resource: u64, requester: u64, requests: u64 };
pub const Capabilities = struct {
    version: u8 = 2,
    source: u8 = 2,
    plan: u8 = 2,
    result: u8 = 2,
    bundle_bytes: u32 = q.Bundle.max_bytes,
    part_bytes: u16 = q.UnifiedRequest.part_bytes,
    segment_bytes: u32 = q.fuze.Unified.Arrow.segment_bytes,
    batch_rows: u8 = q.fuze.Unified.max_rows,
    columns: u8 = q.fuze.Unified.max_columns,
    kv: bool = true,
    table: bool = true,
    document: bool = true,
};
pub const Description = struct {
    capabilities: Capabilities = .{},
    definition: q.SourceDefinition,
    resource_revision: u64,
    policy_revision: u64,
    limits: q.Bundle.Limits,
    active: ?u64,
};
pub const Prepared = struct { version: u8 = 2, signed: g.SignedRequest };
pub const Observation = union(enum) { pending, committed, rejected: p.Value };
/// Only a stale observation may restart at a fresh current cut. This never
/// retries a signed mutation, denial or an unavailable resource.
pub fn readConflict(self: *Self, err: anyerror) bool {
    return err == error.QueryReadConflict or ((err == error.Rejected or err == error.Conflict) and (self.wire.last_rejection == .StaleStateResource or self.wire.last_rejection == .QueryExpired));
}
fn read(self: *Self, comptime operation: anytype, args: anytype) @typeInfo(@TypeOf(operation)).@"fn".return_type.? {
    for (0..3) |_| return @call(.auto, operation, .{self} ++ args) catch |err| {
        if (self.readConflict(err)) continue;
        return err;
    };
    return error.QueryReadConflict;
}
pub fn resources(self: *Self) q.wire.ResourceReader {
    return .{ .wire = self.wire, .realm = self.connection.realm, .principal = self.connection.principal, .key = self.key };
}
fn query(self: *Self, kind: @FieldType(g.Query, "kind")) !g.Response {
    return self.resources().query(kind);
}
fn checked(self: *Self, resource: u64, pid: u64) !q.wire.ResourceReader.Reader {
    const metadata = (try self.query(.{ .resource = resource })).body.resource;
    if (metadata.id != resource or metadata.writer != pid or metadata.phase != .active) return error.QuerySourceUnavailable;
    return .{ .client = self.resources(), .view = .{ .resource = resource, .revision = metadata.revision } };
}
fn requester(self: *Self) !q.wire.ResourceReader.Reader {
    var reader = try self.checked(self.connection.requests, self.connection.requester);
    try (q.UnifiedBehavior.Requester{ .principal = self.connection.principal, .source = self.connection.source }).check(&reader);
    return reader;
}
pub fn describe(self: *Self, definition: q.SourceDefinition) !Description {
    return self.read(describeOnce, .{definition});
}
fn describeOnce(self: *Self, definition: q.SourceDefinition) !Description {
    if (definition.resource != self.connection.resource) return error.QueryIdentityMismatch;
    var source = try self.checked(self.connection.resource, self.connection.source);
    var requests = try self.requester();
    const grant = (try q.UnifiedCapture.policy(&source, self.connection.requester)) orelse return error.QueryDenied;
    if (!grant.allow or grant.requests != self.connection.requests or !std.mem.eql(u8, &grant.declaration, &try q.Bundle.declaration(definition))) return error.QueryDenied;
    try q.UnifiedSource.checkCurrent(definition, &source);
    return .{ .definition = definition, .resource_revision = source.view.revision, .policy_revision = grant.revision, .limits = grant.limits, .active = try q.UnifiedUpload.active(&requests) };
}
/// Prepare only one command. After any uncertain submit, retain and resubmit
/// this object; do not call prepare/prepareNext to invent another sequence.
pub fn prepare(self: *Self, command: q.UnifiedRequest.Command) !Prepared {
    inline for (.{ "realm", "principal", "source", "resource", "requester", "requests" }) |name| try r.identity(@field(self.connection, name));
    if (command == .initialize) _ = try self.checked(self.connection.requests, self.connection.requester) else _ = try self.requester();
    if (command == .begin and command.begin.resource != self.connection.requests) return error.QueryIdentityMismatch;
    const payload = try command.encode();
    const sequence = (try self.query(.{ .capabilities = {} })).principal_sequence;
    return .{ .signed = try g.sign(.{ .realm = self.connection.realm, .principal = self.connection.principal, .sequence = try std.math.add(u64, sequence, 1), .command = .{ .send = .{ .pid = self.connection.requester, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, self.key) };
}
pub fn validate(self: *Self, prepared: Prepared) !void {
    const request = prepared.signed.request;
    if (prepared.version != 2 or request.realm != self.connection.realm or request.principal != self.connection.principal or request.command != .send or request.command.send.pid != self.connection.requester) return error.InvalidQueryRequest;
    const frame = try s.Frame.decode(request.command.send.value);
    if (frame.kind != .cast) return error.InvalidQueryRequest;
    const command = try q.UnifiedRequest.Command.decode(&frame.payload);
    if (command == .begin and command.begin.resource != self.connection.requests) return error.QueryIdentityMismatch;
}
pub fn submit(self: *Self, prepared: Prepared) !p.Receipt {
    try self.validate(prepared);
    // No fresh preparation or policy-dependent replacement of an uncertain
    // command. Node grants, requester identity and source policy remain live.
    return self.wire.submitGrowing(prepared.signed);
}
/// Receipt position is the requester input, not its ordinal. The public head
/// can prove that input is still pending or that all earlier input has committed.
pub fn observe(self: *Self, input: u64) !Observation {
    return self.read(observeOnce, .{input});
}
fn observeOnce(self: *Self, input: u64) !Observation {
    try r.identity(input);
    const response = try self.query(.{ .process = self.connection.requester });
    if (input > response.position) return error.InvalidQueryIdentity;
    const state = response.body.process;
    if (state.process.lifecycle != .running) return error.QueryRequesterUnavailable;
    if (state.process.failure != null) return error.QueryRequesterFailed;
    if (state.input) |head| if (head.position <= input) return .pending;
    var reader = try self.requester();
    if (try reader.read(r.key('e', input, 0))) |reason| return .{ .rejected = reason };
    return .committed;
}
pub fn status(self: *Self, namespace: u64) !?q.UnifiedRequest.Status {
    return self.read(statusOnce, .{namespace});
}
fn statusOnce(self: *Self, namespace: u64) !?q.UnifiedRequest.Status {
    var reader = try self.requester();
    return q.UnifiedUpload.status(&reader, namespace);
}
/// Canonical finite input must remain owned by the caller while uploading.
/// This selects one bounded next step from committed state. Invoke only after
/// observe confirms the preceding exact signed command has committed.
pub fn prepareNext(self: *Self, namespace: u64, bundle: q.Bundle) !?Prepared {
    try bundle.validate();
    const description = try self.describe(bundle.source);
    if (!description.limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
    const reference = try bundle.reference(self.connection.requests, namespace);
    var reader = try self.requester();
    const current = (try q.UnifiedUpload.status(&reader, namespace)) orelse return try self.prepare(.{ .begin = reference });
    if (!std.meta.eql(current.reference, reference)) return error.QueryUploadIdentityConflict;
    switch (current.phase) {
        .uploading => {
            const descriptor = try reference.publication().inspect(&reader, reference.record);
            if (!std.meta.eql(descriptor.spec, reference.spec) or descriptor.state != .staging) return error.InvalidQueryUpload;
            if (descriptor.written == descriptor.spec.chunks()) return try self.prepare(.{ .seal = namespace });
            var buffer: [q.Bundle.max_bytes]u8 = undefined;
            const bytes = try bundle.encode(&buffer);
            const chunk = bytes[descriptor.written * s.Publication.chunk_bytes ..][0..try descriptor.spec.size(descriptor.written)];
            const first = try reader.read(r.key('h', namespace, 0));
            if (first) |part| {
                if (chunk.len <= q.UnifiedRequest.part_bytes or part.len != q.UnifiedRequest.part_bytes or !std.mem.eql(u8, part.slice(), chunk[0..q.UnifiedRequest.part_bytes])) return error.QueryUploadIdentityConflict;
            }
            const offset: usize = if (first != null) q.UnifiedRequest.part_bytes else 0;
            return try self.prepare(.{ .part = .{ .namespace = namespace, .ordinal = descriptor.written, .second = first != null, .bytes = chunk[offset..@min(offset + q.UnifiedRequest.part_bytes, chunk.len)] } });
        },
        .sealed => return try self.prepare(.{ .submit = namespace }),
        else => return null,
    }
}
pub fn page(self: *Self, namespace: u64, cursor: ?q.UnifiedResult.Cursor, allocator: std.mem.Allocator, workspace: []u8, output: []u8, decoded: *q.fuze.Unified.Inspect.Batch) !q.UnifiedResult.Page {
    const current = (try self.status(namespace)) orelse return error.QueryUploadNotFound;
    if (current.phase != .complete) return error.IncompleteResult;
    return q.UnifiedResult.page(current.manifest.?, .{ .resource = self.connection.resource, .source = self.connection.source, .requester = self.connection.requester, .correlation = current.correlation, .request = current.reference }, cursor, self.resources(), allocator, workspace, output, decoded);
}
