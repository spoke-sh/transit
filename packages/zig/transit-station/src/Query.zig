//! Incremental capture in ordinary bounded private turns. No call performs I/O
//! outside the captured reader or publishes mutations before authority commit.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const stream = f.LogicalStream;
const Turn = @import("Turn.zig");
const Table = @import("TableReader.zig");
const Frame = @import("Frame.zig");
const q = @import("QueryPolicy.zig");
pub const records = @import("QueryRecords.zig");
pub const Job = records.Job;
pub const Segment = records.Segment;
pub const Continuation = records.Continuation;
const Stage = records.Stage;
const key = records.key;
pub const Policy = q.Policy;
pub const policy = q.policy;
pub const setPolicy = q.setPolicy;
const delivery = @import("QueryDelivery.zig");
pub const Context = delivery.Context;
pub const Manifest = delivery.Manifest;
pub const dispatch = delivery.dispatch;
pub const beginPublication = delivery.begin;
pub const completed = delivery.completed;
pub const completedSegment = delivery.completedSegment;

pub fn job(turn: *Turn, identity: u64) !Job {
    const stored = try Job.decode((try turn.read(key('j', identity, 0, 0))) orelse return error.MissingResult);
    if (stored.result != identity or stored.source.pid != turn.delivery.pid) return error.InvalidQueryJob;
    return stored;
}
pub fn progress(turn: *Turn, identity: u64) !?stream.Progress {
    return if (try turn.read(key('e', identity, 0, 0))) |value| try stream.Progress.decodeRecord(value.slice()) else null;
}
pub fn permitted(turn: *Turn, stored: Job) !bool {
    const grant = (try policy(turn, stored.destination)) orelse return false;
    return grant.allow and grant.table == stored.table and grant.revision == stored.policy_revision;
}
fn continueCapture(turn: *Turn, next: Continuation) !void {
    try turn.cast(turn.delivery.pid, try next.encode());
}
pub fn start(turn: *Turn, table: *const Table, plan: f.LogicalQuery.Plan) !Job {
    const before = turn.decision;
    errdefer turn.decision = before;
    for (before.mutations) |mutation| if (mutation != null) return error.QueryAfterMutation;
    const call = try Frame.decode(turn.delivery.input.value);
    if (call.kind != .call) return error.ExpectedCall;
    const peer = try Frame.source(turn.delivery.input);
    const grant = (try policy(turn, peer)) orelse return error.QueryDenied;
    if (!grant.allow or grant.table != table.head.object) return error.QueryDenied;
    if (try turn.read(key('i', peer, call.correlation, 0)) != null) return error.CorrelationAlreadyUsed;
    try table.validate(turn);
    var columns: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const schema = try table.schema.schema.rowType(&columns);
    if (!std.mem.eql(u8, &table.basis.head, &plan.source_basis) or !try schema.eql(plan.schema)) return error.SourceChanged;
    const identity = turn.delivery.input.position;
    if (try turn.read(key('j', identity, 0, 0)) != null) return error.ResultAlreadyExists;
    // Two plan cells plus job and correlation index fit the four-write native
    // admission. Initial stream progress is reconstructible from this frozen
    // plan, so it is first stored with the first completed page.
    var encoded: [records.max_plan_bytes]u8 = undefined;
    const plan_bytes = f.LogicalPlanCodec.encode(plan, &encoded) catch |err| return if (err == error.WriteFailed) error.QueryPlanTooLarge else err;
    const stored: Job = .{ .result = identity, .destination = peer, .correlation = call.correlation, .table = table.head.object, .source = try turn.retain(), .resource = table.head.resource, .revision = turn.view.revision, .plan_bytes = @intCast(plan_bytes.len), .policy_revision = grant.revision };
    try turn.write(key('j', identity, 0, 0), try stored.encode());
    var offset: usize = 0;
    while (offset < plan_bytes.len) {
        const end = @min(offset + p.Value.max_bytes, plan_bytes.len);
        try turn.write(key('p', identity, 0, @intCast(offset / p.Value.max_bytes)), try p.Value.init(plan_bytes[offset..end]));
        offset = end;
    }
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
pub fn advance(allocator: std.mem.Allocator, turn: *Turn, request: Continuation, workspace: []u8, cancellation: *const f.execution.Cancellation) !Advance {
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
    var source = try turn.openVersion(stored.source);
    var table = try Table.open(allocator, &source, stored.table);
    defer table.deinit();
    if (table.head.resource != stored.resource or source.view.revision != stored.revision) return error.SourceChanged;
    var columns: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var encoded: [records.max_plan_bytes]u8 = undefined;
    var offset: usize = 0;
    while (offset < stored.plan_bytes) {
        const end = @min(offset + p.Value.max_bytes, stored.plan_bytes);
        const part = (try turn.read(key('p', stored.result, 0, @intCast(offset / p.Value.max_bytes)))) orelse return error.MissingQueryPlan;
        if (part.len != end - offset) return error.InvalidQueryPlan;
        @memcpy(encoded[offset..end], part.slice());
        offset = end;
    }
    var decoded = try f.LogicalPlanCodec.decode(allocator, try table.schema.schema.rowType(&columns), table.basis.head, encoded[0..stored.plan_bytes]);
    defer decoded.deinit();
    const logical = decoded.plan;
    const previous = (try progress(turn, stored.result)) orelse try stream.Progress.start(logical);
    const stage_value = try turn.read(key('s', stored.result, 0, 0));
    const stage = if (stage_value) |value| try Stage.decode(value) else null;
    const written: u16 = if (stage) |value| value.written else 0;
    if (request.page < previous.pages or (request.page == previous.pages and request.written < written)) return .duplicate;
    if (request.page != previous.pages or request.written != written) return error.InvalidQueryContinuation;
    try previous.validate(logical);
    const cursor: ?Table.Cursor = if (stored.table_after) |last| .{ .basis = table.basis, .after = last } else null;
    var page = try table.page(allocator, &source, cursor, stream.max_rows);
    defer page.deinit();
    var bytes: [records.segment_bytes]u8 = undefined;
    var rows: [stream.max_rows]f.LogicalArrow.Row = undefined;
    for (page.rows[0..page.len], 0..) |slot, index| rows[index] = .{ .cells = slot.?.row().cells };
    const candidate = stream.step(logical, previous, .{ .ordinal = previous.pages, .binding = logical.source_basis, .rows = rows[0..page.len], .end = page.next == null }, workspace, &bytes, cancellation, null) catch |err| {
        // These failures come from deterministic arithmetic or the encoder's
        // explicit buffers. Host OOM, failed reads and cancellation still abort
        // the private proposal and must never be mislabeled as a query result.
        if (stage != null) return err;
        const reason: records.Failure = switch (err) {
            error.WriteFailed => .result_too_large,
            error.ArrowWorkspaceExceeded => .workspace_exceeded,
            error.Overflow => .overflow,
            else => return err,
        };
        try turn.release(stored.source);
        stored.phase = .failed;
        stored.failure = reason;
        try turn.write(key('j', stored.result, 0, 0), try stored.encode());
        var message: [96]u8 = undefined;
        try turn.send(stored.destination, .{ .kind = .reply, .correlation = stored.correlation, .payload = try p.Value.init(try std.fmt.bufPrint(&message, "station.query.failed.v1:{s}", .{@tagName(reason)})) });
        try turn.validate();
        return .closed;
    };
    stored.table_after = if (page.next) |next| next.after else null;
    if (candidate.segment) |segment| {
        var next: Stage = .{ .candidate = candidate.progress, .segment = .{ .result = stored.result, .ordinal = previous.segments, .bytes = @intCast(segment.bytes.len), .rows = segment.rows, .digest = segment.digest }, .written = written };
        if (stage) |expected| if (!std.meta.eql(expected, next)) return error.QueryStageChanged;
        if (written == next.segment.bytes) {
            var staged: [records.segment_bytes]u8 = undefined;
            _ = try readSegment(turn, next.segment, &staged);
            try turn.write(key('m', stored.result, next.segment.ordinal, 0), try next.segment.encode());
            try turn.write(key('e', stored.result, 0, 0), try p.Value.init(&try candidate.progress.encodeRecord()));
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
        if (stage != null) return error.InvalidQueryStage;
        if (candidate.progress.finished != null) {
            stored.phase = .captured;
            try turn.release(stored.source);
        }
        try turn.write(key('e', stored.result, 0, 0), try p.Value.init(&try candidate.progress.encodeRecord()));
        try turn.write(key('j', stored.result, 0, 0), try stored.encode());
        if (stored.phase == .capturing) try continueCapture(turn, .{ .result = stored.result, .page = candidate.progress.pages });
    }
    try turn.validate();
    return if (stored.phase == .captured) .captured else .progress;
}
/// Close explicitly in a fresh private proposal, before any failed source read.
/// No retained source read is needed; current process/job-resource rights are.
pub fn close(turn: *Turn, identity: u64, phase: enum { cancelled, denied }) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var stored = try job(turn, identity);
    if (stored.phase == .acknowledged or stored.phase == .cancelled or stored.phase == .denied or stored.phase == .failed) return;
    if (stored.phase == .capturing) try turn.release(stored.source);
    stored.phase = if (phase == .cancelled) .cancelled else .denied;
    try turn.write(key('j', identity, 0, 0), try stored.encode());
    try turn.send(stored.destination, .{ .kind = .reply, .correlation = stored.correlation, .payload = try p.Value.init(if (phase == .cancelled) "station.query.cancelled.v1" else "station.query.denied.v1") });
    try turn.validate();
}
pub const Captured = struct { job: Job, progress: stream.Progress };
pub fn captured(turn: *Turn, identity: u64) !Captured {
    const stored = try job(turn, identity);
    if (stored.phase != .captured and stored.phase != .published and stored.phase != .acknowledged) return error.IncompleteResult;
    const state = (try progress(turn, identity)) orelse return error.MissingQueryProgress;
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
        var keys: [p.Growth.page_size]p.Value = undefined;
        const count = @min(keys.len, std.math.divCeil(usize, manifest.bytes - offset, records.fragment_bytes) catch unreachable);
        for (keys[0..count], 0..) |*entry, index| entry.* = key('f', manifest.result, manifest.ordinal, @intCast(offset / records.fragment_bytes + index));
        try turn.prefetch(keys[0..count]);
        for (keys[0..count]) |entry| {
            const fragment = (try turn.read(entry)) orelse return error.MissingResultFragment;
            const end = @min(offset + records.fragment_bytes, manifest.bytes);
            if (fragment.len != end - offset) return error.InvalidResultFragment;
            @memcpy(output[offset..end], fragment.slice());
            offset = end;
        }
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(output[0..manifest.bytes], &digest, .{});
    if (!std.mem.eql(u8, &digest, &manifest.digest)) return error.InvalidResultDigest;
    return output[0..manifest.bytes];
}
