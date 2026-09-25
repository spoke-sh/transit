//! Incremental result publication and receive progress are ordinary Station
//! state/input/output decisions. Acknowledgement never removes retained data.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig").Growing;
const Frame = @import("Frame.zig");
const q = @import("GrowingQuery.zig");
const r = q.records;
pub const Manifest = r.Manifest;
pub const Context = struct { workspace: []u8, cancellation: *const f.execution.Cancellation };

pub fn begin(turn: *Turn, identity: u64) !void {
    const result = try q.captured(turn, identity);
    if (result.job.phase != .captured) return;
    try continuation(turn, .{ .result = identity, .segment = result.job.send_segment, .offset = result.job.send_offset });
}
fn continuation(turn: *Turn, request: r.Publication) !void {
    try turn.cast(turn.delivery.pid, try request.encode());
}
fn publishing(turn: *Turn, request: r.Publication, context: Context) !void {
    if (try Frame.source(turn.delivery.input) != turn.delivery.pid) return error.UnexpectedResultContinuation;
    var job = try q.job(turn, request.result);
    if (job.phase != .captured) return;
    if (request.segment < job.send_segment or (request.segment == job.send_segment and request.offset < job.send_offset)) return;
    if (request.segment != job.send_segment or request.offset != job.send_offset) return error.InvalidQueryContinuation;
    if (!try q.permitted(turn, job)) return q.close(turn, job.result, .denied);
    if (context.cancellation.load(.acquire)) return error.Cancelled;
    const state = try q.captured(turn, job.result);
    const transfer_key = r.key('u', job.result, 0, 0);
    var transfer: r.Transfer = if (try turn.read(transfer_key)) |value| try r.Transfer.decode(value) else .{ .result = job.result, .source = turn.delivery.pid };
    if (transfer.source != turn.delivery.pid or transfer.result != job.result or transfer.segments != job.send_segment or transfer.pending != 0) return error.InvalidResultTransfer;
    var output: [r.segment_bytes]u8 = undefined;
    const captured = try q.capturedSegment(turn, job.result, job.send_segment, &output);
    const schema = try f.Inspect.segment(captured.bytes, captured.manifest.rows, context.workspace);
    if (job.send_offset > captured.bytes.len) return error.InvalidResultTransfer;
    if (job.send_offset == captured.bytes.len) {
        transfer.pending = job.send_offset;
        try transfer.seal(captured.manifest, schema);
        try turn.send(job.destination, .{ .kind = .result_chunk, .correlation = job.correlation, .payload = try captured.manifest.encode() });
        job.send_segment = transfer.segments;
        job.send_offset = 0;
        try turn.write(transfer_key, try transfer.encode());
        if (job.send_segment == state.progress.segments) {
            const manifest: Manifest = .{ .result = job.result, .destination = job.destination, .correlation = job.correlation, .table = job.table, .policy_revision = job.policy_revision, .basis = state.progress.basis, .plan = state.progress.plan, .segments = state.progress.segments, .bytes = job.bytes, .rows = state.progress.rows, .chain = job.chain, .schema = transfer.schema };
            try manifest.check(transfer);
            try turn.write(r.key('z', job.result, 0, 0), try manifest.encode());
            try turn.send(job.destination, .{ .kind = .result_complete, .correlation = job.correlation, .payload = try manifest.encode() });
            job.phase = .published;
        } else {
            try continuation(turn, .{ .result = job.result, .segment = job.send_segment });
        }
    } else {
        for (0..3) |_| {
            if (job.send_offset == captured.bytes.len) break;
            const end: u16 = @intCast(@min(@as(usize, job.send_offset) + r.fragment_bytes, captured.bytes.len));
            const fragment: r.Fragment = .{ .result = job.result, .segment = job.send_segment, .offset = job.send_offset, .bytes = captured.bytes[job.send_offset..end] };
            try turn.send(job.destination, .{ .kind = .result_chunk, .correlation = job.correlation, .payload = try fragment.encode() });
            job.send_offset = end;
        }
        try continuation(turn, .{ .result = job.result, .segment = job.send_segment, .offset = job.send_offset });
    }
    if (context.cancellation.load(.acquire)) return error.Cancelled;
    try turn.write(r.key('j', job.result, 0, 0), try job.encode());
}
fn receiveTransfer(turn: *Turn, correlation: u64, result: u64, peer: u64) !r.Transfer {
    const transfer: r.Transfer = if (try turn.read(r.key('r', correlation, 0, 0))) |value| try r.Transfer.decode(value) else .{ .result = result, .source = peer };
    if (transfer.source != peer or transfer.result != result) return error.ConflictingResultIdentity;
    return transfer;
}
fn bytes(turn: *Turn, correlation: u64, manifest: r.Segment, output: []u8) ![]const u8 {
    if (output.len < manifest.bytes) return error.ResultBufferTooSmall;
    var offset: usize = 0;
    while (offset < manifest.bytes) {
        const value = (try turn.read(r.key('d', correlation, manifest.ordinal, @intCast(offset / r.fragment_bytes)))) orelse return error.IncompleteResultSegment;
        const end = @min(offset + r.fragment_bytes, manifest.bytes);
        if (value.len != end - offset) return error.InvalidResultFragment;
        @memcpy(output[offset..end], value.slice());
        offset = end;
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(output[0..manifest.bytes], &digest, .{});
    if (!std.mem.eql(u8, &digest, &manifest.digest)) return error.InvalidResultDigest;
    return output[0..manifest.bytes];
}
fn receiving(turn: *Turn, frame: Frame, context: Context) !bool {
    var wait = (try turn.waiting(frame.correlation)) orelse return error.UnknownCorrelation;
    const peer = try Frame.source(turn.delivery.input);
    if (peer != wait.target) return error.UnexpectedReplySource;
    if (wait.phase != .waiting) {
        try turn.write(try p.Value.init("\x00disposition"), try p.Value.init("station.closed-result.v2"));
        return true;
    }
    if (context.cancellation.load(.acquire)) return error.Cancelled;
    if (frame.kind == .result_chunk) {
        if (std.mem.startsWith(u8, frame.payload.slice(), "GQF2")) {
            const fragment = try r.Fragment.decode(&frame.payload);
            var transfer = try receiveTransfer(turn, frame.correlation, fragment.result, peer);
            const key = r.key('d', frame.correlation, fragment.segment, fragment.offset / r.fragment_bytes);
            const value = try p.Value.init(fragment.bytes);
            if (fragment.segment < transfer.segments or (fragment.segment == transfer.segments and fragment.offset < transfer.pending)) {
                if (!(try turn.read(key) orelse return error.IncompleteResultSegment).eql(value)) return error.ConflictingResultFragment;
                return true;
            }
            if (fragment.segment != transfer.segments or fragment.offset != transfer.pending or transfer.pending % r.fragment_bytes != 0) return error.UnorderedResultFragment;
            if (try turn.read(key)) |old| {
                if (!old.eql(value)) return error.ConflictingResultFragment;
            } else try turn.write(key, value);
            transfer.pending += @intCast(fragment.bytes.len); // Decoder bounded offset+length.
            try turn.write(r.key('r', frame.correlation, 0, 0), try transfer.encode());
            return true;
        }
        const manifest = try r.Segment.decode(frame.payload);
        var transfer = try receiveTransfer(turn, frame.correlation, manifest.result, peer);
        const key = r.key('v', frame.correlation, manifest.ordinal, 0);
        if (manifest.ordinal < transfer.segments) {
            if (!(try turn.read(key) orelse return error.IncompleteResultSegment).eql(frame.payload)) return error.ConflictingResultSegment;
            return true;
        }
        if (manifest.ordinal != transfer.segments or transfer.pending != manifest.bytes) return error.IncompleteResultSegment;
        var output: [r.segment_bytes]u8 = undefined;
        const encoded = try bytes(turn, frame.correlation, manifest, &output);
        const schema = try f.Inspect.segment(encoded, manifest.rows, context.workspace);
        try transfer.seal(manifest, schema);
        if (context.cancellation.load(.acquire)) return error.Cancelled;
        try turn.write(key, frame.payload);
        try turn.write(r.key('r', frame.correlation, 0, 0), try transfer.encode());
        return true;
    }
    const manifest = try Manifest.decode(frame.payload);
    if (manifest.correlation != frame.correlation or manifest.destination != turn.delivery.pid) return error.InvalidResultManifest;
    const transfer = try receiveTransfer(turn, frame.correlation, manifest.result, peer);
    try manifest.check(transfer);
    try turn.write(r.key('c', frame.correlation, 0, 0), frame.payload);
    wait.phase = .replied;
    wait.resolution_input = turn.delivery.input.position;
    try turn.write(Turn.waitKey(frame.correlation), wait.encode());
    try turn.send(peer, .{ .kind = .result_ack, .correlation = frame.correlation, .payload = frame.payload });
    return false; // Only a verified first completion invokes application code.
}
fn acknowledge(turn: *Turn, frame: Frame) !void {
    const manifest = try Manifest.decode(frame.payload);
    var job = try q.job(turn, manifest.result);
    if (try Frame.source(turn.delivery.input) != job.destination or frame.correlation != job.correlation) return error.UnexpectedReplySource;
    if (job.phase == .cancelled or job.phase == .denied) return;
    if (job.phase != .published and job.phase != .acknowledged) return error.InvalidResultAcknowledgement;
    const expected = (try turn.read(r.key('z', job.result, 0, 0))) orelse return error.IncompleteResult;
    if (!expected.eql(frame.payload)) return error.InvalidResultAcknowledgement;
    if (job.phase == .acknowledged) return;
    job.phase = .acknowledged;
    try turn.write(r.key('j', job.result, 0, 0), try job.encode());
}
/// A false result means the application should handle this frame. On any error
/// discard the private candidate; sticky read errors remain sticky.
pub fn dispatch(turn: *Turn, frame: Frame, context: Context) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (!turn.delivery.input.value.eql(try frame.encode())) return error.InvalidFrame;
    const handled = switch (frame.kind) {
        .cast => blk: {
            if (std.mem.startsWith(u8, frame.payload.slice(), "GQC2")) {
                const request = try q.Continuation.decode(frame.payload);
                if (try q.advance(turn, request, context.workspace, context.cancellation) == .captured) try begin(turn, request.result);
                break :blk true;
            }
            if (std.mem.startsWith(u8, frame.payload.slice(), "GQP2")) {
                try publishing(turn, try r.Publication.decode(frame.payload), context);
                break :blk true;
            }
            break :blk false;
        },
        .result_chunk, .result_complete => try receiving(turn, frame, context),
        .result_ack => blk: {
            try acknowledge(turn, frame);
            break :blk true;
        },
        .cancel => blk: {
            const peer = try Frame.source(turn.delivery.input);
            if (try turn.read(r.key('i', peer, frame.correlation, 0))) |index| {
                if (index.len != 8) return error.InvalidQueryJob;
                const identity = std.mem.readInt(u64, index.data[0..8], .little);
                const job = try q.job(turn, identity);
                if (job.destination != peer or job.correlation != frame.correlation) return error.InvalidQueryJob;
                try q.close(turn, identity, .cancelled);
            } else try turn.write(try p.Value.init("\x00disposition"), try p.Value.init("station.cancellation.v2"));
            break :blk true;
        },
        else => false,
    };
    try turn.validate();
    return handled;
}
pub fn completed(turn: *Turn, correlation: u64) !Manifest {
    const wait = (try turn.waiting(correlation)) orelse return error.UnknownCorrelation;
    if (wait.phase != .replied) return error.IncompleteResult;
    const manifest = try Manifest.decode((try turn.read(r.key('c', correlation, 0, 0))) orelse return error.IncompleteResult);
    if (manifest.correlation != correlation or manifest.destination != turn.delivery.pid) return error.InvalidResultManifest;
    try manifest.check(try receiveTransfer(turn, correlation, manifest.result, wait.target));
    return manifest;
}
pub fn completedSegment(turn: *Turn, correlation: u64, ordinal: u64, output: []u8) !q.CapturedSegment {
    const result = try completed(turn, correlation);
    if (ordinal >= result.segments) return error.InvalidQueryOrdinal;
    const manifest = try r.Segment.decode((try turn.read(r.key('v', correlation, ordinal, 0))) orelse return error.IncompleteResultSegment);
    if (manifest.result != result.result or manifest.ordinal != ordinal) return error.InvalidResultSegment;
    return .{ .manifest = manifest, .bytes = try bytes(turn, correlation, manifest, output) };
}
