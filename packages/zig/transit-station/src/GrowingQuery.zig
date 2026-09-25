//! Incremental capture in ordinary bounded private turns. No call performs I/O
//! outside the captured reader or publishes mutations before authority commit.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig").Growing;
const Table = @import("Table.zig");
const Frame = @import("Frame.zig");
const q = @import("Query.zig");
pub const records = @import("QueryRecords.zig");
pub const Job = records.Job;
pub const Segment = records.Segment;
pub const Continuation = records.Continuation;
const Stage = records.Stage;
const key = records.key;
pub const policy = q.policy;
pub const setPolicy = q.setPolicy;

pub fn job(turn: *Turn, identity: u64) !Job {
    const stored = try Job.decode((try turn.read(key('j', identity, 0, 0))) orelse return error.MissingResult);
    if (stored.result != identity or stored.source.pid != turn.delivery.pid) return error.InvalidQueryJob;
    return stored;
}
pub fn progress(turn: *Turn, identity: u64) !f.Stream.Progress {
    return f.Stream.Progress.decode(((try turn.read(key('e', identity, 0, 0))) orelse return error.MissingQueryProgress).slice());
}
fn permitted(turn: *Turn, stored: Job) !bool {
    const grant = (try policy(turn, stored.destination)) orelse return false;
    return grant.allow and grant.table == stored.table and grant.revision == stored.policy_revision;
}
fn continueCapture(turn: *Turn, next: Continuation) !void {
    try turn.cast(turn.delivery.pid, try next.encode());
}
pub fn start(turn: *Turn, table: Table, plan: f.Stream.Plan) !Job {
    const before = turn.decision;
    errdefer turn.decision = before;
    for (before.mutations) |mutation| if (mutation != null) return error.QueryAfterMutation;
    const call = try Frame.decode(turn.delivery.input.value);
    if (call.kind != .call) return error.ExpectedCall;
    const peer = try Frame.source(turn.delivery.input);
    const grant = (try policy(turn, peer)) orelse return error.QueryDenied;
    if (!grant.allow or grant.table != table.id) return error.QueryDenied;
    if (try turn.read(key('i', peer, call.correlation, 0)) != null) return error.CorrelationAlreadyUsed;
    const current = try Table.open(turn, table.id);
    if (!std.meta.eql(current, table)) return error.TableSchemaChanged;
    const identity = turn.delivery.input.position;
    if (try turn.read(key('j', identity, 0, 0)) != null) return error.ResultAlreadyExists;
    const bound = try plan.bind(.{ .resource = turn.view.resource, .revision = turn.view.revision, .schema = try table.schema.fingerprint() }, table.schema);
    var encoded: [f.Stream.PlanCodec.encoded_bytes]u8 = undefined;
    const plan_bytes = try f.Stream.PlanCodec.encode(plan, &encoded);
    const stored: Job = .{ .result = identity, .destination = peer, .correlation = call.correlation, .table = table.id, .source = try turn.retain(), .policy_revision = grant.revision };
    try turn.write(key('j', identity, 0, 0), try stored.encode());
    try turn.write(key('p', identity, 0, 0), try p.Value.init(plan_bytes));
    try turn.write(key('e', identity, 0, 0), try p.Value.init(&try bound.start().encode()));
    var index: [8]u8 = undefined;
    std.mem.writeInt(u64, &index, identity, .little);
    try turn.write(key('i', peer, call.correlation, 0), try p.Value.init(&index));
    try continueCapture(turn, .{ .result = identity, .page = 0 });
    try turn.validate();
    return stored;
}
pub const Advance = enum { progress, captured, closed, duplicate };
/// The application dispatches the recorded self-continuation with bounded
/// workspace. Result publication is separate from successful capture.
pub fn advance(turn: *Turn, request: Continuation, workspace: []u8, cancellation: *const f.execution.Cancellation) !Advance {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (try Frame.source(turn.delivery.input) != turn.delivery.pid) return error.UnexpectedResultContinuation;
    const frame = try Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or !frame.payload.eql(try request.encode())) return error.InvalidQueryContinuation;
    var stored = try job(turn, request.result);
    if (stored.phase != .capturing) return .duplicate;
    if (!try permitted(turn, stored)) {
        try close(turn, stored.result, .denied);
        return .closed;
    }
    const previous = try progress(turn, stored.result);
    const stage_value = try turn.read(key('s', stored.result, 0, 0));
    const stage = if (stage_value) |value| try Stage.decode(value) else null;
    const written: u16 = if (stage) |value| value.written else 0;
    if (request.page < previous.pages or (request.page == previous.pages and request.written < written)) return .duplicate;
    if (request.page != previous.pages or request.written != written) return error.InvalidQueryContinuation;
    const logical = try f.Stream.PlanCodec.decode(((try turn.read(key('p', stored.result, 0, 0))) orelse return error.MissingQueryPlan).slice());
    var source = try turn.openVersion(stored.source);
    const table = try Table.open(&source, stored.table);
    const bound = try logical.bind(previous.basis, table.schema);
    try previous.validate(bound);
    const cursor: ?Table.Cursor = if (previous.last_key) |last| .{ .source = .{ .version = stored.source }, .resource = previous.basis.resource, .revision = previous.basis.revision, .table = table.id, .schema = previous.basis.schema, .after = last } else null;
    const page = try table.page(&source, cursor);
    var bytes: [records.segment_bytes]u8 = undefined;
    const candidate = try f.Stream.step(bound, previous, .{ .ordinal = previous.pages, .source = .{ .basis = page.basis, .schema = table.schema, .rows = page.rows[0..page.len] }, .end = page.next == null }, workspace, &bytes, cancellation);
    if (candidate.segment) |segment| {
        var next: Stage = .{ .candidate = candidate.progress, .segment = .{ .result = stored.result, .ordinal = previous.segments, .bytes = @intCast(segment.bytes.len), .rows = segment.rows, .digest = segment.digest }, .written = written };
        if (stage) |expected| if (!std.meta.eql(expected, next)) return error.QueryStageChanged;
        if (written == next.segment.bytes) {
            var staged: [records.segment_bytes]u8 = undefined;
            _ = try readSegment(turn, next.segment, &staged);
            try turn.write(key('m', stored.result, next.segment.ordinal, 0), try next.segment.encode());
            try turn.write(key('e', stored.result, 0, 0), try p.Value.init(&try candidate.progress.encode()));
            stored.bytes = try std.math.add(u64, stored.bytes, next.segment.bytes);
            stored.chain = try next.segment.extend(stored.chain);
            if (candidate.progress.finished != null) {
                stored.phase = .captured;
                try turn.release(stored.source);
            }
            try turn.write(key('j', stored.result, 0, 0), try stored.encode());
            try turn.write(key('s', stored.result, 0, 0), null);
            if (stored.phase == .capturing) try continueCapture(turn, .{ .result = stored.result, .page = candidate.progress.pages });
            try turn.validate();
            return if (stored.phase == .captured) .captured else .progress;
        }
        // Three fragments plus one staging record fit the atomic budget.
        for (0..3) |_| {
            if (next.written == next.segment.bytes) break;
            const end: u16 = @intCast(@min(@as(usize, next.written) + records.fragment_bytes, next.segment.bytes));
            const fragment_key = key('f', stored.result, next.segment.ordinal, next.written / records.fragment_bytes);
            const fragment = try p.Value.init(segment.bytes[next.written..end]);
            if (try turn.read(fragment_key)) |old| {
                if (!old.eql(fragment)) return error.ConflictingResultFragment;
            } else try turn.write(fragment_key, fragment);
            next.written = end;
        }
        try turn.write(key('s', stored.result, 0, 0), try next.encode());
        try continueCapture(turn, .{ .result = stored.result, .page = previous.pages, .written = next.written });
    } else {
        if (stage != null or candidate.progress.finished != null) return error.InvalidQueryStage;
        try turn.write(key('e', stored.result, 0, 0), try p.Value.init(&try candidate.progress.encode()));
        try continueCapture(turn, .{ .result = stored.result, .page = candidate.progress.pages });
    }
    try turn.validate();
    return .progress;
}
/// Close explicitly in a fresh private proposal, before any failed source read.
/// No retained source read is needed; current process/job-resource rights are.
pub fn close(turn: *Turn, identity: u64, phase: enum { cancelled, denied }) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var stored = try job(turn, identity);
    if (stored.phase == .acknowledged or stored.phase == .cancelled or stored.phase == .denied) return;
    if (stored.phase == .capturing) try turn.release(stored.source);
    stored.phase = if (phase == .cancelled) .cancelled else .denied;
    try turn.write(key('j', identity, 0, 0), try stored.encode());
    try turn.send(stored.destination, .{ .kind = .reply, .correlation = stored.correlation, .payload = try p.Value.init(if (phase == .cancelled) "station.query.cancelled.v2" else "station.query.denied.v2") });
    try turn.validate();
}
pub const Captured = struct { job: Job, progress: f.Stream.Progress };
pub fn captured(turn: *Turn, identity: u64) !Captured {
    const stored = try job(turn, identity);
    if (stored.phase != .captured and stored.phase != .published and stored.phase != .acknowledged) return error.IncompleteResult;
    const state = try progress(turn, identity);
    if (state.finished == null or state.segments == 0 or stored.bytes == 0 or try turn.read(key('s', identity, 0, 0)) != null) return error.InvalidQueryJob;
    return .{ .job = stored, .progress = state };
}
pub const CapturedSegment = struct { manifest: Segment, bytes: []const u8 };
/// Bounded verified captured bytes. Incomplete jobs expose no complete result.
/// The output borrows the supplied buffer; there is no whole-result allocation.
pub fn capturedSegment(turn: *Turn, identity: u64, ordinal: u64, output: []u8) !CapturedSegment {
    const result = try captured(turn, identity);
    if (ordinal >= result.progress.segments) return error.InvalidQueryOrdinal;
    const manifest = try Segment.decode((try turn.read(key('m', identity, ordinal, 0))) orelse return error.MissingResultSegment);
    if (manifest.result != identity or manifest.ordinal != ordinal) return error.InvalidResultSegment;
    return .{ .manifest = manifest, .bytes = try readSegment(turn, manifest, output) };
}
fn readSegment(turn: *Turn, manifest: Segment, output: []u8) ![]const u8 {
    _ = try Segment.decode(try manifest.encode());
    if (output.len < manifest.bytes) return error.ResultBufferTooSmall;
    var offset: usize = 0;
    while (offset < manifest.bytes) {
        const fragment = (try turn.read(key('f', manifest.result, manifest.ordinal, @intCast(offset / records.fragment_bytes)))) orelse return error.MissingResultFragment;
        const end = @min(offset + records.fragment_bytes, manifest.bytes);
        if (fragment.len != end - offset) return error.InvalidResultFragment;
        @memcpy(output[offset..end], fragment.slice());
        offset = end;
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(output[0..manifest.bytes], &digest, .{});
    if (!std.mem.eql(u8, &digest, &manifest.digest)) return error.InvalidResultDigest;
    return output[0..manifest.bytes];
}
