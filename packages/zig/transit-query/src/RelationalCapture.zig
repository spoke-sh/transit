//! Source-owned captured relational jobs. One native resource owns each job;
//! registered foreign sources remain read-only and current-policy guarded.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const f = q.fuze;
const r = q.RelationalRecords;
const Turn = s.Turn;
const Pub = s.Publication;
const Ref = s.PublicationReference;
pub const resident_base = 4 * @sizeOf(q.RelationalCaptured) + 3 * q.RelationalBundle.max_bytes + 2 * f.TableRow.max_bytes + 4 * f.TableSchema.max_bytes + f.RelationalIndex.resident_bytes + 4 * f.RelationalCheckpoint.max_bytes;
pub fn policy(source: anytype, peer: u64) !?r.Policy {
    const value = (try source.read(r.key('p', peer, 0))) orelse return null;
    const result = try r.Policy.decode(value);
    if (result.peer != peer) return error.InvalidRelationalRecord;
    return result;
}
/// Called by the coordinator's authorized configuration handler.
pub fn setPolicy(turn: *Turn, proposed: r.Policy) !void {
    const encoded = try proposed.encode();
    if (try policy(turn, proposed.peer)) |old| {
        if (std.meta.eql(old, proposed)) return;
        if (proposed.revision <= old.revision) return error.StaleQueryPolicy;
    }
    try turn.write(r.key('p', proposed.peer, 0), encoded);
}
pub fn job(source: anytype, id: u64) !r.Job {
    const result = try r.Job.decode((try source.read(r.key('j', id, 0))) orelse return error.QueryNotFound);
    if (result.id != id) return error.InvalidRelationalRecord;
    return result;
}
fn vector(source: anytype, id: u64) !p.Value {
    return (try source.read(r.key('v', id, 0))) orelse return error.MissingQueryProgress;
}
fn schedule(turn: *Turn, stored: *r.Job) !void {
    stored.continuation = turn.delivery.input.position;
    try turn.write(r.key('j', stored.id, 0), try stored.encode());
    try turn.cast(turn.delivery.pid, try (q.UnifiedRecords.Continuation{ .job = stored.id, .input = stored.continuation }).encode());
}
fn body(ref: Ref, source: anytype, bytes: []u8) ![]const u8 {
    try ref.validate();
    if (source.view.resource != ref.resource or ref.spec.length > bytes.len) return error.InvalidQueryBundle;
    var cursor = try ref.publication().open(source, ref.record);
    if (!std.meta.eql(cursor.spec, ref.spec)) return error.PublicationReferenceChanged;
    var at: usize = 0;
    while (true) {
        const part = try ref.publication().read(source, cursor);
        if (part.bytes.len > ref.spec.length - at) return error.InvalidQueryBundle;
        @memcpy(bytes[at..][0..part.bytes.len], part.bytes.slice());
        at += part.bytes.len;
        cursor = part.next orelse break;
    }
    if (at != ref.spec.length) return error.InvalidQueryBundle;
    return bytes[0..at];
}
fn memory(bundle: q.RelationalBundle, workspace: []u8) !void {
    if (workspace.len > std.math.maxInt(u64) - resident_base or workspace.len + resident_base > bundle.plan.budgets.resident_bytes) return error.RelationalResidentBudget;
}
/// Four mutations admit the job, vector, correlation and publication budget.
/// The request and every distinct data resource are retained in that same turn.
/// The coordinator is the first Table owner; no second resource is mutated.
pub fn start(turn: *Turn, reference: Ref, workspace: []u8) !r.Job {
    const before = turn.decision;
    errdefer turn.decision = before;
    for (before.mutations) |mutation| if (mutation != null) return error.QueryAfterMutation;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .call) return error.ExpectedCall;
    const peer = try s.Frame.source(turn.delivery.input);
    const grant = (try policy(turn, peer)) orelse return error.QueryDenied;
    try q.RelationalBundle.checkReference(reference);
    if (!grant.allow or grant.requests != reference.resource) return error.QueryDenied;
    if (try turn.read(r.key('i', peer, frame.correlation)) != null) return error.CorrelationAlreadyUsed;
    var request_view = try turn.captured(reference.resource);
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace);
    const bundle = try q.RelationalBundle.decodeInto(fixed.allocator(), try body(reference, &request_view, &bytes));
    try memory(bundle, workspace);
    const descriptor = try reference.publication().inspect(&request_view, reference.record);
    if (descriptor.publisher != peer) return error.UnexpectedQueryPublisher;
    if (!std.mem.eql(u8, &grant.request, &try bundle.fingerprint())) return error.QueryDenied;
    if (bundle.sources[0].scope.resource != turn.view.resource or bundle.sources[0].owner != turn.delivery.pid) return error.RelationalSourceChanged;
    try request_view.requireCurrent();
    const request_version = try request_view.retain();
    const sources = try q.RelationalCaptured.capture(turn, fixed.allocator(), bundle, grant.principal);
    var stored: r.Job = .{ .id = turn.delivery.input.position, .destination = peer, .correlation = frame.correlation, .policy_revision = grant.revision, .request = reference, .request_version = request_version, .continuation = turn.delivery.input.position };
    if (try turn.read(r.key('j', stored.id, 0)) != null or try turn.read(Pub.key(.query_result, stored.namespace(), 'b', 0, 0)) != null) return error.QueryNamespaceInUse;
    _ = try q.RelationalState.create(turn, stored.namespace());
    try turn.write(r.key('v', stored.id, 0), try sources.encode(bundle));
    try turn.write(r.key('i', peer, frame.correlation), q.UnifiedRecords.identityValue(stored.id));
    try schedule(turn, &stored);
    try turn.validate();
    return stored;
}
/// Fresh closure does not read the submitted plan or retained source data.
/// Callers must authenticate cancellation/retirement in their public handler.
/// A poisoned native read requires a fresh proposal before this can commit.
pub fn close(turn: *Turn, id: u64, phase: enum { cancelled, denied, failed, retired }, failure: ?r.Failure) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var stored = try job(turn, id);
    if (stored.request_version.pid != turn.delivery.pid) return error.InvalidRelationalRecord;
    if (stored.phase != .capturing and stored.phase != .complete) return;
    if (stored.phase == .complete and phase != .retired) return;
    if (stored.phase != .complete and phase == .retired) return error.IncompleteResult;
    if ((phase == .denied or phase == .failed) != (failure != null)) return error.InvalidRelationalRecord;
    if (failure) |cause| if (cause.denied() != (phase == .denied)) return error.InvalidRelationalRecord;
    if (!stored.released) {
        const captured = try q.RelationalCaptured.Vector.decodeStored(try vector(turn, id));
        try captured.releaseStored(turn, id);
        try turn.release(stored.request_version);
        stored.released = true;
    }
    stored.phase = switch (phase) {
        .cancelled => .cancelled,
        .denied => .denied,
        .failed => .failed,
        .retired => .retired,
    };
    if (failure) |cause| try turn.write(r.key('f', id, 0), try cause.encode());
    try turn.write(r.key('j', id, 0), try stored.encode());
    if (phase != .retired) try turn.send(stored.destination, .{ .kind = .reply, .correlation = stored.correlation, .payload = try p.Value.init("closed") });
}

/// Explicit bounded collection after closure. Permanent record identities and
/// job evidence survive; failed/denied jobs retain their last checkpoint for
/// the first-error witness. No request/source permission is needed for cleanup.
/// The caller schedules another input when false is returned.
pub fn collect(turn: *Turn, id: u64) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    for (before.mutations) |mutation| if (mutation != null) return error.QueryAfterMutation;
    var stored = try job(turn, id);
    if (stored.request_version.pid != turn.delivery.pid) return error.InvalidRelationalRecord;
    if (!stored.released or stored.phase == .capturing or stored.phase == .complete) return error.QueryUploadActive;
    if (stored.cleanup == std.math.maxInt(u64)) return true;
    const at = @max(stored.cleanup, 1);
    const publication = stored.publication(turn.view.resource);
    if (at != stored.checkpoint or (stored.phase != .failed and stored.phase != .denied)) {
        const descriptor = publication.inspect(turn, at) catch |err| switch (err) {
            error.PublicationNotFound => null,
            else => return err,
        };
        if (descriptor) |record| switch (record.state) {
            .staging => {
                _ = try publication.abandon(turn, at);
                return false;
            },
            .published => {
                _ = try publication.retire(turn, at);
                return false;
            },
            .abandoned, .retired => if (record.collected < record.written or record.reserved) {
                // Publication owns the bounded chunk cursor; it may consume
                // all four mutations, so do not write the job in this turn.
                _ = try publication.collect(turn, at);
                return false;
            },
        } else {
            if (at < stored.next_record) return error.MissingQueryProgress;
            // Candidate records are staged sequentially, including records
            // beyond the last accepted root. The first absent descriptor
            // therefore proves coverage of all abandoned private candidates.
            stored.cleanup = std.math.maxInt(u64);
            try turn.write(r.key('j', id, 0), try stored.encode());
            return true;
        }
    }
    stored.cleanup = try std.math.add(u64, at, 1);
    try turn.write(r.key('j', id, 0), try stored.encode());
    return false;
}

const Candidate = q.RelationalState.Candidate(*Turn);
const Groups = struct {
    index: f.RelationalIndex,
    candidate: *Candidate,
    pub fn get(self: *Groups, key: f.RelationalExecution.Key) !?f.RelationalExecution.Group {
        return self.index.get(self.candidate, key);
    }
    pub fn put(self: *Groups, group: f.RelationalExecution.Group) !void {
        return self.index.put(self.candidate, group);
    }
    pub fn next(self: *Groups, after: ?f.RelationalExecution.Key) !?f.RelationalExecution.Group {
        return self.index.next(self.candidate, after);
    }
};
const Engine = f.RelationalExecution.Execution(*q.RelationalCaptured, *Groups);
pub const Advance = enum { progress, complete, closed, duplicate };
fn failed(turn: *Turn, stored: r.Job, err: anyerror) !Advance {
    if (turn.read_error != null) return err;
    const cause = (try r.Failure.fromError(err)) orelse return err;
    try close(turn, stored.id, if (cause.denied()) .denied else .failed, cause);
    return .closed;
}
pub fn advance(turn: *Turn, continuation: q.UnifiedRecords.Continuation, workspace: []u8) !Advance {
    const before = turn.decision;
    errdefer turn.decision = before;
    const stored = try job(turn, continuation.job);
    if (stored.request_version.pid != turn.delivery.pid or try s.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.UnexpectedQueryContinuation;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or !frame.payload.eql(try continuation.encode())) return error.InvalidQueryContinuation;
    if (stored.phase != .capturing) return .duplicate;
    if (continuation.input < stored.continuation) return .duplicate;
    if (continuation.input != stored.continuation) return error.InvalidQueryContinuation;
    return advanceInner(turn, stored, workspace) catch |err| {
        turn.decision = before;
        return failed(turn, stored, err);
    };
}
fn advanceInner(turn: *Turn, stored: r.Job, workspace: []u8) !Advance {
    const grant = (try policy(turn, stored.destination)) orelse return error.QueryDenied;
    if (!grant.allow or grant.revision != stored.policy_revision or grant.requests != stored.request.resource) return error.QueryDenied;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace);
    const allocator = fixed.allocator();
    var retained_request = try turn.openVersion(stored.request_version);
    var request_bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    const bundle = try q.RelationalBundle.decodeInto(allocator, try body(stored.request, &retained_request, &request_bytes));
    try memory(bundle, workspace);
    if (!std.mem.eql(u8, &grant.request, &try bundle.fingerprint())) return error.QueryDenied;
    const vector_value = try vector(turn, stored.id);
    const sources = try q.RelationalCaptured.Vector.decode(bundle, vector_value);
    const data = try allocator.create(q.RelationalCaptured);
    data.* = try q.RelationalCaptured.open(turn, allocator, bundle, grant.principal, sources, 1);
    const bound = data.bound();
    const pages: q.RelationalState = .{ .publication = stored.publication(turn.view.resource) };
    const candidate = try allocator.create(Candidate);
    candidate.* = try Candidate.init(pages, turn, stored.next_record, stored.state_bytes, bound, 8 * f.RelationalIndex.max_candidate_records);
    const previous: ?f.RelationalCheckpoint = if (stored.checkpoint == 0) null else try pages.checkpoint(turn, stored.checkpoint, bound);
    var groups: Groups = .{ .index = try f.RelationalIndex.init(bound, if (previous) |old| old.root else null), .candidate = candidate };
    var engine = if (previous) |old| try Engine.restore(bound, data, &groups, old) else try Engine.init(bound, data, &groups);
    if (engine.result_rows != stored.outputs) return error.InvalidRelationalRecord;
    var failure: ?r.Failure = null;
    const event = engine.step() catch |err| blk: {
        if (turn.read_error != null) return err;
        failure = (try r.Failure.fromError(err)) orelse return err;
        // A failed operation cannot accept candidate groups. Its bounded control
        // checkpoint preserves the first observed semantic witness separately.
        groups.index.root = if (previous) |old| old.root else null;
        candidate.count = 0;
        candidate.bytes = 0;
        break :blk f.RelationalExecution.Event.progress;
    };
    const progress = try engine.checkpoint(groups.index.root);
    var checkpoint_bytes: [f.RelationalCheckpoint.max_bytes]u8 = undefined;
    const checkpoint_body = try progress.encode(bound, &checkpoint_bytes);
    const checkpoint_id = try candidate.checkpointId();
    const checkpoint_ref: Ref = .{ .resource = turn.view.resource, .domain = .query_result, .namespace = stored.namespace(), .record = checkpoint_id, .spec = try Pub.Digest.of(q.RelationalState.checkpoint_format, checkpoint_body) };
    var proposed = stored;
    proposed.checkpoint = checkpoint_id;
    proposed.next_record = try std.math.add(u64, checkpoint_id, 1);
    proposed.state_bytes = if (failure != null)
        try std.math.add(u64, stored.state_bytes, checkpoint_body.len)
    else
        try candidate.retainedBytes(checkpoint_body.len);
    var output_bytes: [f.RelationalOutput.max_bytes]u8 = undefined;
    var output_body: ?[]const u8 = null;
    var output_record: ?r.Output = null;
    if (event == .row) {
        output_body = try (f.RelationalOutput{ .binding = try bound.fingerprint(), .ordinal = stored.outputs, .row = event.row }).encode(bound, &output_bytes);
        output_record = .{ .ordinal = stored.outputs, .reference = .{ .resource = turn.view.resource, .domain = .query_result, .namespace = stored.namespace(), .record = proposed.next_record, .spec = try Pub.Digest.of(r.output_format, output_body.?) } };
        proposed.next_record = try std.math.add(u64, proposed.next_record, 1);
        proposed.state_bytes = try std.math.add(u64, proposed.state_bytes, output_body.?.len);
        proposed.outputs = try std.math.add(u64, proposed.outputs, 1);
        proposed.output_bytes = try std.math.add(u64, proposed.output_bytes, output_body.?.len);
        proposed.chain = try output_record.?.extend(stored.chain);
    }
    var manifest_bytes: [r.Manifest.max_bytes]u8 = undefined;
    var manifest_body: ?[]const u8 = null;
    var manifest_ref: ?Ref = null;
    if (event == .complete) {
        proposed.phase = .complete;
        proposed.continuation = proposed.id;
        proposed.manifest = proposed.next_record;
        proposed.next_record = try std.math.add(u64, proposed.next_record, 1);
        const length = (try (r.Manifest{ .job = proposed, .vector = vector_value, .checkpoint = checkpoint_ref }).encode(&manifest_bytes)).len;
        proposed.state_bytes = try std.math.add(u64, proposed.state_bytes, length);
        manifest_body = try (r.Manifest{ .job = proposed, .vector = vector_value, .checkpoint = checkpoint_ref }).encode(&manifest_bytes);
        manifest_ref = .{ .resource = turn.view.resource, .domain = .query_result, .namespace = stored.namespace(), .record = proposed.manifest, .spec = try Pub.Digest.of(r.manifest_format, manifest_body.?) };
    }
    if (failure == null and proposed.state_bytes > bundle.plan.budgets.spill_bytes) return error.RelationalSpillBudget;
    // One job write reserves room for continuation before bounded publication
    // staging. The accepted checkpoint still points to the original root.
    var pending = stored;
    try schedule(turn, &pending);
    if (!try candidate.stage(turn)) return .progress;
    if (!try stage(turn, pages.publication, checkpoint_ref, checkpoint_body)) return .progress;
    if (output_record) |record| if (!try stage(turn, pages.publication, record.reference, output_body.?)) return .progress;
    if (manifest_ref) |reference| if (!try stage(turn, pages.publication, reference, manifest_body.?)) return .progress;
    // Accept only on a turn where all immutable records were already complete.
    // This leaves room for the root, output index and failure/reply together.
    for (turn.decision.mutations) |mutation| if (mutation) |entry| if (!entry.key.eql(r.key('j', stored.id, 0))) return .progress;
    try data.validate(bound);
    if (failure) |cause| {
        proposed.phase = if (cause.denied()) .denied else .failed;
        proposed.released = true;
        try sources.releaseStored(turn, stored.id);
        try turn.release(stored.request_version);
        try turn.write(r.key('f', stored.id, 0), try cause.encode());
        try turn.send(stored.destination, .{ .kind = .reply, .correlation = stored.correlation, .payload = try p.Value.init("closed") });
    } else if (output_record) |record| {
        if (try turn.read(r.key('o', stored.id, stored.outputs)) != null) return error.InvalidRelationalRecord;
        try turn.write(r.key('o', stored.id, stored.outputs), try record.encode());
    }
    if (proposed.phase != .complete) proposed.continuation = pending.continuation;
    try turn.write(r.key('j', stored.id, 0), try proposed.encode());
    if (manifest_ref) |reference| try turn.send(stored.destination, .{ .kind = .reply, .correlation = stored.correlation, .payload = try reference.encode() });
    return if (failure != null) .closed else if (event == .complete) .complete else .progress;
}
fn stage(turn: *Turn, publication: Pub, reference: Ref, bytes: []const u8) !bool {
    return publication.stage(turn, reference.record, reference.spec, bytes) catch |err| {
        if (err == error.MutationBudgetExceeded) return false;
        return err;
    };
}
