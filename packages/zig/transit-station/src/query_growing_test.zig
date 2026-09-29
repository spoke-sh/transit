const std = @import("std");
const t = std.testing;
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig").Growing;
const Table = @import("Table.zig");
const Frame = @import("Frame.zig");
const q = @import("GrowingQuery.zig");
const r = q.records;
const Map = std.AutoHashMapUnmanaged(p.Value, p.Value);
// Independent in-memory reader/commit fixture. Public service tests qualify
// actual authority, node and provider failures separately.
const Store = struct {
    pid: u64 = 2,
    resource: u64 = 7,
    state: Map = .empty,
    source: Map = .empty,
    version: ?p.Growth.ReadVersion = null,
    revision: u64 = 1,
    input: u64 = 100,
    source_reads: usize = 0,
    unavailable: bool = false,
    fn deinit(self: *Store) void {
        self.state.deinit(t.allocator);
        self.source.deinit(t.allocator);
    }
    fn turn(self: *Store, frame: Frame, peer: u64) !Turn {
        self.input += 1;
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = self.pid, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = try frame.encode(), .origin = .{ .process = .{ .pid = peer, .turn = self.input - 1, .output = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = self.pid, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = self.resource, .revision = self.revision, .deadline_ms = 10_000 }, .{ .context = self, .read = read, .version = metadata, .version_entries = entries });
    }
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        return self.state.get(key);
    }
    fn metadata(raw: *anyopaque, id: p.Growth.ReadVersionId) !p.Growth.ReadVersion {
        const self: *Store = @ptrCast(@alignCast(raw));
        const value = self.version orelse return error.UnknownReadVersion;
        if (!std.meta.eql(id, value.id)) return error.UnknownReadVersion;
        return value;
    }
    fn entries(raw: *anyopaque, _: p.Growth.ReadVersion, key: ?p.Value, after: ?p.Value) !@import("Turn.zig").Page {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.source_reads += 1;
        if (self.unavailable) return error.Unavailable;
        var page: @import("Turn.zig").Page = .{};
        if (key) |point| {
            if (self.source.get(point)) |value| page.entries[0] = .{ .key = point, .value = value, .revision = 1 };
            return page;
        }
        var cursor = after;
        for (0..page.entries.len + 1) |i| {
            var next: ?p.Value = null;
            var iterator = self.source.keyIterator();
            while (iterator.next()) |candidate| {
                if (cursor) |previous| if (std.mem.order(u8, candidate.slice(), previous.slice()) != .gt) continue;
                if (next == null or std.mem.order(u8, candidate.slice(), next.?.slice()) == .lt) next = candidate.*;
            }
            const found = next orelse return page;
            if (i == page.entries.len) {
                page.next = cursor;
                return page;
            }
            page.entries[i] = .{ .key = found, .value = self.source.get(found).?, .revision = 1 };
            cursor = found;
        }
        unreachable;
    }
    fn commit(self: *Store, proposal: Turn) !void {
        try proposal.validate();
        for (proposal.decision.retain, 0..) |slot, i| if (slot != null) {
            try t.expect(self.version == null);
            var iterator = self.state.iterator();
            while (iterator.next()) |entry| try self.source.put(t.allocator, entry.key_ptr.*, entry.value_ptr.*);
            self.version = .{ .id = .{ .pid = proposal.delivery.pid, .input = proposal.delivery.input.position, .index = @intCast(i) }, .resource = proposal.view.resource, .revision = proposal.view.revision, .created_at = proposal.delivery.input.position };
        };
        for (proposal.decision.release) |slot| if (slot) |id| {
            try t.expect(std.meta.eql(id, self.version.?.id));
            self.version.?.released_at = proposal.delivery.input.position;
        };
        for (proposal.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.state.put(t.allocator, mutation.key, value) else _ = self.state.remove(mutation.key);
        };
        self.revision += 1;
    }
    fn seed(self: *Store, rows: usize, data_type: f.model.Type) !Table {
        var setup = try self.turn(.{ .kind = .cast }, 2);
        const table = try Table.create(&setup, 1, .{ .names = .{ try .init("id"), try .init("value") }, .value_type = data_type });
        try q.setPolicy(&setup, 8, 1, 0, true);
        try self.commit(setup);
        for (0..rows) |i| {
            var insert = try self.turn(.{ .kind = .cast }, 2);
            try table.insert(&insert, .{ .key = @intCast(i), .value = if (i % 5 == 0) .null else if (data_type == .utf8) .{ .utf8 = try .init(&@as([220]u8, @splat('x'))) } else .{ .int64 = @intCast(i * 10) } });
            try self.commit(insert);
        }
        return table;
    }
};
fn request(turn: Turn) !q.Continuation {
    return q.Continuation.decode((try Frame.decode(turn.decision.outputs[0].?.value)).payload);
}
fn advance(store: *Store, continuation: q.Continuation, workspace: []u8, cancel: *const f.execution.Cancellation) !struct { turn: Turn, result: q.Advance } {
    var turn = try store.turn(.{ .kind = .cast, .payload = try continuation.encode() }, 2);
    const result = try q.advance(&turn, continuation, workspace, cancel);
    return .{ .turn = turn, .result = result };
}

test "growing capture seals bounded segments across fresh turns and keeps complete evidence without source access" {
    var store: Store = .{};
    defer store.deinit();
    const table = try store.seed(70, .utf8);
    var start = try store.turn(.{ .kind = .call, .correlation = std.math.maxInt(u64) }, 8);
    const job = try q.start(&start, table, .{});
    try store.commit(start);
    var next = try request(start);
    const original = next;
    var workspace: [f.execution.working_bytes]u8 = undefined;
    const cancel = f.execution.Cancellation.init(false);
    var staging_turns: usize = 0;
    var completed: usize = 0;
    while (true) {
        var step = try advance(&store, next, &workspace, &cancel);
        try t.expect(step.turn.decision.read_versions[0] != null);
        const prior_progress = try q.progress(&step.turn, job.result);
        // A fresh handler recreates the exact candidate after an uncommitted loss.
        var retry = try Turn.init(step.turn.delivery, step.turn.view, step.turn.reader);
        try t.expectEqual(step.result, try q.advance(&retry, next, &workspace, &cancel));
        try t.expect(std.meta.eql(step.turn.decision, retry.decision));
        try store.commit(step.turn);
        if (step.result == .captured) {
            completed += 1;
            break;
        }
        next = try request(step.turn);
        if (next.written != 0) {
            staging_turns += 1;
            try t.expectEqual(prior_progress.pages, next.page);
        }
        var inspect = try store.turn(.{ .kind = .cast }, 2);
        try t.expectError(error.IncompleteResult, q.captured(&inspect, job.result));
        const duplicate = try advance(&store, original, &workspace, &cancel);
        try t.expectEqual(q.Advance.duplicate, duplicate.result);
        for (duplicate.turn.decision.mutations) |slot| try t.expect(slot == null);
    }
    try t.expect(staging_turns > 9 and completed == 1);
    try t.expect(store.version.?.released_at != null);
    // Current rows change, and source access is gone. Captured bytes still work.
    store.unavailable = true;
    var inspect = try store.turn(.{ .kind = .cast }, 2);
    const result = try q.captured(&inspect, job.result);
    try t.expectEqual(@as(u64, 70), result.progress.rows);
    try t.expect(result.job.bytes > 672 and result.progress.segments == 9);
    var buffer: [r.segment_bytes]u8 = undefined;
    var chain: [32]u8 = @splat(0);
    var rows: u64 = 0;
    var bytes: u64 = 0;
    for (0..result.progress.segments) |ordinal| {
        const segment = try q.capturedSegment(&inspect, job.result, ordinal, &buffer);
        chain = try segment.manifest.extend(chain);
        rows += segment.manifest.rows;
        bytes += segment.bytes.len;
        // Use the upstream decoder too; independent PyArrow is a service gate.
        var input: std.Io.Reader = .fixed(segment.bytes);
        var decoder = f.arrow.IpcStreamReader(*std.Io.Reader).init(t.allocator, &input);
        defer decoder.deinit();
        _ = try decoder.readSchema();
        var batch = (try decoder.nextRecordBatch()).?;
        defer batch.deinit();
        try t.expectEqual(segment.manifest.rows, batch.numRows());
        try t.expect((try decoder.nextRecordBatch()) == null);
    }
    try t.expectEqual(result.progress.rows, rows);
    try t.expectEqual(result.job.bytes, bytes);
    try t.expectEqualSlices(u8, &chain, &result.job.chain);
    var duplicate_call = try store.turn(.{ .kind = .call, .correlation = job.correlation }, 8);
    try t.expectError(error.CorrelationAlreadyUsed, q.start(&duplicate_call, table, .{}));
    try t.expectError(error.InvalidQueryOrdinal, q.capturedSegment(&inspect, job.result, result.progress.segments, &buffer));
    const fragment = r.key('f', job.result, 0, 0);
    const old = store.state.get(fragment).?;
    _ = store.state.remove(fragment);
    try t.expectError(error.MissingResultFragment, q.capturedSegment(&inspect, job.result, 0, &buffer));
    var bad = old;
    bad.data[0] ^= 1;
    try store.state.put(t.allocator, fragment, bad);
    try t.expectError(error.InvalidResultDigest, q.capturedSegment(&inspect, job.result, 0, &buffer));
}

test "growing capture rejects changed staging and closes policy or source loss without publishing a prefix" {
    var store: Store = .{};
    defer store.deinit();
    const table = try store.seed(10, .utf8);
    var start = try store.turn(.{ .kind = .call, .correlation = 3 }, 8);
    const job = try q.start(&start, table, .{});
    try store.commit(start);
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var cancel = f.execution.Cancellation.init(true);
    const initial = try request(start);
    try t.expectError(error.Cancelled, advance(&store, initial, &workspace, &cancel));
    cancel.store(false, .release);
    const step = try advance(&store, initial, &workspace, &cancel);
    try store.commit(step.turn);
    const next = try request(step.turn);
    const stage_key = r.key('s', job.result, 0, 0);
    const original = store.state.get(stage_key).?;
    var changed = try r.Stage.decode(original);
    changed.segment.digest[0] ^= 1;
    try store.state.put(t.allocator, stage_key, try changed.encode());
    try t.expectError(error.QueryStageChanged, advance(&store, next, &workspace, &cancel));
    try store.state.put(t.allocator, stage_key, original);
    var forged = try store.turn(.{ .kind = .cast, .payload = try next.encode() }, 8);
    try t.expectError(error.UnexpectedResultContinuation, q.advance(&forged, next, &workspace, &cancel));
    var future = next;
    future.page += 1;
    try t.expectError(error.InvalidQueryContinuation, advance(&store, future, &workspace, &cancel));
    store.unavailable = true;
    var failed = try store.turn(.{ .kind = .cast, .payload = try next.encode() }, 2);
    try t.expectError(error.Unavailable, q.advance(&failed, next, &workspace, &cancel));
    try t.expectError(error.Unavailable, q.close(&failed, job.result, .cancelled));
    for (failed.decision.mutations) |slot| try t.expect(slot == null);
    var close = try store.turn(.{ .kind = .cast }, 2);
    const read_count = store.source_reads;
    try q.close(&close, job.result, .cancelled);
    try t.expectEqual(read_count, store.source_reads);
    try store.commit(close);
    var inspect = try store.turn(.{ .kind = .cast }, 2);
    try t.expectEqual(r.Phase.cancelled, (try q.job(&inspect, job.result)).phase);
    try t.expectError(error.IncompleteResult, q.captured(&inspect, job.result));
    try t.expect(store.version.?.released_at != null);
    try t.expect(store.state.get(stage_key) != null); // Closure grants no deletion.

    var revoked: Store = .{};
    defer revoked.deinit();
    const second_table = try revoked.seed(10, .int64);
    start = try revoked.turn(.{ .kind = .call, .correlation = 4 }, 8);
    const second = try q.start(&start, second_table, .{});
    try revoked.commit(start);
    var policy = try revoked.turn(.{ .kind = .cast }, 2);
    try q.setPolicy(&policy, 8, 1, 1, false);
    try revoked.commit(policy);
    const denied = try advance(&revoked, try request(start), &workspace, &cancel);
    try t.expectEqual(q.Advance.closed, denied.result);
    try t.expectEqual(@as(usize, 0), revoked.source_reads);
    try revoked.commit(denied.turn);
    inspect = try revoked.turn(.{ .kind = .cast }, 2);
    try t.expectEqual(r.Phase.denied, (try q.job(&inspect, second.result)).phase);
    try t.expectError(error.IncompleteResult, q.captured(&inspect, second.result));
}

const Message = struct { source: u64, destination: u64, frame: Frame };
fn enqueue(queue: *std.ArrayList(Message), turn: Turn) !void {
    for (turn.decision.outputs) |slot| if (slot) |output| try queue.append(t.allocator, .{ .source = turn.delivery.pid, .destination = output.pid, .frame = try Frame.decode(output.value) });
}

test "growing result delivery preserves bounded progress through fresh handlers and completes exactly once before acknowledgement" {
    var producer: Store = .{};
    defer producer.deinit();
    const table = try producer.seed(41, .utf8);
    var receiver: Store = .{ .pid = 8, .resource = 9 };
    defer receiver.deinit();
    var initial = try receiver.turn(.{ .kind = .cast }, 8);
    const correlation = try initial.call(2, .{}, null);
    try receiver.commit(initial);
    var queue: std.ArrayList(Message) = .empty;
    defer queue.deinit(t.allocator);
    try enqueue(&queue, initial);
    var workspace: [f.execution.working_bytes]u8 = undefined;
    const cancel = f.execution.Cancellation.init(false);
    const context: q.Context = .{ .workspace = &workspace, .cancellation = &cancel };
    var next: usize = 0;
    var identity: u64 = 0;
    var callbacks: usize = 0;
    var duplicate = false;
    var first_fragment: ?Frame = null;
    var completion: ?Frame = null;
    var credit_frames: usize = 0;
    while (next < queue.items.len) : (next += 1) {
        try t.expect(next < 512);
        const message = queue.items[next];
        const target = if (message.destination == 2) &producer else &receiver;
        var turn = try target.turn(message.frame, message.source);
        if (!try q.dispatch(&turn, message.frame, context)) {
            if (message.frame.kind == .call) {
                identity = (try q.start(&turn, table, .{})).result;
            } else {
                try t.expectEqual(Frame.Kind.result_complete, message.frame.kind);
                const result = try q.completed(&turn, correlation);
                try t.expectEqual(@as(u64, 41), result.rows);
                callbacks += 1;
                completion = message.frame;
            }
        }
        if (message.frame.kind == .result_chunk and std.mem.startsWith(u8, message.frame.payload.slice(), "GQF2")) {
            if (first_fragment == null) first_fragment = message.frame;
            var forged = try target.turn(message.frame, 99);
            try t.expectError(error.UnexpectedReplySource, q.dispatch(&forged, message.frame, context));
            try t.expectEqual(.waiting, (try turn.waiting(correlation)).?.phase);
            if (!duplicate) {
                try queue.append(t.allocator, message);
                duplicate = true;
            }
        }
        if (message.frame.kind == .cast and std.mem.startsWith(u8, message.frame.payload.slice(), "GQG2")) {
            credit_frames += 1;
            var forged = try target.turn(message.frame, 99);
            try t.expectError(error.UnexpectedReplySource, q.dispatch(&forged, message.frame, context));
        }
        if (message.frame.kind != .result_complete and message.frame.kind != .result_ack and message.destination == 8) {
            try t.expectError(error.IncompleteResult, q.completed(&turn, correlation));
        }
        try target.commit(turn);
        try enqueue(&queue, turn);
    }
    try t.expectEqual(@as(usize, 1), callbacks);
    // One receiver-issued credit grant per sealed segment (docs/internal/FLOW_CONTROL.md):
    // the sender never runs more than `credit_window` segments ahead of it.
    try t.expectEqual(@as(usize, 6), credit_frames);
    var sender = try producer.turn(.{ .kind = .cast }, 2);
    try t.expectEqual(r.Phase.acknowledged, (try q.job(&sender, identity)).phase);
    var inspect = try receiver.turn(.{ .kind = .cast }, 8);
    const result = try q.completed(&inspect, correlation);
    try t.expect(result.bytes > 672 and result.segments == 6);
    var buffer: [r.segment_bytes]u8 = undefined;
    var chain: [32]u8 = @splat(0);
    var rows: u64 = 0;
    for (0..result.segments) |ordinal| {
        const segment = try q.completedSegment(&inspect, correlation, ordinal, &buffer);
        chain = try segment.manifest.extend(chain);
        rows += segment.manifest.rows;
    }
    try t.expectEqual(result.rows, rows);
    try t.expectEqualSlices(u8, &result.chain, &chain);
    try t.expect(producer.state.count() > 32 and receiver.state.count() > 32);
    var late = try receiver.turn(completion.?, 2);
    try t.expect(try q.dispatch(&late, completion.?, context));
    try t.expectEqual(.replied, (try late.waiting(correlation)).?.phase);
    var fragment = first_fragment.?;
    fragment.payload.data[22] ^= 1;
    late = try receiver.turn(fragment, 2);
    try t.expect(try q.dispatch(&late, fragment, context)); // Closed wait stays closed.
    const key = r.key('d', correlation, 0, 0);
    const retained = receiver.state.get(key).?;
    var corrupt = retained;
    corrupt.data[0] ^= 1;
    try receiver.state.put(t.allocator, key, corrupt);
    try t.expectError(error.InvalidResultDigest, q.completedSegment(&inspect, correlation, 0, &buffer));
    try receiver.state.put(t.allocator, key, retained);
    _ = receiver.state.remove(key);
    try t.expectError(error.IncompleteResultSegment, q.completedSegment(&inspect, correlation, 0, &buffer));
}

test "receiver rejects out-of-order conflicting and premature result evidence without closing its wait" {
    var receiver: Store = .{ .pid = 8, .resource = 9 };
    defer receiver.deinit();
    var initial = try receiver.turn(.{ .kind = .cast }, 8);
    const correlation = try initial.call(2, .{}, null);
    try receiver.commit(initial);
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var cancel = f.execution.Cancellation.init(false);
    const context: q.Context = .{ .workspace = &workspace, .cancellation = &cancel };
    const data: [r.fragment_bytes]u8 = @splat(1);
    var fragment: r.Fragment = .{ .result = 55, .segment = 0, .offset = r.fragment_bytes, .bytes = &data };
    var frame: Frame = .{ .kind = .result_chunk, .correlation = correlation, .payload = try fragment.encode() };
    var turn = try receiver.turn(frame, 2);
    const before = turn.decision;
    try t.expectError(error.UnorderedResultFragment, q.dispatch(&turn, frame, context));
    try t.expect(std.meta.eql(before, turn.decision));
    fragment.offset = 0;
    frame.payload = try fragment.encode();
    turn.delivery.input.value = try frame.encode();
    cancel.store(true, .release);
    try t.expectError(error.Cancelled, q.dispatch(&turn, frame, context));
    cancel.store(false, .release);
    try t.expect(try q.dispatch(&turn, frame, context));
    try receiver.commit(turn);
    turn = try receiver.turn(frame, 2);
    try t.expect(try q.dispatch(&turn, frame, context));
    for (turn.decision.mutations) |slot| try t.expect(slot == null);
    frame.payload.data[22] ^= 1;
    turn.delivery.input.value = try frame.encode();
    try t.expectError(error.ConflictingResultFragment, q.dispatch(&turn, frame, context));
    fragment.result += 1;
    frame.payload = try fragment.encode();
    turn.delivery.input.value = try frame.encode();
    try t.expectError(error.ConflictingResultIdentity, q.dispatch(&turn, frame, context));
    const schema: f.model.Schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 };
    const manifest: q.Manifest = .{ .result = 55, .destination = 8, .correlation = correlation, .table = 1, .policy_revision = 1, .basis = .{ .resource = 7, .revision = 1, .schema = try schema.fingerprint() }, .plan = @splat(1), .segments = 1, .bytes = data.len, .rows = 1, .chain = @splat(0), .schema = @splat(0) };
    frame = .{ .kind = .result_complete, .correlation = correlation, .payload = try manifest.encode() };
    turn.delivery.input.value = try frame.encode();
    try t.expectError(error.IncompleteResult, q.dispatch(&turn, frame, context));
    try t.expectEqual(.waiting, (try turn.waiting(correlation)).?.phase);
    // A matching fragment digest alone cannot turn non-IPC bytes into a result.
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&data, &digest, .{});
    frame = .{ .kind = .result_chunk, .correlation = correlation, .payload = try (r.Segment{ .result = 55, .ordinal = 0, .bytes = data.len, .rows = 1, .digest = digest }).encode() };
    turn.delivery.input.value = try frame.encode();
    try t.expectError(error.InvalidArrowResult, q.dispatch(&turn, frame, context));
    try t.expectEqual(.waiting, (try turn.waiting(correlation)).?.phase);
    for (turn.decision.outputs) |slot| try t.expect(slot == null);
}

fn countSet(slots: anytype) usize {
    var found: usize = 0;
    for (slots) |slot| if (slot != null) {
        found += 1;
    };
    return found;
}

test "receiver-issued credit authenticates its peer, never regresses and is inert once published" {
    var producer: Store = .{};
    defer producer.deinit();
    const job: r.Job = .{ .result = 55, .destination = 8, .correlation = 1, .table = 1, .source = .{ .pid = 2, .input = 55, .index = 0 }, .policy_revision = 1, .phase = .captured, .send_segment = r.credit_window, .send_offset = 0 };
    var setup = try producer.turn(.{ .kind = .cast }, 2);
    try setup.write(r.key('j', job.result, 0, 0), try job.encode());
    try producer.commit(setup);
    var workspace: [f.execution.working_bytes]u8 = undefined;
    const cancel = f.execution.Cancellation.init(false);
    const context: q.Context = .{ .workspace = &workspace, .cancellation = &cancel };
    const first: r.Credit = .{ .result = job.result, .granted = 1 };
    var frame: Frame = .{ .kind = .cast, .payload = try first.encode() };
    // Only the job's authenticated destination may grant credit for it.
    var forged = try producer.turn(frame, 99);
    try t.expectError(error.UnexpectedReplySource, q.dispatch(&forged, frame, context));
    try t.expect(countSet(forged.decision.mutations) == 0 and countSet(forged.decision.outputs) == 0);
    // The authentic peer's grant is durably recorded and resumes publication.
    var turn = try producer.turn(frame, job.destination);
    try t.expect(try q.dispatch(&turn, frame, context));
    try t.expectEqual(@as(u64, 1), (try r.Credit.decode((try turn.read(r.key('g', job.result, 0, 0))).?)).granted);
    try t.expectEqual(@as(usize, 1), countSet(turn.decision.outputs)); // Self-cast continuation to resume.
    try producer.commit(turn);
    // Repeating the same grant is inert: nothing to record or resume.
    turn = try producer.turn(frame, job.destination);
    try t.expect(try q.dispatch(&turn, frame, context));
    try t.expect(countSet(turn.decision.mutations) == 0 and countSet(turn.decision.outputs) == 0);
    // A regressing grant is rejected outright, not silently ignored.
    const regressed: r.Credit = .{ .result = job.result, .granted = 0 };
    frame = .{ .kind = .cast, .payload = try regressed.encode() };
    turn = try producer.turn(frame, job.destination);
    try t.expectError(error.InvalidResultCredit, q.dispatch(&turn, frame, context));
    // Once published, further credit neither errors nor mutates anything.
    var published = job;
    published.phase = .published;
    var advance_phase = try producer.turn(.{ .kind = .cast }, 2);
    try advance_phase.write(r.key('j', job.result, 0, 0), try published.encode());
    try producer.commit(advance_phase);
    const late: r.Credit = .{ .result = job.result, .granted = 2 };
    frame = .{ .kind = .cast, .payload = try late.encode() };
    turn = try producer.turn(frame, job.destination);
    try t.expect(try q.dispatch(&turn, frame, context));
    try t.expect(countSet(turn.decision.mutations) == 0 and countSet(turn.decision.outputs) == 0);
}
