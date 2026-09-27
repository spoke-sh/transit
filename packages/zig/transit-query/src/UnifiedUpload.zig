//! One active finite upload/query per requester. Immutable identities survive
//! completion and cleanup; replay cannot acquire a new call or reuse a namespace.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const r = q.UnifiedRecords;
const wire = q.UnifiedRequest;
const Turn = s.GrowingTurn;
const Pub = s.Publication;
const Ref = s.PublicationReference;
pub fn status(source: anytype, namespace: u64) !?wire.Status {
    const value = (try source.read(r.key('u', namespace, 0))) orelse return null;
    const out = try wire.Status.decode(value);
    if (out.reference.namespace != namespace or out.reference.resource != source.view.resource) return error.InvalidQueryUpload;
    return out;
}
fn required(source: anytype, namespace: u64) !wire.Status {
    return (try status(source, namespace)) orelse error.QueryUploadNotFound;
}
pub fn active(source: anytype) !?u64 {
    const value = (try source.read(r.key('a', 0, 0))) orelse return null;
    if (value.len != 8) return error.InvalidQueryUpload;
    const namespace = std.mem.readInt(u64, value.data[0..8], .little);
    if (namespace == 0) return error.InvalidQueryUpload;
    return namespace;
}
fn checkActive(turn: *Turn, namespace: u64) !void {
    if (try active(turn) != namespace) return error.QueryUploadNotActive;
}
fn store(turn: *Turn, current: wire.Status) !void {
    try turn.write(r.key('u', current.reference.namespace, 0), try current.encode());
}
pub fn begin(turn: *Turn, reference: Ref) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try q.Bundle.checkReference(reference);
    if (reference.resource != turn.view.resource) return error.InvalidQueryUpload;
    if (try status(turn, reference.namespace)) |existing| {
        if (!std.meta.eql(existing.reference, reference)) return error.QueryUploadIdentityConflict;
        return;
    }
    if (try active(turn) != null) return error.QueryBusy;
    if (try turn.read(Pub.key(reference.namespace, 'b', 0, 0)) != null) return error.QueryNamespaceInUse;
    const publication = try Pub.create(turn, reference.namespace, .{ .record_bytes = q.Bundle.max_bytes, .staging_bytes = q.Bundle.max_bytes, .staging_records = 1 });
    _ = try publication.begin(turn, reference.record, reference.spec);
    try store(turn, .{ .reference = reference });
    try turn.write(r.key('a', 0, 0), q.Request.identity(reference.namespace));
}
pub fn part(turn: *Turn, value: @FieldType(wire.Command, "part")) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    const current = try required(turn, value.namespace);
    if (current.phase != .uploading) return error.QueryUploadClosed;
    try checkActive(turn, value.namespace);
    const reference = current.reference;
    const publication = reference.publication();
    const descriptor = try publication.inspect(turn, reference.record);
    const length = try reference.spec.size(value.ordinal);
    const offset: usize = if (value.second) wire.part_bytes else 0;
    if (offset >= length or value.bytes.len != @min(wire.part_bytes, length - offset)) return error.InvalidQueryUpload;
    if (value.ordinal < descriptor.written) {
        const existing = (try turn.read(Pub.key(value.namespace, 'c', reference.record, value.ordinal))) orelse return error.MissingPublicationChunk;
        if (existing.len != length or !std.mem.eql(u8, existing.slice()[offset..][0..value.bytes.len], value.bytes)) return error.QueryUploadIdentityConflict;
        return;
    }
    if (value.ordinal != descriptor.written) return error.PublicationGap;
    const address = r.key('h', value.namespace, 0);
    if (length <= wire.part_bytes) {
        _ = try publication.append(turn, reference.record, value.ordinal, value.bytes);
    } else if (!value.second) {
        if (try turn.read(address)) |existing| {
            if (existing.len != value.bytes.len or !std.mem.eql(u8, existing.slice(), value.bytes)) return error.QueryUploadIdentityConflict;
        } else try turn.write(address, try q.protocol.Value.init(value.bytes));
    } else {
        const first = (try turn.read(address)) orelse return error.PublicationGap;
        if (first.len != wire.part_bytes) return error.InvalidQueryUpload;
        var bytes: [Pub.chunk_bytes]u8 = undefined;
        @memcpy(bytes[0..first.len], first.slice());
        @memcpy(bytes[first.len..][0..value.bytes.len], value.bytes);
        _ = try publication.append(turn, reference.record, value.ordinal, bytes[0..length]);
        try turn.write(address, null);
    }
}
pub fn seal(turn: *Turn, namespace: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var current = try required(turn, namespace);
    if (current.phase == .sealed) return;
    if (current.phase != .uploading) return error.QueryUploadClosed;
    try checkActive(turn, namespace);
    _ = try current.reference.publication().publish(turn, current.reference.record);
    current.phase = .sealed;
    try store(turn, current);
}
pub fn submit(turn: *Turn, namespace: u64, destination: u64) !u64 {
    const before = turn.decision;
    errdefer turn.decision = before;
    try r.identity(destination);
    var current = try required(turn, namespace);
    if (current.correlation != 0) return current.correlation;
    if (current.phase != .sealed) return error.QueryUploadClosed;
    try checkActive(turn, namespace);
    current.correlation = try turn.call(destination, try current.reference.encode(), null);
    current.phase = .admitted;
    try store(turn, current);
    try turn.write(r.key('i', current.correlation, 0), q.Request.identity(namespace));
    return current.correlation;
}
/// The host's Waiting preprocessing authenticates/accepts this reply before the
/// application callback. The result reader separately verifies its full content.
pub fn reply(turn: *Turn, frame: s.Frame, expected_source: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (frame.kind != .reply or try s.Frame.source(turn.delivery.input) != expected_source) return error.UnexpectedQueryReply;
    const wait = (try turn.waiting(frame.correlation)) orelse return error.UnknownCorrelation;
    if (wait.target != expected_source or wait.phase != .replied) return error.UnexpectedQueryReply;
    const value = (try turn.read(r.key('i', frame.correlation, 0))) orelse return error.UnknownCorrelation;
    if (value.len != 8) return error.InvalidQueryUpload;
    const namespace = std.mem.readInt(u64, value.data[0..8], .little);
    var current = try required(turn, namespace);
    if (current.correlation != frame.correlation) return error.UnexpectedQueryReply;
    if (current.phase != .admitted) return;
    if (std.mem.eql(u8, frame.payload.slice(), "query.v2.denied")) current.phase = .denied else if (std.mem.eql(u8, frame.payload.slice(), "query.v2.cancelled")) current.phase = .cancelled else if (std.mem.eql(u8, frame.payload.slice(), "query.v2.failed") or std.mem.eql(u8, frame.payload.slice(), "query.v2.rejected")) current.phase = .rejected else {
        current.manifest = try Ref.decode(frame.payload);
        current.phase = .complete;
    }
    try store(turn, current);
    if (try active(turn) == namespace) try turn.write(r.key('a', 0, 0), null);
}
/// Explicit cancellation closes the local wait once. Accepted source work may
/// already have completed; this cannot retract replies/results already disclosed.
pub fn cancel(turn: *Turn, namespace: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var current = try required(turn, namespace);
    if (current.phase != .uploading and current.phase != .sealed and current.phase != .admitted) return;
    if (current.phase == .admitted) _ = try s.Waiting.cancel(turn, current.correlation);
    const publication = current.reference.publication();
    const descriptor = try publication.inspect(turn, current.reference.record);
    if (descriptor.state == .staging) _ = try publication.abandon(turn, current.reference.record) else if (descriptor.state == .published) _ = try publication.retire(turn, current.reference.record);
    current.phase = .cancelled;
    try store(turn, current);
}
pub fn retire(turn: *Turn, namespace: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var current = try required(turn, namespace);
    if (current.phase == .retired) return;
    if (current.phase != .complete and current.phase != .denied and current.phase != .rejected) return error.QueryUploadActive;
    _ = try current.reference.publication().retire(turn, current.reference.record);
    current.phase = .retired;
    try store(turn, current);
}
/// At most four mutations. Completion is recorded in a separate turn after the
/// Publication has released its reservation, so abandonment cannot bypass quota.
pub fn collect(turn: *Turn, namespace: u64) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    var current = try required(turn, namespace);
    if (current.phase != .cancelled and current.phase != .retired) return error.QueryUploadActive;
    if (current.collected) return true;
    const publication = current.reference.publication();
    const descriptor = try publication.inspect(turn, current.reference.record);
    if (descriptor.state == .published and current.phase == .cancelled) {
        _ = try publication.retire(turn, current.reference.record);
        return false;
    }
    if (descriptor.collected != descriptor.written or descriptor.reserved) {
        _ = try publication.collect(turn, current.reference.record);
        return false;
    }
    current.collected = true;
    try store(turn, current);
    try turn.write(r.key('h', namespace, 0), null);
    if (try active(turn) == namespace) try turn.write(r.key('a', 0, 0), null);
    return true;
}
