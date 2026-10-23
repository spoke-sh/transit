//! Source-owned finite v1 capture. Accepted request references and retained cuts
//! are durable; workspaces and decoded bundles are disposable handler memory.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const f = q.fuze;
const r = q.UnifiedRecords;
const Turn = s.Turn;
const Pub = s.Publication;
const Ref = s.PublicationReference;
const Pin = q.CapturedTablePin;
fn direct(source: anytype) !q.catalog.DirectTableClient {
    const T = switch (@typeInfo(@TypeOf(source))) {
        .pointer => |pointer| pointer.child,
        else => @TypeOf(source),
    };
    if (comptime @hasField(T, "tables")) return source.tables orelse error.QuerySourceUnavailable;
    return error.QuerySourceUnavailable;
}
fn pinSlot(id: u64) Pin.Slot {
    return .{ .job = id, .source = 0 };
}

pub fn policy(source: anytype, peer: u64) !?r.Policy {
    const value = (try source.read(r.key('p', peer, 0))) orelse return null;
    const result = try r.Policy.decode(value);
    if (result.peer != peer) return error.InvalidQueryPolicy;
    return result;
}
pub fn setPolicy(turn: *Turn, next: r.Policy) !void {
    const encoded = try next.encode();
    if (next.target == .catalog) {
        const grant = next.target.catalog;
        if (grant.scope.realm != turn.delivery.realm) return error.InvalidQueryPolicy;
    }
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
    return permittedDiagnostic(source, stored, null);
}
fn permittedDiagnostic(source: anytype, stored: r.Job, diagnostic: ?*?q.SourceWitness) !?r.Policy {
    const grant = (try policy(source, stored.destination)) orelse {
        if (diagnostic) |detail| detail.* = .{ .reason = .policy_missing, .resource = source.view.resource, .expected = stored.policy_revision };
        return null;
    };
    const reason: ?q.SourceWitness.Reason = if (!grant.allow) .policy_disabled else if (grant.revision != stored.policy_revision) .policy_revision else if (grant.requests != stored.request.resource) .request_resource else null;
    if (reason) |cause| {
        if (diagnostic) |detail| detail.* = .{
            .reason = cause,
            .resource = source.view.resource,
            .expected = if (cause == .request_resource) stored.request.resource else stored.policy_revision,
            .actual = if (cause == .request_resource) grant.requests else grant.revision,
        };
        return null;
    }
    return grant;
}
fn matches(bundle: q.Bundle, grant: r.Policy, resource: u64, diagnostic: ?*?q.SourceWitness) !?u64 {
    try bundle.validate();
    if (bundle.source.source != .table and bundle.source.resource != resource) {
        if (diagnostic) |detail| detail.* = .{ .reason = .resource, .resource = resource, .expected = resource, .actual = bundle.source.resource };
        return error.QueryDenied;
    }
    const declaration = try q.Bundle.declaration(bundle.source);
    const principal = grant.principal(bundle.source) catch |err| {
        if (diagnostic) |detail| detail.* = .{ .reason = .declaration, .resource = resource, .expected_hash = try grant.target.fingerprint(), .actual_hash = declaration };
        return err;
    };
    inline for (.{ "pages", "segments", "result_bytes" }) |field| if (@field(bundle.limits, field) > @field(grant.limits, field)) {
        if (diagnostic) |detail| detail.* = .{ .reason = .policy_budget, .resource = resource, .dimension = @field(q.QueryFailure.Dimension, field), .expected = @field(grant.limits, field), .actual = @field(bundle.limits, field) };
        return error.QueryDenied;
    };
    return principal;
}

fn schedule(turn: *Turn, stored: *r.Job) !void {
    stored.continuation = turn.delivery.input.position;
    try turn.write(r.key('j', stored.id, 0), try stored.encode());
    try turn.cast(turn.delivery.pid, try (r.Continuation{ .job = stored.id, .input = stored.continuation }).encode());
}
/// One current peer and request-resource policy owns admission. Retention and
/// all records become live only with this whole four-mutation turn.
pub fn start(turn: *Turn, reference: Ref, source: anytype, allocator: std.mem.Allocator) !r.Job {
    return startDiagnostic(turn, reference, source, allocator, null);
}
pub fn startDiagnostic(turn: *Turn, reference: Ref, source: anytype, allocator: std.mem.Allocator, diagnostic: ?*?q.QueryFailure) !r.Job {
    return startAllocated(turn, reference, source, allocator, false, diagnostic);
}
/// Only local allocation sites use this buffer. External publication reads and
/// poisoned current/retained reads preserve their original failure.
pub fn startBoundedDiagnostic(turn: *Turn, reference: Ref, source: anytype, buffer: []u8, diagnostic: ?*?q.QueryFailure) !r.Job {
    var fixed: std.heap.FixedBufferAllocator = .init(buffer);
    return startAllocated(turn, reference, source, fixed.allocator(), true, diagnostic);
}
fn startAllocated(turn: *Turn, reference: Ref, source: anytype, allocator: std.mem.Allocator, comptime bounded: bool, diagnostic: ?*?q.QueryFailure) !r.Job {
    if (diagnostic) |detail| detail.* = null;
    var source_witness: ?q.SourceWitness = null;
    return startWitness(turn, reference, source, allocator, bounded, &source_witness) catch |err| {
        if (diagnostic) |detail| if (source_witness) |value| {
            if (q.QueryFailure.fromError(err, .admission)) |failure| {
                detail.* = failure;
                detail.*.?.source = value;
                detail.*.?.validate() catch {
                    detail.*.?.source = null;
                };
            }
        };
        return err;
    };
}
/// Call only around pure decode/allocation or source operations whose external
/// reads poison this turn. Never wrap request-publication/network operations.
fn allocationFailure(err: anyerror, comptime bounded: bool, turn: *const Turn) anyerror {
    return if (bounded and err == error.OutOfMemory and turn.read_error == null) error.QueryAdapterBudgetExceeded else err;
}
fn startWitness(turn: *Turn, reference: Ref, source: anytype, allocator: std.mem.Allocator, comptime bounded: bool, witness: *?q.SourceWitness) !r.Job {
    const before = turn.decision;
    errdefer turn.decision = before;
    for (before.mutations) |mutation| if (mutation != null) return error.QueryAfterMutation;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .call) return error.ExpectedCall;
    const peer = try s.Frame.source(turn.delivery.input);
    const grant = (try policy(turn, peer)) orelse {
        witness.* = .{ .reason = .policy_missing, .resource = turn.view.resource };
        return error.QueryDenied;
    };
    try q.Bundle.checkReference(reference);
    if (!grant.allow or grant.requests != reference.resource) {
        witness.* = if (!grant.allow) .{ .reason = .policy_disabled, .resource = turn.view.resource, .actual = grant.revision } else .{ .reason = .request_resource, .resource = turn.view.resource, .expected = grant.requests, .actual = reference.resource };
        return error.QueryDenied;
    }
    if (try turn.read(r.key('i', peer, frame.correlation)) != null) return error.CorrelationAlreadyUsed;
    var buffer: [q.Bundle.max_bytes]u8 = undefined;
    const request_bytes = try reference.read(source, &buffer);
    const bundle = q.Bundle.decode(allocator, request_bytes) catch |err| return allocationFailure(err, bounded, turn);
    try q.Bundle.checkPublisher(reference, source, peer);
    const principal = try matches(bundle, grant, turn.view.resource, witness);
    try bundle.bindSubject(turn, peer, reference.resource, principal);
    var captured: ?q.Basis = null;
    const table = bundle.source.source == .table;
    if (table) {
        try Pin.authorizeAdmission(turn, bundle.retention.?, try direct(source));
    } else {
        try q.UnifiedSource.checkCurrentDiagnostic(bundle.source, turn, principal, witness);
        captured = q.UnifiedSource.captureDiagnostic(bundle.source, turn, turn, principal, allocator, witness) catch |err| return allocationFailure(err, bounded, turn);
    }
    var stored: r.Job = .{ .id = turn.delivery.input.position, .destination = peer, .correlation = frame.correlation, .policy_revision = grant.revision, .source = if (table) .{ .table = .{ .worker = turn.delivery.pid } } else .{ .native = try turn.retain() }, .phase = if (table) .admitted else .capturing, .request = reference, .continuation = turn.delivery.input.position };
    const publication = stored.publication(turn.view.resource);
    if (try turn.read(r.key('j', stored.id, 0)) != null or try turn.read(Pub.key(publication.domain, publication.namespace, 'b', 0, 0)) != null) return error.QueryNamespaceInUse;
    _ = try Pub.create(turn, .query_result, publication.namespace, .{ .record_bytes = f.LogicalArrow.segment_bytes, .staging_bytes = f.LogicalArrow.segment_bytes, .staging_records = 1 });
    if (captured) |value| try turn.write(r.key('c', stored.id, 0), try (r.Checkpoint{ .cut = value.cut, .progress = try f.LogicalStream.Progress.start(try bundle.bind(try value.fingerprint())) }).encode());
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
    return advanceAllocated(turn, continuation, source, allocator, false, workspace, cancellation, diagnostic);
}
pub fn advanceBoundedDiagnostic(turn: *Turn, continuation: r.Continuation, source: anytype, buffer: []u8, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation, diagnostic: ?*?q.QueryFailure) !Advance {
    var fixed: std.heap.FixedBufferAllocator = .init(buffer);
    return advanceAllocated(turn, continuation, source, fixed.allocator(), true, workspace, cancellation, diagnostic);
}
fn advanceAllocated(turn: *Turn, continuation: r.Continuation, source: anytype, allocator: std.mem.Allocator, comptime bounded: bool, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation, diagnostic: ?*?q.QueryFailure) !Advance {
    if (diagnostic) |detail| detail.* = null;
    var source_witness: ?q.SourceWitness = null;
    return advanceWitness(turn, continuation, source, allocator, bounded, workspace, cancellation, &source_witness, diagnostic) catch |err| {
        if (diagnostic) |detail| if (source_witness) |value| {
            if (q.QueryFailure.fromError(err, .execution)) |failure| {
                detail.* = failure;
                detail.*.?.source = value;
                detail.*.?.validate() catch {
                    detail.*.?.source = null;
                };
            }
        };
        return err;
    };
}
fn advanceWitness(turn: *Turn, continuation: r.Continuation, source: anytype, allocator: std.mem.Allocator, comptime bounded: bool, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation, witness: *?q.SourceWitness, diagnostic: ?*?q.QueryFailure) !Advance {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (try s.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.UnexpectedQueryContinuation;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or !frame.payload.eql(try continuation.encode())) return error.InvalidQueryContinuation;
    var stored = try job(turn, continuation.job);
    if (stored.source.worker() != turn.delivery.pid) return error.InvalidQueryJob;
    if (stored.phase == .complete) {
        _ = try settlePin(allocator, turn, stored, source);
        return .duplicate;
    }
    if (stored.phase != .admitted and stored.phase != .acquiring and stored.phase != .capturing and stored.phase != .captured) {
        if (try settlePin(allocator, turn, stored, source)) {
            try schedule(turn, &stored);
        } else try cleanup(turn, &stored);
        return .closed;
    }
    if (continuation.input < stored.continuation) return .duplicate;
    if (continuation.input != stored.continuation) return error.InvalidQueryContinuation;
    const grant = (try permittedDiagnostic(turn, stored, witness)) orelse {
        var failure = q.QueryFailure.fromError(error.QueryDenied, .execution).?;
        failure.source = witness.*;
        failure.validate() catch {
            failure.source = null;
        };
        try closeFailure(turn, stored.id, failure);
        return .closed;
    };
    if (cancellation.load(.acquire)) return error.Cancelled;
    var buffer: [q.Bundle.max_bytes]u8 = undefined;
    const request_bytes = try stored.request.read(source, &buffer);
    const bundle = q.Bundle.decode(allocator, request_bytes) catch |err| return allocationFailure(err, bounded, turn);
    try q.Bundle.checkPublisher(stored.request, source, stored.destination);
    const principal = try matches(bundle, grant, turn.view.resource, witness);
    try bundle.bindSubject(turn, stored.destination, stored.request.resource, principal);
    if ((bundle.source.source == .table) != (stored.source == .table)) return error.InvalidQueryJob;
    if (stored.phase == .admitted) {
        try Pin.authorizeAdmission(turn, bundle.retention.?, try direct(source));
        try Pin.prepare(allocator, turn, pinSlot(stored.id), bundle.retention.?);
        stored.phase = .acquiring;
        try schedule(turn, &stored);
        return .progress;
    }
    if (stored.phase == .acquiring) {
        const retained = try Pin.acquire(allocator, turn, pinSlot(stored.id), try direct(source));
        if (!std.meta.eql(retained.interpretation, bundle.source.source.table.interpretation)) return error.SourceChanged;
        try Pin.authorizeSource(turn, bundle.retention.?, retained.authority);
        const tables = try Pin.readClient(allocator, turn, pinSlot(stored.id), try direct(source));
        const captured = try bundle.source.source.table.capture(allocator, tables, retained.snapshot);
        if (!std.meta.eql(captured.retained, retained)) return error.SourceChanged;
        try turn.write(r.key('c', stored.id, 0), try (r.Checkpoint{ .cut = (try captured.record()).cut, .progress = try f.LogicalStream.Progress.start(try bundle.bind(try captured.fingerprint())) }).encode());
        stored.phase = .capturing;
        try schedule(turn, &stored);
        return .progress;
    }
    if (stored.source == .table) {
        try Pin.authorizeExecution(allocator, turn, pinSlot(stored.id));
    } else try q.UnifiedSource.checkCurrentDiagnostic(bundle.source, turn, principal, witness);
    const previous = try checkpoint(turn, stored.id);
    const bound = try previous.bound(bundle);
    const captured = try previous.basis(bundle.source);
    if (stored.phase == .captured) {
        if (stored.source == .table) {
            const pin = (try Pin.inspect(allocator, turn, pinSlot(stored.id))) orelse return error.IncompleteSource;
            if (pin.phase == .acquiring) {
                // Final segment publication, checkpoint and job already use
                // all four mutations. Record release eligibility in this
                // subsequent turn, after traversal is durably complete.
                try Pin.beginClose(allocator, turn, pinSlot(stored.id));
                try schedule(turn, &stored);
                return .progress;
            }
        }
        _ = try settlePin(allocator, turn, stored, source);
        try publishManifest(turn, &stored, previous);
        return if (stored.phase == .complete) .complete else .progress;
    }
    if (previous.progress.pages >= bundle.limits.pages) {
        if (diagnostic) |detail| detail.* = .{ .code = .budget_exceeded, .stage = .execution, .dimension = .pages, .limit = bundle.limits.pages, .observed = try std.math.add(u64, previous.progress.pages, 1) };
        return error.QueryBudgetExceeded;
    }
    var page: q.UnifiedSource.Batch = undefined;
    if (bound.limit == 0) {
        page = .{ .basis = captured, .binding = bound.source_basis, .ordinal = previous.cursor.ordinal, .next = .{ .ordinal = try std.math.add(u64, previous.cursor.ordinal, 1), .done = true } };
    } else if (stored.source == .table) {
        var current = turn.committed();
        const retained = try Pin.source(allocator, &current, pinSlot(stored.id), turn.delivery.pid);
        const tables = try Pin.readClient(allocator, turn, pinSlot(stored.id), try direct(source));
        q.UnifiedSource.tablePage(bundle.source, bound, captured, retained, previous.cursor, tables, allocator, &page) catch |err| return allocationFailure(err, bounded, turn);
        try Pin.authorizeExecution(allocator, turn, pinSlot(stored.id));
    } else {
        var retained = try turn.openVersion(stored.source.native);
        q.UnifiedSource.page(bundle.source, bound, captured, previous.cursor, &retained, turn, principal, allocator, &page) catch |err| return allocationFailure(err, bounded, turn);
    }
    defer page.deinit();
    var bytes: [f.LogicalArrow.segment_bytes]u8 = undefined;
    var runtime: ?f.LogicalStream.Failure = null;
    const candidate = f.LogicalStream.step(bound, previous.progress, page.engine(), workspace, &bytes, cancellation, &runtime) catch |err| {
        const cause = if (err == error.WriteFailed) error.QuerySegmentBudgetExceeded else err;
        if (diagnostic) |detail| if (runtime) |runtime_failure| {
            if (q.QueryFailure.fromError(cause, .execution)) |failure| {
                detail.* = failure;
                detail.*.?.runtime = q.RuntimeWitness.capture(bound, &page, runtime_failure) catch null;
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
        if (stored.source == .native) try turn.release(stored.source.native);
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
    if (stored.source.worker() != turn.delivery.pid) return error.InvalidQueryJob;
    if (stored.phase != .admitted and stored.phase != .acquiring and stored.phase != .capturing and stored.phase != .captured and stored.phase != .complete) return;
    if (stored.phase == .complete and phase != .retired) return;
    if (phase == .retired and stored.phase != .complete) return error.IncompleteResult;
    if (stored.source == .native and stored.phase == .capturing) try turn.release(stored.source.native);
    if (stored.source == .table and stored.phase != .admitted) {
        var memory: [16384]u8 = undefined;
        var fixed: std.heap.FixedBufferAllocator = .init(&memory);
        try Pin.beginClose(fixed.allocator(), turn, pinSlot(stored.id));
    }
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
    const recorded = try turn.read(r.key('c', stored.id, 0));
    const segments = if (recorded) |value| (try r.Checkpoint.decode(value)).progress.segments else 0;
    stored.cleanup = if (stored.cleanup == r.manifest_record) 0 else if (stored.cleanup > segments) r.manifest_record else stored.cleanup + 1;
    if (stored.cleanup == 0) try turn.write(r.key('j', stored.id, 0), try stored.encode()) else try schedule(turn, stored);
}

/// Cleanup is independent of result completeness. A known current denial or
/// transport outage leaves the durable closing record for explicit retry.
/// Corruption/unknown errors still fail this attempt without claiming closure.
fn settlePin(allocator: std.mem.Allocator, turn: *Turn, stored: r.Job, resources: anytype) !bool {
    if (stored.source != .table) return false;
    const record = (try Pin.inspect(allocator, turn, pinSlot(stored.id))) orelse return false;
    if (record.phase == .closed) return false;
    if (record.phase != .closing) return error.QueryActive;
    const tables = try direct(resources);
    Pin.settle(allocator, turn, pinSlot(stored.id), tables) catch |err| {
        if (q.wire.Client.unavailable(err) or err == error.AccessDenied or (err == error.Conflict and (tables.authority.last_rejection == .StaleAuthorizationCredential or tables.service.last_rejection == .StaleAuthorizationCredential))) return false;
        return err;
    };
    return true;
}
/// The caller authenticates the requester route before retrying terminal work.
/// This cannot release a job that is still consuming its source.
pub fn retryCleanup(allocator: std.mem.Allocator, turn: *Turn, id: u64, resources: anytype, authorization: ?q.catalog.DirectReadDelegation.Closure) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var stored = try job(turn, id);
    if (stored.source.worker() != turn.delivery.pid) return error.InvalidQueryJob;
    if (stored.phase == .admitted or stored.phase == .acquiring or stored.phase == .capturing or stored.phase == .captured) return error.QueryActive;
    if (authorization) |permission| {
        if (stored.source != .table) return error.InvalidQueryJob;
        // Admission can close before acquisition eligibility was committed. No
        // pin exists in that case, and cleanup must not create one. A retained
        // checkpoint, however, requires the original immutable pin evidence.
        if (try Pin.inspect(allocator, turn, pinSlot(stored.id)) == null) {
            if (stored.phase == .complete or try turn.read(r.key('c', stored.id, 0)) != null) return error.IncompleteSource;
            return cleanup(turn, &stored);
        }
        try Pin.authorizeCleanup(allocator, turn, pinSlot(stored.id), try direct(resources), permission);
        // The permission becomes usable only after this proposal commits.
        try schedule(turn, &stored);
        return;
    }
    if (try settlePin(allocator, turn, stored, resources)) return;
    if (stored.phase != .complete) try cleanup(turn, &stored);
}
