//! Finite Arrow results are copied into associated state before publication.
//! All fragments and acknowledgement are ordinary authenticated mailbox inputs.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig").Legacy;
const Frame = @import("Frame.zig");
const Table = @import("Table.zig");
pub const chunk_bytes = 224;
pub const max_chunks = 3;
pub const max_bytes = chunk_bytes * max_chunks;
pub const Phase = enum(u8) { captured = 1, published = 2, acknowledged = 3, cancelled = 4, denied = 5 };
pub const Manifest = struct {
    result: u64,
    correlation: u64,
    destination: u64,
    table: u32,
    basis: f.model.Basis,
    digest: [32]u8,
    bytes: u16,
    rows: u8,
    policy_revision: u64,
    phase: Phase = .captured,
    pub fn encode(self: Manifest) p.Value {
        var bytes: [133]u8 = @splat(0);
        bytes[0..4].* = "AIR1".*;
        std.mem.writeInt(u64, bytes[4..12], self.result, .little);
        std.mem.writeInt(u64, bytes[12..20], self.correlation, .little);
        std.mem.writeInt(u64, bytes[20..28], self.destination, .little);
        std.mem.writeInt(u32, bytes[28..32], self.table, .little);
        std.mem.writeInt(u64, bytes[32..40], self.basis.resource, .little);
        std.mem.writeInt(u64, bytes[40..48], self.basis.revision, .little);
        bytes[48..80].* = self.basis.schema;
        bytes[80..112].* = self.digest;
        std.mem.writeInt(u16, bytes[112..114], self.bytes, .little);
        bytes[114] = self.rows;
        std.mem.writeInt(u64, bytes[115..123], self.policy_revision, .little);
        bytes[123] = @backingInt(self.phase);
        // Reserved bytes are zero and covered by canonical round-trip checking.
        return p.Value.init(&bytes) catch unreachable;
    }
    pub fn decode(value: p.Value) !Manifest {
        try value.validate();
        if (value.len != 133 or !std.mem.eql(u8, value.data[0..4], "AIR1")) return error.InvalidResultManifest;
        const result: Manifest = .{
            .result = std.mem.readInt(u64, value.data[4..12], .little),
            .correlation = std.mem.readInt(u64, value.data[12..20], .little),
            .destination = std.mem.readInt(u64, value.data[20..28], .little),
            .table = std.mem.readInt(u32, value.data[28..32], .little),
            .basis = .{ .resource = std.mem.readInt(u64, value.data[32..40], .little), .revision = std.mem.readInt(u64, value.data[40..48], .little), .schema = value.data[48..80].* },
            .digest = value.data[80..112].*,
            .bytes = std.mem.readInt(u16, value.data[112..114], .little),
            .rows = value.data[114],
            .policy_revision = std.mem.readInt(u64, value.data[115..123], .little),
            .phase = std.enums.fromInt(Phase, value.data[123]) orelse return error.InvalidResultManifest,
        };
        if (result.result == 0 or result.correlation == 0 or result.destination == 0 or result.basis.resource == 0 or result.table == 0 or result.bytes == 0 or result.bytes > max_bytes or result.rows > f.model.max_rows or !result.encode().eql(value)) return error.InvalidResultManifest;
        return result;
    }
};
pub const Policy = struct { table: u32, revision: u64, allow: bool };
pub fn key(tag: u8, identity: u64, ordinal: u8) p.Value {
    var bytes: [11]u8 = undefined;
    bytes[0] = 0;
    bytes[1] = tag;
    std.mem.writeInt(u64, bytes[2..10], identity, .little);
    bytes[10] = ordinal;
    return p.Value.init(&bytes) catch unreachable;
}
pub fn policy(turn: anytype, peer: u64) !?Policy {
    const value = (try turn.read(key('a', peer, 0))) orelse return null;
    if (value.len != 14 or value.data[0] != 1 or value.data[13] > 1) return error.InvalidQueryPolicy;
    return .{ .table = std.mem.readInt(u32, value.data[1..5], .little), .revision = std.mem.readInt(u64, value.data[5..13], .little), .allow = value.data[13] == 1 };
}
/// This is a trusted handler operation. A remote policy API must separately
/// authorize its administrator from authenticated origin before invoking it.
pub fn setPolicy(turn: anytype, peer: u64, table: u32, expected_revision: u64, allow: bool) !void {
    if (peer == 0 or peer > p.max_counter or table == 0) return error.InvalidQueryPolicy;
    const old = try policy(turn, peer);
    if ((if (old) |value| value.revision else 0) != expected_revision) return error.QueryPolicyConflict;
    var bytes: [14]u8 = undefined;
    bytes[0] = 1;
    std.mem.writeInt(u32, bytes[1..5], table, .little);
    std.mem.writeInt(u64, bytes[5..13], try std.math.add(u64, expected_revision, 1), .little);
    bytes[13] = @intFromBool(allow);
    try turn.write(key('a', peer, 0), try p.Value.init(&bytes));
}
fn allowed(turn: *const Turn, peer: u64, table: u32) !Policy {
    const grant = (try policy(turn, peer)) orelse return error.QueryDenied;
    if (!grant.allow or grant.table != table) return error.QueryDenied;
    return grant;
}
pub fn capture(turn: *Turn, table: Table, plan: f.Plan, workspace: []u8, cancellation: *const f.execution.Cancellation) !Manifest {
    const before = turn.decision;
    errdefer turn.decision = before;
    const request = try Frame.decode(turn.delivery.input.value);
    if (request.kind != .call) return error.ExpectedCall;
    const peer = try Frame.source(turn.delivery.input);
    const grant = try allowed(turn, peer, table.id);
    const identity = turn.delivery.input.position;
    if (turn.get(key('q', identity, 0)) != null) return error.ResultAlreadyExists;
    for (turn.entries) |slot| if (slot) |entry| {
        if (entry.key.len != 11 or entry.key.data[0] != 0 or entry.key.data[1] != 'q' or entry.key.data[10] != 0) continue;
        const previous = try Manifest.decode(entry.value);
        if (previous.correlation == request.correlation and previous.destination == peer) return error.CorrelationAlreadyUsed;
    };
    var snapshot = try table.snapshot(turn);
    var output: [max_bytes]u8 = undefined;
    const result = try f.execution.run(try plan.bind(snapshot.source()), snapshot.source(), workspace, &output, cancellation);
    const manifest: Manifest = .{ .result = identity, .correlation = request.correlation, .destination = peer, .table = table.id, .basis = result.basis, .digest = result.digest, .bytes = @intCast(result.bytes.len), .rows = result.rows, .policy_revision = grant.revision };
    try turn.write(key('q', identity, 0), manifest.encode());
    var offset: usize = 0;
    var ordinal: u8 = 0;
    while (offset < result.bytes.len) : (ordinal += 1) {
        const end = @min(offset + chunk_bytes, result.bytes.len);
        try turn.write(key('q', identity, ordinal + 1), try p.Value.init(result.bytes[offset..end]));
        offset = end;
    }
    var continuation: [12]u8 = undefined;
    continuation[0..4].* = "SQC1".*;
    std.mem.writeInt(u64, continuation[4..12], identity, .little);
    try turn.cast(turn.delivery.pid, try p.Value.init(&continuation));
    try turn.validate();
    return manifest;
}
/// Resume using only captured bytes, never a new view of source rows.
fn publish(turn: *Turn, identity: u64) !void {
    if (try Frame.source(turn.delivery.input) != turn.delivery.pid) return error.UnexpectedResultContinuation;
    var manifest = try Manifest.decode(turn.get(key('q', identity, 0)) orelse return error.MissingResult);
    if (manifest.phase != .captured) return; // Duplicate continuation is inert.
    const grant = policy(turn, manifest.destination) catch null;
    if (grant == null or !grant.?.allow or grant.?.table != manifest.table or grant.?.revision != manifest.policy_revision) {
        manifest.phase = .denied;
        try turn.write(key('q', identity, 0), manifest.encode());
        try turn.send(manifest.destination, .{ .kind = .reply, .correlation = manifest.correlation, .payload = try p.Value.init("station.query.denied.v1") });
        return;
    }
    var captured: [max_bytes]u8 = undefined;
    var offset: usize = 0;
    var ordinal: u8 = 0;
    while (offset < manifest.bytes) : (ordinal += 1) {
        const bytes = turn.get(key('q', identity, ordinal + 1)) orelse return error.MissingResultFragment;
        const len = @min(chunk_bytes, manifest.bytes - offset);
        if (bytes.len != len) return error.InvalidResultFragment;
        @memcpy(captured[offset..][0..len], bytes.slice());
        var payload: [13 + chunk_bytes]u8 = undefined;
        payload[0..4].* = "AIP1".*;
        std.mem.writeInt(u64, payload[4..12], identity, .little);
        payload[12] = ordinal;
        @memcpy(payload[13..][0..len], bytes.slice());
        try turn.send(manifest.destination, .{ .kind = .result_chunk, .correlation = manifest.correlation, .payload = try p.Value.init(payload[0 .. 13 + len]) });
        offset += len;
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(captured[0..manifest.bytes], &digest, .{});
    if (!std.mem.eql(u8, &digest, &manifest.digest)) return error.InvalidResultDigest;
    manifest.phase = .published;
    try turn.send(manifest.destination, .{ .kind = .result_complete, .correlation = manifest.correlation, .payload = manifest.encode() });
    try turn.write(key('q', identity, 0), manifest.encode());
}
pub const Completed = struct {
    manifest: Manifest,
    data: [max_bytes]u8 = undefined,
    pub fn bytes(self: *const Completed) []const u8 {
        return self.data[0..self.manifest.bytes];
    }
};
pub fn completed(turn: *const Turn, correlation: u64) !Completed {
    const manifest = try Manifest.decode(turn.get(key('i', correlation, 3)) orelse return error.IncompleteResult);
    return collect(turn, manifest);
}
fn collect(turn: *const Turn, manifest: Manifest) !Completed {
    var result: Completed = .{ .manifest = manifest };
    var offset: usize = 0;
    var ordinal: u8 = 0;
    while (offset < manifest.bytes) : (ordinal += 1) {
        const fragment = turn.get(key('i', manifest.correlation, ordinal)) orelse return error.IncompleteResult;
        try validateFragment(fragment);
        const len = @min(chunk_bytes, manifest.bytes - offset);
        if (fragment.len != 13 + len or fragment.data[12] != ordinal or std.mem.readInt(u64, fragment.data[4..12], .little) != manifest.result) return error.InvalidResultFragment;
        @memcpy(result.data[offset..][0..len], fragment.slice()[13..]);
        offset += len;
    }
    // Extra unexpected fragments cannot turn a truncated announced result into success.
    while (ordinal < max_chunks) : (ordinal += 1) if (turn.get(key('i', manifest.correlation, ordinal)) != null) return error.InvalidResultFragment;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(result.bytes(), &digest, .{});
    if (!std.mem.eql(u8, &digest, &manifest.digest)) return error.InvalidResultDigest;
    return result;
}
fn validateFragment(value: p.Value) !void {
    try value.validate();
    if (value.len <= 13 or value.len > 13 + chunk_bytes or !std.mem.eql(u8, value.data[0..4], "AIP1") or value.data[12] >= max_chunks or std.mem.readInt(u64, value.data[4..12], .little) == 0) return error.InvalidResultFragment;
}
/// Parse only after bounded reassembly. A fixed arena limits decoded allocation,
/// and the profile requires exactly one batch followed by an explicit end marker.
pub fn validateArrow(bytes: []const u8, expected_rows: u8) !void {
    if (bytes.len > max_bytes or bytes.len < 8 or !std.mem.eql(u8, bytes[bytes.len - 8 ..], &.{ 255, 255, 255, 255, 0, 0, 0, 0 })) return error.InvalidArrowResult;
    var memory: [f.execution.working_bytes]u8 = undefined;
    var arena = std.heap.FixedBufferAllocator.init(&memory);
    var source = std.Io.Reader.fixed(bytes);
    var reader = f.arrow.IpcStreamReader(*std.Io.Reader).init(arena.allocator(), &source);
    defer reader.deinit();
    const schema = try reader.readSchema();
    if (schema.fields.len == 0 or schema.fields.len > 2) return error.InvalidArrowResult;
    for (schema.fields) |field| {
        _ = try f.model.Name.init(field.name);
        switch (field.data_type.*) {
            .int64, .bool, .string, .binary => {},
            else => return error.InvalidArrowResult,
        }
    }
    var batch = (try reader.nextRecordBatch()) orelse return error.InvalidArrowResult;
    defer batch.deinit();
    if (batch.numRows() != expected_rows or expected_rows > f.model.max_rows) return error.InvalidArrowResult;
    if (try reader.nextRecordBatch()) |extra| {
        var unexpected = extra;
        unexpected.deinit();
        return error.InvalidArrowResult;
    }
    if (source.bufferedLen() != 0) return error.InvalidArrowResult;
}
/// True means an internal message was completely handled. A verified completion
/// returns false so application code can consume the captured IPC in this turn.
pub fn dispatch(turn: *Turn, frame: Frame) !bool {
    if (frame.kind == .cancel) {
        const peer = try Frame.source(turn.delivery.input);
        for (turn.entries) |slot| if (slot) |entry| {
            if (entry.key.len != 11 or entry.key.data[0] != 0 or entry.key.data[1] != 'q' or entry.key.data[10] != 0) continue;
            var manifest = try Manifest.decode(entry.value);
            if (manifest.correlation != frame.correlation or manifest.destination != peer) continue;
            if (manifest.phase == .captured or manifest.phase == .published) {
                manifest.phase = .cancelled;
                try turn.write(entry.key, manifest.encode());
            }
        };
        // Cancellation is advisory at the peer; no query or completed ordinary
        // call is undone, and no new application callback is implied.
        try turn.write(try p.Value.init("\x00disposition"), try p.Value.init("station.cancellation.v1"));
        return true;
    }
    if (frame.kind == .cast and frame.payload.len == 12 and std.mem.eql(u8, frame.payload.data[0..4], "SQC1")) {
        try publish(turn, std.mem.readInt(u64, frame.payload.data[4..12], .little));
        return true;
    }
    if (frame.kind == .result_ack) {
        const received = try Manifest.decode(frame.payload);
        var stored = try Manifest.decode(turn.get(key('q', received.result, 0)) orelse return error.MissingResult);
        if (try Frame.source(turn.delivery.input) != stored.destination or frame.correlation != stored.correlation) return error.UnexpectedReplySource;
        if (stored.phase == .acknowledged or stored.phase == .cancelled or stored.phase == .denied) return true;
        if (!stored.encode().eql(received.encode()) or stored.phase != .published) return error.InvalidResultAcknowledgement;
        stored.phase = .acknowledged;
        try turn.write(key('q', stored.result, 0), stored.encode());
        return true;
    }
    if (frame.kind != .result_chunk and frame.kind != .result_complete) return false;
    var wait = (try turn.waiting(frame.correlation)) orelse return error.UnknownCorrelation;
    if (try Frame.source(turn.delivery.input) != wait.target) return error.UnexpectedReplySource;
    if (wait.phase != .waiting) {
        try turn.write(try p.Value.init("\x00disposition"), try p.Value.init("station.closed-result.v1"));
        return true;
    }
    if (frame.kind == .result_chunk) {
        try validateFragment(frame.payload);
        const fragment_key = key('i', frame.correlation, frame.payload.data[12]);
        if (turn.get(fragment_key)) |old| {
            if (!old.eql(frame.payload)) return error.ConflictingResultFragment;
        } else try turn.write(fragment_key, frame.payload);
        return true;
    }
    const manifest = try Manifest.decode(frame.payload);
    if (manifest.correlation != frame.correlation or manifest.destination != turn.delivery.pid or manifest.phase != .published) return error.InvalidResultManifest;
    const collected = try collect(turn, manifest);
    try validateArrow(collected.bytes(), manifest.rows);
    try turn.write(key('i', frame.correlation, 3), manifest.encode());
    wait.phase = .replied;
    wait.resolution_input = turn.delivery.input.position;
    try turn.write(Turn.waitKey(frame.correlation), wait.encode());
    try turn.send(wait.target, .{ .kind = .result_ack, .correlation = frame.correlation, .payload = manifest.encode() });
    return false;
}

test "fragments require authenticated peer, stable bytes and complete hash coverage" {
    var turn = try Turn.fixture(.{});
    turn.entries[0] = .{ .key = Turn.waitKey(3), .value = (Turn.Wait{ .target = 8 }).encode(), .revision = 0 };
    var fragment: [16]u8 = undefined;
    fragment[0..4].* = "AIP1".*;
    std.mem.writeInt(u64, fragment[4..12], 42, .little);
    fragment[12] = 0;
    fragment[13..16].* = "abc".*;
    const frame: Frame = .{ .kind = .result_chunk, .correlation = 3, .payload = try p.Value.init(&fragment) };
    turn.delivery.input.origin.source = .{ .process = .{ .pid = 9, .turn = 4, .output = 0 } };
    try std.testing.expectError(error.UnexpectedReplySource, dispatch(&turn, frame));
    turn.delivery.input.origin.source.process.pid = 8;
    try std.testing.expect(try dispatch(&turn, frame));
    try std.testing.expect(try dispatch(&turn, frame)); // identical duplicate
    var conflict = frame;
    conflict.payload.data[13] = 'z';
    try std.testing.expectError(error.ConflictingResultFragment, dispatch(&turn, conflict));
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("abc", &digest, .{});
    var manifest: Manifest = .{ .result = 42, .correlation = 3, .destination = 2, .table = 1, .basis = .{ .resource = 7, .revision = 9, .schema = @splat(1) }, .digest = digest, .bytes = 3, .rows = 0, .policy_revision = 1, .phase = .published };
    var complete: Frame = .{ .kind = .result_complete, .correlation = 3, .payload = manifest.encode() };
    manifest.bytes = 4;
    complete.payload = manifest.encode();
    try std.testing.expectError(error.InvalidResultFragment, dispatch(&turn, complete));
    manifest.bytes = 3;
    complete.payload = manifest.encode();
    try std.testing.expectError(error.InvalidArrowResult, dispatch(&turn, complete));
    const result = try collect(&turn, manifest);
    try std.testing.expectEqualStrings("abc", result.bytes());
    try turn.write(Turn.waitKey(3), (Turn.Wait{ .target = 8, .phase = .cancelled, .resolution_input = 4 }).encode());
    try std.testing.expect(try dispatch(&turn, conflict)); // closed wait: no reopen
    try turn.validate();
}

fn acceptFixture(turn: *Turn) !void {
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        const destination = for (&turn.entries) |*entry| {
            if (entry.*) |value| if (value.key.eql(mutation.key)) break entry;
        } else for (&turn.entries) |*entry| {
            if (entry.* == null) break entry;
        } else return error.StateCapacityExceeded;
        destination.* = if (mutation.value) |value| .{ .key = mutation.key, .value = value, .revision = 1 } else null;
    };
    turn.decision = .{};
}

test "maximum captured IPC fits four mutations and outputs; a delayed consumer cannot complete a prefix" {
    const t = std.testing;
    const bytes: [f.model.max_cell_bytes]u8 = @splat('x');
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var cancellation = f.execution.Cancellation.init(false);
    var largest: ?Turn = null;
    var maximum: usize = 0;
    var rejected: usize = 0;
    // Sweep real IPC sizes around the admitted boundary, including padding.
    for (0..bytes.len + 1) |length| {
        var turn = try Turn.fixture(try (Frame{ .kind = .call, .correlation = 3 }).encode());
        turn.delivery.input.origin.source = .{ .process = .{ .pid = 8, .turn = 1, .output = 0 } };
        const table = try Table.create(&turn, 1, .{ .names = .{ try f.model.Name.init("id"), try f.model.Name.init("value") }, .value_type = .utf8 });
        try table.insert(&turn, .{ .key = 1, .value = .{ .utf8 = try f.model.Bytes.init(&bytes) } });
        try table.insert(&turn, .{ .key = 2, .value = .{ .utf8 = try f.model.Bytes.init(bytes[0..length]) } });
        try setPolicy(&turn, 8, 1, 0, true);
        try acceptFixture(&turn);
        const before = turn.decision;
        const manifest = capture(&turn, table, .{}, &workspace, &cancellation) catch |err| {
            try t.expectEqual(error.WriteFailed, err);
            try t.expect(std.meta.eql(before, turn.decision));
            rejected += 1;
            continue;
        };
        if (manifest.bytes > maximum) {
            maximum = manifest.bytes;
            largest = turn;
        }
    }
    try t.expectEqual(max_bytes, maximum);
    try t.expect(rejected > 0);
    var producer = largest.?;
    for (producer.decision.mutations) |slot| try t.expect(slot != null);
    const continuation = producer.decision.outputs[0].?.value;
    try acceptFixture(&producer);
    producer.delivery.input.value = continuation;
    producer.delivery.input.origin.source.process.pid = producer.delivery.pid;
    try t.expect(try dispatch(&producer, try Frame.decode(continuation)));
    try producer.validate();
    for (producer.decision.outputs) |slot| try t.expect(slot != null);
    var receiver = try Turn.fixture(.{});
    receiver.delivery.pid = 8;
    receiver.delivery.input.origin.source = .{ .process = .{ .pid = 2, .turn = 9, .output = 0 } };
    receiver.entries[0] = .{ .key = Turn.waitKey(3), .value = (Turn.Wait{ .target = 2 }).encode(), .revision = 1 };
    const complete = try Frame.decode(producer.decision.outputs[3].?.value);
    try t.expectError(error.IncompleteResult, dispatch(&receiver, complete));
    for (producer.decision.outputs[0..3]) |slot| {
        try t.expect(try dispatch(&receiver, try Frame.decode(slot.?.value)));
        try acceptFixture(&receiver); // no live task/buffer crosses a turn
        try t.expect((try receiver.waiting(3)).?.phase == .waiting);
    }
    try t.expect(!try dispatch(&receiver, complete));
    try receiver.validate();
    try t.expect((try receiver.waiting(3)).?.phase == .replied);
    var result = try completed(&receiver, 3);
    try t.expectEqual(max_bytes, result.bytes().len);
    try validateArrow(result.bytes(), 2);

    // Cancellation before capture has no queued work and publishes nothing.
    var cancelled = largest.?;
    cancelled.decision = .{};
    cancellation.store(true, .release);
    try t.expectError(error.Cancelled, capture(&cancelled, try Table.open(&cancelled, 1), .{}, &workspace, &cancellation));
    try t.expect(std.meta.eql(cancelled.decision, @as(@TypeOf(cancelled.decision), .{})));
}
