//! Source-owned maintained relations. Every complete Table transaction selects
//! one durable basis. Bounded recomputation stages a complete result and paired
//! delta before atomically publishing their common revision root.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const f = q.fuze;
const r = q.RelationalMaintenanceRecords;
const finite = q.RelationalRecords;
const Turn = s.Turn;
const Pub = s.Publication;
const Ref = s.PublicationReference;
const History = q.RelationalHistory;
pub const resident_base = 4 * History.resident_bytes + 3 * q.RelationalBundle.max_bytes + 4 * f.RelationalCheckpoint.max_bytes + 4 * f.RelationalOutput.max_bytes + 2 * f.RelationalDelta.max_bytes + 3 * r.Manifest.max_bytes;
pub const Advance = enum { progress, complete, idle, closed, duplicate };
pub fn head(source: anytype, identity: r.Identity) !r.Head {
    try identity.validate();
    const stored = try r.Head.decode((try source.read(identity.address())) orelse return error.QueryNotFound);
    if (!std.meta.eql(stored.identity(), identity)) return error.InvalidMaintainedRecord;
    return stored;
}
fn workKey(stored: r.Head) !q.protocol.Value {
    return r.key('w', stored.id, try stored.successor(), 0);
}
fn readWork(source: anytype, stored: r.Head) !r.Work {
    const revision = try stored.successor();
    const found = (try source.read(try workKey(stored))) orelse return .{ .revision = revision, .next_record = stored.next_record, .state_bytes = stored.state_bytes };
    const result = try r.Work.decode(found);
    if (result.revision != revision or result.next_record < stored.next_record or result.state_bytes < stored.state_bytes) return error.InvalidMaintainedRecord;
    return result;
}
pub fn readBody(reference: Ref, source: anytype, bytes: []u8) ![]const u8 {
    try reference.validate();
    if (source.view.resource != reference.resource or reference.spec.length > bytes.len) return error.InvalidMaintainedRecord;
    var cursor = try reference.publication().open(source, reference.record);
    if (!std.meta.eql(cursor.spec, reference.spec)) return error.PublicationReferenceChanged;
    var at: usize = 0;
    while (true) {
        const part = try reference.publication().read(source, cursor);
        if (part.bytes.len > reference.spec.length - at) return error.InvalidMaintainedRecord;
        @memcpy(bytes[at..][0..part.bytes.len], part.bytes.slice());
        at += part.bytes.len;
        cursor = part.next orelse break;
    }
    if (at != reference.spec.length) return error.InvalidMaintainedRecord;
    return bytes[0..at];
}
fn storedReference(source: anytype, publication: Pub, id: u64) !Ref {
    const cursor = try publication.open(source, id);
    return .{ .resource = publication.resource, .domain = publication.domain, .namespace = publication.namespace, .record = id, .spec = cursor.spec };
}
pub fn manifest(source: anytype, bundle: q.RelationalBundle, stored: r.Head) !?r.Manifest {
    if (stored.revision == 0) return null;
    const ref = try storedReference(source, stored.publication(source.view.resource), stored.manifest);
    if (ref.spec.format != r.revision_format) return error.InvalidMaintainedRecord;
    var bytes: [r.Manifest.max_bytes]u8 = undefined;
    const value = try r.Manifest.decode(bundle, try readBody(ref, source, &bytes));
    if (value.id != stored.id or value.work.revision != stored.revision or value.work.manifest != stored.manifest or value.work.next_record != stored.next_record or value.work.state_bytes != stored.state_bytes) return error.InvalidMaintainedRecord;
    return value;
}
fn readBasis(source: anytype, bundle: q.RelationalBundle, stored: r.Head) !History.Vector {
    var vector: History.Vector = .{ .request = try bundle.fingerprint(), .count = stored.count };
    for (vector.entries[0..stored.count], stored.positions[0..stored.count], 0..) |*entry, position, i| {
        const value = (try source.read(r.key('b', stored.id, try stored.successor(), i))) orelse return error.MissingQueryProgress;
        entry.* = .{ .position = position, .record = try s.TableHistory.Record.decode(value) };
    }
    try vector.validate(bundle);
    return vector;
}
fn writeBasis(turn: *Turn, stored: *r.Head, vector: History.Vector) !void {
    stored.count = vector.count;
    for (vector.entries[0..vector.count], 0..) |entry, i| {
        stored.positions[i] = entry.position;
        try turn.write(r.key('b', stored.id, try stored.successor(), i), try entry.record.encode());
    }
}
fn schedule(turn: *Turn, stored: *r.Head) !void {
    stored.continuation = turn.delivery.input.position;
    try turn.write(stored.identity().address(), try stored.encode());
    try turn.cast(turn.delivery.pid, try (r.Continuation{ .identity = stored.identity(), .input = stored.continuation }).encode());
}
fn memory(bundle: q.RelationalBundle, workspace: []u8) !void {
    if (workspace.len > std.math.maxInt(u64) - resident_base or workspace.len + resident_base > bundle.plan.budgets.resident_bytes) return error.RelationalResidentBudget;
}
/// Explicit activation by the configured caller. Admission retains the exact
/// request and records both source heads with the root in at most four writes.
pub fn start(turn: *Turn, request: Ref, workspace: []u8) !r.Head {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    for (decision.mutations) |mutation| if (mutation != null) return error.QueryAfterMutation;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .call) return error.ExpectedCall;
    const peer = try s.Frame.source(turn.delivery.input);
    const grant = (try q.RelationalCapture.policy(turn, peer)) orelse return error.QueryDenied;
    try q.RelationalBundle.checkReference(request);
    if (!grant.allow or grant.requests != request.resource) return error.QueryDenied;
    const identity: r.Identity = .{ .peer = peer, .correlation = frame.correlation };
    if (try turn.read(identity.address()) != null) return error.CorrelationAlreadyUsed;
    var current = try turn.captured(request.resource);
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace);
    const bundle = try q.RelationalBundle.decodeInto(fixed.allocator(), try readBody(request, &current, &bytes));
    if (bundle.plan.lifetime != .maintained) return error.InvalidRelationalHistory;
    try memory(bundle, workspace);
    if (!std.mem.eql(u8, &grant.request, &try bundle.fingerprint())) return error.QueryDenied;
    if (bundle.sources[0].scope.resource != turn.view.resource or bundle.sources[0].owner != turn.delivery.pid) return error.RelationalSourceChanged;
    if ((try request.publication().inspect(&current, request.record)).publisher != peer) return error.UnexpectedQueryPublisher;
    try current.requireCurrent();
    const request_version = try current.retain();
    const vector = try History.capture(turn, fixed.allocator(), bundle, grant.principal);
    var stored: r.Head = .{ .id = turn.delivery.input.position, .peer = peer, .correlation = frame.correlation, .policy_revision = grant.revision, .request = request, .request_version = request_version, .continuation = turn.delivery.input.position, .count = vector.count };
    if (try turn.read(Pub.key(.query_result, stored.namespace(), 'b', 0, 0)) != null) return error.QueryNamespaceInUse;
    _ = try q.RelationalState.create(turn, stored.namespace());
    try writeBasis(turn, &stored, vector);
    try schedule(turn, &stored);
    // Admission settles the activation call. Later revisions have their own
    // immutable identities and are observed through the revision reader.
    try turn.send(peer, .{ .kind = .reply, .correlation = frame.correlation, .payload = try stored.encode() });
    try turn.validate();
    return stored;
}
/// Fresh own-resource closure requires no source reads. The authenticated host
/// settles uncertain work first. Cancellation/failure preserves prior complete
/// revisions and the request dependency; retirement releases that dependency.
pub fn close(turn: *Turn, identity: r.Identity, phase: enum { cancelled, failed, retired }, failure: ?finite.Failure) !void {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    var stored = try head(turn, identity);
    if (stored.request_version.pid != turn.delivery.pid) return error.InvalidMaintainedRecord;
    if (stored.phase == .retired or ((stored.phase == .failed or stored.phase == .cancelled) and phase != .retired)) return;
    if ((phase == .failed) != (failure != null)) return error.InvalidMaintainedRecord;
    if (phase == .retired) {
        try turn.release(stored.request_version);
        stored.released = true;
    }
    stored.phase = switch (phase) {
        .cancelled => .cancelled,
        .failed => .failed,
        .retired => .retired,
    };
    if (failure) |cause| try turn.write(r.key('f', stored.id, try stored.successor(), 0), try cause.encode());
    try turn.write(identity.address(), try stored.encode());
}
fn failed(turn: *Turn, stored: r.Head, err: anyerror) !Advance {
    if (turn.read_error != null) return err;
    const cause = (try finite.Failure.fromError(err)) orelse return err;
    try close(turn, stored.identity(), .failed, cause);
    return .closed;
}
/// A durable self-continuation advances active work. An authenticated host may
/// explicitly wake an idle query with wake(); invalidation is only a wakeup.
pub fn advance(turn: *Turn, continuation: r.Continuation, workspace: []u8) !Advance {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    const stored = try head(turn, continuation.identity);
    if (stored.request_version.pid != turn.delivery.pid or try s.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.UnexpectedQueryContinuation;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or !frame.payload.eql(try continuation.encode())) return error.InvalidQueryContinuation;
    if (stored.phase != .admitted and stored.phase != .running) return .duplicate;
    if (continuation.input < stored.continuation) return .duplicate;
    if (continuation.input != stored.continuation) return error.InvalidQueryContinuation;
    return advanceInner(turn, stored, workspace, false) catch |err| {
        turn.decision = decision;
        return failed(turn, stored, err);
    };
}
pub fn wake(turn: *Turn, identity: r.Identity, workspace: []u8) !Advance {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    const stored = try head(turn, identity);
    if (stored.request_version.pid != turn.delivery.pid) return error.InvalidMaintainedRecord;
    if (stored.phase != .idle) return .duplicate;
    return advanceInner(turn, stored, workspace, true) catch |err| {
        turn.decision = decision;
        return failed(turn, stored, err);
    };
}
const Candidate = q.RelationalState.Candidate(*Turn);
const Groups = struct {
    index: f.RelationalIndex,
    candidate: *Candidate,
    pub fn get(self: *Groups, key: f.RelationalExecution.Key) !?f.RelationalExecution.Group {
        return self.index.get(self.candidate, key);
    }
    pub fn put(self: *Groups, value: f.RelationalExecution.Group) !void {
        return self.index.put(self.candidate, value);
    }
    pub fn next(self: *Groups, after: ?f.RelationalExecution.Key) !?f.RelationalExecution.Group {
        return self.index.next(self.candidate, after);
    }
};
const Engine = f.RelationalExecution.Execution(*History, *Groups);
fn advanceInner(turn: *Turn, stored: r.Head, workspace: []u8, waking: bool) !Advance {
    const grant = (try q.RelationalCapture.policy(turn, stored.peer)) orelse return error.QueryDenied;
    if (!grant.allow or grant.revision != stored.policy_revision or grant.requests != stored.request.resource) return error.QueryDenied;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace);
    const allocator = fixed.allocator();
    var retained = try turn.openVersion(stored.request_version);
    var bytes: [q.RelationalBundle.max_bytes]u8 = undefined;
    const bundle = try q.RelationalBundle.decodeInto(allocator, try readBody(stored.request, &retained, &bytes));
    try memory(bundle, workspace);
    if (!std.mem.eql(u8, &grant.request, &try bundle.fingerprint())) return error.QueryDenied;
    const previous = try manifest(turn, bundle, stored);
    if (waking) {
        const next = (try History.successor(turn, bundle, grant.principal, previous.?.vector, stored.preference)) orelse return .idle;
        var proposed = stored;
        proposed.phase = .admitted;
        proposed.preference = (stored.preference + 1) % stored.count;
        try writeBasis(turn, &proposed, next);
        try schedule(turn, &proposed);
        return .progress;
    }
    const vector = try readBasis(turn, bundle, stored);
    const data = try allocator.create(History);
    data.* = try History.open(turn, allocator, bundle, grant.principal, vector, 1);
    const work = try readWork(turn, stored);
    return switch (work.phase) {
        .compute => compute(turn, allocator, stored, work, data),
        .delta => delta(turn, bundle, stored, work, data, previous),
        .manifest => publish(turn, bundle, stored, work, data, previous),
        .complete, .failed => error.InvalidMaintainedRecord,
    };
}
fn stage(turn: *Turn, ref: Ref, bytes: []const u8) !bool {
    return ref.publication().stage(turn, ref.record, ref.spec, bytes) catch |err| {
        if (err == error.MutationBudgetExceeded) return false;
        return err;
    };
}
fn allocated(turn: *Turn, stored: r.Head, id: u64, format: u32, bytes: []const u8) !Ref {
    return .{ .resource = turn.view.resource, .domain = .query_result, .namespace = stored.namespace(), .record = id, .spec = try Pub.Digest.of(format, bytes) };
}
fn onlyScheduled(turn: *Turn, stored: r.Head) bool {
    for (turn.decision.mutations) |mutation| if (mutation) |entry| if (!entry.key.eql(stored.identity().address())) return false;
    return true;
}
fn compute(turn: *Turn, allocator: std.mem.Allocator, stored: r.Head, work: r.Work, data: *History) !Advance {
    const bound = data.bound();
    const pages: q.RelationalState = .{ .publication = stored.publication(turn.view.resource) };
    const candidate = try allocator.create(Candidate);
    candidate.* = try Candidate.init(pages, turn, work.next_record, work.state_bytes, bound, 8 * f.RelationalIndex.max_candidate_records);
    const previous: ?f.RelationalCheckpoint = if (work.checkpoint == 0) null else try pages.checkpoint(turn, work.checkpoint, bound);
    var groups: Groups = .{ .index = try f.RelationalIndex.init(bound, if (previous) |old| old.root else null), .candidate = candidate };
    var engine = if (previous) |old| try Engine.restore(bound, data, &groups, old) else try Engine.init(bound, data, &groups);
    if (engine.result_rows != work.outputs) return error.InvalidMaintainedRecord;
    var failure: ?finite.Failure = null;
    const event = engine.step() catch |err| blk: {
        if (turn.read_error != null) return err;
        failure = (try finite.Failure.fromError(err)) orelse return err;
        groups.index.root = if (previous) |old| old.root else null;
        candidate.count = 0;
        candidate.bytes = 0;
        break :blk f.RelationalExecution.Event.progress;
    };
    const progress = try engine.checkpoint(groups.index.root);
    var bytes: [f.RelationalCheckpoint.max_bytes]u8 = undefined;
    const checkpoint = try progress.encode(bound, &bytes);
    const checkpoint_ref = try allocated(turn, stored, try candidate.checkpointId(), q.RelationalState.checkpoint_format, checkpoint);
    var proposed = work;
    proposed.checkpoint = checkpoint_ref.record;
    proposed.next_record = try std.math.add(u64, checkpoint_ref.record, 1);
    proposed.state_bytes = if (failure != null) try std.math.add(u64, work.state_bytes, checkpoint.len) else try candidate.retainedBytes(checkpoint.len);
    var output_bytes: [f.RelationalOutput.max_bytes]u8 = undefined;
    var output_body: ?[]const u8 = null;
    var output_record: ?finite.Output = null;
    if (event == .row) {
        output_body = try (f.RelationalOutput{ .binding = try bound.fingerprint(), .ordinal = work.outputs, .row = event.row }).encode(bound, &output_bytes);
        output_record = .{ .ordinal = work.outputs, .reference = try allocated(turn, stored, proposed.next_record, finite.output_format, output_body.?) };
        proposed.next_record = try std.math.add(u64, proposed.next_record, 1);
        proposed.state_bytes = try std.math.add(u64, proposed.state_bytes, output_body.?.len);
        proposed.outputs = try std.math.add(u64, proposed.outputs, 1);
        proposed.output_bytes = try std.math.add(u64, proposed.output_bytes, output_body.?.len);
        proposed.chain = try output_record.?.extend(work.chain);
    }
    if (failure != null) proposed.phase = .failed else if (event == .complete) proposed.phase = .delta;
    if (failure == null and proposed.state_bytes > bound.plan.budgets.spill_bytes) return error.RelationalSpillBudget;
    var pending = stored;
    pending.phase = .running;
    try schedule(turn, &pending);
    if (!try candidate.stage(turn) or !try stage(turn, checkpoint_ref, checkpoint)) return .progress;
    if (output_record) |record| if (!try stage(turn, record.reference, output_body.?)) return .progress;
    if (!onlyScheduled(turn, stored)) return .progress;
    try data.validate(bound);
    try turn.write(try workKey(stored), try proposed.encode());
    if (failure) |cause| {
        try close(turn, stored.identity(), .failed, cause);
        return .closed;
    }
    if (output_record) |record| {
        const key = r.key('o', stored.id, work.revision, work.outputs);
        if (try turn.read(key) != null) return error.InvalidMaintainedRecord;
        try turn.write(key, try record.encode());
    }
    return .progress;
}
fn output(turn: *Turn, stored: r.Head, revision: u64, ordinal: u64, bound: f.Relational.Bound) !f.RelationalOutput {
    const record = try finite.Output.decode((try turn.read(r.key('o', stored.id, revision, ordinal))) orelse return error.MissingResultSegment);
    if (record.ordinal != ordinal or record.reference.resource != turn.view.resource or record.reference.namespace != stored.namespace()) return error.InvalidMaintainedRecord;
    var bytes: [f.RelationalOutput.max_bytes]u8 = undefined;
    const value = try f.RelationalOutput.decode(bound, try readBody(record.reference, turn, &bytes));
    if (value.ordinal != ordinal) return error.InvalidMaintainedRecord;
    return value;
}
fn delta(turn: *Turn, bundle: q.RelationalBundle, stored: r.Head, work: r.Work, data: *History, previous: ?r.Manifest) !Advance {
    var old_cuts: [f.Relational.max_sources]f.Relational.Cut = undefined;
    if (previous) |old| try old.vector.boundCuts(bundle, &old_cuts);
    const old_bound: ?f.Relational.Bound = if (previous != null) .{ .plan = bundle.plan, .cuts = old_cuts[0..bundle.sources.len] } else null;
    const old_count = if (previous) |old| old.work.outputs else 0;
    if (work.old_cursor > old_count) return error.InvalidMaintainedRecord;
    const before = if (work.old_cursor < old_count) try output(turn, stored, previous.?.work.revision, work.old_cursor, old_bound.?) else null;
    const after = if (work.new_cursor < work.outputs) try output(turn, stored, work.revision, work.new_cursor, data.bound()) else null;
    var proposed = work;
    var change: ?f.RelationalDelta = null;
    if (before == null and after == null) {
        proposed.phase = .manifest;
    } else {
        const order: std.math.Order = if (before == null) .gt else if (after == null) .lt else try f.RelationalDelta.identityOrder(before.?.row.identity, after.?.row.identity);
        if (order != .gt) proposed.old_cursor += 1;
        if (order != .lt) proposed.new_cursor += 1;
        if (order != .eq or !f.RelationalDelta.sameValues(before.?.row, after.?.row)) change = .{ .ordinal = work.deltas, .before = if (order != .gt) before else null, .after = if (order != .lt) after else null };
    }
    var pending = stored;
    try schedule(turn, &pending);
    if (change) |value| {
        var bytes: [f.RelationalDelta.max_bytes]u8 = undefined;
        const encoded = try value.encode(old_bound, data.bound(), &bytes);
        const record: r.Delta = .{ .ordinal = work.deltas, .reference = try allocated(turn, stored, work.next_record, r.delta_format, encoded) };
        proposed.next_record = try std.math.add(u64, proposed.next_record, 1);
        proposed.state_bytes = try std.math.add(u64, proposed.state_bytes, encoded.len);
        proposed.deltas = try std.math.add(u64, proposed.deltas, 1);
        proposed.delta_bytes = try std.math.add(u64, proposed.delta_bytes, encoded.len);
        proposed.delta_chain = try record.extend(work.delta_chain);
        if (proposed.state_bytes > bundle.plan.budgets.spill_bytes) return error.RelationalSpillBudget;
        if (!try stage(turn, record.reference, encoded) or !onlyScheduled(turn, stored)) return .progress;
        const key = r.key('d', stored.id, work.revision, work.deltas);
        if (try turn.read(key) != null) return error.InvalidMaintainedRecord;
        try turn.write(key, try record.encode());
    }
    try data.validate(data.bound());
    try turn.write(try workKey(stored), try proposed.encode());
    return .progress;
}
fn publish(turn: *Turn, bundle: q.RelationalBundle, stored: r.Head, work: r.Work, data: *History, previous: ?r.Manifest) !Advance {
    const publication = stored.publication(turn.view.resource);
    const pages: q.RelationalState = .{ .publication = publication };
    const checkpoint = try pages.checkpoint(turn, work.checkpoint, data.bound());
    if (checkpoint.phase != .complete or checkpoint.result_rows != work.outputs or work.new_cursor != work.outputs or work.old_cursor != if (previous) |old| old.work.outputs else @as(u64, 0)) return error.IncompleteResult;
    var proposed = work;
    proposed.phase = .complete;
    proposed.manifest = work.next_record;
    proposed.next_record = try std.math.add(u64, proposed.manifest, 1);
    var result: r.Manifest = .{ .id = stored.id, .work = proposed, .previous = if (previous != null) try storedReference(turn, publication, stored.manifest) else null, .vector = data.vector, .checkpoint = try storedReference(turn, publication, work.checkpoint) };
    var bytes: [r.Manifest.max_bytes]u8 = undefined;
    const size = (try result.encode(bundle, &bytes)).len;
    proposed.state_bytes = try std.math.add(u64, proposed.state_bytes, size);
    if (proposed.state_bytes > bundle.plan.budgets.spill_bytes) return error.RelationalSpillBudget;
    result.work = proposed;
    const encoded = try result.encode(bundle, &bytes);
    const ref = try allocated(turn, stored, proposed.manifest, r.revision_format, encoded);
    var pending = stored;
    try schedule(turn, &pending);
    if (!try stage(turn, ref, encoded) or !onlyScheduled(turn, stored)) return .progress;
    try data.validate(data.bound());
    var complete = pending;
    complete.revision = proposed.revision;
    complete.manifest = proposed.manifest;
    complete.next_record = proposed.next_record;
    complete.state_bytes = proposed.state_bytes;
    complete.phase = .idle;
    try turn.write(try workKey(stored), try proposed.encode());
    try turn.write(r.key('r', stored.id, proposed.revision, 0), try ref.encode());
    try turn.write(complete.identity().address(), try complete.encode());
    return .complete;
}

test {
    _ = @import("relational_maintenance_test.zig");
}
