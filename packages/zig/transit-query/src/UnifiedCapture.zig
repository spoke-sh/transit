//! Source-owned finite v1 capture. Accepted request references and retained cuts
//! are durable; workspaces and decoded bundles are disposable handler memory.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const m = q.fuze.Unified;
const r = q.UnifiedRecords;
const Turn = s.Turn;
const Pub = s.Publication;
const Ref = s.PublicationReference;
pub fn policy(source: anytype, peer: u64) !?r.Policy {
    const value = (try source.read(r.key('p', peer, 0))) orelse return null;
    const result = try r.Policy.decode(value);
    if (result.peer != peer) return error.InvalidQueryPolicy;
    return result;
}
pub fn setPolicy(turn: *Turn, next: r.Policy) !void {
    const encoded = try next.encode();
    if (try policy(turn, next.peer)) |old| {
        if (std.meta.eql(old, next)) return;
        if (next.revision <= old.revision) return error.StaleQueryPolicy;
    }
    try turn.write(r.key('p', next.peer, 0), encoded);
}
pub fn job(source: anytype, id: u64) !r.Job {
    const result = try r.Job.decode((try source.read(r.key('j', id, 0))) orelse return error.QueryNotFound);
    if (result.id != id) return error.InvalidQueryJob;
    return result;
}
pub fn checkpoint(source: anytype, id: u64) !r.Checkpoint {
    return r.Checkpoint.decode((try source.read(r.key('c', id, 0))) orelse return error.MissingQueryProgress);
}
pub fn permitted(source: anytype, stored: r.Job) !?r.Policy {
    const grant = (try policy(source, stored.destination)) orelse return null;
    if (!grant.allow or grant.revision != stored.policy_revision or grant.requests != stored.request.resource) return null;
    return grant;
}
fn matches(bundle: q.Bundle, grant: r.Policy, resource: u64) !void {
    try bundle.validate();
    if (bundle.source.resource != resource or !std.mem.eql(u8, &grant.declaration, &try q.Bundle.declaration(bundle.source)) or !grant.limits.permits(bundle.limits)) return error.QueryDenied;
}
fn schedule(turn: *Turn, stored: *r.Job) !void {
    stored.continuation = turn.delivery.input.position;
    try turn.write(r.key('j', stored.id, 0), try stored.encode());
    try turn.cast(turn.delivery.pid, try (r.Continuation{ .job = stored.id, .input = stored.continuation }).encode());
}
/// One current peer and request-resource policy owns admission. Retention and
/// all records become live only with this whole four-mutation turn.
pub fn start(turn: *Turn, reference: Ref, source: anytype, allocator: std.mem.Allocator) !r.Job {
    const before = turn.decision;
    errdefer turn.decision = before;
    for (before.mutations) |mutation| if (mutation != null) return error.QueryAfterMutation;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .call) return error.ExpectedCall;
    const peer = try s.Frame.source(turn.delivery.input);
    const grant = (try policy(turn, peer)) orelse return error.QueryDenied;
    try q.Bundle.checkReference(reference);
    if (!grant.allow or grant.requests != reference.resource) return error.QueryDenied;
    if (try turn.read(r.key('i', peer, frame.correlation)) != null) return error.CorrelationAlreadyUsed;
    var buffer: [q.Bundle.max_bytes]u8 = undefined;
    const bundle = try q.Bundle.decode(allocator, try reference.read(source, &buffer));
    try q.Bundle.checkPublisher(reference, source, peer);
    try matches(bundle, grant, turn.view.resource);
    try q.UnifiedSource.checkCurrent(bundle.source, turn);
    var columns: [m.max_columns]m.Column = undefined;
    const bound = try bundle.plan.bind(try q.UnifiedSource.basis(bundle.source, turn.view.revision), try bundle.source.schema(&columns));
    var stored: r.Job = .{ .id = turn.delivery.input.position, .destination = peer, .correlation = frame.correlation, .policy_revision = grant.revision, .source = try turn.retain(), .request = reference, .continuation = turn.delivery.input.position };
    const publication = stored.publication(turn.view.resource);
    if (try turn.read(r.key('j', stored.id, 0)) != null or try turn.read(Pub.key(publication.domain, publication.namespace, 'b', 0, 0)) != null) return error.QueryNamespaceInUse;
    _ = try Pub.create(turn, .query_result, publication.namespace, .{ .record_bytes = m.Arrow.segment_bytes, .staging_bytes = m.Arrow.segment_bytes, .staging_records = 1 });
    try turn.write(r.key('c', stored.id, 0), try (r.Checkpoint{ .progress = m.Stream.Progress.start(bound) }).encode());
    try turn.write(r.key('i', peer, frame.correlation), q.UnifiedRecords.identityValue(stored.id));
    try schedule(turn, &stored);
    try turn.validate();
    return stored;
}
pub const Advance = enum { progress, complete, closed, duplicate };
/// Reads a finite bundle and one bounded source page; stages at most two chunks
/// plus its durable self-input. No whole result or source collection is loaded.
pub fn advance(turn: *Turn, continuation: r.Continuation, source: anytype, allocator: std.mem.Allocator, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation) !Advance {
    return advanceDiagnostic(turn, continuation, source, allocator, workspace, cancellation, null);
}
pub fn advanceDiagnostic(turn: *Turn, continuation: r.Continuation, source: anytype, allocator: std.mem.Allocator, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation, diagnostic: ?*?q.QueryFailure) !Advance {
    if (diagnostic) |detail| detail.* = null;
    const before = turn.decision;
    errdefer turn.decision = before;
    if (try s.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.UnexpectedQueryContinuation;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or !frame.payload.eql(try continuation.encode())) return error.InvalidQueryContinuation;
    var stored = try job(turn, continuation.job);
    if (stored.source.pid != turn.delivery.pid) return error.InvalidQueryJob;
    if (stored.phase == .complete) return .duplicate;
    if (stored.phase != .capturing and stored.phase != .captured) {
        try cleanup(turn, &stored);
        return .closed;
    }
    if (continuation.input < stored.continuation) return .duplicate;
    if (continuation.input != stored.continuation) return error.InvalidQueryContinuation;
    const grant = (try permitted(turn, stored)) orelse {
        try close(turn, stored.id, .denied);
        return .closed;
    };
    if (cancellation.load(.acquire)) return error.Cancelled;
    var buffer: [q.Bundle.max_bytes]u8 = undefined;
    const bundle = try q.Bundle.decode(allocator, try stored.request.read(source, &buffer));
    try q.Bundle.checkPublisher(stored.request, source, stored.destination);
    try matches(bundle, grant, turn.view.resource);
    try q.UnifiedSource.checkCurrent(bundle.source, turn);
    const previous = try checkpoint(turn, stored.id);
    var columns: [m.max_columns]m.Column = undefined;
    const bound = try bundle.plan.bind(previous.progress.basis, try bundle.source.schema(&columns));
    try previous.progress.validate(bound);
    if (!std.mem.eql(u8, &bound.basis.contract, &try bundle.source.fingerprint())) return error.SourceChanged;
    if (stored.phase == .captured) {
        try publishManifest(turn, &stored, previous);
        return if (stored.phase == .complete) .complete else .progress;
    }
    if (previous.progress.pages >= bundle.limits.pages) {
        if (diagnostic) |detail| detail.* = .{ .code = .budget_exceeded, .stage = .execution, .dimension = .pages, .limit = bundle.limits.pages, .observed = try std.math.add(u64, previous.progress.pages, 1) };
        return error.QueryBudgetExceeded;
    }
    var retained = try turn.openVersion(stored.source);
    var page: q.UnifiedSource.Batch = undefined;
    try q.UnifiedSource.page(bundle.source, previous.progress.basis, previous.cursor, &retained, turn, allocator, &page);
    var bytes: [m.Arrow.segment_bytes]u8 = undefined;
    var runtime: ?m.Stream.Failure = null;
    const candidate = m.Stream.stepDiagnostic(bound, previous.progress, page.engine(), workspace, &bytes, cancellation, &runtime) catch |err| {
        const cause = if (err == error.WriteFailed) error.QuerySegmentBudgetExceeded else err;
        if (diagnostic) |detail| if (runtime) |witness| {
            if (q.QueryFailure.fromError(cause, .execution)) |failure| {
                detail.* = failure;
                detail.*.?.runtime = q.RuntimeWitness.capture(bound, &page, witness) catch null;
            }
        };
        return cause;
    };
    var progress = previous;
    progress.progress = candidate.progress;
    progress.cursor = page.next;
    const publication = stored.publication(turn.view.resource);
    if (candidate.segment) |segment| {
        progress.bytes = try std.math.add(u64, previous.bytes, segment.bytes.len);
        if (candidate.progress.segments > bundle.limits.segments) {
            if (diagnostic) |detail| detail.* = .{ .code = .budget_exceeded, .stage = .execution, .dimension = .segments, .limit = bundle.limits.segments, .observed = candidate.progress.segments };
            return error.QueryBudgetExceeded;
        }
        if (progress.bytes > bundle.limits.result_bytes) {
            if (diagnostic) |detail| detail.* = .{ .code = .budget_exceeded, .stage = .execution, .dimension = .result_bytes, .limit = bundle.limits.result_bytes, .observed = progress.bytes };
            return error.QueryBudgetExceeded;
        }
        const metadata: r.Segment = .{ .ordinal = previous.progress.segments, .row_start = previous.progress.rows, .rows = segment.rows, .reference = .{ .domain = .query_result, .resource = turn.view.resource, .namespace = publication.namespace, .record = previous.progress.segments + 1, .spec = try Pub.Digest.of(r.arrow_format, segment.bytes) }, .arrow_digest = segment.digest };
        const encoded = try metadata.encode();
        const address = r.key('s', stored.id, metadata.ordinal);
        if (try turn.read(address)) |old| {
            if (!old.eql(encoded)) return error.QueryStageChanged;
        } else {
            _ = try publication.begin(turn, metadata.reference.record, metadata.reference.spec);
            try turn.write(address, encoded);
            try schedule(turn, &stored);
            return .progress;
        }
        const descriptor = try publication.inspect(turn, metadata.reference.record);
        if (!std.meta.eql(descriptor.spec, metadata.reference.spec) or descriptor.state != .staging) return error.QueryStageChanged;
        if (descriptor.written < descriptor.spec.chunks()) {
            const end = descriptor.written + @min(@as(u32, 2), descriptor.spec.chunks() - descriptor.written);
            for (descriptor.written..end) |index| {
                const offset = index * Pub.chunk_bytes;
                _ = try publication.append(turn, metadata.reference.record, @intCast(index), segment.bytes[offset..][0..try descriptor.spec.size(@intCast(index))]);
            }
            try schedule(turn, &stored);
            return .progress;
        }
        progress.chain = try metadata.extend(previous.chain);
        _ = try publication.publish(turn, metadata.reference.record);
    }
    try turn.write(r.key('c', stored.id, 0), try progress.encode());
    if (candidate.progress.finished != null) {
        stored.phase = .captured;
        try turn.release(stored.source);
    }
    try schedule(turn, &stored);
    try turn.validate();
    return .progress;
}
fn publishManifest(turn: *Turn, stored: *r.Job, progress: r.Checkpoint) !void {
    var complete = stored.*;
    complete.phase = .complete;
    // The complete identity does not change during its finite publication.
    complete.continuation = stored.id;
    var bytes: [r.Manifest.max_bytes]u8 = undefined;
    const content = try (r.Manifest{ .job = complete, .checkpoint = progress }).encode(&bytes);
    const publication = stored.publication(turn.view.resource);
    const spec = try Pub.Digest.of(r.manifest_format, content);
    const descriptor = publication.inspect(turn, r.manifest_record) catch |err| switch (err) {
        error.PublicationNotFound => {
            _ = try publication.begin(turn, r.manifest_record, spec);
            try schedule(turn, stored);
            return;
        },
        else => return err,
    };
    if (!std.meta.eql(descriptor.spec, spec) or descriptor.state != .staging) return error.QueryStageChanged;
    if (descriptor.written < spec.chunks()) {
        const offset = descriptor.written * Pub.chunk_bytes;
        _ = try publication.append(turn, r.manifest_record, descriptor.written, content[offset..][0..try spec.size(descriptor.written)]);
        try schedule(turn, stored);
        return;
    }
    _ = try publication.publish(turn, r.manifest_record);
    stored.* = complete;
    try turn.write(r.key('j', stored.id, 0), try stored.encode());
    const reference: Ref = .{ .domain = .query_result, .resource = turn.view.resource, .namespace = publication.namespace, .record = r.manifest_record, .spec = spec };
    try turn.send(stored.destination, .{ .kind = .reply, .correlation = stored.correlation, .payload = try reference.encode() });
}
/// Close in a fresh proposal before a failed read poisons the turn. This releases
/// the pin and original wait exactly once; physical staging cleanup is separate.
pub fn close(turn: *Turn, id: u64, phase: enum { cancelled, denied, retired }) !void {
    return closeOutcome(turn, id, switch (phase) {
        .cancelled => .cancelled,
        .denied => .denied,
        .retired => .retired,
    }, if (phase == .denied) q.QueryFailure.fromError(error.QueryDenied, .execution).? else null);
}
pub fn closeFailure(turn: *Turn, id: u64, failure: q.QueryFailure) !void {
    return closeOutcome(turn, id, if (failure.denied()) .denied else .failed, failure);
}
fn closeOutcome(turn: *Turn, id: u64, phase: enum { cancelled, denied, failed, retired }, failure: ?q.QueryFailure) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var stored = try job(turn, id);
    if (stored.source.pid != turn.delivery.pid) return error.InvalidQueryJob;
    if (stored.phase != .capturing and stored.phase != .captured and stored.phase != .complete) return;
    if (stored.phase == .complete and phase != .retired) return;
    if (phase == .retired and stored.phase != .complete) return error.IncompleteResult;
    if (stored.phase == .capturing) try turn.release(stored.source);
    stored.phase = switch (phase) {
        .cancelled => .cancelled,
        .denied => .denied,
        .failed => .failed,
        .retired => .retired,
    };
    stored.failure = failure;
    if (phase != .retired) try turn.send(stored.destination, .{ .kind = .reply, .correlation = stored.correlation, .payload = if (failure) |detail| try detail.encode() else try p.Value.init("query.v1.cancelled") });
    try schedule(turn, &stored);
}
fn cleanup(turn: *Turn, stored: *r.Job) !void {
    if (stored.cleanup == 0) return;
    const publication = stored.publication(turn.view.resource);
    const descriptor = publication.inspect(turn, stored.cleanup) catch |err| switch (err) {
        error.PublicationNotFound => null,
        else => return err,
    };
    if (descriptor) |record| {
        switch (record.state) {
            .staging => {
                _ = try publication.abandon(turn, stored.cleanup);
            },
            .published => {
                _ = try publication.retire(turn, stored.cleanup);
            },
            .abandoned, .retired => {
                if (record.collected < record.written or record.reserved) {
                    _ = try publication.collect(turn, stored.cleanup);
                } else {
                    try nextCleanup(turn, stored);
                    return;
                }
            },
        }
        // collect may consume all four mutations. Its descriptor is the durable
        // cleanup cursor; no independent progress write accompanies that turn.
        try turn.cast(turn.delivery.pid, try (r.Continuation{ .job = stored.id, .input = stored.continuation }).encode());
    } else try nextCleanup(turn, stored);
}
fn nextCleanup(turn: *Turn, stored: *r.Job) !void {
    const progress = try checkpoint(turn, stored.id);
    stored.cleanup = if (stored.cleanup == r.manifest_record) 0 else if (stored.cleanup > progress.progress.segments) r.manifest_record else stored.cleanup + 1;
    if (stored.cleanup == 0) try turn.write(r.key('j', stored.id, 0), try stored.encode()) else try schedule(turn, stored);
}
