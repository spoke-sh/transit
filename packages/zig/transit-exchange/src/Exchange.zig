const std = @import("std");
const root = @import("root.zig");
const p = root.p;
const Pub = root.Publication;
const Turn = root.station.GrowingTurn;
const Self = @This();
resource: u64,
id: u64,
pub fn key(id: u64, tag: u8, ordinal: u32) p.Value {
    var bytes: [15]u8 = undefined;
    bytes[0..2].* = "\x00E".*;
    std.mem.writeInt(u64, bytes[2..10], id, .big);
    bytes[10] = tag;
    std.mem.writeInt(u32, bytes[11..15], ordinal, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn publication(self: Self) Pub {
    return .{ .resource = self.resource, .namespace = self.id };
}
pub fn create(turn: *Turn, id: u64, origin: root.Origin, limits: root.Limits, reconcile_before_ms: u64) !Self {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (id == 0 or origin.parent == id) return error.InvalidExchangeIdentity;
    const self: Self = .{ .resource = turn.view.resource, .id = id };
    const initial: root.Descriptor = .{ .protocol = origin.protocol, .caller = origin.caller, .input = origin.input, .parent = origin.parent, .owner = turn.delivery.pid, .reconcile_before_ms = reconcile_before_ms, .segment_bytes = limits.segment_bytes, .capture_bytes = limits.capture_bytes, .max_segments = limits.segments };
    try initial.validate();
    if (try turn.read(key(id, 'd', 0))) |value| {
        const old = try root.Descriptor.decode(value);
        if (old.phase == .retired) return error.ExchangeUnavailable;
        if (old.protocol != initial.protocol or old.caller != initial.caller or old.input != initial.input or old.parent != initial.parent or old.owner != initial.owner or old.reconcile_before_ms != reconcile_before_ms or old.segment_bytes != limits.segment_bytes or old.capture_bytes != limits.capture_bytes or old.max_segments != limits.segments) return error.ExchangeIdentityConflict;
        return self;
    }
    // A namespace belongs exclusively to one exchange; never adopt unrelated bodies.
    if (try turn.read(Pub.key(id, 'b', 0, 0)) != null) return error.ExchangeIdentityConflict;
    _ = try Pub.create(turn, id, .{ .record_bytes = limits.segment_bytes, .staging_bytes = limits.segment_bytes, .staging_records = 1 });
    try turn.write(key(id, 'd', 0), try initial.encode());
    return self;
}
pub fn inspect(self: Self, source: anytype) !root.Descriptor {
    if (self.id == 0 or self.resource != source.view.resource) return error.InvalidExchangeIdentity;
    return root.Descriptor.decode((try source.read(key(self.id, 'd', 0))) orelse return error.ExchangeNotFound);
}
fn writable(self: Self, turn: *Turn) !root.Descriptor {
    const d = try self.inspect(turn);
    if (d.owner != turn.delivery.pid) return error.WrongExchangeWriter;
    return d;
}
fn save(self: Self, turn: *Turn, d: root.Descriptor) !void {
    try turn.write(key(self.id, 'd', 0), try d.encode());
}
/// Freeze exact request coverage and its effect intent in the same turn. The
/// ready state prevents recovery from creating a second effect for this group.
pub fn commitIntent(self: Self, turn: *Turn) !Pub.Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    var d = try self.writable(turn);
    if (d.phase == .ready) return .duplicate;
    if (d.phase != .preparing) return error.ExchangeClosed;
    if (d.pending_kind != 0 or d.segments == 0) return error.ExchangeNotPrepared;
    if (turn.decision.effect != null) return error.EffectBudgetExceeded;
    turn.decision.effect = try (root.Intent{ .resource = self.resource, .exchange = self.id, .segments = d.segments, .bytes = d.bytes, .chain = d.chain }).encode();
    d.phase = .ready;
    try self.save(turn, d);
    return .changed;
}
pub fn bind(self: Self, turn: *Turn, effect: p.Growth.Effect) !Pub.Outcome {
    var d = try self.writable(turn);
    if (effect.pid != d.owner or effect.id == 0 or effect.phase != .authorized or effect.attempt == null or effect.executor == null or effect.reconcile_before_ms != d.reconcile_before_ms) return error.InvalidExchangeAttempt;
    if (d.effect != 0) {
        if (d.effect != effect.id or d.attempt != effect.attempt.? or d.executor != effect.executor.?) return error.ExchangeIdentityConflict;
        if (d.phase != .capturing) return error.ExchangeClosed;
        return .duplicate;
    }
    if (d.phase != .ready or d.pending_kind != 0) return error.ExchangeNotPrepared;
    const intent = try root.Intent.decode(effect.payload);
    if (intent.resource != self.resource or intent.exchange != self.id or intent.segments != d.segments or intent.bytes != d.bytes or !std.mem.eql(u8, &intent.chain, &d.chain)) return error.ExchangeIdentityConflict;
    d.effect = effect.id;
    d.attempt = effect.attempt.?;
    d.executor = effect.executor.?;
    d.phase = .capturing;
    try self.save(turn, d);
    return .changed;
}
pub fn member(self: Self, source: anytype, ordinal: u32) !root.Member {
    const d = try self.inspect(source);
    if (ordinal >= d.segments) return error.ExchangeGap;
    const result = try root.Member.decode((try source.read(key(self.id, 'm', ordinal))) orelse return error.ExchangeGap);
    if (result.ordinal != ordinal) return error.InvalidExchangeRecord;
    return result;
}
pub fn beginSegment(self: Self, turn: *Turn, ordinal: u32, kind: u32, spec: Pub.Spec) !Pub.Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    var d = try self.writable(turn);
    if (d.phase != .preparing and d.phase != .capturing) return error.ExchangeClosed;
    if (kind == 0) return error.InvalidExchangeRecord;
    if (ordinal < d.segments) {
        const old = try self.member(turn, ordinal);
        if (old.kind != kind or !std.meta.eql(old.spec(), spec)) return error.ExchangeIdentityConflict;
        return .duplicate;
    }
    if (ordinal != d.segments) return error.ExchangeGap;
    if (d.segments == d.max_segments or spec.length > d.capture_bytes - d.bytes) return error.ExchangeCapacity;
    if (d.pending_kind != 0 and d.pending_kind != kind) return error.ExchangeIdentityConflict;
    const outcome = try self.publication().begin(turn, @as(u64, ordinal) + 1, spec);
    d.pending_kind = kind;
    try self.save(turn, d);
    return outcome;
}
pub fn append(self: Self, turn: *Turn, ordinal: u32, chunk: u32, bytes: []const u8) !Pub.Outcome {
    const d = try self.writable(turn);
    if (d.phase != .preparing and d.phase != .capturing) return error.ExchangeClosed;
    if (ordinal != d.segments or d.pending_kind == 0) return error.ExchangeGap;
    return self.publication().append(turn, @as(u64, ordinal) + 1, chunk, bytes);
}
pub fn sealSegment(self: Self, turn: *Turn, ordinal: u32) !Pub.Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    var d = try self.writable(turn);
    if (d.phase != .preparing and d.phase != .capturing) return error.ExchangeClosed;
    if (ordinal < d.segments) {
        _ = try self.member(turn, ordinal);
        return .duplicate;
    }
    if (ordinal != d.segments or d.pending_kind == 0) return error.ExchangeGap;
    const pubn = self.publication();
    const record = try pubn.inspect(turn, @as(u64, ordinal) + 1);
    if (record.spec.length > d.capture_bytes - d.bytes) return error.ExchangeCapacity;
    const chain = root.Coverage.next(d.chain, ordinal, d.pending_kind, record.spec);
    const entry: root.Member = .{ .ordinal = ordinal, .kind = d.pending_kind, .format = record.spec.format, .length = record.spec.length, .digest = record.spec.digest, .chain = chain };
    _ = try pubn.publish(turn, @as(u64, ordinal) + 1);
    d.segments += 1;
    d.bytes += record.spec.length;
    d.chain = chain;
    d.pending_kind = 0;
    try turn.write(key(self.id, 'm', ordinal), try entry.encode());
    try self.save(turn, d);
    return .changed;
}
pub fn finish(self: Self, turn: *Turn, code: u32) !Pub.Outcome {
    var d = try self.writable(turn);
    if (code == 0) return error.InvalidExchangeRecord;
    if (d.phase == .complete) {
        if (d.terminal_code != code) return error.ExchangeIdentityConflict;
        return .duplicate;
    }
    if (d.phase != .capturing) return error.ExchangeClosed;
    if (d.pending_kind != 0) return error.IncompleteExchange;
    d.phase = .complete;
    d.terminal_code = code;
    try self.save(turn, d);
    return .changed;
}
pub fn reference(self: Self, source: anytype) !root.Client.Reference {
    const d = try self.inspect(source);
    if (d.phase == .retired) return error.ExchangeUnavailable;
    if (d.phase != .complete) return error.IncompleteExchange;
    return .{ .resource = self.resource, .exchange = self.id, .chain = d.chain };
}
pub fn closeUnknown(self: Self, turn: *Turn) !Pub.Outcome {
    var d = try self.writable(turn);
    if (d.phase == .unknown) return .duplicate;
    if (d.phase != .preparing and d.phase != .ready and d.phase != .capturing) return error.ExchangeClosed;
    d.phase = .unknown;
    try self.save(turn, d);
    return .changed;
}
/// Caller must discharge replay dependencies before explicit retirement.
pub fn retire(self: Self, turn: *Turn) !Pub.Outcome {
    var d = try self.writable(turn);
    if (d.phase == .retired) return .duplicate;
    if (d.phase != .complete and d.phase != .unknown) return error.ExchangeStillOpen;
    d.phase = .retired;
    try self.save(turn, d);
    return .changed;
}
/// Each call either closes one member, cleans <=2 chunks, or advances the floor.
pub fn collect(self: Self, turn: *Turn) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    var d = try self.writable(turn);
    if (d.phase != .retired) return error.ExchangeStillOpen;
    const total = @as(u64, d.segments) + @intFromBool(d.pending_kind != 0);
    if (d.collected == total) return true;
    const id = @as(u64, d.collected) + 1;
    const pubn = self.publication();
    const record = try pubn.inspect(turn, id);
    switch (record.state) {
        .staging => {
            _ = try pubn.abandon(turn, id);
            return false;
        },
        .published => {
            _ = try pubn.retire(turn, id);
            return false;
        },
        else => {},
    }
    if (record.reserved or record.collected != record.written) {
        _ = try pubn.collect(turn, id);
        return false;
    }
    d.collected += 1;
    try self.save(turn, d);
    return d.collected == total;
}
pub const Cursor = struct {
    descriptor: root.Descriptor,
    next_member: u32 = 0,
    chain: [32]u8 = root.Coverage.initial,
    bytes: u64 = 0,
    member_cursor: ?Pub.Cursor = null,
};
pub const Part = struct { kind: u32, bytes: p.Value, next: ?Cursor };
fn available(self: Self, current: anytype) !root.Descriptor {
    const d = try self.inspect(current);
    if (d.phase == .retired) return error.ExchangeUnavailable;
    return d;
}
/// `current` must resolve fresh authority at every step, even for old sources.
pub fn open(self: Self, current: anytype, source: anytype) !Cursor {
    const now = try self.available(current);
    const d = try self.inspect(source);
    if (d.phase != .complete or now.phase != .complete) return error.IncompleteExchange;
    if (!std.meta.eql(d, now)) return error.StaleExchangeSource;
    return .{ .descriptor = d };
}
pub fn read(self: Self, current: anytype, source: anytype, cursor: Cursor) !Part {
    const now = try self.available(current);
    if (!std.meta.eql(now, cursor.descriptor) or !std.meta.eql(try self.inspect(source), cursor.descriptor)) return error.StaleExchangeSource;
    if (now.phase != .complete or cursor.next_member > now.segments) return error.IncompleteExchange;
    var next = cursor;
    if (cursor.next_member == now.segments) {
        if (cursor.member_cursor != null or cursor.bytes != now.bytes or !std.mem.eql(u8, &cursor.chain, &now.chain)) return error.InvalidExchangeCoverage;
        return .{ .kind = 0, .bytes = .{}, .next = null };
    }
    const entry = try self.member(source, cursor.next_member);
    const pubn = self.publication();
    const chunk = cursor.member_cursor orelse try pubn.open(source, @as(u64, cursor.next_member) + 1);
    if (!std.meta.eql(chunk.spec, entry.spec()) or chunk.id != @as(u64, cursor.next_member) + 1) return error.InvalidExchangeCoverage;
    const part = try pubn.read(source, chunk);
    next.member_cursor = part.next;
    if (part.next == null) {
        next.chain = root.Coverage.next(cursor.chain, entry.ordinal, entry.kind, entry.spec());
        if (!std.mem.eql(u8, &next.chain, &entry.chain)) return error.InvalidExchangeCoverage;
        if (entry.length > now.bytes -| next.bytes) return error.InvalidExchangeCoverage;
        next.bytes += entry.length;
        next.next_member += 1;
        if (next.next_member == now.segments) {
            if (next.bytes != now.bytes or !std.mem.eql(u8, &next.chain, &now.chain)) return error.InvalidExchangeCoverage;
            return .{ .kind = entry.kind, .bytes = part.bytes, .next = null };
        }
    }
    return .{ .kind = entry.kind, .bytes = part.bytes, .next = next };
}
